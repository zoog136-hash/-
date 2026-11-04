extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const PANEL = preload("res://scripts/ui/patch523_npc_panel.gd")
var failures: Array[String] = []
var checks: int = 0
var screen_dir: String = ""
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func _init() -> void: call_deferred("run")
func capture(name: String) -> void:
	if screen_dir.is_empty(): return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screen_dir.path_join(name)) == OK,"actual Main capture "+name)
func attack_for(service: RefCounted, spell_id: int) -> Dictionary:
	for entry: Dictionary in service.catalog.content.tables.NpcAttack.values():
		if int(entry.row.get("SpellID",0)) == spell_id: return entry.row
	return {}
func assign(actor: Node, service: RefCounted, spell_id: int) -> Dictionary:
	var attack: Dictionary = attack_for(service,spell_id)
	actor.source_m_npc_id = int(attack.NpcClassID)
	actor.source_m_original = service.catalog.row("NpcClass",actor.source_m_npc_id).duplicate(true)
	actor.motion.advance(2.0,Vector2.ZERO); actor.attack_cooldown = 0
	return attack
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-screen-dir="): screen_dir = arg.trim_prefix("--patch523-screen-dir=")
	if not screen_dir.is_empty(): DirAccess.make_dir_recursive_absolute(screen_dir)
	var world = (load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world)
	world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world),"actual class choice and Main entry")
	check(world.field_map != null and not world.map_bootstrap_blocked,"actual current source map loaded")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	var service = world.patch523_npc_spells; service.tick(0)
	var panel: CanvasLayer
	for node: Node in world.get_children():
		if node.get_script() == PANEL: panel = node
	check(panel != null,"actual boss UI exists")
	(panel.find_child("BossCombatToggle",true,false) as CheckButton).button_pressed = true
	(panel.find_child("BossCompat_enabled",true,false) as CheckButton).button_pressed = true
	(panel.find_child("BossCompat_allow_test_definitions",true,false) as CheckButton).button_pressed = true
	(panel.find_child("BossCompat_ground_radius",true,false) as SpinBox).value = 80
	(panel.find_child("BossCompat_summon_seconds",true,false) as SpinBox).value = 2
	var rules = service.compatibility.get_script().new(); rules.configure(service)
	check(rules.enabled and rules.allow_test_definitions and rules.ground_radius == 80 and rules.summon_seconds == 2,"actual UI choices survive config reload")
	panel.get_node("BossSkillsButton").pressed.emit()
	panel.find_child("BossCompatOpen",true,false).pressed.emit()
	var own_controls: Control = panel.find_child("BossCompat_ground_radius",true,false).get_parent().get_parent()
	check(panel.panel.visible and own_controls.visible,"player can open own boss settings from actual inspector")
	if not screen_dir.is_empty():
		await process_frame; await process_frame
		(panel.find_child("BossSkillsScroll",true,false) as ScrollContainer).ensure_control_visible(own_controls)
		await capture("boss-host-settings.png")
	panel.panel.hide()
	var original_field: Variant = world.field_map
	var original_astar: Variant = world.astar
	var original_position: Vector2 = world.player.global_position
	var saved_hp: int = world.hp; var saved_max: int = world.max_hp
	world.field_map = null # Explicit hit execution fixture, never a native placement claim.
	world.astar = AStarGrid2D.new()
	world.astar.region = Rect2i(world._world_to_cell(original_position)-Vector2i(50,50),Vector2i(100,100)); world.astar.update()
	world.max_hp = 100000000; world.hp = 100000000
	var actor = world.MONSTER_SCENE.instantiate(); world.monsters_root.add_child(actor)
	actor.setup({"name":"TWILIGHT source skill execution fixture","lv":1,"hp":1000000,"atk":1},world.player,world,null)
	actor.hide(); actor.set_physics_process(false); actor.global_position = world.player.global_position+Vector2(24,0)
	actor.magic_accuracy = 1000000
	var source_attack: Dictionary = assign(actor,service,88822)
	check(service.try_begin(actor,true,int(source_attack.ID)),"source88822 begins real ActorMotion")
	actor.motion.advance(.65,Vector2.ZERO)
	check(service.compatibility.waiting.size() == 1,"real release schedules exact88832")
	await capture("boss-host-warning.png")
	service.tick(2.99)
	check(service.compatibility.zones.is_empty(),"real runtime does not apply plate before source3000ms")
	service.tick(.02); actor.motion.advance(1.0,Vector2.ZERO); actor.attack_cooldown = 0
	actor._tick_ai(0)
	check(int(service.last_event.get("spell_id",0)) == 88832,"actual Monster AI takes due source NextSpell")
	actor.motion.advance(.65,Vector2.ZERO)
	check(service.compatibility.zones.size() == 1,"real child strike creates persistent host area")
	var before: int = world.hp; world.rng.seed = 42; service.tick(.3)
	check(world.hp < before and int(service.compatibility.last_event.get("last_raw_damage",0)) >= 400010,"source plate damage reaches actual authoritative player hit path")
	await capture("boss-host-ground.png")
	service.clear(); world.field_map = original_field; world.hp = saved_hp; world.max_hp = saved_max
	var summon_point: Vector2 = Vector2.INF
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode","normal")) != "normal": continue
		for trial: int in range(8):
			var p: Vector2 = world.field_population._spawn_point(slot.region)
			if p.is_finite() and original_field.point_clear(p+Vector2(24,0),4) and not original_field.is_safe(p+Vector2(24,0)) and original_field.line_clear(p,p+Vector2(24,0)) and original_field.walkable(p+Vector2(100,0)) and original_field.point_clear(p+Vector2(100,0)) and not original_field.is_safe(p+Vector2(100,0)):
				summon_point = p; break
		if summon_point.is_finite(): break
	check(summon_point.is_finite(),"existing field API finds actual traversable summon site")
	if summon_point.is_finite():
		world.player.global_position = summon_point+Vector2(24,0); actor.global_position = summon_point
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		source_attack = assign(actor,service,48013)
		check(service.try_begin(actor,true,int(source_attack.ID)),"native summon spell uses real host cast")
		actor.motion.advance(.65,Vector2.ZERO)
		check(not service.compatibility.summons.is_empty(),"existing population API creates real no-reward helpers")
		for entry: Dictionary in service.compatibility.summons:
			var helper: Node = entry.monster.get_ref(); helper.set_physics_process(false)
		if not screen_dir.is_empty():
			world.field_renderer.refresh_visible()
			for frame: int in range(90): await process_frame
		await capture("boss-host-summons.png")
		if not service.compatibility.summons.is_empty():
			var helper: Node = service.compatibility.summons[0].monster.get_ref()
			var player_point: Vector2 = world.player.global_position
			world.player.global_position = helper.global_position
			helper.melee_accuracy = 1000000; helper.attack_power = 100; world.rng.seed = 42
			var before_helper: int = world.hp
			helper.motion.begin_attack(.3,Vector2.RIGHT,"slash")
			helper._resolve_attack(helper.motion.sequence,"melee",helper.life_id)
			check(world.hp < before_helper,"real helper impact signal reaches existing authoritative player damage path")
			world.player.global_position = player_point
			var old_gold: int = world.gold; var old_exp: int = world.experience; var inventory: Dictionary = world.inventory.duplicate(true)
			helper.take_damage(helper.hp+1); world._on_monster_died(helper)
			check(world.gold == old_gold and world.experience == old_exp and world.inventory == inventory,"helper death and duplicate signal cannot award XP/currency/items")
		service.tick(2.01)
		check(service.compatibility.summons.is_empty(),"real helper lifetime removes own actors")
	world.player.global_position = original_position; actor.global_position = original_position+Vector2(24,0)
	world.hp = saved_hp; world.max_hp = saved_max
	world.field_map = null; source_attack = assign(actor,service,88822)
	service.try_begin(actor,true,int(source_attack.ID)); actor.motion.advance(.65,Vector2.ZERO)
	world.field_map = original_field
	check(not service.compatibility.waiting.is_empty(),"live pending chain exists before save/load checks")
	check(world._save_game(true) == OK,"actual progression save succeeds with transient host state")
	var path: String = world.save_path(); var digest: String = FileAccess.get_sha256(path)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not data.has("patch523_boss_active") and not data.has("patch523_summons"),"transient states are not serialized as repeatable rewards")
	var prior_pack: String = OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",ProjectSettings.globalize_path("user://missing-compat-map-pack"))
	world._load_game(true)
	check(world.source_save_blocked and not service.compatibility.waiting.is_empty() and FileAccess.get_sha256(path) == digest,"rejected load preserves live state and durable save")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",prior_pack); world._load_game(true)
	check(not world.source_save_blocked and service.compatibility.waiting.is_empty() and service.compatibility.zones.is_empty() and service.compatibility.summons.is_empty(),"accepted load clears transient callbacks/areas/helpers")
	check(FileAccess.get_sha256(path) == digest and world.gold == int(data.gold) and world.experience == int(data.experience),"accepted load preserves original save bytes and progression")
	world.astar = original_astar
	world.queue_free(); await process_frame
	print("PATCH523_BOSS_COMPAT_MAIN_RESULT checks=",checks," failures=",JSON.stringify(failures)," own_rules_explicit=true; original_boss_body_equivalence=false")
	quit(0 if failures.is_empty() else 1)
