# 奇观、大学、修道院、码头与农田

[三文明总览](25d.png) · [正常缩放](map-zoom.png) · [选中肖像](portraits.png) · [农田周期](farm-cycle.png)

总览按英格兰、法兰西、中国排列三行，五列依次为奇观、大学、修道院、码头、成熟农田。放大图为 1.8 倍，正常地图缩放为 1 倍；顶视图采用相同文明和建筑顺序。

| 视图 | 修改前 | 修改后 |
| --- | --- | --- |
| 2.5D | [原模型](before-25d.png) | [新模型](25d.png) |
| 2D | [原模型](before-2d.png) | [新模型](2d.png) |
| 正常缩放 | [原模型](before-map-zoom.png) | [新模型](map-zoom.png) |
| 肖像 | [通用房屋](before-portraits.png) | [对应模型](portraits.png) |

另有[中国建筑实际地图与 HUD](in-game.png)、[湖岸码头与肖像](dock-in-game.png)，以及[施工 40% 的五类建筑](construction-25d.png)。实际地图采用湖泊地图、种子 431，在可建造地块放置建筑，暂停游戏并关闭迷雾以便观察。

- 奇观由三套独立建筑组成：[英格兰](wonder-english.png)为双钟塔、十字长殿和飞扶壁；[法兰西](wonder-french.png)为阶梯多翼修院与中央高尖塔；[中国](wonder-chinese.png)为五层八角宝塔、金瓦前殿、园亭和水池。旧的大方盒台基取消。
- 大学采用英格兰石木学院、法兰西浅石高坡顶学院、中国灰绿瓦书院；保留入口、回廊、主塔、门窗和院内设施。
- 修道院分别采用英格兰长教堂与钟楼、法兰西回廊修院、中国暖赭瓦主殿、双檐山门与前侧钟亭。中国寺院和书院在顶视和斜视下都有不同轮廓。
- 码头由岸侧主栈台和两条独立桥舌组成，中间留空，露出实际地形；补齐桥桩斜撑、装卸口、木箱、桶、麻袋、系船设施和起吊木架。三国分别使用山墙、四坡及曲檐屋顶。
- 农田显示田垄、幼苗、成熟穗粒和收割后残茬，中国稻田增加窄灌溉沟。[周期预览](farm-cycle.png)每行五列依次为裸土、播种一半、成熟、收割一半和残茬；四行依次为英格兰斜视、顶视、中国斜视、顶视。

地图、可见部分点击和肖像使用相同几何；码头外伸桥头在 2D 和 2.5D 都可选中。图标按实际模型最高点放置，早期脚手架的高度和点击范围保持一致。农田的播种或收割阶段进入战争迷雾快照，隐藏后的作业不会改变已记住的外观。

建筑占地、费用、生命值、生产、农田产量和周期规则保持原值。农田按 13 档作物进度缓存，多个相同阶段的农田共享已准备模型；码头也共享缓存，减少地图重复建模开销。

## 验证

- `civic_building_selection`：15 种建筑与文明组合，205,872 个可三角化面片点击采样，覆盖三档缩放、两档地形高度、75%/100%施工；另验证40%脚手架、图标、肖像范围、农田缓存和记忆。
- `civic_building_occlusion`：大学、修道院、码头、农田的 441 个可见采样，独立射线深度参考与绘制顺序一致。
- `wonder_geometry`：三文明奇观的 355 个可见深度采样通过。
- `dock_visual`：30,192 个投影面可三角化；90 个外伸桥头与屋顶点击组合通过，桥舌外端之间的空泊位不误选。
- 农田周期、视觉快照、斜视、建筑选择、基础运行、迷雾记忆与绘制、地标点击与遮挡、防御建筑点击、地标目录与规则、集结点和敌人查看等 15 项现有回归通过。
- 2D、2.5D、1 倍缩放、肖像和实际地图截图均已检查。

## 复现

图形预览不能使用 `--headless`：

```sh
make run RUN_ARGS='--script tools/civic_building_preview.gd'
make run RUN_ARGS='--script tools/farm_visual_preview.gd'
make run RUN_ARGS='--script tools/civic_building_game_preview.gd'
make run RUN_ARGS='--script tests/landmark_rendering.gd -- /tmp/civic-construction --focus-buildings --ids=wonder,university,monastery,dock,farm --civilization=Chinese --construction=0.4 --scale=1.4'
```

几何、点击与农田回归：

```sh
make run RUN_ARGS='--headless --script tests/civic_building_selection.gd'
make run RUN_ARGS='--headless --script tests/civic_building_occlusion.gd'
make run RUN_ARGS='--headless --script tests/wonder_geometry.gd'
make run RUN_ARGS='--headless --script tests/dock_visual.gd'
make run RUN_ARGS='--headless --script tests/farm_cycle.gd'
make run RUN_ARGS='--headless --script tests/fog_building_memory.gd'
```
