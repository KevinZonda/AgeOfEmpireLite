class_name RtsMapPreview
extends RefCounted

const PIXELS_PER_CELL := 4
const Contours = preload("res://scripts/world/terrain_contours.gd")

static func create_texture(seed_value: int, world_size: Vector2, style: String, player_colors: Array[Color]) -> ImageTexture:
	var map := RtsWorldMap.new()
	map.generate_terrain(seed_value, world_size, style, player_colors.size())
	var image := Contours.overview_image(map, PIXELS_PER_CELL)
	for post in map.trade_post_positions(): _dot(image, map, post, Color("9b5fbd"), 6)
	for site in map.sacred_site_positions(): _dot(image, map, site, Color("ffe29a"), 7)
	var spawns := map.spawn_positions()
	for index in spawns.size():
		_dot(image, map, spawns[index], Color("27302c"), 10)
		_dot(image, map, spawns[index], player_colors[index], 7)
	map.free()
	return ImageTexture.create_from_image(image)

static func _dot(image: Image, map: RtsWorldMap, point: Vector2, color: Color, diameter: int) -> void:
	var pixel := Vector2i(point / map.world_size * Vector2(image.get_size()))
	image.fill_rect(Rect2i(pixel - Vector2i(diameter / 2, diameter / 2), Vector2i(diameter, diameter)), color)
