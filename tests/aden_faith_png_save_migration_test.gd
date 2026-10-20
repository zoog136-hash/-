extends SceneTree
## Real Main/pack save compatibility. Render proof is the separate OpenGL suite.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("ADEN_FAITH_SAVE_FAIL: "+label)
func finish(world: TwilightWorld) -> void:
	print("ADEN_FAITH_SAVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_SAVE_MIGRATION; RENDER_VALIDATION_SEPARATE"}))
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
func run() -> void:
	if not REGISTRY.extra_installed():
		print("ADEN_FAITH_SAVE_SKIP: actual verified private PNG pack required");quit();return
	var child: bool="--legacy-save-child" in OS.get_cmdline_user_args()
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000
	if child:
		var saved: Dictionary=REGISTRY.read_json(world.save_path())
		check(not world.source_save_blocked and world.active_map_id=="faith_02","explicit legacy mode restores existing map ID")
		check(not world.field_map is NativePngField,"explicit legacy mode uses actual previous terrain")
		check(world.gold==1234567 and world.level==int(saved.level),"explicit legacy mode retains latest progression")
		check(JSON.parse_string(JSON.stringify(world.inventory))==saved.inventory,"explicit legacy mode retains inventory quantities")
		check(JSON.parse_string(JSON.stringify(world.item_instances))==saved.item_instances,"explicit legacy mode retains physical equipment IDs/enhancement")
		check(world.player.global_position.distance_to(world._spawn_position())<1 and world.field_map.walkable(world.player.global_position),"PNG pixels migrate to safe legacy entry")
		await finish(world);return
	check(not REGISTRY.enabled(),"ordinary character save migration fixture")
	check(QA.enter_game(world),"actual Main character entry")
	world._set_map("faith_02",false);world.gold=1234567;world._save_game(true)
	var fixture: Dictionary=REGISTRY.read_json(world.save_path())
	fixture.erase("native_png_plan_sha256");fixture.erase("native_png_review_sha256")
	fixture.map_layout_revision=1;fixture.position=[200,200]
	check(WRITER.write(world.save_path(),fixture)==OK,"legacy schema fixture through real save writer")
	var legacy_hash: String=FileAccess.get_sha256(world.save_path())
	var prior_backup: String=FileAccess.get_sha256(world.save_path()+".pre-native-png") if FileAccess.file_exists(world.save_path()+".pre-native-png") else ""
	var installed: String=OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	var default_root: String=ProjectSettings.globalize_path("user://aden_faith_png_maps")
	check(not DirAccess.dir_exists_absolute(default_root),"isolated app-data corruption fixture")
	DirAccess.make_dir_recursive_absolute(default_root)
	var bad:=FileAccess.open(default_root+"/index.json",FileAccess.WRITE)
	bad.store_string("corrupt negative-test index");bad.close()
	# Override a valid Git bundle with the isolated corrupt installation.
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",default_root)
	world.gold=77;world._load_game(true);world._save_game(true)
	check(world.source_save_blocked and world.gold==77,"corrupt pack cannot partially mutate a legacy character")
	check(FileAccess.get_sha256(world.save_path())==legacy_hash,"corrupt installation cannot overwrite old ordinary save bytes")
	DirAccess.remove_absolute(default_root+"/index.json");DirAccess.remove_absolute(default_root)
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",installed);world._load_game(true)
	check(not world.source_save_blocked and world.field_map is NativePngField and world.gold==1234567,"verified pack migrates legacy progression")
	check(world.player.global_position.distance_to(world._spawn_position())<1,"legacy pixels replaced with inspected PNG entry")
	check(FileAccess.get_sha256(world.save_path()+".pre-native-png")== (legacy_hash if prior_backup.is_empty() else prior_backup),"one-time pre-PNG save backup retains original bytes")
	world._save_game(true)
	var native_hash: String=FileAccess.get_sha256(world.save_path())
	for legacy_switch: String in ["--legacy-map-layouts","--legacy-aden-faith-layouts"]:
		var args:=PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/aden_faith_png_save_migration_test.gd","--",legacy_switch,"--legacy-save-child"])
		var pid: int=OS.create_process(OS.get_executable_path(),args,false)
		check(pid>0,"isolated legacy-mode child started with the same test-owned save: "+legacy_switch)
		if pid>0:
			var deadline: int=Time.get_ticks_msec()+60000
			while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline: await process_frame
			if OS.is_process_running(pid): OS.kill(pid);check(false,"legacy child completed before deadline")
			else: check(OS.get_process_exit_code(pid)==0,"actual explicit legacy restart restores latest native-save progression: "+legacy_switch)
	check(FileAccess.get_sha256(world.save_path())==native_hash,"loading in legacy mode does not silently overwrite PNG save bytes")
	await finish(world)
