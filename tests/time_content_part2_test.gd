extends SceneTree
## Titles, expedition, shop period limits, event-region portals and timed
## items follow the TWILIGHT calendar (KST 05:00) and local rotation.
const TITLES = preload("res://scripts/titles/title_runtime523.gd")
const EXPEDITION = preload("res://scripts/expedition/local_runtime.gd")
const SHOP = preload("res://scripts/shop/source523_shop_runtime.gd")
const MAP_CONTEXT = preload("res://scripts/maps/current523_map_runtime_context.gd")
const PORTALS = preload("res://scripts/maps/current523_source_portal_provider.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const BOOKS = preload("res://scripts/monsterbook/monsterbook523.gd")
const BOOK_ITEMS = preload("res://scripts/monsterbook/monsterbook523_items.gd")
const QUESTS = preload("res://scripts/quests/quest_service.gd")

var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("TIME_CONTENT2_FAIL: ", label)

static func kst(year: int, month: int, day: int, hour: int, minute: int = 0) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":hour,"minute":minute,"second":0})) - 9 * 3600

func _initialize() -> void:
	var before := kst(2026, 11, 10, 4, 59)
	var after := kst(2026, 11, 10, 5, 0)

	var titles = TITLES.new()
	titles.policy = JSON.parse_string(FileAccess.get_file_as_string("res://data/titles/local_policy523.json"))
	check(titles.day(after) == titles.day(before) + 1 and titles.day(kst(2026, 11, 11, 4, 59)) == titles.day(after), "title daily attempts reset at KST 05:00")
	check(titles.day(kst(2026, 11, 10, 14, 0)) == titles.day(after), "titles no longer reset at 14:00 Korea time")

	var expedition = EXPEDITION.new()
	expedition.clock = func() -> int: return before
	var day_before: int = expedition.today()
	expedition.clock = func() -> int: return after
	check(expedition.today() == day_before + 1 and expedition.today() == QUESTS.korean_daily_key(after), "expedition day resets at KST 05:00")

	var shop = SHOP.new()
	check(int(shop.calendar_offset_minutes) == 540 and shop.period_reset_hour == {"61":5,"71":5,"81":5,"11311":5}, "shop limits default to KST with 05:00 resets")
	check(shop._period(61, after, 5) != shop._period(61, before, 5), "daily purchase bucket turns at KST 05:00")
	var monday := kst(2026, 11, 9, 5, 0)
	check(shop._period(71, monday, 5) != shop._period(71, monday - 60, 5) and shop._period(71, monday, 5) == shop._period(71, kst(2026, 11, 15, 23, 0), 5), "weekly limit turns on Monday 05:00")
	check(shop._period(81, kst(2026, 12, 1, 5, 0), 5) != shop._period(81, kst(2026, 12, 1, 4, 59), 5), "monthly limit turns on the 1st at 05:00")

	check(MAP_CONTEXT.OFFLINE_PROFILE == {"source_snapshot":"patch523","ServiceRegionCode":"KR","WorldNo":1}, "portals fall back to the offline Korean world 1 profile")
	check(PORTALS.ROTATE_ENDED_EVENT_LANDS, "ended event regions rotate locally")

	var ended := {"source_end_time_raw": 202601010500, "source_delete_time_raw": 202601020500}
	check(DROPS.deadline_problem(ended).is_empty(), "a passed item end/delete date no longer blocks")
	check(not DROPS.deadline_problem({"source_start_time_raw": 209912310500}).is_empty(), "an item whose source start is still ahead stays closed")
	DROPS.rotate_ended_dates = false
	check(not DROPS.deadline_problem(ended).is_empty(), "source-date mode keeps passed item dates closed")
	DROPS.rotate_ended_dates = true

	var catalog = BOOKS.new()
	check(BOOK_ITEMS.delete_clock({"source_delete_clock":"202601150500"}) == "202601150500", "source deletion clock is used without a rotation")
	check(BOOK_ITEMS.delete_clock({"source_delete_clock":"202601150500","local_delete_clock":"202602120500"}) == "202602120500", "rotated reward uses its local deletion clock")
	check(catalog._unix_clock(catalog._clock_unix("202601150500") + 28 * 86400) == "202602120500", "deletion clock moves by whole season lengths")

	print("TIME_CONTENT2_TEST failures=%d" % failures)
	if failures == 0: print("TIME_CONTENT_PART2_OK")
	quit(0 if failures == 0 else 1)
