extends RefCounted
class_name TwilightLootPickupController

const PICKUP_RADIUS: float = 60.0
const SCAN_RADIUS: float = 460.0
const SCAN_INTERVAL: float = 0.25
const BLOCKED_RETRY: float = 15.0
const REFUSED_RETRY: float = 1.0
## Path searches for new targets stop for this frame once this much time is
## spent (the first one always runs); the scan continues next frame. Up to 8
## unreachable drops each ran a full search in one frame (523.699: auto.pickup
## 454 ms once on the phone).
const SCAN_PATH_BUDGET_USEC: int = 6000
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
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
## The HUD pickup button (next to 셀프): keep collecting the next nearby drop
## after each one until none is left, the player moves or a drop is
## unreachable (user list 2026-11-21 #25).
var sweep: bool = false
var sweep_picked: int = 0
const SWEEP_LIMIT: int = 50

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
	pickup_button.expand_icon = true
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
	selected_id = id
	(view as TwilightGroundLoot).set_selected(true)
	var record: Dictionary = manager.records[id]
	var title: String = str(record["item_name"])
	var item: Dictionary = manager.floor_item_record(record)
	if item.get("source_m_native_item") == true:
		title = str(preload("res://scripts/loot/current523_native_fields.gd").field(item,"source_display_name",title))
	info.text = "%s · %s ×%d" % [title, record["grade"], record["quantity"]]
	info.add_theme_color_override("font_color", preload("res://scripts/loot/current523_item_grade.gd").color(item if not item.is_empty() else str(record["grade"]), TwilightDropVisual.grade_color(str(record["grade"]))))
	_show_selected_item_image(record,item)
	overlay.show()

func _show_selected_item_image(record: Dictionary,item: Dictionary) -> void:
	_clear_selected_item_image()
	# This is the selected item's UI icon on the existing pickup button. The
	# floor visual still requires its own source-declared ground asset role.
	if not IMAGES.handles_item(item): return
	var image_info: Dictionary = IMAGES.describe_item(item, str(record.get("item_name", "")))
	pickup_button.icon = image_info.get("texture") as Texture2D
	var evidence: Dictionary = image_info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_role"] = "selected_loot_item_icon"
	evidence["presentation_trigger"] = "existing_loot_selection"
	pickup_button.set_meta("source523_image", evidence)
	pickup_button.set_meta("source523_image_provenance", image_info.get("provenance", {}).duplicate(true))
	pickup_button.set_meta("source523_image_status", str(image_info.get("source_status", image_info.get("reason", ""))))

func _clear_selected_item_image() -> void:
	if not is_instance_valid(pickup_button): return
	pickup_button.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if pickup_button.has_meta(key): pickup_button.remove_meta(key)

func request_selected() -> void:
	if not manager.views.has(selected_id): cancel(); return
	if player.is_stunned() or player.is_feared() or player.is_held():
		world.hud.show_message("이동 불가 상태에서는 아이템을 주울 수 없습니다")
		return
	target_id = selected_id
	mode = "manual"
	stuck_time = 0.0
	last_position = player.global_position
	repath_time = 0.0
	world.set("pending_ground_pickup", manager.views[target_id])
	_advance_target()

## The HUD pickup button: the selected drop, else the nearest reachable
## drops around the player within SCAN_RADIUS, one after another. Returns
## whether a pickup started.
func request_nearby(continuing: bool = false) -> bool:
	if not selected_id.is_empty() and manager.views.has(selected_id):
		# Set before the request: a drop already in reach is collected inside it.
		sweep = true
		request_selected()
		if mode != "manual": sweep = false
		return true
	if not continuing: sweep_picked = 0
	if player.is_stunned() or player.is_feared() or player.is_held():
		world.hud.show_message("이동 불가 상태에서는 아이템을 주울 수 없습니다")
		return false
	var candidates: Array[String] = _ranked_candidates(false, 1)
	if candidates.is_empty() or sweep_picked >= SWEEP_LIMIT:
		sweep = false
		return false
	var id: String = candidates[0]
	cancel()
	selected_id = id
	(manager.views[id] as TwilightGroundLoot).set_selected(true)
	sweep = true
	request_selected()
	if mode != "manual": sweep = false
	return true

func cancel() -> void:
	sweep = false
	if manager != null and manager.views.has(selected_id):
		(manager.views[selected_id] as TwilightGroundLoot).set_selected(false)
	if not target_id.is_empty() and is_instance_valid(player): player.clear_click_path()
	selected_id = ""
	target_id = ""
	mode = "idle"
	world.set("pending_ground_pickup", null)
	_clear_selected_item_image()
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
	var sweeping: bool = sweep and was_manual
	blocked[target_id] = clock + BLOCKED_RETRY
	cancel()
	# The pickup button goes on with the next nearby drop (blocked ones are
	# skipped); only a single chosen drop reports that it cannot be reached.
	if sweeping and request_nearby(true): return
	if was_manual: world.hud.show_message("아이템에 접근할 수 없습니다")

func _advance_target() -> bool:
	if not manager.views.has(target_id) or not manager.valid_view(manager.views[target_id]): cancel(); return false
	if player.is_stunned() or player.is_feared() or player.is_held() or player.movement_locked: return true
	var view: TwilightGroundLoot = manager.views[target_id]
	var destination: Vector2 = _destination(target_id)
	var radius: float = world._ground_pickup_radius() if world.has_method("_ground_pickup_radius") else PICKUP_RADIUS
	if player.global_position.distance_to(destination) <= radius and bool(world.call("_has_line_of_sight_world", player.global_position, destination)):
		player.clear_click_path()
		if Time.get_ticks_msec() - view.visible_since < manager.MIN_VISIBLE_MS: return true
		if not bool(world.call("_collect_ground_drop", view)):
			# The item reached the ownership check. Release the route and let
			# AUTO consider another drop or resume combat.
			if mode == "auto": blocked[target_id] = clock + REFUSED_RETRY
			cancel()
			return false
		var again: bool = sweep and mode == "manual"
		cancel()
		if again:
			sweep_picked += 1
			request_nearby(true)
		return true
	if stuck_time > 2.2:
		_reject_target()
		return false
	if repath_time <= 0.0:
		repath_time = 0.65
		repath_count += 1
		var path: PackedVector2Array = world.call("find_world_path", player.global_position, destination)
		if path.is_empty() or path[path.size() - 1].distance_to(destination) > radius:
			_reject_target()
			return false
		player.set_click_path(path, destination)
	return true

## Only the first target (manual) or first eight (auto) are ever tried.
## Evaluate each drop's original tie-break tuple once. Nothing is cached:
## moving, batch changes, player drops, cooldowns and expiry apply immediately.
func _ranked_candidates(automatic: bool, limit: int) -> Array[String]:
	var ids: Array[String] = []
	if limit <= 0: return ids
	var ranks: Array[int] = []
	var origin: Vector2 = player.global_position
	var grade_count: int = TwilightDropVisual.GRADES.size()
	var other_batch: int = roundi(SCAN_RADIUS * 10.0) + 1
	for id: String in manager.views:
		if float(blocked.get(id, 0)) > clock: continue
		var row: Dictionary = manager.records.get(id, {})
		if row.is_empty() or (automatic and bool(row.get("player_dropped", false))): continue
		var coords: Array = row.position
		var distance: float = origin.distance_to(Vector2(float(coords[0]), float(coords[1])))
		if not (distance <= SCAN_RADIUS): continue
		if not manager.valid_view(manager.views[id]): continue
		var distance_key: int = roundi(distance * 10.0)
		if manager.current_batch.is_empty() or str(row.hunt_batch) != manager.current_batch: distance_key += other_batch
		# Lower is better. Unknown grade (-1) sorts after every named grade.
		var rank: int = distance_key * (grade_count + 1) + grade_count - 1 - TwilightDropVisual.GRADES.find(str(row.grade))
		var at: int = ranks.size()
		if at == limit and (rank > ranks[-1] or (rank == ranks[-1] and id >= ids[-1])): continue
		while at > 0 and (rank < ranks[at-1] or (rank == ranks[at-1] and id < ids[at-1])): at -= 1
		ranks.insert(at, rank); ids.insert(at, id)
		if ranks.size() > limit: ranks.pop_back(); ids.pop_back()
	return ids

func run_auto() -> bool:
	if not player.auto_enabled: return false
	if mode == "manual" or not selected_id.is_empty(): return true
	if player.has_manual_movement(): return true
	if mode == "auto":
		if _advance_target(): return true
	if scan_time > 0 and seen_revision == manager.revision: return false
	scan_time = SCAN_INTERVAL
	seen_revision = manager.revision
	scan_count += 1
	var candidates: Array[String] = _ranked_candidates(true, 8)
	# Bound path searches even with many inaccessible drops. Rejected IDs are
	# retried after a cooldown, allowing the existing combat AI to continue.
	var scan_started: int = Time.get_ticks_usec()
	for index: int in range(mini(candidates.size(), 8)):
		if index > 0 and Time.get_ticks_usec() - scan_started >= SCAN_PATH_BUDGET_USEC:
			# Rejected drops are blocked; the rest are tried on the next frame.
			scan_time = 0.0
			return false
		target_id = candidates[index]
		mode = "auto"
		stuck_time = 0.0
		last_position = player.global_position
		repath_time = 0.0
		if _advance_target(): return true
	return false
