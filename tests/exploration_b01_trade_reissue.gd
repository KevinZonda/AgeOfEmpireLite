extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	setup_case()
	var post: RtsTradePost = game.trade_posts[0]
	var market: RtsBuilding = game.spawn_building(0, "market", free_site("market"))
	var trader := soldier("trader", 0, post.position)
	trader.issue_command("trade", Vector2.INF, post)
	trader.position = post.position
	var gold_before: int = game.players[0]["gold"]
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] > gold_before and trader.trade_returning)
	gold_before = game.players[0]["gold"]
	for i in 10:
		trader.issue_command("trade", Vector2.INF, post)
		trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] == gold_before and trader.trade_returning)
	trader.order_stop()
	trader.issue_command("trade", Vector2.INF, post)
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] == gold_before and trader.trade_returning)
	# Choosing another home market cannot reset a paid outbound leg either.
	var second: RtsBuilding = game.spawn_building(0, "market", free_site("market", market.position + Vector2(300, 0)))
	trader.trade_home = second
	trader.issue_command("trade", Vector2.INF, post)
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] == gold_before and trader.trade_returning)
	# A genuine visit to home still pays and starts the next outbound leg.
	trader.position = second.position
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] > gold_before and not trader.trade_returning)
	gold_before = game.players[0]["gold"]
	trader.position = post.position
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] > gold_before and trader.trade_returning)
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B01_OK")
	quit()
