extends RefCounted

# Ordinary/range searches remain on the main thread because they use live
# scene objects and shared grids. FIFO admission spreads an army's searches
# across frames. This is a SOFT budget: one native A* query cannot be preempted.
const MAX_PENDING := 512
var budget_us := 4000
var max_queries_per_frame := 64
var pending: Array[Dictionary] = []
var current: Dictionary = {}
var completed: Dictionary = {}
var serial := 0
var last_frame := -1
var metrics := {"requested": 0, "updated": 0, "finished": 0, "discarded": 0, "rejected": 0, "max_pending": 0, "search_us": 0, "max_query_us": 0, "max_tick_us": 0}

func request(unit: RtsUnit, target: Vector2, reach: float, use_range: bool) -> bool:
	var id := unit.get_instance_id()
	if current.has(id):
		var existing: Dictionary = current[id]
		if _valid(existing):
			if not completed.has(id):
				# A moving formation/target updates its pending endpoint in place.
				# Cancelling and appending each frame would starve the back of an
				# army's queue even though the unit/order generation never changed.
				if existing.target != target or not is_equal_approx(existing.reach, reach) or existing.use_range != use_range: metrics.updated += 1
				existing.target = target
				existing.reach = reach
				existing.use_range = use_range
				return true
			if existing.target.distance_to(target) <= RtsWorldMap.CELL_SIZE * 0.5 and is_equal_approx(existing.reach, reach) and existing.use_range == use_range: return true
		cancel(unit)
	if pending.size() >= MAX_PENDING:
		metrics.rejected += 1
		return false
	serial += 1
	var job := {"id": id, "ticket": serial, "unit": weakref(unit), "generation": unit.route_generation,
		"order": unit.order, "owner": unit.owner_id, "target": target, "reach": reach, "use_range": use_range}
	current[id] = job
	pending.append(job)
	metrics.requested += 1
	metrics.max_pending = maxi(metrics.max_pending, pending.size())
	return true

func has_request(unit: RtsUnit) -> bool:
	return current.has(unit.get_instance_id())

func cancel(unit: RtsUnit) -> void:
	var id := unit.get_instance_id()
	if not current.has(id) and not completed.has(id): return
	var was_pending := current.has(id) and not completed.has(id)
	current.erase(id)
	completed.erase(id)
	if not was_pending: return
	for i in range(pending.size() - 1, -1, -1):
		if pending[i].id == id: pending.remove_at(i)

func _valid(job: Dictionary) -> bool:
	var unit: RtsUnit = job.unit.get_ref()
	return unit != null and not unit.is_queued_for_deletion() and unit.garrisoned_in == null and unit.route_generation == job.generation and unit.order == job.order and unit.owner_id == job.owner and current.has(job.id) and current[job.id].ticket == job.ticket

func _discard(job: Dictionary) -> void:
	metrics.discarded += 1
	completed.erase(job.id)
	if current.has(job.id) and current[job.id].ticket == job.ticket: current.erase(job.id)

func tick(navigation, simulation_frame := -1) -> void:
	# Production uses the engine epoch; deterministic simulators may supply
	# their own monotonically increasing frame without advancing SceneTree.
	var frame := Engine.get_process_frames() if simulation_frame < 0 else simulation_frame
	if last_frame == frame: return
	last_frame = frame
	# Results not consumed by dead/cancelled units must never hold a slot.
	for job in completed.values():
		if not _valid(job): _discard(job)
	var started := Time.get_ticks_usec()
	var queries := 0
	while not pending.is_empty() and queries < max_queries_per_frame:
		var job: Dictionary = pending.pop_front()
		if not _valid(job):
			_discard(job)
		else:
			var unit: RtsUnit = job.unit.get_ref()
			navigation._ensure_current()
			job.origin = unit.position
			job.radius = unit.radius()
			job.naval = unit.stats.get("tags", []).has("naval")
			job.revision = navigation.obstacle_revision
			var query_started := Time.get_ticks_usec()
			job.path = navigation.path_to_range(job.origin, job.target, job.reach, unit) if job.use_range else navigation.path_between(job.origin, job.target, unit)
			var elapsed := Time.get_ticks_usec() - query_started
			metrics.search_us += elapsed
			metrics.max_query_us = maxi(metrics.max_query_us, elapsed)
			completed[job.id] = job
			metrics.finished += 1
			queries += 1
		if Time.get_ticks_usec() - started >= budget_us: break
	metrics.max_tick_us = maxi(metrics.max_tick_us, Time.get_ticks_usec() - started)

func take(unit: RtsUnit, target: Vector2, reach: float, use_range: bool, navigation) -> Dictionary:
	var id := unit.get_instance_id()
	if not completed.has(id): return {}
	var job: Dictionary = completed[id]
	navigation._ensure_current()
	if not _valid(job) or job.target.distance_to(target) > RtsWorldMap.CELL_SIZE * 0.5 or not is_equal_approx(job.reach, reach) or job.use_range != use_range or job.revision != navigation.obstacle_revision or not is_equal_approx(job.radius, unit.radius()) or job.naval != unit.stats.get("tags", []).has("naval") or job.origin.distance_to(unit.position) > unit.radius() * 2.0:
		_discard(job)
		return {}
	completed.erase(id)
	current.erase(id)
	var path: PackedVector2Array = job.path
	if path.size() > 1 and not navigation._static_segment_clear(unit.position, path[1], unit.radius(), unit):
		# Fine routing may start at a grid connector less than one pixel from
		# the origin. The connector's next edge can be safe even when skipping
		# that tiny first turn clips a building corner. Preserve the connector,
		# rather than repeatedly discarding the same otherwise valid route.
		# Never reconnect by returning to a displaced captured unit position.
		if path[0] == job.origin or not navigation._static_segment_clear(unit.position, path[0], unit.radius(), unit):
			metrics.discarded += 1
			return {}
		path.insert(0, unit.position)
	elif not path.is_empty():
		path[0] = unit.position
	# Empty path is a completed failure; empty dictionary means still pending
	# or discarded. Movement must not apply retry backoff while merely queued.
	return {"path": path}

func reset() -> void:
	pending.clear()
	current.clear()
	completed.clear()
	last_frame = -1
