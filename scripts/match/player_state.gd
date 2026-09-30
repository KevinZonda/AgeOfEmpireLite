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
