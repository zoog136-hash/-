extends SceneTree
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,why:String)->bool:
	checks+=1
	if not ok:failures.append(why);printerr("NATIVE_BONUS_EYE_FAIL ",why)
	return ok
var rejected:Dictionary={}
func reject(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func _initialize()->void:run.call_deferred()
func run()->void:
	var selected:=not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty()
	ck(not STACK.bonus_point_rule({"name":"깨달은자의 눈"},{}),"name-only cannot grant")
	ck(not STACK.authorizes_bonus_point(null,{"stat_points":1}),"unsealed positive candidate never allowed")
	if selected and not ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"use a separate fresh user-data directory"):
		print("NATIVE_BONUS_EYE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
	if selected and ck(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"pinned 523 archive"):
		await exact()
	print("NATIVE_BONUS_EYE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pinned_source":selected}))
	quit(0 if failures.is_empty() else 1)
func exact()->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"Main class selected");w.field_population.set_process(false);w.player.set_physics_process(false)
	for id:int in [146412,147152,4151]:ck(STACK.profile(w.source_item_record(id)).get("kind")!="bonus_stat_point","cap items and regular elixir not misclassified")
	var s:Dictionary=INV.stage(w,[{"item_class_id":146402,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if ck(s.get("ok",false),"exact original developer grant via native supplier: "+str(s.get("error",s.get("reason","")))):
		w.inventory=s.overrides.inventory;w.item_instances=s.overrides.item_instances
		var uid:String=""
		for key:String in w.item_instances:
			if int(w.item_instances[key].get("record",{}).get("source_item_class_id",0))==146402:uid=key;break
		if ck(not uid.is_empty(),"native receipt instance selected"):
			var record:Dictionary=w.item_instances[uid].record;var name_key:String=record.name;var ref:String=name_key+"@@@"+uid
			ck(STACK.profile(record).get("kind")=="bonus_stat_point","only exact original direct bonus")
			ck(w._save_game(true)==OK,"baseline saves before consuming physical eye")
			ck(w._save_game(true,{"stat_points":w.stat_points+1})!=OK,"unsealed direct stat grant rejected")
			var pts:int=w.stat_points;var stat:int=w.str_stat;var wallet:int=w.gold
			w.level=88;w.hud.inventory_item_activated.emit(ref)
			ck(int(w.inventory.get(name_key,0))==1 and w.stat_points==pts,"below 89 does not spend")
			w.level=89;w.equipment_collections.test_save_writer=reject;w.hud.inventory_item_activated.emit(ref)
			ck(rejected.get("stat_points")==pts+1 and int(rejected.get("inventory",{}).get(name_key,0))==0,"writer received joint point and debit candidate")
			ck(int(w.inventory.get(name_key,0))==1 and w.stat_points==pts,"refused write keeps both")
			w.equipment_collections.test_save_writer=Callable();w.hud.inventory_item_activated.emit(ref)
			ck(not w.item_instances.has(uid) and int(w.inventory.get(name_key,0))==0 and w.stat_points==pts+1 and w.str_stat==stat and w.gold==wallet,"one physical eye -> unallocated point only")
			w.hud.inventory_item_activated.emit(ref);ck(w.stat_points==pts+1,"stale duplicate tap did not grant")
			w.stat_points=0;w._load_game(true)
			ck(w.stat_points==pts+1 and not w.item_instances.has(uid),"atomic quantity + point restored from disk")
			w.hud.stat_increase_requested.emit("STR")
			ck(w.str_stat==stat+1 and w.stat_points==pts,"new bonus point spendable in existing character stat owner")
	w.queue_free();await process_frame
