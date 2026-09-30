extends RefCounted

const Typography = preload("res://scripts/ui/typography.gd")

# A value snapshot. Memory keeps these values after the live building changes or dies.
# Texture assets are shared; no live building/game, production, or inventory is retained.
var kind := ""
var landmark_id := ""
var world_position := Vector2.ZERO
var dimensions := Vector2.ZERO
var wall_vertical := false
var civilization := "English"
var player_color := Color.WHITE
var label := ""
var building_icon: Texture2D
var hp := 1.0
var max_hp := 1.0
var health_bar_timer := 0.0
var build_remaining := 0.0
var build_total := 0.0
var crop_fraction := 0.0
var farm_stage := "sowing"
var has_production := false
var damage_flash_timer := 0.0
var foundation_height := 0.0
var corner_heights := PackedFloat64Array([0, 0, 0])
var view_mode_25d := false
var zoom := 1.0
var show_building_icons := true
var show_building_names := true
var show_health_bar := false
var caption_size := 14

static func capture(building, existing_state = null, include_terrain := true):
	var result = existing_state if existing_state != null else new()
	result.kind = building.kind
	result.landmark_id = building.landmark_id
	result.wall_vertical = building.wall_vertical
	result.building_icon = building.building_icon
	result.hp = building.hp
	result.max_hp = building.max_hp
	result.health_bar_timer = building.health_bar_timer
	result.build_remaining = building.build_remaining
	result.build_total = building.build_total
	result.damage_flash_timer = building.damage_flash_timer
	result.world_position = building.position
	result.dimensions = building.size()
	result.civilization = building.game.civilizations[building.owner_id]
	result.player_color = building.game.player_color(building.owner_id)
	result.label = building.display_label()
	result.crop_fraction = building.farm_crop_fraction()
	result.farm_stage = building.farm_stage
	result.has_production = not building.production_queue.is_empty()
	var map = building.game.world_map
	if include_terrain:
		result.foundation_height = 0.0
		result.corner_heights.fill(0.0)
	if include_terrain and map != null:
		var half: Vector2 = result.dimensions * 0.5
		result.foundation_height = map.elevation_at(building.position)
		var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
		for i in corners.size():
			var height: float = map.elevation_at(building.position + corners[i])
			result.foundation_height = maxf(result.foundation_height, height)
			if i > 0: result.corner_heights[i - 1] = maxf(0.0, height)
	result.update_view(building.game)
	return result

# Camera and display preferences remain current while remembered simulation values stay frozen.
func update_view(context: Node2D) -> void:
	view_mode_25d = context.view_mode_25d
	zoom = context.camera.zoom.x
	show_building_icons = context.get("show_building_icons") != false
	show_building_names = context.get("show_building_names") != false
	caption_size = Typography.world_caption_size(context)
	show_health_bar = context.should_show_health_bar(hp, max_hp, health_bar_timer)

func is_complete() -> bool:
	return build_remaining <= 0.0

func icon_size() -> float:
	return 24.0 if kind.ends_with("_wall") or kind.ends_with("_gate") or kind == "scout_camp" else 30.0

func isometric_height() -> float:
	if kind in ["landmark", "wonder"]: return 6.0
	if kind in ["university", "monastery"]: return 2.0
	var art_kind := visual_kind()
	if art_kind == "farm": return 0.0
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"): return 11.0
	if art_kind == "outpost": return 43.0
	if art_kind == "wonder": return 58.0
	if art_kind in ["town_center", "keep", "palace"]: return 42.0
	if art_kind in ["monastery", "university"]: return 34.0
	if art_kind == "mill": return 35.0
	if art_kind in ["lumber_camp", "mining_camp", "scout_camp", "dock"]: return 17.0
	if art_kind == "house": return 23.0
	return 26.0

func visual_feature_height() -> float:
	match kind:
		"town_center": return 22.0
		"lumber_camp": return 10.0
		"mining_camp": return 17.0
		"mill": return 12.0
		"blacksmith": return 18.0
		"siege_workshop": return 15.0
		"market": return 10.0
		"university": return 18.0
		"dock": return 18.0
		"outpost": return 10.0
		"stone_gate": return 21.0
		"palisade_gate": return 15.0
		"keep": return 34.0
		"monastery": return 44.0
	return 0.0

func visual_kind() -> String:
	if kind != "landmark": return kind
	match landmark_id:
		"eng_white_tower", "eng_berkshire_fortress", "fr_red_palace", "zh_barbican", "zh_gatehouse": return "keep"
		"eng_kings_mill", "eng_abbey", "zh_spirit_way": return "monastery"
		"eng_wynguard_palace", "zh_imperial_palace": return "palace"
		"fr_school_of_cavalry": return "stable"
		"fr_chamber_of_commerce", "fr_guild_hall": return "market"
		"fr_royal_institute", "zh_imperial_academy": return "university"
		"fr_college_of_artillery", "zh_clocktower": return "siege_workshop"
		_: return "town_center"
