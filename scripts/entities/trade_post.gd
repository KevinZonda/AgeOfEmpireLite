class_name RtsTradePost
extends Node2D
const RtsUiTypography = preload("res://scripts/ui/typography.gd")
const TradePostVisual = preload("res://scripts/entities/visuals/trade_post_visual.gd")

var game: Node2D
var visual := TradePostVisual.new()

func contains(point: Vector2) -> bool:
	if game != null and game.view_mode_25d:
		var canvas := get_viewport().get_canvas_transform()
		var local: Vector2 = canvas.basis_xform(point - position - RtsIsoProjection.ground_lift(game, position)) / game.camera.zoom.x
		return visual.contains(local, true)
	return visual.contains(point - position, false)

func _draw() -> void:
	var isometric: bool = game != null and game.view_mode_25d
	var canvas := get_viewport().get_canvas_transform()
	var ground_lift := Vector2.ZERO
	var zoom: float = game.camera.zoom.x if game != null else canvas.x.length()
	if isometric:
		ground_lift = RtsIsoProjection.ground_lift(game, position)
		draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift, zoom))
	visual.draw(self, isometric)
	draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift))
	var font := ThemeDB.fallback_font
	if font != null:
		var font_size: int = RtsUiTypography.world_caption_size(game)
		var label_width := font.get_string_size("贸易站", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var label_y := visual.bounds(isometric).end.y * zoom + font_size + 6.0
		draw_string(font, Vector2(-label_width * 0.5, label_y), "贸易站", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)
