class_name RtsSacredSite
extends Node2D

const Geometry = preload("res://scripts/entities/visuals/sacred_site_geometry.gd")
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const Typography = preload("res://scripts/ui/typography.gd")
const NEUTRAL_FLAG_COLOR := Color("d4c69e")

# Display only: the objective manager owns all capture and victory state.
var game: Node2D
var site: Dictionary = {}
var site_index := 0
var geometry
var geometry_key := ""
var flag_color := NEUTRAL_FLAG_COLOR
var _visual_signature: Array = []
var _sync_timer := 0.0

func setup(game_ref: Node2D, site_dictionary: Dictionary, index: int) -> void:
	game = game_ref
	site = site_dictionary
	site_index = index
	z_as_relative = false
	sync_visual()

static func isometric_for(game_ref: Node2D) -> bool:
	return game_ref != null and game_ref.get("view_mode_25d") == true

static func zoom_for(game_ref: Node2D, canvas: Transform2D) -> float:
	var camera: Variant = game_ref.get("camera") if game_ref != null else null
	return camera.zoom.x if camera is Camera2D else maxf(canvas.x.length(), 0.01)

static func ground_lift_for(game_ref: Node2D, point: Vector2) -> Vector2:
	if not isometric_for(game_ref): return Vector2.ZERO
	var world: Variant = game_ref.get("world_map")
	var camera: Variant = game_ref.get("camera")
	if world == null or not world.has_method("elevation_at") or not camera is Camera2D: return Vector2.ZERO
	return RtsIsoProjection.ground_lift(game_ref, point)

static func owner_color(game_ref: Node2D, owner_id: int) -> Color:
	if owner_id < 0 or game_ref == null: return NEUTRAL_FLAG_COLOR
	if game_ref.has_method("player_color"): return game_ref.player_color(owner_id)
	var civilizations: Variant = game_ref.get("civilizations")
	if civilizations is Array and owner_id < civilizations.size():
		return GameData.CIVILIZATIONS.get(civilizations[owner_id], {}).get("color", NEUTRAL_FLAG_COLOR)
	return NEUTRAL_FLAG_COLOR

const SYNC_INTERVAL := 0.15

func _process(delta: float) -> void:
	_sync_timer -= delta
	if _sync_timer > 0.0: return
	_sync_timer = SYNC_INTERVAL
	sync_visual()

func sync_visual() -> void:
	if site.is_empty(): return
	position = site["position"]
	flag_color = owner_color(game, int(site.get("owner_id", -1)))
	var key := "%d:%s" % [site_index, flag_color.to_html(true)]
	if geometry == null or key != geometry_key:
		geometry = Geometry.new(flag_color, site_index)
		geometry_key = key
	var isometric := isometric_for(game)
	z_index = clampi(roundi((position.x + position.y) * 0.5), 0, 2800) if isometric else 0
	# Sites are known objectives, just as their old ground markers were. Dim
	# the known ruins outside vision without revealing or altering capture state.
	var fog: Variant = game.get("fog") if game != null else null
	var dimmed: bool = fog != null and fog.get("active") == true and fog.has_method("can_see") and not fog.can_see(0, position)
	modulate = Color(0.48, 0.48, 0.48, 1) if dimmed else Color.WHITE
	if not is_inside_tree(): return
	var canvas := get_viewport().get_canvas_transform()
	var signature: Array = [geometry_key, canvas.x, canvas.y, zoom_for(game, canvas), isometric, ground_lift_for(game, position), Typography.world_caption_size(game)]
	if signature != _visual_signature:
		_visual_signature = signature
		queue_redraw()
		# The manager may stop simulation processing while paused; its ground
		# overlay still follows presentation changes driven by this display node.
		var manager := get_parent()
		if manager is CanvasItem: manager.queue_redraw()

func _draw() -> void:
	if geometry == null: return
	var canvas := get_viewport().get_canvas_transform()
	var zoom := zoom_for(game, canvas)
	var lift := ground_lift_for(game, position)
	var isometric := isometric_for(game)
	var polygons: Array = geometry.projected_faces(canvas, zoom, lift) if isometric else geometry.flat_faces
	var screen_bottom := -INF
	for polygon in polygons:
		FilledPolygon.draw(self, polygon["points"], polygon["color"])
		for point in polygon["points"]:
			screen_bottom = maxf(screen_bottom, canvas.basis_xform(point - lift).y)
	# Keep the site number upright and outside the ruins in either camera mode.
	var font := ThemeDB.fallback_font
	if font == null: return
	var label: String = ["I", "II", "III"][site_index] if site_index < 3 else str(site_index + 1)
	var font_size := Typography.world_caption_size(game)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_set_transform_matrix(RtsIsoProjection.upright(canvas, lift))
	var baseline := Vector2(-width * 0.5, maxf(screen_bottom, 0) + font_size + 5)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("343931"))
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("eee7cd"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
