# 四项重构与验证记录

基线为 `23dab46`。四个方向使用独立工作树并行实现，在主分支集成、测试后分别提交并推送。

| 范围 | 结果 | 实现提交 |
| --- | --- | --- |
| 经济、生产与 HUD | 对局变化在事务完成后发布；HUD 合并通知，队列倒计时原位更新，取消按任务身份定位 | `3dc9c39`、`37b8c9c` |
| 输入与动作 | 输入、选择、编组和平台指针分别拥有状态；按钮与快捷键共用动作执行和实时验证 | `317e37f` |
| 单位订单 | 验证后才替换命令；统一启动、结束、恢复、驻军、死亡及淘汰的清理，失效队列目标被跳过 | `76f4be7` |
| 导航 | 分离几何缓存、空间索引和路线调度；预算队列验证结果、保留必要的细网格拐点，并支持暂停与重开 | `e309214` |

旧字段和公共入口代理真实拥有者，继续支持现有场景及调用方。详情见 [架构说明](../scripts/ARCHITECTURE.md)。

## 最终验证

- 默认模式完整集成套件：89/89 个测试通过。
- `RTS_ROUTE_BUDGET=1`：11/11 个重点回归通过。
- 导航边界：58/58 项检查；单位订单：47/47；完整模拟驱动：9/9。
- 96 工人施工：所有建筑完成，96/96 工人在原定 2600 步内结束队列并走出区域；速度及碰撞断言保持。
- 最终长局：模拟 600 秒，达到时代 3、人口上限峰值 110、军队峰值 81，满足严格的时代、人口和军队检查。
- 性能：8 次串行运行通过，两种工作负载分别使用关闭／开启／开启／关闭预算的顺序。预算移动另验证最终抵达。

逐项结果及源码摘要见 [验证数据](refactor-validation.json)。

```sh
python3 tools/check_navigation.py --suite refactor --output /tmp/refactor-checks --timeout 180

RTS_ROUTE_BUDGET=1 python3 tools/check_navigation.py --tests \
  smoke navigation_boundaries navigation_async_poc unit_orders_regression \
  session_rules_regression match_changes player_input_actions_regression \
  group_mass_chokepoint navigation_construction_poc navigation_tasks_poc \
  match_simulation_regression --output /tmp/route-budget-checks --timeout 90
```

手动施工模拟现在每步服务导航任务。长局模拟按固定时间步推进整个场景，并推进真实帧以处理编队、异步寻路、迷雾、野生动物、投射物、延迟通知与删除。经济长局设置为无交战场景，严格要求时代至少达到 3。测试运行器在引擎报告脚本错误或断言失败时保存日志并终止该进程，继续运行下一项。

## 性能取舍与验证范围

寻路预算默认关闭，可通过 `RTS_ROUTE_BUDGET=1` 开启。最终 400 单位拥堵场景的同步平均耗时为 74.2／72.9 ms，预算模式为 62.5／60.0 ms；同一时段移动超过 10 像素的单位分别为 330／330 和 307／314。独立移动场景的预算模式平均耗时较高，单个原生查询最长仍达 132.7 ms，因此 4 ms 是软派发预算，不能保证帧耗时。完整数据与解释见 [导航说明](navigation-boundaries.md) 和 [原始性能数据](battle-overhead/refactor-integrated.json)。

本轮计时使用 headless CPU 模拟，没有测量真实窗口 FPS。`hud_resolution` 的布局断言和 `navigation_range_corner_poc` 的负路径缓存性能断言已在基线复现失败，未计入通过的集成套件。单位快照、农田和地标等像素截图测试需要真实渲染驱动，应另行运行。
