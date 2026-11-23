extends Node
## Ledger lifetime spans map scene changes; only process teardown may join.
const USAGE = preload("res://scripts/maps/current523_map_usage.gd")
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func _process(_delta: float) -> void: USAGE.pump()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		USAGE.flush(true)
		USAGE.pump()
func _exit_tree() -> void: USAGE.finish()
