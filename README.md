# 拾贴 · ClipShelf

一个轻巧的 Mac 菜单栏剪贴板工具。原生 SwiftUI + AppKit，不需要账号、网络或 API Key。

Native macOS clipboard history in your menu bar. Search, favorite and reuse text or images. Local storage, no account, no network, no third-party dependencies.

**macOS 13+ · SwiftUI / AppKit · MIT License**

## 功能

- 文字、链接、代码和图片历史，自动去重。
- 按内容和来源应用搜索，收藏常用片段。
- `⌃⌥V` 全局呼出，方向键选择，回车复制。
- 可暂停记录，设置数量上限、保留时间和图片记录开关。
- 默认保留 200 条、30 天；收藏长期保留。

## 从源码安装

需要 macOS 13 或以上，以及 Xcode Command Line Tools。没有第三方依赖。

```sh
git clone https://github.com/Vles0123/ClipShelf.git
cd ClipShelf
bash build.sh
open build/拾贴.app
```

如果尚未安装编译工具，先执行 `xcode-select --install`，完成系统安装步骤后再构建。

构建完成后，可以把 `build/拾贴.app` 拖到“应用程序”文件夹。应用使用本地临时签名，未做 Developer ID 公证。

## 开始使用

双击 **拾贴.app**。运行后，顶部菜单栏会出现剪贴板图标，Dock 中不显示应用图标。

1. 照常使用 `⌘C` 复制文字、链接、代码或图片。
2. 按 `Control + Option + V`（`⌃⌥V`），或者点击菜单栏图标。
3. 搜索并点击一条历史，应用会将它放回剪贴板并返回之前的应用。
4. 按 `⌘V` 粘贴。

支持方向键选择、回车复制、`⌘F` 搜索、`Esc` 关闭。输入中文时，回车会优先确认正在组词的文字。

点击星标收藏；右键记录可查看完整内容、收藏或删除。右上角的“记录中”按钮可暂停记录，暂停期间的复制内容不会在恢复后补录。

设置中可以调整数量、保留时间、是否记录图片，以及清空未收藏记录。默认保留最近 **200 条、30 天**；收藏不受这两个限制。重复内容会合并并移到最前面。菜单栏图标的右键菜单也可暂停或退出。

## 本地数据与边界

- 数据位于 `~/Library/Application Support/ClipShelf/`，设置中可打开该文件夹。
- 历史文本以 JSON 保存，图片以 PNG 保存。目录和内容文件限制为当前用户访问；内容没有额外加密。
- 自动忽略剪贴板中标记为 concealed、transient、auto-generated 的内容，并跳过几个常见密码管理器作为前台应用时的复制。这不是通用密码识别：其他来源的普通文本仍会记录，可在复制不想保留的内容前暂停。
- 从应用启动后的下一次复制开始记录，无法恢复安装前的历史。
- 文字超过约 500 KB、图片数据超过约 16 MB 时跳过。复制文件时不保存文件本体；富文本会保存为纯文本。
- 应用通过每 0.6 秒检查一次剪贴板变化来记录，极短时间内连续多次复制可能只保留最后一次。
- 不申请辅助功能权限，不自动模拟粘贴。选中内容后使用 `⌘V`。
- 本地版本没有开机自启。需要时可将应用移到“应用程序”，再通过 macOS 的“登录项”添加。
- 构建脚本默认使用当前 Mac 的架构；Apple Silicon 已验证，Intel 尚未进行实际运行验证。

## 开发与验证

```sh
bash build.sh
build/拾贴.app/Contents/MacOS/ClipShelf --self-test
```

也可传入自定义输出应用路径：`bash build.sh /absolute/path/ClipShelf.app`。

通过 `CLIPSHELF_ARCH=arm64` 或 `CLIPSHELF_ARCH=x86_64` 指定构建架构。构建产物位于 `build/`，不会进入 Git。

`--self-test` 在临时文件夹和独立命名剪贴板中验证去重、持久化、收藏、保留策略、敏感内容过滤和图片读写，不访问系统剪贴板。`--demo --preview` 启动使用示例数据和独立剪贴板的界面预览，不写入真实历史。

文件结构：

- `Sources/HistoryStore.swift`：记录、搜索、存储与剪贴板读写。
- `Sources/PanelView.swift`：搜索、列表、设置与详情界面。
- `Sources/App.swift`：菜单栏、弹出面板、快捷键和应用生命周期。
- `Sources/SelfTests.swift`：独立功能测试。
- `Resources/`：应用信息和图标。

退出应用后，可删除应用文件卸载。若也需要清除本地历史，可删除上面的 ClipShelf 数据文件夹。

## 贡献

欢迎提交 Issue 或 Pull Request。修改后请运行上面的自测，并检查菜单栏面板和键盘操作。涉及图片的修改还应检查图片复制、缩略图与完整预览。

示例数据必须是虚构内容。请勿在 Issue、日志或截图中附上真实剪贴板记录、密码或个人资料。

## 许可证

[MIT](LICENSE) © 2026 Vles0123。
