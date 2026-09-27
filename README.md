# Age of Empire Lite

使用 Godot 4.7 制作的 2D 即时战略原型。英格兰、法兰西和中国共用经济、建造、生产与战斗系统。`scripts/game_data.gd` 定义兵种模板，`data/aoe4_balance.json` 保存从 [归档资料](docs/aoe4-units/GAME_BALANCE.md) 生成的可玩数值，`scripts/stat_resolver.gd` 合成最终属性，`scripts/unit_catalog.gd` 处理文明兵种替换，`scripts/tech_tree.gd` 保存时代与科技要求，`scripts/landmark_catalog.gd` 保存地标与王朝能力，`scripts/combat_rules.gd` 计算伤害。画面采用程序绘制的临时图形，无需模型或外部贴图。

## 运行

用 Godot 4 打开 `project.godot`，或在项目目录执行：

```sh
make run
```

如 Godot 安装在其他位置，可执行 `make run GODOT=/你的/Godot/路径`。

## 操作

- 左键选择，拖拽框选；双击己方单位可选中屏幕内同类型单位，按住 Shift 可追加选择。
- 右键移动、采集、耕作农田、攻击敌人、维修受损建筑与攻城器械，或进入己方防御建筑；按住 Shift 右键可连续下令。每块农田同时容纳一位村民。
- Ctrl+数字键保存编组，数字键选中编组，Shift+数字键追加选择；连续按两次数字键可将镜头移到编组。双击己方建筑可选中屏幕内同类建筑，多选生产建筑后训练命令会向所有合格建筑下达。
- 选择一名或多名村民后在底部切换经济、军营、防御和特殊建造页，再点击地图放置建筑；所有选中的村民会共同施工。Shift 点击可连续放置建筑并排队施工。
- 主界面点击「开始游戏」进入对局设置。左侧可添加至多 4 位玩家，为电脑选择简单／普通／困难强度，并为每位玩家分别选择文明和队伍；选定国家后可点击「查看科技树」，按时代浏览该国地标、建筑、兵种和科技，悬停可查看费用与前置要求。同队共享视野及胜负，至少需要两个队伍。右侧可设置地图类型与大小、初始资源及地图种子。村民的「港口与贸易」页可以建造市场、码头、修道院和城门。
- 主界面和暂停菜单的「设置」包含「显示设置」和「操作设置」两个标签页。显示设置可选择窗口分辨率与 2D／2.5D 视角；高于当前显示器可用尺寸的分辨率不会显示。操作设置可开关鼠标边缘卷页与触控板双指捏合缩放；保存后立即生效，并在下次启动时保留。
- 选中村民选择木墙或石墙后，在地图上拖拽可连续铺设一段城墙；按 R 旋转单段墙或城门。选中已建好的墙可付差价改建城门，己方单位能通行。军队可从相邻己方石门登上石墙；攻城塔靠近敌方石墙后，步兵也可登墙。墙上单位获得远程护甲并可向地面射击。
- 码头只能建在岸边，可训练渔船和战船。渔船右键点击鱼群自动捕鱼；战船只能在水上移动和作战。
- 码头还能训练箭船、弩炮船、火攻船与运输船。弩炮船克制重型船，火攻船接触敌舰后爆炸；选中陆军右键运输船登船，选中载兵运输船右键陆地登陆。选择「群岛」地图可进行跨水域进攻。
- 市场可训练商人。选择商人右键点击中立贸易站后，商人持续往返市场与贸易站，抵达两端都会获得收益；中断后可用「恢复贸易」继续原路线。法兰西商人可选择食物、木材或黄金；市场集结点也可直接设置为贸易站。
- 选中市场可买卖食物、木材和石料；每次交易 100 单位，买卖价格会随交易量变化。顶部「全部队列」或 F 键可查看所有建筑的训练、研究与升级任务，定位建筑或取消并退款。
- 修道院可训练修士。只有修士能占领圣地；敌方部队进入会中断占领。修士右键拾取圣物后会送回修道院，存放的圣物持续产出黄金；修士死亡会掉落携带的圣物。
- 施工中断后，选择村民并右键未完工建筑即可继续；追加村民可加快建造。
- 磨坊、伐木场和采矿场附近的对应采集点有采集加成，相应经济科技在这些建筑内研究。城镇中心的「镇钟」可召回附近村民，随后「返回原工作」恢复先前采集或施工。
- 选择建筑训练单位或研究科技；选中城镇中心或村民的特殊建造页，可在两个文明地标中选择其一并放置。村民建成地标后进入下一个时代，启用对应文明加成。训练与研究共用建筑生产队列；可在队列中取消任务并返还资源。
- 中国可在进入新时代后补建该时代的第二座地标，在村民的王朝页选择；两座地标解锁对应王朝加成。
- 中国村民建造速度提高 15%；宋朝使村民训练加快 20%，元朝使军事单位速度 +8，明朝使军事单位生命值 +15。当前王朝显示在顶部状态栏。
- 文明经济与战术进一步分化：英格兰农田木材成本降低，城镇中心／防御建筑附近可触发城堡网络；法兰西村民与骑兵训练较快，城堡附近的生产建筑有成本优惠，商人可选择回收资源；中国的朝廷命官可监督生产与征税，并提升金矿采集效率。经济科技可提高相应资源的采集速度。
- 未满足时代、前置科技、人口或资源要求的命令会灰显，并在按钮上说明原因。
- 选中部队后按 1 进入攻击移动模式，再点击地图指定目标；按住 Shift 点击可排队多个目标。按 2 停止。村民的下一页和停止键分别为 5、6。
- 部队可用 3 巡逻、4 坚守位置、5 指定集火目标、7 撤退到城镇中心。开局侦察兵接近中立羊群后会认领羊群，带回城镇中心交给村民采集；对手也能抢夺途中羊群。
- 选中军队可在命令区选择默认、横队、密集、纵队阵型，调整队宽；可设置主动、防御或被动交战。防御交战只短距追击并返回原位，被动交战只响应手动攻击。窄路会临时收队，离开后恢复指定阵型。
- 选中投石车、投石机或火炮可用「攻击地面」持续轰击指定位置。时代 III 起步兵可在野外建造攻城槌和攻城塔，随后进驻其中；攻城塔必须靠墙停稳才能让步兵登墙。
- 多选单位移动时，附近单位组成小队，共用路径并保持稳定位置；点击近处直接平移当前阵形，经过窄路会收成纵队，离开后向目标队形展开。分散的单位与大部队会拆成多个小队；卡住的单位会单独重新寻路。
- 选择可训练单位的建筑后右键点击地图设置集结点；右键点击资源或农田，新训练的村民抵达后会自动采集。
- 城镇中心、哨塔和城堡可驻军并自动射击附近敌人；选中建筑可放出驻军。攻城器械厂可训练攻城槌、攻城塔、弹簧弩炮、轻型投石车、投石机和手推炮；中国用蜂巢炮替代轻型投石车，法兰西用加农炮替代手推炮。
- 野外资源点耗尽时，村民会自动转向附近的同类资源点继续采集。
- 每局会生成新地图，并检查双方起始资源数量与距离。山地不可通行，陆军会绕开水域，船只则在水域航行；鹿会躲避军队，野猪需要击杀后才能采集，鱼群可由渔船采集。高地可扩大视野，潜伏森林能遮蔽其中的单位，近距离侦察可发现他们。
- 单位和建筑提供视野；未探索区域全黑，探索后失去视野的区域变暗，山地会挡住视线。敌军与鹿群只有在当前视野内才会显示。
- 底部命令网格显示各按钮快捷键；开局选中城镇中心，信息栏用单位或建筑肖像显示当前对象，并列出生命、护甲、攻击档案、射程与攻击间隔。资源剩余量在鼠标悬停时显示。点击可见的敌方单位可查看其数值，离开视野或隐蔽后面板会清除该单位，小地图也不会泄露隐蔽敌军。顶部显示人口已用／上限（及空余），「空闲村民」按钮或句号键可循环选中空闲村民；右下角小地图可点击定位。
- WASD / 方向键、鼠标移到窗口边缘或 Mac 触控板双指滑动可移动镜头，四角可斜向移动；滚轮缩放，启用缩放手势时可双指捏合缩放。
- 顶部「切换 2.5D」按钮或 V 键可在俯视 2D 与 2:1 菱形等距视角之间切换；两种视角共用同一地图和指令。2.5D 下山体采用共享顶点的连续坡面，包含更高的山峰与山脚缓坡；地图边缘的地面向外延伸并逐渐降平，战争迷雾也沿坡面绘制。单位贴地显示，建筑在坡面上绘出基座，并按深度遮挡。地图文字与血条保持正向，框选沿屏幕矩形生效。镜头可沿屏幕方向移动，滚轮缩放保持鼠标指向的地图位置，小地图用旋转后的四角显示当前视野。
- 按 Esc 打开或关闭暂停菜单；暂停时显示系统鼠标，可移出游戏窗口。
- 摧毁敌人的城镇中心及全部已建成地标、占领全部三处圣地并守住 90 秒，或建造奇观并守住 120 秒即可获胜。
- 结束对局后点击「查看战后统计与战局回看」，可查看资源、人口、军队、科技与地图控制的时间曲线，并从关键事件跳到对应时间。战局回看每 5 秒记录一次双方单位与建筑状态，可播放或拖动时间轴。

## 当前内容

- 四种资源、村民采集、农田、人口上限、多人施工、训练与研究队列、四个时代、文明地标、兵种等级与铁匠铺科技。
- 共享兵种分为侦察兵、长矛兵、重装步兵、弓箭手、弩手、轻骑兵与重骑士。英格兰以长弓兵替换弓箭手，法兰西以弩炮手和皇家骑士替换对应兵种；中国保留普通弓箭手，王朝解锁诸葛弩、火长矛骑兵和掷弹兵。
- 战斗按攻击档案处理目标加成、多段伤害、近远程护甲、攻城器械远程减伤、穿透、冲锋与范围伤害。长弓兵可架设拒马或发动万箭齐发；法兰西弩炮手可部署大盾，军学院火炮可使用炮击齐射；战船可短时加速，携圣物修士可招降敌军并治疗友军。英格兰侦察兵可花木材建预备营地。科技升级会更新已有单位的数值。
- 地标可直接生产、研究、驻军、防御、积累资源或侦察；中国第二座地标解锁王朝。未满足要求的兵种和科技继续显示在面板并说明原因。
- 电脑对手能够采集、选择并建造地标升级、研究、建造、根据视野内敌军兵种训练部队。村民目标随时代增长，闲置工人按当前采集人数和资源缺口分配；城堡时代起可扩建多座兵营、靶场和马厩。军队会在基地防守、低血量撤退、骑兵袭击可见村民、集结后成波进攻之间切换。简单／普通／困难使用不同的村民目标、出兵门槛、升时代时机和思考间隔；长局中会继续建房与农田，资源不足时通过市场交易，并为升时代保留资源。卡住的施工会更换工人或重新选址。
- 地图由种子生成山地、湖泊、草地、植物群、树林、矿点与鹿群；雨会周期性出现。可用 `start_game("English", 12345)` 复现指定地图。
- 地图还生成鱼群、中立贸易站与圣物；标准地图为 2400×2400，大型地图为 3000×3000，支持四种地形类型。陆军、水军分别寻路，港口生产水军。
- 市场贸易、修士占领圣地与存放圣物、拖拽式连续墙段和可通行城门均已接入玩家与电脑对局。
- 战争迷雾分别记录各玩家当前视野与探索范围，同队共享当前视野，并同步到主地图、小地图和鼠标目标判定。
- 单位按地形与建筑、资源障碍寻路，并在移动时避开其他单位。群体移动按小队复用路径，窄路采用纵队；战斗还包含攻城器械、建筑驻军与自动防御。当前多人局由一名玩家和多名电脑参加；真人网络联机尚未加入。
- 大军分队、近敌搜索、防御建筑寻敌与隐蔽检测使用空间索引；单位碰撞只检查接触到的地形格，编队拥挤时降低绕行探测频率。`tests/performance_400.gd` 提供 400 单位无渲染 CPU 基准，`tests/performance_visible.gd` 在真实窗口测量 400 个可见移动单位的中位与 95 分位帧时间。开发目标是 400 单位 30 Hz 模拟每步不超过 40 ms、群体命令不超过 250 ms；可见窗口帧率仍受密集碰撞影响，需要在目标设备上持续测量。

## 验证

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/selection.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/isometric_view.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/tech_tree_page.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/chinese.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/extended_systems.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/map_generator.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/fog_of_war.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/navigation.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/group_multiplayer.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/group_chokepoint.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/group_mass_chokepoint.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/combat_rules.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/balance_system.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/landmark_catalog.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/landmark_roles.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/siege_rules.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/objectives.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/strategic_expansion.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/ai_long_match.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/ai_tactics.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/balance_multiseed.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/aoe4_requested_systems.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/battle_experience.gd
RTS_BENCH_UNITS=200 /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance_400.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/performance_400.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/map_fairness.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/economy_siege_controls.gd
RTS_BENCH_PROJECTION=2d /Applications/Godot_mono.app/Contents/MacOS/Godot --path . --script res://tests/performance_visible.gd --windowed --resolution 1280x720
RTS_BENCH_PROJECTION=2.5d /Applications/Godot_mono.app/Contents/MacOS/Godot --path . --script res://tests/performance_visible.gd --windowed --resolution 1280x720
```
