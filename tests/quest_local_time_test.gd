extends SceneTree

const SERVICE = preload("res://scripts/quests/quest_service.gd")
const VIEW = preload("res://scripts/ui/renewal_quests.gd")
const AIN = preload("res://scripts/ainhasad_service.gd")
var failures: Array[String] = []
var checks: int = 0

class ClockQuest:
	extends "res://scripts/quests/quest_service.gd"
	var local_now: String = "2026-11-04T04:59:59"
	func _local_date(_now: int = -1) -> Dictionary:
		return Time.get_datetime_dict_from_datetime_string(local_now, false)

class QuestWorld:
	extends Node
	var quest_service: RefCounted
	var level: int = 1
	var inventory: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("LOCAL_QUEST_FAIL: " + label)

func key(local_date: String) -> int:
	return SERVICE.local_daily_key(Time.get_datetime_dict_from_datetime_string(local_date, false))

func configured(local_date: String = "2026-11-04T04:59:59") -> RefCounted:
	var service := ClockQuest.new()
	service.local_now = local_date
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	check(service.configure(db.get("아이템", []), db.get("몬스터", [])), "quest definitions configure")
	return service

func claim(service: RefCounted, id: String = "twilight:daily:001") -> bool:
	return bool(service.complete_instantly(id, 1).get("ok", false))

func roundtrip(service: RefCounted, at: String) -> RefCounted:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(service.export_state()))
	var result: RefCounted = configured(at)
	result.import_state(saved)
	return result

func _run() -> void:
	# Dates are civil wall-clock values, not Unix instants with a fixed offset.
	for pair: Array in [
		["2026-11-04", "2026-11-03"], # Wednesday / Tuesday
		["2026-11-02", "2026-11-01"], # Monday / Sunday
		["2027-01-01", "2026-12-31"],
		["2026-03-01", "2026-02-28"],
		["2028-03-01", "2028-02-29"]]:
		var before: int = key(str(pair[0]) + "T04:59:59")
		check(before == key(str(pair[1]) + "T12:00:00"), "pre-05:00 belongs to previous date: " + str(pair[0]))
		check(key(str(pair[0]) + "T00:00:00") == before, "midnight is not a reset: " + str(pair[0]))
		check(key(str(pair[0]) + "T05:00:00") == before + 1, "05:00 inclusive boundary: " + str(pair[0]))
		check(key(str(pair[0]) + "T23:59:59") == before + 1, "end of local day: " + str(pair[0]))
	# The calendar already reflects the OS's DST rules. A skipped/repeated hour
	# before 05:00 stays in the same daily period, regardless of elapsed length.
	check(key("2026-03-08T01:59:59") == key("2026-03-08T03:00:00"), "spring DST jump does not reset")
	check(key("2026-11-01T01:59:59") == key("2026-11-01T01:00:00"), "fall DST repeated hour does not reset")
	var service: RefCounted = configured()
	check(claim(service), "claim before local 05:00")
	check(claim(service, "twilight:main:001"), "main completion recorded")
	service.local_now = "2026-11-04T05:00:00"
	check(claim(service), "claim at local 05:00")
	check(not claim(service), "same period cannot pay twice")
	check(not claim(service, "twilight:main:001"), "daily reset preserves main claim")
	service.local_now = "2026-11-04T00:00:00"
	check(not claim(service), "clock or timezone rollback cannot pay again")
	service = roundtrip(service, "2026-11-04T00:00:00")
	service.local_now = "2026-11-04T05:00:00"
	check(not claim(service), "reload during rollback preserves greatest observed day")
	service.local_now = "2026-11-05T05:00:00"
	check(claim(service), "next local 05:00 resets normally")
	# Crossing a date line forward and back, even with a reload in between,
	# must not erase the recorded future-day guard or one-time claims.
	service.local_now = "2026-11-06T06:00:00"
	check(claim(service), "new day after forward timezone change")
	service = roundtrip(service, "2026-11-04T06:00:00")
	for date: String in ["2026-11-04", "2026-11-05", "2026-11-06"]:
		service.local_now = date + "T06:00:00"
		check(not claim(service), "timezone return cannot repay " + date)
	service.local_now = "2026-11-07T05:00:00"
	check(claim(service), "first unseen day after timezone guard pays")
	# Schema 1 saved KST day ordinals without an instant/timezone. Migrate
	# conservatively, preserving daily progress/claims on the first local day.
	var legacy_at: int = 1793746800 # 2026-11-03 23:00 UTC, KST reset day 20761
	var legacy_day: int = 20761
	var legacy: Dictionary = {"schema_version":1, "day_key":legacy_day,
		"claimed":{"twilight:daily:001":true, "twilight:main:001":true},
		"progress":{"twilight:daily:002":3, "twilight:main:001":2}}
	for date: String in ["2026-11-03T18:00:00", "2026-11-04T08:00:00", "2026-11-05T08:00:00"]:
		var migrated: RefCounted = configured(date)
		migrated.import_state(legacy, legacy_at)
		check(not claim(migrated), "legacy claim preserved across time bases at " + date)
		check(int(migrated.progress.get("twilight:daily:002", 0)) == 3, "legacy daily progress preserved at migration")
		var saved: Dictionary = migrated.export_state()
		check(saved.schema_version == 2 and saved.time_basis == "device_local", "save distinguishes local day from legacy KST")
		var next_day: int = key(date) + 1
		migrated.local_now = Time.get_datetime_string_from_unix_time(next_day * 86400 + 5 * 3600)
		check(claim(migrated), "legacy migration resumes next local reset")
		check(not claim(migrated, "twilight:main:001"), "migration and reset preserve one-time claim")
		check(not migrated.progress.has("twilight:daily:002"), "next reset clears old daily progress")
	# A future guard in a legacy save survives the one-time basis migration.
	var guarded: RefCounted = configured("2026-11-04T08:00:00")
	legacy.day_key = legacy_day + 2
	guarded.import_state(legacy, legacy_at)
	guarded = roundtrip(guarded, "2026-11-04T08:00:00")
	guarded.local_now = "2026-11-06T08:00:00"
	check(not claim(guarded), "legacy future-day guard survives local reload")
	guarded.local_now = "2026-11-07T05:00:00"
	check(claim(guarded), "legacy future guard eventually expires normally")
	# Progress must reset before the first kill/pickup of the new local day,
	# even when the quest screen has not been opened since yesterday.
	var tracking: RefCounted = configured()
	tracking.record_kill("고스트", false)
	tracking.record_pickup("HP 물약", 3)
	tracking.local_now = "2026-11-04T05:00:00"
	tracking.record_kill("고스트", false)
	tracking.record_pickup("HP 물약", 1)
	check(int(tracking.progress.get("twilight:daily:001", 0)) == 1, "first post-reset kill belongs to new local day")
	check(int(tracking.progress.get("twilight:daily:002", 0)) == 1, "first post-reset pickup belongs to new local day")
	check(int(tracking.progress.get("twilight:main:001", 0)) == 2, "main progress persists across local reset")
	# Actual OS timezone is checked in separate processes with distinct TZ values.
	var actual := SERVICE.new()
	var expected_day: String = OS.get_environment("TWILIGHT_TEST_LOCAL_DAY")
	if not expected_day.is_empty():
		check(SERVICE.local_daily_key(actual._local_date()) == int(expected_day), "production OS calendar matches independent Python local-day oracle")
		check(AIN.month_key() == OS.get_environment("TWILIGHT_TEST_LOCAL_MONTH"), "monthly purchase calendar follows device timezone")
	# Build the real existing quest view and verify its daily reset explanation.
	var owner_world := QuestWorld.new()
	owner_world.quest_service = tracking
	root.add_child(owner_world)
	var view := VIEW.new()
	root.add_child(view)
	view.configure(owner_world)
	view._select("daily")
	check(view.summary.text.contains("기기 로컬 시간 오전 5시") and not view.summary.text.contains("KST"), "daily UI explains the actual local schedule")
	view.free()
	owner_world.free()
	print("LOCAL_QUEST_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"timezone":Time.get_time_zone_from_system()}))
	quit(0 if failures.is_empty() else 1)
