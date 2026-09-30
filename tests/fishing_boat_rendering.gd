extends SceneTree

const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Page = preload("res://scripts/ui/unit_preview_page.gd")
const Typography = preload("res://scripts/ui/typography.gd")
const Fishing = preload("res://scripts/entities/visuals/fishing_boat_visual.gd")
const CELL := Vector2i(240, 240)
const TINT := Color("4e9bea")

class Actor extends Node2D:
	var state
	var renderer := Visual.new()
	func _draw() -> void:
		if state != null: renderer.draw(self, state)

class Context extends Node2D:
	var view_mode_25d := false
	var world_map: Node2D
	var navigation: RtsNavigation
	var camera := Camera2D.new()
	var units: Array = []
	var selected: Array = []
	func player_color(_owner: int) -> Color: return TINT
	func should_show_health_bar(_hp: float, _max_hp: float, _timer: float) -> bool: return false

var failures: Array[String] = []
var captures := 0

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _capture(viewport: SubViewport, canvas: CanvasItem) -> Image:
	canvas.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	captures += 1
	return viewport.get_texture().get_image()

func _state(iso: bool):
	var result = State.preview("fishing_boat", GameData.UNITS["fishing_boat"], TINT)
	result.view_mode_25d = iso
	result.facing_direction = Vector2.RIGHT
	return result

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fishing boat pixel tests require the local graphics renderer")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := Actor.new()
	viewport.add_child(actor)
	var atlas := Image.create(CELL.x * 8, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for mode in 2:
		viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339), Vector2(-0.70710678, 0.35355339), Vector2(120, 140)) if mode == 1 else Transform2D(0.0, Vector2(120, 140))
		var directions: Array[PackedByteArray] = []
		var bounds: Array[Rect2i] = []
		for facing in 8:
			actor.state = _state(mode == 1)
			actor.state.facing_direction = Vector2.RIGHT.rotated(facing * PI / 4.0)
			var picture: Image = await _capture(viewport, actor)
			var used := picture.get_used_rect()
			_check(used.get_area() > 350, "mode=%d heading=%d has no substantial boat silhouette" % [mode, facing])
			_check(used.position.x > 0 and used.position.y > 0 and used.end.x < CELL.x and used.end.y < CELL.y, "mode=%d heading=%d is clipped" % [mode, facing])
			directions.append(picture.get_data())
			bounds.append(used)
			atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, CELL), Vector2i(facing * CELL.x, mode * CELL.y))
		for facing in 8:
			_check(directions[facing] != directions[(facing + 1) % 8], "mode=%d adjacent headings %d/%d share identical pixels" % [mode, facing, (facing + 1) % 8])
		_check(bounds[0].size != bounds[2].size, "mode=%d east and south silhouettes do not turn with the heading" % mode)
		actor.state = _state(mode == 1)
		var idle: Image = await _capture(viewport, actor)
		actor.state.visual_moving = true
		actor.state.visual_phase = 1.2
		var sailing: Image = await _capture(viewport, actor)
		_check(sailing.get_data() != idle.get_data(), "mode=%d sailing adds no visible wake or rig movement" % mode)
		# Movement must retract the net even if the previous work state survives.
		actor.state.fishing_active = true
		actor.state.fishing_cycle = 0.5
		actor.state.visual_action = "gather"
		actor.state.gather_kind = "fish"
		var moving_with_work: Image = await _capture(viewport, actor)
		_check(moving_with_work.get_data() == sailing.get_data(), "mode=%d sailing retains the deployed fishing net" % mode)
		actor.state = _state(mode == 1)
		actor.state.fishing_active = true
		var phases: Array[PackedByteArray] = []
		for cycle in [0.08, 0.35, 0.7, 0.94]:
			actor.state.fishing_cycle = cycle
			var picture: Image = await _capture(viewport, actor)
			phases.append(picture.get_data())
			_check(picture.get_data() != idle.get_data(), "mode=%d fishing cycle %.2f looks identical to idle" % [mode, cycle])
		for phase in 3:
			_check(phases[phase] != phases[phase + 1], "mode=%d adjacent fishing phases have identical pixels" % mode)
	viewport.free()
	await _portraits()
	await _capture_work_state()
	_capture_fishing_heading()
	await _preview_page()
	DirAccess.make_dir_recursive_absolute("res://tmp/fishing-boat-preview")
	_check(atlas.save_png("res://tmp/fishing-boat-preview/test-directions.png") == OK, "failed to save direction regression atlas")
	if failures.is_empty():
		print("FISHING_BOAT_RENDERING_OK headings=16 fishing_target_cases=8 portraits=3 preview_cases=144 captures=%d" % captures)
		quit()
	else:
		print("FISHING_BOAT_RENDERING_FAILED failures=%d" % failures.size())
		quit(1)

func _portraits() -> void:
	for dimensions in [Vector2i(102, 142), Vector2i(80, 110), Vector2i(160, 180)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var portrait := RtsSelectionPortrait.new()
		viewport.add_child(portrait)
		portrait.custom_minimum_size = Vector2.ZERO
		portrait.size = Vector2(dimensions)
		portrait.show_subject(null)
		var frame: Image = await _capture(viewport, portrait)
		var unit := RtsUnit.new()
		unit.kind = "fishing_boat"
		unit.stats = GameData.UNITS["fishing_boat"].duplicate(true)
		portrait.show_subject(unit, TINT)
		var picture: Image = await _capture(viewport, portrait)
		var changed := 0
		var escaped := false
		for y in dimensions.y:
			for x in dimensions.x:
				if picture.get_pixel(x, y) == frame.get_pixel(x, y): continue
				changed += 1
				if x < 12 or x >= dimensions.x - 12 or y < 12 or y >= dimensions.y - 12: escaped = true
		_check(changed > 250, "portrait %s has no visible boat" % dimensions)
		_check(not escaped, "portrait %s escapes its inner frame" % dimensions)
		unit.free()
		viewport.free()

func _capture_work_state() -> void:
	var context := Context.new()
	root.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var boat := RtsUnit.new()
	boat.game = context
	boat.kind = "fishing_boat"
	boat.stats = GameData.UNITS["fishing_boat"].duplicate(true)
	boat.process_mode = Node.PROCESS_MODE_DISABLED
	context.add_child(boat)
	var fish := RtsResource.new()
	fish.kind = "food"
	fish.appearance = "fish"
	fish.amount = 100
	fish.position = Vector2(24, 0)
	boat.target = fish
	boat.order = "gather"
	boat.work_timer = 0.6
	boat.visual_action = ""
	var working = State.capture(boat)
	_check(working.fishing_active, "capture loses fishing between short gather action pulses")
	boat.work_timer = 0.2
	_check(State.capture(boat).fishing_cycle > working.fishing_cycle, "work timer does not advance the fishing cycle")
	boat.visual_moving = true
	_check(not State.capture(boat).fishing_active, "moving boat captures active deployed fishing")
	boat.visual_moving = false
	fish.position = Vector2(600, 0)
	_check(not State.capture(boat).fishing_active, "boat deploys net before reaching fish")
	fish.position = Vector2(24, 0)
	fish.amount = 0
	_check(not State.capture(boat).fishing_active, "depleted fish leaves fishing animation active")
	fish.amount = 100
	boat.order = "idle"
	_check(not State.capture(boat).fishing_active, "idle boat captures an active fishing order")
	boat.visual_last_position = boat.position
	var phase_before: float = boat.visual_phase
	boat._tick_visual(0.2)
	_check(boat.visual_phase > phase_before, "visible unselected idle boat never floats")
	boat.hide()
	phase_before = boat.visual_phase
	boat._tick_visual(0.2)
	_check(is_equal_approx(boat.visual_phase, phase_before), "hidden idle boat keeps updating idle animation")
	boat.free()
	fish.free()
	context.free()

func _capture_fishing_heading() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var context := Context.new()
	viewport.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var boat := RtsUnit.new()
	boat.game = context
	boat.kind = "fishing_boat"
	boat.stats = GameData.UNITS["fishing_boat"].duplicate(true)
	boat.visual_facing_world = Vector2.LEFT
	boat.process_mode = Node.PROCESS_MODE_DISABLED
	context.add_child(boat)
	var fish := RtsResource.new()
	fish.kind = "food"
	fish.appearance = "fish"
	fish.amount = 100
	boat.target = fish
	var fishing := Fishing.new()
	for mode in 2:
		context.view_mode_25d = mode == 1
		viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339), Vector2(-0.70710678, 0.35355339), Vector2.ZERO) if mode == 1 else Transform2D.IDENTITY
		boat.order = "idle"
		var travel_heading: Vector2 = State.capture(boat).facing_direction
		for target_direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			fish.position = target_direction * 24.0
			boat.order = "gather"
			boat.visual_moving = false
			var working = State.capture(boat)
			_check(working.fishing_active, "direction case loses active fishing mode=%d target=%s" % [mode, target_direction])
			var model = fishing.geometry(working)
			# The deployed net extends along local +X from its starboard attachment.
			var net_outward: Vector2 = (model.project(Vector3(24, 8, 0)) - model.project(Vector3(8, 8, 0))).normalized()
			var target_screen := viewport.canvas_transform.basis_xform(fish.position - boat.position).normalized()
			_check(net_outward.dot(target_screen) > 0.9, "net points away from fish mode=%d target=%s" % [mode, target_direction])
			_check(boat.visual_facing_world == Vector2.LEFT, "fishing pose changes navigation heading")
			boat.visual_moving = true
			var moving = State.capture(boat)
			_check(not moving.fishing_active and moving.facing_direction.is_equal_approx(travel_heading), "moving boat retains fishing side-on pose")
	fish.free()
	viewport.free()

func _preview_page() -> void:
	var host := Control.new()
	host.size = Vector2(1440, 960)
	root.add_child(host)
	var page = Page.new()
	page.build(host, "English", func(_button) -> void: pass)
	page.selected_kind = "fishing_boat"
	page._refresh_selection()
	await process_frame
	page.set_process(false)
	page.preview_viewport.get_parent().stretch = false
	for iso in [false, true]:
		page.preview_context.view_mode_25d = iso
		for dimensions in [Vector2i(160, 180), Vector2i(350, 390), Vector2i(800, 900)]:
			page.preview_viewport.size = dimensions
			for action in 3:
				page.fishing_action_choice.select(action)
				page.fishing_action_choice.item_selected.emit(action)
				for heading in 8:
					page.fishing_heading_choice.select(heading)
					page.fishing_heading_choice.item_selected.emit(heading)
					var state = page.preview_unit.state
					_check(state.visual_moving == (action == 1) and state.fishing_active == (action == 2), "preview action controls do not reach the production snapshot")
					_check(state.facing_direction.is_equal_approx(Vector2.RIGHT.rotated(heading * PI / 4.0)), "preview heading control does not reach the production snapshot")
					var bounds: Rect2 = page.fishing_renderer.bounds(state)
					var rendered := Rect2(page.preview_unit.position + bounds.position * page.preview_unit.scale, bounds.size * page.preview_unit.scale)
					var safe := Rect2(Vector2(8, 8), Vector2(dimensions) - Vector2(16, 16))
					_check(safe.encloses(rendered), "preview %s iso=%s action=%d heading=%d clips its boat" % [dimensions, iso, action, heading])
	for text_scale in [1.5, 1.75, 2.0]:
		Typography.apply_tree(host, text_scale, 1.0, 16)
		await process_frame
		await process_frame
		var row: HBoxContainer = page.fishing_preview_controls
		_check(row.get_combined_minimum_size().x <= row.size.x + 1.0, "fishing controls overflow at %.0f%% text scale" % (text_scale * 100))
		for child in row.get_children():
			if child is Control:
				_check(child.position.x >= 0 and child.position.x + child.size.x <= row.size.x + 1.0, "fishing control escapes its row at %.0f%% text scale" % (text_scale * 100))
	page.selected_kind = "warship"
	page._refresh_selection()
	_check(not page.fishing_preview_controls.visible, "fishing controls remain visible for warships")
	host.free()
