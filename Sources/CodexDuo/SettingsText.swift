import Foundation

enum SettingsText {
    private static let translations: [AppLanguage: [String: String]] = [
        .english: [
            "language.system": "System", "window.title": "Codex Duo Settings", "general": "General", "language": "Language",
            "appearance": "Appearance", "system": "System", "light": "Light", "dark": "Dark", "refresh": "Refresh",
            "off": "Off", "1m": "1 min", "2m": "2 min", "5m": "5 min", "10m": "10 min", "15m": "15 min",
            "startup": "Open at login", "activation": "Automatic quota activation", "accounts": "Accounts", "add": "Add",
            "rename": "Rename", "remove": "Remove", "refreshNow": "Refresh", "install": "Copy install command",
            "current": "Current", "unknown": "Unknown", "none": "No accounts", "accountCount": "%d of 10 accounts",
            "dependencyReady": "%@", "dependencyMissing": "codex-auth unavailable"
        ],
        .simplifiedChinese: [
            "language.system": "跟随系统", "window.title": "Codex Duo 设置", "general": "通用", "language": "语言",
            "appearance": "外观", "system": "系统", "light": "浅色", "dark": "深色", "refresh": "自动刷新",
            "off": "关闭", "1m": "1 分钟", "2m": "2 分钟", "5m": "5 分钟", "10m": "10 分钟", "15m": "15 分钟",
            "startup": "登录时打开", "activation": "自动激活额度", "accounts": "账户", "add": "添加", "rename": "重命名",
            "remove": "移除", "refreshNow": "刷新", "install": "复制安装命令", "current": "当前", "unknown": "未知",
            "none": "暂无账户", "accountCount": "%d / 10 个账户", "dependencyReady": "%@", "dependencyMissing": "codex-auth 不可用"
        ],
        .traditionalChinese: [
            "language.system": "跟隨系統", "window.title": "Codex Duo 設定", "general": "一般", "language": "語言",
            "appearance": "外觀", "system": "系統", "light": "淺色", "dark": "深色", "refresh": "自動重新整理",
            "off": "關閉", "1m": "1 分鐘", "2m": "2 分鐘", "5m": "5 分鐘", "10m": "10 分鐘", "15m": "15 分鐘",
            "startup": "登入時開啟", "activation": "自動啟用額度", "accounts": "帳戶", "add": "新增", "rename": "重新命名",
            "remove": "移除", "refreshNow": "重新整理", "install": "複製安裝指令", "current": "目前", "unknown": "未知",
            "none": "沒有帳戶", "accountCount": "%d / 10 個帳戶", "dependencyReady": "%@", "dependencyMissing": "codex-auth 無法使用"
        ],
        .japanese: [
            "language.system": "システム", "window.title": "Codex Duo 設定", "general": "一般", "language": "言語", "appearance": "外観",
            "system": "システム", "light": "ライト", "dark": "ダーク", "refresh": "自動更新", "off": "オフ",
            "1m": "1分", "2m": "2分", "5m": "5分", "10m": "10分", "15m": "15分", "startup": "ログイン時に開く",
            "activation": "クォータを自動有効化", "accounts": "アカウント", "add": "追加", "rename": "名前変更", "remove": "削除",
            "refreshNow": "更新", "install": "インストールコマンドをコピー", "current": "現在", "unknown": "不明", "none": "アカウントなし",
            "accountCount": "%d / 10 アカウント", "dependencyReady": "%@", "dependencyMissing": "codex-auth 利用不可"
        ],
        .korean: [
            "language.system": "시스템", "window.title": "Codex Duo 설정", "general": "일반", "language": "언어", "appearance": "화면 모드",
            "system": "시스템", "light": "라이트", "dark": "다크", "refresh": "자동 새로 고침", "off": "끔",
            "1m": "1분", "2m": "2분", "5m": "5분", "10m": "10분", "15m": "15분", "startup": "로그인 시 열기",
            "activation": "할당량 자동 활성화", "accounts": "계정", "add": "추가", "rename": "이름 변경", "remove": "제거",
            "refreshNow": "새로 고침", "install": "설치 명령 복사", "current": "현재", "unknown": "알 수 없음", "none": "계정 없음",
            "accountCount": "계정 %d / 10", "dependencyReady": "%@", "dependencyMissing": "codex-auth 사용 불가"
        ],
        .spanish: [
            "language.system": "Sistema", "window.title": "Ajustes de Codex Duo", "general": "General", "language": "Idioma", "appearance": "Apariencia",
            "system": "Sistema", "light": "Claro", "dark": "Oscuro", "refresh": "Actualización automática", "off": "No",
            "1m": "1 min", "2m": "2 min", "5m": "5 min", "10m": "10 min", "15m": "15 min", "startup": "Abrir al iniciar sesión",
            "activation": "Activación automática de cuota", "accounts": "Cuentas", "add": "Añadir", "rename": "Renombrar", "remove": "Eliminar",
            "refreshNow": "Actualizar", "install": "Copiar comando de instalación", "current": "Actual", "unknown": "Desconocido", "none": "Sin cuentas",
            "accountCount": "%d de 10 cuentas", "dependencyReady": "%@", "dependencyMissing": "codex-auth no disponible"
        ],
        .french: [
            "language.system": "Système", "window.title": "Réglages Codex Duo", "general": "Général", "language": "Langue", "appearance": "Apparence",
            "system": "Système", "light": "Clair", "dark": "Sombre", "refresh": "Actualisation automatique", "off": "Non",
            "1m": "1 min", "2m": "2 min", "5m": "5 min", "10m": "10 min", "15m": "15 min", "startup": "Ouvrir à la connexion",
            "activation": "Activation automatique du quota", "accounts": "Comptes", "add": "Ajouter", "rename": "Renommer", "remove": "Supprimer",
            "refreshNow": "Actualiser", "install": "Copier la commande d’installation", "current": "Actuel", "unknown": "Inconnu", "none": "Aucun compte",
            "accountCount": "%d comptes sur 10", "dependencyReady": "%@", "dependencyMissing": "codex-auth indisponible"
        ],
        .german: [
            "language.system": "System", "window.title": "Codex Duo Einstellungen", "general": "Allgemein", "language": "Sprache", "appearance": "Darstellung",
            "system": "System", "light": "Hell", "dark": "Dunkel", "refresh": "Automatisch aktualisieren", "off": "Aus",
            "1m": "1 Min.", "2m": "2 Min.", "5m": "5 Min.", "10m": "10 Min.", "15m": "15 Min.", "startup": "Bei Anmeldung öffnen",
            "activation": "Kontingent automatisch aktivieren", "accounts": "Konten", "add": "Hinzufügen", "rename": "Umbenennen", "remove": "Entfernen",
            "refreshNow": "Aktualisieren", "install": "Installationsbefehl kopieren", "current": "Aktuell", "unknown": "Unbekannt", "none": "Keine Konten",
            "accountCount": "%d von 10 Konten", "dependencyReady": "%@", "dependencyMissing": "codex-auth nicht verfügbar"
        ]
    ]

    static func value(_ key: String, language: AppLanguage) -> String {
        translations[language.resolved]?[key] ?? translations[.english]?[key] ?? key
    }
}
