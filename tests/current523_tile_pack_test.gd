extends SceneTree
## Synthetic fixture checks and optional separately counted real source reads.
const PACK = preload("res://scripts/maps/current523_tile_pack.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _write_manifest(root: String, manifest: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(root)
	var encoded: PackedByteArray = (JSON.stringify(manifest, "\t") + "\n").to_utf8_buffer()
	var file := FileAccess.open(root.path_join(PACK.MANIFEST_NAME), FileAccess.WRITE)
	file.store_buffer(encoded)
	file.close()
	return PACK._hash(encoded)

func _rgba_inventory(rows: Array) -> String:
	var lines: Array[String] = []
	for row: Dictionary in rows: lines.append(str(row.member) + "\t" + str(row.atlas_rgba_sha256) + "\n")
	lines.sort()
	return "".join(lines).sha256_text()

func _store(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()

func _initialize() -> void:
	var pack = PACK.new()
	check(not pack.load_pack("/nonexistent/current523-tiles", ""), "empty manifest trust pin rejects")
	check(not pack.load_pack("/nonexistent/current523-tiles", "0".repeat(64)), "missing manifest rejects safely")
	check(not pack.loaded and pack.cache_size() == 0 and not pack.has_tile(0), "failed load leaves empty registry/cache")
	check(PACK.source_rect(0) == Rect2(0, 0, 24, 24) and PACK.source_rect(255) == Rect2(360, 360, 24, 24), "8bit frame endpoints")
	check(PACK.source_rect(-1) == Rect2() and PACK.source_rect(256) == Rect2(), "out-of-range frame rejects")
	check(not PACK._uint(true, 1) and not PACK._uint(1.5, 2) and not PACK._sha("F".repeat(64)), "bounded numeric/hash helper rejects boolean/fractional/uppercase")
	var fixture_root: String = ""
	var fixture_sha: String = ""
	var real_root: String = ""
	var real_sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tile523-fixture="): fixture_root = arg.trim_prefix("--tile523-fixture=")
		if arg.begins_with("--tile523-fixture-sha="): fixture_sha = arg.trim_prefix("--tile523-fixture-sha=")
		if arg.begins_with("--tile523-pack="): real_root = arg.trim_prefix("--tile523-pack=")
		if arg.begins_with("--tile523-pack-sha="): real_sha = arg.trim_prefix("--tile523-pack-sha=")
	check(not fixture_root.is_empty(), "focused runtime requires explicit synthetic fixture")
	if not fixture_root.is_empty():
		check(not pack.load_pack(fixture_root, "0".repeat(64)), "caller pin mismatch rejects before registry")
		check(pack.load_pack(fixture_root, fixture_sha), "synthetic generic subset accepts: " + pack.problem)
		if pack.loaded:
			check(pack.has_tile(0) and pack.has_tile(34) and not pack.has_tile(35), "flexible35-tile fixture registry")
			check(pack.texture_for(999) == null and pack.cache_size() == 0, "unresolved tile does not create fallback")
			for id: int in range(32): check(pack.texture_for(id) != null, "fixture source+PNG+RGBA verifies: " + str(id))
			check(pack.cache_size() == 32 and pack.atlas_loads == 32, "cache reaches32 verified atlases")
			check(pack.texture_for(0) != null and pack.atlas_loads == 32, "cache hit reuses verified texture")
			check(pack.texture_for(32) != null and pack.cache_size() == 32 and pack.atlas_loads == 33, "33rd atlas evicts oldest")
			check(pack.texture_for(0) != null and pack.atlas_loads == 33, "recently touched atlas stays cached")
			check(pack.texture_for(1) != null and pack.atlas_loads == 34 and pack.cache_size() == 32, "oldest untouched atlas reloads")
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_root.path_join(PACK.MANIFEST_NAME)))
		var mutation_root: String = ProjectSettings.globalize_path("user://generic-ti2-metadata-rejections")
		for kind: String in ["edition", "version", "count", "duplicate", "path", "provenance_edition", "provenance_version", "wrong_current_container", "wrong_member", "layout", "png_bytes", "raw_sections", "raw_header", "raw_roundtrip", "alpha", "source_inventory", "rgba_inventory", "whole_input_inventory", "atlas_storage", "runtime_with_png", "missing_png_metadata"]:
			var changed: Dictionary = original.duplicate(true)
			match kind:
				"edition": changed.edition = "PC"
				"version": changed.cumulative_version = 508
				"count": changed.source_count = true
				"duplicate": changed.tiles[1] = changed.tiles[0].duplicate(true)
				"path": changed.tiles[0].original_path = "../outside.ti2"
				"provenance_edition": changed.tiles[0].provenance.edition = "PC"
				"provenance_version": changed.tiles[0].provenance.snapshot_version = 508
				"wrong_current_container": changed.tiles[0].provenance.current_selected_dat_sha256 = "2".repeat(64)
				"wrong_member": changed.tiles[0].provenance.expected_member_sha256 = "2".repeat(64)
				"layout": changed.tiles[0].atlas_size = [4096, 4096]
				"png_bytes": changed.tiles[0].atlas_bytes = PACK.MAX_PNG_BYTES + 1
				"raw_sections": changed.tiles[0].raw_sections.flags.offset += 1
				"raw_header": changed.tiles[0].raw_header_u32 = 256
				"raw_roundtrip": changed.tiles[0].raw_decoded_roundtrip = false
				"alpha": changed.semantics.runtime_alpha = "BLACK_TRANSPARENT"
				"source_inventory": changed.source_inventory_sha256 = "0".repeat(64)
				"rgba_inventory": changed.atlas_rgba_inventory_sha256 = "0".repeat(64)
				"whole_input_inventory": changed.input_source_inventory_sha256 = "0".repeat(64)
				"atlas_storage": changed.atlas_storage = "invented"
				"runtime_with_png": changed.atlas_storage = "runtime_ti2"
				"missing_png_metadata": changed.tiles[0].erase("atlas_path")
			var changed_sha: String = _write_manifest(mutation_root, changed)
			check(not pack.load_pack(mutation_root, changed_sha) and not pack.loaded and pack.cache_size() == 0 and not pack.has_tile(0), "pinned invalid metadata rejects and resets: " + kind)
		var row: Dictionary = original.tiles[0]
		var original_source: PackedByteArray = FileAccess.get_file_as_bytes(fixture_root.path_join(row.original_path))
		var original_png: PackedByteArray = FileAccess.get_file_as_bytes(fixture_root.path_join(row.atlas_path))
		for kind: String in ["missing_original", "wrong_source_size", "wrong_source_hash", "missing_png", "wrong_png_hash", "wrong_rgba", "huge_png_header"]:
			var root: String = ProjectSettings.globalize_path("user://generic-ti2-byte-rejections/" + kind)
			var changed: Dictionary = original.duplicate(true)
			var source_bytes: PackedByteArray = original_source.duplicate()
			var png_bytes: PackedByteArray = original_png.duplicate()
			if kind == "wrong_source_size": source_bytes.resize(source_bytes.size() - 1)
			if kind == "wrong_source_hash": source_bytes[0] ^= 1
			if kind == "wrong_png_hash": png_bytes[png_bytes.size() - 1] ^= 1
			if kind == "wrong_rgba":
				changed.tiles[0].atlas_rgba_sha256 = "0".repeat(64)
				changed.atlas_rgba_inventory_sha256 = _rgba_inventory(changed.tiles)
			if kind == "huge_png_header":
				png_bytes[16] = 127
				changed.tiles[0].atlas_sha256 = PACK._hash(png_bytes)
			if kind != "missing_original": _store(root.path_join(row.original_path), source_bytes)
			if kind != "missing_png": _store(root.path_join(row.atlas_path), png_bytes)
			var changed_sha: String = _write_manifest(root, changed)
			check(pack.load_pack(root, changed_sha), "byte rejection fixture has valid metadata: " + kind)
			check(pack.texture_for(0) == null and pack.cache_size() == 0, "bad/missing bytes reject without caching: " + kind)
	var real_count: int = 0
	var real_bytes: int = 0
	if not real_root.is_empty():
		check(pack.load_pack(real_root, real_sha), "actual private generic TI2 subset accepts: " + pack.problem)
		if pack.loaded:
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(real_root.path_join(PACK.MANIFEST_NAME)))
			for row: Dictionary in manifest.tiles:
				check(pack.texture_for(int(row.tile_id)) != null, "actual original+coveragePNG+RGBA: " + row.member + " " + pack.problem)
				real_count += 1
				real_bytes += int(row.source_bytes)
			check(pack.cache_size() <= 32, "actual subset cache bounded")
	print("CURRENT523_GENERIC_TI2_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "synthetic_fixture":not fixture_root.is_empty(), "real_source_members":real_count, "real_compressed_bytes":real_bytes, "native_M_alpha_verified":false, "native_M_rendering_verified":false}))
	quit(0 if failures.is_empty() else 1)
