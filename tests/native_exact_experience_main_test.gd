extends SceneTree
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const EFFECTS=preload("res://scripts/loot/source523_item_effects.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const IDS:Dictionary={170184:2000000,170194:1500000,170204:1000000,181273:2000000,234598:4000000}
var checks:=0
var failures:Array[String]=[]
var rejected:Dictionary={}
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);printerr("NATIVE_EXACT_EXPERIENCE_FAIL ",message)
	return ok
func reject(_path:String,data:Dictionary)->Error:
	rejected=data
	return ERR_CANT_CREATE
func _initialize()->void:run.call_deferred()
func run()->void:
	ck(not STACK.authorizes_experience_reward({"experience":1}),"unsealed change cannot authorize EXP progression")
	ck(STACK.DIRECT_EXP_REWARDS.size()==IDS.size() and not STACK.DIRECT_EXP_REWARDS.has(170214) and not STACK.DIRECT_EXP_REWARDS.has(3062),"no contradictory IDs")
	if not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		if ck(not FileAccess.file_exists("user://twilight_v20_save.json") and SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"isolated profile and pinned definitions"):
			await exact()
	print("NATIVE_EXACT_EXPERIENCE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func exact()->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w)
	w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"real Main selection")
	w.field_population.set_process(false);w.player.set_physics_process(false)
	var invalid:Dictionary=w.source_item_definition(170214).get("native_record",{})
	ck(not invalid.is_empty() and STACK.profile(invalid).get("kind")!="exact_experience","fourth original fruit retained without guessed amount")
	var grants:Array=[]
	for id:int in IDS:
		grants.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	var given:Dictionary=INV.stage(w,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(given.get("ok",false),"shared source supplier physical grant "+str(given.get("error",""))):
		w.queue_free();return
	w.inventory=given.overrides.inventory;w.item_instances=given.overrides.item_instances
	var uids:Dictionary={}
	for uid:String in w.item_instances:
		var rec:Dictionary=w.item_instances[uid].get("record",{})
		var id:int=int(rec.get("source_item_class_id",0))
		if IDS.has(id):
			uids[id]=uid
			var p:Dictionary=STACK.profile(rec)
			ck(p.get("kind")=="exact_experience" and p.get("spec",{}).get("source_exp")==IDS[id],"matching raw ItemClass, bonus and text "+str(id))
	if not ck(uids.size()==IDS.size(),"five actual physical stack receipts"):
		w.queue_free();return
	var prior_level:int=41
	w.level=prior_level-2;w.exp_need=9000000;w.experience=0
	var eye_id:String=uids[170184];var eye:String=str(w.item_instances[eye_id].name)+"@@@"+eye_id
	w.hud.inventory_item_activated.emit(eye)
	ck(w.experience==0 and w.item_instances.has(eye_id),"exact original rank fruit minimum level enforced")
	w.level=prior_level
	var mark_uid:String=uids[181273]
	w.hud.inventory_item_activated.emit(str(w.item_instances[mark_uid].name)+"@@@"+mark_uid)
	ck(w.experience==0 and w.item_instances.has(mark_uid),"world-boss mark separate lv45 gate")
	w.level=45;w.exp_need=9000000;w.experience=w.exp_need-1
	var started_points:int=w.stat_points;var started_hp:int=w.max_hp;var started_mp:int=w.max_mp
	ck(w._save_game(true)==OK,"baseline persisted before exercising save failure")
	var before:PackedByteArray=FileAccess.get_file_as_bytes(w.save_path())
	ck(w._save_game(true,{"experience":9000000,"stat_points":started_points+1})!=OK and FileAccess.get_file_as_bytes(w.save_path())==before,"ordinary save cannot forge unsealed EXP and growth")
	w.equipment_collections.test_save_writer=reject;w.hud.inventory_item_activated.emit(eye)
	var amount:int=EFFECTS.twilight_experience(IDS[170184])
	ck(rejected.get("experience")==amount-1 and rejected.get("level")==46 and rejected.get("stat_points")==started_points+1 and not rejected.get("item_instances",{}).has(eye_id),"pending debit, new level, EXP and point are together at actual writer")
	ck(w.experience==8999999 and w.level==45 and w.stat_points==started_points and w.item_instances.has(eye_id) and FileAccess.get_file_as_bytes(w.save_path())==before,"refused writer keeps bytes, growth and physical item")
	w.equipment_collections.test_save_writer=Callable();w.hud.inventory_item_activated.emit(eye)
	ck(not w.item_instances.has(eye_id) and w.level==46 and w.experience==amount-1 and w.stat_points==started_points+1 and w.max_hp==started_hp+45 and w.max_mp==started_mp+9,"exact same durable growth on level crossing")
	w.hud.inventory_item_activated.emit(eye)
	ck(w.experience==amount-1 and w.stat_points==started_points+1,"stale repeat cannot consume or grant")
	w.exp_need=90000000
	var before_overflow:int=w.experience
	w.experience=9007199254740991
	w.hud.inventory_item_activated.emit(str(w.item_instances[mark_uid].name)+"@@@"+mark_uid)
	ck(w.experience==9007199254740991 and w.item_instances.has(mark_uid),"out-of-range exact JSON EXP retains the item without overflow")
	w.experience=before_overflow
	for id:int in IDS:
		if id==170184:continue
		var uid:String=uids[id];var name:String=str(w.item_instances[uid].name)
		var prior:int=w.experience;var before_ain:int=w.ain_service.blessing
		w.hud.inventory_item_activated.emit(name+"@@@"+uid)
		ck(w.experience==prior+EFFECTS.twilight_experience(IDS[id]) and not w.item_instances.has(uid) and w.ain_service.blessing==before_ain,"exact EP amount, no blessing, one native debit "+str(id))
	var exp:int=w.experience
	w.experience=0;w.stat_points=0;w._load_game(true)
	var all_used:bool=true
	for uid:String in uids.values():
		if w.item_instances.has(uid):all_used=false
	ck(w.experience==exp and w.level==46 and w.stat_points==started_points+1 and all_used,"disk reload exact new EXP, level, point, and five consumed receipts")
	w.queue_free();await process_frame
