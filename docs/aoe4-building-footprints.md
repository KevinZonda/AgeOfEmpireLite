# 《帝国时代 IV》建筑占地参考

2026-09-29 查询；机器可读数据分为[本项目对应建筑](aoe4-building-footprints.json)与[其他原版建筑](aoe4-building-footprints-additional.json)。面积指原版放置格数 `宽 × 高`，不是现实平方米、模型可见面积或本项目的像素面积。这是参考表，不声称覆盖原版全部地标或未来补丁。

[原版建筑总览](https://ageofempires.fandom.com/wiki/Building_(Age_of_Empires_IV))说明，普通建筑按方格放置，墙体采用自由路径；建筑地基边缘还留有单位可通过的空间。因此**放置占格、可见模型和单位实际阻挡范围不是同一个尺寸**。

## 已核实的矩形建筑

| 原版占格 | 格数 | 本项目对应建筑 |
| --- | ---: | --- |
| 2×2 | 4 | [房屋](https://ageofempires.fandom.com/wiki/House_(Age_of_Empires_IV))、[农田](https://ageofempires.fandom.com/wiki/Farm_(Age_of_Empires_IV))、[磨坊](https://ageofempires.fandom.com/wiki/Mill_(Age_of_Empires_IV))、[伐木场](https://ageofempires.fandom.com/wiki/Lumber_Camp_(Age_of_Empires_IV))、[采矿场](https://ageofempires.fandom.com/wiki/Mining_Camp_(Age_of_Empires_IV))、[哨塔](https://ageofempires.fandom.com/wiki/Outpost_(Age_of_Empires_IV)) |
| 3×3 | 9 | [兵营](https://ageofempires.fandom.com/wiki/Barracks_(Age_of_Empires_IV))、[靶场](https://ageofempires.fandom.com/wiki/Archery_Range_(Age_of_Empires_IV))、[马厩](https://ageofempires.fandom.com/wiki/Stable_(Age_of_Empires_IV))、[攻城器械厂](https://ageofempires.fandom.com/wiki/Siege_Workshop_(Age_of_Empires_IV)) |
| 4×4 | 16 | [城镇中心](https://ageofempires.fandom.com/wiki/Capital_Town_Center)、[铁匠铺](https://ageofempires.fandom.com/wiki/Blacksmith_(Age_of_Empires_IV))、[大学](https://ageofempires.fandom.com/wiki/University_(Age_of_Empires_IV))、[码头](https://ageofempires.fandom.com/wiki/Dock_(Age_of_Empires_IV))、[市场](https://ageofempires.fandom.com/wiki/Market_(Age_of_Empires_IV))、[修道院](https://ageofempires.fandom.com/wiki/Monastery_(Age_of_Empires_IV))、[城堡](https://ageofempires.fandom.com/wiki/Keep_(Age_of_Empires_IV)) |
| 6×6 | 36 | [奇观](https://ageofempires.fandom.com/wiki/Wonder_(Age_of_Empires_IV)) |

以上单体尺寸来自《帝国时代》社区 Wiki 对应页面的 **Statistics → Size** 信息框，属于社区整理资料，尚未用本机原版游戏或游戏蓝图逐一复测。[官方 6.0.878 更新说明](https://www.ageofempires.com/news/ageiv_seasonfour_update_60878/)另外明确：两座马里地标从 5×5 改为 4×4；马里奇观从 5×5 改为 6×6。**4×4 不是所有地标的无例外规则**，见下表的智慧宫和撒哈拉贸易网络。

## 其他文明专属建筑和变体

下表列出新增数据中有明确数字的 35 种建筑；每项的文明、证据类型和直接来源链接在 [JSON](aoe4-building-footprints-additional.json) 中。特别要留意同一功能的建筑可能尺寸不同，例如普通马厩为 3×3，晋朝战马厩为 4×4；普通哨塔为 2×2，金帐汗国强化哨站为 3×3。

| 原版占格 | 格数 | 其他建筑 |
| --- | ---: | --- |
| 2×2 | 4 | 水池、橄榄树林、蒙古包、农舍、牧场、狩猎小屋、木制堡垒 |
| 3×3 | 9 | 雇佣兵之家、敖包、强化哨站、庄园、锻造厂、瓦兰吉堡垒、牧牛场、大名庄园、撒哈拉贸易网络 |
| 4×4 | 16 | 村庄、粮仓、佛塔、黄金大帐、佛寺、日式城堡、神社、草场、机械工坊、战马厩、圣殿骑士总部、要塞、海港、瓦兰吉军械库、军事学校、祭典所、图格鲁克堡、祈祷帐篷 |
| 5×5 | 25 | 智慧宫 |

[智慧宫](https://ageofempires.fandom.com/wiki/House_of_Wisdom)为 5×5；[撒哈拉贸易网络](https://ageofempires.fandom.com/wiki/Saharan_Trade_Network)为 3×3。这两座地标说明官方 6.0.878 更新里“与其他地标一致”的措辞不能当作覆盖全部地标的尺寸清单。其余地标如需逐座精确使用，仍应逐座核对。

## 特殊和未核实的占地

- [木墙](https://ageofempires.fandom.com/wiki/Palisade_Wall_(Age_of_Empires_IV))、[石墙](https://ageofempires.fandom.com/wiki/Stone_Wall_(Age_of_Empires_IV))沿路径分段铺设；[木门](https://ageofempires.fandom.com/wiki/Palisade_Gate_(Age_of_Empires_IV))和[石门](https://ageofempires.fandom.com/wiki/Stone_Wall_Gate)属于墙体系统。查到的页面没有给出可比作独立建筑的固定矩形占格，JSON 中保留 `null`。
- 中国的[长城门楼](https://ageofempires.fandom.com/wiki/Great_Wall_Gatehouse)需要至少连续三段石墙。它不应直接沿用独立地标的 4×4。
- 本项目的“预备营地”没有查到原版同名建筑，JSON 中保留 `null`。
- 另有 11 项原版专属建筑（包括水渠、畜栏、露天金矿、瓦兰吉军营等）未查到足以确认矩形占格的资料，或采用墙体放置方式。它们也在[新增数据](aoe4-building-footprints-additional.json)中逐项保留为 `null`，没有按相似建筑猜测。

## 与本项目尺寸的关系

本项目在 [`game_data.gd`](../scripts/catalogs/game_data.gd) 为 19 类有数字来源的建筑配置 `footprint_tiles`，[`game.gd`](../scripts/game.gd) 按现有 **25 世界单位一格**放置。2×2 的房屋、农田和三种采集建筑，以及 4×4 地标的实体尺寸也缩小到地基以内；实体尺寸仍独立控制绘制和碰撞。原版一格与本项目 25 世界单位之间没有已核实的物理换算关系，这次采用的是**占格数量**，不是现实比例。

目前游戏里尚无可靠原版矩形占格数据的是：预备营地、木墙、石墙、木门、石门。它们继续使用原有的 3×3 或 3×1 墙段规则。18 座具体地标也尚未逐座核实占格，目前共用 4×4 地基；这是通用近似值，不是每座地标的已证实尺寸。尤其中国长城门楼在原版依附石墙，不能视为普通 4×4 独立建筑。
