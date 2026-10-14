extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
var world: TwilightWorld
var hud: Node
var failures: Array[String] = []
var assertions: int = 0
var stages: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures.append(message)
		print("EIGHT_INTERACTIONS_FAIL ",message)
func frames(count: int = 3) -> void:
	for i: int in range(count): await process_frame
func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)
func mouse(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.pressed = down
	root.push_input(e,true)
func touch(p: Vector2, down: bool, canceled: bool = false, finger: int = 12) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.index = finger
	e.pressed = down
	e.canceled = canceled
	root.push_input(e,true)
func move_pointer(p: Vector2, native: bool = false) -> void:
	if native:
		var e := InputEventScreenDrag.new()
		e.position = p
		e.index = 12
		root.push_input(e,true)
	else:
		var e := InputEventMouseMotion.new()
		e.position = p
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(e,true)
func tap(p: Vector2, native: bool = false) -> void:
	if native: touch(p,true); touch(p,false)
	else: mouse(p,true); mouse(p,false)
	await frames(2)
func drag(a: Vector2,b: Vector2,native: bool = false) -> void:
	if native: touch(a,true)
	else: mouse(a,true)
	move_pointer(b,native)
	if native: touch(b,false)
	else: mouse(b,false)
	await frames(3)
func freeze() -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
func bag_search(text: String) -> Control:
	if not hud.workspace.visible or hud.active_section != "inventory": hud.toggle_inventory()
	await frames(4)
	var bag: Control = hud.lineage_inventory_ui
	bag.detail_active = false
	bag.search_line.text = text
	bag._refresh_inventory_grid()
	bag._reflow()
	hud.pointer_transfer.cancel()
	await frames(4)
	return bag

func run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(6)
	check(QA.enter_game(world),"character ready")
	hud = world.hud
	freeze()
	world.player.clear_click_path()
	world.inventory["HP 물약"] = 30
	world._grant_playtest_catalog_item("낡은 장검",3)
	var ids: Array[String] = []
	for id: String in world.item_instances:
		if world.item_instances[id].name == "낡은 장검": ids.append(id)
	ids.sort()
	check(ids.size() >= 3,"three distinct physical equipment fixtures")
	if ids.size() < 3: finish(); return
	var ref0: String = "낡은 장검@@@"+ids[0]
	var ref1: String = "낡은 장검@@@"+ids[1]
	var bag: Control = await bag_search("낡은 장검")
	var p: Vector2 = point(bag.slot_buttons[ref0])
	await tap(p)
	check(bag.detail_active and bag.detail_panel.is_visible_in_tree() and bag.selected_item == ref0,"single mouse tap shows correct equipment details")
	await tap(p)
	check(world.equipped_items.weapon.get("instance_id","") == ids[0],"double mouse tap equips exact instance")
	bag = await bag_search("낡은 장검")
	p = point(bag.slot_buttons[ref1])
	await tap(p,true)
	check(bag.detail_active and bag.selected_item == ref1,"single native tap shows details")
	await tap(p,true)
	check(world.equipped_items.weapon.get("instance_id","") == ids[1],"double native tap equips second instance")
	bag = await bag_search("HP 물약")
	world.hp = 1
	world.item_use_cooldowns.clear()
	p = point(bag.slot_buttons["HP 물약"])
	var count: int = world.inventory["HP 물약"]
	await tap(p,true)
	check(int(world.inventory["HP 물약"]) == count,"single tap does not consume")
	await tap(p,true)
	check(int(world.inventory["HP 물약"]) == count-1,"double native tap consumes exactly once")
	print("EIGHT_STAGE ",assertions)
	stages.append("single_double_tap")

	# Native outward drag works without long-press; equipped/locked gear is safe.
	world.item_instances[ids[0]]["level"] = 7
	world.item_instances[ids[0]]["element"] = "fire"
	world.item_instances[ids[0]]["element_level"] = 3
	world.item_instances[ids[0]]["bless_state"] = "blessed"
	world.item_instances[ids[0]]["record"] = world._find_catalog_item_record("낡은 장검").duplicate(true)
	var before_physical: Dictionary = world.item_instances[ids[0]].duplicate(true)
	world._update_hud()
	bag = await bag_search("낡은 장검")
	var before_drop: int = int(world.inventory["낡은 장검"])
	var ground_before: int = world.ground_loot.records.size()
	check(not hud.blocks_world_input(Vector2(420,390)),"fixture floor is not a HUD element")
	await drag(point(bag.slot_buttons[ref0]),Vector2(420,390),true)
	check(int(world.inventory["낡은 장검"]) == before_drop-1 and not world.item_instances.has(ids[0]),"native bag-floor drag transfers exact inventory ownership")
	check(world.ground_loot.records.size() == ground_before+1,"one real floor item spawned")
	var ground_id: String = ""
	for id: String in world.ground_loot.records:
		if str(world.ground_loot.records[id].get("physical_item",{}).get("id","")) == ids[0]: ground_id = id
	check(not ground_id.is_empty(),"floor record retains physical identity")
	if not ground_id.is_empty():
		check(world.ground_loot.records[ground_id].physical_item.data == before_physical,"floor preserves enhancement, element, blessing, pinned record")
		var snapshot: Array = world.ground_loot.snapshot()
		world.ground_loot.restore(snapshot)
		check(world.ground_loot.records[ground_id].physical_item.data == before_physical,"floor serialization retains full physical payload")
		var view: Button = world.ground_loot.views[ground_id]
		var destination: Vector2 = view.get_meta("world_position")
		world.player.global_position = destination
		view.visible_since = Time.get_ticks_msec()-900
		check(world._collect_ground_drop(view),"dropped equipment can be collected")
		check(world.item_instances[ids[0]] == before_physical and int(world.inventory["낡은 장검"]) == before_drop,"pickup restores same physical instance and count")
		check(not world._collect_ground_drop(view),"stale pickup cannot duplicate")
	world._set_item_locked(ref0,true)
	check(not world._drop_inventory_reference(ref0,world.player.global_position),"locked equipment remains in inventory")
	world._set_item_locked(ref0,false)
	check(not world._drop_inventory_reference(ref1,world.player.global_position),"equipped equipment cannot be lost through drop")
	world._save_game(true)
	world.item_instances[ids[0]]["level"] = 0
	world._load_game(true)
	freeze()
	# JSON stores numeric variants as floats; compare normalized serialized data.
	check(JSON.parse_string(JSON.stringify(world.item_instances[ids[0]])) == JSON.parse_string(JSON.stringify(before_physical)),"save and actual load preserve recovered physical item")
	print("EIGHT_STAGE ",assertions)
	# Persist an item while it is on the floor, then restore without duplication.
	check(world._drop_inventory_reference(ref0,world.player.global_position),"drop recovered item again before save")
	world._save_game(true)
	world._load_game(true)
	freeze()
	check(not world.item_instances.has(ids[0]),"loading floor save does not recreate owned instance in bag")
	ground_id = ""
	for id: String in world.ground_loot.records:
		if str(world.ground_loot.records[id].get("physical_item",{}).get("id","")) == ids[0]: ground_id = id
	check(not ground_id.is_empty(),"actual load restores the player-dropped floor record")
	if not ground_id.is_empty():
		var dropped: Button = world.ground_loot.views[ground_id]
		dropped.visible_since = Time.get_ticks_msec()-900
		world.player.global_position = dropped.get_meta("world_position")
		world.player.set_auto_enabled(true)
		world._run_auto_ground_pickup()
		check(not world.loot_pickup.target_id == ground_id and world.ground_loot.valid_view(dropped),"AUTO does not immediately pick up items deliberately dropped")
		world.loot_pickup.select(dropped)
		check(world.player.auto_enabled,"manual loot selection preserves AUTO")
		world.loot_pickup.request_selected()
		check(world.player.auto_enabled and world.item_instances.has(ids[0]),"manual loot pickup succeeds while AUTO remains on")
		check(JSON.parse_string(JSON.stringify(world.item_instances[ids[0]])) == JSON.parse_string(JSON.stringify(before_physical)),"saved floor item retains all options after recovery")
	world.player.set_auto_enabled(false)
	bag = await bag_search("HP 물약")
	var stack_before: int = int(world.inventory["HP 물약"])
	await drag(point(bag.slot_buttons["HP 물약"]),Vector2(420,390))
	check(int(world.inventory["HP 물약"]) == stack_before-1,"stack floor drag drops one unit")
	var stack_source: Vector2 = point(bag.slot_buttons["HP 물약"])
	touch(stack_source,true)
	move_pointer(Vector2(420,390),true)
	touch(Vector2(420,390),false,true)
	await frames()
	check(int(world.inventory["HP 물약"]) == stack_before-1,"canceled drag never drops a stack")
	check(hud.pointer_transfer.pointer == -2,"canceled native drag releases pointer ownership")
	stages.append("floor_drop_identity_save")

	# Both NPC teleport and map selector receive real native input, including scroll.
	hud._close_workspace()
	world.level = 90
	world.gold = 1000000
	hud.open_npc_teleport()
	await frames(5)
	var list: ItemList = hud.workspace.find_child("NpcTeleportDestinations",true,false)
	var screen: Node = list.get_parent()
	var row_point: Vector2 = list.get_global_transform_with_canvas()*list.get_item_rect(1).get_center()
	await tap(row_point,true)
	check(screen.selected_index == 1 and list.get_selected_items() == PackedInt32Array([1]),"native teleport row selects intended destination")
	var old_index: int = screen.selected_index
	touch(row_point,true)
	move_pointer(row_point-Vector2(0,60),true)
	touch(row_point-Vector2(0,60),false)
	await frames()
	check(screen.selected_index == old_index,"list scroll does not select a different destination")
	list.get_v_scroll_bar().value = 0
	await frames()
	row_point = list.get_global_transform_with_canvas()*list.get_item_rect(1).get_center()
	await tap(row_point,true)
	var destination_id: String = str(screen.destinations[1].id)
	var price: int = int(preload("res://scripts/npc/teleport_policy.gd")._rule(destination_id).price)
	var wallet: int = world.gold
	await tap(point(screen.travel),true)
	check(world.active_map_id == destination_id and world.gold == wallet-price,"native confirm performs actual map travel and charges once")
	freeze()
	hud._close_workspace()
	hud.toggle_map()
	await frames(5)
	list = hud.region_selection
	var index: int = 0
	await tap(list.get_global_transform_with_canvas()*list.get_item_rect(index).get_center(),true)
	check(list.get_selected_items() == PackedInt32Array([index]),"world-map region list supports native selection")
	var enter: Button = hud.workspace.find_child("EnterRegion",true,false)
	await tap(point(enter),true)
	check(world.active_map_id == str(list.get_item_metadata(index)),"world-map native button enters selected map")
	freeze()
	hud._close_workspace()
	print("EIGHT_STAGE ",assertions)
	stages.append("native_teleport")

	# Use actual game actors and a test-only NPC record; never mutate source files.
	var actors: Array[TwilightMonster] = []
	for actor: Node in world.monsters_root.get_children():
		actor.hide()
		if actors.size() < 3 and actor is TwilightMonster: actors.append(actor)
	check(actors.size() == 3,"three real game actors available")
	if actors.size() == 3:
		world.player.global_position = world._spawn_position()
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await frames()
		for i: int in range(3):
			actors[i].show()
			actors[i].dead = false
			actors[i].global_position = COORD.screen_to_world(root,Vector2(460+i*120,320))+Vector2(0,28)
		var interaction: Node = world.world_interactions
		interaction.clear_selection()
		world.player.clear_click_path()
		await drag(Vector2(460,320),Vector2(700,320),true)
		check(interaction.selections.size() == 3,"native drag sweep selects crossed monsters")
		check(world.player.click_path.is_empty(),"selection drag never moves player")
		if interaction.selections.size() == 3:
			check(interaction.selections[0].actor.get_ref() == actors[0] and interaction.selections[1].actor.get_ref() == actors[1] and interaction.selections[2].actor.get_ref() == actors[2],"left list preserves selection order")
			var third: Vector2 = interaction.listing.get_global_transform_with_canvas()*interaction.listing.get_item_rect(2).get_center()
			await tap(third,true)
			check(interaction.selections[0].actor.get_ref() == actors[2] and interaction.selections[1].actor.get_ref() == actors[0] and interaction.selections[2].actor.get_ref() == actors[1],"native row tap promotes target and preserves others")
			check(world.selected_monster == actors[2] and world.auto_target == actors[2],"promoted row drives combat primary target")
			actors[2].dead = true
			interaction.prune()
			check(interaction.selections.size() == 2 and world.selected_monster == actors[0],"dead target pruned and next selected")
			actors[0].life_id += 1
			interaction.prune()
			check(interaction.selections.size() == 1 and world.selected_monster == actors[1],"pooled actor new life cannot inherit stale selection")
		var npc_position: Vector2 = COORD.screen_to_world(root,Vector2(810,320))+Vector2(0,28)
		var npc: Dictionary = {"id":"qa_selection_npc","name":"선택 시험 NPC","role":"guide","position":[npc_position.x,npc_position.y]}
		world.field_map.data.npc_spawn.append(npc)
		interaction.clear_selection()
		await drag(Vector2(750,260),Vector2(860,370))
		check(interaction.selections.size() == 1 and interaction.primary_is_npc(),"blank-floor marquee can select NPC without opening service")
		check(not hud.workspace.visible,"NPC drag selection does not open dialogue")
		world.player.set_auto_enabled(true)
		world._run_auto_hunt()
		check(world.player.auto_enabled and world.auto_target == null,"NPC primary pauses attack without switching AUTO off")
		world.field_map.data.npc_spawn.erase(npc)
		interaction.prune()
		check(interaction.selections.is_empty(),"removed NPC is pruned")
		print("EIGHT_STAGE ",assertions)
	stages.append("drag_multi_select_priority")

	# Manual navigation wins over auto path replacement. AUTO resumes after arrival.
	world.world_interactions.clear_selection()
	world.player.set_auto_enabled(true)
	world.player.clear_click_path()
	var goal: Vector2 = world.player.global_position+Vector2(50,0)
	if not world._is_walkable_world(goal): goal = world.player.global_position
	await tap(COORD.world_to_screen(root,goal),true)
	check(world.player.auto_enabled,"native floor click does not disable AUTO")
	var manual_path: PackedVector2Array = world.player.click_path.duplicate()
	world._run_auto_hunt()
	check(world.player.click_path == manual_path and world.player.manual_navigation,"AUTO does not replace manual path")
	# Arrival releases manual priority and the automatic hunt can choose a target.
	world.player.set_physics_process(true)
	for tick: int in range(100):
		await physics_frame
		world._run_auto_hunt()
		if not world.player.has_manual_movement(): break
	world.player.set_physics_process(false)
	check(not world.player.has_manual_movement() and world.player.global_position.distance_to(goal) <= 8.0,"manual destination actually reached with AUTO enabled")
	world._run_auto_hunt()
	check(world.player.auto_enabled and (is_instance_valid(world.auto_target) or not world.pending_attack.is_empty()),"AUTO resumes selecting or attacking after manual arrival")
	world.player.set_touch_vector(Vector2(1,0))
	world.player._physics_process(0.016)
	world._run_auto_hunt()
	check(world.player.auto_enabled and world.player.has_manual_movement(),"joystick movement keeps AUTO enabled and priority")
	world.player.set_touch_vector(Vector2.ZERO)
	world.player.clear_click_path()
	await tap(point(hud.v20_auto_button),true)
	check(not world.player.auto_enabled,"actual native AUTO button disables mode")
	hud.show_target("must not reappear",10,10)
	world._update_target_hud()
	await frames()
	check(not is_instance_valid(hud.v20_target_panel) and not is_instance_valid(hud.target_panel) and hud.get_node_or_null("Root/TargetPanel") == null,"removed top target readout cannot be re-shown")
	print("EIGHT_STAGE ",assertions)
	stages.append("sticky_auto_removed_top_hud")
	finish()

func finish() -> void:
	print("EIGHT_INTERACTIONS_RESULT ",JSON.stringify({"assertions":assertions,"failures":failures,"stages":stages}))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
