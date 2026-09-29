# 6 建筑场景中的碰撞网格准备

真实窗口的脚本计时显示，单位 `_process` 是最大脚本开销，导航的 `_grid_for` 和 `_rasterize_static_grid` 在诊断运行中分别累计约 4.27 和 4.67 ms/帧（嵌套计时，不应与父调用相加）。原生 A* 本身远小于这些准备步骤。

最小 PoC 在 3200×2400 地图上放置 6 座建筑、150 个资源、固定水域和一个移动单位，反复冷建导航网格。无需 80 个单位或 UI 即可复现：

| 30 次请求 | 原实现 | 修复后 |
| --- | ---: | ---: |
| 全图粗网格 | 319.15 ms | 45.97 ms |
| 193×193 局部网格 | 75.82 ms | 51.64 ms |

粗网格此前对每格调用动态占位查询，反复进行空间桶查找和碰撞计算；改为复用已经用于细网格的几何栅格化。局部栅格化此前逐个扫描全地图地形格；现在只枚举可能影响局部网格的地形范围，包含单位半径。资源移动仍然刷新导航，不通过降低碰撞更新频率或忽略鹿来获得加速。

`navigation_battle_static_grid_poc.gd` 用独立的连续碰撞查询逐格对照：海陆单位、三种半径、局部网格偏移和地图两端，共 **187,794 格、24 项断言，修复前后都通过**。另有 12 个导航/鹿移动回归脚本通过，包括海陆栅格化、建筑施工、密集编队和资源移动重规划。

```sh
make run RUN_ARGS='--headless --script res://tests/navigation_battle_static_grid_poc.gd'
python3 tools/check_navigation.py --tests navigation_grid_raster navigation_battle_static_grid_poc navigation_dense_poc navigation_construction_poc navigation_replanning group_chokepoint deer_movement_poc
```

这里报告冷建耗时；真实战斗不会每帧固定执行 30 次。窗口整体帧率需单独测量。
