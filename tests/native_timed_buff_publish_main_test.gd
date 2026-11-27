extends SceneTree
## Exact, independently staged original timed buff use from the phone UI
## after a durable commit. With no private archive, leave the live case off.
const QA=preload("res://tests/qa_class_selection.gd")
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const LAYOUT=preload("res://scripts/ui/reference_layout.gd")
const ITEMS:Dictionary={380:[40,300],335:[41,300],887:[237,600]}
var checks:int=0
var failures:Array[String]=[]
var trips:int=0
var rejected:Dictionary={}

func _initialize()->void:run.call_deferred()

func ck(value:bool,message:String)->bool:
	checks+=1
	if not value:failures.append(message);printerr("NATIVE_TIMED_BUFF_PUBLISH_FAIL ",message)
	return value

func run()->void:
	ck(ITEMS.size()==3,"fixture separates original first-, second- and third-stage buffs")
	var archive:String=OS.get_environment("TWILIGHT_TIMED_BUFF_MAIN_DEFINITIONS")
	if not archive.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated real save"):
		await live(archive)
		ck(trips==6,"three original physical buffs through both real touch entry points")
	print("NATIVE_TIMED_BUFF_PUBLISH_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"trips":trips}))
	quit(0 if failures.is_empty() else 1)

func tap(control:Control)->void:
	for down:bool in [true,false]:
		var e:=InputEventScreenTouch.new()
		e.index=14;e.pressed=down;e.position=control.get_global_transform_with_canvas()*(control.size*.5)
		root.push_input(e,true)

func deny(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE

func authored_bag_slot(view: RefCounted, reference: String) -> Control:
	var control: Control=view._hits.get(reference,{}).get("control")
	if is_instance_valid(control) and view._inside_scroll_view(control.get_global_transform_with_canvas()*(control.size*0.5)):
		return control
	for index: int in view._lines.size():
		if not view._lines[index].values().has(reference):continue
		var position: float=-view._row_y-view.ROW_PITCH*(index+1)-view._view_height()*0.5
		var scale: float=absf(view._scroll_content.get_global_transform_with_canvas().get_scale().y)
		view.scroll_by((position-view._scroll_content.position.y)*scale)
		break
	return view._hits.get(reference,{}).get("control")

func live(archive:String)->void:
	root.size=Vector2i(2048,919)
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	if not ck(QA.enter_game(w),"actual Main enters as 기사"):w.queue_free();return
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"private original definitions SHA matches")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var h:Node=w.hud
	var request:Array=[]
	for id:int in ITEMS:
		var record:Dictionary=w.source_item_definition(id).get("native_record",{})
		if not ck(not record.is_empty(),"original live definition #"+str(id)):w.queue_free();return
		w.catalog_db["아이템"].append(record)
		request.append({"item_class_id":id,"amount":4,"bless_raw":1,"enchant":0})
	w._index_catalog_item_sources()
	var staged:Dictionary=INV.stage(w,request,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(staged.get("ok",false) and w._save_game(true,staged.get("overrides",{}))==OK,"original three exact grants and initial save"):w.queue_free();return
	w.inventory=staged.overrides.inventory;w.item_instances=staged.overrides.item_instances
	var names:Dictionary={};var uids:Dictionary={}
	for uid:String in w.item_instances:
		var entry:Dictionary=w.item_instances[uid]
		var id:int=int(entry.get("record",{}).get("source_item_class_id",0))
		if ITEMS.has(id):names[id]=str(entry.name);uids[id]=uid
	if not ck(names.size()==ITEMS.size(),"all three exact physical IDs issued"):w.queue_free();return
	w._update_hud();h.refresh_inventory(w.inventory)
	for route:String in ["bag","quickslot"]:
		for id:int in ITEMS:
			var name:String=names[id]
			w.item_use_cooldowns.clear()
			var ref:String=name+"@@@"+str(uids[id])
			var control:Control
			if route=="bag":
				if not h.original_inventory_is_open():h.toggle_inventory();await process_frame
				control=authored_bag_slot(h.original_main_ui_controller._inventory_view,ref)
				if not ck(is_instance_valid(control),"actual original bag slot #"+str(id)):w.queue_free();return
				h.lineage_inventory_ui.disarm_item_action()
				h.pointer_transfer.reset_tap_history()
				tap(control)
				ck(h.lineage_inventory_ui.item_action_label(ref)=="사용","first touch arms existing action")
			else:
				if h.original_inventory_is_open():h.toggle_inventory();await process_frame
				w.quickslots[h.quickslot_index(0)]={"kind":"item","id":name};w._update_hud()
				control=h.original_quickslot_control(0)
				if not ck(is_instance_valid(control),"actual original quickslot #"+str(id)):w.queue_free();return
			var old_hash:String=FileAccess.get_sha256(w.save_path())
			var left:int=int(w.inventory[name]);var speed:int=w.hud_publish_counts.speed_refreshes
			var stock:Dictionary=w.item_instances.duplicate(true)
			var cards:Dictionary=w.card_draw_fusion.export_state()
			var awake:Dictionary=w.option_awakening.export_state()
			var look:Dictionary=w.equipped_catalog.duplicate(true)
			var ui_cards:Dictionary=h.card_collection_state.duplicate(true)
			var journals: Dictionary=w.consumable_service.export_state()
			tap(control)
			var committed_journals: Dictionary=w.consumable_service.export_state()
			var prior_uses: Dictionary=journals.get(STACK.USES,{})
			var committed_uses: Dictionary=committed_journals.get(STACK.USES,{})
			prior_uses.erase(uids[id])
			committed_uses.erase(uids[id])
			journals.erase(STACK.USES)
			committed_journals.erase(STACK.USES)
			ck(journals==committed_journals and prior_uses==committed_uses,"only the selected use ledger row changes")
			var buff:Dictionary={}
			for effect:Dictionary in w.active_item_buffs.values():
				if effect.get("source_item_class_id")==id:buff=effect;break
			ck(w.inventory[name]==left-1 and STACK.proof(w,uids[id]).get("remaining")==left-1 and FileAccess.get_sha256(w.save_path())!=old_hash,"physical debit and durable commit in the same gesture")
			ck(buff.get("source_buff_class",{}).get("ID")==ITEMS[id][0] and buff.get("duration")==ITEMS[id][1] and w.item_use_cooldowns.has(name),"exact original effect, duration and cooldown")
			ck(w.hud_publish_counts.speed_refreshes-speed==1 and is_equal_approx(w.player.equipment_move_speed_multiplier,w._effective_move_speed_multiplier()),"one synchronous live speed update")
			ck(w.card_draw_fusion.export_state()==cards and w.option_awakening.export_state()==awake and w.equipped_catalog==look and h.card_collection_state==ui_cards,"card, awakening, transformation and displayed card state unchanged")
			ck(h.lineage_inventory_ui.inventory[name]==left-1 and h.lineage_inventory_ui.character_state.item_instances[uids[id]]==w.item_instances[uids[id]] and h.lineage_inventory_ui._state_publish_depth==0,"bag received the correct paired count and physical state")
			if route=="bag":ck(h.lineage_inventory_ui.selected_item==ref,"actual bag selection remains on the same exact physical ID")
			for other:int in ITEMS:
				if other!=id:ck(w.item_instances[uids[other]]==stock[uids[other]],"unrelated physical receipt/card ownership unchanged")
			if route=="quickslot":
				var hash_after:String=FileAccess.get_sha256(w.save_path())
				tap(control)
				ck(w.inventory[name]==left-1 and FileAccess.get_sha256(w.save_path())==hash_after,"real second touch while cooling does not debit or write")
			trips+=1
	var hash_before:String=FileAccess.get_sha256(w.save_path())
	var stock_before:Dictionary=w.item_instances.duplicate(true)
	var buffs_before:Dictionary=w.active_item_buffs.duplicate(true)
	var rng:int=w.rng.state
	w.item_use_cooldowns.clear()
	w.equipment_collections.test_save_writer=deny
	w._on_inventory_item_activated(str(names[380])+"@@@"+str(uids[380]))
	ck(not rejected.is_empty() and w.item_instances==stock_before and w.active_item_buffs==buffs_before and w.rng.state==rng and FileAccess.get_sha256(w.save_path())==hash_before,"refused real writer leaves both debit and effect unpublished")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true)
	ck(w.inventory[names[380]]==2 and w.inventory[names[335]]==2 and w.inventory[names[887]]==2,"real reload preserves all six successful debits and none from rejected writes")
	await auto_refresh(w,str(names[380]),str(uids[380]))
	w.queue_free();await process_frame

func pull(control: Control, direction: float) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	var offset:=Vector2(0,direction*(LAYOUT.AUTO_PULL_DISTANCE+2.0))
	var touch:=InputEventScreenTouch.new()
	touch.index=14;touch.position=point;touch.pressed=true
	root.push_input(touch,true)
	await process_frame
	var drag:=InputEventScreenDrag.new()
	drag.index=14;drag.position=point+offset;drag.relative=offset
	root.push_input(drag,true)
	await process_frame
	touch.position=point+offset;touch.pressed=false
	root.push_input(touch,true)
	await process_frame

func auto_refresh(w: Node, item: String, uid: String) -> void:
	var h: Node=w.hud
	if h.original_inventory_is_open():h.toggle_inventory();await process_frame
	w.self_mode_enabled=false
	for entry: Dictionary in w.quickslots:
		if not entry.is_empty():entry["auto"]=false
	w.item_use_cooldowns.clear()
	var slot: int=h.quickslot_index(0)
	# A retained catalog-only row wins name lookup over the real receipt.
	var records: Array=w.catalog_db["아이템"]
	var shadow: Dictionary={"name":item,"slot":"material","source_automation_catalog_only":true,"source_item_class_id":380}
	records.push_front(shadow)
	preload("res://scripts/catalog_item_lookup.gd").forget_misses()
	ck(w._find_catalog_item_record(item)==shadow,"the quickslot lookup sees the retained catalog shadow")
	h.quickslot_assignment_requested.emit(slot,"item",item)
	await process_frame
	await pull(h.original_quickslot_control(0),1.0)
	if not ck(w.quickslots[slot].get("id")==item and w.quickslots[slot].get("auto",false),"real short downward drag enables AUTO for the physical source haste potion behind a catalog shadow"):
		records.erase(shadow)
		return
	w._run_auto_item_quickslots(1.0)
	ck(STACK.proof(w,uid).get("remaining")==2,"active original effect does not spend another bottle")
	for effect: Dictionary in w.active_item_buffs.values():effect["remaining"]=0.2
	w.ui_preferences.item_locks[item+"@@@"+uid]=true
	w._tick_item_buffs(0.2)
	w._run_auto_item_quickslots(1.0)
	ck(STACK.proof(w,uid).get("remaining")==2,"a locked physical bottle waits even after expiry")
	w.ui_preferences.item_locks.erase(item+"@@@"+uid)
	w.item_use_cooldowns["m523:item:380"]=0.2
	w._run_auto_item_quickslots(1.0)
	ck(STACK.proof(w,uid).get("remaining")==2,"the original shared cooldown remains in force")
	w._tick_item_buffs(0.2)
	ck(w._run_auto_item_quickslots(1.0) and STACK.proof(w,uid).get("remaining")==1,"expiry plus cooldown permits one durable source refresh")
	w._load_game(true)
	ck(w.quickslots[slot].get("auto",false) and STACK.proof(w,uid).get("remaining")==1,"actual save/reload preserves AUTO and the exact debit")
	await pull(h.original_quickslot_control(0),-1.0)
	w.active_item_buffs.clear();w.item_use_cooldowns.clear()
	w._run_auto_item_quickslots(1.0)
	ck(not w.quickslots[slot].get("auto",true) and STACK.proof(w,uid).get("remaining")==1,"pulling up disables later item refresh")
	records.erase(shadow)

	w.level=90
	w.equipped_items["weapon"]={"name":"검사 양손검","type":"양손검","slot":"weapon"}
	var counter: Dictionary=w.original_skills.catalog.record_for("카운터 배리어")
	w.inventory[str(counter.book_name)]=1
	w.original_skills.catalog.learn(str(counter.id))
	h.quickslot_assignment_requested.emit(slot,"skill","카운터 배리어")
	w.mp=999;w.skill_cooldowns.clear();w.skill_global_cooldown=0.0
	w.auto_buff_check_timer=0.0
	w._run_auto_buff_quickslots(1.0)
	ck(not w.active_skill_buffs.has("카운터 배리어"),"an assigned manual-only skill is never consumed automatically")
	await pull(h.original_quickslot_control(0),1.0)
	ck(w.quickslots[slot].get("auto",false) and w._run_auto_buff_quickslots(1.0) and w.active_skill_buffs.has("카운터 배리어"),"downward skill drag enables the real skill cast")
	if not w.active_skill_buffs.has("카운터 배리어"):return
	w.skill_cooldowns.clear();w.skill_global_cooldown=0.0
	w.active_skill_buffs["카운터 배리어"]["remaining"]=0.2
	var mp_before: int=w.mp
	w._tick_skill_buffs(0.1)
	w._run_auto_buff_quickslots(1.0)
	ck(w.mp==mp_before and float(w.active_skill_buffs["카운터 배리어"].remaining)<0.2,"skill cannot spend MP while its timed effect is active")
	var before: int=w.hud_publish_counts.full
	if w._tick_skill_buffs(0.2,false) and not w._run_auto_buff_quickslots(0.0):w._publish_timed_buff_hud()
	ck(w.mp<mp_before and w.active_skill_buffs.has("카운터 배리어") and w.hud_publish_counts.full-before==1,"expiry and AUTO recast issue one character/buff publication")
	w.self_mode_enabled=true
	w.skill_cooldowns.clear();w.skill_global_cooldown=0.0
	w._tick_skill_buffs(float(w.active_skill_buffs.get("카운터 배리어",{}).get("remaining",0))+0.2)
	w._run_auto_buff_quickslots(1.0)
	ck(not w.active_skill_buffs.has("카운터 배리어"),"SELF suppresses the timed skill recast")
