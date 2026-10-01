# 修复前完整测试基线

运行工具为 [tools/run_full_tests.py](../../tools/run_full_tests.py)。它发现全部顶层 `tests/*.gd` 的可执行 `SceneTree` 继承链，并运行 `tests/*.js` 的 Node 测试；不按一份手动维护的子集清单跳过测试。本次发现 161 个 Godot 脚本、2 个 JavaScript 脚本和原始探索脚本的全部 63 个场景。

```sh
python3 tools/run_full_tests.py --output poc/exploration-2026-10-02/fixes/baseline --jobs 4 --timeout 600
```

每个脚本的日志、退出状态、耗时与命令写入独立证据目录。完整基线正在执行，最终结果将在 [fixes/baseline/results.json](fixes/baseline/results.json) 和 [fixes/baseline/summary.json](fixes/baseline/summary.json) 中保存。原始审计的 `results.json`、日志与截图不被覆盖。

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
