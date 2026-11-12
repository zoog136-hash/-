extends RefCounted
## Mesh samples are derived from unchanged source by the pinned licensed 3.6
## evaluator. They are never counted as original images or layout acceptance.
const PLAYER_PATH := "res://scripts/characters/lobby_spine_mesh_player.gd"
const SCHEMA := "twilight.spine36.mesh.v1"
const RUNTIME_GIT := "654c20e5b0e523040b6366bbd1042510d2645134"
const MAX_MESH_BYTES := 128 * 1024 * 1024
const MAX_PAGE_BYTES := 32 * 1024 * 1024
const MAX_PAGE_PIXELS := 16 * 1024 * 1024

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"error":code}

static func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _whole(value: Variant, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value == floorf(float(value)) and value <= maximum

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for i: int in value.length():
		if not "0123456789abcdef".contains(value.substr(i,1)): return false
	return true

static func _safe_derived(value: Variant) -> bool:
	if not value is String or not value.begins_with("derived/spine/") or not value.ends_with(".mesh.json") or value.length() > 1024: return false
	if value != value.strip_edges() or "\\" in value or ":" in value or "%" in value or "?" in value or "#" in value: return false
	for i: int in value.length():
		if value.unicode_at(i) < 32 or value.unicode_at(i) == 127: return false
	for part: String in value.split("/",true):
		if part in ["", ".", ".."] or part != part.strip_edges(): return false
	return true

static func _read_mesh(root_path: String, entry: Dictionary) -> Dictionary:
	if not root_path.is_absolute_path() or not _safe_derived(entry.get("path")) or not _sha(entry.get("sha256")) or not _whole(entry.get("bytes"),MAX_MESH_BYTES) or int(entry.bytes) <= 0 or entry.get("compression") != "none": return _fail("mesh_bake_entry_invalid")
	var directory := DirAccess.open(root_path)
	if directory == null: return _fail("mesh_bake_root_missing")
	var current: String = root_path
	var parts: PackedStringArray = str(entry.path).split("/")
	for i: int in parts.size():
		if directory.is_link(parts[i]): return _fail("mesh_bake_link_not_allowed")
		current = current.path_join(parts[i])
		if i + 1 < parts.size():
			directory = DirAccess.open(current)
			if directory == null: return _fail("mesh_bake_directory_missing")
	var file := FileAccess.open(current,FileAccess.READ)
	if file == null: return _fail("mesh_bake_file_missing")
	if file.get_length() != int(entry.bytes): return _fail("mesh_bake_size_mismatch")
	var bytes: PackedByteArray = file.get_buffer(int(entry.bytes))
	if bytes.size() != int(entry.bytes) or _digest(bytes) != entry.sha256: return _fail("mesh_bake_hash_mismatch")
	# Derived JSON normally escapes non-ASCII names. Native round-trip avoids
	# a GDScript loop over tens of megabytes while still rejecting bad UTF-8.
	var text: String = bytes.get_string_from_ascii()
	if text.to_utf8_buffer() != bytes:
		if not _utf8_valid(bytes): return _fail("mesh_bake_utf8_invalid")
		text = bytes.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary: return _fail("mesh_bake_json_invalid")
	return {"ok":true,"data":json.data}

static func _validate_source(data: Dictionary, bundle: Dictionary) -> String:
	if data.get("schema") != SCHEMA or data.get("coordinate_space") != "godot_y_down" or not data.get("premultiplied_alpha") is bool: return "mesh_bake_schema_or_policy_invalid"
	var source: Variant = data.get("source")
	if not source is Dictionary or source.get("runtime_git") != RUNTIME_GIT or source.get("spine_version") != bundle.get("spine_version") or bundle.get("major_minor") != "3.6": return "mesh_bake_runtime_or_version_mismatch"
	if not bundle.get("json_bytes") is PackedByteArray or not bundle.get("atlas_bytes") is PackedByteArray or not _sha(bundle.get("source_sha256")): return "mesh_bake_original_bundle_invalid"
	if source.get("json_sha256") != bundle.source_sha256 or _digest(bundle.json_bytes) != bundle.source_sha256 or source.get("atlas_sha256") != _digest(bundle.atlas_bytes): return "mesh_bake_original_hash_mismatch"
	var pages: Variant = bundle.get("pages")
	var declared: Variant = source.get("pages")
	if not pages is Dictionary or pages.is_empty() or pages.size() > 64 or not declared is Dictionary or declared.size() != pages.size(): return "mesh_bake_page_set_mismatch"
	for page: Variant in pages:
		if not page is String or not declared.has(page) or not declared[page] is Dictionary or not pages[page] is Dictionary or not pages[page].get("bytes") is PackedByteArray: return "mesh_bake_page_entry_invalid"
		var bytes: PackedByteArray = pages[page].bytes
		if bytes.is_empty() or bytes.size() > MAX_PAGE_BYTES or not _sha(pages[page].get("sha256")) or pages[page].sha256 != _digest(bytes) or declared[page].get("sha256") != pages[page].sha256 or not _whole(declared[page].get("bytes"),MAX_PAGE_BYTES) or int(declared[page].bytes) != bytes.size(): return "mesh_bake_page_hash_mismatch"
	var animations: Variant = bundle.get("animations")
	var clips: Variant = data.get("clips")
	if not animations is Array or animations.is_empty() or not clips is Dictionary or clips.size() != animations.size(): return "mesh_bake_clip_set_mismatch"
	var seen: Dictionary = {}
	for name: Variant in animations:
		if not name is String or name.is_empty() or seen.has(name) or not clips.has(name): return "mesh_bake_clip_set_mismatch"
		seen[name] = true
	return ""

static func _png_size(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < 33 or bytes.slice(0,8) != PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(12,16).get_string_from_ascii() != "IHDR": return Vector2i.ZERO
	var width: int = 0
	var height: int = 0
	for i: int in 4:
		width = (width << 8) | bytes[16 + i]
		height = (height << 8) | bytes[20 + i]
	if width <= 0 or height <= 0 or width > 16384 or height > 16384 or width * height > MAX_PAGE_PIXELS: return Vector2i.ZERO
	return Vector2i(width,height)

static func create(bundle: Dictionary, root_path: String, entry: Dictionary) -> Dictionary:
	var loaded: Dictionary = _read_mesh(root_path,entry)
	if not loaded.get("ok",false): return loaded
	var data: Dictionary = loaded.data
	var error: String = _validate_source(data,bundle)
	if not error.is_empty(): return _fail(error)
	var textures: Dictionary = {}
	for path: String in bundle.pages:
		var bytes: PackedByteArray = bundle.pages[path].bytes
		var size: Vector2i = _png_size(bytes)
		if size == Vector2i.ZERO: return _fail("mesh_bake_page_png_header_invalid")
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_size() != size: return _fail("mesh_bake_page_decode_failed")
		textures[path] = ImageTexture.create_from_image(image)
	if not ResourceLoader.exists(PLAYER_PATH): return _fail("mesh_player_not_installed")
	var player_script: Script = load(PLAYER_PATH) as Script
	if player_script == null: return _fail("mesh_player_not_installed")
	var node: Node2D = player_script.new()
	var configured: Variant = node.call("configure",data,textures)
	if not configured is Dictionary or configured.get("ok") != true:
		var detail: String = str(configured.get("error","mesh_player_configuration_failed")) if configured is Dictionary else "mesh_player_configuration_failed"
		node.free()
		return _fail(detail)
	return {"ok":true,"node":node,"source_sha256":bundle.source_sha256,"supported_major_minor":"3.6","autoplay_disabled":true,"sampling_scope":"source_evaluator_samples_host_alpha_policy","original_render_verified":false,"original_lobby_layout_verified":false}

static func _utf8_valid(bytes: PackedByteArray) -> bool:
	# Validate before Godot's UTF-8 decoder, which prints engine errors on bad
	# byte sequences even when the subsequent JSON failure is handled.
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 128:
			index += 1
			continue
		var count: int = 0
		var second_min: int = 128
		var second_max: int = 191
		if first >= 194 and first <= 223: count = 1
		elif first >= 224 and first <= 239:
			count = 2
			if first == 224: second_min = 160
			elif first == 237: second_max = 159
		elif first >= 240 and first <= 244:
			count = 3
			if first == 240: second_min = 144
			elif first == 244: second_max = 143
		else: return false
		if index + count >= bytes.size(): return false
		if bytes[index + 1] < second_min or bytes[index + 1] > second_max: return false
		for offset: int in range(2,count + 1):
			if bytes[index + offset] < 128 or bytes[index + offset] > 191: return false
		index += count + 1
	return true
