extends SceneTree
## Installed private source data, separate from game-world and synthetic CI checks.
const NAV = preload("res://addons/twilight_l1j/twilight_source_navigation.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/l1j/maps/source_maps.json"))
	var count: int = 0
	var edges: int = 0
	var paths: int = 0
	for record: Dictionary in manifest.maps:
		var size := Vector2i(int(record.dimensions[0]),int(record.dimensions[1]))
		var origin := Vector2i(int(record.source_origin[0]),int(record.source_origin[1]))
		var navigation: TwilightL1JSourceNavigation = NAV.new()
		var projection := Transform2D(Vector2(64,0),Vector2(0,64),-Vector2(origin)*64)
		if not navigation.configure(int(record.map_id),size,origin,projection):
			failures.append("load map " + str(record.map_id));continue
		if FileAccess.get_sha256("res://data/l1j/maps/raw/%d.bin" % int(record.map_id)) != str(record.row_major_sha256):
			failures.append("source digest " + str(record.map_id))
		var found: bool = false
		for y: int in range(size.y):
			if found: break
			for x: int in range(size.x):
				var cell := Vector2i(x,y)
				if navigation.coordinates.world_to_cell(navigation.coordinates.cell_to_world(cell)) != cell:
					failures.append("coordinates " + str(record.map_id));break
				for heading: int in range(8):
					if navigation.can_step(cell,heading):
						edges += 1
						var route: Array[Vector2i] = navigation.find_path(cell,cell+navigation.DIRECTIONS[heading],64)
						if route.size() != 2: failures.append("path " + str(record.map_id))
						else: paths += 1
						found = true
						break
				if found: break
		if not found: failures.append("no passable edge " + str(record.map_id))
		if navigation.can_step(Vector2i.ZERO,0) or navigation.can_step(Vector2i(size.x-1,size.y-1),4):
			failures.append("bounds " + str(record.map_id))
		count += 1
	var report: Dictionary = {"loaded_maps":count,"real_source_edges":edges,"paths":paths,"failures":failures,"engine":Engine.get_version_info().string}
	var output := FileAccess.open("res://SOURCE_MAPS_GODOT.json",FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(report,"\t")+"\n")
	print("L1J_SOURCE_MAPS_OK " if failures.is_empty() else "L1J_SOURCE_MAPS_FAIL ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
