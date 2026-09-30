# 攻城器重做

八种器械均重建为共享的局部立体几何，2D 和 2.5D 使用同一结构；根据渲染快照的八方向朝向投影、剔除背面并排序。战场、单位预览和选中肖像共用模型。

- [重做后总览](overview.png)：八型号，两投影，2.6×与正常1×。
- [重做前总览](before.png)：相同型号、投影与倍率，旧图的单元格较矮。
- [八方向](directions.png)：朝向改变时的前后轮、车身和支架遮挡。
- [机械动作](motion.png)：静止、移动、蓄力、释放、恢复、部署／载兵。
- [肖像](portraits.png)：102×142及80×110内框适配。
- [管口与撞槌接头修正](details-corrected.png)：完整3×4管口及连续端部框架。

| 型号 | 结构与动作 |
| --- | --- |
| 攻城槌 | 四轮护棚、尖顶、护板、悬吊撞木、独立前冲铁头 |
| 投石机 | 双侧A架、长短臂、固定枢轴、悬挂配重、定长吊索 |
| 轻型投石车 | 低宽底盘、扭力轴、绕轴转动的投臂与勺端 |
| 弹簧弩炮 | 箱形框架、双扭力束、射轨、弓臂、弦及绞盘 |
| 手推炮 | 四轮低车架、短粗青铜炮、推把、炮耳、独立后坐 |
| 加农炮 | 两大轮、长铁炮管、拖架、炮箍、厚炮口、独立后坐 |
| 一窝蜂 | 倾斜厚箱、十二管阵列、侧箍、支撑架、齐射闪光 |
| 攻城塔 | 三层车塔、侧窗、梯子、斜撑、顶台、折叠桥、可见乘员 |

攻击动画读取实际发射／撞击事件，蓄力阶段不造成额外伤害。攻击地面的发射事件也接入相同快照信号。攻城塔靠墙时朝向墙体并展开桥，离开部署状态后收桥。高塔和长臂器械的单位预览、肖像及血条按投影后的真实范围定位。

管口后板与十二个铜圈、黑色内膛按同一面组合绘制，避免整块后板按中心深度排序时覆盖部分管口。撞槌端部立柱、上下横梁与铁接头共面连接并组合排序；长撞木分段排序，保留前框外可见的木轴。`tests/siege_detail_occlusion.gd` 在两投影及三个正面方向检查72个管口的铜圈／内膛和12根连续立柱。

## 绘制成本

静态车身在单位之间共享缓存；轮辐仅绘制少量动态线段。按深度顺序将静态面和结构线合并为网格，并在轮辐处拆开网格批次，保留远侧轮被车身遮挡的顺序。攻击姿态使用有上限的独立缓存。

本机 Apple M2、Godot 4.7.2 Compatibility/OpenGL，96台可见移动器械的独立预览基准：帧等待加绘制中位16.69 ms、P95 25.22 ms。该基准不含寻路、战斗模拟或地图绘制，不能视作完整对局帧率。合批前同一预览中位约95 ms；优化后移动车身不会随轮辐相位重建。

## 验证与复现

已通过：128种型号／投影／方向渲染、机械动作及部署像素变化、16个肖像内框检查、48种预览尺寸组合、12种真实攻击／攻击地面事件和部署快照检查、360种实时与离线快照渲染一致性。既有攻城规则、经济／攻城控制及全单位视觉覆盖回归也通过。

```sh
make run RUN_ARGS="--script tools/siege_visual_preview.gd -- res://docs/siege-refinement overview"
make run RUN_ARGS="--script tools/siege_visual_preview.gd -- res://docs/siege-refinement directions"
make run RUN_ARGS="--script tools/siege_visual_preview.gd -- res://docs/siege-refinement motion"
make run RUN_ARGS="--script tools/siege_visual_preview.gd -- /tmp/siege-benchmark benchmark"
make run RUN_ARGS="--script tests/siege_rendering.gd"
make run RUN_ARGS="--script tests/siege_detail_occlusion.gd"
make run RUN_ARGS="--headless --script tests/siege_actions.gd"
make run RUN_ARGS="--headless --script tests/siege_preview_page.gd"
make run RUN_ARGS="--script tests/unit_snapshot_rendering.gd"
```
