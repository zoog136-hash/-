extends SceneTree
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const SMELT=preload("res://scripts/equipment523/native_smelt_input.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const BAG=preload("res://scripts/ui/renewal_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const TREE=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const RESOURCE=preload("res://scripts/boot/source523_pack.gd")
const SIDECAR=preload("res://scripts/equipment523/native_smelt_rules.gd")
const EQUIPMENT=preload("res://scripts/equipment523/service.gd")
const TARGET:=183681
const NORMAL_TARGET:=289062
const INPUT:=359652
const SOURCE_RULES_SHA:="e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);printerr("NATIVE_SMELT_INVENTORY_FAIL ",message)
	return ok
func _initialize()->void:run.call_deferred()
func reject(_path:String,data:Dictionary)->Error:
	rejected=data
	return ERR_CANT_CREATE
func touch(window:RefCounted,controller:Node,path:String)->Dictionary:
	var located:Dictionary=TREE.locate(window._scene,window.node_keys(),path)
	if not located.get("ok",false):return located
	var node:Variant=located.player.source_nodes.get(located.offset)
	var button:Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
	var area:Variant=button.get("_input_area") if is_instance_valid(button) else null
	if not area is Control:return {"ok":false,"error":"source touch area missing"}
	var responses:Array=[]
	button.activation_result.connect(func(outcome:Dictionary)->void:responses.append(outcome),CONNECT_ONE_SHOT)
	var point:Vector2=area.get_global_transform_with_canvas()*(area.size*0.5)
	for pressed:bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=6;event.pressed=pressed;event.position=point
		controller._input(event)
	if not responses.is_empty():return responses[0]
	return {"ok":false,"error":"source touch not dispatched at %s (available=%s, hit=%s, modal=%s)" % [point,button._input_available(),button._hit_viewport(point),controller._hud.get_ref().blocks_keyboard_input()]}
func run()->void:
	ck(SMELT.POOLS.size()==12 and SMELT.kind({}).is_empty() and not SMELT.known(359722),"supported permanent and active issues only; no legacy blanket enable")
	var cutoff:int=Time.get_unix_time_from_datetime_string("2027-02-23T20:00:00")
	ck(SMELT.period_allows(374544,cutoff-1,540) and not SMELT.period_allows(374544,cutoff,540) and SMELT.period_allows(INPUT,cutoff,540),"exact Korean end with permanent same-name variant separate")
	var definitions:String=OS.get_environment("TWILIGHT_NATIVE_SMELT_DEFINITIONS")
	var rules:String=OS.get_environment("TWILIGHT_NATIVE_SMELT_RULES")
	var addon:String=OS.get_environment("TWILIGHT_NATIVE_SMELT_ADDON")
	if not definitions.is_empty() and (not rules.is_empty() or not addon.is_empty()) and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main"):
		if not addon.is_empty():prepare_addon(addon)
		await exact(definitions,rules)
	print("NATIVE_SMELT_INVENTORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func prepare_addon(addon:String)->void:
	var zip:=ZIPReader.new()
	if not ck(zip.open(addon)==OK,"exact resource add-on open"):return
	var index:Dictionary=JSON.parse_string(zip.read_file(RESOURCE.PREFIX+RESOURCE.PART_INDEX).get_string_from_utf8())
	var declared:Dictionary=RESOURCE.read_addon(zip.read_file(RESOURCE.PREFIX+RESOURCE.ADDON_DESCRIPTOR),index)
	zip.close()
	if not ck(not declared.is_empty(),"actual app accepts the authored tiny add-on index"):return
	var base:String="user://equipment-smelt-install-fixture"
	if not ck(RESOURCE.install_smelt_sidecar(addon,base),"actual installer checks full ZIP SHA and writes only the pinned compact rule"):return
	var path:String=base.path_join(SIDECAR.SECTION).path_join(SIDECAR.MEMBER)
	var tampered:PackedByteArray=FileAccess.get_file_as_bytes(addon)
	tampered[tampered.size()-10]^=1
	var write:=FileAccess.open(base.path_join("bad.zip"),FileAccess.WRITE)
	write.store_buffer(tampered);write.close()
	ck(not RESOURCE.install_smelt_sidecar(base.path_join("bad.zip"),base) and FileAccess.get_sha256(path)==SIDECAR.SHA,"mutated same-size add-on never replaces the active bytes")
	ck(RESOURCE.record_addon_sections(base,declared.sections),"actual installer records the add-on for the next normal launch")
	var stub:Dictionary={"tables":{"path":"definitions.zip"},"images":{"root":"images","manifest_sha256":SIDECAR.SHA},"bank":{"manifest":"bank/manifest.json","manifest_sha256":SIDECAR.SHA},"maps":{"root":"maps","manifest_sha256":SIDECAR.SHA},"tiles":{"root":"tiles","manifest_sha256":SIDECAR.SHA}}
	var selected:Dictionary=RESOURCE.selections(base,stub,RESOURCE.read_addons(base))
	ck(selected.environment.get(SIDECAR.ENV)==path and not SIDECAR.SECTION in RESOURCE.missing_addons(stub,{}),"normal source-pack selection sees the optional add-on without making it a mandatory startup dependency")
	OS.set_environment(SIDECAR.ENV,str(selected.environment.get(SIDECAR.ENV,"")))
	var raw:PackedByteArray=FileAccess.get_file_as_bytes(path)
	raw[0]^=1
	write=FileAccess.open(base.path_join("bad.json"),FileAccess.WRITE)
	write.store_buffer(raw);write.close()
	ck(SIDECAR.read(base.path_join("bad.json")).is_empty(),"tampered extracted data is also rejected on startup")
	var pointer:String=EQUIPMENT.PackStore.POINTER
	if not ck(not FileAccess.file_exists(pointer),"full-pack precedence check has an isolated profile"):return
	DirAccess.make_dir_recursive_absolute(pointer.get_base_dir())
	write=FileAccess.open(pointer,FileAccess.WRITE)
	write.store_string("{\"sha256\":\"invalid\"}");write.close()
	var other:RefCounted=EQUIPMENT.new()
	ck(not other.startup(null).get("ok",false) and other._compact_smelt_job==null,"a broken configured full pack may not silently fall back")
	DirAccess.remove_absolute(pointer)

func exact(definitions:String,rules:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",definitions);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"exact original definition archive")
	var compact:bool=not OS.get_environment("TWILIGHT_NATIVE_SMELT_ADDON").is_empty()
	if compact:
		var deadline:int=Time.get_ticks_msec()+1000
		while w.equipment523.compact_smelt_rules.is_empty() and Time.get_ticks_msec()<deadline:
			w.equipment523.tick(w,0)
			if w.equipment523.compact_smelt_rules.is_empty():await process_frame
		ck(w.equipment523.store.pack.is_empty() and w.equipment523.compact_smelt_rules.get("source_sha256")==SRC.SOURCE_SHA,"actual Main starts with installed exact compact data and does not load a full pack")
		ck(not w.equipment523.quote(w,{"kind":"alchemy"}).get("ok",false),"the compact pack cannot enable unrelated processing modes")
		print("NATIVE_SMELT_SIDECAR_STARTUP_USEC ",w.equipment523.compact_smelt_schedule_usec," background=",w.equipment523.compact_smelt_prepare_usec)
	else:
		var start:int=Time.get_ticks_usec()
		ck(w.equipment523.store.load_verified(rules,SOURCE_RULES_SHA).get("ok",false),"standard derived rule tables from the verified source")
		print("NATIVE_SMELT_FULL_LOAD_USEC ",Time.get_ticks_usec()-start)
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var ids:Array=SMELT.POOLS.keys()+[SMELT.ORDINARY]
	for id:int in ids+[TARGET,NORMAL_TARGET,359722]:
		var record:Dictionary=w.source_item_definition(id).get("native_record",{})
		w.catalog_db["아이템"].append(record)
		if id in ids:ck(not SMELT.kind(record).is_empty() and BAG.action_for_record(record,str(record.get("name","")),w)=="사용","material owner and bag marker for exact source "+str(id))
		if id==359722:ck(SMELT.kind(record).is_empty() and not BAG.material_direct_use(record),"expired event core cannot borrow the shared source label")
	w._index_catalog_item_sources()
	var grants:Array=[
		{"item_class_id":INPUT,"amount":2,"bless_raw":1,"enchant":0},
		{"item_class_id":INPUT,"amount":3,"bless_raw":1,"enchant":0},
		{"item_class_id":TARGET,"amount":1,"bless_raw":1,"enchant":4},
		{"item_class_id":NORMAL_TARGET,"amount":1,"bless_raw":1,"enchant":0},
		{"item_class_id":SMELT.ORDINARY,"amount":2,"bless_raw":1,"enchant":0}
	]
	var given:Dictionary=INV.stage(w,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(given.get("ok",false),"normal current supplier can give exact processing items "+str(given.get("error",""))):
		w.queue_free();return
	w.inventory=given.overrides.inventory;w.item_instances=given.overrides.item_instances
	var chosen:String="";var sibling:String="";var target:String="";var ordinary:String="";var ordinary_target:String=""
	for uid:String in w.item_instances:
		var item:Dictionary=w.item_instances[uid]
		match int(item.get("record",{}).get("source_item_class_id",0)):
			INPUT:
				if item.get(STACK.QUANTITY)==2:chosen=uid
				elif item.get(STACK.QUANTITY)==3:sibling=uid
			TARGET:target=uid
			NORMAL_TARGET:ordinary_target=uid
			SMELT.ORDINARY:ordinary=uid
	if not ck(not chosen.is_empty() and not sibling.is_empty() and not target.is_empty() and not ordinary_target.is_empty() and not ordinary.is_empty(),"distinct exact in-bag receipts and real equipment"):
		w.queue_free();return
	var equipment:RefCounted=w.equipment523
	var native:Dictionary=equipment.native_smelt_offer(w,chosen)
	ck(native.get("ok",false) and native.get("quantity")==2 and native.get("targets",[]).size()==1 and native.get("targets",[{}])[0].get("target_id")==target,"source target resolver admits the one owned source badge only")
	var exact_ui:bool=OS.get_environment("TWILIGHT_NATIVE_SMELT_REQUIRE_UI")=="1"
	if exact_ui and not is_instance_valid(w.hud.original_main_ui_controller):
		w.hud._bind_selected_original_main_ui()
	ck(not exact_ui or is_instance_valid(w.hud.original_main_ui_controller),"real original UI configured: "+str(w.hud.original_main_ui_bind_problem))
	var ref:String=str(w.item_instances[chosen].name)+"@@@"+chosen
	var rng:int=w.rng.state
	ck(w._save_game(true)==OK,"saved proof baseline")
	var disk:PackedByteArray=FileAccess.get_file_as_bytes(w.save_path())
	var opening_started:int=Time.get_ticks_usec()
	w.hud.inventory_item_activated.emit(ref)
	print("NATIVE_SMELT_OPEN_USEC ",Time.get_ticks_usec()-opening_started)
	var controller:Node=w.hud.original_main_ui_controller
	var window:RefCounted=controller.enchant_window() if is_instance_valid(controller) else null
	var ui_ready:bool=window!=null and window.is_open() and window.last_result.get("mode")=="spirit_smelt"
	if exact_ui:ck(ui_ready,"actual bag opens the original spirit-smelt tab: "+str(window.last_result if window!=null else w.hud.original_main_ui_status)+" "+str(w.hud.message_label.text))
	else:ck(not ui_ready and w.hud.message_label.text.contains("재료 보존"),"without real art the bag explains refusal and never mounts a substitute")
	ck(STACK.proof(w,chosen).remaining==2 and w.rng.state==rng and FileAccess.get_file_as_bytes(w.save_path())==disk,"opening no charge, roll or save")
	var action:Dictionary={"kind":"spirit_smelt","target_id":target,"material_ids":[chosen]}
	var invalid:Dictionary={"kind":"spirit_smelt","target_id":ordinary_target,"material_ids":[chosen]}
	ck(not equipment.quote(w,invalid).get("ok",false),"source spirit core cannot process an unrelated ordinary item")
	var q:Dictionary=equipment.quote(w,action)
	if not ck(q.get("ok",false) and q.get("pool_id")==92 and q.get("slots",[]).size()==1 and q.get("_native_smelt_requests",[]).size()==1,"actual original +4 pool/slot reached with physical debit attached "+str(q.get("error",""))):
		w.queue_free();return
	var target_button:String="";var start_button:String=""
	if ui_ready:
		var body:String=window.P_ALL+"Nd_Enchant_Properties_Smelt/Enchant_Tab_Properties_Smelt"
		ck(TREE.locate(window._scene,window.node_keys(),body).get("ok",false),"authored spirit body actually mounted")
		target_button=window.P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/Slot_1/Btn"
		start_button=window.P_SMELT_START
		var picked:Dictionary=touch(window,controller,target_button)
		ck(picked.get("ok",false) and window.last_result.get("can_smelt",false),"actual authored slot touch previews valid +4 quote "+str(picked.get("error","")))
	w.equipment_collections.test_save_writer=reject
	var fault:Dictionary=touch(window,controller,start_button) if ui_ready else equipment.commit(w,action)
	ck(not fault.get("ok",false) and STACK.proof(w,chosen).remaining==2 and STACK.proof(w,sibling).remaining==3 and w.rng.state==rng and FileAccess.get_file_as_bytes(w.save_path())==disk,"failed actual writer keeps both physical stacks, all effects, RNG and bytes")
	ck(rejected.get("item_instances",{}).get(chosen,{}).get(STACK.QUANTITY)==1 and rejected.get("item_instances",{}).get(target,{}).get("equipment523",{}).has("spirit_smelt"),"writer receives new exact physical debit and selected target options together "+str(fault.get("error","")))
	w.equipment_collections.test_save_writer=Callable()
	if ui_ready:touch(window,controller,target_button)
	else:equipment.quote(w,action)
	var done:Dictionary=touch(window,controller,start_button) if ui_ready else equipment.commit(w,action)
	ck(done.get("ok",false) and STACK.proof(w,chosen).remaining==1 and STACK.proof(w,sibling).remaining==3 and w.item_instances[target].get("equipment523",{}).has("spirit_smelt"),"selected identical-looking stack alone pays and target gains original option")
	ck(not equipment.commit(w,action).get("ok",false) and STACK.proof(w,chosen).remaining==1,"a stale repeat cannot spend another unit")
	var normal_action:Dictionary={"kind":"smelt","target_id":ordinary_target,"material_ids":[ordinary]}
	var normal_q:Dictionary=equipment.quote(w,normal_action)
	ck(normal_q.get("ok",false) and normal_q.get("_native_smelt_requests",[]).size()==1,"ordinary Life Stone uses the same physical custody owner "+str(normal_q.get("error","")))
	if normal_q.get("ok",false):
		var normal_result:Dictionary=equipment.commit(w,normal_action)
		ck(normal_result.get("ok",false) and STACK.proof(w,ordinary).remaining==1 and w.item_instances[ordinary_target].get("equipment523",{}).has("smelt"),"ordinary Life Stone commits its own source namespace")
	var disk_after:Variant=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	ck(disk_after.get("patch523_transaction_rng",{}).get("state")==str(w.rng.state),"actual post-roll RNG persisted together with target and debit")
	w._load_game(true)
	var total:int=0
	for uid:String in w.item_instances:
		var proof:Dictionary=STACK.proof(w,uid)
		if proof.get("record",{}).get("source_item_class_id")==INPUT:total+=int(proof.remaining)
	var consumed_from_selected:bool=false;var sibling_unchanged:bool=false
	for journal:Dictionary in w.consumable_service.export_state().get(STACK.MERGES,{}).values():
		for row:Dictionary in journal.get("components",[]):
			if row.get("physical_id")==chosen and row.get("receipt",{}).get("item_class_id")==INPUT and row.get("used_quantity")==1 and row.get("remaining_quantity")==1:consumed_from_selected=true
			if row.get("physical_id")==sibling and row.get("receipt",{}).get("item_class_id")==INPUT and row.get("used_quantity")==0 and row.get("remaining_quantity")==3:sibling_unchanged=true
	ck(total==4 and consumed_from_selected and sibling_unchanged and w.item_instances[target].get("equipment523",{}).get("spirit_smelt",{}).get("pool_id")==92,"reloaded stack consolidation preserves count, both exact provenance components and target options")
	var chosen_bonus:int=int(done.get("state",{}).get("spirit_smelt",{}).get("bonus_ids",[0])[0])
	w.hud.inventory_item_activated.emit(str(w.item_instances[target].name)+"@@@"+target)
	var active_bonus:bool=false
	for effect:Dictionary in w._equipment523_bonus_records():
		if effect.get("equipment523_bonus_id")==chosen_bonus and (effect.has("element_resist_fire") or effect.has("equipment523_element_pierce_fire")):active_bonus=true
	ck(chosen_bonus>0 and w._is_instance_equipped(target) and active_bonus,"actual equip activation applies the reloaded, rolled original fire effect")
	w.queue_free();await process_frame
