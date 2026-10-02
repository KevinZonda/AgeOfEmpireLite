# B21：密集施工队列中的互堵

候选修复已经写回主工作区，独立验证副本为 `/private/tmp/AgeOfEmpireLite-b21-v2-validation`，验证基线为 B05 提交 `1b6d95e6a6a6bbd2545940591e79ef291150760e`。**按用户最新指令暂缓本问题，待其他 bug 修复后回头处理；完整验证、commit、push 尚未完成。** 写回时保留了原 B06 暂存变更及 Git 索引，见 [工作区应用记录](workspace-application.json)。随后发现当前 HEAD 被外部更新为 `9fcca22c35e8952c912c651c9b1efde74bfa8cca`，其中已包含 B06；不将该外部提交计作本候选的提交或推送。

## 复现与原因

- 原密集队列测试有真实失败：48 名工人仅完成 89/96 座建筑，7 人队列未结束。保留原 96 座建筑的布局、合法位置、2600 步期限和碰撞规则，重建这 7 个单位。
- 旧礼让仅接纳闲置单位或卡住的普通移动单位，不接纳仍在路上且卡住的施工、修理、采集单位。
- 路由重建和后台寻路结果会清零 `route_stalled_time`，即使单位的位置完全没有变化。工作单位的礼让改用独立的实际位移停滞时间；新命令、目标、交互距离、实际位移及到位时清零。
- 原六个退让方向缺少沿通道前后的方向。以真实 4.52 像素步长复现三单位互堵时，六方向失败，给卡住的工作单位增加 `±PI/2` 后成功；普通移动与闲置单位保留原六个方向。原碰撞扫掠、ID 优先级、保持位置、敌方边界、递归层数和步长限制保持有效。

7 单位旧版复现受寻路调度影响，有失败也有自行恢复，不能宣称每次必败。确定性的工作礼让及六方向/八方向对照另行保存。最初使用 2.4 像素的几何缩减不足以证明方向缺失，纠正过程与原日志保留在 [独立几何证据](independent-geometry/results.json)。

## 修复与证据

当前补丁：[b21-final-v2.patch](b21-final-v2.patch)，SHA256 `eed200f4bac622dfde5e3affe5e6d75d1e15b484e3a3a49d8ca9c1bef6648847`。当前三份源码在 [source-final-v2](source-final-v2)，哈希在 [source-final-v2-hashes.json](source-final-v2-hashes.json)。此前候选补丁及失败尝试保留，不能用其结果替代最终源码验证。

最终 PoC 有 113 项检查：合法布局、7 人施工与后续队列、碰撞/瞬移、三种工作指令的礼让边界、已到位工人、移动目标、跨指令旧 group 状态、实际停滞计时与后台结果、三单位纵向礼让。两轮独立 B05 执行通过。另有 172 项安全控制、12 项真实计时控制通过；这些均不替代完整回归。

第一轮 [可用回归](../B21-available/summary.json)：151/169 项脚本实际执行，147 通过、4 项基线已有失败；63 个探索场景全部执行（35 通过、16 个待修复问题、12 个观察）。48/96 名工人的原密集队列测试均完成全部 96 座建筑、清空队列，未放宽布局、期限、碰撞及瞬移检查。源码运行期间未变。

第一轮使用 106 项的旧 PoC 测试文件。最终修正了修理工测试距离并补入几何控制，游戏代码不变；旧的全单位八方向版本复核在 [B21-available-final](../B21-available-final)，因采用范围更窄的 v2 已正常取消：AI 2501.9 秒后取消，146 通过、4 已有失败、18 原生跳过，0/63 完整探索；引擎退出已确认，源码未变，不属于完成证明。

v2 只给卡住的工作单位增加两个方向。相同 169 个闲置单位初态的独立对照，原六方向查询中位 36.25 ms、通用八方向 83.865 ms、v2 40.411 ms；全部 33 次布局、碰撞、工作/队列等 11190 项控制通过。此微基准证明该布局中的方向搜索成本，不可将倍率推广为整场 AI 加速；[因果记录](worker-only-angle-causal-summary.json)。最终 v2 的 [可用回归](../B21-available-v2/summary.json) 已结束：453.212 秒，151 项实际执行（147 通过、4 项已有失败），18 项原生测试明确跳过；63 个探索场景全部执行（35 通过、16 个问题、12 个观察）。113 项 PoC、AI 长局（189.4 秒）和密集施工的 31 项检查均通过，源码运行期间不变。该结果仍是 `complete: false`，不能称为完整验证。主工作区 B06 + B21 的 [定向集成验证](../B21-workspace-targeted/results.json) 三项均通过，也不能替代全量验证。

## 当前阻塞与下一步

当前 macOS 原生窗口启动遇到 LaunchServices / `hiservices` XPC 连接失败。真实 `smoke` 60 秒、`farm_rendering` 120 秒超时，未出现 Godot 启动或像素输出。可用回归明确跳过 18 项原生测试，结果保持 `complete: false`、`no_new_failures: false`，没有用旧图像或无界面运行替代原生测试。最新 v2 smoke 同样在 60.078 秒超时，见 [v2 启动记录](../tool-validation/b21-v2-native-startup/result.json)。证据：[smoke](../tool-validation/b21-native-isolation-r2/result.json)、[farm_rendering](../tool-validation/macos-temp-isolation-native/result.json)。

GitHub 连接实测失败：`Could not resolve host: github.com`，见 [最新连接记录](push-connectivity-v2.json)。完整测试门槛尚未达到，因此没有为本候选制作游戏修复提交或声称已推送。

环境恢复后，在最终源码的独立副本执行正常完整 runner（不得使用跳过原生测试的诊断 wrapper）：

```sh
python3 tools/run_full_tests.py --engine /Users/kevin/Desktop/AgeOfEmpireLite/docs/godot/bin/godot.macos.template_debug.arm64 --output /tmp/ageofempirelite-b21-full --profile regression --jobs 2 --timeout 1800 --compare /Users/kevin/Desktop/AgeOfEmpireLite/poc/exploration-2026-10-02/fixes/B05-r3
```

仍按既定顺序：完整 regression 与全部 63 场景执行、无新增失败、最终 PoC 及此前修复回归通过、源码哈希不变，才 commit 与 push。用户已要求先处理其余修复，本问题最后返回；不再反复重试相同的环境阻塞。最终版本还需正常 `all` 范围的四种子平衡性实验。
