extends Node

const COORD = preload("res://scripts/maps/world_coordinates.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const NativeList = preload("res://scripts/ui/native_touch_list.gd")
const NativeButton = preload("res://scripts/ui/native_touch_button.gd")
var world: Node
var selections: Array[Dictionary] = []
var panel: PanelContainer
var listing: ItemList
var overlay: Control
var pointer: int = -2
var origin: Vector2
var previous: Vector2
var dragging: bool = false
var marquee: bool = false
var first_target: Dictionary = {}
var gesture_map: String = ""
var gesture_window_visible: bool = false
var gesture_section: String = ""
var prune_clock: float = 0.0

func configure(owner_world: Node) -> void:
	world = owner_world
	panel = PanelContainer.new()
	panel.name = "OrderedTargetSelection"
	panel.position = Vector2(12,132)
	panel.size = Vector2(256,160)
	panel.z_index = 12
	panel.add_theme_stylebox_override("panel",UI.box(Color(0.06,0.055,0.045,0.90),UI.BRONZE,7))
	world.hud.get_node("Root").add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var title: Label = UI.label("선택 순서 · 누르면 우선 선택",12,UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var clear_button := NativeButton.new()
	clear_button.name = "ClearTargets"
	clear_button.text = "해제"
	clear_button.pressed.connect(clear_selection)
	row.add_child(clear_button)
	listing = NativeList.new()
	listing.name = "SelectedTargets"
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.custom_minimum_size = Vector2(238,112)
	listing.item_selected.connect(_promote_row)
	column.add_child(listing)
	overlay = preload("res://scripts/input/selection_overlay.gd").new()
	overlay.name = "TargetSelectionMarquee"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 11
	world.hud.get_node("Root").add_child(overlay)
	panel.hide()
	get_window().focus_exited.connect(cancel_gesture)
	get_viewport().size_changed.connect(cancel_gesture)

func _process(delta: float) -> void:
	if pointer != -2 and (gesture_map != str(world.active_map_id) or bool(world.hud.class_picker_initial) or world.hud.workspace.visible != gesture_window_visible or str(world.hud.active_section) != gesture_section): cancel_gesture()
	prune_clock += delta
	if prune_clock >= 0.2:
		prune_clock = 0.0
		prune()

func monster_entry(monster: Node) -> Dictionary:
	return {"kind":"monster","key":"m:%d:%d" % [monster.get_instance_id(),int(monster.life_id)],"actor":weakref(monster),"life":int(monster.life_id),"map":str(world.active_map_id)}

func npc_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world.field_map == null: return result
	var records: Array = world.field_map.data.get("npc_spawn",[])
	for index: int in range(records.size()):
		var record: Dictionary = records[index]
		result.append({"kind":"npc","key":"n:%s:%s" % [str(world.active_map_id),str(record.get("id",index))],"map":str(world.active_map_id),"index":index,"record":record})
	return result

func valid(entry: Dictionary) -> bool:
	if str(entry.get("map","")) != str(world.active_map_id): return false
	if entry.kind == "monster":
		var actor: Node = entry.actor.get_ref()
		return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.get_parent() == world.monsters_root and not actor.dead and int(actor.life_id) == int(entry.life)
	if world.field_map == null: return false
	var records: Array = world.field_map.data.get("npc_spawn",[])
	var index: int = int(entry.index)
	return index >= 0 and index < records.size() and records[index] == entry.record

func primary_monster() -> TwilightMonster:
	prune()
	if selections.is_empty() or selections[0].kind != "monster": return null
	return selections[0].actor.get_ref() as TwilightMonster

func primary_is_npc() -> bool:
	prune()
	return not selections.is_empty() and selections[0].kind == "npc"

func prune() -> void:
	var changed: bool = false
	for index: int in range(selections.size()-1,-1,-1):
		if not valid(selections[index]):
			selections.remove_at(index)
			changed = true
	if changed:
		_sync_primary()
		_refresh()

func append_target(entry: Dictionary) -> void:
	if entry.is_empty() or not valid(entry): return
	for old: Dictionary in selections:
		if old.key == entry.key: return
	selections.append(entry)
	if selections.size() == 1: _sync_primary()
	_refresh()

func select_monster(monster: Node) -> void:
	if not is_instance_valid(monster) or monster.dead: return
	var entry: Dictionary = monster_entry(monster)
	append_target(entry)
	promote(str(entry.key))

func promote(key: String) -> void:
	prune()
	for index: int in range(selections.size()):
		if selections[index].key == key:
			var entry: Dictionary = selections[index]
			selections.remove_at(index)
			selections.push_front(entry)
			_sync_primary()
			_refresh()
			return

func _promote_row(index: int) -> void:
	if index >= 0 and index < listing.item_count: promote(str(listing.get_item_metadata(index)))

func clear_selection() -> void:
	selections.clear()
	_sync_primary()
	_refresh()

func _sync_primary() -> void:
	var target: TwilightMonster = null
	if not selections.is_empty() and selections[0].kind == "monster": target = selections[0].actor.get_ref() as TwilightMonster
	world.selected_monster = target
	world.auto_target = target
	world.auto_repath_timer = 0.0
	world.auto_stuck_time = 0.0
	if not world.player.has_manual_movement() and world.loot_pickup.mode == "idle": world.player.clear_click_path()

func _refresh() -> void:
	listing.clear()
	for index: int in range(selections.size()):
		var entry: Dictionary = selections[index]
		var caption: String
		if entry.kind == "monster":
			var actor: Node = entry.actor.get_ref()
			caption = "Lv.%d %s" % [int(actor.monster_level),str(actor.monster_name)]
		else: caption = "NPC · %s" % str(entry.record.get("name",entry.record.get("id","NPC")))
		var row: int = listing.add_item("%d. %s" % [index+1,caption])
		listing.set_item_metadata(row,entry.key)
	if listing.item_count > 0: listing.select(0)
	panel.visible = not selections.is_empty()

func _all_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for actor: Node in world.monsters_root.get_children():
		if actor is TwilightMonster and not actor.dead and actor.is_visible_in_tree() and not actor.is_queued_for_deletion(): targets.append(monster_entry(actor))
	targets.append_array(npc_entries())
	return targets

func _screen_center(entry: Dictionary) -> Vector2:
	var point: Vector2 = entry.actor.get_ref().global_position if entry.kind == "monster" else COORD.array_vector(entry.record.position)
	return COORD.world_to_screen(get_viewport(),point+Vector2(0,-28))

func _target_at(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = 44.0
	for entry: Dictionary in _all_targets():
		var center: Vector2 = _screen_center(entry)
		var current: float = center.distance_to(point)
		if current < distance:
			distance = current
			best = entry
	return best

func begin(event: InputEvent) -> void:
	if pointer != -2 or event.device == InputEvent.DEVICE_ID_EMULATION: return
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed and not event.canceled
	if not pressed or world.hud.blocks_world_input(event.position): return
	pointer = event.index if event is InputEventScreenTouch else -1
	origin = event.position
	previous = origin
	dragging = false
	first_target = _target_at(origin)
	marquee = first_target.is_empty()
	gesture_map = str(world.active_map_id)
	gesture_window_visible = world.hud.workspace.visible
	gesture_section = str(world.hud.active_section)
	get_viewport().set_input_as_handled()

func cancel_gesture() -> void:
	pointer = -2
	dragging = false
	first_target = {}
	if is_instance_valid(overlay):
		overlay.active = false
		overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if pointer == -2: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_gesture()
		get_viewport().set_input_as_handled()
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch and event.index == pointer and event.canceled:
		cancel_gesture()
		get_viewport().set_input_as_handled()
		return
	var move: bool = event is InputEventMouseMotion and pointer == -1 or event is InputEventScreenDrag and event.index == pointer
	var release: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and pointer == -1 or event is InputEventScreenTouch and not event.pressed and event.index == pointer
	if not move and not release: return
	if gesture_map != str(world.active_map_id):
		cancel_gesture()
		return
	var point: Vector2 = event.position
	if move:
		if not dragging and point.distance_to(origin) >= 10.0:
			dragging = true
			if not marquee: append_target(first_target)
		if dragging:
			if marquee:
				overlay.selection_rect = Rect2(origin,point-origin).abs()
				overlay.active = true
				overlay.queue_redraw()
			else: _sweep(previous,point)
		previous = point
	elif release:
		if dragging:
			if marquee:
				var rect: Rect2 = Rect2(origin,point-origin).abs()
				var candidates: Array[Dictionary] = _all_targets()
				candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return _screen_center(a).distance_squared_to(origin) < _screen_center(b).distance_squared_to(origin))
				for entry: Dictionary in candidates:
					if rect.has_point(_screen_center(entry)): append_target(entry)
			else: _sweep(previous,point)
		elif not world.hud.blocks_world_input(point):
			var target: Dictionary = _target_at(point)
			if not target.is_empty():
				append_target(target)
				promote(str(target.key))
				if target.kind == "npc": world._set_click_destination(COORD.screen_to_world(get_viewport(),point))
			else: world._set_click_destination(COORD.screen_to_world(get_viewport(),point))
		cancel_gesture()
	get_viewport().set_input_as_handled()

func _sweep(a: Vector2,b: Vector2) -> void:
	var segment: Vector2 = b-a
	var hits: Array[Dictionary] = []
	for entry: Dictionary in _all_targets():
		var center: Vector2 = _screen_center(entry)
		var fraction: float = clampf((center-a).dot(segment)/maxf(segment.length_squared(),0.001),0.0,1.0)
		if center.distance_to(a+segment*fraction) <= 36.0: hits.append({"entry":entry,"fraction":fraction})
	hits.sort_custom(func(x: Dictionary,y: Dictionary) -> bool: return x.fraction < y.fraction)
	for hit: Dictionary in hits: append_target(hit.entry)
