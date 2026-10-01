extends SceneTree

const Fixture = preload("res://tests/helpers/navigation_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func scenario(in_tree: bool) -> void:
	var game := Fixture.new()
	var lifecycle := {"exits": 0}
	game.tree_exiting.connect(func() -> void: lifecycle.exits += 1)
	if in_tree: root.add_child(game)
	game.initialize(Vector2(1000, 1000))
	var unit := game.spawn_unit(Vector2(125, 125))
	var navigation: RtsNavigation = game.navigation
	# Retain the navigation and snapshots after freeing the fixture so the
	# assertion observes teardown, rather than relying on engine finalization.
	navigation.async_geometry_enabled = true
	navigation._fine_grid_for(unit)
	navigation.refresh()
	check(navigation.grid_builds.active.size() == 1, "real_geometry_worker_submitted")
	var geometry_snapshot = navigation.grid_builds.active[0].snapshot
	var goal := Vector2(825, 125)
	check(navigation.background_jobs.request(unit, goal, Vector2.INF), "recovery_request_accepted")
	navigation.background_jobs.tick(navigation)
	check(navigation.background_jobs.active.size() == 1, "real_recovery_worker_submitted")
	var recovery_snapshot = navigation.background_jobs.active[0].snapshot
	check(navigation.request_route(unit, goal, 6.0, false), "route_request_accepted")
	check(navigation.route_jobs.pending.size() == 1, "route_request_pending_at_teardown")
	game.free()
	check(lifecycle.exits == (1 if in_tree else 0), "free_emits_tree_exit_only_for_attached_fixture")
	check(navigation.grid_builds.active.is_empty(), "free_reaps_all_geometry_workers")
	check(geometry_snapshot.grid != null and not geometry_snapshot.labels.is_empty(), "geometry_worker_completed_before_free_returned")
	check(navigation.background_jobs.active.is_empty() and navigation.background_jobs.pending.is_empty(), "free_reaps_all_recovery_workers")
	check(not recovery_snapshot.result.is_empty(), "recovery_worker_completed_before_free_returned")
	check(navigation.route_jobs.pending.is_empty() and navigation.route_jobs.current.is_empty() and navigation.route_jobs.completed.is_empty(), "free_clears_route_admission_state")
	# Production also permits idempotent cleanup during reset and tree exit.
	navigation.shutdown_jobs()
	check(navigation.grid_builds.active.is_empty(), "repeated_shutdown_is_safe")

func _run() -> void:
	scenario(true)
	scenario(false)
	print("NAVIGATION_FIXTURE_LIFECYCLE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
