extends RefCounted
const ContextOrder = preload("res://scripts/player/context_order.gd")

# Player command priority and group formation, using match state owned by the game.

static func issue_order(game: Node2D, point: Vector2, append_order := false) -> void:
	var context := ContextOrder.targets(game, point)
	var entity: Node2D = context["entity"]
	var resource: RtsResource = context["resource"]
	var post: RtsTradePost = context["post"]
	var relic: RtsRelic = context["relic"]
	var ground_point: Vector2 = context["ground_point"]
	if not Rect2(Vector2.ZERO, game.world_size).has_point(ground_point):
		game._show_order_feedback(point, "invalid")
		game.notify_player("地图边界之外，无法下令")
		return
	var has_selected_unit := false
	for subject in game.selected:
		if is_instance_valid(subject) and subject is RtsUnit and subject.owner_id == 0:
			has_selected_unit = true
			break
	if not has_selected_unit:
		var assigned := false
		for subject in game.selected:
			if not is_instance_valid(subject) or not subject is RtsBuilding: continue
			if not subject.can_set_rally(0): continue
			var rally_target: Node2D = resource if resource != null else post if post != null else entity if entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "farm" else null
			var rally_point: Vector2 = rally_target.position if rally_target != null else ground_point
			subject.set_rally(rally_point.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24)), rally_target)
			assigned = true
		if assigned:
			game.notify_player("资源集结点已设置；新村民自动采集" if resource != null or entity is RtsBuilding and entity.kind == "farm" else "集结点已设置")
			game._show_order_feedback(point, "move", append_order)
			game.queue_redraw()
		return
	var movers: Array[RtsUnit] = []
	for subject in game.selected:
		if not is_instance_valid(subject) or not subject is RtsUnit or subject.owner_id != 0: continue
		var command := ContextOrder.for_unit(game, subject, context)
		if command["type"] == "move":
			movers.append(subject)
		else:
			subject.issue_command(command["type"], command["point"], command["target"], append_order)
			if command.get("hunt", false): subject.issue_command("gather", Vector2.INF, command["target"], true)
	game.issue_group_order(movers, ground_point, false, append_order)
	if not movers.is_empty() or entity != null or resource != null or post != null or relic != null:
		var kind := "attack" if entity != null and game.is_enemy(0, entity.owner_id) else "gather" if resource != null or post != null or relic != null else "build" if entity is RtsBuilding and not entity.is_complete() else "move"
		game._show_order_feedback(point, kind, append_order)
	elif has_selected_unit:
		game._show_order_feedback(point, "invalid")

static func issue_mode_order(game: Node2D, point: Vector2, append_order := false) -> void:
	var mode: String = game.order_mode
	if not append_order: game.order_mode = ""
	if mode == "attack_move":
		game._issue_attack_move(point, append_order)
	elif mode == "patrol":
		var patrol_issued := false
		for subject in game.selected:
			if is_instance_valid(subject) and subject is RtsUnit and subject.stats.get("tags", []).has("military"):
				subject.issue_command("patrol", point, null, append_order)
				patrol_issued = true
		if patrol_issued: game._show_order_feedback(point, "move", append_order)
	elif mode == "focus":
		var enemy: Node2D = game._entity_at(point)
		if enemy != null and game.is_enemy(0, enemy.owner_id):
			for subject in game.selected:
				if is_instance_valid(subject) and subject is RtsUnit and subject.attack_damage() > 0.0:
					subject.issue_command("attack", Vector2.INF, enemy, append_order)
			game._show_order_feedback(point, "attack", append_order)
		else:
			game.notify_player("请选择可见的敌方目标")
			game._show_order_feedback(point, "invalid")
	elif mode == "attack_ground":
		for subject in game.selected:
			if is_instance_valid(subject) and subject is RtsUnit: subject.issue_command("attack_ground", point, null, append_order)
		game._show_order_feedback(point, "attack", append_order)
	elif mode in ["field_ram", "field_tower"]:
		game.place_field_siege("battering_ram" if mode == "field_ram" else "siege_tower", point, append_order)
	elif mode == "unload":
		if game.world_map.is_walkable(point):
			for subject in game.selected:
				if is_instance_valid(subject) and subject is RtsUnit and subject.kind == "transport_ship": subject.issue_command("unload", point, null, append_order)
			game._show_order_feedback(point, "move", append_order)
		else:
			game.notify_player("请点击陆地作为登陆目标")
			game._show_order_feedback(point, "invalid")
	game.queue_redraw()

static func issue_attack_move(game: Node2D, point: Vector2, append_order := false) -> void:
	if not append_order: game.order_mode = ""
	var movers: Array[RtsUnit] = []
	for subject in game.selected:
		if not is_instance_valid(subject) or not subject is RtsUnit or not subject.stats.get("tags", []).has("military"): continue
		movers.append(subject)
	game.issue_group_order(movers, point, true, append_order)
	if not movers.is_empty(): game._show_order_feedback(point, "attack", append_order)
	game.queue_redraw()

static func issue_group_order(game: Node2D, movers: Array[RtsUnit], point: Vector2, attack_move := false, append_order := false) -> void:
	if movers.is_empty(): return
	var squads := RtsMovementGroup.split_squads(movers)
	var center := Vector2.ZERO
	for unit in movers: center += unit.position
	center /= movers.size()
	var heading := (point - center).normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	var lateral := Vector2(-heading.y, heading.x)
	squads.sort_custom(func(a: Array, b: Array) -> bool:
		var ac := Vector2.ZERO
		var bc := Vector2.ZERO
		for unit in a: ac += unit.position
		for unit in b: bc += unit.position
		ac /= a.size()
		bc /= b.size()
		var front_a := ac.dot(heading)
		var front_b := bc.dot(heading)
		if absf(front_a - front_b) > 25.0: return front_a > front_b
		return ac.dot(lateral) < bc.dot(lateral)
	)
	var columns := mini(6 if squads.size() > 12 else 3, maxi(1, ceili(sqrt(float(squads.size())))))
	var rows := ceili(float(squads.size()) / columns)
	var squad_spacing := 140.0 if squads.size() > 12 else 200.0
	for index in squads.size():
		var squad: Array[RtsUnit] = squads[index]
		var group_point := point
		if squads.size() > 1:
			var row := index / columns
			var col := index % columns
			group_point += heading * (float(rows - 1) * 0.5 - float(row)) * squad_spacing + lateral * (float(col) - float(columns - 1) * 0.5) * squad_spacing
		var group := RtsMovementGroup.new(game, squad, group_point, game.formation_mode, game.formation_width)
		for unit in squad:
			unit.issue_command("group_attack_move" if attack_move else "group_move", group_point, null, append_order, group)

static func stop_selected_units(game: Node2D) -> void:
	game.order_mode = ""
	for subject in game.selected:
		if is_instance_valid(subject) and subject is RtsUnit: subject.order_stop()
	game.notify_player("单位已停止")

static func retreat_selected(game: Node2D) -> void:
	for subject in game.selected:
		if not is_instance_valid(subject) or not subject is RtsUnit: continue
		var center: RtsBuilding = game.find_nearest_owned_building(0, "town_center", subject.position)
		if center != null: subject.issue_command("move", center.position)
	game.notify_player("部队撤往城镇中心")
