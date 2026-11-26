extends "res://tests/source_catalog_stack_bag_test.gd"
## Fresh process, disposable profile and the same original box in its historic
## balance and physical UID forms. Report CPU dispatch and the actual frame
## completion separately. Wall-clock values depend on GPU, driver and load.

func timed_selection(world: Node, ref: String, sample: String) -> void:
	var hit: Dictionary = await slot(world,ref)
	if not check(not hit.is_empty(),"visible slot for "+sample): return
	var bag: Node = world.hud.lineage_inventory_ui
	var control: Control = hit.control
	var point := control.get_global_transform_with_canvas() * (control.size/2)
	var dispatch_us: Array[int] = []
	var start := Time.get_ticks_usec()
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.position=point
		event.index=13
		event.pressed=pressed
		var sample_start := Time.get_ticks_usec()
		root.push_input(event,true)
		dispatch_us.append(Time.get_ticks_usec()-sample_start)
		if pressed: await process_frame
	var released := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var painted := Time.get_ticks_usec()
	check(bag.item_action_label(ref)=="사용","action visible for "+sample)
	print("CATALOG_STACK_TIMING ",JSON.stringify({"sample":sample,"press_us":dispatch_us[0],"release_us":dispatch_us[1],"dispatch_us":dispatch_us[0]+dispatch_us[1],"touch_to_paint_us":painted-start,"release_to_paint_us":painted-released}))
	bag.disarm_item_action()
	await frames()

func run() -> void:
	if OS.get_environment("TWILIGHT_CATALOG_STACK_BAG")!="1": quit(2); return
	root.size=Vector2i(2048,919)
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	if not check(QA.enter_game(world),"normal installed Main entry"): quit(1); return
	await frames()
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer=-100000
	var key: String = LABELS.original_name(6161)
	world.inventory[key]=2
	check(SUPPLY.commit(world,[{"item_class_id":6161,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"catalog_stack_timing"}),"issue the original control and save both balances")
	world._load_game(true)
	await frames()
	await open_bag(world)
	var uid_ref := ""
	for row: Dictionary in world.hud.lineage_inventory_ui._inventory_entries():
		if world.item_instances.get(str(row.reference).get_slice("@@@",1),{}).get("record",{}).get("source_item_class_id")==6161: uid_ref=row.reference
	check(CATALOG_STACK._name_generation<0 and world.inventory.get(key)==2,"first selection starts cold with saved catalog balance")
	if check(not uid_ref.is_empty(),"same original box has a physical control"):
		if "--physical-first" in OS.get_cmdline_user_args():
			await timed_selection(world,uid_ref,"physical_first")
			check(CATALOG_STACK._name_generation<0,"physical selection needs no legacy stock metadata")
			await timed_selection(world,key,"legacy_first")
		else:
			await timed_selection(world,key,"legacy_first")
			await timed_selection(world,uid_ref,"physical")
	for i: int in 3: await timed_selection(world,key,"legacy_repeat_"+str(i+1))
	world.queue_free()
	await frames()
	print("CATALOG_STACK_TIMING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
