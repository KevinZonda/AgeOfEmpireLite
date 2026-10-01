# 构建与运行

## macOS 为什么需要自定义 Godot

本项目在 macOS 上使用打过补丁的 Godot 运行时，修复 Magnet 开启时的拖框起步延迟，以及 headless 任务空转、反复查询 Launch Services 导致的高 CPU 占用。

修复位于 Godot 的 macOS 主循环：系统或辅助功能（AX）事件提前唤醒 RunLoop 时，如果下一帧的等待计时器仍在运行，就继续处理事件，等到帧期限再执行 `Main::iteration()`，避免额外渲染及 VSync 等待拖慢输入事件处理。

因此构建流程是：**给 Godot 源码应用补丁 → 编译 Godot 运行时 → 使用该运行时加载游戏项目**。修改游戏 GDScript 或场景后，通常只需重新运行游戏，不需要重新编译引擎。

有窗口的输入延迟补丁需要配合 `project.godot` 的 macOS 帧率上限使用：

```ini
[application]
run/max_fps.macos=120
```

请保留这项配置。当前验证的是补丁与限帧共同生效的方案，单独设置 120 FPS 未能解决问题。测量结果、根因分析和独立诊断工具见 [输入延迟 POC](poc/input-poc/README.md)。

异步窗口限帧还会扣除当前帧已经消耗的时间，避免慢帧之后仍额外等待完整的 8.33 ms。复现与数据见 [帧预算 PoC](docs/battle-overhead/frame-budget.md)。

独立的 headless 补丁让 `OS_MacOS_Headless` 使用阻塞式帧等待，跳过 Magnet 查询及 AppKit 定时器。它同时适用于 `--headless` 和 `--display-driver headless`，保留 60/120 FPS 上限及未设上限时的默认休眠，不依赖上述 120 FPS 配置。修复前后的空项目对照见 [headless 等待 PoC](docs/headless-wait-poc/README.md)。

## 环境与固定版本

- macOS，安装 Xcode Command Line Tools（提供编译器、SDK、Git 和 Make）；未安装时执行 `xcode-select --install`。
- Python 3，支持 `venv` 和 `pip`。
- 首次构建需要网络以获取 Godot 源码及构建依赖。
- 可选：已安装的 SCons。未找到时，脚本会在源码目录创建 `.build-venv` 并安装 SCons 4.11.1。
- Godot 4.7.2 编辑器，用于首次导入项目、注册全局脚本类及日常编辑。

| 项目 | 位置／版本 |
| --- | --- |
| Godot 源码版本 | `4.7.2-stable` |
| 固定提交 | `ed1daf0bf001b61586d9930840f2f1394092c079` |
| 源码目录 | `docs/godot/` |
| 引擎补丁 | [godot-4.7.2-macos-frame-wait.patch](patches/godot-4.7.2-macos-frame-wait.patch) |
| 帧预算补丁 | [godot-4.7.2-macos-frame-budget.patch](patches/godot-4.7.2-macos-frame-budget.patch) |
| headless 补丁 | [godot-4.7.2-macos-headless-wait.patch](patches/godot-4.7.2-macos-headless-wait.patch) |
| 构建脚本 | [build_godot_macos.sh](tools/build_godot_macos.sh) |
| 构建目标 | `template_debug`，当前机器架构（`uname -m`） |
| 输出文件 | `docs/godot/bin/godot.macos.template_debug.<架构>` |

当前已验证的是 Apple Silicon 的 `arm64` 构建；脚本按本机架构构建，不会自动生成通用二进制。源码和构建产物不随项目提交，需要在本地生成。脚本不会替换系统中已安装的 Godot。

## 首次构建与运行

以下命令均在项目根目录执行。

1. 使用 Godot 编辑器打开 `project.godot`，完成首次导入。也可以通过编辑器可执行文件执行：

   ```sh
   /你的/Godot/路径 --headless --editor --path . --quit
   ```

   此步骤需要编辑器；下面构建的 `template_debug` 运行时不包含编辑器功能。

2. 构建修复版引擎：

   ```sh
   make build-macos
   ```

   脚本会获取固定版本的源码、校验提交、应用两份补丁并编译。已应用补丁时可重复执行；源码版本不符时会停止，避免将补丁应用到未经验证的版本。

3. 启动游戏：

   ```sh
   make run
   ```

macOS 上的 `make run` 默认使用上述本地构建产物。当前构建是面向本项目的精简 2D／GDScript 运行时，使用 OpenGL Compatibility，不包含编辑器、C# 或 3D 支持。

构建默认使用 6 个并行任务，可调整任务数或指定 SCons：

```sh
BUILD_JOBS=4 make build-macos
SCONS_BIN=/你的/scons/路径 make build-macos
```

## 日常开发与验证

修改游戏脚本或场景后直接执行 `make run`；修改引擎源码、补丁或构建选项后重新执行 `make build-macos`。

可以继续使用官方 Godot 编辑器编辑项目。不过，从未打补丁的编辑器直接运行游戏仍使用原版引擎，不包含此次输入延迟修复。需要验证该修复时，使用 `make run`。

使用本地修复版引擎运行基础测试：

```sh
make run RUN_ARGS='--headless --script res://tests/smoke.gd'
make run RUN_ARGS='--headless --script res://tests/selection.gd'
```

成功时分别输出 `SMOKE_OK` 和 `SELECTION_OK`。无窗口测试验证游戏逻辑；实际输入延迟仍需在有窗口、Magnet 开启的情况下，用鼠标或物理按压触控板验证拖框响应。

验证 headless 帧等待（各子进程带超时，使用临时空项目）：

```sh
python3 tools/headless_wait_poc/run.py --candidate "docs/godot/bin/godot.macos.template_debug.$(uname -m)"
```

此补丁不会让 headless 开始渲染。需要 `RenderingServer.frame_post_draw` 或 GPU 截图的任务应使用有窗口的渲染模式，并由外部进程设置超时。`/Applications/Godot_mono.app` 保持官方原版，直接从它启动 headless 任务仍可能触发旧问题。

其他平台默认使用 PATH 中的 `godot`。也可以显式指定引擎：

```sh
make run GODOT=/你的/Godot/路径
```

指定官方原版引擎运行 macOS 项目时，不会包含本仓库的引擎补丁。

## macOS 发布与导出

**发布包中的 Godot 运行时也必须包含这三份补丁**，并保留项目的 macOS 120 FPS 上限。仅在开发机器上使用修复版运行时，不会让官方导出模板自动获得修复。

目前 `make build-macos` 只构建用于本地运行和测试的 `template_debug` 二进制，仓库尚未提供完整的 macOS 发布包构建流程。正式发布还需要：

1. 基于同一固定源码与补丁构建 `template_release`；如果需要调试导出，也要提供相应的修复版 `template_debug`。
2. 为目标架构准备自定义 macOS 导出模板，并在 Godot 的 macOS 导出预设中配置使用。需要同时支持 Intel 和 Apple Silicon 时，需准备对应架构的产物及模板封装。
3. 导出游戏，按分发方式完成应用打包、签名和公证。
4. 使用实际导出的应用，在 Magnet 开启时复测拖框响应。

当前 `make build-macos` 和 `make run` 完成的是本地开发流程，不会生成可分发的 `.app`／`.dmg`，也不会执行签名或公证。

## Web 构建、导出与预览

Web 默认使用官方 Godot 4.7.2 导出模板，不需要安装 Emscripten 或编译引擎。macOS 主循环补丁只用于 macOS 运行时，Web 不依赖这些补丁。

首次本地导出前，使用普通版 Godot 4.7.2 编辑器打开项目，在「编辑器 → 管理导出模板」中下载并安装对应版本的官方模板。macOS 导出脚本准备的编辑器位于 `.godot/tools/web-export/Godot.app`；模板需与脚本使用的编辑器版本一致。GitHub Actions 自动完成编辑器与模板安装。

```sh
make run-web
```

`make run-web` 每次重新导出当前游戏，再启动预览服务器。然后访问 <http://127.0.0.1:8060>。可以通过 `make run-web WEB_PORT=8080` 更换端口。按 Ctrl+C 停止预览服务器。只需重新启动已有导出产物的服务器时，执行 `make serve-web`；只导出而不启动服务器时，执行 `make export-web`。

`make export-web` 使用已安装的官方 Web release 模板，导入并导出游戏，网页产物位于 `build/web/`。也可以直接执行 `tools/export_web.sh`。`export_presets.cfg` 的 `custom_template/release` 留空以使用官方模板。

如需精简模板，仍可安装 Emscripten 4.0.0 或更新版本，再执行 `make build-web` 从固定 Godot 源码编译。生成的模板为 `docs/godot/bin/godot.web.template_release.wasm32.zip`，使用前需将 Web 预设的 `custom_template/release` 指向该文件。可用 `BUILD_JOBS=4 make build-web` 调整编译并行数。日常导出和 CI 不执行此流程。

导出必须使用 **普通版 Godot 4.7.2 编辑器**。本机已安装的 Mono 编辑器会拒绝 Web 导出，即使游戏只使用 GDScript。macOS 和 Linux x86_64 的导出脚本会自动下载官方普通版编辑器、验证固定的 SHA-256，并解压到 `.godot/tools/web-export/`。它不会替换 `/Applications/Godot_mono.app`。其他平台需设置 `GODOT_EDITOR=/普通版/Godot/路径`，macOS 和 Linux 也可用此变量指定已有编辑器。

Web 预设启用多线程，以支持当前的后台寻路任务。预览服务器提供以下响应头：

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

正式部署时，上传整个 `build/web/` 目录，通过 HTTPS 提供这些响应头，并将 `.wasm` 的 MIME 类型设为 `application/wasm`。预设也启用了 Godot 自带的 PWA 与 `ensure_cross_origin_isolation_headers`：无法配置响应头的静态站点可以由 service worker 补齐隔离响应头，保留后台寻路线程。首次访问可能自动刷新以激活 service worker；浏览器需允许 service worker，建议用 Chrome 或 Firefox。不能通过双击 `index.html` 来运行。该目录包含游戏数据包，不包含开发文档与测试资源。

浏览器决定画布尺寸，游戏的分辨率选项显示「跟随浏览器」；全屏仍通过玩家点击设置按钮触发，刷新网页时不会自动恢复全屏。浏览器对局隐藏系统鼠标并使用游戏光标，不锁定鼠标到画布内。其他显示与操作偏好继续存入 `user://`。此流程生成 Web release 版本。

2026-09-30 已完成源码模板编译与 release 导出，并在 Chrome 验证开始菜单、设置保存及刷新、1v1 对局、资源增长、图标与中文字体、2D／2.5D 切换和 1280×720 画布尺寸变化。浏览器确认 `crossOriginIsolated=true`，引擎报告多线程构建，最终运行日志无错误或警告。本机 `smoke.gd`、`settings_store.gd`、`display_settings.gd` 与 `player_input_actions_regression.gd` 均通过。此记录覆盖基本运行与平台适配，不代表大规模战斗性能基准。

## GitHub Actions 与 Pages

[Web workflow](.github/workflows/web-pages.yml) 从 Actions 页面手动运行时执行（选择 `main`）：

1. 在 Ubuntu 24.04 上通过 [chickensoft-games/setup-godot](https://github.com/chickensoft-games/setup-godot/tree/v2.4.1) 安装普通版 Godot 4.7.2 编辑器和官方导出模板。Action 固定到 v2.4.1 的提交，启用安装缓存，并在安装完成后立即保存缓存；不安装 Emscripten、不编译 ICU 或引擎源码。
2. 使用 Action 安装的编辑器导入项目，再导出完整的 `build/web/`（包括多线程、PWA 文件与 `.nojekyll`）。首次需下载完整的官方跨平台模板包，缓存命中后无需重复下载；Web 模板体积不再采用之前的精简构建。
3. 将产物提交到 `pages` 分支根目录；首次创建独立分支，后续保留提交历史。该分支由 workflow 管理，只用于生成的站点文件。
4. 使用官方 Pages artifact 和 deploy actions 将同一份产物发布到 GitHub Pages。

仓库需在 **Settings → Pages → Source** 选择 **GitHub Actions**，然后将 workflow 提交到 `main`。手动运行也应选择 `main`。默认站点地址为 <https://kevinzonda.github.io/AgeOfEmpireLite/>。无需额外 PAT；workflow 使用仓库自带的 `GITHUB_TOKEN`，构建任务有 `contents: write` 权限以提交产物，部署任务有 `pages: write` 和 `id-token: write` 权限。仓库／组织策略需允许这些权限；`github-pages` 环境也需允许从 `main` 部署。

`pages` 分支用于保存编译产物，实际站点通过 Actions 部署。不要把 Source 设为「Deploy from a branch」并仅依赖机器人推送：[GitHub 官方说明](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)指出，通过 `GITHUB_TOKEN` 推送的提交不会触发分支式 Pages 构建。多线程静态托管使用的是 [Godot 官方 PWA 隔离机制](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#exporting-as-a-progressive-web-app-pwa)。

2026-10-01 本地验证：workflow 通过 actionlint；Web release 实际导出成功；临时 Git 远端验证了首次创建 `pages`、增量提交、移除旧产物、保留历史和产物未变化时跳过提交。在不提供 COOP／COEP 响应头的普通 HTTP 服务器子目录下，Chrome 激活导出的 service worker 后达到 `crossOriginIsolated=true`，游戏启动且未捕获到运行错误。尚未在 GitHub 执行首次 Ubuntu 构建或实际 Pages 部署。

2026-10-01 切换官方模板后验证：actionlint 和 shell 语法检查通过，`make export-web` 使用官方包中的多线程 `web_release.zip` 成功导出。普通静态服务器下，Chrome 的 service worker 生效，`crossOriginIsolated=true`，加载界面消失且未捕获到运行错误。官方 WASM 约 37 MiB，之前的精简模板约 26 MiB；游戏数据包约 9.7 MiB。此验证未运行更新后的远端 workflow。
