extends Node2D

const WORLD_SIZE := Vector2(2400, 1500)
const CAMERA_PAN_SPEED := 570.0
const GESTURE_PAN_PIXELS := 32.0
const EDGE_SCROLL_MARGIN := 28.0
const UNIT_SCENE := preload("res://scripts/unit.gd")
const BUILDING_SCENE := preload("res://scripts/building.gd")
const RESOURCE_SCENE := preload("res://scripts/resource_node.gd")

var world_size := WORLD_SIZE
var civilizations := ["English", "French"]
var teams: Array[int] = [0, 1]
var match_mode := "duel"
var match_choice: OptionButton
var defeated_players: Array[int] = []
var players: Array[Dictionary] = []
var units: Array[RtsUnit] = []
var buildings: Array[RtsBuilding] = []
var resources: Array[RtsResource] = []
var trade_posts: Array[RtsTradePost] = []
var relics: Array[RtsRelic] = []
var selected: Array[Node2D] = []
var camera: Camera2D
var world_map: RtsWorldMap
var navigation: RtsNavigation
var weather: RtsWeather
var fog: RtsFogOfWar
var objectives: RtsObjectiveManager
var map_seed := 0
var map_style := "balanced"
var selected_map_size := WORLD_SIZE
var selected_map_style := "balanced"
var map_size_choice: OptionButton
var map_style_choice: OptionButton
var map_seed_input: LineEdit
var started := false
var game_over := false
var paused := false
var selected_civ := "English"
var selected_opponent_civ := "French"
var build_mode := ""
var pending_landmark_id := ""
var build_page := 0
var order_mode := ""
var dragging := false
var wall_dragging := false
var wall_vertical := false
var wall_start := Vector2.ZERO
var wall_end := Vector2.ZERO
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var ai_timer := 0.0
var ai: RtsAiController
var ai_controllers: Array[RtsAiController] = []
var hud_timer := 0.0
var notice_timer := 0.0
var hit_lines: Array[Dictionary] = []

var top_label: Label
var info_label: Label
var detail_label: Label
var selection_icon: Label
var selection_health: ProgressBar
var selection_progress: ProgressBar
var queue_label: Label
var queue_controls: HBoxContainer
var queue_choice: OptionButton
var cancel_queue_button: Button
var command_title: Label
var notice_label: Label
var action_bar: GridContainer
var command_buttons: Array[RtsCommandButton] = []
var hotkey_buttons: Dictionary = {}
var minimap: RtsMinimap
var menu_panel: PanelContainer
var result_panel: PanelContainer
var pause_overlay: ColorRect
var cursor: GameCursor

func _ready() -> void:
	world_map = RtsWorldMap.new()
	world_map.z_index = -10
	add_child(world_map)
	world_map.hide()
	navigation = RtsNavigation.new(self, world_map)
	camera = Camera2D.new()
	camera.position = Vector2(630, 720)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	add_child(camera)
	camera.make_current()
	weather = RtsWeather.new()
	weather.z_index = 10
	add_child(weather)
	weather.hide()
	fog = RtsFogOfWar.new()
	fog.z_index = 20
	add_child(fog)
	fog.setup(self)
	fog.hide()
	objectives = RtsObjectiveManager.new()
	objectives.z_index = 2
	add_child(objectives)
	objectives.victory.connect(func(owner_id: int, reason: String) -> void: _finish_game(not is_enemy(0, owner_id), reason))
	objectives.site_captured.connect(func(_index: int, owner_id: int) -> void:
		if owner_id == 0: notify_player("圣地已占领")
	)
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
	bottom.offset_top = -194
	bottom.add_theme_stylebox_override("panel", _hud_panel_style(Color("192423"), 7))
	root.add_child(bottom)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 9)
	bottom.add_child(dock)
	var command_panel := PanelContainer.new()
	command_panel.custom_minimum_size.x = 368
	command_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color("111a1a"), 6))
	dock.add_child(command_panel)
	var command_column := VBoxContainer.new()
	command_column.add_theme_constant_override("separation", 6)
	command_panel.add_child(command_column)
	command_title = Label.new()
	command_title.text = "命令"
	command_title.add_theme_font_size_override("font_size", 17)
	command_column.add_child(command_title)
	var action_scroll := ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(350, 155)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	command_column.add_child(action_scroll)
	action_bar = GridContainer.new()
	action_bar.columns = 3
	action_bar.add_theme_constant_override("h_separation", 6)
	action_bar.add_theme_constant_override("v_separation", 5)
	action_scroll.add_child(action_bar)
	var selection_panel := PanelContainer.new()
	selection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color("172322"), 7))
	dock.add_child(selection_panel)
	var selection_row := HBoxContainer.new()
	selection_row.add_theme_constant_override("separation", 10)
	selection_panel.add_child(selection_row)
	selection_icon = Label.new()
	selection_icon.custom_minimum_size.x = 58
	selection_icon.custom_minimum_size.y = 58
	selection_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	selection_icon.text = "◆"
	selection_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_icon.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	selection_icon.add_theme_font_size_override("font_size", 36)
	selection_row.add_child(selection_icon)
	var selection_column := VBoxContainer.new()
	selection_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_column.add_theme_constant_override("separation", 7)
	selection_row.add_child(selection_column)
	info_label = Label.new()
	info_label.text = "未选择"
	info_label.add_theme_font_size_override("font_size", 19)
	selection_column.add_child(info_label)
	detail_label = Label.new()
	detail_label.text = "左键选择 · 右键下令"
	detail_label.add_theme_font_size_override("font_size", 14)
	selection_column.add_child(detail_label)
	selection_health = ProgressBar.new()
	selection_health.show_percentage = false
	selection_health.custom_minimum_size = Vector2(285, 11)
	selection_health.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_progress_bar(selection_health, Color("80c47f"))
	selection_health.hide()
	selection_column.add_child(selection_health)
	selection_progress = ProgressBar.new()
	selection_progress.show_percentage = false
	selection_progress.custom_minimum_size = Vector2(285, 9)
	selection_progress.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_progress_bar(selection_progress, Color("dcc778"))
	selection_progress.hide()
	selection_column.add_child(selection_progress)
	queue_label = Label.new()
	queue_label.add_theme_font_size_override("font_size", 13)
	selection_column.add_child(queue_label)
	queue_controls = HBoxContainer.new()
	queue_controls.hide()
	selection_column.add_child(queue_controls)
	queue_choice = OptionButton.new()
	queue_choice.custom_minimum_size.x = 205
	queue_controls.add_child(queue_choice)
	cancel_queue_button = Button.new()
	cancel_queue_button.text = "取消并退款"
	cancel_queue_button.pressed.connect(_cancel_selected_job)
	queue_controls.add_child(cancel_queue_button)
	notice_label = Label.new()
	notice_label.add_theme_color_override("font_color", Color("f0d783"))
	notice_label.add_theme_font_size_override("font_size", 13)
	selection_column.add_child(notice_label)
	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size.x = 220
	map_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color("111a1a"), 5))
	dock.add_child(map_panel)
	var map_column := VBoxContainer.new()
	map_column.add_theme_constant_override("separation", 5)
	map_panel.add_child(map_column)
	var map_title := Label.new()
	map_title.text = "小地图  ·  点击定位"
	map_title.add_theme_font_size_override("font_size", 15)
	map_column.add_child(map_title)
	minimap = RtsMinimap.new()
	map_column.add_child(minimap)
	minimap.setup(self)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(500, 480)
	menu_panel.offset_left = -250
	menu_panel.offset_top = -240
	menu_panel.offset_right = 250
	menu_panel.offset_bottom = 240
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
	_add_pause_button(pause_box, "重新开始", func() -> void: start_game(selected_civ, -1, selected_opponent_civ))
	_add_pause_button(pause_box, "返回文明选择", func() -> void: _return_to_menu())
	_add_pause_button(pause_box, "退出游戏", func() -> void: get_tree().quit())

func _hud_panel_style(color: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("35413e")
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

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
	_add_menu_label(box, "选择地图与文明，开始与电脑进行即时战略对战。", 17)
	var options := HBoxContainer.new()
	box.add_child(options)
	map_size_choice = OptionButton.new()
	map_size_choice.add_item("标准地图", 0)
	map_size_choice.add_item("大型地图", 1)
	map_size_choice.selected = 1 if selected_map_size.x > WORLD_SIZE.x else 0
	options.add_child(map_size_choice)
	map_style_choice = OptionButton.new()
	map_style_choice.add_item("平衡", 0)
	map_style_choice.add_item("大湖", 1)
	map_style_choice.add_item("高地", 2)
	map_style_choice.selected = ["balanced", "lakes", "highlands"].find(selected_map_style)
	options.add_child(map_style_choice)
	match_choice = OptionButton.new()
	for option in ["1 对 1", "三方混战", "四方混战", "2 对 2"]: match_choice.add_item(option)
	match_choice.selected = ["duel", "ffa3", "ffa4", "team2"].find(match_mode)
	options.add_child(match_choice)
	map_seed_input = LineEdit.new()
	map_seed_input.placeholder_text = "地图种子（留空随机）"
	map_seed_input.custom_minimum_size.x = 170
	options.add_child(map_seed_input)
	for civ in GameData.CIVILIZATIONS:
		var button := Button.new()
		button.text = "%s · %s" % [GameData.CIVILIZATIONS[civ]["label"], GameData.CIVILIZATIONS[civ]["description"]]
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void:
			match_mode = ["duel", "ffa3", "ffa4", "team2"][match_choice.selected]
			selected_map_size = Vector2(3000, 1800) if map_size_choice.selected == 1 else WORLD_SIZE
			selected_map_style = ["balanced", "lakes", "highlands"][map_style_choice.selected]
			var requested := int(map_seed_input.text) if map_seed_input.text.is_valid_int() else -1
			start_game(civ, requested)
		)
		box.add_child(button)
	_add_menu_label(box, "目标：摧毁城镇中心和地标、控制圣地，或建造奇观。", 14)
	menu_panel.show()

func _add_menu_label(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func start_game(civ: String, requested_seed := -1, opponent_civ := "") -> void:
	if not GameData.CIVILIZATIONS.has(civ): return
	var civilization_ids := GameData.CIVILIZATIONS.keys()
	if opponent_civ == "" or opponent_civ == civ or not GameData.CIVILIZATIONS.has(opponent_civ):
		opponent_civ = civilization_ids[(civilization_ids.find(civ) + 1) % civilization_ids.size()]
	_clear_world()
	paused = false
	pause_overlay.hide()
	selected_civ = civ
	selected_opponent_civ = opponent_civ
	var player_count := 2 if match_mode == "duel" else 3 if match_mode == "ffa3" else 4
	teams.clear()
	civilizations.clear()
	players.clear()
	defeated_players.clear()
	for owner_id in player_count:
		teams.append(0 if owner_id == 0 or match_mode == "team2" and owner_id == 2 else 1 if match_mode == "team2" else owner_id)
		civilizations.append(civ if owner_id == 0 else civilization_ids[(civilization_ids.find(opponent_civ) + owner_id - 1) % civilization_ids.size()])
		players.append({"food": 340 if owner_id == 0 else 420, "wood": 360 if owner_id == 0 else 420, "gold": 150 if owner_id == 0 else 170, "stone": 100, "age": 1, "researched": [], "landmarks": [], "dynasty": ""})
	started = true
	game_over = false
	map_seed = requested_seed if requested_seed >= 0 else randi_range(1, 2147483647)
	world_size = selected_map_size
	map_style = selected_map_style
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	world_map.generate(map_seed, world_size, map_style, player_count)
	world_map.show()
	weather.setup(self, map_seed, world_size)
	weather.show()
	build_mode = ""
	pending_landmark_id = ""
	build_page = 0
	order_mode = ""
	ai_timer = 0.0
	camera.position = _scaled_point(Vector2(630, 720))
	menu_panel.hide()
	result_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cursor.show()
	_spawn_map_resources()
	objectives.setup(self)
	_spawn_neutral_sites()
	for owner_id in player_count:
		var base := spawn_point_for(owner_id)
		spawn_building(owner_id, "town_center", base)
		for i in 5:
			var worker := spawn_unit(owner_id, "villager", base + Vector2((i % 3) * 29 - 30, 80 + (i / 3) * 28))
			var resource := find_nearest_resource(worker.position, "food" if i < 2 else "wood" if i < 4 else "gold")
			if resource != null: worker.order_gather(resource)
	navigation.refresh()
	fog.reset()
	ai_controllers.clear()
	for owner_id in range(1, player_count): ai_controllers.append(RtsAiController.new(self, owner_id))
	ai = ai_controllers[0]
	_update_hud()
	_rebuild_actions()
	queue_redraw()

func _clear_world() -> void:
	if world_map != null: world_map.hide()
	if weather != null: weather.hide()
	if fog != null: fog.clear()
	for unit in units: if is_instance_valid(unit): unit.queue_free()
	for building in buildings: if is_instance_valid(building): building.queue_free()
	for resource in resources: if is_instance_valid(resource): resource.queue_free()
	for post in trade_posts: if is_instance_valid(post): post.queue_free()
	for relic in relics: if is_instance_valid(relic): relic.queue_free()
	units.clear()
	buildings.clear()
	resources.clear()
	trade_posts.clear()
	relics.clear()
	if objectives != null: objectives.reset()
	selected.clear()
	hit_lines.clear()

func _scaled_point(point: Vector2) -> Vector2:
	return point * Vector2(world_size.x / WORLD_SIZE.x, world_size.y / WORLD_SIZE.y)

func spawn_point_for(owner_id: int) -> Vector2:
	if players.size() <= 2: return _scaled_point(Vector2(330, 720) if owner_id == 0 else Vector2(2070, 720))
	var positions := [Vector2(330, 420), Vector2(2070, 1080), Vector2(330, 1080), Vector2(2070, 420)]
	return _scaled_point(positions[owner_id])

func is_enemy(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a < teams.size() and b < teams.size() and teams[a] != teams[b]

func player_color(owner_id: int) -> Color:
	if players.size() <= 2: return GameData.CIVILIZATIONS[civilizations[owner_id]]["color"]
	return [Color("4e9bea"), Color("e65852"), Color("4ac59a"), Color("e5ae4b")][owner_id]

func highest_enemy_age(owner_id: int) -> int:
	var age := 1
	for rival in players.size():
		if is_enemy(owner_id, rival): age = maxi(age, int(players[rival]["age"]))
	return age

func nearest_enemy_center(owner_id: int) -> RtsBuilding:
	var home := Vector2.ZERO
	var allies := 0
	for ally_id in players.size():
		if not is_enemy(owner_id, ally_id) and not defeated_players.has(ally_id):
			home += spawn_point_for(ally_id)
			allies += 1
	if allies > 0: home /= allies
	var best: RtsBuilding
	var distance := INF
	for building in buildings:
		if not is_instance_valid(building) or not is_enemy(owner_id, building.owner_id) or building.kind != "town_center": continue
		var candidate := home.distance_squared_to(building.position)
		if candidate < distance:
			best = building
			distance = candidate
	return best

func strategic_target_for(owner_id: int) -> Node2D:
	# An AI first helps a nearby ally whose base is being attacked. Allied AIs
	# then converge on the same enemy center chosen from their team's midpoint.
	var threat: RtsUnit
	var threat_score := INF
	for building in buildings:
		if not is_instance_valid(building) or building.kind != "town_center" or is_enemy(owner_id, building.owner_id): continue
		for unit in units:
			if not is_instance_valid(unit) or not is_enemy(owner_id, unit.owner_id) or not unit.stats.get("tags", []).has("military"): continue
			var distance := building.position.distance_squared_to(unit.position)
			if distance < 340.0 * 340.0 and distance < threat_score and (not fog.active or fog.can_see(owner_id, unit.position)):
				threat = unit
				threat_score = distance
	if threat != null: return threat
	return nearest_enemy_center(owner_id)

func _spawn_neutral_sites() -> void:
	for desired in [_scaled_point(Vector2(1200, 190)), _scaled_point(Vector2(1200, 1310))]:
		var post := RtsTradePost.new()
		post.position = world_map.nearest_walkable_point(desired)
		add_child(post)
		trade_posts.append(post)
	for site in objectives.sacred_sites:
		var relic := RtsRelic.new()
		relic.position = world_map.nearest_walkable_point(site["position"] + Vector2(70, 45))
		relic.game = self
		add_child(relic)
		relics.append(relic)

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
	order_mode = ""
	result_panel.hide()
	top_label.text = ""
	_rebuild_actions()
	_show_menu()
	queue_redraw()

func _spawn_map_resources() -> void:
	for spec in world_map.resource_specs:
		spawn_resource(spec["kind"], spec["position"], spec["amount"], spec["appearance"])

func spawn_resource(kind: String, world_point: Vector2, amount: int, appearance := "") -> RtsResource:
	var resource: RtsResource = RESOURCE_SCENE.new()
	resource.position = world_point
	resource.game = self
	add_child(resource)
	resource.setup(kind, amount, appearance)
	resources.append(resource)
	navigation.invalidate_spatial_index()
	return resource

func spawn_unit(owner_id: int, kind: String, world_point: Vector2, rally := Vector2.INF, rally_target: Node2D = null, rally_resource_kind := "") -> RtsUnit:
	var unit: RtsUnit = UNIT_SCENE.new()
	unit.position = world_map.nearest_water_point(world_point) if GameData.UNITS[kind]["tags"].has("naval") else world_map.nearest_walkable_point(world_point)
	add_child(unit)
	unit.setup(self, owner_id, kind)
	unit.position = navigation.nearest_walkable_point(unit.position, unit.radius(), unit)
	units.append(unit)
	navigation.invalidate_spatial_index()
	if rally != Vector2.INF:
		if kind == "trader" and rally_target is RtsTradePost:
			unit.issue_command("trade", Vector2.INF, rally_target)
		elif kind == "fishing_boat" and rally_target is RtsResource and rally_target.appearance == "fish":
			unit.issue_command("gather", Vector2.INF, rally_target)
		elif kind == "villager" and is_instance_valid(rally_target) and not rally_target.is_queued_for_deletion() and (rally_target is RtsResource or rally_target is RtsBuilding and rally_target.kind == "farm" and rally_target.is_complete()):
			unit.issue_command("gather", Vector2.INF, rally_target)
		elif kind == "villager" and rally_resource_kind != "":
			var replacement := find_nearest_resource(rally, rally_resource_kind, 220.0, owner_id)
			if replacement != null: unit.issue_command("gather", Vector2.INF, replacement)
			else: unit.issue_command("move", rally)
		else: unit.issue_command("move", rally)
	_update_hud()
	return unit

func spawn_building(owner_id: int, kind: String, world_point: Vector2, under_construction := false, landmark_id := "", vertical := false) -> RtsBuilding:
	var building: RtsBuilding = BUILDING_SCENE.new()
	building.position = world_point
	building.wall_vertical = vertical
	add_child(building)
	building.setup(self, owner_id, kind, under_construction, landmark_id)
	buildings.append(building)
	_update_hud()
	return building

func find_spawn_position(building: RtsBuilding) -> Vector2:
	if building.kind == "dock": return world_map.nearest_water_point(building.position)
	var direction := 1 if spawn_point_for(building.owner_id).x < world_size.x * 0.5 else -1
	return building.position + Vector2(direction * (building.size().x * 0.5 + 27), randf_range(-25, 25))

func building_completed(building: RtsBuilding) -> void:
	if building.kind.ends_with("_gate"): navigation.refresh()
	if building.kind == "landmark":
		complete_age(building.owner_id, int(RtsLandmarkCatalog.landmark(building.landmark_id).get("age", 0)), building.landmark_id)
	if building.owner_id == 0: notify_player("%s建造完成" % building.display_label())
	_rebuild_actions()
	_update_hud()

func entity_destroyed(entity: Node2D) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion(): return
	selected.erase(entity)
	if entity is RtsUnit:
		units.erase(entity)
		navigation.invalidate_spatial_index()
	elif entity is RtsBuilding:
		for relic in entity.relics:
			if is_instance_valid(relic):
				relic.stored_in = null
				relic.position = world_map.nearest_walkable_point(entity.position + Vector2(65, 0))
		entity.relics.clear()
		entity.ungarrison_all()
		objectives.on_building_destroyed(entity)
		buildings.erase(entity)
		if entity.landmark_id == "zh_gatehouse":
			for building in buildings:
				if is_instance_valid(building) and building.owner_id == entity.owner_id and building.kind in ["stone_wall", "stone_gate"]: building.refresh_stats()
		if entity.kind == "town_center" or entity.kind == "landmark":
			var has_landmark := false
			for building in buildings:
				if is_instance_valid(building) and building.owner_id == entity.owner_id and building.is_complete() and (building.kind == "town_center" or building.kind == "landmark"):
					has_landmark = true
					break
			if not has_landmark:
				defeated_players.append(entity.owner_id)
				_eliminate_player(entity.owner_id)
				_check_match_end()
	entity.queue_free()
	_rebuild_actions()
	_update_hud()

func _eliminate_player(owner_id: int) -> void:
	for unit in units.duplicate():
		if is_instance_valid(unit) and unit.owner_id == owner_id:
			selected.erase(unit)
			units.erase(unit)
			unit.queue_free()
	for building in buildings.duplicate():
		if is_instance_valid(building) and building.owner_id == owner_id:
			for relic in building.relics:
				if is_instance_valid(relic):
					relic.stored_in = null
					relic.position = world_map.nearest_walkable_point(building.position + Vector2(60, 0))
			building.relics.clear()
			objectives.on_building_destroyed(building)
			selected.erase(building)
			buildings.erase(building)
			building.queue_free()
	navigation.refresh()
	if fog.active: fog.update_visibility()

func _check_match_end() -> void:
	var surviving_teams: Dictionary = {}
	for owner_id in players.size():
		if not defeated_players.has(owner_id): surviving_teams[teams[owner_id]] = true
	if not surviving_teams.has(teams[0]):
		_finish_game(false, "landmarks")
	elif surviving_teams.size() == 1:
		_finish_game(true, "landmarks")

func _finish_game(won: bool, reason := "landmarks") -> void:
	if game_over: return
	game_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cursor.hide()
	for child in result_panel.get_children(): child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	result_panel.add_child(box)
	_add_menu_label(box, "胜利！" if won else "战败", 30)
	var result_reason: String = {"landmarks": "城镇中心与地标全部摧毁", "sacred": "控制全部圣地", "wonder": "奇观守护成功"}.get(reason, reason)
	_add_menu_label(box, result_reason, 17)
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
			cap += building.definition()["pop"]
	return cap

func train_unit(building: RtsBuilding, unit_kind: String) -> bool:
	if game_over or not is_instance_valid(building) or not building.is_complete(): return false
	if not RtsTechTree.can_train(civilizations[building.owner_id], players[building.owner_id]["age"], building.producer_kind(), unit_kind, players[building.owner_id]["researched"], players[building.owner_id].get("dynasty", "")): return false
	if population_used(building.owner_id) >= population_cap(building.owner_id):
		if building.owner_id == 0: notify_player("人口已满，请建造房屋")
		return false
	if not spend(building.owner_id, GameData.unit_cost(unit_kind)):
		if building.owner_id == 0: notify_player("资源不足")
		return false
	building.enqueue(unit_kind)
	if building.owner_id == 0: notify_player("正在训练%s" % GameData.UNITS[unit_kind]["label"])
	_update_hud()
	return true

func queued_research(owner_id: int) -> Array[String]:
	var result: Array[String] = []
	for building in buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id: continue
		for tech_id in building.research_queue:
			if not result.has(tech_id): result.append(tech_id)
	return result

func research_technology(building: RtsBuilding, tech_id: String) -> bool:
	if game_over or not is_instance_valid(building) or not building.is_complete(): return false
	var owner_id: int = building.owner_id
	if not RtsTechTree.can_research(civilizations[owner_id], players[owner_id]["age"], building.producer_kind(), tech_id, players[owner_id]["researched"]): return false
	if queued_research(owner_id).has(tech_id): return false
	var technology: Dictionary = RtsTechTree.get_technology(tech_id)
	var paid_cost: Dictionary = technology["cost"].duplicate(true)
	var discount := RtsLandmarkCatalog.research_discount(building.landmark_id)
	for resource in paid_cost: paid_cost[resource] = ceili(float(paid_cost[resource]) * discount)
	if not spend(owner_id, paid_cost):
		if owner_id == 0: notify_player("研究所需资源不足")
		return false
	building.enqueue_research(tech_id, technology["time"], paid_cost)
	if owner_id == 0: notify_player("正在研究%s" % technology["label"])
	_update_hud()
	return true

func complete_research(owner_id: int, tech_id: String) -> void:
	if players[owner_id]["researched"].has(tech_id): return
	players[owner_id]["researched"].append(tech_id)
	for unit in units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: unit.refresh_stats()
	if owner_id == 0:
		notify_player("%s研究完成" % RtsTechTree.get_technology(tech_id)["label"])
		_rebuild_actions()
	_update_hud()

func is_age_queued(owner_id: int) -> bool:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "landmark" and not building.is_complete(): return true
		if is_instance_valid(building) and building.owner_id == owner_id and building.has_queued_age(): return true
	return false

func active_landmark_id(owner_id: int) -> String:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "landmark" and not building.is_complete(): return building.landmark_id
	return ""

func place_landmark(owner_id: int, landmark_id: String, world_point: Vector2, workers: Array[RtsUnit], append_order := false) -> bool:
	var status := RtsLandmarkCatalog.choice_status(civilizations[owner_id], players[owner_id]["age"], players[owner_id]["landmarks"], landmark_id, active_landmark_id(owner_id))
	if not status["available"]:
		if owner_id == 0: notify_player(status["reason"])
		return false
	var builders: Array[RtsUnit] = []
	for worker in workers:
		if is_instance_valid(worker) and worker.owner_id == owner_id and worker.kind == "villager": builders.append(worker)
	if builders.is_empty(): return false
	if not can_place("landmark", world_point):
		if owner_id == 0: notify_player("这里不能建造地标")
		return false
	var choice := RtsLandmarkCatalog.landmark(landmark_id)
	if not spend(owner_id, choice["cost"]):
		if owner_id == 0: notify_player("地标资源不足")
		return false
	var building := spawn_building(owner_id, "landmark", world_point, true, landmark_id)
	for worker in builders: worker.issue_command("build", Vector2.INF, building, append_order)
	if owner_id == 0: notify_player("正在建造%s" % choice["label"])
	_rebuild_actions()
	return true

func advance_age(owner_id: int, landmark_id := "") -> bool:
	var age: int = players[owner_id]["age"]
	if not RtsTechTree.can_advance(age) or is_age_queued(owner_id): return false
	var center := _player_center(owner_id)
	if center == null or not center.is_complete(): return false
	var choices := RtsLandmarkCatalog.choices_for(civilizations[owner_id], age, players[owner_id]["landmarks"])
	if choices.is_empty(): return false
	if landmark_id.is_empty():
		for choice in choices:
			if choice["age"] == age + 1:
				landmark_id = choice["id"]
				break
	if landmark_id.is_empty(): return false
	return construct_landmark(owner_id, landmark_id)

func construct_landmark(owner_id: int, landmark_id: String) -> bool:
	var age: int = players[owner_id]["age"]
	if not RtsLandmarkCatalog.choice_status(civilizations[owner_id], age, players[owner_id]["landmarks"], landmark_id, active_landmark_id(owner_id))["available"]: return false
	var center := _player_center(owner_id)
	if center == null or not center.is_complete(): return false
	var workers: Array[RtsUnit] = []
	for unit in units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "villager": workers.append(unit)
	workers.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(center.position) < b.position.distance_squared_to(center.position))
	if workers.size() > 2: workers.resize(2)
	var inward := 180.0 if spawn_point_for(owner_id).x < world_size.x * 0.5 else -180.0
	var candidates := [Vector2(0, 180), Vector2(0, -180), Vector2(inward, 0), Vector2(inward, 180), Vector2(inward, -180)]
	for offset in candidates:
		if can_place("landmark", center.position + offset): return place_landmark(owner_id, landmark_id, center.position + offset, workers)
	return false

func complete_age(owner_id: int, target_age: int, landmark_id := "") -> void:
	var current_age: int = players[owner_id]["age"]
	var aged_up := target_age == current_age + 1
	if not aged_up and (landmark_id.is_empty() or civilizations[owner_id] != "Chinese" or target_age > current_age): return
	if landmark_id != "" and players[owner_id]["landmarks"].has(landmark_id): return
	if aged_up: players[owner_id]["age"] = target_age
	if aged_up and civilizations[owner_id] == "French" and target_age >= 2:
		for upgrade_age in range(2, target_age + 1):
			var free_upgrade := "melee_attack_%d" % upgrade_age
			if not players[owner_id]["researched"].has(free_upgrade): players[owner_id]["researched"].append(free_upgrade)
	if landmark_id != "": players[owner_id]["landmarks"].append(landmark_id)
	var previous_dynasty: String = players[owner_id].get("dynasty", "")
	players[owner_id]["dynasty"] = RtsLandmarkCatalog.dynasty_for(players[owner_id]["landmarks"]) if civilizations[owner_id] == "Chinese" else ""
	for unit in units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: unit.refresh_stats()
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id: building.refresh_stats()
	if owner_id == 0:
		if aged_up: notify_player("进入时代 %d！" % target_age)
		if players[owner_id]["dynasty"] != previous_dynasty:
			notify_player("进入%s朝：王朝加成已生效" % RtsLandmarkCatalog.DYNASTY_NAMES[players[owner_id]["dynasty"]])
		_rebuild_actions()
	_update_hud()

func cancel_production_job(building: RtsBuilding, index: int = 0) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or index < 0: return false
	var job := building.cancel_queue_entry(index)
	if job.is_empty(): return false
	for resource in job["cost"]:
		players[building.owner_id][resource] += job["cost"][resource]
	if building.owner_id == 0: notify_player("已取消，资源已返还")
	_update_hud()
	return true

func _cancel_selected_job() -> void:
	if selected.is_empty() or not is_instance_valid(selected[0]) or not selected[0] is RtsBuilding: return
	var building: RtsBuilding = selected[0]
	if building.owner_id == 0: cancel_production_job(building, queue_choice.get_selected_id())

func can_place(kind: String, world_point: Vector2, vertical := false) -> bool:
	var dimensions: Vector2 = GameData.BUILDINGS[kind]["size"]
	if vertical and (kind.ends_with("_wall") or kind.ends_with("_gate")): dimensions = Vector2(dimensions.y, dimensions.x)
	var half: Vector2 = dimensions * 0.5
	if world_point.x < half.x + 20 or world_point.y < half.y + 70: return false
	if world_point.x > world_size.x - half.x - 20 or world_point.y > world_size.y - half.y - 20: return false
	var padding := 0.0 if kind.ends_with("_wall") or kind.ends_with("_gate") else 9.0
	var footprint := Rect2(world_point - half - Vector2.ONE * padding, dimensions + Vector2.ONE * padding * 2.0)
	if world_map != null and not world_map.is_area_buildable(footprint): return false
	if kind == "dock" and not world_map.has_adjacent_water(world_point): return false
	for building in buildings:
		if is_instance_valid(building):
			var other := Rect2(building.position - building.size() * 0.5, building.size())
			if footprint.intersects(other): return false
	for resource in resources:
		if is_instance_valid(resource) and footprint.grow(resource.radius * 0.5).has_point(resource.position): return false
	for post in trade_posts:
		if is_instance_valid(post) and footprint.grow(28).has_point(post.position): return false
	for relic in relics:
		if is_instance_valid(relic) and relic.available() and footprint.grow(18).has_point(relic.position): return false
	return true

func place_building(owner_id: int, kind: String, world_point: Vector2, workers: Array[RtsUnit], append_order := false, vertical := false) -> bool:
	if not RtsTechTree.can_build(civilizations[owner_id], players[owner_id]["age"], kind): return false
	if kind == "wonder":
		for existing in buildings:
			if is_instance_valid(existing) and existing.owner_id == owner_id and existing.kind == "wonder":
				if owner_id == 0: notify_player("已有奇观")
				return false
	var builders: Array[RtsUnit] = []
	for worker in workers:
		if is_instance_valid(worker) and worker.owner_id == owner_id and worker.kind == "villager":
			builders.append(worker)
	if builders.is_empty(): return false
	if not can_place(kind, world_point, vertical):
		if owner_id == 0: notify_player("这里不能建造")
		return false
	if not spend(owner_id, GameData.BUILDINGS[kind]["cost"]):
		if owner_id == 0: notify_player("建造资源不足")
		return false
	var building := spawn_building(owner_id, kind, world_point, true, "", vertical)
	for worker in builders: worker.issue_command("build", Vector2.INF, building, append_order)
	if owner_id == 0: notify_player("%d 名村民正在建造%s" % [builders.size(), GameData.BUILDINGS[kind]["label"]])
	return true

func convert_wall_to_gate(building: RtsBuilding) -> bool:
	if not is_instance_valid(building) or not building.is_complete() or not building.kind.ends_with("_wall"): return false
	var gate_kind := "stone_gate" if building.kind == "stone_wall" else "palisade_gate"
	var resource := "stone" if gate_kind == "stone_gate" else "wood"
	var extra: int = GameData.BUILDINGS[gate_kind]["cost"][resource] - GameData.BUILDINGS[building.kind]["cost"][resource]
	if not spend(building.owner_id, {resource: extra}): return false
	building.kind = gate_kind
	building.refresh_stats()
	navigation.refresh()
	if building.owner_id == 0:
		notify_player("城墙已改建为城门")
		_rebuild_actions()
	return true

func count_builders(building: RtsBuilding) -> int:
	var count := 0
	for unit in units:
		if is_instance_valid(unit) and unit.order == "build" and unit.target == building:
			count += 1
	return count

func find_nearest_resource(world_point: Vector2, kind: String, max_distance := INF, viewer_id := -1, naval := false) -> RtsResource:
	var nearest: RtsResource
	var shortest := max_distance * max_distance
	for resource in resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion() or resource.kind != kind: continue
		if naval != (resource.appearance == "fish"): continue
		if viewer_id >= 0 and fog.active and not fog.can_show_resource(viewer_id, resource): continue
		var distance := world_point.distance_squared_to(resource.position)
		if distance < shortest:
			shortest = distance
			nearest = resource
	return nearest

func find_nearest_owned_building(owner_id: int, kind: String, point: Vector2) -> RtsBuilding:
	var nearest: RtsBuilding
	var best := INF
	for building in buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or building.owner_id != owner_id or building.kind != kind or not building.is_complete(): continue
		var distance := point.distance_squared_to(building.position)
		if distance < best:
			nearest = building
			best = distance
	return nearest

func nearest_enemy(unit: RtsUnit, max_distance: float) -> Node2D:
	var best: Node2D
	var distance_limit := max_distance * max_distance
	for other in units:
		if unit.kind == "battering_ram": break
		if not is_instance_valid(other) or other == unit or not is_enemy(unit.owner_id, other.owner_id) or other.garrisoned_in != null: continue
		if fog.active and not fog.can_see(unit.owner_id, other.position): continue
		var d := unit.position.distance_squared_to(other.position)
		if d < distance_limit:
			distance_limit = d
			best = other
	for building in buildings:
		if not is_instance_valid(building) or not is_enemy(unit.owner_id, building.owner_id): continue
		if fog.active and not fog.can_see(unit.owner_id, building.position): continue
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
		for controller in ai_controllers:
			if not defeated_players.has(controller.owner_id): controller.tick()
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
		_move_camera_screen_delta(direction.normalized() * CAMERA_PAN_SPEED * delta)

func _move_camera_screen_delta(screen_delta: Vector2) -> void:
	var half_view := get_viewport_rect().size * 0.5 / camera.zoom.x
	var min_center := half_view.min(world_size * 0.5)
	camera.position = (camera.position + screen_delta / camera.zoom.x).clamp(min_center, world_size - min_center)

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
	if order_mode == "attack_move": return "attack_move"
	if build_mode != "":
		var cost: Dictionary = RtsLandmarkCatalog.landmark(pending_landmark_id).get("cost", {}) if build_mode == "landmark" else GameData.BUILDINGS[build_mode]["cost"]
		return "build_valid" if can_place(build_mode, world_point, wall_vertical) and can_afford(0, cost) else "build_invalid"
	if dragging and drag_start.distance_to(world_point) > 12.0: return "drag"
	var entity := _entity_at(world_point)
	var resource := _resource_at(world_point)
	var post := _trade_post_at(world_point)
	var relic := _relic_at(world_point)
	var has_unit := false
	var has_worker := false
	var has_producer := false
	for subject in selected:
		if not is_instance_valid(subject): continue
		if subject is RtsUnit:
			has_unit = true
			if subject.kind == "villager": has_worker = true
		elif subject is RtsBuilding and subject.is_complete() and RtsTechTree.PRODUCTION.has(subject.kind):
			has_producer = true
	if entity != null and is_enemy(0, entity.owner_id) and has_unit: return "attack"
	if has_worker and entity is RtsBuilding and entity.owner_id == 0 and not entity.is_complete(): return "construct"
	if has_worker and (resource != null and resource.appearance != "fish" or entity is RtsBuilding and entity.kind == "farm"): return "gather"
	if resource != null and resource.appearance == "fish" and not selected.is_empty() and selected[0] is RtsUnit and selected[0].kind == "fishing_boat": return "gather"
	if post != null and not selected.is_empty() and selected[0] is RtsUnit and selected[0].kind == "trader": return "trade"
	if relic != null and not selected.is_empty() and selected[0] is RtsUnit and selected[0].kind == "monk": return "relic"
	if entity != null and entity.owner_id == 0: return "select"
	if has_unit: return "move"
	if has_producer: return "rally"
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and (build_mode.ends_with("_wall") or build_mode.ends_with("_gate")):
		wall_vertical = not wall_vertical
		queue_redraw()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not started or game_over or paused: return
	if event is InputEventPanGesture:
		_move_camera_screen_delta(event.delta * GESTURE_PAN_PIXELS)
		get_viewport().set_input_as_handled()
		return
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
				if order_mode == "attack_move":
					_issue_attack_move(get_global_mouse_position(), event.shift_pressed)
					return
				if build_mode != "":
					if build_mode.ends_with("_wall"):
						wall_dragging = true
						wall_start = get_global_mouse_position()
						wall_end = wall_start
					else:
						_confirm_build(get_global_mouse_position(), event.shift_pressed)
					return
				if event.double_click:
					var clicked := _entity_at(get_viewport().get_canvas_transform().affine_inverse() * event.position)
					if clicked is RtsUnit and clicked.owner_id == 0:
						_select_same_type_visible(clicked, event.shift_pressed)
						return
				dragging = true
				drag_start = get_global_mouse_position()
				drag_current = drag_start
			else:
				if wall_dragging:
					wall_dragging = false
					_confirm_wall_line(wall_start, get_global_mouse_position(), event.shift_pressed)
					return
				if dragging:
					dragging = false
					_select_area(drag_start, get_global_mouse_position(), event.shift_pressed)
					queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if order_mode != "":
				order_mode = ""
				notify_player("已取消命令")
				return
			if build_mode != "":
				build_mode = ""
				wall_dragging = false
				pending_landmark_id = ""
				notify_player("已取消建造")
				return
			_issue_order(get_global_mouse_position(), event.shift_pressed)
			return
	if event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()
		queue_redraw()
	if event is InputEventMouseMotion and wall_dragging:
		wall_end = get_global_mouse_position()
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if hotkey_buttons.has(event.keycode):
			var button: RtsCommandButton = hotkey_buttons[event.keycode]
			if is_instance_valid(button) and not button.disabled:
				button.pressed.emit()
				get_viewport().set_input_as_handled()
			return
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
			if is_instance_valid(unit) and unit.garrisoned_in == null and unit.owner_id == 0 and area.has_point(unit.position) and not selected.has(unit):
				selected.append(unit)
	_rebuild_actions()
	_update_hud()
	queue_redraw()

func _select_same_type_visible(clicked: RtsUnit, additive: bool) -> void:
	if not additive: selected.clear()
	var screen_to_world := get_viewport().get_canvas_transform().affine_inverse()
	var visible_area := Rect2(screen_to_world * Vector2.ZERO, screen_to_world * get_viewport_rect().size).abs()
	for unit in units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		if unit.owner_id == clicked.owner_id and unit.kind == clicked.kind and visible_area.has_point(unit.position) and not selected.has(unit):
			selected.append(unit)
	_rebuild_actions()
	_update_hud()
	queue_redraw()

func _entity_at(point: Vector2) -> Node2D:
	for unit in units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		if unit.owner_id != 0 and fog.active and not fog.can_see(0, unit.position): continue
		if is_instance_valid(unit) and unit.position.distance_to(point) <= unit.radius() + 5: return unit
	for building in buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if building.owner_id != 0 and fog.active and not fog.can_see(0, building.position): continue
		if is_instance_valid(building) and building.contains(point): return building
	return null

func _resource_at(point: Vector2) -> RtsResource:
	for resource in resources:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion() and (not fog.active or fog.can_show_resource(0, resource)) and resource.position.distance_to(point) < resource.radius + 6:
			return resource
	return null

func _trade_post_at(point: Vector2) -> RtsTradePost:
	for post in trade_posts:
		if is_instance_valid(post) and (not fog.active or fog.is_explored(0, post.position)) and post.contains(point): return post
	return null

func _relic_at(point: Vector2) -> RtsRelic:
	for relic in relics:
		if is_instance_valid(relic) and relic.available() and (not fog.active or fog.can_see(0, relic.position)) and relic.position.distance_to(point) <= 20.0: return relic
	return null

func _issue_order(point: Vector2, append_order := false) -> void:
	var entity := _entity_at(point)
	var resource := _resource_at(point)
	var post := _trade_post_at(point)
	var relic := _relic_at(point)
	var has_selected_unit := false
	for subject in selected:
		if is_instance_valid(subject) and subject is RtsUnit:
			has_selected_unit = true
			break
	if not has_selected_unit:
		var assigned := false
		for subject in selected:
			if not is_instance_valid(subject) or not subject is RtsBuilding: continue
			if subject.owner_id != 0 or not subject.is_complete() or not RtsTechTree.PRODUCTION.has(subject.kind): continue
			var rally_target: Node2D = resource if resource != null else post if post != null else entity if entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "farm" else null
			subject.set_rally(point.clamp(Vector2(24, 24), world_size - Vector2(24, 24)), rally_target)
			assigned = true
		if assigned:
			notify_player("资源集结点已设置；新村民自动采集" if resource != null or entity is RtsBuilding and entity.kind == "farm" else "集结点已设置")
			queue_redraw()
		return
	var movers: Array[RtsUnit] = []
	for subject in selected:
		if not is_instance_valid(subject) or not subject is RtsUnit: continue
		if post != null and subject.kind == "trader":
			subject.issue_command("trade", Vector2.INF, post, append_order)
		elif relic != null and subject.kind == "monk":
			subject.issue_command("relic", Vector2.INF, relic, append_order)
		elif entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "monastery" and subject.kind == "monk" and subject.carried_relic != null:
			subject.issue_command("deposit_relic", Vector2.INF, entity, append_order)
		elif entity != null and is_enemy(0, entity.owner_id):
			subject.issue_command("attack", Vector2.INF, entity, append_order)
		elif entity is RtsBuilding and entity.owner_id == 0 and not entity.is_complete() and subject.kind == "villager":
			subject.issue_command("build", Vector2.INF, entity, append_order)
		elif resource != null and (subject.kind == "villager" and resource.appearance != "fish" or subject.kind == "fishing_boat" and resource.appearance == "fish"):
			subject.issue_command("gather", Vector2.INF, resource, append_order)
		elif entity is RtsBuilding and entity.owner_id == 0 and entity.kind == "farm" and subject.kind == "villager":
			subject.issue_command("gather", Vector2.INF, entity, append_order)
		elif entity is RtsBuilding and entity.owner_id == 0 and entity.is_complete() and (RtsSiegeRules.can_garrison(subject.stats, entity.kind) or entity.kind == "landmark" and entity.garrison_capacity() > 0 and not subject.stats.get("tags", []).has("siege")):
			subject.issue_command("garrison", Vector2.INF, entity, append_order)
		else:
			movers.append(subject)
	issue_group_order(movers, point, false, append_order)

func _issue_attack_move(point: Vector2, append_order := false) -> void:
	if not append_order: order_mode = ""
	var movers: Array[RtsUnit] = []
	for subject in selected:
		if not is_instance_valid(subject) or not subject is RtsUnit or not subject.stats.get("tags", []).has("military"): continue
		movers.append(subject)
	issue_group_order(movers, point, true, append_order)
	queue_redraw()

func issue_group_order(movers: Array[RtsUnit], point: Vector2, attack_move := false, append_order := false) -> void:
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
	var columns := mini(3, maxi(1, ceili(sqrt(float(squads.size())))))
	var rows := ceili(float(squads.size()) / columns)
	for index in squads.size():
		var squad: Array[RtsUnit] = squads[index]
		var group_point := point
		if squads.size() > 1:
			var row := index / columns
			var col := index % columns
			group_point += heading * (float(rows - 1) * 0.5 - float(row)) * 200.0 + lateral * (float(col) - float(columns - 1) * 0.5) * 200.0
		var group := RtsMovementGroup.new(self, squad, group_point)
		for unit in squad:
			unit.issue_command("group_attack_move" if attack_move else "group_move", group_point, null, append_order, group)

func _stop_selected_units() -> void:
	order_mode = ""
	for subject in selected:
		if is_instance_valid(subject) and subject is RtsUnit: subject.order_stop()
	notify_player("单位已停止")

func _confirm_build(point: Vector2, append_order := false) -> void:
	var builders: Array[RtsUnit] = []
	for entity in selected:
		if is_instance_valid(entity) and entity is RtsUnit and entity.owner_id == 0 and entity.kind == "villager":
			builders.append(entity)
	if builders.is_empty():
		for unit in units:
			if is_instance_valid(unit) and unit.owner_id == 0 and unit.kind == "villager": builders.append(unit)
		builders.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
		if builders.size() > 2: builders.resize(2)
	if builders.is_empty():
		notify_player("需要村民建造")
		return
	var success := place_landmark(0, pending_landmark_id, point, builders, append_order) if build_mode == "landmark" else place_building(0, build_mode, point, builders, append_order, wall_vertical)
	if success and (not append_order or build_mode == "landmark"):
		build_mode = ""
		pending_landmark_id = ""
		_rebuild_actions()
	queue_redraw()

func _wall_positions(from: Vector2, to: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var delta := to - from
	var vertical := absf(delta.y) > absf(delta.x) if delta.length() > 20.0 else wall_vertical
	var length := absf(delta.y) if vertical else absf(delta.x)
	var count := clampi(roundi(length / 68.0) + 1, 1, 24)
	var sign_value := signf(delta.y if vertical else delta.x)
	if is_zero_approx(sign_value): sign_value = 1.0
	for index in count:
		positions.append(from + (Vector2.DOWN if vertical else Vector2.RIGHT) * sign_value * index * 68.0)
	return positions

func _confirm_wall_line(from: Vector2, to: Vector2, append_order := false) -> void:
	var vertical := absf(to.y - from.y) > absf(to.x - from.x) if from.distance_to(to) > 20.0 else wall_vertical
	var positions := _wall_positions(from, to)
	var builders: Array[RtsUnit] = []
	for entity in selected:
		if entity is RtsUnit and entity.owner_id == 0 and entity.kind == "villager": builders.append(entity)
	if builders.is_empty():
		notify_player("需要村民建墙")
		return
	var cost: Dictionary = GameData.BUILDINGS[build_mode]["cost"]
	for resource in cost:
		if players[0][resource] < cost[resource] * positions.size():
			notify_player("整段城墙所需资源不足")
			return
	for point in positions:
		if not can_place(build_mode, point, vertical):
			notify_player("城墙经过不可建造的位置")
			return
	for index in positions.size():
		place_building(0, build_mode, positions[index], builders, append_order or index > 0, vertical)
	if not append_order:
		build_mode = ""
		_rebuild_actions()
	queue_redraw()

func _update_hud() -> void:
	if top_label == null or players.is_empty(): return
	var bank := players[0]
	var dynasty_text := " · %s朝" % RtsLandmarkCatalog.DYNASTY_NAMES[bank["dynasty"]] if bank["dynasty"] != "" else ""
	top_label.text = "%s · 时代 %d%s     食物 %d    木材 %d    黄金 %d    石料 %d     人口 %d/%d     %s     地图 %d" % [
		GameData.CIVILIZATIONS[civilizations[0]]["label"], bank["age"], dynasty_text, bank["food"], bank["wood"], bank["gold"], bank["stone"], population_used(0), population_cap(0), objectives.status_text(0), map_seed]
	_refresh_action_buttons()
	selection_health.hide()
	selection_progress.hide()
	queue_label.text = ""
	queue_controls.hide()
	if selected.is_empty() or not is_instance_valid(selected[0]):
		selection_icon.text = "◆"
		selection_icon.add_theme_color_override("font_color", Color("9da9a2"))
		info_label.text = "未选择"
		detail_label.text = "左键选择 · 双击同型单位 · 右键下令 · Esc 暂停"
		return
	var item := selected[0]
	selection_icon.text = "⌂" if item is RtsBuilding else "◆"
	selection_icon.add_theme_color_override("font_color", GameData.CIVILIZATIONS[civilizations[0]]["color"].lightened(0.35))
	if selected.size() > 1:
		info_label.text = "已选中 %d 个单位" % selected.size()
		var counts: Dictionary = {}
		for entity in selected:
			if not is_instance_valid(entity): continue
			var label_text: String = GameData.UNITS[entity.kind]["label"] if entity is RtsUnit else entity.display_label()
			counts[label_text] = counts.get(label_text, 0) + 1
		var parts: Array[String] = []
		for label_text in counts: parts.append("%s ×%d" % [label_text, counts[label_text]])
		detail_label.text = "  ".join(parts)
		return
	var name: String = GameData.UNITS[item.kind]["label"] if item is RtsUnit else item.display_label()
	info_label.text = name
	selection_health.max_value = item.max_hp
	selection_health.value = maxf(0.0, item.hp)
	selection_health.show()
	if item is RtsUnit:
		var stats: Dictionary = item.stats
		var armor: Dictionary = stats.get("armor", {})
		var profile: Dictionary = stats.get("profiles", {}).get(stats.get("primary_profile", ""), {})
		detail_label.text = "生命 %.0f/%.0f   攻击 %d×%.0f/%.2f秒   近甲 %.0f   远甲 %.0f   射程 %.0f   移速 %.0f" % [item.hp, item.max_hp, int(profile.get("hits", 1)), float(profile.get("damage", 0.0)), float(profile.get("cooldown", 1.0)), armor.get("melee", 0.0), armor.get("ranged", 0.0), stats["range"], item.effective_speed()]
		if int(stats.get("rank_age", 0)) > 0: detail_label.text += "   等级%d" % int(stats["rank_age"])
		for bonus in profile.get("bonuses", []):
			detail_label.text += "   %s +%.0f" % [bonus.get("source_label", "加成"), float(bonus.get("amount", 0.0))]
		if item.kind == "trader": detail_label.text += "   右键贸易站往返交易"
		if item.kind == "monk": detail_label.text += "   携带圣物" if item.carried_relic != null else "   可占圣地、拾取圣物"
		if item.kind == "fishing_boat": detail_label.text += "   右键鱼群捕鱼"
	else:
		detail_label.text = "生命 %.0f/%.0f   %s" % [item.hp, item.max_hp, "建造中" if not item.is_complete() else "已建成"]
		if item.kind == "monastery": detail_label.text += "   圣物 %d（每 4 秒每件 +12 黄金）" % item.relics.size()
		if not item.garrisoned_units.is_empty(): detail_label.text += "   驻军 %d/%d" % [item.garrisoned_units.size(), item.garrison_capacity()]
		if item.is_complete() and RtsTechTree.PRODUCTION.has(item.producer_kind()):
			detail_label.text += "   右键设置集结点"
		if not item.is_complete():
			selection_progress.max_value = maxf(0.1, item.build_total)
			selection_progress.value = item.build_total - item.build_remaining
			selection_progress.show()
			queue_label.text = "施工 %d%% · 村民 %d · 选村民右键继续" % [int(100.0 * selection_progress.value / selection_progress.max_value), count_builders(item)]
		elif not item.production_queue.is_empty():
			var job: Dictionary = item.current_job()
			selection_progress.max_value = job["time"]
			selection_progress.value = job["time"] - job["remaining"]
			selection_progress.show()
			queue_label.text = "%s   队列 %d" % [_job_label(job), item.production_queue.size()]
		_refresh_queue_controls(item)

func _job_label(job: Dictionary) -> String:
	match job["type"]:
		"train": return "训练：%s" % GameData.UNITS[job["kind"]]["label"]
		"research": return "研究：%s" % RtsTechTree.get_technology(job["kind"])["label"]
		"age": return "升级到时代 %d" % job["target_age"]
	return "未知任务"

func _refresh_queue_controls(building: RtsBuilding) -> void:
	if building.owner_id != 0 or building.production_queue.is_empty(): return
	queue_controls.show()
	var previous := queue_choice.get_selected_id()
	var needs_rebuild := queue_choice.item_count != building.production_queue.size()
	if not needs_rebuild:
		for index in building.production_queue.size():
			if queue_choice.get_item_text(index) != "%d. %s" % [index + 1, _job_label(building.production_queue[index])]:
				needs_rebuild = true
				break
	if not needs_rebuild: return
	queue_choice.clear()
	for index in building.production_queue.size():
		queue_choice.add_item("%d. %s" % [index + 1, _job_label(building.production_queue[index])], index)
	queue_choice.select(clampi(previous, 0, building.production_queue.size() - 1))

func _refresh_action_buttons() -> void:
	if players.is_empty(): return
	var producer := ""
	var complete := true
	var landmark_id := ""
	var landmark_cooldown := 0.0
	var landmark_stockpile := {}
	var ability_ready := {"palings": false, "volley": false, "pavise": false, "helmsman": false, "convert": false, "camp": false}
	var ability_reason := {"convert": "需要携带圣物"}
	var camp_count := 0
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == 0 and building.kind == "scout_camp": camp_count += 1
	for selection in selected:
		if not is_instance_valid(selection) or not selection is RtsUnit: continue
		if selection.kind == "longbow":
			if selection.paling_cooldown <= 0.0: ability_ready["palings"] = true
			if selection.volley_cooldown <= 0.0: ability_ready["volley"] = true
		if selection.kind == "arbaletrier": ability_ready["pavise"] = true
		if selection.kind == "warship" and selection.helm_cooldown <= 0.0: ability_ready["helmsman"] = true
		if selection.kind == "monk":
			if selection.carried_relic != null and selection.conversion_cooldown <= 0.0: ability_ready["convert"] = true
			elif selection.carried_relic != null: ability_reason["convert"] = "技能冷却中"
		if civilizations[0] == "English" and selection.kind in ["scout", "man_at_arms"] and camp_count < 5: ability_ready["camp"] = true
	if not selected.is_empty() and is_instance_valid(selected[0]) and selected[0] is RtsBuilding:
		producer = selected[0].producer_kind()
		complete = selected[0].is_complete()
		landmark_id = selected[0].landmark_id
		landmark_cooldown = selected[0].landmark_ability_cooldown
		landmark_stockpile = selected[0].landmark_stockpile
	var context := {
		"civilization": civilizations[0], "age": players[0]["age"], "dynasty": players[0].get("dynasty", ""), "producer": producer,
		"researched": players[0]["researched"], "queued_research": queued_research(0),
		"landmarks": players[0]["landmarks"], "active_landmark": active_landmark_id(0),
		"has_wonder": _has_wonder(0),
		"resources": players[0], "population_used": population_used(0), "population_cap": population_cap(0),
		"production_complete": complete,
		"landmark_id": landmark_id, "landmark_cooldown": landmark_cooldown, "landmark_stockpile": landmark_stockpile,
		"ability_ready": ability_ready, "ability_reason": ability_reason, "camp_count": camp_count,
	}
	for button in command_buttons:
		if not is_instance_valid(button) or button.is_queued_for_deletion(): continue
		var status := RtsActionAvailability.evaluate(button.get_meta("action_type"), button.get_meta("action_kind"), context)
		button.set_availability(status["available"], status["reason"], status["cost"])

func _has_wonder(owner_id: int) -> bool:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "wonder": return true
	return false

func _rebuild_actions() -> void:
	if action_bar == null: return
	for child in action_bar.get_children(): child.queue_free()
	command_buttons.clear()
	hotkey_buttons.clear()
	command_title.text = "命令"
	if selected.is_empty() or not is_instance_valid(selected[0]): return
	var item := selected[0]
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	var action_index := 0
	if item is RtsUnit:
		var any_worker := false
		var any_military := false
		var any_special := false
		for unit in selected:
			if not is_instance_valid(unit) or not unit is RtsUnit: continue
			if unit.kind == "villager": any_worker = true
			if unit.stats.get("tags", []).has("military"): any_military = true
			if unit.kind == "monk": any_special = true
		if any_worker:
			var pages := [
				{"title": "经济", "kinds": ["house", "farm"]},
				{"title": "军营", "kinds": ["barracks", "archery_range", "stable", "siege_workshop", "blacksmith"]},
				{"title": "防御", "kinds": ["outpost", "palisade_wall", "stone_wall", "keep"]},
				{"title": "地标与奇观", "kinds": ["wonder"]},
			]
			if civilizations[0] == "Chinese": pages.append({"title": "王朝地标", "kinds": []})
			pages.append({"title": "港口与贸易", "kinds": ["market", "dock", "monastery", "palisade_gate", "stone_gate"]})
			build_page = posmod(build_page, pages.size())
			var page: Dictionary = pages[build_page]
			command_title.text = "村民 · %s (%d/%d)" % [page["title"], build_page + 1, pages.size()]
			for kind in page["kinds"]:
				_add_build_action(kind, keys[action_index])
				action_index += 1
			if build_page == 3:
				for choice in RtsLandmarkCatalog.choices_for(civilizations[0], players[0]["age"], players[0]["landmarks"]):
					if int(choice["age"]) != players[0]["age"] + 1: continue
					_add_landmark_action(choice, keys[action_index])
					action_index += 1
			if civilizations[0] == "Chinese" and build_page == 4:
				for choice in RtsLandmarkCatalog.choices_for(civilizations[0], players[0]["age"], players[0]["landmarks"]):
					if int(choice["age"]) > players[0]["age"]: continue
					_add_landmark_action(choice, keys[action_index])
					action_index += 1
			_add_action("next_page", "下一页", {}, KEY_9 if page["kinds"].size() >= 5 else KEY_5, "order", func() -> void:
				build_page = (build_page + 1) % pages.size()
				_rebuild_actions()
			)
		if (any_military or any_special) and not any_worker:
			command_title.text = "部队 · 命令"
			if any_military:
				_add_action("attack_move", "攻击移动", {}, KEY_1, "order", func() -> void:
					order_mode = "attack_move"
					build_mode = ""
					notify_player("点击地图攻击移动；Shift 点击连续下令")
				)
			for ability_id in ["palings", "volley", "pavise", "helmsman", "convert", "camp"]:
				var unit_kind := "arbaletrier" if ability_id == "pavise" else "warship" if ability_id == "helmsman" else "monk" if ability_id == "convert" else "longbow"
				var has_ability := false
				for unit in selected:
					if is_instance_valid(unit) and unit is RtsUnit and (ability_id != "camp" and unit.kind == unit_kind or ability_id == "camp" and civilizations[0] == "English" and unit.kind in ["scout", "man_at_arms"]): has_ability = true
				if has_ability:
					var ability_label := "部署大盾" if ability_id == "pavise" else "万箭齐发" if ability_id == "volley" else "掌舵人" if ability_id == "helmsman" else "招降" if ability_id == "convert" else "预备营地" if ability_id == "camp" else "架设拒马"
					_add_action(ability_id, ability_label, {}, KEY_NONE, "unit_ability", func() -> void: _activate_selected_ability(ability_id))
		_add_action("stop", "停止", {}, KEY_6 if any_worker else KEY_2, "order", func() -> void: _stop_selected_units())
	elif item is RtsBuilding:
		command_title.text = "%s · 训练与研究" % item.display_label()
		if item.kind.ends_with("_wall"):
			var gate_kind := "stone_gate" if item.kind == "stone_wall" else "palisade_gate"
			var resource := "stone" if gate_kind == "stone_gate" else "wood"
			var extra: int = GameData.BUILDINGS[gate_kind]["cost"][resource] - GameData.BUILDINGS[item.kind]["cost"][resource]
			_add_action(gate_kind, "改建城门", {resource: extra}, KEY_1, "convert_gate", func() -> void: convert_wall_to_gate(item))
			action_index += 1
		for kind in RtsTechTree.all_train_units(civilizations[0], item.producer_kind()):
			var cost: Dictionary = GameData.unit_cost(kind)
			_add_action(kind, GameData.UNITS[kind]["label"], cost, keys[action_index] if action_index < keys.size() else KEY_NONE, "train", func() -> void: train_unit(item, kind))
			action_index += 1
		for kind in RtsTechTree.all_researches(civilizations[0], item.producer_kind()):
			var technology: Dictionary = RtsTechTree.get_technology(kind)
			_add_action(kind, technology["label"], technology["cost"], keys[action_index] if action_index < keys.size() else KEY_NONE, "research", func() -> void: research_technology(item, kind))
			action_index += 1
		if item.kind == "town_center":
			var age: int = players[0]["age"]
			for choice in RtsLandmarkCatalog.choices_for(civilizations[0], age, players[0]["landmarks"]):
				if int(choice["age"]) != age + 1: continue
				_add_landmark_action(choice, keys[action_index] if action_index < keys.size() else KEY_NONE)
				action_index += 1
		if item.garrison_capacity() > 0:
			_add_action("ungarrison", "放出驻军", {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "order", func() -> void: item.ungarrison_all())
			action_index += 1
		if item.landmark_id == "fr_guild_hall":
			_add_action("collect_stockpile", "提取公会资源", {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "landmark_ability", func() -> void: item.collect_stockpile())
			action_index += 1
		if item.landmark_id == "zh_imperial_palace":
			_add_action("spy", "侦察敌方村民", {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "landmark_ability", func() -> void: item.activate_landmark_ability())
	_refresh_action_buttons()

func _activate_selected_ability(ability_id: String) -> void:
	for selection in selected:
		if is_instance_valid(selection) and selection is RtsUnit: selection.activate_ability(ability_id)
	_refresh_action_buttons()

func _add_build_action(kind: String, keycode: int) -> void:
	var cost: Dictionary = GameData.BUILDINGS[kind]["cost"]
	_add_action(kind, GameData.BUILDINGS[kind]["label"], cost, keycode, "build", func() -> void:
		build_mode = kind
		pending_landmark_id = ""
		notify_player("拖拽铺设%s；R 旋转；Shift 连续建造" % GameData.BUILDINGS[kind]["label"] if kind.ends_with("_wall") else "点击地图放置%s；R 旋转墙门；Shift 连续建造" % GameData.BUILDINGS[kind]["label"])
	)

func _add_landmark_action(choice: Dictionary, keycode: int) -> void:
	var choice_id: String = choice["id"]
	_add_action(choice_id, choice["label"], choice["cost"], keycode, "landmark", func() -> void:
		build_mode = "landmark"
		pending_landmark_id = choice_id
		notify_player("%s：%s。点击地图放置" % [choice["label"], choice["description"]])
	)

func _add_action(icon_kind: String, label_text: String, cost: Dictionary, keycode: int, action_type: String, callback: Callable) -> void:
	var button := RtsCommandButton.new()
	var key_text := OS.get_keycode_string(keycode) if keycode != KEY_NONE else ""
	button.configure(icon_kind, label_text, key_text, command_buttons.size())
	if action_type == "train" and GameData.UNITS.has(icon_kind):
		var source_landmark: String = selected[0].landmark_id if not selected.is_empty() and selected[0] is RtsBuilding else ""
		var unit_stats := RtsUnitCatalog.unit_definition(civilizations[0], icon_kind, players[0]["researched"], players[0]["age"], players[0]["landmarks"], players[0].get("dynasty", ""), source_landmark)
		var profile: Dictionary = unit_stats.get("profiles", {}).get(unit_stats.get("primary_profile", ""), {})
		var train_seconds: float = selected[0]._training_time(icon_kind) if not selected.is_empty() and selected[0] is RtsBuilding else GameData.training_time(civilizations[0], "", icon_kind)
		button.set_description("生命 %.0f · 攻击 %d×%.0f · 训练 %.1f 秒" % [float(unit_stats.get("hp", 0.0)), int(profile.get("hits", 1)), float(profile.get("damage", 0.0)), train_seconds])
	elif action_type == "research":
		button.set_description("研究 %.1f 秒" % float(RtsTechTree.get_technology(icon_kind).get("time", 0.0)))
	button.set_meta("cost", cost)
	button.set_meta("action_type", action_type)
	button.set_meta("action_kind", icon_kind)
	button.pressed.connect(callback)
	action_bar.add_child(button)
	command_buttons.append(button)
	if keycode != KEY_NONE: hotkey_buttons[keycode] = button

func _draw() -> void:
	if not started:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("638b5c"))
	for entity in selected:
		if not is_instance_valid(entity): continue
		if entity is RtsUnit:
			draw_arc(entity.position, entity.radius() + 6, 0, TAU, 32, Color("f5e597"), 2)
		elif entity is RtsBuilding:
			draw_rect(Rect2(entity.position - entity.size() * 0.5 - Vector2(5, 5), entity.size() + Vector2(10, 10)), Color("f5e597"), false, 2)
			if entity.owner_id == 0 and entity.is_complete() and RtsTechTree.PRODUCTION.has(entity.kind):
				var marker: Vector2 = entity.rally_point
				var marker_color := Color("f5e597")
				draw_line(entity.position, marker, Color(marker_color, 0.65), 2)
				draw_arc(marker, 9, 0, TAU, 24, marker_color, 2)
				draw_line(marker + Vector2(0, 12), marker + Vector2(0, -14), marker_color, 2)
				draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -14), marker + Vector2(15, -9), marker + Vector2(0, -4)]), marker_color)
	if dragging:
		draw_rect(Rect2(drag_start, drag_current - drag_start).abs(), Color("f5e597"), false, 2)
	if build_mode != "":
		var mouse := get_global_mouse_position()
		var vertical := wall_vertical
		var preview_positions: Array[Vector2] = [mouse]
		if wall_dragging:
			preview_positions = _wall_positions(wall_start, wall_end)
			vertical = absf(wall_end.y - wall_start.y) > absf(wall_end.x - wall_start.x) if wall_start.distance_to(wall_end) > 20.0 else wall_vertical
		for preview in preview_positions:
			var valid := can_place(build_mode, preview, vertical)
			var dimensions: Vector2 = GameData.BUILDINGS[build_mode]["size"]
			if vertical and (build_mode.ends_with("_wall") or build_mode.ends_with("_gate")): dimensions = Vector2(dimensions.y, dimensions.x)
			draw_rect(Rect2(preview - dimensions * 0.5, dimensions), Color(0.25, 0.9, 0.4, 0.35) if valid else Color(0.9, 0.2, 0.2, 0.35))
	for line in hit_lines:
		if fog.active and line["owner"] != 0 and not fog.can_see(0, line["to"]): continue
		var color: Color = player_color(line["owner"]).lightened(0.45)
		draw_line(line["from"], line["to"], color, 3)
