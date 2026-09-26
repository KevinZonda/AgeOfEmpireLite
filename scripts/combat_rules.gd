class_name RtsCombatRules
extends RefCounted

# All attack arithmetic lives here. Units and buildings only supply their
# definitions and the short-lived combat state (charging or braced).
static func damage(attacker: Dictionary, defender: Dictionary, modifiers: Dictionary = {}) -> float:
	var attack_type: String = attacker.get("attack_type", "melee")
	var total: float = float(attacker.get("damage", 0.0))
	var bonuses: Dictionary = attacker.get("bonus", {})
	var defender_tags: Array = defender.get("tags", [])
	for tag in bonuses:
		if defender_tags.has(tag):
			total += float(bonuses[tag])

	if bool(modifiers.get("charging", false)) and not charge_stopped(attacker, defender, bool(modifiers.get("defender_braced", false))):
		total += float(attacker.get("charge_bonus", 0.0))
	if bool(modifiers.get("braced", false)) and defender_tags.has("cavalry"):
		total += float(attacker.get("brace_bonus", 0.0))

	total += float(modifiers.get("extra_damage", 0.0))
	total *= float(modifiers.get("multiplier", 1.0))
	var armor: Dictionary = defender.get("armor", {})
	return maxf(1.0, total - float(armor.get(attack_type, 0.0)))


static func charge_stopped(attacker: Dictionary, defender: Dictionary, defender_braced: bool) -> bool:
	if not defender_braced: return false
	var attacker_tags: Array = attacker.get("tags", [])
	return attacker_tags.has("cavalry") and float(defender.get("brace_bonus", 0.0)) > 0.0
