extends "res://tests/quickslot_register523_main_test.gd"
## Run in a disposable profile with the installed original 523 definitions and UI.
const REVIEW=preload("res://scripts/ui/original_ui/source_main_awakening_review.gd")

func _source_button(node: Node, method: String, args: Array) -> Control:
	var source: Variant=node.get_meta("source_button",null) if node.has_meta("source_button") else null
	if is_instance_valid(source):
		var action: Callable=source._activation
		if action.is_valid() and str(action.get_method())==method and action.get_bound_arguments()==args and source._input_area.is_visible_in_tree():
			return source._input_area
	for child: Node in node.get_children():
		var found: Control=_source_button(child,method,args)
		if found!=null:return found
	return null

func _hit(button: Control, label: String) -> bool:
	var point: Vector2=center(button)
	if not check(root.get_visible_rect().has_point(point),"visible touch target: "+label):return false
	await tap(point)
	return true

func _confirm(hud: Node, cancel: bool=false) -> bool:
	var dialog: Node=hud.get_node_or_null("Root/TwilightConfirmation")
	if not check(is_instance_valid(dialog) and dialog.get_script()==REVIEW,"original common review opened"):return false
	for page: int in dialog._pages.size():
		if not await _hit(dialog.cancel_button if cancel else dialog.confirm_button,"review action"):return false
		if cancel:break
	return true

func run() -> void:
	root.size=Vector2i(2048,919) if "--wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	if not check(not FileAccess.file_exists("user://twilight_v20_save.json"),"disposable Main profile"):
		_finish()
		return
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer=-100000
	if check(QA.enter_game(world,"기사"),"normal Main entry"):
		await frames()
		var controller: Node=world.hud.original_main_ui_controller
		if check(is_instance_valid(controller),"pinned original Main UI mounted"):
			world.growth.state.points=100000
			world.inventory["수호석"]=30
			if check(world._save_game(true)==OK,"isolated growth fixture saved"):
				await _symbols(world,controller)
				await _guardians(world,controller)
				_check_name_font(world)
	world.hud._close_workspace()
	world.queue_free()
	await frames()
	_finish()

func _symbols(world: TwilightWorld, controller: Node) -> void:
	world.hud.open_growth("emblems")
	await frames()
	if not check(controller.feature_window_is_open("emblems"),"authored 문양 opens through HUD"):return
	var window: RefCounted=controller.feature_window("emblems")
	var growth: RefCounted=world.growth
	check(window._scene.get_node_or_null(window.ENHANCEMENT_MOTION)==null,"idle symbol does not mount its enhancement overlay")
	if not await _hit(_source_button(window._scene,"_ask",["enhance","eva",1]),"one enhancement"):return
	if not await _confirm(world.hud):return
	var first: Dictionary=growth.progress("eva")
	check(first.attempts==1 and first.spent==20,"one confirmation commits exactly one original-cost enhancement")
	var original_scene: Node2D=window._scene
	var motion: Node2D=original_scene.get_node_or_null(window.ENHANCEMENT_MOTION)
	var prompt: Node2D=original_scene.get_node_or_null(window.ENHANCEMENT_PROMPT)
	check(is_instance_valid(motion) and motion.source_member==window.ROOT and motion.playback_status().clip=="Fx_Start"
		and not window._clips.has("On"),"original center charge begins before any new part lights up")
	check(is_instance_valid(prompt) and prompt.source_member==window.REVEAL_TOUCH and prompt.playback_status().clip in ["Start","Loop"],
		"authored immediate-result prompt enters with the charge")
	window.refresh()
	check(window._scene==original_scene,"refresh preserves the scene playing the committed reveal")
	var disk: String=FileAccess.get_sha256(world.save_path())
	var rng_state: int=growth.rng.state
	await tap(root.get_visible_rect().size*Vector2(0.12,0.48))
	check(window._scene.get_node_or_null(window.ENHANCEMENT_MOTION)==null and window._scene.get_node_or_null(window.ENHANCEMENT_PROMPT)==null
		and window.last_result.filled.stage==first.stage,"an immediate touch during the charge reveals the committed stage")
	check(FileAccess.get_sha256(world.save_path())==disk and growth.progress("eva")==first and growth.rng.state==rng_state,"skip cannot roll or charge again")
	if not await _hit(_source_button(window._scene,"_ask",["enhance","eva",5]),"five enhancements"):return
	if not await _confirm(world.hud):return
	check(window._reveal_stages.size()==5,"all five committed stage steps wait for the charge")
	var committed_stage: int=growth.progress("eva").stage
	disk=FileAccess.get_sha256(world.save_path())
	rng_state=growth.rng.state
	var phases: Array[String]=[]
	var steps: Dictionary={}
	var visible_sphere: bool=false
	var visible_finish: bool=false
	var prompt_ends: bool=false
	# The source player uses process time. Software OpenGL in QA may advance
	# less process time than wall time, so bound both independently.
	var elapsed: float=0.0
	var deadline: int=Time.get_ticks_msec()+45000
	motion=window._scene.get_node_or_null(window.ENHANCEMENT_MOTION)
	prompt=window._scene.get_node_or_null(window.ENHANCEMENT_PROMPT)
	while not window._reveal_message.is_empty() and elapsed<9.0 and Time.get_ticks_msec()<deadline:
		if is_instance_valid(motion):
			var clip: String=motion.playback_status().clip
			if phases.is_empty() or phases.back()!=clip:phases.append(clip)
			if clip=="Fx_Start":visible_sphere=visible_sphere or _visible_sprite(motion,"Fx_Sphere")
			if clip=="Fx_Light" and window._clips.has("On"):steps[window._revealed_stage]=true
			if clip=="Fx_End":visible_finish=visible_finish or _visible_sprite(motion,"Sp_Glow_2")
		if is_instance_valid(prompt):prompt_ends=prompt_ends or prompt.playback_status().clip=="End"
		await process_frame
		elapsed+=world.get_process_delta_time()
	check(phases==["Fx_Start","Fx_Light","Fx_End"] and steps.size()==5,
		"the original charge, five flashes with On and finish: %s, steps %s, remaining %s, process seconds %.2f" % [phases,steps.keys(),window._reveal_stages,elapsed])
	check(visible_sphere and visible_finish and prompt_ends,"the source sphere, finish glow and prompt exit play visibly")
	check(window._reveal_message.is_empty() and growth.progress("eva").attempts==6 and window.last_result.filled.stage==committed_stage,"natural playback reveals the committed batch")
	check(FileAccess.get_sha256(world.save_path())==disk and growth.rng.state==rng_state,"natural playback neither saves nor rolls again")
	var settled: Dictionary=growth.state.duplicate(true)
	disk=FileAccess.get_sha256(world.save_path())
	if not await _hit(_source_button(window._scene,"_ask",["enhance","eva",1]),"an enhancement with a blocked save"):return
	world.source_save_blocked=true
	var confirmed: bool=await _confirm(world.hud)
	world.source_save_blocked=false
	if not confirmed:return
	check(window._reveal_message.is_empty() and window._scene.get_node_or_null(window.ENHANCEMENT_MOTION)==null
		and growth.state==settled and FileAccess.get_sha256(world.save_path())==disk,"save rejection starts no motion and spends nothing")
	world.hud._close_workspace()

func _visible_sprite(motion: Node2D, name: String) -> bool:
	var node: Node2D=motion.find_child(name,true,false)
	if not is_instance_valid(node) or not node.is_visible_in_tree():return false
	var sprite: Sprite2D=node.get_meta("source_sprite",null)
	var tint: Color=node.get_meta("source_display_color",Color.TRANSPARENT)
	return is_instance_valid(sprite) and sprite.texture!=null and tint.a>0.25

func _guardians(world: TwilightWorld, controller: Node) -> void:
	var growth: RefCounted=world.growth
	var offer: Dictionary={}
	var slot: String=""
	for group: Dictionary in growth.config.guardians:
		for row: Dictionary in group.nodes:
			if not growth.guardian_source.has_node(str(row.id)):continue
			offer=growth.quote("activate",str(row.id))
			if offer.ok:slot=str(row.id);break
		if not slot.is_empty():break
	if not check(not slot.is_empty() and growth.execute("activate",slot,1,int(offer.revision)).ok,"saved original guardian slot is pending"):return
	world.hud.open_growth("guardians")
	await frames()
	if not check(controller.feature_window_is_open("guardian_find"),"actual 수호성 menu resumes the saved choice"):return
	var window: RefCounted=controller.feature_window("guardian_find")
	check(window.last_result.filled.get("original_background",false),"original guardian backdrop is mounted behind the cards")
	var winner: int=int(growth.state.searches[slot].winner)
	var cost: int=int(growth.node(slot).cost)
	var stock: int=int(world.inventory["수호석"])
	var disk: String=FileAccess.get_sha256(world.save_path())
	if not await _hit(_source_button(window._scene,"_pick",[winner]),"original guardian card"):return
	if not await _confirm(world.hud,true):return
	check(window.stage=="pick" and FileAccess.get_sha256(world.save_path())==disk and int(world.inventory["수호석"])==stock,"cancel leaves pending cards and paid stock intact")
	if not await _hit(_source_button(window._scene,"_pick",[winner]),"select the same guardian card again"):return
	if not await _confirm(world.hud):return
	check(window.stage=="result" and window.won and int(world.inventory["수호석"])==stock-cost and growth.state.pending.is_empty(),"authored result shows the one paid success")
	var played: Node2D=window._project(window._scene,window._out,"SkillTree_RandomOpen_Layout")
	check(played!=null and played.playback_status().clip in ["Fx_Open_End_Success","Fx_Success_Loop"],"original reveal clip is playing")
	await tap(root.get_visible_rect().size*Vector2(0.2,0.65))
	check(controller.feature_window_is_open("guardians") and not window.is_open(),"result tap returns to the authored guardian tree")
	world.hud._close_workspace()
	world._load_game(true)
	check(growth.state.nodes.has(slot) and int(world.inventory["수호석"])==stock-cost,"reloading keeps the unlock and single payment")

func _check_name_font(world: TwilightWorld) -> void:
	var marker: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(marker)
	marker.set_physics_process(false)
	marker.world_controller=world
	marker.apply_original_name_font()
	var font: FontFile=world.hud.original_world_name_font()
	check(font!=null and font.has_char("몬".unicode_at(0)) and marker.name_label.get_theme_font("font")==font,"monster names use the verified Korean font from the installed pack")
	marker.queue_free()

func _finish() -> void:
	print("ORIGINAL_GROWTH_TOUCH_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
