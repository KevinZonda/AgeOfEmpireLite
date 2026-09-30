class_name RtsCombatRules
extends RefCounted

# All attack arithmetic lives here. Units and buildings only supply their
# definitions and the short-lived combat state (charging or braced).
static func damage(attacker: Dictionary, defender: Dictionary, modifiers: Dictionary = {}) -> float:
	var attack_type: String = RtsStatResolver.primary_attack_type(attacker)
	var total: float = RtsStatResolver.primary_damage(attacker)
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
	total = maxf(1.0, total - float(armor.get(attack_type, 0.0)))
	var resistance: Dictionary = defender.get("resistance", {})
	return maxf(1.0, total * (1.0 - clampf(float(resistance.get(attack_type, 0.0)), 0.0, 0.99)))


static func charge_stopped(attacker: Dictionary, defender: Dictionary, defender_braced: bool) -> bool:
	if not defender_braced: return false
	var attacker_tags: Array = attacker.get("tags", [])
	return attacker_tags.has("cavalry") and float(defender.get("brace_bonus", 0.0)) > 0.0


# A profile is one impact. Multi-hit attacks call this once per impact, so armor
# applies to each arrow/bolt rather than once to the combined volley.
static func profile_damage(attacker: Dictionary, defender: Dictionary, profile: Dictionary, modifiers: Dictionary = {}) -> float:
	if profile.is_empty() or float(profile.get("damage", 0.0)) <= 0.0: return 0.0
	var total: float = float(profile["damage"])
	var target_tags: Array = defender.get("target_tags", defender.get("tags", []))
	for bonus in profile.get("bonuses", []):
		var matches := true
		for required in bonus.get("required_tags", []):
			if not target_tags.has(required):
				matches = false
				break
		if matches: total += float(bonus.get("amount", 0.0))
	if bool(modifiers.get("brace_impact", false)) and target_tags.has("cavalry"):
		total += float(attacker.get("brace_bonus", 0.0))
	total += float(modifiers.get("extra_damage", 0.0))
	total *= float(modifiers.get("multiplier", 1.0))
	var damage_kind: String = profile.get("damage_kind", "melee")
	var armor: Dictionary = defender.get("armor", {})
	total = maxf(1.0, total - float(armor.get(damage_kind, 0.0)))
	var resistance: Dictionary = defender.get("resistance", {})
	total = maxf(1.0, total * (1.0 - clampf(float(resistance.get(damage_kind, 0.0)), 0.0, 0.99)))
	if defender.get("kind", "") == "battering_ram" and damage_kind == "melee": total *= 1.2
	return total

static func volley_damage(attacker: Dictionary, defender: Dictionary, profile: Dictionary, modifiers: Dictionary = {}) -> float:
	return profile_damage(attacker, defender, profile, modifiers) * maxi(1, int(profile.get("hits", 1)))
