# 第二轮模块边界重构验证

基线为 `8acc69f`。各项在独立工作树实现，主分支逐项集成，完整测试通过后分别提交与推送。

| 范围 | 完整逻辑回归 | 真实渲染检查 | 结果 |
| --- | --- | --- | --- |
| 经济／生产与玩家状态 | 90/90 | 5/5 | 完成 |

经济／生产服务注入 session 和实体查询，不依赖整个游戏节点；资源／研究／时代／王朝业务写入由 PlayerState 负责。保留旧 game 公共入口及同一资源字典。独立 `match_services` 以 RefCounted 生产者验证折扣、人口预留、队列、退款、市场、时代和文明效果，无需主场景或 HUD。完成后的变化与表现请求在装配层订阅。

新增真实渲染运行入口：

```sh
python3 tools/check_navigation.py --suite refactor --output /tmp/boundary-checks --timeout 180
python3 tools/check_navigation.py --rendering --tests unit_snapshot_rendering filled_polygon_rendering farm_rendering landmark_rendering relic_rendering --output /tmp/rendering-checks --timeout 90
```

渲染检查使用 Apple M2 的 Compatibility/OpenGL 驱动。单位活体／快照图像逐字节相等；多边形比较所有通道差异不超过 1/255；农田、21 座地标和圣物预览可生成。截图统一写入指定的 output 目录，不覆盖仓库预览图。修复了旧单位快照测试夹具缺少 navigation 空字段导致退出订单清理报错的问题，保留原像素等价断言。

基线逻辑89项全部通过，两个已知排除项 HUD resolution 和 range corner 将在各自重构中修复并纳入套件。真实渲染结果不代表游戏窗口 FPS。逐项执行时间及日志位置见 [验证数据](refactor-boundary-validation.json)。
