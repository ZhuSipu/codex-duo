# Codex Duo

[English](README.md) | [简体中文](README.zh-CN.md)

Codex Duo 是一款紧凑的原生桌面工具：在 macOS 上驻留菜单栏，在 Windows 上驻留系统托盘，用于查看并切换最多十个由 [`codex-auth`](https://github.com/Loongphy/codex-auth) 管理的 Codex 账号。

> macOS 与 Windows 是两个独立的原生实现，共享产品行为和设计原则。现阶段以 macOS 界面作为视觉基准；Windows 在遵循 Windows 原生控件和系统托盘习惯的前提下对齐同一套设计语言。详见[开发边界](#开发边界)。

## 功能

- macOS 使用原生 AppKit 菜单栏界面，Windows 使用原生 .NET 8 WPF 系统托盘界面。
- 跟随系统的明暗材质、克制的层次、光泽和动效。
- 支持最多十个账号，自适应显示 5 小时、每周、Free 每月及其他实际返回的用量窗口。
- 显示重置倒计时和陈旧数据时间标记。
- 点击账号后立即切换，验证成功再重启 Codex App。
- 添加、重命名、移除和刷新账号均交给 `codex-auth` 处理。
- 支持九种语言选项、自动刷新、代理和可选的开机启动。
- 不内置凭据、账号快照、分析统计或独立网络客户端。

## 下载与安装

请从最新的 [GitHub Release](https://github.com/ZhuSipu/codex-duo/releases/latest) 下载与你的操作系统对应的文件。普通用户推荐使用 Release 安装包；源码安装主要供开发使用。

### macOS

要求：macOS 14 或更高版本；当前发布包面向 Apple Silicon；已安装官方 Codex App、Node.js/npm 和 `codex-auth`。

1. 下载名称含 `macOS-arm64.dmg` 的发布文件和 `SHA256SUMS-macOS-arm64.txt`。
2. 打开 DMG，将 **Codex Duo** 拖入 **Applications（应用程序）**。
3. 校验 SHA-256，然后从应用程序目录启动 Codex Duo。
4. 当前个人构建尚未经过 Apple 公证；如 macOS 阻止首次启动，请按住 Control 点击应用，依次选择**打开**并再次确认。不要全局关闭 Gatekeeper。
5. 打开设置，点击**添加**，在终端中完成 Codex 官方登录流程。

ZIP 仅用于便携或手动部署。如果需要“登录时启动”稳定工作，请不要直接从 DMG 或下载目录运行应用。

```shell
shasum -a 256 -c SHA256SUMS-macOS-arm64.txt
```

### Windows

要求：Windows 10 2004 或更高版本，或 Windows 11；x64 处理器；已安装官方 Codex App、Node.js/npm 和 `codex-auth`。发布包已经包含所需的 .NET 运行时。

1. 下载 `Codex-Duo-<版本>-Windows-x64-Setup.exe` 和 `SHA256SUMS-Windows-x64.txt`。
2. 校验安装包的 SHA-256 后运行安装程序。它采用当前用户安装，不需要管理员权限。
3. 未签名的个人构建可能触发 SmartScreen；继续前请核对校验值和下载来源。
4. 启动 Codex Duo，在设置中添加账号。

只有在无法正常安装时才建议使用便携 ZIP；请先完整解压到固定目录再启动。开机启动默认关闭。

```powershell
Get-FileHash .\Codex-Duo-*-Windows-x64-Setup.exe -Algorithm SHA256
Get-Content .\SHA256SUMS-Windows-x64.txt
```

### 安装账号辅助工具

Codex Duo 会检测辅助工具是否缺失，并在设置中显示安装命令，但不会静默下载任何依赖：

```shell
npm install -g @loongphy/codex-auth@next
codex-auth --help
```

macOS 会在 `~/.local/bin`、`/opt/homebrew/bin` 和 `/usr/local/bin` 中查找 `codex-auth`。Windows 会定位 npm 全局安装的 `codex-auth` 与 Codex CLI，并通过 Node.js 调用其 JavaScript 入口。

## 首次启动与日常使用

如果尚未配置账号，Codex Duo 会在首次启动时打开一次设置。点击**添加**，在终端中完成 Codex 官方登录，然后返回 Codex Duo。认证始终由 Codex 与 `codex-auth` 管理；Codex Duo 不会询问密码，也不会显示令牌。

点击非当前账号会立即开始切换。切换过程会关闭并重启 Codex，因此请先停止正在生成的回复。点击当前账号不会执行任何操作。

设置包括外观、语言、刷新间隔、登录时启动、账号和平台对应的代理选项。自动刷新可设为关闭或 1、2、5、10、15 分钟；关闭自动刷新后仍可使用**立即刷新**。

## 从源码构建

先克隆仓库：

```shell
git clone https://github.com/ZhuSipu/codex-duo.git
cd codex-duo
```

### macOS 开发

需要 macOS 14+ 和 Swift 5.10 命令行工具。

```shell
./Scripts/test.sh
app_path=$(./Scripts/build_app.sh)
open "$app_path"
```

如需安全替换本机已安装的开发版本：

```shell
./Scripts/install.sh
```

运行 `./Scripts/install.sh --help` 可查看 `--install-dir` 和 `--no-launch`。脚本会先检查工具和构建结果，在目标目录中暂存新版本；安装失败时会恢复旧版本。

### Windows 开发

Windows 版本必须在 Windows 电脑上开发，并安装 .NET 8 SDK。只有制作安装包时才需要 Inno Setup 6。

```powershell
dotnet test Windows/CodexDuo.Windows.sln -c Release
./Scripts/package_windows.ps1
```

发布文件输出到 `dist/`。可设置 `CODEX_DUO_SIGN_THUMBPRINT`，并按需设置 `CODEX_DUO_TIMESTAMP_URL` 进行 Authenticode 签名。普通 Windows `dotnet build` 成功后可同步到已有的当前用户安装；传入 `-p:SyncInstalledCodexDuo=false` 可关闭实时同步。

## 开发边界

两个平台的实现必须保持独立：

| 变更类型 | 权威文档或路径 | 开发环境 |
| --- | --- | --- |
| 共同行为与数据语义 | [`docs/feature-spec.md`](docs/feature-spec.md) | macOS 或 Windows |
| 共通视觉语言 | [`docs/design-language.md`](docs/design-language.md) | macOS 或 Windows；当前以 macOS 为基准 |
| macOS 实现 | `Sources/`、`Resources/`、macOS shell 脚本 | 仅 macOS |
| Windows 实现 | `Windows/`、Windows PowerShell 与安装器文件 | 仅 Windows |

修改代码前请阅读 [`docs/development-workflow.zh-CN.md`](docs/development-workflow.zh-CN.md)。macOS 开发任务不得修改 Windows 实现文件；Windows 开发任务不得修改 macOS 实现文件。修改共同约定时，应记录两个平台的影响，但不得顺手在另一平台实现未经验证的改动。

## 隐私与风险

Codex Duo 只读取 `~/.codex/accounts/registry.json`，不会打开受管理的 `*.auth.json` 快照。刷新、登录和账号切换均交由 `codex-auth` 执行。

默认情况下，`codex-auth list` 可能会把账号访问令牌发送到 OpenAI 端点以刷新用量。上游明确提示该方式依赖非公开行为，可能随时失效，并可能带来账号风险。使用前请阅读 [`codex-auth` 免责声明](https://github.com/Loongphy/codex-auth#disclaimer)。

## 故障排查

- **菜单或托盘显示 —：**确认 `codex-auth --help` 可运行，并且至少配置了一个账号。
- **macOS 中“添加”无法打开：**确认终端位于 `/System/Applications/Utilities`，然后重新打开设置。
- **用量数据陈旧：**查看时间标记，启用自动刷新或点击**立即刷新**。刷新失败时会保留最新的已验证数据。
- **切换打断工作：**重新打开 Codex 并继续任务；不要在回复生成过程中切换。
- **登录时启动失败：**将应用安装到平台常规位置，从该位置启动一次，然后重试此设置。
- **Codex 无法关闭：**先停止活动任务并手动关闭 Codex，再切换账号。

## 卸载

先关闭**登录时启动**并退出应用。

- macOS：将 `/Applications/Codex Duo.app` 移到废纸篓。
- Windows：在 Windows 设置中卸载 **Codex Duo**；便携版用户可删除解压目录。

账号数据属于 `codex-auth`，卸载 Codex Duo 不会删除它。仅在确认其他流程不再依赖时，才单独移除辅助工具。

## 许可证

MIT。参见 [LICENSE](LICENSE) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
