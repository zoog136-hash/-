extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const PANEL = preload("res://scripts/ui/patch523_npc_panel.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
var checks: int = 0
var failures: Array[String] = []
var screens: String = ""
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func _init() -> void: call_deferred("run")
func actor_for(world: Node) -> Node:
	var actor = world.MONSTER_SCENE.instantiate(); world.monsters_root.add_child(actor); actor.global_position = world.player.global_position+Vector2(24,0)
	actor.setup({"name":"TWILIGHT policy fixture","lv":1,"hp":1000,"xp":25,"gold":0,"atk":10,"speed":100},world.player,world,null)
	actor.hide(); actor.set_physics_process(false); return actor
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-screen-dir="): screens = arg.trim_prefix("--patch523-screen-dir=")
	if not screens.is_empty(): DirAccess.make_dir_recursive_absolute(screens)
	var world = (load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world) and world.field_map != null and not world.map_bootstrap_blocked,"real Main/current source field")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	var ext = world.patch523_npc_spells.extensions; var p = ext.remaining
	world.patch523_npc_spells.host_enabled = true; world.patch523_npc_spells.tick(0); ext.enabled = true; ext.environment_enabled = true
	# Initial actor must be outside any previously saved own binding before the UI entry test.
	p.own_buff = 0; ext.own_attribute = 0
	var panel: CanvasLayer
	for child: Node in world.get_children():
		if child.get_script() == PANEL: panel = child
	check(panel != null,"actual policy inspector")
	var actor: Node = actor_for(world)
	(panel.find_child("BossRemaining_stats_enabled",true,false) as CheckButton).button_pressed = true
	panel.remaining_buff_choice.select(panel.remaining_buff_ids.find(70874)); panel.find_child("BossRemainingBind",true,false).pressed.emit()
	check(p.own_buff == 70874 and p.own_map == world.active_map_id,"explicit own buff binding from actual UI")
	check(actor.source_523_base_max_hp == 1000 and actor.max_hp == 1500 and actor.hp == 1000,"source HP cap adds500 with no boundary healing/base overwrite")
	var base_melee: int = actor.melee_accuracy; var base_range: int = actor.ranged_accuracy
	check(world._monster_accuracy_for_attack_type(actor,"melee") == base_melee+10 and world._monster_accuracy_for_attack_type(actor,"ranged") == base_range+10,"STR/DEX reach existing accuracy API")
	var flat: int = int(world.patch523_npc_spells.catalog.scalar("BuffBonus",70874,"MeleeDamage","Value"))
	check(ext.outgoing(actor,100,"melee") == 100+flat+10,"STR reaches existing outgoing damage API")
	check(panel.update_remaining("strength_damage",2.0) and ext.outgoing(actor,100,"melee") == 100+flat+20,"own attribute coefficient is configurable and persisted")
	p.strength_damage = 1
	actor.hp = 1490
	var region: Dictionary = {"id":"qa-regional-hp","boss_id":"qa-regional-hp","layout_revision":int(world.field_map.data.layout_revision)}
	world.field_population.boss_director.capture(world.active_map_id,region,actor)
	check(int(world.field_population.boss_director.state_for(world.active_map_id,region).hp) == 1490,"existing boss state captures HP above immutable base")
	actor.global_position += Vector2(ext.own_radius+100,0); p.sync_actor(actor)
	check(actor.max_hp == 1000 and actor.hp == 1000 and actor.melee_accuracy == base_melee,"exit restores cap/current HP and leaves base stats intact")
	actor.global_position = p.own_center+Vector2(24,0); p.sync_actor(actor)
	check(actor.max_hp == 1500 and actor.hp == 1000,"reentry grants cap but no free HP")
	check(not ext.dismiss(actor) and actor.max_hp == 1500,"source cancellation immunity protects regional HP/stat effects")
	check(panel.update_remaining("own_buff",0) and actor.max_hp == 1000,"explicit removal of own context stops its effects")
	p.own_buff = 70874
	actor.position += Vector2(ext.own_radius+100,0); ext.tick_environment(.3); actor.global_position = p.own_center; ext.tick_environment(.3)
	check(actor.max_hp == 1500,"same-life exit/reentry restores dismissed context")
	p.own_buff = 57244; actor.apply_slow(5,.5)
	check(is_equal_approx(actor.source_523_speed_factor(),1.1) and is_equal_approx(actor.move_speed,50),"raw percentage speed multiplies existing slow without rewriting base")
	actor.fear_source_position = actor.global_position-Vector2(30,0)
	var boosted: float = actor._fear_velocity().length(); p.own_buff = 0
	check(is_equal_approx(boosted/actor._fear_velocity().length(),1.1),"actual movement consumer uses regional factor")
	p.own_buff = 70874
	check(panel.update_remaining("stats_enabled",false) and actor.max_hp == 1000,"turning policy off restores base cap")
	p.sync_actor(actor); panel.update_remaining("stats_enabled",true)
	actor.setup({"name":"reused policy fixture","hp":1000,"xp":25,"atk":10,"speed":100},world.player,world,null); actor.set_physics_process(false); actor.hide()
	check(actor.source_523_base_max_hp == 1000 and actor.max_hp == 1500 and p.reward_for(actor).is_empty(),"pooled life has one base/bonus and no old reward receipt")
	# Exact source context for XP plus a separate explicit item-buff context.
	ext.own_attribute = 217054; ext.own_map = world.active_map_id; ext.own_center = world.player.global_position; p.own_buff = 54074
	(panel.find_child("BossRemaining_drops_enabled",true,false) as CheckButton).button_pressed = true
	var names: Array[String] = []
	for name: String in world.loot_catalog.by_name:
		var row: Dictionary = world.loot_catalog.by_name[name]
		if str(row.get("grade","")) == "일반" and str(row.get("slot","")) in ["weapon","armor"]: names.append(name)
		if names.size() == 2: break
	check(names.size() == 2,"actual eligible same-grade catalog items available")
	p.item_bindings = {"327293":names[0]}
	var weights: Dictionary = p.drop_weights(actor)
	check(weights.get(names[0],0) == 2.5 and not weights.has(names[1]),"typed exact ItemClass target applies explicit own denominator")
	var original_names: Dictionary = world.loot_catalog.by_name
	world.loot_catalog.by_name = {names[0]:original_names[names[0]].duplicate(true),names[1]:original_names[names[1]].duplicate(true)}
	for row: Dictionary in world.loot_catalog.by_name.values(): row.erase("source_item_class_id")
	p.item_bindings.clear()
	check(p.drop_weights(actor).is_empty(),"unmatched source ItemClass never selects an arbitrary catalog name")
	world.loot_catalog.by_name[names[0]]["source_item_class_id"] = 327293
	check(p.drop_weights(actor) == {names[0]:2.5},"unique exact source ItemClass resolves automatically")
	world.loot_catalog.by_name[names[1]]["source_item_class_id"] = 327293
	check(p.drop_weights(actor).is_empty(),"ambiguous exact source variants require explicit user selection")
	p.item_bindings = {"327293":names[0]}; world.loot_catalog.by_name = original_names
	var original_catalog: String = JSON.stringify(world.loot_catalog)
	var targeted: int = 0
	var rng := RandomNumberGenerator.new(); rng.seed = 123
	for i: int in 300:
		var item: Dictionary = LOOT._pick_equipment_entry("일반",names,world.loot_catalog,rng,"QA unique pool",{},weights)
		check(names.has(str(item.get("item_name",""))) and item.get("quantity") == 1,"same successful-grade pool and quantity preserved")
		if item.get("item_name") == names[0]: targeted += 1
	check(targeted > 175 and JSON.stringify(world.loot_catalog) == original_catalog,"selection weighting changes choices without catalog mutation")
	for boss: bool in [false,true]:
		for seed_value: int in range(30):
			var a := RandomNumberGenerator.new(); var b := RandomNumberGenerator.new(); a.seed = seed_value; b.seed = seed_value
			check(LOOT.roll_detailed(names,boss,world.loot_catalog,a,"QA unique pool") == LOOT.roll_detailed(names,boss,world.loot_catalog,b,"QA unique pool",{},"",{} ) and a.state == b.state,"disabled/empty weighting preserves exact existing rolls and RNG")
	var xp_before: int = world.experience; var expected: int = int(round((actor.exp_reward+10000)*world._experience_multiplier()*world.ain_service.experience_rate()*world.EXP_PROGRESSION.map_exp_multiplier(world._kill_map_id())))
	actor.died.connect(world._on_monster_died); actor.take_damage(actor.hp+100)
	check(world.experience == xp_before+expected,"actual death uses captured regional flat XP with existing rates")
	check(p.reward_for(actor).is_empty(),"claimed death consumes the transient reward snapshot")
	var xp_after: int = world.experience; var gold_after: int = world.gold; var drops_after: int = world.ground_loot.records.size()
	world._on_monster_died(actor)
	check(world.experience == xp_after and world.gold == gold_after and world.ground_loot.records.size() == drops_after,"duplicate death cannot duplicate XP/currency/drop rolls")
	var helper: Node = actor_for(world); helper.set_meta("summoned",true); helper.died.connect(world._on_monster_died); helper.take_damage(helper.hp+100)
	check(world.experience == xp_after and world.ground_loot.records.size() == drops_after,"summoned no-reward branch remains before bonuses")
	var target: Node = actor_for(world); p.own_buff = 0; ext.own_attribute = 154063
	ext.reaction_enabled = true
	var seed: int = 0
	for n: int in 100:
		world.rng.seed = n
		if world.rng.randf() < .2: seed = n; break
	for pair: Array in [[42,false,6403],[42,true,6423],[72,false,6413],[72,true,6433]]:
		p.special_type = pair[0]; world.rng.seed = seed; world.hp = 1000
		ext.begin_incoming(target,100,"melee",pair[1]); var damage: int = ext.before_damage(target,100,"")
		check(damage == 0 and ext.last_event.invoke == pair[2],"explicit special tag selects exact original branch "+str(pair))
		check(ext.last_event.get("channel") == "melee","special reaction tag does not convert damage channel")
	p.special_type = 0
	var battle_triggered: bool = false; p.special_type = 42
	for n: int in 100:
		target.hp = target.max_hp; world.hp = 1000; world.rng.seed = n; ext.last_event.clear()
		world._deal_successful_player_hit(target,100,false,"melee",false)
		if ext.last_event.get("invoke") == 6403:
			battle_triggered = ext.last_event.get("channel") == "melee"; break
	check(battle_triggered,"actual player successful-hit API reaches explicit Dark branch without channel conversion")
	p.special_type = 0
	world.active_skill_buffs.clear()
	var cancel_base_hp: int = world._effective_max_hp(); var cancel_base_mp: int = world._effective_max_mp()
	world.active_skill_buffs = {"QA remove":{"skill_id":"qa-remove","remaining":30,"skill_stats":{"speed":1.1,"hp":500,"mp":200}},"QA keep":{"remaining":30},"QA immune":{"remaining":30,"IsImmuneToCancellation":true},"QA summon":{"remaining":30,"summon_stage":"entity"}}
	world.hp = world._effective_max_hp(); world.mp = world._effective_max_mp()
	check(world.hp == cancel_base_hp+500 and world.mp == cancel_base_mp+200,"host buff actually increases effective HP/MP before source cancel")
	var cancel: OptionButton = panel.find_child("BossRemainingCancel",true,false); cancel.select(2); cancel.item_selected.emit(2)
	var protect: LineEdit = panel.find_child("BossRemaining_protected_host_buffs",true,false); protect.text = "QA keep"; protect.text_submitted.emit(protect.text)
	check(p.cancel_host([192]) == 0 and world.active_skill_buffs.has("QA remove"),"group-specific cancel does not guess unknown host groups")
	var caster: Node = actor_for(world); caster.source_m_npc_id = 104258; caster.source_m_original = world.patch523_npc_spells.catalog.row("NpcClass",104258).duplicate(true); caster.magic_accuracy = 1000000
	var current_field: Variant = world.field_map; var current_astar: Variant = world.astar
	world.field_map = null; world.astar = AStarGrid2D.new(); world.astar.region = Rect2i(world._world_to_cell(world.player.global_position)-Vector2i(50,50),Vector2i(100,100)); world.astar.update(); world.rng.seed = 42
	check(world.patch523_npc_spells.try_begin(caster,true,355058),"actual source NPC begins cancellation under explicit host policy")
	caster.motion.advance(.65,Vector2.ZERO)
	world.field_map = current_field; world.astar = current_astar
	check(not world.active_skill_buffs.has("QA remove") and world.active_skill_buffs.has("QA keep") and world.active_skill_buffs.has("QA immune") and world.active_skill_buffs.has("QA summon"),"actual cancellation preserves declared/user immunity and summoned entities")
	check(world.hp == cancel_base_hp and world.mp == cancel_base_mp and world._effective_max_hp() == cancel_base_hp and world._effective_max_mp() == cancel_base_mp,"actual source cancellation clamps HP/MP to restored caps without restoring removed buff")
	world.active_skill_buffs.clear()
	var cfg_path: String = ext.settings_path; check(ext.save_settings() == OK,"persist selected policies before reconnect")
	var cfg_sha: String = FileAccess.get_sha256(cfg_path); ext.settings_path = "user://absent-parent/remaining.cfg"
	check(not panel.update_remaining("stats_enabled",false) and p.stats_enabled and FileAccess.get_sha256(cfg_path) == cfg_sha,"failed policy persistence restores value and prior bytes")
	ext.settings_path = cfg_path
	panel.get_node("BossSkillsButton").pressed.emit(); panel.find_child("BossRemainingOpen",true,false).pressed.emit()
	await process_frame; await process_frame
	(panel.find_child("BossSkillsScroll",true,false) as ScrollContainer).ensure_control_visible(panel.find_child("BossRemainingSpecial",true,false))
	if not screens.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(screens.path_join("remaining-policy-main.png")) == OK,"actual own policy UI render")
	panel.panel.hide()
	check(world._save_game(true) == OK,"actual save after regional consumers")
	var path: String = world.save_path(); var digest: String = FileAccess.get_sha256(path); var saved_xp: int = world.experience
	var pack: String = OS.get_environment("TWILIGHT_SOURCE_MAP_PACK"); OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",ProjectSettings.globalize_path("user://missing-remaining-map")); world._load_game(true)
	check(world.source_save_blocked and world.experience == saved_xp and FileAccess.get_sha256(path) == digest,"rejected load preserves actual progression and original bytes")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",pack); world._load_game(true)
	check(not world.source_save_blocked and world.experience == saved_xp and FileAccess.get_sha256(path) == digest and p.rewards.is_empty(),"accepted reconnect clears transient reward receipts and preserves progression")
	var restored = ext.get_script().new(); restored.configure(world.patch523_npc_spells)
	check(restored.remaining.stats_enabled and restored.remaining.drops_enabled and restored.remaining.host_cancel_mode == 2 and restored.remaining.item_bindings == p.item_bindings,"separate user policies restore on new service")
	p.own_buff = 70874; ext.own_attribute = 0
	var fresh: Node = actor_for(world)
	var state: Dictionary = world.field_population.boss_director.state_for(world.active_map_id,region)
	world.field_population.restore_boss_hp(fresh,state)
	check(state.hp == 1490 and fresh.max_hp == 1500 and fresh.hp == 1490 and fresh.source_523_base_max_hp == 1000,"production boss restore resolves final regional max before preserving above-base saved HP")
	var all_buffs: Dictionary = {}
	for entry: Dictionary in world.patch523_npc_spells.catalog.content.tables.LandAttribute.values(): all_buffs[int(entry.row.Value)] = true
	for buff_id: int in all_buffs:
		p.own_buff = buff_id
		var c = world.patch523_npc_spells.catalog
		check(fresh.max_hp == 1000+int(c.scalar("BuffBonus",buff_id,"HPPlus","Value")),"all180 real max HP consumer "+str(buff_id))
		check(world._monster_accuracy_for_attack_type(fresh,"melee") == fresh.melee_accuracy+int(c.scalar("BuffBonus",buff_id,"Strength","Value")),"all180 real STR accuracy "+str(buff_id))
		check(world._monster_accuracy_for_attack_type(fresh,"ranged") == fresh.ranged_accuracy+int(c.scalar("BuffBonus",buff_id,"Dexterity","Value")),"all180 real DEX accuracy "+str(buff_id))
		check(is_equal_approx(fresh.source_523_speed_factor(),1+c.scalar("BuffBonus",buff_id,"MoveSpeedBonus","Percentage")/1000000.0),"all180 real speed consumer "+str(buff_id))
		p.capture_rewards(fresh)
		check(p.reward_for(fresh).experience == int(c.scalar("BuffBonus",buff_id,"AddtionalExperience","Value")),"all180 captured XP consumer "+str(buff_id))
		check(fresh.source_523_base_max_hp == 1000 and fresh.exp_reward == 25,"all180 preserve original max/XP fields "+str(buff_id))
	var drop_rows: int = 0; var drop_buffs: Dictionary = {}
	for entry: Dictionary in world.patch523_npc_spells.catalog.content.tables.BuffClass.values():
		for edge: Dictionary in world.patch523_npc_spells.catalog.buff_details(int(entry.row.ID)).bonuses:
			if edge.type.get("Name") != "NpcSingleItemDropProbabilityMultiple": continue
			p.own_buff = int(entry.row.ID); p.item_bindings = {str(int(edge.bonus.BonusApplicationTargetID)):names[0]}
			check(p.drop_weights(fresh).get(names[0]) == float(edge.bonus.Value)/p.drop_divisor,"all18 exact typed drop consumer "+str(edge.link.ID))
			drop_rows += 1; drop_buffs[p.own_buff] = true
	check(all_buffs.size() == 180 and drop_rows == 18 and drop_buffs.size() == 8,"full source180 environment buffs and18 item edges across8 carriers covered")
	p.own_buff = 70874
	var base_only: Node = actor_for(world)
	base_only.setup({"name":"QA default-stat preservation","hp":100,"atk":1},world.player,world,null); base_only.set_physics_process(false); base_only.hide()
	check(base_only.source_523_base_max_hp == 100 and base_only.max_hp == 600 and base_only.exp_reward == 25 and base_only.gold_reward == 33 and base_only.base_move_speed == 80,"regional HP never leaks into base derived XP/gold/speed")
	world.queue_free(); await process_frame
	print("PATCH523_REMAINING_MAIN_RESULT checks=",checks," failures=",JSON.stringify(failures)," source_matrix_buffs=180 drop_rows=18; one_explicit_current_field_fixture=true; local_only=true; native_semantics_not_claimed=true")
	quit(0 if failures.is_empty() else 1)
