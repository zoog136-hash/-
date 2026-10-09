extends SceneTree

const METER = preload("res://tests/qa_combat_hud_world.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failed: bool = false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failed = true; print("COMBAT HUD FAIL: " + message)

func check_vitals(world: TwilightWorld, message: String) -> void:
	check(int(world.hud.hp_bar.value)==world.hp and int(world.hud.mp_bar.value)==world.mp,message+" HUD bars")
	check(int(world.hud.character_state.hp)==world.hp and int(world.hud.character_state.mp)==world.mp,message+" HUD snapshot")
	var side: TwilightSideUI = world.hud.lineage_side_ui
	check(side.hp_label.text=="HP %d / %d" % [world.hp,int(world.hud.hp_bar.max_value)],message+" open sheet HP")
	check(side.mp_label.text=="MP %d / %d" % [world.mp,int(world.hud.mp_bar.max_value)],message+" open sheet MP")
	check(int(world.hud.lineage_inventory_ui.character_state.hp)==world.hp,message+" inventory snapshot")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	world.set_script(METER)
	root.add_child(world)
	check(CLASS_QA.enter_game(world),"gameplay entry")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.player.global_position = Vector2(3550,4300)
	world.quickslots = []
	world.save_timer = -100000
	# Isolate HP-only strikes; stat-changing procs are exercised separately below.
	for index: int in range(world.skills_db.size()-1,-1,-1):
		var skill: Dictionary = world.skills_db[index]
		if world._is_passive_skill(skill) and world.SKILL_RULES.passive_trigger(skill)=="on_damaged":
			world.skills_db.remove_at(index)
	for mob: TwilightMonster in world.monsters_root.get_children(): mob.set_physics_process(false)
	var attacker: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(attacker)
	var record: Dictionary = world.monster_db[0].duplicate(true)
	record.merge({"hp":999999,"crit":0,"melee_crit":0,"ranged_crit":0,"magic_crit":0},true)
	attacker.setup(record,world.player,world,world._monster_texture(record))
	attacker.global_position = world.player.global_position+Vector2(40,0)
	attacker.set_physics_process(false)
	world.set("force_monster_hits",true)
	world.max_hp = 20000
	world.hp = 20000
	world._update_hud()
	world.hud.open_character()
	var ids_before: Dictionary = world.item_instances.duplicate(true)
	var equipped_before: Dictionary = world.hud.character_state.equipped_items.duplicate(true)
	var expected_hp: int = world.hp
	world.call("reset_hud_counts")
	for frame: int in range(32):
		for index: int in range(6):
			var kind: String = ["melee","ranged","magic"][(frame*6+index)%3]
			var expected_damage: int = 37 if kind=="magic" else world._physical_damage_after_reduction(37)
			expected_damage = world._pve_damage_after_item_buffs(expected_damage)
			expected_hp -= expected_damage
			world._on_player_hit(attacker,37,kind)
			check(world.hp==expected_hp,"live damage formula for "+kind)
			check_vitals(world,"strike")
		world._process(1./60.)
	check(int(world.get("full_hud_refreshes"))==0,"192 strikes queue no full HUD rebuild")
	check(int(world.get("equipment_syncs"))==0,"192 strikes do not resync equipment IDs")
	check(int(world.get("character_snapshots"))==0,"192 strikes do not recalculate character stats")
	check(int(world.get("max_hp_queries"))==0 and int(world.get("max_mp_queries"))==0,"presentation reuses stat-change limits")
	check(world.item_instances==ids_before and world.hud.character_state.equipped_items==equipped_before,"physical items unchanged by incoming damage")
	world._on_player_poison_tick(7)
	world._on_player_bleed_tick(11)
	check(world.hp==expected_hp-18,"poison/bleed damage")
	check_vitals(world,"poison/bleed")
	check(int(world.get("full_hud_refreshes"))==0,"damage-over-time remains lightweight")
	world.mp = 17
	world._refresh_combat_hud()
	check_vitals(world,"MP changed")
	# New HP/MP limits from equipment/buffs must supersede the presentation cache.
	world._equip_catalog("성물",{"name":"HUD QA relic","hpFlat":125,"mpFlat":23})
	check(int(world.hud.hp_bar.max_value)==world._effective_max_hp(),"equipment HP limit refreshed")
	check(int(world.hud.mp_bar.max_value)==world._effective_max_mp(),"equipment MP limit refreshed")
	world.active_skill_buffs["HUD QA"] = {"remaining":.1,"hp":75,"atk":9}
	world._update_hud()
	var buff_hp: int = int(world.hud.hp_bar.max_value)
	world._on_player_poison_tick(1)
	check(int(world.hud.hp_bar.max_value)==buff_hp,"live buff limit retained during hit")
	world._tick_skill_buffs(.2)
	check(int(world.hud.hp_bar.max_value)==world._effective_max_hp() and int(world.hud.hp_bar.max_value)==buff_hp-75,"expiry refreshes limit immediately")
	world.skills_db.append({"name":"HUD QA proc","class":"공용","activation":"passive",
		"trigger":"on_damaged","proc_effect":"hpBuff","proc_chance":1.,"hpFlat":55,"duration":1.,"cooldown":2.})
	var pre_proc_limit: int = int(world.hud.hp_bar.max_value)
	world.call("reset_hud_counts")
	world._try_trigger_passives("on_damaged",attacker)
	check(int(world.hud.hp_bar.max_value)==pre_proc_limit+55,"stat-changing damage proc publishes fresh limit")
	check(int(world.get("full_hud_refreshes"))==0 and world.stat_hud_refresh_pending,"stat proc does not rebuild UI inside the hit")
	world.skill_cooldowns.erase("HUD QA proc")
	world._try_trigger_passives("on_damaged",attacker)
	world._process(0.)
	check(int(world.get("full_hud_refreshes"))==1 and not world.stat_hud_refresh_pending,"multiple stat procs share one UI-phase refresh")
	check(int(world.hud.character_state.max_hp)==world._effective_max_hp(),"queued snapshot uses current stats")
	world._tick_skill_buffs(1.1)
	check(int(world.hud.hp_bar.max_value)==pre_proc_limit,"proc expiry invalidates limit")
	# Successful HP absorption remains exactly one after PR #46.
	world._equip_catalog("마법인형",{"name":"HUD QA doll","hpAbsorption":true})
	var player_hp: int = world.hp
	var mob_hp: int = attacker.hp
	world.call("reset_hud_counts")
	world._deal_successful_player_hit(attacker,10)
	check(world.hp==player_hp+1 and attacker.hp==mob_hp-11,"PR46 one HP absorption preserved")
	check_vitals(world,"absorption")
	check(int(world.get("full_hud_refreshes"))==0,"absorption does not rebuild equipment")
	# Death still refreshes currency and a save/load publishes fresh limits.
	world.hp = 1
	var gold: int = world.gold
	world._on_player_poison_tick(2)
	check(world.hp==world._effective_max_hp() and world.gold==maxi(0,gold-500),"death/respawn amount and currency")
	check(int(world.hud.character_state.gold)==world.gold,"respawn currency snapshot")
	check_vitals(world,"respawn")
	world.hp -= 39
	world.mp = 9
	world._save_game(true)
	var saved_hp: int = world.hp
	world.hp = 1
	world._load_game(true)
	check(world.hp==saved_hp and world.mp==9,"save/load vitals")
	check(int(world.hud.hp_bar.max_value)==world._effective_max_hp() and int(world.hud.mp_bar.max_value)==world._effective_max_mp(),"load restores display limits")
	check_vitals(world,"load")
	world.queue_free()
	await process_frame
	print("COMBAT_HUD_OK checks="+str(checks) if not failed else "COMBAT_HUD_FAILED")
	quit(1 if failed else 0)
