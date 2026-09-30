# 渔船重做

渔船改为共享的局部立体模型，战场、单位预览与选中头像使用同一船体。2D 俯视和 2.5D 斜视分别投影，船头、甲板、帆、渔夫、鱼篓、舵与渔网随八方向航向转动并按深度遮挡。

- [重做前](before.png)：旧船体、固定朝向与大块地面阴影。
- [重做后总览](overview.png)：两种视角，正常 1× 和放大 3.3×，左右航向对照。
- [八方向](directions.png)：两种投影下的八方向船头与前后遮挡。
- [动作](motion.png)：停泊、航行、撒网、网在水中、提网和收网。
- [头像](portrait.png)：102×142、80×110 与 160×180 尺寸。
- [实际地图 2D](in-game-2d.png)、[实际地图 2.5D](in-game-25d.png)：真实码头与鱼群附近的作业和航行渔船。

船帮降低，露出木板甲板；米白布帆保留帆缝、桅杆与绳索，蓝色旗帜和衣服显示队伍色。原来的深色椭圆阴影改为船底淡影和贴水线的水纹，航行时绘制朝船尾延伸的尾波。静止、未选中的可见渔船周围水纹也会持续变化。

捕鱼读取真实采集订单、鱼群余量、距离和工作计时器，短暂的采集动作结束后仍继续捕鱼循环。停船捕鱼时船体侧转，让右舷渔网朝向鱼群；航行方向与导航状态不受影响。袋状渔网使用菱形网格，随循环撒出、浸水、提起和收回，渔夫同时改变手臂姿态。驶向鱼群的船、正在移动的船和资源耗尽的船会收起渔网。头像使用稳定姿态，并按模型范围适配内框；单位预览增加“停泊／航行／捕鱼”和八方向选择。

## 验证

`tests/fishing_boat_rendering.gd` 使用生产渲染器验证 16 个投影／航向、8 个捕鱼目标方向、航行尾波和强制收网、4 个捕鱼阶段、3 种头像内框，以及 144 个单位预览尺寸／动作／方向组合。新增动作与方向控件在 150%、175%、200% 文字缩放下均不溢出。另检查真实单位快照的捕鱼连续性、移动／距离／余量／订单切换，以及可见未选中渔船的水纹动画和隐藏后的停止更新。

像素检查需要带图形驱动的 Godot；`--headless` 不会生成可用于检查的船体纹理。

```sh
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fishing_boat_preview.gd -- res://docs/fishing-boat-refinement overview
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fishing_boat_preview.gd -- res://docs/fishing-boat-refinement directions
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fishing_boat_preview.gd -- res://docs/fishing-boat-refinement motion
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fishing_boat_preview.gd -- res://docs/fishing-boat-refinement portrait
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fishing_boat_game_preview.gd
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tests/fishing_boat_rendering.gd
```

`before.png` 是改动前保存的基线；在新实现上运行 `before` 模式会覆盖该基线。
