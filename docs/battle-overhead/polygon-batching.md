# 小多边形的渲染提交成本

GLES3 的 `RasterizerCanvasGLES3` 对 `TYPE_POLYGON` 总是新建 batch，每个填充多边形都有独立的 polygon buffer 和绘制调用。建筑和单位大量使用这种调用；即使画面冻结，CPU 仍需每帧提交这些指令，GPU 利用率并不能反映提交成本。

`filled_polygon.gd` 将三角形和严格凸四边形交给 `draw_primitive`，使用引擎可合批的图元流。较大、凹、多点共线等形状保留原有三角剖分。只替换无纹理、单色填充；描边、绘制顺序、透明度、动画和深度顺序保持原规则。

`tools/polygon_batch_poc.gd` 在同一个真实 6 建筑、80 人和鹿群场景内冻结模拟，然后依次重绘原实现和新实现。1280×800、标准 2.5D 纵横缩放、关闭 VSync 和帧上限以隔离提交成本，原图元与新图元各测 120 帧：

| 指标 | 原实现 | 合批图元 |
| --- | ---: | ---: |
| draw call | 3153 | 2851 |
| 视口 CPU 提交均值 | 8.219 ms | 7.501 ms |

这约节约 0.72 ms 的提交时间，收益小于导航和帧等待修复，不能单独解决低帧率。新旧图像的 4,096,000 个通道逐一比较，最大差异 1/255，没有任何通道超过这个差值；图元使用半精度颜色传输会有最低位舍入差异。

独立 `tests/filled_polygon_rendering.gd` 还覆盖正反绕序、凸/凹/多点共线形状、五边形回退、旋转和半透明叠加，460,800 个通道均在上述误差内。`siege_rules`、`zoom_projection`、`minimap_projection`、`economy_siege_controls` 通过。`unit_visual_coverage` 遇到预览上下文缺少 `should_show_health_bar` 的既有错误；修复前快照同样失败，未计入通过项。

```sh
make run RUN_ARGS='--script res://tools/polygon_batch_poc.gd --windowed --resolution 1280x800'
make run RUN_ARGS='--script res://tests/filled_polygon_rendering.gd --windowed --resolution 640x360'
```

第一条可加 `RTS_POC_IMAGE_DIR=/tmp/polygon-images` 保存新旧渲染图（先创建目录）。正常游戏保留原有 VSync 和 120 FPS 上限；关闭它们只用于这项渲染隔离测试。
