extends RefCounted

const Recovery = preload("res://scripts/world/navigation_recovery.gd")
const MAX_ACTIVE := 2
const MAX_PENDING := 128
const DISPATCH_BUDGET_US := 1000
const MAX_REQUEST_AGE_MS := 2000
# All queue metadata belongs to the main thread. Only a job's snapshot is
# accessed by its worker, and only after completion may the main thread read it.
var pending: Array[Dictionary] = []
var active: Array[Dictionary] = []
var current := {}
var completed := {}
var serial := 0
var metrics := {"submitted": 0, "finished": 0, "discarded": 0, "accepted": 0, "snapshot_us": 0, "worker_us": 0, "max_active": 0, "max_pending": 0}

func request(unit: RtsUnit, target: Vector2, fallback: Vector2) -> bool:
	var id := unit.get_instance_id()
	if current.has(id): return true
	if pending.size() >= MAX_PENDING: return false
	serial += 1
	var job := {"id": id, "ticket": serial, "unit": weakref(unit), "generation": unit.route_generation,
		"order": unit.order, "owner": unit.owner_id, "created_ms": Time.get_ticks_msec(), "goal": unit.route_goal, "target": target, "fallback": fallback}
	current[id] = serial
	pending.append(job)
	metrics.max_pending = maxi(metrics.max_pending, pending.size())
	return true

func cancel(unit: RtsUnit) -> void:
	var id := unit.get_instance_id()
	current.erase(id)
	completed.erase(id)
	for i in range(pending.size() - 1, -1, -1):
		if pending[i].id == id: pending.remove_at(i)

func has_request(unit: RtsUnit) -> bool:
	return current.has(unit.get_instance_id())

func _valid(job: Dictionary) -> bool:
	var unit: RtsUnit = job.unit.get_ref()
	return unit != null and not unit.is_queued_for_deletion() and unit.garrisoned_in == null and unit.route_generation == job.generation and unit.order == job.order and unit.owner_id == job.owner and Time.get_ticks_msec() - job.created_ms <= MAX_REQUEST_AGE_MS and current.get(job.id, -1) == job.ticket

func tick(navigation, allow_dispatch := true) -> void:
	# Never join incomplete work in the frame loop. Reaping a completed task
	# establishes ownership of its output and releases the engine task record.
	for i in range(active.size() - 1, -1, -1):
		var job := active[i]
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		active.remove_at(i)
		metrics.finished += 1
		metrics.worker_us += job.snapshot.elapsed_us
		if _valid(job): completed[job.id] = job
		else:
			metrics.discarded += 1
			if current.get(job.id, -1) == job.ticket: current.erase(job.id)
	for id in completed.keys():
		if not _valid(completed[id]):
			completed.erase(id)
			current.erase(id)
	if not allow_dispatch: return
	var started := Time.get_ticks_usec()
	while active.size() < MAX_ACTIVE and not pending.is_empty():
		var job: Dictionary = pending.pop_front()
		if not _valid(job):
			if current.get(job.id, -1) == job.ticket: current.erase(job.id)
			continue
		var unit: RtsUnit = job.unit.get_ref()
		navigation._ensure_current()
		var capture_start := Time.get_ticks_usec()
		var snapshot = Recovery.capture(navigation, unit)
		metrics.snapshot_us += Time.get_ticks_usec() - capture_start
		snapshot.target = job.target
		snapshot.fallback = job.fallback
		job.snapshot = snapshot
		job.revision = navigation.retry_obstacle_revision
		job.task = WorkerThreadPool.add_task(snapshot.run, false, "RTS crowd recovery")
		active.append(job)
		metrics.submitted += 1
		metrics.max_active = maxi(metrics.max_active, active.size())
		if Time.get_ticks_usec() - started >= DISPATCH_BUDGET_US: break

func take(unit: RtsUnit, goal: Vector2, navigation) -> Dictionary:
	var id := unit.get_instance_id()
	if not completed.has(id): return {}
	var job: Dictionary = completed[id]
	completed.erase(id)
	var valid := _valid(job)
	current.erase(id)
	var snapshot = job.snapshot
	if not valid or not is_equal_approx(snapshot.radius, unit.radius()) or snapshot.naval != unit.stats.get("tags", []).has("naval") or job.revision != navigation.retry_obstacle_revision or job.goal.distance_to(goal) > RtsWorldMap.CELL_SIZE * 0.5 or snapshot.origin.distance_to(unit.position) > unit.radius() * 2.0:
		metrics.discarded += 1
		return {}
	var path: PackedVector2Array = snapshot.result
	# Never snap to the captured start. Connect the CURRENT position to the
	# first advancing waypoint using current deer/unit/building collisions.
	if path.size() > 1 and not navigation._segment_clear(unit.position, path[1], unit.radius(), unit):
		metrics.discarded += 1
		return {}
	metrics.accepted += 1
	return {"path": path, "target": job.target}

func shutdown() -> void:
	# Waiting is confined to scene teardown/reset, never normal frame dispatch.
	pending.clear()
	current.clear()
	completed.clear()
	for job in active: WorkerThreadPool.wait_for_task_completion(job.task)
	active.clear()
