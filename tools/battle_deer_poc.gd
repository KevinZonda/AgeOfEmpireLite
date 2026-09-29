extends SceneTree

class DemoGame extends "res://scripts/game.gd":
	func _load_settings() -> void:
		pass

var game: Node2D
var deer_frozen := false
var caption: Label
var deer_button: Button

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(4242)
	game = DemoGame.new()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.edge_scroll_enabled = false
	game.show_fps = true
	game.fps_label.show()
	var center: Vector2 = game.world_size * 0.5
	var fort: RtsBuilding = game.spawn_building(0, "town_center", center)
	fort.max_hp = 1000000.0
	fort.hp = fort.max_hp
	for i in 80:
		var offset := Vector2.from_angle(TAU * (i % 16) / 16.0) * (180.0 + (i / 16) * 27.0)
		var unit: RtsUnit = game.spawn_unit(1, "spearman", center + offset)
		unit.max_hp = 10000.0
		unit.hp = unit.max_hp
		unit.order_attack(fort)
	for i in 8:
		var point: Vector2 = game.world_map.nearest_walkable_point(center + Vector2(220 + (i % 4) * 28, -145 + (i / 4) * 32))
		game.spawn_resource("food", point, 160, "deer")
	if not game.view_mode_25d: game._toggle_view_mode()
	game.camera.position = center + Vector2(30, -20)
	game.camera.zoom = Vector2.ONE * 0.95
	game.camera.force_update_scroll()
	game.fog.active = false
	game.fog.hide()
	for resource in game.resources: resource.show()
	for unit in game.units: unit.show()
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 90)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	caption = Label.new()
	caption.text = "围攻与鹿群 PoC  |  80 名长矛兵  |  旁边鹿群正常活动"
	caption.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-Regular.otf"))
	caption.add_theme_font_size_override("font_size", 18)
	row.add_child(caption)
	deer_button = Button.new()
	deer_button.text = "冻结鹿群（全地图）"
	deer_button.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC-Regular.otf"))
	deer_button.pressed.connect(_toggle_deer)
	row.add_child(deer_button)
	root.title = "实际战斗 PoC：80 人围攻 + 鹿群"
	print("LIVE_BATTLE_DEER_READY attackers=80 extra_deer=8 fog=false health_extended=true")

func _toggle_deer() -> void:
	deer_frozen = not deer_frozen
	for resource in game.resources:
		if resource.appearance == "deer": resource.set_process(not deer_frozen)
	deer_button.text = "恢复鹿群活动" if deer_frozen else "冻结鹿群（全地图）"
	caption.text = "围攻与鹿群 PoC  |  80 名长矛兵  |  鹿群已冻结" if deer_frozen else "围攻与鹿群 PoC  |  80 名长矛兵  |  旁边鹿群正常活动"
