extends RefCounted
class_name TwilightLootPickupController

const PICKUP_RADIUS: float = 60.0
const SCAN_RADIUS: float = 460.0
const SCAN_INTERVAL: float = 0.25
const BLOCKED_RETRY: float = 15.0
var world: Node
var player: TwilightPlayer
var manager: TwilightGroundLootManager
var selected_id: String = ""
var target_id: String = ""
var mode: String = "idle"
var scan_time: float = 0.0
var blocked: Dictionary = {}
var clock: float = 0.0
var repath_time: float = 0.0
var stuck_time: float = 0.0
var last_position: Vector2
var seen_revision: int = -1
var scan_count: int = 0
var repath_count: int = 0
var cleanup_time: float = 0.0
var overlay: PanelContainer
var info: Label
var pickup_button: Button

func configure(owner_world: Node, service: TwilightGroundLootManager) -> void:
	world = owner_world
	player = world.get("player") as TwilightPlayer
	manager = service
	var layer := CanvasLayer.new()
	layer.name = "LootPickupOverlay"
	layer.layer = 21
	world.add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	overlay.offset_left = 16
	overlay.offset_right = 342
	overlay.offset_top = 304
	overlay.offset_bottom = 384
	var style := StyleBoxFlat.new()
	style.bg_color = Color("181a20ed")
	style.border_color = Color("a58b52")
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	overlay.add_theme_stylebox_override("panel", style)
	root_control.add_child(overlay)
	var column := VBoxContainer.new()
	overlay.add_child(column)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 16)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	var row := HBoxContainer.new()
	column.add_child(row)
	pickup_button = Button.new()
	pickup_button.text = "줍기"
	pickup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pickup_button.custom_minimum_size.y = 36
	row.add_child(pickup_button)
	pickup_button.pressed.connect(request_selected)
	pickup_button.gui_input.connect(_touch_button.bind(pickup_button))
	var close_button := Button.new()
	close_button.text = "취소"
	row.add_child(close_button)
	close_button.pressed.connect(cancel)
	close_button.gui_input.connect(_touch_button.bind(close_button))
	overlay.hide()

func _touch_button(event: InputEvent, button: Button) -> void:
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and not event.canceled: button.pressed.emit()
		button.accept_event()

func select(view: Button) -> void:
	if not manager.valid_view(view): return
	var id: String = str(view.get_meta("id"))
	if selected_id == id:
		request_selected()
		return
	cancel()
	if player.auto_enabled: player.set_auto_enabled(false)
	selected_id = id
	(view as TwilightGroundLoot).set_selected(true)
	var record: Dictionary = manager.records[id]
	info.text = "%s · %s ×%d" % [record["item_name"], record["grade"], record["quantity"]]
	info.add_theme_color_override("font_color", TwilightDropVisual.grade_color(str(record["grade"])))
	overlay.show()

func request_selected() -> void:
	if not manager.views.has(selected_id): cancel(); return
	if player.is_stunned() or player.is_feared() or player.is_held():
		world.hud.show_message("이동 불가 상태에서는 아이템을 주울 수 없습니다")
		return
	if player.auto_enabled: player.set_auto_enabled(false)
	target_id = selected_id
	mode = "manual"
	stuck_time = 0.0
	last_position = player.global_position
	repath_time = 0.0
	world.set("pending_ground_pickup", manager.views[target_id])
	_advance_target()

func cancel() -> void:
	if manager != null and manager.views.has(selected_id):
		(manager.views[selected_id] as TwilightGroundLoot).set_selected(false)
	if not target_id.is_empty() and is_instance_valid(player): player.clear_click_path()
	selected_id = ""
	target_id = ""
	mode = "idle"
	world.set("pending_ground_pickup", null)
	if is_instance_valid(overlay): overlay.hide()
	scan_time = 0.0

func map_changed() -> void:
	cancel()
	blocked.clear()

func tick(delta: float) -> void:
	clock += delta
	cleanup_time += delta
	if cleanup_time >= 1.0:
		cleanup_time = 0.0
		for id: String in blocked.keys():
			if not manager.records.has(id) or float(blocked[id]) <= clock: blocked.erase(id)
	scan_time = maxf(0, scan_time - delta)
	repath_time = maxf(0, repath_time - delta)
	if not selected_id.is_empty() and not manager.views.has(selected_id): cancel()
	if mode == "auto" and not player.auto_enabled: cancel()
	if not target_id.is_empty():
		if player.is_stunned() or player.is_feared() or player.is_held() or player.movement_locked:
			stuck_time = 0.0
			repath_time = 0.0
		elif player.global_position.distance_squared_to(last_position) < 1.0: stuck_time += delta
		else: stuck_time = 0.0
		last_position = player.global_position
	if mode == "manual": _advance_target()
	if not selected_id.is_empty() and (player.touch_vector.length_squared() > 0.01 or Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.01): cancel()

func _destination(id: String) -> Vector2:
	var coordinates: Array = manager.records[id]["position"]
	return Vector2(float(coordinates[0]), float(coordinates[1]))

func _reject_target() -> void:
	var was_manual: bool = mode == "manual"
	blocked[target_id] = clock + BLOCKED_RETRY
	cancel()
	if was_manual: world.hud.show_message("아이템에 접근할 수 없습니다")

func _advance_target() -> bool:
	if not manager.views.has(target_id) or not manager.valid_view(manager.views[target_id]): cancel(); return false
	if player.is_stunned() or player.is_feared() or player.is_held() or player.movement_locked: return true
	var view: Button = manager.views[target_id]
	var destination: Vector2 = _destination(target_id)
	if player.global_position.distance_to(destination) <= PICKUP_RADIUS and bool(world.call("_has_line_of_sight_world", player.global_position, destination)):
		player.clear_click_path()
		if bool(world.call("_collect_ground_drop", view)):
			cancel()
		return true
	if stuck_time > 2.2:
		_reject_target()
		return false
	if repath_time <= 0.0:
		repath_time = 0.65
		repath_count += 1
		var path: PackedVector2Array = world.call("find_world_path", player.global_position, destination)
		if path.is_empty() or path[path.size() - 1].distance_to(destination) > PICKUP_RADIUS:
			_reject_target()
			return false
		player.set_click_path(path, destination)
	return true

func _priority(a: String, b: String) -> bool:
	var current_a: bool = not manager.current_batch.is_empty() and str(manager.records[a]["hunt_batch"]) == manager.current_batch
	var current_b: bool = not manager.current_batch.is_empty() and str(manager.records[b]["hunt_batch"]) == manager.current_batch
	if current_a != current_b: return current_a
	var da: int = roundi(player.global_position.distance_to(_destination(a)) * 10.0)
	var db: int = roundi(player.global_position.distance_to(_destination(b)) * 10.0)
	if da != db: return da < db
	var ga: int = TwilightDropVisual.GRADES.find(str(manager.records[a]["grade"]))
	var gb: int = TwilightDropVisual.GRADES.find(str(manager.records[b]["grade"]))
	return ga > gb if ga != gb else a < b

func run_auto() -> bool:
	if not player.auto_enabled: return false
	if mode == "manual": cancel()
	if mode == "auto":
		if _advance_target(): return true
	if scan_time > 0 and seen_revision == manager.revision: return false
	scan_time = SCAN_INTERVAL
	seen_revision = manager.revision
	scan_count += 1
	var candidates: Array[String] = []
	for id: String in manager.views.keys():
		if float(blocked.get(id, 0)) > clock: continue
		if manager.valid_view(manager.views[id]) and player.global_position.distance_to(_destination(id)) <= SCAN_RADIUS: candidates.append(id)
	candidates.sort_custom(_priority)
	# Bound path searches even with many inaccessible drops. Rejected IDs are
	# retried after a cooldown, allowing the existing combat AI to continue.
	for index: int in range(mini(candidates.size(), 8)):
		target_id = candidates[index]
		mode = "auto"
		stuck_time = 0.0
		last_position = player.global_position
		repath_time = 0.0
		if _advance_target(): return true
	return false
