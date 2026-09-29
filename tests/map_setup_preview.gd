extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._show_setup_menu()
	assert(game.map_seed_input.text.is_empty())
	assert(game.menu_ui._selected_setup_seed() == -1)
	var preview: TextureRect = game.menu_ui.map_preview_texture
	assert(preview.texture != null)
	await process_frame
	var settings_column: VBoxContainer = preview.get_parent()
	assert(preview.get_global_rect().end.x <= settings_column.get_global_rect().end.x)
	assert(preview.get_global_rect().position.y < game.map_style_choice.get_global_rect().position.y)
	assert(preview.get_global_rect().end.y <= game.get_viewport_rect().end.y)
	var original := preview.texture.get_image().get_data()
	game.map_style_choice.select(3)
	game.map_style_choice.item_selected.emit(3)
	await create_timer(0.2).timeout
	assert(preview.texture.get_image().get_data() != original, "map style must update the preview")
	game.map_size_choice.select(1)
	game.map_size_choice.item_selected.emit(1)
	await create_timer(0.2).timeout
	assert(preview.texture.get_width() == 240, "large map must use the larger terrain grid")
	var two_player_image := preview.texture.get_image().get_data()
	game.add_player_button.pressed.emit()
	await create_timer(0.2).timeout
	assert(preview.texture.get_image().get_data() != two_player_image, "player count must update spawn positions")
	var illustrative_image := preview.texture.get_image().get_data()
	game.map_seed_input.text = "12345"
	game.map_seed_input.text_changed.emit("12345")
	assert(game.menu_ui._selected_setup_seed() == 12345)
	assert(preview.texture.get_image().get_data() == illustrative_image, "match seed must not reveal the real map")
	assert(game.menu_ui.map_preview_caption.text == "示意地图 · 种子 0")
	game.free()
	print("MAP_SETUP_PREVIEW_OK")
	quit()
