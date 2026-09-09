# 平台开发流程

## 不可跨越的边界

Codex Duo 包含两个独立的原生实现，开发与验证必须在目标操作系统上完成。

- **macOS 实现变更**可以修改 `Sources/`、`Resources/`、`Package.swift`、macOS shell 脚本和 macOS 专用 CI；不得修改 `Windows/`、`Scripts/*.ps1` 或 Windows 专用 CI 步骤。
- **Windows 实现变更**可以修改 `Windows/`、`global.json`、Windows PowerShell/安装器脚本和 Windows 专用 CI；不得修改 `Sources/`、`Resources/`、`Package.swift` 或 macOS 专用脚本/CI。
- **共同约定变更**可以修改 README、`docs/feature-spec.md`、`docs/design-language.md`、共用测试数据和仓库级规则。它需要说明对两个产品的影响，但不得夹带未经另一系统验证的实现改动。

同一需求同时包含共同约定和平台实现时，提交应可分离：先提交共同约定，再提交目标平台实现。没有在对应操作系统上实际运行原生界面时，不能仅凭 CI 宣称两个平台已经对齐。

## 权威来源

- 共通产品行为和数据含义：`docs/feature-spec.md`。
- 共通视觉语言：`docs/design-language.md`。
- macOS 行为与视觉：经过测试的 macOS 实现。
- Windows 行为与视觉：经过测试的 Windows 实现。
- 当前跨平台视觉对齐基准：macOS。

以 macOS 为基准不代表 Windows 必须逐像素复制。菜单栏与系统托盘、窗口边框、系统材质、图标、字体、键盘行为、启动机制、进程控制和无障碍支持都应保持平台原生。

## macOS 流程（仅在 macOS 执行）

1. 在干净工作区拉取 `main`，创建 `codex/` 分支。
2. 编辑前先将任务归类为“仅 macOS”或“共通约定 + macOS”。
3. 视觉改动先对照 `docs/design-language.md`；如果共通意图发生变化，先更新该文档。
4. 运行 `./Scripts/test.sh`。
5. 使用 `./Scripts/build_app.sh` 构建并启动返回的 App，在明暗模式和相关菜单/设置状态下检查。
6. 仅在验证安装位置、登录项或启动行为时使用 `./Scripts/install.sh`。
7. 检查 `git diff --name-only`，交付前移除任何误改的 Windows 实现文件。

macOS 开发者可以记录 Windows 后续工作，但将具体实现留给 Windows 开发电脑。

## Windows 流程（仅在 Windows 执行）

1. 在干净工作区拉取 `main`，创建 `codex/` 分支。
2. 编辑前先将任务归类为“仅 Windows”或“共通约定 + Windows”。
3. 阅读共通设计语言并查看 macOS 基准行为或截图，用 Windows 原生能力转译层级和材质特征。
4. 运行 `dotnet test Windows/CodexDuo.Windows.sln -c Release`。
5. 在 Windows 上实际检查托盘、设置、开机启动、账号切换、DPI 缩放、键盘操作和明暗模式。
6. 仅在验证打包或发布时运行 `./Scripts/package_windows.ps1`。
7. 检查 `git diff --name-only`，交付前移除任何误改的 macOS 实现文件。

只有完成 Windows 原生验证后，Windows 开发者才能更新实现状态表。

## 共同约定检查表

- 是否改变了用户可见行为、数据语义、默认值、隐私或错误处理？更新 `feature-spec.md`。
- 是否改变了材质、层级、间距关系、视觉状态或交互语气？更新 `design-language.md`。
- 两个平台能否用各自原生能力实现？不能时，明确标注平台例外。
- 是否如实标注实现状态和限制，没有宣称未经验证的对齐？
- 英文和简体中文 README 的安装说明是否仍然等价？

## 发布纪律

macOS 和 Windows 发布文件独立构建；只有两个平台负责人都验证通过后才共用同一版本标签。可以推迟其中一个平台的发布，但不得为了强行合并发布而在错误的操作系统上修改另一平台实现。校验值、签名/公证状态、支持的架构和安全提示都必须按发布文件分别说明。
