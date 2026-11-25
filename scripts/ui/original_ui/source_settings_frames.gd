extends RefCounted
## Authenticated optional records carried by a private UI section. The original
## manifest, page identities, and the texture cache belong to source_pack.gd.
const MEMBER := "settings_frames_v1.bin"
const SCHEMA := "twilight.settings-frames.v1"
const MAX_BUNDLE := 8 * 1024 * 1024
## Reviewed against the source page, geometry and exact PMA pixels of each frame.
## The private pack descriptor alone cannot authorize replacement pixels.
const VERIFIED_CATALOG_SHA256 := "170934b9fcf2b95f6398d1f06b750a7eadc92f35abfdc19632f56b7f4268fb62"
const MAX_INDEX := 65536
const MAX_PIXELS := 4 * 1024 * 1024

var _bytes: PackedByteArray
var _start: int
var _ranges: Dictionary
var _atlases: Dictionary
var _verified_pages: Dictionary = {}

static func _digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func load_bundle(root: String, manifest_sha: String, pin: String) -> bool:
	if pin.length() != 64 or not pin.is_valid_hex_number(false):
		return false
	var file := FileAccess.open(root.path_join(MEMBER), FileAccess.READ)
	if file == null:
		return false
	var size := file.get_length()
	if size < 5 or size > MAX_BUNDLE:
		return false
	var data := file.get_buffer(size)
	if data.size() != size or _digest(data) != pin:
		return false
	var index_bytes := data.decode_u32(0)
	if index_bytes == 0 or index_bytes > MAX_INDEX - 4 or index_bytes >= size - 4:
		return false
	var start := 4 + index_bytes
	var json := JSON.new()
	if json.parse(data.slice(4, start).get_string_from_utf8()) != OK:
		return false
	var index: Variant = json.data
	if not index is Dictionary or index.get("schema") != SCHEMA or index.get("manifest_sha256") != manifest_sha or not index.get("ranges") is Dictionary:
		return false
	var catalog: Variant = index.get("catalog")
	if not catalog is String or catalog.sha256_text() != VERIFIED_CATALOG_SHA256:
		return false
	if json.parse(catalog) != OK or not json.data is Dictionary:
		return false
	_bytes = data
	_start = start
	_atlases = json.data
	_ranges = index.ranges
	return true

func frame_image(plist: String, name: String, atlas: Dictionary, frame: Dictionary, pack: RefCounted) -> Image:
	var entry: Variant = _atlases.get(plist)
	if not entry is Dictionary or not entry.get("frames") is Dictionary:
		return null
	var record: Variant = entry.frames.get(name)
	if not record is Dictionary:
		return null
	if record.get("geometry") != [frame.get("rect"), frame.get("source_rect"), frame.get("source_size"), bool(frame.get("rotated", false))]:
		return null
	var member: String = str(atlas.get("page", ""))
	var source: Variant = pack.manifest.files.get(member)
	if not source is Dictionary or member != entry.get("page") or source.get("sha256") != entry.get("source_sha256"):
		return null
	if not _verified_pages.has(member) and not pack._pages.has(member):
		var path: String = pack.root.path_join("originals").path_join(member)
		if not pack._safe_member(member) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != source.sha256:
			return null
		_verified_pages[member] = true
	var canvas: Variant = frame.get("source_size")
	if not canvas is Array or canvas.size() != 2:
		return null
	var width := int(canvas[0])
	var height := int(canvas[1])
	if width <= 0 or height <= 0 or width > 4096 or height > 4096 or width * height > MAX_PIXELS:
		return null
	var span: Variant = _ranges.get(record.rgba_sha256)
	if not span is Array or span.size() != 2 or typeof(span[0]) not in [TYPE_FLOAT, TYPE_INT] or typeof(span[1]) not in [TYPE_FLOAT, TYPE_INT]:
		return null
	var offset := int(span[0])
	var length := int(span[1])
	if offset < 0 or length <= 0 or offset > _bytes.size() - _start - length:
		return null
	var at := _start + offset
	var raw_size := width * height * 4
	var pixels := _bytes.slice(at, at + length).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if pixels.size() != raw_size or _digest(pixels) != record.get("rgba_sha256"):
		return null
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
