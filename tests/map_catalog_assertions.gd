extends RefCounted
## Historical IDs remain mandatory. Independently registered PNG regions extend
## the catalog; source-pack l1_ regions remain a separately verified namespace.
static func checks(world: TwilightWorld) -> Array[Dictionary]:
	var results: Array[Dictionary]=[]
	var expected: Dictionary={}
	var historical: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json"))
	for row: Dictionary in historical:
		var mid: String=str(row.id)
		expected[mid]=true
		results.append({"ok":world.maps_by_id.has(mid),"label":"historical persistent map ID retained: "+mid})
	for row: Dictionary in preload("res://scripts/maps/native_png_registry.gd").catalog_entries():
		var mid: String=str(row.id)
		results.append({"ok":mid in ["escaros_world","yahee_temple","balrog_temple"] and not expected.has(mid),"label":"independent native region has a distinct ID: "+mid})
		expected[mid]=true
		results.append({"ok":world.maps_by_id.has(mid),"label":"installed native region registered: "+mid})
	var seen: Dictionary={}
	for row: Dictionary in world.maps:
		var mid: String=str(row.get("id",row.get("map_id","")))
		results.append({"ok":not seen.has(mid),"label":"unique persistent catalog entry: "+mid})
		seen[mid]=true
		if mid.begins_with("l1_"): continue
		results.append({"ok":expected.has(mid),"label":"catalog contains no unexplained replacement/addition: "+mid})
	for mid: String in expected:
		results.append({"ok":seen.has(mid),"label":"map list retains registered ID: "+mid})
	return results
