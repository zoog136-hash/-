extends SceneTree
const QA = preload("res://tests/qa_symbol_absolute_world.gd")
var checks: int = 0
var failures: Array[String] = []
var world
var rt
var attacker: TwilightMonster
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);print("SYMBOL_ABSOLUTE_FAIL "+message)
func stage(grades: int) -> Dictionary:
	var owned: Array=[]
	for grade: int in range(1,grades+1): owned.append(grade)
	return {"stage":30,"attempts":10,"spent":0,"guaranteed":false,"absolute":0,"absolute_grades":owned}
func own(values: Dictionary) -> void:
	var next: Dictionary=rt.empty_state();next.points=10000000
	for id: String in values:next.emblems[id]=stage(int(values[id]))
	check(rt.validate(next).is_empty(),"valid source ownership "+str(values))
	rt.restore(next);world._invalidate_equipment_static()
	world.player.clear_status_effects()
func act(id: String, grade: int, chance: bool = false) -> Dictionary:
	return rt.execute("absolute_chance" if chance else "absolute",id,grade,int(rt.state.revision))
func canonical(value: Variant) -> Variant:
	if value is float and value==floorf(value):return int(value)
	if value is Array:
		var out: Array=[]
		for v: Variant in value:out.append(canonical(v))
		return out
	if value is Dictionary:
		var out: Dictionary={}
		for k: Variant in value:out[str(k)]=canonical(value[k])
		return out
	return value
func damage(hp_before: int, critical: bool=false, stunned: bool=false) -> int:
	world.hp=hp_before;world.symbol_test_critical=critical;world.player.clear_status_effects()
	if stunned:world.player.apply_stun(2.0)
	var original_map=world.field_map;world.field_map=null
	world._on_player_hit(attacker,100,"magic")
	world.field_map=original_map
	return hp_before-int(world.hp)
func run() -> void:
	world=load("res://Main.tscn").instantiate();world.set_script(QA);root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	world.hud.complete_class_selection();world.quickslots=[];world.max_hp=20000
	rt=world.growth
	attacker=world.MONSTER_SCENE.instantiate();world.monsters_root.add_child(attacker)
	attacker.setup({"name":"문양 전투 검증","hp":999999,"lv":1,"ac":0,"crit":0},world.player,world,null)
	attacker.set_physics_process(false);attacker.attack_element="physical"
	var original_map=world.field_map
	own({"sayha":0});world.inventory["축복의 열쇠"]=1000
	var before: Dictionary=rt.state.duplicate(true)
	check(not act("sayha",5).ok and rt.state==before and world.inventory["축복의 열쇠"]==1000,"cannot skip four predecessors or spend")
	var used: int=0;var experience: int=20
	for grade: int in range(1,6):
		var row: Dictionary=rt.source523.absolute("sayha",grade).payment
		used+=int(row.ForceOpenCost);experience+=int(float(row.Value)/10000.0)
		check(act("sayha",grade).ok,"buy sequential Sayha "+str(grade))
		check(world.inventory["축복의 열쇠"]==1000-used,"exact source key cost "+str(grade))
		check(rt.bonus("experience_bonus:percent")==experience,"all owned XP bonuses counted once "+str(grade))
		var spent: int=world.inventory["축복의 열쇠"]
		check(not act("sayha",grade).ok and world.inventory["축복의 열쇠"]==spent,"duplicate tier does not spend")
	check(used==838 and experience==75,"five source tiers require838 keys; existing additive adapter gives75 totalXP")
	own({"eva":0});world.inventory["축복의 열쇠"]=1000
	check(act("eva",1).ok and act("eva",2).ok,"Eva first two tiers now usable")
	check(rt.bonus("magic_heal:percent")==10 and rt.bonus("potion_cooldown:percent")==20,"magic healing and potion cooldown use different channels")
	before=rt.state.duplicate(true)
	check(not act("eva",3).ok and rt.state==before,"teleport control remains blocked without a consumer")
	check(not act("eva",4).ok,"known fourth-tier effect still requires third-tier ownership")
	own({"maphr":0});world.inventory["축복의 열쇠"]=100
	check(act("maphr",1).ok and rt.bonus("low_hp_reduction:percent")==3,"Maphr interval nested bonus resolved")
	check(rt.incoming_damage(100,false,false,300,1000)==97,"30 percent inclusive lowHP boundary")
	check(rt.incoming_damage(100,false,false,301,1000)==100,"30.1 percent does not floor into interval")
	var maximum: int=world._effective_max_hp()
	check(damage(int(maximum*30/100))==97,"actual monster hit uses lowHP Maphr condition")
	check(damage(int(maximum*30/100)+1)==100,"actual hit above threshold has no conditional reduction")
	check(not act("maphr",2).ok,"PvP reduction not sold as NPC defense")
	own({"grankain":0});world.inventory["축복의 열쇠"]=100
	check(act("grankain",1).ok,"Grankain first conditional tier now usable")
	check(damage(10000)==90 and damage(10000,false,true)==86,"actual stunned hit subtracts source5 in existing growth adapter")
	own({"eva":0})
	world.hp=1;world.inventory["체력 회복제"]=1;world.item_use_cooldowns.clear();world._use_healing_item("체력 회복제",100)
	var potion_before: int=world.hp
	own({"eva":1})
	world.hp=1;world.inventory["체력 회복제"]=1;world.item_use_cooldowns.clear();world._use_healing_item("체력 회복제",100)
	check(world.hp==potion_before,"magic healing bonus does not amplify potions")
	world.hp=1;world.mp=1000
	var base_heal: int=100+(world.int_stat+world._active_skill_buff_total("intFlat"))*2
	check(world._cast_job_heal_skill({"name":"문양 회복 검증","heal":100,"mp":0}),"actual job healing executes")
	check(world.hp==1+int(round(base_heal*1.1)),"job healing uses exact10 percent magic channel")
	own({"eva":1,"einhasad":0});world.inventory["축복의 열쇠"]=100
	var lfe: float=world.original_skills.stat("lfe")
	check(act("einhasad",1).ok and world.original_skills.stat("lfe")==lfe+3,"source life3 reaches existing LFE skill scalar")
	var heal_record: Dictionary={}
	for record: Dictionary in world.original_skills.catalog.records:
		if record.get("mode")=="heal":heal_record=record.duplicate(true);break
	check(not heal_record.is_empty(),"existing original healing definition available")
	heal_record["lfe_scale"]=2.0;world.hp=1
	world.original_skills.heal(heal_record,100)
	check(world.hp==1+int(round((100+int(world.original_skills.stat("lfe")*2))*1.1)),"original spell healing uses LFE then magic healing; both actual consumers")
	own({"einhasad":2});var no_critical_reduction: int=damage(10000,true)
	own({"einhasad":3});check(damage(10000,true)==no_critical_reduction-5,"actual critical damage reduction channel")
	check(damage(10000)==97,"critical reduction does not affect ordinary hits")
	own({"maphr":2});var stun_resist: int=world._stun_resistance_stat()
	own({"maphr":3});check(world._stun_resistance_stat()==stun_resist+5,"Stun enum6 maps exact resistance")
	var stun_hit: int=world._stun_accuracy_stat()
	own({"maphr":4});check(world._stun_accuracy_stat()==stun_hit+5,"HitSpecialResistance maps accuracy separately")
	own({"einhasad":3});var fear_resist: int=world._fear_resistance_stat()
	own({"einhasad":4});check(world._fear_resistance_stat()==fear_resist+5,"Fear enum8 is not stun resistance")
	stun_resist=world._stun_resistance_stat()
	own({"einhasad":5});check(world._stun_resistance_stat()==stun_resist+5,"fifth-tier exact Stun enum")
	own({"shilen":2});var prior_crit: Dictionary={}
	for kind: String in ["melee","ranged","magic"]:prior_crit[kind]=world._player_critical_damage(100,kind)
	own({"shilen":3})
	for kind: String in prior_crit:check(world._player_critical_damage(100,kind)==prior_crit[kind]+5,"actual "+kind+" critical flat5")
	own({"paagrio":2});world.hp=1;attacker.hp=10000;attacker.dead=false
	world._deal_successful_player_hit(attacker,10,false);var old_heal: int=world.hp;var old_target: int=attacker.hp
	own({"paagrio":3});world.hp=1;attacker.hp=10000;attacker.dead=false
	world._deal_successful_player_hit(attacker,10,false)
	check(world.hp==old_heal+3 and attacker.hp==old_target-3,"source HP absorption shares existing exact damage/heal path")
	var all: Dictionary={}
	for id: String in rt.source523.data.emblems:all[id]=5
	own(all)
	check(world._save_game(true)==OK,"preserve all known native ownership even when some consumers remain unavailable")
	before=canonical(rt.state);world.field_map=original_map;world._load_game(true);world.field_population.set_process(false)
	check(canonical(rt.state)==before,"all35 owned grade records survive real game save and reload")
	var malformed: Dictionary=rt.state.duplicate(true);malformed.emblems["sayha"].absolute_grades=[2]
	check(not rt.validate(malformed).is_empty(),"noncontiguous native tier list rejected")
	own({"sayha":0});world._save_game(true)
	var persisted: String=FileAccess.get_sha256(world.save_path());before=rt.state.duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary) -> Error:return ERR_CANT_CREATE
	check(not act("sayha",1,true).ok and rt.state==before and FileAccess.get_sha256(world.save_path())==persisted,"chance transaction failure preserves file bytes and all state")
	world.equipment_collections.test_save_writer=Callable()
	print("SYMBOL_ABSOLUTE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
