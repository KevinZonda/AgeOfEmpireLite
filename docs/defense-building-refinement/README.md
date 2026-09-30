# 城防建筑与选中头像细化

本轮细化石墙、木栅栏、哨塔和城堡，并让城防建筑与全部 18 个地标的选中头像复用地图模型。

总览按英格兰、法兰西、中国排列三行，列依次为城堡、哨塔、石墙、石门、木栅栏和木门。

| 视图 | 修改前 | 修改后 |
| --- | --- | --- |
| 2.5D 放大 | [原模型](before-25d.png) | [新模型](25d.png) |
| 2D 俯视 | [原模型](before-2d.png) | [新模型](2d.png) |
| 正常缩放 | [原模型](before-map-zoom.png) | [新模型](map-zoom.png) |
| 城防头像 | [通用房屋头像](before-portraits.png) | [对应建筑头像](portraits.png) |
| 地标头像 | [通用房屋头像](before-landmark-portraits.png) | [18 个地标模型](landmark-portraits.png) |

竖向城防另有 [2.5D](vertical-25d.png)、[2D](vertical-2d.png)、[正常缩放](vertical-map-zoom.png) 和 [头像](vertical-portraits.png) 预览。

[实际游戏与城堡选中头像](in-game.png) 使用中国文明、种子 `12345`，通过真实放置检查寻找避开资源和已有建筑的地块；展示时暂停游戏并隐藏迷雾与天气。

## 外观变化

- 石墙：补充外撇石基、端头交错包角石和压顶，将线条垛口换成立体正面、侧面与顶面。
- 木栅栏：补充斜撑、木钉与较粗的端柱；俯视图保留窄墙带周围的地面。
- 哨塔与城堡：移除旧的厚黑边底座，改为 2 单位高的浅石基与细边线。
- 中国城堡：主楼增加曲面四坡瓦顶，四座角塔增加独立瓦顶和挑檐；中国哨塔增加两层屋檐。俯视图同步体现瓦顶布局。
- 城防头像：采用地图的同一套绘制函数与等角投影，头像框按完整视觉轮廓适配；旋转墙体有对应的旋转头像。
- 地标头像：采用地图模型的排序面片，保留文明、地标种类和队伍颜色。

曲面屋檐以独立三角面绘制，避免小尺寸屋檐在投影后发生多边形自交。屋檐外沿与抬高的墙顶纳入视觉点击范围。城堡和哨塔图标按视觉轮廓的最高投影位置排列，保留屋顶上方的间距。

建筑占地、放置规则、成本、生命值与战斗参数均未调整。本轮没有加入依赖相邻墙体的转角识别，也未改动施工与受损状态。

## 复现

```sh
make run RUN_ARGS='--script tools/defense_building_refinement_preview.gd'
make run RUN_ARGS='--script tools/defense_building_refinement_preview.gd -- res://docs/defense-building-refinement --vertical'
make run RUN_ARGS='--script tools/landmark_portrait_preview.gd'
make run RUN_ARGS='--script tools/defense_building_game_preview.gd'
make run RUN_ARGS='--headless --script tests/defense_refinement.gd'
```

建筑预览支持 `RTS_BUILDING_BASELINE_VISUAL` 与 `RTS_BUILDING_BASELINE_PORTRAIT` 加载保存的旧脚本；基线脚本应引用其原来的绘制依赖。前后建筑对比图在修改前后分别捕获。地标的修改前头像由保存的旧版头像脚本捕获。

## 验证

在独立副本中使用已提交的项目基线与本轮 9 个源码、测试及预览文件完成验证，避免其他正在编辑的地标文件影响结果。

- `defense_refinement.gd`：1,224 个曲面屋檐与墙顶检查、54 组头像组合；覆盖三个文明、两种旋转、0.6× / 1× / 2× 缩放及平地、19 单位高地。验证屋檐可三角化、屋檐与墙顶可点击、图标与屋顶间距、头像不受相机缩放影响，以及全部地标头像在 HUD 框内。
- `defense_visual_selection.gd`：66 个城门、塔楼和施工架点击检查通过。
- `architecture_redraw_geometry.gd`：18 个不同地标、20,278 个有效投影片段。
- `landmark_selection.gd`：146,406 个面片中心点击通过。
- `landmark_occlusion.gd`：1,931 个遮挡采样点，失败 0。
- `visual_state.gd`、`fog_building_memory.gd`、`isometric_view.gd`、`smoke.gd` 通过。`visual_state.gd` 保留现有的退出时两项 ObjectDB 泄漏提示。
- 横向与竖向的放大、俯视、正常缩放、头像，以及全部地标头像和实际游戏截图均已渲染并人工检查；最终渲染日志无错误。

九项检查的输出保存在 [checks](checks/) 中。
