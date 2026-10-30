extends RefCounted
const GROUND_ICONS = preload("res://scripts/ui/ground_item_icons.gd")
const INVEN_INVENTORY = preload("res://scripts/ui/inven_inventory_icons.gd")
## One read-only image resolver for every item surface, including physical instances.
## New pinned art wins; legacy links are recovery paths, never identity overrides.
const FALLBACK = preload("res://scripts/ui/item_fallback_art.gd")
const REVIEWED = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd")
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const A2 = preload("res://addons/twilight_l1j/twilight_external_a2_bridge.gd")
const OPTIONAL = preload("res://scripts/ui/optional_item_icon_pack.gd")
const MAX_CACHE: int = 256
const LOCAL_ITEM_ICONS: Dictionary = {
	"HP 물약":"res://assets/ui/potionRed.png",
	"강력 HP 물약":"res://assets/ui/potionRed.png",
	"축복받은 HP 물약":"res://assets/ui/potionRed.png",
	"초록 잎":"res://assets/ui/items/green_leaf_painted.png"
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
	if not path.begins_with("res://assets/") or path.contains("..") or path.contains("\\"):
		return false
	if ResourceLoader.exists(path): return true
	# Optional/local PNGs may exist before editor import. Do not mistake missing
	# .godot import metadata for a deleted image; exported .ctex still uses load().
	return path.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg", "svg"] and FileAccess.file_exists(path)

static func _load_path(path: String) -> Texture2D:
	if not _valid(path): return null
	if ResourceLoader.exists(path): return load(path) as Texture2D
	var pixels := Image.new()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var error: int = ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png": error = pixels.load_png_from_buffer(bytes)
		"webp": error = pixels.load_webp_from_buffer(bytes)
		"jpg", "jpeg": error = pixels.load_jpg_from_buffer(bytes)
		"svg": error = pixels.load_svg_from_buffer(bytes, 1.0)
	return ImageTexture.create_from_image(pixels) if error == OK and not pixels.is_empty() else null

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

static func describe(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:
	if ground:
		var original: Dictionary = _describe_original(record, fallback_name, images, true)
		# Preserve existing dedicated floor pairs and their provenance.
		if original.route in ["reviewed_ground", "l1j_dedicated_ground_candidate"]:
			return original
		var source: Dictionary = _source(record, str(original.name))
		# A known publisher ID paired with the wrong name remains rejected.
		if source.is_empty(): return original
		var choice: Dictionary = GROUND_ICONS.lookup(source, str(original.name))
		if not choice.is_empty() and _valid(str(choice.path)):
			original.path = choice.path
			original.route = "ground_category"
			original.status = "ground_category_art"
			original.family = ""
			original["category"] = choice.category
			original["art_source"] = choice
		return original
	# Ground art and all real/unknown source IDs retain the original resolver.
	if not ground and str(record.get("sourceId", "")).is_empty():
		_ensure()
		var inventory_name: String = str(record.get("name", fallback_name))
		# Catalog names (including ambiguous variants) must never borrow an alias.
		if not _names.has(inventory_name):
			var binding: Dictionary = INVEN_INVENTORY.lookup(record, inventory_name)
			if not binding.is_empty():
				return {"source_id":"", "name":inventory_name, "path":binding.path,
					"status":"inven_exact_name" if binding.match_kind == "exact_name" else "inven_visual_alias",
					"route":"inven_inventory", "family":"", "match_kind":binding.match_kind,
					"art_source":binding.art_source}
	return _describe_original(record, fallback_name, images, ground)

static func _describe_original(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:
	var name_value: String = str(record.get("name", fallback_name))
	var source: Dictionary = _source(record, name_value)
	var id: String = str(source.get("sourceId", record.get("sourceId", "")))
	var result: Dictionary = {"source_id":id,"name":name_value,"status":"original_review_pending","path":"","route":"","family":""}
	var has_id: bool = not str(record.get("sourceId", "")).is_empty()
	var ambiguous: bool = not has_id and (_names.get(name_value, []) as Array).size() > 1
	# Ground-only reviewed pairs remain distinct from inventory art.
	if ground and not source.is_empty() and not ambiguous:
		var reviewed_ground: Texture2D = REVIEWED.ground_icon(source, name_value)
		if reviewed_ground != null:
			result.path = str(REVIEWED.item_binding(source, name_value).get("ground_texture", ""))
			result.route = "reviewed_ground"
			result.status = "original_linked"
			return result
		var ground_binding: Dictionary = VISUALS.item_binding(source,name_value)
		var ground_path: String = str(ground_binding.get("ground_path",""))
		if ground_path != str(ground_binding.get("path","")) and _valid(ground_path):
			result.path = ground_path
			result.route = "l1j_dedicated_ground_candidate"
			return result
	# Preserve the replacement artwork and its provenance before any recovery.
	var pinned: String = str(source.get("image_path", ""))
	if not ambiguous and _valid(pinned):
		result.path = pinned
		result.route = "source_id_catalog" if not id.is_empty() else "record_path"
		var proof: Dictionary = _evidence.get(id, {})
		if proof.get("path", "") == pinned and proof.get("identity", "") == "source_id_name_image_bytes_verified":
			result.status = "original_linked"
		return result
	# Canonicalization used to discard a physical record's working old link
	# even when the replacement file was absent. Never recover a rejected ID.
	var record_path: String = str(record.get("image_path", ""))
	if not source.is_empty() and not ambiguous and _valid(record_path):
		result.path = record_path
		result.route = "legacy_record_path"
		if record_path.begins_with("res://assets/ui/"): result.status = "bundled_ui_art"
		return result
	var local_path: String = str(LOCAL_ITEM_ICONS.get(name_value,""))
	if not has_id and id.is_empty() and not ambiguous and _valid(local_path):
		result.path = local_path
		result.route = "twilight_local_item"
		result.status = "bundled_ui_art"
		return result
	# A known ID paired with the wrong name is rejected all the way to fallback.
	if not source.is_empty() and not ambiguous:
		var reviewed: Dictionary = REVIEWED.item_binding(source, name_value)
		if REVIEWED.item_icon(source, name_value) != null:
			result.path = str(reviewed.get("inventory_texture", ""))
			result.route = "reviewed_l1j"
			result.status = "original_linked"
			return result
		var mapped: Dictionary = VISUALS.item_binding(source, name_value)
		var path: String = str(mapped.get("ground_path" if ground else "path", ""))
		if _valid(path):
			result.path = path
			result.route = "l1j_candidate"
			return result
		var bridge: Texture2D = A2.item_icon(source, name_value)
		if bridge != null:
			result.path = bridge.resource_path
			result.route = "a2_candidate"
			return result
	# Private exact-name icon candidates are allowed only for records with no
	# sourceId. They never override verified catalog, physical, reviewed L1J,
	# visual manifest, or A2 art, and invalid/missing files retain fallback.
	if id.is_empty() and not ambiguous:
		var optional: Dictionary = OPTIONAL.lookup(source, name_value)
		if not optional.is_empty():
			result.path = str(optional.get("path", ""))
			result.route = "optional_exact_name_icon"
			result.status = "original_review_pending"
			return result
	# The pre-rework exact-name index also contains deliberate stock UI links.
	# Restore those links instead of replacing them with an unrelated family
	# symbol. They are bundled art, not newly verified publisher originals.
	# Empty records with an explicit fallback_name must work as they did before.
	var indexed: String = str(images.get(name_value, ""))
	if not has_id and not ambiguous and _valid(indexed):
		result.path = indexed
		result.route = "legacy_exact_name_index"
		if indexed.begins_with("res://assets/ui/"): result.status = "bundled_ui_art"
		return result
	result.family = FALLBACK.family(record, name_value)
	result.route = "twilight_family_symbol"
	result.status = "self_authored_substitute"
	result["reason"] = "ambiguous_name" if ambiguous else "no_verified_source_path"
	return result

static func texture(record: Dictionary, name_value: String = "", images: Dictionary = {}, ground: bool = false) -> Texture2D:
	var info: Dictionary = describe(record, name_value, images, ground)
	var path: String = str(info.path)
	# Keep the original loader's hash gate and returned ImageTexture. Reloading
	# its path can fail in optional packs/PCKs even though it decoded correctly.
	if info.route in ["reviewed_ground", "reviewed_l1j", "a2_candidate"]:
		var source: Dictionary = _source(record, str(info.name))
		var external: Texture2D = null
		match str(info.route):
			"reviewed_ground": external = REVIEWED.ground_icon(source, str(info.name))
			"reviewed_l1j": external = REVIEWED.item_icon(source, str(info.name))
			"a2_candidate": external = A2.item_icon(source, str(info.name))
		if external != null: return external
		return FALLBACK.texture(FALLBACK.family(record, name_value))
	if path.is_empty(): return FALLBACK.texture(str(info.family))
	if _textures.has(path):
		_order.erase(path)
		_order.append(path)
		return _textures[path]
	var result: Texture2D = _load_path(path)
	if result == null: return FALLBACK.texture(FALLBACK.family(record, name_value))
	_textures[path] = result
	_order.append(path)
	while _order.size() > MAX_CACHE: _textures.erase(_order.pop_front())
	return result

static func cache_size() -> int:
	return _textures.size()
