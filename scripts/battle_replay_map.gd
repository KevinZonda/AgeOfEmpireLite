class_name RtsBattleReplayMap
extends Control

var statistics: RtsMatchStatistics
var world_map: RtsWorldMap
var player_colors: Array[Color] = []
var sample_index := 0
var terrain_texture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(690, 350)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func prepare(map_ref: RtsWorldMap) -> void:
	world_map = map_ref
	var image := Image.create(world_map.grid_size.x, world_map.grid_size.y, false, Image.FORMAT_RGBA8)
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var terrain: int = world_map.cells[y * world_map.grid_size.x + x]
			var color := Color("648856")
			match terrain:
				RtsWorldMap.Terrain.MEADOW: color = Color("779b64")
				RtsWorldMap.Terrain.WATER: color = Color("426d88")
				RtsWorldMap.Terrain.MOUNTAIN: color = Color("777e79")
				RtsWorldMap.Terrain.ROAD: color = Color("9a9b70")
			image.set_pixel(x, y, color)
	terrain_texture = ImageTexture.create_from_image(image)
	queue_redraw()

func seek(index: int) -> void:
	sample_index = clampi(index, 0, maxi(0, statistics.samples.size() - 1))
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(bounds, Color("283b36"))
	if terrain_texture != null: draw_texture_rect(terrain_texture, bounds, false)
	if statistics == null or statistics.samples.is_empty() or world_map == null: return
	var sample: Dictionary = statistics.samples[sample_index]
	for building in sample["buildings"]:
		var owner: int = building["owner"]
		if owner < 0 or owner >= player_colors.size(): continue
		var point := _to_map(building["position"], bounds)
		var radius := 6.0 if building["kind"] in ["town_center", "landmark", "wonder", "keep"] else 3.0
		draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), player_colors[owner])
	for unit in sample["units"]:
		var owner: int = unit["owner"]
		if owner < 0 or owner >= player_colors.size(): continue
		var point := _to_map(unit["position"], bounds)
		draw_circle(point, 2.3 if GameData.UNITS.get(unit["kind"], {}).get("tags", []).has("military") else 1.5, player_colors[owner].lightened(0.3))
	draw_rect(bounds, Color("e4d68f"), false, 1.5)

func _to_map(world_point: Vector2, bounds: Rect2) -> Vector2:
	return bounds.position + Vector2(world_point.x / world_map.world_size.x * bounds.size.x, world_point.y / world_map.world_size.y * bounds.size.y)
