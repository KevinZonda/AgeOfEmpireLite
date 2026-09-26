class_name RtsWeather
extends Node2D

var game: Node2D
var world_size := Vector2.ZERO
var rain_active := true
var weather_remaining := 12.0
var elapsed := 0.0
var drops := PackedVector2Array()
var speeds := PackedFloat32Array()
var rng := RandomNumberGenerator.new()

func setup(game_ref: Node2D, seed_value: int, map_size: Vector2) -> void:
	game = game_ref
	world_size = map_size
	rng.seed = seed_value + 99173
	rain_active = true
	weather_remaining = rng.randf_range(10.0, 16.0)
	elapsed = 0.0
	drops.clear()
	speeds.clear()
	for i in 520:
		drops.append(Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, world_size.y)))
		speeds.append(rng.randf_range(360.0, 580.0))
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.started or game.paused or game.game_over: return
	elapsed += delta
	weather_remaining -= delta
	var changed := false
	if weather_remaining <= 0.0:
		rain_active = not rain_active
		weather_remaining = rng.randf_range(10.0, 16.0) if rain_active else rng.randf_range(15.0, 25.0)
		changed = true
	if rain_active or changed: queue_redraw()

func _draw() -> void:
	if not rain_active: return
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.27, 0.40, 0.51, 0.07))
	for i in drops.size():
		var origin := drops[i]
		var point := Vector2(fposmod(origin.x - elapsed * speeds[i] * 0.27, world_size.x), fposmod(origin.y + elapsed * speeds[i], world_size.y))
		draw_line(point, point + Vector2(-5, 16), Color(0.72, 0.86, 0.96, 0.38), 1.3)
