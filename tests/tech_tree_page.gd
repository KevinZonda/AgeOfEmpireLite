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
		var row: HBoxContainer = game.player_list.get_child(0)
		var view_button: Button
		for child in row.get_children():
			if child is Button and child.text == "查看科技树": view_button = child
		assert(view_button != null, "each civilization selector needs a tech tree button")
		view_button.pressed.emit()
		await process_frame
		assert(game.tech_tree_overlay != null and game.tech_tree_overlay.visible)
		assert(not game.menu_panel.visible)
		var labels: Array[String] = []
		for child in game.tech_tree_overlay.find_children("*", "Label", true, false): labels.append(child.text)
		assert(labels.any(func(value: String) -> bool: return value.contains(GameData.CIVILIZATIONS[civilization]["label"] + "  ·  科技树")))
		assert(labels.any(func(value: String) -> bool: return value.contains("I  黑暗时代")))
		assert(labels.any(func(value: String) -> bool: return value.contains("IV  帝王时代")))
		var unique_unit: String = {"English": "长弓兵", "French": "皇家骑士", "Chinese": "诸葛弩"}[civilization]
		assert(labels.any(func(value: String) -> bool: return value.contains(unique_unit)), "civilization units should come from the game data")
		var landmark: String = {"English": "议会厅", "French": "骑兵学校", "Chinese": "翰林院"}[civilization]
		assert(labels.any(func(value: String) -> bool: return value.contains(landmark)), "civilization landmarks should come from the game data")
		game._close_tech_tree()
		assert(game.tech_tree_overlay == null and game.menu_panel.visible)
		assert(game.lobby_players[0]["civilization"] == civilization)
	game.free()
	print("TECH_TREE_PAGE_OK")
	quit()
