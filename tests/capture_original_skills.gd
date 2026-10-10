extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var capture_dir: String = "res://docs/skills/previews"

func _initialize() -> void:
	if not OS.get_environment("TWILIGHT_SKILL_CAPTURE_DIR").is_empty(): capture_dir = OS.get_environment("TWILIGHT_SKILL_CAPTURE_DIR")
	call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := capture_dir + "/" + name + ".png"
	if image.save_png(path) != OK:
		push_error("Cannot preserve rendered preview: " + path)
		quit(1)
		return
	print("RENDER_CAPTURE ",name," size=",image.get_size())

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Real GL rendering required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not QA.enter_game(world): quit(1); return
	world.save_timer = -100000
	world.self_mode_enabled = false
	world.player.set_auto_enabled(false)
	for entry: Dictionary in world.quickslots: entry["auto"] = false
	world.level = 90
	world.gold = 10000000
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300,4370)))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.equipped_items["weapon"] = {"name":"검사 양손검","type":"양손검","slot":"weapon"}
	var catalog := world.original_skills.catalog
	for skill: Dictionary in catalog.records:
		if skill.classes.has("기사"):
			catalog.learned[str(skill.id)] = 1
	world._update_hud()
	world.hud.open_skills()
	for _frame: int in range(12): await process_frame
	var view: Node = world.hud.skills_view
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].name)=="카운터 배리어": view.cards.select(index);view.select(index)
	await capture("01-knight-catalog")
	view.preview_button.pressed.emit()
	for _frame: int in range(3): await process_frame
	await capture("02-skill-preview")
	world.hud._close_workspace()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	if not world._cast_job_skill("카운터 배리어"):
		push_error("Counter aura capture requires a successful cast")
		quit(1)
		return
	for _frame: int in range(4): await process_frame
	await capture("03-counter-aura")
	var samples: Array[float] = []
	for frame: int in range(60):
		var start := Time.get_ticks_usec()
		world.original_skills.vfx.emit_skill(str(catalog.records[frame%catalog.records.size()].id),"impact",world.player.global_position + Vector2(frame%8*14-56,0))
		await process_frame
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	await capture("04-effect-crowd")
	samples.sort()
	print("ORIGINAL_RENDER_OK driver=",RenderingServer.get_video_adapter_name()," median_ms=",samples[30]," p95_ms=",samples[57]," active=",world.original_skills.vfx.live.size()," available=",world.original_skills.vfx.available.size())
	world._clear_combat_actions()
	world.active_skill_buffs.clear()
	world._clear_monsters()
	world.job_class = "마법사"
	world._update_job_skillbar()
	world.equipped_items["weapon"] = {"name":"검증 SP 지팡이","type":"지팡이","slot":"weapon","atk":0,"sp":4}
	var guardian := catalog.record_for("서먼 가디언")
	catalog.learned[str(guardian.id)] = 1
	world.mp = 999;world.hp = world._effective_max_hp()
	world.skill_cooldowns.clear();world.skill_global_cooldown = 0
	if not world._cast_job_skill(str(guardian.name)):
		push_error("Guardian capture requires a successful real cast")
		quit(1);return
	var summons := world.original_skills.summons
	for _frame: int in range(20):
		summons.tick(1.0/60)
		await process_frame
	if not summons.active() or world.mp != 999-int(guardian.mp):
		push_error("Guardian actor/cost mismatch")
		quit(1);return
	await capture("05-guardian-summon")
	world.hud.open_skills()
	for _frame: int in range(5): await process_frame
	view = world.hud.skills_view
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].id)==str(guardian.id): view.cards.select(index);view.select(index)
	if not view.summon_controls.visible:
		push_error("Guardian commands must be visible in the actual skill UI")
		quit(1);return
	await capture("08-guardian-commands")
	world.hud._close_workspace()
	var dummy: TwilightMonster = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"가디언 실제 타격 검사","hp":1000000,"lv":1,"ac":0,"mr":0},world.player,world,null)
	dummy.set_physics_process(false)
	dummy.global_position = world.player.global_position+Vector2(56,0)
	summons.actor.global_position = world.player.global_position+Vector2(24,0)
	summons.command("attack",dummy)
	var hits := dummy.damage_hit_count
	var struck := false
	for _frame: int in range(240):
		summons.tick(1.0/60)
		await process_frame
		if dummy.damage_hit_count > hits:
			struck = true;break
	if not struck:
		push_error("Guardian capture requires an actual NPC hit")
		quit(1);return
	await capture("06-guardian-hit")
	world.hp = 10
	var damage := world.original_skills.incoming_damage(dummy,"magic",11)
	if summons.active() or summons.shield_events != 1 or damage != 0:
		push_error("Guardian shield requires actual damage-triggered conversion")
		quit(1);return
	world.hp = maxi(0,world.hp-damage)
	world._update_hud()
	for _frame: int in range(3): await process_frame
	await capture("07-guardian-shield")
	print("ORIGINAL_GUARDIAN_RENDER_OK npc_hits=",dummy.damage_hit_count-hits," shield_events=",summons.shield_events," mp_spent=",999-world.mp)
	await capture_turn_undead(world, dummy)
	world.queue_free()
	await process_frame
	quit()

func capture_turn_undead(world: TwilightWorld, dummy: TwilightMonster) -> void:
	world._clear_combat_actions()
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.active_skill_buffs.clear()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.mp = 999
	world.hp = world._effective_max_hp()
	var service := world.original_skills
	var catalog := service.catalog
	var base := catalog.record_for("턴 언데드")
	var ancient := catalog.record_for("턴 언데드(에이션트)")
	catalog.learned.clear()
	catalog.seed_starters()
	catalog.learned[str(base.id)] = 1
	catalog.learned[str(ancient.id)] = 1
	dummy.undead = true
	dummy.monster_type = "언데드"
	dummy.monster_name = "턴 언데드 검증 대상"
	dummy.magic_resistance = 150
	dummy.hp = 10000
	dummy.max_hp = 10000
	world.selected_monster = dummy
	world._update_hud()
	world._on_quickslot_assignment_requested(0, "skill_auto", str(base.id))
	world.hud.open_skills()
	for _frame: int in range(3): await process_frame
	var view: Node = world.hud.skills_view
	view.class_filter.select(0)
	view.type_filter.select(0)
	view.grade_filter.select(0)
	view.search.text = "턴 언데드"
	view.refresh()
	var selected := false
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].id) == str(base.id):
			view.cards.select(index)
			view.select(index)
			selected = true
	if not selected or world.quickslots[0].get("skill_id") != base.id:
		push_error("Turn Undead UI requires learned records and stable AUTO slot")
		quit(1); return
	await capture("09-turn-undead-learning")
	world.hud._close_workspace()
	if not world._cast_job_skill(str(base.id)) or world.mp != 999 - int(base.mp):
		push_error("Turn Undead render requires a real paid cast")
		quit(1); return
	for _step: int in range(90):
		world.player.motion.advance(1.0 / 60.0, Vector2.ZERO)
		if world.pending_attack.is_empty(): break
	world.combat_flights.set_physics_process(false)
	world.combat_flights._physics_process(.005)
	if world.combat_flights.flights.size() != 1 or dummy.hp != 10000:
		push_error("Turn Undead capture requires a real pending projectile without early damage")
		quit(1); return
	await capture("10-turn-undead-projectile")
	var chance := service.turn_undead_chance(catalog.resolve(base), dummy)
	var forced := false
	for seed_value: int in range(10000):
		world.rng.seed = seed_value
		if service.roll_turn_undead(world.rng, chance):
			world.rng.seed = seed_value
			forced = true
			break
	if not forced:
		push_error("No valid deterministic Turn Undead success seed")
		quit(1); return
	for _step: int in range(20): world.combat_flights._physics_process(.02)
	if not dummy.dead or dummy.hp != 0 or service.vfx.audio_pool.last_phase != "impact":
		push_error("Turn Undead impact capture requires actual death and confirmed-hit sound")
		quit(1); return
	await capture("11-turn-undead-ancient-impact")
	print("ORIGINAL_TURN_UNDEAD_RENDER_OK hp=", dummy.hp, " mp_spent=", 999 - world.mp, " audio_phase=", service.vfx.audio_pool.last_phase)
