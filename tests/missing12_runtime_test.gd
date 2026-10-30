extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
var world: TwilightWorld
var service: TwilightOriginalSkillService
var catalog: TwilightOriginalSkillCatalog
var enemies: Array[TwilightMonster] = []
var checks := 0
var failures: Array[String] = []
var all_learned: Dictionary
var arena := Vector2.INF
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:failures.append(note);print("MISSING12_FAIL ",note)
func row(name_value: String) -> Dictionary: return catalog.record_for(name_value)
func reset(names: Array[String], job: String, weapon: String = "한손검") -> void:
	world._clear_combat_actions()
	service.summons.clear()
	world.active_skill_buffs.clear()
	service.toggles.clear();service.local_runtime.windows.clear();service.local_runtime.cooldowns.clear()
	catalog.learned.clear();catalog.seed_starters()
	world.job_class=job;world.level=90
	world.equipped_items={"weapon":{"name":"테스트 무기","type":weapon,"slot":"weapon"}}
	for name_value: String in names:catalog.learned[str(row(name_value).id)]=1
	world.skill_cooldowns.clear();world.skill_global_cooldown=0
	world.hp=world._effective_max_hp();world.max_mp=1000;world.mp=1000
	world.player.global_position=arena
	world.player.stun_remaining=0;world.player.fear_remaining=0;world.player.silence_remaining=0
	for i: int in range(enemies.size()):
		var enemy: TwilightMonster=enemies[i]
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
			enemy=(load("res://scenes/Monster.tscn") as PackedScene).instantiate()
			world.monsters_root.add_child(enemy)
			enemy.setup({"name":"재기동 검사 NPC","hp":1000000,"lv":1,"mr":0,"ac":0,"atk":1},world.player,world,null)
			enemy.global_position=arena+Vector2(30+i*20,0);enemy.set_physics_process(false);enemies[i]=enemy
		enemy.hp=1000000;enemy.dead=false;enemy.hold_remaining=0;enemy.stun_remaining=0
	service.status.clear()
func seed_proc(record: Dictionary) -> void:
	for value: int in range(10000):
		world.rng.seed=value
		if world.rng.randf()<float(record.proc_chance):world.rng.seed=value;return
func normal_hit(record: Dictionary) -> void:
	seed_proc(record);service.trigger("on_hit",enemies[0])
func verify_restart() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://local_skill_restart_expect.json"))
	check(world.job_class=="요정","restart class preserved")
	for id: String in expected.ids:check(int(catalog.learned.get(id,0))==1,"restart learned stable ID "+id)
	var shooting:=row("슈팅 스타")
	check(service.local_runtime.is_on(shooting),"restart real toggle preserved")
	check(world.mp==int(expected.mp),"restart did not charge activation twice")
	check(float(service.local_runtime.windows[str(shooting.id)])<=float(expected.window),"restart does not renew toggle lifetime")
	check(float(service.local_runtime.cooldowns.get(str(shooting.id),0))>0,"restart preserves proc ICD")
	world.queue_free();await process_frame
	print("MISSING12_RESTART_RESULT checks=%d errors=%d" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func run() -> void:
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	service=world.original_skills;catalog=service.catalog
	if "--verify-local-restart" in OS.get_cmdline_user_args():
		await verify_restart();return
	if not QA.enter_game(world):quit(1);return
	check(world.field_map is NativePngField and world.active_map_id=="aden_world","must use current main Aden PNG, no legacy")
	world.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false);world.save_timer=-100000
	world._clear_monsters();world.level=90;world.gold=100000000;world.max_mp=1000
	service=world.original_skills;catalog=service.catalog
	check(catalog.records.size()==137,"137 runtime records")
	check(catalog.record_for("엘리멘탈 애로우").id==row("엘리멘탈 웨폰").id,"alias stable identity")
	arena=POSITIONS.combat(world,[Vector2(30,0),Vector2(50,0)],25)
	check(arena.is_finite(),"real native walkable combat lane")
	if not arena.is_finite():world.queue_free();quit(1);return
	world.player.global_position=arena
	for i: int in range(2):
		var enemy: TwilightMonster=(load("res://scenes/Monster.tscn") as PackedScene).instantiate()
		world.monsters_root.add_child(enemy);enemy.setup({"name":"신규 스킬 검사 NPC","hp":1000000,"lv":1,"mr":0,"ac":0,"atk":1},world.player,world,null)
		enemy.global_position=arena+Vector2(30+i*20,0);enemy.set_physics_process(false);enemies.append(enemy)
	var spirit:=row("아쿠아 프리즌(스피릿)")
	world.job_class="요정";world.inventory[str(spirit.book_name)]=1
	check(not catalog.learn(str(spirit.id)),"upgrade needs base before book consumed")
	for record: Dictionary in catalog.current_official.records:
		world.job_class=record["class"];world.level=int(record.minimum_level)-1
		check(not catalog.buy_book(str(record.id)),str(record.name)+" low level blocked")
		world.level=90;world.gold=0
		check(not catalog.buy_book(str(record.id)),str(record.name)+" insufficient gold blocked")
		world.gold=100000000
		var before: int=world.gold
		check(catalog.buy_book(str(record.id)),str(record.name)+" actual book shop")
		check(world.gold==before-int(record.book_cost),"positive exact book price")
		check(catalog.learn(str(record.id)),str(record.name)+" actual learn")
		check(catalog.owned(record),str(record.name)+" owned for proper class")
		check(not catalog.learn(str(record.id)),str(record.name)+" no duplicate learning")
		check(record.design_provenance.cooldown.status=="local_design","cooldown provenance local")
		world.job_class="총사"
		check(not catalog.owned(record) and not service.ready(record),"wrong class cannot activate")
	all_learned=catalog.learned.duplicate(true)
	check(all_learned.size()>=12,"all twelve learned")
	reset(["프라이드"],"기사","양손검")
	var pride:=row("프라이드")
	world.mp=29;world.inventory["명예 코인"]=8
	check(not world._cast_job_skill(str(pride.id)) and world.mp==29 and world.inventory["명예 코인"]==8,"Pride insufficient MP atomic")
	world.mp=30;world.inventory["명예 코인"]=7
	check(not world._cast_job_skill(str(pride.id)) and world.mp==30,"Pride reagent shortage atomic")
	world.inventory["명예 코인"]=8
	check(world._cast_job_skill(str(pride.id)),"Pride paid cast")
	check(world.mp==0 and world.inventory["명예 코인"]==0,"official Pride MP30 coin8")
	check(float(world.active_skill_buffs[str(pride.name)].remaining)==7 and world._active_skill_speed_multiplier()>1,"official Pride seven seconds / local speed")
	check(service.stat("attackSpeed")==10,"Pride passive two-hand speed")
	reset(["버서커스"],"마법사","지팡이")
	var berserk:=row("버서커스");var melee_before:=world._melee_damage_stat();var range_before:=world._current_attack_range_cells()
	world.inventory["명예 코인"]=5;world.mp=40
	check(world._cast_job_skill(str(berserk.id)),"Berserk cast")
	check(world.mp==0 and world.inventory["명예 코인"]==0 and world.active_skill_buffs[str(berserk.name)].remaining==1800,"official Berserk costs/duration")
	check(world._melee_damage_stat()>melee_before and world._current_attack_range_cells()==range_before+1,"Berserk melee/INT/range implemented")
	reset(["아쿠아 애로우"],"요정","활")
	var aqua:=row("아쿠아 애로우");world.hp-=100;var hp_before:=world.hp;world.mp=5;world.inventory["명예 코인"]=1
	check(world._cast_job_skill(str(aqua.id)) and world.hp==hp_before+80 and world.mp==0 and world.inventory["명예 코인"]==0,"Aqua actual self healing single-player adaptation / official cost")
	reset(["슈팅 스타"],"요정","활")
	var shooting:=row("슈팅 스타");world.mp=26
	check(world._cast_job_skill(str(shooting.id)) and service.local_runtime.is_on(shooting) and world.mp==0,"Shooting real toggle / official MP26 on local activation phase")
	var victim_before:=enemies[0].hp
	normal_hit(shooting)
	check(enemies[0].hp==victim_before,"Shooting no free proc at zero MP")
	service.local_runtime.cooldowns.clear();world.mp=100
	normal_hit(shooting)
	check(enemies[0].hp<victim_before and enemies[1].hp<1000000 and world.mp==98,"Shooting split hit + local proc cost")
	var after:=enemies[0].hp;service.trigger("on_hit",enemies[0]);check(enemies[0].hp==after,"no duplicate/nested proc in ICD")
	world.mp=0;check(world._cast_job_skill(str(shooting.id)) and not service.local_runtime.is_on(shooting) and world.mp==0,"OFF allowed at zero MP / in cooldown")
	reset(["디그니티"],"군주","한손검")
	var dignity:=row("디그니티");normal_hit(dignity)
	check(enemies[0].hp<1000000 and enemies[1].hp==1000000,"Dignity OFF single target paid proc")
	service.local_runtime.cooldowns.clear();world.skill_global_cooldown=0
	check(world._cast_job_skill(str(dignity.id)),"Dignity ON")
	check(service.local_runtime.windows[str(dignity.id)]==1200,"Dignity official 20min")
	normal_hit(dignity);check(enemies[1].hp<1000000,"Dignity ON area hit")
	service.local_runtime.tick(1201);check(not service.local_runtime.is_on(dignity),"finite toggle expiry")
	reset(["블러디 크로우"],"다크엘프","크로우")
	var bloody:=row("블러디 크로우");world.inventory["흑요석"]=0;check(world._cast_job_skill(str(bloody.id)),"Bloody toggle ON")
	world.hp-=50;victim_before=enemies[0].hp;normal_hit(bloody)
	check(enemies[0].hp==victim_before,"Bloody missing proc reagent blocks damage/heal")
	service.local_runtime.cooldowns.clear();world.inventory["흑요석"]=1;hp_before=world.hp
	normal_hit(bloody);check(world.inventory["흑요석"]==0 and enemies[0].hp<victim_before and world.hp==hp_before+8,"Bloody obsidian1 + area damage + absorption")
	reset(["아쿠아 프리즌"],"요정","활")
	var prison:=row("아쿠아 프리즌");normal_hit(prison)
	check(enemies[0].hold_remaining>0 and service.status.modifier(enemies[0],"dg")==-8,"base Prison real hold and evasion reduction")
	reset(["아쿠아 프리즌","아쿠아 프리즌(스피릿)"],"요정","활")
	world.hp-=50;hp_before=world.hp;normal_hit(prison)
	check(is_equal_approx(enemies[0].hold_remaining,1.8) and service.status.modifier(enemies[0],"dg")==-12,"Spirit upgrades base once")
	check(world.hp==hp_before+8 and enemies[0].hp==1000000-30,"Spirit shark damage/absorption once")
	reset(["엘리멘탈 웨폰"],"요정","활")
	var weapon:=row("엘리멘탈 웨폰");check(service.stat("rangedHit")==5 and service.stat("meleeHit")==5,"Elemental Weapon passive stats")
	normal_hit(weapon);check(enemies[0].hp<1000000 and service.status.modifier(enemies[0],"dg")==-5,"Elemental Weapon elemental hit / defense ignore surrogate")
	reset(["엘븐 윙 슈즈"],"요정","활")
	var wings:=row("엘븐 윙 슈즈");check(catalog.speed()>=1.12,"Wing shoes passive movement")
	normal_hit(wings);check(world.player.global_position.distance_to(arena)>0,"Wing shoes collision-checked dash")
	seed_proc(wings);var received:=service.local_runtime.incoming(enemies[0],"melee",20)
	check(received==15,"Wing shield incoming reduction")
	reset(["리포스트"],"기사","양손검")
	var riposte:=row("리포스트");seed_proc(riposte);received=service.local_runtime.incoming(enemies[0],"charge",100)
	check(received==75 and enemies[0].hp==999925 and enemies[0].stun_remaining>0,"Riposte reduction, guaranteed counter and charge stagger")
	reset(["엘리멘탈 가디언"],"요정","활")
	var guardian:=row("엘리멘탈 가디언");world.mp=600;world.inventory["정령옥"]=99
	check(not world._cast_job_skill(str(guardian.id)) and world.mp==600 and not service.summons.active(),"Guardian shortage no cost/no actor")
	world.inventory["정령옥"]=100
	check(world._cast_job_skill(str(guardian.id)),"Elemental Guardian actual summon")
	check(world.mp==0 and world.inventory["정령옥"]==0 and service.summons.remaining==3600,"official Guardian 600MP/100 gems/hour")
	if service.summons.active():
		service.summons.actor.global_position=arena+Vector2(20,0);service.summons.actor.age=1
		service.summons.pending_hit={"target":weakref(enemies[0]),"life":enemies[0].life_id,"generation":world.combat_generation}
		service.summons.release_hit()
		check(enemies[0].hp<1000000 and enemies[1].hp<1000000,"elemental guardian gameplay strike marker area magic")
		world._save_game(true);service.summons.clear();world._load_game(false)
		check(service.summons.active() and service.summons.remaining<=3600,"real save/load restores guardian without repayment")
	reset(["블러디 크로우"],"다크엘프","크로우")
	world.inventory["흑요석"]=10;world._cast_job_skill(str(bloody.id));service.local_runtime.tick(10)
	world._save_game(true);var saved_mp:=world.mp;service.toggles.clear();service.local_runtime.windows.clear();world._load_game(false)
	check(service.local_runtime.is_on(bloody) and service.local_runtime.windows[str(bloody.id)]<=1790.01 and world.mp==saved_mp,"real save/load restores finite toggle and resources")
	world.job_class="기사";service.local_runtime.tick(.1)
	check(not service.local_runtime.is_on(bloody),"class switch disables incompatible toggle")
	reset(["프라이드"],"기사","양손검");world.gold=0
	check(not service.local_runtime.buy_reagents(pride),"reagent shop cannot overdraw gold")
	world.gold=1000;check(service.local_runtime.buy_reagents(pride) and world.gold==200,"reagent shop charges positive local price for eight coins")
	reset(["슈팅 스타"],"요정","활")
	world.level=9;var before_low:=world.mp
	check(not service.cast(shooting) and world.mp==before_low,"owned skill still checks current level")
	world.level=90;world._cast_job_skill(str(shooting.id));world.hp=0;service.local_runtime.tick(.1)
	check(not service.local_runtime.is_on(shooting),"death clears toggle")
	reset(["슈팅 스타"],"요정","활")
	world._cast_job_skill(str(shooting.id))
	var proc_before: int=int(service.local_runtime.proc_events.get(str(shooting.id),0))
	var marker_proc := false
	service.vfx.detail_limit=0
	for seed_value: int in range(40):
		world._clear_combat_actions();service.local_runtime.cooldowns.clear()
		enemies[0].hp=1000000;enemies[1].hp=1000000;world.rng.seed=seed_value;world.mp=1000
		var queued: bool=world._queue_player_attack(enemies[0],"ranged",world._resolve_normal_attack.bind(enemies[0],"ranged"),.72,true,430)
		check(queued and enemies[0].hp==1000000,"real motion queue has no early damage")
		preload("res://tests/combat_test_clock.gd").settle(world)
		if int(service.local_runtime.proc_events.get(str(shooting.id),0))>proc_before:
			marker_proc=true;break
	check(marker_proc and enemies[1].hp<1000000,"real motion/flight normal hit invokes split proc with visual pool disabled")
	service.vfx.detail_limit=160
	reset(["슈팅 스타"],"요정","활")
	catalog.learned=all_learned.duplicate(true)
	world._cast_job_skill(str(shooting.id));normal_hit(shooting)
	world._save_game(true)
	var expected_ids: Array[String]=[]
	for record: Dictionary in catalog.current_official.records:expected_ids.append(str(record.id))
	var expected_file:=FileAccess.open("user://local_skill_restart_expect.json",FileAccess.WRITE)
	expected_file.store_string(JSON.stringify({"ids":expected_ids,"mp":world.mp,"window":service.local_runtime.windows[str(shooting.id)]}));expected_file.close()
	world.queue_free();await process_frame
	print("MISSING12_RUNTIME_RESULT checks=%d errors=%d usable=12 map=NativePngField/aden_world" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
