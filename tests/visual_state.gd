extends SceneTree

const BuildingState = preload("res://scripts/entities/visuals/building_visual_state.gd")
const UnitState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(400, 400))
	farm.farm_stage_progress = farm.FARM_SOW_WORK * 0.5
	var working_building_state = BuildingState.new()
	assert(BuildingState.capture(farm, working_building_state) == working_building_state)
	var building_state = BuildingState.capture(farm)
	var dimensions: Vector2 = building_state.dimensions
	var hp: float = building_state.hp
	farm.stats["size"] = Vector2(1, 1)
	farm.hp -= 25.0
	farm.farm_stage_progress = 0.0
	farm.production_queue.append({"kind": "training", "id": "villager"})
	assert(building_state.dimensions == dimensions and building_state.hp == hp)
	assert(building_state.crop_fraction == 0.5 and not building_state.has_production)
	assert(building_state.get("stats") == null and building_state.get("production_queue") == null)
	game.show_building_names = false
	building_state.update_view(game)
	assert(not building_state.show_building_names and building_state.hp == hp)
	var unit: RtsUnit = game.units[0]
	var working_unit_state = UnitState.new()
	assert(UnitState.capture(unit, working_unit_state) == working_unit_state)
	unit._face_direction(Vector2.LEFT * 20.0)
	unit._start_visual_action("attack", 0.4)
	unit.visual_action_timer = 0.2
	var unit_state = UnitState.capture(unit)
	assert(unit_state.action_progress == 0.5 and not unit_state.action_released)
	assert(not is_same(unit_state.tags, unit.stats["tags"]), "durable captures own their tag values")
	assert(is_same(working_unit_state.tags, unit.stats["tags"]), "explicit renderer reuse keeps the allocation-free tag view")
	var remembered_heading: Vector2 = unit_state.facing_direction
	unit._mark_visual_impact()
	unit._face_direction(Vector2.RIGHT * 20.0)
	var original_tags: Array = unit_state.tags.duplicate()
	unit.stats["tags"].append("snapshot_mutation")
	unit.visual_phase += 10.0
	unit.hp -= 5.0
	assert(UnitState.capture(unit, working_unit_state) == working_unit_state)
	assert(working_unit_state.visual_phase == unit.visual_phase)
	assert(working_unit_state.action_released and not unit_state.action_released)
	assert(unit_state.facing_direction == remembered_heading and unit_state.facing_direction != working_unit_state.facing_direction)
	assert(unit_state.tags == original_tags and unit_state.visual_phase != unit.visual_phase)
	assert(unit_state.hp != unit.hp and unit_state.get("passengers") == null)
	for state in [unit_state, building_state]:
		for property in state.get_property_list():
			if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				assert(not state.get(property["name"]) is Node, "snapshots must not retain live entities or game")
	var definition := {"radius": 18.0, "hp": 100.0, "tags": ["infantry"]}
	var preview_state = UnitState.preview("spearman", definition, Color("4e9bea"))
	definition["tags"].append("mutated")
	assert(preview_state.tags == ["infantry"] and preview_state.radius == 18.0 and not preview_state.show_health_bar)
	game.free()
	assert(unit_state.tags == original_tags and building_state.crop_fraction == 0.5, "snapshot must outlive its source")
	print("VISUAL_STATE_OK")
	quit()
