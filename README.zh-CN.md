# AgentBar

[English](README.md)

AgentBar 是一个 macOS 菜单栏应用，用来查看本地 AI 编程助手的使用量。它会扫描本地使用记录，估算 token 和费用，并把配额进度直接显示在菜单栏里。

![AgentBar 主界面](docs/assets/agentbar-dashboard.png)

## 主要功能

- 在菜单栏显示 5 小时和 7 天滚动窗口的配额状态。
- 汇总今日、近 7 天和全部使用量。
- 按来源展示使用量，例如 Codex、Claude Code。
- 基于模型价格估算费用，并支持配置预算。
- 本地优先：扫描、归一化和统计都在你的 Mac 上完成。

![AgentBar 菜单栏](docs/assets/agentbar-menu-bar.png)

## 安装

### 从 GitHub Release 下载

1. 打开项目的 **Releases** 页面。
2. 下载最新版本里的 `AgentBar-macos.zip`。
3. 解压后把 `AgentBar.app` 移到 `/Applications`。
4. 启动应用。如果 macOS 首次运行时拦截，请到 **系统设置 > 隐私与安全性** 中允许打开。

仓库里已经包含 GitHub Actions 配置。推送版本 tag 后，会自动构建应用并把 zip 上传到 GitHub Release。

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 通过 Homebrew 安装

发布 Release 后，可以通过 Homebrew tap 分发：

```bash
brew tap your-org/agentbar
brew install --cask agentbar
```

### 从源码构建

环境要求：

- macOS 14 或更新版本
- Xcode Command Line Tools
- Swift 5.9 或更新版本

```bash
git clone https://github.com/your-org/agentbar.git
cd agentbar
./build.sh
open .build/AgentBar.app
```

本地开发：

```bash
swift test
./debug.sh
```

## 设置

AgentBar 支持配置菜单栏显示内容、刷新频率、token 与费用预算，也可以手动扫描或重新计算本地使用数据。

![AgentBar 设置](docs/assets/agentbar-settings.png)

## 基础原理

AgentBar 会读取支持的编程助手在本地生成的使用记录，从中解析 provider、model、token 等信息，然后把归一化后的记录写入本地 SQLite 数据库。应用会基于这些记录计算滚动窗口和汇总区间，再结合模型价格表估算费用，最后通过轻量的 SwiftUI 菜单栏界面展示。

配额信息和本地使用量是分开的。可用时，AgentBar 会刷新配额状态并缓存在本地，这样菜单栏在两次刷新之间也能保持可用。

## 仓库结构

```text
Sources/AgentBar/          SwiftUI 应用与菜单栏界面
Sources/AgentBarCore/      扫描、解析、存储、价格、聚合逻辑
Tests/AgentBarCoreTests/   核心逻辑测试
Scripts/build_app.sh       release app bundle 构建脚本
.github/workflows/         CI 与 release 打包配置
```

## 隐私

AgentBar 以本地扫描和本地存储为基础，不需要服务器来计算本地使用量。分享截图时请注意，账号、使用量和配额重置时间可能会出现在界面中。

## 参与贡献

欢迎提交 issue 和 pull request。提交 PR 前建议运行：

```bash
swift test
./build.sh
```

## License

开源发布前，请补充你希望使用的开源许可证。
