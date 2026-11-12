extends SceneTree
## Synthetic acceptance probe for the load_bank metadata memo. Run from a
## checkout containing the optimization:
## godot --headless --path <repo> --script res://tests/reference_sp2_load_memo_test.gd
## These invented FE files prove equivalence/integrity mechanics only.
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const ACTOR: int = 9001
const TOKENS: Array = [[0, 0, 3], [0, 1, 5], [0, 0, 2], [0, 1, 4]]
const BINDINGS: Dictionary = {"idle": 0, "attack": 3}
const LOOPS: Dictionary = {"idle": true, "attack": false}

class OptimizedBank:
	extends "res://scripts/resources/reference_sp2_bank.gd"
	var member_calls: int = 0
	var member_names: Dictionary = {}
	var memo_observations: int = 0
	var memo_is_compact: bool = true
	var pin_checks: int = 0
	func _pins_valid() -> bool:
		pin_checks += 1
		return super._pins_valid()
	func _member(member: String) -> Dictionary:
		member_calls += 1
		member_names[member] = int(member_names.get(member, 0)) + 1
		return super._member(member)
	func _load_layer_metadata(layer: Dictionary, memo: Dictionary) -> Dictionary:
		var result: Dictionary = super._load_layer_metadata(layer, memo)
		for entry: Dictionary in memo.values():
			memo_observations += 1
			var source: Dictionary = entry.get("source", {})
			var parsed: Dictionary = source.get("parsed", {})
			memo_is_compact = memo_is_compact and parsed.keys() == ["groups"]
			for forbidden: String in ["raw", "body", "blocks", "refs", "palette"]:
				memo_is_compact = memo_is_compact and not source.has(forbidden) and not parsed.has(forbidden)
			for group: Dictionary in parsed.get("groups", []):
				memo_is_compact = memo_is_compact and group.size() == 2 and group.has("bit") and group.has("frames")
				for frame: Dictionary in group.get("frames", []):
					memo_is_compact = memo_is_compact and frame.size() == 2 and frame.has("bounds") and frame.has("empty")
		return result

class LegacyBank:
	extends OptimizedBank
	func _load_layer_metadata(layer: Dictionary, _memo: Dictionary) -> Dictionary:
		return render_layer(layer, false)

class ChangedDuringMemoBank:
	extends OptimizedBank
	var change_path: String = ""
	var changed: bool = false
	func _load_layer_metadata(layer: Dictionary, memo: Dictionary) -> Dictionary:
		var result: Dictionary = super._load_layer_metadata(layer, memo)
		if result.get("ok", false) and not changed:
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(change_path)
			var file := FileAccess.open(change_path, FileAccess.WRITE)
			file.store_buffer(bytes + PackedByteArray([0]))
			file.close()
			changed = true
		return result

var checks: int = 0
var failures: Array[String] = []
var scratch: String = ""

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

func write_json(path: String, value: Dictionary) -> String:
	write_bytes(path, JSON.stringify(value).to_utf8_buffer())
	return FileAccess.get_sha256(path)

static func put16(out: PackedByteArray, value: int) -> void:
	out.append(value & 255)
	out.append((value >> 8) & 255)

## All selected groups have two stored frames. The shadow intentionally omits
## odd direction bits; clothes frame 1 is a legitimate empty frame at (-3,2).
static func make_sp2(mask: int, empty_second: bool = false) -> PackedByteArray:
	var out := PackedByteArray([254, 4])
	for word: int in [0xf800, 0x07e0, 0x001f, 0xffff]: put16(out, word)
	out.append(mask)
	var groups: int = 0
	for direction: int in range(8):
		if (mask & (1 << direction)) == 0: continue
		groups += 1
		out.append(2)
		for frame: int in range(2):
			var empty: bool = empty_second and frame == 1
			for value: int in ([-3, 2, -3, 2] if empty else [0, 0, 2, 2]): put16(out, value)
			put16(out, 0 if empty else 1)
			if not empty:
				out.append_array(PackedByteArray([0, 0, 0]))
				put16(out, 0) # Both nonempty frames reference this group's block 0.
		var count := PackedByteArray()
		count.resize(4)
		count.encode_s32(0, 1)
		out.append_array(count)
		out.append_array(PackedByteArray([0, 0, 2]))
		put16(out, (2 << 5) | (1 << 10))
		put16(out, 2 << 5)
	# SP2 places every group's metadata before all groups' sample streams.
	for direction: int in range(groups):
		out.append_array(PackedByteArray([direction % 4, 1, 2, 3]))
	return out

func contract() -> Dictionary:
	return {"format": "current523_identity_roles_v1", "native_dispatch_verified": false,
		"selection": "explicit_source_actor_id_and_source_action_id",
		"loop": "unknown_requires_explicit_caller_policy",
		"timing": "source_explicit_fps_and_duration_ticks_only",
		"frame_policy": "client_clamp_frame_null_missing_direction_or_empty_body"}

func source_action(action: int) -> Dictionary:
	var role: String = "source_action:" + str(action)
	var layers: Array = []
	var declarations: Array = []
	var attributes: Array = []
	for index: int in range(3):
		var kind: String = ["body", "shadow", "clothes"][index]
		var sprite: int = ACTOR + index
		layers.append({"kind": kind, "source_sprite_id": sprite})
		var declaration: Dictionary = {"sprite_id": sprite, "source_file": "list_9.spr", "source_line": 10 + index, "source_sha256": "a".repeat(64)}
		declarations.append({"kind": kind, "declaration_path": [declaration.duplicate(true)]})
		var literal: Dictionary = declaration.duplicate(true)
		literal["literal_attribute_directives"] = [{"code": 104, "body": "8", "line": 15}] if kind == "clothes" else []
		attributes.append({"kind": kind, "source_sprite_id": sprite, "declaration_path": [literal]})
	var directions: Array = []
	for direction: int in range(8):
		var frames: Array = []
		for token: Array in TOKENS:
			var selected: Array = []
			for layer: Dictionary in layers:
				var chosen: Dictionary = layer.duplicate(true)
				chosen.merge({"member": "Sprite/%d-0.sp2" % int(layer.source_sprite_id), "group_bit": direction, "frame_index": token[1]})
				if layer.kind == "shadow" and direction % 2 == 1: chosen.client_null = "direction_absent"
				selected.append(chosen)
			frames.append({"duration_ticks": token[2], "layers": selected})
		directions.append(frames)
	var action_proof: Dictionary = {"code": action, "fps": 24, "source_file": "list_9.spr", "source_line": 30 + action,
		"source_sha256": "b".repeat(64), "tokens": TOKENS.duplicate(true), "declared_flag": 1,
		"source_annotations": [{"token_index": 0, "raw": "synthetic provenance annotation"}]}
	var track: Dictionary = {"source_action_id": action, "fps": 24, "loop": null, "source_file": "list_9.spr", "source_line": 30 + action, "directions": directions}
	var compact: Dictionary = {"source_action_id": action, "source_sprite_id": ACTOR, "fps": 24, "loop": null,
		"tokens": TOKENS.duplicate(true), "declared_flag": 1, "layers": layers}
	return {"schema": 1, "source_snapshot": "patch523", "consumer_contract": contract(),
		"action_key": "list_9.spr:B9001:A" + str(action),
		"actor": {"source_sprite_id": ACTOR, "roles": {role: track}},
		"source_proof": {"root_sprite_id": ACTOR, "body_sprite_id": ACTOR, "declarations": declarations, "roles": {role: action_proof}},
		"compact_roles": {role: compact}, "source_layer_declarations": attributes,
		"independent_source_layers": []}

func fixture(directory: String, mutation: String = "") -> Dictionary:
	var members: Dictionary = {}
	for index: int in range(3):
		var member: String = "Sprite/%d-0.sp2" % (ACTOR + index)
		var raw_path: String = directory.path_join("raw/" + member)
		write_bytes(raw_path, make_sp2(0x55 if index == 1 else 0xff, index == 2))
		members[member] = {"member": member, "path": "raw/" + member, "sha256": FileAccess.get_sha256(raw_path), "bytes": FileAccess.get_size(raw_path)}
	var actions: Dictionary = {}
	for action: int in [0, 3]:
		var source: Dictionary = source_action(action)
		var role: String = "source_action:" + str(action)
		if action == 0:
			match mutation:
				"frame_out_of_range":
					source.compact_roles[role].tokens[1][1] = 2
					source.source_proof.roles[role].tokens[1][1] = 2
					for frames: Array in source.actor.roles[role].directions:
						for layer: Dictionary in frames[1].layers: layer.frame_index = 2
				"missing_direction": source.actor.roles[role].directions[1][0].layers[1].erase("client_null")
				"wrong_member": source.actor.roles[role].directions[0][0].layers[0].member = "Sprite/9999-0.sp2"
				"wrong_attributes": source.source_layer_declarations[2].declaration_path[0].source_sha256 = "c".repeat(64)
		var relative: String = "actors/%d/action-%d.json" % [ACTOR, action]
		actions[str(action)] = {"path": relative, "sha256": write_json(directory.path_join(relative), source)}
	var manifest: Dictionary = {"schema": 1, "kind": "current523_reference_sp2_action_bank", "source_snapshot": "patch523",
		"consumer_contract": contract(), "source_dummy_exclusion_policy": BANK.SOURCE_DUMMY_EXCLUSION_POLICY,
		"excluded_source_actors": {}, "members": members, "actors": {"sprite:" + str(ACTOR): actions}}
	var path: String = directory.path_join("manifest.json")
	return {"path": path, "sha": write_json(path, manifest), "raw": directory.path_join("raw/Sprite/9001-0.sp2")}

func open(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS)

func bytes_equal(left: Variant, right: Variant) -> bool:
	# Canonical JSON keeps this comparison byte exact while disregarding only
	# Dictionary insertion order (which is not part of the bank API).
	return JSON.stringify(left, "", true).to_utf8_buffer() == JSON.stringify(right, "", true).to_utf8_buffer()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scratch = "user://reference_sp2_load_memo_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ASSETS.reset_for_tests()
	BANK.forget_verified_members()
	var data: Dictionary = fixture(scratch.path_join("equivalence"))
	for member: String in ["9001", "9002", "9003"]:
		var parsed: Dictionary = DECODER.parse(FileAccess.get_file_as_bytes(data.path.get_base_dir().path_join("raw/Sprite/" + member + "-0.sp2")))
		check(parsed.get("ok", false), "synthetic source parses: " + member + " / " + str(parsed.get("error", "")))
	var legacy := LegacyBank.new()
	var optimized := OptimizedBank.new()
	var before: Dictionary = open(legacy, data)
	var after: Dictionary = open(optimized, data)
	var optimized_initial_calls: int = optimized.member_calls
	var legacy_initial_pins: int = legacy.pin_checks
	var optimized_initial_pins: int = optimized.pin_checks
	check(before.get("ok", false), "legacy path accepts the exact synthetic bank: " + str(before.get("error", "")))
	check(after.get("ok", false), "memo path accepts the exact synthetic bank: " + str(after.get("error", "")))
	if before.get("ok", false) and after.get("ok", false):
		check(bytes_equal(before, after), "complete load result is byte equivalent")
		check(bytes_equal(before.record, after.record), "loaded record is byte equivalent")
		check(bytes_equal(before.tracks, after.tracks), "tracks are byte equivalent")
		var provenance_before: Array = []
		var provenance_after: Array = []
		for role: String in BINDINGS:
			for direction: int in range(8):
				for index: int in range(TOKENS.size()):
					var old_frame: Dictionary = before.tracks[role].directions[direction][index]
					var new_frame: Dictionary = after.tracks[role].directions[direction][index]
					for layer: Dictionary in old_frame.layers + old_frame.effect_layers:
						if layer.has("frame_provenance"): provenance_before.append(layer.frame_provenance)
					for layer: Dictionary in new_frame.layers + new_frame.effect_layers:
						if layer.has("frame_provenance"): provenance_after.append(layer.frame_provenance)
		check(bytes_equal(provenance_before, provenance_after), "every selected layer provenance is byte equivalent")
		check(after.tracks.idle.directions[1][0].layers[1].client_null == "direction_absent", "sparse shadow direction remains a declared client null")
		var empty: Dictionary = after.tracks.attack.directions[7][1].effect_layers[0]
		check(empty.offset == [-3, 2] and empty.frame_provenance.empty, "legitimate empty clothes frame retains exact negative offset and provenance")
	check(legacy.member_calls == 160, "legacy baseline verifies every non-null selected layer (160 calls)")
	check(optimized.member_calls == 3 and optimized.member_names.size() == 3, "memo verifies each of three unique members exactly once")
	check(legacy.pin_checks == 161 and optimized.pin_checks == 1, "metadata pin checks reduce from each layer plus final (161) to final only (1)")
	for calls: int in optimized.member_names.values(): check(calls == 1, "each member has exactly one metadata verification")
	check(optimized.memo_observations > 0 and optimized.memo_is_compact, "load memo retains only groups/bit/frames/bounds/empty and identity; no raw/body/blocks/refs/palette")
	var repeated: Dictionary = open(optimized, data)
	check(repeated.get("ok", false) and bytes_equal(after, repeated) and optimized.member_calls == 6, "a second load on the same bank verifies three members again and returns an identical result")
	if after.get("ok", false):
		for layer: Dictionary in [after.tracks.attack.directions[7][1].layers[0], after.tracks.attack.directions[7][1].effect_layers[0]]:
			var independent: Dictionary = DECODER.parse(FileAccess.get_file_as_bytes(data.path.get_base_dir().path_join("raw/" + str(layer.member))))
			var direct: Dictionary = DECODER.render(independent, 7, 1)
			var rendered: Dictionary = optimized.render_layer(layer, true)
			check(rendered.get("ok", false) and direct.get("ok", false) and rendered.offset == direct.offset and rendered.image.get_size() == direct.image.get_size() and rendered.image.get_data() == direct.image.get_data(), "draw-time pixels and offset equal an independent decoder render: " + str(layer.kind))
	for mutation: String in ["frame_out_of_range", "missing_direction", "wrong_member", "wrong_attributes"]:
		var bad: Dictionary = fixture(scratch.path_join(mutation), mutation)
		var old_rejected: Dictionary = open(LegacyBank.new(), bad)
		var new_rejected: Dictionary = open(OptimizedBank.new(), bad)
		check(not old_rejected.get("ok", true) and not new_rejected.get("ok", true), "both paths reject wrong metadata: " + mutation)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(data.raw)
	write_bytes(data.raw, original + PackedByteArray([0]))
	check(not open(optimized, data).get("ok", true), "changed member size between loads is rejected despite a prior successful memo")
	write_bytes(data.raw, original)
	check(open(optimized, data).get("ok", false), "restored member can load after a size-change rejection")
	# Filesystem mtimes have one-second resolution; this is an actual observed
	# stamp change, matching the approved size/mtime re-verification policy.
	await create_timer(1.1).timeout
	var changed: PackedByteArray = original.duplicate()
	changed[changed.size() - 1] = (changed[changed.size() - 1] + 1) % 4
	write_bytes(data.raw, changed)
	check(not open(optimized, data).get("ok", true), "same-size member rewrite between loads is re-hashed and rejected")
	write_bytes(data.raw, original)
	BANK.forget_verified_members()
	check(open(optimized, data).get("ok", false), "original bytes load after explicit verification reset")
	var during_data: Dictionary = fixture(scratch.path_join("during_memo"))
	var during := ChangedDuringMemoBank.new()
	during.change_path = during_data.raw
	var interrupted: Dictionary = open(during, during_data)
	check(during.changed and during.member_calls == 4 and int(during.member_names.get("Sprite/9001-0.sp2", 0)) == 2, "during-load mutation rechecks the changed member once at the end; repeated tokens reuse the memo")
	check(not interrupted.get("ok", true), "end-of-load identity check rejects a member changed during the memo")
	print("REFERENCE_SP2_LOAD_MEMO_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "legacy_member_calls": legacy.member_calls, "optimized_member_calls": optimized_initial_calls, "legacy_pin_checks": legacy_initial_pins, "optimized_pin_checks": optimized_initial_pins, "scratch": scratch, "synthetic_only": true}))
	quit(0 if failures.is_empty() else 1)
