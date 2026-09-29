# 战斗长帧 PoC

2026-09-29，Apple M2，项目自带 Godot 4.7.2 template_debug。用户报告场景为 2.5D 建筑被围攻。

## PoC 1：包围中的恢复搜索扫描不可达区域

`navigation_battle_recovery_poc.gd` 在平地上放置一名单位和八名包围者。连续发出十次恢复寻路，再移走三个包围者验证重新可达。修复前十次耗时 **852.6 ms**，修复后 **35.3 ms**（单次运行的诊断值，不作为跨机器阈值）。

原 `_local_unit_path` 为每次恢复调用 `_components_for`，给整个网格的所有连通区域打标签，随后遍历整张网格收集候选点；最大网格为 193 × 193。单位脚下只有一个可达格时，外面数万格仍被反复遍历。现在从起点 flood fill，只访问当前连通区域，只从该区域收集候选点。四邻域连通性与禁止切角的八邻域 A* 一致；碰撞判定、搜索分辨率和搜索范围均保持原规则。

回归逐个比较五种网格的可达集合与原完整连通分量算法，验证包围时无路径、开口后恢复安全路径；导航、施工、编队、经济等 19 个既有回归通过。`smoke.gd:55` 受本机已保存的“关闭边缘卷页”设置影响而失败，未修改的基线也在同一行失败；不计为本次回归通过。

初步 100 对 100、600 步野战诊断中，恢复搜索累计 12.66 秒，占单位模拟总耗时约 61%，单步最大 336 ms；A* 核心本身仅累计 0.15 秒。主要开销是 GDScript 中为恢复搜索准备和遍历网格，不是伤害计算。

## PoC 2：远处动物移动取消失败退避

`navigation_battle_retry_poc.gd` 用四名单位占满建筑接触位置，一名进攻者等待，另一端资源每步移动 0.1 像素。修复前 90 步发起 **90 次**完整射程寻路，耗时 **245.6 ms**；修复后 **3 次、8.8 ms**。原实现遇到任意障碍版本变化就把空路径的重试计时归零，远处动物移动让指数退避失效。

现在区分碰撞版本和失败重试版本。资源移动仍立即刷新几何、验证现有路径，但不唤醒所有失败请求；建筑位置、类型、完成状态、资源增删和大小变化，以及显式地形更新仍会唤醒。资源移动后原本无路的单位在正常退避到期后重试，最多等待现有的 `ROUTE_RETRY_MAX` 加错峰时间；新的目标仍使用原有快速重试规则。

新增断言验证移动资源依旧阻挡碰撞、结构更新即时唤醒、临时拥堵消失后可抵达目标。重新验证了失败退避、目标切换、施工、复杂地形和密集编队。

## 复现

```sh
make run RUN_ARGS='--headless --script res://tests/navigation_battle_recovery_poc.gd'
make run RUN_ARGS='--headless --script res://tests/navigation_battle_retry_poc.gd'
python3 tools/check_navigation.py
RTS_BATTLE_SIEGE=1 RTS_BATTLE_MAP=generated RTS_NAV_PROFILE=1 make run RUN_ARGS='--script res://tests/performance_battle_poc.gd --windowed --resolution 1280x720'
```

集成基准固定随机种子 4242，默认 40 名进攻者、300 个 1/30 秒模拟步、2.5D，围攻中央城镇中心。提高目标生命值以持续观察拥堵；更新单位、建筑、弹道、资源、迷雾和 UI，禁用 AI。环境变量 `RTS_BATTLE_SIDE` / `RTS_BENCH_STEPS` 调整规模与时长，`RTS_BENCH_PROJECTION=2d` 切换投影，去掉 `RTS_BATTLE_SIEGE=1` 改为两军接战，去掉 `RTS_BATTLE_MAP=generated` 使用平地隔离场景。

输出分别记录单位模拟、其他 CPU 更新与真实窗口帧间隔。headless 帧间隔不是渲染 FPS；开启 profiling 的数据只用于热点定位，最终窗口比较应关闭 profiling 并串行运行。
