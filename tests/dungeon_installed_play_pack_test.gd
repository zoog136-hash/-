extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("DUNGEON_INSTALLED_FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(OS.get_environment("TWILIGHT_DUNGEON523_PACK").is_empty(),"no external pack argument; persistent install required")
	var world=load("res://Main.tscn").instantiate();root.add_child(world);world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main restart from saved profile")
	check(world.source_dungeons.orim_actor_types.size()==244 and not world.source_dungeons.orim_actor_defs.is_empty(),"persisted source NPC roles and stats actually loaded")
	check(world.source_dungeons.orim_item_effects.has(231162),"persisted reward effects loaded")
	check(FileAccess.get_sha256(world.SOURCE_DUNGEONS.DEFAULT_MANIFEST.get_base_dir()+"/orim_execution.json")==world.SOURCE_DUNGEONS.EXECUTION_SHA,"actual installed sidecar SHA matches latest")
	check(not world.dungeon_play.state.receipts.is_empty() and not world.dungeon_play.save_blocked,"real own settlements restore without duplicate awards")
	print("DUNGEON_INSTALLED_PLAY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_RESTART_FROM_DRIVE_DOWNLOADED_UI_INSTALLED_PACK_NO_EXTERNAL_PACK_ARGUMENT"}))
	world.dungeon_play.cleanup();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
