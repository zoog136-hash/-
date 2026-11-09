extends RefCounted
## C11 / P3. DESIGN_NOT_RECOVERED_API. Land row -> S32 prefix -> per-slot basename.
## Land ids, channels and territory ids are never turned into folder names.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const MAP_ASSET_TYPE := 2
const SLOT_FILE_X_BASE := 0x7F00
const SLOT_FILE_Y_BASE := 0x7E00

static func make_key(current_land_id: int, pending_land_id: int, channel_id: int, origin_half_cell: Vector2i, slot: int, prefix: String, basename: String) -> Dictionary:
	return {"record": "MapResourceKey", "design_status": VOCAB.EVIDENCE_DESIGN, "current_land_id": current_land_id,
		"pending_land_id": pending_land_id, "channel_id": channel_id, "origin_half_cell": origin_half_cell,
		"slot": slot, "prefix": prefix, "basename": basename}

## prefix = AssetType[2].Path + Land[currentLandID].AssetPath. A missing Land row gives an
## empty prefix (cleanup); no other Land and no default Map is ever substituted. An empty
## Land.AssetPath with a non-empty AssetType.Path still yields a live prefix.
static func prefix(tables: Dictionary, land_id: int) -> Dictionary:
	var land: Variant = (tables.get("Land", {}) as Dictionary).get(land_id)
	if not land is Dictionary:
		return {"status": "LAND_ROW_ABSENT", "prefix": "", "cleanup": true, "substituted_other_land": false}
	var type_row: Variant = (tables.get("AssetType", {}) as Dictionary).get(MAP_ASSET_TYPE)
	var type_path: String = str(type_row.get("Path", "")) if type_row is Dictionary else ""
	var result: String = type_path + str(land.get("AssetPath", ""))
	if result.is_empty():
		return {"status": "PREFIX_EMPTY", "prefix": "", "cleanup": true, "substituted_other_land": false}
	return {"status": "OK", "prefix": result, "cleanup": false, "substituted_other_land": false}

## Half-cell X of a source X: 2*X - 0x8000 (low32, signed).
static func half_cell_x(source_x: int) -> int:
	return VOCAB.i32(2 * source_x - 0x8000)

## Slot q file coordinates use SIGNED TRUNCATION toward zero, not floor.
@warning_ignore("integer_division")
static func slot_file_coordinates(origin_x: int, origin_y: int, slot: int) -> Vector2i:
	return Vector2i(origin_x / 128 + SLOT_FILE_X_BASE + (slot & 1), origin_y / 64 + SLOT_FILE_Y_BASE + (slot >> 1))

static func basename(file_x: int, file_y: int) -> String:
	return "%04x%04x.s32" % [file_x, file_y]

## Why a map read produced no data. Metadata failures (empty prefix) go to cleanup; an
## empty read under a normal prefix goes to the fallback tile/attribute fill. The two are
## different, and an uppercase retry is never an S32 -> SEG substitution.
static func classify_read(prefix_result: Dictionary, bytes: PackedByteArray, read_ok: bool) -> Dictionary:
	if prefix_result.get("prefix", "") == "":
		return {"status": "CLEANUP_METADATA_EMPTY", "fallback_fill": false, "seg_substitution": false}
	if not read_ok or bytes.is_empty():
		return {"status": "FALLBACK_FILL_EMPTY_READ", "fallback_fill": true, "seg_substitution": false}
	return {"status": "OK", "fallback_fill": false, "seg_substitution": false}

static func slot_cell_offsets() -> Array:
	return [0, 128, 16384, 16512]
