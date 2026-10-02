extends "res://poc/exploration-2026-10-02/explore.gd"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("FAIL ", label)
func has_domain(events: Array, owner: int, domain: StringName) -> bool:
 for event in events:
  if event.owner == owner and event.domains.has(domain): return true
 return false
func _run() -> void:
 setup_case()
 var monk := soldier("monk")
 carry(monk)
 var u := soldier("spearman", 1, monk.position + Vector2(30, 0))
 game.selected.assign([u])
 game._rebuild_actions()
 game._update_hud()
 check(game.command_buttons.is_empty(), "selected_enemy_has_no_commands")
 var events: Array = []
 game.session.changes.changed.connect(func(owner: int, domains: Array[StringName]) -> void: events.append({"owner":owner,"domains":domains}))
 monk._finish_conversion()
 game._update_hud()
 check(u.owner_id == 0 and game.selected.has(u) and not game.command_buttons.is_empty(), "conversion_rebuilds_commands_without_reselection")
 check(has_domain(events, 0, &"selection"), "conversion_publishes_selected_ownership_change")
 check(has_domain(events, 0, &"entities") and has_domain(events, 1, &"entities"), "both_owner_counts_invalidated")
 events.clear()
 monk.position = Vector2(1000, 1300)
 monk._finish_conversion()
 check(events.is_empty(), "no_conversion_publishes_no_spurious_change")
 var other := soldier("spearman", 1, monk.position + Vector2(30, 0))
 events.clear()
 monk._finish_conversion()
 check(other.owner_id == 0 and has_domain(events, 0, &"entities") and not has_domain(events, 0, &"selection"), "unselected_conversion_updates_entities_only")
 var enemy_monk := soldier("monk", 1, u.position + Vector2(30, 0))
 carry(enemy_monk)
 events.clear()
 enemy_monk._finish_conversion()
 game._update_hud()
 check(u.owner_id == 1 and game.command_buttons.is_empty(), "losing_selected_unit_removes_own_commands")
 game.navigation.shutdown_jobs()
 game.free()
 print("B15_TEST_COMPLETE checks=", checks, " failures=", failures)
 quit(1 if failures else 0)
