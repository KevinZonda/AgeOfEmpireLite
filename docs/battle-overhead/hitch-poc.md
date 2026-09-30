# hitch_poc 第一轮卡顿修复

2026-09-30，Apple M2，项目自带 Godot 4.7.2 debug template。以下为 headless 帧间墙钟测量，包含真实游戏模拟和脚本下令；不代表窗口 FPS。每轮固定 seed 7、15 秒模拟，初始 153 个单位、23 座建筑，保留 AI 和迷雾。

## 修改与行为

- 可达落点查询在本次同步调用内复用起点网格连接、可见格和静态线段检查，连空连接集合也缓存。查询结束恢复此前上下文，不跨帧保存这些结果，避免移动单位和动物沿用旧检查。
- 起点没有粗网格连接、也不能使用严格边角路径时，复用已知的细网格连通性排除无望候选。直达的重叠逃逸仍先检查；细网格不通不会单独用于否定窄通道。
- 所有候选路径均失败时返回当前位置，结束无法执行的移动；不再把一个未经可达性验证的空格交给单位持续重试。可达候选的环形顺序、全局距离排序和同距离规则保持不变。
- 连通区域洪泛顺便记录每个区域的格子数。严格、对称的边角搜索选择较小区域作为搜索起点，结果恢复原方向。这仅改变搜索方向，不根据网格连通性直接拒绝边角路线。
- 起点无连接时不再计算无用的终点连接。没有新增后台任务；冷建网格和部分编队重规划仍在主线程。
- PoC 的墙钟计时移动到下令和拆建之后，修正原先遗漏这些操作、但导航计数已经包含它们的问题。新增动作标签；迷雾、AI、统计标记只说明同一采样区间发生过活动，不视为独立耗时或确定因果。

## 前后对照

两轮原版和两轮候选版均关闭 profiling，串行执行，使用修正后的同一 PoC。原版在 `/tmp` 独立项目副本运行，只替换回修改前的 `navigation.gd`，未临时回退共享工作区。后台调度使用真实时间，单位轨迹和后续查询数量会有差异，表中保留每轮结果。

| 指标 | 原版第 1 / 2 轮 | 候选第 1 / 2 轮 |
| --- | ---: | ---: |
| 中位数 | 8.3 / 8.4 ms | 8.4 / 8.3 ms |
| P95 | 29.3 / 30.0 ms | 29.2 / 29.4 ms |
| 最大帧间耗时 | 3043.8 / 2085.2 ms | 512.2 / 795.2 ms |
| 第 6 秒编队及封闭目标下令帧 | 2085.5 / 2085.2 ms | 140.1 / 795.2 ms |
| 超过 12 ms 的帧数 | 266 / 267 | 260 / 258 |

本轮明显降低了最严重的停顿，P95 基本不变，仍有约 0.5–0.8 秒长帧。不能据此宣称卡顿全部解决或稳定 60/120 FPS。后续若继续消除长帧，应处理同步冷启动、编队批量寻路和落点查询的跨帧调度。

日志仅清理行末空白，未修改测试输出内容。原始日志、源码 SHA-256 和逐项回归结果见 [results.json](hitch-poc-20260930/results.json)，四轮日志为 [原版 1](hitch-poc-20260930/baseline-1.log)、[原版 2](hitch-poc-20260930/baseline-2.log)、[候选 1](hitch-poc-20260930/candidate-1.log)、[候选 2](hitch-poc-20260930/candidate-2.log)。

## 正确性与复现

15 个相关回归脚本通过，覆盖导航角点与窄通道、施工和行为状态、阵营编队、大规模拥堵、动物移动以及后台恢复。最后撤回占位检查前的额外筛选后，重新执行了落点、角点、矩阵、重规划、搜索工作量和后台恢复六项回归，全部通过。

新增 `navigation_destination_poc.gd` 的 19 项检查覆盖无网格连接的合法小区域、资源重叠逃逸、细网格孤立区域、起点连接复用、失败落点、清障后恢复、较小区域搜索方向、原方向路径，以及跨查询的单位占位变化。已加入默认导航测试列表。

另行运行的 `navigation_range_corner_poc` 中，已有的 `range_candidates_reuse_origin_visibility` 断言仍失败；原版副本也复现相同失败。记录见 [原版](hitch-poc-20260930/known-failure-baseline.log) 和 [候选](hitch-poc-20260930/known-failure-candidate.log)。

```sh
RTS_NAV_PROFILE=0 docs/godot/bin/godot.macos.template_debug.arm64 \
  --headless --path . -s res://poc/hitch_poc.gd
RTS_NAV_PROFILE=1 docs/godot/bin/godot.macos.template_debug.arm64 \
  --headless --path . -s res://poc/hitch_poc.gd
python3 tools/check_navigation.py --tests navigation_destination_poc \
  navigation_corner_poc navigation_poc_matrix navigation_replanning \
  navigation_search_work navigation_async_poc
```
