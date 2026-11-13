extends "res://tests/source_native_attachment_bank_test.gd"
## Real pinned native DTO + invented FE SP2; no original/native execution claim.
## Optional --baseline-script=res://... loads an unchanged pre-optimization bank
## and compares every output byte. The fixture is reusable by timing probes.
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")

class CapturedBank extends "res://scripts/resources/reference_sp2_bank.gd":
	var sources: Array = []
	var source_bytes: Array[PackedByteArray] = []
	func _json(path: String, expected: String, manifest_json: bool = false) -> Dictionary:
		var result: Dictionary = super._json(path,expected,manifest_json)
		if result.ok:
			sources.append(result.value)
			source_bytes.append(var_to_bytes(result.value))
		return result

func build_fixture(directory: String, scenario: String = "ordinary", token_count: int = 16) -> Dictionary:
	var source: Dictionary = native_source()
	if scenario == "null_prefix": source.consumer_contract["clothes_collection_policy"] = "first_null_asset_retains_successful_clothes_prefix"
	var tokens: Array = []
	for ordinal: int in token_count: tokens.append([65532 if scenario == "wrap" else 0,ordinal%2,2+ordinal%2])
	var directional: int = 0 if scenario == "nondirectional" else 1
	var compact: Dictionary = source.compact_roles[ROLE]
	compact.tokens = tokens.duplicate(true)
	compact.declared_flag = directional
	source.source_proof.roles[ROLE].tokens = tokens.duplicate(true)
	source.source_proof.roles[ROLE].declared_flag = directional
	var directions: Array = []
	var members: Dictionary = {}
	for direction: int in 8:
		var frames: Array = []
		for token: Array in tokens:
			var layers: Array = []
			# Independent fixture arithmetic exercises directional u16 wrap.
			var selected: int = (int(token[0])+(direction if directional else 0)) & 65535
			for spec: Dictionary in compact.layers:
				var layer: Dictionary = spec.duplicate(true)
				var member: String = "Sprite/%d-%d.sp2" % [int(spec.source_sprite_id),selected & 65528]
				layer.merge({"member":member,"group_bit":selected & 7,"frame_index":token[1],"synthetic_nested":{"values":["original"]}})
				if not members.has(member):
					var raw_path: String = directory.path_join("raw/"+member)
					write_bytes(raw_path,make_sp2(255))
					members[member] = {"member":member,"path":"raw/"+member,"sha256":FileAccess.get_sha256(raw_path),"bytes":FileAccess.get_size(raw_path)}
				layers.append(layer)
			if scenario == "null_prefix":
				layers[0]["client_null"] = "direction_absent"
				layers[1]["client_null"] = "empty_body_frame"
				layers[3]["client_null"] = "direction_absent"
				if int(token[1]) == 0: layers[4]["client_null"] = "empty_frame_set"
			if scenario == "prefilled":
				layers[2]["source_attributes"] = ["preserved source field"]
				layers[2]["source_attribute_owner_attributes"] = ["preserved owner field"]
				layers[2]["frame_provenance"] = {"supplied_field":"retained"}
				layers[2]["path"] = "preserved/path"
			frames.append({"duration_ticks":token[2],"layers":layers})
		directions.append(frames)
	source.actor.roles[ROLE].directions = directions
	var relative: String = "actors/%d/action-3.json" % REQUEST
	var action_path: String = directory.path_join(relative)
	var entry: Dictionary = {"path":relative,"sha256":write_json(action_path,source)}
	var manifest: Dictionary = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","consumer_contract":source.consumer_contract.duplicate(true),"source_dummy_exclusion_policy":BANK.SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{},"actors":{"sprite:"+str(REQUEST):{"3":entry}},"members":members}
	var path: String = directory.path_join("manifest.json")
	return {"path":path,"sha":write_json(path,manifest),"action_path":action_path,"raw":directory.path_join("raw/"+str(members.keys()[0]))}

func build(bank: RefCounted, data: Dictionary, shared: bool) -> Dictionary:
	if shared: return bank.load_shared_bank(data.path,data.sha,REQUEST,{"selected":3},{"selected":true},"npc")
	return bank.load_bank(data.path,data.sha,REQUEST,{"selected":3},{"selected":true},"npc")

func check_sources(bank: CapturedBank, label: String) -> void:
	check(not bank.sources.is_empty(),label+" captured raw action JSON")
	for index: int in bank.sources.size(): check(var_to_bytes(bank.sources[index]) == bank.source_bytes[index],label+" preserves source JSON values")

func check_mutable(loaded: Dictionary, label: String) -> void:
	var first: Dictionary = loaded.tracks.selected.directions[0][0]
	var sibling: Dictionary = loaded.tracks.selected.directions[1][1]
	var saved: PackedByteArray = var_to_bytes(sibling)
	for layer: Dictionary in first.layers+first.effect_layers:
		check(not layer.is_read_only() and not layer.source_attribute_owner_declarations.is_read_only(),label+" mutable output containers")
		layer.synthetic_nested.values[0] = "private edit"
		layer.source_attribute_owner_declarations[0].literal_attribute_directives[0].body = "private owner edit"
		layer.source_attribute_owner_attributes.append("private attribute edit")
		if layer.has("source_reference_instances"):
			layer.source_reference_instances[0].source_edge_path[0].target_sprite_id = -99
	check(var_to_bytes(sibling) == saved,label+" nested occurrence evidence remains independent")

func run() -> void:
	var baseline: Script = null
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-script="): baseline = load(argument.trim_prefix("--baseline-script="))
	scratch = "user://native_build_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var baseline_cases: int = 0
	for scenario: String in ["ordinary","null_prefix","prefilled","nondirectional","wrap"]:
		var data: Dictionary = build_fixture(scratch.path_join(scenario),scenario)
		var action_bytes: PackedByteArray = FileAccess.get_file_as_bytes(data.action_path)
		var outputs: Array = []
		for shared: bool in [false,true]:
			PREPARED.clear()
			var bank := CapturedBank.new()
			var result: Dictionary = build(bank,data,shared)
			check(result.ok,scenario+" loads shared="+str(shared)+": "+str(result.get("error","")))
			if not result.ok: continue
			outputs.append(var_to_bytes(result))
			if baseline != null:
				var oracle: Dictionary = build(baseline.new(),data,shared)
				check(var_to_bytes(result) == var_to_bytes(oracle),scenario+" complete output bytes match pre-optimization bank shared="+str(shared))
				baseline_cases += 1
			var first: Dictionary = result.tracks.selected.directions[0][0]
			var next: Dictionary = result.tracks.selected.directions[1][1]
			if scenario == "null_prefix":
				check(first.layers[0].client_null == "direction_absent" and first.layers[1].client_null == "empty_body_frame","native shadow/body null markers retained")
				check(first.effect_layers[1].client_null == "direction_absent" and first.effect_layers[2].client_null == "empty_frame_set" and first.effect_layers[2].source_client_null == "empty_frame_set" and first.effect_layers[2].clothes_prefix_stop_layer_index == 3 and next.effect_layers[2].client_null == "clothes_prefix_stopped","clothes stop and original non-overwritten null provenance retained")
			if scenario == "prefilled":
				check(first.effect_layers[0].source_attributes == ["preserved source field"] and first.effect_layers[0].source_attribute_owner_attributes == ["preserved owner field"] and first.effect_layers[0].path == "preserved/path" and first.effect_layers[0].frame_provenance.supplied_field == "retained","non-overwriting merge fields preserved")
			if shared:
				for index: int in first.layers.size():
					check(first.layers[index].is_read_only() and is_same(first.layers[index].source_attribute_projection,next.layers[index].source_attribute_projection),scenario+" prepared body/null proof is frozen and shared")
				for index: int in first.effect_layers.size():
					check(first.effect_layers[index].is_read_only() and is_same(first.effect_layers[index].source_attribute_projection,next.effect_layers[index].source_attribute_projection) and first.effect_layers[index].source_attribute_projection.is_read_only(),scenario+" prepared clothes/stopped proof is shared read-only")
			else: check_mutable(result,scenario)
			check_sources(bank,scenario)
		check(outputs.size() == 2 and outputs[0] == outputs[1],scenario+" mutable/prepared complete output bytes agree")
		check(FileAccess.get_file_as_bytes(data.action_path) == action_bytes,scenario+" pinned action file unchanged")
	# Existing changed-file rejection remains active through the real raw loader.
	var changed_data: Dictionary = build_fixture(scratch.path_join("changed"))
	var owner := BANK.new()
	check(build(owner,changed_data,true).ok,"prime shared native source")
	write_bytes(changed_data.raw,FileAccess.get_file_as_bytes(changed_data.raw)+PackedByteArray([0]))
	check(not build(BANK.new(),changed_data,true).ok,"changed native SP2 rejects shared reuse")
	print("REFERENCE_SP2_NATIVE_BUILD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"baseline_cases":baseline_cases,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
