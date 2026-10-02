extends SceneTree
const Fixture = preload("res://tests/helpers/navigation_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("FAIL ",label)
func scenario(dirty: bool) -> void:
 var game := Fixture.new()
 root.add_child(game)
 game.initialize(Vector2(1500,1000))
 var center := Vector2(625,525)
 var guard := game.spawn_unit(center)
 guard.owner_id = 1
 guard.order = "hold"
 guard.stance = "hold"
 if dirty:
  game.navigation._ensure_spatial_index()
  check(game.navigation.max_dynamic_radius == 12.0,"fixture_cached_smaller_body")
  guard.stats["radius"] = 40.0
  game.navigation.invalidate_spatial_index()
 var radius := 10.0
 var normal := Vector2(1,1).normalized()
 var tangent := normal.orthogonal()
 var midpoint := center + normal * (radius + guard.radius() - 0.02)
 var u := game.spawn_unit(midpoint - tangent * radius * 0.25)
 u.stats["radius"] = radius
 var goal := midpoint + tangent * radius * 0.25
 check(u.position.distance_to(center) > radius+guard.radius() and goal.distance_to(center)>radius+guard.radius(),"endpoints_are_clear")
 check(not game.navigation._motion_clear(u,goal),"dirty_sweep_rejects_body_graze" if dirty else "first_sweep_rejects_body_graze")
 var next := game.navigation.move_step(u,goal)
 var nearest := Geometry2D.get_closest_point_to_segment(center,u.position,next)
 check(nearest.distance_to(center) >= radius+guard.radius()-0.0001,"sidestep_remains_collision_safe")
 var safe_mid := center + normal * (radius+guard.radius()+0.05)
 u.position = safe_mid - tangent * radius * 0.25
 game.navigation.invalidate_spatial_index()
 check(game.navigation._motion_clear(u,safe_mid+tangent*radius*0.25),"clear_tangent_is_not_overblocked")
 game.navigation.background_jobs.shutdown()
 game.free()
func run() -> void:
 scenario(false)
 scenario(true)
 print("B19_TEST_COMPLETE checks=",checks," failures=",failures)
 quit(1 if failures else 0)
