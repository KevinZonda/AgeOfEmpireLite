# Bug 修复与逐项全量验证

原报告的 18 类问题逐项修复；追加 B19 为全量测试确认的空间索引漏碰撞，B20 为视觉快照隔离契约。每项先执行完整 regression 测试范围和 63 个探索场景，检查该项回归通过、没有新增失败及源码运行期间不变，再提交并推送。四种子平衡性统计实验在最终版本完整执行，默认 all 范围也包含该实验。

全量结果保留未修复 PoC 和基线已有失败；`passed: false` 不会被改写为全绿。每轮 comparison 明确列出新增失败、已修复场景和执行缺失。

|编号|修复|全量测试|新增失败|验证提交 / 推送|
|---|---|---|---|---|
|B01|Prevent repeated trade income|[结果](fixes/B01-r2/summary.json)：158通过 / 6已有失败 / 0超时，PoC 63/63，范围 regression|0|[ab877f8b](https://github.com/KevinZonda/AgeOfEmpireLite/commit/ab877f8b7875aa032ac9f47ab25a7bca45fc41ed) · 已推送|
|B02|Preserve training with expired rally targets|[结果](fixes/B02-parallel/summary.json)：159通过 / 6已有失败 / 0超时，PoC 63/63，范围 regression|0|[883162b7](https://github.com/KevinZonda/AgeOfEmpireLite/commit/883162b7bcdcf852a1e7867a8b651cb9aa662c2c) · 已推送|
|B03|Prevent eliminated teams winning objectives|[结果](fixes/B03-r2/summary.json)：160通过 / 6已有失败 / 0超时，PoC 63/63，范围 regression|0|[7a21a028](https://github.com/KevinZonda/AgeOfEmpireLite/commit/7a21a0282d4240c774582bb60191f3a4995d5fef) · 已推送|
|B04|Preserve construction damage and repairs|[结果](fixes/B04-r2/summary.json)：161通过 / 6已有失败 / 0超时，PoC 63/63，范围 regression|0|生成验证提交中 · 待推送|

重跑任一修复的完整验证：

```sh
python3 tools/run_full_tests.py --output /tmp/ageofempirelite-full-recheck --jobs 4 --timeout 600 --compare poc/exploration-2026-10-02/fixes/baseline
```

默认保留 AI 6000 步与四种子各 480 秒的完整模拟；渲染/原生窗口测试单独串行，user:// 使用每项测试独立目录。初始报告、原始失败证据与复现步骤见 [探索报告](README.md)。
