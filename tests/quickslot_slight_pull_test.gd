extends SceneTree
## User list 2026-11-21 #26: "퀵슬롯 살짝 내리기 안 됨". AUTO used to be
## decided only on release after a 28 px vertical drag; the bottom-row slots
## leave little room and a finger sliding off the screen edge is canceled, so
## a slight pull did nothing. Real ScreenTouch/ScreenDrag on the actual Main:
## a quick pull of AUTO_PULL_DISTANCE switches AUTO while the finger moves
## (down: on / off again, up: off), a canceled touch keeps it, the original
## slot's AUTO icon follows, a tap still uses the slot and a held drag keeps
## the old release rules. Everything written under user:// is put back.
const QA = preload("res://tests/qa_class_selection.gd")
const L = preload("res://scripts/ui/reference_layout.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("QUICKSLOT_SLIGHT_PULL_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func touch(at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed; event.canceled = canceled
	root.push_input(event,true)

func drag(at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0; event.position = at; event.relative = relative
	root.push_input(event,true)

## Press, move by `delta` in `steps` frames, then release (or cancel).
func pull(from: Vector2, delta: Vector2, hold: float = 0.0, canceled: bool = false, steps: int = 4) -> void:
	touch(from,true)
	if hold > 0.0: await create_timer(hold).timeout
	else: await process_frame
	for step: int in range(1,steps+1):
		drag(from+delta*float(step)/steps,delta/steps); await process_frame
	touch(from+delta,false,canceled)
	await frames(6)

func snapshot_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file: String in dir.get_files(): user_files[path.path_join(file)] = FileAccess.get_file_as_bytes(path.path_join(file))
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
		if int(world.inventory[key]) > 0 and world._quickslot_registration_error("item",key).is_empty() and world._quickslot_auto_allowed({"kind":"item","id":key}): return key
	for record: Variant in world.catalog_db.get("아이템",[]):
		if not record is Dictionary or int(record.get("heal",0)) <= 0: continue
		var key: String = str(record.get("name",""))
		if key.is_empty() or not world._quickslot_item_supported(key): continue
		world.inventory[key] = 5
		if world._quickslot_registration_error("item",key).is_empty() and world._quickslot_auto_allowed({"kind":"item","id":key}):
			world.hud.refresh_inventory(world.inventory)
			return key
		world.inventory.erase(key)
	return ""

func auto(world: Node, slot: int) -> bool:
	return bool((world.quickslots[slot] as Dictionary).get("auto",false))

## The original slot's AUTO icon, or null without the original quick slots.
func auto_icon(hud: Node, visible: int) -> Variant:
	var controller: Variant = hud.get("original_main_ui_controller")
	if not is_instance_valid(controller) or controller.get("_quickslot_view") == null or not controller._quickslot_view.is_open(): return null
	var control: Control = hud.original_quickslot_control(visible)
	var node: Node = control
	while node != null and not (node is Node2D and str(node.get("source_member")).ends_with("Hud_QuickSlotSet.csb")): node = node.get_parent()
	if node == null: return null
	var icon: Variant = node.get("source_nodes").get(13684)
	return (icon as Node2D).is_visible_in_tree() if is_instance_valid(icon) else null

func finish(world: Node) -> void:
	world.queue_free()
	await frames(4)
	restore_user("user://")
	print("QUICKSLOT_SLIGHT_PULL_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(1 if not failures.is_empty() else 0)

func run() -> void:
	snapshot_user("user://")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world._clear_monsters()
	await frames(30)
	var hud: Node = world.hud
	check(L.AUTO_PULL_DISTANCE < L.AUTO_DISTANCE and L.AUTO_PULL_DISTANCE > L.TOUCH_SCROLL_DISTANCE, "a pull is shorter than the old release distance and longer than a tap's slop")
	var item: String = registrable_item(world)
	var visible: int = -1
	for index: int in range(10):
		if (world.quickslots[hud.quickslot_index(index)] as Dictionary).is_empty(): visible = index; break
	if not check(not item.is_empty() and visible >= 0, "a consumable and an empty quick slot"):
		await finish(world); return
	var slot: int = hud.quickslot_index(visible)
	hud.quickslot_assignment_requested.emit(slot,"item",item)
	await frames(6)
	check(str(world.quickslots[slot].get("id","")) == item, "the item is on the quick slot")
	var control: Control = hud.original_quickslot_control(visible)
	var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
	evidence["slot"] = {"item":item,"point":str(point),"room_below":root.get_visible_rect().size.y-point.y,"original":control != hud.v20_quickslot_buttons[visible]}
	var down := Vector2(2,L.AUTO_PULL_DISTANCE+2)
	await pull(point,down)
	check(auto(world,slot), "a slight pull down turns AUTO on")
	var icon: Variant = auto_icon(hud,visible)
	if icon != null: check(icon == true, "the original slot shows its AUTO icon")
	await pull(point,down)
	check(not auto(world,slot), "a slight pull down again turns it off")
	if icon != null: check(auto_icon(hud,visible) == false, "the AUTO icon goes away")
	await pull(point,down)
	await pull(point,Vector2(0,-(L.AUTO_PULL_DISTANCE+2)))
	check(not auto(world,slot), "a slight pull up turns AUTO off")
	# A tap still uses the slot.
	var pressed: Array = []
	hud.quickslot_pressed.connect(func(index: int) -> void: pressed.append(index))
	touch(point,true); await process_frame
	touch(point,false); await frames(6)
	evidence["tap"] = [str(pressed),slot,auto(world,slot),hud.pointer_transfer.pointer,hud.pointer_transfer.mode]
	check(pressed == [slot] and not auto(world,slot), "a tap uses the slot and does not switch AUTO")
	# The finger slides off the bottom edge: the touch is canceled.
	await pull(point,down,0.0,true)
	check(auto(world,slot), "the switch survives a canceled touch at the screen edge")
	await pull(point,Vector2(0,-(L.AUTO_PULL_DISTANCE+2)))
	evidence["after_cancel"] = [hud.pointer_transfer.pointer,hud.pointer_transfer.mode]
	# A held drag keeps the release rules: a short held move changes nothing.
	await pull(point,down,L.TOUCH_HOLD_SECONDS+0.2)
	check(not auto(world,slot), "a held drag shorter than AUTO_DISTANCE does not switch AUTO")
	await pull(point,Vector2(0,L.AUTO_DISTANCE+20),L.TOUCH_HOLD_SECONDS+0.2)
	check(auto(world,slot), "a held drag past AUTO_DISTANCE still turns AUTO on at release")
	# Horizontal swipe still pages (left group, first slot).
	var pages: Array = world._quickslot_pages().duplicate()
	var left: Control = hud.original_quickslot_control(0)
	point = left.get_global_transform_with_canvas()*(left.size*0.5)
	await pull(point,Vector2(-(L.QUICK_PAGE_SWIPE_DISTANCE+40),0),0.0,false,5)
	evidence["pages"] = [str(pages),str(world._quickslot_pages())]
	check(world._quickslot_pages() != pages, "a horizontal swipe still changes the page")
	await finish(world)
