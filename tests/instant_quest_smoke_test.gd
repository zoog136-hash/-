extends SceneTree

const SERVICE = preload("res://scripts/quests/quest_service.gd")
const DB = "res://data/game_db_v17.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("INSTANT_QUEST_FAIL: " + label)

func _run() -> void:
	var db: Variant = JSON.parse_string(FileAccess.get_file_as_string(DB))
	check(db is Dictionary, "base game data parses")
	if not db is Dictionary:
		quit(1)
		return
	var service := SERVICE.new()
	check(service.configure(db.get("아이템", []), db.get("몬스터", [])), "quest schema and current game IDs validate: " + service.problem)
	var at: int = 1793670000
	var original_count: int = service.entries(1, {}, at).size()
	check(original_count >= 10, "main, daily and achievement quest definitions loaded")
	check(not bool(service.complete_instantly("invalid:quest:id", 1, at).get("ok", false)), "unknown quest never pays")
	check(not bool(service.complete_instantly("twilight:main:001", 0, at).get("ok", false)), "quest minimum level remains enforced")
	check(service.claimed.is_empty(), "invalid attempts cannot modify quest ownership")
	var first: Dictionary = service.complete_instantly("twilight:main:001", 1, at)
	check(bool(first.get("ok", false)), "fresh quest may be instantly completed without prior kill")
	check(int(first.get("rewards", {}).get("adena", -1)) == 2500, "original quest's explicit reward row returned")
	check(not bool(service.complete_instantly("twilight:main:001", 1, at).get("ok", false)), "one-time reward cannot be claimed twice")
	var snapshot: Dictionary = service.export_state()
	var restored := SERVICE.new()
	check(restored.configure(db.get("아이템", []), db.get("몬스터", [])), "fresh service configured")
	restored.import_state(snapshot, at)
	check(not bool(restored.complete_instantly("twilight:main:001", 1, at).get("ok", false)), "main claim survives save/load")
	check(bool(restored.complete_instantly("twilight:daily:001", 1, at).get("ok", false)), "daily mission may be instantly completed")
	check(not bool(restored.complete_instantly("twilight:daily:001", 1, at).get("ok", false)), "daily cannot be claimed twice on same day")
	var day_after: int = at + 86400
	check(bool(restored.complete_instantly("twilight:daily:001", 1, day_after).get("ok", false)), "daily KST 05:00 rollover allows another claim")
	check(not bool(restored.complete_instantly("twilight:main:001", 1, day_after).get("ok", false)), "daily reset cannot wipe main completion")
	var prior_day: int = at - 86400
	check(not bool(restored.complete_instantly("twilight:daily:001", 1, prior_day).get("ok", false)), "clock rollback cannot farm another daily reward")
	var tracking := SERVICE.new()
	check(tracking.configure(db.get("아이템", []), db.get("몬스터", [])), "tracking service config")
	tracking.record_kill("고스트", false)
	tracking.record_kill("고스트", false)
	tracking.record_pickup("HP 물약", 3)
	var progress: Dictionary = {}
	for row: Dictionary in tracking.entries(1, {}, at):
		progress[str(row["id"])] = int(row["progress"])
	check(int(progress.get("twilight:main:001", 0)) == 2, "real monster death updates progress")
	check(int(progress.get("twilight:daily:002", 0)) == 3, "real item pickup updates progress")
	check(bool(tracking.complete_instantly("twilight:main:001", 1, at).get("ok", false)), "normal objective progress never gates instant completion")
	var future := SERVICE.new()
	check(future.configure(db.get("아이템", []), db.get("몬스터", [])), "future service config")
	future.import_state({"schema_version":1, "claimed":{"does:not:exist":true,"twilight:main:002":true}},at)
	check(not bool(future.complete_instantly("twilight:main:002",1,at).get("ok",false)), "known source id completion imported")
	check(not future.claimed.has("does:not:exist"), "unknown saved quest id ignored")
	print("INSTANT_QUEST_PASS" if failures.is_empty() else "INSTANT_QUEST_FAILED %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
