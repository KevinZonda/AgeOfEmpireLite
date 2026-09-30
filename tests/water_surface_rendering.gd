extends SceneTree

const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Fishing = preload("res://scripts/entities/visuals/fishing_boat_visual.gd")
const STYLES := ["balanced", "lakes", "highlands", "islands"]
const SEEDS := [431, 12345, 67890]

class Context extends Node2D:
	var view_mode_25d := false
	var world_map: RtsWorldMap
	var navigation: RtsNavigation
	var camera := Camera2D.new()
	var units: Array = []
	var selected: Array = []
	func player_color(_owner: int) -> Color: return Color("4e9bea")
	func should_show_health_bar(_hp: float, _max_hp: float, _timer: float) -> bool: return false

var failures: Array[String] = []
var water_cells := 0
var fish_sites := 0

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Water surface pixel tests require a graphics renderer")
		quit(1)
		return
	for style in STYLES:
		for seed_value in SEEDS:
			var map := RtsWorldMap.new()
			map.generate(seed_value, Vector2(2400, 1500), style, 2)
			for y in map.grid_size.y:
				for x in map.grid_size.x:
					var cell := Vector2i(x, y)
					if map.cells[map._index(cell)] != RtsWorldMap.Terrain.WATER: continue
					water_cells += 1
					var corners := [map._vertex_height(x, y), map._vertex_height(x + 1, y), map._vertex_height(x + 1, y + 1), map._vertex_height(x, y + 1)]
					_check(corners.all(func(height: float) -> bool: return is_zero_approx(height)), "%s seed=%d water cell %s rises above sea level: %s" % [style, seed_value, cell, corners])
					_check(is_zero_approx(map.elevation_at(map.cell_center(cell))), "%s seed=%d water center %s has nonzero elevation" % [style, seed_value, cell])
			for resource in map.resource_specs:
				if resource["appearance"] != "fish": continue
				fish_sites += 1
				_check(map.is_navigable(resource["position"]) and is_zero_approx(map.elevation_at(resource["position"])), "%s seed=%d fish %s does not lie on flat water" % [style, seed_value, resource["position"]])
			map.free()
	await _mountain_lake_rendering()
	if failures.is_empty():
		print("WATER_SURFACE_RENDERING_OK maps=12 water_cells=%d fish_sites=%d projected_ground_samples=6" % [water_cells, fish_sites])
		quit()
	else:
		print("WATER_SURFACE_RENDERING_FAILED failures=%d" % failures.size())
		quit(1)

func _mountain_lake_rendering() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var context := Context.new()
	viewport.add_child(context)
	context.world_map = RtsWorldMap.new()
	context.world_map.generate(431, Vector2(2400, 1500), "lakes", 2)
	context.add_child(context.world_map)
	context.add_child(context.camera)
	# These exact points previously remained WATER in navigation while the raised
	# relief mesh painted grass over them. The right boat rose by 12.5053 pixels.
	var positions := [Vector2(1375, 225), Vector2(1409, 225), Vector2(1341, 225)]
	for point in positions:
		_check(context.world_map.is_navigable(point), "lakes 431 regression point %s is no longer a water cell" % point)
	var boat := RtsUnit.new()
	boat.kind = "fishing_boat"
	boat.stats = GameData.UNITS["fishing_boat"].duplicate(true)
	boat.game = context
	boat.process_mode = Node.PROCESS_MODE_DISABLED
	boat.hide()
	context.add_child(boat)
	var fish := RtsResource.new()
	fish.kind = "food"
	fish.appearance = "fish"
	fish.position = positions[0]
	fish.amount = 100
	var renderer := Fishing.new()
	DirAccess.make_dir_recursive_absolute("res://tmp/water-surface-preview")
	for iso in [false, true]:
		context.view_mode_25d = iso
		context.world_map.isometric_view = iso
		context.camera.position = positions[0]
		context.camera.rotation = -PI / 4.0 if iso else 0.0
		context.camera.zoom = Vector2(2, 1) if iso else Vector2(2, 2)
		context.camera.force_update_scroll()
		context.world_map.queue_redraw()
		for frame in 3:
			await process_frame
			RenderingServer.force_draw()
		var picture := viewport.get_texture().get_image()
		var canvas := viewport.get_canvas_transform()
		for point in positions:
			var anchor: Vector2 = canvas * point
			var color := picture.get_pixel(roundi(anchor.x), roundi(anchor.y))
			_check(color.b > color.r + 0.06 and color.b > color.g + 0.03, "lakes 431 iso=%s water %s renders as land at %s: %s" % [iso, point, anchor, color])
			boat.position = point
			boat.target = fish
			boat.order = "gather"
			var state = State.capture(boat)
			_check(is_zero_approx(state.ground_height), "iso=%s boat water anchor %s is elevated" % [iso, point])
			var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.ground_height * state.zoom)) if iso else Vector2.ZERO
			_check((canvas * (point + lift)).is_equal_approx(anchor), "iso=%s boat is displaced from its underlying water" % iso)
			_check(renderer.geometry(state).project(Vector3.ZERO).is_zero_approx(), "iso=%s boat geometry displaces its sea-level origin" % iso)
		_check(is_zero_approx(context.world_map.elevation_at(fish.position)), "iso=%s fish anchor differs from water sea level" % iso)
		_check(picture.save_png("res://tmp/water-surface-preview/lakes-431-%s.png" % ("25d" if iso else "2d")) == OK, "failed to save water ground regression picture")
	boat.free()
	fish.free()
	viewport.free()
