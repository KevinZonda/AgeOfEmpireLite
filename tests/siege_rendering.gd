extends SceneTree

const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Siege = preload("res://scripts/entities/visuals/siege_visual.gd")
const CELL := Vector2i(192, 160)
const TINT := Color("4e9bea")

class SnapshotCanvas extends Node2D:
	var state
	var renderer := Visual.new()
	func _draw() -> void:
		if state != null: renderer.draw(self, state)

var failures: Array[String] = []
var captures := 0

func _initialize() -> void:
	call_deferred("_run")

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

func _state(kind: String, iso: bool):
	var result = State.preview(kind, GameData.UNITS[kind], TINT)
	result.view_mode_25d = iso
	result.facing_direction = Vector2(1, 1).normalized()
	return result

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Siege pixel regressions require the local graphics renderer")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := SnapshotCanvas.new()
	viewport.add_child(canvas)
	var atlas := Image.create(CELL.x * 8, CELL.y * 16, false, Image.FORMAT_RGBA8)
	var poses := 0
	for kind_index in Siege.KINDS.size():
		var kind: String = Siege.KINDS[kind_index]
		for mode in 2:
			# Exercise the production upright transform under the game's camera basis.
			viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339), Vector2(-0.70710678, 0.35355339), Vector2(96, 123)) if mode == 1 else Transform2D(0.0, Vector2(96, 100))
			var directions: Array[PackedByteArray] = []
			for facing in 8:
				canvas.state = _state(kind, mode == 1)
				canvas.state.facing_direction = Vector2.RIGHT.rotated(float(facing) * PI / 4.0)
				var picture: Image = await _capture(viewport, canvas)
				_check(picture.get_used_rect().get_area() > 300, "%s mode=%d facing=%d renders no substantial silhouette" % [kind, mode, facing])
				var used := picture.get_used_rect()
				_check(used.position.x > 0 and used.position.y > 0 and used.end.x < CELL.x and used.end.y < CELL.y, "%s mode=%d facing=%d is clipped by the test viewport" % [kind, mode, facing])
				directions.append(picture.get_data())
				atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, CELL), Vector2i(facing * CELL.x, (kind_index * 2 + mode) * CELL.y))
				poses += 1
			for facing in 8:
				_check(directions[facing] != directions[(facing + 1) % 8], "%s mode=%d adjacent headings %d and %d have identical pixels" % [kind, mode, facing, (facing + 1) % 8])
			# Wheels and articulated machinery must respond to animation state.
			canvas.state = _state(kind, mode == 1)
			var idle: Image = await _capture(viewport, canvas)
			canvas.state.visual_moving = true
			canvas.state.visual_phase = 0.83
			var rolling: Image = await _capture(viewport, canvas)
			_check(rolling.get_data() != idle.get_data(), "%s mode=%d movement leaves the model unchanged" % [kind, mode])
			if kind != "siege_tower":
				canvas.state = _state(kind, mode == 1)
				canvas.state.visual_action = "attack"
				canvas.state.action_progress = 0.8
				var windup: Image = await _capture(viewport, canvas)
				canvas.state.action_released = true
				canvas.state.release_elapsed = 0.025
				var release: Image = await _capture(viewport, canvas)
				canvas.state.release_elapsed = 0.4
				var recovered: Image = await _capture(viewport, canvas)
				_check(release.get_data() != windup.get_data(), "%s mode=%d attack release has no visible change" % [kind, mode])
				_check(release.get_data() != recovered.get_data(), "%s mode=%d mechanism never visibly recovers" % [kind, mode])
				if kind in ["battering_ram", "trebuchet", "mangonel", "springald"]:
					_check(windup.get_data() != idle.get_data(), "%s mode=%d mechanical windup does not move" % [kind, mode])
			else:
				canvas.state = _state(kind, mode == 1)
				canvas.state.facing_direction = Vector2.DOWN
				var travelling: Image = await _capture(viewport, canvas)
				canvas.state.siege_deployed = true
				var deployed: Image = await _capture(viewport, canvas)
				_check(deployed.get_data() != travelling.get_data(), "tower mode=%d deployment does not change the bridge" % mode)
				canvas.state.passenger_count = 3
				var occupied: Image = await _capture(viewport, canvas)
				_check(occupied.get_data() != deployed.get_data(), "tower mode=%d passengers have no visible effect" % mode)
	viewport.free()
	await _portraits()
	DirAccess.make_dir_recursive_absolute("res://tmp/siege-preview")
	_check(atlas.save_png("res://tmp/siege-preview/directions.png") == OK, "failed to save siege direction atlas")
	if failures.is_empty():
		print("SIEGE_RENDERING_OK directional_poses=%d portraits=16 captures=%d" % [poses, captures])
		quit()
	else:
		print("SIEGE_RENDERING_FAILED failures=%d" % failures.size())
		quit(1)

func _portraits() -> void:
	var atlas := Image.create(102 * 8, 142 * 2, false, Image.FORMAT_RGBA8)
	for dimensions in [Vector2i(102, 142), Vector2i(80, 110)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var portrait := RtsSelectionPortrait.new()
		viewport.add_child(portrait)
		# The compact case intentionally overrides the default minimum UI size.
		portrait.custom_minimum_size = Vector2.ZERO
		portrait.size = Vector2(dimensions)
		portrait.show_subject(null)
		var frame: Image = await _capture(viewport, portrait)
		for kind_index in Siege.KINDS.size():
			var kind: String = Siege.KINDS[kind_index]
			var unit := RtsUnit.new()
			unit.kind = kind
			unit.stats = GameData.UNITS[kind].duplicate(true)
			portrait.show_subject(unit, TINT)
			var picture: Image = await _capture(viewport, portrait)
			var changed := 0
			var first_escape := Vector2i(-1, -1)
			var changed_bounds := Rect2i()
			for y in dimensions.y:
				for x in dimensions.x:
					if picture.get_pixel(x, y) == frame.get_pixel(x, y): continue
					if changed == 0: changed_bounds = Rect2i(x, y, 1, 1)
					else: changed_bounds = changed_bounds.expand(Vector2i(x, y))
					changed += 1
					if (x < 12 or x >= dimensions.x - 12 or y < 12 or y >= dimensions.y - 12) and first_escape.x < 0:
						first_escape = Vector2i(x, y)
			_check(changed > 200, "%s portrait %s has no visible model" % [kind, dimensions])
			_check(first_escape.x < 0, "%s portrait %s escapes its inner frame at %s (changed bounds %s)" % [kind, dimensions, first_escape, changed_bounds])
			atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, dimensions), Vector2i(kind_index * 102, 0 if dimensions.x == 102 else 142))
			unit.free()
		viewport.free()
	DirAccess.make_dir_recursive_absolute("res://tmp/siege-preview")
	_check(atlas.save_png("res://tmp/siege-preview/portraits.png") == OK, "failed to save siege portrait atlas")
