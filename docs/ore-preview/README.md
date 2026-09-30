# 石矿与金矿预览

[重绘前 2.5D](before-25d.png) · [重绘后 2.5D](ore-25d.png) · [重绘前 2D](before-2d.png) · [重绘后 2D](ore-2d.png)

预览上排展示三种不同位置的矿点和剩余 14% 时的外观，下排展示 1.4 倍、1 倍缩放下的成组摆放，以及选中资源的肖像。游戏内截图：[2.5D](in-game-25d.png) · [2D](in-game-2d.png)，使用英格兰、种子 12345、1.6 倍缩放。

矿点由大小、高低与灰度各异的岩块组成，采用左上方光照、破碎裂面、外围碎石和柔和的接地阴影。石矿使用冷灰色；金矿使用暖灰褐色母岩，金色矿脉分布在顶面及前侧裂面中。采集后减少外露矿脉和松散碎石，保留主体岩块。

几何按资源位置和类型生成并缓存，使用独立随机数生成器，不改变地图随机序列。2D、2.5D 与选中肖像共享同一矿点的数据；资源数量、采集距离与寻路碰撞半径沿用原有规则。

重新生成预览（需要图形渲染）：

```sh
make run RUN_ARGS='--script tools/ore_preview.gd'
```

检查随机多边形有效性、外观复现、随机数隔离与游戏基本行为：

```sh
make run RUN_ARGS='--headless --script tests/ore_geometry.gd'
make run RUN_ARGS='--headless --script tests/smoke.gd'
```
