extends SceneTree
const Runtime = preload("res://scripts/cards/halphas_star_enchant_runtime.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int=0
var failures: Array[String]=[]
var world: TwilightWorld
const ID: String=Runtime.IDENTITY
class RejectingHost extends Node:
	var catalog_db: Dictionary
	var card_draw_fusion: RefCounted
	var card_collections: RefCounted
	var gold: int
	var equipment_records_dirty: bool=false
	var equipment_effects_dirty: bool=false
	func _save_game(_quiet: bool, _override: Dictionary) -> Error:return ERR_CANT_CREATE
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("HALPHAS_TRANSACTION_FAIL: ",label)
func settle() -> void:
	for i: int in range(4):await process_frame
func tap(button: Button) -> void:
	check(button!=null,"button exists")
	if button==null:return
	var point: Vector2=button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed
		root.push_input(event,true);await process_frame
	await settle()
func button(name_value: String) -> Button:return world.hud.find_child(name_value,true,false)
func scroll_to(control: Control) -> void:
	var scroll: ScrollContainer=world.hud.find_child("HalphasStarEnchantScroll",true,false)
	scroll.ensure_control_visible(control);await settle()
func seed_for(success: bool,threshold: int) -> int:
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(10000):
		probe.seed=seed_value
		if (probe.randi_range(0,999999)<threshold)==success:return seed_value
	return -1
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class entry")
	world.player.set_physics_process(false);world.legacy_population.set_process(false);world.original_population.set_process(false);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
	await settle()
	var runtime: RefCounted=world.halphas_star
	world.gold=100000000;world.card_draw_fusion.owned["변신"][ID]=true;world.card_draw_fusion.spare["변신"][ID]=99
	world.source_card_visual_options["m508:1:24504"]=24
	check(world._save_game(true)==OK,"baseline real atomic save")
	var path: String=world.save_path();var before: String=FileAccess.get_sha256(path)
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not runtime.settings.offline_enable_despite_native_flag and not runtime.settings.offline_server_override,"production activation overrides remain false")
	check(not runtime.attempt(ID,{ID:1},0,"blocked").ok and FileAccess.get_sha256(path)==before,"economic approval does not bypass technical gate")
	# Explicit isolated fixture: production JSON and native flags remain untouched.
	runtime.settings.offline_enable_despite_native_flag=true;runtime.settings.offline_server_override=true
	for invalid: Dictionary in [{ID:0},{ID:-1},{ID:0.5},{ID:2},{"source:m508:2:25072":1},{"forged":1},{}]:
		var rng_before: int=runtime.rng.state
		check(not runtime.attempt(ID,invalid,0,"invalid").ok and runtime.rng.state==rng_before,"invalid materials preserve RNG and economy "+str(invalid))
	check(not runtime.attempt("source:m508:1:18722",{ID:1},0,"other").ok,"other unique target remains prohibited")
	check(not runtime.attempt(ID,{ID:1},1,"stale").ok,"stale revision rejected")
	# Save failure must not apply a successful roll or advance its RNG.
	var rejected:=RejectingHost.new();rejected.catalog_db=world.catalog_db;rejected.card_draw_fusion=world.card_draw_fusion;rejected.card_collections=world.card_collections;rejected.gold=world.gold
	var isolated:=Runtime.new();isolated.configure(rejected);isolated.settings=runtime.settings.duplicate(true)
	var reject_rng: int=isolated.rng.state;var reject_cards: Dictionary=world.card_draw_fusion.export_state()
	check(isolated.attempt(ID,{ID:1},0,"fail-save").code=="save_failed","failed atomic persistence reported")
	check(isolated.rng.state==reject_rng and isolated.progress.level==0 and rejected.gold==100000000 and world.card_draw_fusion.export_state()==reject_cards,"failed persistence preserves RNG cards gold and level")
	rejected.free()
	# Actual UI: auto-selection, confirmation cancellation, then successful commit.
	world.hud.open_halphas_star_enchant("변신",ID);await settle()
	await scroll_to(button("HalphasAutoSelect"));await tap(button("HalphasAutoSelect"))
	await scroll_to(button("HalphasStarEnchantAttempt"));check(not button("HalphasStarEnchantAttempt").disabled,"fixture UI enables exact selected material")
	await tap(button("HalphasStarEnchantAttempt"));check(button("CancelTransaction")!=null,"confirmation opened by actual input")
	await tap(button("CancelTransaction"));check(FileAccess.get_sha256(path)==before and runtime.progress.level==0,"confirmation cancel preserves bytes and level")
	await tap(button("HalphasStarEnchantAttempt"));await tap(button("ConfirmTransaction"))
	check(runtime.progress.level==1 and world.gold==94500000 and int(world.card_draw_fusion.spare["변신"][ID])==98,"real UI stage1 charges exact source cost and one duplicate")
	check(world.source_card_visual_options["m508:1:24504"]==24,"upgrade does not overwrite legacy cosmetic choice")
	var status: Label=world.hud.find_child("HalphasStarEnchantStatus",true,false)
	check(status!=null and status.text.contains("성공") and status.text.contains("5500000"),"success cost and earned level shown")
	var replay: Dictionary=runtime.attempt(ID,{ID:1},0,str(runtime.progress.last_operation))
	check(replay.get("replayed",false) and world.gold==94500000,"repeated operation cannot charge twice")
	check(runtime.apply_appearance(ID,int(runtime.progress.revision)).ok and int(world.source_card_visual_options["m508:1:24504"])==4,"explicit earned stage1 appearance saves separately")
	runtime.settings.failure_consumes_material_and_gold=false
	runtime.rng.seed=seed_for(false,666000)
	var free_failure: Dictionary=runtime.attempt(ID,{ID:2},int(runtime.progress.revision),"configured-free-failure")
	check(free_failure.ok and not free_failure.success and world.gold==94500000 and world.card_draw_fusion.spare["변신"][ID]==98 and Runtime.validate(runtime.export_state()).is_empty(),"configurable failure consumption keeps a balanced zero-debit ledger")
	runtime.settings.failure_consumes_material_and_gold=true
	runtime.rng.seed=seed_for(false,666000)
	var result: Dictionary=runtime.attempt(ID,{ID:2},int(runtime.progress.revision),"stage2-failure")
	check(result.ok and not result.success and runtime.progress.level==1 and world.gold==89000000 and world.card_draw_fusion.spare["변신"][ID]==96,"stage2 failure consumes exact material cost and retains level")
	check(world.card_draw_fusion.owned["변신"][ID] and world.source_card_visual_options["m508:1:24504"]==4,"failure preserves permanent card and chosen look")
	runtime.rng.seed=seed_for(true,666000)
	result=runtime.attempt(ID,{ID:2},int(runtime.progress.revision),"stage2-success")
	check(result.ok and result.success and runtime.progress.level==2,"stage2 success persists")
	runtime.rng.seed=seed_for(true,333000)
	result=runtime.attempt(ID,{ID:3},int(runtime.progress.revision),"stage3-success")
	check(result.ok and result.success and runtime.progress.level==3 and world.gold==78000000 and world.card_draw_fusion.spare["변신"][ID]==91,"stage3 exact final economy")
	check(runtime.progress.spent_gold==22000000 and runtime.progress.spent_cards==8 and Runtime.validate(runtime.export_state()).is_empty(),"attempt ledger balances source costs")
	check(not runtime.attempt(ID,{ID:3},int(runtime.progress.revision),"overmax").ok,"maximum stage rejects further debit")
	check(runtime.effects(3).hpFlat==30000 and runtime.effects(3).strFlat==6 and runtime.effects(3).meleeDamage==10,"estimated replacement and carry-forward avoid cumulative inflation")
	world.equipped_catalog["변신"]={};world.equipment_records_dirty=true;world.equipment_effects_dirty=true
	var base_str: int=world._effective_attribute("STR")
	check(runtime.catalog_bonus("strFlat")==0,"unequipped card gives no star bonus")
	world.equipped_catalog["변신"]=runtime._record(ID);runtime.settings.offline_enable_despite_native_flag=false;world.equipment_records_dirty=true;world.equipment_effects_dirty=true
	var base_hp: int=world._effective_max_hp();var base_mp: int=world._effective_max_mp()
	runtime.settings.offline_enable_despite_native_flag=true;world.equipment_records_dirty=true;world.equipment_effects_dirty=true
	check(runtime.active() and world._effective_max_hp()==base_hp+30000 and world._effective_max_mp()==base_mp+30000,"earned equipped HP MP apply once")
	check(world._effective_attribute("STR")>=base_str+6,"earned strength enters actual attribute path")
	check(runtime.catalog_bonus("hp_regen")==3 and runtime.catalog_bonus("damage_reduction_ignore")==60,"recovery and pierce source values retained")
	root.size=Vector2i(960,540)
	world.hud.open_halphas_star_enchant("변신",ID);await settle()
	await scroll_to(button("HalphasApplyAppearance"));await tap(button("HalphasApplyAppearance"))
	check(int(world.source_card_visual_options["m508:1:24504"])==24,"reopened small-screen UI applies earned stage3 appearance")
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var durable_rng: String=durable.halphas_star_enchant.rng_state
	world.gold=1;runtime.progress=Runtime.fresh();runtime.rng.seed=8
	world._load_game(true)
	world.field_population.set_process(false)
	check(world.gold==78000000 and runtime.progress.level==3 and str(runtime.rng.state)==durable_rng,"actual save reload restores gold level and separate RNG")
	check(world.card_draw_fusion.spare["변신"][ID]==91,"reload restores exact duplicate balance")
	for bad_value: Variant in [-1,4,1.5,true]:
		var invalid: Dictionary=durable.duplicate(true);invalid.halphas_star_enchant.level=bad_value
		check(Writer.write(path,invalid)==OK,"write malformed isolated fixture")
		var bad_sha: String=FileAccess.get_sha256(path);world.gold=17
		world._load_game(true)
		world.field_population.set_process(false)
		check(runtime.save_blocked and world.gold==17 and world._save_game(true)!=OK and FileAccess.get_sha256(path)==bad_sha,"invalid star save rejected before mutation and overwrite")
	check(Writer.write(path,durable)==OK,"restore valid isolated fixture")
	var restored_sha: String=FileAccess.get_sha256(path)
	world._load_game(true);world.field_population.set_process(false)
	check(not runtime.save_blocked and world.gold==78000000 and FileAccess.get_sha256(path)==restored_sha,"valid save recovers after blocked load")
	var legacy: Dictionary=baseline.duplicate(true);legacy.erase(Runtime.SAVE_KEY)
	check(Writer.write(path,legacy)==OK,"legacy fixture lacks new progression")
	var legacy_sha: String=FileAccess.get_sha256(path);world._load_game(true)
	world.field_population.set_process(false)
	check(runtime.progress.level==0 and FileAccess.get_sha256(path)==legacy_sha,"legacy load creates zero earned progression without rewriting original")
	check(FileAccess.get_sha256(path+".pre-halphas-"+legacy_sha)==legacy_sha,"exact durable pre-feature backup")
	check(not runtime.apply_appearance(ID,int(runtime.progress.revision)).ok,"legacy cosmetic cannot grant earned appearance rights")
	check(Runtime.POLICY.data.offline_enable_despite_native_flag==false and Runtime.Native.DATA.data.content_control.Enable==false,"isolated fixture never modifies production activation or source")
	print("HALPHAS_STAR_TRANSACTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_ECONOMY_UI_SAVE_WITH_EXPLICIT_ISOLATED_ACTIVATION_FIXTURE"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
