# Age of Empire Lite

使用 Godot 4.7 制作的 2D 即时战略原型。英格兰和法兰西共用经济、建造、生产与战斗系统。`scripts/game_data.gd` 保存基础数值，`scripts/unit_catalog.gd` 处理文明兵种替换，`scripts/tech_tree.gd` 保存时代与科技要求，`scripts/combat_rules.gd` 计算伤害。画面采用程序绘制的临时图形，无需模型或外部贴图。

## 运行

用 Godot 4 打开 `project.godot`，或在项目目录执行：

```sh
make run
```

如 Godot 安装在其他位置，可执行 `make run GODOT=/你的/Godot/路径`。

## 操作

- 左键选择，拖拽框选，按住 Shift 可追加选择。
- 右键移动、采集、耕作农田或攻击敌人。
- 选择一名或多名村民后在底部选择建筑，再点击地图放置；所有选中的村民会共同施工。
- 施工中断后，选择村民并右键未完工建筑即可继续；追加村民可加快建造。
- 选择建筑训练单位或研究科技；选择城镇中心升级时代。训练、研究和升级共用建筑生产队列；可在选中建筑的队列中取消任务并返还资源。
- 未满足时代、前置科技、人口或资源要求的命令会灰显，并在按钮上说明原因。
- 选中部队后按 1 进入攻击移动模式，再点击地图指定目标；按 2 停止。村民的停止键为 6。混选村民与部队时，攻击移动和停止键分别为 6、7。
- 选择可训练单位的建筑后右键点击地图设置集结点；新训练的单位会自动前往该位置。
- 野外资源点耗尽时，村民会自动转向附近的同类资源点继续采集。
- 每局会生成新地图；顶部显示地图种子。山地、水域不可建造，单位会绕行；鹿群可以作为食物采集。
- 单位和建筑提供视野；未探索区域全黑，探索后失去视野的区域变暗，山地会挡住视线。敌军与鹿群只有在当前视野内才会显示。
- 底部命令网格显示各按钮快捷键；底部中间显示选中对象、生产队列与进度，右下角小地图可点击定位。
- WASD / 方向键、鼠标移到窗口边缘或 Mac 触控板双指滑动可移动镜头，四角可斜向移动；滚轮缩放。
- 按 Esc 打开或关闭暂停菜单；暂停时显示系统鼠标，可移出游戏窗口。
- 摧毁敌人的城镇中心获胜。

## 当前内容

- 四种资源、村民采集、农田、人口上限、多人施工、统一生产队列、四个时代和四项可研究科技。
- 共享兵种分为侦察兵、长矛兵、重装步兵、弓箭手、弩手、轻骑兵与重骑士。英格兰以长弓兵替换弓箭手，法兰西以弩炮手和皇家骑士替换对应兵种。
- 战斗包含轻重甲、近远程护甲、兵种克制、骑兵冲锋、长矛兵驻足反冲锋与飞行中的远程弹体。科技升级会更新已有单位的数值。
- 电脑对手能够采集、升级、研究、建造、根据对方兵种训练部队并进攻。
- 地图由种子生成山地、湖泊、草地、植物群、树林、矿点与鹿群；雨会周期性出现。可用 `start_game("English", 12345)` 复现指定地图。
- 战争迷雾分别记录双方当前视野与探索范围，并同步到主地图、小地图和鼠标目标判定。
- 单位按地形与建筑、资源障碍寻路，并在移动时避开其他单位。目前胜利条件为摧毁城镇中心；多人联机和正式美术资源尚未加入。

## 验证

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/map_generator.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/fog_of_war.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/navigation.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/combat_rules.gd
```
