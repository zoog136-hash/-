class_name Source523ImagePack
extends RefCounted
## Explicit private pack. Exact original bytes only; no install/save/activation.

const ORIGINAL_ASSETS = preload("res://scripts/original_client/asset_resolver.gd")
const IMAGE_TYPES: Array[int] = [1, 3, 5, 6, 7, 9, 10, 11, 82, 143, 161]
const CONSUMER_FIELDS: Dictionary = {"ItemClass":["IconID"], "SpellClass":["IconID","ActivateIconID"], "BuffClass":["OnIconID","OffIconID"]}
const TABLE_KEYS: Dictionary = {"AssetView":"AssetId", "AssetType":"ID", "Icon":"ID", "ItemClass":"ID", "SpellClass":"ID", "BuffClass":"ID"}
const DUMMY_IMAGE_TABLE: String = "UIBuffCardDummyImagePath"
## Members may come from the earlier handoff components or, for a pack built
## from the complete client (tools/images/client523_image_inputs.py), from
## containers identified by the 523 files_info SHA-1/size.
var _root: String = ""
var _manifest_sha: String = ""
var _manifest: Dictionary = {}
var _members: Dictionary = {}
var _assets: Dictionary = {}
var _icons: Dictionary = {}
var _consumers: Dictionary = {}
var _source_tables: Dictionary = {}
# NEW PROPOSED CODE: bounded per-pack texture residency; not Android recovery.
const TEXTURE_CACHE = preload("res://scripts/resources/source523_texture_cache.gd")
var _texture_cache = TEXTURE_CACHE.new()
var _dummy_assets: Dictionary = {}
var _dummy_paths: Dictionary = {}
var _dummy_source: Dictionary = {}
## After the first verified open the checked metadata lives in a device-local
## record bake (user://, keyed by the manifest pin and this script) and is read
## one record at a time; the parsed manifest and source tables (about 800 MB)
## are not kept. The bake is never a substitute for the pack: the manifest pin
## is checked before it is used and every image file is still hash-checked.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME := "source523_image_pack"
var _records: RefCounted
## Open while the first verification runs: the big consumer tables are read
## one at a time and their rows go straight to storage instead of staying in
## memory together.
var _writer: RefCounted
## Tests compare the record bake with the in-memory metadata.
static var bake_enabled: bool = true
var _member_count: int = 0
var _manifest_stamp: String = ""

static func _failure(status: String, message: String, provenance: Dictionary = {}) -> Dictionary:
	return {"ok":false, "status":status, "status_type":status, "error":message, "texture":null, "provenance":provenance}

static func _safe_relative(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains(":") or path.contains("\\"): return false
	for part: String in path.split("/",true):
		if part.is_empty() or part == "." or part == "..": return false
	for index: int in path.length():
		if path.unicode_at(index) < 32: return false
	return true

static func _sha_valid(value: String) -> bool:
	if value.length() != 64: return false
	for index: int in value.length():
		if not value.substr(index,1) in "0123456789abcdef": return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func _canonical_row_sha(row: Dictionary) -> String:
	# These exact source523 class tables contain flat int/bool/string values.
	# Godot JSON parses integers as floats; restore integers before serializing.
	var normalized: Dictionary = {}
	for key: String in row:
		var value: Variant = row[key]
		if value is bool or value is String:
			normalized[key] = value
		elif _integer(value) and absf(float(value)) <= 9007199254740991.0:
			normalized[key] = int(value)
		else:
			return ""
	return JSON.stringify(normalized,"",true).sha256_text()

static func open(root: String, expected_manifest_sha256: String) -> Dictionary:
	if not _sha_valid(expected_manifest_sha256): return _failure("invalid_manifest_pin","An exact manifest SHA-256 is required.")
	var absolute: String = ProjectSettings.globalize_path(root)
	if not absolute.is_absolute_path() or root.begins_with("res://") or absolute.contains("\\"):
		return _failure("unsafe_pack_root","Select an explicit private pack root.")
	var reader: Variant = (load("res://scripts/resources/source523_image_pack.gd") as Script).new()
	reader._root = absolute.simplify_path()
	reader._manifest_sha = expected_manifest_sha256
	if not (bake_enabled and reader._open_baked()):
		var key: String = reader._bake_key() if bake_enabled else ""
		reader._writer = BAKE.record_writer(BAKE_NAME, key) if not key.is_empty() else null
		var result: Dictionary = reader._open_verified()
		if not result.ok:
			if reader._writer != null: reader._writer.abort()
			reader._writer = null
			return result
		reader._member_count = reader._members.size()
		if reader._writer != null: reader._bake()
	return {"ok":true, "status":"verified_pack_open", "pack":reader,
		"metadata":reader.metadata(), "metrics":reader._manifest.metrics.duplicate(true),
		"actual_game_consumption_observed":false}

func _bytes(spec: Dictionary) -> Dictionary:
	var member: String = str(spec.get("path",""))
	if not _safe_relative(member) or not _sha_valid(str(spec.get("sha256",""))) or not _integer(spec.get("bytes")) or int(spec.bytes) <= 0:
		return _failure("invalid_file_contract","Invalid private file contract.")
	var directory: String = _root
	for part: String in member.split("/"):
		var access := DirAccess.open(directory)
		if access == null or access.is_link(part): return _failure("unsafe_pack_path","Missing directory or symlink in pack path.")
		directory = directory.path_join(part)
	var file := FileAccess.open(_root.path_join(member),FileAccess.READ)
	if file == null or file.get_length() != int(spec.bytes): return _failure("file_bytes_mismatch","Private file missing or byte length changed.")
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	if hash.finish().hex_encode() != spec.sha256: return _failure("file_sha_mismatch","Private file SHA-256 changed.")
	return {"ok":true, "bytes":bytes}

func _json(spec: Dictionary) -> Dictionary:
	var checked: Dictionary = _bytes(spec)
	if not checked.ok: return checked
	var bytes: PackedByteArray = checked.bytes
	var text: String = bytes.get_string_from_utf8().trim_prefix(String.chr(0xfeff))
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null: return _failure("invalid_json","Private metadata JSON cannot be parsed.")
	return {"ok":true,"value":parsed}

## The pinned manifest is hashed once; afterwards it is hashed again only
## when its size or modification time changes.
func _manifest_intact() -> bool:
	var path: String = _root.path_join("manifest.json")
	if not FileAccess.file_exists(path): return false
	var stamp: String = "%d:%d" % [FileAccess.get_modified_time(path), FileAccess.get_size(path)]
	if not _manifest_stamp.is_empty() and stamp == _manifest_stamp: return true
	_manifest_stamp = ""
	if FileAccess.get_sha256(path) != _manifest_sha: return false
	_manifest_stamp = stamp
	return true

func _bake_key() -> String:
	return bake_key_for(_manifest_sha)

static func bake_key_for(manifest_sha: String) -> String:
	return BAKE.key(["source523_image_pack.v1", manifest_sha, BAKE.code_key(["res://scripts/resources/source523_image_pack.gd"])])

## True when this device already holds the verified metadata for this pin.
static func baked(manifest_sha: String) -> bool:
	return BAKE.present(BAKE_NAME, bake_key_for(manifest_sha))

func _open_baked() -> bool:
	var key: String = _bake_key()
	if key.is_empty() or not _manifest_intact(): return false
	var records: RefCounted = BAKE.open_records(BAKE_NAME, key)
	if records == null: return false
	var meta: Variant = records.read("meta")
	if not meta is Dictionary or meta.get("manifest_sha256") != _manifest_sha or not meta.get("manifest") is Dictionary or not meta.manifest.get("metrics") is Dictionary or not meta.manifest.get("source_tables") is Dictionary: return false
	_manifest = meta.manifest
	_dummy_assets = meta.get("dummy_assets", {})
	_dummy_paths = meta.get("dummy_paths", {})
	_dummy_source = meta.get("dummy_source", {})
	_member_count = int(meta.get("member_count", 0))
	_records = records
	return true

## Writes the verified metadata as records and drops the in-memory copies.
## When the device cannot store it, the in-memory copies stay in use.
func _bake() -> void:
	var key: String = _bake_key()
	var writer: RefCounted = _writer
	_writer = null
	var slim: Dictionary = _manifest.duplicate()
	for field: String in ["members","assets","icons","consumers"]: slim.erase(field)
	writer.add("meta", {"manifest_sha256":_manifest_sha,"manifest":slim,"dummy_assets":_dummy_assets,"dummy_paths":_dummy_paths,"dummy_source":_dummy_source,"member_count":_members.size()})
	var by_path: Dictionary = {}
	for id: int in _assets:
		writer.add("a:%d" % id, _assets[id])
		var path: String = str(_assets[id].get("path",""))
		if not by_path.has(path): by_path[path] = PackedInt64Array()
		by_path[path].append(id)
	for path: String in by_path: writer.add("p:" + path, by_path[path])
	for id: int in _icons: writer.add("i:%d" % id, _icons[id])
	for table: String in _consumers:
		for id: int in _consumers[table]:
			var item: Dictionary = _consumers[table][id]
			writer.add("c:%s:%d" % [table, id], item)
	for path: String in _members: writer.add("m:" + path, _members[path])
	if not BAKE.finish_records(writer): return
	var records: RefCounted = BAKE.open_records(BAKE_NAME, key)
	if records == null: return
	_records = records
	_manifest = slim
	_members = {}; _assets = {}; _icons = {}; _consumers = {}; _source_tables = {}

func _has_asset(id: int) -> bool:
	return _records.has("a:%d" % id) if _records != null else _assets.has(id)
func _asset(id: int) -> Dictionary:
	return _records.read("a:%d" % id) if _records != null else _assets[id]
func _has_icon(id: int) -> bool:
	return _records.has("i:%d" % id) if _records != null else _icons.has(id)
func _icon(id: int) -> Dictionary:
	return _records.read("i:%d" % id) if _records != null else _icons[id]
func _has_consumer(table: String, id: int) -> bool:
	return _records.has("c:%s:%d" % [table, id]) if _records != null else _consumers.get(table,{}).has(id)
func _consumer(table: String, id: int) -> Dictionary:
	return _records.read("c:%s:%d" % [table, id]) if _records != null else _consumers[table][id]
func _has_member(path: String) -> bool:
	return _records.has("m:" + path) if _records != null else _members.has(path)
func _member(path: String) -> Dictionary:
	return _records.read("m:" + path) if _records != null else _members[path]
func _source_row(table: String, index: int) -> Dictionary:
	return _records.read("r:%s:%d" % [table, index]) if _records != null else _source_tables[table][index]

func _open_verified() -> Dictionary:
	if not _manifest_intact(): return _failure("manifest_sha_mismatch","Manifest missing or SHA-256 differs from the explicit pin.")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_root.path_join("manifest.json")))
	if not parsed is Dictionary: return _failure("invalid_manifest","Invalid pack manifest.")
	_manifest = parsed
	if _manifest.get("schema") != 1 or _manifest.get("kind") != "source523-exact-original-image-pack" or _manifest.get("source_version") != 523 or _manifest.get("source_snapshot") != "patch523" or _manifest.get("image_pixels") != "unchanged_original_file_bytes":
		return _failure("wrong_source_identity","Pack source/version/original-byte contract differs.")
	for field: String in ["source_index","source_tables","decoder_summary","decoder_catalog","metrics","consumers"]:
		if not _manifest.get(field) is Dictionary: return _failure("invalid_manifest","Missing manifest dictionary: " + field)
	for field: String in ["members","assets","icons"]:
		if not _manifest.get(field) is Array: return _failure("invalid_manifest","Missing manifest array: " + field)
	var source: Dictionary = _json(_manifest.source_index)
	if not source.ok: return source
	if not source.value is Array: return _failure("invalid_source_index","Source index is not an array.")
	for table: String in TABLE_KEYS:
		var spec: Variant = _manifest.source_tables.get(table)
		if not spec is Dictionary or spec.get("version") != 523: return _failure("source_table_contract","Missing current source table: " + table)
		var matches: Array = []
		for entry: Variant in source.value:
			if entry is Dictionary and entry.get("path") == "content/" + table + ".json": matches.append(entry)
		if matches.size() != 1: return _failure("source_table_contract","Missing or duplicate source index table.")
		var entry: Dictionary = matches[0]
		if entry.get("version") != 523 or entry.get("status") != "strict_json_pass" or entry.get("member_crc_verified") != true or entry.get("sha256") != spec.sha256 or entry.get("bytes") != spec.bytes or entry.get("row_count") != spec.get("row_count"):
			return _failure("source_table_contract","Source index fingerprint differs: " + table)
		if CONSUMER_FIELDS.has(table): continue
		var loaded: Dictionary = _load_table(table)
		if not loaded.ok: return loaded
	var decoder_summary: Dictionary = _json(_manifest.decoder_summary)
	if not decoder_summary.ok: return decoder_summary
	var catalog: Dictionary = _bytes(_manifest.decoder_catalog)
	if not catalog.ok: return catalog
	if not decoder_summary.value is Dictionary or decoder_summary.value.get("strict_failure_count") != 0 or decoder_summary.value.get("catalog_sha256") != _manifest.decoder_catalog.sha256 or decoder_summary.value.get("catalog_bytes") != _manifest.decoder_catalog.bytes:
		return _failure("decoder_contract","Decoder summary/catalog identity differs.")
	var catalog_members: Dictionary = {}
	var catalog_bytes: PackedByteArray = catalog.bytes
	for line: String in catalog_bytes.get_string_from_utf8().split("\n",false):
		var record: Variant = JSON.parse_string(line)
		if not record is Dictionary or not _safe_relative(str(record.get("path",""))) or catalog_members.has(record.path): return _failure("decoder_contract","Invalid/duplicate verified decoder member.")
		catalog_members[record.path] = record
	if catalog_members.size() != int(decoder_summary.value.get("verified_original_members",-1)) or _manifest.metrics.get("actual_game_consumption_observed") != 0:
		return _failure("decoder_contract","Catalog count or load/use accounting differs.")
	var complete: bool = decoder_summary.value.get("source_current_catalog_complete",false) == true
	if _manifest.metrics.get("source_current_catalog_complete",false) != complete: return _failure("decoder_contract","Full current catalog status differs.")
	if complete:
		var checks: Variant = decoder_summary.value.get("source_current_catalog_completion_checks")
		var denominator: Variant = _manifest.metrics.get("whole_current_source_denominator")
		if not checks is Dictionary or checks.is_empty() or not denominator is Dictionary or denominator.get("files") != catalog_members.size(): return _failure("decoder_contract","Full current denominator proof missing.")
		for check: Variant in checks.values():
			if check != true: return _failure("decoder_contract","Full current catalog check is incomplete.")
	elif _manifest.metrics.get("whole_current_source_denominator") != null:
		return _failure("decoder_contract","Partial catalog cannot claim a whole current denominator.")
	var folded: Dictionary = {}
	for record: Variant in _manifest.members:
		if not record is Dictionary or not _safe_relative(str(record.get("path",""))) or not _safe_relative(str(record.get("file",""))): return _failure("invalid_member","Unsafe original member.")
		var path: String = str(record.path)
		if _members.has(path) or folded.has(path.to_lower()): return _failure("duplicate_member_path","Ambiguous original member path.")
		folded[path.to_lower()] = true
		if not catalog_members.has(path): return _failure("member_catalog_mismatch","Original member absent from pinned decoder catalog.")
		var raw: Dictionary = catalog_members[path]
		if record.size() != raw.size() or record.file != "originals/" + path: return _failure("member_catalog_mismatch","Original member identity fields are incomplete.")
		for field: String in raw:
			if field != "relative_output_path" and (not record.has(field) or record[field] != raw[field]): return _failure("member_catalog_mismatch","Original member field differs from decoder catalog.")
		if record.get("original_bytes_preserved") != true or record.get("pillow_verify_and_load") != true or not record.get("format") in ["PNG","JPEG","BMP"] or not record.get("current523_component") in ["retained_noncard_lineage14964","changed4_current523","client523_files_info_verified"]:
			return _failure("invalid_member_proof","Original member verification proof missing.")
		_members[path] = record
	catalog_members = {}
	folded = {}
	if _manifest.metrics.get("pack_members") != _members.size(): return _failure("member_catalog_mismatch","Pack member count differs.")
	var types: Dictionary = {}
	var type_indexes: Dictionary = {}
	for index: int in _source_tables.AssetType.size():
		var row: Dictionary = _source_tables.AssetType[index]
		types[int(row.ID)] = row
		type_indexes[int(row.ID)] = index
	if _manifest.assets.size() != _source_tables.AssetView.size(): return _failure("asset_contract","Asset count differs from exact source.")
	for index: int in _manifest.assets.size():
		var asset: Variant = _manifest.assets[index]
		var row: Dictionary = _source_tables.AssetView[index]
		if not asset is Dictionary or not types.has(int(row.get("AssetTypeId",-1))): return _failure("asset_contract","Missing exact AssetType.")
		var typed: Dictionary = types[int(row.AssetTypeId)]
		var path: String = ORIGINAL_ASSETS.join_path(str(typed.Path), str(row.FilePath))
		if asset.get("asset_id") != row.AssetId or asset.get("asset_type_id") != row.AssetTypeId or asset.get("path") != path or int(asset.get("asset_view_row_index_zero",-1)) != index or asset.get("asset_type_row_index_zero") != type_indexes[int(row.AssetTypeId)]:
			return _failure("asset_contract","Literal AssetType.Path + AssetView.FilePath identity differs.")
		if int(row.AssetId) != 0 and not str(row.FilePath).is_empty() and not _safe_relative(path): return _failure("asset_contract","Unsafe literal asset path.")
		var expected_status: String = "zero_sentinel" if int(row.AssetId) == 0 or str(row.FilePath).is_empty() else "unsupported_csb" if int(row.AssetTypeId) == 101 else "unsupported_asset_type" if not int(row.AssetTypeId) in IMAGE_TYPES else "verified_original" if _members.has(path) else "missing_current_member"
		if asset.get("status") != expected_status: return _failure("asset_contract","Asset status differs from verified members.")
		_assets[int(row.AssetId)] = asset
	if _manifest.icons.size() != _source_tables.Icon.size(): return _failure("icon_contract","Icon count differs from source.")
	for index: int in _manifest.icons.size():
		var icon: Dictionary = _manifest.icons[index]
		var row: Dictionary = _source_tables.Icon[index]
		if icon.get("id") != row.ID or icon.get("asset_id") != row.AssetID or icon.get("row_index_zero") != index: return _failure("icon_contract","Icon source chain differs.")
		_icons[int(row.ID)] = icon
	for table: String in CONSUMER_FIELDS:
		var records: Variant = _manifest.consumers.get(table)
		if not records is Array or records.size() != int(_manifest.source_tables[table].row_count): return _failure("consumer_contract","Consumer row count differs.")
		_consumers[table] = {}
		if _writer != null:
			var streamed: Dictionary = _stream_consumer_table(table, records)
			if streamed.ok: continue
			if not streamed.get("unstreamable", false): return streamed
		var table_loaded: Dictionary = _load_table(table)
		if not table_loaded.ok: return table_loaded
		for index: int in records.size():
			var problem: Dictionary = _consumer_row(table, index, _source_tables[table][index], records[index])
			if not problem.ok: return problem
		if _writer != null:
			for index: int in records.size(): _writer.add("r:%s:%d" % [table, index], _source_tables[table][index])
			_source_tables.erase(table)
	return _load_dummy_declarations(source.value)

## Checks one consumer record against its exact source row and registers it.
func _consumer_row(table: String, index: int, row: Dictionary, item: Variant) -> Dictionary:
	if not item is Dictionary or item.get("id") != row.get("ID") or item.get("row_index_zero") != index or not _sha_valid(str(item.get("source_row_canonical_sha256",""))) or not item.get("roles") is Dictionary or item.roles.size() != CONSUMER_FIELDS[table].size(): return _failure("consumer_contract","Consumer source row differs.")
	if _canonical_row_sha(row) != item.source_row_canonical_sha256: return _failure("consumer_contract","Consumer source row SHA differs.")
	for field: String in CONSUMER_FIELDS[table]:
		if item.roles.get(field) != row.get(field) or not _integer(item.roles.get(field)): return _failure("consumer_contract","Consumer role differs from exact source.")
	_consumers[table][int(row.ID)] = item
	return {"ok":true}

## The same checks as _load_table + _consumer_row for a big consumer table,
## parsing its pinned bytes a few MB at a time and writing each row to the
## bake, so the whole parsed table (hundreds of MB) never sits in memory.
## Only the pack builder's one-row-object-per-indented-block layout is
## streamed; any other layout reports "unstreamable" before anything is
## written and the table is loaded whole instead.
func _stream_consumer_table(table: String, records: Array) -> Dictionary:
	var checked: Dictionary = _bytes(_manifest.source_tables[table])
	if not checked.ok: return checked
	var bytes: PackedByteArray = checked.bytes
	checked = {}
	var head: String = bytes.slice(0, mini(bytes.size(), 64)).get_string_from_utf8().trim_prefix(String.chr(0xfeff))
	var nl: String = "\r\n" if head.begins_with("{\r\n") else "\n"
	if not head.begins_with("{" + nl + "  \"rows\": [" + nl + "    {" + nl): return {"ok":false,"unstreamable":true}
	var row_end: String = nl + "    }," + nl
	var position: int = bytes.find(0x5b) + 1
	var ids: Dictionary = {}
	var index: int = 0
	var first: bool = true
	while position < bytes.size():
		var last: bool = position + 4 * 1024 * 1024 >= bytes.size()
		# End the window on a line break so no UTF-8 character is split.
		var window_end: int = bytes.size() if last else bytes.rfind(10, position + 4 * 1024 * 1024) + 1
		if window_end <= position: return _failure("source_table_contract","Invalid source rows: " + table)
		var text: String = bytes.slice(position, window_end).get_string_from_utf8()
		var cut: int = text.rfind(nl + "  ]") if last else text.rfind(row_end)
		if cut < 0:
			if first: return {"ok":false,"unstreamable":true}
			return _failure("source_table_contract","Invalid source rows: " + table)
		first = false
		var body: String = text.substr(0, cut + (0 if last else nl.length() + 5))
		position += (text.substr(0, cut + (0 if last else row_end.length()))).to_utf8_buffer().size()
		var rows: Variant = JSON.parse_string("[" + body + "]")
		if not rows is Array: return _failure("source_table_contract","Invalid source rows: " + table)
		for row: Variant in rows:
			if not row is Dictionary or not _integer(row.get(TABLE_KEYS[table])): return _failure("source_table_contract","Invalid source row key.")
			var key: int = int(row[TABLE_KEYS[table]])
			if ids.has(key): return _failure("duplicate_source_key","Duplicate current source row key.")
			ids[key] = true
			if index >= records.size(): return _failure("source_table_contract","Invalid source rows: " + table)
			var problem: Dictionary = _consumer_row(table, index, row, records[index])
			if not problem.ok: return problem
			_writer.add("r:%s:%d" % [table, index], row)
			index += 1
		if last: break
	if index != records.size(): return _failure("source_table_contract","Invalid source rows: " + table)
	return {"ok":true}

## Reads one pinned source table into _source_tables and checks its row keys.
func _load_table(table: String) -> Dictionary:
	var spec: Dictionary = _manifest.source_tables[table]
	var loaded: Dictionary = _json(spec)
	if not loaded.ok: return loaded
	if not loaded.value is Dictionary or not loaded.value.get("rows") is Array or loaded.value.rows.size() != int(spec.row_count): return _failure("source_table_contract","Invalid source rows: " + table)
	_source_tables[table] = loaded.value.rows
	var ids: Dictionary = {}
	for row: Variant in loaded.value.rows:
		if not row is Dictionary or not _integer(row.get(TABLE_KEYS[table])): return _failure("source_table_contract","Invalid source row key.")
		var key: int = int(row[TABLE_KEYS[table]])
		if ids.has(key): return _failure("duplicate_source_key","Duplicate current source row key.")
		ids[key] = true
	return {"ok":true}

func _load_dummy_declarations(source_index: Array) -> Dictionary:
	# The manifest-pinned full source index already declares this original
	# table. A supplement can add its exact bytes without replacing originals,
	# rewriting the base manifest or reducing the inventory denominator.
	var matches: Array = []
	for entry: Variant in source_index:
		if entry is Dictionary and entry.get("path") == "content/" + DUMMY_IMAGE_TABLE + ".json":
			matches.append(entry)
	if matches.is_empty():
		_dummy_source = {"status":"not_declared_by_source_index"}
		return {"ok":true}
	if matches.size() != 1:
		return _failure("source_dummy_declaration_contract","Duplicate original dummy-image table declaration.")
	var entry: Dictionary = matches[0]
	if entry.get("version") != 523 or entry.get("status") != "strict_json_pass" or entry.get("member_crc_verified") != true or not _integer(entry.get("row_count")) or int(entry.row_count) < 0:
		return _failure("source_dummy_declaration_contract","Original dummy-image table identity is incomplete.")
	var spec: Dictionary = {"path":"source/" + DUMMY_IMAGE_TABLE + ".json","bytes":entry.get("bytes"),"sha256":entry.get("sha256")}
	var loaded: Dictionary = _json(spec)
	if not loaded.get("ok",false):
		var missing: Dictionary = _failure("source_dummy_declarations_unavailable","Install the exact original dummy-image declaration table before connecting this pack.")
		missing["details"] = loaded
		return missing
	if not loaded.value is Dictionary or not loaded.value.get("rows") is Array or loaded.value.rows.size() != int(entry.row_count):
		return _failure("source_dummy_declaration_contract","Original dummy-image rows differ from their indexed identity.")
	var ids: Dictionary = {}
	for index: int in loaded.value.rows.size():
		var row: Variant = loaded.value.rows[index]
		if not row is Dictionary:
			return _failure("source_dummy_declaration_contract","Original dummy-image row is invalid.")
		for field: String in ["ID","BuffCardDeckID","GradeID","AssetID"]:
			if not _integer(row.get(field)) or int(row[field]) <= 0:
				return _failure("source_dummy_declaration_contract","Original dummy-image identity is invalid.")
		var id: int = int(row.ID)
		var asset_id: int = int(row.AssetID)
		if ids.has(id) or not _assets.has(asset_id):
			return _failure("source_dummy_declaration_contract","Original dummy-image declaration has a duplicate row or missing asset identity.")
		ids[id] = true
		var evidence: Dictionary = {"source_table":DUMMY_IMAGE_TABLE,"source_table_sha256":spec.sha256,
			"source_row_index_zero":index,"source_row_canonical_sha256":_canonical_row_sha(row),
			"source_row":row.duplicate(true),"declared_asset_id":asset_id}
		if not _dummy_assets.has(asset_id): _dummy_assets[asset_id] = []
		_dummy_assets[asset_id].append(evidence)
		var path: String = str(_assets[asset_id].path)
		if not path.is_empty():
			if not _dummy_paths.has(path): _dummy_paths[path] = []
			_dummy_paths[path].append(evidence)
	_dummy_source = {"status":"original_dummy_images_excluded","source_table":DUMMY_IMAGE_TABLE,
		"source_table_sha256":spec.sha256,"source_file":spec.path,"source_file_bytes":spec.bytes,
		"declaration_rows":loaded.value.rows.size(),"declared_assets":_dummy_assets.size(),
		"inventory_preserved":true,"excluded_is_not_gameplay_use":true}
	return {"ok":true}

func metadata() -> Dictionary:
	return {"schema":1,"source_snapshot":"patch523","source_version":523,"manifest_sha256":_manifest_sha,
		"source_tables":_manifest.get("source_tables",{}).duplicate(true),"pack_members":_member_count,
		"actual_game_consumption_observed":false,
		"source_dummy_exclusions":_dummy_source.duplicate(true),
		"source_current_catalog_complete":_manifest.get("metrics",{}).get("source_current_catalog_complete",false),
		"whole_current_source_denominator":_manifest.get("metrics",{}).get("whole_current_source_denominator")}.duplicate(true)

func resolve_consumer(table: String, id: int, field: String) -> Dictionary:
	var provenance: Dictionary = {"source_table":table,"source_id":id,"source_field":field,"source_version":523}
	if not CONSUMER_FIELDS.has(table) or not field in CONSUMER_FIELDS[table]: return _failure("unsupported_consumer_role","Exact consumer role is not registered.",provenance)
	if id == 0: return _failure("zero_sentinel","Source class ID is zero.",provenance)
	if not _has_consumer(table,id): return _failure("missing_consumer_key","Exact source class ID is absent.",provenance)
	var item: Dictionary = _consumer(table,id)
	provenance["source_row_index_zero"] = item.row_index_zero
	provenance["source_table_sha256"] = _manifest.source_tables[table].sha256
	provenance["source_row_canonical_sha256"] = item.source_row_canonical_sha256
	var icon_id: int = int(item.roles[field])
	provenance["icon_id"] = icon_id
	if icon_id == 0: return _failure("zero_sentinel","Source icon role is zero.",provenance)
	if not _has_icon(icon_id): return _failure("missing_icon_key","Exact Icon.ID is absent.",provenance)
	var icon: Dictionary = _icon(icon_id)
	provenance["icon_row_index_zero"] = icon.row_index_zero
	provenance["icon_table_sha256"] = _manifest.source_tables.Icon.sha256
	provenance["asset_id"] = int(icon.asset_id)
	var result: Dictionary = resolve_asset(int(icon.asset_id))
	result.provenance.merge(provenance,true)
	return result

func source_consumer_row(table: String, id: int) -> Dictionary:
	if not _manifest_intact(): return _failure("manifest_sha_mismatch","Pinned manifest changed after open.")
	if not _has_consumer(table,id): return _failure("missing_consumer_key","Exact source class ID is absent.")
	var item: Dictionary = _consumer(table,id)
	return {"ok":true,"row":_source_row(table,int(item.row_index_zero)).duplicate(true),
		"provenance":{"source_table":table,"source_id":id,"source_row_index_zero":item.row_index_zero,
			"source_table_sha256":_manifest.source_tables[table].sha256,
			"source_row_canonical_sha256":item.source_row_canonical_sha256}}

func resolve_asset(asset_id: int, expected_type: int = -1, declared_path: String = "") -> Dictionary:
	var provenance: Dictionary = {"asset_id":asset_id,"source_version":523,"manifest_sha256":_manifest_sha}
	if not _manifest_intact(): return _failure("manifest_sha_mismatch","Pinned manifest changed after open.",provenance)
	if asset_id == 0: return _failure("zero_sentinel","AssetID is zero.",provenance)
	if not _has_asset(asset_id): return _failure("missing_asset_key","Exact AssetView.AssetId is absent.",provenance)
	var asset: Dictionary = _asset(asset_id)
	provenance.merge(asset,true)
	provenance["asset_view_table_sha256"] = _manifest.source_tables.AssetView.sha256
	provenance["asset_type_table_sha256"] = _manifest.source_tables.AssetType.sha256
	if expected_type != -1 and int(asset.asset_type_id) != expected_type: return _failure("asset_type_mismatch","Expected AssetType differs.",provenance)
	if not declared_path.is_empty() and declared_path != asset.path: return _failure("declared_path_mismatch","Declared literal path differs.",provenance)
	var excluded: Array = _dummy_assets.get(asset_id,_dummy_paths.get(str(asset.path),[]))
	if not excluded.is_empty():
		provenance["source_dummy_declarations"] = excluded.duplicate(true)
		provenance["source_dummy_policy"] = _dummy_source.duplicate(true)
		var blocked: Dictionary = _failure("source_dummy_excluded","An explicit original dummy-image declaration excludes this asset from connection.",provenance)
		blocked["excluded_from_connection"] = true
		blocked["original_inventory_preserved"] = true
		blocked["actual_game_consumption_observed"] = false
		return blocked
	if asset.status != "verified_original":
		if asset.status == "unsupported_csb": provenance["owner_note"] = "AssetType101 belongs to the existing UI owner."
		return _failure(str(asset.status),"Exact source asset has no supported verified original image.",provenance)
	return _texture(str(asset.path),provenance)

func resolve_path(declared_path: String, expected_type: int = -1) -> Dictionary:
	if not _safe_relative(declared_path): return _failure("unsafe_declared_path","Unsafe declared literal path.")
	var matches: Array[int] = []
	if _records != null:
		var listed: Variant = _records.read("p:" + declared_path)
		if listed is PackedInt64Array:
			for id: int in listed:
				if expected_type == -1 or int(_asset(id).asset_type_id) == expected_type: matches.append(id)
	else:
		for id: int in _assets:
			var asset: Dictionary = _assets[id]
			if asset.path == declared_path and (expected_type == -1 or int(asset.asset_type_id) == expected_type): matches.append(id)
	if matches.size() != 1: return _failure("ambiguous_or_missing_asset_path","Literal path must have one exact typed AssetView identity.",{"path":declared_path})
	return resolve_asset(matches[0],expected_type,declared_path)

## Proposed budget is configurable; no process-wide cache or forced UI clears.
func configure_texture_cache(budget_bytes: int, max_entries: int = 4096) -> void:
	_texture_cache.configure(budget_bytes, max_entries)

func clear_texture_cache(forget_weak: bool = false) -> void:
	_texture_cache.clear(forget_weak)

func trim_texture_cache(target_bytes: int) -> void:
	_texture_cache.trim_to(target_bytes)

func texture_cache_metrics() -> Dictionary:
	return _texture_cache.metrics()

func _texture(path: String, provenance: Dictionary) -> Dictionary:
	if not _has_member(path): return _failure("missing_current_member","Verified current member is absent.",provenance)
	var member: Dictionary = _member(path)
	provenance["member"] = member.duplicate(true)
	var checked: Dictionary = _bytes({"path":member.file,"bytes":member.plain_bytes,"sha256":member.sha256})
	if not checked.ok:
		checked.provenance = provenance
		return checked
	# Verification above intentionally runs even on a resident or weak hit.
	var texture: Texture2D = _texture_cache.lookup(path)
	if texture == null:
		var image := Image.new()
		var error: Error = ERR_FILE_UNRECOGNIZED
		var data: PackedByteArray = checked.bytes
		match str(member.format):
			"PNG": error = image.load_png_from_buffer(data)
			"JPEG": error = image.load_jpg_from_buffer(data)
			"BMP": error = image.load_bmp_from_buffer(data)
		if error != OK or image.is_empty() or image.get_width() != int(member.width) or image.get_height() != int(member.height): return _failure("original_image_decode_failed","Original image format/dimensions failed.",provenance)
		texture = ImageTexture.create_from_image(image)
		_texture_cache.remember(path, texture, image.get_data_size())
	return {"ok":true,"status":"verified_original_texture","status_type":"verified_original_texture",
		"texture":texture,"provenance":provenance,"original_bytes_unchanged":true,
		"actual_game_consumption_observed":false}
