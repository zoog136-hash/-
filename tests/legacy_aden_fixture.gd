extends RefCounted
## These legacy-art/physics checks intentionally exercise the preserved
## layout-1 compatibility fixture. world_structure_test checks the active map.
static func install(world: Node) -> void:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pr84_aden_layout1.json"))
	var catalog = preload("res://scripts/monsters/monster_catalog.gd")
	catalog.ensure_loaded()
	catalog.spawn_profiles = catalog.spawn_profiles.duplicate(true)
	catalog.spawn_profiles.maps.aden_world = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pr84_aden_population.json"))
	world.maps_by_id.aden_world.erase("field_path")
	world.maps_by_id.aden_world["field_definition"] = definition
	world.maps_by_id.aden_world["width"] = int(definition.bounds[2])/32
	world.maps_by_id.aden_world["height"] = int(definition.bounds[3])/32
