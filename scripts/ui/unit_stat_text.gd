extends RefCounted

const PROFILE_LABELS := {"melee": "近战", "ranged": "远程", "siege": "攻城", "charge": "冲锋", "structure": "对建筑", "torch": "火炬", "hunt_melee": "狩猎近战", "hunt_ranged": "狩猎远程"}

static func active_profiles(stats: Dictionary) -> Dictionary:
	var result := {}
	for id in stats.get("profiles", {}):
		var profile: Dictionary = stats["profiles"][id]
		if float(profile.get("damage", 0.0)) > 0.0: result[id] = profile
	return result

static func attack_text(id: String, profile: Dictionary, compact := false) -> String:
	var format := "%s %d×%.0f  ·  间隔 %.2f 秒  ·  射程 %.1f 格" if compact else "%s：%d × %.0f  ·  间隔 %.2f 秒  ·  射程 %.1f 格"
	return format % [PROFILE_LABELS.get(id, id), int(profile.get("hits", 1)), float(profile.get("damage", 0.0)), float(profile.get("cooldown", 1.0)), float(profile.get("range", 0.0)) / 30.0]

static func bonus_text(bonus: Dictionary, compact := false) -> String:
	return "%s +%.0f" % [bonus.get("source_label", "加成" if compact else "额外伤害"), float(bonus.get("amount", 0.0))]
