extends SceneTree

# All production figures, without match simulation. Space changes projection;
# Up/Down changes the roster and Left/Right rotates action headings.
const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const GROUPS = [
	["villager", "spearman", "archer", "longbow"],
	["scout", "horseman", "knight", "royal_knight", "fire_lancer"],
	["man_at_arms", "palace_guard", "monk", "trader", "imperial_official"],
	["crossbowman", "arbaletrier", "zhuge_nu", "handcannoneer", "grenadier"],
]
const COLUMNS = ["IDLE / FRONT", "WALK / SIDE", "WALK / BACK", "PREPARE", "IMPACT / CAST", "RECOVER"]

class Actor extends Node2D:
	var state
	var renderer = Visual.new()
	func _draw() -> void: renderer.draw(self, state)

var actors: Array[Actor] = []
var labels: Array[Label] = []
var camera: Camera2D
var title: Label
var group := clampi(int(OS.get_environment("RTS_CHARACTER_GROUP")), 0, 3)
var heading := int(OS.get_environment("RTS_CHARACTER_HEADING"))
var isometric := OS.get_environment("RTS_CHARACTER_PROJECTION") != "2d"
var capture_path := OS.get_environment("RTS_CHARACTER_CAPTURE")
var elapsed := 0.0
var captured := false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1560, 1000)
	root.title = "Character motion preview"
	RenderingServer.set_default_clear_color(Color("41523e"))
	camera = Camera2D.new()
	root.add_child(camera)
	camera.position = Vector2(1500, 1500)
	_apply_camera()
	await process_frame
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	title = _label(overlay, "", Vector2(20, 18), 21)
	for column in COLUMNS.size(): _label(overlay, COLUMNS[column], Vector2(190 + column * 225, 80), 16)
	for row in 5:
		labels.append(_label(overlay, "", Vector2(20, 217 + row * 163), 16))
		for column in COLUMNS.size():
			var actor := Actor.new()
			root.add_child(actor)
			actors.append(actor)
	_set_roster()
	process_frame.connect(_tick)

func _label(parent: Node, content: String, point: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _set_roster() -> void:
	for row in 5:
		var available: bool = row < GROUPS[group].size()
		labels[row].text = GROUPS[group][row] if available else ""
		for column in COLUMNS.size():
			var actor := actors[row * COLUMNS.size() + column]
			actor.visible = available
			if available: actor.state = State.preview(GROUPS[group][row], GameData.UNITS[GROUPS[group][row]], Color("4e9bea"))

func _apply_camera() -> void:
	camera.rotation = -PI / 4.0 if isometric else 0.0
	camera.zoom = Vector2(2.2, 1.1) if isometric else Vector2.ONE * 2.2
	camera.force_update_scroll()

func _tick() -> void:
	elapsed += root.get_process_delta_time()
	if capture_path.is_empty():
		if Input.is_action_just_pressed("ui_accept"):
			isometric = not isometric
			_apply_camera()
		if Input.is_action_just_pressed("ui_right"): heading = (heading + 1) % 8
		if Input.is_action_just_pressed("ui_left"): heading = (heading + 7) % 8
		if Input.is_action_just_pressed("ui_up"):
			group = (group + 3) % 4
			_set_roster()
		if Input.is_action_just_pressed("ui_down"):
			group = (group + 1) % 4
			_set_roster()
	var canvas := root.get_canvas_transform()
	title.text = "19 character types · %s · Space: projection · Up / Down: roster · Left / Right: eight directions" % ("2.5D" if isometric else "2D")
	for index in actors.size():
		var actor := actors[index]
		if not actor.visible: continue
		var row := index / COLUMNS.size()
		var column := index % COLUMNS.size()
		var state = actor.state
		actor.position = canvas.affine_inverse() * Vector2(255 + column * 225, 260 + row * 163)
		state.view_mode_25d = isometric
		state.zoom = camera.zoom.x
		state.visual_moving = column in [1, 2]
		state.visual_phase = elapsed * 7.5 if capture_path.is_empty() else 1.3
		state.facing_direction = Vector2.DOWN if column == 0 else Vector2.RIGHT if column == 1 else Vector2.UP if column == 2 else Vector2.RIGHT.rotated(heading * PI / 4.0)
		state.visual_action = "attack" if column >= 3 else ""
		if state.kind == "villager":
			state.visual_action = "gather" if column >= 3 else ""
			state.gather_kind = "wood"
		if state.kind in ["monk", "trader", "imperial_official"]: state.visual_action = "heal" if state.kind == "monk" and column == 3 else "tax" if state.kind == "imperial_official" and column >= 3 else ""
		state.action_progress = 0.35 if column == 3 else 0.5 if column == 4 else 0.9 if column == 5 else 0.0
		state.action_released = column >= 4 and state.visual_action == "attack"
		state.release_elapsed = 0.02 if column == 4 else 0.3 if column == 5 else -1.0
		state.charging = column == 3 and state.kind in ["horseman", "knight", "royal_knight", "fire_lancer"]
		state.charge_impact = column == 4 and state.kind in ["horseman", "knight", "royal_knight", "fire_lancer"]
		state.shield_active = state.kind == "arbaletrier" and column == 5
		state.healing = state.kind == "monk" and column == 3
		state.converting = state.kind == "monk" and column == 4
		state.carries_relic = state.kind == "monk" and column == 5
		state.tax_active = state.kind == "imperial_official" and column >= 3
		actor.queue_redraw()
	if not capture_path.is_empty() and elapsed > 1.0 and not captured:
		captured = true
		_capture.call_deferred()

func _capture() -> void:
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(capture_path) == OK)
	print("CHARACTER_PREVIEW_CAPTURE ", capture_path)
	quit()
