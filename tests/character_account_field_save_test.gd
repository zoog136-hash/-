extends SceneTree
## Use a fresh XDG profile. Pass -- --bench to repeat the live save handlers
## with progressively larger synthetic history. No phone save is an input.
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const WAREHOUSE = preload("res://tests/warehouse_busy_retry_test.gd")
const MATERIAL = WAREHOUSE.ITEM
const HISTORY := "historical_test_extension"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ACCOUNT_FIELD_SAVE_FAIL ", label)
	return ok

func disk(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func seed_history(world: Node, rows: int) -> bool:
	var history: Dictionary = {}
	for i: int in rows:
		var row: Array = []
		for j: int in 32:
			row.append({"id": i, "counts": [j, j+1, j+2], "description": "historical test extension"})
		history[str(i)] = row
	var state: Dictionary = world.monsterbook523.export_state()
	state[HISTORY] = history
	return world.monsterbook523.import_state(state)

func sample(started: int) -> Dictionary:
	var result := {"total": Time.get_ticks_usec() - started}
	for phase: String in ["save.check_native_stack", "save.snapshot", "save.account", "save.write"]:
		result[phase] = HITCH._details.get(phase, [0])[0]
	return result

func finish() -> void:
	ACCOUNT.session.clear()
	ACCOUNT.forget_durable()
	print("ACCOUNT_FIELD_SAVE_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("twilight_v20_save"):
			printerr("ACCOUNT_FIELD_SAVE_FAIL fresh XDG profile required")
			quit(2)
			return
	var store := ACCOUNT.new()
	if not check(store.open().get("ok", false), "open isolated roster"):
		finish()
		return
	var catalog := WAREHOUSE.Catalog.new()
	var dormant: Dictionary = store.create_character("보관용캐릭터", 3, 2, catalog)
	var active: Dictionary = store.create_character("사냥용캐릭터", 1, 1, catalog)
	if not check(dormant.get("ok", false) and active.get("ok", false) and store.select_character(active.id).get("ok", false), "create two real account records and select the knight"):
		finish()
		return
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var fixture := WAREHOUSE.new()
	fixture.prepare(world)
	fixture.free()
	check(world.save_path() == store.path and world.source_gender_id == 1, "Main opened the selected v2 character")
	var inactive: Dictionary = disk(store.path)[ACCOUNT.KEY].characters[0]
	var writer: RefCounted = world.equipment_collections
	world.inventory[MATERIAL] = 20
	world.ui_preferences["test_save_nested"] = {"value": [17]}
	var before: int = writer.save_writes
	world.hud.save_now()
	check(writer.save_writes == before + 1 and disk(store.path).inventory[MATERIAL] == 20, "the HUD Save action writes the account")
	var context: Dictionary = disk(store.path)
	context.gold += 1
	var old: Dictionary = ACCOUNT.stage_save(store.path, context)
	var compact: Dictionary = ACCOUNT.stage_compact_write(store.path, context)
	check(old.get("ok", false) and compact.get("ok", false) and
		JSON.stringify(ACCOUNT.compact(old.payload), "", true, true) == JSON.stringify(compact.payload, "", true, true),
		"dedicated compact writer produces the same canonical bytes")
	world.ui_preferences.test_save_nested.value[0] = 26
	check(writer._last_payload_snapshot.ui_preferences.test_save_nested.value == [17] and
		ACCOUNT._durable.envelope.characters[1].state.ui_preferences.test_save_nested.value == [17],
		"both retained save views stay detached from nested live preference edits")
	world.hud.save_now()
	check(disk(store.path).ui_preferences.test_save_nested.value == [26.0], "nested change is persisted by a later save")
	var prior_json_builds: int = writer.payload_json_builds
	world.hud.save_now()
	check(writer.payload_json_builds == prior_json_builds, "unchanged manual save still avoids JSON serialization")

	var benchmark: bool = "--bench" in OS.get_cmdline_user_args()
	HITCH.reset_for_test(ProjectSettings.globalize_path("user://"))
	HITCH.enabled = true
	for rows: int in ([40, 400, 1600] if benchmark else [3]):
		check(seed_history(world, rows), "accept historical extension of " + str(rows) + " rows")
		var manual_times: Array[Dictionary] = []
		var transfer_times: Array[Dictionary] = []
		for iteration: int in (13 if benchmark else 2):
			world.gold += 10
			HITCH._details.clear()
			var started: int = Time.get_ticks_usec()
			world.hud.save_now()
			var manual := sample(started)
			HITCH._details.clear()
			started = Time.get_ticks_usec()
			var deposit: bool = iteration % 2 == 0
			world.hud.warehouse_transfer_requested.emit(MATERIAL, 1, "deposit" if deposit else "withdraw", "")
			var transfer := sample(started)
			var stored: Dictionary = disk(store.path)
			check(stored.gold == world.gold and stored.inventory.get(MATERIAL) == (19 if deposit else 20) and
				stored.warehouse.stacks.get(MATERIAL, 0) == (1 if deposit else 0), "one exact transfer across live and durable owners")
			if iteration > 0:
				manual_times.append(manual)
				transfer_times.append(transfer)
		if benchmark:
			print("ACCOUNT_FIELD_SAVE_SAMPLE ", JSON.stringify({"history_rows": rows, "bytes": FileAccess.get_size(store.path),
				"manual_us": manual_times, "warehouse_us": transfer_times}))
		# Leave the inventory identical across fixture sizes.
		if int(world.warehouse.stacks.get(MATERIAL, 0)) > 0:
			world.hud.warehouse_transfer_requested.emit(MATERIAL, 1, "withdraw", "")

	var disk_sha: String = FileAccess.get_sha256(store.path)
	check(DirAccess.make_dir_absolute(store.path + ".tmp") == OK, "force an atomic write-open error")
	world.hud.warehouse_transfer_requested.emit(MATERIAL, 1, "deposit", "")
	check(FileAccess.get_sha256(store.path) == disk_sha and world.inventory.get(MATERIAL) == 20 and
		world.warehouse.stacks.get(MATERIAL, 0) == 0 and ACCOUNT._durable.is_empty(), "failed transfer preserves disk and the live balances")
	DirAccess.remove_absolute(store.path + ".tmp")
	world.hud.warehouse_transfer_requested.emit(MATERIAL, 1, "deposit", "")
	var written: Dictionary = disk(store.path)
	check(written[ACCOUNT.KEY].characters[0] == inactive and FileAccess.get_sha256(store.path) == ACCOUNT._durable.sha,
		"successful retry keeps the dormant character and records the written digest")
	check(written.inventory.get(MATERIAL) == 19 and written.warehouse.stacks.get(MATERIAL) == 1,
		"successful retry saves one transfer")
	var file := FileAccess.open(store.path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(" ")
	file.close()
	var outside_sha: String = FileAccess.get_sha256(store.path)
	world.hud.warehouse_transfer_requested.emit(MATERIAL, 1, "deposit", "")
	check(writer.save_blocked and FileAccess.get_sha256(store.path) == outside_sha and world.inventory.get(MATERIAL) == 19,
		"outside edit is protected, with the attempted debit refused")
	world._load_game(true)
	check(not writer.save_blocked and world.inventory.get(MATERIAL) == 19 and world.warehouse.stacks.get(MATERIAL) == 1,
		"normal reload restores the last committed balances")
	world.queue_free()
	await process_frame
	finish()
