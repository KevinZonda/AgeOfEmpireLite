extends RefCounted

# The dictionary is the compatibility view, not a copied bank. Existing callers
# can keep writing bank["food"] while accounting moves to this owner.
var bank: Dictionary

func _init(initial_bank: Dictionary) -> void:
	bank = initial_bank

func can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		if int(bank.get(resource, 0)) < int(cost[resource]): return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost): return false
	for resource in cost: bank[resource] -= cost[resource]
	return true

func credit(resource: String, amount: int) -> void:
	bank[resource] += amount

func complete_research(tech_id: String) -> bool:
	if bank["researched"].has(tech_id): return false
	bank["researched"].append(tech_id)
	return true

# Progression updates the shared bank in one operation. The production service
# publishes these domains only after dependent entity stats have been refreshed.
func complete_age(civilization: String, target_age: int, landmark_id := "") -> Dictionary:
	var current_age: int = bank["age"]
	var aged_up := target_age == current_age + 1
	if not aged_up and (landmark_id.is_empty() or civilization != "Chinese" or target_age > current_age): return {}
	if landmark_id != "" and bank["landmarks"].has(landmark_id): return {}
	var domains: Array[StringName] = []
	if aged_up:
		bank["age"] = target_age
		domains.append(&"age")
	if aged_up and civilization == "French" and target_age >= 2:
		for upgrade_age in range(2, target_age + 1):
			if complete_research("melee_attack_%d" % upgrade_age) and not domains.has(&"research"): domains.append(&"research")
	if landmark_id != "":
		bank["landmarks"].append(landmark_id)
		domains.append(&"landmarks")
	var previous_dynasty: String = bank.get("dynasty", "")
	bank["dynasty"] = RtsLandmarkCatalog.dynasty_for(bank["landmarks"]) if civilization == "Chinese" else ""
	var dynasty_changed: bool = bank["dynasty"] != previous_dynasty
	if dynasty_changed: domains.append(&"dynasty")
	return {"aged_up": aged_up, "dynasty_changed": dynasty_changed, "dynasty": bank["dynasty"], "domains": domains}
