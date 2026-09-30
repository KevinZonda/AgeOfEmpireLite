extends SceneTree

const Fish = preload("res://scripts/entities/visuals/fish_visual.gd")
const CELL := Vector2i(200, 200)

class Context extends Node2D:
	var view_mode_25d := false
	var started := false

var failures: Array[String] = []
var captures := 0

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _capture(viewport: SubViewport, item: CanvasItem) -> Image:
	item.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	captures += 1
	return viewport.get_texture().get_image()

func _ink(picture: Image) -> float:
	var total := 0.0
	for y in picture.get_height():
		for x in picture.get_width(): total += picture.get_pixel(x, y).a
	return total

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fish rendering checks require a graphics renderer")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var context := Context.new()
	viewport.add_child(context)
	var fish := RtsResource.new()
	fish.game = context
	fish.setup("food", 420, "fish")
	context.add_child(fish)
	fish.set_process(false)
	var default_seed := fish.fish_visual_seed
	for iso in [false, true]:
		context.view_mode_25d = iso
		for zoom in [0.65, 1.0, 3.0]:
			viewport.canvas_transform = Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2(100, 100)) if iso else Transform2D(0.0, Vector2.ONE * zoom, 0.0, Vector2(100, 100))
			fish.fish_visual_seed = default_seed
			fish.fish_time = 0.0
			fish.amount = 420
			var full: Image = await _capture(viewport, fish)
			var used := full.get_used_rect()
			_check(_ink(full) > 5.0, "fish school unreadable iso=%s zoom=%.2f" % [iso, zoom])
			_check(used.position.x > 0 and used.position.y > 0 and used.end.x < CELL.x and used.end.y < CELL.y, "fish school clipped iso=%s zoom=%.2f" % [iso, zoom])
			# Schools stay close to the fixed gathering target despite cosmetic drift.
			_check(used.size.x < 65.0 * zoom + 4.0 and used.size.y < 65.0 * zoom + 4.0, "fish school escapes gathering footprint iso=%s zoom=%.2f" % [iso, zoom])
			fish.fish_time = 0.24
			var swimming: Image = await _capture(viewport, fish)
			_check(swimming.get_data() != full.get_data(), "fish animation has identical pixels iso=%s zoom=%.2f" % [iso, zoom])
			fish.fish_time = 0.0
			fish.amount = 42
			var low: Image = await _capture(viewport, fish)
			_check(_ink(low) > 2.0 and _ink(low) < _ink(full) * 0.9, "resource depletion does not visibly thin the school iso=%s zoom=%.2f" % [iso, zoom])
			fish.amount = 420
			fish.fish_visual_seed = hash(Vector2(191, 227))
			var variant: Image = await _capture(viewport, fish)
			_check(variant.get_data() != full.get_data(), "separate fish sites have identical schools iso=%s zoom=%.2f" % [iso, zoom])
	viewport.free()
	await _portraits()
	if failures.is_empty():
		print("FISH_RENDERING_OK projections=2 zooms=3 portraits=3 captures=%d" % captures)
		quit()
	else:
		print("FISH_RENDERING_FAILED failures=%d" % failures.size())
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
		var frame: Image = await _capture(viewport, portrait)
		var resource := RtsResource.new()
		resource.setup("food", 420, "fish")
		portrait.show_subject(resource)
		var picture: Image = await _capture(viewport, portrait)
		var changed := 0
		var escaped := false
		for y in dimensions.y:
			for x in dimensions.x:
				if picture.get_pixel(x, y) == frame.get_pixel(x, y): continue
				changed += 1
				if x < 12 or x >= dimensions.x - 12 or y < 12 or y >= dimensions.y - 12: escaped = true
		_check(changed > 100, "fish portrait %s has no visible school" % dimensions)
		_check(not escaped, "fish portrait %s escapes its frame" % dimensions)
		resource.fish_time = 19.0
		var later: Image = await _capture(viewport, portrait)
		_check(picture.get_data() == later.get_data(), "fish portrait %s must keep a stable pose" % dimensions)
		resource.free()
		viewport.free()
