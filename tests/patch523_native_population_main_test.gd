extends SceneTree
## Verified private508 pixels + latest523 gate in an existing host encounter.
## No native geographic placement or latest-art equivalence claim.
const QA = preload("res://tests/qa_class_selection.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_NATIVE_MAIN_FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func click(control: Control) -> void:
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.position=at; event.pressed=pressed
		root.push_input(event,true); await process_frame
func capture(name: String) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--patch523-capture-dir="): continue
		var output: String = arg.trim_prefix("--patch523-capture-dir=")
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK, "actual rendered "+name)
func body_ready(actor: TwilightMonster) -> bool:
	if not is_instance_valid(actor.source_m_view): return false
	var view: Node = actor.source_m_view
	var source_layers: Array = view._tracks.idle.directions[5][0].layers
	for index: int in range(source_layers.size()):
		if source_layers[index].relation != "body": continue
		var layer: Sprite2D = view._layers[index]
		if layer.visible and layer.texture != null and layer.texture.get_width()>1 and layer.texture.get_height()>1: return true
	return false
func run() -> void:
	root.size=Vector2i(1280,720)
	check(POLICY.settings().enabled,"latest523 gate explicitly enabled")
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world); world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class/map startup")
	world.player.set_physics_process(false); world.field_population.set_process(false); world.original_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	var slot: Dictionary = {}
	# Prefer a native encounter created during actual Main startup. A vacant
	# authored encounter may also use its existing floor; no encounter is added.
	for candidate: Dictionary in world.field_population.slots:
		if str(candidate.region.get("mode","normal"))=="boss": continue
		if is_instance_valid(candidate.monster):
			if candidate.monster.source_m_npc_id in [257,258]: slot=candidate; break
			continue
		if not "오크" in candidate.region.monster_types: continue
		var point: Vector2 = world.field_population._spawn_point(candidate.region)
		if not point.is_finite(): continue
		world.player.global_position=point
		if not world.field_population._zone_active(candidate.region): continue
		world.field_population._spawn_slot(candidate)
		if is_instance_valid(candidate.monster):
			candidate.monster.set_physics_process(false)
			if candidate.monster.source_m_npc_id in [257,258]: slot=candidate; break
	check(not slot.is_empty(),"existing orc habitat creates native source actor through real population")
	if slot.is_empty(): world.queue_free(); quit(1); return
	var actor: TwilightMonster = slot.monster
	check(body_ready(actor) and not actor.sprite.visible,"actual source SP2 body decoded and legacy silhouette hidden")
	var admission: Dictionary = actor.get_meta("patch523_spawn_admission",{})
	check(admission.get("manifest_sha256")==POLICY.settings().sha and admission.get("snapshot")=="patch523","real population actor passes latest523 definitions")
	check(actor.gold_reward==0 and actor.drop_items.is_empty(),"no unverified native loot/currency")
	var region: String = JSON.stringify(slot.region)
	var actor_id: int = actor.source_m_npc_id
	world.player.global_position=actor.global_position
	world.player.hide(); world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for _frame: int in range(360):
		await process_frame
		if not world.field_renderer.waiting_for_visible: break
	check(not world.field_renderer.waiting_for_visible and world.field_renderer.failure.is_empty(),"existing habitat source terrain streams successfully")
	check(world._save_game(true)==OK,"isolated baseline save")
	var save_sha: String = FileAccess.get_sha256(world.save_path())
	var inventory: String = JSON.stringify(world.inventory)
	var gold: int = world.gold
	var boss_state: String = JSON.stringify(world.field_population.export_state())
	for _frame: int in range(4): await process_frame
	await click(world.hud.find_child("Shortcut_map",true,false))
	for _frame: int in range(4): await process_frame
	await click(world.hud.workspace.find_child("OpenWorldLinks",true,false))
	for _frame: int in range(4): await process_frame
	var panel: Control = world.hud.workspace.find_child("WorldLinksPanel",true,false)
	check(panel!=null and panel.links.loaded,"actual map information UI opens with verified definitions")
	if panel!=null:
		var found: bool = false
		for index: int in range(panel.visible_entries.size()):
			var entry: Dictionary = panel.visible_entries[index]
			if entry.kind=="live" and int(entry.slot.slot_id)==int(slot.slot_id):
				panel.rows.select(index); panel.show_entry(index); found=true; break
		check(found and panel.detail.text.contains("누적523의 명시적 출현 정의 검사를 통과"),"UI shows latest-definition admission for the real live slot")
		await capture("06-native-population-ui")
	world.hud._close_workspace()
	await capture("07-native-existing-habitat")
	check(FileAccess.get_sha256(world.save_path())==save_sha and JSON.stringify(world.inventory)==inventory and JSON.stringify(world.field_population.export_state())==boss_state,"native rendering/UI preserve save, inventory and boss state")
	actor.take_damage(actor.hp+1); actor.set_physics_process(false)
	check(actor.dead and slot.monster==null and float(slot.remaining)>0.0,"actual native death releases existing slot with its declared respawn delay")
	check(FileAccess.get_sha256(world.save_path())==save_sha and JSON.stringify(world.inventory)==inventory and world.gold==gold,"native kill creates no invented item, currency or save write")
	var pending: Array[Dictionary] = world.field_population.pending_initial_spawns.duplicate()
	var pending_ids: Dictionary = world.field_population.pending_spawn_ids.duplicate()
	world.field_population.pending_initial_spawns.clear()
	# Other initial encounters remain queued and paused for this bounded test.
	world.field_population._process(float(slot.remaining)+0.5)
	for _attempt: int in range(4):
		world.field_population._drain_initial_spawns()
		if is_instance_valid(slot.monster): break
	for existing: Node in world.monsters_root.get_children(): existing.set_physics_process(false)
	world.field_population.pending_initial_spawns=pending; world.field_population.pending_spawn_ids=pending_ids
	check(is_instance_valid(slot.monster) and not slot.monster.dead and body_ready(slot.monster),"real population respawns native pixels after its existing delay")
	check(JSON.stringify(slot.region)==region,"host placement, count and respawn policy unchanged")
	print("PATCH523_NATIVE_POPULATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_npc_id":actor_id,"slot_id":slot.slot_id,"source_art_snapshot":"base508","definition_snapshot":"patch523"}))
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
