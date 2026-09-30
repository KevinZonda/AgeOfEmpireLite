extends RefCounted

# Match mutations publish facts after a complete transaction. Subscribers may
# coalesce several commits; this object has no knowledge of controls or scenes.
signal changed(owner_id: int, domains: Array[StringName])
signal feedback_requested(owner_id: int, message: String)

var _depth := 0
var _pending: Dictionary = {}
var _feedback: Array[Dictionary] = []

func begin_transaction() -> void:
	_depth += 1

func end_transaction() -> void:
	assert(_depth > 0, "unbalanced match transaction")
	_depth -= 1
	if _depth == 0: _publish()

func mark(owner_id: int, domain: StringName) -> void:
	if not _pending.has(owner_id): _pending[owner_id] = {}
	_pending[owner_id][domain] = true
	if _depth == 0: _publish()

func feedback(owner_id: int, message: String) -> void:
	_feedback.append({"owner_id": owner_id, "message": message})
	if _depth == 0: _publish()

func _publish() -> void:
	# Detach before invoking subscribers so nested mutations form a new commit.
	var pending := _pending
	var feedback_items := _feedback
	_pending = {}
	_feedback = []
	for owner_id in pending:
		var domains: Array[StringName] = []
		for domain in pending[owner_id]: domains.append(domain)
		changed.emit(owner_id, domains)
	for item in feedback_items:
		feedback_requested.emit(item["owner_id"], item["message"])
