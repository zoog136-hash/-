extends SceneTree
## Exercise the four unchanged original buff graphs and two current exact
## inventory receipts through Main. Expired event items keep their deadlines.
const RAW=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const SOURCE_IDS=[258463,258483,269008,281361,289134,296348,299802,304748,315113,322478,325832,330014,339173,347208,351351,359153,365874,284628,303098,329328,363558,306601,310574,344364]
const LIVE_IDS=[258463,306601]
var failures:Array[String]=[]
var checks:int=0
var rejected:Dictionary={}
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("GROWTH_ADENA_MAIN_FAIL ",label)
	return ok
func refuse(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func _initialize()->void:run.call_deferred()
func run()->void:
	preload("res://tests/native_growth_deadline_cases.gd").clock_cases(ck)
	var source:String=OS.get_environment("TWILIGHT_GROWTH_ADENA_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main file"):
		await exact(source)
	else:
		ck(SOURCE_IDS.size()==24 and not SOURCE_IDS.has(193431),"separate exploration-loot probability contract is excluded")
	print("GROWTH_ADENA_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

static func item(id:int)->Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func kill(w:Node, expected_growth:int)->bool:
	var target:TwilightMonster=w.MONSTER_SCENE.instantiate();root.add_child(target)
	target.monster_name="source-potency-fixture"
	target.set_process(false);target.set_physics_process(false)
	target.gold_reward=100;target.exp_reward=0;target.dead=true;target.drop_items.clear()
	var before:int=w.gold
	var expected:int=int(round(100.0*w.ain_service.adena_rate()*(1.0+clampf(w._equipped_numeric_sum("adena_drop_pct"),0,500)/100.0)*(1.0+float(expected_growth)/100.0)))
	w._on_monster_died(target)
	var actual:int=w.gold-before
	var rewarded:int=w.gold
	w._on_monster_died(target)
	if is_instance_valid(target):target.queue_free()
	return ck(actual==expected and w.gold==rewarded,"actual NPC Adena factor +%d%% and one reward; actual %d expected %d" % [expected_growth,actual,expected])

func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);RAW.reset()
	ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA,"released exact source")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var requests:Array=[]
	for id:int in SOURCE_IDS:
		var record:Dictionary=item(id)
		var spec:Dictionary=FIELDS.full(record).get("source_use_spec",{})
		var typed:Dictionary=spec.get("typed_effects",{})
		var group:Dictionary=spec.get("source_buff_group",{})
		var expects_xp:int=700 if id in [284628,303098,329328,363558] else 500
		ck(typed.get("source_npc_adena_drop_pct")==20 and typed.get("xp")==expects_xp and group.get("ID")==2903 and group.get("IsAllowOverlap")==false,"exact 20 percent / preserved XP / nonstacking 2903 for "+str(id)+": "+str(spec.get("blocked_reasons",[])))
		if id not in LIVE_IDS:continue
		if not ck(STACK.profile(record).get("kind")=="buff" and D.deadline_problem(FIELDS.full(record)).is_empty(),"current use path active "+str(id)):continue
		w.catalog_db["아이템"].append(record)
		requests.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	var unknown:Dictionary=FIELDS.full(item(193431)).get("source_use_spec",{})
	ck(unknown.get("activation_status")=="blocked" and "conditional_buff_effect:NpcItemDropProbabilityMultiple" in unknown.get("blocked_reasons",[]) and not unknown.get("typed_effects",{}).has("source_npc_adena_drop_pct"),"does not enable exploration scroll or its 39 unimplemented loot selectors")
	w._index_catalog_item_sources()
	kill(w,0)
	if not ck(requests.size()==2 and INV.commit(w,requests,{"kind":"qa_growth_adena"}),"two exact physical growth potion supplies"):
		w.queue_free();await process_frame;return
	var refs:Dictionary={}
	for uid:String in w.item_instances:
		var proof:Dictionary=STACK.proof(w,uid)
		if proof.get("receipt",{}).get("item_class_id") in LIVE_IDS:refs[int(proof.receipt.item_class_id)]=[str(proof.record.name),uid]
	if not ck(refs.size()==2,"separate receipt for each growth potion"):
		w.queue_free();await process_frame;return
	for id:int in LIVE_IDS:
		var name:String=refs[id][0];var uid:String=refs[id][1];var ref:String=name+"@@@"+uid
		if id==258463:
			ck(w._save_game(true)==OK,"durable pre-use save")
			var before:String=FileAccess.get_sha256(w.save_path())
			w.equipment_collections.test_save_writer=refuse
			w.hud.inventory_item_activated.emit(ref)
			ck(not rejected.get("inventory",{}).has(name) and not rejected.get("active_item_buffs",{}).is_empty(),"failed writer received combined debit and buff candidate: "+w.hud.message_label.text)
			ck(w.inventory.get(name)==1 and w._active_item_buff_total("source_npc_adena_drop_pct")==0 and FileAccess.get_sha256(w.save_path())==before,"failed writer leaves item, buff and bytes unchanged")
			w.equipment_collections.test_save_writer=Callable()
			w._load_game(true)
		else:
			var before:String=FileAccess.get_sha256(w.save_path())
			w.hud.inventory_item_activated.emit(ref)
			ck(w.hud.message_label.text.contains("함께 사용할 수 없는") and STACK.proof(w,uid).get("remaining")==1 and FileAccess.get_sha256(w.save_path())==before,"original conflicting group refuses the other potion without debit")
			expire(w)
		w.hud.inventory_item_activated.emit(ref)
		ck(not w.item_instances.has(uid) and w._active_item_buff_total("source_npc_adena_drop_pct")==20 and w._active_item_buff_total("xp")==500,"actual bag action activates nonstacking source effect "+str(id)+": "+w.hud.message_label.text)
		w._load_game(true)
		ck(not w.item_instances.has(uid) and w._active_item_buff_total("source_npc_adena_drop_pct")==20,"physical debit plus source buff survive disk reload "+str(id))
		kill(w,20)
	expire(w)
	ck(w._active_item_buff_total("source_npc_adena_drop_pct")==0,"normal expiration stops temporary boost")
	kill(w,0)
	preload("res://tests/native_growth_deadline_cases.gd").from_bag(w,ck)
	w.queue_free();await process_frame

static func expire(w:Node)->void:
	for buff:Dictionary in w.active_item_buffs.values():
		if buff.has("absolute_until"):buff.absolute_until=0
	w._tick_item_buffs(10000000.0)
