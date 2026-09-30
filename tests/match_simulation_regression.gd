extends SceneTree

const MatchSimulation = preload("res://tests/helpers/match_simulation.gd")

class Actor extends Node2D:
	var elapsed := 0.0
	var ticks := 0
	var deferred_ticks := 0
	var remove_on_tick := false
	func _process(delta: float) -> void:
		elapsed += delta
		ticks += 1
		call_deferred("_finish_deferred_tick")
		if remove_on_tick: queue_free()
	func _finish_deferred_tick() -> void: deferred_ticks += 1

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("POC_FAIL ", label)

func _run() -> void:
	var game := Actor.new()
	root.add_child(game)
	var active := Actor.new()
	game.add_child(active)
	var disabled := Actor.new()
	game.add_child(disabled)
	disabled.set_process(false)
	var disabled_subtree := Actor.new()
	disabled_subtree.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(disabled_subtree)
	var inherited_disabled := Actor.new()
	disabled_subtree.add_child(inherited_disabled)
	var always := Actor.new()
	always.process_mode = Node.PROCESS_MODE_ALWAYS
	disabled_subtree.add_child(always)
	var when_paused := Actor.new()
	when_paused.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	game.add_child(when_paused)
	var removed := Actor.new()
	removed.process_mode = Node.PROCESS_MODE_ALWAYS
	removed.remove_on_tick = true
	game.add_child(removed)
	var simulation := MatchSimulation.new(game)
	var epoch := Engine.get_process_frames()
	await simulation.step(0.2)
	check(game.ticks == 1 and active.ticks == 1 and is_equal_approx(game.elapsed, 0.2) and is_equal_approx(active.elapsed, 0.2), "fixed_delta_once_without_automatic_double_processing")
	check(disabled.ticks == 0 and disabled_subtree.ticks == 0 and inherited_disabled.ticks == 0, "disabled_flags_and_subtrees_are_preserved")
	check(Engine.get_process_frames() > epoch, "real_epoch_advances_for_group_and_navigation_services")
	check(game.deferred_ticks == 1 and active.deferred_ticks == 1, "deferred_changes_flush_before_step_returns")
	check(not is_instance_valid(removed), "queued_deletion_flushes_before_step_returns")
	check(always.ticks == 1 and is_equal_approx(always.elapsed, 0.2) and when_paused.ticks == 0, "explicit_overrides_are_manually_processed_without_automatic_extra_ticks")
	paused = true
	await simulation.step(0.4)
	check(game.ticks == 1 and active.ticks == 1 and always.ticks == 2 and when_paused.ticks == 1 and is_equal_approx(when_paused.elapsed, 0.4), "pause_modes_and_nested_always_override_follow_original_modes")
	paused = false
	await simulation.step(0.3)
	check(game.ticks == 2 and active.ticks == 2 and is_equal_approx(game.elapsed, 0.5), "consecutive_steps_preserve_fixed_simulation_time")
	simulation.finish()
	check(always.process_mode == Node.PROCESS_MODE_ALWAYS and when_paused.process_mode == Node.PROCESS_MODE_WHEN_PAUSED and disabled_subtree.process_mode == Node.PROCESS_MODE_DISABLED, "finish_restores_original_override_modes")
	game.free()
	print("MATCH_SIMULATION_REGRESSION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
