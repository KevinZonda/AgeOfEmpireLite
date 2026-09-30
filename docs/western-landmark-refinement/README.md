# 议会厅、温嘉德宫殿、商会与炮兵学院

四座地标使用独立布局和局部三维面片；地图、点击检测及选中肖像沿用共用的 BSP 遮挡排序与模型缓存。建筑占地、成本、生命值、生产与地标规则保持原值。

- 议会厅：长条木构大厅、两侧开放柱廊、突出山墙门廊、屋顶钟亭与长弓架。
- 温嘉德宫殿：陡顶双侧塔翼、中央大厅、屋顶老虎窗、开放入口柱廊、台阶与绿篱前庭。
- 商会：商贸大厅与尖顶屋亭、开放石柱拱廊、蓝白条纹摊棚、柜台、木箱、木桶及货袋。
- 炮兵学院：学院主楼和非对称工房围绕开放装配院；两门青铜火炮有圆柱炮管、黑色炮口、炮架及圆形辐条车轮，院内配置炮弹与通条。

各图从左到右依次为议会厅、温嘉德宫殿、商会、炮兵学院。2.5D 与俯视放大图为 1.8 倍，正常缩放为 1 倍；肖像使用实际 130×170 框。施工图为 40% 进度，沿用早期脚手架表现。

| 视图 | 修改前 | 修改后 |
| --- | --- | --- |
| 2.5D | [之前](before-25d.png) | [之后](25d.png) |
| 2D 俯视 | [之前](before-2d.png) | [之后](2d.png) |
| 正常缩放 | [之前](before-map-zoom.png) | [之后](map-zoom.png) |
| HUD 肖像 | [之前](before-portraits.png) | [之后](portraits.png) |
| 40% 施工 | [之前](before-construction-25d.png) | [之后](construction-25d.png) |
| 实际地形与 HUD | [之前](before-in-game.png) | [之后](in-game.png) |

[议会厅近景](closeups/eng_council_hall.png) · [温嘉德宫殿近景](closeups/eng_wynguard_palace.png) · [商会近景](closeups/fr_chamber_of_commerce.png) · [炮兵学院近景](closeups/fr_college_of_artillery.png)

实际游戏截图使用湖泊地图、种子 431；在有效且避开资源的地块放置四座地标，暂停游戏、关闭迷雾并选中炮兵学院，展示当前地形和真实 HUD。此场景为外观展示，英法地标集中放在同一玩家下。

## 验证

在只包含本轮提交内容的隔离目录运行，[测试结果](checks/results.json)中 10 项回归全部通过：建筑几何、地标遮挡与选择、地标目录与规则、集结点、肖像边界、迷雾记忆、斜视图与基础运行。

- `architecture_redraw_geometry`：18 种独立地标，24,591 个投影片段均可三角化。
- `landmark_occlusion`：1,965 个有效射线深度采样，遮挡失败 0。
- `landmark_selection`：21 种地标／奇观外观、三档缩放和两档施工状态，172,284 个面片中心点击通过。
- `western_landmark_portrait`：验证四座地标使用实际模型、两种 HUD 框尺寸下无裁切、相机与地形变化复用缓存、队伍色变化刷新旗帜。
- 本轮公共细节函数抽取后，额外对比其余 8 座英法地标的原始面片及颜色，保持完全一致。
- 2D、2.5D、正常缩放、肖像、施工与实际地图截图均已检查。

## 复现

预览需要图形驱动，不能添加 `--headless`：

```sh
make run RUN_ARGS='--script tools/western_landmark_refinement_preview.gd -- docs/western-landmark-refinement'
make run RUN_ARGS='--script tools/western_landmark_game_preview.gd -- docs/western-landmark-refinement'
```

预览支持 `--prefix=before-` 为运行时模型生成带前缀的截图；已保存的 before 图来自新模型接入前的相同脚本。

```sh
python3 tools/check_navigation.py --tests architecture_redraw_geometry landmark_occlusion landmark_selection landmark_catalog landmark_roles rally_landmarks western_landmark_portrait fog_building_memory isometric_view smoke --output docs/western-landmark-refinement/checks
```
