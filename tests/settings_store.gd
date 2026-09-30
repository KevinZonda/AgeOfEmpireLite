extends SceneTree

const SettingsStore = preload("res://scripts/ui/settings_store.gd")

func _initialize() -> void:
	var preferences = SettingsStore.new()
	var path := "user://settings_store_regression.cfg"
	var legacy_path := "user://settings_store_legacy_regression.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	var legacy := ConfigFile.new()
	legacy.set_value("display", "ui_scale", 1.25)
	legacy.set_value("display", "text_scale", 2.0)
	legacy.set_value("display", "minimap_size", 264)
	legacy.set_value("display", "health_bar_mode", "changed")
	legacy.set_value("display", "view_mode_25d", true)
	legacy.set_value("controls", "edge_scroll_enabled", false)
	assert(legacy.save(legacy_path) == OK)
	var restored: ConfigFile = preferences.read_config(path, legacy_path)
	assert(restored != null, "a missing settings file should fall back to the legacy display file")
	preferences.apply_preferences(restored)
	assert(preferences.ui_scale == 1.25 and preferences.text_scale == 2.0)
	assert(preferences.minimap_size == 264 and preferences.health_bar_mode == "changed")
	assert(preferences.selected_view_mode_25d and not preferences.edge_scroll_enabled)
	assert(preferences.show_building_icons and preferences.show_building_names and preferences.zoom_gesture_enabled)
	preferences.windowed_resolution = Vector2i(1440, 810)
	preferences.adaptive_resolution_enabled = true
	preferences.show_fps = true
	assert(preferences.save(true, path) == OK)
	var saved: ConfigFile = preferences.read_config(path, legacy_path)
	assert(saved.get_value("display", "window_size") == Vector2i(1440, 810))
	assert(saved.get_value("display", "adaptive_resolution") and saved.get_value("display", "fullscreen"))
	assert(saved.get_value("display", "show_fps"))
	saved.set_value("display", "ui_scale", 9.0)
	saved.set_value("display", "text_scale", -1.0)
	saved.set_value("display", "minimap_size", 999)
	saved.set_value("display", "health_bar_mode", "unknown")
	preferences.apply_preferences(saved)
	assert(preferences.ui_scale == 1.0 and preferences.text_scale == 1.0, "unsupported scale values should use defaults")
	assert(preferences.minimap_size == 216 and preferences.health_bar_mode == "damaged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	print("SETTINGS_STORE_OK")
	quit()
