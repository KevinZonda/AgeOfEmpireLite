extends RefCounted

const WINDOW_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1440, 810), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var game: Node2D
var settings
var adaptive_usable_rect := Rect2i()
var adaptive_resolution_check_timer := 0.0

func _init(game_ref: Node2D, preference_store) -> void:
	game = game_ref
	settings = preference_store

static func _fit_window_size_to_screen(usable_size: Vector2i) -> Vector2i:
	var minimum := Vector2i(960, 540)
	return Vector2i(
		mini(usable_size.x, maxi(minimum.x, floori(usable_size.x * 0.9))),
		mini(usable_size.y, maxi(minimum.y, floori(usable_size.y * 0.9)))
	)

func _adaptive_window_resolution() -> Vector2i:
	if DisplayServer.get_name() == "headless": return game.get_window().size
	return _fit_window_size_to_screen(DisplayServer.screen_get_usable_rect(game.get_window().current_screen).size)

func _apply_window_resolution(resolution: Vector2i, save_setting := true) -> void:
	var adaptive := resolution == Vector2i.ZERO
	if not adaptive and not WINDOW_RESOLUTIONS.has(resolution) and resolution != settings.windowed_resolution and resolution != game.get_window().size: return
	var target := _adaptive_window_resolution() if adaptive else resolution
	var window := game.get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = target
	settings.windowed_resolution = target
	settings.adaptive_resolution_enabled = adaptive
	settings.fullscreen_enabled = false
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = usable.position + (usable.size - target) / 2
		adaptive_usable_rect = usable if adaptive else Rect2i()
	if game.started: game.call_deferred("_clamp_camera_position")
	if save_setting: settings.save(_window_is_fullscreen())

func _window_is_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless": return settings.fullscreen_enabled
	return game.get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func _apply_window_mode(fullscreen: bool, save_setting := true) -> void:
	settings.fullscreen_enabled = fullscreen
	if fullscreen:
		game.get_window().mode = Window.MODE_FULLSCREEN
	else:
		_apply_window_resolution(Vector2i.ZERO if settings.adaptive_resolution_enabled else settings.windowed_resolution, false)
	if game.started: game.call_deferred("_clamp_camera_position")
	if save_setting: settings.save(_window_is_fullscreen())

func tick(delta: float) -> void:
	if settings.adaptive_resolution_enabled and not _window_is_fullscreen() and DisplayServer.get_name() != "headless":
		adaptive_resolution_check_timer -= delta
		if adaptive_resolution_check_timer <= 0.0:
			adaptive_resolution_check_timer = 1.0
			if DisplayServer.screen_get_usable_rect(game.get_window().current_screen) != adaptive_usable_rect:
				_apply_window_resolution(Vector2i.ZERO, false)
