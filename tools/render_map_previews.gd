extends SceneTree

const SEED := 431
const PIXELS_PER_CELL := 8
const STYLES := ["balanced", "lakes", "highlands", "islands"]
const Contours = preload("res://scripts/world/terrain_contours.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://docs/map-previews")
	DirAccess.make_dir_recursive_absolute(directory)
	var map := RtsWorldMap.new()
	for style in STYLES:
		map.generate(SEED, Vector2(2400, 2400), style)
		var image := Contours.overview_image(map, PIXELS_PER_CELL)
		for spec in map.resource_specs:
			var color := Color("315e38") if spec["kind"] == "wood" else Color("cf9d38") if spec["kind"] == "gold" else Color("e1d9bf") if spec["kind"] == "stone" else Color("d88058") if spec["appearance"] in ["deer", "boar"] else Color("9dd0df") if spec["appearance"] == "fish" else Color("a9c97a")
			_dot(image, map, spec["position"], color, 2)
		for post in map.trade_post_positions(): _dot(image, map, post, Color("9b5fbd"), 6)
		for site in map.sacred_site_positions(): _dot(image, map, site, Color("ffe29a"), 8)
		for index in map.spawn_positions().size(): _dot(image, map, map.spawn_positions()[index], Color("3976b8") if index == 0 else Color("c05252"), 9)
		var path := "%s/%s-seed-%d.png" % [directory, style, SEED]
		assert(image.save_png(path) == OK, "map preview could not be saved")
	map.free()
	print("MAP_PREVIEWS_OK")
	quit()

func _dot(image: Image, map: RtsWorldMap, point: Vector2, color: Color, size: int) -> void:
	var pixel := Vector2i(point / map.world_size * Vector2(image.get_width(), image.get_height()))
	image.fill_rect(Rect2i(pixel - Vector2i(size / 2, size / 2), Vector2i(size, size)), color)
