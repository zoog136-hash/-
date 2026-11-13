extends "res://tests/player_skills523_live.gd"
const RECOVERY=preload("res://scripts/skills/recovery_rules523.gd")
var source: RefCounted
var settings_only:=false

func clear_conditions() -> void:
	reset_cast()
	for kind: String in ["stun","hold","fear","silence","poison","bleed"]:world.player.set(kind+"_remaining",0.0)

func enter(job: String) -> void:
	check(QA.enter_game(world,job),"actual class confirmation "+job)
	world.level=90;clear_conditions();world.inventory["명예 코인"]=1000

func learn_ui(id: String) -> Control:
	var view:=await select_skill(id)
	check(view.selection_sheet.category.text.begins_with("원본 + TWILIGHT 설정"),"source/host distinction visible "+id)
	check(not view.book_button.disabled,"existing book UI available "+id)
	view.book_button.pressed.emit();view=await select_skill(id)
	check(not view.learn_button.disabled,"existing learning UI available "+id)
	view.learn_button.pressed.emit();view=await select_skill(id)
	check(world.original_skills.catalog.owned(view.selected),"existing learned identity retained "+id)
	return view

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-captures="):captures=arg.get_slice("=",1)
		if arg=="--recovery-settings-only":settings_only=true
	if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world,"기사"),"actual initial class confirmation")
	world.player.set_physics_process(false);world.player.set_auto_enabled(false);world._clear_monsters()
	if is_instance_valid(world.field_population):world.field_population.set_process(false)
	world.level=90;world.gold=100000000
	world._update_hud()
	var catalog=world.original_skills.catalog
	var service=world.original_skills
	source=catalog.source523
	check(source.profiles.size()==441 and source.recovery_rules.percent_denominator==10000,"new source components and percentage units actually consumed")
	if source.recovery_rules.percent_denominator!=10000:world.queue_free();quit(2);return
	var arena: Vector2=POSITIONS.combat(world,[Vector2(24,0)])
	check(arena.is_finite(),"actual source-map combat floor")
	if not arena.is_finite():world.queue_free();quit(2);return
	world.player.global_position=arena
	dummy=(load("res://scenes/Monster.tscn") as PackedScene).instantiate();world.monsters_root.add_child(dummy)
	dummy.setup({"name":"복합 회복 검증 대상","hp":100000,"lv":1,"ac":0,"mr":0,"atk":1},world.player,world,null)
	dummy.global_position=arena+Vector2(24,0);dummy.set_physics_process(false);world.selected_monster=dummy
	check(world._save_game(true)==OK,"real baseline save")
	var save_before: String=FileAccess.get_sha256(world.save_path())
	var inventory_before: Dictionary=world.inventory.duplicate(true)
	var row_before: String=source.evidence_for("lm_62bee07ed64c92aa").row_json
	var sentinel:=ConfigFile.new();sentinel.set_value("unrelated","sentinel","keep");sentinel.save(RECOVERY.PATH)
	source.recovery_rules.reload_settings()
	world.hud.open_settings_info(true)
	for _frame: int in range(3):await process_frame
	var panel: Control=world.hud.workspace.find_child("SkillRecovery523Settings",true,false)
	check(panel!=null,"actual settings window contains recovery controls")
	panel.selector.select(2);panel.selector.item_selected.emit(2)
	panel.heal.value=160;panel.cooldown.value=3.5
	check(source.recovery_rules.value_for("lm_a67097404fc5663e","heal")==160,"actual settings control updates missing restoration amount")
	check(source.recovery_rules.value_for("lm_a67097404fc5663e","cooldown")==3.5,"actual settings control updates host cooldown")
	var loaded:=RECOVERY.new()
	check(loaded.value_for("lm_a67097404fc5663e","heal")==160,"settings survive a fresh rules instance")
	var saved:=ConfigFile.new();saved.load(RECOVERY.PATH)
	check(saved.get_value("unrelated","sentinel","")=="keep","settings preserve unrelated sections")
	check(FileAccess.get_sha256(world.save_path())==save_before and world.inventory==inventory_before,"settings UI does not mutate progression save or inventory")
	var config_sha:=FileAccess.get_sha256(RECOVERY.PATH)
	check(not source.set_recovery_setting("lm_62bee07ed64c92aa","heal_percent",.99) and FileAccess.get_sha256(RECOVERY.PATH)==config_sha,"confirmed native heal percentage cannot be replaced by an estimate setting")
	var settings_scroll: ScrollContainer=world.hud.workspace.find_child("SettingsScroll",true,false)
	for _frame: int in range(2):await process_frame
	settings_scroll.scroll_vertical=int(panel.position.y)
	await capture("source-recovery-settings",Vector2i(1280,720))
	if settings_only:
		world.queue_free();await process_frame
		print("SKILLS523_RECOVERY_SETTINGS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
		quit(0 if failures.is_empty() else 1);return
	enter("기사")
	var clear_id: String="lm_62bee07ed64c92aa"
	var view:=await learn_ui(clear_id)
	world.hp=100;world.player.hold_remaining=5;world.player.stun_remaining=5;world.player.fear_remaining=5;world.player.silence_remaining=5
	var damage_reduction_before: float=service.stat("damageReduction")
	view=await select_skill(clear_id)
	check(not view.use_button.disabled,"native escape flags allow clear while disabled")
	view.use_button.pressed.emit()
	check(world.hp==mini(world._effective_max_hp(),100+int(world._effective_max_hp()*.35)) and world.mp==979 and int(world.inventory["명예 코인"])==992,"clear35percent and native MP20/coin8 are applied once")
	check(world.player.hold_remaining==0 and world.player.stun_remaining==5 and world.player.fear_remaining==5 and world.player.silence_remaining==5,"clear only removes its supported native hold groups")
	check(service.stat("damageReduction")==damage_reduction_before,"native PvP reduction is not invented as PvE reduction")
	await capture("clear-native",Vector2i(960,540))
	enter("투사")
	var dragon: String="lm_517ca31126a31b45"
	view=await learn_ui(dragon)
	world.hp=100;world.player.stun_remaining=4;world.player.hold_remaining=4;world.player.fear_remaining=4
	view.use_button.pressed.emit()
	check(world.hp==mini(world._effective_max_hp(),100+int(world._effective_max_hp()*.5)) and world.mp==949 and int(world.inventory["명예 코인"])==990,"dragon force50percent uses native parent payment")
	check(world.player.stun_remaining==0 and world.player.hold_remaining==0 and world.player.fear_remaining==0,"dragon force supported native groups clear before healing")
	check(service.stat("stunResistance")==10 and float(world.active_skill_buffs["드래곤 포스"].remaining)==5,"native typed stun resistance10 and seconds5 override old guesses")
	enter("뇌신")
	var plasma: String="lm_a67097404fc5663e"
	view=await learn_ui(plasma)
	world.hp=world._effective_max_hp()-300;var hp_before: int=world.hp
	world.player.stun_remaining=4;world.player.hold_remaining=4;world.player.fear_remaining=4;world.player.poison_remaining=4
	view.use_button.pressed.emit()
	check(world.hp==hp_before+160 and world.mp==959 and int(world.inventory["명예 코인"])==990,"plasma uses configured fallback160 and native MP40/coin10")
	check(world.player.stun_remaining==0 and world.player.hold_remaining==0 and world.player.fear_remaining==0 and world.player.poison_remaining==4,"plasma does not invent unrelated poison cleanse")
	check(is_equal_approx(float(world.skill_cooldowns.get("플라즈마 다이브",0)),3.5),"settings affect actual cooldown")
	world.player.motion.hit_clock=0;world.player.show_received_damage(1)
	check(world.player.motion.hit_clock==0 and service.stat("ignoreDamageMotion")==1,"source plasma flag suppresses real hit motion without suppressing HP damage")
	var drop: Button=world._spawn_ground_drop("HP 물약",world.player.global_position,1)
	var potions: int=int(world.inventory.get("HP 물약",0))
	check(is_instance_valid(drop) and not world._collect_ground_drop(drop) and int(world.inventory.get("HP 물약",0))==potions and world.ground_loot.valid_view(drop),"native no-loot flag preserves real ground item and inventory")
	world.player.poison_remaining=0
	check(world._queue_player_attack(dummy,"melee",func() -> void:pass,.4,true,100),"actual attack starts after plasma")
	check(service.stat("cannotLoot")==0 and not world.active_skill_buffs.has("플라즈마 다이브"),"native attack-erasure ends plasma restrictions")
	world._clear_combat_actions()
	(drop as TwilightGroundLoot).visible_since=Time.get_ticks_msec()-2000
	check(world._collect_ground_drop(drop) and int(world.inventory.get("HP 물약",0))==potions+1,"ground item can be collected after restriction ends")
	check(not world._collect_ground_drop(drop) and int(world.inventory.get("HP 물약",0))==potions+1,"repeat pickup cannot duplicate grant")
	enter("마검사")
	var life: String="lm_1fb2fb45ca7bb6e5"
	check(source.set_recovery_setting(life,"heal",350) and source.set_recovery_setting(life,"shield_cap_percent",10),"shield host cap and missing restoration remain independently configurable")
	view=await learn_ui(life)
	world.hp=world._effective_max_hp()-50;view.use_button.pressed.emit()
	var expected_cap: int=int(world._effective_max_hp()*.1)
	check(world.hp==world._effective_max_hp() and int(service.shields.get(life,{}).get("amount",0))==expected_cap and world.mp==959,"overheal converts once and respects configured cap")
	check(float(service.shields[life].remaining)==5 and int(world.inventory["명예 코인"])==990,"native shield duration and parent material cost retained")
	var damage: int=service.incoming_damage(dummy,"melee",50)
	check(damage==0 and int(service.shields[life].amount)==expected_cap-50,"life shield participates in real incoming damage")
	clear_conditions();world.hp=world._effective_max_hp()
	check(world._cast_job_skill(life) and int(service.shields[life].amount)==expected_cap,"repeat overheal replaces rather than accumulates shield")
	service.tick(6)
	check(not service.shields.has(life) and not world.active_skill_buffs.has("라이프 스트림"),"shield expiry removes actual shield aura")
	enter("마법사")
	var full: String="lm_81c8985fec94cf55"
	check(source.set_recovery_setting(full,"average_dice",1),"host dice-average policy can be configured without changing native coefficients")
	view=await learn_ui(full)
	world.hp=100;var sp: int=world._spell_power_stat()
	view.use_button.pressed.emit()
	check(world.hp==mini(world._effective_max_hp(),100+40+60+sp*3) and world.mp==959 and int(world.inventory["명예 코인"])==997,"full heal uses native coefficients and self-target SpellCost MP40/coin3")
	clear_conditions();world.hp=world._effective_max_hp();var rng_before: int=world.rng.state
	check(not world._cast_job_skill(full) and world.mp==999 and world.rng.state==rng_before,"full HP does not roll dice spend MP or start cooldown")
	var cure: String="lm_2b058c083f711c56"
	view=await learn_ui(cure);world.player.apply_poison(5,1);view.use_button.pressed.emit()
	check(world.player.poison_remaining==0 and world.mp==984,"original poison cure has an actual self branch and native MP15")
	clear_conditions()
	var immune: String="lm_b1922663d36bc890"
	world.inventory["마력의 돌"]=2
	view=await learn_ui(immune)
	view.use_button.pressed.emit()
	check(world.mp==969 and int(world.inventory["마력의 돌"])==0,"immune to harm uses confirmed self-target SpellCost MP30/material2")
	check(float(world.active_skill_buffs["이뮨 투 함"].remaining)==60 and service.incoming_damage(dummy,"magic",100)==50,"native50percent and60seconds reach actual incoming damage")
	var pack_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-skills523-pack="):pack_path=arg.get_slice("=",1)
	var broken_pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(pack_path))
	var component: Dictionary=broken_pack.profiles[clear_id].components[0]
	component.row.ID=99999991;component.row_json=JSON.stringify(component.row)
	var broken_path: String="user://skills523-invalid-component.json"
	var broken_file:=FileAccess.open(broken_path,FileAccess.WRITE);broken_file.store_string(JSON.stringify(broken_pack));broken_file.close()
	var source_revision: int=source.revision;var source_sha: String=source.active_sha256
	check(not source.load_pack(broken_path,FileAccess.get_sha256(broken_path)),"unlinked child identity cannot replace source snapshot")
	check(source.revision==source_revision and source.active_sha256==source_sha and source.recovery_rules.percent_denominator==10000,"failed component swap preserves active rules and metadata atomically")
	DirAccess.remove_absolute(broken_path)
	check(source.evidence_for(clear_id).row_json==row_before,"runtime projections and settings preserve original rows")
	check(world._save_game(true)==OK,"new recovery paths persist through existing atomic save")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(payload.original_skill_state.learned.has(life) and not payload.has("recovery523"),"stable learned IDs persist while configuration stays separate")
	world.queue_free();await process_frame
	print("SKILLS523_RECOVERY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Main/current source map/settings/UI/self recovery"}))
	quit(0 if failures.is_empty() else 1)
