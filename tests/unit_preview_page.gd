extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
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
	var preview_panel: Control = page.get_child(0)
	assert(preview_panel.get_global_rect().end.x <= game.get_viewport_rect().size.x)
	assert(preview_panel.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	assert(page.preview_unit is RtsUnit and page.preview_unit.kind == "villager")
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
