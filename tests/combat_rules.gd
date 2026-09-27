extends SceneTree

const CombatRules = preload("res://scripts/rules/combat_rules.gd")
const Projectile = preload("res://scripts/entities/projectile.gd")


class GameStub extends Node2D:
	var started := true
	var paused := false
	var game_over := false
	var view_mode_25d := false
	var hits := 0

	func show_hit(_origin: Vector2, _destination: Vector2, _owner_id: int, _kind := "ranged") -> void:
		hits += 1


class TargetStub extends Node2D:
	var hp := 10.0

	func take_damage(amount: float) -> void:
		hp -= amount


func _initialize() -> void:
	var spear := {
		"damage": 10.0,
		"attack_type": "melee",
		"tags": ["infantry"],
		"bonus": {"cavalry": 4.0},
		"brace_bonus": 6.0,
	}
	var horse := {
		"damage": 12.0,
		"attack_type": "melee",
		"tags": ["cavalry", "light"],
		"charge_bonus": 5.0,
	}
	var cavalry_armor := {"tags": ["cavalry", "light"], "armor": {"melee": 2.0, "ranged": 1.0}}
	var spear_armor := {"tags": ["infantry"], "armor": {"melee": 1.0, "ranged": 0.0}, "brace_bonus": 6.0}
	assert(CombatRules.damage(spear, cavalry_armor) == 12.0)
	assert(CombatRules.damage(spear, cavalry_armor, {"braced": true}) == 18.0)
	assert(CombatRules.damage(horse, spear_armor, {"charging": true}) == 16.0)
	assert(CombatRules.charge_stopped(horse, spear_armor, true))
	assert(CombatRules.damage(horse, spear_armor, {"charging": true, "defender_braced": true}) == 11.0)
	assert(CombatRules.damage({"damage": 0.0, "attack_type": "ranged"}, {"armor": {"ranged": 8.0}}) == 1.0)
	var game := GameStub.new()
	root.add_child(game)
	var target := TargetStub.new()
	target.position = Vector2(100, 0)
	game.add_child(target)
	var projectile := Projectile.new()
	projectile.setup(game, 0, Vector2.ZERO, target, 4.0, 100.0)
	game.add_child(projectile)
	projectile._process(0.5)
	assert(projectile.position == Vector2(50, 0))
	game.paused = true
	projectile._process(1.0)
	assert(projectile.position == Vector2(50, 0) and target.hp == 10.0)
	game.paused = false
	projectile._process(0.5)
	assert(projectile.is_queued_for_deletion() and target.hp == 6.0 and game.hits == 1)
	game.free()
	quit()
