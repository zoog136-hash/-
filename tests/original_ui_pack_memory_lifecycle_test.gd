extends SceneTree
## Synthetic pack and real scene owners: bounds cache ownership while active
## sprites, TTF labels and bitmap glyphs retain their exact source resources.
## All writes live in a unique user:// test fixture; installed packs/saves and
## device bake files are never removed. Payload counters are not RSS/GPU.
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const PAGES = preload("res://scripts/ui/original_ui/source_pack_page_cache.gd")
const BITMAP_TEXT = preload("res://scripts/ui/original_ui/source_bitmap_text.gd")
const ATLAS = preload("res://scripts/ui/original_ui/atlas_pixels.gd")
const PAGE_SIZE := Vector2i(64, 48)
const PAGE_BYTES: int = 64 * 48 * 4
const RESERVE: int = PAGE_BYTES * 2
const PAGE_COUNT: int = 32
const FRAME_REF: Dictionary = {"plistFile": "atlas.plist", "path": "trim"}
const TTF_REF: Dictionary = {"path": "fixture.ttf", "resourceType": 0}
const BITMAP_REF: Dictionary = {"path": "fixture.fnt", "resourceType": 0}
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func fixture(directory: String, variant: int) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(directory.path_join("originals/UI"))
	var files: Dictionary = {}
	for index: int in range(PAGE_COUNT):
		var image := Image.create(PAGE_SIZE.x, PAGE_SIZE.y, false, Image.FORMAT_RGBA8)
		for y: int in range(PAGE_SIZE.y):
			for x: int in range(PAGE_SIZE.x):
				image.set_pixel(x, y, Color8((x * 13 + index * 17 + variant) % 256, (y * 23 + index * 11) % 256, (x * y + variant * 7) % 256, [0, 1, 77, 128, 200, 255][(x + y) % 6]))
		image.save_png(directory.path_join("originals/UI/page_%d.png" % index))
	var descriptor: String = 'info face="Synthetic" size=12 unicode=1\ncommon lineHeight=12 base=10 scaleW=64 scaleH=48 pages=1 packed=0\npage id=0 file="page_1.png"\nchars count=3\nchar id=65 x=0 y=0 width=8 height=8 xoffset=0 yoffset=0 xadvance=9 page=0 chnl=15\nchar id=66 x=8 y=0 width=8 height=8 xoffset=0 yoffset=0 xadvance=9 page=0 chnl=15\nchar id=44032 x=16 y=0 width=8 height=8 xoffset=0 yoffset=0 xadvance=9 page=0 chnl=15\nkernings count=1\nkerning first=65 second=66 amount=-1\n'
	write_bytes(directory.path_join("originals/UI/fixture.fnt"), descriptor.to_utf8_buffer())
	write_bytes(directory.path_join("originals/UI/fixture.ttf"), FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansKR.ttf"))
	for index: int in range(PAGE_COUNT + 2):
		var member: String = "UI/page_%d.png" % index if index < PAGE_COUNT else ("UI/fixture.fnt" if index == PAGE_COUNT else "UI/fixture.ttf")
		var path: String = directory.path_join("originals/" + member)
		files[member] = {"sha256": FileAccess.get_sha256(path), "bytes": FileAccess.get_size(path)}
	var frame: Dictionary = {"rect": [4, 6, 8, 6], "source_rect": [3, 2, 8, 6], "source_size": [16, 12]}
	var manifest: Dictionary = {"schema": "twilight-original-ui-v1", "scenes": {}, "files": files, "blockers": [], "probe_variant": variant,
		"atlases": {"UI/atlas.plist": {"page": "UI/page_0.png", "frames": {"trim": frame}}}}
	var path: String = directory.path_join("original_ui.json")
	write_bytes(path, JSON.stringify(manifest).to_utf8_buffer())
	return {"root": directory, "sha": FileAccess.get_sha256(path), "files": files, "frame": frame}

func texture_fingerprint(texture: Texture2D) -> Dictionary:
	var image: Image = texture.get_image()
	return {"size": image.get_size(), "format": image.get_format(), "bytes": image.get_data(), "pma": texture.get_meta("cocos_premultiplied", null)}

func bitmap_fingerprint(bitmap: Node2D) -> Dictionary:
	var descriptor: Dictionary = bitmap._font_data.duplicate(true)
	var page_hashes: Dictionary = {}
	for id: int in descriptor.page_textures:
		page_hashes[id] = texture_fingerprint(descriptor.page_textures[id])
	descriptor.erase("page_textures")
	return {"descriptor": descriptor, "pages": page_hashes, "native_size": bitmap.native_size, "text": bitmap._options.text}

func window_fingerprint(window: Dictionary) -> Dictionary:
	var font: FontFile = window.label.get_theme_font("font") as FontFile
	return {"texture": texture_fingerprint(window.sprite.texture), "bitmap": bitmap_fingerprint(window.bitmap),
		"label": {"text": window.label.text, "font_bytes_sha": digest(font.data), "supported_chars": font.get_supported_chars(), "minimum_size": window.label.get_minimum_size()}}

func make_window(pack: RefCounted, title: String) -> Dictionary:
	var owner := Control.new()
	owner.name = title
	root.add_child(owner)
	var sprite := Sprite2D.new()
	sprite.texture = pack.texture(FRAME_REF, true)
	owner.add_child(sprite)
	var label := Label.new()
	label.text = "AB가"
	label.add_theme_font_override("font", pack.font(TTF_REF))
	owner.add_child(label)
	var bitmap := BITMAP_TEXT.new()
	var loaded: Dictionary = pack.bitmap_font(BITMAP_REF)
	check(loaded.get("ok", false), "bitmap descriptor and exact page load: " + title)
	owner.add_child(bitmap)
	var configured: Dictionary = bitmap.configure(loaded.get("font_data", {}), {"text": "AB가"}, Vector2(80, 20))
	check(configured.get("ok", false), "real SourceBitmapText owns exact glyph pages: " + title)
	return {"owner": owner, "sprite": sprite, "label": label, "bitmap": bitmap}

func close_window(window: Dictionary) -> void:
	window.owner.queue_free()
	await process_frame
	await process_frame

func pressure(pack: RefCounted) -> void:
	for index: int in range(PAGE_COUNT):
		var texture: Texture2D = pack.texture({"path": "page_%d.png" % index, "resourceType": 0}, true)
		check(texture != null, "distinct verified page decodes under pressure: " + str(index))

func has_object(value: Variant) -> bool:
	if value is Object: return true
	if value is Dictionary:
		for nested: Variant in value.values():
			if has_object(nested): return true
	elif value is Array:
		for nested: Variant in value:
			if has_object(nested): return true
	return false

func check_bounds(pack: RefCounted, entries: int, label: String) -> void:
	var stats: Dictionary = pack.cache_stats()
	var textures: Dictionary = stats.instance_texture_cache
	check(int(textures.resident_decoded_bytes_estimate) <= RESERVE and int(textures.tracked_entries) <= entries and int(stats.instance_textures) == int(textures.resident_entries), "texture bytes, metadata and resident count stay bounded: " + label)
	check(int(stats.instance_pages) == 0 and int(stats.instance_page_leases) == 0 and int(stats.live_leases) == 0 and int(stats.cache_owned_bytes) <= PAGES.budget_bytes, "closed owner releases CPU pages/leases to the page budget: " + label)
	for metadata: Dictionary in pack._bitmap_fonts.values():
		check(not metadata.has("page_textures") and not has_object(metadata), "bitmap metadata cache cannot retain page textures: " + label)

func verify_originals(data: Dictionary) -> bool:
	for member: String in data.files:
		var path: String = data.root.path_join("originals/" + member)
		if FileAccess.get_sha256(path) != data.files[member].sha256 or FileAccess.get_size(path) != data.files[member].bytes: return false
	return FileAccess.get_sha256(data.root.path_join("original_ui.json")) == data.sha

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var directory: String = "user://original_ui_pack_memory_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var first: Dictionary = fixture(directory.path_join("first"), 1)
	var second: Dictionary = fixture(directory.path_join("second"), 2)
	var prior_page_budget: int = PAGES.budget_bytes
	# This standalone synthetic process uses a small equivalent CPU-page budget
	# so bounded-ownership assertions need neither giant images nor cache wipes.
	PAGES.budget_bytes = RESERVE
	var pack: RefCounted = PACK.new()
	pack.configure_texture_cache(RESERVE, 64)
	check(pack.open(first.root, first.sha).get("ok", false), "exact synthetic pack opens")
	var one: Dictionary = make_window(pack, "FirstWindow")
	var two: Dictionary = make_window(pack, "SecondWindow")
	await process_frame
	await process_frame
	check(is_same(one.sprite.texture, two.sprite.texture), "simultaneous windows share one exact atlas texture")
	var original_window: Dictionary = window_fingerprint(two)
	check(original_window.label.supported_chars.contains("A") and original_window.label.supported_chars.contains("가") and original_window.bitmap.descriptor.glyphs.has(44032), "TTF and bitmap fixtures retain Latin and Korean characters")
	var source_page: Image = Image.load_from_file(first.root.path_join("originals/UI/page_0.png"))
	source_page.convert(Image.FORMAT_RGBA8)
	var independent: Image = PACK.cocos_premultiply(ATLAS.decode(source_page, first.frame).image)
	check(original_window.texture.bytes == independent.get_data() and original_window.texture.size == independent.get_size() and original_window.texture.pma == true, "trimmed atlas pixels, size and Cocos PMA flag equal independent decode")
	var frame_ref: WeakRef = weakref(two.sprite.texture)
	var bitmap_page_ref: WeakRef = weakref(two.bitmap._font_data.page_textures[0])
	var font_ref: WeakRef = weakref(two.label.get_theme_font("font"))
	await close_window(one)
	pack.release_cache_leases()
	pressure(pack)
	pack.release_cache_leases()
	check_bounds(pack, 64, "first window closed, second still open")
	check(window_fingerprint(two) == original_window, "closing one window and evicting cache reserves preserves the other's pixels, evidence, TTF and bitmap text")
	var before_hits: int = int(pack.cache_stats().instance_texture_cache.weak_hits)
	var reused: Texture2D = pack.texture(FRAME_REF, true)
	check(is_same(reused, two.sprite.texture) and int(pack.cache_stats().instance_texture_cache.weak_hits) > before_hits, "external strong owner permits exact weak-cache reuse after reserve eviction")
	reused = null
	var stable_metrics: Dictionary = pack.cache_stats().instance_texture_cache.duplicate()
	check(not pack.open(second.root, "0".repeat(64)).get("ok", true) and pack.root == first.root and pack.manifest_sha256 == first.sha and pack.cache_stats().instance_texture_cache == stable_metrics, "failed replacement preserves previous root, pin and complete texture-cache state")
	check(window_fingerprint(two) == original_window, "failed replacement leaves the other open window unchanged")
	check(pack.open(second.root, second.sha).get("ok", false), "verified replacement adopts the new pack")
	var adopted: Dictionary = pack.cache_stats()
	check(adopted.instance_textures == 0 and adopted.instance_texture_cache.tracked_entries == 0 and adopted.instance_fonts == 0 and adopted.instance_bitmap_font_metadata == 0, "successful adoption invalidates strong and weak cache identities and font caches")
	var replacement: Texture2D = pack.texture(FRAME_REF, true)
	check(not is_same(replacement, two.sprite.texture) and texture_fingerprint(replacement) != original_window.texture, "new pack identity produces its own exact pixels while an old window still holds its texture")
	replacement = null
	check(window_fingerprint(two) == original_window, "old active window's resources survive successful pack replacement")
	await close_window(two)
	pack.release_cache_leases()
	await process_frame
	check(frame_ref.get_ref() == null and bitmap_page_ref.get_ref() == null and font_ref.get_ref() == null, "old atlas texture, bitmap page and TTF die after their last external owner closes")
	pack.configure_texture_cache(RESERVE, 8)
	var cycle_counts: Array = []
	for cycle: int in range(4):
		var window: Dictionary = make_window(pack, "RepeatedWindow%d" % cycle)
		await process_frame
		var still_valid: Dictionary = window_fingerprint(window)
		pressure(pack)
		pack.release_cache_leases()
		check(window_fingerprint(window) == still_valid, "active repeated window survives metadata eviction and page release: " + str(cycle))
		await close_window(window)
		pack.release_cache_leases()
		check_bounds(pack, 8, "cycle " + str(cycle))
		var stats: Dictionary = pack.cache_stats()
		cycle_counts.append([stats.instance_texture_cache.resident_entries, stats.instance_texture_cache.tracked_entries, stats.instance_fonts, stats.instance_bitmap_font_metadata, stats.cache_owned_bytes])
	check(cycle_counts[1] == cycle_counts[2] and cycle_counts[2] == cycle_counts[3], "repeated open/close cycles plateau in resident, tracked, font and CPU-page counts")
	# Cache ownership may be dropped while a real active window still renders.
	var final_window: Dictionary = make_window(pack, "FinalWindow")
	await process_frame
	var final_pixels: Dictionary = window_fingerprint(final_window)
	var final_frame_ref: WeakRef = weakref(final_window.sprite.texture)
	var final_bitmap_ref: WeakRef = weakref(final_window.bitmap._font_data.page_textures[0])
	pack.configure_texture_cache(0, 8)
	pack.release_cache_leases()
	check(window_fingerprint(final_window) == final_pixels and final_frame_ref.get_ref() != null and final_bitmap_ref.get_ref() != null, "zero cache reserve preserves externally owned frame and bitmap resources")
	await close_window(final_window)
	await process_frame
	check(final_frame_ref.get_ref() == null and final_bitmap_ref.get_ref() == null, "evicted frames and bitmap pages die after the final window closes")
	check(verify_originals(first) and verify_originals(second), "all original fixture bytes, sizes and manifest pins remain unchanged")
	PAGES.budget_bytes = prior_page_budget
	print("ORIGINAL_UI_PACK_MEMORY_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "cycles": cycle_counts, "texture_budget_bytes": RESERVE, "synthetic_pages": PAGE_COUNT, "synthetic_only": true, "accounting": "decoded_payload_counters_not_rss_or_gpu"}))
	quit(0 if failures.is_empty() else 1)
