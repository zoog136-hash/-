extends Node
## Nonvisual endpoint for PR265's existing view/host signal contract.
## Original source controls supply the selection and confirmation events.
signal preview_requested(action: Dictionary)
signal commit_requested(action: Dictionary)
signal install_requested(path: String, sha256: String)
signal model_changed
signal quote_received(quote: Dictionary)
signal operation_result(result: Dictionary)
signal closed
var _snapshot: Dictionary={}
var _selection: Dictionary={}
var _pending_action: Dictionary={}
var _quoted_action: Dictionary={}
var _waiting: bool=false
var _quoted_ok: bool=false
var _confirmed: bool=false
var _source_scene: WeakRef

func bind_source_scene(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or not scene.has_method("playback_status"):return {"ok":false,"code":"original_equipment_scene_required"}
	var status: Dictionary=scene.call("playback_status")
	if bool(status.get("inspection_only",true)) or str(status.get("source","")).is_empty():return {"ok":false,"code":"original_equipment_scene_required"}
	_source_scene=weakref(scene)
	return {"ok":true,"transaction_performed":false}

func _source_ready() -> bool:
	var scene: Node2D=_source_scene.get_ref() if _source_scene!=null else null
	return is_instance_valid(scene) and scene.is_inside_tree() and scene.is_visible_in_tree() and not scene.is_queued_for_deletion()

func set_snapshot(data: Dictionary) -> void:
	_snapshot=data.duplicate(true)
	_invalidate_quote()
	model_changed.emit()

func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func select_action(action: Dictionary) -> Dictionary:
	# The existing caller supplies kind, actual instance IDs, recipe_type and
	# slot. Never construct these from node labels, names or guessed quantities.
	_selection=action.duplicate(true)
	_invalidate_quote()
	model_changed.emit()
	return {"ok":true,"selection_changed":true,"transaction_performed":false}

func set_confirmation(value: bool) -> Dictionary:
	_confirmed=value
	return {"ok":true,"transaction_performed":false}

func request_preview() -> Dictionary:
	if not _source_ready():return {"ok":false,"code":"presentation_unavailable"}
	if _waiting or _selection.is_empty():return {"ok":false,"code":"source_selection_unavailable"}
	_invalidate_quote()
	_pending_action=_selection.duplicate(true)
	_waiting=true
	preview_requested.emit(_pending_action.duplicate(true))
	return {"ok":true,"preview_requested":true,"transaction_performed":false}

func show_quote(quoted: Dictionary) -> void:
	if not _waiting or _pending_action!=_selection:return
	_waiting=false
	_quoted_ok=bool(quoted.get("ok",false))
	_confirmed=false
	_quoted_action=_pending_action.duplicate(true) if _quoted_ok else {}
	quote_received.emit(quoted.duplicate(true))

func request_commit() -> Dictionary:
	if not _source_ready():return {"ok":false,"code":"presentation_unavailable"}
	if _waiting or not _confirmed or not _quoted_ok or _quoted_action!=_selection:return {"ok":false,"code":"source_confirmation_required"}
	var action: Dictionary=_quoted_action.duplicate(true)
	_invalidate_quote()
	commit_requested.emit(action)
	return {"ok":true,"commit_requested":true,"transaction_performed":false}

func show_result(result: Dictionary) -> void:
	_invalidate_quote()
	operation_result.emit(result.duplicate(true))

func cancel() -> Dictionary:
	_invalidate_quote()
	return {"ok":true,"cancelled":true,"transaction_performed":false}

func close() -> Dictionary:
	_invalidate_quote()
	closed.emit()
	return {"ok":true,"closed":true,"transaction_performed":false}

func _invalidate_quote() -> void:
	_waiting=false
	_quoted_ok=false
	_confirmed=false
	_pending_action.clear()
	_quoted_action.clear()
