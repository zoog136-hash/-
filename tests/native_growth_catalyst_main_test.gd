extends SceneTree
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const C=preload("res://scripts/loot/native_growth_catalyst523.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const E=preload("res://scripts/loot/source523_item_effects.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checked:int=0
var failures:Array[String]=[]
var candidate:Dictionary={}
func ck(ok:bool,message:String)->bool:
	checked+=1
	if not ok:failures.append(message);printerr("NATIVE_GROWTH_CATALYST_MAIN_FAIL ",message)
	return ok
func _initialize()->void:run.call_deferred()
func reject(_path:String,data:Dictionary)->Error:
	candidate=data
	return ERR_CANT_CREATE
func run()->void:
	ck(C.profile({},{}).is_empty() and not STACK.authorizes_experience_reward({"experience":1}),"no unrelated/unauthenticated item owner")
	var source_end:int=Time.get_unix_time_from_datetime_string("2027-03-23T20:00:00")
	ck(C.before_issue_end(source_end-1,540) and not C.before_issue_end(source_end,540),"source issue stops at the exact Korean boundary; not an offline recurrence")
	var definitions:String=OS.get_environment("TWILIGHT_NATIVE_CATALYST_DEFINITIONS")
	if not definitions.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main profile"):
		await exact(definitions)
	print("NATIVE_GROWTH_CATALYST_MAIN_RESULT ",JSON.stringify({"checks":checked,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func exact(definitions:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main inventory")
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",definitions);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"exact mounted definitions")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	for id:int in [C.ITEM_ID,C.REWARD_ID]:
		w.catalog_db["아이템"].append(w.source_item_definition(id).get("native_record",{}))
	w._index_catalog_item_sources()
	var d:Dictionary=w.source_item_definition(C.ITEM_ID)
	var p:Dictionary=STACK.profile(d.get("native_record",{}))
	var sources:Dictionary=preload("res://scripts/loot/current523_native_fields.gd").field(d.get("native_record",{}),"source_use_spec",{})
	if not ck(p.get("spec",{}).get("growth_catalyst")==true,"only exact current catalyst profile admits all original effects "+str(sources.get("blocked_reasons",[]))+" "+str(sources.get("typed_effects",{}))):
		w.queue_free();return
	var old:Dictionary=w.source_item_definition(353513).get("native_record",{})
	ck(not old.is_empty() and STACK.profile(old).get("kind")!="exact_experience","the already-expired Halpha dose is not reopened")
	var given:Dictionary=INV.stage(w,[{"item_class_id":C.ITEM_ID,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(given.get("ok",false),"physical original supplier "+str(given.get("error",""))):
		w.queue_free();return
	w.inventory=given.overrides.inventory;w.item_instances=given.overrides.item_instances
	var uid:String=""
	for key:String in w.item_instances:
		if w.item_instances[key].get("record",{}).get("source_item_class_id")==C.ITEM_ID:uid=key
	if not ck(not uid.is_empty(),"exact two-unit initial receipt"):w.queue_free();return
	var ref:String=str(w.item_instances[uid].name)+"@@@"+uid
	var reward_name:String=str(w.source_item_definition(C.REWARD_ID).native_record.name)
	w.exp_need=50000000;w.experience=200
	var expected:int=w.experience+E.twilight_experience(20000000)
	var rng:int=w.rng.state
	var prior:=Vector3(w._pve_reduction_percent("melee"),w._pve_reduction_percent("ranged"),w._pve_reduction_percent("magic"))
	w.active_item_buffs["원본 시험군 624"]={"remaining":20.0,"source_buff_class":{"ID":1,"BuffGroupID":624}}
	w.hud.inventory_item_activated.emit(ref)
	ck(w.experience==200 and STACK.proof(w,uid).remaining==2 and not w.active_item_buffs.has(C.ACTIVE_KEY),"original incompatible buff group refuses without debit")
	w.active_item_buffs.erase("원본 시험군 624")
	ck(w._save_game(true)==OK,"baseline save")
	var bytes:PackedByteArray=FileAccess.get_file_as_bytes(w.save_path())
	var original_wallet:int=w.inventory.get("명예 코인",0)
	w.equipment_collections.test_save_writer=reject;w.hud.inventory_item_activated.emit(ref)
	ck(candidate.get("experience")==expected and candidate.get("active_item_buffs",{}).has(C.ACTIVE_KEY),"source EXP and time-based buff share the real writer")
	ck(w.experience==200 and STACK.proof(w,uid).remaining==2 and FileAccess.get_file_as_bytes(w.save_path())==bytes and not w.active_item_buffs.has(C.ACTIVE_KEY),"failure keeps XP, physical dose, save and buff unchanged")
	w.equipment_collections.test_save_writer=Callable()
	w.hud.inventory_item_activated.emit(ref)
	if not ck(w.experience==expected and STACK.proof(w,uid).remaining==1 and w.active_item_buffs.has(C.ACTIVE_KEY),"one real debit starts exactly one active benefit"):
		w.queue_free();return
	ck(w.active_item_buffs[C.ACTIVE_KEY].remaining==3600.0 and w.item_use_cooldowns.get("m523:item:371558")==5.0 and w.rng.state==rng,"raw 3600s active duration, 5s cooldown and unchanged RNG")
	ck(w._active_item_buff_total("xp")==70 and w._active_item_buff_total("potion_heal_pct")==10 and w._active_item_buff_total("pve_damage_reduction")==3,"actual progression, potion and PVE flat incoming owners see typed values")
	ck(is_equal_approx(w._pve_reduction_percent("melee"),prior.x) and is_equal_approx(w._pve_reduction_percent("ranged"),prior.y+1) and is_equal_approx(w._pve_reduction_percent("magic"),prior.z+1),"melee unaffected; only ranged and magic reduce by one percentage point")
	ck(w.inventory.get(reward_name,0)==0 and w.inventory.get("명예 코인",0)==original_wallet,"honor material is never granted upfront or to wallet")
	w._load_game(true)
	ck(w.active_item_buffs.get(C.ACTIVE_KEY,{}).get("remaining")==3600.0 and w.experience==expected,"active relative timer and item consumption persist")
	w._tick_item_buffs(5.0);w.hud.inventory_item_activated.emit(ref)
	ck(STACK.proof(w,uid).remaining==1 and w.experience==expected,"same-group restriction remains after five-second reuse")
	w._tick_item_buffs(3594.0)
	ck(w.active_item_buffs[C.ACTIVE_KEY].remaining==1.0 and w.inventory.get(reward_name,0)==0,"no reward before full original duration")
	ck(w._save_game(true)==OK,"final second saved for a controlled restart")
	bytes=FileAccess.get_file_as_bytes(w.save_path())
	w.equipment_collections.test_save_writer=reject;w._tick_item_buffs(1.0)
	ck(candidate.get("inventory",{}).get(reward_name)==15 and not candidate.get("active_item_buffs",{}).has(C.ACTIVE_KEY),"expiry writer must carry exact 216053 ×15 and remove entitlement together")
	ck(w.active_item_buffs.has(C.ACTIVE_KEY) and w.active_item_buffs[C.ACTIVE_KEY].remaining==0.0 and w._active_item_buff_total("xp")==0 and w.inventory.get(reward_name,0)==0 and FileAccess.get_file_as_bytes(w.save_path())==bytes,"fault keeps exact entitlement, no elapsed stat boost, no payout and disk intact")
	w._load_game(true);w._growth_catalyst_retry_usec=0
	ck(w.active_item_buffs.get(C.ACTIVE_KEY,{}).get("remaining")==1.0 and w.inventory.get(reward_name,0)==0,"previous exact checkpoint survives restart after writer failure")
	w._tick_item_buffs(1.0)
	w.equipment_collections.test_save_writer=Callable()
	ck(w._save_game(true)==OK,"a pending expiry receipt can be saved independently without paying")
	w._load_game(true);w._growth_catalyst_retry_usec=0
	ck(w.active_item_buffs.get(C.ACTIVE_KEY,{}).get("remaining")==0.0 and w.inventory.get(reward_name,0)==0 and w._active_item_buff_total("xp")==0,"the zero-duration entitlement survives a later ordinary save without extending stats")
	w._tick_item_buffs(1.0)
	ck(not w.active_item_buffs.has(C.ACTIVE_KEY) and w.inventory.get(reward_name,0)==15 and w.inventory.get("명예 코인",0)==original_wallet,"expiry/retry grants exact material only, once")
	w._load_game(true);w._growth_catalyst_retry_usec=0;w._tick_item_buffs(1.0)
	var reward_units:int=0
	for key:String in w.item_instances:
		var row:Dictionary=w.item_instances[key]
		if row.get("record",{}).get("source_item_class_id")==C.REWARD_ID:reward_units+=int(row.get(STACK.QUANTITY,0))
	ck(not w.active_item_buffs.has(C.ACTIVE_KEY) and w.inventory.get(reward_name,0)==15 and reward_units==15,"reloaded claimant has no repeat and holds a physical source receipt")
	w.queue_free();await process_frame
