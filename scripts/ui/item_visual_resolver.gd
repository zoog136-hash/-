extends RefCounted
## One read-only image resolver for every item surface, including physical instances.
## Never infer a sourceId from a similar name, strip engraving, or mutate game records.
const FALLBACK = preload("res://scripts/ui/item_fallback_art.gd")
const REVIEWED = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd")
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const A2 = preload("res://addons/twilight_l1j/twilight_external_a2_bridge.gd")
const MAX_CACHE: int = 256
# These are TWILIGHT's local healing items, without publisher source IDs.
# Preserve their bundled game icon without allowing unrelated indexed items
# (for example the old ruby placeholder) to borrow the same potion artwork.
const LOCAL_ITEM_ICONS: Dictionary = {
	"HP 물약":"res://assets/ui/potionRed.png",
	"강력 HP 물약":"res://assets/ui/potionRed.png",
	"축복받은 HP 물약":"res://assets/ui/potionRed.png"
}
static var _loaded: bool = false
static var _ids: Dictionary = {}
static var _names: Dictionary = {}
static var _evidence: Dictionary = {}
static var _textures: Dictionary = {}
static var _order: Array[String] = []

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for record: Dictionary in catalog.get("아이템", []):
		var id: String = str(record.get("sourceId", ""))
		var name_value: String = str(record.get("name", ""))
		_ids[id] = record
		if not _names.has(name_value): _names[name_value] = []
		_names[name_value].append(id)
	var proof_path: String = "res://data/item_visual_provenance.json"
	if FileAccess.file_exists(proof_path):
		var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
		if proof is Dictionary: _evidence = proof.get("records", {})

static func _valid(path: String) -> bool:
	return path.begins_with("res://assets/") and not path.contains("..") and not path.contains("\\") and ResourceLoader.exists(path)

static func _source(record: Dictionary, name_value: String) -> Dictionary:
	_ensure()
	var id: String = str(record.get("sourceId", ""))
	if not id.is_empty():
		var canonical: Dictionary = _ids.get(id, {})
		if not canonical.is_empty():
			return canonical if str(canonical.get("name", "")) == name_value else {}
		return record # An explicit external record may pin a path, never a name lookup.
	var matches: Array = _names.get(name_value, [])
	if matches.size() == 1: return _ids[matches[0]]
	return record

# Even a catalog/legacy candidate must not give the bundled red HP potion art
# to a different item. Keep genuine distinct source-ID-linked images untouched.
static func _finalize_description(record: Dictionary, result: Dictionary) -> Dictionary:
	var path: String = str(result.get("path", ""))
	var name_value: String = str(result.get("name", ""))
	if path == "res://assets/ui/potionRed.png" and not LOCAL_ITEM_ICONS.has(name_value):
		result["path"] = ""
		result["family"] = FALLBACK.family(record, name_value)
		result["status"] = "self_authored_substitute"
		result["route"] = "twilight_family_symbol"
		result["reason"] = "unrelated_bundled_potion"
	return result

static func describe(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:
	var name_value: String = str(record.get("name", fallback_name))
	var source: Dictionary = _source(record, name_value)
	var id: String = str(source.get("sourceId", record.get("sourceId", "")))
	var result: Dictionary = {"source_id":id,"name":name_value,"status":"original_review_pending","path":"","route":"","family":""}
	var has_id: bool = not str(record.get("sourceId", "")).is_empty()
	var ambiguous: bool = not has_id and (_names.get(name_value, []) as Array).size() > 1
	# Pinned catalog art is the Lineage M record's own PNG. Broad PC/L1J name
	# matches must not override it. Ground-only reviewed pairs remain distinct.
	if ground and not source.is_empty() and not ambiguous:
		var reviewed_ground: Texture2D = REVIEWED.ground_icon(source, name_value)
		if reviewed_ground != null:
			result.path = str(REVIEWED.item_binding(source, name_value).get("ground_texture", ""))
			result.route = "reviewed_ground"
			result.status = "original_linked"
			return _finalize_description(record, result)
		var ground_binding: Dictionary = VISUALS.item_binding(source,name_value)
		var ground_path: String = str(ground_binding.get("ground_path",""))
		if ground_path != str(ground_binding.get("path","")) and _valid(ground_path):
			result.path = ground_path
			result.route = "l1j_dedicated_ground_candidate"
			return _finalize_description(record, result)
	var pinned: String = str(source.get("image_path", ""))
	if not ambiguous and _valid(pinned):
		result.path = pinned
		result.route = "source_id_catalog" if not id.is_empty() else "record_path"
		var proof: Dictionary = _evidence.get(id, {})
		if proof.get("path", "") == pinned and proof.get("identity", "") == "source_id_name_image_bytes_verified":
			result.status = "original_linked"
		return _finalize_description(record, result)
	var local_path: String = str(LOCAL_ITEM_ICONS.get(name_value,""))
	if not has_id and id.is_empty() and not ambiguous and _valid(local_path):
		result.path = local_path
		result.route = "twilight_local_item"
		result.status = "bundled_ui_art"
		return _finalize_description(record, result)
	# A known ID paired with the wrong name is rejected all the way to fallback.
	if not source.is_empty() and not ambiguous:
		var reviewed: Dictionary = REVIEWED.item_binding(source, name_value)
		if REVIEWED.item_icon(source, name_value) != null:
			result.path = str(reviewed.get("inventory_texture", ""))
			result.route = "reviewed_l1j"
			result.status = "original_linked"
			return _finalize_description(record, result)
		var mapped: Dictionary = VISUALS.item_binding(source, name_value)
		var path: String = str(mapped.get("ground_path" if ground else "path", ""))
		if _valid(path):
			result.path = path
			result.route = "l1j_candidate"
			return _finalize_description(record, result)
		# A2's ID check rejects name-only candidates for source-identified records.
		var bridge: Texture2D = A2.item_icon(source, name_value)
		if bridge != null:
			result.path = bridge.resource_path
			result.route = "a2_candidate"
			return _finalize_description(record, result)
		var indexed: String = str(images.get(name_value, ""))
		# Old stock UI placeholders (e.g. a red potion for a ruby) are not
		# original item art. Prefer the explicit item-family symbol below.
		if not has_id and _valid(indexed) and not indexed.begins_with("res://assets/ui/"):
			result.path = indexed
			result.route = "legacy_exact_name_index"
			return _finalize_description(record, result)
	result.family = FALLBACK.family(record, name_value)
	result.route = "twilight_family_symbol"
	result.status = "self_authored_substitute"
	result["reason"] = "ambiguous_name" if ambiguous else "no_verified_source_path"
	return _finalize_description(record, result)

static func texture(record: Dictionary, name_value: String = "", images: Dictionary = {}, ground: bool = false) -> Texture2D:
	var info: Dictionary = describe(record, name_value, images, ground)
	var path: String = str(info.path)
	if path.is_empty(): return FALLBACK.texture(str(info.family))
	if _textures.has(path): return _textures[path]
	var result: Texture2D = load(path) as Texture2D
	if result == null: return FALLBACK.texture(FALLBACK.family(record, name_value))
	_textures[path] = result
	_order.append(path)
	while _order.size() > MAX_CACHE: _textures.erase(_order.pop_front())
	return result

static func cache_size() -> int:
	return _textures.size()
