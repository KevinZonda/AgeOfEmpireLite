# 第二轮模块边界重构验证

基线为 `8acc69f`。各项在独立工作树实现，主分支逐项集成，完整测试通过后分别提交与推送。

| 范围 | 完整逻辑回归 | 真实渲染检查 | 结果 |
| --- | --- | --- | --- |
| 经济／生产与玩家状态 | 90/90 | 5/5 | 完成（`972011b`） |
| 导航纯计算内核／局部缓存 | 93/93 | 5/5 | 完成（`09a6e47`） |
| 玩家命令目录／HUD 表现边界 | 95/95 | 6/6 | 完成（`dce0367`） |
| 对局模拟驱动／时钟 | 96/96 | 6/6 | 完成 |

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

玩家命令目录以无主场景／零 Control 夹具验证执行、资源重查、世代和选择失效、隐藏页、快捷键、年龄选择请求、混合生产者以及释放回调。完整逻辑套件纳入 player-command-catalog 和 hud-resolution；真实渲染额外验证 HUD 在三种分辨率及大字体下的边界。正常 HUD 保留既有 241px 设计，230px 是 minimap 框的独立尺寸；修复大字体时生产区域为隐藏空标签预留额外行的实际溢出。

最终对局驱动完整逻辑 96 项通过，包括 600 模拟秒长对局；组合版本另跑预算模式 11 项与生成地图战斗检查。独立运行时检查覆盖每步恰好一次、同一引擎帧连续 step、出生／销毁边界、重入拒绝、暂停／结束、非法 delta、跨步空间索引及编队 epoch、重开归零与旧箭矢清理。对局保留 caller-controlled delta，没有启用固定步长。完整对局测试与实时游戏共用 game.step，窄单位夹具仍允许直接调用回调。

附加 islands 文明／地图矩阵未完成，不计入通过数：组合版本在 24 × 60 模拟秒矩阵中完成前三个案例，第四个 English/French islands normal seed4242 在 201 秒墙钟时停止；sim 前 `09a6e47` 的相同旧驱动案例也超过 90 秒上限。两者均未见脚本错误，主线程采样显示引擎执行而非等待 worker，但导出模板没有完整符号，无法精确归因或比较相对速度。此诊断证明慢案例已存在，不能证明长期平衡或完整矩阵通过；复杂岛屿同步寻路仍需后续性能工作。

最终真实窗口诊断采用同一 Apple M2/OpenGL 导出模板，80 个长矛兵集中攻击 6 座建筑，额外 8 只鹿，1280×800；每次预热 2 秒后采样 8 秒，顺序 baseline/candidate/candidate/baseline，无并发测试。整轮边界对照 baseline=`972011b`：平均帧耗时 37.25/41.33ms，最终组合为 40.33/50.45ms。进一步隔离模拟层，以 `dce0367` 为 baseline：40.87/32.49ms，最终为 40.81/31.34ms。8 个成功窗口样本均造成建筑伤害；样本波动明显，不能声称整轮 FPS 改善或稳定性能等价。数据全部保留，可作为后续性能工作的基线。

窗口 profile 工具请求 always-on-top，避免被其他窗口遮住时绘制信号停止、计时无法结束；该选项同时作用于 baseline 和 candidate。首次未置顶 baseline 超时的原日志另存 `/tmp/aoelite-refactor-20260930/boundary-live-profile/1-6-baseline.log`，不计入有效性能数据。
