extends SceneTree

# Hitch reproduction POC. Runs the REAL game loop headless with scripted
# gameplay (army clashes, building destruction/construction, an unreachable
# order target) and attributes every frame spike to its cause.
#
# Run: RTS_NAV_PROFILE=1 docs/godot/bin/godot.macos.template_debug.arm64 \
#        --headless --path . -s res://poc/hitch_poc.gd

const SIM_SECONDS := 15.0
const SPIKE_US := 12000  # 1.5x the 8.3 ms frame budget at 120 fps
const WALL_LIMIT_US := 200_000_000  # stop the sim after 200 wall seconds

var game: Node2D
var frames: Array[Dictionary] = []
var prev_profile := {}
var prev_fog_timer := 0.0
var prev_sample_count := 0
var prev_ai_timer := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _spawn_army(owner_id: int, count: int, origin: Vector2) -> Array[RtsUnit]:
	var army: Array[RtsUnit] = []
	for i in count:
		var unit := RtsUnit.new()
		unit.position = origin + Vector2((i % 15) * 30, (i / 15) * 30)
		game.add_child(unit)
		unit.setup(game, owner_id, "spearman")
		game.units.append(unit)
		army.append(unit)
	return army

func _run() -> void:
	seed(7)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 7, "French")
	await process_frame

	var army0 := _spawn_army(0, 70, Vector2(400, 500))
	var army1 := _spawn_army(1, 70, Vector2(1800, 1700))
	# Sacrificial buildings: destroyed/rebuilt mid-match to wipe nav caches,
	# exactly like combat and expansion do in a real game.
	var decoys: Array[RtsBuilding] = []
	for i in 4:
		decoys.append(game.spawn_building(1, "house", Vector2(900 + i * 90, 1100)))
	# Unreachable enclosure (stuck-unit / unreachable-relic scenario).
	var cage_center := Vector2(1500, 700)
	for ring in [60.0, 110.0]:
		for i in 8:
			var angle := TAU * i / 8.0
			game.spawn_building(1, "stone_wall", cage_center + Vector2(cos(angle), sin(angle)) * ring)
	var probe := _spawn_army(0, 1, Vector2(1250, 700))[0]
	await process_frame
	var cage_path: PackedVector2Array = game.navigation.path_between(probe.position, cage_center, probe)
	print("setup: units=%d buildings=%d players=%d ai_controllers=%d cage_reachable=%s" % [
		game.units.size(), game.buildings.size(), game.players.size(), game.ai_controllers.size(), not cage_path.is_empty()])

	prev_profile = game.navigation.profile_snapshot()
	prev_sample_count = game.match_statistics.samples.size()
	prev_fog_timer = game.fog.update_timer
	prev_ai_timer = float(game.ai_think_timers.get(1, 0.0))

	var next_order := 2.0
	var next_siege := 4.0
	var next_probe := 6.0
	var order_flip := false
	var elapsed := 0.0
	var sim_start := Time.get_ticks_usec()
	var last_report := -1
	while elapsed < SIM_SECONDS and Time.get_ticks_usec() - sim_start < WALL_LIMIT_US:
		var frame_start := Time.get_ticks_usec()
		await process_frame
		var wall_us := Time.get_ticks_usec() - frame_start
		elapsed = game.match_statistics.elapsed
		if int(elapsed) != last_report:
			last_report = int(elapsed)
			print("... sim t=%ds frames=%d wall=%ds" % [last_report, frames.size(), (Time.get_ticks_usec() - sim_start) / 1_000_000])
		if elapsed >= next_order:
			next_order += 4.0
			order_flip = not order_flip
			game.issue_group_order(army0, Vector2(1900, 1700) if order_flip else Vector2(400, 500))
			game.issue_group_order(army1, Vector2(400, 500) if order_flip else Vector2(1800, 1700))
		if elapsed >= next_siege:
			next_siege += 7.0
			var victim: RtsBuilding = decoys.pop_front()
			if victim != null and is_instance_valid(victim):
				game.entity_destroyed(victim)
				decoys.append(game.spawn_building(1, "house", Vector2(900 + randi() % 300, 1100 + randi() % 200)))
		if elapsed >= next_probe:
			next_probe += 10.0
			var probe_group: Array[RtsUnit] = [probe]
			game.issue_group_order(probe_group, cage_center)
		# Per-frame attribution snapshot.
		var profile: Dictionary = game.navigation.profile_snapshot()
		var nav_added := {}
		for op in profile.keys():
			var prev: Dictionary = prev_profile.get(op, {"total_us": 0})
			var added_us: int = profile[op]["total_us"] - prev["total_us"]
			if added_us > 0: nav_added[op] = added_us
		prev_profile = profile
		var flags: Array[String] = []
		var fog_now: float = game.fog.update_timer
		if fog_now > prev_fog_timer: flags.append("fog")
		prev_fog_timer = fog_now
		var samples_now: int = game.match_statistics.samples.size()
		if samples_now != prev_sample_count: flags.append("stats")
		prev_sample_count = samples_now
		var ai_now := float(game.ai_think_timers.get(1, 0.0))
		if ai_now > prev_ai_timer: flags.append("ai_tick")
		prev_ai_timer = ai_now
		frames.append({"t": elapsed, "us": wall_us, "flags": flags, "nav": nav_added})
	_report()

func _report() -> void:
	var times: Array[int] = []
	for frame in frames: times.append(frame["us"])
	times.sort()
	var median := times[times.size() / 2]
	var p95 := times[int(times.size() * 0.95)]
	print("\n=== frame wall time over %d frames (%.1f sim s) ===" % [frames.size(), SIM_SECONDS])
	print("median %.1f ms | p95 %.1f ms | max %.1f ms" % [median / 1000.0, p95 / 1000.0, times.back() / 1000.0])
	var nav_totals := {}
	var cause_totals := {}
	var spikes: Array[Dictionary] = []
	for frame in frames:
		for op in frame["nav"].keys():
			nav_totals[op] = int(nav_totals.get(op, 0)) + frame["nav"][op]
		if frame["us"] < SPIKE_US: continue
		spikes.append(frame)
		if frame["flags"].is_empty() and frame["nav"].is_empty():
			cause_totals["unattributed"] = int(cause_totals.get("unattributed", 0)) + frame["us"]
		else:
			for flag in frame["flags"]:
				cause_totals[flag] = int(cause_totals.get(flag, 0)) + frame["us"]
			if not frame["nav"].is_empty():
				cause_totals["nav"] = int(cause_totals.get("nav", 0)) + frame["us"]
	print("\n=== %d spike frames (> %d ms) ===" % [spikes.size(), SPIKE_US / 1000])
	for frame in spikes:
		var nav_str := ""
		for op in frame["nav"].keys():
			nav_str += " %s=%.1fms" % [op, frame["nav"][op] / 1000.0]
		print("t=%5.1fs  %6.1f ms  flags=%s%s" % [frame["t"], frame["us"] / 1000.0, frame["flags"], nav_str])
	print("\n=== spike time by cause (a spike can count toward several) ===")
	for cause in cause_totals.keys():
		print("%-14s %8.1f ms total" % [cause, cause_totals[cause] / 1000.0])
	print("\n=== nav profile totals across whole run ===")
	for op in nav_totals.keys():
		print("%-24s %8.1f ms" % [op, nav_totals[op] / 1000.0])
	quit()
