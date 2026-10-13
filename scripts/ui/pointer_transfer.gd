extends Node

# One pointer owns one gesture. Input is captured through release/cancel, even
# outside the source window. Source references are IDs, never array positions.
const L = preload("res://scripts/ui/reference_layout.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var pointer: int = -2
var source: Dictionary = {}
var origin: Vector2
var position: Vector2
var elapsed: float = 0
var pressed_at: int = 0
var mode: String = ""
var preview: TextureRect
var hint: Label
var remove_target: Button
var suppress_click: bool = false
var handled_touch_at: int = -1000
var handled_touch_position: Vector2

func configure(controller: Node) -> void:
	hud = controller
	preview = TextureRect.new()
	preview.name = "PointerTransferPreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(62,62)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 350
	hud.get_node("Root").add_child(preview)
	hint = UI.label("",13,UI.GOLD)
	hint.z_index = 351
	hud.get_node("Root").add_child(hint)
	remove_target = UI.button("슬롯 해제",Callable(),Vector2(118,40))
	remove_target.name = "QuickslotRemoveTarget"
	remove_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remove_target.z_index = 349
	hud.get_node("Root").add_child(remove_target)
	cancel()
	get_viewport().size_changed.connect(cancel)
	get_window().focus_exited.connect(cancel)

func inside(control: Control, point: Vector2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	if not Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point): return false
	var parent: Node = control.get_parent()
	while parent is Control:
		if parent.clip_contents and not Rect2(Vector2.ZERO,parent.size).has_point(parent.get_global_transform_with_canvas().affine_inverse()*point): return false
		parent = parent.get_parent()
	return true

func _source_at(point: Vector2) -> Dictionary:
	if hud.class_picker_initial: return {}
	for child: Node in hud.get_node("Root").get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return {}
	for i: int in range(hud.v20_quickslot_buttons.size()):
		if inside(hud.v20_quickslot_buttons[i],point) and (not hud.workspace.visible or not inside(hud.workspace,point)):
			var slot: int = hud.quickslot_index(i)
			return {"from":"quick","slot":slot,"visible":i,"entry":hud.get_parent().quickslots[slot].duplicate(true),"texture":hud.quickslot_icons[i].texture}
	var bag: Control = hud.lineage_inventory_ui
	if bag.is_visible_in_tree() and bag.inventory_panel.visible:
		if bag.detail_active and inside(bag.detail_panel,point): return {}
		for id: String in bag.slot_buttons:
			var button: Control = bag.slot_buttons[id]
			if inside(button,point):
				var record: Dictionary = bag._find_item_record(id)
				return {"from":"inventory","id":id,"entry":{"kind":"item","id":bag._base_item_name(id)},"texture":bag._icon_for_reference(record,bag._base_item_name(id),id)}
	if hud.active_section == "warehouse" and is_instance_valid(hud.transaction_view):
		var view: Control = hud.transaction_view
		if view.mode.selected == 1 and inside(view.listing,point):
			var local: Vector2 = view.listing.get_global_transform_with_canvas().affine_inverse()*point
			var index: int = view.listing.get_item_at_position(local,true)
			if index >= 0 and index < view.entries.size():
				var entry: Dictionary = view.entries[index]
				var id: String = str(entry.name)+("@@@"+str(entry.instance_id) if not str(entry.instance_id).is_empty() else "")
				return {"from":"warehouse","id":id,"entry":{"kind":"item","id":str(entry.name)},"texture":view.listing.get_item_icon(index)}
	if hud.active_section == "skills" and is_instance_valid(hud.skills_view):
		var view: Node = hud.skills_view
		if inside(view.cards,point):
			var local: Vector2 = view.cards.get_global_transform_with_canvas().affine_inverse()*point
			var index: int = view.cards.get_item_at_position(local,true)
			if index >= 0 and index < view.filtered.size():
				var record: Dictionary = view.filtered[index]
				return {"from":"skill","id":str(record.get("id",record.name)),"entry":{"kind":"skill","id":str(record.get("id",record.name))},"texture":view.cards.get_item_icon(index)}
	return {}

func _input(event: InputEvent) -> void:
	if hud == null: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and pointer != -2:
		cancel()
		get_viewport().set_input_as_handled()
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		# Godot may send a mouse event after the native touch release. The UI
		# gesture already committed; consuming its matching synthetic event
		# prevents the underlying button from using the newly bound item.
		if pointer >= 0 or (event is InputEventMouse and Time.get_ticks_msec()-handled_touch_at < 200 and event.position.distance_to(handled_touch_position) < 3):
			get_viewport().set_input_as_handled()
		return
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed and not event.canceled
	if press:
		if pointer != -2:
			get_viewport().set_input_as_handled()
			return
		var candidate: Dictionary = _source_at(event.position)
		if candidate.is_empty(): return
		pointer = event.index if event is InputEventScreenTouch else -1
		source = candidate
		origin = event.position
		position = origin
		elapsed = 0
		pressed_at = Time.get_ticks_msec()
		mode = "pending"
		set_process(true)
		suppress_click = false
		if pointer >= 0:
			handled_touch_at = Time.get_ticks_msec()
			handled_touch_position = event.position
		get_viewport().set_input_as_handled()
		return
	if pointer == -2: return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index == pointer:
		handled_touch_at = Time.get_ticks_msec()
		handled_touch_position = event.position
	var move: bool = event is InputEventMouseMotion and pointer == -1 or event is InputEventScreenDrag and event.index == pointer
	var release: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and pointer == -1 or event is InputEventScreenTouch and event.index == pointer and not event.pressed
	if event is InputEventScreenTouch and event.index == pointer and event.canceled:
		cancel()
		get_viewport().set_input_as_handled()
		return
	if move:
		elapsed = float(Time.get_ticks_msec()-pressed_at)/1000.0
		var previous: Vector2 = position
		position = event.position
		var distance: Vector2 = position-origin
		if mode == "pending" and distance.length() > (L.TOUCH_SCROLL_DISTANCE if pointer >= 0 else L.MOUSE_DRAG_DISTANCE):
			if pointer >= 0 and elapsed < L.TOUCH_HOLD_SECONDS:
				if source.from != "quick": mode = "scroll"
				elif absf(distance.x) > absf(distance.y)*1.5: mode = "page"
				else: mode = "drag"
			else: mode = "drag"
		if mode == "scroll":
			var bar: VScrollBar
			if source.from == "inventory": bar = hud.lineage_inventory_ui.grid_scroll.get_v_scroll_bar()
			elif source.from == "skill" and is_instance_valid(hud.skills_view): bar = hud.skills_view.cards.get_v_scroll_bar()
			elif source.from == "warehouse" and is_instance_valid(hud.transaction_view): bar = hud.transaction_view.listing.get_v_scroll_bar()
			if bar != null: bar.value -= (position-previous).y
		elif mode == "drag": _show_drag()
		elif mode == "page":
			hint.text = "다음 페이지" if distance.x < 0 else "이전 페이지"
			hint.position = origin-Vector2(40,65)
			hint.show()
		get_viewport().set_input_as_handled()
	elif release:
		position = event.position
		if mode == "pending": _tap()
		elif mode == "drag": _drop()
		elif mode == "page" and absf(position.x-origin.x) >= L.QUICK_PAGE_SWIPE_DISTANCE and absf(position.x-origin.x) > absf(position.y-origin.y)*1.5:
			var group: int = int(source.visible)/L.QUICK_GROUP_SIZE
			var page: int = int(hud.get_parent()._quickslot_pages()[group])+(1 if position.x < origin.x else -1)
			hud.quickslot_edit_requested.emit("page",group,page)
		if event is InputEventScreenTouch:
			handled_touch_at = Time.get_ticks_msec()
			handled_touch_position = event.position
		cancel()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if pointer == -2: return
	elapsed = float(Time.get_ticks_msec()-pressed_at)/1000.0
	if source.from == "inventory" and not hud.lineage_inventory_ui.is_visible_in_tree() or source.from == "skill" and (not hud.workspace.visible or hud.active_section != "skills"):
		cancel()
		return
	if source.from == "warehouse" and (not hud.workspace.visible or hud.active_section != "warehouse" or not is_instance_valid(hud.transaction_view) or hud.transaction_view.mode.selected != 1):
		cancel()
		return
	if mode == "pending" and pointer >= 0 and elapsed >= L.TOUCH_HOLD_SECONDS:
		mode = "drag"
		_show_drag()

func _tap() -> void:
	match str(source.from):
		"quick":
			if not hud.pending_quickslot_binding.is_empty():
				hud._emit_quickslot_assignment(int(source.slot),str(hud.pending_quickslot_binding.kind),str(hud.pending_quickslot_binding.id))
			else: hud.quickslot_pressed.emit(int(source.slot))
		"inventory": hud.lineage_inventory_ui._select_item(str(source.id))
		"warehouse":
			for i: int in range(hud.transaction_view.entries.size()):
				var entry: Dictionary = hud.transaction_view.entries[i]
				var id: String = str(entry.name)+("@@@"+str(entry.instance_id) if not str(entry.instance_id).is_empty() else "")
				if id == str(source.id):
					hud.transaction_view.listing.select(i)
					hud.transaction_view._selected(i)
					break
		"skill":
			for i: int in range(hud.skills_view.filtered.size()):
				if str(hud.skills_view.filtered[i].get("id",hud.skills_view.filtered[i].name)) == str(source.id):
					hud.skills_view.cards.select(i)
					hud.skills_view.select(i)
					break

func _show_drag() -> void:
	suppress_click = true
	preview.texture = source.get("texture")
	preview.position = position-Vector2(31,31)+(L.TOUCH_PREVIEW_OFFSET if pointer >= 0 else Vector2(14,-14))
	preview.show()
	remove_target.visible = source.from == "quick" and not source.entry.is_empty()
	remove_target.position = Vector2(get_viewport().get_visible_rect().size.x*.5-59,get_viewport().get_visible_rect().size.y-165)
	var valid: bool = not source.entry.is_empty() and (source.from == "quick" or hud.get_parent()._quickslot_registration_error(str(source.entry.kind),str(source.entry.id)).is_empty())
	for button: Button in hud.v20_quickslot_buttons:
		button.modulate = Color("c9ebff") if valid else Color("b6a39d")
	if source.from == "inventory":
		var record: Dictionary = hud.lineage_inventory_ui._find_item_record(str(source.id))
		var slot: String = hud.get_parent()._equipment_slot_for_record(record)
		for key: String in hud.lineage_side_ui.equipment_buttons:
			var compatible: bool = key == slot
			for pair: Array in [["ring1","ring2"],["earring1","earring2"],["seal1","seal2"]]:
				if slot in pair and key in pair: compatible = true
			hud.lineage_side_ui.equipment_buttons[key].modulate = Color("b3f3c0") if compatible else Color("817d75")
	hint.text = "퀵슬롯에 놓아 등록" if source.from != "quick" else "슬롯 이동 · 아래 AUTO · 위 AUTO 해제"
	if not valid: hint.text = "등록할 수 없는 항목"
	if source.from == "warehouse":
		hint.text = "가방에 놓아 찾기"
		for button: Button in hud.v20_quickslot_buttons: button.modulate = Color("b6a39d")
	hint.position = preview.position+Vector2(-40,-22)
	hint.show()

func _drop() -> void:
	var world: Node = hud.get_parent()
	if source.from == "warehouse":
		if is_instance_valid(hud.transaction_view) and hud.active_section == "warehouse" and inside(hud.lineage_inventory_ui.inventory_panel,position):
			hud.transaction_view.request_withdraw(str(source.id))
		return
	# Revalidate the identity after all game ticks that occurred during the drag.
	if source.from == "quick" and world.quickslots[int(source.slot)] != source.entry: return
	if source.from == "quick" and inside(remove_target,position):
		hud.quickslot_edit_requested.emit("clear",int(source.slot),-1)
		return
	if source.from == "quick":
		var delta: Vector2 = position-origin
		if absf(delta.x) < L.QUICK_SIZE*.5 and absf(delta.y) >= L.AUTO_DISTANCE:
			hud.quickslot_edit_requested.emit("auto_on" if delta.y > 0 else "auto_off",int(source.slot),-1)
			return
	for i: int in range(hud.v20_quickslot_buttons.size()):
		if not inside(hud.v20_quickslot_buttons[i],position): continue
		var target: int = hud.quickslot_index(i)
		if source.from == "quick":
			if target != int(source.slot): hud.quickslot_edit_requested.emit("swap",int(source.slot),target)
		else: hud.quickslot_assignment_requested.emit(target,str(source.entry.kind),str(source.entry.id))
		return
	if source.from == "inventory":
		var bag: Control = hud.lineage_inventory_ui
		for key: String in hud.lineage_side_ui.equipment_buttons:
			if inside(hud.lineage_side_ui.equipment_buttons[key],position):
				world._equip_reference_in_slot(str(source.id),key)
				return
		if is_instance_valid(hud.transaction_view) and hud.active_section in ["warehouse","sell"] and inside(hud.transaction_view,position):
			hud.transaction_view.request_drop(str(source.id))
			return
		for id: String in bag.slot_buttons:
			if inside(bag.slot_buttons[id],position):
				bag.reorder(str(source.id),id)
				return
	# All other releases are cancellations, including a drop onto the world.

func cancel() -> void:
	set_process(false)
	pointer = -2
	source.clear()
	mode = ""
	suppress_click = false
	if is_instance_valid(preview): preview.hide()
	if is_instance_valid(hint): hint.hide()
	if is_instance_valid(remove_target): remove_target.hide()
	if hud != null:
		for button: Button in hud.v20_quickslot_buttons: button.modulate = Color.WHITE
		for button: Button in hud.lineage_side_ui.equipment_buttons.values(): button.modulate = Color.WHITE
