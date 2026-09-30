# 圣地遗迹模型

圣地采用方形阶梯石台、中央旗杆、断柱、倒柱及散落碎石，替换原来的编号圆环。三处圣地使用固定的断柱高度与碎石差异；模型通过三维面片与 BSP 排序绘制，2D 俯视使用同一模型的水平投影。

造型参考《帝国时代 IV》攻略中的圣地截图：[GosuNoob 圣地指南](https://www.gosunoob.com/guides/sacred-site-age-empires-4-how-to-capture-sacred-sites/)、[Gamepur 圣地指南](https://www.gamepur.com/guides/how-to-capture-sacred-sites-in-age-of-empires-4)。采用石台、旗杆和残破柱列的视觉特征，没有将外部截图或素材加入仓库。

## 状态与视图

[2.5D 总览](25d.png) · [2D 俯视](2d.png) · [1× 正常缩放](map-zoom.png)

每张总览六列依次为中立、蓝方占领、红方占领、占领进度 50%、争夺中、重置后。三行展示三种固定遗迹变体，第三行额外使用 21 单位高地。在斜视模式下，遗迹、地面范围、进度环和编号一起跟随地形高度。

- 旗帜显示当前所有者颜色。占领进度不会提前更换旗帜；争夺期间仍保留已有所有者的旗帜。
- 中立及重置后的旗帜为浅色。争夺状态的地面环为黄色，占领状态显示独立进度弧。
- 编号 I、II、III 移到遗迹前方，保持正立，避免被石台或旗杆挡住。
- 圣地继续作为已知地图目标显示；战争迷雾外的遗迹变暗，重新进入视野后恢复颜色。

## 实际游戏截图

| 视图 | 原圆环 | 中立遗迹 | 蓝方占领 |
| --- | --- | --- | --- |
| 2.5D | [修改前](before-in-game-25d.png) | [中立](in-game-neutral-25d.png) | [占领后](in-game-captured-25d.png) |
| 2D | [修改前](before-in-game-2d.png) | [中立](in-game-neutral-2d.png) | [占领后](in-game-captured-2d.png) |

实际场景使用生产地图、相机与圣地显示节点；展示时暂停游戏并关闭迷雾覆盖，以便观察模型。

## 实现与验证

`RtsObjectiveManager` 继续持有位置、所有权、争夺、占领与胜利状态；`RtsSacredSite` 只负责显示。模型只在旗帜所有者颜色或遗迹编号变化时重新准备，缩放、视图、地形、进度与争夺更新复用几何缓存。重新初始化目标会释放旧显示节点；重置保留节点并恢复中立外观。

本轮未修改圣地位置、占领半径、占领时间、争夺判定、胜利倒计时或奇观胜利规则。

- `sacred_site_geometry.gd`：三种变体 × 中立、蓝方、红方，共 9 个模型，5,412 个 BSP 片段；177 个独立射线深度采样全部正确。
- 三档缩放 `0.7× / 1× / 1.65×` 与平地、21 单位高地组合下，28,908 个投影片段三角化检查通过；另验证全部源面片共面。
- 170 个生命周期与状态检查通过，覆盖四次重新初始化、重置保留节点、旗帜颜色、进度和争夺缓存、视图及缩放缓存，以及迷雾变暗与恢复。
- 三张状态总览已实际渲染并检查，18 种变体与状态组合没有裁切或明显遮挡错误。
- 目标规则、等距视图与基础游戏回归检查均通过：`OBJECTIVES_OK`、`ISOMETRIC_VIEW_OK`、`SMOKE_OK`。

## 复现

```sh
make run RUN_ARGS='--script tools/sacred_site_preview.gd'
make run RUN_ARGS='--script tools/sacred_site_game_preview.gd'
make run RUN_ARGS='--headless --script tests/sacred_site_geometry.gd'
make run RUN_ARGS='--headless --script tests/objectives.gd'
make run RUN_ARGS='--headless --script tests/isometric_view.gd'
make run RUN_ARGS='--headless --script tests/smoke.gd'
```

状态预览脚本可在 `--` 后传入输出目录。预览需要图形驱动；测试可使用无窗口模式。
