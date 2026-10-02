extends "res://poc/exploration-2026-10-02/explore.gd"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("FAIL ", label)
func execute_kind(kind: String, label_contains := "") -> bool:
 for desc in game.player_actions.descriptors:
  if desc.get("kind", "") == kind and (label_contains.is_empty() or desc.get("label", "").contains(label_contains)):
   return game.player_actions.execute(desc.id)
 return false
func _run() -> void:
 setup_case()
 var own := soldier("spearman", 0, Vector2(1000, 600))
 var lost := soldier("spearman", 0, Vector2(1500, 600))
 var monk := soldier("monk", 1, Vector2(1530, 600))
 carry(monk)
 game.selected.assign([own, lost])
 game._rebuild_actions()
 monk._finish_conversion()
 check(lost.owner_id == 1 and own.owner_id == 0 and game.selected.has(lost), "fixture_real_conversion_keeps_mixed_selection")
 check(execute_kind("hold"), "owned_hold_action_still_accepted_before_refresh")
 check(own.order == "hold", "owned_hold_changes_own_unit")
 check(lost.order == "idle", "pre_refresh_hold_does_not_control_converted_enemy")
 lost.order_stop()
 game._rebuild_actions()
 check(execute_kind("hold"), "owned_hold_action_still_accepted_after_refresh")
 check(lost.order == "idle", "post_refresh_hold_does_not_control_converted_enemy")
 game.player_actions.command_page = 1
 game._rebuild_actions()
 lost.engagement = "aggressive"
 check(execute_kind("stance", "防御"), "owned_stance_action_accepted")
 check(own.engagement == "defensive", "owned_stance_changes_own_unit")
 check(lost.engagement == "aggressive", "stance_does_not_control_converted_enemy")
 lost.order_move(Vector2(1750, 700))
 own.order_move(Vector2(1100, 700))
 game._stop_selected_units()
 check(own.order == "idle", "stop_still_stops_owned_unit")
 check(lost.order == "move", "stop_does_not_cancel_enemy_order")
 lost.order_stop()
 game._retreat_selected()
 check(own.order == "move", "retreat_still_moves_owned_unit")
 check(lost.order == "idle", "retreat_does_not_move_enemy")
 for mode in ["patrol", "attack_move"]:
  own.order_stop()
  lost.order_stop()
  game.order_mode = mode
  game._issue_mode_order(Vector2(1100, 700))
  check(own.order == mode, mode + "_still_controls_owned_unit")
  check(lost.order == "idle", mode + "_cannot_control_converted_enemy")
 var bow := soldier("longbow", 0, Vector2(1000, 660))
 var lost_bow := soldier("longbow", 0, Vector2(1500, 660))
 var trader := soldier("trader", 0, Vector2(1000, 690))
 var lost_trader := soldier("trader", 0, Vector2(1500, 690))
 monk._finish_conversion()
 check(lost_bow.owner_id == 1 and lost_trader.owner_id == 1, "fixture_additional_units_really_converted")
 game.selected.assign([bow, lost_bow])
 game._activate_selected_ability("volley")
 check(bow.volley_timer > 0.0, "ability_still_activates_owned_unit")
 check(lost_bow.volley_timer == 0.0, "ability_cannot_activate_converted_enemy")
 game.selected.assign([trader, lost_trader])
 game._set_selected_trade_resource("food")
 check(trader.trade_resource_kind == "food", "resource_choice_still_sets_owned_trader")
 check(lost_trader.trade_resource_kind == "gold", "resource_choice_cannot_set_converted_enemy")
 # Team mates are friendly but belong to a different human/controller.
 game.teams[1] = game.teams[0]
 lost.order_stop()
 game.selected.assign([own, lost])
 game.player_actions.command_page = 0
 game._rebuild_actions()
 check(execute_kind("hold") and own.order == "hold", "hold_still_works_with_allied_selection")
 check(lost.order == "idle", "friendly_team_units_are_not_locally_owned")
 for actor in game.units: actor.order_stop()
 game.navigation.shutdown_jobs()
 game.free()
 await process_frame
 print("B22_TEST_COMPLETE checks=", checks, " failures=", failures)
 quit(1 if failures else 0)
