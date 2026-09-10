# Codex Duo

<p align="center">
  <strong>在菜单栏里掌握每个 Codex 账号。</strong><br>
  查看剩余用量、了解重置时间，并在需要时快速切换账号。
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.en.md">English</a> · <a href="https://github.com/ZhuSipu/codex-duo/releases/latest">下载最新版</a>
</p>

<p align="center">
  <img src="docs/assets/codex-duo-macos-live-demo.webp" alt="Codex Duo 在 macOS 菜单栏中显示账号用量并打开设置" width="800">
</p>

Codex Duo 是一款紧凑的原生桌面工具。它在 macOS 菜单栏或 Windows 系统托盘中集中显示多个 Codex 账号的剩余用量和重置倒计时，并通过 [`codex-auth`](https://github.com/Loongphy/codex-auth) 完成账号管理与切换。

## 为什么使用 Codex Duo

- **不必逐个账号查看。** 一个面板最多展示十个账号及其实际返回的用量窗口。
- **随时知道何时重置。** 剩余百分比、重置倒计时和数据更新时间一目了然。
- **切换更省心。** 选择目标账号后，Codex Duo 会完成切换验证并重新打开 Codex App。
- **刷新失败也不丢数据。** 最近一次已验证的用量会继续显示，并明确标记陈旧状态。
- **账号操作集中完成。** 可以添加、重命名、移除账号，也可以手动刷新或设置自动刷新。
- **尊重隐私边界。** 不读取认证快照、不保存令牌，也不包含分析统计或遥测。
- **贴合系统体验。** 支持系统、浅色和深色外观，九种语言以及可选的登录时启动。

## 产品界面

<p align="center">
  <img src="docs/assets/codex-duo-macos-accounts.png" alt="Codex Duo macOS 账号菜单" width="49%">
  <img src="docs/assets/codex-duo-macos-settings.png" alt="Codex Duo macOS 设置窗口" width="49%">
</p>

macOS 使用原生 AppKit 菜单栏界面，Windows 使用原生 .NET 8 WPF 系统托盘界面。两个版本共享相同的账号、用量和切换规则，同时遵循各自平台的操作习惯。

## 下载与要求

从最新 [GitHub Release](https://github.com/ZhuSipu/codex-duo/releases/latest) 下载与你的系统对应的安装包及 SHA-256 校验文件。

### macOS

- macOS 14 或更高版本
- Apple Silicon（当前发布包）
- 官方 Codex App
- Node.js/npm 与 `codex-auth`

下载 `macOS-arm64.dmg`，打开后将 **Codex Duo** 拖入 **Applications（应用程序）**。当前个人构建可能尚未经过 Apple 公证；请先核对下载来源，然后通过 Control-点击应用 → **打开**完成首次启动。不要全局关闭 Gatekeeper。

### Windows

- Windows 10 2004 或更高版本，或 Windows 11
- x64 处理器
- 官方 Codex App
- Node.js/npm 与 `codex-auth`
- 安装版需要 [.NET 8 Desktop Runtime (x64)](https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe)

运行 `Codex-Duo-<版本>-Windows-x64-Setup.exe` 即可完成当前用户安装，无需管理员权限。如果不希望单独安装 .NET 运行时，可以下载已包含运行时的自包含便携 ZIP。未签名构建可能触发 SmartScreen，请先核对校验值与下载来源。

### 安装账号辅助工具

Codex Duo 会检测 `codex-auth` 是否可用，但不会静默安装依赖：

```shell
npm install -g @loongphy/codex-auth@next
codex-auth --help
```

## 开始使用

1. 启动 Codex Duo。
2. 打开设置并点击**添加**。
3. 在终端中完成 Codex 官方登录流程。
4. 返回 Codex Duo，账号和用量会自动出现。
5. 点击非当前账号即可开始切换。

认证始终由 Codex 与 `codex-auth` 管理。Codex Duo 不会要求你输入密码，也不会显示访问令牌。

## 日常使用

### 查看用量

每个账号会显示可用的 5 小时、每周、Free 每月或其他实际返回的用量窗口。重置时间已到时，该窗口会恢复为 100%；缺失的数据会显示为不可用，而不是 0。

### 切换账号

点击目标账号后，Codex Duo 会关闭 Codex App、执行切换、验证活动账号，再重新打开 Codex。切换会中断正在生成的回复，因此请先停止当前任务。点击当前账号不会执行任何操作。

### 刷新与设置

自动刷新可设为关闭或 1、2、5、10、15 分钟。即使关闭自动刷新，仍可使用**立即刷新**。设置还包括外观、语言、登录时启动、账号管理以及平台对应的代理选项。

## 常见问题

- **菜单或托盘显示 —：**确认 `codex-auth --help` 可以运行，并且至少配置了一个账号。
- **用量显示为陈旧：**检查时间标记，启用自动刷新或点击**立即刷新**；刷新失败时会保留最近的已验证数据。
- **无法切换账号：**先停止活动任务并手动关闭 Codex，然后重试。
- **登录时启动无效：**将应用安装到系统常规位置，从该位置启动一次后重新开启此设置。
- **macOS 无法添加账号：**确认系统终端位于 `/System/Applications/Utilities`，然后重新打开设置。

## 隐私与风险

Codex Duo 只读取 `~/.codex/accounts/registry.json`，不会直接修改它，也不会打开受管理的 `*.auth.json` 文件。登录、刷新和账号操作均交给 `codex-auth`。

默认情况下，`codex-auth list` 可能向 OpenAI 端点发送账号访问令牌以刷新用量。上游说明该方式依赖非公开行为，可能失效并可能带来账号风险。使用前请阅读 [`codex-auth` 免责声明](https://github.com/Loongphy/codex-auth#disclaimer)。

## 从源码构建

<details>
<summary>macOS 与 Windows 开发命令</summary>

macOS 需要 macOS 14+ 和 Swift 5.10 命令行工具：

```shell
./Scripts/test.sh
app_path=$(./Scripts/build_app.sh)
open "$app_path"
```

Windows 需要 .NET 8 SDK，并且必须在 Windows 主机上构建和验证：

```powershell
dotnet test Windows/CodexDuo.Windows.sln -c Release
./Scripts/package_windows.ps1
```

贡献前请阅读 [`docs/development-workflow.md`](docs/development-workflow.md)、[`docs/feature-spec.md`](docs/feature-spec.md) 和 [`docs/design-language.md`](docs/design-language.md)。

</details>

## License

MIT。参见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
