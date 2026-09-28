extends SceneTree

const CharacterVisual = preload("res://scripts/entities/visuals/character_visual.gd")
const NavalVisual = preload("res://scripts/entities/visuals/naval_visual.gd")
const ChineseVisual = preload("res://scripts/entities/visuals/chinese_visual.gd")
const InfantryVisual = preload("res://scripts/entities/visuals/infantry_visual.gd")
const SupportVisual = preload("res://scripts/entities/visuals/support_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for kind in GameData.UNITS:
		var tags: Array = GameData.UNITS[kind]["tags"]
		var owners := int(tags.has("siege")) + int(CharacterVisual.handles(kind)) + int(NavalVisual.handles(kind)) + int(ChineseVisual.handles(kind)) + int(InfantryVisual.handles(kind)) + int(SupportVisual.handles(kind))
		assert(owners == 1, "%s needs exactly one battlefield visual" % kind)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.menu_ui._show_unit_preview("English")
	var page = game.unit_preview_page
	for civilization in GameData.CIVILIZATIONS:
		var civilization_index := GameData.CIVILIZATIONS.keys().find(civilization)
		page.civilization_choice.select(civilization_index)
		page.civilization_choice.item_selected.emit(civilization_index)
		for kind in page.roster:
			page.selected_kind = kind
			page._refresh_selection()
			assert(page.preview_unit.kind == kind)
			for mode in 2:
				page.preview_mode_choice.select(mode)
				page.preview_mode_choice.item_selected.emit(mode)
				assert(page.preview_context.view_mode_25d == (mode == 1))
				await process_frame
	game.free()
	print("UNIT_VISUAL_COVERAGE_OK")
	quit()
