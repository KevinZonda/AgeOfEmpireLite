# 修复前完整测试基线

运行工具为 [tools/run_full_tests.py](../../tools/run_full_tests.py)。它发现全部顶层 `tests/*.gd` 的可执行 `SceneTree` 继承链，并运行 `tests/*.js` 的 Node 测试；不按一份手动维护的子集清单跳过测试。本次发现 161 个 Godot 脚本、2 个 JavaScript 脚本和原始探索脚本的全部 63 个场景。

```sh
python3 tools/run_full_tests.py --output poc/exploration-2026-10-02/fixes/baseline --jobs 4 --timeout 600
```

每个脚本的日志、退出状态、耗时与命令写入独立证据目录。第一轮完整脚本清单和全部探索场景已经执行；独立基准 worktree 的四种子长局补跑在 3600.124 秒超时，只完成 3/4 个种子，因此完整 `all` 范围尚未完成。结果在 [fixes/baseline/results.json](fixes/baseline/results.json) 和 [fixes/baseline/summary.json](fixes/baseline/summary.json) 中保存。原始审计的 `results.json`、日志与截图不被覆盖。

常规测试并行执行，像素截取和可见帧率测试使用真实渲染窗口串行执行。本次需真实渲染的 16 个脚本：`character_portraits`、`farm_rendering`、`filled_polygon_rendering`、`fish_rendering`、`fishing_boat_rendering`、`landmark_rendering`、`naval_rendering`、`performance_pan`、`performance_visible`、`relic_rendering`、`siege_detail_occlusion`、`siege_rendering`、`terrain_occlusion`、`unit_snapshot_rendering`、`unit_visual_scale`、`water_surface_rendering`。此外，`display_settings` 和 `smoke` 补跑真实窗口，以覆盖原生窗口/鼠标模式断言，后续工具直接将这两项纳入串行窗口阶段，共 18 项。明确输出 `SKIP`/`SKIPPED` 的脚本不能记作通过。

Godot 的断言通常仅中断测试协程，进程会继续空转。工具检测 `SCRIPT ERROR` 后保留日志并结束该进程，标记为失败而非超时。正常脚本上限 600 秒，`ai_long_match` 保留原始 6000 步场景并使用 1800 秒上限；`balance_multiseed` 保留默认 4 个种子、每局 480 模拟秒，没有缩短长局参数。首次 600 秒仅完成第一个种子，完整四局补跑上限提高为 3600 秒；后续工具自动用普通上限的 6 倍。性能数字在并行运行期间受到 CPU 竞争影响，只可用于趋势观察；像素检查和可见帧率测试串行执行。

每次测试使用临时资源镜像，只有镜像 `project.godot` 设置独立的 `application/config/custom_user_dir_name`，避免读取/覆盖真实游戏的 `user://` 配置。测试用户文件复制到证据目录后删除隔离目录。已用 `settings_store` 验证隔离项目可以正常加载。本机 PATH 中的 Homebrew Node 因缺少有效 `libada.3.dylib` 无法启动，工具探测后使用已有的 `/usr/local/bin/node`（v24.11.1）；没有安装或修改系统依赖。

63 个探索场景分成每批 8 个执行。原脚本进程退出 0 仍可能报告 `status=bug`，工具明确记为 `unresolved_bugs`，整体退出 1。`observation` 仅保留原始审计的规则待确认项；运行时异常或没有完成的场景计作失败。每个案例的原始证据保留于 `results.json` 的 `exploration[].cases`。修复中仍有其他未修复的问题时，整体退出 1 不能直接解释为当前修复引入回归。

后续每个修复应使用新的目录，比较上一轮的完整结果：

```sh
python3 tools/run_full_tests.py --output poc/exploration-2026-10-02/fixes/01-construction --jobs 4 --timeout 600 --compare poc/exploration-2026-10-02/fixes/baseline
```

`comparison.json` 分别列出从通过变为失败的旧测试、退化的探索场景、修复后通过的场景和缺失测试。它不会把剩余问题从结果中隐藏。工具同时记录运行前后源文件 SHA-256；中途改动游戏、测试、数据或探索脚本会使本轮结果无法作为单一代码状态的可靠验证。

原始 PoC 审计已经记录的失败包括施工倍率旧夹具、AI 城堡影响范围、商人返程、迷雾显示、门洞旧摆放假设、驻军/耕田排队、UI 子节点假设和边缘滚动旧预期。本轮最终表格将区分游戏问题、测试夹具和长局超时；在诊断前不将每个失败自动算作一个新的游戏 bug。

## 已核验结果（长局仍未完整完成）

第一轮完整清单耗时 881.892 秒（14 分 42 秒），其中 `ai_long_match` 原始 6000 步通过，耗时 432.3 秒。16 个真实窗口像素/帧率测试全部通过；全部 63 个探索场景完成，24 个通过、27 个复现问题、12 个规则观察项。运行前后源文件哈希一致。

补充真实窗口检查发现 `display_settings` 在 278 行 `match setup should fill a resized view` 断言失败，headless 原尝试通过，两份证据均保留。有效结果为 143 通过、19 失败、1 长局超时。长局有效记录已替换为 3600.124 秒补跑，并保留首次 600 秒超时的原始记录与日志。

第一轮进程采用早期工具版本，`diag_frame_spikes` 的打印内容 `stuck ... failures=N` 被当成测试摘要。该脚本实际退出 0 且没有错误或失败断言，已纠正为通过，原分类和说明同时保存。后续工具仅匹配 `checks=N failures=N` 的测试摘要。同名 `web_gestures.gd` 与 `.js` 的 stdout 路径也已拆分，Godot 原 stdout 使用完整独立 engine 日志恢复。未经纠正的原文件保留于 `results-initial.json`、`summary-initial.json`、`progress-initial.jsonl`。

19 个失败脚本的原始日志如下；暂未逐项诊断完成的失败不能自动归类为游戏错误，也不能当成通过：

| 脚本 | 首个失败 | 日志 |
|---|---|---|
| `chinese` | SCRIPT ERROR: Assertion failed: Chinese villagers should construct 15% faster | [日志](fixes/baseline/logs/chinese.log) |
| `civ_map_ai` | SCRIPT ERROR: Assertion failed: French AI should build within influence range of its stable | [日志](fixes/baseline/logs/civ_map_ai.log) |
| `display_settings` | SCRIPT ERROR: Assertion failed: match setup should fill a resized view | [日志](fixes/baseline/native-recheck/logs/display_settings.log) |
| `extended_systems` | SCRIPT ERROR: Assertion failed: completed trade route should earn gold | [日志](fixes/baseline/logs/extended_systems.log) |
| `fog_unit_flash_poc` | ERROR: FOG_UNIT_FLASH_REGRESSION: enemy stays hidden after its whole figure enters vision | [日志](fixes/baseline/logs/fog_unit_flash_poc.log) |
| `group_multiplayer` | SCRIPT ERROR: Assertion failed: actual unit grids should respect allied and enemy gates | [日志](fixes/baseline/logs/group_multiplayer.log) |
| `match_simulation_regression` | POC_FAIL real_epoch_advances_for_group_and_navigation_services | [日志](fixes/baseline/logs/match_simulation_regression.log) |
| `military_building_occlusion` | POC_FAIL English_barracks_0 wrong_pixels=1 faces=126 fragments=360 | [日志](fixes/baseline/logs/military_building_occlusion.log) |
| `navigation_corner_poc` | POC_FAIL unit_r10_corner0_safe_motion (638.7745, 542.31) -> (642.31, 538.7745) | [日志](fixes/baseline/logs/navigation_corner_poc.log) |
| `navigation_state_poc` | POC_FAIL farm_queue_control_occupiedtrue_extratrue order=idle queue=0 | [日志](fixes/baseline/logs/navigation_state_poc.log) |
| `navigation_tasks_poc` | POC_FAIL farm_1_workers_use_assigned_farms 0 working | [日志](fixes/baseline/logs/navigation_tasks_poc.log) |
| `performance_navigation` | SCRIPT ERROR: Assertion failed: all units should make sustained forward progress | [日志](fixes/baseline/logs/performance_navigation.log) |
| `player_input_actions_regression` | ERROR: Index p_index = 0 is out of bounds ((int)data.children_cache.size() - data.internal_children_front_count_cache - data.internal_children_back_count_cache = 0). | [日志](fixes/baseline/logs/player_input_actions_regression.log) |
| `rally_landmarks` | SCRIPT ERROR: Assertion failed: right click should update White Tower's rally point | [日志](fixes/baseline/logs/rally_landmarks.log) |
| `selection_battle_latency_poc` | SCRIPT ERROR: Invalid call to function 'tick' in base 'RefCounted (TimedJobs)'. Expected 1 argument(s). | [日志](fixes/baseline/logs/selection_battle_latency_poc.log) |
| `smoke` | SCRIPT ERROR: Assertion failed: hovering the bottom HUD should suppress edge scrolling | [日志](fixes/baseline/native-recheck/logs/smoke.log) |
| `unit_orders_regression` | POC_FAIL siege_docking_cancels_active_movement | [日志](fixes/baseline/logs/unit_orders_regression.log) |
| `villager_post_construction` | 退出状态或汇总检查失败 | [日志](fixes/baseline/logs/villager_post_construction.log) |
| `visual_state` | SCRIPT ERROR: Assertion failed. | [日志](fixes/baseline/logs/visual_state.log) |

长局补跑位于 `/tmp/AgeOfEmpireLite-baseline`，基于提交 `70e3b754d56437a2f22e4efaf897f704984b52ab`。其源快照与第一轮逐文件完全相同，主目录后续修复不会污染长局基线。因转移位置而中止的 81.6 秒尝试保留于 `long-recheck-aborted`；有效补跑证据位于 [long-recheck/result.json](fixes/baseline/long-recheck/result.json)，仍属未完成实验。该次运行完成种子 `17,431,9021`，种子 `4242` 没有完成输出；没有 `SCRIPT ERROR`，运行前后基准源快照一致。引擎与启动器均已退出，没有遗留进程。实际观察成本至少 60 分钟，不能把 3600 秒超时当成四种子完整验证。最终 `--profile all` 必须使用足够时限让四个种子全部完成，且明确检查输出。

## 取消执行

工具捕获 `SIGINT` 与 `SIGTERM`，通过共享取消事件让运行中的各进程组退出并回收。尚未启动的队列项直接记录 `cancelled`，不会继续打开引擎或窗口。取消后保留 partial `results.json` / `summary.json`，`cancelled=true`、`complete=false`，程序退出 130。已用真实 Godot 进程分别发送两种信号验证：仅第一个脚本启动，该引擎被回收，其余 163 个脚本均未启动，没有遗留引擎进程。证据见 [SIGTERM](fixes/baseline/cancellation-check/results.json) 和 [SIGINT](fixes/baseline/cancellation-sigint-check/results.json)。这些是工具取消行为验证，不合并到游戏测试基线的通过/失败统计中。

后续工具明确固定完整平衡样本为种子 `17,431,9021,4242`、每局 480 模拟秒，避免继承 shell 的短跑环境配置。`RTS_BALANCE_TRACE=1` 仅增加长局模拟进度日志。完整性检查要求四个种子都有实际输出；任何 timeout、cancelled、skipped 或缺失探索场景都会令 `complete=false`，不会通过比较阶段的 `no_new_failures` 条件。

## 明确的执行范围选项

已准备 `--profile all` 与 `--profile regression`，默认始终为 `all`。`regression` 唯一延后的项目是仅输出平衡统计与地图公平断言的四种子 `balance_multiseed` 实验；6000 步 `ai_long_match`、所有真实窗口/像素测试、JavaScript 测试和全部 63 个 PoC 仍然执行。若使用该选项，`environment.json`、`summary.json`、`comparison.json` 均明确记录 `profile` 及 `deferred_benchmarks`，不会静默漏掉实验。`complete` 表示所选范围实际完成，`complete_all` 还要求没有延后项目；比较阶段只允许这个明确延后的实验不计为 missing，其余缺失都失败。修复轮次使用明确的 `--profile regression`，最终另跑 `--profile all`；每项修复不能把延后的平衡实验声称为已完成。独立基准实验的超时与原始统计单独保留，不会被回归范围隐藏。

## 比较与资源快照的加固

后续工具将完整 `SCRIPT ERROR` / `ERROR` 首行及 `POC_FAIL` 符号归一化为失败诊断集合，忽略浮动证据、调用栈与 `.gd` 行号变化。原失败脚本出现新的失败诊断也会阻止 `no_new_failures`，不能只比较通过/失败状态。旧证据缺少诊断字段时，从保存的日志读取诊断。源快照另纳入 `scenes` 与 `assets` 的业务文件（排除 `.uid` / `.import`），覆盖场景与资源改动。工具验证示例见 [diagnostics-demo.json](fixes/tool-validation/diagnostics-demo.json)。
