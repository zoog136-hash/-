extends Node2D
## Pending source-ground boundary; owns no loot, save state or substitute art.
signal source_status_changed(status: Dictionary)
const SELECTION = preload("res://scripts/resources/current523_source_ground_selection.gd")
var selection_status: Dictionary = {}

func _init() -> void:
	set_process(false)

func clear_source() -> void:
	set_process(false)
	hide()

func configure_ground_source(original_item: Dictionary, source_bank_context: Dictionary = {}, binding: Dictionary = {}, owner_context: Dictionary = {}, expected_ground_id: String = "") -> bool:
	clear_source()
	if not owner_context.is_empty() and owner_context.get("ok") != true:
		selection_status = SELECTION.fail("current523_ground_owner_context_unavailable",{"table":"ItemClass","row":original_item.duplicate(true),"field":"SpriteID"})
	elif not owner_context.is_empty() and ((not expected_ground_id.is_empty() and owner_context.get("ground_id") != expected_ground_id) or owner_context.get("original_item") != original_item):
		selection_status = SELECTION.fail("current523_ground_owner_selection_differs",{"table":"ItemClass","row":original_item.duplicate(true),"field":"SpriteID"})
	else:
		selection_status = SELECTION.select(original_item,source_bank_context,binding)
	if not owner_context.is_empty(): selection_status["source_owner_context"] = owner_context.duplicate(true)
	source_status_changed.emit(selection_status.duplicate(true))
	# No original ground renderer/member contract has been supplied yet. Keep
	# this actual loot view pending; an actor, UI icon or drop effect cannot fill it.
	return false

func source_frame_status() -> Dictionary:
	return {}
