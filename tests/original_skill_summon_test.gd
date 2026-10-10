extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var world: TwilightWorld
var dummy: TwilightMonster
var guardian: Dictionary

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		print("SUMMON FAIL: ",message)

func fresh() -> void:
	world._clear_combat_actions()
	world.active_skill_buffs.clear()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.hp = world._effective_max_hp()
	world.mp = 999

func hit_seed(chance: float, hit: bool) -> void:
	for seed_value: int in range(10000):
		world.rng.seed = seed_value
		if (world.rng.randf() < chance) == hit:
			world.rng.seed = seed_value
			return

func queue_strike() -> void:
	var summons := world.original_skills.summons
	summons.actor.age = 1
	summons.actor.global_position = dummy.global_position-Vector2(20,0)
	summons.attack_clock = 0
	check(summons.command("attack",dummy),"attack command accepts a living NPC")
	summons.tick(.01)
	check(not summons.pending_hit.is_empty(),"guardian schedules its own strike")

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"enter actual gameplay")
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.job_class = "마법사"
	world.level = 90;world.max_hp = 5000
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300,4370)))
	world.equipped_items.clear();world.equipped_catalog.clear()
	world.original_skills.catalog.learned.clear()
	world.original_skills.catalog.seed_starters()
	guardian = world.original_skills.catalog.record_for("서먼 가디언")
	check(not guardian.is_empty(),"dated guardian record")
	if guardian.is_empty(): quit(1);return
	world.inventory[str(guardian.book_name)] = 1
	check(world.original_skills.catalog.learn(str(guardian.id)),"learn through the book service")
	check(int(world.inventory[str(guardian.book_name)]) == 0,"book consumed once")
	dummy = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"가디언 검증 NPC","hp":1000000,"lv":1,"ac":0,"mr":0,"atk":1},world.player,world,null)
	dummy.global_position = world.player.global_position+Vector2(30,0)
	dummy.set_physics_process(false)
	world.selected_monster = dummy
	var service := world.original_skills
	var summons := service.summons
	fresh()
	check(world._cast_job_skill(str(guardian.name)),"manual summon")
	check(world.mp == 999-int(guardian.mp),"exact MP cost")
	check(summons.active(str(guardian.id)),"independent creature")
	check(not world._cast_job_skill(str(guardian.name)),"duplicate denied")
	check(world.mp == 999-int(guardian.mp),"denied duplicate costs nothing")
	check(not service.auto_wants(guardian),"automatic summon respects creature")
	var hits := dummy.damage_hit_count
	queue_strike()
	summons.tick(float(guardian.summon_strike_time)*.5)
	check(dummy.damage_hit_count == hits,"windup has no early damage")
	var chance := world._physical_hit_chance(int(guardian.summon_accuracy)+world.level,dummy.armor_class,0)
	hit_seed(chance,true)
	summons.tick(float(guardian.summon_strike_time)*.6)
	check(dummy.damage_hit_count == hits+1 and summons.hit_events == 1,"one marker equals one confirmed hit")
	check(summons.actor.recovery_remaining > 0,"impact retains strike pose")
	summons.tick(.01)
	check(dummy.damage_hit_count == hits+1,"no duplicate hit")
	queue_strike()
	var effects := service.vfx.live.size()
	hit_seed(chance,false)
	summons.tick(float(guardian.summon_strike_time)+.01)
	check(dummy.damage_hit_count == hits+1 and service.vfx.live.size() == effects,"miss has no impact explosion")
	queue_strike();dummy.life_id += 1
	summons.tick(float(guardian.summon_strike_time)+.01)
	check(dummy.damage_hit_count == hits+1,"recycled target cancels old strike")
	queue_strike();dummy.dead = true
	summons.tick(float(guardian.summon_strike_time)+.01)
	check(dummy.damage_hit_count == hits+1,"dead target cancels strike")
	dummy.dead = false
	check(summons.command("stay"),"stay command")
	var location := summons.actor.global_position
	for _step: int in range(10): summons.tick(.1)
	check(summons.actor.global_position == location and dummy.damage_hit_count == hits+1,"stay prevents chase/attack")
	check(summons.command("follow"),"follow command")
	summons.actor.global_position = world._random_walkable_position(world.player.global_position,180,240)
	location = summons.actor.global_position
	for _step: int in range(20): summons.tick(.1)
	check(summons.actor.global_position != location,"follows via map pathfinder")
	check(world._is_walkable_world(summons.actor.global_position),"cannot enter blocked cells")
	check(summons.command("guard"),"guard command")
	service.incoming_damage(dummy,"magic",1)
	check(summons.choose_target() == dummy,"owner threat becomes defense target")
	summons.command("follow")
	var state := service.export_state()
	var mp_before := world.mp
	service.import_state(JSON.parse_string(JSON.stringify(state)))
	check(summons.active() and summons.order == "follow","JSON save round trip restores summon")
	check(summons.pending_hit.is_empty() and world.mp == mp_before,"load replays no strike and charges no MP")
	check(summons.remaining <= float(state.summon.remaining),"load cannot extend duration")
	var sp_before := world._spell_power_stat()
	world.equipped_items["weapon"] = {"name":"검증 SP 지팡이","type":"지팡이","slot":"weapon","atk":0,"sp":4,"instance_id":"summon-sp-test","enhance_level":0,"is_engraved":true,"bless_state":"blessed"}
	check(world._spell_power_stat() == sp_before+4,"SP gear affects shield separately from flat spell damage")
	var item_state := world.equipped_items.duplicate(true)
	var expected_capacity := mini(int(guardian.guardian_shield_base)+int(world._spell_power_stat()*float(guardian.guardian_shield_sp_scale)),int(world._effective_max_hp()*float(guardian.guardian_shield_hp_cap)))
	world.hp = 30
	var triggering_damage := world.hp+10
	var absorbed := service.incoming_damage(dummy,"magic",triggering_damage)
	check(not summons.active() and summons.shield_events == 1,"low HP releases creature exactly once")
	check(absorbed == 0,"shield absorbs triggering lethal hit")
	check(str(world.active_skill_buffs[str(guardian.name)].summon_stage) == "shield","buff becomes shield stage")
	check(int(service.shields.get(str(guardian.id),{}).get("amount",0)) == expected_capacity-triggering_damage,"SP capacity uses shared damage calculation")
	check(world.equipped_items == item_state,"instance/enhancement/engraving/blessing untouched")
	check(not service.auto_wants(guardian),"auto casting respects shield")
	state = service.export_state()
	service.import_state(JSON.parse_string(JSON.stringify(state)))
	check(str(world.active_skill_buffs.get(str(guardian.name),{}).get("summon_stage","")) == "shield" and not summons.active(),"shield save restores aura without resurrecting creature")
	service.incoming_damage(dummy,"magic",1)
	check(summons.shield_events == 1,"no recursive shield conversion")
	var leftover := service.incoming_damage(dummy,"magic",expected_capacity)
	check(leftover == triggering_damage+1 and service.shields.is_empty(),"depletion returns exact unabsorbed damage")
	check(not world.active_skill_buffs.has(str(guardian.name)),"depleted aura removed")
	fresh()
	check(world._cast_job_skill(str(guardian.name)),"cast before map cancellation")
	queue_strike();world.combat_generation += 1;summons.tick(1)
	check(not summons.active() and summons.pending_hit.is_empty(),"map generation cancellation")
	check(dummy.damage_hit_count == hits+1,"cancelled generation cannot hit")
	fresh()
	check(world._cast_job_skill(str(guardian.name)),"cast before death")
	world.hp = 0;summons.tick(.1)
	check(not summons.active(),"owner death cleanup")
	fresh()
	check(world._cast_job_skill(str(guardian.name)),"cast before class change")
	world._on_job_class_selected("기사")
	check(not summons.active(),"class change cleanup")
	world.job_class = "마법사";fresh()
	check(world._cast_job_skill(str(guardian.name)),"cast before expiry")
	summons.tick(float(guardian.duration)+1)
	check(not summons.active() and not world.active_skill_buffs.has(str(guardian.name)),"expiry removes actor/aura")
	fresh()
	world.quickslots = [{"kind":"skill","id":str(guardian.name),"skill_id":str(guardian.id),"auto":true}]
	world.auto_buff_check_timer = 0
	world._run_auto_buff_quickslots(1)
	check(summons.active() and world.mp == 999-int(guardian.mp),"auto slot shares manual service/cost")
	check(summons.command("dismiss") and not summons.active(),"dismiss cleanup")
	world._update_hud();world.hud.open_skills()
	await process_frame
	var view: Node = world.hud.skills_view
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].id) == str(guardian.id): view.cards.select(index);view.select(index)
	check(view.summon_controls.visible,"skill UI exposes summon commands")
	world.queue_free()
	for _frame: int in range(3): await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_SUMMON_OK hit_events=",summons.hit_events," shield_events=",summons.shield_events)
	quit(0 if failures.is_empty() else 1)
