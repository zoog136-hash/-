extends "res://tests/original_client_test_base.gd"
## C11 - C14 acceptance tests.
const MAP = preload("res://scripts/original_client/map_path.gd")
const S32 = preload("res://scripts/original_client/s32_chunk.gd")
const COLLISION = preload("res://scripts/original_client/terrain_collision.gd")
const INPUT = preload("res://scripts/original_client/input_projection.gd")
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

func put_u16(bytes: PackedByteArray, p: int, v: int) -> void:
	bytes[p] = v & 0xFF
	bytes[p + 1] = (v >> 8) & 0xFF

func put_u32(bytes: PackedByteArray, p: int, v: int) -> void:
	put_u16(bytes, p, v & 0xFFFF)
	put_u16(bytes, p + 2, (v >> 16) & 0xFFFF)

## A synthetic chunk: floors, 0 covers, attributes, then the given tail bytes.
func synthetic_chunk(floor_values: Dictionary, attribute_values: Dictionary, extra: PackedByteArray) -> PackedByteArray:
	var size: int = 8192 * 4 + 2 + 8192 * 2
	var bytes := PackedByteArray()
	bytes.resize(size)
	for i: int in 8192:
		put_u32(bytes, i * 4, int(floor_values.get(i, 0x00000102)))
	put_u16(bytes, 8192 * 4, 0)
	for i: int in attribute_values:
		put_u16(bytes, 8192 * 4 + 2 + int(i) * 2, int(attribute_values[i]))
	bytes.append_array(extra)
	return bytes

func run() -> void:
	run_c11()
	run_c12()
	run_c13()
	run_c14()
	finish("ORIGINAL_CLIENT_P3_RESULT")

func run_c11() -> void:
	var tables := {"AssetType": {2: {"ID": 2, "Path": "Map/"}}, "Land": {5: {"ID": 5, "AssetPath": "13158/"}, 6: {"ID": 6, "AssetPath": ""}}}
	var none: Dictionary = MAP.prefix(tables, 99)
	check("C11-T01", none.prefix == "" and none.cleanup == true and none.substituted_other_land == false, "missing Land row -> empty prefix and cleanup")
	var empty_asset_path: Dictionary = MAP.prefix(tables, 6)
	check("C11-T02", empty_asset_path.prefix == "Map/" and empty_asset_path.status == "OK", "empty Land.AssetPath with AssetType.Path 'Map/' keeps a live prefix")
	check("C11-T02", MAP.prefix(tables, 5).prefix == "Map/13158/", "prefix = AssetType[2].Path + Land.AssetPath")
	check("C11-T02", MAP.basename(0x7F00, 0x7E00) == "7f007e00.s32" and MAP.basename(1, 2) == "00010002.s32", "basename is lowercase hex, minimum width 4")
	check("C11-T02", MAP.slot_file_coordinates(0, 0, 3) == Vector2i(0x7F01, 0x7E01) and MAP.slot_file_coordinates(128, 64, 0) == Vector2i(0x7F01, 0x7E01), "slot file coordinates")
	var half: int = MAP.half_cell_x(16383)
	check("C11-T03", half == -2, "source X 16383 -> half-cell -2")
	check("C11-T03", MAP.slot_file_coordinates(half, 0, 0).x == 0x7F00, "signed truncation gives 0x7F00, not the floor value 0x7EFF")
	check("C11-T03", int(floor(float(half) / 128.0)) + 0x7F00 == 0x7EFF, "the floor shortcut would differ, so it must not be used")
	check("C11-T03", MAP.slot_cell_offsets() == [0, 128, 16384, 16512], "slot cell offsets")
	check("C11-T01", MAP.classify_read(none, PackedByteArray(), false).status == "CLEANUP_METADATA_EMPTY", "empty prefix is cleanup")
	var normal: Dictionary = MAP.prefix(tables, 5)
	var fill: Dictionary = MAP.classify_read(normal, PackedByteArray(), true)
	check("C11-T01", fill.status == "FALLBACK_FILL_EMPTY_READ" and fill.fallback_fill == true and fill.seg_substitution == false, "empty read under a normal prefix is a fallback fill, not cleanup and not SEG")

func run_c12() -> void:
	var tail_empty := PackedByteArray([0x00, 0x80])
	var chunk_bytes: PackedByteArray = synthetic_chunk({5: 0xFFFFFFFF}, {5: 0}, tail_empty)
	var chunk: Dictionary = S32.read_prefix(chunk_bytes)
	check("C12-T01", chunk.ok and chunk.offsets.end == 8192 * 4 + 2 + 8192 * 2, "prefix offsets are preserved")
	var cell: Dictionary = S32.cell(chunk, 5)
	check("C12-T01", cell.fallback_floor == true and cell.replacement_value == 0x8CBB + 1 and cell.attribute == 0, "sentinel floor -> fallback floor, final attribute is 0")
	check("C12-T01", cell.attribute_overrides_sentinel == true, "the sentinel never proves a blocked cell")
	var normal_cell: Dictionary = S32.cell(chunk, 0)
	check("C12-T01", normal_cell.tile_id == 1 and normal_cell.block == 2 and normal_cell.tile_member == "Tile/1.ti2", "packed tile: upper 24 bits are the id, low 8 the block")
	var tail: Dictionary = S32.read_tail(chunk_bytes, chunk.remaining_offset)
	check("C12-T02", tail.ok and tail.extended == true and tail.count == 0 and tail.records.is_empty(), "tail W=0x8000 is the extended form with count 0")
	check("C12-T02", tail.clears_existing_tail == false and S32.read_tail(chunk_bytes, chunk_bytes.size()).clears_existing_tail == false, "an empty tail does not clear an earlier tail")
	var record := PackedByteArray()
	record.resize(2 + 6 + 8)
	put_u16(record, 0, 1)
	put_u16(record, 2, 16400)
	put_u16(record, 4, 77)
	put_u16(record, 6, 0xFFFE)
	for i: int in 8:
		record[8 + i] = 0xA0 + i
	var with_tail: PackedByteArray = synthetic_chunk({}, {}, record)
	var parsed: Dictionary = S32.read_tail(with_tail, 8192 * 4 + 2 + 8192 * 2)
	check("C12-T03", parsed.ok and parsed.count == 1 and parsed.records[0].x == 2 * 16400 - 32768 and parsed.records[0].y == 77 and parsed.records[0].sprite_id == -2, "tail record: x = 2X-32768, signed sprite id")
	check("C12-T03", (parsed.trailing_bytes as PackedByteArray).size() == 8 and parsed.trailing_bytes[0] == 0xA0, "8 bytes after the tail are preserved as opaque trailing bytes")
	check("C12-T03", not parsed.records[0].has("portal") and not parsed.records[0].has("date"), "no portal or date field is invented")
	var negative := PackedByteArray([0xFF, 0xFF, 0xFF, 0xFF])
	check("C12-T04", S32.read_groups(negative, 0).status == "NEGATIVE_COUNT", "negative group count is a safety error")
	var cut := PackedByteArray([1, 0, 0, 0, 9, 0, 3, 0, 1, 2, 3])
	check("C12-T04", S32.read_groups(cut, 0).status == "TRUNCATED", "a cut-off group record is a safety error")
	var good := PackedByteArray([1, 0, 0, 0, 9, 0, 1, 0, 1, 2, 3, 4, 5, 6, 7])
	var groups: Dictionary = S32.read_groups(good, 0)
	check("C12-T04", groups.ok and groups.groups[0].id == 9 and groups.groups[0].part_count == 1 and groups.end_offset == 15, "a well-formed group section parses")
	check("C12-T04", S32.read_prefix(PackedByteArray([1, 2, 3])).status == "TRUNCATED", "a cut-off prefix is a safety error")

func run_c13() -> void:
	check("C13-T01", COLLISION.direction_step(Vector2i(100, 20), 1) == Vector2i(102, 19), "direction 1 from (100,20) is (102,19)")
	check("C13-T01", COLLISION.direction_step(Vector2i(0, 0), 7) == Vector2i(-2, -1) and COLLISION.direction_step(Vector2i(0, 0), 0) == Vector2i(0, -1), "other half-cell deltas")
	var attrs: Array = []
	attrs.resize(32768)
	attrs.fill(0)
	var origin := Vector2i(0, 0)
	attrs[COLLISION.base_index(Vector2i(10, 10), origin)] = 1
	check("C13-T02", COLLISION.reject_attr(1, false) == true and COLLISION.reject_attr(0, false) == false, "attribute 1 is blocked and 0 is passable")
	check("C13-T02", COLLISION.check_step(attrs, Vector2i(10, 9), origin, 4, false).reject == true, "even direction reads one cell and a blocked cell rejects")
	check("C13-T03", COLLISION.plan_path(Vector2i(4, 4), Vector2i(4, 4), attrs, origin, false) == {"status": "OK", "points": [], "design_pathfinder": true}, "start == target succeeds with an empty path")
	var path: Dictionary = COLLISION.plan_path(Vector2i(0, 0), Vector2i(2, 0), attrs, origin, false)
	check("C13-T03", path.status == "OK" and path.points.size() == 2, "a one-step path has two points")
	check("C13-T04", COLLISION.reject_attr(0x41, false) == true and COLLISION.reject_attr(0x41, true) == false, "0x41 rejects only without allow40")
	check("C13-T04", COLLISION.reject_attr(0x02, false) == false and COLLISION.reject_attr(0x40, false) == false, "bit 1 and bit 6 alone never reject")
	check("C13-T05", COLLISION.odd_direction_pair([true, false, false, false]) == false and COLLISION.odd_direction_pair([true, false, true, false]) == true, "odd pair rule")
	check("C13-T05", COLLISION.odd_direction_pair([false, false, true, true]) == false and COLLISION.odd_direction_pair([true, true, true, true]) == true, "pair rule is not 'any' and not 'all'")
	check("C13-T05", COLLISION.cell_indices(Vector2i(5, 5), Vector2i(0, 0), 1) == [1285, 1030, 1286, 1287], "odd direction cell indices use A0..A3")
	check("C13-T05", COLLISION.attribute_at(attrs, -1) == 1 and COLLISION.attribute_at(attrs, 40000) == 1, "indices outside the array read as attribute 1")

func run_c14() -> void:
	var low: Dictionary = INPUT.input_point(-0.75, -0.75, 1200.0, 675.0)
	check("C14-T01", low.view_i32 == Vector2i(0, 0) and low.gate_passed == true, "(-0.75,-0.75) truncates to (0,0) and passes the gate")
	var high: Dictionary = INPUT.input_point(1200.75, 675.75, 1200.0, 675.0)
	check("C14-T02", high.view_i32 == Vector2i(1200, 675) and high.gate_passed == true, "(1200.75,675.75) truncates to (1200,675) and passes")
	check("C14-T02", INPUT.input_point(1201.0, 10.0, 1200.0, 675.0).gate_passed == false and INPUT.input_point(10.0, -1.0, 1200.0, 675.0).gate_passed == false, "outside the integer range fails the gate")
	check("C14-T02", high.normalized_i32 == Vector2i(800, 450) and high.handler_i32 == Vector2i(832, 462), "normalised then container-corrected")
	var origin := Vector2i(32768, 32768)
	check("C14-T03", INPUT.screen_to_world(Vector2i(400, 300), origin) == Vector2i(32758, 32791), "reverse projection (independent calculation)")
	check("C14-T03", INPUT.screen_to_world(Vector2i(0, 0), origin) == Vector2i(32766, 32771) and INPUT.screen_to_world(Vector2i(1200, 675), origin) == Vector2i(32760, 32824), "more reverse projection values")
	check("C14-T03", INPUT.world_to_screen(Vector2i(32770, 32770), origin) == Vector2i(48, 12) and INPUT.world_to_screen(Vector2i(32769, 32768), origin) == Vector2i(0, 0) and INPUT.world_to_screen(origin, origin) == Vector2i(-24, 0), "forward projection values")
	var points: Array = []
	var p := Vector2i(0, 0)
	points.append(p)
	for i: int in 100:
		p = COLLISION.direction_step(p, 2)
		points.append(p)
	var request: Dictionary = INPUT.directions_from_path(points)
	check("C14-T03", points.size() == 101 and request.directions.size() == 50 and request.truncated_to_50 == true and request.target_field_added == false, "101 points give only 50 directions and no target field")
	check("C14-T03", INPUT.directions_from_path([Vector2i(0, 0)]).status == "TOO_SHORT" and INPUT.directions_from_path([Vector2i(0, 0), Vector2i(5, 5)]).status == "NON_ADJACENT_STEP", "short and non-adjacent paths are refused")
	check("C14-T03", INPUT.directions_from_path([Vector2i(0, 0), Vector2i(2, -1)]).directions == [1], "a single step becomes one direction")
