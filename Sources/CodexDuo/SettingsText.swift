import Foundation

enum SettingsText {
    private static let translations: [AppLanguage: [String: String]] = [
        .english: [
            "language.system": "System", "window.title": "Settings", "general": "General", "language": "Language",
            "appearance": "Appearance", "system": "System", "light": "Light", "dark": "Dark", "refresh": "Refresh", "proxy": "Proxy",
            "off": "Off", "1m": "1 min", "2m": "2 min", "5m": "5 min", "10m": "10 min", "15m": "15 min",
            "startup": "Open at login", "accounts": "Accounts", "add": "Add",
            "rename": "Rename", "remove": "Remove", "refreshNow": "Refresh",
            "current": "Current", "unknown": "Unknown", "none": "No accounts", "accountCount": "%d / 10",
            "appIncomplete": "Codex Duo is incomplete. Reinstall the app.", "addHelp": "Add an account to begin.",
            "loginOpening": "Opening Terminal…", "loginWaiting": "Finish in Terminal. This list updates automatically.",
            "loginAdded": "Account added.", "loginNotAdded": "No account added. Check Terminal and try again.",
            "loginOpenFailed": "Unable to Open Login", "refreshingStatus": "Refreshing…",
            "refreshStarted": "Refresh started.",
            "proxyPlaceholder": "Automatic (system proxy)", "proxyInvalid": "Use http, https, socks5, or socks5h without credentials."
        ],
        .simplifiedChinese: [
            "language.system": "跟随系统", "window.title": "设置", "general": "通用", "language": "语言",
            "appearance": "外观", "system": "系统", "light": "浅色", "dark": "深色", "refresh": "自动刷新", "proxy": "代理",
            "off": "关闭", "1m": "1 分钟", "2m": "2 分钟", "5m": "5 分钟", "10m": "10 分钟", "15m": "15 分钟",
            "startup": "登录时打开", "accounts": "账户", "add": "添加", "rename": "重命名",
            "remove": "移除", "refreshNow": "刷新", "current": "当前", "unknown": "未知",
            "none": "暂无账户", "accountCount": "%d / 10",
            "appIncomplete": "Codex Duo 安装不完整，请重新安装应用。", "addHelp": "添加账户以开始。",
            "loginOpening": "正在打开终端…", "loginWaiting": "请在终端完成登录，此处会自动更新。",
            "loginAdded": "账户已添加。", "loginNotAdded": "未添加账户，请查看终端后重试。",
            "loginOpenFailed": "无法打开登录", "refreshingStatus": "正在刷新…",
            "refreshStarted": "已开始刷新。", "proxyPlaceholder": "自动（系统代理）", "proxyInvalid": "请使用不含凭据的 http、https、socks5 或 socks5h 地址。"
        ],
        .traditionalChinese: [
            "language.system": "跟隨系統", "window.title": "設定", "general": "一般", "language": "語言",
            "appearance": "外觀", "system": "系統", "light": "淺色", "dark": "深色", "refresh": "自動重新整理", "proxy": "代理",
            "off": "關閉", "1m": "1 分鐘", "2m": "2 分鐘", "5m": "5 分鐘", "10m": "10 分鐘", "15m": "15 分鐘",
            "startup": "登入時開啟", "accounts": "帳戶", "add": "新增", "rename": "重新命名",
            "remove": "移除", "refreshNow": "重新整理", "current": "目前", "unknown": "未知",
            "none": "沒有帳戶", "accountCount": "%d / 10",
            "appIncomplete": "Codex Duo 安裝不完整，請重新安裝應用程式。", "addHelp": "新增帳戶以開始。",
            "loginOpening": "正在開啟終端機…", "loginWaiting": "請在終端機完成登入，此處會自動更新。",
            "loginAdded": "帳戶已新增。", "loginNotAdded": "未新增帳戶，請查看終端機後重試。",
            "loginOpenFailed": "無法開啟登入", "refreshingStatus": "正在重新整理…",
            "refreshStarted": "已開始重新整理。", "proxyPlaceholder": "自動（系統代理）", "proxyInvalid": "請使用不含憑據的 http、https、socks5 或 socks5h 位址。"
        ],
        .japanese: [
            "language.system": "システム", "window.title": "設定", "general": "一般", "language": "言語", "appearance": "外観",
            "system": "システム", "light": "ライト", "dark": "ダーク", "refresh": "自動更新", "proxy": "プロキシ", "off": "オフ",
            "1m": "1分", "2m": "2分", "5m": "5分", "10m": "10分", "15m": "15分", "startup": "ログイン時に開く",
            "accounts": "アカウント", "add": "追加", "rename": "名前変更", "remove": "削除",
            "refreshNow": "更新", "current": "現在", "unknown": "不明", "none": "アカウントなし",
            "accountCount": "%d / 10", "appIncomplete": "Codex Duo が不完全です。アプリを再インストールしてください。", "addHelp": "アカウントを追加してください。",
            "loginOpening": "ターミナルを開いています…", "loginWaiting": "ターミナルでログインを完了してください。自動で更新されます。",
            "loginAdded": "アカウントを追加しました。", "loginNotAdded": "追加されませんでした。ターミナルを確認して再試行してください。",
            "loginOpenFailed": "ログインを開けません", "refreshingStatus": "更新中…",
            "refreshStarted": "更新を開始しました。", "proxyPlaceholder": "自動（システムプロキシ）", "proxyInvalid": "認証情報なしの http、https、socks5、socks5h を使用してください。"
        ],
        .korean: [
            "language.system": "시스템", "window.title": "설정", "general": "일반", "language": "언어", "appearance": "화면 모드",
            "system": "시스템", "light": "라이트", "dark": "다크", "refresh": "자동 새로 고침", "proxy": "프록시", "off": "끔",
            "1m": "1분", "2m": "2분", "5m": "5분", "10m": "10분", "15m": "15분", "startup": "로그인 시 열기",
            "accounts": "계정", "add": "추가", "rename": "이름 변경", "remove": "제거",
            "refreshNow": "새로 고침", "current": "현재", "unknown": "알 수 없음", "none": "계정 없음",
            "accountCount": "%d / 10", "appIncomplete": "Codex Duo 설치가 완전하지 않습니다. 앱을 다시 설치하세요.", "addHelp": "계정을 추가하세요.",
            "loginOpening": "터미널 여는 중…", "loginWaiting": "터미널에서 로그인을 완료하세요. 자동으로 업데이트됩니다.",
            "loginAdded": "계정이 추가되었습니다.", "loginNotAdded": "계정이 추가되지 않았습니다. 터미널 확인 후 다시 시도하세요.",
            "loginOpenFailed": "로그인을 열 수 없음", "refreshingStatus": "새로 고치는 중…",
            "refreshStarted": "새로 고침을 시작했습니다.", "proxyPlaceholder": "자동(시스템 프록시)", "proxyInvalid": "자격 증명 없이 http, https, socks5 또는 socks5h를 사용하세요."
        ],
        .spanish: [
            "language.system": "Sistema", "window.title": "Ajustes", "general": "General", "language": "Idioma", "appearance": "Apariencia",
            "system": "Sistema", "light": "Claro", "dark": "Oscuro", "refresh": "Actualización automática", "proxy": "Proxy", "off": "No",
            "1m": "1 min", "2m": "2 min", "5m": "5 min", "10m": "10 min", "15m": "15 min", "startup": "Abrir al iniciar sesión",
            "accounts": "Cuentas", "add": "Añadir", "rename": "Renombrar", "remove": "Eliminar",
            "refreshNow": "Actualizar", "current": "Actual", "unknown": "Desconocido", "none": "Sin cuentas",
            "accountCount": "%d / 10", "appIncomplete": "Codex Duo está incompleto. Reinstala la aplicación.", "addHelp": "Añade una cuenta para empezar.",
            "loginOpening": "Abriendo Terminal…", "loginWaiting": "Termina en Terminal. La lista se actualizará sola.",
            "loginAdded": "Cuenta añadida.", "loginNotAdded": "No se añadió. Revisa Terminal e inténtalo de nuevo.",
            "loginOpenFailed": "No se pudo abrir el inicio de sesión", "refreshingStatus": "Actualizando…",
            "refreshStarted": "Actualización iniciada.", "proxyPlaceholder": "Automático (proxy del sistema)", "proxyInvalid": "Usa http, https, socks5 o socks5h sin credenciales."
        ],
        .french: [
            "language.system": "Système", "window.title": "Réglages", "general": "Général", "language": "Langue", "appearance": "Apparence",
            "system": "Système", "light": "Clair", "dark": "Sombre", "refresh": "Actualisation automatique", "proxy": "Proxy", "off": "Non",
            "1m": "1 min", "2m": "2 min", "5m": "5 min", "10m": "10 min", "15m": "15 min", "startup": "Ouvrir à la connexion",
            "accounts": "Comptes", "add": "Ajouter", "rename": "Renommer", "remove": "Supprimer",
            "refreshNow": "Actualiser", "current": "Actuel", "unknown": "Inconnu", "none": "Aucun compte",
            "accountCount": "%d / 10", "appIncomplete": "Codex Duo est incomplet. Réinstallez l’application.", "addHelp": "Ajoutez un compte pour commencer.",
            "loginOpening": "Ouverture du Terminal…", "loginWaiting": "Terminez dans Terminal. La liste se mettra à jour seule.",
            "loginAdded": "Compte ajouté.", "loginNotAdded": "Aucun ajout. Vérifiez Terminal et réessayez.",
            "loginOpenFailed": "Impossible d’ouvrir la connexion", "refreshingStatus": "Actualisation…",
            "refreshStarted": "Actualisation lancée.", "proxyPlaceholder": "Automatique (proxy système)", "proxyInvalid": "Utilisez http, https, socks5 ou socks5h sans identifiants."
        ],
        .german: [
            "language.system": "System", "window.title": "Einstellungen", "general": "Allgemein", "language": "Sprache", "appearance": "Darstellung",
            "system": "System", "light": "Hell", "dark": "Dunkel", "refresh": "Automatisch aktualisieren", "proxy": "Proxy", "off": "Aus",
            "1m": "1 Min.", "2m": "2 Min.", "5m": "5 Min.", "10m": "10 Min.", "15m": "15 Min.", "startup": "Bei Anmeldung öffnen",
            "accounts": "Konten", "add": "Hinzufügen", "rename": "Umbenennen", "remove": "Entfernen",
            "refreshNow": "Aktualisieren", "current": "Aktuell", "unknown": "Unbekannt", "none": "Keine Konten",
            "accountCount": "%d / 10", "appIncomplete": "Codex Duo ist unvollständig. Installieren Sie die App erneut.", "addHelp": "Fügen Sie ein Konto hinzu.",
            "loginOpening": "Terminal wird geöffnet…", "loginWaiting": "Im Terminal anmelden. Die Liste wird automatisch aktualisiert.",
            "loginAdded": "Konto hinzugefügt.", "loginNotAdded": "Kein Konto hinzugefügt. Terminal prüfen und erneut versuchen.",
            "loginOpenFailed": "Anmeldung konnte nicht geöffnet werden", "refreshingStatus": "Aktualisieren…",
            "refreshStarted": "Aktualisierung gestartet.", "proxyPlaceholder": "Automatisch (Systemproxy)", "proxyInvalid": "Verwenden Sie http, https, socks5 oder socks5h ohne Zugangsdaten."
        ]
    ]

    static func value(_ key: String, language: AppLanguage) -> String {
        translations[language.resolved]?[key] ?? translations[.english]?[key] ?? key
    }
}
