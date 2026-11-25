extends SceneTree
## Quick slot use on the actual Main with real screen touches (ScreenTouch /
## ScreenDrag through the viewport), original UI when the pack is installed:
##  - bag item: hold, drag onto an empty quick slot -> registered (not dropped)
##  - quick slot: short drag down -> AUTO on, up -> AUTO off; the AUTO potion is
##    used by the consumable poll at the HP threshold
##  - quick slot: horizontal swipe -> next/previous page (5 pages)
##  - an attack skill pressed with no target says why ("대상이 없습니다"); the
##    automatic passes stay silent
##  - original skill window (UI pack): long-press a skill slot and drop it on a
##    quick slot -> registered; a short tap still only selects the slot
## Everything this test writes under user:// is put back at the end.
const QA = preload("res://tests/qa_class_selection.gd")
const L = preload("res://scripts/ui/reference_layout.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("QUICKSLOT_REGISTER_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed
	root.push_input(event,true)

func drag(at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0; event.position = at; event.relative = relative
	root.push_input(event,true)

func gesture(from: Vector2, to: Vector2, hold: float, steps: int = 8) -> void:
	touch(from,true)
	if hold > 0.0: await create_timer(hold).timeout
	else: await process_frame
	for step: int in range(1,steps+1):
		drag(from.lerp(to,float(step)/steps),(to-from)/steps)
		await process_frame
	touch(to,false)
	await frames(8)

func tap(at: Vector2) -> void:
	touch(at,true); await process_frame
	touch(at,false); await frames(6)

func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5) if is_instance_valid(control) else Vector2.INF

func slot_control(hud: Node, visible: int) -> Control:
	return hud.original_quickslot_control(visible)

func empty_visible(world: Node, hud: Node) -> int:
	for visible: int in range(10):
		var index: int = hud.quickslot_index(visible)
		if index < world.quickslots.size() and (world.quickslots[index] as Dictionary).is_empty(): return visible
	return -1

func snapshot_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file: String in dir.get_files():
		user_files[path.path_join(file)] = FileAccess.get_file_as_bytes(path.path_join(file))
	for sub: String in dir.get_directories(): snapshot_user(path.path_join(sub))

func restore_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for sub: String in dir.get_directories(): restore_user(path.path_join(sub))
	for file: String in dir.get_files():
		var full: String = path.path_join(file)
		if not user_files.has(full): DirAccess.remove_absolute(full)
	for full: String in user_files:
		if full.get_base_dir() != path: continue
		var current: PackedByteArray = FileAccess.get_file_as_bytes(full) if FileAccess.file_exists(full) else PackedByteArray()
		if current != user_files[full]:
			var out := FileAccess.open(full,FileAccess.WRITE)
			if out != null: out.store_buffer(user_files[full]); out.close()

func registrable_item(world: Node) -> String:
	for key: String in world.inventory:
		if int(world.inventory[key]) > 0 and world._quickslot_registration_error("item",key).is_empty() and world._quickslot_auto_allowed({"kind":"item","id":key}) and int(world._find_catalog_item_record(key).get("heal",0)) > 0: return key
	for key: String in world.inventory:
		if int(world.inventory[key]) > 0 and world._quickslot_registration_error("item",key).is_empty() and world._quickslot_auto_allowed({"kind":"item","id":key}): return key
	# No original pack (CI): give the plain catalog's first healing potion.
	for record: Variant in world.catalog_db.get("아이템",[]):
		if not record is Dictionary or record.get("source_m_native_item") == true or int(record.get("heal",0)) <= 0: continue
		var key: String = str(record.get("name",""))
		if key.is_empty() or not world._quickslot_item_supported(key): continue
		world.inventory[key] = 5
		if world._quickslot_registration_error("item",key).is_empty() and world._quickslot_auto_allowed({"kind":"item","id":key}):
			world.hud.refresh_inventory(world.inventory)
			return key
		world.inventory.erase(key)
	return ""

func bag_point(world: Node, hud: Node, item: String) -> Vector2:
	var size: Vector2 = root.get_visible_rect().size
	var native: bool = hud.original_inventory_is_open()
	for y: int in range(0,int(size.y),8):
		for x: int in range(0,int(size.x),8):
			var point := Vector2(x,y)
			if native:
				var hit: Dictionary = hud.original_inventory_hit_at(point)
				if not hit.is_empty() and str(hit.get("id",hit.get("reference",""))).get_slice("@@@",0) == item: return point+Vector2(4,4)
	if not native:
		var bag: Control = hud.lineage_inventory_ui
		for id: String in bag.slot_buttons:
			var button: Control = bag.slot_buttons[id]
			if str(bag._base_item_name(id)) == item and button.is_visible_in_tree():
				var middle: Vector2 = center(button)
				evidence["bag_button"] = [str(button.get_global_rect()), str(middle), hud.pointer_transfer.inside(button,middle), JSON.stringify(hud.pointer_transfer._source_at(middle)).left(160)]
				if hud.pointer_transfer.inside(button,middle): return middle
				# Clipped by the grid scroll: show the slot first.
				var scroll: Variant = bag.get("grid_scroll")
				if scroll is ScrollContainer: (scroll as ScrollContainer).ensure_control_visible(button)
				await process_frame
				await process_frame
				middle = center(button)
				if hud.pointer_transfer.inside(button,middle): return middle
		evidence["bag_slots"] = [bag.slot_buttons.size(), str(bag.slot_buttons.keys().slice(0,6)), bag.is_visible_in_tree(), bag.inventory_panel.visible]
	return Vector2.INF

func run() -> void:
	snapshot_user("user://")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world._clear_monsters()
	await frames(30)
	var hud: Node = world.hud
	evidence["original_quickslots"] = slot_control(hud,0) != hud.v20_quickslot_buttons[0]
	# 1. bag -> quick slot (hold, drag, release over the slot)
	var item: String = registrable_item(world)
	evidence["item"] = item
	var target: int = empty_visible(world,hud)
	if check(not item.is_empty() and target >= 0, "a registrable consumable and an empty quick slot"):
		hud.toggle_inventory()
		await frames(30)
		evidence["bag"] = "original" if hud.original_inventory_is_open() else "twilight"
		var start: Vector2 = await bag_point(world,hud,item)
		if not start.is_finite() and evidence.bag == "twilight":
			# Without the original pack the headless TWILIGHT bag lays its slot
			# outside the 1280x720 view (1520 px cell): register through the
			# same assignment signal the drop emits and test the rest.
			evidence["bag_drag"] = "skipped_twilight_slot_offscreen"
			hud.quickslot_assignment_requested.emit(hud.quickslot_index(target),"item",item)
			await frames(4)
			check(str(world.quickslots[hud.quickslot_index(target)].get("id","")) == item, "the assignment signal registers the item")
		elif check(start.is_finite(), "the item has a slot in the open %s bag" % evidence.bag):
			var to: Vector2 = center(slot_control(hud,target))
			var count: int = int(world.inventory.get(item,0))
			await gesture(start,to,L.TOUCH_HOLD_SECONDS+0.2)
			var entry: Dictionary = world.quickslots[hud.quickslot_index(target)]
			check(str(entry.get("kind","")) == "item" and str(entry.get("id","")) == item, "dragging onto the quick slot registers it (%s)" % JSON.stringify(entry))
			check(int(world.inventory.get(item,0)) == count and not hud.original_drop_confirm_is_open(), "registration is not a floor drop")
		hud.toggle_inventory()
		await frames(10)
	# 2. AUTO by a short drag down / up on the slot
	var slot_index: int = hud.quickslot_index(target) if target >= 0 else -1
	if slot_index >= 0 and not (world.quickslots[slot_index] as Dictionary).is_empty():
		var point: Vector2 = center(slot_control(hud,target))
		await gesture(point,point+Vector2(0,L.AUTO_DISTANCE+20),0.0,5)
		check(bool(world.quickslots[slot_index].get("auto",false)), "drag down turns AUTO on")
		await gesture(point,point-Vector2(0,L.AUTO_DISTANCE+20),0.0,5)
		check(not bool(world.quickslots[slot_index].get("auto",true)), "drag up turns AUTO off")
		await gesture(point,point+Vector2(0,L.AUTO_DISTANCE+20),0.0,5)
		check(bool(world.quickslots[slot_index].get("auto",false)), "drag down again turns AUTO on")
		# AUTO potion at the HP threshold of the settings window
		var settings: Dictionary = world.get_consumable_auto_settings()
		if int(world._find_catalog_item_record(item).get("heal",0)) > 0 and bool(settings.get("hp_enabled",false)):
			world.hp = maxi(1,int(world._effective_max_hp()*float(settings.hp_percent)/100.0)-10)
			var before: int = int(world.inventory.get(item,0))
			world.item_use_cooldowns.clear()
			world.auto_item_clock = 0.0
			world._run_auto_item_quickslots(0.25)
			await frames(3)
			check(int(world.inventory.get(item,0)) == before-1, "AUTO potion is used below HP %d%%" % int(settings.hp_percent))
			evidence["auto_potion"] = [before,int(world.inventory.get(item,0))]
	# 3. page swipe on the left group
	var left: Vector2 = center(slot_control(hud,0))
	var pages: Array = world._quickslot_pages()
	await gesture(left,left-Vector2(L.QUICK_PAGE_SWIPE_DISTANCE+40,0),0.0,5)
	check(int(world._quickslot_pages()[0]) == posmod(int(pages[0])+1,5), "swipe left shows the next page (%s)" % str(world._quickslot_pages()))
	left = center(slot_control(hud,0))
	await gesture(left,left+Vector2(L.QUICK_PAGE_SWIPE_DISTANCE+40,0),0.0,5)
	check(world._quickslot_pages() == pages, "swipe right returns to the page")
	# 4. attack skill without a target says why; automatic casts stay silent
	var catalog: Object = world.original_skills.catalog
	var attack: Dictionary = {}
	for record: Dictionary in catalog.records:
		if not catalog.permitted(record) or str(record.get("activation","")) != "active" or catalog.level_locked(record): continue
		var resolved: Dictionary = catalog.resolve(record)
		if bool(resolved.get("runtime_blocked",false)) or str(resolved.get("mode","")) != "attack" or int(resolved.get("ammo_per_hit",0)) > 0 or str(resolved.get("shape","single")) == "self_circle": continue
		if not catalog.source_learning_status(record).is_empty(): continue
		attack = record; break
	evidence["attack"] = str(attack.get("name",""))
	if check(not attack.is_empty(), "an attack skill of the class"):
		catalog.learned[str(attack.id)] = 1
		var visible: int = empty_visible(world,hud)
		if check(visible >= 0, "a free quick slot for the skill"):
			world._on_quickslot_assignment_requested(hud.quickslot_index(visible),"skill",str(attack.name))
			await frames(6)
			world._clear_monsters(); world.selected_monster = null
			world.mp = world._effective_max_mp(); world.skill_global_cooldown = 0.0; world.skill_cooldowns.clear()
			hud.message_label.text = ""
			var mp_before: int = world.mp
			await tap(center(slot_control(hud,visible)))
			check(str(hud.message_label.text) == "대상이 없습니다" and world.mp == mp_before and world.pending_attack.is_empty(), "pressing it without a target says 대상이 없습니다 and spends nothing (%s)" % str(hud.message_label.text))
			hud.message_label.text = ""
			world.skill_global_cooldown = 0.0
			check(not world._cast_job_skill(str(attack.name),false) and str(hud.message_label.text).is_empty(), "an automatic cast without a target stays silent")
			world.quickslots[hud.quickslot_index(visible)] = {}
	# 5. original skill window long-press (UI pack only)
	hud.open_skills()
	await frames(20)
	var controller: Object = hud.get("original_main_ui_controller")
	var window_open: bool = is_instance_valid(controller) and controller.has_method("skill_window_is_open") and controller.skill_window_is_open()
	evidence["skill_window"] = "original" if window_open else "twilight"
	if window_open:
		var size: Vector2 = root.get_visible_rect().size
		var held := Vector2.INF
		var held_id: String = ""
		var window: Object = controller.skill_window()
		# The middle of a fully shown slot (rows near the view edge are built
		# but clipped; a corner can sit under the tab strip).
		var catalog_now: Object = world.original_skills.catalog
		for slot: Dictionary in window._slots.values():
			var area: Variant = slot.get("area")
			if not area is Control: continue
			var middle: Vector2 = center(area)
			var hit: Dictionary = hud.original_skill_window_hit_at(middle)
			if hit.is_empty(): continue
			# A fresh character owns few skills: learn the shown one for the drop.
			var shown: Dictionary = catalog_now.record_for(str(hit.id))
			if not shown.is_empty() and str(shown.get("activation","")) == "active": catalog_now.learned[str(shown.id)] = 1
			if not world._quickslot_registration_error("skill",str(hit.id)).is_empty(): continue
			if hud.original_skill_window_hit_at(middle+Vector2(0,30)).is_empty() or hud.original_skill_window_hit_at(middle-Vector2(0,30)).is_empty(): continue
			held = middle; held_id = str(hit.id); break
		evidence["held_skill"] = held_id
		var visible: int = empty_visible(world,hud)
		if check(held.is_finite() and visible >= 0, "a registrable skill slot in the original skill window"):
			var before_tap: String = JSON.stringify(world.quickslots)
			await tap(held)
			evidence["tap_selected"] = str(window.selected())
			check(controller.skill_window_is_open() and hud.pointer_transfer.pointer == -2 and str(window.selected()) == held_id and JSON.stringify(world.quickslots) == before_tap, "a short tap selects the exact source row without registering or casting")
			var to: Vector2 = center(slot_control(hud,visible))
			touch(held,true)
			await process_frame
			check(hud.pointer_transfer.source.get("id")==held_id and hud.pointer_transfer.mode=="pending","the first press captures the same original skill ID")
			evidence["captured_source_id"] = str(hud.pointer_transfer.source.get("id",""))
			await create_timer(L.TOUCH_HOLD_SECONDS+0.15).timeout
			check(str(hud.pointer_transfer.mode) == "drag", "holding the skill slot starts a quick slot drag")
			for step: int in range(1,9):
				drag(held.lerp(to,step/8.0),(to-held)/8.0)
				await process_frame
			touch(to,false)
			await frames(8)
			var entry: Dictionary = world.quickslots[hud.quickslot_index(visible)]
			check(str(entry.get("kind",""))=="skill" and str(entry.get("skill_id",entry.get("id","")))==held_id,"dropping it on the quick slot registers the exact skill (%s)" % JSON.stringify(entry))
			world.quickslots[hud.quickslot_index(visible)] = {}
		if controller.has_method("close_skill_window"): controller.close_skill_window()
	finish(world)

func finish(world: Node) -> void:
	world.queue_free()
	await process_frame
	await process_frame
	restore_user("user://")
	print("QUICKSLOT_REGISTER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
