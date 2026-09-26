# Age of Empire Lite

使用 Godot 4.7 制作的 2D 即时战略原型。英格兰、法兰西和中国共用经济、建造、生产与战斗系统。`scripts/game_data.gd` 保存基础数值，`scripts/unit_catalog.gd` 处理文明兵种替换，`scripts/tech_tree.gd` 保存时代与科技要求，`scripts/landmark_catalog.gd` 保存地标与王朝加成，`scripts/combat_rules.gd` 计算伤害。画面采用程序绘制的临时图形，无需模型或外部贴图。

## 运行

用 Godot 4 打开 `project.godot`，或在项目目录执行：

```sh
make run
```

如 Godot 安装在其他位置，可执行 `make run GODOT=/你的/Godot/路径`。

## 操作

- 左键选择，拖拽框选；双击己方单位可选中屏幕内同类型单位，按住 Shift 可追加选择。
- 右键移动、采集、耕作农田、攻击敌人或进入己方防御建筑；按住 Shift 右键可连续下令。
- 选择一名或多名村民后在底部切换经济、军营、防御和特殊建造页，再点击地图放置建筑；所有选中的村民会共同施工。Shift 点击可连续放置建筑并排队施工。
- 开局可选择标准或大型地图、平衡／大湖／高地地形，并可输入地图种子复现同一局。村民的新「港口与贸易」页可以建造市场、码头、修道院和城门。
- 选中村民选择木墙或石墙后，在地图上拖拽可连续铺设一段城墙；按 R 旋转单段墙或城门。选中已建好的墙可付差价改建城门，己方单位能通行，敌军需要破门或绕路。
- 码头只能建在岸边，可训练渔船和战船。渔船右键点击鱼群自动捕鱼；战船只能在水上移动和作战。
- 市场可训练商人。选择商人右键点击中立贸易站后，商人持续往返市场与贸易站，每次返回市场获得黄金；市场的集结点也可直接设置为贸易站。
- 修道院可训练修士。只有修士能占领圣地；敌方部队进入会中断占领。修士右键拾取圣物后会送回修道院，存放的圣物持续产出黄金；修士死亡会掉落携带的圣物。
- 施工中断后，选择村民并右键未完工建筑即可继续；追加村民可加快建造。
- 选择建筑训练单位或研究科技；选中城镇中心或村民的特殊建造页，可在两个文明地标中选择其一并放置。村民建成地标后进入下一个时代，启用对应文明加成。训练与研究共用建筑生产队列；可在队列中取消任务并返还资源。
- 中国可在进入新时代后补建该时代的第二座地标，在村民的王朝页选择；两座地标解锁对应王朝加成。
- 中国村民建造速度提高 15%；宋朝使村民训练加快 20%，元朝使军事单位速度 +8，明朝使军事单位生命值 +15。当前王朝显示在顶部状态栏。
- 未满足时代、前置科技、人口或资源要求的命令会灰显，并在按钮上说明原因。
- 选中部队后按 1 进入攻击移动模式，再点击地图指定目标；按住 Shift 点击可排队多个目标。按 2 停止。村民的下一页和停止键分别为 5、6。
- 选择可训练单位的建筑后右键点击地图设置集结点；右键点击资源或农田，新训练的村民抵达后会自动采集。
- 城镇中心、哨塔和城堡可驻军并自动射击附近敌人；选中建筑可放出驻军。攻城器械厂可训练攻城槌和投石机。
- 野外资源点耗尽时，村民会自动转向附近的同类资源点继续采集。
- 每局会生成新地图；顶部显示地图种子。山地不可通行，陆军会绕开水域，船只则在水域航行；鹿群与鱼群都可采集食物。
- 单位和建筑提供视野；未探索区域全黑，探索后失去视野的区域变暗，山地会挡住视线。敌军与鹿群只有在当前视野内才会显示。
- 底部命令网格显示各按钮快捷键；底部中间显示选中对象、生产队列与进度，右下角小地图可点击定位。
- WASD / 方向键、鼠标移到窗口边缘或 Mac 触控板双指滑动可移动镜头，四角可斜向移动；滚轮缩放。
- 按 Esc 打开或关闭暂停菜单；暂停时显示系统鼠标，可移出游戏窗口。
- 摧毁敌人的城镇中心及全部已建成地标、占领全部三处圣地并守住 90 秒，或建造奇观并守住 120 秒即可获胜。

## 当前内容

- 四种资源、村民采集、农田、人口上限、多人施工、训练与研究队列、四个时代、文明地标与四项可研究科技。
- 共享兵种分为侦察兵、长矛兵、重装步兵、弓箭手、弩手、轻骑兵与重骑士。英格兰以长弓兵替换弓箭手，法兰西以弩炮手和皇家骑士替换对应兵种，中国有诸葛弩与宫廷卫士。
- 战斗包含轻重甲、近远程护甲、兵种克制、骑兵冲锋、长矛兵驻足反冲锋与飞行中的远程弹体。科技升级会更新已有单位的数值。
- 电脑对手能够采集、选择并建造地标升级、研究、建造、根据对方兵种训练部队并进攻。
- 地图由种子生成山地、湖泊、草地、植物群、树林、矿点与鹿群；雨会周期性出现。可用 `start_game("English", 12345)` 复现指定地图。
- 地图还生成鱼群、中立贸易站与圣物；地图生成器支持两种尺寸和三种地形侧重。陆军、水军分别寻路，港口生产水军。
- 市场贸易、修士占领圣地与存放圣物、拖拽式连续墙段和可通行城门均已接入玩家与电脑对局。
- 战争迷雾分别记录双方当前视野与探索范围，并同步到主地图、小地图和鼠标目标判定。
- 单位按地形与建筑、资源障碍寻路，并在移动时避开其他单位。战斗还包含攻城器械、建筑驻军与自动防御；地图目标包含圣地和奇观。多人联机和正式美术资源尚未加入。

## 验证

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/selection.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/chinese.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/extended_systems.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/map_generator.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/fog_of_war.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/navigation.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/combat_rules.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/landmark_catalog.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/siege_rules.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/objectives.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/chinese.gd
```
