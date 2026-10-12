extends SceneTree
## Explicit full private-data check; not a substitute for restored game visuals.
const CATALOG = preload("res://addons/twilight_l1j/twilight_source_map_catalog.gd")
const ATTRIBUTES = preload("res://addons/twilight_l1j/twilight_map_attributes.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var catalog = CATALOG.new()
	if not catalog.load_catalog():
		print("RECOVERED_MAP_CATALOG_FAIL: missing or invalid private catalogue")
		quit(1)
		return
	var loaded: int = 0
	var navigation_maps: int = 0
	var tested_edges: int = 0
	var empty_maps: Array[int] = []
	var unverified_maps: int = 0
	for map_id: int in catalog.map_ids():
		var row: Dictionary = catalog.record(map_id)
		var size := Vector2i(int(row.dimensions[0]),int(row.dimensions[1]))
		var path: String = catalog.raw_directory.path_join("%d.bin" % map_id)
		var attributes: TwilightL1JMapAttributes = ATTRIBUTES.new()
		if not attributes.load_a3(map_id,size,catalog.raw_directory) or FileAccess.get_sha256(path) != row.row_major_sha256:
			failures.append("raw dimensions/digest " + str(map_id))
			continue
		loaded += 1
		if row.navigation_rules != "A3_STATIC_EDGES" or row.source_origin == null:
			unverified_maps += 1
			continue
		var origin := Vector2i(int(row.source_origin[0]),int(row.source_origin[1]))
		# Explicit diagnostic projection; not a calibrated live game transform.
		var projection := Transform2D(Vector2(24,-12),Vector2(24,12),Vector2(-24*(origin.x+origin.y),12*(origin.x-origin.y)))
		var nav: TwilightL1JSourceNavigation = catalog.create_navigation(map_id,projection)
		if nav == null:
			failures.append("navigation load "+str(map_id))
			continue
		navigation_maps += 1
		for cell: Vector2i in [Vector2i.ZERO,size-Vector2i.ONE,size/2]:
			if nav.coordinates.world_to_cell(nav.coordinates.cell_to_world(cell)) != cell:
				failures.append("coordinate roundtrip "+str(map_id))
		var found: bool = false
		for index: int in range(attributes._raw.size()):
			if (int(attributes._raw[index]) & 3) == 0: continue
			var cell := Vector2i(index%size.x,index/size.x)
			for heading: int in range(8):
				if not nav.can_step(cell,heading): continue
				var goal: Vector2i = cell+nav.DIRECTIONS[heading]
				if nav.find_path(cell,goal,2) != [cell,goal]: failures.append("source edge path "+str(map_id))
				tested_edges += 1
				found = true
				break
			if found: break
		if not found: empty_maps.append(map_id)
		if nav.can_step(Vector2i.ZERO,0) or nav.can_step(size-Vector2i.ONE,4): failures.append("bounds "+str(map_id))
	var report: Dictionary = {"engine":Engine.get_version_info().string,"loaded_source_grids":loaded,
		"a3_navigation_maps":navigation_maps,"tested_source_edges":tested_edges,"empty_edge_maps":empty_maps,
		"other_revision_maps_navigation_blocked":unverified_maps,"failures":failures,"restored_game_maps":0}
	var output := FileAccess.open("res://docs/map-recovery-20261011/source-catalog-validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	output.close()
	print("RECOVERED_MAP_CATALOG_OK " if failures.is_empty() else "RECOVERED_MAP_CATALOG_FAIL ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
