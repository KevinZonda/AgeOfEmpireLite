#!/usr/bin/env python3
"""Consolidate independently executed cases without counting variants as bugs."""
import collections
import json
import pathlib
import re

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT.parents[1]
ISSUES = [
    ("P1", "原地重复贸易指令可以刷黄金", ["trade_reissue"], "scripts/entities/unit_work.gd", "process_trade_order", "让商人先抵达中立贸易站，连续重新下达贸易指令。10 次模拟 tick 内位置不变，却增加 120 黄金。", "重新下令把 trade_returning 清为 false；到站检测没有记录这次收益是否已领取。收益应绑定实际完成的贸易行程。"),
    ("P1", "失效的资源集结点导致训练扣费却不出单位", ["rally_dead_fish", "rally_dead_tree", "rally_dead_farm"], "scripts/entities/building.gd", "_process", "把码头/城镇中心集结到鱼群、树或农田，排入训练，再让目标耗尽或被毁并完成释放，最后完成训练。队列变空、单位数不增加。", "建筑先 pop_front，再把已释放的 rally_target 传给类型为 Node2D 的 spawn_unit 参数，报 Invalid type。调用在进入 spawn_unit 内部检查前失败，任务和已付资源一起丢失。"),
    ("P1", "已淘汰玩家仍能以圣地胜利结束混战", ["sacred_eliminated_wins"], "scripts/match/entity_registry.gd", "eliminate_player", "三人混战中，让玩家 1 持有全部圣地，随后摧毁其最后一个城镇中心；另外两名玩家仍存活。再推进 91 秒。", "defeated_players 包含 1，但 sacred_holder 仍为 1，remaining 归零并把 game_over 设为 true。淘汰没有使圣地持有关系失效，目标管理器也不检查持有者是否已淘汰。"),
    ("P1", "继续施工会抹掉建筑受到的伤害", ["construction_damage", "construction_zero", "construction_repair", "construction_completion_damage", "construction_real_worker"], "scripts/entities/building.gd", "advance_construction", "正常村民施工后给未完工房屋造成 40 点伤害，再施工 1 秒。按原进度增加的血量应为 72.88，实际达到 112.88；竣工也会直接恢复满血。", "每次施工把 hp 赋值为理论进度血量，没有保留既有伤害。另有 0 delta 和维修后继续施工的边界变体；这五个 PoC 只算一个根因。"),
    ("P1", "商人返程永远无法进入市场结算距离", ["trade_return_market"], "scripts/entities/unit_work.gd", "process_trade_order", "使用可合法放置的市场，让商人抵达贸易站并返程，从市场外可通行位置再推进 30 秒。", "返程收入为 0，距离市场中心 68，order=trade、trade_returning=true。市场半宽为 56，商人半径 11，而结算距离仍固定为 46，位于不可占据区域。"),
    ("P1", "命官停在建筑外却无法产生监督加成", ["supervise_town_center", "supervise_barracks"], "scripts/entities/building.gd", "_process", "中国命官从建筑外正常走到城镇中心或兵营监督；等其到位后，在建筑里训练单位并更新生产。", "城镇中心停距 87.25，兵营停距 71.25，生产 work_rate 均为 1.0。命官接近建筑按半宽+半径+4计算，而加成只接受中心距离 <=70；这两个条件没有共用尺度。"),
    ("P1", "攻击命令持续追踪战争迷雾内敌军的实时坐标", ["hidden_attack_tracking"], "scripts/entities/unit_combat.gd", "process_attack_order", "在敌军可见时下达攻击；让敌军进入已不可探测的区域，再推进攻击者两个模拟 tick。", "enemy_detected=false，攻击者仍以敌军最新位置 (2000,1900) 为 route_goal。有效目标与攻击执行没有视野检查或最后可见坐标，隐藏敌军仍被实时追踪。"),
    ("P2", "驻军村民保持选中，能扣费建造无人施工的地基", ["selection_after_garrison"], "scripts/entities/unit_orders.gd", "enter_garrison", "选中村民并正常下令进入城镇中心，保持选择，然后点击房屋建造并在地图上放置。", "驻军成功后仍 selected=true，11 个建造按钮可用；扣除 80 木材并生成地基，但村民 order=idle。建造调用只筛选 owner/kind，没有筛掉驻军者；界面还显示正在建造。"),
    ("P2", "Shift 排队耕种忙碌农田时静默丢弃指令", ["queued_farm_frees_later", "queued_farm_alternative"], "scripts/entities/unit_orders.gd", "prepare", "让一位村民耕种农田，另一位远处村民先移动，再 Shift 排队耕种该农田；让原村民离开后激活队列。另一个变体在原田旁保留空田。", "两种情况 queued_gather_commands 都为 0，后续激活变成 idle。入队时就按当前占用和当前村民附近 190 范围验证，导致未来本可执行的意图没有进入队列。"),
    ("P2", "农田集结点已被占用时，新村民直接原地闲置", ["rally_full_farm"], "scripts/match/entity_registry.gd", "spawn_unit", "将城镇中心集结点设到已有农夫的农田，然后训练村民。", "新村民 order=idle，连移动到集结点的指令都没有。gather 入场失败后没有移动或其他工作的兜底。与上项排队拒绝的入口不同，分别记录。"),
    ("P2", "已发射的己方弹丸仍伤害刚被招降的友军", ["conversion_projectile"], "scripts/entities/projectile.gd", "_process", "己方射向敌军的弹丸仍在飞行时，用携圣物修士把目标招降，再让弹丸命中。", "目标 owner 从 1 变为 0，生命仍从 90 降到 80。弹丸命中时直接对原 target.take_damage，没有重新验证敌我关系。"),
    ("P2", "招降商人后可继续使用敌方市场贸易", ["conversion_trader"], "scripts/entities/unit_orders.gd", "prepare", "敌方商人已有贸易路线时招降它；己方没有市场，再恢复贸易。", "恢复成功，但 converted_owner=0、home_owner=1。贸易入场只检查原 trade_home 是否有效，没有检查其归属。"),
    ("P2", "攻击地面绕过投石机最小射程", ["ground_min_range"], "scripts/entities/unit_combat.gd", "process_attack_ground", "给投石机下令攻击距离仅 20 的地面位置。", "最小射程为 82.5，却立即生成 1 发弹丸。普通攻击处理最小射程，攻击地面没有同等检查或撤退逻辑。"),
    ("P2", "炮击齐射在攻击地面时不生效，也不消耗技能", ["ground_artillery_ability"], "scripts/entities/unit_combat.gd", "process_attack_ground", "使用战争学院生产的加农炮，激活炮击齐射，再攻击射程内地面。", "已生成弹丸，但 artillery_shot_ready 仍为 true、冷却为 0。普通攻击消费技能并设 35 秒冷却，攻击地面走了不同路径。"),
    ("P2", "选中敌军被招降后，指令面板仍为空", ["conversion_selection"], "scripts/entities/unit_combat.gd", "finish_conversion", "查看一名敌军的面板，让己方修士招降它，再按正常 HUD 刷新路径更新。", "owner 已变为 0，commands_before=0、commands_after=0。所有权变化没有发布 selection/entities 变更，命令面板没有重建；重新选择才能更新。"),
    ("P1", "同队共享视野没有共享森林内单位的探测", ["allied_forest_visibility", "allied_scout_detection"], "scripts/world/fog_of_war.gd", "can_detect_unit", "2v2 中让盟友单位进入潜伏森林；另一个变体让盟友斥候在 55 距离内侦察森林中的敌军。己方观察者留在远处。", "地形已经可见，但盟友单位/被盟友斥候发现的敌军仍不可探测。早返回只认同 owner，森林观察者循环也只接受同 owner。own_scout_detection 为对照。"),
    ("P2", "修士不治疗同队盟友", ["monk_heal_teammate"], "scripts/entities/unit_combat.gd", "heal_ally", "2v2 中，把受伤的盟友士兵放到己方修士旁 35 距离内，推进一次治疗。", "same_team=true，但血量保持 60；同 owner 对照会增加到 67。治疗筛选用了 owner_id 完全相等，而不是友方队伍关系。"),
    ("P2", "法国 AI 的城堡吸附到网格后落到优惠范围外", ["french_keep_influence_snap"], "scripts/ai/ai_economy.gd", "_construct_french_keep", "种子 431，给法国 AI 马厩和充足资源，调用现有城堡选址行为并完成城堡。", "候选点只按吸附前的 125/155/175 半径枚举，没有再次验证最终实际位置距马厩是否 <=180。以运行结果中的 distance 和 bonus_active 为准。"),
]

def log_cases(path):
    if not path.exists(): return []
    return [json.loads(line[5:]) for line in path.read_text().splitlines() if line.startswith("CASE ")]

def source_link(path, function):
    lines = (ROOT / path).read_text().splitlines()
    line = next((i+1 for i,s in enumerate(lines) if re.search(r"func " + re.escape(function) + r"\(", s)), 1)
    return f"[{path}:{line}](../../{path}#L{line})"

def main():
    records = {}
    for name in ["explore-initial.log", "explore.log", "repeat.log"]:
        for entry in log_cases(OUT / "logs" / name):
            records[entry['id']] = entry | {'log': 'logs/' + name}
    expected_block = (OUT / 'explore.gd').read_text().split('var cases := [',1)[1].split('\n]',1)[0]
    expected = re.findall(r'"([a-z_]+)"', expected_block)
    missing = sorted(set(expected)-records.keys())
    assert not missing, f"Unexecuted cases: {missing}"
    repeat = {r['id']:r for r in log_cases(OUT/'logs/repeat.log')}
    assert 'EXPLORATION_COMPLETE' in (OUT/'logs/repeat.log').read_text(), 'repeat batch incomplete'
    issues = [i for i in ISSUES if any(records[c]['status']=='bug' for c in i[2])]
    suites = sum([json.loads((OUT/name).read_text()) for name in ['baseline.json','navigation.json','strategy.json']], [])
    statuses = collections.Counter(r['status'] for r in records.values())
    summary = {'scenarios':len(records),'scenario_statuses':dict(statuses),'root_causes':len(issues),'repeat_cases':len(repeat),'existing_scripts':len(suites),'existing_statuses':dict(collections.Counter(r['status'] for r in suites)),'missing':missing}
    (OUT/'results.json').write_text(json.dumps([records[c] for c in expected],indent=2,ensure_ascii=False))
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False))
    paragraphs = [
        '# 游戏探索与 PoC 报告 · 2026-10-02',
        f'本轮执行 **{len(records)} 个新探索场景**，重点复验 **{len(repeat)} 个场景**，按根因合并为 **{len(issues)} 类确认问题**。另外运行 **{len(suites)} 个已有测试脚本**：53 个通过、7 个失败退出、9 个超时。超时中存在断言失败后未主动 quit 的脚本，不能将这些结果全部当成游戏 bug。',
        '范围覆盖经济、施工、生产队列、资源集结点、农田、指令排队、招降、战斗、驻军、运输、多人队伍、迷雾、胜负、AI 和寻路。工作仅添加/更新本目录的审计产物，没有修改游戏业务脚本。测试使用项目本地补丁引擎 Godot 4.7.2、macOS ARM64，以确定性模拟为主；通过实际窗口渲染复核了三处状态。没有把它描述为人工游玩完整长局。',
        '结果按原始日志合并；一次整批执行达到 240 秒时间上限，随后用独立批次完成重点复验和补充场景。`summary.json` 的 missing 为空，表示脚本中声明的场景均有执行记录，而不是把整批超时算作执行成功。复验触发的资源集结点 SCRIPT ERROR 是要复现的游戏问题，脚本仍继续执行并打印 EXPLORATION_COMPLETE。',
        '## 复现入口',
        '完整执行（可耗时数分钟）：\n\n```sh\npython3 poc/exploration-2026-10-02/run.py --jobs 1 --timeout 600\n```',
        '独立复现某个场景：\n\n```sh\nmake run RUN_ARGS=\'--headless --script res://poc/exploration-2026-10-02/explore.gd -- trade_return_market\'\n```\n\n把末尾场景 ID 换成下表或结果文件中的 ID；可一次传入多个 ID。退出码 0 表示探索脚本完成，是否出现问题以 CASE.status 和 evidence 为准。默认会重新写 results.json；可用 RTS_POC_RESULTS 指定其他结果文件。',
        '## 按根因合并的问题',
    ]
    table = ['|编号|优先级|问题|主要 PoC|','|---|---|---|---|']
    for n,i in enumerate(issues,1): table.append(f'|B{n:02d}|{i[0]}|{i[1]}|`{i[2][0]}`|')
    paragraphs.append('\n'.join(table))
    paragraphs.append('P1 表示经济功能失效、胜负错误或明显可利用漏洞；P2 表示特定操作、界面或战斗分支的功能错误。优先级是本轮建议。')
    for n,(priority,title,cases,path,function,steps,cause) in enumerate(issues,1):
        paragraphs += [f'### B{n:02d} · {title} · {priority}',f'触发：{steps}',f'实际与原因：{cause}',f'定位：{source_link(path,function)}。场景：'+', '.join(f'`{c}`' for c in cases)+'.']
        for case in cases:
            r=records[case]
            paragraphs.append(f'- `{case}`：{r["status"]}；证据 `{json.dumps(r["evidence"],ensure_ascii=False,separators=(",",":"))}`；[日志]({r["log"]})。')
    paragraphs += ['## 需要确认规则或进一步证明触发路径的观察项',
                  '以下记录保留为 observation，不计入确认问题数量。直接调用内部方法验证的不变量，不等于证明普通玩家能通过界面触发。']
    for c in expected:
        r=records[c]
        if r['status']=='observation': paragraphs.append(f'- `{c}`：`{json.dumps(r["evidence"],ensure_ascii=False,separators=(",",":"))}`。')
    paragraphs += ['人口超限、命官招降后超过训练上限、招降者继续站在敌墙上、修士/商人是否允许驻军都涉及设计预期。重复-host、驻军/运输乘员被外部直接杀死、重叠贸易站属于白盒边界布置；没有将这些直接计为可利用的游戏缺陷。同队保留已淘汰盟友的圣地可能合理，单独记录；FFA 中已淘汰者触发胜利则是明确问题。',
                  '## 已有测试失败的分流',
                  '- `smoke`：旧断言要求底部 HUD 抑制边缘卷页；当前 `edge_scrolling` 明确要求最外缘卷页，并且通过。属于互相冲突的旧测试预期。',
                  '- `chinese`、`villager_post_construction`、`unit_orders_regression`：部分摆位落在放大后的建筑碰撞范围内；直接 orders.tick 与完整 unit._process 的重叠恢复行为不同，可能影响旧布置。新的正常施工、完工采集和攻城塔停靠场景已通过。旧测试失败未逐项确诊，不能全部列为游戏 bug。',
                  '- `rally_landmarks`：默认 2.5D 下，点击坐标会先转换为地面坐标，旧断言仍直接比较未转换坐标。这可能影响结果，需统一测试坐标约定后复核。',
                  '- `navigation_tasks_poc`：市场返程失败被新场景独立确认；农田到达断言仍使用旧半宽 27.5，当前农田半宽 38.4。96 工人场景 91/96 完成退出队列，其余停滞保留为拥挤压力观察，尚未证明无限卡死。',
                  '- `navigation_state_poc`：忙碌农田排队被新场景确认；若干 boarding 布置没有通过 can_place，本轮不将这些失败计为海陆通行漏洞。',
                  '- `navigation_corner_poc`：818 个检查中 20 个失败均属于动态单位切线的亚像素接触；需要结合碰撞容差策略判断，未计为 20 个独立 bug。',
                  '- `fog_unit_flash_poc`：旧脚本声明复现 2D 头部问题，但没有显式切回 2D；当前默认是 2.5D，且全身显示判定不同。保留失败日志，本轮没有将其计为永久不可见 bug。',
                  '- `match_simulation_regression` 的 process_frame epoch 断言、`player_input_actions_regression` 的快捷键子节点访问、`lobby_setup`/`group_multiplayer` 的旧测试假设：保留为测试维护项，未作独立游戏 bug 结论。',
                  '- `civ_map_ai` 城堡范围断言对应新增 `french_keep_influence_snap` 场景；实际结果保存于 results.json。`ai_long_match` 仅达到 120 秒墙钟时限，没有失败断言，不能据此声称 AI 长局卡死。',
                  '## 画面与原始产物',
                  '- [商人返程](screenshots/trade_return_market.png)\n- [命官监督](screenshots/supervise_town_center.png)\n- [驻军村民仍能建造](screenshots/selection_after_garrison.png)',
                  '截图来自 `visual_witness.gd` 在实际 Godot 窗口渲染后的视口图像，上方证据面板仅由 PoC 脚本添加。截图生成没有保存用户显示设置。',
                  '- [合并结果](results.json) · [统计](summary.json) · [复验结果](results-repeat.json)\n- [初次完整 57 场景日志](logs/explore-initial.log) · [整批执行日志](logs/explore.log) · [重点复验日志](logs/repeat.log)\n- [基线](baseline.json) · [寻路](navigation.json) · [AI/边缘卷页](strategy.json)\n- [源码 SHA-256 清单](source-manifest.json)',
                  '通过项包括圣物掉落/修道院摧毁、农田独占、取消退款、市场买卖无套利、无效排队目标跳过、友敌城门、攻城塔停靠、完工后务农/采集、暂停冻结生产、重开清理弹丸、运输船死亡清理乘员等。已保存源码清单，供后续修复前后比较。']
    (OUT/'README.md').write_text('\n\n'.join(paragraphs)+'\n')
    print(json.dumps(summary,ensure_ascii=False))

if __name__ == '__main__': main()
