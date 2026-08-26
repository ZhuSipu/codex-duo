import Foundation

struct LocalUsageSample: Codable {
    let observedAt: Date
    let snapshot: UsageSnapshot
}

final class LocalCodexUsageReader {
    private struct CachedFile {
        let modifiedAt: Date?
        let size: Int?
        let samples: [LocalUsageSample]
    }

    private let fileManager: FileManager
    private let sessionsRoot: URL
    private let cacheLock = NSLock()
    private var fileCache: [URL: CachedFile] = [:]

    init(fileManager: FileManager = .default, sessionsRoot: URL? = nil) {
        self.fileManager = fileManager
        self.sessionsRoot = sessionsRoot ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    func latestSample(notBefore threshold: Date, now: Date = Date()) -> LocalUsageSample? {
        self.latestSamples(notBefore: threshold, now: now).max { $0.observedAt < $1.observedAt }
    }

    func latestSamples(notBefore threshold: Date, now: Date = Date()) -> [LocalUsageSample] {
        self.cacheLock.lock()
        defer { self.cacheLock.unlock() }

        var allSamples: [LocalUsageSample] = []
        let calendar = Calendar.current
        let requestedDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: threshold),
            to: calendar.startOfDay(for: now)).day ?? 0
        let oldestDayOffset = -max(0, min(7, requestedDays))
        var seenFiles = Set<URL>()
        for dayOffset in stride(from: 0, through: oldestDayOffset, by: -1) {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
            guard let year = components.year, let month = components.month, let dayNumber = components.day else { continue }
            let directory = self.sessionsRoot
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", dayNumber), isDirectory: true)
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles])
            else { continue }

            for file in files where file.pathExtension == "jsonl" {
                seenFiles.insert(file)
                let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard values?.contentModificationDate.map({ $0 >= threshold }) ?? false else { continue }
                let cached = self.fileCache[file]
                if cached?.modifiedAt == values?.contentModificationDate, cached?.size == values?.fileSize {
                    allSamples.append(contentsOf: cached?.samples ?? [])
                    continue
                }
                guard let text = self.readTail(file, maximumBytes: 524_288) else { continue }
                let samples = text.split(separator: "\n").compactMap { Self.parseLine(String($0)) }
                self.fileCache[file] = CachedFile(
                    modifiedAt: values?.contentModificationDate,
                    size: values?.fileSize,
                    samples: samples)
                allSamples.append(contentsOf: samples)
            }
        }
        self.fileCache = self.fileCache.filter { seenFiles.contains($0.key) }

        var clusters: [(reset: TimeInterval, sample: LocalUsageSample)] = []
        for sample in allSamples where sample.observedAt >= threshold {
            guard let reset = sample.snapshot.weekly?.resetsAt else { continue }
            if let index = clusters.firstIndex(where: { abs($0.reset - reset) <= 300 }) {
                if sample.observedAt > clusters[index].sample.observedAt {
                    clusters[index] = (reset, sample)
                }
            } else {
                clusters.append((reset, sample))
            }
        }
        return clusters.map(\.sample)
    }

    static func parseLine(_ line: String) -> LocalUsageSample? {
        guard let data = line.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let rateLimits = payload["rate_limits"] as? [String: Any],
              rateLimits["limit_id"] as? String == "codex",
              let primaryObject = rateLimits["primary"] as? [String: Any],
              let primary = Self.window(primaryObject),
              let timestamp = root["timestamp"] as? String,
              let observedAt = Self.parseDate(timestamp)
        else { return nil }

        let secondary = (rateLimits["secondary"] as? [String: Any]).flatMap(Self.window)
        return LocalUsageSample(
            observedAt: observedAt,
            snapshot: UsageSnapshot(primary: primary, secondary: secondary))
    }

    private static func window(_ object: [String: Any]) -> RateLimitWindow? {
        guard let used = (object["used_percent"] as? NSNumber)?.doubleValue else { return nil }
        return RateLimitWindow(
            usedPercent: used,
            windowMinutes: (object["window_minutes"] as? NSNumber)?.intValue,
            resetsAt: (object["resets_at"] as? NSNumber)?.doubleValue)
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private func readTail(_ url: URL, maximumBytes: UInt64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > maximumBytes ? size - maximumBytes : 0
        try? handle.seek(toOffset: offset)
        guard var text = String(data: handle.readDataToEndOfFile(), encoding: .utf8) else { return nil }
        if offset > 0, let newline = text.firstIndex(of: "\n") { text.removeSubrange(...newline) }
        return text
    }
}

final class LocalUsageStore {
    private let defaults: UserDefaults
    private let key = "localUsageSamplesByAccount"
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: LocalUsageSample] {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard let data = self.defaults.data(forKey: self.key),
              let samples = try? JSONDecoder().decode([String: LocalUsageSample].self, from: data)
        else { return [:] }
        return samples
    }

    func save(_ samples: [String: LocalUsageSample]) {
        self.lock.lock()
        defer { self.lock.unlock() }
        if samples.isEmpty {
            self.defaults.removeObject(forKey: self.key)
        } else if let data = try? JSONEncoder().encode(samples) {
            self.defaults.set(data, forKey: self.key)
        }
    }
}
