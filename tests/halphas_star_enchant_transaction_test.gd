extends SceneTree
const Runtime = preload("res://scripts/cards/halphas_star_enchant_runtime.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const Positions=preload("res://tests/active_source_test_positions.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const Rules = preload("res://scripts/cards/native_halphas_star_enchant.gd")
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
func conditional_checks(runtime: RefCounted) -> void:
	check(runtime.effects(1).stun_accuracy==40 and runtime.effects(1).stun_resistance==30,"exact source Stun links remain scoped and independently add 30+10")
	check(runtime.effects(2).hold_accuracy==60 and runtime.effects(2).hold_resistance==60 and runtime.effects(2).fear_accuracy==20,"Hold and Fear target identities stay separate")
	check(runtime.effects(3).dark_accuracy==90 and runtime.effects(3).dark_resistance==90 and runtime.effects(3).ice_accuracy==30 and runtime.effects(3).charge_time_reduction_pct==120 and not runtime.effects(3).has("charge_speed"),"Dark Ice and charging retain exact scopes instead of other statuses or dash speed")
	var pending_ids: Array[int]=[]
	for row: Dictionary in Runtime.pending_effects():pending_ids.append(int(row.bonus.ID))
	pending_ids.sort()
	check(pending_ids.is_empty(),"all43 source rows now have native or explicit custom consumers")
	var forged: Dictionary=Runtime.Native.DATA.data.effects[7].duplicate(true)
	forged.application_target.Name="Fear"
	check(Runtime.conditional_key(forged).is_empty(),"target ID and target definition must agree")
	var status: RefCounted=world.original_skills.status
	var dummy: TwilightMonster=load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"할파스 상태 검증 NPC","hp":999999,"lv":world.level,"stun_resistance":20,"hold_resistance":20,"fear_resistance":20,"silence_resistance":20},world.player,world,null)
	dummy.set_physics_process(false)
	var baseline: Dictionary={}
	runtime.settings.offline_enable_despite_native_flag=false;world.equipment_records_dirty=true
	for kind: String in ["stun","hold","fear","silence"]:
		baseline[kind]=status.chance({"status":kind,"status_chance":.2},dummy,world)
	check(is_equal_approx(baseline.stun,.16) and runtime.status_hit_bonus("stun")==0,"native activation gate suppresses conditional combat benefits")
	check(is_equal_approx(status.chance({"status":"stun","status_chance":1.4},dummy,world),1.12),"no-bonus path preserves existing out-of-range fixture probabilities")
	var base_stun: int=world._stun_accuracy_stat();var base_hold: int=world._hold_accuracy_stat();var base_resistance: int=world._stun_resistance_stat()
	runtime.settings.offline_enable_despite_native_flag=true;world.equipment_records_dirty=true
	check(world._stun_accuracy_stat()>=base_stun+40 and world._hold_accuracy_stat()>=base_hold+60 and world._stun_resistance_stat()>=base_resistance+30,"actual legacy outgoing and incoming stat consumers see conditional records")
	check(is_equal_approx(status.chance({"status":"stun","status_chance":.2},dummy,world),.48),"current skill API consumes exact Stun hit points before existing resistance")
	check(is_equal_approx(status.chance({"status":"hold","status_chance":.2},dummy,world),.64) and is_equal_approx(status.chance({"status":"fear","status_chance":.2},dummy,world),.32),"current skill API keeps Hold and Fear scopes")
	check(is_equal_approx(status.chance({"status":"silence","status_chance":.2},dummy,world),baseline.silence),"unrelated silence probability remains unchanged")
	check(is_equal_approx(status.chance({"status":"stun","status_chance":1.4},dummy,world),1.12),"positive earned bonus never lowers an existing over-one fixture probability")
	dummy.is_boss=true
	check(is_equal_approx(status.chance({"status":"stun","status_chance":.2},dummy,world),.48*float(status.rules.boss_chance_factor)),"existing boss resistance factor preserved")
	dummy.is_boss=false
	var chosen_seed: int=-1;var probe:=RandomNumberGenerator.new()
	for value: int in range(1000):
		probe.seed=value;var roll: float=probe.randf()
		if roll>.16 and roll<.48:chosen_seed=value;break
	check(chosen_seed>=0,"deterministic combat roll between base and earned chance")
	var skill: Dictionary={"id":"halphas-status-fixture","status":"stun","status_chance":.2,"duration":2.0}
	var before_gold: int=world.gold;var before_mp: int=world.mp;var cards: Dictionary=world.card_draw_fusion.export_state();var star_rng: int=runtime.rng.state
	runtime.settings.offline_enable_despite_native_flag=false;world.equipment_records_dirty=true;world.rng.seed=chosen_seed
	check(not status.apply(skill,dummy,world) and dummy.stun_remaining==0,"same actual status API resists unearned disabled bonus")
	runtime.settings.offline_enable_despite_native_flag=true;world.equipment_records_dirty=true;world.rng.seed=chosen_seed
	check(status.apply(skill,dummy,world) and dummy.stun_remaining==2.0,"same actual status API applies stun with earned equipped bonus")
	check(world.gold==before_gold and world.mp==before_mp and world.card_draw_fusion.export_state()==cards and runtime.rng.state==star_rng,"passive status bonus never consumes card currency MP or star RNG")
	dummy.status_immunities=["stun"];var combat_rng: int=world.rng.state
	check(not status.apply(skill,dummy,world) and world.rng.state==combat_rng,"explicit immunity still rejects before RNG")
	dummy.status_immunities=[];dummy.stun_resistance=100
	check(not status.apply(skill,dummy,world) and world.rng.state==combat_rng,"absolute resistance still rejects before RNG")
	world.original_skills.status.clear();dummy.queue_free()
func custom_combat_checks(runtime: RefCounted) -> void:
	var adapter: RefCounted=runtime.combat
	var point: Vector2=Positions.combat(world,[Vector2(25,0)])
	check(point.is_finite(),"source map has real clear positions for custom status and charged cast")
	if point.is_finite():world.player.global_position=point
	var dummy: TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(dummy)
	dummy.setup({"name":"자체 암흑 동빙 검증","hp":999999,"lv":world.level,"dark_resistance":0,"ice_resistance":0},world.player,world,null)
	dummy.global_position=world.player.global_position+Vector2(25,0);dummy.set_physics_process(false)
	check(is_equal_approx(adapter.step_seconds(1000),1.0/2.2),"source120 percent uses labelled positive reciprocal custom time")
	runtime.settings.custom_combat.charge_time_formula="linear_percent_with_source_minimum"
	check(is_equal_approx(adapter.step_seconds(1000),.1),"alternate configured linear rule preserves source minimum at120percent")
	runtime.settings.custom_combat.charge_time_formula="source_time_divided_by_one_plus_reduction_percent"
	var baseline: float=world._monster_hit_chance(dummy,"melee")
	var skill: Dictionary={"id":"own-dark-fixture","status":"dark","status_chance":1.0,"duration":3.0}
	check(world.original_skills.status.apply(skill,dummy,world) and is_equal_approx(world._monster_hit_chance(dummy,"melee"),baseline*.5),"own Dark actual status API lowers actual enemy hit probability")
	skill.status="ice";skill.duration=2.0
	check(world.original_skills.status.apply(skill,dummy,world) and adapter.frozen(dummy),"own Ice actual status API freezes target independently of Hold")
	adapter.tick(2.1)
	check(not adapter.frozen(dummy) and adapter.remaining(dummy,"dark")>0,"independent own status timers do not clear one another")
	dummy.status_immunities=["dark"]
	check(not world.original_skills.status.apply({"status":"dark","status_chance":1.0,"duration":3.0},dummy,world),"own Dark preserves explicit immunity")
	dummy.status_immunities=[]
	var cards: Dictionary=world.card_draw_fusion.export_state();var gold: int=world.gold
	check(adapter.apply_status(world.player,"ice",2.0) and adapter.frozen(world.player),"incoming own Ice controls actual player")
	var mp_before: int=world.mp
	check(not world._queue_player_attack(dummy,"melee",func():pass,.5) and world.mp==mp_before,"frozen player cannot queue an attack or spend MP")
	check(world._save_game(true)==OK,"own player condition saves through production writer")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(float(saved.halphas_star_enchant.custom_combat.ice)==2.0,"save records exact own player remaining time")
	world._load_game(true);world.field_population.set_process(false)
	check(adapter.frozen(world.player) and is_equal_approx(adapter.remaining(world.player,"ice"),2.0),"real map reload restores player own condition after map reset")
	adapter.tick(2.1);check(not adapter.frozen(world.player),"restored own player condition expires")
	# Load rebuilt the map; construct a new current-life target for real paid casts.
	dummy=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(dummy)
	dummy.setup({"name":"자체 차징 검증","hp":999999,"lv":world.level,"stun_resistance":0},world.player,world,null)
	dummy.global_position=world.player.global_position+Vector2(25,0);dummy.set_physics_process(false)
	world.selected_monster=dummy;world.level=90;world.skill_cooldowns.clear();world.skill_global_cooldown=0
	var source: Dictionary=world.original_skills.catalog.record_for("쇼크 스턴")
	world.inventory[str(source.book_name)]=1
	check(world.original_skills.catalog.learn(str(source.id)),"learn original Shock Stun through real book consumption")
	world.equipped_items["weapon"].type="양손검";world.mp=100
	world.hud.open_halphas_star_enchant("변신",ID);await settle()
	await scroll_to(button("HalphasChargeStart"));await tap(button("HalphasChargeStart"))
	check(adapter.charge_view().active and world.mp==100,"actual UI starts own charge without paying")
	await scroll_to(button("HalphasChargeCancel"));await tap(button("HalphasChargeCancel"))
	check(not adapter.charge_view().active and world.mp==100,"actual UI cancel is free")
	await scroll_to(button("HalphasChargeStart"));await tap(button("HalphasChargeStart"));adapter.tick(1.0);await settle()
	check(adapter.charge_view().stage==2,"source steps and earned reduction reach own phase2")
	await scroll_to(button("HalphasChargeRelease"));await tap(button("HalphasChargeRelease"))
	check(world.mp==100-int(source.mp) and not world.pending_attack.is_empty(),"actual UI release queues original paid skill exactly once")
	check(not adapter.release_charge().ok and world.mp==100-int(source.mp),"repeated release cannot pay again")
	world._release_player_attack(int(world.pending_attack.id))
	for unused: int in range(20):world.combat_flights._physics_process(.05)
	check(dummy.is_stunned(),"charged original skill reaches real marker flight and status impact")
	var corrupt: Dictionary=runtime.export_state();corrupt.custom_combat.ice=-1
	check(not Runtime.validate(corrupt).is_empty(),"invalid own condition save rejected before loading")
	world._clear_combat_actions();world.skill_cooldowns.clear();world.skill_global_cooldown=0;world.selected_monster=dummy
	check(adapter.start_charge().ok,"start another charge for lifecycle checks")
	adapter.tick(4.0);check(adapter.charge.is_empty() and world.mp==100-int(source.mp),"own timeout cancels without a second payment")
	check(adapter.start_charge().ok,"restart charge before target life change")
	dummy.life_id+=1;adapter.tick(.01);check(adapter.charge.is_empty(),"target reuse cancels charge without old-life hit")
	check(world.gold==gold and world.card_draw_fusion.export_state()==cards,"own statuses and charge preserve Adena and duplicate cards")
	dummy.queue_free();await settle()
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
	if DEFINITIONS.not_installed():
		# Halphas definitions come only from the owned current523 ZIP. Even the
		# isolated activation fixture must refuse without touching save bytes.
		print("VALIDATION_SCOPE current523 definitions not installed: Halphas transaction checks verify the absent-install path")
		var status: Dictionary=Rules.input_status()
		check(not bool(status.available) and str(status.problem).begins_with("halphas_current523_unavailable"),"unavailable definitions are reported, not substituted")
		runtime.settings.offline_enable_despite_native_flag=true;runtime.settings.offline_server_override=true
		var rng_before: int=runtime.rng.state
		check(not runtime.attempt(ID,{ID:1},0,"absent").ok and FileAccess.get_sha256(path)==before and runtime.rng.state==rng_before and runtime.progress.level==0 and world.gold==100000000,"absent definitions refuse even with isolated activation and preserve save, RNG, level and Adena")
		runtime.settings.offline_enable_despite_native_flag=false;runtime.settings.offline_server_override=false
		print("HALPHAS_STAR_TRANSACTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"CURRENT523_NOT_INSTALLED"}))
		world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
		return
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
	conditional_checks(runtime)
	await custom_combat_checks(runtime)
	root.size=Vector2i(960,540)
	world.hud.open_halphas_star_enchant("변신",ID);await settle()
	await scroll_to(button("HalphasApplyAppearance"));await tap(button("HalphasApplyAppearance"))
	check(int(world.source_card_visual_options["m508:1:24504"])==24,"reopened small-screen UI applies earned stage3 appearance")
	var pending_label: Label=world.hud.find_child("HalphasPendingEffects",true,false)
	check(pending_label!=null and pending_label.text.contains("암흑") and pending_label.text.contains("동빙") and pending_label.text.contains("차징"),"UI identifies precise remaining combat integrations")
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var durable_rng: String=durable.halphas_star_enchant.rng_state
	world.gold=1;runtime.progress=Runtime.fresh();runtime.rng.seed=8
	world._load_game(true)
	world.field_population.set_process(false)
	check(world.gold==78000000 and runtime.progress.level==3 and str(runtime.rng.state)==durable_rng,"actual save reload restores gold level and separate RNG")
	check(world.card_draw_fusion.spare["변신"][ID]==91,"reload restores exact duplicate balance")
	check(runtime.status_hit_bonus("stun")==40 and runtime.status_hit_bonus("hold")==60,"reload derives conditional bonuses from saved earned stage only")
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
	check(runtime.status_hit_bonus("stun")==0,"legacy appearance grants no conditional status bonuses")
	check(not runtime.apply_appearance(ID,int(runtime.progress.revision)).ok,"legacy cosmetic cannot grant earned appearance rights")
	check(Runtime.POLICY.data.offline_enable_despite_native_flag==false and Runtime.Native.DATA.data.content_control.Enable==false,"isolated fixture never modifies production activation or source")
	print("HALPHAS_STAR_TRANSACTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_ECONOMY_UI_SAVE_WITH_EXPLICIT_ISOLATED_ACTIVATION_FIXTURE"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
