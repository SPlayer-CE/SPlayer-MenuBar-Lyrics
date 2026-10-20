<p align="center">
  <img src="Support/AppIcon.png" width="128" height="128" alt="SPlayer 菜单栏歌词应用图标">
</p>

# SPlayer 菜单栏歌词

<p align="center">
  <a href="README.md"><b>简体中文</b></a> · <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/%E7%89%88%E6%9C%AC-1.1.0-2EA44F" alt="版本 1.1.0">
  <img src="https://img.shields.io/badge/%E7%95%8C%E9%9D%A2%E8%AF%AD%E8%A8%80-%E4%B8%AD%E6%96%87%20%7C%20English-4C9AFF" alt="界面语言：中文 / English">
  <img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="许可证：AGPL-3.0">
</p>

把 **SPlayer-Next** 当前播放的歌词放进 macOS 菜单栏：逐字高亮、随唱随滚，点一下就能控制播放。

这是一个独立的小应用，通过 SPlayer-Next 的**外部 API** 读取歌词与播放进度，**不修改客户端源码，也不依赖其内部实现**。SPlayer-Next 升级后通常无需跟着改动。

## 特性

- **菜单栏歌词**：状态栏图标旁显示当前歌词，逐字扫光随播放推进；超宽歌词跟随已唱进度横向滚动，唱到行尾恰好露出结尾，而不是用省略号截断。
- **真实逐字高亮**：支持 QRC / YRC / TTML 等自带逐字时间的歌词；LRC 整行歌词保持静态，不会凭空生成逐字效果。
- **就地操控**：歌词项右侧内置 18px 的「上一首 / 播放·暂停 / 下一首」按钮，无需打开菜单。
- **网易云收藏**：播放网易云歌曲时显示红心，可在菜单栏直接收藏 / 取消收藏（需安装附带的桥接插件）。
- **可调外观**：展示宽度 100–600 px、字号 11–16 pt、自动宽度、歌词对齐、音乐图标位置均可配置。
- **歌曲信息与 HUD**：点开菜单里的歌名可查看封面、专辑与播放进度；切歌时在菜单栏下方短暂显示 HUD。
- **歌词偏移**：歌词整体偏早或偏晚时，可按 0.1 s / 0.5 s 微调。
- **刘海与多屏适配**：按状态项所在屏幕的可用区域自动收窄，避免被刘海或其他状态项挤掉。
- **更新检查与诊断**：设置页可检查 GitHub Releases，并一键复制排障信息。
- **中英双语**：菜单、设置与按钮提示即时切换。
- **轻量**：无 Dock 图标、无后台守护进程，退出应用即完全停止；暂停或未连接时会停掉 30fps 重绘。

## 工作原理简述

SPlayer-Next 的插件运行在沙箱子进程中，权限只有 `network / control / ui / library / api`，其中 `ui` 仅能贡献歌曲右键菜单，**无法创建菜单栏项**。因此菜单栏歌词只能由外置应用实现，而外部 API 正是唯一无需改动客户端就能拿到歌词与进度的入口。

## 环境要求

| 项目 | 要求 |
| --- | --- |
| 系统 | macOS 13 Ventura 或更高 |
| 播放器 | [SPlayer-Next](https://splayer-next.imsyy.top)，并开启 **设置 → 外部 API** |
| 构建 | Xcode 命令行工具（`swiftc`、`swift build`） |
| 收藏功能（可选） | SPlayer-Next **v1.2.0-nightly.990**，登录网易云账号 |

> 建议同时在 SPlayer-Next 中开启 **WebSocket**：切歌、歌词与播放状态会即时推送。即使不开启，本应用也会以约 0.45 秒的间隔轮询，功能不受影响。
>
> 外部 API 默认端口为 `14558`，首次启动会自动读取 SPlayer-Next 配置文件中的端口。

## 快速开始

### 1. 构建并运行

```bash
./scripts/build.sh
open "build/SPlayer Menu Bar Lyrics.app"
```

开发时也可以直接从源码运行：

```bash
swift run SPlayerMenuBarLyrics
```

启动后不会出现 Dock 图标，菜单栏会多出「音符图标 + 当前歌词」。

### 2. 打包 DMG（可选）

```bash
./scripts/package.sh
# 输出 build/SPlayer-Menu-Bar-Lyrics-1.1.0.dmg
```

DMG 内含应用本体与 `Applications` 快捷方式，拖入即可安装。应用使用 ad-hoc 签名、未公证，首次打开若被 Gatekeeper 拦截，请在「系统设置 → 隐私与安全性」中放行，或右键 → 打开。

## 使用说明

### 菜单栏

- 点击歌词打开菜单：顶部显示连接状态与当前歌曲，点歌名可打开歌曲信息面板（封面、专辑、进度）。
- 「歌词偏移」子菜单可按 0.1 s / 0.5 s 微调当前歌词时间。
- 菜单栏空间不足（含刘海屏）时会自动收窄；仍可手动调小展示宽度。
- 菜单展开时可用快捷键：`⌘,` 打开设置，`⌘Q` 退出。

### 设置项

菜单栏 →「设置…」，或按 `⌘,`。

| 设置 | 默认值 | 说明 |
| --- | --- | --- |
| 菜单栏展示歌词 | 开启 | 总开关 |
| 展示宽度 | 287 px | 可调 100–600 px；自动宽度时作为上限 |
| 自动宽度 | 关闭 | 按当前歌词长度调整 |
| 字号 | 13 pt | 11–16 pt |
| 歌词对齐 | 靠左 | 靠左 / 居中 / 靠右，也可在菜单中切换 |
| 图标位置 | 歌词左侧 | 歌词左侧 / 歌词右侧 / 不显示 |
| 逐字高亮 | 开启 | 仅对带真实逐字时间的歌词生效 |
| 菜单栏常驻操控 | 开启 | 关闭后空闲时隐藏上一首 / 播放·暂停 / 下一首 |
| 切歌 HUD | 开启 | 切歌时显示歌名、歌手与封面 |
| 歌词偏移 | 0.0 s | ±3 s，步进 0.1 s |
| 开机自动启动 | 关闭 | 使用系统登录项 |
| 界面语言 | 跟随系统 | 跟随系统 / 简体中文 / English |
| 外部 API 端口 | 14558 | 可点「读取 SPlayer 配置」自动同步 |

### 收藏按钮

播放网易云歌曲时，歌词项最右侧会出现红心：空心表示未收藏，实心表示已收藏，点击即可切换。本地文件、流媒体等其他来源暂不支持收藏，红心会自动隐藏。

启用步骤：

1. 将 SPlayer-Next 升级到 **v1.2.0-nightly.990**（1.1.0 的插件 Host API 级别为 3，没有 `splayer.api.call`）。
2. 在 SPlayer-Next 中打开 **设置 → 插件管理 → 本地导入**，选择 [plugin/favorite-bridge.js](plugin/favorite-bridge.js)。设置面板中的「在 Finder 中显示插件文件」可直接定位到包内文件。
3. 为插件授予 `network` 与 `api` 权限并启用。
4. 菜单栏应用会在 `127.0.0.1:14561` 监听收藏请求，设置 → 收藏按钮 会显示「桥接插件已连接」。

插件只调用 SPlayer-Next 已有的网易云登录态以及 `song_like` / `likelist` 接口，不会修改客户端源码。

## 工作原理

```
SPlayer-Next ──HTTP /api/now-playing（轮询进度）──▶ SPlayerClient
             ──HTTP /api/lyrics（歌词时间轴）─────▶      │
             ──WS  /ws（track / lyric / status）──▶      │
                                                        │
                                       PositionAnchor（单调时钟插值）
                                                        ▼
                                       当前行索引 → NSStatusItem 自绘
```

- 外部 API 的 WebSocket 会过滤高频 `position` 事件，因此进度以轮询得到的锚点 + 本地单调时钟插值计算。
- 菜单栏以 30fps 自绘歌词：先画未播放色，再按逐字进度裁切出已播放色，形成连续扫光；滚动位置由已唱到的字符决定，与高亮同步推进。
- 播放控制通过外部 API 的 `POST /api/play | pause | next | prev` 完成。
- 收藏通过本地桥接：应用在 `14561` 端口提供极简 HTTP 接口，插件轮询请求并回报状态。

## 开发

### 模拟调试

没有启动播放器时，可用仓库自带的模拟服务：

```bash
python3 scripts/mock_server.py          # 默认 127.0.0.1:14558
swift run SPlayerMenuBarLyrics
```

模拟服务循环播放 8 行逐字歌词，并提供与 SPlayer-Next 形状一致的 `/api/now-playing`、`/api/lyrics`、`/api/status` 与 `/ws` 事件。

### 测试

```bash
swift test
```

覆盖歌词当前行选择、位置锚点插值 / 暂停 / 倍速 / 漂移校正、超宽歌词绘制边界、图标与自动宽度布局、封面字段解析、版本比较，以及中英文案完整性。

### 应用图标

`Support/AppIcon.icns` 由脚本生成（珊瑚色圆角方块 + 音符 + 带扫光的歌词条）：

```bash
swift scripts/GenerateIcon.swift Support/AppIcon.icns
```

### 持续集成

[.github/workflows/build.yml](.github/workflows/build.yml) 会在推送到 `main` / `master`、提交 PR、推送 `v*` 标签或手动触发时运行测试，并构建通用二进制（arm64 + x86_64）、打包 DMG 与 zip 产物。推送与 `Info.plist` 版本一致的标签（如 `v1.1.0`）会自动创建 GitHub Release 并附加产物；本地可用 `UNIVERSAL=1 ./scripts/package.sh` 复现同样的通用构建。

## 已知限制

- 屏幕过小或状态项过多时，菜单栏仍可能隐藏本应用；展示宽度会自动收窄，也可以手动调小。
- 逐字高亮依赖歌词源提供真实 word 时间；LRC 等整行歌词不会生成逐字效果。
- 本地歌曲没有歌词时显示歌曲标题；播放器未连接时仅显示图标。
- 外部 API 无鉴权且默认仅监听本机；请勿在不可信网络中开启「允许局域网访问」。
- 应用为 ad-hoc 签名、未公证，每次重新构建后系统可能再次询问权限。

## 目录结构

```
MenuBarLyrics/
├── .github/
│   ├── workflows/build.yml                 # GitHub Actions 构建与发布
│   ├── ISSUE_TEMPLATE/                     # Issue 模板
│   └── PULL_REQUEST_TEMPLATE.md
├── Package.swift
├── LICENSE                                 # GNU AGPL v3.0
├── CONTRIBUTING.md
├── SECURITY.md
├── Sources/SPlayerMenuBarLyrics/
│   ├── main.swift / AppDelegate.swift      # 菜单栏入口、状态栏与菜单
│   ├── MenuBarLyricView.swift              # 菜单栏歌词与播放控制的自绘视图
│   ├── SPlayerClient.swift                 # 轮询 + WebSocket + 位置锚点 + 控制
│   ├── Models.swift                        # 外部 API 数据模型
│   ├── Timeline.swift                      # 当前行选择与位置插值
│   ├── LyricHighlight.swift                # 字符级时间片与高亮探针
│   ├── Preferences.swift                   # UserDefaults 配置
│   ├── Localization.swift                  # 中英文案表
│   ├── SettingsView.swift                  # SwiftUI 设置面板
│   ├── TrackInfoPopover.swift              # 歌曲信息与封面面板
│   ├── TrackHUD.swift                      # 切歌 HUD
│   ├── UpdateChecker.swift                 # GitHub Releases 更新检查
│   ├── Diagnostics.swift                   # 诊断信息导出
│   ├── DebugLog.swift                      # 仅 Debug 构建启用的日志
│   ├── FavoriteBridge.swift                # 收藏桥接本地 HTTP 服务
│   └── SPlayerConfigReader.swift           # 读取 SPlayer-Next 端口配置
├── plugin/favorite-bridge.js               # SPlayer 收藏桥接插件
├── Support/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── AppIcon.png                         # README 展示用图标
├── scripts/
│   ├── build.sh                            # 构建 .app
│   ├── package.sh                          # 打包 DMG
│   ├── mock_server.py                      # 本地模拟服务
│   └── GenerateIcon.swift                  # 重新生成图标
└── Tests/SPlayerMenuBarLyricsTests/
```

## 参与贡献

请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。遇到安全问题请按 [SECURITY.md](SECURITY.md) 私下报告，不要直接开公开 Issue。

提交 Bug 时，可在设置 → 关于 里点「复制诊断信息」，把结果一并附上。

## 许可证

本项目采用 [GNU Affero General Public License v3.0](LICENSE) 许可。
