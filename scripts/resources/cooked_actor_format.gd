extends RefCounted
## Cooked 523 actor format (2026-11-16, user-approved direction: build-time
## "cooking" of the private 523 resource pack instead of runtime parsing).
##
## One file per runtime actor selection (for now: one 523 NPC sprite with the
## existing NPC core roles). Every role x stored direction x source frame was
## drawn at cook time by the EXISTING runtime path (original_source_preview.gd
## with reference_sp2_bank.gd, the SP2 compositor styles of the Android copy-free
## path and cached frame composites) and recorded as the list of sprites it
## draws. Runs of MIX / alpha 1 / binary-alpha sprites of one z are pre-composited
## (the rule actor_frame_composite_cache.gd uses); every other sprite (ADD,
## half alpha, soft alpha) stays a separate item with its blend mode. Item
## images are packed into texture pages (4-aligned cells, so GPU blocks never
## mix two cells). Opaque-sprite pages may be ETC2 block compressed at cook
## time (the editor binary has the compressor; the phone's release template has
## none); soft-alpha / non-MIX pages always keep exact RGBA8 pixels.
##
## File layout (little endian):
##   "TWCA" | u32 FILE_VERSION | u32 index_zstd_bytes | u32 index_raw_bytes |
##   index (var_to_bytes Dictionary, zstd) | page blobs (zstd image data)
## The index names FORMAT explicitly; a reader rejects any other FORMAT. A rule
## change of the capture, composition or index layout must bump FORMAT; script
## edits that keep the same output do not.
const FORMAT := "twilight-cooked-actor-v2:android_copy_free;cached_frame_composites;binary_alpha_MIX_runs;cells4;bundled_entries;astc4x4_psnr32_binary_alpha_else_rgba8"
## Folder name under the cooked pack root; changes together with FORMAT.
const FORMAT_TAG := "v2"
const MAGIC := "TWCA"
const FILE_VERSION: int = 1
const PAGE_MAX: int = 2048
## Ints per drawn item in a state: image, x, y, blend, z, filter, color id
## (into the float RGBA table "colors"), flags.
const ITEM_STRIDE: int = 8
const FILTER_INHERIT: int = -1
const PAGE_RGBA8 := "rgba8"
const PAGE_ETC2 := "etc2"
const MAX_INDEX_BYTES: int = 64 * 1024 * 1024
const MAX_PAGE_BYTES: int = 64 * 1024 * 1024

static func actor_file(key: String) -> String:
	# "npc:1234" -> "actors/npc_1234.twca"
	return "actors/" + key.replace(":", "_") + ".twca"

static func pad4(value: int) -> int:
	return (value + 3) & ~3

## Shelf packing of cells (sizes rounded up to multiples of 4) into pages of at
## most PAGE_MAX. Returns {"placements": [[page, x, y], ...] in input order,
## "pages": [Vector2i size, ...]}.
static func pack(sizes: Array) -> Dictionary:
	var order: Array = range(sizes.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa: Vector2i = sizes[a]
		var sb: Vector2i = sizes[b]
		return sa.y > sb.y or (sa.y == sb.y and (sa.x > sb.x or (sa.x == sb.x and a < b))))
	var placements: Array = []
	placements.resize(sizes.size())
	var pages: Array = []
	var page: int = -1
	var shelf_x: int = 0
	var shelf_y: int = 0
	var shelf_h: int = 0
	var used := Vector2i.ZERO
	for index: int in order:
		var cell := Vector2i(pad4(maxi(1, sizes[index].x)), pad4(maxi(1, sizes[index].y)))
		var limit := Vector2i(maxi(PAGE_MAX, cell.x), maxi(PAGE_MAX, cell.y))
		if page >= 0 and shelf_x + cell.x > limit.x:
			shelf_y += shelf_h
			shelf_x = 0
			shelf_h = 0
		if page < 0 or shelf_y + cell.y > limit.y:
			if page >= 0: pages[page] = used
			page += 1
			pages.append(Vector2i.ZERO)
			shelf_x = 0
			shelf_y = 0
			shelf_h = 0
			used = Vector2i.ZERO
		placements[index] = [page, shelf_x, shelf_y]
		shelf_x += cell.x
		shelf_h = maxi(shelf_h, cell.y)
		used = Vector2i(maxi(used.x, shelf_x), maxi(used.y, shelf_y + shelf_h))
	if page >= 0: pages[page] = used
	return {"placements":placements, "pages":pages}

## Writes a cooked actor. `index` is the in-memory index without "pages";
## `pages` are Images (RGBA8 or block compressed). Returns {ok, bytes, error}.
static func write(path: String, index: Dictionary, pages: Array) -> Dictionary:
	var blobs: Array[PackedByteArray] = []
	var page_entries: Array = []
	var offset: int = 0
	for image: Image in pages:
		var raw: PackedByteArray = image.get_data()
		var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_ZSTD)
		page_entries.append({"w":image.get_width(),"h":image.get_height(),"format":int(image.get_format()),"offset":offset,"bytes":packed.size(),"raw":raw.size()})
		blobs.append(packed)
		offset += packed.size()
	var stored: Dictionary = index.duplicate()
	stored["format"] = FORMAT
	stored["pages"] = page_entries
	var raw_index: PackedByteArray = var_to_bytes(stored)
	var packed_index: PackedByteArray = raw_index.compress(FileAccess.COMPRESSION_ZSTD)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"cooked_actor_unwritable"}
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(FILE_VERSION)
	file.store_32(packed_index.size())
	file.store_32(raw_index.size())
	file.store_buffer(packed_index)
	for blob: PackedByteArray in blobs: file.store_buffer(blob)
	var length: int = file.get_position()
	file.close()
	return {"ok":true,"bytes":length}

## Reads the index of a cooked actor file. Returns {ok, index, data_start} or
## {ok:false, error}. Page pixels are read by read_pages().
static func read_index(file: FileAccess) -> Dictionary:
	if file == null or file.get_length() < 16: return {"ok":false,"error":"cooked_actor_missing"}
	if file.get_buffer(4).get_string_from_ascii() != MAGIC or file.get_32() != FILE_VERSION: return {"ok":false,"error":"cooked_actor_header"}
	var packed_size: int = file.get_32()
	var raw_size: int = file.get_32()
	if packed_size <= 0 or raw_size <= 0 or raw_size > MAX_INDEX_BYTES or 16 + packed_size > file.get_length(): return {"ok":false,"error":"cooked_actor_index_size"}
	var raw: PackedByteArray = file.get_buffer(packed_size).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size: return {"ok":false,"error":"cooked_actor_index_corrupt"}
	var index: Variant = bytes_to_var(raw)
	if not index is Dictionary or index.get("format") != FORMAT: return {"ok":false,"error":"cooked_actor_format"}
	if not index.get("pages") is Array or not index.get("images") is PackedInt32Array or not index.get("states") is Array or not index.get("entries") is Array or not index.get("colors") is PackedFloat32Array: return {"ok":false,"error":"cooked_actor_index_shape"}
	return {"ok":true,"index":index,"data_start":16 + packed_size}

## Bytes of one mip level in the page formats a cooked file may hold; -1 else.
static func data_size(width: int, height: int, format: int) -> int:
	var blocks: int = ((width + 3) / 4) * ((height + 3) / 4)
	match format:
		Image.FORMAT_RGBA8: return width * height * 4
		Image.FORMAT_ETC2_RGBA8, Image.FORMAT_ASTC_4x4: return blocks * 16
		Image.FORMAT_ETC2_RGB8, Image.FORMAT_ETC2_RGB8A1, Image.FORMAT_ETC: return blocks * 8
	return -1

static func read_pages(file: FileAccess, index: Dictionary, data_start: int) -> Dictionary:
	var images: Array[Image] = []
	for entry: Variant in index.pages:
		if not entry is Dictionary: return {"ok":false,"error":"cooked_actor_page_entry"}
		var size: int = int(entry.get("bytes", 0))
		var raw_size: int = int(entry.get("raw", 0))
		var start: int = data_start + int(entry.get("offset", -1))
		if size <= 0 or raw_size <= 0 or raw_size > MAX_PAGE_BYTES or start < data_start or start + size > file.get_length(): return {"ok":false,"error":"cooked_actor_page_range"}
		file.seek(start)
		var raw: PackedByteArray = file.get_buffer(size).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
		var width: int = int(entry.get("w", 0))
		var height: int = int(entry.get("h", 0))
		var format: int = int(entry.get("format", -1))
		if raw.size() != raw_size or width <= 0 or height <= 0 or format < 0 or format >= Image.FORMAT_MAX: return {"ok":false,"error":"cooked_actor_page_corrupt"}
		if data_size(width, height, format) != raw_size: return {"ok":false,"error":"cooked_actor_page_size"}
		var image: Image = Image.create_from_data(width, height, false, format, raw)
		if image == null or image.is_empty(): return {"ok":false,"error":"cooked_actor_page_image"}
		images.append(image)
	return {"ok":true,"images":images}
