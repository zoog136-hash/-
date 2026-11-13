extends "res://tests/player_skills523_live.gd"
## Nine existing roles only; no new player-opponent or reference skill activation.
var arena: Vector2
const IDS={"light":"lm_d44e85981c877135","brave":"lm_9f340db69e8b2702","capacity":"lm_d23194d0b63ee4e1","speed":"lm_7d4f31d336a3441f","taunt":"lm_310e7f51a839530f","triple":"lm_b9f1605d690c64f7","foe":"lm_45d35daedfc527c9","static":"lm_b08f206fe97abc83","rapid":"lm_795059827558bc19"}

func freeze() -> void:
	world.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false);world.player.set_auto_enabled(false)
	world._clear_monsters()
	if is_instance_valid(world.field_population):world.field_population.set_process(false)

func enter(job: String, weapon: String="한손검") -> void:
	check(QA.enter_game(world,job),"actual class confirmation "+job)
	world.level=90;reset_cast();world.player.global_position=arena;world.selected_monster=dummy
	dummy.global_position=arena+Vector2(24,0);dummy.hp=100000;dummy.dead=false
	world.equipped_items["weapon"]={"name":"기존 스킬 실행 검증 무기","type":weapon,"slot":"weapon"}
	world.equipped_ammo="화살" if weapon=="활" else "총알" if weapon=="총" else ""
	world.ammo_unequipped=false;world._invalidate_equipment_static();world._update_hud()

func learn_ui(id: String) -> Control:
	var view:=await select_skill(id)
	check(view.selection_sheet.category.text.begins_with("원본 실행 + TWILIGHT 설정"),"actual source/host label "+id)
	if not world.original_skills.catalog.owned(view.selected):
		check(not view.book_button.disabled,"existing purchase UI "+id);view.book_button.pressed.emit();view=await select_skill(id)
		check(not view.learn_button.disabled,"existing learning UI "+id);view.learn_button.pressed.emit();view=await select_skill(id)
	check(world.original_skills.catalog.owned(view.selected),"stable learned ID "+id)
	return view

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-captures="):captures=arg.get_slice("=",1)
	if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	check(QA.enter_game(world,"군주"),"actual Main starts")
	freeze();world.gold=100000000
	arena=POSITIONS.combat(world,[Vector2(24,0)])
	check(arena.is_finite(),"real source-map combat floor")
	if not arena.is_finite():world.queue_free();quit(2);return
	dummy=(load("res://scenes/Monster.tscn") as PackedScene).instantiate();world.monsters_root.add_child(dummy)
	dummy.setup({"name":"기존 스킬 전환 검증 대상","hp":100000,"lv":1,"ac":0,"mr":0,"atk":1},world.player,world,null);dummy.set_physics_process(false)
	var service=world.original_skills
	var catalog=service.catalog
	var source=catalog.source523
	print("SKILLS523_PHASE Main loaded")
	check(source.profiles.size()==441 and source.profiles[IDS.triple].execution_graph.spells.size()==2,"new reviewed execution pack actually loaded")
	var identities: Dictionary={}
	for id: String in IDS.values():
		var r: Dictionary=catalog.record_for(id)
		identities[id]={"id":r.id,"name":r.name,"class":r["class"],"origin":r.origin,"activation":r.activation}
	enter("군주")
	var view:=await learn_ui(IDS.light)
	check(view.use_button.disabled and view.selection_sheet.category.text.contains("패시브"),"light UI shows passive and prevents active use")
	check(not world._quickslot_registration_error("skill",IDS.light).is_empty(),"converted passive cannot register as active quickslot")
	var mp_before: int=world.mp
	service.tick(.01)
	check(is_instance_valid(service.progression.light) and service.progression.light.visible and service.catalog.stat("lightRadiusRaw")==13,"native radius drives actual player light consumer")
	check(not world._cast_job_skill(IDS.light) and world.mp==mp_before,"passive never spends old active cost")
	view=await learn_ui(IDS.brave)
	var brave: Dictionary=catalog.resolve(catalog.record_for(IDS.brave))
	check(brave.activation=="passive" and brave.proc_chance==.3 and brave.multiplier==2,"exact original invoke probability and multiplier replace old guesses")
	var hit:=false;var miss:=false
	for seed_value: int in range(1,40):
		world.rng.seed=seed_value;var amount: int=service.outgoing_damage(100)
		hit=hit or amount==200;miss=miss or amount==100
	check(hit and miss,"native passive reaches live outgoing damage using real PCG")
	service.proc_depth=1
	check(service.outgoing_damage(100)==100,"amplification does not recursively scale additional procs")
	service.proc_depth=0
	enter("마법사")
	var max_hp_before: int=world._effective_max_hp();var max_mp_before: int=world._effective_max_mp()
	world.hp=100;world.mp=100
	view=await learn_ui(IDS.capacity)
	check(service.stat("hpPct")==.2 and service.stat("mpPct")==.2 and world._effective_max_hp()>max_hp_before and world._effective_max_mp()>max_mp_before,"native20percent actually changes both host maxima")
	check(world.hp==100 and world.mp==100,"learning capacity does not refill or grant HP/MP")
	world.active_skill_buffs["어드밴스 스피릿"]={"skill_id":IDS.capacity,"remaining":500,"skill_stats":{"hp":100,"mp":60}}
	service.tick(.01)
	check(not world.active_skill_buffs.has("어드밴스 스피릿") and service.stat("hp")==0,"legacy active package cannot stack with converted passive")
	enter("투사","체인소드")
	view=await learn_ui(IDS.speed)
	check(is_equal_approx(catalog.speed(),1.25) and service.stat("attackSpeed")==25 and service.stat("castSpeed")==25,"native25percent reaches move attack and cast-speed consumers")
	check(view.use_button.disabled and view.selection_sheet.category.text.contains("패시브"),"speed passive has actual UI classification")
	enter("기사")
	view=await learn_ui(IDS.taunt)
	check(world._save_game(true)==OK,"durable pre-toggle baseline")
	var disk_hash: String=FileAccess.get_sha256(world.save_path())
	world.equipment_collections.save_blocked=true
	view.use_button.pressed.emit()
	check(not service.progression.is_on(view.selected) and FileAccess.get_sha256(world.save_path())==disk_hash,"actual toggle UI save refusal publishes no state")
	world.equipment_collections.save_blocked=false
	view.use_button.pressed.emit();service.tick(.01)
	check(service.progression.is_on(view.selected) and dummy.aggro_remaining==10,"ON invokes native10second taunt on actual monster")
	check(not service.auto_wants(view.selected,dummy) and not world._quickslot_auto_allowed({"kind":"skill","id":IDS.taunt}),"AUTO cannot repeatedly invert ON/OFF")
	view=await select_skill(IDS.taunt)
	check(view.use_button.text.begins_with("OFF"),"actual toggle UI displays current state")
	view.use_button.pressed.emit();dummy.aggro_remaining=0;service.tick(20)
	check(not service.progression.is_on(view.selected) and dummy.aggro_remaining==0,"OFF stops aura refresh")
	enter("요정","활")
	print("SKILLS523_PHASE native passives and aura checked")
	world.inventory["화살"]=30
	view=await learn_ui(IDS.triple)
	var inventory_before: Dictionary=world.inventory.duplicate(true);mp_before=world.mp
	view.use_button.pressed.emit()
	check(service.progression.is_on(view.selected) and world.mp==mp_before and world.inventory==inventory_before,"ON itself does not pay the firing cost")
	world.auto_attack_timer=0;world._attack()
	check(world.pending_attack.get("original_skill",{}).get("execution_spell_id",0)==120712 and world.pending_attack.original_skill.hits==3 and world.mp==mp_before-15 and int(world.inventory["화살"])==27,"normal attack becomes native triple shot with MP15 and three arrows once")
	var target_hp: int=dummy.hp
	CLOCK.settle(world)
	check(dummy.hp<target_hp and world.mp==mp_before-15 and int(world.inventory["화살"])==27,"actual triple projectiles impact without extra normal damage or payment")
	await capture("triple-source-toggle",Vector2i(960,540))
	reset_cast();world.ammo_unequipped=true;world.equipped_ammo=""
	var rng_before: int=world.rng.state;inventory_before=world.inventory.duplicate(true)
	check(not service.progression.try_repeat(dummy) and world.inventory==inventory_before and world.rng.state==rng_before,"unworn ammo prevents repeat without cost or RNG")
	world.ammo_unequipped=false;world.equipped_ammo="화살"
	view=await select_skill(IDS.triple);view.use_button.pressed.emit()
	enter("투사","체인소드")
	view=await learn_ui(IDS.foe);view.use_button.pressed.emit()
	var hp_before: int=world.hp;world.auto_attack_timer=0;world._attack()
	check(world.pending_attack.get("original_skill",{}).get("execution_spell_id",0)==122992 and world.hp==hp_before-5,"foe normal-attack replacement uses native HP5 rather than old MP cost")
	CLOCK.settle(world)
	check(world.hp==hp_before-5,"three foe impacts do not multiply parent cost")
	enter("총사","총")
	world.inventory["정제석"]=20;world.inventory["총알"]=20
	view=await learn_ui(IDS.rapid)
	view.use_button.pressed.emit()
	check(world.mp==991 and int(world.inventory["정제석"])==18 and int(world.inventory["총알"])==18 and world.pending_attack.original_skill.hits==2,"rapid source MP8/material2 and configured double shot consume once")
	target_hp=dummy.hp;CLOCK.settle(world)
	check(dummy.hp<target_hp,"rapid estimates execute actual projectile impacts")
	enter("뇌신")
	world.inventory["번개석"]=100
	print("SKILLS523_PHASE repeat and rapid checked")
	view=await learn_ui(IDS.static);view.use_button.pressed.emit()
	var fired_before: int=int(service.progression.fired.get(IDS.static,0))
	for seed_value: int in range(1,101):
		reset_cast();service.progression.clocks[IDS.static]=0;world.rng.seed=seed_value;world.auto_attack_timer=0
		world._attack();CLOCK.settle(world)
		if int(service.progression.fired.get(IDS.static,0))>fired_before:break
	check(int(service.progression.fired.get(IDS.static,0))==fired_before+1 and int(world.inventory["번개석"])==97,"real normal attack triggers native9percent static proc and material3 once")
	check(not service.stacks.has(IDS.static),"static no longer invents an attack-stat stack")
	service.progression.clocks[IDS.static]=0;inventory_before=world.inventory.duplicate(true);rng_before=world.rng.state
	service.progression.on_normal_hit(dummy,{"id":"other-skill"})
	check(world.inventory==inventory_before and world.rng.state==rng_before,"BySpellAttack false prevents spell/proc recursion without RNG")
	world.hud.open_settings_info(true)
	for _frame: int in range(3):await process_frame
	var panel: Control=world.hud.workspace.find_child("SkillProgression523Settings",true,false)
	check(panel!=null,"actual settings window includes existing-skill policy controls")
	panel.selector.select(8);panel.selector.item_selected.emit(8)
	var power: SpinBox=panel.find_child("Progression523_power",true,false)
	check(power!=null,"rapid own coefficients have real controls")
	check(world._save_game(true)==OK,"settings progression baseline")
	disk_hash=FileAccess.get_sha256(world.save_path());power.value=44
	check(catalog.resolve(catalog.record_for(IDS.rapid)).power==44 and FileAccess.get_sha256(world.save_path())==disk_hash,"actual setting updates next resolved attack without changing progression bytes")
	check(not source.set_progression_setting(IDS.brave,"proc_chance",1),"native proc chance has no writable estimate setting")
	var scroll: ScrollContainer=world.hud.workspace.find_child("SettingsScroll",true,false)
	for _frame: int in range(2):await process_frame
	scroll.scroll_vertical=int(panel.position.y)
	await capture("existing-skill-settings",Vector2i(1280,720))
	# Known PC restrictions remain source facts, not missing-number estimates.
	for pair: Array in [["마법사","lm_f5125fc718ebf071"],["마법사","lm_4577052891abbbc4"],["사신","lm_f3e3300d0862d21a"],["사신","lm_44e63d3719e2f526"],["사신","lm_ad6488f0cedbc544"],["사신","lm_8187ff2de29d3853"]]:
		var record: Dictionary=catalog.record_for(str(pair[1]));enter(str(record["class"]));catalog.learned[str(record.id)]=1
		var skill: Dictionary=catalog.resolve(record);inventory_before=world.inventory.duplicate(true);hp_before=world.hp;mp_before=world.mp;rng_before=world.rng.state
		check(not str(skill.get("source523_block_reason","")).is_empty() and not world._cast_job_skill(str(record.id)) and world.hp==hp_before and world.mp==mp_before and world.inventory==inventory_before and world.rng.state==rng_before,"confirmed PC-only target never expands to monster "+str(record.id))
	# Canonical identity contract used by PR248 is unaffected by runtime modes.
	for id: String in IDS.values():
		var row: Dictionary=catalog.record_for(id)
		check({"id":row.id,"name":row.name,"class":row["class"],"origin":row.origin,"activation":row.activation}==identities[id],"canonical identity unchanged for relic binding "+id)
	enter("뇌신")
	check(world._save_game(true)==OK,"new states persist through existing actual save")
	var save_path: String=world.save_path();disk_hash=FileAccess.get_sha256(save_path)
	world.queue_free();await process_frame
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world);await process_frame
	freeze();service=world.original_skills;catalog=service.catalog
	check(service.progression.is_on(catalog.record_for(IDS.static)) and int(catalog.learned.get(IDS.rapid,0))==1,"fresh Main restores toggle state and learned identities without activating another class")
	check(catalog.resolve(catalog.record_for(IDS.rapid)).power==44,"own policy reload survives fresh Main")
	check(FileAccess.get_sha256(save_path)==disk_hash,"fresh Main derived rules do not rewrite durable save")
	world.queue_free();await process_frame
	print("SKILLS523_PROGRESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"nine existing roles; six source PC restrictions preserved"}))
	quit(0 if failures.is_empty() else 1)
