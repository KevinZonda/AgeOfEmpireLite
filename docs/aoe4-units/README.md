# AoE IV 参考数据

这里保存 [Seicing 的《帝国时代 IV》单位与建筑目录](https://seicing.com/html/aoe2/index-aoe4units.html?civ=chi)中的结构化事实，供兵种谱系、战斗数值和地标机制设计时查阅。它是第三方资料，不是本项目的运行时配置，也不保证与任意游戏补丁完全一致。每条记录都保留了详情页链接；采集日期、文明代码、条目数量和上游缺页见 [`manifest.json`](manifest.json)。

## 目录结构

```text
aoe4-units/
  manifest.json
  chi/
    catalog.json
    units/诸葛弩手.json
    buildings/靶场.json
    landmarks/翰林院.json
  eng/
    ...
```

文明目录名使用来源站点的代码。`catalog.json` 按来源清单保留每个条目的名称、栏目和本地路径；同一通用单位会分别出现在拥有它的文明目录中，方便查看该文明的专属加成。

每个详情文件包含：

- `civilization`、`kind`、`section`、`name`、`source_url`：来源和目录分类。
- `detail.sections`：详情页主表，按原有栏目和字段顺序保存。`values` 是原表从左到右的单元格；四个独立值通常对应Ⅰ至Ⅳ时代。原站用 `-` 表示该时代没有这个数值，不能当成零。跨四列的单值保留 `colspan: 4`。
- `parts`：单元格中的文字和图标按顺序交替排列。例如成本里的图标“肉／木／金”对应后面的数字。单独的 `text` 是去掉图标后的可读文本。
- `detail.bonuses`：来源页面的通用或对应文明的科技、加成表。`civilization: null` 表示通用表。站点通过 `tech.js` 填入的科技费用和效果已解析进这些表。
- `detail.gallery_captions`：页面图集中的名称，仅作文字索引，不作为等级或数值字段。

少数来源目录链接返回 HTTP 404。对应文件仍保留目录条目和 `detail_error`，具体链接见 `manifest.json` 的 `missing_source_pages`。采集器不会猜测缺失数值。

## 重新采集

需要 Python 3、`requests` 和 `beautifulsoup4`：

```sh
python3 -m pip install requests beautifulsoup4
python3 tools/scrape_aoe4_units.py
```

也可以只更新一个文明，例如 `python3 tools/scrape_aoe4_units.py --civ chi`。此命令会将 `manifest.json` 改成仅记录所选文明；要恢复全量目录，再运行不带 `--civ` 的命令。
