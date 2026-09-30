extends RefCounted

# Persisted user preferences; rendering and window operations are delegated by callers.
const SETTINGS_PATH := "user://settings.cfg"
const LEGACY_DISPLAY_SETTINGS_PATH := "user://display.cfg"
const UI_SCALE_OPTIONS := [0.75, 1.0, 1.25, 1.5]
const TEXT_SCALE_OPTIONS := [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
const MINIMAP_SIZE_OPTIONS := [160, 216, 264]
const HEALTH_BAR_MODES := ["always", "damaged", "changed"]

var selected_view_mode_25d := false
var ui_scale := 1.0
var text_scale := 1.0
var minimap_size := 216
var show_building_icons := true
var show_building_names := true
var show_fps := false
var health_bar_mode := "damaged"
var windowed_resolution := Vector2i.ZERO
var adaptive_resolution_enabled := false
var fullscreen_enabled := false
var edge_scroll_enabled := true
var zoom_gesture_enabled := true

func save(fullscreen: bool, path: String = SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "window_size", windowed_resolution)
	config.set_value("display", "adaptive_resolution", adaptive_resolution_enabled)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "view_mode_25d", selected_view_mode_25d)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "text_scale", text_scale)
	config.set_value("display", "minimap_size", minimap_size)
	config.set_value("display", "show_building_icons", show_building_icons)
	config.set_value("display", "show_building_names", show_building_names)
	config.set_value("display", "show_fps", show_fps)
	config.set_value("display", "health_bar_mode", health_bar_mode)
	config.set_value("controls", "edge_scroll_enabled", edge_scroll_enabled)
	config.set_value("controls", "zoom_gesture_enabled", zoom_gesture_enabled)
	return config.save(path)

func load_preferences(display) -> void:
	windowed_resolution = display.game.get_window().size
	if DisplayServer.get_name() == "headless": return
	var config := read_config()
	if config == null: return
	apply_preferences(config)
	# The browser owns the canvas size; fullscreen needs a fresh user gesture.
	if OS.has_feature("web"): return
	var resolution: Variant = config.get_value("display", "window_size", Vector2i.ZERO)
	if bool(config.get_value("display", "adaptive_resolution", false)):
		display._apply_window_resolution(Vector2i.ZERO, false)
	elif resolution is Vector2i and resolution.x > 0 and resolution.y > 0:
		var usable := DisplayServer.screen_get_usable_rect(display.game.get_window().current_screen).size
		if resolution.x <= usable.x and resolution.y <= usable.y:
			windowed_resolution = resolution
			display._apply_window_resolution(resolution, false)
	if bool(config.get_value("display", "fullscreen", false)):
		display._apply_window_mode(true, false)

func read_config(path: String = SETTINGS_PATH, legacy_path: String = LEGACY_DISPLAY_SETTINGS_PATH) -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(path) != OK and config.load(legacy_path) != OK: return null
	return config

func apply_preferences(config: ConfigFile) -> void:
	selected_view_mode_25d = bool(config.get_value("display", "view_mode_25d", false))
	show_building_icons = bool(config.get_value("display", "show_building_icons", true))
	show_building_names = bool(config.get_value("display", "show_building_names", true))
	show_fps = bool(config.get_value("display", "show_fps", false))
	var saved_health_bar_mode: String = str(config.get_value("display", "health_bar_mode", "damaged"))
	health_bar_mode = saved_health_bar_mode if HEALTH_BAR_MODES.has(saved_health_bar_mode) else "damaged"
	var saved_ui_scale: float = float(config.get_value("display", "ui_scale", 1.0))
	var saved_text_scale: float = float(config.get_value("display", "text_scale", 1.0))
	var saved_minimap_size: int = int(config.get_value("display", "minimap_size", 216))
	ui_scale = saved_ui_scale if UI_SCALE_OPTIONS.has(saved_ui_scale) else 1.0
	text_scale = saved_text_scale if TEXT_SCALE_OPTIONS.has(saved_text_scale) else 1.0
	minimap_size = saved_minimap_size if MINIMAP_SIZE_OPTIONS.has(saved_minimap_size) else 216
	edge_scroll_enabled = bool(config.get_value("controls", "edge_scroll_enabled", true))
	zoom_gesture_enabled = bool(config.get_value("controls", "zoom_gesture_enabled", true))
