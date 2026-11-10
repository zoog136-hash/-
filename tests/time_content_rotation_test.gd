extends SceneTree
## One TWILIGHT calendar (KST 05:00), local season rotation for ended monster
## books and passes, and dungeons on by default. Synthetic fixtures only.
const BOOKS = preload("res://scripts/monsterbook/monsterbook523.gd")
const BOOK_LOCAL = preload("res://scripts/monsterbook/monsterbook523_local.gd")
const EVENTS = preload("res://scripts/unconfirmed523/events_domain.gd")
const RUNTIME = preload("res://scripts/unconfirmed523/runtime.gd")
const QUESTS = preload("res://scripts/quests/quest_service.gd")
const DUNGEON_PLAY = preload("res://scripts/dungeons/dungeon_play_service.gd")
const DUNGEON_RUNS = preload("res://scripts/dungeons/dungeon_run_service.gd")
const LOCAL_TOWER = preload("res://scripts/dungeons/local_tower_host.gd")

var failures: int = 0

class FakeBookRuntime extends RefCounted:
	var catalog

class FixtureSource extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array: return tables.get(table, [])
	func row(table: String, id: int) -> Dictionary:
		for entry in rows(table):
			if int(entry.get("ID", 0)) == id: return entry
		return {}
	func item_eligibility(_id: int, _context: Dictionary) -> Dictionary: return {"ok": true}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("TIME_CONTENT_FAIL: ", label)

static func kst(year: int, month: int, day: int, hour: int, minute: int = 0) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":hour,"minute":minute,"second":0})) - 9 * 3600

func _initialize() -> void:
	_calendar()
	_monster_book_rotation()
	_pass_rotation()
	_dungeon_defaults()
	print("TIME_CONTENT_TEST failures=%d" % failures)
	if failures == 0: print("TIME_CONTENT_ROTATION_OK")
	quit(0 if failures == 0 else 1)

func _calendar() -> void:
	var events = EVENTS.new()
	var before := kst(2026, 11, 5, 4, 59)
	var after := kst(2026, 11, 5, 5, 0)
	check(events._local_day({"now": after}) == events._local_day({"now": before}) + 1, "attendance day turns at KST 05:00 by default")
	check(events._local_day({"now": after}) == QUESTS.korean_daily_key(after) and events._local_day({"now": before}) == QUESTS.korean_daily_key(before), "attendance uses the same day as quests, monster book and dungeons")
	var runtime = RUNTIME.new()
	var policy: Dictionary = runtime._time_policy()
	check(int(policy.utc_offset_minutes) == 540 and int(policy.attendance_reset_hour) == 5, "host time policy defaults to KST with a 05:00 reset")
	runtime.time_policy = {"attendance_reset_hour": 0}
	check(int(runtime._time_policy().attendance_reset_hour) == 0, "policy file overrides still apply")

func _monster_book_rotation() -> void:
	var catalog = BOOKS.new()
	catalog._indexes = {
		"MonsterBook": {7: {"ID": 7, "ResetType": 0, "NpcGroupID": 1, "ServerLimitSetID": 0, "StartDateTimeID": 1, "CountingEndDateTimeID": 2, "EndDateTimeID": 3}},
		"DateTimes_Korean": {
			1: {"Year": 2026, "Month": 1, "Day": 1, "Hour": 5, "Minute": 0},
			2: {"Year": 2026, "Month": 1, "Day": 8, "Hour": 5, "Minute": 0},
			3: {"Year": 2026, "Month": 1, "Day": 15, "Hour": 5, "Minute": 0},
		},
	}
	check(catalog.current_period(7, "202601100000") == "options_only" and catalog.rotation(7, "202601100000") == 0, "source season keeps its own dates")
	check(catalog.rotation(7, "202601150500") == 1 and catalog.current_period(7, "202601150500") == "counting", "ended season reopens as rotation 1 at the source end")
	check(catalog.book_clock(7, "202601200000") == "202601060000" and catalog.current_period(7, "202601200000") == "counting", "rotation maps the clock back into the source window")
	check(catalog.current_period(7, "202601270000") == "options_only", "each rotation repeats counting then options-only")
	var turn: int = catalog.rotation(7, "202611091200")
	check(turn > 1 and catalog.current_period(7, "202611091200") in ["counting", "options_only"], "today's clock is inside a rotation, never ended")
	var shown: Dictionary = catalog.local_period(7, "202601200000")
	check(int(shown.rotation) == 1 and int(shown.StartDateTimeID.Day) == 15 and int(shown.EndDateTimeID.Day) == 29, "panel dates follow the current rotation")
	catalog.rotate_ended_seasons = false
	check(catalog.current_period(7, "202601200000") == "ended" and catalog.rotation(7, "202601200000") == 0, "source-date mode keeps ended seasons closed")
	catalog.rotate_ended_seasons = true
	var runtime := FakeBookRuntime.new()
	runtime.catalog = catalog
	var local = BOOK_LOCAL.new()
	local.configure(runtime, null)
	local.unix_clock = func() -> int: return kst(2026, 1, 10, 12)
	check(local.epoch(7) == "source-season:1", "source season epoch is unchanged for existing saves")
	local.unix_clock = func() -> int: return kst(2026, 1, 20, 12)
	check(local.epoch(7) == "source-season:1:r1" and local.window_problem(7).is_empty(), "rotation starts a new epoch and the book can be counted")

func _pass_rotation() -> void:
	var source := FixtureSource.new()
	source.tables = {
		"PassSystem": [{"ID": 50, "PassSystemTypeID": 12, "IsActive": true, "PassSystemQuestListID": 60, "PassSystemDailyQuestListID": 0, "SeasonStartDateTimeID": 1, "SeasonEndDateTimeID": 2}],
		"PassSystemQuest": [{"ID": 61, "PassSystemQuestListID": 60, "QuestID": 70}],
		"QuestView": [{"ID": 70, "TypeID": 102, "QuestResetType": 0}],
		"DateTimes_Korean": [{"ID": 1, "Year": 2026, "Month": 1, "Day": 1, "Hour": 5, "Minute": 0}, {"ID": 2, "Year": 2026, "Month": 1, "Day": 29, "Hour": 5, "Minute": 0}],
	}
	var events = EVENTS.new()
	events.setup(source)
	var pass_row: Dictionary = source.row("PassSystem", 50)
	var context := {"now": kst(2026, 11, 9, 12), "level": 90, "class_id": 1, "region": "KR", "world_no": 1}
	var turn: int = events._pass_rotation(pass_row, context)
	check(turn == floori(float(context.now - kst(2026, 1, 1, 5)) / float(28 * 86400)), "pass rotation counts 28-day repetitions")
	check(events._pass_available(pass_row, context).is_empty(), "ended pass season is open again locally")
	check(events._pass_available(pass_row, {"now": kst(2026, 1, 10, 12)}).is_empty() and events._pass_rotation(pass_row, {"now": kst(2026, 1, 10, 12)}) == 0, "source season is unchanged")
	var state := {"schema": 1, "attendance": {}, "passes": {"50": {"experience": 40, "base": true, "premium": false, "claims": {}}}, "rng_state": "52338039", "roulette_pool": 0, "uses": {}, "quest_progress": {}, "quest_claims": {}, "latest_at": 0, "final_progress": {}}
	var progress: Dictionary = events._pass_progress(state, 50, context)
	check(int(progress.experience) == 0 and not bool(progress.base) and int(progress.rotation) == turn, "a new rotation starts with fresh pass progress")
	check(int(events._pass_progress(state, 50).experience) == 40, "the saved source-season record is untouched")
	var added: Dictionary = events.add_pass_exp(state, 50, 10, context)
	check(bool(added.ok) and int(added.state.passes["50"].experience) == 10 and int(added.state.passes["50"].rotation) == turn, "pass experience goes to the current rotation")
	check(events.validate_state(added.state).is_empty(), "rotated pass record passes save validation")
	check(int(events._pass_progress(added.state, 50, context).experience) == 10, "same rotation keeps its progress")
	var token: String = events._quest_token(pass_row, source.row("QuestView", 70), context)
	check(token == "50:70:season~%d" % turn and events._validate_quest_token(token).is_empty(), "season quest token is per rotation and valid")
	check(events._validate_quest_token("50:70:season").is_empty() and not events._validate_quest_token("50:70:season~0").is_empty(), "old tokens stay valid; rotation 0 is never written")
	events.rotate_ended_passes = false
	check(not events._pass_available(pass_row, context).is_empty(), "source-date mode keeps the ended pass closed")

func _dungeon_defaults() -> void:
	check(bool(DUNGEON_PLAY.defaults().enabled) and bool(DUNGEON_PLAY.empty_state().default_on_v2), "orim and timed dungeons are on by default")
	var fresh: Dictionary = DUNGEON_RUNS.empty_state()
	check(bool(LOCAL_TOWER.settings(fresh).enabled) and bool(fresh.local_default_on_v2), "local Tower of Trials is on by default")
	var runs = DUNGEON_RUNS.new()
	var old_save: Dictionary = fresh.duplicate(true)
	old_save.erase("local_default_on_v2")
	old_save.local_settings = {"enabled": false, "time_scale": 3}
	check(runs.restore(old_save) and bool(LOCAL_TOWER.settings(runs.state).enabled) and int(LOCAL_TOWER.settings(runs.state).time_scale) == 3, "older save is switched on once, keeping its time scale")
	var chosen: Dictionary = runs.state.duplicate(true)
	chosen.local_settings = {"enabled": false, "time_scale": 1}
	check(runs.restore(chosen) and not bool(LOCAL_TOWER.settings(runs.state).enabled), "a later choice to turn it off is kept")
