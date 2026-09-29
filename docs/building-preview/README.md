# 当前建筑外观

以下图片由 `tests/landmark_rendering.gd` 调用当前 Godot 绘制代码直接截图，普通建筑为英格兰配色、完工状态，按 `GameData.BUILDINGS` 的顺序排列。截图使用纯色背景，实际对局还会有地形、单位和其他界面元素。

- [22 种普通建筑：2.5D](regular-25d.png)
- [22 种普通建筑：2D](regular-2d.png)
- [城堡、哨塔与 8 种墙门朝向：2.5D](fortifications-25d.png)
- [城堡、哨塔与 8 种墙门朝向：2D](fortifications-2d.png)
- [18 座地标与 3 座奇观：2.5D](landmarks-25d.png)

## 六座建筑重绘

城镇中心、伐木场、采矿场、磨坊、铁匠铺和攻城器械厂的[重绘前 2.5D](before-six-25d.png)与[重绘后 2.5D](redrawn-six-25d.png)可直接比较；另有[重绘前 2D](before-six-2d.png)和[重绘后 2D](redrawn-six-2d.png)。这六座建筑使用独立的程序绘制文件；英格兰版本采用参考图里的灰瓦屋顶，法兰西和中国沿用项目已有的文明色系。另有[法兰西 2.5D](redrawn-six-french-25d.png)和[中国 2.5D](redrawn-six-chinese-25d.png)的截图供检查配色。

根据实渲染截图的反馈又调整了四座建筑：[反馈前 2.5D](before-feedback-six-25d.png)、[反馈后 2.5D](redrawn-six-25d.png)，以及对应的[反馈前 2D](before-feedback-six-2d.png)、[反馈后 2D](redrawn-six-2d.png)。城镇中心撤去前门楼，在开阔院内悬挂带钟舌的铜钟；采矿场强调矿口、矿轨、满载矿车和矿石堆；磨坊改为高墙、陡顶与正面风帆；攻城器械厂的前院零件改成双轮投石车。

四座建筑的单张放大截图：[城镇中心](town_center-corrected-25d.png) · [采矿场](mining_camp-corrected-25d.png) · [磨坊](mill-corrected-25d.png) · [攻城器械厂](siege_workshop-corrected-25d.png)。

市场和大学参考了 AoE4 的[英格兰市场](https://ageofempires.fandom.com/wiki/Market_(Age_of_Empires_IV))与[英格兰大学](https://ageofempires.fandom.com/wiki/University_(Age_of_Empires_IV))：市场以木构主楼、条纹摊棚、货物和中央石柱组成；大学改成围合前院的多翼建筑，增加中央门楼、窗列与庭院石像。

城堡、修道院、码头与墙门也已重绘。城堡参考 [AoE4 城堡截图](https://forums.ageofempires.com/t/rotating-buildings/224074/)的围墙、角塔和中央主楼；修道院参考[西欧建筑截图](https://forums.ageofempires.com/t/hre-uniqueness-mechanic-and-army-rant-there-is-a-lot-of-potential-lying-fallow/176231?page=16)，中国配色另参考[官方少林寺页面](https://www.ageofempires.com/games/age-of-empires-iv/civilizations/zhu-xis-legacy/)；码头参考[海岸实战截图](https://forums.ageofempires.com/t/how-to-dominate-french-in-boulder-bay-as-hre/184269/)，改成木栈台、仓棚与瞭望亭；木墙、石墙及两类门参考[城门实战截图](https://forums.ageofempires.com/t/the-gate-of-wall-should-be-the-focal-point-of-the-attack/223892)，增加尖桩、垛口和清楚的门洞。四类建筑均可在上方的普通建筑总览中查看。

造型参考是《帝国时代 IV》原版建筑图：

| 建筑 | 借鉴的轮廓 | 参考 |
| --- | --- | --- |
| 城镇中心 | 围合院落、后侧大厅；院内铜钟按本项目需求加入 | [英格兰城镇中心](https://data.seicing.com/seicingdepot/3fatcatpool/aoe4/architecture/eng/城镇中心2.png) |
| 伐木场 | 露天原木、木制吊架 | [西欧伐木场](https://data.seicing.com/seicingdepot/3fatcatpool/aoe4/architecture/hre/伐木场.png) |
| 采矿场 | 矿石、矿车、斜臂起重架 | [西欧采矿场](https://data.seicing.com/seicingdepot/3fatcatpool/aoe4/architecture/hre/采矿场.png) |
| 磨坊 | 陡坡屋顶、四叶风车 | [西欧磨坊](https://data.seicing.com/seicingdepot/3fatcatpool/aoe4/architecture/hre/磨坊.png) |
| 铁匠铺 | 陡坡屋顶、烟囱、外接棚和炉区 | [英格兰铁匠铺](https://data.seicing.com/seicingdepot/3fatcatpool/aoe4/architecture/eng/铁匠铺2.png) |
| 攻城器械厂 | 双后厅、开敞组装院；前院加入双轮投石车 | [英格兰攻城器械厂](https://data.seicing.com/seicingdepot/3fatcatpool/aoe4/architecture/eng/攻城武器厂3.png) |

参考图只用于确定轮廓；游戏内建筑仍由本项目的绘制代码生成。

重新生成普通建筑截图：

```sh
docs/godot/bin/godot.macos.template_debug.arm64 --path . \
  --script res://tests/landmark_rendering.gd --rendering-method gl_compatibility \
  -- /tmp/buildings-25d --buildings
docs/godot/bin/godot.macos.template_debug.arm64 --path . \
  --script res://tests/landmark_rendering.gd --rendering-method gl_compatibility \
  -- /tmp/buildings-2d --buildings --topdown
# 把 --buildings 换成 --focus-buildings，可只导出本次重绘的六座建筑。
# 把 --buildings 换成 --fortifications，可导出城堡、哨塔与横纵两向的木墙、木门、石墙、石门。
```

输出目录中的 `all.png` 是总览图，每个建筑也有单独的 PNG。该脚本必须在有图形界面的环境运行，不使用 `--headless`。
