extends Control
## In-game transition overlay; separate from boot/character initialization.
const STYLE = preload("res://scripts/boot/boot_style.gd")
const SOURCE_ART := preload("res://scripts/boot/source_loading_art.gd")
const GROUP = "twilight_dungeon_loading"
var _label: Label
var _column: VBoxContainer
var _title: String = "던전 이동 준비"
var _show_cover: bool = true
var painted: bool = false
var started_usec: int = 0
var first_paint_usec: int = 0
var operation_usec: int = 0
var arrival_ready_usec: int = -1
signal completed(result: Dictionary)

static func report(world: Node, text: String) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	var overlay: Node = world.get_tree().get_first_node_in_group(GROUP)
	if overlay != null and overlay._label != null: overlay._label.text = text

static func arrival_ready(world: Node) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	var overlay: Node = world.get_tree().get_first_node_in_group(GROUP)
	if overlay != null: overlay.arrival_ready_usec = Time.get_ticks_usec()-overlay.started_usec

## The callable keeps the existing eligibility, quote and atomic payment owner.
## Freeze the tree, not movement_locked: eligibility checks must see the real
## pre-existing player state. Concurrent requests cannot quote/debit twice.
static func busy(world: Node) -> bool:
	return world.is_inside_tree() and world.get_tree().get_first_node_in_group(GROUP) != null


static func run(world: Node, operation: Callable, title: String = "던전 이동 준비", show_cover: bool = true) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree() or not operation.is_valid(): return {"ok":false,"reason":"이동 요청을 사용할 수 없습니다."}
	var tree: SceneTree = world.get_tree()
	if tree.get_first_node_in_group(GROUP) != null: return {"ok":false,"busy":true,"reason":"다른 이동을 준비하고 있습니다."}
	var started: int = Time.get_ticks_usec()
	var overlay = load("res://scripts/boot/dungeon_loading.gd").new()
	overlay._title = title
	overlay.started_usec = started
	overlay._show_cover = show_cover
	var layer := CanvasLayer.new()
	layer.layer = 126
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	layer.add_child(overlay)
	var was_paused: bool = tree.paused
	tree.paused = true
	var art_status: Dictionary = {}
	if show_cover:
		if world.has_method("map_loading_art_pack"):
			var pack: RefCounted = world.map_loading_art_pack()
			if pack != null:
				var art := SOURCE_ART.new()
				art_status = art.mount(overlay, pack)
				if not art_status.get("ok", false): art.free()
				elif not str(art_status.get("world_layout", "")).is_empty():
					overlay._labels_at_bottom()
		if DisplayServer.get_name() == "headless": await tree.process_frame
		else: await RenderingServer.frame_post_draw
		overlay.first_paint_usec = Time.get_ticks_usec() - overlay.started_usec
	var result: Dictionary = {"ok":false,"reason":"이동 요청이 취소되었습니다."}
	if is_instance_valid(world) and world.is_inside_tree() and operation.is_valid():
		if show_cover: overlay._label.text = "이동 조건과 도착 지역을 확인하는 중"
		var began: int = Time.get_ticks_usec()
		result = await operation.call()
		overlay.operation_usec = Time.get_ticks_usec() - began
	# Source transitions only commit after their candidate's readiness barrier.
	# Reveal the committed map while gameplay remains paused. Unlock input only
	# after this draw; the destination paint and input-return clocks are separate.
	if show_cover:
		overlay.hide()
		if DisplayServer.get_name() == "headless": await tree.process_frame
		else: await RenderingServer.frame_post_draw
		var destination_paint_usec: int = Time.get_ticks_usec()-overlay.started_usec
		result["loading"] = {"destination_paint_usec":destination_paint_usec,"first_paint_usec":overlay.first_paint_usec,"operation_usec":overlay.operation_usec,"total_usec":Time.get_ticks_usec()-overlay.started_usec,"arrival_ready_usec":overlay.arrival_ready_usec,"painted":overlay.painted}
		if not art_status.is_empty(): result.loading["source_art"] = art_status
	tree.paused = was_paused
	if show_cover: print("DUNGEON_TRANSITION_TIMING "+JSON.stringify({"ok":result.get("ok"),"timing":result.loading,"headless":DisplayServer.get_name()=="headless"}))
	overlay.remove_from_group(GROUP)
	overlay.completed.emit(result)
	layer.queue_free()
	return result

func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _show_cover:
		hide()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(STYLE.backdrop())
	_column = VBoxContainer.new()
	_column.anchor_left = 0.1
	_column.anchor_right = 0.9
	_column.anchor_top = 0.5
	_column.anchor_bottom = 0.5
	_column.offset_top = -60
	_column.offset_bottom = 60
	add_child(_column)
	_column.add_child(STYLE.label(_title,30))
	_label = STYLE.label("이동 화면을 준비하는 중",22)
	_column.add_child(_label)
	draw.connect(func() -> void: painted = true)

func _labels_at_bottom() -> void:
	_column.anchor_top = 1.0
	_column.anchor_bottom = 1.0
	_column.offset_top = -102
	_column.offset_bottom = -18
