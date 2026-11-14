extends Node
## First node processed every frame: closes the previous frame's hitch record.
## See frame_hitch_log.gd. Runs while paused so a stalled menu is measured too.
const FRAME_HITCH := preload("res://scripts/boot/frame_hitch_log.gd")
const BOOT_LOG := preload("res://scripts/boot/boot_progress_log.gd")
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
		BOOT_LOG.mark("alive", {"map": map_id})

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
