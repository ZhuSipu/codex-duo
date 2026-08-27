using System.Globalization;

namespace CodexDuo.Windows.Core;

public sealed class Localizer
{
    private static readonly Dictionary<string, Dictionary<string, string>> Values = new(StringComparer.Ordinal)
    {
        ["en"] = new()
        {
            ["accounts"] = "Accounts",
            ["active"] = "Active",
            ["unavailable"] = "Unavailable",
            ["refresh"] = "Refresh Now",
            ["settings"] = "Settings",
            ["quit"] = "Quit",
            ["appearance"] = "Appearance",
            ["language"] = "Language",
            ["interval"] = "Automatic refresh",
            ["startup"] = "Open Codex Duo at sign-in",
            ["activation"] = "Activate refreshed weekly quotas",
            ["add"] = "Add Account…",
            ["rename"] = "Rename…",
            ["remove"] = "Remove…",
            ["apply"] = "Apply",
            ["dependency"] = "codex-auth is unavailable. Install: npm install -g @loongphy/codex-auth@next",
            ["empty"] = "No accounts are configured. Add an account, finish login, then refresh.",
            ["fiveHour"] = "5 HOUR",
            ["weekly"] = "WEEKLY",
            ["remaining"] = "remaining",
            ["general"] = "General",
            ["dependencyReady"] = "codex-auth is ready",
            ["none"] = "No accounts",
            ["accountCount"] = "{0} accounts",
            ["install"] = "Copy Install Command",
            ["system"] = "System",
            ["light"] = "Light",
            ["dark"] = "Dark",
            ["off"] = "Off",
            ["everyMinute"] = "Every minute",
            ["everyMinutes"] = "Every {0} minutes",
        },
        ["zh-Hans"] = new()
        {
            ["accounts"] = "账户",
            ["active"] = "当前",
            ["unavailable"] = "不可用",
            ["refresh"] = "立即刷新",
            ["settings"] = "设置",
            ["quit"] = "退出",
            ["appearance"] = "外观",
            ["language"] = "语言",
            ["interval"] = "自动刷新",
            ["startup"] = "登录时启动 Codex Duo",
            ["activation"] = "自动激活刷新的周配额",
            ["add"] = "添加账户…",
            ["rename"] = "重命名…",
            ["remove"] = "移除…",
            ["apply"] = "应用",
            ["dependency"] = "codex-auth 不可用。安装：npm install -g @loongphy/codex-auth@next",
            ["empty"] = "尚未配置账户。添加账户并完成登录，然后刷新。",
            ["fiveHour"] = "5 小时",
            ["weekly"] = "每周",
            ["remaining"] = "剩余",
            ["general"] = "通用",
            ["dependencyReady"] = "codex-auth 已就绪",
            ["none"] = "没有账户",
            ["accountCount"] = "{0} 个账户",
            ["install"] = "复制安装命令",
            ["system"] = "跟随系统",
            ["light"] = "浅色",
            ["dark"] = "深色",
            ["off"] = "关闭",
            ["everyMinute"] = "每分钟",
            ["everyMinutes"] = "每 {0} 分钟",
        },
        ["zh-Hant"] = new()
        {
            ["accounts"] = "帳戶",
            ["active"] = "目前",
            ["unavailable"] = "無法使用",
            ["refresh"] = "立即重新整理",
            ["settings"] = "設定",
            ["quit"] = "結束",
            ["appearance"] = "外觀",
            ["language"] = "語言",
            ["interval"] = "自動重新整理",
            ["startup"] = "登入時啟動 Codex Duo",
            ["activation"] = "自動啟用重新整理的每週配額",
            ["add"] = "新增帳戶…",
            ["rename"] = "重新命名…",
            ["remove"] = "移除…",
            ["apply"] = "套用",
            ["dependency"] = "codex-auth 無法使用。安裝：npm install -g @loongphy/codex-auth@next",
            ["empty"] = "尚未設定帳戶。新增帳戶並完成登入，然後重新整理。",
            ["fiveHour"] = "5 小時",
            ["weekly"] = "每週",
            ["remaining"] = "剩餘",
            ["general"] = "一般",
            ["dependencyReady"] = "codex-auth 已就緒",
            ["none"] = "沒有帳戶",
            ["accountCount"] = "{0} 個帳戶",
            ["install"] = "複製安裝命令",
            ["system"] = "跟隨系統",
            ["light"] = "淺色",
            ["dark"] = "深色",
            ["off"] = "關閉",
            ["everyMinute"] = "每分鐘",
            ["everyMinutes"] = "每 {0} 分鐘",
        },
        ["ja"] = new()
        {
            ["accounts"] = "アカウント",
            ["active"] = "使用中",
            ["unavailable"] = "利用不可",
            ["refresh"] = "今すぐ更新",
            ["settings"] = "設定",
            ["quit"] = "終了",
            ["appearance"] = "外観",
            ["language"] = "言語",
            ["interval"] = "自動更新",
            ["startup"] = "サインイン時に起動",
            ["activation"] = "更新された週次クォータを有効化",
            ["add"] = "アカウントを追加…",
            ["rename"] = "名前を変更…",
            ["remove"] = "削除…",
            ["apply"] = "適用",
        },
        ["ko"] = new()
        {
            ["accounts"] = "계정",
            ["active"] = "활성",
            ["unavailable"] = "사용 불가",
            ["refresh"] = "지금 새로 고침",
            ["settings"] = "설정",
            ["quit"] = "종료",
            ["appearance"] = "모양",
            ["language"] = "언어",
            ["interval"] = "자동 새로 고침",
            ["startup"] = "로그인할 때 시작",
            ["activation"] = "갱신된 주간 할당량 활성화",
            ["add"] = "계정 추가…",
            ["rename"] = "이름 바꾸기…",
            ["remove"] = "제거…",
            ["apply"] = "적용",
        },
        ["es"] = new()
        {
            ["accounts"] = "Cuentas",
            ["active"] = "Activa",
            ["unavailable"] = "No disponible",
            ["refresh"] = "Actualizar ahora",
            ["settings"] = "Ajustes",
            ["quit"] = "Salir",
            ["appearance"] = "Apariencia",
            ["language"] = "Idioma",
            ["interval"] = "Actualización automática",
            ["startup"] = "Abrir al iniciar sesión",
            ["activation"] = "Activar cuotas semanales renovadas",
            ["add"] = "Añadir cuenta…",
            ["rename"] = "Renombrar…",
            ["remove"] = "Eliminar…",
            ["apply"] = "Aplicar",
        },
        ["fr"] = new()
        {
            ["accounts"] = "Comptes",
            ["active"] = "Actif",
            ["unavailable"] = "Indisponible",
            ["refresh"] = "Actualiser",
            ["settings"] = "Réglages",
            ["quit"] = "Quitter",
            ["appearance"] = "Apparence",
            ["language"] = "Langue",
            ["interval"] = "Actualisation automatique",
            ["startup"] = "Ouvrir à la connexion",
            ["activation"] = "Activer les quotas hebdomadaires renouvelés",
            ["add"] = "Ajouter un compte…",
            ["rename"] = "Renommer…",
            ["remove"] = "Supprimer…",
            ["apply"] = "Appliquer",
        },
        ["de"] = new()
        {
            ["accounts"] = "Konten",
            ["active"] = "Aktiv",
            ["unavailable"] = "Nicht verfügbar",
            ["refresh"] = "Jetzt aktualisieren",
            ["settings"] = "Einstellungen",
            ["quit"] = "Beenden",
            ["appearance"] = "Darstellung",
            ["language"] = "Sprache",
            ["interval"] = "Automatisch aktualisieren",
            ["startup"] = "Bei Anmeldung öffnen",
            ["activation"] = "Erneuerte Wochenkontingente aktivieren",
            ["add"] = "Konto hinzufügen…",
            ["rename"] = "Umbenennen…",
            ["remove"] = "Entfernen…",
            ["apply"] = "Anwenden",
        },
    };

    public Localizer(string language)
    {
        Language = ResolveLanguage(language);
    }

    public string Language { get; }
    public string this[string key] => Values.GetValueOrDefault(Language)?.GetValueOrDefault(key)
        ?? Values["en"].GetValueOrDefault(key)
        ?? key;

    public static string ResolveLanguage(string language)
    {
        if (language != "system" && Values.ContainsKey(language)) return language;
        var code = CultureInfo.CurrentUICulture.Name;
        if (code.StartsWith("zh-Hant", StringComparison.OrdinalIgnoreCase) || code.StartsWith("zh-TW", StringComparison.OrdinalIgnoreCase) || code.StartsWith("zh-HK", StringComparison.OrdinalIgnoreCase)) return "zh-Hant";
        if (code.StartsWith("zh", StringComparison.OrdinalIgnoreCase)) return "zh-Hans";
        foreach (var candidate in new[] { "ja", "ko", "es", "fr", "de" })
        {
            if (code.StartsWith(candidate, StringComparison.OrdinalIgnoreCase)) return candidate;
        }
        return "en";
    }
}
