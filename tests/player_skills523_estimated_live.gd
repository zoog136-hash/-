extends "res://tests/player_skills523_live.gd"
## Actual Main/UI verification of the eight user-authorized estimates.
var arena: Vector2

func seed_below(chance: float) -> void:
	var probe := RandomNumberGenerator.new()
	for value: int in range(1, 100):
		probe.seed = value
		if probe.randf() < chance:
			world.rng.seed = value
			return

func enter(job: String) -> void:
	check(QA.enter_game(world,job),"actual class confirmation " + job)
	world.level=90
	reset_cast()
	world.player.global_position=arena
	dummy.global_position=arena+Vector2(96,0)
	dummy.stun_remaining=0;dummy.hold_remaining=0
	world.selected_monster=dummy
	world.inventory["명예 코인"]=1000
	world.inventory["혈정석"]=1000
	world.equipped_items["weapon"]={"name":"검증 체인소드","type":"체인소드","slot":"weapon"} if job=="투사" else {}
	world._invalidate_equipment_static()
	world._update_hud()

func learn_ui(id: String) -> Control:
	var view := await select_skill(id)
	check(view.detail.text.contains("추정"),"actual detail labels estimate " + id)
	check(view.selection_sheet.category.text.begins_with("TWILIGHT 추정"),"visible card header labels estimate without scrolling " + id)
	if str(view.selected.mode)=="status":
		var effective: Dictionary=world.original_skills.catalog.resolve(view.selected)
		var expected := "%.1f~%.1f초" % [float(effective.duration_bounds[0]),float(effective.duration_bounds[1])]
		check(view.selection_sheet.info_text.contains(expected),"compact duration matches actual estimated status bounds " + id)
	check(not view.book_button.disabled,"actual book purchase available " + id)
	view.book_button.pressed.emit()
	view=await select_skill(id)
	check(not view.learn_button.disabled,"actual learning available " + id)
	view.learn_button.pressed.emit()
	view=await select_skill(id)
	check(world.original_skills.catalog.owned(view.selected),"owned via existing UI/save identity " + id)
	return view

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-captures="): captures=arg.get_slice("=",1)
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	world=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world,"마법사"),"actual startup class confirmation")
	world.player.set_physics_process(false);world.player.set_auto_enabled(false)
	world._clear_monsters()
	if is_instance_valid(world.field_population):world.field_population.set_process(false)
	var service=world.original_skills
	var catalog=service.catalog
	check(catalog.source523.profiles.size()==441,"same delivered private source pack consumed")
	var promoted := 0
	for record: Dictionary in catalog.records:
		if record.has("estimated523"):promoted+=1
	check(promoted==8,"exact eight reviewed identities gain estimated execution")
	if promoted!=8:world.queue_free();quit(2);return
	var blocked: Array=catalog.current_official.records.filter(func(row: Dictionary) -> bool:return bool(row.get("runtime_blocked",false)))
	check(not blocked.is_empty() and catalog.resolve(blocked[0]).runtime_blocked,"unrelated reference remains blocked")
	arena=POSITIONS.combat(world,[Vector2(24,0),Vector2(96,0),Vector2(120,0)])
	check(arena.is_finite(),"actual current-map dash lane")
	if not arena.is_finite():world.queue_free();quit(2);return
	dummy=(load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"추정8종 검증 대상","hp":100000,"lv":1,"ac":0,"mr":0,"atk":1},world.player,world,null)
	dummy.set_physics_process(false)
	world.gold=100000000
	enter("마법사")
	var disintegrate := "lm_b39dbcf394503410"
	var view := await learn_ui(disintegrate)
	var old_hp: int=dummy.hp
	view.use_button.pressed.emit()
	check(world.mp==929 and world.pending_attack.has("original_skill"),"native MP70 queued exactly once through UI")
	CLOCK.settle(world)
	check(dummy.hp<old_hp and world.mp==929,"estimated damage uses actual impact path")
	reset_cast()
	var detection := "lmref_a145521a8b2fa008"
	view=await learn_ui(detection)
	world.world_interactions.select_monster(dummy)
	check(dummy.set_concealed523(true) and world._skill_target(240)==null,"concealment prevents current target acquisition")
	check(world.selected_monster==dummy,"hidden explicit selection is not pruned into an implicit different target during cast")
	check(not world.world_interactions.valid(world.world_interactions.monster_entry(dummy)),"hidden target cannot be clicked or retained as valid selection")
	view.use_button.pressed.emit()
	check(world.mp==969 and not dummy.concealed523 and dummy.reveal_lock523==8,"actual detection spends native MP30 and reveals/locks target")
	check(not dummy.set_concealed523(true),"target cannot immediately cloak again")
	check(not service.cost_reason({"mode":"stealth"}).is_empty(),"existing player stealth is also locked after self reveal")
	await capture("detection-estimated",Vector2i(960,540))
	dummy.tick_reveal523(9);service.estimated_nodes.tick(9)
	check(dummy.set_concealed523(true) and service.cost_reason({"mode":"stealth"}).is_empty(),"recloak locks expire without save mutation")
	dummy.set_concealed523(false)
	enter("요정")
	var elemental := "lmref_abb46932647df2be"
	check(catalog.resolve(catalog.record_for(elemental)).range==192,"estimated elemental range without bow")
	world.equipped_items["weapon"]={"name":"검증 활","type":"활","slot":"weapon"}
	world._invalidate_equipment_static()
	check(catalog.resolve(catalog.record_for(elemental)).range==240,"bow changes estimated elemental range through live cache")
	view=await learn_ui(elemental)
	seed_below(.6);view.use_button.pressed.emit();CLOCK.settle(world)
	check(dummy.stun_remaining>=2 and dummy.stun_remaining<=4 and world.mp==964 and int(world.inventory["명예 코인"])==998,"elemental stun affects real NPC with source MP35/coin2")
	enter("다크엘프")
	var recovery := "lm_8e2c8c76c068ae0e"
	view=await learn_ui(recovery)
	world.hp=world._effective_max_hp()-200
	var before_hp: int=world.hp
	view.use_button.pressed.emit()
	check(world.hp==before_hp+100 and world.mp==949 and int(world.inventory["명예 코인"])==990,"recovery heals100 with native MP50/coin10")
	var recovery_stats: Dictionary=world.active_skill_buffs.get("쉐도우 리커버리",{}).get("skill_stats",{})
	check(is_equal_approx(float(recovery_stats.get("dg",0)),8) and is_equal_approx(float(recovery_stats.get("er",0)),8),"recovery applies temporary avoidance via live buff path")
	await capture("recovery-estimated",Vector2i(1280,720))
	enter("투사")
	var grab := "lm_57fedb578e5ba9de"
	view=await learn_ui(grab)
	before_hp=world.hp
	seed_below(.6);view.use_button.pressed.emit();CLOCK.settle(world)
	check(world.player.global_position.distance_to(arena+Vector2(72,0))<.1 and dummy.hold_remaining>=3,"target dash and hold execute through actual cast/impact")
	check(world.hp==before_hp-20 and world.mp==999 and int(world.inventory["혈정석"])==997,"native HP20/material3 spent once for grab")
	reset_cast();world.player.global_position=arena
	world.world_interactions.clear_selection();dummy.global_position=arena+Vector2(600,0)
	world.player.motion.direction=Vector2.RIGHT
	check(world._cast_job_skill(grab) and world.player.global_position.distance_to(arena+Vector2(120,0))<.1,"no-target grab dashes forward on actual walkable lane")
	reset_cast();world.player.global_position=arena;world.selected_monster=dummy
	var inventory_before: Dictionary=world.inventory.duplicate(true)
	before_hp=world.hp
	check(not world._cast_job_skill(grab) and world.hp==before_hp and world.inventory==inventory_before and world.skill_cooldowns.is_empty(),"unreachable explicit target does not redirect or consume resources")
	dummy.global_position=arena+Vector2(96,0)
	var asura := "lmref_b864ab63b5fc91ed"
	view=await learn_ui(asura)
	dummy.hold_remaining=0
	view.use_button.pressed.emit()
	check(world.mp==969 and int(world.inventory["명예 코인"])==970 and world.active_skill_buffs.has("아수라"),"Asura native payment activates estimated self branch")
	var asura_stats: Dictionary=world.active_skill_buffs["아수라"].skill_stats
	check(dummy.hold_remaining==0 and float(asura_stats.get("atk",0))==20 and float(asura_stats.get("meleeHit",0))==5 and float(asura_stats.get("damageReduction",0))==5,"Asura buff reaches live stat service without PC-only monster hold")
	reset_cast()
	var breath := "lmref_5537debb655c3399"
	view=await learn_ui(breath)
	dummy.stun_remaining=0;seed_below(.6)
	view.use_button.pressed.emit();CLOCK.settle(world)
	check(world.mp==984 and int(world.inventory["명예 코인"])==965 and dummy.stun_remaining>=2,"breath stun uses real impact with native MP15/coin5")
	await capture("breath-estimated",Vector2i(1280,720))
	enter("뇌신")
	var protection := "lmref_32fab3b95ec26e3d"
	view=await learn_ui(protection)
	check(view.use_button.disabled and view.quick_button.disabled,"learned protection is passive rather than fabricated active cast")
	check(service.stat("physicalReduction")==5 and service.stat("rangedReduction")==3,"protection passive stats enter actual combat index once")
	seed_below(.35)
	var absorbed: int=service.incoming_damage(dummy,"melee",50)
	check(absorbed==0 and int(service.shields.get(protection,{}).get("amount",0))==35,"incoming hit triggers protection and absorbs same hit")
	var protection_events: int=int(service.event_counts.get(protection,0))
	check(service.incoming_damage(dummy,"melee",50)==10 and not service.shields.has(protection) and not world.active_skill_buffs.has("썬더 프로텍션(미스틱)"),"shield consumption removes aura without doubling passive stats")
	service.incoming_damage(dummy,"melee",50)
	check(int(service.event_counts.get(protection,0))==protection_events,"multihits do not reroll during15second interval")
	check(world._save_game(true)==OK,"estimated skills use existing atomic save writer")
	var state: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(state.original_skill_state.learned.has(protection) and not state.has("estimated523"),"new owned skills retain stable IDs and do not serialize estimate config")
	world.queue_free();await process_frame
	print("SKILLS523_ESTIMATED_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"render_scope":"OpenGL" if not captures.is_empty() else "headless","source_pack":"unchanged version1"}))
	quit(0 if failures.is_empty() else 1)
