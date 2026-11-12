extends "res://tests/reference_sp2_load_memo_test.gd"
## Synthetic regression probe for action-scoped source attribute validation.
## These invented files prove contracts and independent values, not original
## resource delivery or native visual equivalence.
const CORE_BINDINGS: Dictionary = {"idle": 3, "walk": 0, "attack": 1, "hit": 2, "death": 8}
const CORE_LOOPS: Dictionary = {"idle": true, "walk": true, "attack": false, "hit": false, "death": false}
const KINDS: Array[String] = ["body", "shadow", "clothes"]
var token_count: int = 64

class MeasuredBank:
	extends "res://scripts/resources/reference_sp2_bank.gd"
	var attribute_calls: int = 0
	var calls_by_action: Dictionary = {}
	var source_records: Dictionary = {}
	func _attributes(record: Dictionary, kind: String, sprite: int) -> Dictionary:
		attribute_calls += 1
		var action: String = str(record.action_key)
		calls_by_action[action] = int(calls_by_action.get(action, 0)) + 1
		source_records[action] = record
		return super._attributes(record, kind, sprite)

class AttributeLegacyBank:
	extends MeasuredBank
	func _load_action_attributes(record: Dictionary, kind: String, sprite: int, _memo: Dictionary) -> Dictionary:
		return _attributes(record, kind, sprite)

func expected_attributes(action: int, layer_index: int) -> Array:
	var literal: String = str(action * 10 + layer_index)
	return [literal, "8", literal]

func source_action(action: int) -> Dictionary:
	var source: Dictionary = super.source_action(action)
	var role: String = "source_action:" + str(action)
	var tokens: Array = []
	for index: int in range(token_count): tokens.append(TOKENS[index % TOKENS.size()].duplicate())
	var original: Array = source.actor.roles[role].directions
	var directions: Array = []
	for direction: int in range(8):
		var frames: Array = []
		for index: int in range(token_count): frames.append(original[direction][index % TOKENS.size()].duplicate(true))
		directions.append(frames)
	source.actor.roles[role].directions = directions
	source.compact_roles[role].tokens = tokens
	source.source_proof.roles[role].tokens = tokens.duplicate(true)
	# The same kind:sprite occurs in every action with different literal values
	# and proof identities. A memo escaping its action cannot pass this fixture.
	for layer_index: int in range(KINDS.size()):
		var base: Dictionary = source.source_proof.declarations[layer_index].declaration_path[0]
		base.source_line = 100 + action * 10 + layer_index
		base.source_sha256 = "%064x" % (action * 10 + layer_index + 1)
		var literal: Dictionary = base.duplicate(true)
		var directives: Array = []
		for ordinal: int in range(3):
			directives.append({"code": 104, "body": expected_attributes(action, layer_index)[ordinal], "line": 200 + action * 10 + ordinal})
		literal.literal_attribute_directives = directives
		source.source_layer_declarations[layer_index].declaration_path = [literal]
	return source

func dummy_exclusion(sprite: int) -> Dictionary:
	return {"source_snapshot": "patch523", "reason": "source_literal_dummy", "originals_preserved": true,
		"raw_member_namespace_excluded": false,
		"dummy_declarations": [{"sprite_id": sprite, "literal_name": "synthetic_dummy", "literal_declaration": "synthetic_dummy", "matched_literal": "dummy", "source_file": "list_9.spr", "source_line": 1, "source_sha256": "d".repeat(64)}],
		"source_graph_paths": [{"kind": "source_declared_root", "sprite_ids": [sprite]}]}

func fixture(directory: String, mutation: String = "") -> Dictionary:
	var data: Dictionary = super.fixture(directory)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	var actions: Dictionary = {}
	var action_paths: Dictionary = {}
	for action: int in CORE_BINDINGS.values():
		var source: Dictionary = source_action(action)
		if mutation == "all_shadow_client_null":
			var role: String = "source_action:" + str(action)
			for frames: Array in source.actor.roles[role].directions:
				for frame: Dictionary in frames: frame.layers[1].client_null = "direction_absent"
			source.source_layer_declarations[1].declaration_path[0].erase("literal_attribute_directives")
		# Corrupt the final action, after four valid actions have used the same
		# kind:sprite keys. Previous successful validation must not mask it.
		if action == 8:
			match mutation:
				"missing_evidence": source.erase("source_layer_declarations")
				"ambiguous_evidence": source.source_layer_declarations.append(source.source_layer_declarations[0].duplicate(true))
				"missing_directives": source.source_layer_declarations[0].declaration_path[0].erase("literal_attribute_directives")
				"wrong_directive_code": source.source_layer_declarations[0].declaration_path[0].literal_attribute_directives[0].code = 105
				"wrong_source_pin": source.source_layer_declarations[0].declaration_path[0].source_sha256 = "c".repeat(64)
				"invalid_path_entry": source.source_layer_declarations[0].declaration_path = [null]
				"unresolved_clothes":
					source.source_layer_declarations[2].declaration_path[0].literal_attribute_directives[0].body = "8 128"
					source.source_layer_declarations[2].declaration_path[0].literal_attribute_directives[2].body = "8 128"
		var relative: String = "actors/%d/action-%d.json" % [ACTOR, action]
		var path: String = directory.path_join(relative)
		actions[str(action)] = {"path": relative, "sha256": write_json(path, source)}
		action_paths[str(action)] = path
	manifest.actors["sprite:" + str(ACTOR)] = actions
	if mutation == "excluded_child": manifest.excluded_source_actors["sprite:" + str(ACTOR + 2)] = dummy_exclusion(ACTOR + 2)
	data.sha = write_json(data.path, manifest)
	data.action_paths = action_paths
	return data

func load_core(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_bank(data.path, data.sha, ACTOR, CORE_BINDINGS, CORE_LOOPS)

func all_provenance(loaded: Dictionary) -> Array:
	var result: Array = []
	for role: String in CORE_BINDINGS:
		for frames: Array in loaded.tracks[role].directions:
			for frame: Dictionary in frames:
				for layer: Dictionary in frame.layers + frame.effect_layers:
					if layer.has("frame_provenance"): result.append(layer.frame_provenance)
	return result

func validate_values(loaded: Dictionary) -> void:
	for role: String in CORE_BINDINGS:
		var action: int = int(CORE_BINDINGS[role])
		var frame: Dictionary = loaded.tracks[role].directions[0][0]
		var layers: Array = frame.layers + frame.effect_layers
		var expected_order: Array = []
		for layer_index: int in range(KINDS.size()):
			var layer: Dictionary = layers[layer_index]
			expected_order.append(layer.kind)
			check(layer.source_attributes == expected_attributes(action, layer_index), "literal attribute order and duplicate multiplicity survive: %s/%s" % [role, KINDS[layer_index]])
			check(layer.source_attribute_declarations[0].source_line == 100 + action * 10 + layer_index, "same kind:sprite retains its own action proof: %s/%s" % [role, KINDS[layer_index]])
		check(expected_order == KINDS, "declared layer order survives: " + role)
		var absent: Dictionary = loaded.tracks[role].directions[1][0].layers[1]
		check(absent.client_null == "direction_absent" and not absent.has("source_attributes") and not absent.has("source_attribute_declarations"), "client-null shadow skips attribute expansion: " + role)

func check_independent_values(loaded: Dictionary, measured: RefCounted) -> void:
	var first: Dictionary = loaded.tracks.idle.directions[0][0].layers[0]
	var other: Dictionary = loaded.tracks.idle.directions[0][1].layers[0]
	var another_direction: Dictionary = loaded.tracks.idle.directions[2][0].layers[0]
	var another_role: Dictionary = loaded.tracks.walk.directions[0][0].layers[0]
	var other_before: Dictionary = other.duplicate(true)
	var direction_before: Dictionary = another_direction.duplicate(true)
	var role_before: Dictionary = another_role.duplicate(true)
	var original_source: Dictionary = measured.source_records["list_9.spr:B9001:A3"]
	var source_before: Dictionary = original_source.duplicate(true)
	check(not is_same(first.source_attributes, other.source_attributes) and not is_same(first.source_attribute_declarations, other.source_attribute_declarations), "each converted frame receives independent attribute and declaration arrays")
	check(not is_same(first.source_attribute_declarations[0], other.source_attribute_declarations[0]) and not is_same(first.source_attribute_declarations[0].literal_attribute_directives[0], other.source_attribute_declarations[0].literal_attribute_directives[0]), "declarations and nested directive dictionaries are independently mutable")
	first.source_attributes.append("changed in one converted frame")
	first.source_attribute_declarations[0].literal_attribute_directives[0].body = "changed in one converted frame"
	check(bytes_equal(other, other_before) and bytes_equal(another_direction, direction_before), "mutating one converted frame leaves other tokens and directions unchanged")
	check(bytes_equal(another_role, role_before) and bytes_equal(original_source, source_before), "mutating one converted frame leaves other roles and the parsed source unchanged")

func check_helper_copy_contract() -> void:
	var bank := MeasuredBank.new()
	var source: Dictionary = source_action(3)
	var snapshot: Dictionary = source.duplicate(true)
	var memo: Dictionary = {}
	var first: Dictionary = bank._load_action_attributes(source, "body", ACTOR, memo)
	var second: Dictionary = bank._load_action_attributes(source, "body", ACTOR, memo)
	var expected: Dictionary = second.duplicate(true)
	check(first.get("ok", false) and second.get("ok", false) and bank.attribute_calls == 1, "direct repeated helper requests validate one exact kind:sprite")
	if not first.get("ok", false): return
	first.attributes[0] = "changed returned attributes"
	first.declarations[0].literal_attribute_directives[0].body = "changed returned declaration"
	var third: Dictionary = bank._load_action_attributes(source, "body", ACTOR, memo)
	check(bytes_equal(second, expected) and bytes_equal(third, expected) and bytes_equal(source, snapshot) and bank.attribute_calls == 1, "first, cached and later helper results have independent deep values")
	var kind_source: Dictionary = source_action(3)
	kind_source.source_proof.declarations[1].declaration_path[0].sprite_id = ACTOR
	kind_source.source_layer_declarations[1].source_sprite_id = ACTOR
	kind_source.source_layer_declarations[1].declaration_path[0].sprite_id = ACTOR
	kind_source.source_layer_declarations[1].declaration_path[0].literal_attribute_directives[0].body = "native_unresolved"
	var kind_bank := MeasuredBank.new()
	var kind_memo: Dictionary = {}
	var body: Dictionary = kind_bank._load_action_attributes(kind_source, "body", ACTOR, kind_memo)
	var shadow: Dictionary = kind_bank._load_action_attributes(kind_source, "shadow", ACTOR, kind_memo)
	check(body.get("ok", false) and shadow.get("ok", false) and kind_bank.attribute_calls == 2 and kind_memo.size() == 2 and body.attributes == expected_attributes(3, 0), "one sprite ID used by two layer kinds has separate exact memo identities")
	check(shadow.get("unresolved", false) and shadow.attributes == ["native_unresolved", "8", "31"] and not body.unresolved, "literal unresolved status and ordered values are preserved independently by kind")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scratch = "user://reference_sp2_attribute_memo_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ASSETS.reset_for_tests()
	BANK.forget_verified_members()
	var data: Dictionary = fixture(scratch.path_join("equivalence"))
	var legacy := AttributeLegacyBank.new()
	var measured := MeasuredBank.new()
	var before: Dictionary = load_core(legacy, data)
	var after: Dictionary = load_core(measured, data)
	var legacy_calls: int = legacy.attribute_calls
	var memo_calls: int = measured.attribute_calls
	check(before.get("ok", false), "legacy accepts five exact synthetic actions: " + str(before.get("error", "")))
	check(after.get("ok", false), "memo accepts five exact synthetic actions: " + str(after.get("error", "")))
	check(legacy_calls == 6400 and memo_calls == 15, "five actions x eight directions x 64 tokens reduce validations from 6400 to 15")
	if not before.get("ok", false) or not after.get("ok", false): finish_attribute(legacy_calls, memo_calls); return
	check(bytes_equal(before, after), "complete result remains byte equivalent")
	check(bytes_equal(before.record, after.record) and bytes_equal(before.tracks, after.tracks), "record and tracks remain byte equivalent")
	check(bytes_equal(all_provenance(before), all_provenance(after)), "every layer's source provenance remains byte equivalent")
	check(measured.calls_by_action.size() == 5, "all five source actions have their own validation memo")
	for action: String in measured.calls_by_action: check(int(measured.calls_by_action[action]) == 3, "each action validates its three own identities exactly once: " + action)
	validate_values(after)
	check_independent_values(after, measured)
	var reloaded: Dictionary = load_core(measured, data)
	check(reloaded.get("ok", false) and measured.attribute_calls == 30 and bytes_equal(before, reloaded), "reloading the same bank starts fresh action memos and restores the original result")
	check_helper_copy_contract()
	token_count = 4
	for mutation: String in ["missing_evidence", "ambiguous_evidence", "missing_directives", "wrong_directive_code", "wrong_source_pin", "invalid_path_entry", "excluded_child"]:
		var bad: Dictionary = fixture(scratch.path_join(mutation), mutation)
		var old_rejected: Dictionary = load_core(AttributeLegacyBank.new(), bad)
		var new_rejected: Dictionary = load_core(MeasuredBank.new(), bad)
		check(not old_rejected.get("ok", true) and not new_rejected.get("ok", true), "both paths reject invalid or excluded source attributes: " + mutation)
		check(old_rejected.get("error") == new_rejected.get("error"), "failure reason remains exact: " + mutation)
	var absent_data: Dictionary = fixture(scratch.path_join("all_shadow_client_null"), "all_shadow_client_null")
	var absent_legacy := AttributeLegacyBank.new()
	var absent_memo := MeasuredBank.new()
	var absent_before: Dictionary = load_core(absent_legacy, absent_data)
	var absent_after: Dictionary = load_core(absent_memo, absent_data)
	check(absent_before.get("ok", false) and absent_after.get("ok", false) and bytes_equal(absent_before, absent_after), "all-client-null shadow layers preserve acceptance despite unused malformed attribute declarations")
	check(absent_legacy.attribute_calls == 320 and absent_memo.attribute_calls == 10, "unused client-null shadows are never eagerly validated by either path")
	var unresolved_data: Dictionary = fixture(scratch.path_join("unresolved_clothes"), "unresolved_clothes")
	var unresolved_before: Dictionary = load_core(AttributeLegacyBank.new(), unresolved_data)
	var unresolved_after: Dictionary = load_core(MeasuredBank.new(), unresolved_data)
	check(unresolved_before.get("ok", false) and unresolved_after.get("ok", false) and bytes_equal(unresolved_before, unresolved_after), "noninteger literal attribute strings remain accepted and byte equivalent")
	if unresolved_after.get("ok", false):
		var unresolved_layer: Dictionary = unresolved_after.tracks.death.directions[0][0].effect_layers[0]
		check(unresolved_layer.source_attributes_unresolved and unresolved_layer.source_attributes == ["8 128", "8", "8 128"] and not unresolved_after.tracks.idle.directions[0][0].effect_layers[0].source_attributes_unresolved, "unresolved clothes attributes retain their action, literal order and repeated values")
	# Existing draw-time pin and member guards remain active after all metadata
	# was memoized. Real observed mtime changes follow the approved stamp policy.
	var picture_layer: Dictionary = reloaded.tracks.idle.directions[0][0].layers[0]
	var action_path: String = data.action_paths["3"]
	var action_bytes: PackedByteArray = FileAccess.get_file_as_bytes(action_path)
	await create_timer(1.1).timeout
	var changed_action: PackedByteArray = action_bytes.duplicate()
	changed_action[changed_action.size() - 1] ^= 1
	write_bytes(action_path, changed_action)
	check(not measured.render_layer(picture_layer, false).get("ok", true), "same-size action rewrite invalidates the loaded action pin after memo reuse")
	check(not load_core(measured, data).get("ok", true), "a subsequent load rejects the changed action JSON despite prior memo success")
	write_bytes(action_path, action_bytes)
	check(load_core(measured, data).get("ok", false), "restored action bytes load normally")
	var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(data.raw)
	await create_timer(1.1).timeout
	var changed_member: PackedByteArray = raw_bytes.duplicate()
	changed_member[changed_member.size() - 1] = (changed_member[changed_member.size() - 1] + 1) % 4
	write_bytes(data.raw, changed_member)
	check(not measured.render_layer(picture_layer, false).get("ok", true), "same-size member rewrite is rejected on draw despite prior attribute and metadata memos")
	check(not load_core(measured, data).get("ok", true), "a subsequent load rejects changed member bytes")
	write_bytes(data.raw, raw_bytes)
	BANK.forget_verified_members()
	check(load_core(measured, data).get("ok", false), "restored member bytes retain normal acceptance")
	finish_attribute(legacy_calls, memo_calls)

func finish_attribute(legacy_calls: int, memo_calls: int) -> void:
	print("REFERENCE_SP2_ATTRIBUTE_MEMO_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "legacy_attribute_calls": legacy_calls, "memo_attribute_calls": memo_calls, "actions": 5, "directions": 8, "tokens_per_action": 64, "scratch": scratch, "synthetic_only": true}))
	quit(0 if failures.is_empty() else 1)
