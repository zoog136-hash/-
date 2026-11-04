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
	world.hp = 100000000; world.rng.seed = 123456
	service.host_enabled = true
	check(service.try_begin(actor,true),"actual Monster begins typed source attack")
	var hp_before: int = world.hp
	actor.motion.advance(.65,Vector2.ZERO)
	check(world.hp < hp_before and service.last_event.get("phase") == "impact","real ActorMotion strike reaches world damage once")
	var after: int = world.hp
	actor._release_attack(actor.motion.sequence)
	check(world.hp == after,"real duplicate strike cannot damage")
	check(actor.stun_duration == 10 and actor.stun_accuracy == 100 and not world.player.is_stunned(),"unrelated legacy status suppressed and restored")
	service.clear(); actor.free()
	world.field_map = old_field; world.astar = old_astar; world.player.global_position = old_position; world.hp = saved_hp
	service.host_enabled = false
	panel.get_node("BossSkillsButton").pressed.emit()
	check(panel.panel.visible,"actual game button opens inspector")
	panel.selector.select(panel.ids.find(89102)); panel.refresh_npc()
	var index: int = -1
	for i: int in range(panel.rows.size()):
		if int(panel.rows[i].ID) == 308662: index = i
	check(index >= 0,"forewarning reachable from actual UI attack list")
	panel.attacks.select(index); panel.show_attack(index)
	check(panel.detail.text.contains("NextSpellClassID") and panel.detail.text.contains("88832"),"UI includes indirect followup source definition")
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-screen-dir="): output = arg.trim_prefix("--patch523-screen-dir=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("boss-skills-main.png")) == OK,"actual Main boss UI captured")
	var mode: OptionButton = panel.find_child("NpcSourceMode",true,false) as OptionButton
	mode.select(1); mode.item_selected.emit(1)
	panel.selector.select(panel.ids.find(53)); panel.refresh_npc()
	check(panel.rows.size() == 1 and panel.detail.text.contains("171713"),"bounded regional NPC buff reachable in UI")
	if not output.is_empty():
		await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("npc-environment-main.png")) == OK,"actual Main regional UI captured")
		root.content_scale_size = Vector2i(480,800)
		root.size = Vector2i(480,800)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(panel.panel.size.x <= 456 and panel.panel.size.y <= 776,"small viewport panel stays within screen")
		check(root.get_texture().get_image().save_png(output.path_join("npc-environment-small.png")) == OK,"small viewport Main UI captured")
	world.queue_free(); await process_frame
	if failed: quit(1); return
	print("PATCH523_NPC_MAIN_OK checks=",checks," hidden_execution_fixture=true; source_body_and_VFX_pixels_not_delivered")
	quit()
