extends SceneTree

# Pixel checks exercise UnitVisual under the real 2D and isometric camera bases.
const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Naval = preload("res://scripts/entities/visuals/naval_visual.gd")
const Iso = preload("res://scripts/world/iso_projection.gd")
const Page = preload("res://scripts/ui/unit_preview_page.gd")
const KINDS = ["arrow_ship", "springald_ship", "incendiary_ship", "warship", "transport_ship"]
const CELL := Vector2i(240, 240)
const ANCHOR := Vector2(120, 155)
const TINT := Color("4e9bea")

class Actor extends Node2D:
	var state
	var water_only := false
	var renderer := Visual.new()
	var naval := Naval.new()
	func _draw() -> void:
		if state == null: return
		if water_only:
			if state.view_mode_25d:
				draw_set_transform_matrix(Iso.upright(get_viewport().get_canvas_transform(), Vector2.ZERO, state.zoom))
			naval.draw_shadow(self, state)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			renderer.draw(self, state)

var failures: Array[String] = []
var captures := 0

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _state(kind: String, iso: bool):
	var result = State.preview(kind, GameData.UNITS[kind], TINT)
	result.view_mode_25d = iso
	result.facing_direction = Vector2(1, 1).normalized()
	return result

func _capture(viewport: SubViewport, canvas: CanvasItem) -> Image:
	canvas.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	captures += 1
	return viewport.get_texture().get_image()

func _visible_pixels(picture: Image) -> int:
	var count := 0
	var used := picture.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if picture.get_pixel(x, y).a > 0.05: count += 1
	return count

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Naval pixel regressions require the local graphics renderer")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := Actor.new()
	viewport.add_child(actor)
	var atlas := Image.create(CELL.x * 8, CELL.y * KINDS.size() * 2, false, Image.FORMAT_RGBA8)
	var poses := 0
	for kind_index in KINDS.size():
		var kind: String = KINDS[kind_index]
		_check(Naval.handles(kind), "%s lost naval routing" % kind)
		for mode in 2:
			viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339), Vector2(-0.70710678, 0.35355339), ANCHOR) if mode == 1 else Transform2D(0.0, ANCHOR)
			var headings: Array[PackedByteArray] = []
			for heading in 8:
				actor.state = _state(kind, mode == 1)
				actor.state.facing_direction = Vector2.RIGHT.rotated(heading * PI / 4.0)
				var picture: Image = await _capture(viewport, actor)
				var used := picture.get_used_rect()
				_check(_visible_pixels(picture) > 250, "%s mode=%d heading=%d has no substantial vessel silhouette" % [kind, mode, heading])
				_check(used.position.x > 0 and used.position.y > 0 and used.end.x < CELL.x and used.end.y < CELL.y, "%s mode=%d heading=%d is clipped" % [kind, mode, heading])
				var fitted: Rect2 = actor.naval.bounds(actor.state)
				fitted.position += ANCHOR
				_check(fitted.grow(3).encloses(Rect2(used)), "%s mode=%d heading=%d preview bounds miss rendered pixels (%s versus %s)" % [kind, mode, heading, fitted, used])
				_check(actor.naval.overlay_y(actor.state) < actor.naval.bounds(actor.state).position.y, "%s health bar overlaps the model" % kind)
				headings.append(picture.get_data())
				atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, CELL), Vector2i(heading * CELL.x, (kind_index * 2 + mode) * CELL.y))
				poses += 1
			for heading in 8:
				_check(headings[heading] != headings[(heading + 1) % 8], "%s mode=%d adjacent headings %d/%d share identical pixels" % [kind, mode, heading, (heading + 1) % 8])
			actor.state = _state(kind, mode == 1)
			var idle: Image = await _capture(viewport, actor)
			actor.state.visual_moving = true
			actor.state.visual_phase = 1.2
			var sailing: Image = await _capture(viewport, actor)
			_check(idle.get_data() != sailing.get_data(), "%s mode=%d sailing has no visible effect" % [kind, mode])
			actor.water_only = true
			actor.state.visual_moving = false
			var idle_water: Image = await _capture(viewport, actor)
			actor.state.visual_moving = true
			var sailing_water: Image = await _capture(viewport, actor)
			_check(_visible_pixels(sailing_water) > _visible_pixels(idle_water), "%s mode=%d sailing adds no wake pixels" % [kind, mode])
			actor.state.visual_phase = 2.4
			var wake_phase: Image = await _capture(viewport, actor)
			_check(wake_phase.get_data() != sailing_water.get_data(), "%s mode=%d wake does not animate" % [kind, mode])
			actor.water_only = false
			if kind == "transport_ship":
				actor.state = _state(kind, mode == 1)
				var empty: Image = await _capture(viewport, actor)
				actor.state.passenger_count = 1
				var one: Image = await _capture(viewport, actor)
				actor.state.passenger_count = 6
				var loaded: Image = await _capture(viewport, actor)
				_check(empty.get_data() != one.get_data(), "transport mode=%d first passenger is invisible" % mode)
				_check(one.get_data() != loaded.get_data(), "transport mode=%d occupancy count has no further visible effect" % mode)
			_cache_reuse(actor.naval, kind, mode == 1)
	viewport.free()
	await _portraits()
	await _preview_page()
	_cache_limit()
	DirAccess.make_dir_recursive_absolute("res://tmp/naval-preview")
	_check(atlas.save_png("res://tmp/naval-preview/test-directions.png") == OK, "failed to save naval regression atlas")
	if failures.is_empty():
		print("NAVAL_RENDERING_OK directional_poses=%d portraits=15 preview_cases=30 captures=%d cache_limit=%d" % [poses, captures, Naval.CACHE_LIMIT])
		quit()
	else:
		print("NAVAL_RENDERING_FAILED failures=%d" % failures.size())
		quit(1)

func _cache_reuse(renderer, kind: String, iso: bool) -> void:
	var first_state = _state(kind, iso)
	var first_model = renderer.geometry(first_state)
	var other = Naval.new()
	_check(other.geometry(_state(kind, iso)) == first_model, "%s iso=%s duplicate snapshots fail to share geometry" % [kind, iso])
	# Animation time and movement must not grow the model cache every frame.
	for phase in [0.01, 0.73, 3.2, 100.0, 10000.0]:
		first_state.visual_phase = phase
		first_state.visual_moving = true
		_check(renderer.geometry(first_state) == first_model, "%s iso=%s animation phase %.2f allocates new hull geometry" % [kind, iso, phase])

func _cache_limit() -> void:
	var renderer := Naval.new()
	var state = _state("arrow_ship", true)
	# Distinct team tints exhaust the shared cache without animation-time keys.
	for index in Naval.CACHE_LIMIT + 8:
		state.player_color = Color.from_hsv(float(index) / (Naval.CACHE_LIMIT + 8), 0.62, 0.9)
		renderer.geometry(state)
		_check(Naval.model_cache.size() <= Naval.CACHE_LIMIT, "naval geometry cache exceeds its declared limit")

func _preview_page() -> void:
	var host := Control.new()
	host.size = Vector2(1440, 960)
	root.add_child(host)
	var page = Page.new()
	page.build(host, "English", func(_button) -> void: pass)
	await process_frame
	page.set_process(false)
	page.preview_viewport.get_parent().stretch = false
	for iso in [false, true]:
		page.preview_context.view_mode_25d = iso
		for dimensions in [Vector2i(160, 180), Vector2i(350, 390), Vector2i(800, 900)]:
			page.preview_viewport.size = dimensions
			for kind in KINDS:
				page.selected_kind = kind
				page._refresh_preview()
				var state = page.preview_unit.state
				_check(state.view_mode_25d == iso, "%s preview loses active projection" % kind)
				_check(page.preview_backdrop.water, "%s preview uses a land backdrop" % kind)
				_check(not page.fishing_preview_controls.visible, "%s preview shows fishing-only controls" % kind)
				var bounds: Rect2 = page.naval_renderer.bounds(state)
				var rendered := Rect2(page.preview_unit.position + bounds.position * page.preview_unit.scale, bounds.size * page.preview_unit.scale)
				var margin: float = clampf(minf(dimensions.x, dimensions.y) * 0.06, 12.0, 28.0)
				var area := Rect2(Vector2.ONE * (margin - 0.1), Vector2(dimensions) - Vector2.ONE * (margin - 0.1) * 2.0)
				_check(area.encloses(rendered), "%s preview %s iso=%s clips its fitted vessel" % [kind, dimensions, iso])
	host.free()

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
		for kind in KINDS:
			var unit := RtsUnit.new()
			unit.kind = kind
			unit.stats = GameData.UNITS[kind].duplicate(true)
			portrait.show_subject(unit, TINT)
			var picture: Image = await _capture(viewport, portrait)
			var changed := 0
			var escaped := false
			for y in dimensions.y:
				for x in dimensions.x:
					if picture.get_pixel(x, y) == frame.get_pixel(x, y): continue
					changed += 1
					if x < 12 or x >= dimensions.x - 12 or y < 12 or y >= dimensions.y - 12: escaped = true
			_check(changed > 200, "%s portrait %s renders no substantial vessel" % [kind, dimensions])
			_check(not escaped, "%s portrait %s escapes its inner frame" % [kind, dimensions])
			unit.free()
		viewport.free()
