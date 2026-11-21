extends SceneTree
## User list 2026-11-21 #20-#23: bag touches on the actual Main with real
## ScreenTouch/ScreenDrag (original 523 pack + original UI when installed).
##  #20 one tap shows only the item's name over the slot for about 3 s (in the
##      original Font/font_B.ttf); no information popup opens on a tap.
##  #22 consumable: the tap shows "사용" on the slot (original Common_Slot
##      Label_Center); a tap on it while shown uses it.
##  #23 equipment: "장착", the next tap equips; worn: "해제", the next tap
##      unequips.
##  #21 the information popup opens only by a long press released in place,
##      and a tap on another slot then selects that slot (bag side).
## Materials show their name and no marker; a second tap does nothing; an
## expired marker re-arms instead of using. user:// is put back at the end.
const QA = preload("res://tests/qa_class_selection.gd")
const L = preload("res://scripts/ui/reference_layout.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const SLOTS = preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const ORIGIN = {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
const POTION := 233 ## [물약-회복] 체력 회복제 (각인)
const LEATHER := 366 ## [재료] 가죽
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}
var activations: Array[String] = []

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("INVENTORY_TAP_ACTION_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed
	root.push_input(event,true)

func tap(at: Vector2) -> void:
	touch(at,true); await process_frame
	touch(at,false); await frames(6)

func long_press(at: Vector2) -> void:
	touch(at,true)
	await create_timer(L.TOUCH_HOLD_SECONDS+0.25).timeout
	touch(at,false); await frames(6)

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

func reference_of(world: Node, needle: String) -> String:
	for reference: String in world.hud.lineage_inventory_ui.sorted_references:
		if reference.get_slice("@@@",0) == needle: return reference
	return ""

## Screen center of a built original slot (the bag scrolls to it if needed).
func slot_point(hud: Node, reference: String) -> Vector2:
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	for attempt: int in range(30):
		if view._hits.has(reference):
			var control: Control = view._hits[reference].control
			var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
			if str(hud.original_inventory_hit_at(point).get("reference","")) == reference: return point
		var step := InputEventScreenDrag.new()
		step.index = 0; step.relative = Vector2(0,-60)
		view._forward_scroll_input(step)
		await process_frame
	return Vector2.INF

## Label_Center of the slot: [visible, text].
func marker(hud: Node, reference: String) -> Array:
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	if not view._hits.has(reference): return [false,""]
	var node: Variant = view._hits[reference].native_slot_scene.get("source_nodes").get(SLOTS.ACTION)
	if not is_instance_valid(node): return [false,"<no node>"]
	var text: Variant = node.get_meta("source_text").original_options.get("text","") if node.has_meta("source_text") else ""
	return [(node as Node2D).is_visible_in_tree(),str(text)]

func markers_shown(hud: Node) -> int:
	var shown: int = 0
	for reference: String in hud.original_main_ui_controller._inventory_view._hits:
		if marker(hud,reference)[0]: shown += 1
	return shown

func finish(world: Node) -> void:
	world.queue_free()
	await frames(4)
	restore_user("user://")
	print("INVENTORY_TAP_ACTION_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(1 if not failures.is_empty() else 0)

func run() -> void:
	snapshot_user("user://")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world._clear_monsters()
	await frames(30)
	var hud: Node = world.hud
	var bag: Control = hud.lineage_inventory_ui
	check(bag.ITEM_NAME_DURATION_MS == 3000, "the tapped name stays about three seconds")
	check(bag.has_method("item_action_armed") and bag.has_method("open_item_info"), "the bag arms a tapped item and opens information on request")
	if DEF.not_installed() or not is_instance_valid(hud.get("original_main_ui_controller")):
		evidence["mode"] = "no_original_pack"
		await finish(world); return
	# Grant: potions, a material, equipment candidates.
	var grants: Array = [{"item_class_id":POTION,"amount":5,"bless_raw":1,"enchant":0},{"item_class_id":LEATHER,"amount":3,"bless_raw":1,"enchant":0}]
	var equipment: Array[int] = []
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if equipment.size() >= 6: break
		if record.get("source_m_native_item") != true or not D.equipment(record): continue
		var id: int = int(record.get("source_item_class_id",0))
		if world._equipment_slot_for_record(record).is_empty() or int(DEF.row("ItemClass",id).get("LevelLimitMin",99)) > int(world.level): continue
		var grant: Dictionary = {"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}
		if not INVENTORY.stage(world,[grant],ORIGIN).get("ok",false): continue
		grants.append(grant); equipment.append(id)
	var staged: Dictionary = INVENTORY.stage(world,grants,ORIGIN)
	if not check(staged.get("ok",false), "grant original potions, leather and equipment"):
		await finish(world); return
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	world._update_hud(); world.hud.refresh_inventory(world.inventory)
	hud.inventory_item_activated.connect(func(reference: String) -> void: activations.append(reference))
	hud.toggle_inventory()
	await frames(30)
	if not check(hud.original_inventory_is_open(), "the original bag opens"):
		await finish(world); return
	var controller: Node = hud.original_main_ui_controller
	# --- #20/#22 consumable
	var potion_name: String = str(D.definition_id(str(POTION)).get("native_record",{}).get("name",""))
	var potion: String = reference_of(world,potion_name)
	var point: Vector2 = await slot_point(hud,potion)
	evidence["potion"] = [potion.left(40),str(point)]
	if check(point.is_finite(), "the potion has an original slot"):
		await tap(point)
		check(bag.selected_item == potion, "a tap selects the potion")
		check(bag.item_name_hint.visible and bag.item_name_hint.text == bag._enhanced_display_name(bag._find_item_record(potion),potion), "a tap shows the item's name over it")
		var font: Font = bag.item_name_hint.get_theme_font("font")
		check(font is FontFile and font == hud.original_ui_font("Font/font_B.ttf"), "the name uses the original Font/font_B.ttf")
		check(not controller.item_tooltip_is_open(), "a tap no longer opens the information popup")
		check(marker(hud,potion) == [true,"사용"], "the slot shows 사용 (%s)" % str(marker(hud,potion)))
		check(markers_shown(hud) == 1, "only the tapped slot shows a marker")
		var hint_rect: Rect2 = bag.item_name_hint.get_global_rect()
		check(hint_rect.end.y <= point.y, "the name sits above the slot")
		activations.clear()
		await tap(point)
		check(activations == [potion], "the tap on 사용 uses the potion (%s)" % str(activations))
		check(not marker(hud,potion)[0] and not bag.item_name_hint.visible, "using it clears the marker")
		# expired marker: a later tap re-arms instead of using
		await tap(point)
		check(marker(hud,potion)[0], "the next tap arms it again")
		await create_timer(3.2).timeout
		await frames(3)
		check(not marker(hud,potion)[0] and not bag.item_name_hint.visible, "name and marker disappear after about three seconds")
		activations.clear()
		await tap(point)
		check(activations.is_empty() and marker(hud,potion) == [true,"사용"], "a tap after expiry only arms it")
		await tap(point)
		check(activations.size() == 1, "and the following tap uses it")
	# --- material: name only
	var leather: String = reference_of(world,str(D.definition_id(str(LEATHER)).get("native_record",{}).get("name","")))
	var leather_point: Vector2 = await slot_point(hud,leather)
	if check(leather_point.is_finite(), "the leather has an original slot"):
		activations.clear()
		await tap(leather_point)
		check(bag.selected_item == leather and bag.item_name_hint.visible and not marker(hud,leather)[0], "a material shows its name and no marker")
		await tap(leather_point)
		check(activations.is_empty(), "a second tap on a material does nothing")
	# --- #23 equipment
	var equipped_ok: bool = false
	for id: int in equipment:
		var name_value: String = str(D.definition_id(str(id)).get("native_record",{}).get("name",""))
		var reference: String = reference_of(world,name_value)
		var at: Vector2 = await slot_point(hud,reference)
		if reference.is_empty() or not at.is_finite(): continue
		await tap(at)
		if not check(marker(hud,reference) == [true,"장착"], "equipment shows 장착 (%s)" % str(marker(hud,reference))): break
		await tap(at)
		await frames(10)
		if not bag._is_item_equipped(reference):
			evidence.get_or_add("not_equippable",[]).append(name_value)
			continue
		equipped_ok = true
		evidence["equipped"] = name_value
		at = await slot_point(hud,reference)
		await tap(at)
		check(marker(hud,reference) == [true,"해제"], "worn equipment shows 해제 (%s)" % str(marker(hud,reference)))
		await tap(at)
		await frames(10)
		check(not bag._is_item_equipped(reference), "the tap on 해제 unequips it")
		break
	check(equipped_ok, "the tap on 장착 equips a wearable item (%s)" % str(evidence.get("not_equippable",[])))
	# --- #21 information only by a long press; other slots still respond
	point = await slot_point(hud,potion)
	if point.is_finite() and leather_point.is_finite():
		activations.clear()
		await long_press(point)
		check(controller.item_tooltip_is_open() and bag.selected_item == potion, "a long press released in place opens the information popup")
		check(activations.is_empty(), "the long press does not use the item")
		leather_point = await slot_point(hud,leather)
		await tap(leather_point)
		check(bag.selected_item == leather and not controller.item_tooltip_is_open(), "a tap on another slot selects it and closes the popup")
	hud.toggle_inventory()
	await frames(6)
	check(not controller.item_tooltip_is_open() and not bag.item_name_hint.visible, "closing the bag clears name and popup")
	await finish(world)
