extends SceneTree
## Actual Main: original Life-listed selectors require the same physical
## lifetime at opening and at claim. Keep failures out of source payout.
const RAW=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const PROJ=preload("res://scripts/loot/current523_native_item_projection.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const LIFE={189834:86400,353592:259200}
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("TIMED_SELECTION_MAIN_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	ck(PROJ.exact_selection_life({"original_item":{"ID":189834},"category":{"Name":"LuckyBag"},"item_bonus":[]})==0,"no blanket lifetime adapter for other bags")
	var source:String=OS.get_environment("TWILIGHT_TIMED_SELECTION_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated file"):
		await exact(source)
	print("TIMED_SELECTION_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

static func record(id:int)->Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"actual Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);RAW.reset()
	ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA,"pinned original source")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	for item_id:int in LIFE:
		var i:Dictionary=record(item_id)
		var p:Dictionary=STACK.profile(i)
		var spec:Dictionary=p.get("spec",{})
		var expected:int=LIFE[item_id]
		if not ck(p.get("kind")=="selection" and spec.get("source_owned_lifetime_seconds")==expected and not spec.get("rewards",[]).is_empty(),"actual exact original selector lifetime "+str(item_id)+" / "+str(spec.get("blocked_reasons"))):continue
		w.catalog_db["아이템"].append(i)
		for reward:Dictionary in spec.rewards:w.catalog_db["아이템"].append(record(int(reward.item_class_id)))
		w._index_catalog_item_sources()
		if not ck(INV.commit(w,[{"item_class_id":item_id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"qa_timed_select"}),"original physical source supply "+str(item_id)):continue
		var uid:String=""
		for key:String in w.item_instances:
			var proof:Dictionary=STACK.proof(w,key)
			if not proof.is_empty() and proof.receipt.item_class_id==item_id:uid=key;break
		if not ck(not uid.is_empty(),"obtained exact physical selector"):continue
		var ref:String=str(i.name)+"@@@"+uid
		w.item_life523.sync()
		w.item_life523.state.acquired[uid]=int(Time.get_unix_time_from_system())-expected
		w.hud.inventory_item_activated.emit(ref)
		ck(not w.hud.has_meta("patch523_reward_choice") and w.hud.message_label.text.contains("수명") and STACK.proof(w,uid).get("remaining")==1,"expired copy cannot open even before the next lifecycle sweep")
		w.item_life523.state.acquired[uid]=int(Time.get_unix_time_from_system())
		w.hud.inventory_item_activated.emit(ref)
		var dialog:Control=w.hud.get_meta("patch523_reward_choice") if w.hud.has_meta("patch523_reward_choice") else null
		if not ck(is_instance_valid(dialog) and dialog.choices.item_count>0,"fresh same selector opens original eligible choices: "+w.hud.message_label.text):continue
		var entity:int=int(dialog.choices.get_item_metadata(0))
		var chosen:Dictionary={}
		for r:Dictionary in spec.rewards:
			if r.source_entity_id==entity:chosen=r;break
		if not ck(not chosen.is_empty(),"UI row is the exact original entity"):continue
		var output:Dictionary=record(int(chosen.item_class_id))
		var now:int=int(Time.get_unix_time_from_system())
		w.item_life523.state.acquired[uid]=now-expected
		ck(not dialog.claim_entity(entity) and dialog.last_claim.get("reason","").contains("수명") and STACK.proof(w,uid).get("remaining")==1,"expiry between opening and confirmation cannot claim any output")
		w.item_life523.state.acquired[uid]=now
		var count:int=int(w.inventory.get(output.name,0))
		var rng:int=w.rng.state
		ck(dialog.claim_entity(entity) and dialog.last_claim.get("consumed")==1 and int(w.inventory.get(output.name,0))==count+int(chosen.amount) and not w.item_instances.has(uid) and w.rng.state==rng,"one selected source output, one exact physical debit, no reroll: "+str(dialog.last_claim.get("reason","")))
		await process_frame
		w._load_game(true)
		ck(int(w.inventory.get(output.name,0))==count+int(chosen.amount) and not w.item_instances.has(uid),"debit and whole exact output survive file reload")
	w.queue_free();await process_frame
