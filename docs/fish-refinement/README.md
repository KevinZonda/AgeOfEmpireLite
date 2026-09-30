# 水下鱼群重做

鱼资源改用共享鱼群绘制器，地图的 2D／2.5D 视图与选中头像使用同一套鱼体轮廓。每个资源点保持原来的位置和采集范围；鱼群在其周围小幅游动，个体摆尾、朝向和节奏由资源位置确定。鱼群余量减少时降低密度，避免采集到最后仍显示完整鱼群。

- [原版 2D](before-2d.png)、[原版 2.5D](before-25d.png)：修改前的实际地图基线。
- [总览](overview.png)：两种投影、两个位置种子，正常 1× 与放大 3×。
- [动作和余量](motion.png)：两种投影下 0～0.75 秒的连续摆尾采样，以及 40%／8% 余量。
- [头像](portrait.png)：真实选中头像，102×142、80×110、160×180。
- [实际地图 2D，1×](in-game-2d-1x.png)、[2.5D，1×](in-game-25d-1x.png)：正常缩放下的湖泊、码头、作业渔船和选中鱼群。
- [实际地图 2D，2×](in-game-2d.png)、[2.5D，2×](in-game-25d.png)：放大检查鱼群与真实渔网、船体的尺度和遮挡。

预览直接实例化 `RtsResource` 和 `RtsSelectionPortrait`；湖泊场景使用生产主场景、地图种子 431、真实码头和采集订单。预览冻结比赛并固定动画时间，使两种投影可重复比较。基线文件不由预览脚本覆盖。

需要带图形驱动的 Godot，`--headless` 不生成可用于视觉检查的纹理。默认一次生成全部图片；也可指定 `overview`、`motion`、`portrait` 或 `game`。

```sh
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fish_preview.gd -- --mode=all
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/fish_preview.gd -- --mode=game --output=/tmp/fish-review
```

鱼体使用渐细曲线、分叉尾鳍、半透明鱼鳍和银色背部高光；五条小鱼有各自的深浅、大小和摆尾相位。资源减少时额外个体逐渐淡出，保留核心个体的位置。水面短弧光保持稀疏，避免遮盖水纹。地图沿水面投影，头像使用同一几何的稳定姿态。

可见鱼群每秒最多重绘 12 次；暂停、结束、隐藏和移出视口时停止动画更新。动画不移动资源锚点，也不消耗地图或野生动物的随机数。

## 验证

- `fish_rendering`：两种投影、三档缩放下的可见性、绘制范围、游动差异、余量密度和位置种子差异；三种头像尺寸的内框适配与稳定姿态，共 33 次像素捕获。
- `fish_resource`：暂停、隐藏、离屏、视口边缘、重绘节流、种子与随机数隔离、真实比赛模拟回调、右键捕鱼、食物产出，以及耗尽后的选择与资源清理。
- `fishing_boat_rendering`、`isometric_view`、`fog_of_war`、`extended_systems`、`smoke`：相关回归。

```sh
docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tests/fish_rendering.gd
docs/godot/bin/godot.macos.template_debug.arm64 --headless --path . --script tests/fish_resource.gd
```
