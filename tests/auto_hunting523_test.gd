extends SceneTree
const CATALOG = preload("res://scripts/auto_hunting/source_schedule.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("AUTO_HUNT523_FAIL: ", message)

func _initialize() -> void:
	var catalog = CATALOG.new()
	check(not catalog.load_pack("user://absent-auto-hunt523"), "missing pack rejected")
	check(catalog.list_destinations().is_empty(), "missing pack exposes no invented destinations")
	check(catalog.assess_request(4, 662, 99, 999999).code == "PACK_UNAVAILABLE", "no pack no transit")
	var directory: String = OS.get_environment("TWILIGHT_AUTO_HUNT523_DIR")
	if not directory.is_empty():
		check(catalog.load_pack(directory), "exact actual523 pack loads")
		var entries: Array = catalog.list_destinations()
		check(entries.size() == 80, "all eighty source menu definitions")
		check(catalog.categories().size() == 6, "inactive category definitions preserved")
		check(catalog.list_destinations(11).size() == 49, "field category")
		check(catalog.list_destinations(21).size() == 23, "Hadin category")
		check(catalog.list_destinations(1).size() == 8, "special category")
		var sentinel_count: int = 0
		var destination_count: int = 0
		for entry: Dictionary in entries:
			check(not entry.source_land_specified and not entry.runtime_enabled, "definitions cannot imply departure or activation")
			if entry.schedule.TerritoryID == 0:
				sentinel_count += 1
				check(entry.hunting_territory == null and entry.hunting_land == null, "zero is absent hunting region")
			for landing: Dictionary in entry.destinations:
				destination_count += 1
				var assessment: Dictionary = catalog.assess_request(int(entry.schedule.ID), int(landing.link.ID), 99, 99999999)
				var expected_code: String = "UNVERIFIED_ARRIVAL" if int(entry.currency.ID) == 1 else "UNSUPPORTED_CURRENCY"
				check(not assessment.ok and assessment.code == expected_code, "every landing remains gated without verified geometry/currency")
		check(sentinel_count == 25 and destination_count == 87, "25 zero sentinels and87 landing relations")
		check(catalog.destination(4).hunting_territory.ID == 1723, "hunting territory identity")
		check(catalog.assess_request(4, 662, 1, 8000).code == "UNVERIFIED_ARRIVAL", "recommend19 is not minimum19")
		check(catalog.assess_request(4, 662, 99, 7999).code == "INSUFFICIENT_ADENA", "source fee quote")
		check(catalog.assess_request(4, 672, 99, 99999).code == "UNKNOWN_LANDING_LINK", "foreign schedule landing rejected")
		check(catalog.assess_request(-1, 662, 99, 99999).code == "UNKNOWN_SCHEDULE", "unknown schedule rejected")
		for entry: Dictionary in entries:
			if not entry.prerequisites.is_empty():
				var required: int = int(entry.prerequisites[0].definition.Value)
				check(catalog.assess_request(int(entry.schedule.ID), int(entry.destinations[0].link.ID), required - 1, 99999999).code == "MIN_LEVEL", "explicit minimum enforced")
		var edited: Dictionary = catalog.destination(4)
		edited.teleport.TeleportCost = 0
		edited.destinations.clear()
		check(catalog.destination(4).teleport.TeleportCost == 8000 and catalog.destination(4).destinations.size() == 1, "read callers cannot mutate source catalog")
		check(not catalog.load_pack("user://absent-auto-hunt523"), "failed replacement rejected")
		check(catalog.loaded and catalog.list_destinations().size() == 80, "failed replacement retains session catalog")
		var corrupt_dir: String = "user://corrupt-auto-hunt523"
		DirAccess.make_dir_recursive_absolute(corrupt_dir)
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(directory.path_join(CATALOG.PACK_NAME))
		raw[raw.size() / 2] ^= 1
		var corrupt := FileAccess.open(corrupt_dir.path_join(CATALOG.PACK_NAME), FileAccess.WRITE)
		corrupt.store_buffer(raw)
		corrupt.close()
		check(not catalog.load_pack(corrupt_dir), "same-size corrupt pack rejected by byte hash")
		check(catalog.destination(4).teleport.TeleportCost == 8000, "corrupt replacement preserves costs")
	print("AUTO_HUNT523_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "actual523": not directory.is_empty()}))
	quit(0 if failures.is_empty() else 1)
