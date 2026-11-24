extends SceneTree
const RULE=preload("res://scripts/cards/source_fusion_points523.gd")
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
const CARD_SOURCE=preload("res://scripts/cards/current523_card_catalog.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const WINDOW_KIT=preload("res://scripts/ui/original_ui/source_main_window_kit.gd")
const FIRST:=146442
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
var completed:bool=false
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);printerr("NATIVE_FUSION_POINTS_FAIL ",message)
	return ok
func _initialize()->void:run.call_deferred()
func reject(_path:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE

func run()->void:
	var legacy:=CARDS.new()
	legacy.configure({})
	legacy.pity["변신"]["희귀"]=19
	ck(legacy.export_state().pity["변신"]["희귀"]==19 and not legacy.original_points_active("변신","희귀"),"legacy accrued points are not recategorized before an original action")
	ck(legacy.credit_original_points("변신","희귀"),"original 20th point remains pending, not a draw")
	ck(not legacy.credit_original_points("변신","희귀") and legacy.pity["변신"]["희귀"]==20,"cap forbids extra spend")
	legacy.import_state(JSON.parse_string(JSON.stringify(legacy.export_state())))
	ck(legacy.original_points_active("변신","희귀") and legacy.pity["변신"]["희귀"]==20 and not legacy.fuse("변신","희귀").get("ok",false),"source pending reload kept precisely even without original tables")
	ck(RULE.choose([{"chance":58000,"source_id":85},{"chance":942000,"source_id":86}],57999).source_id==85 and RULE.choose([{"chance":58000,"source_id":85},{"chance":942000,"source_id":86}],58000).source_id==86 and RULE.choose([],1000000).is_empty(),"source million-point intervals are half-open and never rerolled")
	normal_fusion()
	var path:String=OS.get_environment("TWILIGHT_NATIVE_FUSION_POINT_DEFINITIONS")
	if not path.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main"):
		await main(path)
		ck(completed,"Main finished the entire controlled test")
	print("NATIVE_FUSION_POINTS_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func normal_fusion()->void:
	var engine:=CARDS.new()
	engine.configure({"변신":[{"name":"R","grade":"희귀","sourceId":"qa-rare"},{"name":"H","grade":"영웅","sourceId":"qa-hero"}]})
	engine.owned["변신"]["source:qa-rare"]=true;engine.spare["변신"]["source:qa-rare"]=8
	engine.pity["변신"]["희귀"]=19
	var probe:=RandomNumberGenerator.new()
	for seed_value:int in range(100):
		probe.seed=seed_value
		if probe.randi_range(0,9999)>=CARDS.FUSION_WEIGHTS["희귀"]:
			engine.rng.seed=seed_value
			break
	var fused:Dictionary=engine.fuse_many("변신","희귀",2,true)
	ck(fused.get("attempts")==1 and fused.get("success_count")==0 and fused.get("pity_progress")==20 and fused.get("results",[]).size()==1,"normal failed batch pauses at 20 without an automatic extra award")
	ck(engine.total_count("변신","source:qa-rare")==6 and not engine.owned["변신"].has("source:qa-hero"),"only one ordinary set of four spare materials was spent, with the existing same-tier result")
	ck(engine.claim_original_points("변신","희귀") and engine.pity["변신"]["희귀"]==0 and not engine.claim_original_points("변신","희귀"),"manual claim model resets immediately and cannot repeat")

func tap(point:Vector2)->void:
	for pressed:bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=9;event.pressed=pressed;event.position=point
		root.push_input(event,true)

func use(h:Node,ref:String)->void:
	var bag:Control=h.lineage_inventory_ui
	var native:bool=h.original_inventory_is_open()
	var control:Variant=h.original_main_ui_controller._inventory_view._hits.get(ref,{}).get("control") if native else bag.slot_buttons.get(ref)
	if not ck(control is Control and is_instance_valid(control),"actual visible inventory reference "+ref):return
	var point:Vector2=control.get_global_transform_with_canvas()*(control.size*0.5)
	bag.disarm_item_action()
	tap(point)
	ck(bag.item_action_label(ref)=="사용","exact usable action is visible")
	tap(point)

func main(path:String)->void:
	root.size=Vector2i(1280,720)
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);current_scene=w;w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"entered actual Main")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",path);SRC.reset()
	ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"verified original definition archive")
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var catalog:Dictionary=CARD_SOURCE.build()
	if not ck(catalog.get("ready",false),"normal production projection of exact original card catalog "+str(catalog.get("problem",""))):w.queue_free();return
	for category:String in RULE.DECKS:w.catalog_db[category]=catalog.catalog[category]
	w.card_draw_fusion.configure(w.catalog_db)
	var cards:RefCounted=w.card_draw_fusion;var h:Node=w.hud
	var light_begin:int=Time.get_ticks_usec()
	for category:String in RULE.DECKS:
		for grade:String in RULE.GRADES:
			ck(w.source_fusion_progress(category,grade).get("source",false),"original UI using the narrow threshold "+category+" "+grade)
	print("FUSION_POINT_THRESHOLD_ALL_US ",Time.get_ticks_usec()-light_begin)
	var raw_count:int=0;var ready_count:int=0
	for category:String in RULE.DECKS:
		for grade:String in RULE.GRADES:
			var start:int=Time.get_ticks_usec()
			var lane:Dictionary=RULE.source_lane(category,grade);var pool:Dictionary=RULE.reward(w,category,grade)
			ck(not lane.is_empty(),"raw payment/SKU exact lane "+category+" "+grade)
			if not lane.is_empty():raw_count+=1
			if pool.get("ok",false):ready_count+=1
			print("FUSION_POINT_LANE ",category," ",grade," raw=",not lane.is_empty()," ready=",pool.get("ok",false)," us=",Time.get_ticks_usec()-start)
	ck(raw_count==9 and ready_count==9,"all exact weighted reward lanes have installed playable owners "+str(ready_count))
	var grant:Array=[]
	for id:int in RULE.SCROLLS.keys()+RULE.NO_REWARD_LANE:
		var record:Dictionary=w.source_item_definition(id).get("native_record",{})
		if id in RULE.NO_REWARD_LANE:
			ck(RULE.profile(record,w.source_item_definition(id)).is_empty(),"no current spell-card reward policy for exact "+str(id))
			continue
		w.catalog_db["아이템"].append(record)
		ck(STACK.profile(record).get("kind")=="fusion_points","exact use profile "+str(id)+" / "+str(record.get("slot","")))
		grant.append({"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0})
	w._index_catalog_item_sources()
	var supplied:Dictionary=INV.stage(w,grant,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(supplied.get("ok",false),"all eight exact physical scroll supplies "+str(supplied.get("error",""))):w.queue_free();return
	w.inventory=supplied.overrides.inventory;w.item_instances=supplied.overrides.item_instances
	var uids:Dictionary={};var refs:Dictionary={}
	for uid:String in w.item_instances:
		var entry:Dictionary=w.item_instances[uid];var id:int=int(entry.get("record",{}).get("source_item_class_id",0))
		if RULE.SCROLLS.has(id):uids[id]=uid;refs[id]=str(entry.name)+"@@@"+uid
	if not ck(uids.size()==8,"exact eight physical receipt IDs"):w.queue_free();return
	# Seed an already-earned 19 legacy failures; new mode preserves, not resets.
	var grade:String="희귀";var category:String="변신";cards.pity[category][grade]=19
	if not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty() and not is_instance_valid(h.original_main_ui_controller):h._bind_selected_original_main_ui()
	w._update_hud();h.refresh_inventory(w.inventory);h.toggle_inventory()
	await process_frame
	ck(h.original_inventory_is_open()==not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty(),"correct real bag surface")
	ck(w._save_game(true)==OK,"baseline exact save")
	var previous:String=FileAccess.get_sha256(w.save_path())
	w.equipment_collections.test_save_writer=reject
	use(h,refs[FIRST])
	ck(rejected.get("card_draw_fusion",{}).get("pity",{}).get(category,{}).get(grade)==20 and rejected.get("item_instances",{}).get(uids[FIRST],{}).get(STACK.QUANTITY)==1,"durable candidate is item debit plus one point")
	ck(cards.pity[category][grade]==19 and STACK.proof(w,uids[FIRST]).get("remaining")==2 and FileAccess.get_sha256(w.save_path())==previous,"write failure has no visible effect or loss")
	w.equipment_collections.test_save_writer=Callable()
	use(h,refs[FIRST])
	ck(cards.pity[category][grade]==20 and STACK.proof(w,uids[FIRST]).get("remaining")==1 and cards.source_card_receipts.is_empty(),"actual used scroll adds one point without receiving a card")
	use(h,refs[FIRST])
	ck(cards.pity[category][grade]==20 and STACK.proof(w,uids[FIRST]).get("remaining")==1,"20th point cannot silently spend a second scroll")
	w._load_game(true)
	ck(cards.pity[category][grade]==20 and cards.original_points_active(category,grade),"save/reload carries exactly 20 and original provenance")
	for id:int in RULE.SCROLLS:
		if id==FIRST:continue
		h.inventory_item_activated.emit(refs[id])
		var sc:Array=RULE.SCROLLS[id]
		var lane:Dictionary=cards.pity[RULE.DECKS.find_key(sc[0])]
		ck(lane.get(RULE.GRADES.find_key(sc[1]))==1 and STACK.proof(w,uids[id]).get("remaining")==1,"production bag dispatch credits exact lane for "+str(id)+" "+str(h.message_label.text))
	var untouched_rng:int=cards.rng.state
	var pending_hash:String=FileAccess.get_sha256(w.save_path())
	w._on_card_fusion_requested(category,grade)
	ck(cards.pity[category][grade]==20 and cards.rng.state==untouched_rng and FileAccess.get_sha256(w.save_path())==pending_hash,"ordinary fusion can't bypass the pending claim")
	h.open_card_fusion(category)
	await process_frame
	var native:bool=not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty()
	var button:Variant
	var controller:Node=h.original_main_ui_controller if native else null
	if native:
		var view:Variant=h.original_main_ui_controller._feature_windows.get("card_fusion")
		if not ck(view!=null and view.is_open(),"real original fusion window"):w.queue_free();return
		view._select_filter(grade)
		var located:Dictionary=WINDOW_KIT._locate(view._scene,view._out,"Nd_Mileage_Reward/Btn_Reward")
		if located.get("ok",false):
			var node:Variant=located.player.source_nodes.get(located.offset)
			button=node.get_meta("source_button",null) if is_instance_valid(node) else null
	else:
		h.card_fusion_view._select_grade(grade,false)
		button=h.card_fusion_view._point_reward
	if not ck(is_instance_valid(button) and button.is_visible_in_tree(),"real 보상 받기 UI row is visible at 20 points"):
		w.queue_free();return
	var drawn_before:Dictionary=cards.export_state()
	var wallet_before:Array=[w.inventory.get("마일리지",0),w.inventory.get("다이아",0),w.gold]
	rejected.clear()
	w.equipment_collections.test_save_writer=reject
	trigger(button,controller)
	ck(rejected.get("card_draw_fusion",{}).get("pity",{}).get(category,{}).get(grade)==0 and rejected.get("card_draw_fusion",{}).get("source_card_receipts",[]).size()==1,"actual claim writer candidate contains precise reset and one original reward")
	ck(cards.export_state()==drawn_before and cards.rng.state==untouched_rng and FileAccess.get_sha256(w.save_path())==pending_hash,"refused claim restores RNG, card and points")
	w.equipment_collections.test_save_writer=Callable()
	trigger(button,controller)
	var proof:Dictionary=cards.source_card_receipts.back() if not cards.source_card_receipts.is_empty() else {}
	var pool:Dictionary=RULE.source_lane(category,grade)
	ck(proof.get("purchase_id")==pool.get("offer") and proof.get("pool_id")==222 and cards.pity[category][grade]==0 and cards.source_card_receipts.size()==1,"one exact original no-payment reward is delivered")
	ck([w.inventory.get("마일리지",0),w.inventory.get("다이아",0),w.gold]==wallet_before,"never debits shop mileage, diamonds or Adena")
	w._load_game(true)
	ck(cards.pity[category][grade]==0 and cards.source_card_receipts.size()==1 and not w.claim_source_fusion_reward(category,grade).get("ok",false),"saved reset and one precise receipt prevent replay")
	w.queue_free();await process_frame
	completed=true

func trigger(button:Node,controller:Node)->void:
	var area:Variant=button.get("_input_area") if controller!=null else button
	if not ck(area is Control and area.is_visible_in_tree(),"verified live button touch area"):return
	var point:Vector2=area.get_global_transform_with_canvas()*(area.size*0.5)
	if controller==null:tap(point);return
	for pressed:bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=6;event.pressed=pressed;event.position=point
		controller._input(event)
