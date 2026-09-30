# 军事建筑模型细化

本轮细化兵营、靶场、马厩和预备营地，并让四种建筑的选中肖像直接使用地图模型。

## 实际渲染对比

每张总览按英格兰、法兰西、中国排列三行，列依次为兵营、靶场、马厩、预备营地。

| 视图 | 修改前 | 修改后 |
| --- | --- | --- |
| 2.5D 放大 | [原模型](before-25d.png) | [新模型](25d.png) |
| 2D 俯视 | [原模型](before-2d.png) | [新模型](2d.png) |
| 2.5D 正常缩放 | [原模型](before-map-zoom.png) | [新模型](map-zoom.png) |
| HUD 肖像 | [通用房屋肖像](before-portraits.png) | [对应建筑肖像](portraits.png) |

[游戏场景与选中肖像](in-game.png) 使用种子 `12345`，在有效且避开资源的地块放置四种建筑，用实际地形、相机和 HUD 截图。此展示暂停游戏并关闭战争迷雾覆盖，以便观察模型。

## 模型细节

- 兵营：木构立面、门窗、队伍旗帜、长矛与盾牌架、训练木人和补给箱。木人旁的单独盾牌已移除，盾牌集中保留在左侧武器架；见[兵营放大图](barracks-refined.png)。
- 靶场：三座等距对齐、统一高度、带厚度和后撑的立体箭靶，以及弓架、箭筒和开放练习场。靶盘朝向斜视相机，支柱与后撑退到靶面后方，完整显示同心环与靶心；见[修正后的靶场放大图](archery-range-fixed.png)。
- 马厩：开放马栏、带四腿和鞍具的马匹、围栏、草料槽、草捆及马具。
- 预备营地：带敞开入口和支撑绳的帐篷、篝火、铺盖及补给，替换原先的平台和杆。

前三种建筑继承英格兰木构、法兰西石墙与坡屋顶、中国曲面屋檐的建筑特征。营地使用对应文明的帆布颜色。所有细节都进入共同的三维面片遮挡排序、地图点击和肖像投影；几何缓存随建筑、文明及队伍颜色复用。

建筑占地、成本、生命值、生产及战斗规则保持原值。

## 复现

```sh
make run RUN_ARGS='--script tools/military_building_preview.gd'
make run RUN_ARGS='--script tools/military_building_game_preview.gd'
make run RUN_ARGS='--headless --script tests/military_building_occlusion.gd'
make run RUN_ARGS='--headless --script tests/military_building_selection.gd'
```

预览脚本支持 `RTS_BUILDING_BASELINE_VISUAL` 和 `RTS_BUILDING_BASELINE_PORTRAIT` 指向预先保存的旧版本脚本；旧版脚本也需要引用其原来的模型判定，避免新的路由改变基线。设置基线后会生成 `before-` 文件。

## 验证结果

- `military_building_occlusion.gd`：12 种建筑与文明组合，5,767 个可三角化面片；独立射线深度参考与绘制顺序对比检查 464 个可见采样点，遮挡失败 0。
- `military_building_selection.gd`：在 `0.7× / 1× / 1.65×` 相机缩放、75% 与 100% 建造进度、平地及 21 单位高地条件下验证 69,132 个显示面片中心点击。
- 遮挡测试另检查三个箭靶的靶心、下半圈与外缘颜色，避免支柱虽正确排序却遮住靶面。
- 同一选中测试同时验证高地建筑图标中心与边界外命中、战争迷雾快照重建模型一致、相机与建造进度变化复用几何缓存，以及全部肖像顶点都在实际头像框内。
- 2.5D、俯视、正常缩放及肖像截图均已人工检查，三种文明与四种建筑没有裁切。
- 现有 `fog_building_memory.gd`、`isometric_view.gd`、`smoke.gd` 回归测试通过。
