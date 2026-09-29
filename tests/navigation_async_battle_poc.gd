extends "res://tools/battle_deer_poc.gd"

# Actual game/2.5D scene, without a window: measure main-thread simulation
# callbacks only. This is explicitly NOT a graphical FPS benchmark.
class EndOfFrame extends Node:
	var sample: Callable
	func _process(delta: float) -> void:
		sample.call(delta)

var elapsed := 0.0
var main_samples: Array[float] = []
var warm_damage := 0.0

func _run() -> void:
	await super._run()
	Engine.max_fps = 120
	var meter := EndOfFrame.new()
	meter.process_priority = 100000
	meter.sample = _sample_simulation
	root.add_child(meter)

func _sample_simulation(delta: float) -> void:
	elapsed += delta
	if elapsed < 2.0:
		warm_damage = forts[0].max_hp - forts[0].hp
		return
	main_samples.append((Time.get_ticks_usec() - frame_start) / 1000.0)
	if elapsed < 12.0: return
	main_samples.sort()
	var damage := 0.0
	for fort in forts: damage += fort.max_hp - fort.hp
	print("ASYNC_BATTLE_PROFILE ", JSON.stringify({"headless": true, "async_enabled": game.navigation.background_recovery_enabled, "buildings": building_count, "attackers": attackers.size(), "samples": main_samples.size(), "simulation_seconds": elapsed,
		"main_mean_ms": main_samples.reduce(func(a, b): return a + b, 0.0) / main_samples.size(), "main_p95_ms": main_samples[ceili(main_samples.size() * 0.95) - 1], "main_max_ms": main_samples[-1], "damage": damage, "warm_damage": warm_damage, "jobs": game.navigation.background_jobs.metrics, "navigation": game.navigation.profile_snapshot()}))
	print("NAVIGATION_ASYNC_BATTLE_POC_OK" if damage > warm_damage else "POC_FAIL siege_stopped")
	quit(0 if damage > warm_damage else 1)
