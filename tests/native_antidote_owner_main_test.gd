extends SceneTree
## The exact original physical antidote must enter the existing poison-only
## effect owner, even after timed buff priority projection was corrected.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const CURE=preload("res://scripts/quests/quest_cure310.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("ANTIDOTE_OWNER_MAIN_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func refuse(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func run()->void:
	var source:String=OS.get_environment("TWILIGHT_ANTIDOTE_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main file"):
		await exact(source)
	else:
		ck(CURE.profile({}).is_empty(),"no exact source record is refused")
	print("ANTIDOTE_OWNER_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main enters")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);SOURCE.reset()
	ck(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"pinned original ItemClass+Buff graph")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var item:Dictionary=D.variant_item(D.definition_id("310").get("native_record",{}),1)
	var recurring:Dictionary=D.variant_item(D.definition_id("248218").get("native_record",{}),1)
	ck(CURE.profile(recurring).is_empty(),"do not revive the distinct disabled-tower variant")
	if not ck(STACK.profile(item).get("kind")=="cure","actual registered item dispatch resolves only as instant cure"):
		w.queue_free();await process_frame;return
	w.catalog_db["아이템"].append(item);w._index_catalog_item_sources()
	if not ck(INV.commit(w,[{"item_class_id":310,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"qa_native_antidote"}),"two actual supplied units"):
		w.queue_free();await process_frame;return
	var uid:String=""
	for k:String in w.item_instances:
		if STACK.proof(w,k).get("receipt",{}).get("item_class_id")==310:uid=k;break
	if not ck(not uid.is_empty(),"real original receipt"):w.queue_free();await process_frame;return
	var ref:String=str(item.name)+"@@@"+uid
	var prev:String=FileAccess.get_sha256(w.save_path())
	w.hud.inventory_item_activated.emit(ref)
	ck(STACK.proof(w,uid).get("remaining")==2 and FileAccess.get_sha256(w.save_path())==prev,"without existing poison, no waste/no write")
	w.player.apply_poison(20,7,1);w.player.apply_bleed(30,3,0.75)
	var bleed:Array=[w.player.bleed_remaining,w.player.bleed_tick_damage]
	var poison:Dictionary=CURE.poison(w)
	w.equipment_collections.test_save_writer=refuse
	w.hud.inventory_item_activated.emit(ref)
	ck(rejected.get("inventory",{}).get(item.name)==1 and not rejected.get("consumable_state",{}).get("source_instant_cure_uses",{}).is_empty(),"the refused single durable candidate combined native debit and antidote record: "+w.hud.message_label.text)
	ck(STACK.proof(w,uid).get("remaining")==2 and CURE.poison(w)==poison and bleed==[w.player.bleed_remaining,w.player.bleed_tick_damage] and FileAccess.get_sha256(w.save_path())==prev,"failed save preserves receipt, poison, bleed and durable state")
	w.equipment_collections.test_save_writer=Callable()
	w.hud.inventory_item_activated.emit(ref)
	ck(STACK.proof(w,uid).get("remaining")==1 and not w.player.is_poisoned() and bleed==[w.player.bleed_remaining,w.player.bleed_tick_damage] and w.item_use_cooldowns.get("m523:item:310")==0.5,"actual bag clears only poison, debits one, uses original delay: "+w.hud.message_label.text)
	w._load_game(true)
	var row:Dictionary=w.consumable_service.export_state().get("source_instant_cure_uses",{}).get("native_stack:"+uid,{})
	ck(STACK.proof(w,uid).get("remaining")==1 and row.get("units_consumed")==1 and row.get("source_buff_class_id")==27 and not w.player.is_poisoned(),"debit and exact cure record survive disk reload")
	w.queue_free();await process_frame
