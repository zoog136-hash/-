extends RefCounted
## Alpha-only copies for floor rendering. Never replace inventory/source assets.
const MANIFEST: String = "res://data/ground_alpha.json"
const MAX_CACHE: int = 64
static var _loaded: bool = false
static var _entries: Dictionary = {}
static var _cache: Dictionary = {}
static var _order: Array[String] = []

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (parsed is Dictionary) or int(parsed.get("schema",0)) != 1 or parsed.get("scope","") != "ground_display_only": return
	for key: Variant in parsed.get("images",{}):
		var entry: Variant = parsed.images[key]
		if not (entry is Dictionary): continue
		var source: String = str(key)
		var path: String = str(entry.get("path",""))
		if not (source.begins_with("res://assets/l1j/verified/ground/") or source.begins_with("res://assets/original_items/ground/")): continue
		if not path.begins_with("res://assets/ground_alpha/") or not path.ends_with(".png") or ".." in path or "\\" in path: continue
		_entries[source] = entry

static func _sha(image: Image) -> String:
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

static func texture(original: Texture2D) -> Texture2D:
	if original == null: return null
	_ensure()
	var entry: Dictionary = _entries.get(original.resource_path,{})
	if entry.is_empty(): return original
	var key: String = original.resource_path+":"+str(original.get_instance_id())
	if _cache.has(key): return _cache[key] as Texture2D
	# Do not borrow another image's cutout just because a resource path matches.
	var pixels: Image = original.get_image()
	if pixels == null or pixels.is_empty(): return original
	if pixels.is_compressed() and pixels.decompress() != OK: return original
	var decoded_matches: bool = _sha(pixels) == str(entry.get("source_rgba_sha256",""))
	if not decoded_matches:
		# A reviewed L1J ImageTexture can decode differently from the imported
		# CompressedTexture2D used to pin source_rgba_sha256. In that case verify
		# the *exact original PNG bytes* before accepting the audited cutout.
		# Never relax the pixel-hash check for other source families.
		if not original.resource_path.begins_with("res://assets/l1j/verified/ground/"): return original
		var expected_source_sha: String = str(entry.get("source_sha256",""))
		if expected_source_sha.length() != 64 or not expected_source_sha.is_valid_hex_number(false): return original
		var raw_path: String = original.resource_path
		if not FileAccess.file_exists(raw_path):
			raw_path = "res://data/l1j/verified_bytes/%s.l1jpng" % expected_source_sha
		if not FileAccess.file_exists(raw_path) or FileAccess.get_sha256(raw_path) != expected_source_sha: return original
	var path: String = str(entry.path)
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != str(entry.get("sha256","")): return original
	if not ResourceLoader.exists(path): return original
	var cleaned: Texture2D = load(path) as Texture2D
	if cleaned == null or cleaned.get_size() != original.get_size(): return original
	_cache[key] = cleaned
	_order.append(key)
	while _order.size() > MAX_CACHE: _cache.erase(_order.pop_front())
	return cleaned

static func cache_size() -> int: return _cache.size()
