extends SceneTree
## Actual map UI and source-declaration preservation using the private handoff.
const QA = preload("res://tests/qa_class_selection.gd")
const EVIDENCE = preload("res://scripts/maps/patch523_portal_source_evidence.gd")
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PORTAL_SOURCE_FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func click(control: Control) -> void:
	check(control != null, "actual UI control exists")
	if control == null: return
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
		root.push_input(event, true); await process_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	var options: Dictionary = POLICY.settings()
	var links = LINKS.new()
	check(links.load_land(options.root, 4, "Aden/", options.sha), "verified current523 definitions")
	var original: String = JSON.stringify(links.shard)
	var evidence = EVIDENCE.new()
	var path: String = EVIDENCE.configured_path()
	check(evidence.load_archive(path, links), "official handoff and64 member hashes load")
	check(evidence.by_portal.size() == 50 and evidence.aden_count() == 31, "50 source matches include31 Aden departures")
	var mismatch: Dictionary = evidence.for_portal(350)
	check(not mismatch.is_empty() and int(mismatch.packed_target_candidate[0]) == 34278 and int(mismatch.packed_target_candidate[1]) == 32224 and not mismatch.packed_target_within_declared_territory, "Portal350 conflicting packed candidate remains separate")
	var fresh: int = 0
	var contained: int = 0
	var aden_contained: int = 0
	for id: Variant in evidence.by_portal:
		var row: Dictionary = evidence.for_portal(int(id))
		if row.proof.current_DAT_SHA1_freshly_rehashed: fresh += 1
		if row.packed_target_within_declared_territory:
			contained += 1
			if row.source_land_id == 4: aden_contained += 1
		check(not row.runtime_enabled, "source match never grants activation %s" % id)
	check(contained == 42 and aden_contained == 30, "42 candidates within declaration bounds include30 Aden records")
	check(fresh == 31, "31 current-DAT and19 retained508 evidence scopes stay distinct")
	mismatch.packed_target_candidate[0] = 0
	check(evidence.for_portal(350).packed_target_candidate[0] == 34278, "query cannot rewrite evidence")
	check(not evidence.load_archive(path + ".missing", links) and not evidence.loaded and evidence.by_portal.is_empty(), "missing archive clears stale matches")
	var invalid := FileAccess.open("user://invalid-source-evidence.zip", FileAccess.WRITE)
	invalid.store_string("invalid archive"); invalid.close()
	check(not evidence.load_archive("user://invalid-source-evidence.zip", links) and evidence.by_portal.is_empty(), "wrong archive SHA rejects before use")
	var spec: Dictionary = links.manifest.lands["22803"].duplicate(true)
	links.manifest.lands["22803"].sha256 = "0".repeat(64)
	check(not evidence.load_archive(path, links) and evidence.by_portal.is_empty(), "different current declaration shard is rejected")
	links.manifest.lands["22803"] = spec
	check(evidence.load_archive(path, links) and JSON.stringify(links.shard) == original, "recovery preserves source declarations")
	check(links.portal_evidence().size() == 93, "50 additional raw matches are not50 new portals")
	print("PORTAL_SOURCE_PHASE: verified source rows; entering actual Main")
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main class and map start")
	world.player.set_physics_process(false); world.field_population.set_process(false); world.original_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	check(world._save_game(true) == OK, "isolated baseline save")
	var saved: String = FileAccess.get_sha256(world.save_path())
	var gold: int = world.gold
	var inventory: String = JSON.stringify(world.inventory)
	var placements: String = JSON.stringify(world.field_map.data)
	for _frame: int in range(4): await process_frame
	print("PORTAL_SOURCE_PHASE: opening actual map UI")
	await click(world.hud.find_child("Shortcut_map", true, false))
	for _frame: int in range(4): await process_frame
	await click(world.hud.workspace.find_child("OpenWorldLinks", true, false))
	for _frame: int in range(4): await process_frame
	var panel: Control = world.hud.workspace.find_child("WorldLinksPanel", true, false)
	check(panel != null and panel.portal_source.loaded, "actual map screen loads verified source evidence")
	if panel != null:
		check(panel.summary.text.contains("원문 대조 50건 · 아덴 출발 31건"), "actual summary distinguishes records from portals")
		panel.mode.select(2); panel.mode.item_selected.emit(2)
		panel.search.text = "포탈 350 →"; panel.search.text_changed.emit(panel.search.text)
		check(panel.rows.item_count == 1, "existing Portal350 selected through map search")
		check(panel.detail.text.contains("(34275, 32222)") and panel.detail.text.contains("(34278, 32224)") and panel.detail.text.contains("선언값을 유지"), "UI displays both declared arrival and conflicting candidate")
		check(panel.detail.text.contains("Map/Aden/80157ff7.s32@154102") and panel.detail.text.contains("현행 DAT"), "UI exposes row-level source provenance")
		check(panel.action.visible and panel.action.disabled and not panel.navigate.visible, "source research does not enable travel")
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--patch523-capture-dir="):
				await RenderingServer.frame_post_draw
				var output: String = arg.trim_prefix("--patch523-capture-dir=")
				DirAccess.make_dir_recursive_absolute(output)
				check(root.get_texture().get_image().save_png(output.path_join("portal350-source-evidence.png")) == OK, "actual OpenGL map UI capture")
	world.hud._close_workspace()
	check(JSON.stringify(world.field_map.data) == placements and JSON.stringify(links.shard) == original, "host placements and original definitions unchanged")
	check(world.gold == gold and JSON.stringify(world.inventory) == inventory, "inspection preserves currency and inventory")
	check(world._save_game(true) == OK and FileAccess.get_sha256(world.save_path()) == saved, "inspection preserves existing save bytes")
	print("PATCH523_PORTAL_SOURCE_MAIN_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
