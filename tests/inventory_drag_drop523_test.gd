extends SceneTree
## Bag item -> floor by dragging it out of the bag (native ScreenTouch/Drag):
## confirmation first (original Common_Calculator + Common_MessageBox when the
## UI pack is installed, else the TWILIGHT confirmation with a quantity box),
## nothing moves before 확인; equipped / locked / ItemClass.IsDroppable=false
## items are refused; the floor record is picked up again and survives
## save/restore; the popup keeps touches from the field below.
const QA = preload("res://tests/qa_class_selection.gd")
const TRANSFER = preload("res://scripts/loot/inventory_ground_transfer.gd")
const F = preload("res://scripts/loot/current523_native_fields.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const LEATHER := 366 ## [재료] 가죽, IsDroppable, MaxStackAmount 10000
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("INVENTORY_DRAG_DROP_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func pick(world: Node, droppable: bool, stackable: bool) -> Dictionary:
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item") != true: continue
		var original: Variant = F.full(record).get("source_original_item",{})
		if not original is Dictionary or original.get("TestItem") != false or original.get("IsDroppable") != droppable: continue
		if stackable != (int(original.get("MaxStackAmount",1)) > 1): continue
		if not world._enhancement_kind_for_record(record).is_empty(): continue
		return record
	return {}

func plain_record(world: Node) -> Dictionary:
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item") == true or not world._enhancement_kind_for_record(record).is_empty(): continue
		if bool(record.get("quest_item",false)) or not bool(record.get("droppable",record.get("drop_allowed",true))): continue
		if str(record.get("name","")).is_empty(): continue
		return record
	return {}

func touch(world: Node, index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = at; event.pressed = pressed
	root.push_input(event,true)

func drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = at; event.relative = relative
	root.push_input(event,true)

func confirm_popup(world: Node, count: int) -> bool:
	var controller: Variant = world.hud.get("original_main_ui_controller")
	if is_instance_valid(controller) and controller.has_method("drop_confirm_is_open") and controller.drop_confirm_is_open():
		var popup: RefCounted = controller.drop_confirm_popup()
		if popup.stage == "keypad":
			popup._set_count(1)
			popup._back()
			for digit: String in str(count): popup._digit(int(digit))
			if popup.count() != count: return false
			popup._keypad_done()
		if popup.stage != "confirm": return false
		var done: Dictionary = popup._confirm()
		return bool(done.get("result",false))
	for dialog: Node in world.hud.get_node("Root").get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion():
			if dialog.quantity != null: dialog.quantity.value = count
			dialog._accept()
			return true
	return false

func cancel_popup(world: Node) -> void:
	var controller: Variant = world.hud.get("original_main_ui_controller")
	if is_instance_valid(controller) and controller.has_method("close_drop_confirm"): controller.close_drop_confirm()
	for dialog: Node in world.hud.get_node("Root").get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion(): dialog.dismiss()

func popup_open(world: Node) -> String:
	if world.hud.original_drop_confirm_is_open(): return "original:" + str(world.hud.original_main_ui_controller.drop_confirm_popup().stage)
	for dialog: Node in world.hud.get_node("Root").get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion(): return "twilight"
	return ""

func player_floor(world: Node, item_name: String) -> Array:
	var found: Array = []
	for record: Dictionary in world.ground_loot.records.values():
		if record.get("item_name") == item_name and record.get("player_dropped") == true: found.append(record)
	return found

func run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false)
	world._clear_monsters(); world._clear_drops()
	await frames(30)
	evidence["source_field"] = world.current523_aden_source_active()
	evidence["map"] = str(world.ground_loot.current_map)
	var native_installed: bool = not DEF.not_installed()
	var stack: Dictionary = D.variant_item(D.definition_id(str(LEATHER)).get("native_record",{}),1) if native_installed else plain_record(world)
	if not check(not stack.is_empty(), "a droppable stackable bag item"):
		finish(world); return
	var name_value: String = str(stack.name)
	var total: int = 5
	var part: int = 3
	if native_installed:
		# An actual physical original stack (receipt), as every pickup/grant makes.
		total = 50; part = 30
		var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":LEATHER,"amount":total,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		check(staged.get("ok",false) and world._save_game(true,staged.overrides) == OK, "grant 50 original leather")
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	else: world.inventory[name_value] = total
	evidence["stack"] = {"name":name_value,"id":int(stack.get("source_item_class_id",0)),"physical":native_installed}
	var quoted: Dictionary = TRANSFER.quote(world,name_value)
	check(quoted.get("ok",false) and int(quoted.maximum) == total, "stack quote offers its whole count (%s)" % JSON.stringify(quoted))
	# 1. confirmation first; cancel moves nothing
	var target: Vector2 = world.player.global_position + Vector2(40,0)
	var requested: Dictionary = world.request_inventory_ground_drop(name_value,target)
	evidence["request"] = JSON.stringify(requested.get("popup",{})).left(300)
	var controller: Variant = world.hud.get("original_main_ui_controller")
	if is_instance_valid(controller) and controller.get("_window_problems") is Dictionary: evidence["popup_problem"] = JSON.stringify(controller._window_problems.get("drop_popup",{})).left(300)
	await frames()
	var kind: String = popup_open(world)
	evidence["popup"] = kind
	check(kind in ["original:keypad","twilight"], "a stack opens the quantity popup first (%s)" % kind)
	check(int(world.inventory[name_value]) == total and player_floor(world,name_value).is_empty(), "nothing moves before 확인")
	if kind.begins_with("original"):
		var screen: Vector2 = root.get_visible_rect().size * Vector2(0.15,0.5)
		check(world.hud.blocks_world_input(screen) and world.hud.original_source_pointer_capture_blocked(screen), "the open popup blocks the field and the bag under it")
	cancel_popup(world)
	await frames()
	check(popup_open(world) == "" and int(world.inventory[name_value]) == total, "취소 closes without change")
	if str(world.ground_loot.current_map).is_empty():
		# Without the original pack there is no field to put anything on.
		evidence["no_field"] = true
		finish(world); return
	# 2. confirm part of the stack
	world.request_inventory_ground_drop(name_value,target)
	await frames()
	check(confirm_popup(world,part), "확인 with quantity %d" % part)
	await frames()
	var dropped: Array = player_floor(world,name_value)
	check(int(world.inventory.get(name_value,0)) == total-part and dropped.size() == 1 and int(dropped[0].quantity) == part, "%d leave the bag as one floor stack (%s)" % [part,JSON.stringify(dropped).left(300)])
	if dropped.size() == 1:
		var view: Button = world.ground_loot.views.get(str(dropped[0].id))
		check(is_instance_valid(view), "floor view shown at the player")
		if native_installed and is_instance_valid(view):
			check(view.source_ground_status.get("ok",false) or view.source_ground_status.get("status") == "selected_body_action", "floor view uses the original ground sprite (%s)" % JSON.stringify(view.source_ground_status).left(200))
		# 3. save / load keeps the player floor
		check(world._save_game(true) == OK, "save with the floor stack")
		var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		var saved: Array = disk.get("ground_drops",[]) if disk is Dictionary else []
		var on_disk: bool = false
		for entry: Variant in saved:
			if entry is Dictionary and entry.get("id") == dropped[0].id and int(entry.get("quantity",0)) == part: on_disk = true
		check(on_disk, "the floor stack is in the save")
		world.item_instances = {}; world.inventory = {}
		world._load_game(true)
		await frames(20)
		check(str(world.patch523_owner_state_problem).is_empty() and int(world.inventory.get(name_value,0)) == total-part, "load accepts the bag and floor ownership (%s)" % str(world.patch523_owner_state_problem))
		check(world.ground_loot.records.has(str(dropped[0].id)), "restored floor keeps the dropped stack on map %s" % str(dropped[0].map_id))
		# 4. pick it up again
		view = world.ground_loot.views.get(str(dropped[0].id))
		await create_timer(1.0).timeout
		var collected: bool = is_instance_valid(view) and world._collect_ground_drop(view)
		check(collected and int(world.inventory.get(name_value,0)) == total and player_floor(world,name_value).is_empty(), "picked up again: %d in the bag (%d)" % [total,int(world.inventory.get(name_value,0))])
	# 5. refused kinds
	if native_installed:
		var fixed: Dictionary = pick(world,false,true)
		if fixed.is_empty(): fixed = pick(world,false,false)
		if check(not fixed.is_empty(), "an original IsDroppable=false item"):
			world.inventory[str(fixed.name)] = 1
			check(not TRANSFER.quote(world,str(fixed.name)).get("ok",true) and not world._drop_inventory_reference(str(fixed.name),target) and int(world.inventory[str(fixed.name)]) == 1, "IsDroppable=false is refused")
			world.inventory.erase(str(fixed.name))
	var locks: Dictionary = world.ui_preferences.get("item_locks",{}).duplicate()
	var locked: Dictionary = locks.duplicate(); locked[name_value] = true
	world.ui_preferences["item_locks"] = locked
	check(not TRANSFER.quote(world,name_value).get("ok",true) and not world._drop_inventory_reference(name_value,target), "locked item is refused")
	world.ui_preferences["item_locks"] = locks
	var equipped_reference: String = ""
	for key: String in world.item_instances:
		if world._is_instance_equipped(key): equipped_reference = str(world.item_instances[key].get("name",""))+"@@@"+key; break
	if not equipped_reference.is_empty():
		check(not TRANSFER.quote(world,equipped_reference).get("ok",true) and not world._drop_inventory_reference(equipped_reference,target), "equipped item is refused")
	evidence["equipped_checked"] = not equipped_reference.is_empty()
	# 6. actual drag out of the open bag with native touches
	world.hud.toggle_inventory()
	await frames(30)
	var native_bag: bool = world.hud.original_inventory_is_open()
	evidence["bag"] = "original" if native_bag else "twilight"
	var start: Vector2 = Vector2.INF
	var size: Vector2 = root.get_visible_rect().size
	for y: int in range(0,int(size.y),8):
		for x: int in range(0,int(size.x),8):
			var point := Vector2(x,y)
			var hit: Dictionary = world.hud.original_inventory_hit_at(point) if native_bag else {}
			if native_bag and not hit.is_empty() and str(hit.get("id",hit.get("reference",""))).get_slice("@@@",0) == name_value: start = point
			elif not native_bag and world.hud.lineage_inventory_ui.slot_buttons.has(name_value) and world.hud.pointer_transfer.inside(world.hud.lineage_inventory_ui.slot_buttons[name_value],point): start = point
			if start.is_finite(): break
		if start.is_finite(): break
	if check(start.is_finite(), "the stack has a slot in the open %s bag" % evidence.bag):
		var field_point: Vector2 = Vector2.INF
		for y: int in range(int(size.y*0.3),int(size.y*0.7),16):
			for x: int in range(16,int(size.x*0.5),16):
				if not world.hud.blocks_world_input(Vector2(x,y)) and not world.hud.original_source_pointer_capture_blocked(Vector2(x,y)): field_point = Vector2(x,y); break
			if field_point.is_finite(): break
		if check(field_point.is_finite(), "an open field point beside the bag"):
			var moved_before: Vector2 = world.player.global_position
			touch(world,0,start,true)
			await create_timer(0.6).timeout
			var steps: int = 8
			for step: int in range(1,steps+1):
				drag(0,start.lerp(field_point,float(step)/steps),(field_point-start)/steps)
				await process_frame
			evidence["drag_mode"] = str(world.hud.pointer_transfer.mode)
			evidence["drag_source"] = str(world.hud.pointer_transfer.source.get("id",""))
			touch(world,0,field_point,false)
			await frames(8)
			var opened: String = popup_open(world)
			check(opened in ["original:keypad","twilight"], "drag out of the bag onto the field opens the quantity popup (%s)" % opened)
			check(world.player.global_position.distance_to(moved_before) < 2.0, "the drag does not move the player (no touch leak)")
			evidence["drag"] = {"from":[start.x,start.y],"to":[field_point.x,field_point.y],"popup":opened}
			if confirm_popup(world,2):
				await frames()
				check(int(world.inventory.get(name_value,0)) == total-2 and not player_floor(world,name_value).is_empty(), "dragged 2 reach the floor")
	finish(world)

func finish(world: Node) -> void:
	world.queue_free()
	await process_frame
	print("INVENTORY_DRAG_DROP_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
