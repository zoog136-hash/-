extends SceneTree
const PACK = preload("res://scripts/maps/current523_aden_pack.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	var pack = PACK.new()
	check(not pack.load_pack("/nonexistent/twilight-aden523-pack"), "missing private pack must reject")
	check(not pack.loaded and pack.source_members().is_empty(), "missing pack leaves no registry")
	var bytes := PackedByteArray()
	bytes.resize(49166)
	bytes.fill(0)
	bytes.encode_u32(0, 0xffffffff)
	var sections: Dictionary = PACK.scan_sections(bytes)
	check(not sections.is_empty(), "bounded zero-count raw layout parses")
	check(bytes.decode_u32(0) == 4294967295, "packed reference preserves unsigned u32")
	check(sections.get("attributes", {}).get("offset") == 32770, "attribute offset follows cover count header")
	check(sections.get("tail", {}).get("bytes") == 0, "empty opaque tail is distinct from invented effect count")
	for size: int in [0, 32768, 49153, 49157, 49161, 49165]:
		check(PACK.scan_sections(bytes.slice(0, size)).is_empty(), "truncation rejects at " + str(size))
	var bad: PackedByteArray = bytes.duplicate()
	bad.encode_u16(32768, 65535)
	check(PACK.scan_sections(bad).is_empty(), "cover count cannot run past EOF")
	bad = bytes.duplicate()
	bad.encode_u32(49154, 0xffffffff)
	check(PACK.scan_sections(bad).is_empty(), "huge object group count rejects before iteration")
	bad = bytes.duplicate()
	bad.encode_u32(49158, 0xffffffff)
	check(PACK.scan_sections(bad).is_empty(), "huge opacity count rejects")
	bad = bytes.duplicate()
	bad.encode_u32(49162, 0xffffffff)
	check(PACK.scan_sections(bad).is_empty(), "huge declaration count rejects")
	check(not PACK._member_name("Map/13225/800a8000.s32"), "world siege asset root cannot become Aden")
	check(not PACK._member_name("Map/Aden/../800a8000.s32"), "parent traversal rejects")
	check(PACK._member_name("Map/Aden/800f7ff3e.s32"), "nonstandard literal filename preserved")
	check(not PACK._uint(1.25, 5) and not PACK._uint(true, 5), "counts cannot be fractional or boolean")
	var pack_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aden523-pack="): pack_path = arg.trim_prefix("--aden523-pack=")
	var consumed: int = 0
	var consumed_bytes: int = 0
	if not pack_path.is_empty():
		check(pack.load_pack(pack_path), "real current523 pack accepts: " + pack.problem)
		if pack.loaded:
			check(pack.source_members().size() == 677, "all original literal members registered")
			for member: String in pack.source_members():
				var row: Dictionary = pack.read_member(member)
				check(not row.is_empty(), "source read: " + member + " " + pack.problem)
				if row.is_empty(): continue
				var reconstructed := PackedByteArray()
				for name: String in PACK.SECTION_NAMES: reconstructed.append_array(row.sections[name])
				check(PACK._hash(reconstructed) == row.source_sha256, "Godot exact byte reassembly: " + member)
				consumed += 1
				consumed_bytes += reconstructed.size()
			check(pack.source_metadata("Map/Aden/800a8000.s32").get("sha256") == "ab3b89eb4a9be8b2b5448c60bcf4c7ac6d4164ada21d85f88ffc7f566e9b2b96", "changed523 source anchor")
			check(pack.source_members().has("Map/Aden/800f7ff3e.s32"), "unplaced nonstandard source not discarded")
			check(pack.read_member("Map/13225/800a8000.s32").is_empty(), "same basename from different Land rejected")
			var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_path.path_join("aden523.json")))
			var mutation_root: String = ProjectSettings.globalize_path("user://aden523-manifest-rejections")
			DirAccess.make_dir_recursive_absolute(mutation_root)
			for kind: String in ["wrong_land", "base508", "wrong_edition", "invented_collision", "duplicate", "missing_member", "wrong_path", "bad_offset", "stale_hash", "fractional_version", "boolean_schema", "floor_count_array", "attribute_count_dictionary", "tail_count"]:
				var changed: Dictionary = original.duplicate(true)
				match kind:
					"wrong_land": changed.land_id = 45194
					"base508": changed.cumulative_version = 508
					"wrong_edition": changed.edition = "LineageM_base508"
					"invented_collision": changed.semantics.collision = "OPEN"
					"duplicate": changed.members[1] = changed.members[0].duplicate(true)
					"missing_member": changed.members.pop_back()
					"wrong_path": changed.members[0].path = "../outside.s32"
					"bad_offset": changed.members[0].sections.attributes.offset += 2
					"stale_hash": changed.members[0].sha256 = "0".repeat(64)
					"fractional_version": changed.cumulative_version = 523.5
					"boolean_schema": changed.schema = true
					"floor_count_array": changed.members[0].sections.floor.count = []
					"attribute_count_dictionary": changed.members[0].sections.attributes.count = {}
					"tail_count": changed.members[0].sections.tail.count = 1
				var output := FileAccess.open(mutation_root.path_join("aden523.json"), FileAccess.WRITE)
				output.store_string(JSON.stringify(changed))
				output.close()
				var probe = PACK.new()
				check(not probe.load_pack(mutation_root) and not probe.loaded and probe.source_members().is_empty() and not probe.problem.begins_with("Missing or wrong-sized Aden source"), "manifest metadata rejects before file access: " + kind)
	print("CURRENT523_ADEN_PACK_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "real_members_consumed": consumed, "real_source_bytes": consumed_bytes, "rendering_verified": false, "movement_verified": false}))
	quit(0 if failures.is_empty() else 1)
