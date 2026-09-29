# 圣物外观

参考 [AoE4 实机截图](https://forums.ageofempires.com/t/deconstructing-age-of-empires-iv-fan-preview-video-piece-by-piece/125925)中的金色小圣匣、石质底座与向上延伸的金色光束，使用 Godot 绘制代码生成了本项目的圣物。

| 状态 | 2.5D | 2D |
| --- | --- | --- |
| 地面圣物 | [预览](relic-25d.png) | [预览](relic-2d.png) |
| 修士携带 | [预览](monk-carried-25d.png) | [预览](monk-carried-2d.png) |

重新生成截图：

```sh
docs/godot/bin/godot.macos.template_debug.arm64 --path . \
  --script res://tests/relic_rendering.gd --rendering-method gl_compatibility \
  -- /tmp/relic-preview
```
