extends RefCounted

var wants_siege: bool
var wants_monastery: bool
var reserving_strategic_wood: bool
var saving_for_age := false

func _init(age: int, map_style: String, ram_count: int, has_monastery: bool) -> void:
	wants_siege = age >= 3 and map_style != "islands" and ram_count == 0
	wants_monastery = age >= 3 and not wants_siege and not has_monastery
	reserving_strategic_wood = wants_siege or wants_monastery

func update_age_saving(age: int, age_queued: bool, elapsed: float, timing: float, enemy_age: int) -> void:
	saving_for_age = not RtsTechTree.age_cost(age).is_empty() and not age_queued and (elapsed >= timing * float(age - 1) or enemy_age > age)

func allows_research() -> bool:
	return not saving_for_age and not reserving_strategic_wood

func allows_production(producer: String, elapsed: float) -> bool:
	if not saving_for_age: return true
	if producer in ["barracks", "archery_range", "stable", "white_tower", "wynguard"]: return false
	return producer != "siege_workshop" or elapsed >= 330.0
