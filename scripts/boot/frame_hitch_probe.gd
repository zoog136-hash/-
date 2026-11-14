extends Node
## First node processed every frame: closes the previous frame's hitch record.
## See frame_hitch_log.gd. Runs while paused so a stalled menu is measured too.
const FRAME_HITCH := preload("res://scripts/boot/frame_hitch_log.gd")
const BOOT_LOG := preload("res://scripts/boot/boot_progress_log.gd")
const DEFINITIONS := preload("res://scripts/resources/current523_definition_rows.gd")
const SP2_ASSETS := preload("res://scripts/resources/reference_sp2_asset_service.gd")
## Gameplay heartbeat in boot_progress.log (with memory), so the next loading
## screen can say what the app was doing when the system closed it.
const ALIVE_MSEC: int = 5000
var _tail: Node
var _alive_at: int = 0

class ProcessTail extends Node:
	func _init() -> void:
		process_priority = 2147483647
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_delta: float) -> void:
		FRAME_HITCH.process_tail()

func _enter_tree() -> void:
	process_priority = -2147483647
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Both callbacks are delivered on the main thread. A separate render
	# thread defers post_draw, so its delivery cannot identify the same draw.
	FRAME_HITCH.configure_draw_delivery(RenderingServer.is_on_render_thread())
	if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	if not RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.connect(_on_post_draw)

func _ready() -> void:
	FRAME_HITCH.start()
	# Priority orders this process group only; deferred work, physics and
	# other groups are not bounded by this marker. Keep the child on re-entry.
	if _tail == null:
		_tail = ProcessTail.new()
		add_child(_tail)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)

func _on_pre_draw() -> void:
	FRAME_HITCH.draw_pre()

func _on_post_draw() -> void:
	FRAME_HITCH.draw_post()

func _process(_delta: float) -> void:
	var host: Node = get_parent()
	var map_id: String = str(host.get("active_map_id")) if host != null else ""
	FRAME_HITCH.frame(map_id)
	var now: int = Time.get_ticks_msec()
	if now - _alive_at >= ALIVE_MSEC:
		_alive_at = now
		var fields: Dictionary = alive_fields(map_id)
		fields.merge(world_fields(host), true)
		BOOT_LOG.mark("alive", fields)
		DEFINITIONS.remember_used_tables()

## What holds memory, so the next loading screen can name it (MB, counts).
static func alive_fields(map_id: String) -> Dictionary:
	var fields: Dictionary = {"map": map_id}
	var sp2: Dictionary = SP2_ASSETS.stats()
	for kind: String in ["parsed", "texture"]:
		var entry: Dictionary = sp2.get(kind, {})
		var bytes: int = int(entry.get("live_bytes", 0)) + int(entry.get("idle_bytes", 0)) + int(entry.get("stale_live_bytes", 0)) + int(entry.get("pending_bytes", 0))
		fields["sp2_" + kind + "_mb"] = bytes / 1048576
		fields["sp2_" + kind + "_n"] = int(entry.get("live_count", 0)) + int(entry.get("idle_count", 0))
	fields["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	fields["resources"] = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	fields["tables"] = DEFINITIONS._tables.size()
	fields["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	return fields

## 523 field/renderer/actor sizes from the world, for the same heartbeat.
static func world_fields(world: Node) -> Dictionary:
	var fields: Dictionary = {}
	if world == null: return fields
	var renderer: Variant = world.get("field_renderer")
	if renderer is Object and is_instance_valid(renderer):
		for key: String in ["_raw_chunks", "_frame_atlases", "_frame_commands", "_static_tails", "_chunk_rects"]:
			var value: Variant = (renderer as Object).get(key)
			if value is Dictionary: fields["r" + key] = (value as Dictionary).size()
	var monsters: Variant = world.get("monsters_root")
	if monsters is Node and is_instance_valid(monsters): fields["actors"] = (monsters as Node).get_child_count()
	var field: Variant = world.get("field_map")
	if field is Object and is_instance_valid(field):
		var chunks: Variant = (field as Object).get("chunk_table")
		if chunks is Dictionary: fields["field_chunks"] = (chunks as Dictionary).size()
	return fields

func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if not pressed: return
	var control: Control = get_viewport().gui_get_hovered_control()
	BOOT_LOG.mark("touch", {"at": str(control.name) if control != null else "world"})

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: FRAME_HITCH.lifecycle(0)
		NOTIFICATION_APPLICATION_RESUMED: FRAME_HITCH.lifecycle(1)
		NOTIFICATION_APPLICATION_FOCUS_OUT: FRAME_HITCH.lifecycle(2)
		NOTIFICATION_APPLICATION_FOCUS_IN: FRAME_HITCH.lifecycle(3)
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PREDELETE]:
		FRAME_HITCH.flush()
