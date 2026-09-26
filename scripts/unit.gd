class_name RtsUnit
extends Node2D

const AUTO_GATHER_RADIUS := 180.0

var game: Node2D
var owner_id := 0
var kind: String
var stats: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var order := "idle"
var destination := Vector2.ZERO
var target: Node2D
var attack_timer := 0.0
var work_timer := 0.0
var charging := false
var charge_distance := 0.0
var charge_cooldown := 0.0
var charge_elapsed := 0.0
var stun_timer := 0.0
var momentum_timer := 0.0
var resume_destination := Vector2.INF
var gather_kind := ""
var gather_location := Vector2.ZERO
var route := PackedVector2Array()
var route_index := 0
var route_goal := Vector2.INF
var route_retry := 0.0
var movement_group: RtsMovementGroup
var group_stuck_time := 0.0
var group_last_position := Vector2.INF
var command_queue: Array[Dictionary] = []
var garrisoned_in: RtsBuilding
var trade_post: RtsTradePost
var trade_home: RtsBuilding
var trade_returning := false
var carried_relic: RtsRelic
var producer_landmark_id := ""
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

func setup(game_ref: Node2D, player_id: int, unit_kind: String) -> void:
	game = game_ref
	owner_id = player_id
	kind = unit_kind
	refresh_stats(false)
	queue_redraw()

func refresh_stats(preserve_damage := true) -> void:
	var missing_hp := maxf(0.0, max_hp - hp) if preserve_damage else 0.0
	stats = RtsUnitCatalog.unit_definition(game.civilizations[owner_id], kind, game.players[owner_id].get("researched", []), game.players[owner_id].get("age", 1), game.players[owner_id].get("landmarks", []), game.players[owner_id].get("dynasty", ""), producer_landmark_id)
	if shield_timer > 0.0:
		stats["armor"]["ranged"] = float(stats["armor"].get("ranged", 0.0)) + 5.0
		for profile_id in stats.get("profiles", {}): stats["profiles"][profile_id]["range"] = float(stats["profiles"][profile_id].get("range", 0.0)) + 30.0
		stats["range"] = float(stats.get("range", 0.0)) + 30.0
	max_hp = float(stats["hp"])
	hp = maxf(1.0, max_hp - missing_hp)
	queue_redraw()

func radius() -> float:
	return float(stats["radius"])

func effective_speed() -> float:
	return float(stats["speed"]) * (1.4 if helm_timer > 0.0 else 1.0)

func order_move(world_point: Vector2) -> void:
	conversion_timer = 0.0
	if paling_timer > 0.0: paling_timer = 0.0
	movement_group = null
	order = "move"
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_attack(enemy: Node2D) -> void:
	conversion_timer = 0.0
	if float(stats.get("damage", 0.0)) <= 0.0: return
	if kind == "battering_ram" and enemy is RtsUnit: return
	if helm_timer > 0.0: helm_timer = 0.0
	movement_group = null
	order = "attack"
	target = enemy
	charging = enemy is RtsUnit and (stats.get("profiles", {}).has("charge") or float(stats.get("charge_bonus", 0.0)) > 0.0) and charge_cooldown <= 0.0 and position.distance_to(enemy.position) >= 110.0 and position.distance_to(enemy.position) <= 180.0
	charge_distance = 0.0
	charge_elapsed = 0.0
	resume_destination = Vector2.INF
	_reset_route()

func order_attack_move(world_point: Vector2) -> void:
	conversion_timer = 0.0
	if paling_timer > 0.0: paling_timer = 0.0
	movement_group = null
	order = "attack_move"
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_stop() -> void:
	conversion_timer = 0.0
	command_queue.clear()
	movement_group = null
	order = "idle"
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func issue_command(command_type: String, world_point := Vector2.INF, target_ref: Node2D = null, append := false, group: RtsMovementGroup = null) -> void:
	var command := {"type": command_type, "point": world_point, "target": target_ref, "group": group}
	if not append:
		command_queue.clear()
		_start_command(command)
	elif order == "idle" and command_queue.is_empty():
		_start_command(command)
	else:
		command_queue.append(command)
	queue_redraw()

func _start_command(command: Dictionary) -> bool:
	movement_group = null
	match command["type"]:
		"group_move", "group_attack_move":
			if command["type"] == "group_attack_move" and not stats.get("tags", []).has("military"): return false
			movement_group = command.get("group")
			if movement_group == null: return false
			movement_group.activate()
			if movement_group.route.is_empty():
				movement_group = null
				return false
			order = "attack_move" if command["type"] == "group_attack_move" else "move"
			destination = movement_group.destination_for(self)
			target = null
			charging = false
			resume_destination = Vector2.INF
			group_stuck_time = 0.0
			group_last_position = position
			_reset_route()
		"move": order_move(command["point"])
		"attack_move":
			if not stats.get("tags", []).has("military"): return false
			order_attack_move(command["point"])
		"attack":
			if not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion(): return false
			if float(stats.get("damage", 0.0)) <= 0.0: return false
			if kind == "battering_ram" and command["target"] is RtsUnit: return false
			order_attack(command["target"])
		"gather":
			if not ["villager", "fishing_boat"].has(kind) or not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion(): return false
			if kind == "fishing_boat" and (not command["target"] is RtsResource or command["target"].appearance != "fish"): return false
			if kind == "villager" and command["target"] is RtsResource and command["target"].appearance == "fish": return false
			order_gather(command["target"])
		"trade":
			if kind != "trader" or not command["target"] is RtsTradePost: return false
			trade_home = game.find_nearest_owned_building(owner_id, "market", position)
			if trade_home == null: return false
			trade_post = command["target"]
			trade_returning = false
			order = "trade"
			_reset_route()
		"relic":
			if kind != "monk" or carried_relic != null or not command["target"] is RtsRelic or not command["target"].available(): return false
			order = "relic"
			target = command["target"]
			_reset_route()
		"deposit_relic":
			if kind != "monk" or carried_relic == null or not command["target"] is RtsBuilding or command["target"].kind != "monastery" or command["target"].owner_id != owner_id: return false
			order = "deposit_relic"
			target = command["target"]
			_reset_route()
		"build":
			if kind != "villager" or not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion() or command["target"].is_complete(): return false
			order_build(command["target"])
		"garrison":
			if not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion() or not (RtsSiegeRules.can_garrison(stats, command["target"].kind) or command["target"].kind == "landmark" and command["target"].garrison_capacity() > 0 and not stats.get("tags", []).has("siege")): return false
			order = "garrison"
			target = command["target"]
			_reset_route()
		_: return false
	return true

func _advance_command() -> void:
	order = "idle"
	movement_group = null
	target = null
	resume_destination = Vector2.INF
	while not command_queue.is_empty():
		var command: Dictionary = command_queue.pop_front()
		if _start_command(command): break

func is_braced() -> bool:
	if kind == "longbow" and paling_timer > 0.0: return true
	if float(stats.get("brace_bonus", 0.0)) <= 0.0: return false
	if order == "idle": return true
	if order == "attack" and is_instance_valid(target):
		return position.distance_to(target.position) <= float(stats["range"]) + radius() + 8.0
	return false

func activate_ability(ability_id: String) -> bool:
	match ability_id:
		"palings":
			if kind != "longbow" or paling_cooldown > 0.0: return false
			paling_timer = 99999.0
			paling_cooldown = 30.0
			order_stop()
			return true
		"volley":
			if kind != "longbow" or volley_cooldown > 0.0: return false
			volley_timer = 5.0
			volley_cooldown = 45.0
			return true
		"pavise":
			if kind != "arbaletrier": return false
			shield_timer = 99999.0 if shield_timer <= 0.0 else 0.0
			refresh_stats()
			return true
		"helmsman":
			if kind != "warship" or helm_cooldown > 0.0: return false
			helm_timer = 10.0
			helm_cooldown = 30.0
			return true
		"convert":
			if kind != "monk" or carried_relic == null or conversion_cooldown > 0.0: return false
			order_stop()
			conversion_timer = 3.0
			conversion_cooldown = 120.0
			return true
		"camp":
			if game.civilizations[owner_id] != "English" or kind not in ["scout", "man_at_arms"]: return false
			var camp_count := 0
			for building in game.buildings:
				if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "scout_camp": camp_count += 1
			if camp_count >= 5 or not game.can_afford(owner_id, {"wood": 25}): return false
			for offset in [Vector2(46, 0), Vector2(-46, 0), Vector2(0, 46), Vector2(0, -46)]:
				var site: Vector2 = position + offset
				if not game.can_place("scout_camp", site): continue
				if not game.spend(owner_id, {"wood": 25}): return false
				game.spawn_building(owner_id, "scout_camp", site)
				game.fog.update_visibility()
				return true
			return false
	return false

func order_gather(resource: Node2D) -> void:
	if not ["villager", "fishing_boat"].has(kind): return
	order = "gather"
	target = resource
	resume_destination = Vector2.INF
	charging = false
	gather_kind = resource.kind if resource is RtsResource else ""
	gather_location = resource.position
	_reset_route()

func _continue_gather() -> void:
	var next_resource: RtsResource
	if gather_kind != "":
		next_resource = game.find_nearest_resource(gather_location, gather_kind, AUTO_GATHER_RADIUS, owner_id, kind == "fishing_boat")
	if next_resource != null:
		order_gather(next_resource)
	else:
		_advance_command()

func order_build(building: Node2D) -> void:
	if kind != "villager": return
	order = "build"
	target = building
	resume_destination = Vector2.INF
	charging = false
	_reset_route()

func _reset_route() -> void:
	route.clear()
	route_index = 0
	route_goal = Vector2.INF
	route_retry = 0.0

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over or garrisoned_in != null: return
	attack_timer = maxf(0.0, attack_timer - delta)
	work_timer = maxf(0.0, work_timer - delta)
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
	if conversion_timer > 0.0:
		conversion_timer = maxf(0.0, conversion_timer - delta)
		if conversion_timer <= 0.0: _finish_conversion()
		return
	if kind == "monk": _heal_ally(delta)
	if charging:
		charge_elapsed += delta
		if charge_elapsed >= 7.0: charging = false
	if stun_timer > 0.0: return
	if order == "idle":
		var enemy: Node2D = game.nearest_enemy(self, maxf(115.0, float(stats.get("range", 0.0)) + 45.0))
		if enemy != null and stats.get("tags", []).has("military"): order_attack(enemy)
		return
	if order == "attack_move":
		var nearby_enemy: Node2D = game.nearest_enemy(self, 155.0)
		if nearby_enemy != null:
			var resume_point := destination
			order_attack(nearby_enemy)
			resume_destination = resume_point
			return
		if movement_group != null: _move_with_group(delta)
		else: _move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: _advance_command()
		return
	if order == "move":
		if movement_group != null: _move_with_group(delta)
		else: _move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: _advance_command()
		return
	if order == "trade":
		if not is_instance_valid(trade_post) or not is_instance_valid(trade_home) or trade_home.is_queued_for_deletion():
			_advance_command()
			return
		var goal: Vector2 = trade_home.position if trade_returning else trade_post.position
		if _move_toward(goal, delta, 46.0):
			if trade_returning:
				var gold := maxi(12, roundi(trade_home.position.distance_to(trade_post.position) / 18.0))
				gold = roundi(gold * RtsLandmarkCatalog.trade_multiplier(game.civilizations[owner_id], game.players[owner_id].get("landmarks", [])))
				game.credit_resource(owner_id, "gold", gold)
			trade_returning = not trade_returning
			_reset_route()
		return
	if order == "relic":
		if not is_instance_valid(target) or not target is RtsRelic or not target.available():
			_advance_command()
			return
		if _move_toward(target.position, delta, 18.0):
			carried_relic = target
			carried_relic.carried_by = self
			var monastery: RtsBuilding = game.find_nearest_owned_building(owner_id, "monastery", position)
			if monastery != null: issue_command("deposit_relic", Vector2.INF, monastery)
			else: _advance_command()
		return
	if order == "deposit_relic":
		if carried_relic == null or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_complete():
			_advance_command()
			return
		if _move_toward(target.position, delta, target.size().x * 0.5 + radius() + 4.0):
			carried_relic.carried_by = null
			carried_relic.stored_in = target
			target.relics.append(carried_relic)
			carried_relic = null
			_advance_command()
		return
	if order == "gather":
		if not is_instance_valid(target):
			_continue_gather()
		elif target is RtsResource and (target.is_queued_for_deletion() or target.amount <= 0):
			_continue_gather()
		if order != "gather": return
	if not is_instance_valid(target):
		if resume_destination != Vector2.INF:
			var resume_point := resume_destination
			order_attack_move(resume_point)
			return
		_advance_command()
		return
	if order == "idle": return
	if order == "garrison":
		if not target is RtsBuilding or not target.is_complete():
			_advance_command()
			return
		if not _move_toward(target.position, delta, target.size().x * 0.5 + radius() + 5.0): return
		if not target.garrison_unit(self): _advance_command()
		return
	if order == "gather":
		var gathering_distance: float = target.radius + radius() + 2.0 if target is RtsResource else target.size().x * 0.5 + radius() + 2.0
		if not _move_toward(target.position, delta, gathering_distance): return
		if work_timer <= 0.0:
			var resource_kind: String = "food" if target is RtsBuilding else target.kind
			var amount := 12 if kind == "fishing_boat" else GameData.gathered_amount(game.civilizations[owner_id], resource_kind, target is RtsBuilding)
			amount = maxi(1, roundi(amount * RtsLandmarkCatalog.gather_multiplier(game.civilizations[owner_id], game.players[owner_id].get("landmarks", []), resource_kind, target is RtsBuilding)))
			if kind == "villager" and target is RtsResource and target.appearance == "deer":
				for building in game.buildings:
					if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "scout_camp" and building.position.distance_to(position) <= 180.0:
						amount = maxi(1, roundi(amount * 1.1))
						break
			if target is RtsResource: amount = target.harvest(amount)
			if amount > 0: game.credit_resource(owner_id, resource_kind, amount)
			work_timer = 1.1
			if target is RtsResource and target.amount <= 0: _continue_gather()
		return
	if order == "build":
		if not _move_toward(target.position, delta, target.size().x * 0.6 + radius()): return
		target.advance_construction(delta * GameData.construction_multiplier(game.civilizations[owner_id]))
		if target.is_complete(): _advance_command()
		return
	if order == "attack":
		var target_radius := 18.0
		if target is RtsUnit: target_radius = target.radius()
		if target is RtsBuilding: target_radius = maxf(target.size().x, target.size().y) * 0.5 + radius() + 3.0
		var defender_stats: Dictionary = target.stats if target is RtsUnit or target is RtsBuilding else {}
		var charged := charging and charge_distance >= 60.0
		var profile := RtsStatResolver.attack_profile(stats, defender_stats, charged)
		if profile.is_empty(): return
		var reach: float = float(profile.get("range", stats["range"])) + target_radius
		var min_reach: float = float(profile.get("min_range", stats.get("min_range", 0.0))) + target_radius
		if min_reach > 0.0 and position.distance_to(target.position) < min_reach:
			var away := (position - target.position).normalized()
			if away.is_zero_approx(): away = Vector2.RIGHT
			_move_toward(target.position + away * (min_reach + 10.0), delta, 6.0)
			return
		if not _move_toward(target.position, delta, reach): return
		if attack_timer > 0.0: return
		charged = charging and charge_distance >= 60.0
		profile = RtsStatResolver.attack_profile(stats, defender_stats, charged)
		if charged and target is RtsUnit and target.is_braced() and stats.get("tags", []).has("cavalry"):
			var brace_damage := 19.0 + 5.0 * maxi(0, int(target.stats.get("rank_age", 2)) - 2) if target.kind == "longbow" else RtsCombatRules.profile_damage(target.stats, stats, RtsStatResolver.attack_profile(target.stats, stats), {"brace_impact": true})
			take_damage(brace_damage)
			stun_timer = 2.5
			charging = false
			charge_cooldown = 10.0
			return
		var modifiers := {"extra_damage": 3.0 if kind == "royal_knight" and momentum_timer > 0.0 else 0.0}
		var damage: float = RtsCombatRules.volley_damage(stats, defender_stats, profile, modifiers)
		if charged:
			charge_cooldown = 10.0
			if kind == "royal_knight": momentum_timer = 3.0
		charging = false
		if profile.get("damage_kind") == "ranged" or stats.get("primary_profile") == "siege" and float(profile.get("range", 0.0)) > 70.0:
			var projectile := RtsProjectile.new()
			projectile.setup(game, owner_id, global_position, target, damage, float(stats.get("projectile_speed", 350.0)), float(profile.get("splash_radius", 0.0)), stats, profile)
			game.add_child(projectile)
		else:
			var impact_point: Vector2 = target.position
			target.take_damage(damage)
			if charged and float(profile.get("splash_radius", 0.0)) > 0.0:
				for other in game.units:
					if not is_instance_valid(other) or other == target or other.is_queued_for_deletion() or not game.is_enemy(owner_id, other.owner_id) or other.garrisoned_in != null: continue
					if other.position.distance_to(impact_point) <= float(profile["splash_radius"]): other.take_damage(RtsCombatRules.volley_damage(stats, other.stats, profile) * 0.5)
			game.show_hit(position, impact_point, owner_id)
		attack_timer = float(profile.get("cooldown", stats["cooldown"]))
		if volley_timer > 0.0: attack_timer /= 1.7

func _heal_ally(delta: float) -> void:
	heal_timer = maxf(0.0, heal_timer - delta)
	if heal_timer > 0.0: return
	heal_timer = 1.0
	var ally: RtsUnit
	var missing := 0.0
	for candidate in game.units:
		if not is_instance_valid(candidate) or candidate == self or candidate.owner_id != owner_id or candidate.garrisoned_in != null or candidate.position.distance_to(position) > 100.0: continue
		if candidate.max_hp - candidate.hp > missing:
			ally = candidate
			missing = candidate.max_hp - candidate.hp
	if ally != null:
		ally.hp = minf(ally.max_hp, ally.hp + 7.0)
		ally.queue_redraw()

func _finish_conversion() -> void:
	if carried_relic == null: return
	var converted := 0
	for candidate in game.units:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not game.is_enemy(owner_id, candidate.owner_id) or candidate.garrisoned_in != null: continue
		if candidate.position.distance_to(position) > 130.0 or candidate.stats.get("tags", []).has("siege"): continue
		candidate.owner_id = owner_id
		candidate.order_stop()
		candidate.refresh_stats()
		converted += 1
		if converted >= 5: break
	if converted > 0:
		game.navigation.invalidate_spatial_index()
		game.fog.update_visibility()

func _move_toward(point: Vector2, delta: float, stop_distance: float) -> bool:
	var distance := position.distance_to(point)
	if distance <= stop_distance + 0.5: return true
	if paling_timer > 0.0: paling_timer = 0.0
	if shield_timer > 0.0:
		shield_timer = 0.0
		refresh_stats()
	route_retry = maxf(0.0, route_retry - delta)
	if route_goal == Vector2.INF or route_goal.distance_to(point) > RtsWorldMap.CELL_SIZE * 0.5 or route_retry <= 0.0:
		if ["gather", "build", "attack", "garrison", "trade", "deposit_relic"].has(order):
			route = game.navigation.path_to_range(position, point, stop_distance, self)
		else:
			route = game.navigation.path_between(position, point, self)
		route_index = 1 if route.size() > 1 else route.size()
		route_goal = point
		route_retry = 0.7
	if route.is_empty(): return false
	while route_index < route.size() and position.distance_to(route[route_index]) < 8.0:
		route_index += 1
	var waypoint: Vector2 = route[route_index] if route_index < route.size() else point
	var speed: float = effective_speed()
	var step := speed * delta
	if route_index >= route.size(): step = minf(step, distance - stop_distance)
	var old_position := position
	position = game.navigation.move_step(self, position.move_toward(waypoint, step))
	game.navigation.unit_moved(self, old_position)
	if charging: charge_distance += old_position.distance_to(position)
	position = position.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24))
	queue_redraw()
	return position.distance_to(point) <= stop_distance + 0.5

func _move_with_group(delta: float) -> void:
	var point := movement_group.target_for(self)
	# Direct local steering shares the squad path. Only a genuinely stuck member
	# pays for its own A* route around a corner or a crowded gate.
	var old_position := position
	var step := effective_speed() * delta
	position = game.navigation.move_step(self, position.move_toward(point, step))
	game.navigation.unit_moved(self, old_position)
	position = position.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24))
	if position.distance_squared_to(group_last_position) < 9.0 and position.distance_to(point) > 18.0:
		group_stuck_time += delta
	else:
		group_stuck_time = 0.0
		group_last_position = position
	if group_stuck_time > 1.1:
		# A member that cannot follow the shared route computes its own escape
		# path to its assigned slot. It leaves the formation until the order ends.
		movement_group = null
		_reset_route()
		_move_toward(destination, delta, 8.0)
	queue_redraw()

func take_damage(damage: float) -> void:
	hp -= damage
	queue_redraw()
	if hp <= 0.0:
		if carried_relic != null:
			carried_relic.carried_by = null
			carried_relic.position = position
			carried_relic = null
		game.entity_destroyed(self)

func _draw() -> void:
	var color: Color = game.player_color(owner_id)
	draw_circle(Vector2(1, 3), radius() + 2, Color("20292a"))
	draw_circle(Vector2.ZERO, radius(), color)
	if kind == "villager":
		draw_circle(Vector2(0, -2), 4, Color("e8cfab"))
	elif kind == "fishing_boat" or kind == "warship":
		draw_colored_polygon(PackedVector2Array([Vector2(-radius(), -3), Vector2(radius(), -3), Vector2(radius() * 0.6, 8), Vector2(-radius() * 0.6, 8)]), Color("d5bc83"))
		draw_line(Vector2.ZERO, Vector2(0, -radius()), Color("eee4cb"), 2)
	elif kind == "monk":
		draw_line(Vector2(0, -8), Vector2(0, 8), Color("f4e5aa"), 3)
		draw_line(Vector2(-5, -2), Vector2(5, -2), Color("f4e5aa"), 3)
	elif kind == "trader":
		draw_rect(Rect2(-6, -4, 12, 8), Color("e7c97d"))
	elif stats.get("tags", []).has("cavalry"):
		draw_rect(Rect2(-5, -3, 10, 6), Color("f1e6c6"))
	elif kind == "archer" or kind == "longbow":
		draw_arc(Vector2(1, 0), 7, -PI * 0.6, PI * 0.6, 12, Color("eee6c9"), 2)
	elif kind == "crossbowman" or kind == "arbaletrier" or kind == "zhuge_nu":
		draw_line(Vector2(-7, -3), Vector2(7, -3), Color("eee6c9"), 2)
		draw_line(Vector2(0, -3), Vector2(0, 8), Color("eee6c9"), 2)
	elif kind == "man_at_arms" or kind == "palace_guard":
		draw_rect(Rect2(-5, -6, 10, 12), Color("eee6c9"), false, 2)
	else:
		draw_line(Vector2(0, -8), Vector2(0, 8), Color("eee6c9"), 2)
	draw_rect(Rect2(-radius(), -radius() - 7, radius() * 2, 3), Color("422f2d"))
	draw_rect(Rect2(-radius(), -radius() - 7, radius() * 2 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("82dd8b"))
