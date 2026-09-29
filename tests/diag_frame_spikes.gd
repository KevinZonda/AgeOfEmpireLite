extends SceneTree

# Diagnose intermittent frame spikes in a live match: run the real main loop
# headless with default duel settings and record per-frame CPU time, navigation
# revision churn, grid refreshes, and wildlife state.
const MAX_FRAMES := 2400

var game: Node2D
var frame_count := 0
var rows: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(4242)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.match_mode = "ffa4"
	game.start_game("English", 4242)
	await process_frame
	var nav = game.navigation
	var prev_profile: Dictionary = nav.profile_snapshot()
	var t_prev := Time.get_ticks_usec()
	while frame_count < MAX_FRAMES and not game.game_over:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt_ms := (now - t_prev) / 1000.0
		t_prev = now
		var snap: Dictionary = nav.profile_snapshot()
		var row := {
			"frame": frame_count,
			"ms": snappedf(dt_ms, 0.01),
			"rev_delta": 0,
			"grid_refresh": _delta(snap, prev_profile, "grid_refresh"),
			"astar_ms": snappedf(_delta_ms(snap, prev_profile, "astar"), 0.01),
			"path_between_ms": snappedf(_delta_ms(snap, prev_profile, "path_between"), 0.01),
			"path_to_range_ms": snappedf(_delta_ms(snap, prev_profile, "path_to_range"), 0.01),
			"can_occupy_ms": snappedf(_delta_ms(snap, prev_profile, "can_occupy"), 0.01),
			"move_step_ms": snappedf(_delta_ms(snap, prev_profile, "move_step"), 0.01),
			"grid_refresh_ms": snappedf(_delta_ms(snap, prev_profile, "grid_refresh"), 0.01),
			"fine_build_ms": snappedf(_delta_ms(snap, prev_profile, "fine_grid_build"), 0.01),
			"fine_cells": _delta(snap, prev_profile, "fine_grid_cells"),
			"ptr_coarse_ms": snappedf(_delta_ms(snap, prev_profile, "ptr_coarse"), 0.01),
			"ptr_refine_ms": snappedf(_delta_ms(snap, prev_profile, "ptr_refine"), 0.01),
			"units": game.units.size(),
			"buildings": game.buildings.size(),
			"wildlife": _wildlife_count(),
		}
		row["rev_delta"] = nav.obstacle_revision - (rows[-1]["rev"] if not rows.is_empty() else nav.obstacle_revision)
		row["rev"] = nav.obstacle_revision
		rows.append(row)
		prev_profile = snap
		if dt_ms > 30.0:
			print("SPIKE frame=%d ms=%.1f" % [frame_count, dt_ms])
			for unit in game.units:
				if is_instance_valid(unit) and unit.route_failures > 0:
					print("  stuck owner=%d kind=%s order=%s failures=%d pos=%s dest=%s" % [
						unit.owner_id, unit.kind, unit.order, unit.route_failures, unit.position, unit.destination])
		frame_count += 1
	_report()
	quit()


func _delta(snap: Dictionary, prev: Dictionary, key: String) -> int:
	return int(snap.get(key, {}).get("calls", 0)) - int(prev.get(key, {}).get("calls", 0))


func _delta_ms(snap: Dictionary, prev: Dictionary, key: String) -> float:
	return (float(snap.get(key, {}).get("total_us", 0)) - float(prev.get(key, {}).get("total_us", 0))) / 1000.0


func _wildlife_count() -> int:
	var count := 0
	for resource in game.resources:
		if is_instance_valid(resource) and resource.appearance in ["deer", "boar", "sheep"]:
			count += 1
	return count


func _report() -> void:
	var times := rows.map(func(row): return row["ms"])
	times.sort()
	var n := times.size()
	print("frames=%d mean=%.2f p50=%.2f p90=%.2f p99=%.2f max=%.2f" % [
		n, _mean(times), times[int(n * 0.5)], times[int(n * 0.9)], times[int(n * 0.99)], times[n - 1]])
	var rev_frames := rows.filter(func(row): return row["rev_delta"] > 0).size()
	var refresh_frames := rows.filter(func(row): return row["grid_refresh"] > 0).size()
	print("frames with obstacle_revision bump: %d/%d, with grid_refresh: %d/%d" % [rev_frames, n, refresh_frames, n])
	print("first wildlife: %d, last wildlife: %d, last units: %d, last buildings: %d" % [
		rows[0]["wildlife"], rows[-1]["wildlife"], rows[-1]["units"], rows[-1]["buildings"]])
	print("--- slowest 15 frames ---")
	var sorted := rows.duplicate()
	sorted.sort_custom(func(a, b): return a["ms"] > b["ms"])
	for row in sorted.slice(0, 15):
		print(JSON.stringify(row))
	print("--- sample every 300 frames ---")
	for i in range(0, n, 300):
		print(JSON.stringify(rows[i]))


func _mean(values: Array) -> float:
	var total := 0.0
	for value in values: total += value
	return total / maxf(1.0, values.size())
