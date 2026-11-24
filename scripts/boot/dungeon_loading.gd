extends Control
## In-game transition overlay; separate from boot/character initialization.
const STYLE = preload("res://scripts/boot/boot_style.gd")
const GROUP = "twilight_dungeon_loading"
var _label: Label
var _title: String = "던전 이동 준비"
var painted: bool = false
var started_usec: int = 0
var first_paint_usec: int = 0
var operation_usec: int = 0
var arrival_ready_usec: int = -1
signal completed(result: Dictionary)

static func report(world: Node, text: String) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	var overlay: Node = world.get_tree().get_first_node_in_group(GROUP)
	if overlay != null: overlay._label.text = text

static func arrival_ready(world: Node) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	var overlay: Node = world.get_tree().get_first_node_in_group(GROUP)
	if overlay != null: overlay.arrival_ready_usec = Time.get_ticks_usec()-overlay.started_usec

## The callable keeps the existing eligibility, quote and atomic payment owner.
## Freeze the tree, not movement_locked: eligibility checks must see the real
## pre-existing player state. Concurrent requests cannot quote/debit twice.
static func busy(world: Node) -> bool:
	return world.is_inside_tree() and world.get_tree().get_first_node_in_group(GROUP) != null


static func run(world: Node, operation: Callable, title: String = "던전 이동 준비") -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree() or not operation.is_valid(): return {"ok":false,"reason":"이동 요청을 사용할 수 없습니다."}
	var tree: SceneTree = world.get_tree()
	if tree.get_first_node_in_group(GROUP) != null: return {"ok":false,"busy":true,"reason":"다른 이동을 준비하고 있습니다."}
	var overlay = load("res://scripts/boot/dungeon_loading.gd").new()
	overlay._title = title
	var layer := CanvasLayer.new()
	layer.layer = 126
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	layer.add_child(overlay)
	var was_paused: bool = tree.paused
	tree.paused = true
	overlay.started_usec = Time.get_ticks_usec()
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw
	overlay.first_paint_usec = Time.get_ticks_usec() - overlay.started_usec
	var result: Dictionary = {"ok":false,"reason":"이동 요청이 취소되었습니다."}
	if is_instance_valid(world) and world.is_inside_tree() and operation.is_valid():
		overlay._label.text = "이동 조건과 도착 지역을 확인하는 중"
		var began: int = Time.get_ticks_usec()
		result = await operation.call()
		overlay.operation_usec = Time.get_ticks_usec() - began
	# Source transitions only commit after their candidate's readiness barrier.
	# Reveal the committed map while gameplay remains paused. Unlock input only
	# after this draw; the destination paint and input-return clocks are separate.
	overlay.hide()
	if DisplayServer.get_name() == "headless": await tree.process_frame
	else: await RenderingServer.frame_post_draw
	var destination_paint_usec: int = Time.get_ticks_usec()-overlay.started_usec
	result["loading"] = {"destination_paint_usec":destination_paint_usec,"first_paint_usec":overlay.first_paint_usec,"operation_usec":overlay.operation_usec,"total_usec":Time.get_ticks_usec()-overlay.started_usec,"arrival_ready_usec":overlay.arrival_ready_usec,"painted":overlay.painted}
	tree.paused = was_paused
	print("DUNGEON_TRANSITION_TIMING "+JSON.stringify({"ok":result.get("ok"),"timing":result.loading,"headless":DisplayServer.get_name()=="headless"}))
	overlay.remove_from_group(GROUP)
	overlay.completed.emit(result)
	layer.queue_free()
	return result

func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(STYLE.backdrop())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.offset_left = -320
	column.offset_right = 320
	column.offset_top = -60
	column.offset_bottom = 60
	add_child(column)
	column.add_child(STYLE.label(_title,30))
	_label = STYLE.label("이동 화면을 준비하는 중",22)
	column.add_child(_label)
	draw.connect(func() -> void: painted = true)
