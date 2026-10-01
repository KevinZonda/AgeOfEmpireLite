extends "res://tools/battle_deer_poc.gd"

# Exercise the real macOS polling/state-machine/overlay path with a repeatable
# clock-driven pointer. Only the OS pointer/focus inputs are substituted. No
# sleep or artificial load is added. Headless results are NOT display latency.
class TimedJobs extends "res://scripts/world/navigation_jobs.gd":
	var frame_us := 0
	func tick(nav, allow_dispatch := true) -> void:
		var started := Time.get_ticks_usec()
		super.tick(nav, allow_dispatch)
		frame_us = Time.get_ticks_usec() - started

class TimedNavigation extends RtsNavigation:
	var searches: Array[Dictionary] = []
	var search_us := 0
	var movement_us := 0
	var movement_calls := 0
	func _init(owner_game, map) -> void:
		super(owner_game, map)
		background_jobs = TimedJobs.new()
	func path_to_range(from: Vector2, target: Vector2, reach: float, unit: RtsUnit) -> PackedVector2Array:
		var started := Time.get_ticks_usec()
		var result := super.path_to_range(from, target, reach, unit)
		_record_search("path_to_range", started)
		return result
	func path_between(from: Vector2, to: Vector2, unit: RtsUnit = null, smooth := true) -> PackedVector2Array:
		var started := Time.get_ticks_usec()
		var result := super.path_between(from, to, unit, smooth)
		_record_search("path_between", started)
		return result
	func path_around_units(unit: RtsUnit, target: Vector2) -> PackedVector2Array:
		var started := Time.get_ticks_usec()
		var result := super.path_around_units(unit, target)
		_record_search("path_around_units", started)
		return result
	func move_step(unit: RtsUnit, desired_position: Vector2) -> Vector2:
		var started := Time.get_ticks_usec()
		var result := super.move_step(unit, desired_position)
		movement_us += Time.get_ticks_usec() - started
		movement_calls += 1
		return result
	func _record_search(operation: String, started: int) -> void:
		var duration := Time.get_ticks_usec() - started
		search_us += duration
		if duration >= 2000: searches.append({"operation": operation, "ms": duration / 1000.0})

class ProbeGame extends DemoGame:
	var clock_start := 0
	var polling := false
	var last_poll := 0
	var poll_gap_us := 0
	var poll_us := 0
	var poll_stamp := 0
	var root_process_us := 0
	var release_us := 0
	var release_count := 0
	var held_samples := 0
	var overlay_mismatches := 0
	var sampled_pointer := Vector2.ZERO
	var previous_sample_held := false
	var gap_during_hold := false
	func _ready() -> void:
		super._ready()
		var enabled: bool = navigation.background_recovery_enabled
		navigation = TimedNavigation.new(self, world_map)
		navigation.background_recovery_enabled = enabled
	func _uses_native_selection_pointer() -> bool:
		return true
	func _seconds() -> float:
		return (Time.get_ticks_usec() - clock_start) / 1000000.0 if polling else 0.0
	func _selection_native_left_down() -> bool:
		return polling and fmod(_seconds(), 1.5) < 1.2
	func _selection_pointer_screen_position() -> Vector2:
		var phase := fmod(_seconds(), 1.5)
		return Vector2(360, 240) + Vector2(minf(phase / 1.2, 1.0) * 420, sin(phase * PI / 1.2) * 100)
	func _poll_selection_pointer() -> void:
		if not polling: return
		var started := Time.get_ticks_usec()
		poll_gap_us = started - last_poll if last_poll > 0 else 0
		last_poll = started
		poll_stamp = started
		sampled_pointer = _selection_pointer_screen_position()
		var held := _selection_native_left_down()
		gap_during_hold = held and previous_sample_held
		# Production starts selection from LEFT events. Generate the matching
		# press instead of letting a native-state-only pulse create a selection.
		if held and not previous_sample_held:
			_send_left_event(true, sampled_pointer)
		var released := not held and previous_sample_held
		previous_sample_held = held
		_advance_selection_pointer(sampled_pointer, held)
		if released: _send_left_event(false, sampled_pointer)
		poll_us = Time.get_ticks_usec() - started
		if dragging and held:
			held_samples += 1
			if drag_current_screen != sampled_pointer or selection_drag_overlay.drag_current != sampled_pointer: overlay_mismatches += 1
			if not selection_drag_overlay.tracking or not selection_drag_overlay.visible: overlay_mismatches += 1
			if selection_drag_overlay.active != _selection_drag_visible(): overlay_mismatches += 1
			if selection_drag_overlay.active:
				var expected := Rect2(drag_start_screen, sampled_pointer - drag_start_screen).abs()
				if selection_drag_overlay.borders[0].position != expected.position: overlay_mismatches += 1
		elif not held and (dragging or selection_drag_overlay.visible or selection_drag_overlay.tracking):
			overlay_mismatches += 1
	func _send_left_event(pressed: bool, point: Vector2) -> void:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	func _complete_selection_drag(point: Vector2, additive: bool) -> void:
		var started := Time.get_ticks_usec()
		super._complete_selection_drag(point, additive)
		release_us += Time.get_ticks_usec() - started
		release_count += 1
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		root_process_us = Time.get_ticks_usec() - started

class EndOfFrame extends Node:
	var sample: Callable
	func _process(_delta: float) -> void:
		sample.call()

var rows: Array[Dictionary] = []
var diagnostic_start := 0
var duration_seconds := 12.0
var idle := OS.get_environment("RTS_DRAG_IDLE") == "1"
var render_samples := 0
var max_present_gap_us := 0
var last_present := 0

func _create_game() -> Node2D:
	return ProbeGame.new()

func _run() -> void:
	await super._run()
	Engine.max_fps = 120
	if not OS.get_environment("RTS_DRAG_SECONDS").is_empty(): duration_seconds = float(OS.get_environment("RTS_DRAG_SECONDS"))
	if idle:
		for entity in game.units + game.resources + game.buildings: entity.set_process(false)
	game.navigation.searches.clear()
	game.navigation.search_us = 0
	game.navigation.movement_us = 0
	game.navigation.movement_calls = 0
	game.clock_start = Time.get_ticks_usec()
	game.polling = true
	diagnostic_start = game.clock_start
	caption.text = "拖选延迟 PoC：自动循环拖选 · 80 人 / 6 建筑 / 鹿群"
	var meter := EndOfFrame.new()
	meter.process_priority = 100000
	meter.sample = _sample
	root.add_child(meter)
	RenderingServer.frame_post_draw.connect(_present)

func _present() -> void:
	var now := Time.get_ticks_usec()
	if last_present > 0 and game.gap_during_hold: max_present_gap_us = maxi(max_present_gap_us, now - last_present)
	last_present = now
	render_samples += 1

func _sample() -> void:
	var now := Time.get_ticks_usec()
	if game.poll_stamp == 0: return
	rows.append({"elapsed_s": (now - diagnostic_start) / 1000000.0, "poll_elapsed_s": (game.poll_stamp - diagnostic_start) / 1000000.0, "held": game.gap_during_hold,
		"poll_gap_ms": game.poll_gap_us / 1000.0, "poll_ms": game.poll_us / 1000.0,
		"queue_ms": game.navigation.background_jobs.frame_us / 1000.0,
		"active_workers": game.navigation.background_jobs.active.size(), "search_ms": game.navigation.search_us / 1000.0, "movement_ms": game.navigation.movement_us / 1000.0, "movement_calls": game.navigation.movement_calls, "root_ms": game.root_process_us / 1000.0, "scene_ms": (now - frame_start) / 1000.0,
		"after_poll_ms": (now - game.poll_stamp) / 1000.0, "searches": game.navigation.searches.duplicate()})
	game.navigation.searches.clear()
	game.navigation.search_us = 0
	game.navigation.movement_us = 0
	game.navigation.movement_calls = 0
	if now - diagnostic_start < duration_seconds * 1000000.0: return
	var steady: Array[Dictionary] = []
	var slow := []
	var cold_slow := []
	var previous := {}
	for row in rows:
		if row.held and row.poll_gap_ms >= 40.0:
			var event := {"elapsed_s": row.elapsed_s, "poll_gap_ms": row.poll_gap_ms, "queue_before_poll_ms": row.queue_ms, "previous_frame": previous}
			if previous.get("poll_elapsed_s", 0.0) >= 2.0: slow.append(event)
			else: cold_slow.append(event)
		if row.poll_elapsed_s >= 2.0 and previous.get("poll_elapsed_s", 0.0) >= 2.0 and row.held: steady.append(row)
		previous = row
	var summary := {}
	for key in ["poll_gap_ms", "poll_ms", "queue_ms", "root_ms", "scene_ms", "after_poll_ms", "search_ms", "movement_ms"]:
		var values: Array = steady.map(func(row): return row[key])
		values.sort()
		summary[key] = {"mean": values.reduce(func(a, b): return a + b, 0.0) / maxi(1, values.size()), "p95": values[maxi(0, ceili(values.size() * 0.95) - 1)] if not values.is_empty() else 0, "max": values[-1] if not values.is_empty() else 0}
	var damage := 0.0
	for fort in forts: damage += fort.max_hp - fort.hp
	var valid: bool = game.held_samples > 30 and game.release_count >= 2 and game.overlay_mismatches == 0 and (idle or damage > 0)
	print("SELECTION_LATENCY_PROFILE ", JSON.stringify({"headless": DisplayServer.get_name() == "headless", "synthetic_os_pointer": true, "async_enabled": game.navigation.background_recovery_enabled, "idle": idle, "seconds": duration_seconds, "samples": steady.size(), "held_samples": game.held_samples, "releases": game.release_count, "release_total_ms": game.release_us / 1000.0, "overlay_mismatches": game.overlay_mismatches, "render_samples": render_samples, "max_present_gap_ms": max_present_gap_us / 1000.0, "damage": damage, "timings": summary, "slow_polls": slow, "cold_slow_polls": cold_slow, "jobs": game.navigation.background_jobs.metrics}))
	print("SELECTION_BATTLE_LATENCY_POC_OK" if valid else "POC_FAIL selection_latency")
	quit(0 if valid else 1)
