extends "res://poc/exploration-2026-10-02/explore.gd"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("FAIL ", label)
func shot(target: Node2D, area := 0.0, profile: Dictionary = {}) -> void:
 var bolt := RtsProjectile.new()
 bolt.setup(game, 0, target.position - Vector2(30, 0), target, 10.0, 350.0, area, {"damage":10.0}, profile)
 game.add_child(bolt)
 bolt._process(0.2)
func _run() -> void:
 setup_case()
 var monk := soldier("monk")
 carry(monk)
 var target := soldier("spearman", 1, monk.position + Vector2(40, 0))
 var bolt := RtsProjectile.new()
 bolt.setup(game, 0, monk.position, target, 10.0)
 game.add_child(bolt)
 monk._finish_conversion()
 var hp := target.hp
 bolt._process(0.2)
 check(target.owner_id == 0 and target.hp == hp, "converted_target_takes_no_direct_damage")
 var enemy := soldier("spearman", 1, Vector2(1300, 600))
 hp = enemy.hp
 shot(enemy)
 check(enemy.hp == hp - 10.0, "enemy_still_takes_direct_damage")
 game.teams[1] = game.teams[0]
 hp = enemy.hp
 shot(enemy)
 check(enemy.hp == hp, "different_owner_teammate_takes_no_damage")
 game.teams[1] = 1
 var boar := RtsResource.new()
 boar.game = game
 boar.position = Vector2(1400, 600)
 boar.setup("food", 100, "boar")
 game.add_child(boar)
 var wildlife_before := boar.wildlife_hp
 shot(boar)
 check(boar.wildlife_hp == wildlife_before - 10.0, "wildlife_still_takes_hunting_damage")
 var friendly := soldier("spearman", 0, Vector2(1600, 600))
 var splash_enemy := soldier("spearman", 1, friendly.position + Vector2(30, 0))
 hp = friendly.hp
 var enemy_before := splash_enemy.hp
 shot(friendly, 65.0, {"damage":10.0,"damage_kind":"ranged","bonuses":[],"pierce_length":70.0,"pierce_width":10.0})
 check(friendly.hp == hp, "splash_and_pierce_skip_converted_primary_target")
 check(splash_enemy.hp < enemy_before, "splash_and_pierce_can_hit_other_enemies")
 game.navigation.shutdown_jobs()
 game.free()
 print("B11_TEST_COMPLETE checks=", checks, " failures=", failures)
 quit(1 if failures else 0)
