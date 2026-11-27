extends "res://tests/quickslot_register523_main_test.gd"
## Run with the installed 523 definitions/UI and an isolated user directory.
const STORAGE = preload("res://scripts/ui/original_ui/source_main_storage_window.gd")
const POPUP = preload("res://scripts/ui/original_ui/source_main_drop_popup.gd")
const TREE = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const MERGE = preload("res://scripts/loot/native_stack_merge.gd")
const POTION := 233

func _button_for(node: Node, method: String, args: Array) -> Control:
	var source: Variant=node.get_meta("source_button") if node.has_meta("source_button") else null
	if is_instance_valid(source):
		var callback: Callable=source._activation
		if callback.is_valid() and str(callback.get_method())==method and callback.get_bound_arguments()==args and source._input_area.is_visible_in_tree():
			return source._input_area
	for child: Node in node.get_children():
		var found: Control=_button_for(child,method,args)
		if found!=null:return found
	return null

func _hit(control: Control, label: String) -> bool:
	var point: Vector2=center(control)
	if not check(root.get_visible_rect().has_point(point),"visible touch target: "+label):return false
	await tap(point)
	return true

func _slot(storage: RefCounted, side: String, reference: String) -> Control:
	for index: int in storage.rows(side).size():
		if STORAGE.reference_of(storage.rows(side)[index])==reference:return _button_for(storage._scene,"_slot_pressed",[side,index])
	return null

func _popup_button(popup: RefCounted, path: String) -> Control:
	var located: Dictionary=TREE.locate(popup._scene,popup._out,path)
	if not located.get("ok",false):return null
	var node: Node=located.player.source_nodes[located.offset]
	return node.get_meta("source_button")._input_area if node.has_meta("source_button") else null

func _answer(controller: Node, direction: String, count: int, cancel: bool=false) -> bool:
	var popup: RefCounted=controller.drop_confirm_popup()
	if not check(popup!=null and popup.is_open() and popup.last_result.member==POPUP.KEYPAD,"authored quantity window opens for "+direction):return false
	if not await _hit(_popup_button(popup,"Btn_No_%d"%count),"quantity digit"):return false
	if not check(popup.count()==count,"the chosen quantity is displayed"):return false
	if not await _hit(_popup_button(popup,"Btn_Select"),"keypad confirmation"):return false
	if not check(popup.is_open() and popup.stage=="confirm" and popup.last_result.member==POPUP.BOX and popup._operation==direction and popup.count()==count,"authored item review preserves operation and quantity"):return false
	var located: Dictionary=TREE.locate(popup._scene,popup._out,"Text_Message")
	var label: Variant=located.player.source_nodes[located.offset].get_meta("source_text",null) if located.get("ok",false) else null
	var wording: String="창고에 맡기" if direction=="deposit" else "창고에서 찾으"
	check(is_instance_valid(label) and str(label.original_options.get("text","")).contains("%d개를 %s" % [count,wording]),"the rendered review names the correct direction and quantity")
	return await _hit(_popup_button(popup,"Btn_Cancel" if cancel else "Btn_Yes"),"transfer review button")

func run() -> void:
	root.size=Vector2i(1280,720)
	if not check(not FileAccess.file_exists("user://twilight_v20_save.json"),"disposable Main profile"):_finish_storage();return
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer=-100000
	if check(QA.enter_game(world,"기사"),"normal Main entry"):
		await frames()
		await _exercise_storage(world)
	world.queue_free()
	await frames()
	_finish_storage()

func _finish_storage() -> void:
	print("ORIGINAL_STORAGE_TRANSFER_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func _exercise_storage(world: TwilightWorld) -> void:
	var grants: Array=[{"item_class_id":POTION,"amount":4,"bless_raw":1,"enchant":0}]
	if not check(SUPPLY.commit(world,grants,{"kind":"warehouse_ui_test"}),"four authentic potions are owned by the disposable character"):return
	var uid: String=""
	var item: String=""
	for candidate: String in world.item_instances:
		var row: Dictionary=world.item_instances[candidate]
		if int(row.get("record",{}).get("source_item_class_id",0))==POTION:
			uid=candidate
			item=str(row.name)
			break
	if not check(not uid.is_empty(),"the issued physical stock exists"):return
	var reference: String=item+"@@@"+uid
	var hud: Node=world.hud
	var controller: Node=hud.original_main_ui_controller
	hud.open_warehouse()
	await frames()
	if not check(controller.storage_window_is_open(),"authored warehouse opens through Main HUD"):return
	var storage: RefCounted=controller._storage_window
	var initial: int=int(world.inventory.get(item,0))
	var disk: String=FileAccess.get_sha256(world.save_path())
	# Keep the warehouse assets present and remove only the popup from this fixture.
	var scenes: Dictionary=controller._pack.manifest.scenes
	var review: Variant=scenes.get(POPUP.BOX)
	if not check(review is Dictionary,"authored confirmation resource was admitted"):return
	scenes.erase(POPUP.BOX)
	var touched: bool=await _hit(_slot(storage,"bag",reference),"fallback when confirmation asset is absent")
	scenes[POPUP.BOX]=review
	var fallback: Node=hud.get_node_or_null("Root/TwilightConfirmation")
	if not check(touched and is_instance_valid(fallback),"missing popup asset retains the working transfer dialog"):return
	if not await _hit(fallback.cancel_button,"fallback cancellation"):return
	if not await _hit(_slot(storage,"bag",reference),"original inventory grid slot"):return
	if not await _answer(controller,"deposit",2,true):return
	check(world.warehouse.stacks.get(item,0)==0 and world.inventory.get(item,0)==initial and FileAccess.get_sha256(world.save_path())==disk,"cancelling preserves owned stock and disk bytes")
	if not await _hit(_slot(storage,"bag",reference),"retry the same owned stock"):return
	if not await _answer(controller,"deposit",3):return
	check(world.warehouse.stacks.get(item,0)==3 and world.inventory.get(item,0)==initial-3,"confirmation transfers exactly three units")
	var rows: Array=storage.rows("store").filter(func(row: Dictionary)->bool:return row.name==item)
	if not check(rows.size()==1 and rows[0].count==3 and not str(rows[0].instance_id).is_empty(),"warehouse shows the exact physical child stack"):return
	var stored: String=STORAGE.reference_of(rows[0])
	disk=FileAccess.get_sha256(world.save_path())
	if not await _hit(_slot(storage,"store",stored),"stored physical row"):return
	world.source_save_blocked=true
	var answered: bool=await _answer(controller,"withdraw",2)
	world.source_save_blocked=false
	if not answered:return
	check(world.warehouse.stacks.get(item,0)==3 and world.inventory.get(item,0)==initial-3 and FileAccess.get_sha256(world.save_path())==disk and not world.patch523_owner_state_problem.is_empty(),"failed save retains both sides and requires a trusted reload")
	world._load_game(true)
	await frames()
	check(world.patch523_owner_state_problem.is_empty(),"the trusted save clears the transfer protection")
	hud.open_warehouse()
	await frames()
	if not await _hit(_slot(storage,"store",stored),"retry after trusted reload"):return
	if not await _answer(controller,"withdraw",2):return
	check(world.warehouse.stacks.get(item,0)==1 and world.inventory.get(item,0)==initial-1,"withdrawal transfers exactly two units")
	world._load_game(true)
	await frames()
	check(world.warehouse.stacks.get(item,0)==1 and world.inventory.get(item,0)==initial-1,"both stock counts survive a second reload")
	# Loading may fold the bag portions together. The moved parent remains in
	# the live bag or in the verified merge journal of the replacement stack.
	var origin_kept: bool=world.item_instances.has(uid)
	for event: Dictionary in world.consumable_service.export_state().get(MERGE.MERGES,{}).values():
		for component: Dictionary in event.components:
			if component.physical_id==uid:origin_kept=true
	check(origin_kept,"the original physical parent's provenance survives the reload")
	evidence["viewport"]=str(root.size)
