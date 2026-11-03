extends RefCounted
## Local quest service. Original quest/mission categories inform the interface;
## the six explicitly labelled TWILIGHT example objectives are NOT source claims.
const PATH: String = "res://data/quests/twilight_quests.json"
var definitions: Array[Dictionary] = []
var by_id: Dictionary = {}
var progress: Dictionary = {}
var completed: Dictionary = {}

func configure() -> void:
	definitions.clear()
	by_id.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("schema",0)) != 1:
		push_error("Quest definitions missing/invalid")
		return
	for raw: Variant in (parsed as Dictionary).get("quests",[]):
		if not (raw is Dictionary):
			continue
		var q: Dictionary = raw as Dictionary
		var id: String = str(q.get("id",""))
		if id.is_empty() or by_id.has(id) or str(q.get("kind","")) not in ["acquire","kill"] or int(q.get("required",0)) < 1:
			continue
		if not q.get("reward",{}) is Dictionary:
			continue
		definitions.append(q)
		by_id[id] = q

func export_state() -> Dictionary:
	return {"schema":1,"progress":progress.duplicate(true),"completed":completed.duplicate(true)}

func import_state(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var source: Dictionary = value as Dictionary
	if int(source.get("schema",0)) != 1 or not (source.get("progress",{}) is Dictionary) or not (source.get("completed",{}) is Dictionary):
		return false
	var clean_progress: Dictionary = {}
	var clean_completed: Dictionary = {}
	for raw_id: Variant in source.completed:
		var id: String = str(raw_id)
		if not by_id.has(id) or source.completed[raw_id] != true:
			return false
		clean_completed[id] = true
	for raw_id: Variant in source.progress:
		var id: String = str(raw_id)
		if not by_id.has(id) or not (source.progress[raw_id] is int or source.progress[raw_id] is float):
			return false
		var amount: int = int(source.progress[raw_id])
		if amount < 0 or amount > int((by_id[id] as Dictionary).required):
			return false
		clean_progress[id] = amount
	progress = clean_progress
	completed = clean_completed
	return true

func is_available(q: Dictionary) -> bool:
	var prior: String = str(q.get("requires",""))
	return prior.is_empty() or completed.has(prior)

func apply_event(kind: String, target: String, quantity: int = 1) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	if quantity < 1:
		return earned
	# Each objective can pay once, and chained objectives cannot inherit
	# the event that completed their predecessor.
	var available_before: Dictionary = {}
	for q: Dictionary in definitions:
		available_before[str(q.id)] = is_available(q)
	for q: Dictionary in definitions:
		var id: String = str(q.id)
		if completed.has(id) or not bool(available_before[id]) or str(q.kind) != kind or str(q.target) != target:
			continue
		var previous: int = int(progress.get(id,0))
		var updated: int = mini(int(q.required),previous+quantity)
		progress[id] = updated
		if updated >= int(q.required):
			completed[id] = true
			earned.append({"id":id,"title":str(q.title),"reward":q.reward})
	return earned

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q: Dictionary in definitions:
		var row: Dictionary = q.duplicate(true)
		row["progress"] = int(progress.get(str(q.id),0))
		row["completed"] = completed.has(str(q.id))
		row["available"] = is_available(q)
		result.append(row)
	return result
