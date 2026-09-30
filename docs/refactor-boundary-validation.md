# 第二轮模块边界重构验证

基线为 `8acc69f`。各项在独立工作树实现，主分支逐项集成，完整测试通过后分别提交与推送。

| 范围 | 完整逻辑回归 | 真实渲染检查 | 结果 |
| --- | --- | --- | --- |
| 经济／生产与玩家状态 | 90/90 | 5/5 | 完成（`972011b`） |
| 导航纯计算内核／局部缓存 | 93/93 | 5/5 | 完成 |

经济／生产服务注入 session 和实体查询，不依赖整个游戏节点；资源／研究／时代／王朝业务写入由 PlayerState 负责。保留旧 game 公共入口及同一资源字典。独立 `match_services` 以 RefCounted 生产者验证折扣、人口预留、队列、退款、市场、时代和文明效果，无需主场景或 HUD。完成后的变化与表现请求在装配层订阅。

新增真实渲染运行入口：

```sh
python3 tools/check_navigation.py --suite refactor --output /tmp/boundary-checks --timeout 180
python3 tools/check_navigation.py --rendering --tests unit_snapshot_rendering filled_polygon_rendering farm_rendering landmark_rendering relic_rendering --output /tmp/rendering-checks --timeout 90
```

渲染检查使用 Apple M2 的 Compatibility/OpenGL 驱动。单位活体／快照图像逐字节相等；多边形比较所有通道差异不超过 1/255；农田、21 座地标和圣物预览可生成。截图统一写入指定的 output 目录，不覆盖仓库预览图。修复了旧单位快照测试夹具缺少 navigation 空字段导致退出订单清理报错的问题，保留原像素等价断言。

基线逻辑89项全部通过，两个已知排除项 HUD resolution 和 range corner 将在各自重构中修复并纳入套件。真实渲染结果不代表游戏窗口 FPS。逐项执行时间及日志位置见 [验证数据](refactor-boundary-validation.json)。

导航内核独立于场景，330 条内核检查与 128 条几何检查通过。range-corner 保留原 45 条断言，起点严格检查从 55 次降到 16 次；移动野生动物按影响范围失效正负缓存，原 wildlife 重试性能阈值保持通过。完整逻辑套件包含这两组新测试和原先排除的 range-corner。同步 A* 和场景碰撞仍可能造成长帧，预算仍是软预算。

预算模式附加检查修复了 group-chokepoint 手动循环漏派发任务的夹具问题，原到达、重整与速度断言保持。单位快照测试改为在读取像素前显式 force_draw，避免无主场景窗口偶发停止发出 frame_post_draw 导致挂起；逐字节图像相等断言保留。
