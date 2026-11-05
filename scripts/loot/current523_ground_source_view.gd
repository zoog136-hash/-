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

func configure_ground_source(original_item: Dictionary, source_bank_context: Dictionary = {}, binding: Dictionary = {}) -> bool:
	clear_source()
	selection_status = SELECTION.select(original_item,source_bank_context,binding)
	source_status_changed.emit(selection_status.duplicate(true))
	# No original ground renderer/member contract has been supplied yet. Keep
	# this actual loot view pending; an actor, UI icon or drop effect cannot fill it.
	return false

func source_frame_status() -> Dictionary:
	return {}
