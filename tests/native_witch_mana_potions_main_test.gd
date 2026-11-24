extends SceneTree
## Actual Main dual-variant potion: one physical debit, fixed 1,000 MP and
## the original independent 30-minute reuse, in the same persisted candidate.
const RAW=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const PROJ=preload("res://scripts/loot/current523_native_item_projection.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const IDS: Array[int]=[2501,183493]
var rejected:Dictionary={}
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("WITCH_MANA_MAIN_FAIL ",label)
	return ok
func refuse(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func _initialize()->void:run.call_deferred()
func run()->void:
	ck(PROJ.documented_mana_reuse({"ID":2502},{"Name":"Potion"},[],{"MPRestoration":1000})==0,"no implicit support for another potion variant")
	var source:String=OS.get_environment("TWILIGHT_WITCH_MANA_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main file"):
		await exact(source)
	print("WITCH_MANA_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);RAW.reset()
	ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA,"exact input definitions")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var requests:Array=[]
	for id:int in IDS:
		var item:Dictionary=D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
		var profile:Dictionary=STACK.profile(item)
		var spec:Dictionary=profile.get("spec",{})
		if not ck(profile.get("kind")=="mp" and spec.get("base")==1000 and spec.get("dice_number")==0 and spec.get("consume_delay_ms")==1000 and spec.get("reuse_delay_seconds")==1800,"exact original distinct restoration/cue/reuse "+str(id)+": "+str(spec)):
			w.queue_free();await process_frame;return
		w.catalog_db["아이템"].append(item)
		requests.append({"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0})
	w._index_catalog_item_sources()
	w.max_mp=3000;w._invalidate_equipment_static()
	if not ck(w._effective_max_mp()>=1100 and INV.commit(w,requests,{"kind":"qa_witch_mana"}),"actual physical supply"):
		w.queue_free();await process_frame;return
	var exact_refs:Dictionary={}
	for uid:String in w.item_instances:
		var owned:Dictionary=STACK.proof(w,uid)
		if not owned.is_empty() and int(owned.receipt.item_class_id) in IDS:
			exact_refs[int(owned.receipt.item_class_id)]=[str(owned.record.name),uid]
	if not ck(exact_refs.size()==2,"separate physical stack for each variant"):
		w.queue_free();await process_frame;return
	for id:int in IDS:
		var name:String=exact_refs[id][0];var uid:String=exact_refs[id][1]
		var ref:String=name+"@@@"+uid
		var key:String="m523:item:"+str(id)
		w.mp=100
		ck(w._save_game(true)==OK,"durable pre-use state "+str(id))
		var before:String=FileAccess.get_sha256(w.save_path())
		if id==2501:
			w.equipment_collections.test_save_writer=refuse
			w.hud.inventory_item_activated.emit(ref)
			ck(rejected.get("inventory",{}).get(name)==1 and rejected.get("item_use_cooldowns",{}).get(key)==1800 and rejected.get("mp")==1100,"one refused writer candidate has physical debit, +1000 MP, and 1800s reuse")
			ck(w.mp==100 and w.inventory.get(name)==2 and not w.item_use_cooldowns.has(key) and FileAccess.get_sha256(w.save_path())==before,"failed write changes neither MP nor quantity/cooldown/files")
			w.equipment_collections.test_save_writer=Callable()
			w._load_game(true)
		w.hud.inventory_item_activated.emit(ref)
		ck(w.mp==1100 and w.inventory.get(name)==1 and w.item_use_cooldowns.get(key)==1800 and STACK.proof(w,uid).get("remaining")==1,"actual bag use consumes one and immediately restores exactly MP1000 "+str(id)+": "+w.hud.message_label.text)
		w._load_game(true)
		ck(w.mp==1100 and w.inventory.get(name)==1 and w.item_use_cooldowns.get(key)==1800,"disk reload preserves MP/debit/reuse "+str(id))
		before=FileAccess.get_sha256(w.save_path())
		w.hud.inventory_item_activated.emit(ref)
		ck(w.hud.message_label.text.contains("재사용") and w.mp==1100 and w.inventory.get(name)==1 and FileAccess.get_sha256(w.save_path())==before,"repeated activation cannot spend the other copy before exact wait "+str(id))
	w.queue_free();await process_frame
