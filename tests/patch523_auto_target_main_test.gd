extends SceneTree
## Controlled factory/targeting probes; no production encounter is added.
const QA = preload("res://tests/qa_class_selection.gd")
const ROSTER = preload("res://scripts/monsters/base508_source_roster.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_AUTO_MAIN_FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func tap(at: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.pressed=down
		root.push_input(event,true);await process_frame
func click(control: Control) -> void:
	await tap(control.get_global_transform_with_canvas()*(control.size*0.5))
func capture(name: String) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--patch523-capture-dir="): continue
		var output: String=arg.trim_prefix("--patch523-capture-dir=")
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"actual rendered "+name)
func make_actor(world: TwilightWorld,key: String,at: Vector2) -> TwilightMonster:
	var record: Dictionary=ROSTER.for_spawn(key,world.active_map_id)
	check(not record.is_empty(),"exact source context factory "+key)
	var actor: TwilightMonster=world.MONSTER_SCENE.instantiate()
	actor.position=at;world.monsters_root.add_child(actor)
	check(actor.setup(record,world.player,world,null),"actual Monster setup "+key)
	actor.set_physics_process(false)
	actor.selected.connect(world._select_monster)
	return actor
func body_ready(actor: TwilightMonster) -> bool:
	if not is_instance_valid(actor.source_m_view):return false
	var view: Node=actor.source_m_view
	var layers: Array=view._tracks.idle.directions[5][0].layers
	for index: int in range(layers.size()):
		if layers[index].relation=="body":
			var sprite: Sprite2D=view._layers[index]
			if sprite.visible and sprite.texture!=null and sprite.texture.get_width()>1:return true
	return false
func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class/map startup")
	world.player.set_physics_process(false);world.field_population.set_process(false);world.original_population.set_process(false)
	var paused:=Node2D.new();world.add_child(paused);paused.hide()
	for node: Node in world.monsters_root.get_children():node.set_physics_process(false);node.reparent(paused,true)
	var points: Array[Vector2]=[]
	var origin: Vector2=world.player.global_position
	var cell: Vector2i=world.field_map.world_to_cell(origin)
	for radius: int in range(1,12):
		for offset: Vector2i in [Vector2i(radius,0),Vector2i(0,radius),Vector2i(-radius,0),Vector2i(0,-radius)]:
			var point: Vector2=world.field_map.cell_to_world(cell+offset)
			if world.field_map.point_clear(point,4.0) and world.field_map.line_clear(origin,point) and not world.find_world_path(origin,point).is_empty():points.append(point);break
		if points.size()>=3:break
	points.sort_custom(func(a: Vector2,b: Vector2) -> bool:return a.distance_squared_to(origin)<b.distance_squared_to(origin))
	check(points.size()>=3,"existing host floor supplies controlled probe positions")
	if points.size()<3:world.queue_free();quit(1);return
	var guard: TwilightMonster=make_actor(world,"lineagem_base508:npc:93102:spawn:554792:territory:200832",points[0])
	var slime: TwilightMonster=make_actor(world,"lineagem_base508:npc:90:spawn:762:territory:558",points[1])
	var orc: TwilightMonster=make_actor(world,"lineagem_base508:npc:257:spawn:803:territory:563",points[2])
	check(body_ready(guard) and guard.source_m_npc_id==93102 and guard.source_targeting.snapshot=="patch523","new exact guard model decodes with latest selection metadata")
	check(not guard.permits_auto_selection() and not slime.permits_auto_selection() and orc.permits_auto_selection(),"real categories keep automatic and manual acquisition distinct")
	check(world._save_game(true)==OK,"isolated baseline save")
	var saved: String=FileAccess.get_sha256(world.save_path())
	var inventory: String=JSON.stringify(world.inventory)
	var gold: int=world.gold
	var mana: int=world.mp
	world.player.hide()
	for _frame: int in range(4):await process_frame
	await click(world.hud.find_child("AutoHunt",true,false))
	check(world.player.auto_enabled and world.hud.v20_auto_button.text.contains("ON"),"actual AUTO button enables game mode")
	check(world._nearest_reachable_monster(500,true,true)==orc,"automatic acquisition skips closer excluded native models")
	check(world._nearest_reachable_monster(500,true)==guard,"manual nearest-target API still selects the closest native guard")
	world.auto_target=guard;world.selected_monster=guard
	world._run_auto_hunt()
	check(world.auto_target==orc,"cached excluded automatic target is revalidated")
	world._clear_combat_actions();world.player.clear_click_path()
	orc.reparent(paused,true)
	world.auto_target=slime;world.selected_monster=slime;world.auto_target_next_search_ms=0
	world._run_auto_hunt()
	check(world.auto_target==null and world.player.click_path.is_empty() and world.pending_attack.is_empty(),"excluded-only population creates no chase or automatic attack")
	world.selected_monster=guard;world._attack(true)
	check(world.pending_attack.is_empty() and world.mp==mana and world.gold==gold,"automatic weapon fallback cannot acquire excluded actor or consume resources")
	await tap(COORD.world_to_screen(root,guard.global_position+Vector2(0,-28)))
	check(world.world_interactions.primary_monster()==guard and world.selected_monster==guard,"actual manual tap selects excluded guard while AUTO is on")
	check(world._skill_target(999)==guard,"explicit manual skill targeting remains available")
	# Advance the previous attack cooldown in this otherwise paused harness.
	world.auto_attack_timer=0.0
	world._attack()
	check(not world.pending_attack.is_empty(),"manual normal attack queues against the selected native guard")
	world._run_auto_hunt()
	check(world.auto_target==guard and world.world_interactions.primary_monster()==guard,"AUTO preserves explicit manual priority without silently retargeting")
	world._clear_combat_actions()
	var before_hp: int=guard.hp
	guard.take_damage(1);guard.set_physics_process(false)
	check(guard.hp==before_hp-1,"automatic selection exclusion does not grant damage immunity")
	await click(world.hud.find_child("Shortcut_map",true,false))
	for _frame: int in range(4):await process_frame
	await click(world.hud.workspace.find_child("OpenWorldLinks",true,false))
	for _frame: int in range(4):await process_frame
	var panel: Control=world.hud.workspace.find_child("WorldLinksPanel",true,false)
	check(panel!=null and panel.links.loaded,"actual map information UI opens")
	if panel!=null:
		panel.mode.select(1);panel.mode.item_selected.emit(1)
		panel.search.text="93102";panel.search.text_changed.emit(panel.search.text)
		check(panel.rows.item_count>0 and panel.detail.text.contains("자동 대상 탐색 제외") and panel.detail.text.contains("직접 선택 가능"),"UI displays exact guard category rule from523")
		await capture("08-native-guard-targeting-rule")
	world.hud._close_workspace();world._update_target_hud()
	await capture("09-native-guard-manual-selection")
	await click(world.hud.find_child("AutoHunt",true,false))
	check(not world.player.auto_enabled,"AUTO button restores the original mode")
	check(world.gold==gold and world.mp==mana and JSON.stringify(world.inventory)==inventory,"selection and manual queue preserve currency, mana and items")
	check(world._save_game(true)==OK and FileAccess.get_sha256(world.save_path())==saved,"forced save after UI/targeting keeps original character save bytes")
	guard.retire_for_pool()
	check(guard.source_targeting.is_empty(),"pool retirement clears source targeting metadata")
	check(guard.setup({"name":"TEST_LEGACY_POOL_SENTINEL","hp":30,"atk":1,"lv":1},world.player,world,null),"legacy pooled life setup")
	guard.set_physics_process(false)
	check(guard.permits_auto_selection() and guard.source_targeting.is_empty(),"native excluded state does not leak into legacy life")
	var next: Dictionary=ROSTER.for_spawn("lineagem_base508:npc:257:spawn:803:territory:563",world.active_map_id)
	check(guard.setup(next,world.player,world,null),"different native pooled life setup")
	guard.set_physics_process(false)
	check(guard.permits_auto_selection() and guard.source_targeting.snapshot=="patch523","next native life consumes its own current category")
	print("PATCH523_AUTO_TARGET_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"new_resource_npc":93102,"new_production_spawns":0}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty()else 1)
