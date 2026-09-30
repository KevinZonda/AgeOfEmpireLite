# 土地与山丘修整

[前后对比](comparison.png)：左边修改前，右边修改后。上排为平衡图山峰，下排为高地图山脊；均为种子4242、2400×1800地图、1.3×等距视角。修改前取自942998e。

- [草地](grassland.png)：缓慢变化的草色、坡地裸土及少量草丛。
- [山峰与山脚](foothill.png)：连续草／土／岩石过渡、不对称山峰、岩面方向光及碎石。
- [高地山脊](highlands.png)：起伏与鞍部，消除原先平板状的灰色区域。
- [俯视地形](topdown.png)：同一高度和材质，在2D下也保留坡面明暗。
- [背坡遮挡像素用例](occlusion.png)：左边关闭山体遮挡，右边开启；山后兵消失，山前兵保留完整。

高度仍使用共享顶点、同一条三角形对角线和同一套查询，单位、建筑基座、地面点击、植被和迷雾都读取该表面。山脊噪声独立于地图布局RNG。通行格、山口、资源、出生点、圣地、装饰顺序和布局RNG状态的六组原始哈希保持一致；只有山地及其坡脚的高度被有意调整。邻水顶点保持海拔零。

山体的不可通行面以共面小片进入单位深度排序，山前单位保留可见，山后单位被前景岩面遮挡。遮挡面采样同一张迷雾纹理，避免露出未探索地形。面片按固定深度带合批，共用着色器；改变可见范围更新纹理，缩放复用网格。行走地表保持在单位下方，不用自身地块遮住单位脚部。

验证包括六组完整生成快照、六组布局保持、12732条材质／高度连续性采样、2266个平坦湖岸顶点，以及三个缩放档位的前后单位遮挡和九种迷雾状态。既有坡上移动与点击、投影／缩放、地图路线、视野和十二张地图的水面像素回归也一并检查。

```sh
./docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tools/terrain_refinement_preview.gd
./docs/godot/bin/godot.macos.template_debug.arm64 --headless --path . --script tests/terrain_surface.gd
./docs/godot/bin/godot.macos.template_debug.arm64 --path . --script tests/terrain_occlusion.gd
```

Apple M2、Godot 4.7.2 Compatibility/OpenGL，3200×2200高地图、117组遮挡网格，单独运行预览时静态强制绘制中位1.19ms、P95 3.13ms。预览工具可复现该测量；数字不包括寻路、战斗和完整游戏UI，不能视作对局帧率。
