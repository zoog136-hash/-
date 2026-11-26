extends SceneTree
## Real catalog -> authored option page -> reviewed transaction. Only ownership
## and random seeds are fixtures; the original UI, economy and save are not.
const QA=preload("res://tests/qa_class_selection.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
const CHANGE=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const OPTION=preload("res://scripts/ui/original_ui/source_main_option_awakening_window.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG=preload("res://scripts/lineagem_base508.gd")
var _checks: int=0
var _errors: Array[String]=[]
var _touch_usec: Array[int]=[]

func _initialize() -> void:run.call_deferred()

func check(value: bool, label: String) -> bool:
	_checks+=1
	if not value:_errors.append(label);printerr("SOURCE_OPTION_AWAKENING_FAIL: "+label)
	return value

func settle() -> void:
	for i: int in 3:await process_frame

func _pointer(p: Vector2, down: bool, index: int=41) -> void:
	var ev:=InputEventScreenTouch.new();ev.index=index;ev.position=p;ev.pressed=down
	root.push_input(ev,true)

func _point(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas()*(c.size*0.5)

func _tap(c: Control) -> bool:
	if not check(is_instance_valid(c) and c.is_visible_in_tree(),"authored touch target is visible"):return false
	var p: Vector2=_point(c)
	_pointer(p,true)
	await process_frame
	var started: int=Time.get_ticks_usec()
	_pointer(p,false)
	_touch_usec.append(Time.get_ticks_usec()-started)
	await settle()
	return true

func _hit(owner: Node2D) -> Control:
	if not is_instance_valid(owner):return null
	for meta: String in ["source_button","source_checkbox"]:
		if owner.has_meta(meta):return owner.get_meta(meta).get("_input_area") as Control
	return null

func _node(view: RefCounted, suffix: String) -> Node2D:
	var hit: Dictionary=OPTION._locate(view._scene,view._out,suffix)
	return hit.player.source_nodes.get(hit.offset) if hit.get("ok",false) else null

func _material(view: RefCounted, selected: bool, id: String) -> Control:
	var lists: Array=[OPTION.PICKED] if selected else [OPTION.RIGHT+"/ListView_1",OPTION.RIGHT+"/ListView_2",OPTION.RIGHT+"/ListView_3"]
	for suffix: String in lists:
		var list: Dictionary=view._list(view._scene,view._out,suffix)
		if not list.get("ok",false):continue
		for row: Node in list.content.get_children():
			if not row.has_meta("source_option_material") or row.get_meta("source_option_material").id!=id:continue
			for candidate: Node2D in row.source_nodes.values():
				if candidate.has_meta("source_checkbox"):return _hit(candidate)
	return null

func _finger_drag(c: Control) -> void:
	if not is_instance_valid(c):return
	var p: Vector2=_point(c)
	_pointer(p,true,43)
	var event:=InputEventScreenDrag.new();event.index=43;event.position=p+Vector2(8,38);event.relative=Vector2(8,38)
	root.push_input(event,true)
	await process_frame
	_pointer(event.position,false,43)
	await settle()

func _ledger(w: Node) -> Dictionary:
	return {"option":w.option_awakening.export_state(),"skill":w.skill_awakening.export_state(),
		"cards":w.card_draw_fusion.export_state(),"gold":w.gold,"rng":str(w.option_awakening.rng.state)}

func _seed(w: Node, category: String) -> Dictionary:
	var core: RefCounted=w.option_awakening.core
	for id: String in core.definitions.get(category,{}):
		var def: Dictionary=core.definitions[category][id]
		if def.grade!="영웅" or not core.native_eligibility(category,id).get("ok",false):continue
		w.card_draw_fusion.owned[category][id]=true
		var trial: Dictionary=w.option_awakening.view(category,id)
		for material_id: String in core.catalog[category]:
			var card: Dictionary=core.catalog[category][material_id]
			if material_id==id or not trial.get("material_experience",{}).has(card.get("grade")) or not core.native_material_available(card):continue
			w.card_draw_fusion.owned[category][material_id]=true
			w.card_draw_fusion.spare[category][material_id]=1000
			var snapshot: Dictionary=w.option_awakening.view(category,id)
			for material: Dictionary in snapshot.get("materials",[]):
				if material.id==material_id:
					return {"target":id,"material":material_id,"snapshot":snapshot,"need":ceili(float(snapshot.required_experience)/float(material.experience_per_card)),"unit_fee":int(material.get("cost_per_card",0))}
		w.card_draw_fusion.owned[category].erase(id)
	return {}

func _open(w: Node, category: String, id: String) -> RefCounted:
	var h: Node=w.hud
	h.open_catalog(category)
	await settle()
	var c: Node=h.original_main_ui_controller
	var change: RefCounted=c.get("_change_window")
	if change==null:
		print("SOURCE_OPTION_AWAKENING_CATALOG_DIAG ",h.original_main_ui_status)
	if not check(change!=null and change.is_open(),"original "+category+" catalog is mounted"):return null
	for row: Node in change._card_scenes.values():
		if row.get_meta("source_change_card",{}).get("id")!=id:continue
		for node: Node2D in row.source_nodes.values():
			if node.has_meta("source_checkbox") and change._selected!=id:await _tap(_hit(node))
		break
	if not check(change._selected==id,"catalog touch selected the exact "+category+" card"):return null
	await _tap(_hit(change._detail.source_nodes.get(CHANGE.AWAKEN)))
	if not h.source_option_awakening_is_open():print("SOURCE_OPTION_AWAKENING_OPEN_DIAG ",h.original_main_ui_status.get("option_awakening_window"))
	if not check(h.source_option_awakening_is_open() and not h.workspace.visible,"catalog 각성 opens the original option window, not the old form"):return null
	var view: RefCounted=c.feature_window("option_awakening")
	check(view._scene.source_member==OPTION.ROOT and view.last_result.filled.target_id==id and view.last_result.filled.category==category,
		"both categories mount the pinned common authored root with their exact target")
	check(_node(view,OPTION.LEVEL+"ProgressBar_Exp")!=null and _node(view,OPTION.PRIMARY)!=null and _node(view,"Nd_Content/Btn_Back")!=null,
		"original progress bar, primary action and Back are mounted")
	check(_node(view,"Change_Awaken_Skill")==null and not c.feature_window_is_open("card_awakening"),"option presentation does not mount skill awakening")
	var bonuses: Array=view._snapshot.get("bonus_options",[])
	var list: Dictionary=view._list(view._scene,view._out,OPTION.BONUS)
	if check(not bonuses.is_empty() and list.get("ok",false),"authoritative options have the original list"):
		var content: Node2D=list.content
		var first: Node2D=content.get_child(0)
		var label: Node2D=first.get_meta("source_text",null)
		check(label!=null and label.original_options.text==bonuses[0] and first.is_visible_in_tree()
			and first.position.x>=0.0 and first.position.x<=list.size.x
			and first.position.y>=-list.size.y and first.position.y<=0.0,
			"the first real option is in the visible clip, with its original font and exact text")
		check(content.get_child_count()==view.last_result.filled.options_shown and content.get_child_count()>=bonuses.size(),"the list contains all source option rows")
	return view

## Entry with the production pack selector, before any test catalog injection.
## The visual smoke can run on a UI/tables subset without a playable source map.
func _descriptor_smoke() -> void:
	var selector: Node=root.get_node("Source523Pack")
	if not check(selector.configured and SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"cold descriptor selects the pinned 523 definitions"):return
	root.size=Vector2i(2048,919)
	var w: Node=load("res://Main.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await settle()
	if not check(QA.enter_game(w),"Main admits the local test character after descriptor selection"):w.queue_free();return
	w.set_process(false)
	w.player.set_physics_process(false)
	w.field_population.set_process(false)
	w.save_timer=-100000
	for pair: Array in [["변신","source:m508:1:11152"],["마법인형","source:m508:2:40"]]:
		var category: String=pair[0]
		var id: String=pair[1]
		w.card_draw_fusion.owned[category][id]=true
		w._update_hud()
		var ledger_before: Dictionary=_ledger(w)
		var view: RefCounted=await _open(w,category,id)
		if view==null:break
		var list: Dictionary=view._list(view._scene,view._out,OPTION.BONUS)
		var content: Node2D=list.content
		var last: Node2D=content.get_child(-1)
		check(content.get_child_count()>6 and last.position.y>0.0,"later authored option rows are below the initial viewport")
		var start: Vector2=_node(view,OPTION.BONUS).get_global_transform_with_canvas()*Vector2(0.0,32.0)
		# In its authored anchor space, this touch stays in the ListView
		# even after the content itself starts moving.
		for swipe: int in 4:
			if last.position.y+content.position.y<=0.0:break
			_pointer(start,true,47)
			await process_frame
			var event:=InputEventScreenDrag.new()
			event.index=47
			event.position=start-Vector2(0,30)
			event.relative=Vector2(0,-30)
			root.push_input(event,true)
			await process_frame
			_pointer(event.position,false,47)
			await settle()
		var y: float=last.position.y+content.position.y
		check(content.position.y<0.0 and y<=0.0 and y>=-list.size.y,
			"actual touch scroll brings the %s last option into view (scroll %.1f, row %.1f)" % [category,content.position.y,y])
		check(_ledger(w)==ledger_before,"reading and scrolling options leaves the card ledger and RNG intact")
		await _tap(_hit(_node(view,"Nd_Content/Btn_Back")))
		var catalog: RefCounted=w.hud.original_main_ui_controller._change_window
		check(not catalog._show_selected().get("awakening_options",0),"unawakened detail has no applied awakening effects")
		# Exercise the real detail presenter with a committed-state fixture;
		# this descriptor smoke does not write progress over a missing map.
		var progress: Dictionary=w.option_awakening.core.card_progress(w.option_awakening.progress,category,id)
		progress.awakened=true
		w.option_awakening.progress.cards[category][id]=progress
		var detail: Dictionary=catalog._show_selected()
		var applied: Array=w.option_awakening.core.definition(category,id).applied_options
		check(not applied.is_empty() and detail.awakening_options==applied.size(),"owned awakened %s displays all applied source options in ordinary detail" % category)
		if category=="변신":
			await _tap(_hit(catalog._scene.source_nodes.get(CHANGE.MIX_OFF)))
			var setup: RefCounted=w.hud.original_main_ui_controller.feature_window("card_fusion")
			if check(setup!=null and setup.is_open() and w.hud.original_main_ui_status.get("card_fusion_window",{}).get("handled",false),"cold catalog Mix touch mounts native fusion setup"):
				var list_entry: Dictionary=setup._locate(setup._scene,setup._out,"Nd_CardMix/Nd_Card/ListView")
				var prompt: Node2D=_node(setup,"Nd_Card/Label_Message")
				check(list_entry.get("member")=="UI/Change/Change_DetailView_Mix.csb" and list_entry.get("offset")==5392
					and prompt!=null and prompt.is_visible_in_tree() and not setup.last_result.filled.can_fuse,
					"ordinary fusion has its original empty registration panel before a roll")
			w.hud._close_workspace()
	w.queue_free()
	await settle()

func _confirm(h: Node, cancel: bool) -> bool:
	var box: Node=h.get_node_or_null("Root/TwilightConfirmation")
	if not check(is_instance_valid(box),"durable action requires a review dialog"):return false
	return await _tap(box.cancel_button if cancel else box.confirm_button)

func _native() -> void:
	root.size=Vector2i(2048,919)
	var w: Node=load("res://Main.tscn").instantiate()
	root.add_child(w);current_scene=w;await settle()
	if not check(not FileAccess.file_exists(w.save_path()),"isolated save profile"):
		w.queue_free();return
	if not check(QA.enter_game(w),"actual Main enters gameplay"):w.queue_free();return
	w.set_process(false);w.player.set_physics_process(false);w.field_population.set_process(false);w.save_timer=-100000
	var archive: String=OS.get_environment("TWILIGHT_OPTION_AWAKENING_DEFINITIONS")
	if not check(not archive.is_empty(),"a pinned current-definition archive is required"):w.queue_free();return
	# Use the actual catalog producer in this focused Main test, after startup
	# so an artificially absent full original map pack is not called ready.
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	SOURCE.reset()
	w.catalog_db=CATALOG.apply_catalog(w.catalog_db)
	w.card_draw_fusion.configure(w.catalog_db)
	w.option_awakening.configure(w)
	w.skill_awakening=w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	w.hud.set_catalog_data(w.catalog_db,w.catalog_image_index)
	w.gold=100000000
	w.presentation_settings["reduced_motion"]=true
	var options: RefCounted=w.option_awakening
	check(options.problem.is_empty(),"authoritative option economy intact")
	var transform: Dictionary=_seed(w,"변신")
	var doll: Dictionary=_seed(w,"마법인형")
	if not check(not transform.is_empty() and not doll.is_empty(),"there are eligible transform and doll duplicates in the actual runtime"):
		print("SOURCE_OPTION_AWAKENING_OWNER_DIAG ",options.problem," / ",options.core.definitions.get("변신",{}).size(),"/",options.core.definitions.get("마법인형",{}).size()," / ",SOURCE.problem())
		w.queue_free();return
	w._update_hud()
	var base: Dictionary=_ledger(w)
	var view: RefCounted=await _open(w,"변신",transform.target)
	if view==null:w.queue_free();return
	var first_save: Error=w._save_game(false)
	if first_save!=OK:print("SOURCE_OPTION_SAVE_DIAG ",error_string(first_save)," ",w.hud.message_label.text,
		" skill=",w.skill_awakening.blocks_save()," option=",options.problem," source_save=",w.source_save_blocked)
	if not check(first_save==OK,"isolated real starting save"):w.queue_free();return
	var disk: String=FileAccess.get_sha256(w.save_path())
	await _finger_drag(_material(view,false,transform.material))
	check(view._selected.is_empty() and _ledger(w)==base,"drag across a material never registers or consumes")
	await _tap(_material(view,false,transform.material))
	check(view._selected.get(transform.material)==1 and _ledger(w)==base,"exact touch registers a duplicate without changing state")
	await _tap(_material(view,true,transform.material))
	check(view._selected.is_empty(),"touch on the original material strip unregisters exact card")
	await _tap(_hit(_node(view,OPTION.OUTSIDE+"Btn_Use_All")))
	check(view._selected.get(transform.material)==transform.need and _ledger(w)==base,"auto registers only necessary duplicates, without consuming")
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	await _confirm(w.hud,true)
	check(_ledger(w)==base and FileAccess.get_sha256(w.save_path())==disk,"cancel preserves the whole save")
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	w.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary) -> Error:return ERR_CANT_CREATE
	await _confirm(w.hud,false)
	check(_ledger(w)==base and FileAccess.get_sha256(w.save_path())==disk,"failed reviewed save preserves cards, gold, progress and RNG")
	w.equipment_collections.test_save_writer=Callable()
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	w.card_draw_fusion.spare["변신"][transform.material]=1
	var stale: Dictionary=_ledger(w)
	await _confirm(w.hud,false)
	check(_ledger(w)==stale and FileAccess.get_sha256(w.save_path())==disk,"review rejects a material count that changed even without a new awakening revision")
	w.card_draw_fusion.spare["변신"][transform.material]=1000
	w.hud.set_option_awakening_view(options.view("변신",transform.target))
	await _tap(_hit(_node(view,OPTION.OUTSIDE+"Btn_Use_All")))
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	await _confirm(w.hud,false)
	var now: Dictionary=options.view("변신",transform.target)
	if not check(now.experience==now.required_experience and now.can_awaken,"the same original button now enters a separate actual awakening"):
		w.queue_free();return
	check(w.card_draw_fusion.owned["변신"][transform.material] and w.card_draw_fusion.spare["변신"][transform.material]==1000-transform.need
		and w.gold==base.gold-transform.need*transform.unit_fee,"only reviewed duplicate material and exact fee consumed, first copy kept")
	check(w.skill_awakening.export_state()==base.skill,"option feed leaves skill awakening untouched")
	var quoted: Dictionary=_ledger(w)
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	await _confirm(w.hud,true)
	check(_ledger(w)==quoted,"the separate option attempt is also cancellable")
	var probe:=RandomNumberGenerator.new()
	var required_roll: float=float(now.success_chance_pct)*100.0
	for seed: int in range(1,1000):
		probe.seed=seed
		if probe.randi_range(0,9999)>=required_roll:options.rng.seed=seed;break
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	await _confirm(w.hud,false)
	var failed: Dictionary=options.view("변신",transform.target)
	check(failed.attempts==int(now.attempts)+1 and failed.failures==int(now.failures)+1 and
		failed.experience==now.failure_refund_experience and w.gold==quoted.gold-now.attempt_cost,"original UI delegates exact failure cost, preserved experience and counters")
	check(w.card_draw_fusion.export_state()==quoted.cards and w.skill_awakening.export_state()==quoted.skill,"attempt does not double-charge duplicates or modify skill state")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	check(saved.get("card_option_awakening",{}).get("cards",{}).get("변신",{}).has(transform.target),"committed exact card is on disk")
	var reveal: Node=w.hud.option_awakening_reveal
	if is_instance_valid(reveal):reveal.finished.emit()
	await settle()
	await _tap(_hit(_node(view,"Nd_Content/Btn_Back")))
	check(w.hud.active_section=="변신" and not w.hud.source_option_awakening_is_open(),"authored back returns to the same transform catalog")
	view=await _open(w,"마법인형",doll.target)
	if view!=null:
		check(view._selected.is_empty() and view._snapshot.category=="마법인형","no transform registration spills into doll")
		await _tap(_material(view,false,doll.material))
		check(view._selected.get(doll.material)==1 and not view._selected.has(transform.material),"doll selects its own exact duplicate")
		await _tap(_hit(_node(view,OPTION.OUTSIDE+"Btn_Cancel_All")))
		check(view._selected.is_empty(),"authored registration cancel drops only the doll's UI selection")
		var doll_before: Dictionary=_ledger(w)
		await _tap(_hit(_node(view,OPTION.OUTSIDE+"Btn_Use_All")))
		await _tap(_hit(_node(view,OPTION.PRIMARY)))
		await _confirm(w.hud,false)
		var doll_now: Dictionary=options.view("마법인형",doll.target)
		check(doll_now.experience==doll_now.required_experience and w.card_draw_fusion.owned["마법인형"][doll.material]
			and w.card_draw_fusion.spare["마법인형"][doll.material]==1000-doll.need
			and w.gold==doll_before.gold-doll.need*doll.unit_fee,"actual doll confirmation consumes its own duplicate quantity and fee only")
		check(options.view("변신",transform.target).experience==failed.experience and w.skill_awakening.export_state()==base.skill,
			"doll feed does not mutate the transform or skill lanes")
		var file: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
		check(file.get("card_option_awakening",{}).get("cards",{}).get("마법인형",{}).has(doll.target),"the exact doll card and XP are persisted")
		for seed: int in range(1,1000):
			probe.seed=seed
			if probe.randi_range(0,9999)<float(doll_now.success_chance_pct)*100.0:options.rng.seed=seed;break
		await _tap(_hit(_node(view,OPTION.PRIMARY)))
		await _confirm(w.hud,false)
		var success: Dictionary=options.view("마법인형",doll.target)
		check(success.awakened and success.attempts==int(doll_now.attempts)+1
			and success.failures==doll_now.failures and w.gold==int(doll_now.gold)-int(doll_now.attempt_cost),
			"actual doll option success charges only its separate attempt and updates the exact card")
		w._load_game(true)
		await settle()
		check(options.view("마법인형",doll.target).awakened and options.view("변신",transform.target).experience==failed.experience
			and w.skill_awakening.export_state()==base.skill,"real reload keeps actual independent option outcomes")
	w.queue_free()
	await settle()

func run() -> void:
	check(OPTION.PAGE_SIZE==9,"three authored original rows of three cards")
	if "--descriptor-smoke" in OS.get_cmdline_user_args():await _descriptor_smoke()
	elif not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty():await _native()
	print("SOURCE_OPTION_AWAKENING_RESULT ",JSON.stringify({"checks":_checks,"failures":_errors,"original_ui":not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"touch_release_usec":_touch_usec}))
	quit(0 if _errors.is_empty() else 1)
