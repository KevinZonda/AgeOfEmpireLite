# 代码架构与状态所有权

主场景 `scenes/main.tscn` 由 `scripts/game.gd` 装配。主脚本负责启动／结束对局、输入分发和系统调度，公开字段与方法保留兼容入口。已迁移的字段通过 getter／setter 访问实际拥有者，不维护另一份可变状态。

| 模块 | 实际职责与状态 |
| --- | --- |
| `match/match_session.gd` | 玩家、队伍、文明、地图参数与对局运行状态 |
| `match/player_state.gd` | 玩家资源与研究；`bank` 和兼容 `game.players` 指向同一字典 |
| `match/entity_registry.gd` | 单位、建筑、资源、贸易站与圣物集合；创建、移除、重开及玩家淘汰 |
| `match/match_economy.gd` / `match_production.gd` | 经济、生产与退款事务；生产队列由建筑拥有 |
| `match/match_changes.gd` | 事务结束后的状态变化与反馈通知；嵌套事务合并发布，不持有界面 |
| `rules/action_availability.gd` | 建造、训练、研究等公共验证与费用；UI 读取结果，事务执行前再次验证 |
| `player/context_order.gd` | 右键目标与命令优先级；鼠标提示和实际命令共享分类 |
| `player/player_selection.gd` / `player_orders.gd` | 选择及编组的状态所有权、可见性清理与下令 |
| `player/player_input.gd` / `platform_pointer.gd` | 输入路由、互斥操作模式、拖框及镜头控制；平台鼠标适配独立 |
| `player/player_actions.gd` | 按钮与快捷键共享动作入口，执行时重验可用性及选择世代，不依赖按钮实例 |
| `entities/unit.gd` / `unit_orders.gd` | 单位协调入口与订单所有权；统一命令验证、切换、结束、恢复和行为分派 |
| `entities/unit_movement.gd` | 路线、异步请求世代、编队、巡逻、驻守与冲锋状态 |
| `entities/unit_abilities.gd` | 技能及状态计时器；验证结果同时供 UI 和技能执行使用 |
| `entities/unit_stats.gd` / `rules/stat_resolver.gd` | 属性及临时加成；攻击 profiles 为战斗数值源，旧 damage／range 等只作兼容投影 |
| `ai/ai_snapshot.gd` / `economy_plan.gd` / `ai_profile.gd` | 每次思考的实体／队列计数、资源预留与难度配置 |
| `ui/game_hud_ui.gd` / `game_menu_ui.gd` | 各自拥有控件；通过请求信号调用游戏动作 |
| `ui/settings_store.gd` / `display_settings.gd` | 偏好读写与兼容旧配置；窗口状态与自适应尺寸检查 |
| `ui/match_report_ui.gd` / `unit_stat_text.gd` | 战报／回放界面；HUD 和单位图鉴共享攻击属性文字 |
| `entities/visuals/*_visual.gd` / `*_visual_state.gd` | 绘制和视觉快照；不依赖生产、订单或活实体 |
| `world/world_map.gd` / `world_map_renderer.gd` | 公共地形生成阶段、完整地图后续生成与地形绘制 |
| `world/navigation.gd` | 导航兼容入口与碰撞／路线查询；装配缓存、空间索引和调度器 |
| `world/navigation_cache.gd` / `navigation_spatial_index.gd` | 静态网格、连通分量、几何版本及动态实体索引，各自拥有缓存状态 |
| `world/navigation_route_jobs.gd` / `navigation_jobs.gd` | 普通／射程主线程路线预算与异步拥堵恢复；取消、验证及结果回收 |
| `world/fog_of_war.gd` | 迷雾；建筑记忆使用显示节点和冻结快照 |

## 边界约定

- `game.session` 拥有对局状态，`game.players`、`game.units` 等旧接口只作代理。正常实体创建使用注册表；实体离开场景树时自动注销。淘汰和普通摧毁仍分别保留各自的游戏规则与反馈。
- 经济与生产通过 `session.changes` 发布资源、生产、研究等变化。训练／研究的扣费和入队、取消退款在同一事务结束后发布；HUD 合并同一帧通知，读取最终状态。反馈由游戏装配层订阅并显示。周期刷新继续覆盖进度与兼容字典写入。全局队列只有结构变化才重建控件，倒计时原位更新。HUD 更新不修改选择；迷雾更新和玩家选择系统维护选择有效性。
- 建筑的 `production_queue` 是任务的唯一数据源，人口预留、研究去重、命官上限、AI 和 HUD 都据此判断。公共验证返回 `{available, reason, cost}`，执行时不信任较早的 UI 判断。
- 输入状态和选择状态分别由 `player_input` 和 `player_selection` 拥有；`game` 兼容字段代理实际拥有者。建造和目标模式互斥。动作在命令面板重建后更新世代，旧选择、旧按钮和隐藏页动作不可执行；快捷键直接调用动作注册表，按钮可用性只是显示投影。
- `unit.orders` 拥有当前订单、目标、恢复订单与队列；公开命令先验证，再清空或切换。排队命令启动时再次验证活目标和工作条件，失效命令跳过。结束、自动交战恢复、驻军、死亡和淘汰共用取消路径／能力的生命周期入口。
- 单位旧移动／技能字段代理组件。新命令、停止与驻扎统一取消旧异步路线和临时命令状态；无效命令先拒绝，保留正在执行的命令。
- 导航缓存和空间索引分别拥有静态及动态状态，兼容字典共享原实例。普通／射程路线预算默认关闭，可用 `RTS_ROUTE_BUDGET=1` 启用；FIFO 请求保留排队顺序，接收前验证单位、订单世代、目标与几何版本。预算为主线程软上限，单次原生查询不能抢占。暂停仍回收异步完成结果，但不派发新查询；重开与退出统一关闭两类任务。手动模拟须调用 `tick_jobs(true, simulation_frame)`，只调用单位 `_process` 不构成完整游戏帧。
- 属性每次从定义、研究、文明和临时效果重新解析。模拟通过 profile 查询攻击值；兼容字段不得反向覆盖 profile。
- AI 快照只存活于一次思考，包含已排队单位，并在同一轮成功训练或建造后更新。快照不成为跨帧缓存；资源规划保留原有决策优先级。
- `generate_terrain()` 为完整生成与地图预览共同使用的阶段；完整生成按原顺序继续消费 RNG，预览不调用私有生成步骤。
- 实体绘制可复用工作快照，迷雾记忆必须另建独立快照。快照不保留活实体；镜头、投影与显示偏好可更新，记忆中的生命／建造等信息保持发现时的值。
- 单位预览与建筑记忆均为轻量显示节点，不注册进对局。静态 UI 结构／样式由 `scenes/ui/` 和 `assets/ui/game_theme.tres` 提供，动态数据由界面模块填入。

## 验证

```sh
python3 tools/check_navigation.py --suite refactor --output /tmp/refactor-checks
```

默认仍只运行导航回归；`--tests` 可指定子集。集成套件覆盖对局状态、共享规则、单位命令与技能、UI、AI、地图、迷雾及导航。`unit_snapshot_rendering`、农田／地标等截图测试需要真实渲染驱动，应单独运行。`hud_resolution` 的布局断言及 `navigation_range_corner_poc` 的负路径缓存性能断言在基线中也失败，单独记录，不归入通过的集成套件。需直接加载字体的 PoC 还需要引擎生成的字体导入缓存。

性能比较使用相同引擎和固定种子的 `performance_navigation`／`performance_400`，交替运行基线和重构版本；CPU 模拟耗时与真实渲染帧率分别判断。

进一步删除兼容字段前，应先迁移直接访问这些字段的调用方和测试。输入／快捷键、选择状态已迁移到玩家模块；旧入口仅作为场景与测试适配。
