extends RefCounted

# Combat execution works on RtsUnit state; unit.gd keeps its public methods.
static func process_attack_ground(unit, delta: float) -> void:
	var profile: Dictionary = RtsStatResolver.primary_attack(unit.stats)
	if profile.is_empty() or float(profile.get("damage", 0.0)) <= 0.0:
		unit._advance_command()
		return
	var reach := float(profile.get("range", unit.attack_range()))
	if not unit._move_toward(unit.destination, delta, reach): return
	if unit.attack_timer > 0.0:
		if unit.attack_timer <= 0.16 and unit.visual_action != "attack": unit._start_visual_action("attack", 0.34)
		return
	var projectile := RtsProjectile.new()
	projectile.setup_point(unit.game, unit.owner_id, unit.global_position, unit.destination, float(profile["damage"]), float(unit.stats.get("projectile_speed", 350.0)), maxf(55.0, float(profile.get("splash_radius", 0.0))), unit.stats, profile)
	unit.game.add_child(projectile)
	unit.attack_timer = float(profile.get("cooldown", unit.attack_cooldown()))
	unit.revealed_timer = 2.0
	unit._start_visual_action("attack", 0.28)

static func valid_attack_target(unit, candidate) -> bool:
	if not is_instance_valid(candidate) or not candidate is Node2D or candidate.is_queued_for_deletion(): return false
	if candidate is RtsResource: return candidate.appearance == "boar" and candidate.wildlife_hp > 0.0
	if not (candidate is RtsUnit or candidate is RtsBuilding): return false
	return candidate.hp > 0.0 and unit.game.is_enemy(unit.owner_id, candidate.owner_id) and (not candidate is RtsUnit or candidate.garrisoned_in == null)

static func process_attack_order(unit, delta: float) -> void:
	if unit.target is RtsResource and unit.target.appearance == "boar" and unit.target.wildlife_hp <= 0.0:
		unit._advance_command()
		return
	if unit.auto_engaged and unit.engagement == "defensive" and unit.position.distance_to(unit.engagement_origin) > 175.0:
		var origin: Vector2 = unit.engagement_origin
		if not unit.orders.resume(unit): unit.order_move(origin)
		return
	if unit.resume_order == "patrol" and unit.position.distance_to(Geometry2D.get_closest_point_to_segment(unit.position, unit.patrol_origin, unit.patrol_destination)) > 240.0:
		unit.orders.resume(unit)
		return
	if unit.resume_order == "hold" and unit.position.distance_to(unit.hold_position) > 6.0:
		unit.orders.resume(unit)
		return
	var target_radius := 18.0
	if unit.target is RtsUnit: target_radius = unit.target.radius()
	if unit.target is RtsBuilding: target_radius = maxf(unit.target.size().x, unit.target.size().y) * 0.5 + unit.radius() + 3.0
	var defender_stats: Dictionary = unit.target.stats if unit.target is RtsUnit or unit.target is RtsBuilding else {}
	var charged: bool = unit.charging and unit.charge_distance >= 60.0
	var profile := RtsStatResolver.attack_profile(unit.stats, defender_stats, charged)
	if profile.is_empty(): return
	if unit.target is RtsUnit and is_instance_valid(unit.target.wall_host) and unit.target.wall_host != unit.wall_host and profile.get("damage_kind", "melee") == "melee":
		unit._advance_command()
		return
	var reach: float = float(profile.get("range", unit.attack_range())) + target_radius
	var min_reach: float = float(profile.get("min_range", unit.stats.get("min_range", 0.0))) + target_radius
	if min_reach > 0.0 and unit.position.distance_to(unit.target.position) < min_reach:
		if is_instance_valid(unit.wall_host):
			unit._advance_command()
			return
		var away: Vector2 = (unit.position - unit.target.position).normalized()
		if away.is_zero_approx(): away = Vector2.RIGHT
		# Reuse an escape while it remains outside minimum range. If the
		# straight retreat is obstructed, search the other firing positions.
		var retreat: Vector2 = unit.route_goal
		if retreat == Vector2.INF or retreat.distance_to(unit.target.position) <= min_reach + 6.0 or retreat.distance_to(unit.target.position) > reach or not unit.game.navigation.can_occupy(retreat, unit.radius(), unit, false, false):
			retreat = Vector2.INF
			for angle in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI * 0.75, -PI * 0.75, PI]:
				var candidate: Vector2 = unit.target.position + away.rotated(angle) * (min_reach + 10.0)
				if not unit.game.navigation.can_occupy(candidate, unit.radius(), unit, false, false): continue
				if unit.game.navigation.path_between(unit.position, candidate, unit).is_empty(): continue
				retreat = candidate
				break
		if retreat != Vector2.INF: unit._move_toward(retreat, delta, 6.0)
		return
	if is_instance_valid(unit.wall_host):
		if unit.position.distance_to(unit.target.position) > reach:
			unit._advance_command()
			return
	elif not unit._move_toward(unit.target.position, delta, reach): return
	if unit.attack_timer > 0.0:
		if unit.attack_timer <= 0.16 and unit.visual_action != "attack": unit._start_visual_action("attack", 0.34)
		return
	charged = unit.charging and unit.charge_distance >= 60.0
	profile = RtsStatResolver.attack_profile(unit.stats, defender_stats, charged)
	if charged and unit.target is RtsUnit and unit.target.is_braced() and unit.stats.get("tags", []).has("cavalry"):
		var brace_damage := 19.0 + 5.0 * maxi(0, int(unit.target.stats.get("rank_age", 2)) - 2) if unit.target.kind == "longbow" else RtsCombatRules.profile_damage(unit.target.stats, unit.stats, RtsStatResolver.attack_profile(unit.target.stats, unit.stats), {"brace_impact": true})
		unit.take_damage(brace_damage)
		unit.stun_timer = 2.5
		unit.charging = false
		unit.charge_cooldown = 10.0
		return
	if unit.artillery_shot_ready:
		profile = profile.duplicate(true)
		profile["bonuses"] = []
		profile["splash_radius"] = maxf(65.0, float(profile.get("splash_radius", 0.0)))
		unit.artillery_shot_ready = false
		unit.artillery_shot_cooldown = 35.0
	var modifiers := {"extra_damage": 3.0 if unit.kind == "royal_knight" and unit.momentum_timer > 0.0 else 0.0, "multiplier": RtsCivilizationRules.wall_ranged_multiplier(unit.game, unit) if profile.get("damage_kind", "") == "ranged" else 1.0}
	var damage: float = RtsCombatRules.volley_damage(unit.stats, defender_stats, profile, modifiers)
	if unit.kind == "battering_ram": damage *= 1.0 + minf(0.4, unit.passengers.size() * 0.05)
	if charged:
		unit.charge_cooldown = 10.0
		if unit.kind == "royal_knight": unit.momentum_timer = 3.0
	unit.charging = false
	unit.revealed_timer = 2.0
	if unit.visual_action != "attack": unit._start_visual_action("attack", 0.30)
	if profile.get("damage_kind") == "ranged" or unit.stats.get("primary_profile") == "siege" and float(profile.get("range", 0.0)) > 70.0:
		var projectile := RtsProjectile.new()
		projectile.setup(unit.game, unit.owner_id, unit.global_position, unit.target, damage, float(unit.stats.get("projectile_speed", 350.0)), float(profile.get("splash_radius", 0.0)), unit.stats, profile)
		unit.game.add_child(projectile)
	else:
		var impact_point: Vector2 = unit.target.position
		unit.target.take_damage(damage)
		if charged and float(profile.get("splash_radius", 0.0)) > 0.0:
			for other in unit.game.units:
				if not is_instance_valid(other) or other == unit.target or other.is_queued_for_deletion() or not unit.game.is_enemy(unit.owner_id, other.owner_id) or other.garrisoned_in != null: continue
				if other.position.distance_to(impact_point) <= float(profile["splash_radius"]): other.take_damage(RtsCombatRules.volley_damage(unit.stats, other.stats, profile) * 0.5)
		unit.game.show_hit(unit.position, impact_point, unit.owner_id)
		if unit.kind == "incendiary_ship":
			for other in unit.game.navigation.nearby_units(impact_point, 58.0):
				if is_instance_valid(other) and other != unit.target and unit.game.is_enemy(unit.owner_id, other.owner_id) and other.stats.get("tags", []).has("naval") and other.position.distance_to(impact_point) <= 58.0: other.take_damage(damage * 0.45)
			unit.game.entity_destroyed(unit)
			return
	unit.attack_timer = float(profile.get("cooldown", unit.attack_cooldown())) / (RtsCivilizationRules.english_network_rate(unit.game, unit) * (1.2 if unit.spirit_buff_timer > 0.0 else 1.0))
	if unit.volley_timer > 0.0: unit.attack_timer /= 1.7

static func heal_ally(unit, delta: float) -> void:
	unit.heal_timer = maxf(0.0, unit.heal_timer - delta)
	if unit.heal_timer > 0.0: return
	unit.heal_timer = 1.0
	var ally: RtsUnit
	var missing := 0.0
	for candidate in unit.game.units:
		if not is_instance_valid(candidate) or candidate == unit or candidate.owner_id != unit.owner_id or candidate.garrisoned_in != null or candidate.position.distance_to(unit.position) > 100.0: continue
		if candidate.max_hp - candidate.hp > missing:
			ally = candidate
			missing = candidate.max_hp - candidate.hp
	if ally != null:
		ally.hp = minf(ally.max_hp, ally.hp + 7.0)
		ally.queue_redraw()

static func finish_conversion(unit) -> void:
	if unit.carried_relic == null: return
	var converted := 0
	for candidate in unit.game.units:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not unit.game.is_enemy(unit.owner_id, candidate.owner_id) or candidate.garrisoned_in != null: continue
		if candidate.position.distance_to(unit.position) > 130.0 or candidate.stats.get("tags", []).has("siege"): continue
		candidate.owner_id = unit.owner_id
		candidate.order_stop()
		candidate.refresh_stats()
		converted += 1
		if converted >= 5: break
	if converted > 0:
		unit.game.navigation.invalidate_spatial_index()
		unit.game.fog.update_visibility()

static func take_damage(unit, damage: float) -> void:
	unit.hp -= damage
	unit.hit_flash_timer = 0.18
	if unit.owner_id == 0 and unit.game.has_method("play_feedback"): unit.game.play_feedback("alert")
	unit.queue_redraw()
	if unit.hp <= 0.0:
		unit.cancel_orders()
		if RtsCivilizationRules.is_dynasty_unit(unit.kind) and RtsCivilizationRules.spirit_way_active(unit.game, unit.owner_id):
			for ally in unit.game.units:
				if is_instance_valid(ally) and ally != unit and ally.owner_id == unit.owner_id and ally.position.distance_to(unit.position) <= 150.0:
					ally.spirit_buff_timer = maxf(ally.spirit_buff_timer, 10.0)
		for passenger in unit.passengers.duplicate():
			if is_instance_valid(passenger): unit.game.entity_destroyed(passenger)
		unit.passengers.clear()
		if unit.carried_relic != null:
			unit.carried_relic.carried_by = null
			unit.carried_relic.position = unit.position
			unit.carried_relic = null
		unit.game.entity_destroyed(unit)
