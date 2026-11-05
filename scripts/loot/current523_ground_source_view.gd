extends Node2D
## Presentation child of an existing ground-loot view; owns no loot or save state.
signal source_status_changed(status: Dictionary)
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const SELECTION = preload("res://scripts/resources/current523_source_ground_selection.gd")
var selection_status: Dictionary = {}
var _preview: PREVIEW = null
var _stored_direction: int = -1

func _init() -> void:
	set_process(false)

func clear_source() -> void:
	set_process(false)
	_stored_direction = -1
	if is_instance_valid(_preview):
		_preview.clear()
		if _preview.get_parent() == self: remove_child(_preview)
		_preview.free()
	_preview = null
	hide()

func _pending(reason: String, bank_status: Dictionary = {}) -> bool:
	selection_status["ok"] = false
	selection_status["status"] = "source_only_pending"
	selection_status["reason"] = reason
	if not bank_status.is_empty(): selection_status["bank_status"] = bank_status.duplicate(true)
	clear_source()
	source_status_changed.emit(selection_status.duplicate(true))
	return false

func configure_ground_source(original_item: Dictionary, source_bank_context: Dictionary = {}, binding: Dictionary = {}) -> bool:
	clear_source()
	selection_status = SELECTION.select(original_item,source_bank_context,binding)
	if not selection_status.get("ok",false): return false
	var selected: Dictionary = selection_status.duplicate(true)
	var candidate := PREVIEW.new()
	if not candidate._configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),selected.role_actions,selected.loop_policy,"ground","ground_item"):
		var problem: Dictionary = candidate.reference_bank_status.duplicate(true)
		candidate.free()
		return _pending(str(problem.get("error","current523_ground_source_action_unavailable")),problem)
	_preview = candidate
	_stored_direction = int(selected.stored_direction)
	_preview.position = Vector2.ZERO
	_preview._reference_request_context = selected.source_bank_context.duplicate(true)
	_preview._reference_card_context = selected.duplicate(true)
	_preview.source_selection_status = selected.duplicate(true)
	_preview.reference_bank_status["purpose"] = "existing_ground_item_consumer"
	_preview.reference_bank_status["host_policy"] = selected.host_policy
	add_child(_preview)
	if not _preview.advance_reference_source(0.0,"ground",_stored_direction):
		var problem: Dictionary = _preview.reference_bank_status.duplicate(true)
		return _pending(str(problem.get("error","current523_ground_initial_source_frame_unavailable")),problem)
	selection_status["status"] = "configured_existing_ground_source"
	show()
	set_process(true)
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(_preview): return
	if not _preview.advance_reference_source(delta,"ground",_stored_direction):
		var problem: Dictionary = _preview.reference_bank_status.duplicate(true)
		_pending(str(problem.get("error","current523_ground_source_frame_unavailable")),problem)

func source_frame_status() -> Dictionary:
	return _preview.reference_source_frame_status() if is_instance_valid(_preview) else {}
