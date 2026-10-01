class_name RtsBattleReplayMap
extends Control
const Contours = preload("res://scripts/world/terrain_contours.gd")

var statistics: RtsMatchStatistics
var world_map: RtsWorldMap
var player_colors: Array[Color] = []
var sample_index := 0
var terrain_texture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(690, 350)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func prepare(map_ref: RtsWorldMap) -> void:
	world_map = map_ref
	var image := Contours.overview_image(world_map)
	terrain_texture = ImageTexture.create_from_image(image)
	queue_redraw()

func seek(index: int) -> void:
	sample_index = clampi(index, 0, maxi(0, statistics.samples.size() - 1))
	queue_redraw()

func _draw() -> void:
	var side := minf(size.x, size.y) - 8.0
	var bounds := Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)
	draw_rect(Rect2(Vector2.ZERO, size), Color("283b36"))
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
