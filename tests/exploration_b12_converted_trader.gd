extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	setup_case()
	var foreign: RtsBuilding = game.spawn_building(1, "market", free_site("market"))
	var post: RtsTradePost = game.trade_posts[0]
	var trader := soldier("trader", 1, post.position)
	trader.issue_command("trade", Vector2.INF, post)
	assert(trader.order == "trade" and trader.trade_home == foreign)
	var monk := soldier("monk", 0, post.position + Vector2(15, 0))
	carry(monk)
	monk.conversion_timer = 0.0
	monk._finish_conversion()
	assert(trader.owner_id == 0)
	var before: int = game.players[0]["gold"]
	trader._process_trade_order(0.0)
	assert(trader.order == "idle" and game.players[0]["gold"] == before)
	assert(not trader._start_command({"type": "trade", "target": post}))
	var own: RtsBuilding = game.spawn_building(0, "market", free_site("market", foreign.position + Vector2(400, 0)))
	assert(trader._start_command({"type": "trade", "target": post}))
	assert(trader.trade_home == own)
	trader.position = post.position
	trader._process_trade_order(0.0)
	assert(game.players[0]["gold"] > before)
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B12_OK")
	quit()
