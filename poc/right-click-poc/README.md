# 触摸板双指轻点右键 POC

2026-09-30。用户报告：双指轻点有时表现为左键。使用本项目已有补丁的 Godot 4.7.2 运行时。原始诊断仅添加采样和回放；`fix/right-click-selection` 分支现已修复正式游戏的轮询选择入口，修复验证见下节。

## worktree 修复与验证

分支：`fix/right-click-selection`。工作目录：`/Users/kevin/Desktop/AgeOfEmpireLite-right-click`，复用现有补丁引擎。

`scripts/game.gd::_advance_selection_pointer()` 不再根据原生 LEFT 上升沿调用 `_begin_selection_candidate()`。正常 LEFT 事件仍经 `_unhandled_input()` 开始选择；原生坐标和按钮轮询继续更新已有拖框、在松开时完成选择。仅原生状态出现 LEFT 而没有 LEFT 事件时，不会创建选择。移除了不再使用的原生选择开始条件函数，并把旧拖选性能 POC 改为同时提供真实的 LEFT 事件。

修复后以相同 641 种场景、3 个种子、每场景 10 次、3 种分发和 2 个版本重复了 115,380 次合成回放。`--expect-fixed` 会要求原游戏版本也保持选中单位、正常移动且不额外启动选择；全部通过，没有重复不一致或直接调用／引擎即时分发差异。完整结果见 [right-click-fixed-matrix.json](right-click-fixed-matrix.json)。

| 场景组（仅原游戏版本、即时引擎分发）| 修复前清空选择 | 修复后清空选择 |
| --- | ---: | ---: |
| RIGHT 与原生 LEFT 顺序／轮询位置交错 | 2,520 / 5,760 | 0 / 5,760 |
| RIGHT 与原生 LEFT 帧时间组合 | 990 / 4,320 | 0 / 4,320 |
| RIGHT 与原生 BOTH 帧时间组合 | 990 / 4,320 | 0 / 4,320 |
| Control+点击两个对照 | 30 / 60 | 0 / 60 |

这些是合成场景计数，不代表物理触摸板故障率。原始诊断 JSON 保持不变；矩阵默认写入 `right-click-current-matrix.json`，使用 `--expect-fixed` 时默认写入 `right-click-fixed-matrix.json`，避免覆盖历史证据。

新增 [right_click_selection.gd](../../tests/right_click_selection.gd) 经 `Input.parse_input_event()` 验证原生 LEFT 脉冲、Control+点击、右键取消与迟到松开、瞬时 LEFT、Shift 追加、双击、真实事件启动的拖框及失焦取消。该测试和原有 smoke、selection、build_selection、landmark_selection、minimap_projection 均通过。更新后的 `selection_battle_latency_poc.gd` 在 headless 实际帧循环中完成 3 次拖选、429 个按住样本，选框状态／位置不一致数为 0；这不衡量显示器延迟。

```sh
make run RUN_ARGS='--headless --script res://tests/right_click_selection.gd'
python3 poc/right-click-poc/right_click_matrix.py --repeats 10 --expect-fixed
RTS_DRAG_IDLE=1 RTS_DRAG_SECONDS=4.5 \
  make run RUN_ARGS='--headless --script res://tests/selection_battle_latency_poc.gd'
```

本修复针对游戏轮询额外产生的选择。如果 AppKit 已送出 LEFT，游戏仍按实际 LEFT 事件处理；真实双指轻点是否被系统误识别仍需带用户意图标记的物理采样确认。缺失 LEFT 松开且轮询从未见到按下的另一现象也未在此修复中改变。

## 具体诊断目标与判据

本目录独立诊断“右键操作导致额外左键选择、取消选中或无法下令”，包括真实窗口采样、可重复的故障回放，以及用于确认原因的对照版本。入口和诊断代码都在本目录；依赖项目的正式游戏代码和 `docs/godot/bin/` 中的本地运行时，不依赖 `poc/input-poc/`。拖框延迟与 Magnet 调度仍由 [input-poc](../input-poc/README.md) 负责。

需要分别回答两个具体问题：

| 问题 | 复现条件与判据 | 目前结论 |
| --- | --- | --- |
| 游戏是否在已识别 RIGHT 后额外执行 LEFT 选择？ | 不送任何 LEFT 按下事件；已选单位收到 RIGHT；其后仅原生 LEFT 状态出现并消失。观察是否由 `source=native_poll` 启动并完成选择、清空已选单位 | 合成回放已稳定复现；原因在游戏选择状态机 |
| 双指轻点是否在进入游戏之前被系统判成 LEFT？ | 用 F7／F8 标记用户右键意图；若 AppKit 原始事件为 LEFT，说明游戏接收之前已是 LEFT | 首轮日志出现过 AppKit LEFT，但没有用户意图标记，尚未确认该次物理手势 |

成功识别的 RIGHT 事件不应为同一次操作额外创建 LEFT 选择。故障回放的目标是确认这条游戏行为；注入原生 LEFT 脉冲是明确的输入假设，不能证明硬件双指轻点必然生成该脉冲。原始 A/B 版本用“必须有 LEFT 事件才允许轮询选择”确认原因；当前修复直接取消轮询创建选择的入口，保留其更新与松开处理。

## 目录与运行入口

所有命令在项目根目录执行。

| 文件 | 用途 |
| --- | --- |
| [run.sh](run.sh) | `poc/right-click-poc/run.sh --game` 启动完整游戏采样；不加参数启动空场景对照。`right_click.sh` 是同一入口的兼容包装 |
| [probe.gd](probe.gd)、[trace.gd](trace.gd)、[game_trace.gd](game_trace.gd)、[native_probe.m](native_probe.m) | 关联 Quartz、AppKit、Godot 事件与游戏选择／下令动作；原样返回系统事件 |
| [right_click_replay.gd](right_click_replay.gd)、[right_click_fixture.gd](right_click_fixture.gd) | 最小故障及正常左右键对照；`make run RUN_ARGS='--headless --script res://poc/right-click-poc/right_click_replay.gd'` |
| [right_click_matrix.py](right_click_matrix.py)、[right_click_matrix.gd](right_click_matrix.gd) | 自动构造时序矩阵；`python3 poc/right-click-poc/right_click_matrix.py --repeats 10 --expect-fixed` |
| [right_click_summary.py](right_click_summary.py) | 汇总采样时间线；`python3 poc/right-click-poc/right_click_summary.py /tmp/aoe-right-click-poc-日期时间` |
| `right-click-*.json` | 原始诊断数据与 `right-click-fixed-matrix.json` 修复验证结果分别保留 |

## 当前结论

**已用合成回放复现一种会让右键操作产生左键选择效果的游戏路径；尚未证明实际双指轻点出现的事件序列就是该路径。** 真实触摸板需要在诊断窗口操作并标记，不能用程序生成鼠标点击代替。

游戏在 macOS 下同时使用两种输入来源：

- `scripts/game.gd::_unhandled_input()` 根据 Godot 的 `button_index` 下右键指令。
- `_process()` → `_poll_selection_pointer()` → `_advance_selection_pointer()` 根据 `DisplayServer.mouse_get_button_state()` 的 LEFT 位开始／完成选择。

本地引擎源码 `docs/godot/platform/macos/display_server_macos.mm::mouse_get_button_state()` 直接映射 `[NSEvent pressedMouseButtons]`。`godot_content_view.mm::rightMouseDown()` 明确发出 RIGHT；`mouseDown()` 还会将 Control+左键映射成 RIGHT，但系统 LEFT 状态不会随此转换。这说明事件按钮与轮询状态可以有不同语义，**不说明用户的双指轻点属于 Control+点击**。

## 可重复的回放结果

回放使用真实游戏状态机，测试夹具仅提供独立的原生 LEFT 状态和指针坐标，；原始版本还放宽 headless 窗口的焦点条件，修复后轮询不再负责开始选择。每轮选中侦察兵，点击可见的空地。结果保存在 [right-click-replay.json](right-click-replay.json)。

| 输入顺序 | 右键移动 | 松开后仍选中侦察兵 |
| --- | --- | --- |
| RIGHT 事件，原生状态没有 LEFT | 是 | 是 |
| RIGHT 事件 → 轮询首次读到 LEFT → 松开 | 是 | **否** |
| 轮询先读到 LEFT → RIGHT 事件 → 松开 | 是 | 是 |
| LEFT 事件 → RIGHT 事件（同批）→ 松开 | 是 | 是 |
| 纯 LEFT 点击空地（对照）| 否 | 否 |

第二行中，RIGHT 到达时尚未 `dragging`，所以 `_input()` 没有执行取消选择并阻塞至松开的分支。下令后轮询的 LEFT 上升沿启动选择候选；LEFT 下降沿完成空地选择，清空已选单位。没有发生 `button_index` 被改写，但最终效果很像右键被当成左键。

若 LEFT 已先启动选择，现有右键取消逻辑能够阻塞本次 LEFT 至松开。这是一个依赖先后顺序的区别，解释了该**合成场景**为何会时好时坏。真实故障仍需确认：是否确有 LEFT 状态；状态发生在 RIGHT 前还是后；或者 AppKit 本来就送出了 LEFT 事件。

运行回放：

```sh
AOE_RIGHT_CLICK_REPLAY="$PWD/poc/right-click-poc/right-click-replay.json" \
  make run RUN_ARGS='--headless --script res://poc/right-click-poc/right_click_replay.gd'
```

此轮验证：`RIGHT_CLICK_REPLAY_OK`、原有 `tests/selection.gd` 的 `SELECTION_OK`、native dylib 编译、shell 和 Python 语法检查均通过。

## 自动构造与重复测试

后续扩展为 [right_click_matrix.py](right_click_matrix.py) 与 [right_click_matrix.gd](right_click_matrix.gd)。原始结果保存于 [right-click-matrix.json](right-click-matrix.json)，修复结果保存于 [right-click-fixed-matrix.json](right-click-fixed-matrix.json)。验证修复：

```sh
python3 poc/right-click-poc/right_click_matrix.py --repeats 10 --expect-fixed
```

**641 种场景 × 3 个地图种子（12345、4242、431）× 每种 10 次 × 3 种输入分发 × 2 种 POC 版本 = 115,380 次合成回放。** 正常左右键对照无失败，相同场景重复结果无变化，直接调用与 `Input.parse_input_event()` 即时分发无结果差异。

这不是 115,380 次物理触摸板操作。原生按钮状态和指针由夹具提供，原始版本的 headless 焦点条件被放宽；画面、设备识别和 AppKit 的物理手势判定未在此矩阵中运行。时间参数用于排列事件和帧轮询先后，采用虚拟时间，不以 sleep 模拟真实负载。

覆盖范围：

- RIGHT 按下／松开与原生 LEFT 上升／下降沿的全部 6 种合法交错顺序，以及每个顺序的 32 种帧轮询位置。
- 30／60／120 FPS 的帧间隔，4 个帧内起点，0.1／1／5／20ms 的原生按钮脉冲，0／5／30ms 的事件延迟；分别提供 LEFT、RIGHT、BOTH 原生状态。
- 双指轻点日志中常见的按下／松开同批、原生状态已经回到 0；事件掩码为 LEFT/BOTH 但 `button_index=RIGHT`；重复 RIGHT、RIGHT 的双击标记、迟到的 LEFT 松开；RIGHT 前后实际送达 LEFT；Control+点击的事件／状态语义差异；LEFT 缺失松开。
- 直接调用游戏入口、Godot 即时输入分发、Godot 缓冲输入后显式 flush。后两者真实经过 Input 与 Viewport 路径，没有跳过 GUI／handled 分发。

对照版本仅存在于测试夹具中：轮询必须先有已送达的 LEFT 按下才允许启动／更新选择，RIGHT 按下撤销该许可。该 A/B 版本保留用于历史对照。当前分支采用“只有 LEFT 事件能开始选择”的正式修复，而不是添加同一个许可标记。

下表为修复前的历史结果，只统计 `engine_immediate`；每组包含 3 个种子、每场景 10 次。分母是合成场景执行次数，**不能当作真实触摸板故障率**。

| 合成场景组 | 原游戏清空选择 | 对照版清空选择 |
| --- | ---: | ---: |
| 正常 RIGHT、原生 RIGHT，包括瞬时轻点与各种掩码 | 0 / 4,530 | 0 / 4,530 |
| RIGHT 事件与原生 LEFT 的顺序／轮询位置交错 | 2,520 / 5,760 | 0 / 5,760 |
| RIGHT 事件与 LEFT 原生脉冲的帧时间组合 | 990 / 4,320 | 0 / 4,320 |
| RIGHT 事件与 BOTH 原生脉冲的帧时间组合 | 990 / 4,320 | 0 / 4,320 |
| Control+点击：原生 LEFT 持续 vs 已结束两个对照 | 30 / 60 | 0 / 60 |
| 实际 LEFT 事件与 RIGHT 事件交错 | 60 / 90 | 60 / 90 |

### 最小故障时间线

来自 `timing_30_0.65_20_0_mask1`，全部按下事件的 `button_index` 都是 RIGHT：

| 虚拟时间 | 操作 | 原游戏状态 |
| --- | --- | --- |
| 21.67ms | 原生 LEFT=1；送达 RIGHT 按下 | 侦察兵正常接收 move，仍选中 |
| 33.33ms | 帧轮询 LEFT=1 | **没有 LEFT 事件也启动选择** |
| 41.67ms | 原生 LEFT=0；送达 RIGHT 松开 | 选择候选仍存在 |
| 66.67ms | 帧轮询 LEFT=0 | 完成空地选择，选中数从 1 变 0 |

游戏层原因明确：`_advance_selection_pointer()` 把原生 LEFT 上升沿当作独立的选择起点；`_input()` 的 RIGHT 取消逻辑仅在当时已经 `dragging` 时执行。RIGHT 先到时缺少这一保护，之后的轮询能创建新的选择。这无需假设 Godot 把 RIGHT 的 `button_index` 改成 LEFT。

Control+点击是本地引擎源码已经明确提供的合法语义不一致案例：AppKit LEFT + Control 被转换成 Godot RIGHT，原生 LEFT 状态仍是 LEFT。它支持“这类冲突不是只能依靠随意构造不可能的按钮状态才能发生”，但用户报告的双指轻点没有 Control，不能因此声称已复现相同物理手势。

另一个独立现象：LEFT 按下事件到达时原生状态已经是 0，且 LEFT 松开事件缺失，会保持选择候选。此时 `selection_previous_left_down=false`，轮询看不到下降沿。这在两个 POC 版本中都存在；只有缺失松开这一附加假设才会出现，不是当前 RIGHT 误识别的证据。

### 能排除与仍不能断言的部分

正常 RIGHT 在事件掩码为 LEFT 或 BOTH、原生状态为 0 的情况下也不会变成左键。Godot 的 `Input::_parse_input_event_impl()` 根据 `button_index` 更新 Input 按钮状态，不把事件的 `button_mask` 当作按钮种类。已测试的瞬时轻点、事件缓冲和重复 RIGHT 本身未触发误选择。

如果 AppKit 已送出纯 LEFT 事件，游戏没有足够信息区分“真正的左键点击”和“用户想做右键但系统识别成左键”。矩阵中把 LEFT 放在 RIGHT 后面仍会清空选择，对照版也一样；这不能用轮询修复来覆盖。

因此：**游戏双路径输入漏洞已确认并稳定复现；真实双指轻点偶发识别错误的来源仍未确认。** 首轮窗口日志的可疑点击属于 AppKit 已送出 LEFT 的情况，而不是已观察到 RIGHT 后原生轮询误启动选择。两条证据应分开解释。

## 物理操作采样

### 首轮窗口日志

实际启动的诊断窗口日志位于 `/tmp/aoe-right-click-poc-20260930-090324`，关键事件摘录保存于 [right-click-window-events.json](right-click-window-events.json)。这里记录的是窗口收到的事件，没有 F7/F8 用户意图标记，不能仅凭日志认定每次点击对应的物理手势。

- 日志中的 5 次 RIGHT 按下，AppKit 和 Godot 均一致识别为右键，每次均执行下令；其后 150ms 内没有启动左键选择。没有观察到合成回放中的 RIGHT 后左键轮询启动选择。
- 北京时间 **09:05:21.690** 有一次夹在右键操作之间的短促 LEFT 点击，将选中对象从 2 个清空为 0 个。AppKit 已报 `left_down/left_up`、`buttonNumber=0`，Godot 收到 LEFT 并完成空地选择。游戏没有把一个已送达的 RIGHT 事件改成 LEFT。
- 如果用户确认该次点击原本也是双指右键，定位方向应转向 AppKit 送达之前的系统／手势识别；目前缺少该次用户意图证据，不能将它直接认定为误识别。

```sh
# 完整游戏：默认使用 make run 同款补丁引擎。
poc/right-click-poc/right_click.sh --game

# 空场景对照：显示最后一个 Godot 按钮和两种按钮掩码。
poc/right-click-poc/right_click.sh
```

日志目录会打印为 `/tmp/aoe-right-click-poc-日期时间`。`TRACE_DIR` 和 `GODOT_BIN` 可覆盖。运行器只在该进程加载诊断 dylib，native monitor 原样返回事件，不修改输入或系统设置。

完整游戏中先选单位，再在地图空地连续双指轻点下令。可先按 **F7** 标记“下一次有意做右键”；发现误识别后立即按 **F8** 标记。Mac 若默认使用媒体键，使用 Fn+F7／Fn+F8。避免把切回窗口的首次点击当作正常游戏点击。结束后关闭诊断窗口。

```sh
python3 poc/right-click-poc/right_click_summary.py /tmp/aoe-right-click-poc-日期时间
# 默认显示 F8 之前 4 秒；未标记则显示全部按钮和动作。
# --all 显示完整时间线，--window 8 扩大标记前窗口。
```

记录层级：

1. Quartz 每约 2ms 读取 HID 和会话的左右键状态，变化时记录。采样可能漏过极短状态，不把“未采到”当作不存在。
2. AppKit 记录左右键按下／松开、原始 `buttonNumber`、修饰键、点击次数、会话按钮掩码和事件年龄。
3. Godot 记录 `button_index`、事件掩码、Control、双击标记，以及当时的原生状态与 Input 状态。游戏入口也独立记录，避免已处理的事件未到通用观察器。
4. 游戏记录左键轮询边沿、选择开始／完成／取消的来源、RIGHT 下令，以及选中对象 ID 的前后变化。

判定方法：有意右键时 AppKit 已是 LEFT，问题发生在游戏接收之前；AppKit 是 RIGHT 但 Godot 游戏入口是 LEFT，检查引擎转换／同步；游戏收到 RIGHT，却由 `source=native_poll` 启动并完成选择，才支持上述游戏双路径冲突。也应检查右键之前是否已完成一次真实 LEFT 选择。仅凭最终丢失选择不能区分这些原因。

按钮编号不能混用：AppKit `buttonNumber` 0=左、1=右；Godot `button_index` 1=左、2=右；本 POC 中按钮状态掩码 1=左、2=右、3=两者。F7/F8 用于记录用户意图；系统状态本身无法告诉我们用户打算做什么手势。
