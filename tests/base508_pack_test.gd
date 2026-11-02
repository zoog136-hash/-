extends SceneTree
const PACK = preload("res://scripts/maps/base508_pack.gd")

func _initialize() -> void:
	var pack = PACK.new()
	assert(not pack.load_pack("/tmp/absent-base508-test-pack"))
	var path: String = OS.get_environment("TWILIGHT_BASE508_PACK")
	assert(not path.is_empty(), "Set TWILIGHT_BASE508_PACK for the real pack test")
	assert(pack.load_pack(path), pack.error)
	assert(int(pack.manifest.land.ID) == 48962)
	assert(str(pack.manifest.land.AssetPath) == "13474/")
	assert(pack.portals.size() == 4)
	var region: Dictionary = pack.portal_destination(20072)
	assert(int(region.StartX) == 32668 and int(region.EndX) == 32669)
	assert(int(region.StartY) == 32911 and int(region.EndY) == 32913)
	assert(pack.portal_destination(-1).is_empty())
	assert(pack.safe_file("../escape").is_empty())
	assert(pack.safe_file("/absolute").is_empty())
	assert(pack.safe_file("res://escape").is_empty())
	assert(pack.collision_state(Vector2i(32653, 32909)) == "UNKNOWN_TERRAIN")
	assert(not pack.can_enter(Vector2i(32653, 32909)))
	pack.confirmed_occupancy[Vector2i(32653, 32909)] = true
	assert(pack.collision_state(Vector2i(32653, 32909)) == "BLOCKED_CONFIRMED_OBJECT")
	assert(not pack.can_enter(Vector2i(32653, 32909)))
	if pack.geometry.is_empty():
		assert(pack.raw_attribute(32653*2, 32909) == -1)
	else:
		assert(pack.raw_attribute(32653*2, 32909) == 5)
		assert(pack.portal_links_at(Vector2i(32653,32909)).size() == 1)
		if not pack.npc_flags.is_empty():
			assert(pack.source_map_key() == "base508_land_48962")
			assert(pack.geographic_contract().source_cell_bounds == [32576,32832,32895,32959])
			assert(pack.npc_territory_records().size() == 95)
			assert(pack.npc_territory_records()[0].runtime_confirmed_source_cell == null)
			var record: Dictionary = {"edition":"LineageM_base508","map_key":"base508_land_48962","land_id":48962,"asset_path":"13474/","coordinate_space":"LINEAGEM_WORLD_SOURCE_CELLS_V1","npc_class_id":81782}
			assert(not pack.register_source_npc_instance("unconfirmed",record,Vector2i(32653,32909),false))
			assert(not pack.register_source_npc_instance("numeric_confirmation",record,Vector2i(32653,32909),2))
			assert(pack.register_source_npc_instance("contract_ok",record,Vector2i(32653,32909),true))
			pack.unregister_npc_occupancy("contract_ok")
			record.land_id = 13474
			assert(not pack.register_source_npc_instance("asset_is_not_land",record,Vector2i(32653,32909),true))
			record.land_id = 48962
			record.npc_class_id = 81782.5
			assert(not pack.register_source_npc_instance("fractional_class",record,Vector2i(32653,32909),true))
			assert(pack.COORDINATE_CONTRACT.geometry_equal([1.0],[1]))
			assert(not pack.COORDINATE_CONTRACT.geometry_equal([false],[0]))
			assert(pack.COORDINATE_CONTRACT.grid_anchor(pack.manifest,Vector2(32653,32909)) == Vector2(3696,3828))
			assert(pack.COORDINATE_CONTRACT.visual_cell_center(pack.manifest,Vector2(32653,32909)) == Vector2(3720,3840))
			assert(pack.register_npc_occupancy("confirmed_a", 81782, Vector2i(32653,32909)))
			assert(pack.register_npc_occupancy("confirmed_b", 81782, Vector2i(32653,32909)))
			pack.confirmed_occupancy.clear()
			pack.unregister_npc_occupancy("confirmed_a")
			assert(pack.collision_state(Vector2i(32653,32909)) == "BLOCKED_CONFIRMED_OBJECT")
			pack.unregister_npc_occupancy("confirmed_b")
			assert(pack.collision_state(Vector2i(32653,32909)) == "UNKNOWN_TERRAIN")
			pack.npc_flags[-2] = 2
			assert(not pack.register_npc_occupancy("not_boolean", -2, Vector2i(32653,32909)))
	print("BASE508_PACK_TEST_OK: exact region, isolated coordinates, unknown blocked, confirmed occupancy preserved")
	quit()
