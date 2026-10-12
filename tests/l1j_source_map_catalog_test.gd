extends SceneTree
const CATALOG = preload("res://addons/twilight_l1j/twilight_source_map_catalog.gd")
var failures: Array[String] = []
var checks: int = 0
const BASE := "user://map-recovery-catalog/"

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("L1J_SOURCE_MAP_CATALOG_FAIL: ",message)

func write_manifest(rows: Array) -> void:
	var file := FileAccess.open(BASE+"source_maps.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"maps":rows}))
	file.close()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(BASE+"raw")
	var file := FileAccess.open(BASE+"raw/42.bin",FileAccess.WRITE)
	file.store_buffer(PackedByteArray([3,3,3,3,3,3,3,3,3]))
	file.close()
	var original: Dictionary = {"map_id":42,"dimensions":[3,3],"source_origin":[32704,32704],
		"row_major_sha256":FileAccess.get_sha256(BASE+"raw/42.bin"),"raw_file":"raw/42.bin","navigation_rules":"A3_STATIC_EDGES"}
	write_manifest([original])
	var catalog = CATALOG.new()
	check(catalog.load_catalog(BASE+"source_maps.json"), "load well-formed private catalogue")
	check(catalog.map_ids() == [42], "explicit map IDs")
	var changed: Dictionary = catalog.record(42)
	changed.dimensions[0] = 999
	check(int(catalog.record(42).dimensions[0]) == 3 and int(catalog.record(42).dimensions[1]) == 3, "metadata lookup cannot mutate catalogue")
	var projection := Transform2D(Vector2(24,-12),Vector2(24,12),Vector2(-48*32704,0))
	var nav: TwilightL1JSourceNavigation = catalog.create_navigation(42,projection)
	check(nav != null, "confirmed rules and digest load a navigation layer")
	if nav != null:
		check(nav.coordinates.world_to_cell(nav.coordinates.cell_to_world(Vector2i.ONE)) == Vector2i.ONE, "source origin roundtrip")
		check(nav.find_path(Vector2i.ONE,Vector2i(2,1),2) == [Vector2i.ONE,Vector2i(2,1)], "private directory reaches bounded source edge")
	check(catalog.create_navigation(43,projection) == null, "unregistered ID cannot load")
	check(catalog.create_navigation(42,Transform2D(Vector2(NAN,0),Vector2(0,1),Vector2.ZERO)) == null, "invalid projection cannot load")
	var other: Dictionary = original.duplicate(true)
	other.navigation_rules = "UNVERIFIED_OTHER_REVISION"
	write_manifest([other])
	check(catalog.load_catalog(BASE+"source_maps.json"), "other revision can be inspected")
	check(catalog.create_navigation(42,projection) == null, "other revision is not given A3 walkability")
	other = original.duplicate(true)
	other.source_origin = null
	write_manifest([other])
	check(catalog.load_catalog(BASE+"source_maps.json"), "bare text grid can be inspected")
	check(catalog.create_navigation(42,projection) == null, "unknown absolute origin cannot be guessed")
	for change: Dictionary in [{"map_id":42.5},{"dimensions":[3,3.5]}, {"source_origin":[0,0.25]},
		{"raw_file":"../42.bin"},{"row_major_sha256":"bad"},{"navigation_rules":"GUESS"}]:
		other = original.duplicate(true)
		other.merge(change,true)
		write_manifest([original])
		check(catalog.load_catalog(BASE+"source_maps.json"), "restore valid catalogue before rejection")
		write_manifest([other])
		check(not catalog.load_catalog(BASE+"source_maps.json"), "invalid catalogue metadata rejected "+str(change))
		check(catalog.map_ids().is_empty(), "failed reload clears stale records")
	write_manifest([original,original])
	check(not catalog.load_catalog(BASE+"source_maps.json"), "duplicate ID rejected")
	write_manifest([original])
	check(catalog.load_catalog(BASE+"source_maps.json"), "reload before checksum failure")
	file = FileAccess.open(BASE+"raw/42.bin",FileAccess.WRITE)
	file.store_buffer(PackedByteArray([3,3,3,3,3,3,3,3,2]))
	file.close()
	check(catalog.create_navigation(42,projection) == null, "changed source bytes cannot silently load")
	other = original.duplicate(true)
	other.row_major_sha256 = FileAccess.get_sha256(BASE+"raw/42.bin")
	other.dimensions = [4,3]
	write_manifest([other])
	check(catalog.load_catalog(BASE+"source_maps.json"), "schema can be loaded before opening raw bytes")
	check(catalog.create_navigation(42,projection) == null, "valid digest with wrong dimensions still rejected")
	check(not catalog.load_catalog(BASE+"missing.json") and catalog.map_ids().is_empty(), "missing manifest clears stale state")
	print("L1J_SOURCE_MAP_CATALOG_OK " if failures.is_empty() else "L1J_SOURCE_MAP_CATALOG_FAIL ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
