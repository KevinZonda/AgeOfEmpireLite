# Age of Empire Lite

使用 Godot 4.7 制作的 2D 即时战略原型。英格兰、法兰西和中国共用经济、建造、生产与战斗系统。`scripts/catalogs/game_data.gd` 定义兵种模板，`data/aoe4_balance.json` 保存从 [归档资料](docs/aoe4-units/GAME_BALANCE.md) 生成的可玩数值，`scripts/rules/stat_resolver.gd` 合成最终属性，`scripts/catalogs/unit_catalog.gd` 处理文明兵种替换，`scripts/catalogs/tech_tree.gd` 保存时代与科技要求，`scripts/catalogs/landmark_catalog.gd` 保存地标与王朝能力，`scripts/rules/combat_rules.gd` 计算伤害。画面采用程序绘制的临时图形，无需模型或外部贴图。

模块边界和后续拆分顺序见 [架构说明](scripts/ARCHITECTURE.md)。

寻路的路径复用、失败退避、性能计数与对比结果见 [寻路优化与验证](docs/navigation.md)。 绕路、停滞和编队指令故障的复现、修复与测试入口见 [寻路 PoC 报告](docs/navigation-poc/README.md)。

## 运行

完整的环境准备、引擎补丁构建、开发验证与 macOS 发布要求见 [BUILD.md](BUILD.md)。

macOS 使用本地修复版 Godot，解决 Magnet 开启时的按下、拖框延迟，以及 headless 任务使 `launchservicesd` CPU 占用升高的问题。首次在项目目录编译（需要 Xcode 命令行工具和 Python 3），随后正常启动：

```sh
make build-macos
make run
```

本机修复引擎已构建，直接 `make run` 即可。其他平台默认使用 PATH 中的 `godot`；也可执行 `make run GODOT=/你的/Godot/路径` 指定引擎。

补丁位于 `patches/godot-4.7.2-macos-frame-wait.patch`，构建产物位于 `docs/godot/bin/`。macOS 的 120 FPS 上限配合该引擎补丁生效，单独限帧无法修复。Godot 编辑器仍可编辑 `project.godot`；直接使用未打补丁的官方引擎运行时，Magnet 干扰仍可能出现。测量、根因和复现方法见 [输入延迟 POC](docs/input-poc/README.md)。

构建还会应用 `patches/godot-4.7.2-macos-headless-wait.patch`，让无窗口任务正常等待下一帧并跳过 Magnet 查询。下方测试命令统一通过 `make run` 使用本地运行时；空项目复现和回归检查见 [headless 等待 PoC](docs/headless-wait-poc/README.md)。

## 操作

- 左键选择，拖拽框选；双击己方单位可选中屏幕内同类型单位，按住 Shift 可追加选择。
- 右键移动、采集、耕作农田、攻击敌人、维修受损建筑与攻城器械，或进入己方防御建筑；按住 Shift 右键可连续下令。每块农田同时容纳一位村民。农田先播种再收获；村民离开时进度暂停，换人可继续。空田、半播种和已播种的田在 2D／2.5D 视角下都有不同外观，见[农田预览](docs/farm-preview.png)。
- Ctrl+数字键保存编组，数字键选中编组，Shift+数字键追加选择；连续按两次数字键可将镜头移到编组。双击己方建筑可选中屏幕内同类建筑，多选生产建筑后训练命令会向所有合格建筑下达。
- 选择一名或多名村民后在底部切换经济、军营、防御和特殊建造页，再点击地图放置建筑；所有选中的村民会共同施工。Shift 点击可连续放置建筑并排队施工。
- 开始界面和对局设置的国家选择旁均可点击「查看科技树」，在页面内切换国家，按时代浏览各国地标、建筑、兵种和科技，悬停可查看费用与前置要求。开始游戏后可添加至多 4 位玩家，为电脑选择简单／普通／困难强度，并为每位玩家分别选择文明和队伍；同队共享视野及胜负，至少需要两个队伍。右侧可设置地图类型与大小、初始资源及地图种子。村民的「港口与贸易」页可以建造市场、码头、修道院和城门。
- 主界面和暂停菜单的「设置」包含「显示设置」和「操作设置」两个标签页。显示设置可选择窗口化或全屏、窗口分辨率、2D／2.5D 视角、小地图大小，并分别调整界面和文字缩放；单位和建筑的血条可设为「总是」「非满血时显示」（默认）或「变动时显示」（血量变化后显示 3 秒）。「显示 FPS」默认关闭，开启后在游戏界面右上角显示帧率。分辨率的「自动」选项会让窗口使用当前屏幕可用区域的 90%，切换屏幕或下次启动时重新计算，全屏使用屏幕尺寸。界面缩放会按当前分辨率限制可选倍率，文字缩放不改变地图与镜头。操作设置可开关鼠标边缘卷页与触控板双指捏合缩放；保存后立即生效，并在下次启动时保留。
- 窗口、界面、文字与镜头各自的缩放规则见[显示与文字缩放](docs/display-scaling.md)。
- 调整基础字号前，可打开[字体预览页](docs/font-preview.html)，切换界面、分辨率、界面倍率、文字倍率和字体，比较排版并复制字号配置。
- 选中村民选择木墙或石墙后，在地图上拖拽可连续铺设一段城墙；按 R 旋转单段墙或城门。选中已建好的墙可付差价改建城门，己方单位能通行。军队可从相邻己方石门登上石墙；攻城塔靠近敌方石墙后，步兵也可登墙。墙上单位获得远程护甲并可向地面射击。
- 码头只能建在岸边，可训练渔船和战船。渔船右键点击鱼群自动捕鱼；战船只能在水上移动和作战。
- 码头还能训练箭船、弩炮船、火攻船与运输船。弩炮船克制重型船，火攻船接触敌舰后爆炸；选中陆军右键运输船登船，选中载兵运输船右键陆地登陆。选择「群岛」地图可进行跨水域进攻。
- 市场可训练商人。选择商人右键点击中立贸易站后，商人持续往返市场与贸易站，抵达两端都会获得收益；中断后可用「恢复贸易」继续原路线。法兰西商人可选择食物、木材或黄金；市场集结点也可直接设置为贸易站。
- 选中市场可买卖食物、木材和石料；每次交易 100 单位，买卖价格会随交易量变化。顶部「全部队列」或 F 键可查看所有建筑的训练、研究与升级任务，定位建筑或取消并退款。
- 修道院可训练修士。只有修士能占领圣地；敌方部队进入会中断占领。修士右键拾取圣物后会送回修道院，存放的圣物持续产出黄金；修士死亡会掉落携带的圣物。
- 施工中断后，选择村民并右键未完工建筑即可继续；追加村民可加快建造。
- 磨坊、伐木场和采矿场附近的对应采集点有采集加成，相应经济科技在这些建筑内研究。城镇中心的「镇钟」可召回附近村民，随后「返回原工作」恢复先前采集或施工。
- 选择建筑训练单位或研究科技；军事建筑把单位、对应兵种升级和特色科技分组显示，磨坊、伐木场、采矿场分别研究食物、木材、采矿科技。选中村民并切到「地标与奇观」页，点击「升时代」后可比较两座地标的效果与费用，再选择其一放置。村民建成地标后进入下一个时代。训练与研究共用建筑生产队列；可在队列中取消任务并返还资源。
- 中国可在进入新时代后补建该时代的第二座地标，在村民的王朝页选择；两座地标解锁对应王朝加成。
- 中国从唐朝开始，唐朝斥候额外获得 70 视野；宋朝使村民训练加快 20%，元朝使军事单位速度 +8，明朝使军事单位生命值 +15。当前王朝显示在顶部状态栏。
- 文明经济与战术进一步分化：英格兰农田木材成本降低，城镇中心／防御建筑附近可触发城堡网络；法兰西村民与骑兵训练较快，城堡附近的生产建筑有成本优惠，商人可选择回收资源；中国的朝廷命官可监督生产与征税，并提升金矿采集效率。经济科技可提高相应资源的采集速度。
- 未满足时代、前置科技、人口或资源要求的命令会灰显，并在按钮上说明原因。
- 选中部队后按 1 进入攻击移动模式，再点击地图指定目标；按住 Shift 点击可排队多个目标。按 2 停止。村民的下一页和停止键分别为 5、6。
- 部队可用 3 巡逻、4 坚守位置、5 指定集火目标、7 撤退到城镇中心。村民可直接采集无主或敌方羊群；侦察兵接近羊群后也会认领并带回城镇中心，对手能抢夺途中羊群。
- 选中军队可在命令区选择默认、横队、密集、纵队阵型，调整队宽；可设置主动、防御或被动交战。防御交战只短距追击并返回原位，被动交战只响应手动攻击。窄路会临时收队，离开后恢复指定阵型。
- 选中投石车、投石机或火炮可用「攻击地面」持续轰击指定位置。时代 III 起步兵可在野外建造攻城槌和攻城塔，随后进驻其中；攻城塔必须靠墙停稳才能让步兵登墙。
- 多选单位移动时，附近单位组成小队，共用路径并保持稳定位置；点击近处直接平移当前阵形，经过窄路会收成纵队，离开后向目标队形展开。分散的单位与大部队会拆成多个小队；卡住的单位会单独重新寻路。
- 选择可训练单位的建筑后右键点击地图设置集结点；右键点击资源或农田，新训练的村民抵达后会自动采集。
- 城镇中心、哨塔和城堡可驻军并自动射击附近敌人；选中建筑可放出驻军。攻城器械厂可训练攻城槌、攻城塔、弹簧弩炮、轻型投石车、投石机和手推炮；中国用蜂巢炮替代轻型投石车，法兰西用加农炮替代手推炮。
- 野外资源点耗尽时，村民会自动转向附近的同类资源点继续采集。
- 每局会生成新地图，并检查双方起始资源数量与距离。山地不可通行，陆军会绕开水域，船只则在水域航行；鹿会躲避军队，野猪需要击杀后才能采集，鱼群可由渔船采集。高地可扩大视野，潜伏森林能遮蔽其中的单位，近距离侦察可发现他们。
- 地图类型改变路线和争夺重点：平衡图保留开阔中路，山湖和圣地随种子移动；大湖图由三处渡口连接两岸，鱼群分布在河湖水域；高地图由三处山口连接两侧，金矿、石矿和鹿群靠近争夺路线；群岛图需要运输船登上有资源和三处圣地的中央岛。出生点、贸易站及中立资源随地图布局生成。电脑会按文明和地图选择地标、生产顺序与防御位置，在群岛使用本岛贸易站并运送修士登陆。
- 种子 431 的地形与资源预览：[平衡](docs/map-previews/balanced-seed-431.png) · [大湖](docs/map-previews/lakes-seed-431.png) · [高地](docs/map-previews/highlands-seed-431.png) · [群岛](docs/map-previews/islands-seed-431.png)。蓝／红方块是出生点，浅金方块是圣地，紫色方块是贸易站；运行 `tools/render_map_previews.gd` 可重新生成。
- 单位和建筑提供视野；未探索区域全黑，探索后失去视野的区域变暗，山地会挡住视线。敌军与鹿群只有在当前视野内才会显示。
- 底部命令网格显示各按钮快捷键；开局选中城镇中心，信息栏用单位或建筑肖像显示当前对象，并列出生命、护甲、攻击档案、射程与攻击间隔。资源剩余量在鼠标悬停时显示。点击可见的敌方单位可查看其数值，离开视野或隐蔽后面板会清除该单位，小地图也不会泄露隐蔽敌军。顶部显示人口已用／上限（及空余），「空闲村民」按钮或句号键可循环选中空闲村民；右下角小地图可点击定位。
- WASD / 方向键、鼠标移到窗口边缘或 Mac 触控板双指滑动可移动镜头，四角可斜向移动；滚轮缩放，启用缩放手势时可双指捏合缩放。
- 顶部「切换 2.5D」按钮或 V 键可在俯视 2D 与 2:1 菱形等距视角之间切换；两种视角共用同一地图和指令。2.5D 下山体采用共享顶点的连续坡面，包含更高的山峰与山脚缓坡；地图边缘的地面向外延伸并逐渐降平，战争迷雾也沿坡面绘制。单位贴地显示，建筑在坡面上绘出基座，并按深度遮挡。地图文字与血条保持正向，框选沿屏幕矩形生效。镜头可沿屏幕方向移动，滚轮缩放保持鼠标指向的地图位置；2.5D 小地图的菱形可伸出底部面板，显示面积与同档位的 2D 小地图相同，并用旋转后的四角显示当前视野。
- 按 Esc 打开或关闭暂停菜单；暂停时显示系统鼠标，可移出游戏窗口。
- 摧毁敌人的城镇中心及全部已建成地标、占领全部三处圣地并守住 90 秒，或建造奇观并守住 120 秒即可获胜。
- 结束对局后点击「查看战后统计与战局回看」，可查看资源、人口、军队、科技与地图控制的时间曲线，并从关键事件跳到对应时间。战局回看每 5 秒记录一次双方单位与建筑状态，可播放或拖动时间轴。

## 当前内容

- 四种资源、村民采集、农田、人口上限、多人施工、训练与研究队列、四个时代、文明地标、兵种等级与铁匠铺科技。
- 共享兵种分为侦察兵、长矛兵、重装步兵、弓箭手、弩手、轻骑兵与重骑士。英格兰以长弓兵替换弓箭手，法兰西以弩炮手和皇家骑士替换对应兵种；中国保留普通弓箭手，王朝解锁诸葛弩、火长矛骑兵和掷弹兵。
- 战斗按攻击档案处理目标加成、多段伤害、近远程护甲、攻城器械远程减伤、穿透、冲锋与范围伤害。长弓兵可架设拒马或发动万箭齐发；法兰西弩炮手可部署大盾，军学院火炮可使用炮击齐射；战船可短时加速，携圣物修士可招降敌军并治疗友军。英格兰侦察兵可花木材建预备营地。科技升级会更新已有单位的数值。
- 地标可直接生产、研究、驻军、防御、积累资源或侦察；中国第二座地标解锁王朝。未满足要求的兵种和科技继续显示在面板并说明原因。
- 电脑对手能够采集、选择并建造地标升级、研究、建造、根据视野内敌军兵种训练部队。村民目标随时代增长，闲置工人按当前采集人数和资源缺口分配；资源点耗尽时会寻找其他可达资源并派村民探索。城堡时代优先保留木材建造攻城器械厂、攻城槌和修道院，再扩建兵营、靶场和马厩。军队会在基地防守、低血量撤退、骑兵袭击可见村民、集结后成波进攻之间切换；攻城槌主动攻击建筑，卡住的攻击会重新选路，修士分别前往可达的圣地，军队会支援争夺中的圣地。简单／普通／困难使用不同的村民目标、出兵门槛、升时代时机和思考间隔；长局中会继续建房与农田，资源不足时通过市场交易，并为升时代保留资源。卡住的施工会更换工人或重新选址。
- 地图由种子生成山地、湖泊、草地、植物群、树林、矿点与鹿群；雨会周期性出现。可用 `start_game("English", 12345)` 复现指定地图。
- 英格兰电脑优先组织长弓与山口防御，法兰西电脑在开阔图优先马厩、在水道图优先贸易，按库存调整商人运回的资源，并会采石建城堡；中国电脑选择适合地形的地标、训练朝廷命官并在唐朝获得更宽的斥候视野。文明优势来自现有建筑、兵种和地标机制，不随地图直接改写兵种属性。
- 地图还生成鱼群、中立贸易站与圣物；标准地图为 2400×2400，大型地图为 3000×3000，支持四种地形类型。陆军、水军分别寻路，港口生产水军。
- 市场贸易、修士占领圣地与存放圣物、拖拽式连续墙段和可通行城门均已接入玩家与电脑对局。
- 战争迷雾分别记录各玩家当前视野与探索范围，同队共享当前视野，并同步到主地图、小地图和鼠标目标判定。
- 单位按地形与建筑、资源障碍寻路，并在移动时避开其他单位。群体移动按小队复用路径，窄路采用纵队；战斗还包含攻城器械、建筑驻军与自动防御。当前多人局由一名玩家和多名电脑参加；真人网络联机尚未加入。
- 大军分队、近敌搜索、防御建筑寻敌与隐蔽检测使用空间索引；单位碰撞只检查接触到的地形格，编队拥挤时降低绕行探测频率。`tests/performance_400.gd` 提供 400 单位无渲染 CPU 基准，`tests/performance_visible.gd` 在真实窗口测量 400 个可见移动单位的中位与 95 分位帧时间。开发目标是 400 单位 30 Hz 模拟每步不超过 40 ms、群体命令不超过 250 ms；可见窗口帧率仍受密集碰撞影响，需要在目标设备上持续测量。

## 验证

首次克隆后先用 Godot 打开项目，或执行 `Godot --headless --editor --path . --quit` 注册 GDScript 全局类，再运行下列独立脚本。

```sh
make run RUN_ARGS='--headless --script res://tests/smoke.gd'
make run RUN_ARGS='--headless --script res://tests/selection.gd'
make run RUN_ARGS='--headless --script res://tests/isometric_view.gd'
make run RUN_ARGS='--headless --script res://tests/tech_tree_page.gd'
make run RUN_ARGS='--headless --script res://tests/chinese.gd'
make run RUN_ARGS='--headless --script res://tests/extended_systems.gd'
make run RUN_ARGS='--headless --script res://tests/map_generator.gd'
make run RUN_ARGS='--headless --script res://tests/fog_of_war.gd'
make run RUN_ARGS='--headless --script res://tests/navigation.gd'
make run RUN_ARGS='--headless --script res://tests/group_multiplayer.gd'
make run RUN_ARGS='--headless --script res://tests/group_chokepoint.gd'
make run RUN_ARGS='--headless --script res://tests/group_mass_chokepoint.gd'
make run RUN_ARGS='--headless --script res://tests/combat_rules.gd'
make run RUN_ARGS='--headless --script res://tests/balance_system.gd'
make run RUN_ARGS='--headless --script res://tests/landmark_catalog.gd'
make run RUN_ARGS='--headless --script res://tests/landmark_roles.gd'
make run RUN_ARGS='--headless --script res://tests/siege_rules.gd'
make run RUN_ARGS='--headless --script res://tests/objectives.gd'
make run RUN_ARGS='--headless --script res://tests/strategic_expansion.gd'
make run RUN_ARGS='--headless --script res://tests/ai_long_match.gd'
make run RUN_ARGS='--headless --script res://tests/ai_tactics.gd'
make run RUN_ARGS='--headless --script res://tests/balance_multiseed.gd'
RTS_BALANCE_MATRIX=1 RTS_BALANCE_SECONDS=180 make run RUN_ARGS='--headless --script res://tests/balance_multiseed.gd'
make run RUN_ARGS='--headless --script res://tests/aoe4_requested_systems.gd'
make run RUN_ARGS='--headless --script res://tests/battle_experience.gd'
RTS_BENCH_UNITS=200 make run RUN_ARGS='--headless --script res://tests/performance_400.gd'
make run RUN_ARGS='--headless --script res://tests/performance_400.gd'
make run RUN_ARGS='--headless --script res://tests/performance_combat.gd'
make run RUN_ARGS='--headless --script res://tests/map_fairness.gd'
make run RUN_ARGS='--headless --script res://tests/map_strategy.gd'
make run RUN_ARGS='--headless --script res://tests/island_ai_strategy.gd'
make run RUN_ARGS='--headless --script res://tests/civ_map_ai.gd'
make run RUN_ARGS='--headless --script res://tests/economy_siege_controls.gd'
RTS_BENCH_PROJECTION=2d make run RUN_ARGS='--script res://tests/performance_visible.gd --windowed --resolution 1280x720'
RTS_BENCH_PROJECTION=2.5d make run RUN_ARGS='--script res://tests/performance_visible.gd --windowed --resolution 1280x720'
```

`RTS_BALANCE_MATRIX=1` 覆盖三个文明两两对战及出生边互换、四种地图和三档难度，共 24 局。`RTS_BALANCE_SEEDS` 可指定逗号分隔的地图种子，`RTS_BALANCE_SECONDS` 设置每局模拟时长，`RTS_BALANCE_TRACE=1` 每 60 秒输出经济与建筑追踪。脚本会推进迷雾和导航更新，并汇总胜负、时代、军队、攻城、圣地及地图出生点公平性。
