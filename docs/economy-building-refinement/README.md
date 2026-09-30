# 城镇与生产建筑模型细化

本轮细化城镇中心、磨坊、伐木场、采矿场和攻城器械工坊，并让五种建筑的选中肖像直接使用地图模型。

每张总览按英格兰、法兰西、中国排列三行，列依次为城镇中心、磨坊、伐木场、采矿场、攻城器械工坊。

| 视图 | 修改前 | 修改后 |
| --- | --- | --- |
| 2.5D 放大 | [原模型](before-25d.png) | [新模型](25d.png) |
| 2D 俯视 | [原模型](before-2d.png) | [新模型](2d.png) |
| 2.5D 正常缩放 | [原模型](before-map-zoom.png) | [新模型](map-zoom.png) |
| HUD 肖像 | [原肖像](before-portraits.png) | [对应建筑肖像](portraits.png) |

[实际游戏场景与选中肖像](in-game.png) 使用种子 `12345`，通过真实放置检查寻找避开资源和已有建筑的地块。五种建筑均由实际地形、相机及 HUD 渲染；展示时暂停游戏并关闭战争迷雾覆盖。

## 模型细节

- 城镇中心：开放前院、独立铜钟及钟架、入口台阶、铺路石、侧仓与遮阳廊，并保留队伍旗帜。铜钟与钟舌的线性尺寸扩大约 40%，保持原悬挂点和钟架尺寸。
- 磨坊：与正立面垂直的居中传动轴、四片等间隔长帆叶片及木框横撑、谷物料斗、麻袋及面粉箱。
- 伐木场：小仓房、带圆形切口和年轮的原木堆、吊木架、锯马与锯片、木板及劈柴墩上的斧头。
- 采矿场：有纵深的矿口、厚侧墙与支撑梁、手工采矿工具架、运矿筐、手摇卷扬与吊桶、两层六块大碎石与一块散石。
- 攻城器械工坊：相连的双工房与开放装配场、带底盘、车轴、轮子和投掷臂的投石机、装配架及备用材料。

城镇中心、磨坊和工房的主体沿用英格兰木构、法兰西石墙与坡屋顶、中国红木柱与曲面屋檐的区别。每个道具都参与共同的三维面片遮挡排序，地图与肖像共用同一份几何。模型缓存随建筑种类、文明与队伍颜色复用。

本轮模型修改未调整建筑占地、成本、生命值、生产或战斗参数。

## 复现

```sh
make run RUN_ARGS='--script tools/economy_building_refinement_preview.gd'
make run RUN_ARGS='--script tools/economy_building_game_preview.gd'
make run RUN_ARGS='--script tools/economy_building_closeup_preview.gd -- mining_camp'
make run RUN_ARGS='--script tools/economy_building_closeup_preview.gd -- town_center'
make run RUN_ARGS='--headless --script tests/economy_building_occlusion.gd'
make run RUN_ARGS='--headless --script tests/economy_building_selection.gd'
```

预览脚本支持 `RTS_BUILDING_BASELINE_VISUAL` 和 `RTS_BUILDING_BASELINE_PORTRAIT` 指向预先保存的旧版本脚本；旧版脚本需要引用其原来的模型判定，避免新的路由改变基线。设置基线后会生成 `before-` 文件。每个建筑视图单元为 320×360 像素，放大视图使用 1.8× 缩放，正常缩放视图使用 1×；实际 HUD 肖像仍使用 130×170 像素尺寸。

[磨坊转轮细化近景](mill-refined.png)：轮毂居中，四片帆叶保持 90° 间隔，长帆布由双侧框与六道横撑支撑。

[采矿场近景](mining_camp-refined.png)：矿口前采用带宽断面的两层灰色石堆、工具架和手提运矿筐，移除矿车、轨道及枕木。

[城镇中心铜钟近景](town_center-refined.png)：铜钟与钟舌同步放大，保持钟顶连接梁下方的悬挂位置。

## 验证范围

- 独立射线深度参考与三维面片绘制顺序比较，覆盖五种建筑与三个文明，并验证所有投影片段可三角化。
- `0.7× / 1× / 1.65×` 相机缩放、75% 与 100% 建造进度、平地及 21 单位高地条件下的全部显示面片中心点击。
- 高地建筑图标中心与边界外命中、战争迷雾快照重建模型一致、相机与建造进度变化复用几何缓存，以及全部肖像顶点在实际头像框内。

## 验证结果

- `economy_building_occlusion.gd`：15 种建筑与文明组合，9,553 个可三角化投影片段；独立射线深度参考检查 677 个可见采样点，遮挡失败 0。
- `economy_building_selection.gd`：在上述缩放、建造进度及地形高度组合下验证 113,832 个显示面片中心点击，肖像边界、图标、迷雾快照及缓存检查全部通过。
- 四组修改前与修改后截图均已生成。修改后 2.5D、2D、正常缩放和肖像共覆盖三个文明与五种建筑，人工检查未见裁切或遮挡错误。
- 实际游戏场景截图完成；现有 `fog_building_memory.gd`、`isometric_view.gd`、`smoke.gd` 回归测试通过。
