extends RefCounted

const UnitCombat = preload("res://scripts/entities/unit_combat.gd")

# Command admission and lifecycle live here. Admission resolves prerequisites
# without mutating the active order, queue, abilities, or navigation generation.
# Queued commands are validated again when they become active.
var order := "idle"
var target: Node2D
var resume_order := ""
var auto_engaged := false
var command_queue: Array[Dictionary] = []

func prepare(unit: RtsUnit, command: Dictionary) -> Dictionary:
	if unit.hp <= 0.0 or unit.is_queued_for_deletion() or unit.garrisoned_in != null: return {}
	var prepared := command.duplicate()
	var command_type: String = command.get("type", "")
	var candidate = command.get("target")
	var point: Vector2 = command.get("point", Vector2.INF)
	var live_target: bool = is_instance_valid(candidate) and candidate is Node2D and not candidate.is_queued_for_deletion()
	var military: bool = unit.stats.get("tags", []).has("military")
	match command_type:
		"move", "attack_move", "patrol", "attack_ground", "unload":
			if not point.is_finite(): return {}
			if command_type in ["attack_move", "patrol"] and not military: return {}
			if command_type == "attack_ground" and unit.kind not in ["mangonel", "nest_of_bees", "trebuchet", "bombard", "cannon"]: return {}
			if command_type == "unload":
				if unit.kind != "transport_ship" or unit.passengers.is_empty(): return {}
				var pair: Dictionary = unit.game.find_landing_pair(unit, point)
				if pair.is_empty(): return {}
				prepared["landing"] = pair
		"hold": pass
		"group_move", "group_attack_move":
			if command_type == "group_attack_move" and not military: return {}
			if not is_instance_valid(command.get("group")) or not command.get("group") is RtsMovementGroup: return {}
		"attack":
			if not UnitCombat.valid_attack_target(unit, candidate) or unit.attack_damage() <= 0.0: return {}
			if unit.kind == "battering_ram" and candidate is RtsUnit: return {}
		"gather":
			if unit.kind not in ["villager", "fishing_boat"] or not live_target: return {}
			if not candidate is RtsResource and not (candidate is RtsBuilding and candidate.kind == "farm" and candidate.owner_id == unit.owner_id): return {}
			if unit.kind == "fishing_boat" and (not candidate is RtsResource or candidate.appearance != "fish"): return {}
			if unit.kind == "villager" and candidate is RtsResource and candidate.appearance == "fish": return {}
			if candidate is RtsBuilding and unit.game.farm_worker(candidate, unit) != null:
				candidate = unit.game.find_nearest_free_farm(unit.owner_id, unit.position, 190.0, unit)
				if not is_instance_valid(candidate): return {}
			prepared["target"] = candidate
		"build":
			if unit.kind != "villager" or not live_target or not candidate is RtsBuilding or candidate.owner_id != unit.owner_id or candidate.is_complete(): return {}
		"repair":
			if unit.kind != "villager" or not live_target or not (candidate is RtsBuilding or candidate is RtsUnit and candidate.stats.get("tags", []).has("siege")): return {}
			if candidate.owner_id != unit.owner_id: return {}
			if candidate.hp >= candidate.max_hp: return {}
		"field_build":
			if not unit.stats.get("tags", []).has("infantry") or not live_target or not candidate is RtsUnit or candidate.field_build_remaining <= 0.0 or candidate.owner_id != unit.owner_id: return {}
		"trade":
			if unit.kind != "trader" or not live_target or not candidate is RtsTradePost: return {}
			var home := unit.trade_home
			if not is_instance_valid(home) or home.is_queued_for_deletion(): home = unit.game.find_nearest_owned_building(unit.owner_id, "market", unit.position)
			if not is_instance_valid(home): return {}
			prepared["trade_home"] = home
		"supervise", "collect_tax":
			if unit.kind != "imperial_official" or not live_target or not candidate is RtsBuilding or candidate.owner_id != unit.owner_id or not candidate.is_complete(): return {}
		"relic":
			if unit.kind != "monk" or unit.carried_relic != null or not live_target or not candidate is RtsRelic or not candidate.available(): return {}
		"deposit_relic":
			if unit.kind != "monk" or unit.carried_relic == null or not live_target or not candidate is RtsBuilding or candidate.kind != "monastery" or candidate.owner_id != unit.owner_id: return {}
		"garrison":
			if not live_target or not candidate is RtsBuilding or candidate.owner_id != unit.owner_id or not candidate.is_complete(): return {}
			if not (RtsSiegeRules.can_garrison(unit.stats, candidate.kind) or candidate.kind == "landmark" and candidate.garrison_capacity() > 0 and not unit.stats.get("tags", []).has("siege")): return {}
		"board_transport":
			if not live_target or not candidate is RtsUnit or candidate.kind not in ["transport_ship", "battering_ram", "siege_tower"] or candidate.owner_id != unit.owner_id or unit.stats.get("tags", []).has("naval") or unit.stats.get("tags", []).has("siege"): return {}
		"assault_wall":
			if unit.kind != "siege_tower" or not live_target or not candidate is RtsBuilding or candidate.kind != "stone_wall" or not unit.game.is_enemy(unit.owner_id, candidate.owner_id): return {}
		"board_wall":
			if not live_target or not candidate is RtsBuilding: return {}
			var entrance := RtsSiegeRules.wall_entry(unit.game, unit, candidate)
			if entrance == null: return {}
			prepared["entrance"] = entrance
		_: return {}
	return prepared

func issue(unit: RtsUnit, command: Dictionary, append: bool) -> bool:
	var prepared := prepare(unit, command)
	if prepared.is_empty(): return false
	if not append:
		command_queue.clear()
		enter(unit, prepared)
	elif order == "idle" and command_queue.is_empty():
		enter(unit, prepared)
	else:
		# Keep the caller's intent. Farm assignment, wall entrances, home markets,
		# and landing pairs may change before this command starts.
		command_queue.append(command.duplicate())
	unit.queue_redraw()
	return true

func start(unit: RtsUnit, command: Dictionary) -> bool:
	var prepared := prepare(unit, command)
	if prepared.is_empty(): return false
	enter(unit, prepared)
	return true

func exit(unit: RtsUnit) -> void:
	resume_order = ""
	auto_engaged = false
	unit.UnitWork.cancel_hunt(unit)
	unit.abilities.interrupt_command()
	unit.movement.begin_command()
	unit._reset_route()
	target = null

func enter(unit: RtsUnit, command: Dictionary) -> void:
	var command_type: String = command["type"]
	# The unit facade admits every public command here. These private entry
	# methods run only after prepare() succeeds and share the same exit policy.
	match command_type:
		"move": unit._order_move_to(command["point"], "move"); return
		"attack_move": unit._order_move_to(command["point"], "attack_move"); return
		"attack": unit._enter_attack(command["target"], false); return
		"patrol": unit._enter_patrol(command["point"]); return
		"hold": unit._enter_hold(); return
	if command_type == "garrison": unit.remember_work()
	if command_type in ["group_move", "group_attack_move"] and is_instance_valid(unit.wall_host): unit.leave_wall()
	exit(unit)
	order = command_type
	target = command.get("target")
	match command_type:
		"group_move", "group_attack_move":
			unit.movement_group = command["group"]
			unit.movement_group.activate()
			order = "attack_move" if command_type == "group_attack_move" else "move"
			unit.destination = unit.movement_group.destination_for(unit)
			unit.group_stuck_time = 0.0
			unit.group_progress_target = Vector2.INF
			unit.group_best_distance = INF
		"attack_ground": unit.destination = command["point"]
		"board_wall": unit.wall_entry_point = command["entrance"]
		"gather":
			unit.farm_gain_display_amount = 0
			unit.gather_kind = target.kind if target is RtsResource else ""
			unit.gather_location = target.position
		"trade":
			unit.trade_home = command["trade_home"]
			unit.trade_post = target
			# A new command must not claim the same endpoint's income again.
			# Only reaching the opposite endpoint advances the trade leg.
			target = null
		"unload":
			unit.destination = command["landing"]["water"]
			unit.landing_position = command["landing"]["land"]

func stop(unit: RtsUnit, clear_queue := true) -> void:
	exit(unit)
	if clear_queue: command_queue.clear()
	order = "wall" if is_instance_valid(unit.wall_host) else "idle"

func finish(unit: RtsUnit, resume_interrupted := false) -> void:
	if resume_interrupted and resume(unit): return
	stop(unit, false)
	while not command_queue.is_empty():
		var command: Dictionary = command_queue.pop_front()
		if start(unit, command): break

func engage(unit: RtsUnit, enemy: Node2D) -> void:
	if prepare(unit, {"type": "attack", "target": enemy}).is_empty(): return
	var interrupted_order := order
	var interrupted_destination := unit.destination
	unit._enter_attack(enemy, true)
	if interrupted_order in ["attack_move", "patrol"]:
		resume_order = interrupted_order
		unit.resume_destination = interrupted_destination
	elif interrupted_order == "hold": resume_order = "hold"

func resume(unit: RtsUnit) -> bool:
	var previous_order := resume_order
	var previous_destination := unit.resume_destination
	if previous_order not in ["attack_move", "patrol", "hold"]: return false
	if previous_order in ["attack_move", "patrol"] and not previous_destination.is_finite(): return false
	exit(unit)
	order = previous_order
	if previous_order != "hold": unit.destination = previous_destination
	return true

func enter_garrison(unit: RtsUnit, host: Node2D) -> void:
	stop(unit)
	order = "idle"
	unit.garrisoned_in = host
	unit.position = host.position
	unit.hide()

func tick(unit: RtsUnit, delta: float) -> void:
	# Orders without a shared live target perform their own completion checks.
	match order:
		"hold": _tick_hold(unit, delta); return
		"wall": _tick_wall(unit, delta); return
		"board_wall": _tick_board_wall(unit, delta); return
		"assault_wall": _tick_assault_wall(unit, delta); return
		"siege_tower_docked": return
		"idle": unit._process_idle_order(); return
		"attack_move": _tick_attack_move(unit, delta); return
		"patrol": _tick_patrol(unit, delta); return
		"move": _tick_move(unit, delta); return
		"unload": _tick_unload(unit, delta); return
		"trade": unit._process_trade_order(delta); return
		"attack_ground": unit._process_attack_ground(delta); return
		"supervise", "collect_tax": _tick_official(unit, delta); return
		"relic": _tick_relic(unit, delta); return
		"deposit_relic": _tick_deposit_relic(unit, delta); return
	if order == "gather":
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target is RtsResource and target.amount <= 0:
			unit._continue_gather()
		if order != "gather": return
	if order == "attack" and not UnitCombat.valid_attack_target(unit, target): target = null
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		finish(unit, true)
		return
	match order:
		"garrison": _tick_garrison(unit, delta)
		"board_transport": _tick_board_transport(unit, delta)
		"gather": unit._process_gather_order(delta)
		"build": _tick_build(unit, delta)
		"field_build": _tick_field_build(unit, delta)
		"repair": unit._process_repair_order(delta)
		"attack": unit._process_attack_order(delta)

func _tick_hold(unit: RtsUnit, delta: float) -> void:
	if unit.position.distance_to(unit.hold_position) > 6.0:
		unit._move_toward(unit.hold_position, delta, 4.0)
		return
	var held_enemy: Node2D = unit.game.nearest_enemy(unit, unit.attack_range() + 22.0) if unit.engagement != "passive" else null
	if held_enemy != null and unit.attack_damage() > 0.0:
		engage(unit, held_enemy)
	return

func _tick_wall(unit: RtsUnit, delta: float) -> void:
	if not is_instance_valid(unit.wall_host):
		finish(unit)
		return
	var wall_enemy: Node2D = unit.game.nearest_enemy(unit, unit.attack_range() + 20.0) if unit.engagement != "passive" else null
	if wall_enemy != null and unit.attack_damage() > 0.0: engage(unit, wall_enemy)
	return

func _tick_board_wall(unit: RtsUnit, delta: float) -> void:
	if not is_instance_valid(unit.target) or not unit.target is RtsBuilding or not unit.target.is_complete() or not is_instance_valid(unit.wall_entry_point):
		unit._advance_command()
		return
	if not is_instance_valid(unit.wall_host) and not unit._move_toward(unit.wall_entry_point.position, delta, 35.0): return
	unit.wall_host = unit.target
	unit.position = unit.target.position + Vector2(float(unit.get_instance_id() % 3 - 1) * 17.0, -9.0)
	unit.z_index = 3
	unit.refresh_stats()
	unit.game.navigation.invalidate_spatial_index()
	unit._advance_command()
	return

func _tick_assault_wall(unit: RtsUnit, delta: float) -> void:
	if not is_instance_valid(unit.target) or unit.target.is_queued_for_deletion():
		unit._advance_command()
		return
	var docking_distance: float = maxf(unit.target.size().x, unit.target.size().y) * 0.5 + unit.radius() + 4.0
	if unit._move_toward(unit.target.position, delta, docking_distance):
		var dock_target := target
		exit(unit)
		order = "siege_tower_docked"
		target = dock_target
		unit._face_direction(target.position - unit.position)
		unit.queue_redraw()
		for passenger in unit.passengers.duplicate():
			if not is_instance_valid(passenger): continue
			passenger.garrisoned_in = null
			passenger.wall_host = unit.target
			passenger.wall_entry_point = unit
			passenger.position = unit.target.position + Vector2(float(passenger.get_instance_id() % 3 - 1) * 17.0, -9.0)
			unit.game.fog.update_unit_display(passenger)
			passenger.order_stop()
			passenger.refresh_stats()
		unit.passengers.clear()
		unit.game.navigation.invalidate_spatial_index()
	return

func _tick_attack_move(unit: RtsUnit, delta: float) -> void:
	var nearby_enemy: Node2D
	if unit.awareness_timer <= 0.0 and unit.engagement != "passive":
		nearby_enemy = unit.game.nearest_enemy(unit, 110.0 if unit.engagement == "defensive" else 155.0)
		unit.awareness_timer = 0.24
	if nearby_enemy != null:
		engage(unit, nearby_enemy)
		return
	if unit.movement_group != null: unit._move_with_group(delta)
	else: unit._move_toward(unit.destination, delta, 6.0)
	if unit.position.distance_to(unit.destination) < 7.0: unit._advance_command()
	return

func _tick_patrol(unit: RtsUnit, delta: float) -> void:
	var patrol_enemy: Node2D
	if unit.awareness_timer <= 0.0 and unit.engagement != "passive":
		patrol_enemy = unit.game.nearest_enemy(unit, 110.0 if unit.engagement == "defensive" else 155.0)
		unit.awareness_timer = 0.24
	if patrol_enemy != null:
		engage(unit, patrol_enemy)
		return
	unit._move_toward(unit.destination, delta, 6.0)
	if unit.position.distance_to(unit.destination) < 8.0:
		unit.destination = unit.patrol_origin if unit.destination == unit.patrol_destination else unit.patrol_destination
		unit._reset_route()
	return

func _tick_move(unit: RtsUnit, delta: float) -> void:
	if unit.movement_group != null: unit._move_with_group(delta)
	else: unit._move_toward(unit.destination, delta, 6.0)
	if unit.position.distance_to(unit.destination) < 7.0: unit._advance_command()
	return

func _tick_unload(unit: RtsUnit, delta: float) -> void:
	if unit._move_toward(unit.destination, delta, 16.0):
		unit.ungarrison_all()
		unit._advance_command()
	return

func _tick_relic(unit: RtsUnit, delta: float) -> void:
	if not is_instance_valid(unit.target) or not unit.target is RtsRelic or not unit.target.available():
		unit._advance_command()
		return
	if unit._move_toward(unit.target.position, delta, 18.0):
		unit.carried_relic = unit.target
		unit.carried_relic.carried_by = unit
		var monastery: RtsBuilding = unit.game.find_nearest_owned_building(unit.owner_id, "monastery", unit.position)
		if monastery != null: unit.issue_command("deposit_relic", Vector2.INF, monastery)
		else: unit._advance_command()
	return

func _tick_deposit_relic(unit: RtsUnit, delta: float) -> void:
	if unit.carried_relic == null or not is_instance_valid(unit.target) or unit.target.is_queued_for_deletion() or not unit.target.is_complete():
		unit._advance_command()
		return
	if unit._move_toward(unit.target.position, delta, unit.target.size().x * 0.5 + unit.radius() + 4.0):
		unit.carried_relic.carried_by = null
		unit.carried_relic.stored_in = unit.target
		unit.target.relics.append(unit.carried_relic)
		unit.carried_relic = null
		unit._advance_command()
	return

func _tick_garrison(unit: RtsUnit, delta: float) -> void:
	if not unit.target is RtsBuilding or not unit.target.is_complete():
		unit._advance_command()
		return
	if not unit._move_toward(unit.target.position, delta, unit.target.size().x * 0.5 + unit.radius() + 5.0): return
	if not unit.target.garrison_unit(unit): unit._advance_command()
	return

func _tick_board_transport(unit: RtsUnit, delta: float) -> void:
	if not unit.target is RtsUnit or not is_instance_valid(unit.target):
		unit._advance_command()
		return
	if unit._move_toward(unit.target.position, delta, 78.0) and not unit.target.garrison_unit(unit): unit._advance_command()
	return

func _tick_build(unit: RtsUnit, delta: float) -> void:
	if unit.target.is_queued_for_deletion():
		unit._advance_command()
		return
	if unit.target.is_complete():
		unit.UnitWork.finish_construction(unit, unit.target)
		return
	if not unit._move_toward(unit.target.position, delta, unit.target.size().x * 0.6 + unit.radius()): return
	if unit.visual_action_timer <= 0.0: unit._start_visual_action("build", 0.45)
	unit.target.advance_construction(delta * GameData.construction_multiplier(unit.game.civilizations[unit.owner_id]))
	if unit.target.is_complete(): unit.UnitWork.finish_construction(unit, unit.target)
	return

func _tick_field_build(unit: RtsUnit, delta: float) -> void:
	if not unit.target is RtsUnit or unit.target.field_build_remaining <= 0.0:
		unit._advance_command()
		return
	if unit._move_toward(unit.target.position, delta, unit.target.radius() + unit.radius() + 7.0):
		unit.target.field_build_remaining = maxf(0.0, unit.target.field_build_remaining - delta)
		unit.target.queue_redraw()
		if unit.target.field_build_remaining <= 0.0:
			unit.target.hp = minf(unit.target.max_hp, unit.target.hp + unit.target.max_hp * 0.7)
			unit._advance_command()
	return

func _tick_official(unit: RtsUnit, delta: float) -> void:
	if not is_instance_valid(unit.target) or unit.target.is_queued_for_deletion() or not unit.target is RtsBuilding or not unit.target.is_complete():
		unit._advance_command()
		return
	if not unit._move_toward(unit.target.position, delta, unit.target.supervise_distance(unit)): return
	if unit.order == "collect_tax":
		if unit.target.tax_stockpile > 0:
			unit.game.credit_resource(unit.owner_id, "gold", unit.target.tax_stockpile)
			unit.target.tax_stockpile = 0
			unit._start_visual_action("tax", 0.55)
		unit._advance_command()
	return
