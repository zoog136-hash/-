extends SceneTree
const COORD = preload("res://scripts/maps/source_coordinates.gd")
const FIELD = preload("res://scripts/maps/source_field.gd")
const DIRECTOR = preload("res://scripts/monsters/boss_director.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REMAKE_COORD_FAIL "+label)
func _initialize() -> void:
	for mapping: Dictionary in [{},{"basis_x":[-24,-12],"basis_y":[24,-12],"translation":[900,5000]},
			{"basis_x":[48,24],"basis_y":[-48,24],"translation":[16000,0]}]:
		for origin: Array in [[32704,32704],[32576,32768],[32448,32064]]:
			var coord = COORD.new()
			check(coord.configure(origin,[2048,1536],mapping),"explicit mapping accepted")
			for cell: Vector2i in [Vector2i.ZERO,Vector2i(191,191),Vector2i(2047,1535)]:
				var world: Vector2 = coord.cell_to_world(cell)
				check(coord.world_to_cell(world)==cell,"cell center roundtrip across origins/flips/scales")
				check(coord.components_to_world(coord.source_components(world)).distance_to(world)<0.01,"persisted scalar coordinates")
				check(coord.canvas_bounds().has_point(world),"mapped canvas bounds")
			for fractional: Array in [[1.9995,2.5],[1.0005,1.5],[191.5,191.5]]:
				var p: Vector2 = coord.components_to_world([origin[0]+fractional[0],origin[1]+fractional[1]])
				check(coord.world_to_cell(p)==Vector2i(floori(fractional[0]),floori(fractional[1])),"boundary precision")
	var bad = COORD.new()
	check(not bad.configure([0,0],[0,2]),"zero dimensions rejected")
	check(not bad.configure([0,0],[2,2],{"basis_x":[1,1],"basis_y":[2,2]}),"singular calibration rejected")
	check(not bad.configure([NAN,0],[2,2]),"nonfinite origin rejected")
	check(not bad.configure([0,0],[2,2],{"basis_x":"broken"}),"malformed calibration rejected without a type error")
	check(bad.world_to_cell(Vector2.ZERO)==Vector2i(-1,-1),"invalid mapping cannot reuse old transform")
	var director = DIRECTOR.new()
	var cooldown: float = Time.get_unix_time_from_system()+12000
	var original := {"version":2,"bosses":{"oman_01:queen":{"phase":"cooldown","hp":1777,"ready_at":cooldown,"position":[600,800],"home":[600,800]}}}
	director.import_state(original)
	var state: Dictionary = director.state_for("oman_01",{"id":"boss","boss_id":"queen","layout_revision":2026101501})
	check(state.phase=="cooldown" and state.hp==1777 and state.ready_at==cooldown,"layout migration preserves boss life and deadline")
	check(state.position.is_empty() and state.home.is_empty(),"unmapped boss pixels discarded")
	director.import_state(director.export_state())
	check(director.states["oman_01:queen"].layout_revision==2026101501,"layout stamp persists")
	var writer = preload("res://scripts/skills/save_writer.gd")
	var path: String = "user://remake-coordinate-roundtrip.json"
	check(writer.write(path,{"boss":director.export_state(),"fractional_source":[32704.125013,32801.875017]})==OK,"atomic save write")
	var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(restored.boss.bosses["oman_01:queen"].ready_at==cooldown,"Unix deadline keeps full precision through JSON")
	check(restored.fractional_source==[32704.125013,32801.875017],"fractional source keeps full precision through JSON")
	DirAccess.remove_absolute(path)
	print("REMAKE_COORD_STATE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
