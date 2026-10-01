extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	setup_case()
	await run_case("trade_return_market")
	assert(results.back().status == "pass", "Trader must settle the return leg outside the market")
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	setup_case()
	var market: RtsBuilding = game.spawn_building(0, "market", free_site("market"))
	var post: RtsTradePost = game.trade_posts[0]
	var trader := soldier("trader", 0, post.position)
	trader.trade_home = market
	trader.issue_command("trade", Vector2.INF, post)
	trader.position = post.position
	trader._process_trade_order(0.0)
	assert(trader.trade_returning)
	var boundary: float = market.size().x * 0.5 + trader.radius() + 4.0
	trader.position = market.position + Vector2(boundary + 2.0, 0)
	var before: int = game.players[0]["gold"]
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] == before and trader.trade_returning)
	trader.position = market.position + Vector2(boundary, 0)
	assert(game.navigation.can_occupy(trader.position, trader.radius(), trader, false))
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] > before and not trader.trade_returning)
	before = game.players[0]["gold"]
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] == before)
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	setup_case()
	game.start_game("English", 1, "French")
	game.ai_controllers.clear()
	game.fog.active = false
	# This was a legal placement whose two settlement circles overlapped.
	# Enlarging the return range must not introduce stationary infinite trade.
	var near_post := Vector2(1280, 280)
	var saved_posts: Array = game.trade_posts.duplicate()
	game.trade_posts.clear()
	assert(game.can_place("market", near_post), "Seed 1 site must otherwise be a legal market")
	game.trade_posts.assign(saved_posts)
	assert(not game.can_place("market", near_post))
	var far_post := free_site("market", near_post + Vector2(300, 0))
	assert(far_post.is_finite() and game.can_place("market", far_post))
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B05_OK")
	quit()
