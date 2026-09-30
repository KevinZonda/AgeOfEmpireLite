# 贸易站预览

[2.5D 商栈](trade-post-25d.png) · [2D 俯视](trade-post-2d.png) · [游戏地形中的商栈](in-game-25d.png)

贸易站由双坡屋顶的木梁主屋、前方条纹遮阳棚、货物柜台、木箱、木桶、货袋及金币招牌组成，采用中立配色。2.5D 显示侧墙、山墙、屋顶厚度和棚柱；2D 显示屋顶、棚布及院内货物的俯视布局。地面平台与阴影帮助辨认轮廓，名称置于建筑下方。

两种视角的绘制形状在初始化时缓存。贸易目标检测使用这些形状，覆盖屋顶与摊位；阴影和文字不参与点击。地图上的位置、商人往返规则、贸易收益与迷雾可见性沿用原有逻辑。

预览图依次展示 3 倍、1.5 倍、1 倍缩放。重新生成预览需要图形渲染：

```sh
make run RUN_ARGS='--script tools/trade_post_preview.gd'
```

回归验证：

```sh
make run RUN_ARGS='--headless --script tests/trade_post_targeting.gd'
make run RUN_ARGS='--headless --script tests/extended_systems.gd'
make run RUN_ARGS='--headless --script tests/selection.gd'
```

目标检测覆盖 2D、2.5D 和三档缩放下的屋顶、摊位及木箱，并排除空地、阴影和名称。扩展系统测试验证商人完成贸易后获得黄金。
