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
var enclosure_timer := 5.0
var charging := false
var charge_distance := 0.0
var charge_cooldown := 0.0
var charge_elapsed := 0.0
var stun_timer := 0.0
var momentum_timer := 0.0
var resume_destination := Vector2.INF
var resume_order := ""
var patrol_origin := Vector2.ZERO
var patrol_destination := Vector2.ZERO
var hold_position := Vector2.ZERO
var stance := "aggressive"
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
var garrisoned_in: Node2D
var wall_host: RtsBuilding
var wall_entry_point: Node2D
var passengers: Array[RtsUnit] = []
var landing_position := Vector2.INF
var trade_post: RtsTradePost
var trade_home: RtsBuilding
var trade_returning := false
var trade_resource_kind := "gold"
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
var spirit_buff_timer := 0.0
var revealed_timer := 0.0
var artillery_shot_ready := false
var artillery_shot_cooldown := 0.0

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
	if is_instance_valid(wall_host): stats["armor"]["ranged"] = float(stats["armor"].get("ranged", 0.0)) + 2.0
	max_hp = float(stats["hp"])
	hp = maxf(1.0, max_hp - missing_hp)
	queue_redraw()

func radius() -> float:
	return float(stats["radius"])

func effective_speed() -> float:
	return float(stats["speed"]) * (1.4 if helm_timer > 0.0 else 1.0)

func gathering_amount() -> int:
	if order != "gather" or not is_instance_valid(target): return 0
	var resource_kind: String = "food" if target is RtsBuilding else target.kind
	var amount := 12 if kind == "fishing_boat" else GameData.gathered_amount(game.civilizations[owner_id], resource_kind, target is RtsBuilding)
	amount = maxi(1, roundi(amount * RtsLandmarkCatalog.gather_multiplier(game.civilizations[owner_id], game.players[owner_id].get("landmarks", []), resource_kind, target is RtsBuilding) * RtsCivilizationRules.economic_gather_multiplier(game, owner_id, resource_kind)))
	if kind == "villager" and target is RtsResource and target.appearance == "deer":
		for building in game.buildings:
			if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "scout_camp" and building.position.distance_to(position) <= 180.0:
				amount = maxi(1, roundi(amount * 1.1))
				break
	return amount

func gathering_per_second() -> float:
	return float(gathering_amount()) / 1.1

func order_move(world_point: Vector2) -> void:
	if is_instance_valid(wall_host): leave_wall()
	stance = "aggressive"
	resume_order = ""
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
	if is_instance_valid(wall_host) and position.distance_to(enemy.position) > float(stats.get("range", 0.0)) + 35.0: leave_wall()
	resume_order = ""
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
	if is_instance_valid(wall_host): leave_wall()
	stance = "aggressive"
	resume_order = ""
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
	stance = "aggressive"
	resume_order = ""
	conversion_timer = 0.0
	command_queue.clear()
	movement_group = null
	order = "wall" if is_instance_valid(wall_host) else "idle"
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_hold() -> void:
	order_stop()
	stance = "hold"
	hold_position = position
	order = "hold"

func order_patrol(world_point: Vector2) -> void:
	order_stop()
	stance = "aggressive"
	patrol_origin = position
	patrol_destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	destination = patrol_destination
	order = "patrol"

func garrison_unit(unit: RtsUnit) -> bool:
	if kind != "transport_ship" or not is_instance_valid(unit) or unit.owner_id != owner_id or passengers.size() >= 8 or unit.stats.get("tags", []).has("naval") or unit.garrisoned_in != null: return false
	if unit.position.distance_to(position) > 100.0: return false
	passengers.append(unit)
	unit.garrisoned_in = self
	unit.order = "idle"
	unit.command_queue.clear()
	unit.position = position
	unit.hide()
	game.navigation.invalidate_spatial_index()
	queue_redraw()
	return true

func ungarrison_all() -> void:
	if kind != "transport_ship" or passengers.is_empty(): return
	var shore := landing_position
	if shore == Vector2.INF:
		var pair: Dictionary = game.find_landing_pair(self, position)
		if pair.is_empty() or position.distance_to(pair["water"]) > 80.0: return
		shore = pair["land"]
	for index in passengers.size():
		var passenger: RtsUnit = passengers[index]
		if not is_instance_valid(passenger): continue
		passenger.garrisoned_in = null
		passenger.position = game.navigation.nearest_walkable_point(shore + Vector2((index % 3 - 1) * 23, (index / 3) * 23), passenger.radius(), passenger)
		passenger.show()
		passenger.order_stop()
	passengers.clear()
	landing_position = Vector2.INF
	game.navigation.invalidate_spatial_index()
	queue_redraw()

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
		"assault_wall":
			if kind != "siege_tower" or not command["target"] is RtsBuilding or command["target"].kind != "stone_wall" or not game.is_enemy(owner_id, command["target"].owner_id): return false
			target = command["target"]
			order = "assault_wall"
			_reset_route()
		"board_wall":
			if not command["target"] is RtsBuilding: return false
			var entrance := RtsSiegeRules.wall_entry(game, self, command["target"])
			if entrance == null: return false
			wall_entry_point = entrance
			target = command["target"]
			order = "board_wall"
			_reset_route()
		"group_move", "group_attack_move":
			if command["type"] == "group_attack_move" and not stats.get("tags", []).has("military"): return false
			if is_instance_valid(wall_host): leave_wall()
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
		"patrol":
			if not stats.get("tags", []).has("military"): return false
			order_patrol(command["point"])
		"hold": order_hold()
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
			if command["target"] is RtsResource and command["target"].appearance == "sheep" and command["target"].claimed_by != owner_id: return false
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
		"supervise", "collect_tax":
			if kind != "imperial_official" or not command["target"] is RtsBuilding or command["target"].owner_id != owner_id or not command["target"].is_complete(): return false
			order = command["type"]
			target = command["target"]
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
		"board_transport":
			if not command["target"] is RtsUnit or command["target"].kind != "transport_ship" or command["target"].owner_id != owner_id or stats.get("tags", []).has("naval"): return false
			order = "board_transport"
			target = command["target"]
			_reset_route()
		"unload":
			if kind != "transport_ship" or passengers.is_empty(): return false
			var pair: Dictionary = game.find_landing_pair(self, command["point"])
			if pair.is_empty(): return false
			order = "unload"
			destination = pair["water"]
			landing_position = pair["land"]
			target = null
			_reset_route()
		_: return false
	return true

func _advance_command() -> void:
	order = "wall" if is_instance_valid(wall_host) else "idle"
	movement_group = null
	target = null
	resume_destination = Vector2.INF
	while not command_queue.is_empty():
		var command: Dictionary = command_queue.pop_front()
		if _start_command(command): break

func leave_wall() -> void:
	if not is_instance_valid(wall_host): return
	var exit_point := wall_host.position + Vector2(0, 55)
	if is_instance_valid(wall_entry_point): exit_point = wall_entry_point.position + Vector2(0, 55)
	wall_host = null
	wall_entry_point = null
	z_index = 0
	position = game.navigation.nearest_walkable_point(exit_point, radius(), self)
	refresh_stats()
	game.navigation.invalidate_spatial_index()

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
		"artillery_shot":
			if kind != "cannon" or producer_landmark_id != "fr_college_of_artillery" or artillery_shot_cooldown > 0.0: return false
			artillery_shot_ready = true
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
	if resource is RtsResource and resource.appearance == "sheep" and resource.claimed_by != owner_id: return
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
	if _tick_status(delta): return
	if order == "hold":
		if position.distance_to(hold_position) > 6.0:
			_move_toward(hold_position, delta, 4.0)
			return
		var held_enemy: Node2D = game.nearest_enemy(self, float(stats.get("range", 0.0)) + 22.0)
		if held_enemy != null and float(stats.get("damage", 0.0)) > 0.0:
			order_attack(held_enemy)
			resume_order = "hold"
		return
	if order == "wall":
		if not is_instance_valid(wall_host):
			order = "idle"
			return
		var wall_enemy: Node2D = game.nearest_enemy(self, float(stats.get("range", 0.0)) + 20.0)
		if wall_enemy != null and float(stats.get("damage", 0.0)) > 0.0: order_attack(wall_enemy)
		return
	if order == "board_wall":
		if not is_instance_valid(target) or not target is RtsBuilding or not target.is_complete() or not is_instance_valid(wall_entry_point):
			_advance_command()
			return
		if not is_instance_valid(wall_host) and not _move_toward(wall_entry_point.position, delta, 35.0): return
		wall_host = target
		position = target.position + Vector2(float(get_instance_id() % 3 - 1) * 17.0, -9.0)
		z_index = 3
		refresh_stats()
		game.navigation.invalidate_spatial_index()
		_advance_command()
		return
	if order == "assault_wall":
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			_advance_command()
			return
		if _move_toward(target.position, delta, 65.0): order = "siege_tower_docked"
		return
	if order == "siege_tower_docked": return
	if order == "idle":
		_process_idle_order()
		return
	if order == "attack_move":
		var nearby_enemy: Node2D = game.nearest_enemy(self, 155.0)
		if nearby_enemy != null:
			var resume_point := destination
			order_attack(nearby_enemy)
			resume_destination = resume_point
			resume_order = "attack_move"
			return
		if movement_group != null: _move_with_group(delta)
		else: _move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: _advance_command()
		return
	if order == "patrol":
		var patrol_enemy: Node2D = game.nearest_enemy(self, 155.0)
		if patrol_enemy != null:
			var resume_point := destination
			order_attack(patrol_enemy)
			resume_destination = resume_point
			resume_order = "patrol"
			return
		_move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 8.0:
			destination = patrol_origin if destination == patrol_destination else patrol_destination
			_reset_route()
		return
	if order == "move":
		if movement_group != null: _move_with_group(delta)
		else: _move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: _advance_command()
		return
	if order == "unload":
		if _move_toward(destination, delta, 16.0):
			ungarrison_all()
			_advance_command()
		return
	if order == "trade":
		_process_trade_order(delta)
		return
	if order in ["supervise", "collect_tax"]:
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target is RtsBuilding or not target.is_complete():
			_advance_command()
			return
		if not _move_toward(target.position, delta, target.size().x * 0.5 + radius() + 4.0): return
		if order == "collect_tax":
			if target.tax_stockpile > 0:
				game.credit_resource(owner_id, "gold", target.tax_stockpile)
				target.tax_stockpile = 0
			_advance_command()
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
			var next_order := resume_order
			resume_destination = Vector2.INF
			resume_order = ""
			if next_order == "patrol":
				order = "patrol"
				destination = resume_point
				_reset_route()
			else: order_attack_move(resume_point)
			return
		if resume_order == "hold":
			resume_order = ""
			order = "hold"
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
	if order == "board_transport":
		if not target is RtsUnit or not is_instance_valid(target):
			_advance_command()
			return
		if _move_toward(target.position, delta, 78.0) and not target.garrison_unit(self): _advance_command()
		return
	if order == "gather":
		_process_gather_order(delta)
		return
	if order == "build":
		if not _move_toward(target.position, delta, target.size().x * 0.6 + radius()): return
		target.advance_construction(delta * GameData.construction_multiplier(game.civilizations[owner_id]))
		if target.is_complete(): _advance_command()
		return
	if order == "attack": _process_attack_order(delta)

func _tick_status(delta: float) -> bool:
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
	artillery_shot_cooldown = maxf(0.0, artillery_shot_cooldown - delta)
	revealed_timer = maxf(0.0, revealed_timer - delta)
	if spirit_buff_timer > 0.0:
		spirit_buff_timer = maxf(0.0, spirit_buff_timer - delta)
		hp = minf(max_hp, hp + 2.0 * delta)
	if conversion_timer > 0.0:
		conversion_timer = maxf(0.0, conversion_timer - delta)
		if conversion_timer <= 0.0: _finish_conversion()
		return true
	if kind == "monk": _heal_ally(delta)
	if charging:
		charge_elapsed += delta
		if charge_elapsed >= 7.0: charging = false
	return stun_timer > 0.0

func _process_idle_order() -> void:
	if kind == "imperial_official":
		var taxable: RtsBuilding
		var nearest := INF
		for building in game.buildings:
			if not is_instance_valid(building) or building.owner_id != owner_id or building.tax_stockpile < 4: continue
			var distance := position.distance_squared_to(building.position)
			if distance < nearest:
				nearest = distance
				taxable = building
		if taxable != null: issue_command("collect_tax", Vector2.INF, taxable)
		return
	var enemy: Node2D = game.nearest_enemy(self, maxf(115.0, float(stats.get("range", 0.0)) + 45.0))
	if enemy != null and stats.get("tags", []).has("military"): order_attack(enemy)

func _process_trade_order(delta: float) -> void:
	if not is_instance_valid(trade_post) or not is_instance_valid(trade_home) or trade_home.is_queued_for_deletion():
		_advance_command()
		return
	var goal: Vector2 = trade_home.position if trade_returning else trade_post.position
	if _move_toward(goal, delta, 46.0):
		if trade_returning:
			var gold := maxi(12, roundi(trade_home.position.distance_to(trade_post.position) / 18.0))
			gold = roundi(gold * RtsLandmarkCatalog.trade_multiplier(game.civilizations[owner_id], game.players[owner_id].get("landmarks", [])))
			if game.civilizations[owner_id] == "French": gold = roundi(gold * 1.15)
			game.credit_resource(owner_id, trade_resource_kind if game.civilizations[owner_id] == "French" else "gold", gold)
		trade_returning = not trade_returning
		_reset_route()

func _process_gather_order(delta: float) -> void:
	var gathering_distance: float = target.radius + radius() + 2.0 if target is RtsResource else target.size().x * 0.5 + radius() + 2.0
	if not _move_toward(target.position, delta, gathering_distance): return
	if kind == "villager" and target is RtsBuilding and target.kind == "farm" and game.civilizations[owner_id] == "English" and game.players[owner_id]["researched"].has("enclosures"):
		enclosure_timer -= delta
		if enclosure_timer <= 0.0:
			game.credit_resource(owner_id, "gold", 2)
			enclosure_timer += 5.0
	else:
		enclosure_timer = 5.0
	if work_timer <= 0.0:
		var resource_kind: String = "food" if target is RtsBuilding else target.kind
		var amount := gathering_amount()
		if target is RtsResource: amount = target.harvest(amount)
		if amount > 0: game.credit_resource(owner_id, resource_kind, amount)
		work_timer = 1.1
		if target is RtsResource and target.amount <= 0: _continue_gather()

func _process_attack_order(delta: float) -> void:
	if resume_order == "patrol" and position.distance_to(Geometry2D.get_closest_point_to_segment(position, patrol_origin, patrol_destination)) > 240.0:
		order = "patrol"
		destination = resume_destination
		resume_destination = Vector2.INF
		resume_order = ""
		target = null
		_reset_route()
		return
	if resume_order == "hold" and position.distance_to(hold_position) > 6.0:
		order = "hold"
		resume_order = ""
		target = null
		return
	var target_radius := 18.0
	if target is RtsUnit: target_radius = target.radius()
	if target is RtsBuilding: target_radius = maxf(target.size().x, target.size().y) * 0.5 + radius() + 3.0
	var defender_stats: Dictionary = target.stats if target is RtsUnit or target is RtsBuilding else {}
	var charged := charging and charge_distance >= 60.0
	var profile := RtsStatResolver.attack_profile(stats, defender_stats, charged)
	if profile.is_empty(): return
	if target is RtsUnit and is_instance_valid(target.wall_host) and target.wall_host != wall_host and profile.get("damage_kind", "melee") == "melee":
		_advance_command()
		return
	var reach: float = float(profile.get("range", stats["range"])) + target_radius
	var min_reach: float = float(profile.get("min_range", stats.get("min_range", 0.0))) + target_radius
	if min_reach > 0.0 and position.distance_to(target.position) < min_reach:
		if is_instance_valid(wall_host):
			_advance_command()
			return
		var away := (position - target.position).normalized()
		if away.is_zero_approx(): away = Vector2.RIGHT
		_move_toward(target.position + away * (min_reach + 10.0), delta, 6.0)
		return
	if is_instance_valid(wall_host):
		if position.distance_to(target.position) > reach:
			_advance_command()
			return
	elif not _move_toward(target.position, delta, reach): return
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
	if artillery_shot_ready:
		profile = profile.duplicate(true)
		profile["bonuses"] = []
		profile["splash_radius"] = maxf(65.0, float(profile.get("splash_radius", 0.0)))
		artillery_shot_ready = false
		artillery_shot_cooldown = 35.0
	var modifiers := {"extra_damage": 3.0 if kind == "royal_knight" and momentum_timer > 0.0 else 0.0, "multiplier": RtsCivilizationRules.wall_ranged_multiplier(game, self) if profile.get("damage_kind", "") == "ranged" else 1.0}
	var damage: float = RtsCombatRules.volley_damage(stats, defender_stats, profile, modifiers)
	if charged:
		charge_cooldown = 10.0
		if kind == "royal_knight": momentum_timer = 3.0
	charging = false
	revealed_timer = 2.0
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
	attack_timer = float(profile.get("cooldown", stats["cooldown"])) / (RtsCivilizationRules.english_network_rate(game, self) * (1.2 if spirit_buff_timer > 0.0 else 1.0))
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
		if ["gather", "build", "attack", "garrison", "board_transport", "trade", "deposit_relic"].has(order):
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
		if RtsCivilizationRules.is_dynasty_unit(kind) and RtsCivilizationRules.spirit_way_active(game, owner_id):
			for ally in game.units:
				if is_instance_valid(ally) and ally != self and ally.owner_id == owner_id and ally.position.distance_to(position) <= 150.0:
					ally.spirit_buff_timer = maxf(ally.spirit_buff_timer, 10.0)
		for passenger in passengers.duplicate():
			if is_instance_valid(passenger): game.entity_destroyed(passenger)
		passengers.clear()
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
	elif stats.get("tags", []).has("naval"):
		draw_colored_polygon(PackedVector2Array([Vector2(-radius(), -3), Vector2(radius(), -3), Vector2(radius() * 0.6, 8), Vector2(-radius() * 0.6, 8)]), Color("d5bc83"))
		draw_line(Vector2.ZERO, Vector2(0, -radius()), Color("eee4cb"), 2)
		if kind == "transport_ship": draw_string(ThemeDB.fallback_font, Vector2(-9, 4), str(passengers.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
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
