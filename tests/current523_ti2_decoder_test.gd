extends SceneTree
## Synthetic grammar checks and optional exact private TI2-to-PNG comparison.
## Coverage alpha is a display hypothesis; native M rendering remains UNKNOWN.
const DECODER = preload("res://scripts/maps/current523_ti2_decoder.gd")
const PACK = preload("res://scripts/maps/current523_tile_pack.gd")
const RGBA_BYTES = 384 * 384 * 4
const MAX_BYTES = 8 * 1024 * 1024
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _hash(encoded: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not encoded.is_empty(): context.update(encoded)
	return context.finish().hex_encode()

func _reject_raw(decoder: RefCounted, raw: PackedByteArray, row: Dictionary, label: String) -> void:
	var rgba: PackedByteArray = decoder.decode_raw_rgba(raw, row)
	check(rgba.is_empty() and not str(decoder.problem).is_empty(), "raw rejects with problem: " + label)

func _reject_source(decoder: RefCounted, source: PackedByteArray, row: Dictionary, label: String) -> void:
	var rgba: PackedByteArray = decoder.decode_rgba(source, row)
	check(rgba.is_empty() and not str(decoder.problem).is_empty(), "source rejects with problem: " + label)

func _pixel(rgba: PackedByteArray, x: int, y: int) -> PackedByteArray:
	var start: int = (y * 384 + x) * 4
	return rgba.slice(start, start + 4)

func _sample_commandwise(rgba: PackedByteArray) -> void:
	if rgba.size() != RGBA_BYTES: return
	check(_pixel(rgba, 1, 2) == PackedByteArray([0, 0, 0, 255]), "stored index0 black retains alpha255")
	check(_pixel(rgba, 2, 2) == PackedByteArray([255, 255, 255, 255]), "stored white retains alpha255")
	check(_pixel(rgba, 4, 2) == PackedByteArray([255, 0, 0, 255]), "command skip is relative to preceding span")
	check(_pixel(rgba, 4, 4) == PackedByteArray([0, 255, 0, 255]), "row step follows write and zero-count skip advances x")
	check(_pixel(rgba, 3, 5) == PackedByteArray([0, 0, 0, 255]), "zero-count row step resets origin and unknown span bit is ignored")
	check(_pixel(rgba, 1, 3) == PackedByteArray([0, 0, 0, 0]), "unstored pixels remain transparent")
	check(_pixel(rgba, 46, 0) == PackedByteArray([0, 255, 0, 255]) and _pixel(rgba, 24, 0)[3] == 0, "implicit right triangle starts at right edge")
	check(_pixel(rgba, 48, 0) == PackedByteArray([255, 0, 0, 255]) and _pixel(rgba, 71, 0)[3] == 0, "implicit left triangle starts at left edge")
	check(_pixel(rgba, 24, 11)[3] == 255 and _pixel(rgba, 47, 11)[3] == 255 and _pixel(rgba, 48, 11)[3] == 255 and _pixel(rgba, 71, 11)[3] == 255, "implicit triangles reach full row11")
	check(_pixel(rgba, 46, 22)[3] == 255 and _pixel(rgba, 48, 22)[3] == 255 and _pixel(rgba, 46, 23)[3] == 0 and _pixel(rgba, 48, 23)[3] == 0, "implicit triangles end at row22")
	check(_pixel(rgba, 383, 383) == PackedByteArray([0, 0, 0, 255]), "physical block255 maps to atlas lower-right endpoint")

func _metadata_rejections(decoder: RefCounted, raw: PackedByteArray, source: PackedByteArray, row: Dictionary) -> void:
	for kind: String in ["source_size", "source_sha", "source_empty", "source_oversize_metadata", "source_size_boolean"]:
		var changed: Dictionary = row.duplicate(true)
		var encoded: PackedByteArray = source
		match kind:
			"source_size": changed.source_bytes += 1
			"source_sha": changed.source_sha256 = "0".repeat(64)
			"source_empty": encoded = PackedByteArray()
			"source_oversize_metadata": changed.source_bytes = MAX_BYTES + 1
			"source_size_boolean": changed.source_bytes = true
		_reject_source(decoder, encoded, changed, kind)
	# These inputs are deliberately not passed to Brotli: source hash/size must
	# reject them first, without invoking a native malformed-stream error path.
	var corrupted: PackedByteArray = source.duplicate()
	corrupted[0] ^= 1
	_reject_source(decoder, corrupted, row, "changed compressed byte before native decompression")
	for kind: String in ["decoded_size", "decoded_sha", "decoded_zero", "decoded_oversize", "decoded_boolean", "header", "palette_colors", "palette_digest", "rgba_digest", "stored_pixels", "blocks", "atlas_size", "roundtrip", "section_gap", "section_overflow", "missing_section", "extra_section"]:
		var changed: Dictionary = row.duplicate(true)
		match kind:
			"decoded_size": changed.decoded_bytes += 1
			"decoded_sha": changed.decoded_sha256 = "0".repeat(64)
			"decoded_zero": changed.decoded_bytes = 0
			"decoded_oversize": changed.decoded_bytes = MAX_BYTES + 1
			"decoded_boolean": changed.decoded_bytes = true
			"header": changed.raw_header_u32 = int(changed.raw_header_u32) ^ 0x80000000
			"palette_colors": changed.palette_colors += 1
			"palette_digest": changed.palette_u16le_sha256 = "0".repeat(64)
			"rgba_digest": changed.atlas_rgba_sha256 = "0".repeat(64)
			"stored_pixels": changed.stored_pixels += 1
			"blocks": changed.blocks = 255
			"atlas_size": changed.atlas_size = [383, 384]
			"roundtrip": changed.raw_decoded_roundtrip = false
			"section_gap": changed.raw_sections.flags.offset += 1
			"section_overflow": changed.raw_sections.indices.bytes = MAX_BYTES + 1
			"missing_section": changed.raw_sections.erase("flags")
			"extra_section": changed.raw_sections.extra = {"offset": 0, "bytes": 0, "sha256": "0".repeat(64)}
		_reject_raw(decoder, raw, changed, kind)
	for section_name: String in ["header", "palette", "flags", "descriptors", "indices"]:
		var changed: Dictionary = row.duplicate(true)
		changed.raw_sections[section_name].sha256 = "0".repeat(64)
		_reject_raw(decoder, raw, changed, "section SHA256: " + section_name)
	# Both compressed metadata bounds must reject before allocating a native
	# output buffer, even when the compressed bytes and their hash are valid.
	for decoded_size: Variant in [0, MAX_BYTES + 1, true]:
		var changed: Dictionary = row.duplicate(true)
		changed.decoded_bytes = decoded_size
		_reject_source(decoder, source, changed, "native output bound metadata " + str(decoded_size))
	var recovered: PackedByteArray = decoder.decode_raw_rgba(raw, row)
	check(recovered.size() == RGBA_BYTES and str(decoder.problem).is_empty(), "valid decode clears a previous problem")

func _synthetic(root: String, expected_sha: String) -> Dictionary:
	var counts := {"valid": 0, "invalid": 0}
	var encoded: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join("fixtures.json"))
	check(encoded.size() > 0 and encoded.size() <= 256 * 1024, "small explicit synthetic fixture manifest exists")
	if not expected_sha.is_empty(): check(_hash(encoded) == expected_sha, "synthetic fixture caller SHA256 matches")
	var fixture: Variant = JSON.parse_string(encoded.get_string_from_utf8())
	check(fixture is Dictionary and fixture.get("schema") == 1 and fixture.get("kind") == "SYNTHETIC_NOT_ORIGINAL_EVIDENCE", "fixture is explicitly synthetic, separate from original evidence")
	if not fixture is Dictionary or not fixture.get("cases") is Array: return counts
	var decoder := DECODER.new()
	for value: Dictionary in fixture.cases:
		var name: String = str(value.name)
		var row: Dictionary = value.row
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join(str(value.raw_path)))
		var source: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join(str(value.compressed_path)))
		if not bool(value.valid):
			_reject_raw(decoder, raw, row, name)
			counts.invalid += 1
			continue
		var expected: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join(str(value.rgba_path)))
		check(expected.size() == RGBA_BYTES and _hash(expected) == row.atlas_rgba_sha256, "Python expected coverage bytes pinned: " + name)
		var from_raw: PackedByteArray = decoder.decode_raw_rgba(raw, row)
		check(from_raw == expected and str(decoder.problem).is_empty(), "raw equals exact Python RGBA: " + name + " " + str(decoder.problem))
		var from_source: PackedByteArray = decoder.decode_rgba(source, row)
		check(from_source == expected and str(decoder.problem).is_empty(), "bounded native Brotli equals exact Python RGBA: " + name + " " + str(decoder.problem))
		if name == "commandwise_unknown_bits_and_triangles":
			_sample_commandwise(from_raw)
			_metadata_rejections(decoder, raw, source, row)
		counts.valid += 1
	check(counts.valid == 4 and counts.invalid == 16, "all expected synthetic fixture cases executed")
	return counts

func _runtime_cache(pack: RefCounted, root: String, rows: Array) -> Dictionary:
	var metrics := {"cold_members": 0, "cold_elapsed_usec": 0, "cached_hits": 0, "cached_hits_elapsed_usec": 0, "atlas_loads_before_reset": 0, "cache_size_before_reset": 0}
	check(rows.size() >= 35, "actual runtime cache exercise has at least35 source members")
	if rows.size() < 35: return metrics
	var cold_start: int = Time.get_ticks_usec()
	for index: int in range(35):
		check(pack.texture_for(int(rows[index].tile_id)) != null, "actual runtime TI2 texture loads: " + str(rows[index].member) + " " + str(pack.problem))
	metrics.cold_elapsed_usec = Time.get_ticks_usec() - cold_start
	metrics.cold_members = 35
	check(pack.cache_size() == 32 and int(pack.atlas_loads) == 35, "actual runtime branch holds32 atlases after35 cold loads")
	var last_id: int = int(rows[34].tile_id)
	var prior_loads: int = int(pack.atlas_loads)
	check(pack.texture_for(last_id) != null and int(pack.atlas_loads) == prior_loads, "actual runtime last atlas cache hit avoids decoding")
	var hits_start: int = Time.get_ticks_usec()
	var hits_ok: bool = true
	for index: int in range(1000):
		if pack.texture_for(last_id) == null: hits_ok = false
	metrics.cached_hits_elapsed_usec = Time.get_ticks_usec() - hits_start
	metrics.cached_hits = 1000
	check(hits_ok and int(pack.atlas_loads) == prior_loads and pack.cache_size() == 32, "1000 actual cached texture hits avoid atlas reloads")
	check(pack.texture_for(int(rows[0].tile_id)) != null and int(pack.atlas_loads) == prior_loads + 1 and pack.cache_size() == 32, "actual runtime evicted first atlas reloads within32-entry bound")
	metrics.atlas_loads_before_reset = int(pack.atlas_loads)
	metrics.cache_size_before_reset = pack.cache_size()
	check(not pack.load_pack(root, "0".repeat(64)) and not bool(pack.loaded) and pack.cache_size() == 0 and int(pack.atlas_loads) == 0 and not pack.has_tile(last_id), "bad manifest pin resets actual runtime registry and cache")
	return metrics

func _actual(runtime_root: String, runtime_sha: String, reference_root: String, reference_sha: String) -> Dictionary:
	var counts := {"members": 0, "compressed_bytes": 0, "rgba_bytes_compared": 0, "elapsed_ms": 0, "runtime_cache": {}}
	var runtime_pack := PACK.new()
	var reference_pack := PACK.new()
	check(runtime_pack.load_pack(runtime_root, runtime_sha), "caller-pinned runtime TI2 pack metadata: " + runtime_pack.problem)
	check(reference_pack.load_pack(reference_root, reference_sha), "caller-pinned reference PNG pack metadata: " + reference_pack.problem)
	if not runtime_pack.loaded or not reference_pack.loaded: return counts
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(runtime_root.path_join(PACK.MANIFEST_NAME)))
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference_root.path_join(PACK.MANIFEST_NAME)))
	check(runtime.get("atlas_storage") == "runtime_ti2", "actual comparison explicitly uses runtime TI2 storage")
	check(reference.get("atlas_storage", "png") == "png", "actual comparison reference uses PNG storage")
	check(runtime.source_count == reference.source_count and runtime.source_inventory_sha256 == reference.source_inventory_sha256 and runtime.atlas_rgba_inventory_sha256 == reference.atlas_rgba_inventory_sha256 and runtime.raw_model_inventory_sha256 == reference.raw_model_inventory_sha256, "runtime and PNG manifests pin identical source, raw model and RGBA inventories")
	var by_member: Dictionary = {}
	for row: Dictionary in reference.tiles: by_member[str(row.member)] = row
	var decoder := DECODER.new()
	var comparison_start: int = Time.get_ticks_msec()
	for row: Dictionary in runtime.tiles:
		var member: String = str(row.member)
		check(by_member.has(member), "reference member exists: " + member)
		if not by_member.has(member): continue
		var reference_row: Dictionary = by_member[member]
		check(row.source_sha256 == reference_row.source_sha256 and row.decoded_sha256 == reference_row.decoded_sha256 and row.atlas_rgba_sha256 == reference_row.atlas_rgba_sha256, "actual row source/decoded/RGBA pins agree: " + member)
		check(not row.has("atlas_path") and not row.has("atlas_bytes") and not row.has("atlas_sha256"), "runtime row omits PNG storage metadata: " + member)
		var source: PackedByteArray = FileAccess.get_file_as_bytes(runtime_root.path_join(str(row.original_path)))
		var rgba: PackedByteArray = decoder.decode_rgba(source, row)
		check(rgba.size() == RGBA_BYTES and _hash(rgba) == row.atlas_rgba_sha256, "actual pinned original generates expected coverage: " + member + " " + str(decoder.problem))
		var png: PackedByteArray = FileAccess.get_file_as_bytes(reference_root.path_join(str(reference_row.atlas_path)))
		check(png.size() == int(reference_row.atlas_bytes) and _hash(png) == reference_row.atlas_sha256 and PACK.bounded_png_header(png), "reference PNG bytes and layout pinned: " + member)
		var image := Image.new()
		var image_ok: bool = image.load_png_from_buffer(png) == OK and image.get_size() == Vector2i(384, 384)
		check(image_ok, "reference PNG decodes: " + member)
		if not image_ok: continue
		image.convert(Image.FORMAT_RGBA8)
		var expected: PackedByteArray = image.get_data()
		check(_hash(expected) == reference_row.atlas_rgba_sha256 and rgba == expected, "actual TI2 RGBA equals reference PNG RGBA byte-for-byte: " + member)
		counts.members += 1
		counts.compressed_bytes += source.size()
		counts.rgba_bytes_compared += expected.size()
		if int(counts.members) % 100 == 0:
			print("CURRENT523_RUNTIME_TI2_COMPARE_PROGRESS " + JSON.stringify({"members": counts.members, "total": runtime.source_count, "elapsed_ms": Time.get_ticks_msec() - comparison_start}))
	counts.elapsed_ms = Time.get_ticks_msec() - comparison_start
	check(counts.members == int(runtime.source_count), "every runtime source member compared exactly once")
	counts.runtime_cache = _runtime_cache(runtime_pack, runtime_root, runtime.tiles)
	return counts

func _actual_inventory(runtime_root: String, runtime_sha: String) -> Dictionary:
	# The independent Python builder pins every coverage hash. This mode checks
	# all originals against those hashes without pretending that PNGs exist.
	var counts := {"members":0,"compressed_bytes":0,"rgba_bytes_compared":0,"elapsed_ms":0,"runtime_cache":{}}
	var pack := PACK.new()
	check(pack.load_pack(runtime_root,runtime_sha),"full caller-pinned runtime inventory: "+pack.problem)
	if not pack.loaded: return counts
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(runtime_root.path_join(PACK.MANIFEST_NAME)))
	check(manifest.get("atlas_storage")=="runtime_ti2","full inventory uses original TI2 storage")
	var decoder:=DECODER.new()
	var started: int=Time.get_ticks_msec()
	for row: Dictionary in manifest.tiles:
		var source: PackedByteArray=FileAccess.get_file_as_bytes(runtime_root.path_join(str(row.original_path)))
		var rgba: PackedByteArray=decoder.decode_rgba(source,row)
		check(rgba.size()==RGBA_BYTES and _hash(rgba)==row.atlas_rgba_sha256,"cross-language original coverage hash: "+str(row.member)+" "+str(decoder.problem))
		check(pack.has_subimage(int(row.tile_id),int(row.blocks)-1) and not pack.has_subimage(int(row.tile_id),int(row.blocks)),"physical last frame exists and padding is unavailable: "+str(row.member))
		counts.members+=1; counts.compressed_bytes+=source.size(); counts.rgba_bytes_compared+=rgba.size()
		if counts.members%500==0: print("CURRENT523_RUNTIME_TI2_INVENTORY_PROGRESS ",counts.members,"/",manifest.source_count)
	counts.elapsed_ms=Time.get_ticks_msec()-started
	check(counts.members==int(manifest.source_count),"every member in full inventory decoded")
	counts.runtime_cache=_runtime_cache(pack,runtime_root,manifest.tiles)
	return counts

func _initialize() -> void:
	var fixture_root: String = ""
	var fixture_sha: String = ""
	var runtime_root: String = ""
	var runtime_sha: String = ""
	var reference_root: String = ""
	var reference_sha: String = ""
	var verify_inventory: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ti2-decoder-fixture="): fixture_root = arg.trim_prefix("--ti2-decoder-fixture=")
		if arg.begins_with("--ti2-decoder-fixture-sha="): fixture_sha = arg.trim_prefix("--ti2-decoder-fixture-sha=")
		if arg.begins_with("--runtime-ti2-pack="): runtime_root = arg.trim_prefix("--runtime-ti2-pack=")
		if arg.begins_with("--runtime-ti2-pack-sha="): runtime_sha = arg.trim_prefix("--runtime-ti2-pack-sha=")
		if arg.begins_with("--reference-png-pack="): reference_root = arg.trim_prefix("--reference-png-pack=")
		if arg.begins_with("--reference-png-pack-sha="): reference_sha = arg.trim_prefix("--reference-png-pack-sha=")
		if arg=="--verify-runtime-inventory": verify_inventory=true
	check(not fixture_root.is_empty(), "focused runtime decoder test requires an explicit synthetic fixture root")
	var synthetic := {"valid": 0, "invalid": 0}
	if not fixture_root.is_empty(): synthetic = _synthetic(fixture_root, fixture_sha)
	var actual := {"members": 0, "compressed_bytes": 0, "rgba_bytes_compared": 0, "elapsed_ms": 0, "runtime_cache": {}}
	if verify_inventory:
		check(not runtime_root.is_empty() and not runtime_sha.is_empty() and reference_root.is_empty() and reference_sha.is_empty(),"inventory-only mode explicitly selects runtime inputs")
		if not runtime_root.is_empty() and not runtime_sha.is_empty(): actual=_actual_inventory(runtime_root,runtime_sha)
	elif not runtime_root.is_empty() or not reference_root.is_empty():
		check(not runtime_root.is_empty() and not reference_root.is_empty() and not runtime_sha.is_empty() and not reference_sha.is_empty(), "actual comparison requires both roots and caller manifest pins")
		if not runtime_root.is_empty() and not reference_root.is_empty() and not runtime_sha.is_empty() and not reference_sha.is_empty(): actual = _actual(runtime_root, runtime_sha, reference_root, reference_sha)
	print("CURRENT523_RUNTIME_TI2_DECODER_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_valid_cases": synthetic.valid, "synthetic_invalid_cases": synthetic.invalid, "real_source_members": actual.members, "real_compressed_bytes": actual.compressed_bytes, "real_rgba_bytes_compared": actual.rgba_bytes_compared, "real_comparison_elapsed_ms": actual.elapsed_ms, "runtime_cache": actual.runtime_cache, "duplicate_raw_write_fixture": "UNREACHABLE_UNSIGNED_MONOTONIC_COMMANDS", "native_M_alpha_verified": false, "native_M_rendering_verified": false}))
	quit(0 if failures.is_empty() else 1)
