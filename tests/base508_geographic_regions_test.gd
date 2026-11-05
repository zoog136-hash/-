extends SceneTree
const REGIONS = preload("res://scripts/monsters/base508_geographic_regions.gd")
class MapDouble extends RefCounted:
	var contract: Dictionary
	var rows: Array
	var occupancy: Dictionary = {}
	func geographic_contract() -> Dictionary: return contract
	func npc_territory_records() -> Array: return rows
	func register_source_npc_instance(id: String, row: Dictionary, cell: Vector2i, confirmed: Variant) -> bool:
		if not confirmed is bool or not confirmed or not REGIONS.identity(row): return false
		occupancy[id] = cell
		return true
	func unregister_npc_occupancy(id: String) -> void: occupancy.erase(id)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not FileAccess.file_exists(REGIONS.PATH):
		print("BASE508_GEOGRAPHIC_REGIONS_SKIPPED: private source-region projection required")
		quit(0);return
	var map := MapDouble.new()
	map.contract = REGIONS.data().coordinate_contract.duplicate(true)
	map.rows = REGIONS.data().rows.duplicate(true)
	for row: Dictionary in map.rows:
		row.erase("source_key")
		row.erase("territory_link_row_id")
	assert(REGIONS.regions_for_map(map).size() == 90)
	assert(REGIONS.display_position(Vector2i(32576,32832),"source_grid_anchor") == Vector2(0,3828))
	assert(REGIONS.display_position(Vector2i(32576,32832),"visual_cell_center") == Vector2(24,3840))
	assert(not REGIONS.display_position(Vector2i(32576,32832),"").is_finite())
	var key: String = str(REGIONS.data().rows[0].source_key)
	assert(not REGIONS.create_confirmed_visual(map,key,"no-confirm",Vector2i(32661,32868),false,"visual_cell_center").ok)
	assert(not REGIONS.create_confirmed_visual(map,key,"numeric",Vector2i(32661,32868),2,"visual_cell_center").ok)
	assert(map.occupancy.is_empty())
	map.contract["asset_path"] = "48962/"
	assert(REGIONS.regions_for_map(map).is_empty())
	map.contract = REGIONS.data().coordinate_contract.duplicate(true)
	map.contract.display_grid_transform.basis_x[0] = 48
	assert(REGIONS.regions_for_map(map).is_empty())
	map.contract = REGIONS.data().coordinate_contract.duplicate(true)
	map.rows[0].source_bounds[0] = int(map.rows[0].source_bounds[0])+1
	assert(REGIONS.regions_for_map(map).size() == 89)
	map.rows = REGIONS.data().rows.duplicate(true)
	var manifest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lineagem-monster-pack="): manifest = arg.trim_prefix("--lineagem-monster-pack=")
	var confirmed_test_visuals: int = 0
	if not manifest.is_empty():
		var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		for row: Dictionary in REGIONS.data().rows:
			if not pack.records.has(str(int(row.npc_class_id))): continue
			var cell := Vector2i(int(row.source_bounds[0])+1,int(row.source_bounds[1])+1)
			if not REGIONS.source_cell_supplied(cell): continue
			var visual: Dictionary = REGIONS.create_confirmed_visual(map,str(row.source_key),"mock-confirmed",cell,true,"visual_cell_center",manifest,true)
			if not visual.ok: continue
			assert(not visual.movement_enabled and not visual.original_engine_foot_anchor_verified)
			assert(map.occupancy.size() == 1)
			REGIONS.remove_visual(map,visual)
			assert(map.occupancy.is_empty())
			confirmed_test_visuals += 1
			break
		assert(confirmed_test_visuals == 1)
	print("BASE508_GEOGRAPHIC_REGIONS ",JSON.stringify({"region_contexts":90,"original_classes":15,"mock_confirmed_visuals":confirmed_test_visuals,"real_geographic_placements":0,"movement_enabled":false,"wrong_map_transform_and_unconfirmed_instances_rejected":true}))
	quit()
