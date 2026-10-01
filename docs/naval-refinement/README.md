# 海军船只外形

箭船、弩炮船、火攻船、战船和运输船使用同一套可转向立体几何，包含船壳、甲板、船沿、装备和船员。船体贴在水面上，停泊时显示沿船水线，航行时显示动态尾迹。渔船继续使用已有的捕鱼模型。

- [2.5D 总览](overview.png)
- [八个航向](directions.png)
- [游戏原始尺寸：停泊与航行](gameplay-scale.png)
- [2D 总览](overview-2d.png)
- [全部单位图鉴](../unit-gallery-25d/all-units.png)

战场、选择肖像和单位预览共用模型。运输船最多显示六名乘客；碰撞半径、载员容量、战斗与经济数值沿用游戏规则。

导出预览：

```sh
make run RUN_ARGS='--script res://tools/naval_visual_preview.gd --windowed --resolution 640x480'
make run RUN_ARGS='--script res://tools/unit_gallery_preview.gd --windowed --resolution 640x480'
```

绘制回归检查需要有图形渲染器的本地窗口：

```sh
make run RUN_ARGS='--script res://tests/naval_rendering.gd --windowed --resolution 640x480'
```

检查涵盖五种船的两种视角及八个航向、尾迹与载员差异、肖像与预览适配、几何模型共享和缓存上限。
