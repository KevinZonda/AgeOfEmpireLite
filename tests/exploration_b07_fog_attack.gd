extends "res://poc/exploration-2026-10-02/explore.gd"

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("FAIL ", label)

func _run() -> void:
 setup_case()
 game.fog.active = true
 var u := soldier("longbow", 0, Vector2(1000, 650))
 var enemy := soldier("spearman", 1, u.position + Vector2(100, 0))
 game.fog.update_visibility()
 check(game.fog.can_detect_unit(0, enemy), "fixture_enemy_initially_visible")
 u.order_attack(enemy)
 u._process_attack_order(0.05)
 check(u.target == enemy, "visible_enemy_keeps_attack")
 enemy.position = game.world_map.nearest_walkable_point(Vector2(2000, 1900))
 game.fog.update_visibility()
 check(not game.fog.can_detect_unit(0, enemy), "fixture_enemy_hidden")
 u._process_attack_order(0.05)
 check(u.order == "idle" and u.target == null, "manual_attack_loses_hidden_target")
 for previous in ["attack_move", "patrol", "hold"]:
  game.fog.active = false
  if previous == "attack_move": u.order_attack_move(Vector2(1200, 700))
  elif previous == "patrol": u.order_patrol(Vector2(1200, 700))
  else: u.order_hold()
  u.orders.engage(u, enemy)
  game.fog.active = true
  u._process_attack_order(0.05)
  check(u.order == previous and u.target == null, "hidden_target_resumes_" + previous)
 game.fog.active = false
 u.order_attack(enemy)
 u.issue_command("move", Vector2(1200, 700), null, true)
 game.fog.active = true
 u._process_attack_order(0.05)
 check(u.order == "move" and u.destination == Vector2(1200, 700), "hidden_target_advances_queue")
 game.fog.active = false
 u.order_attack(enemy)
 u._process_attack_order(0.05)
 check(u.order == "attack" and u.target == enemy, "disabled_fog_keeps_tracking")
 game.fog.active = true
 var b: RtsBuilding = game._player_center(1)
 u.order_attack(b)
 u._process_attack_order(0.05)
 check(u.target == b, "fixed_building_attack_preserved")
 game.navigation.shutdown_jobs()
 game.free()
 print("B07_TEST_COMPLETE checks=", checks, " failures=", failures)
 quit(1 if failures else 0)
