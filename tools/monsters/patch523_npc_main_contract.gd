extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const PANEL = preload("res://scripts/ui/patch523_npc_panel.gd")
var checks: int = 0
var failed: bool = false
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed = true; push_error(label); quit(1)
func _init() -> void: call_deferred("run")
func run() -> void:
	var world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world),"actual Main and class selection")
	check(world.field_map != null and is_instance_valid(world.field_renderer) and not world.map_bootstrap_blocked and world.process_mode != Node.PROCESS_MODE_DISABLED,"verified current source map boots before UI/combat checks")
	world.player.set_physics_process(false)
	var service = world.patch523_npc_spells
	check(not service.catalog.content.is_empty(),"actual Main loaded private catalog")
	var panel: CanvasLayer
	for child: Node in world.get_children():
		if child.get_script() == PANEL: panel = child as CanvasLayer
	check(panel != null,"game UI attached to actual Main")
	check(panel.get_node("BossSkillsButton") is Button,"reachable game button")
	var saved_inventory: Dictionary = world.inventory.duplicate(true)
	var saved_hp: int = world.hp
	var saved_max_hp: int = world.max_hp
	world.inventory["HP 물약"] = 3; world.hp = 1
	var potion_plan: Dictionary = service.status_plan(47873)
	check(not potion_plan.is_empty(),"actual death potion item restriction resolves")
	service.apply_player_buff(61043,12,potion_plan.buffs[0].values)
	var cooldowns: Dictionary = world.item_use_cooldowns.duplicate(true)
	world._use_healing_item("HP 물약",320)
	world._use_quick_item("HP 물약")
	world._on_inventory_item_activated("HP 물약")
	check(world.hp == 1 and int(world.inventory["HP 물약"]) == 3 and world.item_use_cooldowns == cooldowns,"bag/quick/direct healing block before costs")
	check(not world._use_timed_item_buff({}),"timed item blocks before applying")
	service.tick(13)
	check(not service.blocks("CannotUseItem"),"expiry restores use")
	var hit_before: int = world._melee_accuracy_stat()
	var ac_before: int = world._effective_ac()
	var disease: Dictionary = service.status_plan(121708)
	check(service.apply_player_buff(239,12,disease.buffs[0].values),"source disease applies")
	check(world._melee_accuracy_stat() == hit_before-6 and world._effective_ac() == ac_before+12,"source flat values reach actual host hit/AC")
	service.tick(13)
	check(world._melee_accuracy_stat() == hit_before and world._effective_ac() == ac_before,"expiry restores actual stats")
	world.inventory = saved_inventory; world.hp = saved_hp
	# Real Monster/ActorMotion -> source release -> actual world hit resolver.
	# The hidden actor is an execution fixture; no original body pixels are claimed.
	var old_field: Variant = world.field_map
	var old_astar: Variant = world.astar
	var old_position: Vector2 = world.player.global_position
	world.field_map = null
	world.astar = AStarGrid2D.new(); world.astar.region = Rect2i(-50,-50,100,100); world.astar.update()
	world.player.global_position = Vector2(96,96)
	var actor = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(actor)
	actor.setup({"name":"523 execution fixture","lv":1,"hp":1000,"atk":1},world.player,world,null)
	actor.hide(); actor.set_physics_process(false)
	actor.source_m_npc_id = 60303; actor.source_m_original = service.catalog.row("NpcClass",60303).duplicate(true)
	actor.global_position = world.player.global_position+Vector2(24,0)
	actor.magic_accuracy = 1000000; actor.stun_duration = 10; actor.stun_accuracy = 100
	world.max_hp = 100000000; world.hp = 100000000; world.rng.seed = 123456
	service.host_enabled = true
	check(service.try_begin(actor,true,209093),"actual Monster begins exact source root attack")
	var hp_before: int = world.hp
	actor.motion.advance(.65,Vector2.ZERO)
	check(world.hp < hp_before and service.last_event.get("phase") == "impact","real ActorMotion strike reaches world damage once")
	var after: int = world.hp
	actor._release_attack(actor.motion.sequence)
	check(world.hp == after,"real duplicate strike cannot damage")
	check(actor.stun_duration == 10 and actor.stun_accuracy == 100 and not world.player.is_stunned(),"unrelated legacy status suppressed and restored")
	check(int(service.followups[actor.get_instance_id()].attack.ID) == 208983,"actual source209093 queues208983")
	actor.motion.advance(1.0,Vector2.ZERO)
	actor._tick_ai(2.0)
	check(service.last_event.get("selection") == "exact_source_NextAttack_at_host_clock" and int(service.last_event.get("attack_id",0)) == 208983,"actual Monster AI consumes exact followup after recovery")
	var before_followup: int = world.hp
	world.rng.seed = 42 # Stable host RNG; magic accuracy still uses the production hit roll.
	actor.motion.advance(.65,Vector2.ZERO)
	check(world.hp < before_followup and int(service.last_event.get("attack_id",0)) == 208983,"actual queued attack reaches single host damage path: " + JSON.stringify(service.last_event))
	if not service.source_effects.records.is_empty():
		var toggle: CheckButton = panel.find_child("SourceEffectToggle",true,false) as CheckButton
		toggle.button_pressed = true
		var fps: SpinBox = panel.find_child("Effect_fallback_fps",true,false) as SpinBox
		fps.value = 30
		var restored = preload("res://scripts/monsters/patch523_effect_frames.gd").new()
		restored.load_settings()
		check(restored.enabled and restored.fallback_fps == 30,"actual UI visual preferences persist independently")
		actor.motion.advance(1.0,Vector2.ZERO); actor.attack_cooldown = 0
		actor.source_m_npc_id = 63663; actor.source_m_original = service.catalog.row("NpcClass",63663).duplicate(true)
		world.rng.seed = 123456
		check(service.try_begin(actor,true,225833),"actual death potion source attack begins")
		actor.motion.advance(.65,Vector2.ZERO)
		check(service.blocks("CannotUseItem") and service.effects.size() == 1,"actual strike applies source restriction and exact2232 frame effect")
	service.clear(); actor.free()
	world.field_map = old_field; world.astar = old_astar; world.player.global_position = old_position; world.max_hp = saved_max_hp; world.hp = saved_hp
	service.host_enabled = false
	world._refresh_combat_hud()
	panel.get_node("BossSkillsButton").pressed.emit()
	check(panel.panel.visible,"actual game button opens inspector")
	panel.selector.select(panel.ids.find(89102)); panel.refresh_npc()
	var index: int = -1
	for i: int in range(panel.rows.size()):
		if int(panel.rows[i].ID) == 308662: index = i
	check(index >= 0,"forewarning reachable from actual UI attack list")
	panel.attacks.select(index); panel.show_attack(index)
	check(panel.detail.text.contains("NextSpellClassID") and panel.detail.text.contains("88832"),"UI includes indirect followup source definition")
	panel.selector.select(panel.ids.find(60303)); panel.refresh_npc()
	for i: int in range(panel.rows.size()):
		if int(panel.rows[i].ID) == 209093: index = i
	panel.attacks.select(index); panel.show_attack(index)
	check(panel.detail.text.contains("NextAttack → 208983"),"actual UI shows exact attack graph edge separately from NextSpell")
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-screen-dir="): output = arg.trim_prefix("--patch523-screen-dir=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("boss-skills-main.png")) == OK,"actual Main boss UI captured")
	var mode: OptionButton = panel.find_child("NpcSourceMode",true,false) as OptionButton
	mode.select(1); mode.item_selected.emit(1)
	panel.selector.select(panel.ids.find(53)); panel.refresh_npc()
	check(panel.rows.size() == 1 and panel.detail.text.contains("171713"),"bounded regional NPC buff reachable in UI")
	if not output.is_empty():
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("npc-environment-main.png")) == OK,"actual Main regional UI captured")
		root.content_scale_size = Vector2i(480,800)
		root.size = Vector2i(480,800)
		await process_frame; await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(panel.panel.size.x <= 456 and panel.panel.size.y <= 776,"small viewport panel stays within screen")
		check(root.get_texture().get_image().save_png(output.path_join("npc-environment-small.png")) == OK,"small viewport Main UI captured")
	if not service.source_effects.records.is_empty():
		mode.select(0); mode.item_selected.emit(0)
		panel.selector.select(panel.ids.find(63663)); panel.refresh_npc()
		for i: int in range(panel.rows.size()):
			if int(panel.rows[i].ID) == 225833: index = i
		panel.attacks.select(index); panel.show_attack(index)
		check(not panel.effect_preview.disabled and panel.preview_sprite == 2232,"actual UI offers exact source effect for selected spell")
		panel.effect_preview.pressed.emit()
		check(not panel.panel.visible and service.effects.size() == 1,"actual preview button shows world effect and clears view")
		if not output.is_empty():
			root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("source-effect-main.png")) == OK,"actual source effect candidate rendered on Main")
		service.clear()
		panel.get_node("BossSkillsButton").pressed.emit()
		panel.selector.select(panel.ids.find(53064)); panel.refresh_npc()
		for i: int in range(panel.rows.size()):
			if int(panel.rows[i].ID) == 216043: index = i
		panel.attacks.select(index); panel.show_attack(index)
		var composition: CheckButton = panel.find_child("SourceEffectComposition",true,false) as CheckButton
		composition.button_pressed = true
		var preferences = preload("res://scripts/monsters/patch523_effect_frames.gd").new(); preferences.load_settings()
		check(preferences.compose_children and panel.preview_sprite == 6530,"actual composite preference persists and exact child effect is selected")
		panel.effect_preview.pressed.emit()
		check(service.effects.size() == 1 and service.effects[0].layer_effects.size() == 1,"actual UI previews full6530 plus6529 source layers")
		if not output.is_empty():
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("source-composite-main.png")) == OK,"actual inferred child composition renders on Main")
		service.clear()
	world.queue_free(); await process_frame
	if failed: quit(1); return
	print("PATCH523_NPC_MAIN_OK checks=",checks," hidden_execution_fixture=true; boss_body_native_equivalence=false; candidate_effects=",service.source_effects.records.size())
	quit()
