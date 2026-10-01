extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.ui_scale = 1.0
	game.text_scale = 1.0
	root.add_child(game)
	await process_frame
	var entry: Button
	for child in game.menu_panel.get_child(0).get_children():
		if child is Button and child.text == "单 位 预 览": entry = child
	assert(entry != null, "the start menu needs a unit preview entry")
	entry.pressed.emit()
	await process_frame
	var page = game.unit_preview_page
	assert(page != null and page.visible and not game.menu_panel.visible)
	var page_title: Label = page.find_children("*", "Label", true, false).filter(func(node: Node) -> bool: return (node as Label).text == "单 位 预 览")[0] as Label
	assert(page_title.get_theme_font_size("font_size") == 28, "preview should use the shared page title size")
	var preview_panel: Control = page.get_child(0)
	assert(preview_panel.get_global_rect().end.x <= game.get_viewport_rect().size.x)
	assert(preview_panel.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	assert(page.preview_unit is Node2D and not page.preview_unit is RtsUnit and page.preview_unit.kind == "villager", "preview should render a visual snapshot without a simulation unit")
	assert(page.roster.has("battering_ram") and page.roster.has("siege_tower"))
	page.selected_kind = "spearman"
	page._refresh_selection()
	var base_damage := float(page._resolved_stats()["damage"])
	page._enable_research("forged_weapons")
	page._refresh_selection()
	assert(float(page._resolved_stats()["damage"]) > base_damage, "research should update displayed unit values")
	page.age_choice.select(3)
	page.age_choice.item_selected.emit(3)
	assert(page.age == 4)
	page.preview_mode_choice.select(0)
	page.preview_mode_choice.item_selected.emit(0)
	assert(not page.preview_context.view_mode_25d)
	var chinese_index := GameData.CIVILIZATIONS.keys().find("Chinese")
	page.civilization_choice.select(chinese_index)
	page.civilization_choice.item_selected.emit(chinese_index)
	assert(page.roster.has("zhuge_nu") and page.roster.has("imperial_official"))
	assert(not page.roster.has("longbow"))
	page.selected_kind = "battering_ram"
	page._refresh_selection()
	var normal_ram_hp := float(page._resolved_stats()["hp"])
	page.producer_landmark = "zh_clocktower"
	page._refresh_selection()
	assert(float(page._resolved_stats()["hp"]) > normal_ram_hp, "landmark production bonus should update unit stats")
	page.selected_kind = "bombard"
	page.age = 4
	page._refresh_selection()
	for large_scale in [1.5, 1.75, 2.0]:
		game.text_scale = large_scale
		game._apply_ui_scales()
		await process_frame
		assert(page_title.get_theme_font_size("font_size") == roundi(28 * large_scale))
		for node in page.find_children("*", "Label", true, false):
			var label := node as Label
			assert(label.get_theme_font_size("font_size") >= roundi(14 * large_scale), "preview labels should use at least the shared caption size")
			if label.get_parent() == page.stats_box:
				assert(label.get_combined_minimum_size().x <= label.size.x + 1.0, "preview stat text should wrap inside its column")
	var preview_font: Font = page.stats_box.get_child(0).get_theme_font("font")
	for character in "远程护甲减伤攻城":
		assert(preview_font.has_char(character.unicode_at(0)), "the UI font should contain every preview stat glyph")
		assert(ThemeDB.fallback_font.has_char(character.unicode_at(0)), "world labels should use the bundled Chinese font")
	var fallback_stats := RtsStatResolver.unit("English", "bombard", 1)
	assert(fallback_stats["profiles"]["ranged"]["bonuses"][0]["source_label"] == "对建筑", "fallback attack bonuses should use readable Chinese labels")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.unit_preview_page == null and game.menu_panel.visible)
	game.free()
	print("UNIT_PREVIEW_PAGE_OK")
	quit()
