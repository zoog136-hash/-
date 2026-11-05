extends RefCounted
## Consumer for reviewed, byte-identical base508/current523 static icons only.
## Bindings must arrive in the existing pinned item catalog, never a save record.
## No bindings are shipped until actual original pixels have been reviewed.
const SOURCE = preload("res://scripts/lineagem_base508.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
static var bindings: Dictionary = {}
static var textures: Dictionary = {}
static var identities: Dictionary = {}

static func configure(document: Dictionary) -> void:
	bindings = {}
	textures = {}
	identities = {}
	var source_index: Variant = document.get("source_icon_index", {})
	if not source_index is Dictionary or source_index.get("schema") != "patch523-item-icon-index-v1": return
	identities = source_index.duplicate(true)
	var index: Variant = document.get("source_icon_pixels", {})
	if not index is Dictionary or index.get("schema") != "patch523-base508-identical-icon-pixels-v1": return
	var entries: Variant = index.get("icons", {})
	if entries is Dictionary: bindings = entries.duplicate(true)

static func _hash(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func resolve(identity: Dictionary) -> Dictionary:
	var missing: Dictionary = {"reason":"source_pixels_not_installed"}
	if identity.get("asset_type_id") != 1: return missing
	var spec: Variant = bindings.get(str(identity.get("icon_id", -1)))
	if not spec is Dictionary: return missing
	var icon_id: int = int(identity.get("icon_id", -1))
	if identities.get("items", {}).get(str(identity.get("item_class_id", -1)), -2) != icon_id:
		return {"reason":"source_pixel_identity_mismatch"}
	var canonical: Dictionary = identities.get("icons", {}).get(str(icon_id), {})
	for key: String in ["icon_id", "asset_id", "asset_type_id", "file_path"]:
		if not identity.has(key) or spec.get(key) != identity[key]:
			return {"reason":"source_pixel_identity_mismatch"}
		if key != "icon_id" and canonical.get(key) != identity[key]: return {"reason":"source_pixel_identity_mismatch"}
	# The existing source API serves base508. Accept it for current523 only
	# after an exact container comparison, never because member names agree.
	var original_hash: Variant = spec.get("base508_container_sha256")
	if not _hash(original_hash) or spec.get("current523_container_sha256") != original_hash:
		return {"reason":"source_pixel_version_unverified"}
	if not _hash(spec.get("sha256")): return {"reason":"source_pixel_hash_invalid"}
	var literal: String = str(identity.file_path)
	if not INSTALL.safe_relative(literal) or literal.get_extension() != "png": return {"reason":"source_pixel_path_invalid"}
	var source_path: String = literal if literal.begins_with("icon/") else "icon/" + literal
	var path: String = SOURCE.asset_path(source_path)
	if path.is_empty() or not FileAccess.file_exists(path): return missing
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return missing
	var size: int = file.get_length()
	if size <= 0 or size > 16*1024*1024 or size != int(spec.get("bytes", -1)):
		return {"reason":"source_pixel_bytes_mismatch"}
	var bytes: PackedByteArray = file.get_buffer(size)
	if INSTALL.sha(bytes) != spec.sha256: return {"reason":"source_pixel_hash_mismatch"}
	var key: String = path + ":" + str(spec.sha256)
	var texture: Texture2D = textures.get(key)
	if texture == null:
		var pixels := Image.new()
		if pixels.load_png_from_buffer(bytes) != OK or pixels.is_empty(): return {"reason":"source_pixel_decode_failed"}
		# No resize, alpha removal, crop, rotation or authored rarity treatment.
		if pixels.get_width() != int(spec.get("width", 0)) or pixels.get_height() != int(spec.get("height", 0)):
			return {"reason":"source_pixel_dimensions_mismatch"}
		texture = ImageTexture.create_from_image(pixels)
		if textures.size() >= 96: textures.erase(textures.keys()[0])
		textures[key] = texture
	return {"reason":"", "path":path, "texture":texture}
