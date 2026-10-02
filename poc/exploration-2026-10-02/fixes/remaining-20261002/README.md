# 全部补丁合并到 main

按用户“先把所有的 patch 合并到 main”的新指令，B07–B20 共 14 组补丁已顺序合入 main 工作区，共 27 个文件，无补丁冲突，保留原 B01–B06、B21 v2 及期间的外部改动。见 [应用记录](main-application.json)。随后观测到 main 提交 `da21543c0011b801c05ec0726d9dd85eff482391` 包含这些补丁和外部加入的野猪反击修复，见 [提交观察](main-commit-observation.json)。本执行环境原仓库 `.git` 只读，提交由外部执行者产生，未将其计作本代理完成的验证提交或推送。

[逐项定向结果](targeted-summary.json)：14 项无界面测试通过；B20 图像测试受已记录的原生启动阻塞，未重复启动。组合可用回归与 63 个探索场景在 [combined-available](combined-available)；当前 main 的独立定向结果在 [main-targeted](main-targeted)。组合运行已于 548.078 秒结束：165 项实际执行全部通过、18 项原生明确跳过；63 个探索场景为 52 通过、0 bug、11 观察，源码期间不变。`complete`、`no_new_failures` 仍为 false，因为原生项尚未执行。当前 main 的 16 项定向记录全部 passed，但外部在运行中修改了 `resource_node.gd`，整体源码稳定门槛为 false；保留这一事实，不改写为完整验证。组合副本保留 B21 候选代码，但不再调查 B21，不包含后来外部添加的野猪反击代码。

完整原生验证、逐 bug 验证提交与推送、最终四种子统计实验仍属待办，没有把可用回归或定向测试改称完整全绿。施工互堵及相同环境阻塞按用户指令暂缓，记录在 [deferred-issues.json](deferred-issues.json)，其他修复后返回。

B22 招降后混合选择可控制敌方单位的漏洞也已合入 main 工作区：24 项控制由旧版 10 失败变为 0 失败；当前 main 的新 PoC 与三个现有玩家命令回归全部通过，执行期间源码未变。见 [B22 应用记录](B22/application.json)、[当前 main 定向验证](B22/main-targeted/results.json)。该新增补丁尚未执行完整原生回归，不在前述 165 项冻结组合验证范围内；截至记录时为工作区改动，原仓库 `.git` 只读，未由本代理提交或推送。
