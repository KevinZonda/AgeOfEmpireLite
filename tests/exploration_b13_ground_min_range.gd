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
 var u := soldier("trebuchet")
 var profile := RtsStatResolver.primary_attack(u.stats)
 var minimum: float = profile.get("min_range", u.stats.get("min_range", 0.0))
 var point := u.position + Vector2(20, 0)
 u.issue_command("attack_ground", point)
 u._process_attack_ground(0.05)
 check(projectiles().is_empty(), "cannot_fire_inside_minimum_range")
 for i in 300:
  tick_units([u], 1)
  if not projectiles().is_empty(): break
 check(not projectiles().is_empty(), "retreat_then_fire_without_new_command")
 check(u.position.distance_to(point) >= minimum, "shot_origin_outside_minimum_range")
 clear_shots()
 u.order_stop()
 u.attack_timer = 0.0
 u.position = Vector2(1000, 600)
 point = u.position + Vector2(minimum, 0)
 u.issue_command("attack_ground", point)
 u._process_attack_ground(0.05)
 check(projectiles().size() == 1, "fires_at_minimum_range_boundary")
 clear_shots()
 u.order_stop()
 u.attack_timer = 0.0
 u.issue_command("attack_ground", u.position + Vector2(minimum + 100, 0))
 u._process_attack_ground(0.05)
 check(projectiles().size() == 1, "normal_ground_attack_still_fires")
 clear_shots()
 u.order_stop()
 u.attack_timer = 0.0
 var wall: RtsBuilding = game.spawn_building(0, "stone_wall", free_site("stone_wall"))
 u.wall_host = wall
 u.position = wall.position
 u.issue_command("attack_ground", u.position + Vector2(20, 0))
 u._process_attack_ground(0.05)
 check(projectiles().is_empty(), "wall_occupant_cannot_bypass_minimum_range")
 game.navigation.shutdown_jobs()
 game.free()
 print("B13_TEST_COMPLETE checks=", checks, " failures=", failures)
 quit(1 if failures else 0)
