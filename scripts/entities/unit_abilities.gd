extends RefCounted

# Ability/status state belongs to this component; no retained scene references.
var charge_cooldown := 0.0
var stun_timer := 0.0
var momentum_timer := 0.0
var paling_timer := 0.0
var paling_cooldown := 0.0
var volley_timer := 0.0
var volley_cooldown := 0.0
var shield_timer := 0.0
var heal_timer := 0.0
var helm_timer := 0.0
var helm_cooldown := 0.0
var conversion_timer := 0.0
var conversion_cooldown := 0.0
var spirit_buff_timer := 0.0
var revealed_timer := 0.0
var artillery_shot_ready := false
var artillery_shot_cooldown := 0.0

func availability(unit: RtsUnit, ability_id: String) -> Dictionary:
	var cost: Dictionary = GameData.BUILDINGS["scout_camp"]["cost"] if ability_id == "camp" else {}
	var cooldown := 0.0
	match ability_id:
		"palings", "volley":
			if unit.kind != "longbow": return _locked("此单位无法使用该技能", cost)
			cooldown = paling_cooldown if ability_id == "palings" else volley_cooldown
		"pavise":
			if unit.kind != "arbaletrier": return _locked("此单位无法使用该技能", cost)
		"helmsman":
			if unit.kind != "warship": return _locked("此单位无法使用该技能", cost)
			cooldown = helm_cooldown
		"artillery_shot":
			if unit.kind != "cannon" or unit.producer_landmark_id != "fr_college_of_artillery": return _locked("需要战争学院生产的加农炮", cost)
			cooldown = artillery_shot_cooldown
		"convert":
			if unit.kind != "monk": return _locked("此单位无法使用该技能", cost)
			if not is_instance_valid(unit.carried_relic): return _locked("需要携带圣物", cost)
			cooldown = conversion_cooldown
		"camp":
			if unit.game.civilizations[unit.owner_id] != "English" or unit.kind not in ["scout", "man_at_arms"]: return _locked("此单位无法使用该技能", cost)
			var count := 0
			for building in unit.game.buildings:
				if is_instance_valid(building) and building.owner_id == unit.owner_id and building.kind == "scout_camp": count += 1
			if count >= 5: return _locked("已达到 5 座营地上限", cost)
			if not unit.game.can_afford(unit.owner_id, cost): return _locked("木材不足", cost)
			for offset in [Vector2(46, 0), Vector2(-46, 0), Vector2(0, 46), Vector2(0, -46)]:
				var site: Vector2 = unit.position + offset
				if unit.game.can_place("scout_camp", site): return {"available": true, "reason": "", "cost": cost, "site": site}
			return _locked("没有可放置的营地位置", cost)
		_: return _locked("未知技能", cost)
	if cooldown > 0.0: return _locked("冷却 %.0f 秒" % cooldown, cost)
	return {"available": true, "reason": "", "cost": cost}

func _locked(reason: String, cost: Dictionary) -> Dictionary:
	return {"available": false, "reason": reason, "cost": cost}

func activate(unit: RtsUnit, ability_id: String) -> bool:
	var status := availability(unit, ability_id)
	if not status.available: return false
	match ability_id:
		"palings":
			paling_timer = 99999.0
			paling_cooldown = 30.0
			unit.order_stop()
		"volley":
			volley_timer = 5.0
			volley_cooldown = 45.0
		"pavise":
			shield_timer = 99999.0 if shield_timer <= 0.0 else 0.0
			unit.refresh_stats()
		"helmsman":
			helm_timer = 10.0
			helm_cooldown = 30.0
		"artillery_shot": artillery_shot_ready = true
		"convert":
			unit.order_stop()
			conversion_timer = 3.0
			conversion_cooldown = 120.0
		"camp":
			if not unit.game.spend(unit.owner_id, status.cost): return false
			unit.game.spawn_building(unit.owner_id, "scout_camp", status.site)
			unit.game.fog.update_visibility()
	return true

func interrupt_command() -> void:
	conversion_timer = 0.0

func interrupt_movement(unit: RtsUnit) -> void:
	paling_timer = 0.0
	if shield_timer > 0.0:
		shield_timer = 0.0
		unit.refresh_stats()

func tick(unit: RtsUnit, delta: float) -> bool:
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	momentum_timer = maxf(0.0, momentum_timer - delta)
	paling_timer = maxf(0.0, paling_timer - delta)
	paling_cooldown = maxf(0.0, paling_cooldown - delta)
	volley_timer = maxf(0.0, volley_timer - delta)
	volley_cooldown = maxf(0.0, volley_cooldown - delta)
	helm_timer = maxf(0.0, helm_timer - delta)
	helm_cooldown = maxf(0.0, helm_cooldown - delta)
	conversion_cooldown = maxf(0.0, conversion_cooldown - delta)
	artillery_shot_cooldown = maxf(0.0, artillery_shot_cooldown - delta)
	revealed_timer = maxf(0.0, revealed_timer - delta)
	if spirit_buff_timer > 0.0:
		spirit_buff_timer = maxf(0.0, spirit_buff_timer - delta)
		unit.hp = minf(unit.max_hp, unit.hp + 2.0 * delta)
	if conversion_timer > 0.0:
		conversion_timer = maxf(0.0, conversion_timer - delta)
		if conversion_timer <= 0.0: unit._finish_conversion()
		return true
	if unit.kind == "monk": unit._heal_ally(delta)
	unit.movement.tick_charge(delta)
	return stun_timer > 0.0
