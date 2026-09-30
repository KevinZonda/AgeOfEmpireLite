# 城门、防御建筑与地标重绘

[重点预览](showcase-25d.png) · [石门](stone-gate-25d.png) · [木门](palisade-gate-25d.png) · [哨塔](outpost-25d.png) · [城堡](keep-25d.png) · [皇宫](imperial-palace-25d.png) · [天文钟楼](clocktower-25d.png)

| 内容 | 重绘前 | 重绘后 |
| --- | --- | --- |
| 防御建筑 2.5D | [之前](fortifications-before-25d.png) | [之后](fortifications-25d.png) |
| 防御建筑 2D | [之前](fortifications-before-2d.png) | [之后](fortifications-2d.png) |
| 地标 2.5D | [之前](landmarks-before-25d.png) | [之后](landmarks-25d.png) |
| 地标 2D | [之前](landmarks-before-2d.png) | [之后](landmarks-2d.png) |

另有正常 1 倍缩放下的[防御建筑](fortifications-1x.png)、[地标](landmarks-1x.png)，以及[施工 40% 时的地标](construction-25d.png)。总览保留三座已有奇观便于与原预览比较；本轮重绘全部 18 座地标。

- 石门使用双侧防御塔、分块弧拱、木门铁箍、射击孔、跨门平台和垛口。木门使用双侧木岗楼、覆顶门廊、斜撑及门扇。两种朝向和顶视图共用沿墙参数。
- 哨塔使用收窄石塔身、外展墙脚、木挑台观察廊和四坡屋顶；普通城堡使用八角塔楼、厚围墙、独立主楼、射击孔和拱门。
- 六座中国地标分别突出院落长廊、石堡、两层钟楼、金瓦双檐宫殿、双层门楼，以及牌楼、神道和石兽。屋顶用分段坡面形成挑檐，并补柱梁、瓦缝和脊饰。
- 十二座英法地标使用独立布局：议会厅门廊、修道院双塔、白塔四角塔、王宫前庭、城堡围墙、骑兵学校院落、商会摊位、公会钟塔及炮兵学院火炮。浅石立面、转角石、窗框和石板屋面统一光照。
- 地标的通用底座从高楼体改为 6 像素低台基；早期脚手架仍按主体高度显示，并保持图标位置和点击范围一致。

沿用现有占格、碰撞和资源规则。地标仍由局部三维面片和 BSP 排序绘制，地图、点击检测及战争迷雾记忆使用同一模型。投影面片按观察基向量和高度缓存，重新准备几何时清空缓存；忽略极小的零面积裁切片，避免图形驱动的三角化错误。

## 验证

- `architecture_redraw_geometry`：18 座独特地标，所有非退化投影面片均可三角化。
- `landmark_occlusion`：2,031 个有效射线深度采样点全部与绘制顺序一致。
- `landmark_selection`：132,882 个面片中心点击采样，覆盖 21 种外观、三档缩放和两个施工阶段。
- `defense_visual_selection`：66 个城门、塔顶和施工脚手架高位点击组合，覆盖两种门方向、三档缩放与两档地形高度。
- `visual_state`、`isometric_view`、`build_selection`、`smoke`、`fog_rendering`、`landmark_catalog`、`landmark_roles`、`rally_landmarks`、`enemy_inspection` 回归通过。

## 重新生成

需要图形驱动，不能使用 `--headless`：

```sh
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/landmark-preview'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/landmark-preview-2d --topdown'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/defense-preview --fortifications'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/defense-preview-2d --fortifications --topdown'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/normal-preview --scale=1.0'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/focus-preview --ids=stone_gate,palisade_gate,outpost,keep,zh_imperial_palace,zh_clocktower'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/construction-preview --ids=zh_clocktower,eng_white_tower,zh_imperial_palace --construction=0.4'
```

主要几何与点击回归：

```sh
make run RUN_ARGS='--headless --script tests/architecture_redraw_geometry.gd'
make run RUN_ARGS='--headless --script tests/defense_visual_selection.gd'
make run RUN_ARGS='--headless --script tests/landmark_occlusion.gd'
make run RUN_ARGS='--headless --script tests/landmark_selection.gd'
make run RUN_ARGS='--headless --script tests/smoke.gd'
```
