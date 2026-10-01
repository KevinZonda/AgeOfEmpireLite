class_name RtsWeather
extends Node2D

# World actors remain below this layer; HUD canvases and selection overlays stay above.
const RAIN_Z_INDEX := 4090
const MAX_DROPS := 320
const PIXELS_PER_DROP := 6500.0
const FADE_SECONDS := 1.4
const RAIN_FRAME_SECONDS := 1.0 / 60.0
const WIND := -0.14
const FAR_COLOR := Color(0.72, 0.82, 0.89, 0.19)
const NEAR_COLOR := Color(0.78, 0.87, 0.94, 0.34)

# Presentation is independent of the 30 Hz match clock, with a 60 Hz draw cap.
# One renderer replaces per-drop nodes; its packed buffers are reused.
class RainOverlay extends Node2D:
	var weather: RtsWeather
	var redraw_elapsed := 0.0
	func _process(delta: float) -> void:
		if not is_visible_in_tree() or not weather._running(): return
		weather._rain_time += delta
		redraw_elapsed += delta
		# Keep animation at 60 Hz on high-refresh displays. Camera changes still
		# refresh immediately so the screen-space batch cannot drift with the map.
		if redraw_elapsed + 0.000001 < RAIN_FRAME_SECONDS and get_viewport().get_canvas_transform() == weather._canvas_snapshot: return
		redraw_elapsed = fmod(redraw_elapsed, RAIN_FRAME_SECONDS)
		queue_redraw()
	func _draw() -> void:
		weather._draw_rain(self)

var game: Node2D
var world_size := Vector2.ZERO
var rain_active := true
var weather_remaining := 12.0
var elapsed := 0.0
var rain_intensity := 0.0
var drops := PackedVector2Array()
var speeds := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var _far_segments := PackedVector2Array()
var _near_segments := PackedVector2Array()
var _viewport_size := Vector2.ZERO
var _screen_origins := PackedVector2Array()
var _velocities := PackedVector2Array()
var _streaks := PackedVector2Array()
var _rain_time := 0.0
var _canvas_snapshot := Transform2D.IDENTITY
var _renderer: RainOverlay

func _ready() -> void:
	z_index = RAIN_Z_INDEX
	_renderer = RainOverlay.new()
	_renderer.weather = self
	add_child(_renderer)
	_renderer.hide()

func setup(game_ref: Node2D, seed_value: int, map_size: Vector2) -> void:
	game = game_ref
	world_size = map_size
	rng.seed = seed_value + 99173
	rain_active = true
	weather_remaining = rng.randf_range(10.0, 16.0)
	elapsed = 0.0
	_rain_time = 0.0
	_renderer.redraw_elapsed = 0.0
	rain_intensity = 0.0
	drops.clear()
	speeds.clear()
	# Resolution and camera changes cannot consume the weather-cycle RNG.
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.seed = seed_value + 123997
	for i in MAX_DROPS:
		drops.append(Vector2(drop_rng.randf(), drop_rng.randf()))
		speeds.append(drop_rng.randf_range(330.0, 570.0))
	_resize_buffers(get_viewport_rect().size)
	_sync_intensity()

func _running() -> bool:
	return game != null and game.started and not game.paused and not game.game_over

func _process(delta: float) -> void:
	if not _running(): return
	elapsed += delta
	weather_remaining -= delta
	if weather_remaining <= 0.0:
		rain_active = not rain_active
		weather_remaining = rng.randf_range(10.0, 16.0) if rain_active else rng.randf_range(15.0, 25.0)
	rain_intensity = move_toward(rain_intensity, 1.0 if rain_active else 0.0, delta / FADE_SECONDS)
	_sync_intensity()

func _sync_intensity() -> void:
	if _renderer == null: return
	if _renderer.modulate.a != rain_intensity: _renderer.modulate.a = rain_intensity
	var drawing := rain_intensity > 0.0
	if _renderer.visible != drawing: _renderer.visible = drawing
	if _renderer.is_processing() != drawing: _renderer.set_process(drawing)

func _resize_buffers(size: Vector2) -> void:
	_viewport_size = size
	var count := clampi(roundi(size.x * size.y / PIXELS_PER_DROP), 48, MAX_DROPS)
	_far_segments.resize((count - count / 3) * 2)
	_near_segments.resize((count / 3) * 2)
	_screen_origins.resize(count)
	_velocities.resize(count)
	_streaks.resize(count)
	var far_count := _far_segments.size() / 2
	for i in count:
		var near := i >= far_count
		_screen_origins[i] = drops[i] * (size + Vector2(32, 32))
		_velocities[i] = Vector2(WIND, 1.0) * speeds[i] * (1.0 if near else 0.65)
		_streaks[i] = Vector2(WIND, 1.0) * (18.0 if near else 11.0)

func _draw_rain(item: CanvasItem) -> void:
	if drops.is_empty() or rain_intensity <= 0.0: return
	var size := get_viewport_rect().size
	if size != _viewport_size: _resize_buffers(size)
	_canvas_snapshot = get_viewport().get_canvas_transform()
	var inverse := _canvas_snapshot.affine_inverse()
	# Cancel map rotation, zoom and pan once for the entire screen-space batch.
	item.draw_set_transform_matrix(inverse)
	# Subtle storm shading also reaches roofs, instead of tinting only the ground.
	item.draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.12, 0.17, 0.09))
	_build_rain_segments(inverse)
	item.draw_multiline(_far_segments, FAR_COLOR, 0.75)
	item.draw_multiline(_near_segments, NEAR_COLOR, 1.15)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _build_rain_segments(inverse: Transform2D) -> void:
	var height := _viewport_size.y + 32.0
	var width := _viewport_size.x + 32.0
	var far_count := _far_segments.size() / 2
	var count := far_count + _near_segments.size() / 2
	var footprint := Rect2(Vector2.ZERO, world_size)
	var fog = game.fog
	for i in count:
		var near := i >= far_count
		var position := _screen_origins[i] + _velocities[i] * _rain_time
		var point := Vector2(fposmod(position.x, width) - 16.0, fposmod(position.y, height) - 16.0)
		var end := point + _streaks[i]
		var ground := inverse * end
		# Do not draw rain over uncharted terrain or outside the map.
		if not footprint.has_point(ground) or (fog != null and not fog.is_explored(0, ground)):
			point = Vector2(-64, -64)
			end = point
		if near:
			var index := (i - far_count) * 2
			_near_segments[index] = point
			_near_segments[index + 1] = end
		else:
			_far_segments[i * 2] = point
			_far_segments[i * 2 + 1] = end
