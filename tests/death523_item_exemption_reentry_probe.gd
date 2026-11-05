extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func finish(level: int) -> void:
	var result: Dictionary = {"ok":failures.is_empty(),"level":level,"checks":checks,"failures":failures,"scope":"FRESH_MAIN_PROCESS_DEFAULT_INSTALLED_SOURCE; parent-owned test fixture, not natural acquisition"}
	var error: Error = Writer.write("user://death523-item-exemption-probe.json",result)
	print("DEATH523_ITEM_EXEMPTION_REENTRY ",JSON.stringify(result))
	quit(0 if failures.is_empty() and error == OK else 1)

func run() -> void:
	var boundary: int = -1
	var item_name: String = ""
	var path: String = ""
	var fingerprint: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--death523-source="): check(false,"child must not receive the parent's original source ZIP argument")
		if argument.begins_with("--death523-probe-level="): boundary = int(argument.trim_prefix("--death523-probe-level="))
		if argument.begins_with("--death523-probe-item="): item_name = argument.trim_prefix("--death523-probe-item=")
		if argument.begins_with("--death523-probe-save="): path = argument.trim_prefix("--death523-probe-save=")
		if argument.begins_with("--death523-probe-hash="): fingerprint = argument.trim_prefix("--death523-probe-hash=")
	check(boundary in [30,31] and not item_name.is_empty() and not path.is_empty() and fingerprint.length() == 64,"parent fixture provides a bounded level and exact save identity")
	if not failures.is_empty(): finish(boundary); return
	check(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == fingerprint,"confirmed parent save exists before fresh Main boot")
	if not failures.is_empty(): finish(boundary); return
	var confirmed_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(confirmed_payload is Dictionary and confirmed_payload.get("death_recovery523") is Dictionary and confirmed_payload.death_recovery523.get("records") is Array and confirmed_payload.death_recovery523.records.size() == 1,"confirmed parent payload has one death ledger")
	if not failures.is_empty(): finish(boundary); return
	var world = load("res://Main.tscn").instantiate()
	# Arm the existing save gateway before _ready/load/entry can attempt a write.
	var confirmed_writes: Array[int] = [0]
	var save_guard: Callable = func(_destination: String,_data: Dictionary) -> Error:
		confirmed_writes[0] += 1
		return ERR_UNAVAILABLE
	world.equipment_collections.test_save_writer = save_guard
	root.add_child(world)
	check(QA.enter_game(world),"fresh Main enters the saved character")
	check(world.equipment_collections.test_save_writer == save_guard,"fresh Main retains the armed startup save gateway")
	world.set_process(false)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.set_physics_process(false)
	for actor: Node in get_nodes_in_group("monsters"): actor.set_physics_process(false)
	var service = world.death_recovery
	check(ProjectSettings.globalize_path(world.save_path()) == path,"fresh Main chooses the parent's exact save path")
	check(service.source.ready and service.source.item_exemption_level() == 30 and service.source.item_exemption_origin() == "SOURCE_CONSTANT_APPLIED_TO_LOCAL_ITEM_POLICY","fresh process loads the installed source scalar through the default path")
	check(FileAccess.get_sha256(service.source.PATH) == service.source.SHA,"default installed source retains the original full-archive identity")
	check(world.level == boundary and world.hp == 0 and service.blocked() and service.pending.is_empty() and not service.save_blocked,"fresh process restores the confirmed dead character")
	check(world.experience == int(confirmed_payload.experience),"fresh process restores the exact confirmed XP balance without repeated loss")
	check(service.state.records.size() == 1,"fresh process retains one immutable death receipt")
	if service.state.records.size() == 1:
		var entry: Dictionary = service.state.records[0]
		check(int(entry.level) == boundary and int(entry.exp) > 0 and bool(entry.source_rules),"fresh receipt retains its native level and XP-loss snapshot")
		check(int(entry.exp) == int(confirmed_payload.death_recovery523.records[0].exp),"fresh receipt preserves the exact confirmed XP-loss quantity")
		check(entry.item.is_empty() if boundary == 30 else str(entry.item.get("id","")) == "900001","fresh receipt keeps only the expected physical item escrow")
	check(world.item_instances.has("900001") == (boundary == 30) and int(world.inventory.get(item_name,0)) == (1 if boundary == 30 else 0),"fresh process preserves exactly one ownership location")
	world._respawn_player("fresh process duplicate death callback")
	await process_frame
	check(FileAccess.get_sha256(path) == fingerprint and service.state.records.size() == 1,"fresh process duplicate callback does not repeat loss or rewrite confirmed bytes")
	world.queue_free()
	await process_frame
	check(confirmed_writes[0] == 0 and FileAccess.get_sha256(path) == fingerprint,"fresh reentry and shutdown do not call the game save writer")
	finish(boundary)
