# macOS 拖框起步延迟 POC

环境：Godot 4.7.2 stable mono (`ed1daf0bf001b61586d9930840f2f1394092c079`)，Apple M2，macOS 14.8.7，Magnet 3.0.7。2026-09-28 本机实测。

## 已确认的事实

1. 独立画框 POC 和完整游戏都记录到了 HID 物理按下与系统会话按下的时间差。完整游戏大部分约 250–280ms，期间帧仍在运行。
2. 延迟结束后 AppKit 收到事件，Godot 通常在数毫秒内处理；完整游戏再用十几毫秒激活选框。
3. 某次物理按住期间，AppKit 原始事件本身出现 `down -> up -> down`，并且这三条事件读取的会话按钮状态都为按下。不是 GDScript 凭空生成的序列。
4. 用户确认退出 Magnet 后完整游戏恢复正常。对应日志中 HID 到系统会话的延迟降至 0–2.5ms，HID 到 Godot 约 0–18ms（采样误差约 2.5ms）。
5. 恢复 Magnet，只设置 `Engine.max_fps = 120` 无效：仍为 234–284ms，用户确认仍卡顿。该方案未作为独立修复采用；最终需与引擎补丁配合。
6. 用户主观感受独立 POC 正常；日志仍显示输入到达前的延迟。不能以主观顺滑或 Godot 收到按下后的耗时，证明物理输入没有延迟。

## 为什么旧 F8 POC 无效

`DisplayServer.mouse_get_button_state()` 在 macOS 调用 `[NSEvent pressedMouseButtons]`，位置使用 `[NSEvent mouseLocation]`。这不是原始 HID 输入。

`HIDDEN` 与 `CONFINED_HIDDEN` 都在延迟之后读取同一系统会话状态。改轮询、选框绘制方式和像素阈值无法恢复尚未送达的按下与位移。旧计时器从 Godot 收到按下开始，也漏掉了这段时间；旧“事件断流”还包含用户停止移动的时间，不能直接等同于输入延迟。

## 同一引擎 A/B 结果与修复

Magnet 全程开启，在同一测试二进制、同一个游戏窗口里多次切换原逻辑 / 补丁逻辑：

| 模式 | 匹配的物理按下次数 | 最小 | 中位 | 最大 |
| --- | ---: | ---: | ---: | ---: |
| 原逻辑 | 11 | 182.8ms | 218.8ms | 241.8ms |
| 补丁 | 20 | 1.1ms | 3.7ms | 12.0ms |

见 `engine-ab-summary.txt` 和 `engine-ab-metrics.json`。用户确认 Patched 更好、似乎已解决；日志支持最初约 100–200ms 起步停顿已消除。此结果衡量物理按下到 Godot 事件送达，不等于端到端显示器延迟。

## 引擎根因

源代码位于 `docs/godot`，精确对应已安装引擎的提交。

`OS_MacOS::add_frame_delay` 已针对 Magnet 使用 CFRunLoop 计时器，但 `OS_MacOS_NSApp::start_main` 的 `kCFRunLoopBeforeWaiting` 回调在每次系统事件唤醒后无条件调用 `Main::iteration()`，即使上一个帧计时器仍然有效。

局部补丁：系统事件继续处理；`wait_timer != nil` 时不再执行新一帧、不重设计时器。计时器到期后再推进游戏。连续系统请求因此可以在帧间等待时完成，不必每个请求都夹着整帧更新和 VSync 等待。

正式补丁在 `patches/godot-4.7.2-macos-frame-wait.patch`，没有诊断切换开关。项目设置 `application/run/max_fps.macos=120`，使已有的 Magnet 兼容计时器路径生效。两者必须配合。`make build-macos` 构建，`make run` 默认使用修复版；未修改 `/Applications/Godot_mono.app` 或 Magnet 的设置，Magnet 已恢复运行。

正式运行时是本项目所需的 macOS 2D / GDScript runtime，含 Noise、字体、SVG 和 2D physics；不包含编辑器、C# 和 3D。最终 runtime 已通过 `tests/smoke.gd` 与 `tests/selection.gd`。旧 F8 / 屏幕探针仅在 `--selection-input-poc` 参数下启用。

`tools/input_poc/run_loop_poc.m` 用 CFRunLoop + 顺序请求线程模拟此调度：30 个请求，原逻辑约 300ms / 32 帧，带计时器检查约 17ms / 3 帧。模拟渲染每帧等待 8ms。它验证调度差异，不代替真实 Magnet 或触摸板测试。

## 复现与日志

```sh
# 空场景：1/2/3 切换光标模式，V 切换 VSync，Esc 退出。
tools/input_poc/run.sh

# 原游戏，只增加记录。
tools/input_poc/run.sh --game

# 已验证无效的对照：仅加帧率上限。
tools/input_poc/run.sh --game --responsive-wait

python3 tools/input_poc/summarize.py /tmp/aoe-input-poc-日期时间
```

`GODOT_BIN` 可指定测试引擎；`TRACE_DIR` 可指定日志目录。诊断 dylib 只在该次运行加载，不安装、不修改系统输入；它每约 2ms 读取 HID/会话按钮和 Quartz 位置，并用 AppKit local monitor 原样返回事件。所有记录以同一系统时间基准关联。自动生成到窗口的拖动不改变 HID 状态，不能当作物理手势测试。

`game_trace.gd` 继承游戏脚本，记录开始、结束、取消和阶段变化；不改游戏状态机。`trace.gd` 记录 Godot 事件、帧和渲染提交。`frame_post_draw` 代表引擎完成绘制提交，不保证该时刻画面已经显示在屏幕上。

各轮摘要见本目录 `*-summary.txt`。完整本机原始日志留在 `captures/`（不提交，避免大文件进入仓库）；外部窗口点击也会被 HID 采样，摘要中的 `--` 不能被当作丢失的游戏点击。最后不完整的文件行会被分析器忽略。

## 上游资料

- [Godot #109264：相同症状与 Magnet 对照](https://github.com/godotengine/godot/issues/109264#issuecomment-3148799440)
- [Godot #116524：已有的 Magnet 帧等待兼容代码](https://github.com/godotengine/godot/pull/116524)
- [Godot #123162：按下事件本身延迟的测量盲点](https://github.com/godotengine/godot/issues/123162)

上游资料用于提出假设；本机开关 Magnet 的结果才是本次定位的直接证据。

### 构建引擎 POC

```sh
# 与本机安装版本一致的源码（本次已经克隆）。
git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git docs/godot
touch docs/godot/.gdignore
# 下方 POC 构建脚本会自动在正式补丁与诊断补丁之间转换。

# 安装 SCons 到独立虚拟环境，然后编译本项目使用的 2D / GDScript 模块。
python3 -m venv /tmp/aoe-godot-build-env
/tmp/aoe-godot-build-env/bin/pip install scons==4.11.1
SCONS_BIN=/tmp/aoe-godot-build-env/bin/scons tools/input_poc/build_engine.sh

GODOT_BIN="$PWD/docs/godot/bin/godot.macos.template_debug.arm64.input_poc" \
  tools/input_poc/run.sh --game --engine-wait-gate
```

诊断版用 B（或 F6）切换同一二进制中的原逻辑与计时器检查；默认 `PATCHED scheduler`，加 `--original-scheduler` 可从原逻辑开始。诊断版输出带 `.input_poc` 后缀，正式运行时不会被覆盖。诊断环境变量 `AOE_POC_SKIP_WAIT_GATE=1` 会暂时关闭检查。两种模式均保持 `Engine.max_fps=120`、VSync 开启。普通已安装 Godot 不认识这个诊断变量，不能用它验证补丁。

本机本次已验证的诊断二进制另存于 `captures/godot-poc.macos.arm64`，可用 `GODOT_BIN` 指定它复测。`tools/input_poc/build_engine.sh` 会把源码切到诊断补丁；随后运行 `make build-macos` 会恢复正式补丁。
