# 《帝国时代 IV》建筑占地参考

2026-09-29 查询；机器可读数据见 [aoe4-building-footprints.json](aoe4-building-footprints.json)。范围是**本项目 `GameData.BUILDINGS` 中有《帝国时代 IV》对应物的建筑**，不声称覆盖原版所有文明专属建筑或之后的补丁。面积指原版放置格数 `宽 × 高`，不是现实平方米、模型可见面积或本项目的像素面积。

## 已核实的矩形建筑

| 原版占格 | 格数 | 本项目对应建筑 |
| --- | ---: | --- |
| 2×2 | 4 | [房屋](https://ageofempires.fandom.com/wiki/House_(Age_of_Empires_IV))、[农田](https://ageofempires.fandom.com/wiki/Farm_(Age_of_Empires_IV))、[磨坊](https://ageofempires.fandom.com/wiki/Mill_(Age_of_Empires_IV))、[伐木场](https://ageofempires.fandom.com/wiki/Lumber_Camp_(Age_of_Empires_IV))、[采矿场](https://ageofempires.fandom.com/wiki/Mining_Camp_(Age_of_Empires_IV))、[哨塔](https://ageofempires.fandom.com/wiki/Outpost_(Age_of_Empires_IV)) |
| 3×3 | 9 | [兵营](https://ageofempires.fandom.com/wiki/Barracks_(Age_of_Empires_IV))、[靶场](https://ageofempires.fandom.com/wiki/Archery_Range_(Age_of_Empires_IV))、[马厩](https://ageofempires.fandom.com/wiki/Stable_(Age_of_Empires_IV))、[攻城器械厂](https://ageofempires.fandom.com/wiki/Siege_Workshop_(Age_of_Empires_IV)) |
| 4×4 | 16 | [城镇中心](https://ageofempires.fandom.com/wiki/Capital_Town_Center)、[铁匠铺](https://ageofempires.fandom.com/wiki/Blacksmith_(Age_of_Empires_IV))、[大学](https://ageofempires.fandom.com/wiki/University_(Age_of_Empires_IV))、[码头](https://ageofempires.fandom.com/wiki/Dock_(Age_of_Empires_IV))、[市场](https://ageofempires.fandom.com/wiki/Market_(Age_of_Empires_IV))、[修道院](https://ageofempires.fandom.com/wiki/Monastery_(Age_of_Empires_IV))、[城堡](https://ageofempires.fandom.com/wiki/Keep_(Age_of_Empires_IV)) |
| 6×6 | 36 | [奇观](https://ageofempires.fandom.com/wiki/Wonder_(Age_of_Empires_IV)) |

以上单体尺寸来自《帝国时代》社区 Wiki 对应页面的 **Statistics → Size** 信息框，属于社区整理资料，尚未用本机原版游戏或游戏蓝图逐一复测。[官方 6.0.878 更新说明](https://www.ageofempires.com/news/ageiv_seasonfour_update_60878/)另外明确：两座马里地标从 5×5 改为 4×4，以匹配其他地标；马里奇观从 5×5 改为 6×6，以匹配其他奇观。因此独立地标在本表按 **4×4（16 格）**记录，来源性质为官方对一类建筑的概括，而非逐座实测。

## 特殊和未核实的占地

- [木墙](https://ageofempires.fandom.com/wiki/Palisade_Wall_(Age_of_Empires_IV))、[石墙](https://ageofempires.fandom.com/wiki/Stone_Wall_(Age_of_Empires_IV))沿路径分段铺设；[木门](https://ageofempires.fandom.com/wiki/Palisade_Gate_(Age_of_Empires_IV))和[石门](https://ageofempires.fandom.com/wiki/Stone_Wall_Gate)属于墙体系统。查到的页面没有给出可比作独立建筑的固定矩形占格，JSON 中保留 `null`。
- 中国的[长城门楼](https://ageofempires.fandom.com/wiki/Great_Wall_Gatehouse)需要至少连续三段石墙。它不应直接沿用独立地标的 4×4。
- 本项目的“预备营地”没有查到原版同名建筑，JSON 中保留 `null`。

## 与本项目尺寸的关系

本项目在 [`game_data.gd`](../scripts/catalogs/game_data.gd) 配置世界坐标尺寸，放置时在 [`game.gd`](../scripts/game.gd) 对普通建筑四周各加 9 单位，再按 **25 世界单位一格**向上取整。原版“格”与本项目这个建造格没有已核实的物理换算关系，不能把原版 2×2 直接当作本项目 2×2 使用。这里的数据供布局比例和建筑尺寸调整参考；没有改动游戏配置。
