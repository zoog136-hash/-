extends SceneTree
## Opt-in continuation of set_host in its isolated profile. Never player data.
const QA = preload("res://tests/qa_class_selection.gd")
const PROOF = "user://equipment523-set-host-proof.json"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	if not FileAccess.file_exists(PROOF):
		check(false,"requires the isolated set-host profile and its proof")
		finish()
		return
	var scene: PackedScene = load("res://Main.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	check(QA.enter_game(world),"actual Main accepts the valid source guard save")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	for population: Variant in [world.field_population,world.legacy_population,world.original_population]:
		if is_instance_valid(population):
			population.set_process(false)
			population.set_physics_process(false)
	var path: String = world.save_path()
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var original_sha: String = FileAccess.get_sha256(path)
	var saved: Variant = JSON.parse_string(original.get_string_from_utf8())
	check(saved is Dictionary and saved.get("equipment523_set_effects",{}).get("guard",{}).get("hits",0) > 0,"isolated proof contains a spent active source guard")
	if not saved is Dictionary:
		world.queue_free()
		await process_frame
		finish()
		return
	var backup: String = path+".set-safety-"+str(Time.get_ticks_usec())
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup)) == OK,"preserve the original fixture save before failure injection")
	var before: String = JSON.stringify([world.inventory,world.item_instances,world.gold,world.hp,world.mp,world.equipped_items,world.level,world.experience],"",true,true)
	var invalid: Dictionary = saved.duplicate(true)
	invalid.equipment523_set_effects.guard.hits = "not a numeric source count"
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	var invalid_sha: String = FileAccess.get_sha256(path)
	world._load_game(true)
	check(world.equipment523.save_blocked and world.source_save_blocked,"malformed new source state blocks loading before live adoption")
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.hp,world.mp,world.equipped_items,world.level,world.experience],"",true,true) == before,"failed new-namespace validation preserves live ownership and progression")
	check(world._save_game(true) == ERR_UNAVAILABLE and FileAccess.get_sha256(path) == invalid_sha,"autosave cannot overwrite the unaccepted durable candidate")
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	world._load_game(true)
	check(not world.equipment523.save_blocked and not world.source_save_blocked,"restoring the valid original permits a successful load")
	check(int(world.equipment523.export_state(world).get("guard",{}).get("hits",0)) == int(saved.equipment523_set_effects.guard.hits),"the original spent guard state survives validation recovery")
	check(FileAccess.get_sha256(path) == original_sha and FileAccess.get_sha256(backup) == original_sha,"recovery preserves the exact original bytes and diagnostic backup")
	world.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("EQUIPMENT523_SET_SAVE_SAFETY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_ISOLATED_FIXTURE_SAVE_REJECTION_AND_RECOVERY"}))
	quit(0 if failures.is_empty() else 1)
