extends SceneTree

class FishGame:
	extends Node2D
	var started := true
	var paused := false
	var game_over := false
	var view_mode_25d := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_cosmetic_lifecycle()
	await _check_real_match()
	print("FISH_RESOURCE_OK lifecycle viewport pause throttle seed harvest orders simulation")
	quit()

func _check_cosmetic_lifecycle() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(200, 200)
	root.add_child(viewport)
	var fixture := FishGame.new()
	fixture.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(fixture)
	var fish := RtsResource.new()
	fish.game = fixture
	fish.position = Vector2(100, 100)
	fixture.add_child(fish)
	fish.setup("food", 500, "fish")
	var anchor := fish.position
	var seed_value := fish.fish_visual_seed
	var initial_wander := fish.wander_time
	var initial_rng := fish.deer_rng.state
	seed(75279)
	var expected_random := randf()
	seed(75279)
	fish.setup("food", 500, "fish")
	assert(randf() == expected_random, "fish setup must not consume global RNG")
	assert(seed_value == hash(anchor) and fish.fish_visual_seed == seed_value, "fish layout must be reproducible at its map anchor")
	# MatchSimulation invokes callbacks even when automatic processing is off.
	fish.set_process(false)
	fish._process(0.02)
	assert(is_equal_approx(fish.fish_time, 0.02) and is_equal_approx(fish.fish_redraw_timer, 0.02), "visible fish should advance under manual simulation ownership")
	fish._process(0.07)
	assert(is_equal_approx(fish.fish_time, 0.09) and fish.fish_redraw_timer < RtsResource.FISH_REDRAW_INTERVAL, "redraw throttle must retain its fractional interval")
	fish._process(1.0)
	assert(is_equal_approx(fish.fish_time, 1.09) and fish.fish_redraw_timer < RtsResource.FISH_REDRAW_INTERVAL, "long frames must not schedule a catch-up redraw backlog")
	var frozen_time := fish.fish_time
	var frozen_timer := fish.fish_redraw_timer
	fixture.paused = true
	fish._process(1.0)
	fixture.paused = false
	fixture.started = false
	fish._process(1.0)
	fixture.started = true
	fixture.game_over = true
	fish._process(1.0)
	fixture.game_over = false
	paused = true
	fish._process(1.0)
	paused = false
	fish.hide()
	fish._process(1.0)
	fish.show()
	fixture.hide()
	fish._process(1.0)
	fixture.show()
	fish.position = Vector2(600, 100)
	fish._process(1.0)
	fish.position = anchor
	fish._process(0.0)
	fish._process(-1.0)
	fish._process(INF)
	assert(fish.fish_time == frozen_time and fish.fish_redraw_timer == frozen_timer, "inactive, hidden and offscreen fish must freeze both cosmetic timers")
	# A partially visible school still animates, with culling in canvas space.
	viewport.canvas_transform = Transform2D(0.0, Vector2(-120, 0))
	fish._process(0.1)
	assert(is_equal_approx(fish.fish_time, frozen_time + 0.1), "school margin must keep partly visible fish animating")
	viewport.canvas_transform = Transform2D(0.0, Vector2(-160, 0))
	fish._process(0.1)
	assert(is_equal_approx(fish.fish_time, frozen_time + 0.1), "canvas translation must cull fully offscreen fish")
	viewport.canvas_transform = Transform2D(Vector2(0.7, -0.35), Vector2(0.7, 0.35), Vector2(-40, 100))
	fish._process(0.1)
	assert(is_equal_approx(fish.fish_time, frozen_time + 0.2), "projected water plane must animate visible fish in 2.5D")
	assert(fish.position == anchor and fish.radius == 22.0 and fish.amount == 500 and fish.home_position == anchor, "animation must not alter the resource anchor, footprint or yield")
	assert(fish.wander_time == initial_wander and fish.deer_rng.state == initial_rng, "cosmetic animation must not advance wildlife state or RNG")
	fish.setup("food", 500, "fish")
	assert(fish.fish_time == 0.0 and fish.fish_redraw_timer == 0.0 and fish.fish_visual_seed == seed_value, "reusing a resource must reset cosmetic timers without changing its layout")
	fixture.remove_child(fish)
	fish._process(0.1)
	assert(fish.fish_time == 0.0, "detached fish must not animate")
	fish.free()
	viewport.free()

func _check_real_match() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 6789)
	game.fog.active = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.navigation.route_budget_enabled = false
	var fish: RtsResource
	for resource in game.resources:
		if resource.appearance == "fish":
			fish = resource
			break
	assert(fish != null and game.world_map.is_navigable(fish.position), "map generation must retain navigable fish resource anchors")
	var anchor := fish.position
	var original_amount := fish.amount
	fish.show()
	game.camera.position = anchor
	game.camera.force_update_scroll()
	assert(not fish.is_processing(), "match runtime must own resource callbacks")
	var before_step := fish.fish_time
	game.step(0.1)
	assert(fish.fish_time > before_step, "runtime simulation must dispatch fish animation after disabling automatic callbacks")
	var boat: RtsUnit = game.spawn_unit(0, "fishing_boat", anchor + Vector2(60, 0))
	game.selected.assign([boat])
	game._issue_order(anchor)
	assert(boat.order == "gather" and boat.target == fish, "right-clicking the fish anchor must retain the fishing command")
	var food_before: int = game.players[0]["food"]
	for frame in 200:
		boat._process(0.1)
		if game.players[0]["food"] > food_before: break
	assert(game.players[0]["food"] > food_before and fish.amount < original_amount, "fishing must still turn fish resource quantity into food")
	assert(fish.position == anchor and game.world_map.is_navigable(anchor), "school animation and harvest must leave the resource on water")
	assert(not game.navigation.can_occupy(anchor, game.units[0].radius(), game.units[0]), "fish visuals must not open naval water to land navigation")
	var resource_id := fish.get_instance_id()
	game.selected.assign([fish])
	var remaining := fish.amount
	assert(fish.harvest(remaining + 20) == remaining and fish.amount == 0 and fish.is_queued_for_deletion(), "final harvest must return the remaining yield and retire the fish resource")
	var retired_time := fish.fish_time
	fish._process(0.1)
	assert(fish.fish_time == retired_time, "depleted resources awaiting deletion must not animate")
	await process_frame
	assert(not is_instance_id_valid(resource_id), "depleted fish must be freed")
	assert(game.selected.is_empty(), "resource removal must clean up selection")
	for resource in game.resources:
		assert(is_instance_valid(resource) and resource.get_instance_id() != resource_id, "resource registry must remove depleted fish")
	game.free()
