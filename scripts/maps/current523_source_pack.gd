extends RefCounted
## Generic M523 raw storage. Logical Lands retain exact native AssetPath values.
## Format helpers only are reused from the pinned Aden reader; its identity and
## manifest validation are unchanged and are never called with another member.
const S32_FORMAT = preload("res://scripts/maps/current523_aden_pack.gd")
const LAND_SHA256 = "8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9"
const MANIFEST_NAME = "source523.json"
const MAX_METADATA_BYTES = 24 * 1024 * 1024
const MAX_MEMBERS = 20000
const MAX_STORED_BYTES = 8 * 1024 * 1024 + 65536
var loaded: bool = false
var catalog_loaded: bool = false
var problem: String = ""
var source_asset: String = ""
var _root: String = ""
var _manifest_sha256: String = ""
var _members: Dictionary = {}
var _supported: Dictionary = {}
var _asset: Dictionary = {}
var _logical_lands: Array = []
var _catalog_members: Dictionary = {}
var _assets: Dictionary = {}
var _lands: Dictionary = {}
## After the first verified load the member inventory (the bulk of the parsed
## manifest) lives in a device-local record bake keyed by the manifest pin and
## this script, one record per AssetPath, read when an asset is selected. The
## Land and AssetPath registries stay in memory. The manifest bytes are still
## hash-checked on every load.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
static var bake_enabled: bool = true
var _records: RefCounted

func _fail(message: String) -> bool:
	problem = message
	return false

static func _hash(bytes: PackedByteArray) -> String:
	# An empty opaque tail is legal; HashingContext.update rejects zero bytes.
	return "".sha256_text() if bytes.is_empty() else S32_FORMAT._hash(bytes)

static func _storage(item: Dictionary) -> Dictionary:
	if not _member_name(item.get("member")): return {}
	var format: String = str(item.get("storage_format","raw"))
	if format == "raw":
		if item.has("stored_bytes") and item.stored_bytes != item.bytes: return {}
		if item.has("stored_sha256") and item.stored_sha256 != item.sha256: return {}
		return {"path":"originals/"+str(item.member),"bytes":int(item.bytes),"sha256":str(item.sha256),"gzip":false}
	if format != "gzip" or not str(item.member).ends_with(".s32") or not S32_FORMAT._uint(item.get("stored_bytes"),MAX_STORED_BYTES) or int(item.stored_bytes) < 18 or not S32_FORMAT._sha(item.get("stored_sha256")): return {}
	return {"path":"originals/"+str(item.member)+".gz","bytes":int(item.stored_bytes),"sha256":str(item.stored_sha256),"gzip":true}

static func _gzip_header_valid(bytes: PackedByteArray, original_size: int) -> bool:
	return bytes.size() >= 18 and bytes.size() <= MAX_STORED_BYTES and original_size > 0 and original_size <= S32_FORMAT.MAX_SOURCE_BYTES and bytes[0] == 31 and bytes[1] == 139 and bytes[2] == 8 and bytes[3] == 0 and bytes.decode_u32(bytes.size()-4) == original_size

static func _asset_root(value: Variant) -> String:
	if not value is String or value.is_empty() or value.length() > 128: return ""
	var component: String = value.trim_suffix("/")
	if component.is_empty(): return ""
	for c: String in component:
		if not c in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-": return ""
	return "Map/" + component + "/"

static func _member_name(value: Variant) -> bool:
	if not value is String or value.length() > 256: return false
	var parts: PackedStringArray = value.split("/")
	if parts.size() != 3 or parts[0] != "Map" or _asset_root(parts[1]) == "": return false
	var basename: String = parts[2]
	if not (basename.ends_with(".s32") or basename.ends_with(".seg")): return false
	var stem: String = basename.left(-4)
	if stem.is_empty(): return false
	for c: String in stem:
		if not c in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-": return false
	return true

static func candidate_origin(member: String) -> Variant:
	# Explicit filename-placement hypothesis only, never a native coordinate fact.
	if not _member_name(member) or not member.ends_with(".s32"): return null
	var stem: String = member.get_file().trim_suffix(".s32")
	if stem.length() != 8: return null
	for c: String in stem:
		if not c in "0123456789abcdefABCDEF": return null
	return Vector2i((stem.substr(0,4).hex_to_int()-0x7e00)*64,(stem.substr(4,4).hex_to_int()-0x7e00)*64)

static func _no_links(path: String) -> bool:
	var current: String = ProjectSettings.globalize_path(path).simplify_path()
	while not current.is_empty():
		var parent: String = current.get_base_dir()
		if parent == current or parent.is_empty(): break
		var directory := DirAccess.open(parent)
		if directory != null and directory.is_link(current.get_file()): return false
		current = parent
	return true

func _clear() -> void:
	loaded = false
	catalog_loaded = false
	problem = ""
	source_asset = ""
	_root = ""
	_manifest_sha256 = ""
	_members.clear()
	_supported.clear()
	_asset.clear()
	_logical_lands.clear()
	_catalog_members.clear()
	_assets.clear()
	_lands.clear()
	_records = null

func load_catalog(directory: String, expected_manifest_sha256: String) -> bool:
	_clear()
	if not S32_FORMAT._sha(expected_manifest_sha256): return _fail("Explicit manifest SHA256 is required")
	var manifest_path: String = directory.path_join(MANIFEST_NAME)
	if not _no_links(manifest_path): return _fail("Symlink in generic source pack")
	var file := FileAccess.open(manifest_path,FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_METADATA_BYTES: return _fail("Missing or oversized generic source manifest")
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if _hash(bytes) != expected_manifest_sha256: return _fail("Generic source manifest SHA256 differs from caller pin")
	var bake_name: String = bake_name_for(expected_manifest_sha256)
	var bake_key: String = bake_key_for(expected_manifest_sha256) if bake_enabled else ""
	var baked: RefCounted = BAKE.open_records(bake_name, bake_key) if not bake_key.is_empty() else null
	if baked != null:
		var meta: Variant = baked.read("meta")
		if meta is Dictionary and meta.get("assets") is Dictionary and meta.get("lands") is Dictionary and meta.lands.size() == 1065:
			_assets = meta.assets
			_lands = meta.lands
			_records = baked
			_root = directory
			_manifest_sha256 = expected_manifest_sha256
			catalog_loaded = true
			return true
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	bytes = PackedByteArray()
	if not value is Dictionary: return _fail("Invalid generic source manifest")
	if value.get("schema") != 1 or value.get("kind") != "current523_s32_source_pack" or value.get("edition") != "LineageM" or value.get("cumulative_version") != 523 or value.get("delivery_status") != "PRIVATE_LOCAL_ONLY": return _fail("Generic source identity mismatch")
	var native: Variant = value.get("native_land_table")
	var inventory: Variant = value.get("input_inventory")
	if not native is Dictionary or native.get("sha256") != LAND_SHA256 or native.get("rows") != 1065 or native.get("bytes") != 326356 or not inventory is Dictionary or not S32_FORMAT._sha(inventory.get("sha256")): return _fail("Missing pinned native Land or independent inventory identity")
	var semantics: Variant = value.get("semantics")
	if not semantics is Dictionary: return _fail("Missing generic interpretation boundary")
	for key: String in S32_FORMAT.UNKNOWN_SEMANTICS:
		if semantics.get(key) != "UNKNOWN": return _fail("Unsupported source interpretation")
	for interpretation: Variant in semantics.values():
		if interpretation != "UNKNOWN": return _fail("Unsupported additional source interpretation")
	var asset_rows: Variant = value.get("assets")
	if not asset_rows is Array or asset_rows.is_empty() or asset_rows.size() > 2000: return _fail("Invalid native AssetPath registry")
	var assets: Dictionary = {}
	var physical_roots: Dictionary = {}
	for row: Variant in asset_rows:
		if not row is Dictionary or _asset_root(row.get("asset_path")).is_empty(): return _fail("Unsafe AssetPath binding")
		var literal: String = row.asset_path
		var physical: String = _asset_root(literal)
		if row.get("source_root") != physical or assets.has(literal) or physical_roots.has(physical): return _fail("Duplicate or ambiguous source root binding")
		assets[literal] = row.duplicate(true)
		physical_roots[physical] = true
	var declarations: Variant = value.get("logical_lands")
	if not declarations is Array or declarations.size() != 1065: return _fail("Expected all 1065 native logical Land declarations")
	var lands: Dictionary = {}
	var ids_by_asset: Dictionary = {}
	for entry: Variant in declarations:
		if not entry is Dictionary or not entry.get("declaration") is Dictionary: return _fail("Missing raw native Land declaration")
		var land: Dictionary = entry.declaration
		if not S32_FORMAT._uint(land.get("ID"),2147483647) or lands.has(int(land.ID)) or not assets.has(land.get("AssetPath")): return _fail("Invalid native logical Land binding")
		var exclusions: Variant = entry.get("excluded_content")
		if not exclusions is Array or not entry.get("policy_provenance") is Dictionary or str(entry.policy_provenance.get("source","")).is_empty() or not entry.get("policy_status") in ["classified","unclassified"]: return _fail("Explicit content exclusion policy provenance is required")
		for tag: Variant in exclusions:
			if not tag in ["arena","ziggurat","guild","siege"]: return _fail("Unknown excluded content tag")
		lands[int(land.ID)] = entry.duplicate(true)
		if not ids_by_asset.has(land.AssetPath): ids_by_asset[land.AssetPath] = []
		ids_by_asset[land.AssetPath].append(int(land.ID))
	for asset_path: String in assets:
		var ids: Array = ids_by_asset.get(asset_path,[])
		ids.sort()
		var declared: Variant = assets[asset_path].get("land_ids")
		if not declared is Array: return _fail("Missing native AssetPath Land IDs")
		var declared_ids: Array = []
		for id: Variant in declared:
			if not S32_FORMAT._uint(id,2147483647): return _fail("Invalid native AssetPath Land ID")
			declared_ids.append(int(id))
		if ids.is_empty() or ids != declared_ids: return _fail("AssetPath logical Land list mismatch: "+asset_path)
		assets[asset_path].land_ids = declared_ids
	var entries: Variant = value.get("members")
	if not entries is Array or entries.is_empty() or entries.size() > MAX_MEMBERS or value.get("source_count") != entries.size(): return _fail("Invalid generic member inventory size")
	var members: Dictionary = {}
	var lines: Array[String] = []
	var lines_by_asset: Dictionary = {}
	var ready_by_asset: Dictionary = {}
	for item: Variant in entries:
		if not item is Dictionary or not _member_name(item.get("member")) or not assets.has(item.get("asset_path")): return _fail("Invalid literal generic member")
		var member: String = item.member
		if members.has(member) or not member.begins_with(_asset_root(item.asset_path)): return _fail("Duplicate or misbound generic source path")
		if not S32_FORMAT._uint(item.get("bytes"),S32_FORMAT.MAX_SOURCE_BYTES) or item.bytes <= 0 or not S32_FORMAT._sha(item.get("sha256")): return _fail("Invalid generic source size or digest")
		var storage: Dictionary = _storage(item)
		if storage.is_empty() or item.get("path") != storage.path: return _fail("Invalid or noncanonical stored source representation")
		if not item.get("status") in ["ready","missing_source","unsupported_format","quarantined_malformed_s32","unverified_current_selection"] or not item.get("availability") in ["present","missing"]: return _fail("Unknown source availability status")
		if item.get("status") == "ready":
			if item.get("format") != "s32" or not member.ends_with(".s32") or item.get("availability") != "present": return _fail("Unsupported format declared ready")
			var proof: Variant = item.get("provenance")
			if not proof is Dictionary or proof.get("snapshot_version") != 523 or proof.get("current_selection_verified") != true or proof.get("expected_member_sha256") != item.sha256: return _fail("Ready member lacks current-selection provenance")
			var validator = S32_FORMAT.new()
			if not validator._validate_sections(item): return _fail("Malformed ready raw sections: "+validator.problem)
			ready_by_asset[item.asset_path] = int(ready_by_asset.get(item.asset_path,0))+1
		var line: String = member+"\t"+str(int(item.bytes))+"\t"+str(item.sha256)+"\n"
		lines.append(line)
		if not lines_by_asset.has(item.asset_path): lines_by_asset[item.asset_path] = []
		lines_by_asset[item.asset_path].append(line)
		members[member] = item.duplicate(true)
	lines.sort()
	if "".join(lines).sha256_text() != value.get("source_inventory_sha256"): return _fail("Generic global inventory mismatch")
	for asset_path: String in assets:
		var asset_lines: Array = lines_by_asset.get(asset_path,[])
		asset_lines.sort()
		if "".join(asset_lines).sha256_text() != assets[asset_path].get("source_inventory_sha256") or asset_lines.size() != assets[asset_path].get("source_count") or int(ready_by_asset.get(asset_path,0)) != assets[asset_path].get("ready_count"): return _fail("Per-asset source inventory mismatch")
	_assets = assets
	_lands = lands
	_catalog_members = members
	_root = directory
	_manifest_sha256 = expected_manifest_sha256
	catalog_loaded = true
	if not bake_key.is_empty():
		var writer: RefCounted = BAKE.record_writer(bake_name, bake_key)
		if writer != null:
			var grouped: Dictionary = {}
			for member: String in members:
				var owner: String = members[member].asset_path
				if not grouped.has(owner): grouped[owner] = {}
				grouped[owner][member] = members[member]
			for owner: String in grouped: writer.add("ms:" + owner, grouped[owner])
			writer.add("meta", {"assets":assets, "lands":lands})
			if BAKE.finish_records(writer):
				var records: RefCounted = BAKE.open_records(bake_name, bake_key)
				if records != null:
					_records = records
					_catalog_members = {}
	return true

static func bake_name_for(manifest_sha: String) -> String:
	return "current523_source_pack_" + manifest_sha.left(16)

static func bake_key_for(manifest_sha: String) -> String:
	return BAKE.key(["current523_source_pack.v1", manifest_sha, BAKE.code_key(["res://scripts/maps/current523_source_pack.gd"])])

## True when this device already holds the member inventory for this pin.
static func baked(manifest_sha: String) -> bool:
	return BAKE.present(bake_name_for(manifest_sha), bake_key_for(manifest_sha))

## The verified member rows of one AssetPath.
func _asset_members(asset_path: String) -> Dictionary:
	if _records == null: return _catalog_members
	var listed: Variant = _records.read("ms:" + asset_path)
	return listed if listed is Dictionary else {}

func land_record(id: int) -> Dictionary:
	return _lands[id].duplicate(true) if catalog_loaded and _lands.has(id) else {}

func asset_record(asset_path: String) -> Dictionary:
	return _assets[asset_path].duplicate(true) if catalog_loaded and _assets.has(asset_path) else {}

func load_pack(directory: String, expected_manifest_sha256: String, asset_path: String) -> bool:
	if not load_catalog(directory,expected_manifest_sha256): return false
	return select_asset(asset_path)

func select_asset(asset_path: String) -> bool:
	# Select only from this instance's already caller-pinned catalog. No file
	# identity is inferred or accepted from the physical directory's name.
	loaded=false
	_members.clear(); _supported.clear(); _logical_lands.clear(); _asset.clear()
	source_asset=""; problem=""
	if not catalog_loaded: return _fail("A verified catalog is required before selecting an asset")
	var directory: String=_root
	if _asset_root(asset_path).is_empty() or not _assets.has(asset_path): return _fail("Exact native AssetPath not present in this pack")
	var ordinary: int = 0
	for id: int in _assets[asset_path].land_ids:
		var land: Dictionary = _lands[id]
		_logical_lands.append(land.duplicate(true))
		if land.policy_status == "classified" and land.excluded_content.is_empty(): ordinary += 1
	if ordinary == 0: return _fail("Selected AssetPath has no classified ordinary logical Land")
	var listed: Dictionary = _asset_members(asset_path)
	for member: String in listed:
		var metadata: Dictionary = listed[member]
		if metadata.asset_path != asset_path: continue
		_members[member] = metadata.duplicate(true)
		if metadata.status != "ready": continue
		var path: String = directory.path_join(str(metadata.path))
		if not _no_links(path): _members[member].runtime_status = "symlink_rejected"; continue
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length() != int(_storage(metadata).bytes): _members[member].runtime_status = "missing_or_wrong_size"; continue
		_supported[member] = true
	if _supported.is_empty():
		_members.clear()
		_logical_lands.clear()
		return _fail("Selected AssetPath has no available supported S32 members")
	_asset = _assets[asset_path].duplicate(true)
	_asset.runtime_ready_count = _supported.size()
	source_asset = asset_path
	loaded = true
	return true

func source_members() -> Array:
	var result: Array = _members.keys() if loaded else []
	result.sort()
	return result

func supported_s32_members() -> Array:
	var result: Array = _supported.keys() if loaded else []
	result.sort()
	return result

func source_metadata(member: String) -> Dictionary:
	return _members[member].duplicate(true) if loaded and _members.has(member) else {}

func logical_lands() -> Array:
	return _logical_lands.duplicate(true) if loaded else []

func catalog_lands() -> Array:
	var result: Array = []
	if not catalog_loaded: return result
	var ids: Array = _lands.keys()
	ids.sort()
	for id: int in ids: result.append(_lands[id].duplicate(true))
	return result

func catalog_identity() -> Dictionary:
	return {"manifest_sha256":_manifest_sha256,"native_land_table_sha256":LAND_SHA256} if catalog_loaded else {}

func fork_catalog() -> RefCounted:
	if not catalog_loaded: return null
	# Share only immutable validated row values. Independent top-level registries
	# ensure selecting/resetting one field never clears another field's catalog.
	var result: RefCounted=get_script().new()
	result._root=_root; result._manifest_sha256=_manifest_sha256
	result._catalog_members=_catalog_members.duplicate()
	result._records=_records
	result._assets=_assets.duplicate(); result._lands=_lands.duplicate()
	result.catalog_loaded=true
	return result

func catalog_directory() -> String:
	return _root if catalog_loaded else ""

func matches_manifest(directory: String, expected_sha256: String) -> bool:
	if not catalog_loaded or directory!=_root or expected_sha256!=_manifest_sha256: return false
	var path: String=directory.path_join(MANIFEST_NAME)
	if not _no_links(path): return false
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<1 or file.get_length()>MAX_METADATA_BYTES: return false
	# Recheck bytes without reparsing the immutable catalog for every new field.
	return _hash(file.get_buffer(file.get_length()))==expected_sha256

func format_root() -> String:
	return str(_asset.get("source_root","")) if loaded else ""

func read_metadata(member: String = "") -> Dictionary:
	if not member.is_empty(): return source_metadata(member)
	return {"asset":_asset.duplicate(true),"logical_lands":logical_lands(),"manifest_sha256":_manifest_sha256,
		"source_asset":source_asset,"native_land_table_sha256":LAND_SHA256} if loaded else {}

func read_member(member: String) -> Dictionary:
	problem = ""
	if not loaded or not _supported.has(member):
		_fail("Generic source member not registered in selected AssetPath")
		return {}
	var metadata: Dictionary = _members[member]
	var storage: Dictionary = _storage(metadata)
	if storage.is_empty() or metadata.get("path") != storage.path: _fail("Invalid stored source metadata"); return {}
	var path: String = _root.path_join(str(metadata.path))
	if not _no_links(path): _fail("Symlink in generic source path"); return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() != int(storage.bytes): _fail("Missing or wrong-sized stored source"); return {}
	var stored: PackedByteArray = file.get_buffer(int(storage.bytes))
	if stored.size() != int(storage.bytes) or _hash(stored) != storage.sha256: _fail("Stored source SHA256 mismatch"); return {}
	var bytes: PackedByteArray = stored
	if storage.gzip:
		if not _gzip_header_valid(stored,int(metadata.bytes)): _fail("Invalid gzip header or original ISIZE"); return {}
		bytes = stored.decompress(int(metadata.bytes),FileAccess.COMPRESSION_GZIP)
	if bytes.size() != int(metadata.bytes) or _hash(bytes) != metadata.sha256: _fail("Original source SHA256 mismatch after storage decode"); return {}
	var observed: Dictionary = S32_FORMAT.scan_sections(bytes)
	if observed.is_empty(): _fail("Malformed generic S32 source"); return {}
	var result: Dictionary = {"member":member,"asset_path":source_asset,"source_sha256":metadata.sha256,"source_bytes":bytes.size(),"sections":{}}
	for name: String in S32_FORMAT.SECTION_NAMES:
		var section: Dictionary = metadata.sections[name]
		var actual: Dictionary = observed[name]
		if actual.offset != int(section.offset) or actual.bytes != int(section.bytes) or (name in ["covers","objects","opacity","declared"] and actual.get("count") != int(section.count)):
			_fail("Generic raw section partition mismatch"); return {}
		var raw: PackedByteArray = bytes.slice(int(section.offset),int(section.offset)+int(section.bytes))
		if _hash(raw) != section.sha256: _fail("Generic raw section SHA256 mismatch"); return {}
		result.sections[name] = raw
	if observed.objects.object_part_count != int(metadata.object_part_count): _fail("Generic raw object count mismatch"); return {}
	return result
