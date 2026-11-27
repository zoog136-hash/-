extends "res://tests/quickslot_register523_main_test.gd"
## Real Main + original definitions and selected UI. Run in a fresh profile.
const WINDOW = preload("res://scripts/ui/original_ui/source_main_guardian_enchant_window.gd")

func run() -> void:
	root.size = Vector2i(2048,919) if "--wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	if not check(not FileAccess.file_exists("user://twilight_v20_save.json"),"disposable Main profile"):
		_finish()
		return
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -100000
	if check(QA.enter_game(world,"기사"),"normal Main startup"):
		await frames()
		var fixture: Dictionary = _owned_slot(world.growth)
		if check(not fixture.is_empty(),"original upgrade row present for an opened passive"):
			world.inventory["수호석"] = 100
			if check(world._save_game(true) == OK,"isolated guardian inventory saved"):
				await _test_upgrade(world, fixture)
	world.hud._close_workspace()
	world.queue_free()
	await frames()
	_finish()

func _owned_slot(runtime: RefCounted) -> Dictionary:
	for group: Dictionary in runtime.config.guardians:
		for row: Dictionary in group.nodes:
			var id: String = row.id
			if row.kind != "invoke" or runtime.guardian_source.upgrade(id,1).is_empty() or not runtime.guardian_source.availability(row).is_empty(): continue
			_unlock(runtime,id)
			return {"group":group.id,"id":id}
	return {}

func _unlock(runtime: RefCounted, id: String) -> void:
	if id in runtime.state.nodes: return
	for required: String in runtime.node(id).prerequisites: _unlock(runtime,required)
	runtime.state.nodes.append(id)

func _action(node: Node, method: String, args: Array = []) -> Control:
	if node.has_meta("source_button"):
		var button: Node = node.get_meta("source_button")
		var callback: Callable = button._activation
		if callback.is_valid() and callback.get_method() == method and callback.get_bound_arguments() == args and button._input_area.is_visible_in_tree():
			return button._input_area
	for child: Node in node.get_children():
		var match_button: Control = _action(child,method,args)
		if match_button != null: return match_button
	return null

func _hit(node: Node, method: String, args: Array = []) -> bool:
	var button: Control = _action(node,method,args)
	if not check(is_instance_valid(button) and root.get_visible_rect().has_point(center(button)),"visible touch target for "+method): return false
	await tap(center(button))
	return true

func _tap_slot_upgrade(hud: Node, controller: Node, fixture: Dictionary) -> bool:
	if not controller.feature_window_is_open("guardians"):
		hud.open_growth("guardians")
		await frames()
	if not check(controller.feature_window_is_open("guardians"),"original menu opens its tree"): return false
	var tree: RefCounted = controller.feature_window("guardians")
	if tree.selected != fixture.group and not await _hit(tree._scene,"_select",[fixture.group]): return false
	var scroll: Dictionary = tree._locate(tree._scene,tree._out,"ScrollView_SkillTree")
	var scroll_node: Node2D = scroll.player.source_nodes[scroll.offset]
	var origin: Node2D = scroll_node.get_node("SourceContentOrigin")
	var extent: Vector2 = tree._node_size(tree._out,"ScrollView_SkillTree")
	var transform: Transform2D = origin.get_global_transform_with_canvas()
	var right: Vector2 = transform*Vector2(extent.x*0.92,-extent.y*0.5)
	var left: Vector2 = transform*Vector2(extent.x*0.08,-extent.y*0.5)
	for attempt: int in range(3):
		if center(_action(tree._scene,"_slot_pressed",[fixture.id])).x < right.x: break
		await gesture(right,left,0.0)
	if not await _hit(tree._scene,"_slot_pressed",[fixture.id]): return false
	return await _hit(tree._scene,"_info_ok")

func _open_from_slot(hud: Node, controller: Node, fixture: Dictionary) -> RefCounted:
	if not await _tap_slot_upgrade(hud,controller,fixture): return null
	if not check(controller.feature_window_is_open("guardian_enchant") and not hud.workspace.visible,"opened slot action stays in the original enhancement scene"): return null
	var window: RefCounted = controller.feature_window("guardian_enchant")
	check(window._scene.source_member == WINDOW.ROOT and window.phase == WINDOW.Phase.PREVIEW,"original before/after preview is presented")
	return window

func _test_upgrade(world: TwilightWorld, fixture: Dictionary) -> void:
	var hud: Node = world.hud
	var runtime: RefCounted = world.growth
	var controller: Node = hud.original_main_ui_controller
	var id: String = fixture.id
	if not check(is_instance_valid(controller),"verified UI pack is active"): return
	var offer: Dictionary = runtime.quote("guardian_enchant",id)
	if not check(offer.get("ok",false),"real slot quote succeeds"): return
	var cost: int = int(offer.costs["수호석"])
	var chance: int = int(runtime.guardian_source.upgrade(id,1).Probability)
	var before: String = FileAccess.get_sha256(world.save_path())
	var revision: int = int(runtime.state.revision)
	var scenes: Dictionary = controller._pack.manifest.scenes
	var preview: Dictionary = scenes[WINDOW.ROOT]
	scenes.erase(WINDOW.ROOT)
	var touched_missing: bool = await _tap_slot_upgrade(hud,controller,fixture)
	scenes[WINDOW.ROOT] = preview
	check(touched_missing and not hud.workspace.visible and controller.feature_window_is_open("guardians") and not controller.feature_window_is_open("guardian_enchant"),"a pack missing the preview keeps the original tree without a substitute")
	check(FileAccess.get_sha256(world.save_path()) == before and world.inventory["수호석"]==100 and runtime.state.revision==revision,"a missing preview performs no debit, roll or save")
	hud._close_workspace()
	var window: RefCounted = await _open_from_slot(hud,controller,fixture)
	if window == null: return
	check(not window._preview_rows(0).is_empty() and window._preview_rows(0) != window._preview_rows(1),"preview uses both actual guardian effect records")
	if not await _hit(window._scene,"_begin"): return
	check(window.phase == WINDOW.Phase.CARD and FileAccess.get_sha256(world.save_path()) == before,"opening the original card does not roll or write")
	if not await _hit(window._scene,"_back"): return
	check(controller.feature_window_is_open("guardians") and FileAccess.get_sha256(world.save_path()) == before and int(runtime.state.revision) == revision,"authored exit preserves the exact saved bytes and revision")

	window = await _open_from_slot(hud,controller,fixture)
	if window == null or not await _hit(window._scene,"_begin"): return
	world.source_save_blocked = true
	var tapped: bool = await _hit(window._scene,"_commit")
	world.source_save_blocked = false
	if not tapped: return
	check(controller.feature_window_is_open("guardians") and runtime.guardian_level(id) == 0 and int(world.inventory["수호석"]) == 100 and FileAccess.get_sha256(world.save_path()) == before,"blocked save returns to the tree with balance and level preserved")

	for success: bool in [false,true]:
		window = await _open_from_slot(hud,controller,fixture)
		if window == null or not await _hit(window._scene,"_begin"): return
		runtime.rng.seed = _seed_for(chance,success)
		var stock: int = int(world.inventory["수호석"])
		if not await _hit(window._scene,"_commit"): return
		var stage: Dictionary = window.last_result.get("filled",{})
		check(stage.get("phase") == WINDOW.Phase.RESULT and stage.get("won") == success and runtime.guardian_level(id) == int(success),"saved roll determines the authored result card")
		check(int(world.inventory["수호석"]) == stock-cost,"one committed card debits exactly one source cost")
		var saved: String = FileAccess.get_sha256(world.save_path())
		var effect: Node2D = window._project(window._scene,window._out,"SkillTree_RandomOpen_Enchant_Layout")
		check(effect != null and effect.playback_status().clip == ("Fx_Open_End_Success" if success else "Fx_Open_End_Fail"),"matching original result clip started")
		var visible_parent: Dictionary = window._locate(window._scene,window._out,"SkillTree_RandomOpen_Enchant_Layout")
		check(visible_parent.player.source_nodes[visible_parent.offset].get_meta("source_rgba")[3] == 255,"authored result parent has finished its entry fade")
		check(not window._commit().get("ok",false) and FileAccess.get_sha256(world.save_path()) == saved,"repeating the card action cannot charge or write again")
		await tap(root.get_visible_rect().size*Vector2(0.25,0.40))
		check(controller.feature_window_is_open("guardians") and FileAccess.get_sha256(world.save_path()) == saved,"result touch returns without another debit or write")
	world._load_game(true)
	check(runtime.guardian_level(id) == 1 and int(world.inventory["수호석"]) == 100-2*cost,"reloading preserves the successful level and the two paid attempts")

func _seed_for(chance: int, success: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for seed: int in range(200):
		probe.seed = seed
		if (probe.randi_range(0,999999) < chance) == success: return seed
	return -1

func _finish() -> void:
	print("ORIGINAL_GUARDIAN_ENCHANT_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
