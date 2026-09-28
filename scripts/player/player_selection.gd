extends RefCounted

# Screen picking and player selection use the match state owned by the game.

static func select_area(game: Node2D, from: Vector2, to: Vector2, additive: bool) -> void:
	var world_to_screen := game.get_viewport().get_canvas_transform()
	game._select_screen_area(world_to_screen * from, world_to_screen * to, additive)

static func select_screen_area(game: Node2D, from: Vector2, to: Vector2, additive: bool) -> void:
	if not additive: game.selected.clear()
	elif game.selected.any(func(item: Node2D) -> bool: return item is RtsResource): game.selected.clear()
	var world_to_screen := game.get_viewport().get_canvas_transform()
	var screen_area := Rect2(from, to - from).abs()
	if screen_area.size.length() < 12:
		var point: Vector2 = world_to_screen.affine_inverse() * to
		var entity: Node2D = game._entity_at(point)
		if entity is RtsUnit and game.is_enemy(0, entity.owner_id):
			game.selected.clear()
			game.selected.append(entity)
		elif entity != null and entity.owner_id == 0 and not game.selected.has(entity): game.selected.append(entity)
		elif entity == null:
			var resource: RtsResource = game._resource_at(point)
			if resource != null:
				game.selected.clear()
				game.selected.append(resource)
	else:
		for unit in game.units:
			if is_instance_valid(unit) and unit.garrisoned_in == null and unit.owner_id == 0 and screen_area.has_point(world_to_screen * (unit.position + (RtsIsoProjection.ground_lift(game, unit.position) if game.view_mode_25d else Vector2.ZERO))) and not game.selected.has(unit):
				game.selected.append(unit)
	game._rebuild_actions()
	game._update_hud()
	if not game.selected.is_empty(): game.play_feedback("select")
	game.queue_redraw()

static func select_same_type_visible(game: Node2D, clicked: RtsUnit, additive: bool) -> void:
	if not additive or game.selected.any(func(item: Node2D) -> bool: return item is RtsResource): game.selected.clear()
	var world_to_screen := game.get_viewport().get_canvas_transform()
	var visible_area := game.get_viewport_rect()
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		if unit.owner_id == clicked.owner_id and unit.kind == clicked.kind and visible_area.has_point(world_to_screen * (unit.position + (RtsIsoProjection.ground_lift(game, unit.position) if game.view_mode_25d else Vector2.ZERO))) and not game.selected.has(unit):
			game.selected.append(unit)
	game._rebuild_actions()
	game._update_hud()
	game.queue_redraw()

static func select_same_buildings_visible(game: Node2D, clicked: RtsBuilding, additive: bool) -> void:
	if not additive or game.selected.any(func(item: Node2D) -> bool: return item is RtsResource): game.selected.clear()
	var world_to_screen := game.get_viewport().get_canvas_transform()
	var visible_area := game.get_viewport_rect()
	for building in game.buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion() and building.owner_id == clicked.owner_id and building.kind == clicked.kind and visible_area.has_point(world_to_screen * building.position) and not game.selected.has(building): game.selected.append(building)
	game._rebuild_actions()
	game._update_hud()
	game.queue_redraw()

static func handle_control_group(game: Node2D, event: InputEventKey) -> void:
	var key := event.keycode
	if event.ctrl_pressed:
		var members: Array[Node2D] = []
		if event.shift_pressed and game.control_groups.has(key):
			for member in game.control_groups[key]:
				if is_instance_valid(member) and not member.is_queued_for_deletion() and not member is RtsResource and member.owner_id == 0: members.append(member)
		for member in game.selected:
			if is_instance_valid(member) and not member is RtsResource and member.owner_id == 0 and not members.has(member): members.append(member)
		game.control_groups[key] = members
		game.notify_player("编组 %d：%d 个对象" % [key - KEY_0, members.size()])
		return
	var recalled: Array[Node2D] = []
	for member in game.control_groups[key]:
		if is_instance_valid(member) and not member.is_queued_for_deletion() and not member is RtsResource and member.owner_id == 0 and (not member is RtsUnit or member.garrisoned_in == null): recalled.append(member)
	game.control_groups[key] = recalled
	if not event.shift_pressed or game.selected.any(func(item: Node2D) -> bool: return item is RtsResource): game.selected.clear()
	for member in recalled:
		if not game.selected.has(member): game.selected.append(member)
	var now := Time.get_ticks_msec() / 1000.0
	if game.last_group_key == key and now - game.last_group_press_time < 0.45 and not recalled.is_empty():
		var center := Vector2.ZERO
		for member in recalled: center += member.position
		game.camera.position = center / recalled.size()
		game._clamp_camera_position()
	game.last_group_key = key
	game.last_group_press_time = now
	game._rebuild_actions()
	game._update_hud()
	game.queue_redraw()

static func entity_at(game: Node2D, point: Vector2) -> Node2D:
	var canvas := game.get_viewport().get_canvas_transform()
	for unit in game.navigation.nearby_units(point, 250.0 if game.view_mode_25d else 36.0):
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		if unit.owner_id != 0 and game.fog.active and not game.fog.can_detect_unit(0, unit): continue
		if game.view_mode_25d:
			var screen_delta := canvas.basis_xform(point - unit.position - RtsIsoProjection.ground_lift(game, unit.position))
			if absf(screen_delta.x) <= (unit.radius() + 5.0) * game.camera.zoom.x and screen_delta.y >= -34.0 * game.camera.zoom.x and screen_delta.y <= 6.0 * game.camera.zoom.x: return unit
		if is_instance_valid(unit) and unit.position.distance_to(point) <= unit.radius() + 5: return unit
	for building in game.navigation.nearby_buildings(point, 260.0 if game.view_mode_25d else 50.0):
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if building.owner_id != 0 and game.fog.active and not game.fog.can_see(0, building.position): continue
		if building.contains(point) or game.view_mode_25d and building.contains_isometric_visual(point, canvas): return building
	return null

static func resource_at(game: Node2D, point: Vector2) -> RtsResource:
	var canvas := game.get_viewport().get_canvas_transform()
	for resource in game.navigation.nearby_resources(point, 250.0 if game.view_mode_25d else 35.0):
		if not is_instance_valid(resource) or resource.is_queued_for_deletion() or game.fog.active and not game.fog.can_show_resource(0, resource): continue
		if game.view_mode_25d and resource.appearance != "fish":
			var screen_delta := canvas.basis_xform(point - resource.position - RtsIsoProjection.ground_lift(game, resource.position))
			if absf(screen_delta.x) <= (resource.radius + 8.0) * game.camera.zoom.x and screen_delta.y >= -35.0 * game.camera.zoom.x and screen_delta.y <= 20.0 * game.camera.zoom.x: return resource
		if resource.position.distance_to(point) < resource.radius + 6: return resource
	return null

static func trade_post_at(game: Node2D, point: Vector2) -> RtsTradePost:
	for post in game.trade_posts:
		if not is_instance_valid(post) or game.fog.active and not game.fog.is_explored(0, post.position): continue
		if game.view_mode_25d:
			var screen_delta := game.get_viewport().get_canvas_transform().basis_xform(point - post.position - RtsIsoProjection.ground_lift(game, post.position))
			if absf(screen_delta.x) <= 28.0 * game.camera.zoom.x and screen_delta.y >= -38.0 * game.camera.zoom.x and screen_delta.y <= 23.0 * game.camera.zoom.x: return post
		if post.contains(point): return post
	return null

static func relic_at(game: Node2D, point: Vector2) -> RtsRelic:
	for relic in game.relics:
		if not is_instance_valid(relic) or not relic.available() or game.fog.active and not game.fog.can_see(0, relic.position): continue
		if game.view_mode_25d:
			var screen_delta := game.get_viewport().get_canvas_transform().basis_xform(point - relic.position - RtsIsoProjection.ground_lift(game, relic.position))
			if absf(screen_delta.x) <= 16.0 * game.camera.zoom.x and screen_delta.y >= -20.0 * game.camera.zoom.x and screen_delta.y <= 14.0 * game.camera.zoom.x: return relic
		if relic.position.distance_to(point) <= 20.0: return relic
	return null
