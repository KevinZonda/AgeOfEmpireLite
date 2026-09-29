# macOS headless 帧等待 PoC

2026-09-29，本机 macOS 14.8.7 / arm64，Godot 4.7.2
(`ed1daf0bf001b61586d9930840f2f1394092c079`)，Magnet 全程运行。

## 结论与实测

Godot 的 macOS headless 主循环没有等待 `OS_MacOS::add_frame_delay()`
为 Magnet 兼容而创建的 CFRunLoop 定时器，导致限帧失效，并逐帧查询运行中的
Magnet，拖高 `launchservicesd` CPU。没有游戏逻辑的空项目即可复现。

修复只为 `OS_MacOS_Headless` 覆盖 `add_frame_delay()`，调用原有
`OS_Unix::add_frame_delay()` 阻塞式等待。这样既跳过 Magnet 查询和 AppKit
定时器，也保留已有帧率上限、低功耗／无窗口休眠逻辑。

同一台机器、同一份脚本、每次运行 3 秒的对照结果：

| 配置 | 修复前循环/秒 | 修复后循环/秒 | 修复前 launchservicesd CPU | 修复后 CPU |
| --- | ---: | ---: | ---: | ---: |
| `--headless`，120 FPS | 15,741 | 120.9 | 55.94% | 0.00% |
| `--headless`，60 FPS | 17,126 | 60.9 | 63.61% | 0.31% |
| `--headless`，默认上限 0 | 17,668 | 145.8 | 64.05% | 0.32% |
| `--display-driver headless`，120 FPS | 16,160 | 120.0 | 58.93% | 0.32% |

原始记录见 [results.json](results.json)。对照基线是项目原有的自定义 runtime，
已包含之前的 GUI 输入补丁；候选只增加 headless 等待补丁。因此这里比较的是
同一精简构建的修复前后，而不是 Mono 编辑器与精简 runtime 的差异。

这里统计的是主循环迭代，不是渲染帧。短测包含首帧及启动瞬态，计数可能比上限略高。
上限为 0 时，headless 仍使用默认 6900 微秒休眠，约为 145 次/秒。
CPU 由 `launchservicesd` 的累计 CPU 时间差除以进程运行墙钟时间得到，包含启动／退出，
也可能包含其他程序的请求；限帧断言才是自动回归的通过条件。基线限帧失败是预期结果。

## 复现和回归

从项目根目录运行；每次创建独立临时项目，不加载游戏资源。脚本按真实时间退出，
Python 另外设置超时，超时会终止并回收子进程，防止 PoC 本身留下后台任务。

```sh
make build-macos
python3 tools/headless_wait_poc/run.py \
  --candidate "docs/godot/bin/godot.macos.template_debug.$(uname -m)"
```

默认结果写入 `.godot/headless-wait-poc/results.json`。四个候选测试都需正常退出、
无脚本错误、保持 headless 且无绘制信号，并在合理限帧范围内，命令才返回 0。

需要重新比较官方安装版与本地修复版时：

```sh
python3 tools/headless_wait_poc/run.py \
  --baseline /Applications/Godot_mono.app/Contents/MacOS/Godot \
  --candidate "docs/godot/bin/godot.macos.template_debug.$(uname -m)"
```

本机本次同构建的基线二进制保存在 `captures/godot-before.arm64`，不提交。
可将上面 `--baseline` 指向它来重做表格中的对照。Magnet 不运行时会提示原始触发条件缺失。

## 正式补丁与范围

- [headless 补丁](../../patches/godot-4.7.2-macos-headless-wait.patch)独立于已有的 GUI
  帧等待补丁，`tools/build_godot_macos.sh` 会自动、可重复地应用两者。
- 补丁已验证可单独应用于固定上游版本，也可与正式 GUI 补丁或旧 GUI PoC 补丁并存。
- 本地 runtime 已重新编译；`make run` 默认使用它。官方 `/Applications/Godot_mono.app`
  没有被替换，直接运行该编辑器可执行文件仍可能触发原问题。
- 不修改 `OS_MacOS_NSApp` 或嵌入式编辑器主循环；此前 GUI 输入修复继续保留。

另外通过了游戏 `smoke`、`selection` 的 headless 回归和实际窗口模式的 `smoke`，
两次正式构建均成功。记录见 [verification.json](verification.json)。窗口 smoke 验证
启动、渲染与游戏断言；本次没有重新测量物理拖框输入延迟。

此补丁解决 CPU 空转，不负责让截图脚本在 headless 模式渲染。PoC 的
`frame_post_draw` 计数始终为 0。需要该信号或 GPU 图像的截图任务应使用正常渲染模式，
并由外部进程设置超时。原来的 `/tmp/aoe_infantry_capture.gd`、
`/tmp/aoe_naval_preview.gd` 已不存在，不能据此断定它们具体在哪个 await 处挂起。
