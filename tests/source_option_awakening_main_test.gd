extends SceneTree
## Real catalog -> authored option page -> reviewed transaction. Only ownership
## and random seeds are fixtures; the original UI, economy and save are not.
const QA=preload("res://tests/qa_class_selection.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
const CHANGE=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const OPTION=preload("res://scripts/ui/original_ui/source_main_option_awakening_window.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG=preload("res://scripts/lineagem_base508.gd")
const GRADE_FX=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
var _checks: int=0
var _errors: Array[String]=[]
var _touch_usec: Array[int]=[]
var _attempt_confirm_usec: Dictionary={}

func _initialize() -> void:
	var assets := preload("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
	check(assets.read_installed("user://missing-awakening-scene") == null,"absent local originals cannot mount the result")
	run.call_deferred()

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

func _choose_catalog_card(w: Node, category: String, id: String) -> RefCounted:
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
	return change

func _catalog_option_text(row: Node2D, offset: int) -> String:
	var widget: Node2D=row.source_nodes.get(offset)
	if widget==null or not widget.is_visible_in_tree():return ""
	var label: Node=widget.get_meta("source_text",null)
	return str(label.original_options.text) if label!=null else ""

func _catalog_option_lines(change: RefCounted) -> Array[String]:
	var lines: Array[String]=[]
	for row: Node2D in change._option_content.get_children():
		var description: String=_catalog_option_text(row,CHANGE.OPTION_DESC)
		var value: String=_catalog_option_text(row,CHANGE.OPTION_VALUE)
		lines.append((description+" "+value).strip_edges())
	return lines

func _open(w: Node, category: String, id: String) -> RefCounted:
	var change: RefCounted=await _choose_catalog_card(w,category,id)
	if change==null:return null
	var awakening: Dictionary=w.option_awakening.card_options(category,id)
	var preview: Array=awakening.get("preview",[])
	if not awakening.get("awakened",false) and not preview.is_empty():
		var shown: Array[String]=_catalog_option_lines(change)
		check(shown.has("각성 시 추가 능력") and preview.all(func(effect: String) -> bool: return shown.has(effect)),
			"the mounted catalog displays the localized source preview for "+category)
	var h: Node=w.hud
	var c: Node=h.original_main_ui_controller
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
		var first: Node2D=content.get_child(1)
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
		var preview: Dictionary=catalog._show_selected()
		check(not preview.get("awakened",true) and preview.get("awakening_options",0)>0,"unawakened detail displays the source preview")
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
	if not cancel and box.get_script() == preload("res://scripts/ui/original_ui/source_main_awakening_review.gd"):
		var before: Dictionary = _ledger(h.get_parent())
		while box._page + 1 < box._pages.size():
			var previous: int = box._page
			await _tap(box.confirm_button)
			if not check(is_instance_valid(box) and box._page == previous+1 and _ledger(h.get_parent()) == before, "next review page keeps the transaction uncommitted"): return false
	return await _tap(box.cancel_button if cancel else box.confirm_button)

func _read_result(w: Node, success: bool) -> void:
	if not w.hud.source_awakening_result_is_open():
		if OS.get_environment("TWILIGHT_EXPECT_AWAKEN_RESULT") == "1":
			check(false, "original result scene should be mounted for " + ("success" if success else "failure") + " " + str(w.hud.original_main_ui_status.get("awakening_result_window", {})))
		var fallback: Node = w.hud.option_awakening_reveal
		if is_instance_valid(fallback): fallback.finished.emit()
		await settle()
		return
	var page: RefCounted = w.hud.original_main_ui_controller.feature_window("awakening_result")
	var disk: String = FileAccess.get_sha256(w.save_path())
	var before: Dictionary = _ledger(w)
	var scene: Node2D = page._scene
	var branch: String = "Success" if success else "Fail"
	var target: Sprite2D = scene.get_node_or_null("AwakeningTargetPortrait") as Sprite2D
	var framed: Sprite2D = scene.get_node_or_null("AwakeningTargetCard") as Sprite2D
	if OS.get_environment("TWILIGHT_EXPECT_AWAKEN_PORTRAIT") == "1":
		check(target!=null and target.texture!=null and target.get_meta("source_card_id","")==CARDS.card_id(page._card),"the installed portrait belongs to the exact awakening target")
		check(framed!=null and framed.is_visible_in_tree() and framed.position==Vector2.ZERO,"the card is centered while waiting for the reveal touch")
	check(scene.source_member == "UI/Change/Change_Upgrade_Skill_Awaken.csb" and page.phase().waiting and not _node(page, branch+"_Text").is_visible_in_tree(), "saved result opens on the original touch prompt (no outcome yet)")
	# One touch reveals the committed outcome (the next one closes it).
	await _tap(scene.get_node("AwakeningResultTouch"))
	check(page.phase().revealed and (page._steady or scene.playback_status().clip == "Fx_Touch_Active"), "the touch starts the original reveal")
	await RenderingServer.frame_post_draw
	if not page._steady:
		# A late frame can span each clip. Exercise the real player and the
		# registered transition to the held result, with no wall-clock sleep.
		for step: int in range(4):
			scene._process(20.0)
			await process_frame
	var label: Node2D = _node(page, branch+"_Text")
	check(page._held and is_instance_valid(label) and label.is_visible_in_tree() and label.get_meta("source_display_color").a > 0.99, "original outcome text settles at full authored opacity")
	if target!=null:
		check(target.is_visible_in_tree() and target.modulate.a>0.99 and absf(target.position.x)<1.0,"the same target stays visible at the center after success or failure")
	if OS.get_environment("TWILIGHT_EXPECT_AWAKEN_PORTRAIT") == "1":
		var original: Texture2D = GRADE_FX.card_frame(page._card_pack,str(page._card.grade))
		check(framed!=null and original!=null and framed.texture==original and framed.is_visible_in_tree()
			and framed.position==Vector2.ZERO and framed.get_meta("source_card_id","")==CARDS.card_id(page._card),"the exact target's original card frame remains centered on both outcomes")
		if framed!=null and target!=null:
			check(target.position==framed.position and framed.z_index<target.z_index
				and (target.texture.get_size()*target.scale).y<(framed.texture.get_size()*framed.scale).y,"the selected artwork fits above its own grade card frame")
			if DisplayServer.get_name()!="headless":await _check_center_card_pixels(framed)
	if not page._options.is_empty():
		var template: Node = _node(page, "ListView/Label_Option").get_meta("source_text")
		check(template.get_child_count()>0, "awarded options are drawn in the original list")
	check(w.hud.is_option_awakening_busy() and not is_instance_valid(w.hud.option_awakening_reveal), "original result covers the form")
	var blocker: Control = scene.get_node("AwakeningResultTouch")
	await _tap(blocker)
	check(not page.is_open() and _ledger(w) == before and FileAccess.get_sha256(w.save_path()) == disk, "acknowledgement returns to the form without a second debit or roll")

func _check_center_card_pixels(frame: Sprite2D) -> void:
	paused=true
	var viewport := frame.get_viewport()
	await RenderingServer.frame_post_draw
	var shown := viewport.get_texture().get_image()
	frame.hide()
	await RenderingServer.frame_post_draw
	var hidden := viewport.get_texture().get_image()
	frame.show()
	paused=false
	var bounds: Rect2 = frame.get_global_transform_with_canvas()*frame.get_rect()
	var area: Rect2i = Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO,shown.get_size()))
	var changed: int=0
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			if shown.get_pixel(x,y)!=hidden.get_pixel(x,y):changed+=1
	check(changed>100,"the original grade frame contributes rendered pixels at the center of the outcome")
	print("AWAKENING_CENTER_CARD_PIXELS ",changed)

func _paid_skill(w: Node) -> void:
	var runtime: RefCounted = w.skill_awakening
	w.presentation_settings["reduced_motion"] = false
	w.presentation_settings["impact_intensity"] = 1.0
	var identity: String = ""
	for id: String in runtime.core.cards:
		if runtime.core.cards[id].category == "변신" and runtime.core.eligibility(id).ok and not runtime.core.book_requirement(id).is_empty():
			identity = id
			break
	if not check(not identity.is_empty(), "original eligible skill target"): return
	w.card_draw_fusion.owned["변신"][identity] = true
	w.gold = 100000000
	var required: Dictionary = runtime.core.book_requirement(identity)
	var received: bool = preload("res://scripts/loot/patch523_item_inventory.gd").commit(w,
		[{"item_class_id":required.item_class_id, "amount":2, "bless_raw":1, "enchant":0}], {"kind":"skill_result_regression"})
	if not check(received, "two verified skill awakening books supplied"): return
	w.hud.open_card_skill_awakening("변신", identity)
	await settle()
	var controller: Node = w.hud.original_main_ui_controller
	if not check(controller.feature_window_is_open("card_awakening"), "registered original skill page opens"): return
	var page: RefCounted = controller.feature_window("card_awakening")
	var cost_before: int = w.gold
	var revision: int = runtime.progress.revision
	var price: Node2D = _node(page, page.P+"Btn_Production/Text_Price")
	check(is_instance_valid(price) and price.get_meta("source_text").original_options.text == OPTION._number(int(required.fee)),
		"original skill button shows the fee before the transaction")
	await _tap(_hit(_node(page, page.P+"Btn_Production")))
	var review: Node = w.hud.get_node_or_null("Root/TwilightConfirmation")
	check(is_instance_valid(review) and review.get_script() == preload("res://scripts/ui/original_ui/source_main_awakening_review.gd"),
		"original two-button confirmation displays skill materials and fee")
	check(not runtime.request_operation(identity).ok and w.gold == cost_before, "an open review alone cannot consume a skill book")
	await _confirm(w.hud, true)
	check(w.gold == cost_before and runtime.progress.revision == revision, "cancelling the skill review preserves book and fee")
	await _tap(_hit(_node(page, page.P+"Btn_Production")))
	await _confirm(w.hud, false)
	check(w.gold == cost_before - int(required.fee) and runtime.progress.revision == revision+1
		and int(runtime.progress.cards.get(identity, {}).get("spell_id",0)) > 0, "original input commits exactly one paid skill selection")
	check(not runtime.request_operation(identity).ok and runtime.progress.revision == revision+1, "result overlay prevents a duplicate charge")
	await _read_result(w, true)
	var saved: Dictionary = runtime.export_state()
	w._load_game(true)
	await settle()
	check(runtime.export_state() == saved and w.gold == cost_before - int(required.fee), "committed skill, cost and revision survive reload")

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
	# This test mounts the definitions after startup. Register the proven book
	# supply in the same order as the World's normal catalog initialization.
	preload("res://scripts/cards/native_awakening_supply.gd").install_current_definitions(w.catalog_db)
	w._index_catalog_item_sources()
	w.card_draw_fusion.configure(w.catalog_db)
	w.option_awakening.configure(w)
	w.skill_awakening=w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	w.hud.set_catalog_data(w.catalog_db,w.catalog_image_index)
	w.gold=100000000
	w.presentation_settings["reduced_motion"]=true
	var options: RefCounted=w.option_awakening
	check(options.problem.is_empty(),"authoritative option economy intact")
	var transform_preview: Dictionary=options.card_options("변신","source:m508:1:11152")
	check(transform_preview.get("preview",[]).has("공격 속도 +15%") and transform_preview.get("preview",[]).has("힘(STR) +2")
		and transform_preview.get("applied",[]).is_empty(),"source transform preview uses the Korean BonusType label and original units")
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
	w.presentation_settings["reduced_motion"]=false
	var attempt_form: Node2D=view._scene
	await _tap(_hit(_node(view,OPTION.PRIMARY)))
	await _confirm(w.hud,false)
	_attempt_confirm_usec["변신"]=_touch_usec.back()
	var failed: Dictionary=options.view("변신",transform.target)
	check(view._scene==attempt_form and view._snapshot.experience==failed.experience and view._can_register(),"failed attempt updates the original mounted form and restores eligible material input")
	check(failed.attempts==int(now.attempts)+1 and failed.failures==int(now.failures)+1 and
		failed.experience==now.failure_refund_experience and w.gold==quoted.gold-now.attempt_cost,"original UI delegates exact failure cost, preserved experience and counters")
	check(w.card_draw_fusion.export_state()==quoted.cards and w.skill_awakening.export_state()==quoted.skill,"attempt does not double-charge duplicates or modify skill state")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	check(saved.get("card_option_awakening",{}).get("cards",{}).get("변신",{}).has(transform.target),"committed exact card is on disk")
	await _read_result(w, false)
	w.presentation_settings["reduced_motion"]=true
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
		var doll_form: Node2D=view._scene
		await _tap(_hit(_node(view,OPTION.PRIMARY)))
		await _confirm(w.hud,false)
		_attempt_confirm_usec["마법인형"]=_touch_usec.back()
		var success: Dictionary=options.view("마법인형",doll.target)
		check(view._scene==doll_form and view._snapshot.awakened and not view._can_submit(),"successful attempt keeps the existing original materials and disables submission")
		var bonus_list: Dictionary=view._list(view._scene,view._out,OPTION.BONUS)
		if check(bonus_list.get("ok",false) and bonus_list.content.get_child_count()>1 and not success.applied_options.is_empty(),"mounted form displays applied option rows after success"):
			var heading: Node=bonus_list.content.get_child(0).get_meta("source_text",null)
			var effect: Node=bonus_list.content.get_child(1).get_meta("source_text",null)
			check(heading!=null and effect!=null and heading.original_options.text=="각성 적용 효과"
				and effect.original_options.text==success.applied_options[0],"reused form replaces the preview with the committed source option")
		check(success.awakened and success.attempts==int(doll_now.attempts)+1
			and success.failures==doll_now.failures and w.gold==int(doll_now.gold)-int(doll_now.attempt_cost),
			"actual doll option success charges only its separate attempt and updates the exact card")
		await _read_result(w, true)
		w._load_game(true)
		await settle()
		check(options.view("마법인형",doll.target).awakened and options.view("변신",transform.target).experience==failed.experience
			and w.skill_awakening.export_state()==base.skill,"real reload keeps actual independent option outcomes")
	var relic: Dictionary = _seed(w,"성물")
	if check(not relic.is_empty(),"eligible installed relic and its own material"):
		w._update_hud()
		var before_relic: Dictionary = _ledger(w)
		var relic_page: RefCounted = await _open(w,"성물",str(relic.target))
		if relic_page != null:
			await _tap(_material(relic_page,false,str(relic.material)))
			await _tap(_hit(_node(relic_page,OPTION.PRIMARY)))
			check(relic_page.review_open(),"relic opens the authored confirmation")
			relic_page.cancel_review()
			check(_ledger(w)==before_relic,"review and cancel preserve relic, materials, fee and RNG")
			await _tap(_hit(_node(relic_page,OPTION.OUTSIDE+"Btn_Use_All")))
			await _tap(_hit(_node(relic_page,OPTION.PRIMARY)))
			await _confirm(w.hud,false)
			var supplied: Dictionary = options.view("성물",relic.target)
			check(supplied.experience==supplied.required_experience and w.card_draw_fusion.spare["성물"][relic.material]==1000-relic.need,"original relic page pays the chosen duplicates")
			for seed: int in range(1,1000):
				probe.seed=seed
				if probe.randi_range(0,9999)<float(supplied.success_chance_pct)*100.0: options.rng.seed=seed; break
			var relic_form: Node2D=relic_page._scene
			await _tap(_hit(_node(relic_page,OPTION.PRIMARY)))
			await _confirm(w.hud,false)
			_attempt_confirm_usec["성물"]=_touch_usec.back()
			check(options.view("성물",relic.target).awakened,"confirmed relic awakens with its installed rule")
			check(relic_page._scene==relic_form and relic_page._snapshot.awakened,"relic attempt also keeps its mounted option rows")
			await _read_result(w,true)
			var relic_effects: Dictionary=options.card_options("성물",str(relic.target))
			check(relic_effects.awakened and not relic_effects.applied.is_empty(),"awakened relic exposes its applied options to the card encyclopedia")
			var history: Dictionary = relic_page._history()
			check(history.get("ok",false),"native history accepts the relic awakening tab")
			var change: RefCounted=await _choose_catalog_card(w,"성물",str(relic.target))
			if change!=null:
				var catalog_result: Dictionary=change._show_selected()
				var shown: Array[String]=_catalog_option_lines(change)
				check(catalog_result.get("awakened",false) and catalog_result.awakening_options==relic_effects.applied.size()
					and shown.has("각성 적용 효과") and relic_effects.applied.all(func(effect: String) -> bool: return shown.has(effect)),
					"the mounted catalog displays every applied relic option under the committed heading")
	if OS.get_environment("TWILIGHT_EXPECT_AWAKEN_RESULT") == "1": await _paid_skill(w)
	w.queue_free()
	await settle()

func run() -> void:
	check(OPTION.PAGE_SIZE==9,"three authored original rows of three cards")
	if "--descriptor-smoke" in OS.get_cmdline_user_args():await _descriptor_smoke()
	elif not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty():await _native()
	print("SOURCE_OPTION_AWAKENING_RESULT ",JSON.stringify({"checks":_checks,"failures":_errors,"original_ui":not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"touch_release_usec":_touch_usec,"attempt_confirm_usec":_attempt_confirm_usec}))
	quit(0 if _errors.is_empty() else 1)
