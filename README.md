# 悬浮提词器 · Floating Teleprompter

小型本机桌面提词器，支持 macOS Apple Silicon 和 Windows。中英文台词、大字号白字、连续向上滚动、始终置顶、透明度调整、可移动与缩放。

## 下载与打开

在仓库的 **Releases** 下载对应压缩包并解压：

- **Mac（M1/M2/M3/M4 等 ARM64）**：`Teleprompter-macOS-arm64.zip`，打开“悬浮提词器.app”，也可拖到“应用程序”。macOS 13 或更新版本。
- **Windows Intel / AMD 64 位**：`Teleprompter-win-x64.zip`，双击 `Teleprompter.exe`。
- **Windows ARM64**：`Teleprompter-win-arm64.zip`，双击 `Teleprompter.exe`。

Windows 版本包含运行所需的 .NET，无需另装 Python 或 .NET。使用支持 .NET 10 的 Windows 10/11；建议已受支持并更新的 Windows 11。应用未购买商业代码签名证书，系统可能提示开发者未验证。

## 操作

1. 在正文粘贴或编辑中文、英文台词。Mac 用 ⌘A/⌘V，Windows 用 Ctrl+A/Ctrl+V。
2. 用“开头留白”滑杆调整第一行之前的空白高度。点击“开始”后，空白和正文一起向上滚动，没有固定倒计时。调整留白会暂停并回到开头。
3. 默认约 **140 英文词/分钟**，可在 60–240 之间调速；中文默认约 300 字/分钟。速度按字数和实际排版估算，不是语音跟随。
4. “暂停”停在当前位置，“开始”继续，“重置”回到开头。**最后一行持续向上直到完全离开阅读区域，才停止。**
5. Windows 点击“编辑台词”回到编辑界面；Mac 暂停后可直接编辑。
6. 默认置顶，可取消；透明度可调。拖动标题栏移动，拖动边缘缩放。

置顶适用于普通桌面窗口；系统安全界面或独占全屏应用可能遮挡提词器。本应用仅显示台词，不修改摄像头画面或校正眼神。

## 本机数据

台词保存在自己的电脑，不会上传 GitHub 或发送到网络。仓库只包含通用示例台词。

- Mac：应用的 UserDefaults（`local.zhaorong.teleprompter`）。
- Windows：`%LOCALAPPDATA%\FloatingTeleprompter\settings.json`，同时保存速度、留白和透明度。

## 从源码构建

Mac 需要 Xcode Command Line Tools：

```sh
bash macos/build.sh
```

Windows 需要 .NET 10 SDK：

```powershell
dotnet publish windows/Teleprompter.csproj -c Release -r win-x64 --self-contained true -o dist
```

ARM64 将 `win-x64` 改为 `win-arm64`。Windows CI 构建两个版本，并在 x64 Windows 上运行应用内冒烟检查，覆盖开始、暂停、重置、留白、文字滚动到完全消失和混合语言速度。该检查不替代真人摄像头使用体验测试。
