extends SceneTree
## Real Main and atomic saves, with an explicitly synthetic completed-run fixture.
## This proves delivery/UI/save behavior, not an original dungeon battle or map.
const QA = preload("res://tests/qa_class_selection.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("DUNGEON_EXECUTION_MAIN_FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	var path := OS.get_environment("TWILIGHT_DUNGEON_SCREENSHOTS")
	if path.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(path)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path.path_join(name+".png")) == OK,"fixture-labelled payout screenshot")

func completed_fixture(world: Node, serial: int) -> Dictionary:
	var state: Dictionary = world.source_dungeon_runs.state.duplicate(true)
	var stage: Dictionary = world.source_dungeons.stage("tower",4)
	var counts: Dictionary = {}
	for goal: Dictionary in stage.goals: counts[str(int(goal.row.ID))] = int(goal.row.Amount)
	state.active = {"id":"tower:4:%d" % serial,"stage_id":4,"hard":false,"map_id":"TEST_FIXTURE_ONLY","clock_contract":"TEST_FIXTURE_ONLY","cycle":100,"status":"cleared","counts":counts,"events":{},"grantable_ids":world.DUNGEON_RUNS._reward_ids(world.source_dungeons.reward_preview("tower",4))}
	state.clears["4"] = {"cycle":100,"clock_contract":"TEST_FIXTURE_ONLY","hard":false}
	state.next_run = serial + 1
	return state

func run() -> void:
	check(not OS.get_environment("TWILIGHT_DUNGEON523_PACK").is_empty(),"actual private data required")
	var scene := load("res://Main.tscn") as PackedScene
	check(scene != null,"actual Main loads")
	if scene == null: quit(1); return
	var world = scene.instantiate()
	root.add_child(world)
	world.set_process(false); world.set_physics_process(false); world.save_timer = -100000.0
	check(QA.enter_game(world),"actual class entry")
	world.player.set_physics_process(false)
	var actor: Node = world.player
	var map_id: String = world.active_map_id
	var position: Vector2 = actor.global_position
	var ain: int = world.ain_service.blessing
	check(not world.source_dungeon_action("begin",4).ok and world.ain_service.blessing == ain,"real source84 field cannot impersonate M523 dungeon")
	check(world._save_game(true) == OK,"initial ordinary save")
	check(world.source_dungeon_runs.restore(completed_fixture(world,1)),"explicit completed-run fixture validates")
	check(world._save_game(true) == OK,"completed-run fixture survives production writer")
	var gold: int = world.gold
	var coin: int = int(world.inventory.get("명예 코인",0))
	var tokens: int = int(world.inventory.get("시련의 증표",0))
	world.hud.open_source_dungeons()
	var view: Node = world.hud.workspace.find_child("SourceDungeonView",true,false)
	check(view != null and not view.execution_buttons.claim.disabled,"actual UI enables only a completed claim")
	var badge := Label.new()
	badge.text = "검증용 완료 기록 · 원본 전용 맵 전투 미실행"
	badge.position = Vector2(280,686)
	badge.z_index = 999
	world.hud.get_node("Root").add_child(badge)
	await capture("fixture-cleared-claim")
	view.execution_buttons.claim.pressed.emit()
	check(view.notice.text.contains("저장했습니다"),"claim UI reports actual commit")
	check(world.gold == gold + 70000 and world.inventory.get("명예 코인",0) == coin + 250 and world.inventory.get("시련의 증표",0) == tokens + 1,"real Main credits exact source amounts")
	check(world.source_dungeon_runs.state.settled.size() == 1 and world.source_dungeon_runs.state.active.is_empty(),"receipt and clear-state committed together")
	await capture("fixture-claim-committed")
	var path: String = world.save_path()
	var sha := FileAccess.get_sha256(path)
	check(not world.source_dungeon_action("claim").ok and FileAccess.get_sha256(path) == sha,"duplicate UI request cannot spend/write/grant")
	world._load_game(true)
	check(world.gold == gold + 70000 and not world.source_dungeon_action("claim").ok,"restart preserves delivered balance and receipt")
	var second: Dictionary = completed_fixture(world,2)
	check(world.source_dungeon_runs.restore(second),"second explicit fixture")
	world.source_save_blocked = true
	var failed_gold: int = world.gold
	check(not world.source_dungeon_action("claim").ok and world.gold == failed_gold and world.source_dungeon_runs.state.active.status == "cleared","production save guard rejects without live reward or receipt mutation")
	check(FileAccess.get_sha256(path) == sha,"failed claim preserves original durable bytes")
	world.source_save_blocked = false
	check(world.source_dungeon_action("claim").ok and world.gold == failed_gold + 70000,"save-failure retry delivers exactly once")
	check(not world.source_dungeon_action("claim").ok and world.gold == failed_gold + 70000,"retried claim stays deduplicated")
	check(world.active_map_id == map_id and world.player.global_position == position,"contract test does not fabricate dungeon travel")
	var candidate: Dictionary = world.source_dungeon_runs.state.duplicate(true)
	candidate.revision = int(candidate.revision) + 1
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	persisted.source_dungeon523 = candidate
	check(WRITER.write(path,persisted) == OK,"explicit post-write activation-failure fixture")
	var candidate_sha := FileAccess.get_sha256(path)
	world.source_save_blocked = true
	check(world.commit_source_dungeon(candidate,{}) != OK and world.source_dungeon_runs.save_blocked,"uncertain committed candidate blocks monetary retry")
	check(FileAccess.get_sha256(path) == candidate_sha,"uncertain outcome retains candidate bytes")
	world._load_game(true)
	check(not world.source_dungeon_runs.save_blocked and int(world.source_dungeon_runs.state.revision) == int(candidate.revision),"reload reconciles already committed candidate")
	world.pending_dungeon_events["stale"] = {"kind":"kill","token":"old-life","item_id":0,"run_id":"tower:4:old"}
	check(world.source_dungeon_action("retry").ok and world.pending_dungeon_events.is_empty(),"old-run pending kill cannot leak into a new run")
	var good: String = FileAccess.get_file_as_string(path)
	var corrupt: Dictionary = JSON.parse_string(good)
	corrupt.source_dungeon523.schema = "unknown"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt)); file.close()
	var corrupt_sha := FileAccess.get_sha256(path)
	world._load_game(true)
	check(world.source_save_blocked and world.source_dungeon_runs.save_blocked and world.gold == failed_gold + 70000,"corrupt ledger rejects before live progression mutation")
	check(world._save_game(true) != OK and FileAccess.get_sha256(path) == corrupt_sha,"corrupt save bytes cannot be silently overwritten")
	print("DUNGEON_EXECUTION_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_UI_AND_ATOMIC_PAYOUT; SYNTHETIC_CLEAR_FIXTURE; NO_ORIGINAL_DUNGEON_MAP_OR_COMBAT_CLAIM"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
