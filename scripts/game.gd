extends Node2D

const WORLD_SIZE := Vector2(2400, 1500)
const CAMERA_PAN_SPEED := 570.0
const EDGE_SCROLL_MARGIN := 28.0
const UNIT_SCENE := preload("res://scripts/unit.gd")
const BUILDING_SCENE := preload("res://scripts/building.gd")
const RESOURCE_SCENE := preload("res://scripts/resource_node.gd")

var world_size := WORLD_SIZE
var civilizations := ["English", "French"]
var players: Array[Dictionary] = []
var units: Array[RtsUnit] = []
var buildings: Array[RtsBuilding] = []
var resources: Array[RtsResource] = []
var selected: Array[Node2D] = []
var camera: Camera2D
var started := false
var game_over := false
var paused := false
var selected_civ := "English"
var build_mode := ""
var dragging := false
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var ai_timer := 0.0
var ai: RtsAiController
var hud_timer := 0.0
var notice_timer := 0.0
var hit_lines: Array[Dictionary] = []

var top_label: Label
var info_label: Label
var notice_label: Label
var action_bar: HBoxContainer
var menu_panel: PanelContainer
var result_panel: PanelContainer
var pause_overlay: ColorRect
var cursor: GameCursor

func _ready() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(630, 720)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	add_child(camera)
	camera.make_current()
	ai = RtsAiController.new(self)
	_create_hud()
	_create_cursor()
	_show_menu()
	queue_redraw()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _create_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	cursor = GameCursor.new()
	layer.add_child(cursor)
	cursor.hide()

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 55
	root.add_child(top)
	top_label = Label.new()
	top_label.add_theme_font_size_override("font_size", 18)
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(top_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -154
	root.add_child(bottom)
	var dock := VBoxContainer.new()
	dock.add_theme_constant_override("separation", 8)
	bottom.add_child(dock)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 17)
	info_label.text = "左键选择 / 框选  ·  右键下令  ·  WASD 或鼠标靠边移动画面  ·  滚轮缩放"
	dock.add_child(info_label)
	action_bar = HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 7)
	dock.add_child(action_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(spacer)
	notice_label = Label.new()
	notice_label.add_theme_color_override("font_color", Color("f0d783"))
	dock.add_child(notice_label)
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(460, 300)
	menu_panel.offset_left = -230
	menu_panel.offset_top = -150
	menu_panel.offset_right = 230
	menu_panel.offset_bottom = 150
	root.add_child(menu_panel)
	result_panel = PanelContainer.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(400, 220)
	result_panel.offset_left = -200
	result_panel.offset_top = -110
	result_panel.offset_right = 200
	result_panel.offset_bottom = 110
	result_panel.hide()
	root.add_child(result_panel)
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.06, 0.09, 0.10, 0.67)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.hide()
	root.add_child(pause_overlay)
	var pause_panel := PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(380, 280)
	pause_panel.offset_left = -190
	pause_panel.offset_top = -140
	pause_panel.offset_right = 190
	pause_panel.offset_bottom = 140
	pause_overlay.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_box)
	_add_menu_label(pause_box, "游戏已暂停", 27)
	_add_menu_label(pause_box, "按 Esc 继续游戏", 16)
	_add_pause_button(pause_box, "继续游戏", func() -> void: _set_paused(false))
	_add_pause_button(pause_box, "重新开始", func() -> void: start_game(selected_civ))
	_add_pause_button(pause_box, "返回文明选择", func() -> void: _return_to_menu())
	_add_pause_button(pause_box, "退出游戏", func() -> void: get_tree().quit())

func _add_pause_button(parent: Node, label_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)

func _show_menu() -> void:
	paused = false
	if pause_overlay != null: pause_overlay.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if cursor != null: cursor.hide()
	for child in menu_panel.get_children(): child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	menu_panel.add_child(box)
	_add_menu_label(box, "AGE OF EMPIRE LITE", 27)
	_add_menu_label(box, "选择文明，开始与电脑进行一场即时战略对战。", 17)
	_add_menu_label(box, "英格兰：农田收益和长弓兵    法兰西：骑士冲锋和快速骑兵", 15)
	for civ in ["English", "French"]:
		var button := Button.new()
		button.text = "使用%s开始" % GameData.CIVILIZATIONS[civ]["label"]
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void: start_game(civ))
		box.add_child(button)
	_add_menu_label(box, "目标：摧毁敌人的城镇中心。画面使用临时图形。", 14)
	menu_panel.show()

func _add_menu_label(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func start_game(civ: String) -> void:
	_clear_world()
	paused = false
	pause_overlay.hide()
	selected_civ = civ
	civilizations = [civ, "French" if civ == "English" else "English"]
	players = [
		{"food": 340, "wood": 360, "gold": 150, "stone": 100, "age": 1},
		{"food": 420, "wood": 420, "gold": 170, "stone": 100, "age": 1},
	]
	started = true
	game_over = false
	build_mode = ""
	ai_timer = 0.0
	camera.position = Vector2(630, 720)
	menu_panel.hide()
	result_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cursor.show()
	_spawn_map_resources()
	for owner_id in 2:
		var base := Vector2(330, 720) if owner_id == 0 else Vector2(2070, 720)
		spawn_building(owner_id, "town_center", base)
		for i in 5:
			var worker := spawn_unit(owner_id, "villager", base + Vector2((i % 3) * 29 - 30, 80 + (i / 3) * 28))
			var resource := find_nearest_resource(worker.position, "food" if i < 2 else "wood" if i < 4 else "gold")
			if resource != null: worker.order_gather(resource)
	_update_hud()
	_rebuild_actions()
	queue_redraw()

func _clear_world() -> void:
	for unit in units: if is_instance_valid(unit): unit.queue_free()
	for building in buildings: if is_instance_valid(building): building.queue_free()
	for resource in resources: if is_instance_valid(resource): resource.queue_free()
	units.clear()
	buildings.clear()
	resources.clear()
	selected.clear()
	hit_lines.clear()

func _set_paused(value: bool) -> void:
	if not started or game_over: return
	paused = value
	dragging = false
	pause_overlay.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_HIDDEN
	cursor.visible = not value
	queue_redraw()

func _return_to_menu() -> void:
	_clear_world()
	started = false
	game_over = false
	paused = false
	build_mode = ""
	result_panel.hide()
	top_label.text = ""
	_rebuild_actions()
	_show_menu()
	queue_redraw()

func _spawn_map_resources() -> void:
	for side in [0, 1]:
		var x := 330.0 if side == 0 else 2070.0
		for i in 5:
			spawn_resource("wood", Vector2(x + (-270 if side == 0 else 270) + (i % 2) * 52, 570 + (i / 2) * 57), 500)
		for i in 4:
			spawn_resource("food", Vector2(x + (120 if side == 0 else -120) + (i % 2) * 55, 560 + (i / 2) * 55), 420)
		for i in 3:
			spawn_resource("gold", Vector2(x + (-180 if side == 0 else 180) + i * 50, 930), 580)
		for i in 3:
			spawn_resource("stone", Vector2(x + (100 if side == 0 else -100) + i * 50, 970), 560)
	for i in 7:
		spawn_resource("wood", Vector2(1100 + (i % 3) * 60, 350 + (i / 3) * 60), 550)
	for i in 5:
		spawn_resource("gold", Vector2(1100 + (i % 3) * 60, 1130 + (i / 3) * 60), 550)

func spawn_resource(kind: String, world_point: Vector2, amount: int) -> RtsResource:
	var resource: RtsResource = RESOURCE_SCENE.new()
	resource.position = world_point
	add_child(resource)
	resource.setup(kind, amount)
	resources.append(resource)
	return resource

func spawn_unit(owner_id: int, kind: String, world_point: Vector2, rally := Vector2.INF) -> RtsUnit:
	var unit: RtsUnit = UNIT_SCENE.new()
	unit.position = world_point
	add_child(unit)
	unit.setup(self, owner_id, kind)
	units.append(unit)
	if rally != Vector2.INF: unit.order_move(rally)
	_update_hud()
	return unit

func spawn_building(owner_id: int, kind: String, world_point: Vector2, under_construction := false) -> RtsBuilding:
	var building: RtsBuilding = BUILDING_SCENE.new()
	building.position = world_point
	add_child(building)
	building.setup(self, owner_id, kind, under_construction)
	buildings.append(building)
	_update_hud()
	return building

func find_spawn_position(building: RtsBuilding) -> Vector2:
	var direction := 1 if building.owner_id == 0 else -1
	return building.position + Vector2(direction * (building.size().x * 0.5 + 27), randf_range(-25, 25))

func building_completed(building: RtsBuilding) -> void:
	if building.owner_id == 0: notify_player("%s建造完成" % GameData.BUILDINGS[building.kind]["label"])
	_rebuild_actions()
	_update_hud()

func entity_destroyed(entity: Node2D) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion(): return
	selected.erase(entity)
	if entity is RtsUnit:
		units.erase(entity)
	elif entity is RtsBuilding:
		buildings.erase(entity)
		if entity.kind == "town_center":
			_finish_game(entity.owner_id != 0)
	entity.queue_free()
	_rebuild_actions()
	_update_hud()

func _finish_game(won: bool) -> void:
	game_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cursor.hide()
	for child in result_panel.get_children(): child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	result_panel.add_child(box)
	_add_menu_label(box, "胜利！" if won else "战败", 30)
	_add_menu_label(box, "敌方城镇中心已被摧毁。" if won else "你的城镇中心被摧毁了。", 17)
	var button := Button.new()
	button.text = "返回文明选择"
	button.pressed.connect(func() -> void: _return_to_menu())
	box.add_child(button)
	result_panel.show()

func credit_resource(owner_id: int, kind: String, amount: int) -> void:
	players[owner_id][kind] += amount
	if owner_id == 0: _update_hud()

func can_afford(owner_id: int, cost: Dictionary) -> bool:
	for resource in cost:
		if players[owner_id][resource] < cost[resource]: return false
	return true

func spend(owner_id: int, cost: Dictionary) -> bool:
	if not can_afford(owner_id, cost): return false
	for resource in cost: players[owner_id][resource] -= cost[resource]
	_update_hud()
	return true

func population_used(owner_id: int) -> int:
	var used := 0
	for unit in units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: used += 1
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id:
			used += building.training_queue.size()
	return used

func population_cap(owner_id: int) -> int:
	var cap := 0
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.is_complete():
			cap += GameData.BUILDINGS[building.kind]["pop"]
	return cap

func train_unit(building: RtsBuilding, unit_kind: String) -> bool:
	if game_over or not is_instance_valid(building) or not building.is_complete(): return false
	if not GameData.can_use_unit(civilizations[building.owner_id], unit_kind): return false
	if players[building.owner_id]["age"] < GameData.UNITS[unit_kind]["age"]: return false
	if population_used(building.owner_id) >= population_cap(building.owner_id):
		if building.owner_id == 0: notify_player("人口已满，请建造房屋")
		return false
	if not spend(building.owner_id, GameData.UNITS[unit_kind]["cost"]):
		if building.owner_id == 0: notify_player("资源不足")
		return false
	building.enqueue(unit_kind)
	if building.owner_id == 0: notify_player("正在训练%s" % GameData.UNITS[unit_kind]["label"])
	_update_hud()
	return true

func advance_age(owner_id: int) -> bool:
	var age: int = players[owner_id]["age"]
	if age >= 4: return false
	if not spend(owner_id, GameData.age_cost(age)):
		if owner_id == 0: notify_player("升级时代所需资源不足")
		return false
	players[owner_id]["age"] = age + 1
	if owner_id == 0:
		notify_player("进入时代 %d！" % (age + 1))
		_rebuild_actions()
	_update_hud()
	return true

func can_place(kind: String, world_point: Vector2) -> bool:
	var half: Vector2 = GameData.BUILDINGS[kind]["size"] * 0.5
	if world_point.x < half.x + 20 or world_point.y < half.y + 70: return false
	if world_point.x > WORLD_SIZE.x - half.x - 20 or world_point.y > WORLD_SIZE.y - half.y - 20: return false
	var footprint := Rect2(world_point - half - Vector2(9, 9), half * 2 + Vector2(18, 18))
	for building in buildings:
		if is_instance_valid(building):
			var other := Rect2(building.position - building.size() * 0.5, building.size())
			if footprint.intersects(other): return false
	for resource in resources:
		if is_instance_valid(resource) and footprint.grow(resource.radius * 0.5).has_point(resource.position): return false
	return true

func place_building(owner_id: int, kind: String, world_point: Vector2, worker: RtsUnit) -> bool:
	if not can_place(kind, world_point):
		if owner_id == 0: notify_player("这里不能建造")
		return false
	if not spend(owner_id, GameData.BUILDINGS[kind]["cost"]):
		if owner_id == 0: notify_player("建造资源不足")
		return false
	var building := spawn_building(owner_id, kind, world_point, true)
	worker.order_build(building)
	if owner_id == 0: notify_player("正在建造%s" % GameData.BUILDINGS[kind]["label"])
	return true

func find_nearest_resource(world_point: Vector2, kind: String) -> RtsResource:
	var nearest: RtsResource
	var shortest := INF
	for resource in resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion() or resource.kind != kind: continue
		var distance := world_point.distance_squared_to(resource.position)
		if distance < shortest:
			shortest = distance
			nearest = resource
	return nearest

func nearest_enemy(unit: RtsUnit, max_distance: float) -> Node2D:
	var best: Node2D
	var distance_limit := max_distance * max_distance
	for other in units:
		if not is_instance_valid(other) or other == unit or other.owner_id == unit.owner_id: continue
		var d := unit.position.distance_squared_to(other.position)
		if d < distance_limit:
			distance_limit = d
			best = other
	for building in buildings:
		if not is_instance_valid(building) or building.owner_id == unit.owner_id: continue
		var d := unit.position.distance_squared_to(building.position)
		if d < distance_limit:
			distance_limit = d
			best = building
	return best

func show_hit(from: Vector2, to: Vector2, owner_id: int) -> void:
	hit_lines.append({"from": from, "to": to, "owner": owner_id, "time": 0.13})
	queue_redraw()

func notify_player(message: String) -> void:
	notice_label.text = message
	notice_timer = 3.5

func _process(delta: float) -> void:
	if not started or game_over or paused: return
	_pan_camera(delta)
	_update_cursor()
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0: notice_label.text = ""
	ai_timer -= delta
	if ai_timer <= 0.0:
		ai.tick()
		ai_timer = 3.0
	hud_timer -= delta
	if hud_timer <= 0.0:
		_update_hud()
		hud_timer = 0.4
	for line in hit_lines:
		line["time"] -= delta
	hit_lines = hit_lines.filter(func(line: Dictionary) -> bool: return line["time"] > 0.0)
	if dragging or build_mode != "" or not hit_lines.is_empty(): queue_redraw()

func _pan_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	if get_window().has_focus():
		direction += _edge_pan_direction(get_viewport().get_mouse_position(), get_viewport_rect().size)
	if direction != Vector2.ZERO:
		camera.position += direction.normalized() * CAMERA_PAN_SPEED * delta / camera.zoom.x
		camera.position = camera.position.clamp(Vector2.ZERO, WORLD_SIZE)

func _edge_pan_direction(screen_point: Vector2, viewport_size: Vector2) -> Vector2:
	if not Rect2(Vector2.ZERO, viewport_size).has_point(screen_point): return Vector2.ZERO
	var direction := Vector2.ZERO
	if screen_point.x <= EDGE_SCROLL_MARGIN: direction.x -= 1
	if screen_point.x >= viewport_size.x - EDGE_SCROLL_MARGIN: direction.x += 1
	if screen_point.y <= EDGE_SCROLL_MARGIN: direction.y -= 1
	if screen_point.y >= viewport_size.y - EDGE_SCROLL_MARGIN: direction.y += 1
	return direction

func _update_cursor() -> void:
	var screen_point := get_viewport().get_mouse_position()
	cursor.position = screen_point
	var hovered := get_viewport().gui_get_hovered_control()
	var over_ui := hovered != null and hovered != cursor
	cursor.set_state(_cursor_state_at(get_global_mouse_position(), over_ui))

func _cursor_state_at(world_point: Vector2, over_ui := false) -> String:
	if over_ui: return "default"
	if build_mode != "":
		var cost: Dictionary = GameData.BUILDINGS[build_mode]["cost"]
		return "build_valid" if can_place(build_mode, world_point) and can_afford(0, cost) else "build_invalid"
	if dragging and drag_start.distance_to(world_point) > 12.0: return "drag"
	var entity := _entity_at(world_point)
	var resource := _resource_at(world_point)
	var has_unit := false
	var has_worker := false
	for subject in selected:
		if not is_instance_valid(subject) or not subject is RtsUnit: continue
		has_unit = true
		if subject.kind == "villager": has_worker = true
	if entity != null and entity.owner_id == 1 and has_unit: return "attack"
	if has_worker and (resource != null or entity is RtsBuilding and entity.kind == "farm"): return "gather"
	if entity != null and entity.owner_id == 0: return "select"
	if has_unit: return "move"
	return "default"

func _player_center(owner_id: int) -> RtsBuilding:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "town_center": return building
	return null

func _input(event: InputEvent) -> void:
	if not started or game_over: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_paused(not paused)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not started or game_over or paused: return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT): cursor.flash()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.7, 0.7), Vector2(1.65, 1.65))
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.7, 0.7), Vector2(1.65, 1.65))
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if build_mode != "":
					_confirm_build(get_global_mouse_position())
					return
				dragging = true
				drag_start = get_global_mouse_position()
				drag_current = drag_start
			else:
				if dragging:
					dragging = false
					_select_area(drag_start, get_global_mouse_position(), event.shift_pressed)
					queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if build_mode != "":
				build_mode = ""
				notify_player("已取消建造")
				return
			_issue_order(get_global_mouse_position())
			return
	if event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			for entity in selected.duplicate():
				if entity is RtsBuilding and entity.kind != "town_center": entity_destroyed(entity)

func _select_area(from: Vector2, to: Vector2, additive: bool) -> void:
	if not additive: selected.clear()
	if from.distance_to(to) < 12:
		var entity := _entity_at(to)
		if entity != null and entity.owner_id == 0 and not selected.has(entity): selected.append(entity)
	else:
		var area := Rect2(from, to - from).abs()
		for unit in units:
			if is_instance_valid(unit) and unit.owner_id == 0 and area.has_point(unit.position) and not selected.has(unit):
				selected.append(unit)
	_rebuild_actions()
	queue_redraw()

func _entity_at(point: Vector2) -> Node2D:
	for unit in units:
		if is_instance_valid(unit) and unit.position.distance_to(point) <= unit.radius() + 5: return unit
	for building in buildings:
		if is_instance_valid(building) and building.contains(point): return building
	return null

func _resource_at(point: Vector2) -> RtsResource:
	for resource in resources:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion() and resource.position.distance_to(point) < resource.radius + 6:
			return resource
	return null

func _issue_order(point: Vector2) -> void:
	var entity := _entity_at(point)
	var resource := _resource_at(point)
	var index := 0
	for subject in selected:
		if not is_instance_valid(subject) or not subject is RtsUnit: continue
		if entity != null and entity.owner_id == 1:
			subject.order_attack(entity)
		elif resource != null and subject.kind == "villager":
			subject.order_gather(resource)
		elif entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "farm" and subject.kind == "villager":
			subject.order_gather(entity)
		else:
			var offset := Vector2((index % 4) * 25 - 37, (index / 4) * 25 - 25)
			subject.order_move(point + offset)
		index += 1

func _confirm_build(point: Vector2) -> void:
	var worker: RtsUnit
	for entity in selected:
		if is_instance_valid(entity) and entity is RtsUnit and entity.kind == "villager":
			worker = entity
			break
	if worker == null:
		build_mode = ""
		return
	if place_building(0, build_mode, point, worker):
		build_mode = ""
		_rebuild_actions()
	queue_redraw()

func _update_hud() -> void:
	if top_label == null or players.is_empty(): return
	var bank := players[0]
	top_label.text = "%s  ·  时代 %d     食物 %d    木材 %d    黄金 %d    石料 %d     人口 %d/%d" % [
		GameData.CIVILIZATIONS[civilizations[0]]["label"], bank["age"], bank["food"], bank["wood"], bank["gold"], bank["stone"], population_used(0), population_cap(0)]
	if not selected.is_empty():
		var item := selected[0]
		if is_instance_valid(item):
			var name: String = GameData.UNITS[item.kind]["label"] if item is RtsUnit else GameData.BUILDINGS[item.kind]["label"]
			info_label.text = "%s ×%d  ·  生命 %.0f/%.0f%s" % [name, selected.size(), item.hp, item.max_hp, "  ·  建造中" if item is RtsBuilding and not item.is_complete() else ""]
	else:
		info_label.text = "左键选择 / 框选  ·  右键下令  ·  WASD 或鼠标靠边移动画面  ·  滚轮缩放"

func _rebuild_actions() -> void:
	if action_bar == null: return
	for child in action_bar.get_children(): child.queue_free()
	if selected.is_empty() or not is_instance_valid(selected[0]): return
	var item := selected[0]
	if item is RtsUnit:
		var any_worker := false
		for unit in selected:
			if is_instance_valid(unit) and unit is RtsUnit and unit.kind == "villager": any_worker = true
		if any_worker:
			for kind in ["house", "farm", "barracks", "archery_range", "stable"]:
				if players[0]["age"] < GameData.BUILDINGS[kind]["age"]: continue
				var text_value := "建造%s (%s)" % [GameData.BUILDINGS[kind]["label"], GameData.cost_text(GameData.BUILDINGS[kind]["cost"])]
				_add_action(text_value, func() -> void:
					build_mode = kind
					notify_player("点击地图放置%s；右键取消" % GameData.BUILDINGS[kind]["label"])
				)
	elif item is RtsBuilding and item.is_complete():
		for kind in GameData.BUILDINGS[item.kind]["trains"]:
			if not GameData.can_use_unit(civilizations[0], kind): continue
			if players[0]["age"] < GameData.UNITS[kind]["age"]: continue
			var text_value := "训练%s (%s)" % [GameData.UNITS[kind]["label"], GameData.cost_text(GameData.UNITS[kind]["cost"])]
			_add_action(text_value, func() -> void: train_unit(item, kind))
		if item.kind == "town_center" and players[0]["age"] < 4:
			var age: int = players[0]["age"]
			_add_action("升级时代 (%s)" % GameData.cost_text(GameData.age_cost(age)), func() -> void: advance_age(0))

func _add_action(label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	action_bar.add_child(button)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("638b5c"))
	for x in range(0, int(WORLD_SIZE.x), 100):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color(1, 1, 1, 0.055), 1)
	for y in range(0, int(WORLD_SIZE.y), 100):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), Color(1, 1, 1, 0.055), 1)
	draw_rect(Rect2(Vector2(150, 625), Vector2(2100, 190)), Color("8c9364"), false, 80)
	for entity in selected:
		if not is_instance_valid(entity): continue
		if entity is RtsUnit:
			draw_arc(entity.position, entity.radius() + 6, 0, TAU, 32, Color("f5e597"), 2)
		elif entity is RtsBuilding:
			draw_rect(Rect2(entity.position - entity.size() * 0.5 - Vector2(5, 5), entity.size() + Vector2(10, 10)), Color("f5e597"), false, 2)
	if dragging:
		draw_rect(Rect2(drag_start, drag_current - drag_start).abs(), Color("f5e597"), false, 2)
	if build_mode != "":
		var mouse := get_global_mouse_position()
		var valid := can_place(build_mode, mouse)
		var size: Vector2 = GameData.BUILDINGS[build_mode]["size"]
		draw_rect(Rect2(mouse - size * 0.5, size), Color(0.25, 0.9, 0.4, 0.35) if valid else Color(0.9, 0.2, 0.2, 0.35))
	for line in hit_lines:
		var color: Color = GameData.CIVILIZATIONS[civilizations[line["owner"]]]["color"].lightened(0.45)
		draw_line(line["from"], line["to"], color, 3)
