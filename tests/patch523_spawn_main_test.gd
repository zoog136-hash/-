extends SceneTree
## Actual Main/Monster generation rejection. No original M pixel/placement claim.
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var death_signals: int = 0

class ProbePopulation extends FieldPopulation:
	var existing_point: Vector2
	func _spawn_point(_region: Dictionary) -> Vector2: return existing_point

class SummonFloorFixture extends PlayableField:
	func walkable(_point: Vector2) -> bool: return true
	func point_clear(_point: Vector2, _padding: float = 24.0) -> bool: return true
	func is_safe(_point: Vector2) -> bool: return false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_MAIN_FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-capture-dir="): output = arg.trim_prefix("--patch523-capture-dir=")
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "actual rendered " + name)

func run() -> void:
	root.size = Vector2i(1280,720)
	var options: Dictionary = POLICY.settings()
	check(options.enabled, "explicit latest-definition policy requested")
	var links = LINKS.new()
	check(links.load_land(options.root, 4, "Aden/", options.sha), "actual523 Aden definitions")
	if not links.loaded: quit(1); return
	var scene = load("res://Main.tscn") as PackedScene
	check(scene != null, "actual Main loads")
	if scene == null: quit(1); return
	var world: TwilightWorld = scene.instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer = -100000.0
	check(QA.enter_game(world), "actual class confirmation and current map startup")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.original_population.set_process(false)
	world.field_population._drain_initial_spawns()
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	check(world.active_map_id == "aden_world" and world.field_map != null, "ordinary actual Aden running")
	check(world.monsters_root.get_child_count() > 0, "existing host population still creates actors")
	check(world._save_game(true) == OK, "actual isolated baseline save")
	var save_path: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(save_path)
	var boss_state: String = JSON.stringify(world.field_population.export_state())
	var gold: int = world.gold
	var inventory: String = JSON.stringify(world.inventory)
	var legacy: Dictionary = {}
	var region: Dictionary = {}
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode", "normal")) != "boss": region = slot.region.duplicate(true); break
	for value: Dictionary in world.field_population.records.values():
		if not POLICY.marked(value): legacy = value; break
	check(not legacy.is_empty() and not region.is_empty(), "existing host record and region available")
	if legacy.is_empty() or region.is_empty(): world.queue_free(); quit(1); return
	var positive: TwilightMonster = world.MONSTER_SCENE.instantiate()
	positive.position = world.player.global_position
	world.monsters_root.add_child(positive)
	check(positive.setup(legacy, world.player, world, world._monster_texture(legacy)), "actual existing legacy actor setup succeeds under requested gate")
	positive.set_physics_process(false)
	check(positive.get_meta("patch523_spawn_admission", {}).is_empty(), "PC/host actor not relabelled as original M")
	positive.died.connect(func(_actor: TwilightMonster) -> void: death_signals += 1)
	# A rejection probe built from an actual explicitly disabled523 definition.
	# The host contract here is test-only; no production encounter is added.
	var disabled_view: Dictionary = {}
	var relation: Dictionary = {}
	for view: Dictionary in links.shard.spawn_views:
		if view.get("IsSpawn") != 0: continue
		for row: Dictionary in links.shard.spawn_relations:
			if row.NpcSpawnPackID == view.NpcSpawnPackID: disabled_view = view; relation = row; break
		if not disabled_view.is_empty(): break
	check(not disabled_view.is_empty(), "actual IsSpawn0 with explicit Territory found")
	if disabled_view.is_empty(): world.queue_free(); quit(1); return
	var npc: Dictionary = links.npcs[int(disabled_view.NpcClassID)]
	var key: String = "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [int(npc.ID), int(disabled_view.ID), int(relation.ID)]
	var disabled: Dictionary = {"source": "lineagem_base508", "sourceId": key, "source_m_npc_id": npc.ID, "source_m_sprite_id": npc.Sprite,
		"source_m_spawn_view_id": disabled_view.ID, "source_m_territory_link_id": relation.ID, "source_m_host_placement": "TEST_ONLY_REJECTION_PROBE; NO_PRODUCTION_PLACEMENT",
		"source_m_catalog_key": key, "source_m_runtime_host_map": world.active_map_id, "catalog_only": false,
		"source_m_context": {"land": links.land, "spawn_view": disabled_view, "territory_link": relation, "territory": links.territories[int(relation.TerritoriesID)], "npc": npc}}
	var probe := ProbePopulation.new()
	root.add_child(probe); probe.set_process(false)
	probe.world = world; probe.field = world.field_map; probe.existing_point = world.player.global_position
	region.monster_types = ["patch523_rejection_fixture"]
	probe.records = {"patch523_rejection_fixture": disabled}
	var slot: Dictionary = {"region": region, "index": 0, "slot_id": 0, "monster": null, "remaining": 0.0, "has_spawned": false}
	probe.slots = [slot]
	var before: int = world.monsters_root.get_child_count()
	probe._spawn_slot(slot)
	check(slot.get("patch523_spawn_hold") == "patch523_is_spawn_0" and slot.monster == null and is_inf(float(slot.remaining)), "real population rejects before creating node")
	check(world.monsters_root.get_child_count() == before, "pre-node hold creates no actor")
	var boss_slot: Dictionary = slot.duplicate(true)
	boss_slot.region.mode = "boss"; boss_slot.region.boss_id = "patch523_rejection_fixture"
	var probe_bosses: String = JSON.stringify(probe.boss_director.states)
	probe._spawn_slot(boss_slot)
	check(boss_slot.get("patch523_spawn_hold") == "patch523_is_spawn_0" and JSON.stringify(probe.boss_director.states) == probe_bosses, "rejected boss restores original director state")
	for delay: float in [0.0, 3600.0]:
		var delayed: Dictionary = boss_slot.duplicate(true)
		delayed.region.initial_delay = delay
		probe.existing_point = Vector2.INF
		probe._spawn_slot(delayed)
		check(delayed.get("patch523_spawn_hold") == "patch523_is_spawn_0" and JSON.stringify(probe.boss_director.states) == probe_bosses, "held delayed/no-floor boss never initializes state")
	probe.existing_point = world.player.global_position
	# Re-run the normal respawn update and queued initializer paths. Both must
	# retain an immutable hold rather than replace it with a retry countdown.
	slot.remaining = 0.0; probe.wake_clock = 0.0
	probe._process(0.1)
	check(is_inf(float(slot.remaining)) and slot.monster == null, "normal respawn keeps definition hold")
	probe.pending_initial_spawns = [slot]
	probe._drain_initial_spawns()
	check(is_inf(float(slot.remaining)) and probe.pending_initial_spawns.is_empty(), "queued initial spawn keeps hold")
	# Exercise the real summon helper, isolating floor sampling in a named test
	# fixture. This checks rejection/lifecycle, not original physical placement.
	probe.field = SummonFloorFixture.new()
	probe.summon_for(positive)
	var rejected_summons: int = 0
	for actor: Node in world.monsters_root.get_children():
		if actor.is_queued_for_deletion() and actor.get_meta("patch523_spawn_hold", "") == "patch523_is_spawn_0": rejected_summons += 1
	check(rejected_summons == 2 and probe.summons.is_empty(), "actual summon helper records no rejected actors")
	check(not positive.setup(disabled, world.player, world, null), "direct/pooled real Monster setup rejects")
	check(positive.is_queued_for_deletion() and positive.dead and not positive.visible and not positive.is_physics_processing(), "rejected pooled actor hidden/stopped/disposed")
	check(positive.collision_layer == 0 and positive.collision_mask == 0 and not positive.input_pickable, "rejected actor cannot collide or be selected")
	check(positive.drop_items.is_empty() and positive.source_m_npc_id == -1 and positive.loot_source_identity.is_empty(), "prior actor loot/native identity cleared")
	probe.queue_free()
	await process_frame
	check(death_signals == 0 and world.gold == gold and JSON.stringify(world.inventory) == inventory, "no death/reward/inventory side effect")
	check(JSON.stringify(world.field_population.export_state()) == boss_state, "original boss state preserved")
	check(FileAccess.get_sha256(save_path) == save_sha, "existing save bytes preserved")
	# Real map-screen entry button and panel. Data selection uses the actual
	# controls/signals; opening and closing use viewport mouse hit testing.
	for _frame: int in range(4): await process_frame
	var shortcut: Control = world.hud.find_child("Shortcut_map", true, false)
	check(shortcut != null, "existing map shortcut exists")
	if shortcut != null: await click(shortcut)
	check(world.hud.active_section == "map", "mouse opens existing map screen")
	for _frame: int in range(4): await process_frame
	var open_button: Control = world.hud.workspace.find_child("OpenWorldLinks", true, false)
	check(open_button != null, "map screen exposes portal/spawn entry")
	if open_button != null: await click(open_button)
	check(world.hud.active_section == "map_links", "mouse opens linked feature UI")
	for _frame: int in range(4): await process_frame
	var panel: Control = world.hud.workspace.find_child("WorldLinksPanel", true, false)
	check(panel != null and panel.links.loaded, "actual private523 data displayed")
	if panel != null and panel.links.loaded:
		check(panel.summary.text.contains("포탈 93") and panel.summary.text.contains("1343") and panel.summary.text.contains("142"), "UI shows actual Aden coverage")
		await capture("01-live-state")
		panel.mode.select(1); panel.mode.item_selected.emit(1)
		panel.search.text = str(int(disabled_view.NpcClassID)); panel.search.text_changed.emit(panel.search.text)
		check(panel.rows.item_count > 0 and panel.rows.item_count < links.shard.spawn_relations.size(), "NPC ID search filters actual source rows")
		panel.search.text = "팩 %d" % int(relation.NpcSpawnPackID)
		panel.search.text_changed.emit(panel.search.text)
		for _frame: int in range(3): await process_frame
		check(panel.rows.item_count > 0 and panel.detail.text.contains("원본 정의에서 생성 제외"), "source IsSpawn0 state selectable and visible")
		await capture("02-source-disabled")
		panel.mode.select(2); panel.mode.item_selected.emit(2)
		for _frame: int in range(3): await process_frame
		check(panel.rows.item_count == 93 and panel.action.visible and panel.action.disabled, "portal details retain blocked travel action")
		check(panel.detail.text.contains("도착 지역:") and panel.detail.text.contains("영역 "), "portal destination Land and Territory visible")
		var position_before: Vector2 = world.player.global_position
		await click(panel.action)
		check(world.player.global_position == position_before, "blocked portal button cannot move player")
		await capture("03-portal-held")
	var close: Control = world.hud.workspace.find_child("CloseWindow", true, false)
	if close != null: await click(close)
	check(not world.hud.workspace.visible, "mouse closes feature window")
	check(FileAccess.get_sha256(save_path) == save_sha and JSON.stringify(world.inventory) == inventory, "UI inspection preserves save and inventory")
	world.queue_free()
	await process_frame
	print("PATCH523_SPAWN_MAIN_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "scope": "ACTUAL_MAIN_AND_MONSTER_REJECTION; SUMMON_FLOOR_IS_TEST_FIXTURE; ORIGINAL_M_PIXELS_NOT_TESTED"}))
	quit(0 if failures.is_empty() else 1)
