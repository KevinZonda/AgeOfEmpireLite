extends SceneTree

const NavalVisual = preload("res://scripts/entities/visuals/naval_visual.gd")
const HumanoidVisual = preload("res://scripts/entities/visuals/humanoid_visual.gd")
const SupportVisual = preload("res://scripts/entities/visuals/support_infantry_visual.gd")
const RangedVisual = preload("res://scripts/entities/visuals/ranged_infantry_visual.gd")
const CavalryVisual = preload("res://scripts/entities/visuals/cavalry_visual.gd")
const Figure = preload("res://scripts/entities/visuals/unit_figure_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var figure_count := 0
	for kind in GameData.UNITS:
		var tags: Array = GameData.UNITS[kind]["tags"]
		var owners := int(tags.has("siege")) + int(NavalVisual.handles(kind)) + int(SupportVisual.handles(kind)) + int(RangedVisual.handles(kind)) + int(CavalryVisual.handles(kind)) + int(HumanoidVisual.handles(kind))
		assert(owners == 1, "%s needs exactly one battlefield visual" % kind)
		assert(Figure.handles(kind) == (not tags.has("siege") and not tags.has("naval")), "all human and mounted units must use articulated figures")
		figure_count += int(Figure.handles(kind))
	assert(figure_count == 19)
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
