extends "res://poc/exploration-2026-10-02/explore.gd"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("FAIL ", label)
func clear_shots() -> void:
 for p in projectiles(): p.free()
func _run() -> void:
 setup_case()
 game.civilizations[0] = "French"
 var u := soldier("cannon")
 u.producer_landmark_id = "fr_college_of_artillery"
 var original := RtsStatResolver.primary_attack(u.stats).duplicate(true)
 check(u.activate_ability("artillery_shot"), "artillery_activated")
 u.attack_timer = 1.0
 u.issue_command("attack_ground", u.position + Vector2(160, 0))
 u._process_attack_ground(0.05)
 check(projectiles().is_empty() and u.artillery_shot_ready and u.artillery_shot_cooldown == 0.0, "reload_wait_preserves_ability")
 u.attack_timer = 0.0
 u.issue_command("attack_ground", u.position + Vector2(1000, 0))
 u._process_attack_ground(0.05)
 check(projectiles().is_empty() and u.artillery_shot_ready, "out_of_range_preserves_ability")
 u.issue_command("attack_ground", u.position + Vector2(160, 0))
 u._process_attack_ground(0.05)
 check(projectiles().size() == 1, "ground_shot_fired")
 check(not u.artillery_shot_ready and u.artillery_shot_cooldown == 35.0, "ground_shot_consumes_artillery_once")
 if not projectiles().is_empty():
  var bolt: RtsProjectile = projectiles()[0]
  check(bolt.splash_radius >= 65.0 and bolt.attack_profile.get("bonuses", [1]).is_empty(), "ground_projectile_has_enhanced_profile")
 check(RtsStatResolver.primary_attack(u.stats) == original, "base_profile_not_mutated")
 clear_shots()
 u.attack_timer = 0.0
 u.issue_command("attack_ground", u.position + Vector2(160, 0))
 u._process_attack_ground(0.05)
 check(projectiles().size() == 1 and projectiles()[0].attack_profile == original, "following_shot_is_normal")
 clear_shots()
 u.attack_timer = 0.0
 u.artillery_shot_cooldown = 0.0
 check(u.activate_ability("artillery_shot"), "ability_reactivated_after_cooldown")
 var enemy := soldier("spearman", 1, u.position + Vector2(180, 0))
 u.order_attack(enemy)
 u._process_attack_order(0.05)
 check(projectiles().size() == 1 and not u.artillery_shot_ready and u.artillery_shot_cooldown == 35.0 and projectiles()[0].splash_radius >= 65.0, "target_attack_still_uses_enhanced_shot")
 game.navigation.shutdown_jobs()
 game.free()
 print("B14_TEST_COMPLETE checks=", checks, " failures=", failures)
 quit(1 if failures else 0)
