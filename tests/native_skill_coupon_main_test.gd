extends SceneTree
## Exercise a genuine failed ordinary skill-book merge, the focused physical
## coupon, both results, write failure and disk restart with the pinned pack.
const RAW = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SKILL = preload("res://scripts/tj/skill_retry523.gd")
const CORE = preload("res://scripts/tj/coupon_service.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const WINDOW = preload("res://scripts/ui/original_ui/source_main_tj_retry_window.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const COUPON := 326122
const ITEM := "326122"
const SKILL_ITEMS := [213901,222931,244582,267868,289082,307581,326122,325523,338523,359683]
var w: Node
var checks := 0
var failures: Array[String] = []
var rejected := {}

func ck(ok: bool, msg: String) -> bool:
	checks+=1
	if not ok:
		failures.append(msg)
		printerr("SKILL_COUPON_MAIN_FAIL ",msg)
	return ok

func refuse(_path: String, payload: Dictionary) -> Error:
	rejected=payload
	return ERR_CANT_CREATE

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var isolated := CORE.new()
	var now := int(Time.get_unix_time_from_system())
	var old_rotation := D.rotate_ended_dates
	var server := {"service_region_code":"KR","world_no":1}
	isolated.definitions={"servers":[{"ServerLimitSetID":732,"ServiceRegionCode":"KR","WorldNo":1},{"ServerLimitSetID":891,"ServiceRegionCode":"KR","WorldNo":201}]}
	D.rotate_ended_dates = false
	ck(SKILL.range_for(isolated,{},202212010500,now,222931,server).is_empty(),"strict expired edition")
	var live := D.source_deadline_unix(202209140500,540)
	var original := SKILL.range_for(isolated,{},202212010500,live,222931,server)
	ck(original.get("start")==D.source_deadline_unix(202207060500,540) and original.get("end")==D.source_deadline_unix(202209070500,540),"published July 6 through September 7 history")
	ck(SKILL.range_for(isolated,{},202212010500,int(original.start)+10,222931,server).is_empty(),"cannot redeem before history collection closes")
	D.rotate_ended_dates = true
	var bounds := SKILL.range_for(isolated,{},202212010500,now,222931,server)
	ck(int(bounds.end)-int(bounds.start)==int(original.end)-int(original.start),"expired rotation preserves published duration")
	var late := SKILL.range_for(isolated,{},202503050500,D.source_deadline_unix(202412110500,540),307581,{"service_region_code":"KR","world_no":201})
	ck(late.get("start")==D.source_deadline_unix(202406192000,540),"Talking Island/Windawood launch boundary")
	ck(SKILL.range_for(isolated,{},12345,now,222931,server).is_empty(),"malformed calendar cannot rotate")
	D.rotate_ended_dates = old_rotation
	var archive := OS.get_environment("TWILIGHT_SKILL_COUPON_DEFINITIONS")
	if not archive.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated save"):
		w=load("res://Main.tscn").instantiate(); root.add_child(w); w.set_process(false); w.save_timer=-100000
		if ck(QA.enter_game(w,"마법사"),"real mage Main"):
			await process_frame
			w.field_population.set_process(false); w.player.set_physics_process(false)
			await exact(archive)
		w.queue_free(); await process_frame
	print("SKILL_COUPON_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func seed_for(success: bool, probability: int) -> int:
	var rng := RandomNumberGenerator.new()
	for value: int in range(1,100000):
		rng.seed=value
		var before := rng.state
		if (rng.randi_range(0,999999)<probability)==success: return before
	return 0

func register(id: int) -> void:
	w.catalog_db["아이템"].append(D.variant_item(D.definition_id(str(id)).get("native_record",{}),1))

func uid_of(id: int) -> String:
	for uid: String in w.item_instances:
		if int(STACK.proof(w,uid).get("receipt",{}).get("item_class_id",0))==id: return uid
	return ""

func merge_failure(book_uid: String, reject_write: bool) -> bool:
	var quote: Dictionary=w.skill_card523_merge_quote(1,{book_uid:8})
	if not ck(quote.get("ok",false),"genuine ordinary merge quoted "+str(quote.get("reason",""))): return false
	w.skill_cards523.rng.state=seed_for(false,int(quote.probability))
	var before: int=w.tj_coupons.core.state.history.size()
	var quantity:=int(STACK.proof(w,book_uid).remaining)
	if reject_write: w.equipment_collections.test_save_writer=refuse
	var result: Dictionary=w.skill_card523_merge_execute(str(quote.token))
	w.equipment_collections.test_save_writer=Callable()
	if reject_write:
		return ck(not result.ok and w.tj_coupons.core.state.history.size()==before and int(STACK.proof(w,book_uid).remaining)==quantity and rejected.get(CORE.KEY,{}).get("history",[]).size()==before+1,"failed ordinary merge write keeps material and recorded history together")
	return ck(result.ok and not result.success and w.tj_coupons.core.state.history.size()==before+1,"successful write records actual failure exactly once")

func exact(archive: String) -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive); RAW.reset()
	w.skill_awakening=w.SKILL_AWAKENING.new(); w.skill_awakening.configure(w)
	if not ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA and w.tj_coupons.load_default_source(),"verified original inputs"): return
	var runtime: Object=w.tj_coupons
	var core: Object=runtime.core
	var ctx:=SKILL.context(w)
	for id: int in SKILL_ITEMS:
		var entry: Dictionary=core.definitions.coupons[str(id)]
		ck(WINDOW.physical_route(entry)=={"kind":"skill_fusion","category":"스킬"} and runtime.skill_coupon(str(id)),"verified route "+str(id))
		if id!=325523: ck(core.resolve(str(id),ctx,core.clock()).get("ok",false),"server and dated edition "+str(id))
	var books: Dictionary=w.skill_cards523._book_items()
	if not ck(books.has(14991),"original ice spike physical book"):return
	var input:=int(books[14991])
	register(input);register(COUPON)
	for card: Dictionary in w.skill_cards523.merge_candidates(4): register(int(card.item_class_id))
	w._index_catalog_item_sources()
	var staged: Dictionary=INV.stage(w,[{"item_class_id":input,"amount":24,"bless_raw":1,"enchant":0},{"item_class_id":COUPON,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(staged.get("ok",false) and w._save_game(true,staged.overrides)==OK,"physical grants saved: "+str(staged.get("error",""))):return
	w.inventory=staged.overrides.inventory;w.item_instances=staged.overrides.item_instances
	var book_uid:=uid_of(input);var coupon_uid:=uid_of(COUPON)
	if not ck(not book_uid.is_empty() and not coupon_uid.is_empty(),"UID proofs for book and coupon"): return
	ck(runtime.skill_candidates(ITEM).get("events",[]).is_empty(),"no history yields no free attempt")
	if not merge_failure(book_uid,true) or not merge_failure(book_uid,false):return
	var view: Dictionary=runtime.skill_candidates(ITEM)
	if not ck(view.get("events",[]).size()==1 and view.skill_window.model=="offline_season_rotation","failed event eligible under its own server window"):return
	var event: Dictionary=view.events[0]
	var rev:=int(core.state.revision)
	ck(core.candidates(ITEM,{"world_no":999999,"service_region_code":"KR"},core.clock()).get("events",[]).is_empty(),"a different world has no claim")
	var previous_job: String=w.job_class
	w.job_class="기사"
	ck(runtime.skill_candidates(ITEM).events.is_empty() and not runtime.redeem(ITEM,event.id,rev,[],[],coupon_uid).ok,"wrong character class cannot retry")
	w.job_class=previous_job
	ck(not runtime.redeem(ITEM,event.id,rev,["1"],[],coupon_uid).ok and not runtime.redeem(ITEM,event.id,rev,[],[],"missing").ok,"unearned result selection and stale physical reference refused")
	var info: Dictionary=w.item_instances[coupon_uid]
	var lock_ref := str(info.name)+"@@@"+coupon_uid
	w.ui_preferences.item_locks[lock_ref]=true
	ck(not runtime.redeem(ITEM,event.id,rev,[],[],coupon_uid).ok,"locked coupon kept")
	w.ui_preferences.item_locks.erase(lock_ref)
	var ui_dir:=OS.get_environment("TWILIGHT_SKILL_COUPON_UI")
	if not ui_dir.is_empty():
		var pack=PACK.new()
		var digest:=FileAccess.get_sha256(ui_dir.path_join("original_ui.json"))
		var window=WINDOW.new()
		if ck(pack.open(ui_dir,digest).get("ok",false) and window.configure(pack,w.hud).get("ok",false),"verified original recovery pack"):
			var opened: Dictionary=window.open(w.hud,"","",ITEM,coupon_uid)
			ck(opened.get("member","")==WINDOW.SKILL_COMPOSE and int(opened.get("filled",{}).get("grades",-1))==1,"actual original skill window and grade button")
			ck(not window._grade(5).ok and window._grade(4).get("quoted","")=="tj_coupons.redeem" and runtime.bag_count(ITEM,coupon_uid)==2,"only available grade opens confirmation without payment")
			window.close()
	w.hud.inventory_item_activated.emit(str(info.name)+"@@@"+coupon_uid)
	ck(runtime.bag_count(ITEM,coupon_uid)==2 and not core.state.used.has(event.id),"actual bag activation preserves coupon until confirming")
	core.state["rng_state"]=str(seed_for(true,10000))
	if not ck(w._save_game(true)==OK,"durable before retry"):return
	var durable:=FileAccess.get_sha256(w.save_path())
	w.equipment_collections.test_save_writer=refuse
	var result: Dictionary=runtime.redeem(ITEM,event.id,rev,[],[],coupon_uid)
	w.equipment_collections.test_save_writer=Callable()
	ck(not result.ok and FileAccess.get_sha256(w.save_path())==durable and runtime.bag_count(ITEM,coupon_uid)==2 and not core.state.used.has(event.id) and rejected.get(CORE.KEY,{}).get("used",{}).has(event.id),"rejected retry write leaves coupon, result, history and bytes unchanged")
	result=runtime.redeem(ITEM,event.id,rev,[],[],coupon_uid)
	if not ck(result.ok and result.success and runtime.bag_count(ITEM,coupon_uid)==1 and not uid_of(int(result.result.item_class_id)).is_empty(),"successful retry issues one eligible physical skill book: "+str(result)):return
	ck(not runtime.redeem(ITEM,event.id,rev,[],[],coupon_uid).ok,"duplicate confirmation kept")
	if not merge_failure(book_uid,false):return
	var event2: Dictionary=runtime.skill_candidates(ITEM).events[0]
	core.state["rng_state"]=str(seed_for(false,10000))
	result=runtime.redeem(ITEM,event2.id,int(core.state.revision),[],[],coupon_uid)
	ck(result.ok and not result.success and runtime.bag_count(ITEM,coupon_uid)==0 and core.state.receipts.size()==2 and core.state.receipts.back().card=="","failed retry gives no book and spends its own second coupon")
	w._load_game(true)
	ck(runtime.core.state.used.size()==2 and runtime.core.state.history.size()==2 and runtime.bag_count(ITEM)==0 and runtime.skill_candidates(ITEM).events.is_empty(),"restart preserves both receipts and prevents reuse")
