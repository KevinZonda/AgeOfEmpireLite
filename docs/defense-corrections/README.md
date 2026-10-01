# 防御建筑修正

根据哨塔屋顶、城门侧墙和城堡角塔的截图反馈，修正了三类建筑的外形与绘制。

- 英格兰、法国哨塔：抬高瞭望层，使用短屋脊四坡顶，增加屋顶坡度、瓦面分层和厚檐口。中国哨塔同步抬高上层屋顶，保留双层曲檐。
- 石城门：重建完整门楼、拱形门洞、内缩木门和两侧墙段；统一按几何深度绘制，消除侧墙碎片和遮挡错误。地图、头像与点击区域共用门楼几何。
- 城堡：修正角塔可见面的选择，减少窄面的高亮石条；窗洞贴合所在墙面并按楼层对齐，角塔恢复连续、厚实的石墙观感。

## 近景对比

| 建筑 | 修改前 | 修改后 |
| --- | --- | --- |
| 哨塔 | [原版](before-outpost.png) | [新屋顶](outpost.png) |
| 石城门 | [原版](before-stone_gate.png) | [完整门楼与侧墙](stone_gate.png) |
| 城堡 | [原版](before-keep.png) | [角塔与窗洞](keep.png) |

## 游戏缩放与头像

- [等距总览](25d.png)、[正常地图缩放](map-zoom.png)、[选中头像](portraits.png)、[俯视图](2d.png)。
- 旋转城门：[等距图](vertical-25d.png)、[地图缩放](vertical-map-zoom.png)、[头像](vertical-portraits.png)、[俯视图](vertical-2d.png)。

截图通过项目本身的 Godot 绘制代码生成，涵盖英格兰、法国和中国。

## 验证

7 项检查通过，完整输出见 [validation.log](validation.log)。

- `defense_refinement.gd`：1,320 个屋顶/墙体探测点及 54 个头像检查，覆盖文明、旋转、缩放与地形高度。
- `defense_visual_selection.gd`：66 个城门、塔楼和脚手架选择检查。
- `stone_gate_geometry.gd`：6 种文明/方向组合，156 个独立遮挡深度采样无错层；14,796 个投影面中心选择检查通过。
- `visual_state.gd`、`fog_building_memory.gd`、`isometric_view.gd`、`smoke.gd` 均通过。`visual_state` 退出时报告 2 个 ObjectDB 实例泄漏警告。

复现：

```sh
docs/godot/bin/godot.macos.template_debug.arm64 --headless --path . --script tests/stone_gate_geometry.gd
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/defense_correction_closeup_preview.gd -- outpost
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/defense_building_refinement_preview.gd -- res://docs/defense-corrections
```

