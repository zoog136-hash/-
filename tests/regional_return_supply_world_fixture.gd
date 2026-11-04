extends "res://scripts/world.gd"
## Test-only supplier catalogue injection; not a production drop/shop provider.
var supply_problem: String = ""
var supply_document: Dictionary = {}
var supply_record: Dictionary = {}

func _load_data() -> void:
	super._load_data()
	var path: String = OS.get_environment("TWILIGHT_REGIONAL_SUPPLY_BIN")
	if path.is_empty() or FileAccess.get_sha256(path) != "bec901d26a7766f2c77e9781ce636f17c14e7ba1b33617840eb5a5d5123bafd3":
		supply_problem = "verified PR238 phase3 input required"
		return
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if packed.size() != 1806317:
		supply_problem = "unexpected supplier bytes"
		return
	var raw: PackedByteArray = packed.decompress_dynamic(32*1024*1024, FileAccess.COMPRESSION_GZIP)
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("source_snapshot") != "patch523":
		supply_problem = "invalid supplier snapshot"
		return
	supply_document = parsed
	supply_record = supply_document.get("item_definitions", {}).get("239", {}).get("native_record", {}).duplicate(true)
	# Normal is explicitly present on the two real source membership rows.
	supply_record["source_bless_raw"] = 1
	if REGIONAL_RETURN.stack_identity(str(supply_record.get("name", "")), supply_record).is_empty():
		supply_problem = "supplier identity mismatch"
		return
	catalog_db["아이템"].append(supply_record)
	loot_catalog.by_name[str(supply_record.name)] = supply_record
	_index_catalog_item_sources()
