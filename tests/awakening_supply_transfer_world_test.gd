extends SceneTree
## Focused real Main transfer contract; source grants are explicit test inputs.
const QA=preload("res://tests/qa_class_selection.gd")
const S=preload("res://scripts/cards/native_awakening_supply.gd")
const G=preload("res://scripts/loot/patch523_item_inventory.gd")
var world: Node
var checks: int=0
var errors: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	print("SUPPLY_TRANSFER_CHECK ",checks," ",label," ",ok)
	if not ok:errors.append(label);push_error(label)
func state_hash() -> int:return hash(JSON.parse_string(JSON.stringify([world.inventory,world.item_instances,world.warehouse.snapshot()])))
func uid_for(id: int) -> String:
	for uid: String in world.item_instances:
		if S.proof(world,uid,id).get("ok",false):return uid
	return ""
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if OS.get_environment("TWILIGHT_SUPPLY_TRANSFER_ISOLATED")!="1":push_error("Explicit isolated profile required");quit(2);return
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.field_population.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false)
	for frame: int in range(6):await process_frame
	check(QA.enter_game(world) and not world.map_bootstrap_blocked,"actual Main and pinned map start")
	if world.map_bootstrap_blocked:finish();return
	check(G.commit(world,[{"item_class_id":75184,"amount":3,"bless_raw":1,"enchant":0},{"item_class_id":3252,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"focused_transfer_input"}),"actual source supplier creates typed stacks")
	var uid: String=uid_for(75184);var coin: String=uid_for(3252)
	if uid.is_empty() or coin.is_empty():check(false,"typed inputs present");finish();return
	var book: Dictionary=world.item_instances[uid].record.duplicate(true);var name_value: String=book.name
	var before: int=state_hash();var disk: String=FileAccess.get_sha256(world.save_path())
	world.ui_preferences.item_locks[name_value]=true
	world._warehouse_transfer(name_value,1,"deposit",uid)
	check(state_hash()==before,"global name lock prevents source book deposit")
	world.ui_preferences.item_locks.erase(name_value)
	world.source_save_blocked=true;world._warehouse_transfer(name_value,1,"deposit",uid);world.source_save_blocked=false
	check(state_hash()==before and FileAccess.get_sha256(world.save_path())==disk,"failed warehouse save preserves physical quantity and disk")
	world._warehouse_transfer(name_value,1,"deposit",uid)
	check(world.item_instances[uid].source_awakening_quantity==2 and S.available(world,75184)==2 and world.warehouse.instances.size()==1,"warehouse deposit splits one unit and retains original remainder ID")
	var stored: String=world.warehouse.instances.keys()[0];var physical: Dictionary=world.warehouse.instances[stored].duplicate(true)
	check(stored!=uid and physical.record==book and physical.source_awakening_quantity==1,"warehouse retains original record and provenance under unique split ID")
	world._warehouse_transfer(name_value,1,"withdraw",stored)
	check(world.item_instances.get(stored,{})==physical and world.warehouse.instances.is_empty() and S.available(world,75184)==3,"withdraw restores exact stored identity and usable source quantity")
	before=state_hash();world._warehouse_transfer(str(world.item_instances[coin].name),1,"deposit",coin)
	check(state_hash()==before,"source non-storable coin cannot become an anonymous warehouse stack")
	check(world._drop_inventory_reference(name_value+"@@@"+uid,world.player.global_position),"actual floor transfer splits one source book")
	check(world.item_instances[uid].source_awakening_quantity==1 and S.available(world,75184)==2,"floor split preserves original stack remainder")
	await create_timer(1.0).timeout
	var collected: bool=false
	for view: Button in world.ground_loot.views.values():
		if world.ground_loot.valid_view(view):collected=world._collect_ground_drop(view);break
	check(collected and S.available(world,75184)==3,"actual pickup restores physical source provenance without increasing total")
	check(world._save_game(true)==OK,"transferred source stacks save through actual writer")
	var previous: int=state_hash();world._load_game(true)
	check(state_hash()==previous and S.available(world,75184)==3 and S.available(world,3252)==2,"actual reload preserves physical IDs, quantities and source usability")
	check(G.commit(world,[{"item_class_id":365748,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"focused_scroll_input"}),"native unlock supplied for quickslot contract")
	var unlock_uid: String=uid_for(365748)
	world.consumable_service.try_use(str(world.item_instances[unlock_uid].name),unlock_uid)
	var chosen: String="source:m508:98:20548"
	world.card_draw_fusion.owned["성물"][chosen]=true
	check(world.option_awakening.select_relic_subslot(chosen).ok and not world.option_awakening.relic_subslot_view().active,"new unlock and selection without a proven scroll grant no effects")
	check(G.commit(world,[{"item_class_id":365758,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"focused_scroll_input"}),"native unlimited scroll supplied")
	var scroll_uid: String=uid_for(365758);var scroll_name: String=world.item_instances[scroll_uid].name
	check(world._quickslot_registration_error("item",scroll_name).is_empty(),"existing quickslot registration accepts exact proven scroll")
	world._use_quickslot_item(scroll_name)
	check(world.option_awakening.relic_subslot_view().active and S.available(world,365758)==1,"existing manual quickslot activates source slot11 and retains scroll")
	world.quickslots[0]={"kind":"item","id":scroll_name,"auto":true}
	check(world._quickslot_auto_allowed(world.quickslots[0]),"existing quickslot auto setting is available")
	var timer_key: String=world.option_awakening.RELIC_SUMMON_TIME
	world.option_awakening.progress[timer_key].expires_utc=int(Time.get_unix_time_from_system())+20
	var deadline: int=world.option_awakening.progress[timer_key].expires_utc
	world.auto_item_clock=0;world._run_auto_item_quickslots(.2)
	check(world.option_awakening.progress[timer_key].expires_utc==deadline,"automatic use waits outside source5000ms overlap")
	world.option_awakening.progress[timer_key].expires_utc=int(Time.get_unix_time_from_system())+4
	deadline=world.option_awakening.progress[timer_key].expires_utc
	world.source_save_blocked=true;world.auto_item_clock=0;world._run_auto_item_quickslots(.2);world.source_save_blocked=false
	check(world.option_awakening.progress[timer_key].expires_utc==deadline and S.available(world,365758)==1,"automatic refresh save failure preserves timer and unlimited scroll")
	world.auto_item_clock=0;world._run_auto_item_quickslots(.2)
	check(int(world.option_awakening.progress[timer_key].expires_utc)>int(Time.get_unix_time_from_system())+1790 and S.available(world,365758)==1,"automatic refresh applies source1800seconds at source5second threshold without debit")
	world.ui_preferences.item_locks[scroll_name]=true
	check(not world.option_awakening.source_scroll_supported(scroll_name),"global scroll lock prevents manual and automatic source support")
	world.ui_preferences.item_locks.erase(scroll_name)
	check(world._save_game(true)==OK,"refreshed timer and quickslot save together")
	deadline=world.option_awakening.progress[timer_key].expires_utc;world._load_game(true)
	check(int(world.option_awakening.progress[timer_key].expires_utc)==deadline and world.quickslots[0].get("auto",false) and S.available(world,365758)==1,"actual reconnect retains refreshed timer, auto choice and exact scroll")
	finish()
func finish() -> void:
	print("AWAKENING_SUPPLY_TRANSFER_WORLD ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_PHYSICAL_TRANSFER; FIXTURE_SUPPLIER_INPUT"}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if errors.is_empty() else 1)
