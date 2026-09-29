extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._show_setup_menu()
	for civilization in ["English", "French", "Chinese"]:
		game.lobby_players[0]["civilization"] = civilization
		game._refresh_player_rows()
		await process_frame
		await process_frame
		var row: HBoxContainer = game.player_list.get_child(0)
		assert(row.get_combined_minimum_size().x <= game.player_list.size.x + 1.0, "tech tree button should fit in the player column")
		var view_button: Button
		for child in row.get_children():
			if child is Button and child.text == "科技树": view_button = child
		assert(view_button != null, "each civilization selector needs a tech tree button")
		view_button.pressed.emit()
		await process_frame
		assert(game.tech_tree_overlay != null and game.tech_tree_overlay.visible)
		if civilization == "English":
			game.text_scale = 1.5
			game._apply_ui_scales()
			var tree_title: Label
			for node in game.tech_tree_overlay.find_children("*", "Label", true, false):
				if (node as Label).text.contains("英格兰  ·  科技树"):
					tree_title = node
					break
			assert(tree_title != null and tree_title.get_theme_font_size("font_size") == 39, "tech tree labels should follow text scale")
			assert(game.tech_tree_civilization_choice.get_popup().get_theme_font_size("font_size") == 24, "tech tree dropdown items should follow text scale")
			assert(ThemeDB.get_default_theme().get_font_size("font_size", "TooltipLabel") == 24, "tech tree tooltips should follow text scale")
			game.text_scale = 1.0
			game._apply_ui_scales()
			assert(tree_title.get_theme_font_size("font_size") == 26)
			assert(game.tech_tree_civilization_choice.get_popup().get_theme_font_size("font_size") == 16)
		assert(game.tech_tree_overlay.get_child(0).get_global_rect().end.x <= game.get_viewport_rect().size.x)
		assert(game.tech_tree_overlay.get_child(0).get_global_rect().end.y <= game.get_viewport_rect().size.y)
		assert(not game.menu_panel.visible)
		var labels: Array[String] = []
		for child in game.tech_tree_overlay.find_children("*", "Label", true, false): labels.append(child.text)
		assert(labels.any(func(value: String) -> bool: return value.contains(GameData.CIVILIZATIONS[civilization]["label"] + "  ·  科技树")))
		assert(labels.any(func(value: String) -> bool: return value.contains("I  黑暗时代")))
		assert(labels.any(func(value: String) -> bool: return value.contains("IV  帝王时代")))
		assert(not labels.any(func(value: String) -> bool: return value.contains("横向查看建筑")), "the extra reading hint should be removed")
		for node in game.tech_tree_overlay.find_children("*", "Button", true, false):
			var button := node as Button
			assert(not RtsTechTreePage.AGE_LABELS.has(button.text), "the redundant era navigation should be removed")
		var unique_unit: String = {"English": "长弓兵", "French": "皇家骑士", "Chinese": "诸葛弩"}[civilization]
		assert(labels.any(func(value: String) -> bool: return value.contains(unique_unit)), "civilization units should come from the game data")
		if civilization != "Chinese": assert(not labels.any(func(value: String) -> bool: return value.contains("朝廷命官")))
		var landmark: String = {"English": "议会厅", "French": "骑兵学校", "Chinese": "翰林院"}[civilization]
		assert(labels.any(func(value: String) -> bool: return value.contains(landmark)), "civilization landmarks should come from the game data")
		assert(game.tech_tree_civilization_choice.item_count == 3)
		assert(game.tech_tree_page.age_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO)
		assert(game.tech_tree_page.building_columns[0] == "town_center")
		assert(game.tech_tree_page.building_columns.size() == RtsTechTree.BUILD_MENU.size() + 1)
		for age_row in game.tech_tree_page.age_pages:
			assert(age_row.visible and age_row.get_child_count() == game.tech_tree_page.building_columns.size(), "every era should have one cell per building")
		assert(game.tech_tree_page.age_pages[0].get_child(0).position.x == game.tech_tree_page.age_pages[1].get_child(0).position.x, "building columns should align between eras")
		game.tech_tree_page.age_scroll.scroll_horizontal = 400
		game.tech_tree_page.age_scroll.scroll_vertical = 200
		assert(is_equal_approx(game.tech_tree_page.matrix_header.position.x, -400.0), "building headings should stay visible while scrolling")
		assert(is_equal_approx(game.tech_tree_page.age_rail.position.y, -200.0), "era labels should stay visible while scrolling")
		game.tech_tree_page.show_age(4)
		await process_frame
		assert(game.tech_tree_page.selected_age == 4 and game.tech_tree_page.age_pages[3].visible)
		assert(game.tech_tree_page.age_scroll.scroll_vertical > 200, "the matrix should scroll to the requested era")
		assert(game.tech_tree_page.age_pages[0].visible, "all era rows should remain visible")
		game._close_tech_tree()
		assert(game.tech_tree_overlay == null and game.menu_panel.visible)
		assert(game.lobby_players[0]["civilization"] == civilization)
	game.lobby_players[0]["civilization"] = "English"
	game._show_home_menu()
	await process_frame
	var home_button: Button
	for child in game.menu_panel.get_child(0).get_children():
		if child is Button and child.text == "查看科技树": home_button = child
	assert(home_button != null, "home screen should have a tech tree entry")
	home_button.pressed.emit()
	assert(game.tech_tree_overlay != null)
	game.tech_tree_page.show_age(3)
	var chinese_index := GameData.CIVILIZATIONS.keys().find("Chinese")
	game.tech_tree_civilization_choice.select(chinese_index)
	game.tech_tree_civilization_choice.item_selected.emit(chinese_index)
	await process_frame
	assert(game.tech_tree_civilization_choice.selected == chinese_index)
	assert(game.tech_tree_page.selected_age == 3, "switching civilization should keep the selected era")
	var switched_labels: Array[String] = []
	for child in game.tech_tree_overlay.find_children("*", "Label", true, false): switched_labels.append(child.text)
	assert(switched_labels.any(func(value: String) -> bool: return value.contains("中国  ·  科技树")))
	assert(switched_labels.any(func(value: String) -> bool: return value.contains("诸葛弩")))
	assert(game.lobby_players[0]["civilization"] == "English", "browsing should preserve the chosen player civilization")
	var return_button: Button
	for child in game.tech_tree_overlay.find_children("*", "Button", true, false):
		if child.text == "返回": return_button = child
	assert(return_button != null)
	return_button.pressed.emit()
	assert(game.menu_panel.visible)
	game.free()
	print("TECH_TREE_PAGE_OK")
	quit()
