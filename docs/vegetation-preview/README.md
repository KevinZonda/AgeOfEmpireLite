# 树木与浆果丛预览

[2.5D 预览](vegetation-25d.png) · [2D 预览](vegetation-2d.png)

上排是普通树的外形变化，以及浆果剩余 100%、50%、14% 时的外观。下排展示 1.4 倍和 1 倍缩放下的成片摆放，以及选中资源的肖像。

树木采用分枝树干、外扩根部和不规则叶团；树冠有宽窄、高低和绿色调变化，光照从左上方照入。浆果丛保持低矮，果实以小簇分布，采集后逐渐减少。树木被采集后露出浅色砍痕。

几何形状在资源初始化时按位置生成并缓存，使用独立随机数生成器，不改变地图或动物的随机序列。2D、2.5D 和资源肖像共享同一株植物的数据。采集范围、资源数量和寻路碰撞半径沿用现有规则。

重新生成预览（需要图形渲染）：

```sh
make run RUN_ARGS='--script tools/vegetation_preview.gd'
```

验证随机几何和游戏基本行为：

```sh
make run RUN_ARGS='--headless --script tests/vegetation_geometry.gd'
make run RUN_ARGS='--headless --script tests/smoke.gd'
```
