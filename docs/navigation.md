# 寻路优化与验证

## 当前实现

`scripts/world/navigation.gd` 使用 50×50 栅格的 `AStarGrid2D`，结合路径平滑、交互范围落点选择、64×64 空间索引和局部碰撞避让。`movement_group.gd` 将附近单位拆为最多 12 人的小队，共享路线。

单体移动现在复用已有路线，仅在目标显著移动、交互距离改变、前方路段受阻、路径终点不再满足目标，或持续 0.9 秒没有取得进展时重新请求路径。每段路径在进入时检查静态障碍；导航版本变化也会触发前方路段检查。远处的障碍变化不直接丢弃仍可用的单体路线。

失败请求采用约 0.7、1.4、2.8、4 秒的重试间隔，并添加 0–0.17 秒的单位错峰。局部移动继续尝试避障，只有取得足够前进距离才清除失败次数。新的目标位置会缩短旧失败请求的等待；导航刷新后，空路径请求立即获得重试机会。

导航刷新维护递增版本号，单体和小队据此检测变化。即使刷新前后的建筑、资源哈希相同，显式地形刷新也能被识别。

## 性能计数

设置 `RTS_NAV_PROFILE=1` 开启，默认关闭。`navigation.profile_snapshot()` 返回快照，`navigation.reset_profile()` 清空计数。

| 项目 | 内容 |
| --- | --- |
| `path_between` | 点到点路径请求 |
| `path_to_range` | 到交互范围的路径请求 |
| `astar` | 导航层实际执行的 A*，包括落点可达性检查 |
| `grid_refresh` | 全部导航栅格重建 |
| `can_occupy` | 占位与碰撞检查 |

每项包含 `calls`、`total_us`、`max_us`。这些计时有嵌套关系，不能相加作为总耗时。开启计数有额外开销；耗时对比使用关闭计数的运行，调用次数另行测量。

```sh
# 400 个独立单位，180 个模拟步，输出平均、P95、P99 和首次／后续峰值
make run RUN_ARGS='--headless --script res://tests/performance_navigation.gd'
RTS_NAV_PROFILE=1 make run RUN_ARGS='--headless --script res://tests/performance_navigation.gd'

# 原有群体移动场景，延长模拟以覆盖脱队及独立寻路
RTS_NAV_PROFILE=1 RTS_BENCH_STEPS=180 make run RUN_ARGS='--headless --script res://tests/performance_400.gd'

# 按需重算、障碍改变、失败退避、动态堵路和交互距离变化
make run RUN_ARGS='--headless --script res://tests/navigation_replanning.gd'
```

## 本机对比（2026-09-28）

使用本地 Godot 4.7.2 修复版，400 个独立单位在开阔地图上移动 180 步，每步模拟 1/30 秒。每步重新建立空间索引，不包括 UI、AI 和渲染。旧版与新版使用相同的测试和计数代码，旧版在隔离的临时项目中恢复原单体移动逻辑。耗时各运行三次，下面取各项中位数。

| 指标 | 原固定周期重算 | 按需重算 |
| --- | ---: | ---: |
| 路径请求次数（单独开启计数） | 3,600 | 400 |
| 占位检查次数（单独开启计数） | 383,860 | 117,200 |
| 平均每步 CPU 耗时 | 10.35 ms | 5.38 ms |
| P95 每步 CPU 耗时 | 4.89 ms | 4.73 ms |
| P99 每步 CPU 耗时 | 154.14 ms | 11.43 ms |
| 首次模拟步耗时 | 163.91 ms | 163.93 ms |

这一场景走直线，路径请求通过直线检测完成，不执行 A*；收益来自减少重复路径检查，不能表述为 A* 搜索加速。所有单位均通过前进距离断言。数值只反映该场景，不能直接换算为完整游戏 FPS。

首次集中创建路径的峰值仍然存在。当前也仍采用全量栅格刷新、固定障碍外扩和原有小队窄口逻辑；按体型建立通行配置、窄口通行调度和局部栅格更新属于后续工作。

群体场景 `performance_400.gd` 延长至 180 步后，单次开启计数的对照运行中，路径请求从 2,264 次降至 1,520 次，A* 从 1,929 次降至 1,310 次，平均模拟耗时从 57.0 ms 降至 49.2 ms。P95 为 92.3 → 95.2 ms，并非所有延迟指标都改善。这组计时带有统计开销且只测量一次，主要用于定位剩余瓶颈：新版占位检查累计约 7.38 秒，实际 A* 累计约 18.5 毫秒。

## 回归结果

以下脚本均完成，退出码为 0，未出现脚本错误或断言失败：

- `navigation_replanning.gd`、`navigation_routes.gd`、`navigation.gd`。
- `group_chokepoint.gd`、`group_mass_chokepoint.gd`、`group_multiplayer.gd`。
- `extended_systems.gd`、`terrain_selection_follow.gd`、`economy_siege_controls.gd`、`smoke.gd`。
- `performance_navigation.gd`、`performance_400.gd`、`performance_combat.gd`。

其中 12 人、100 人窄口测试均满足全员通过的原有断言。以上为无窗口逻辑验证，未进行可视化手动游玩验证。
