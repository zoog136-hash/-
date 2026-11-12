extends "res://tests/reference_sp2_load_memo_test.gd"
## Real SHA-pinned JSON loader; only SP2 pixel metadata is replaced. No art.
const REQUEST: int = 9001
const ALIAS_SOURCE: int = 9100
const FILE_BODY: int = 9200
const UNUSED_REMAP: int = 9300
const CLOTHES_A: int = 9401
const CLOTHES_B: int = 9402
const FILE_CLOTHES: int = 9500
const SHADOW: int = 9600
const SELECTED_ACTION: int = 3
const ROLE: String = "source_action:3"

class NativeMetadataBank:
	extends "res://scripts/resources/reference_sp2_bank.gd"
	var native_calls: int = 0
	var pixel_calls: int = 0
	func _native_attributes(source: Dictionary, layer: Dictionary) -> Dictionary:
		native_calls += 1
		return super._native_attributes(source,layer)
	func _load_layer_metadata(layer: Dictionary, _memo: Dictionary) -> Dictionary:
		pixel_calls += 1
		return {"ok":true,"empty":false,"offset":Vector2(3,-2),"provenance":{"member":layer.member,"synthetic_metadata_only":true}}

func own(id: int, target: Variant = null) -> Dictionary:
	var file: String = "list_9.spr" if id == REQUEST or id in [CLOTHES_A,CLOTHES_B] else "list_8.spr"
	return {"sprite_id":id,"alias_target":target,"source_file":file,"source_line":10 if id == REQUEST else id,"source_sha256":("a" if file == "list_9.spr" else "b").repeat(64)}

func literal(base: Dictionary, attributes: Array) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result["literal_attribute_directives"] = []
	for index: int in range(attributes.size()): result.literal_attribute_directives.append({"code":104,"body":attributes[index],"line":int(base.source_line)+index+1})
	return result

func native_contract() -> Dictionary:
	var result: Dictionary = contract()
	result["native_selector_policy"] = BANK.NATIVE_SELECTOR_POLICY
	result["native_activation_policy"] = BANK.NATIVE_ACTIVATION_POLICY
	return result

func native_source() -> Dictionary:
	var root: Dictionary = own(REQUEST)
	var source_owner: Dictionary = own(ALIAS_SOURCE,FILE_BODY)
	var body_file: Dictionary = own(FILE_BODY,UNUSED_REMAP)
	var cloth_file: Dictionary = own(FILE_CLOTHES)
	var specs: Array = []
	var proofs: Array = []
	var evidence: Array = []
	var instances: Array = []
	for index: int in range(5):
		var kind: String = "shadow" if index == 0 else ("body" if index == 1 else "clothes")
		var requested: int = [SHADOW,ALIAS_SOURCE,CLOTHES_A,CLOTHES_B,CLOTHES_A][index]
		var physical: int = SHADOW if kind == "shadow" else (FILE_BODY if kind == "body" else FILE_CLOTHES)
		var owner: int = requested if kind == "clothes" else REQUEST
		var reference_index: Variant = null if kind == "body" else (0 if kind == "shadow" else 1)
		var target_index: Variant = null if kind == "body" else (0 if kind == "shadow" else index-2)
		var binding: String = "native:%d:A3:%s:R%d:D%s:T%s" % [REQUEST,kind,requested,"None" if reference_index == null else str(reference_index),"None" if target_index == null else str(target_index)]
		var identity: Dictionary = {"kind":kind,"source_sprite_id":physical,"requested_sprite_id":requested,"metadata_owner_sprite_id":owner,"source_reference_index":reference_index,"target_index":target_index,"native_binding_id":binding,"file_remap_policy":BANK.NATIVE_FILE_REMAP_POLICY}
		var requested_proof: Dictionary = source_owner if kind == "body" else own(requested,physical if kind == "clothes" else null)
		var path: Array = [requested_proof.duplicate(true)]
		if kind == "body": path.append(body_file.duplicate(true))
		elif kind == "clothes": path.append(cloth_file.duplicate(true))
		var owner_proof: Dictionary = root if kind != "clothes" else requested_proof
		var edges: Array = []
		var source_declaration: Variant = null
		if kind != "body":
			var from_id: int = ALIAS_SOURCE if kind == "shadow" else REQUEST
			var raw: String = str(SHADOW) if kind == "shadow" else "3 %d %d %d" % [CLOTHES_A,CLOTHES_B,CLOTHES_A]
			edges.append({"from_sprite_id":from_id,"target_sprite_id":requested,"kind":kind,"source_reference":raw,"source_reference_index":reference_index,"target_index":target_index})
			source_declaration = own(from_id,FILE_BODY if kind == "shadow" else null)
			source_declaration.merge({"source_line":ALIAS_SOURCE+5 if kind == "shadow" else 20,"source_directive_index":int(reference_index),"source_reference_index":reference_index,"code":101 if kind == "shadow" else 105,"name":kind,"body":raw},true)
			var instance: String = "native-ref:"+binding
			identity["source_binding_id"] = binding
			identity["reference_instance_ids"] = [instance]
			instances.append({"instance_id":instance,"binding_id":binding,"from_sprite_id":from_id,"target_sprite_id":requested,"kind":kind,"source_reference":raw,"source_declaration":source_declaration.duplicate(true),"target_index":target_index,"source_edge_path":edges.duplicate(true),"canonical_instance_id":instance,"connection_stage":"ordered_literal_instance_shared_source_binding","native_reference_multiplicity_verified":false})
		specs.append(identity.duplicate(true))
		var proof: Dictionary = identity.duplicate(true)
		proof.merge({"declaration_path":path.duplicate(true),"attribute_owner_declaration_path":[owner_proof.duplicate(true)],"edge_path":edges,"source_declaration":source_declaration})
		proofs.append(proof)
		var trace: Array = []
		for entry: Dictionary in path:
			var values: Array = ["128"] if entry.sprite_id == FILE_BODY else (["256"] if entry.sprite_id == FILE_CLOTHES else (["8"] if entry.sprite_id == ALIAS_SOURCE or entry.sprite_id == CLOTHES_A else ["128"]))
			trace.append(literal(entry,values))
		var item: Dictionary = identity.duplicate(true)
		item.merge({"declaration_path":trace,"attribute_owner_declaration_path":[literal(owner_proof,["128","5"] if kind != "clothes" else (["8"] if requested == CLOTHES_A else ["128"]))]})
		evidence.append(item)
	var tokens: Array = [[0,0,2],[0,1,3]]
	var directions: Array = []
	for direction: int in range(8):
		var frames: Array = []
		for token: Array in tokens:
			var layers: Array = []
			for spec: Dictionary in specs:
				var layer: Dictionary = spec.duplicate(true)
				layer.merge({"member":"Sprite/%d-0.sp2" % int(spec.source_sprite_id),"group_bit":direction,"frame_index":token[1]})
				layers.append(layer)
			frames.append({"duration_ticks":token[2],"layers":layers})
		directions.append(frames)
	var alias: Dictionary = {"action_id":3,"target_sprite_id":ALIAS_SOURCE,"raw":"3="+str(ALIAS_SOURCE),"source_file":"list_9.spr","source_line":15,"source_column":0,"registration_status":"registered"}
	var action: Dictionary = {"code":3,"fps":24,"source_file":"list_8.spr","source_line":ALIAS_SOURCE+2,"source_sha256":"b".repeat(64),"tokens":tokens.duplicate(true),"declared_flag":1,"source_annotations":[],"native_requested_sprite_id":REQUEST,"native_body_request_sprite_id":ALIAS_SOURCE,"native_descriptor_origin_sprite_id":ALIAS_SOURCE,"native_registration_kind":"explicit_action_alias","native_action_alias_chain":[alias]}
	var track: Dictionary = {"source_action_id":3,"fps":24,"loop":null,"source_file":action.source_file,"source_line":action.source_line,"directions":directions}
	var compact: Dictionary = {"source_action_id":3,"source_sprite_id":REQUEST,"fps":24,"loop":null,"tokens":tokens.duplicate(true),"declared_flag":1,"layers":specs}
	var activation: Dictionary = {"policy":BANK.NATIVE_ACTIVATION_POLICY,"original_actor_sprite_id":REQUEST,"body_request_sprite_id":ALIAS_SOURCE,"shadow_metadata_owner_sprite_id":ALIAS_SOURCE,"clothes_metadata_owner_sprite_id":REQUEST,"auxiliary_recursion":false,"runtime_activation_verified":false}
	return {"schema":1,"source_snapshot":"patch523","consumer_contract":native_contract(),"native_selector_policy":BANK.NATIVE_SELECTOR_POLICY,"native_activation_policy":BANK.NATIVE_ACTIVATION_POLICY,"action_key":"list_9.spr:B10:A3","actor":{"source_sprite_id":REQUEST,"roles":{ROLE:track}},"compact_roles":{ROLE:compact},"source_layer_declarations":evidence,"source_reference_instances":instances,"source_reference_instance_policy":BANK.SOURCE_REFERENCE_INSTANCE_POLICY,"independent_source_layers":[],"source_proof":{"root_sprite_id":REQUEST,"body_sprite_id":FILE_BODY,"declarations":proofs,"roles":{ROLE:action},"native_selector_policy":BANK.NATIVE_SELECTOR_POLICY,"native_activation_policy":BANK.NATIVE_ACTIVATION_POLICY,"native_request_declaration":root,"native_activation_by_role":{ROLE:activation},"raw_candidate_declarations":[root.duplicate(true),source_owner.duplicate(true),body_file.duplicate(true),own(UNUSED_REMAP),own(CLOTHES_A,FILE_CLOTHES),own(CLOTHES_B,FILE_CLOTHES),cloth_file.duplicate(true),own(SHADOW)]}}

func mutate_native(source: Dictionary, mutation: String) -> void:
	match mutation:
		"alias_whitespace": source.source_proof.roles[ROLE].native_action_alias_chain[0].raw = "3 = "+str(ALIAS_SOURCE)
		"partial_marker": source.source_proof.erase("native_selector_policy")
		"numeric_marker": source.native_selector_policy = 0
		"unknown_policy":
			source.consumer_contract.native_selector_policy = "unproved"
			source.native_selector_policy = "unproved"
			source.source_proof.native_selector_policy = "unproved"
		"origin_action_key": source.action_key = "list_8.spr:B9100:A3"
		"descriptor_file_pin": source.source_proof.roles[ROLE].source_sha256 = "c".repeat(64)
		"wrong_alias_target": source.source_proof.roles[ROLE].native_action_alias_chain[0].target_sprite_id = FILE_BODY
		"wrong_alias_origin": source.source_proof.roles[ROLE].native_descriptor_origin_sprite_id = SHADOW
		"frame_request": source.actor.roles[ROLE].directions[0][0].layers[2].requested_sprite_id = CLOTHES_B
		"compact_request": source.compact_roles[ROLE].layers[2].requested_sprite_id = CLOTHES_B
		"duplicate_binding": source.compact_roles[ROLE].layers[3].native_binding_id = source.compact_roles[ROLE].layers[2].native_binding_id
		"wrong_body_owner":
			source.source_proof.declarations[1].attribute_owner_declaration_path = [own(ALIAS_SOURCE,FILE_BODY)]
			source.source_layer_declarations[1].attribute_owner_declaration_path = [literal(own(ALIAS_SOURCE,FILE_BODY),["8"])]
		"wrong_clothes_owner": source.source_layer_declarations[2].attribute_owner_declaration_path[0].sprite_id = FILE_CLOTHES
		"wrong_file_link":
			source.source_layer_declarations[1].declaration_path[0].alias_target = UNUSED_REMAP
			source.source_proof.declarations[1].declaration_path[0].alias_target = UNUSED_REMAP
		"wrong_owner_pin": source.source_layer_declarations[1].attribute_owner_declaration_path[0].source_sha256 = "c".repeat(64)
		"duplicate_evidence": source.source_layer_declarations.append(source.source_layer_declarations[2].duplicate(true))
		"invalid_directive": source.source_layer_declarations[2].attribute_owner_declaration_path[0].literal_attribute_directives[0].code = 105
		"wrong_instance": source.source_reference_instances[1].target_sprite_id = CLOTHES_B
		"wrong_shadow_owner": source.source_proof.declarations[0].edge_path[0].from_sprite_id = REQUEST
		"body_binding_rewrite":
			source.compact_roles[ROLE].layers[1].native_binding_id = "invented-consistent-key"
			source.source_proof.declarations[1].native_binding_id = "invented-consistent-key"
			source.source_layer_declarations[1].native_binding_id = "invented-consistent-key"
			for frames: Array in source.actor.roles[ROLE].directions:
				for frame: Dictionary in frames: frame.layers[1].native_binding_id = "invented-consistent-key"
		"missing_occurrence_binding":
			source.compact_roles[ROLE].layers[2].erase("source_binding_id")
			source.compact_roles[ROLE].layers[2].erase("reference_instance_ids")
			for frames: Array in source.actor.roles[ROLE].directions:
				for frame: Dictionary in frames:
					frame.layers[2].erase("source_binding_id")
					frame.layers[2].erase("reference_instance_ids")
		"fractional_target_index": source.actor.roles[ROLE].directions[0][0].layers[2].target_index = 0.5
		"malformed_own_decimal": source.source_layer_declarations[1].attribute_owner_declaration_path[0].literal_attribute_directives[0].body = "8 128"

func native_fixture(directory: String, mutation: String = "") -> Dictionary:
	var source: Dictionary = native_source()
	mutate_native(source,mutation)
	var relative: String = "actors/%d/action-3.json" % REQUEST
	var entry: Dictionary = {"path":relative,"sha256":write_json(directory.path_join(relative),source)}
	var manifest: Dictionary = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","consumer_contract":source.consumer_contract.duplicate(true),"source_dummy_exclusion_policy":BANK.SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{},"actors":{"sprite:"+str(REQUEST):{"3":entry}},"members":{}}
	var path: String = directory.path_join("manifest.json")
	return {"path":path,"sha":write_json(path,manifest)}

func load_native(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_bank(data.path,data.sha,REQUEST,{"selected":3},{"selected":true})

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scratch = "user://source_native_attachment_bank_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var bank := NativeMetadataBank.new()
	var source_before: String = JSON.stringify(native_source(),"",true)
	var data: Dictionary = native_fixture(scratch.path_join("valid"))
	var loaded: Dictionary = load_native(bank,data)
	check(loaded.get("ok",false),"new native pinned JSON contract loads: "+str(loaded.get("error","")))
	if loaded.get("ok",false):
		var frame: Dictionary = loaded.tracks.selected.directions[0][0]
		var body: Dictionary = frame.layers[1]
		var clothes: Array = frame.effect_layers
		check(body.source_attribute_projection.flags == 5 and body.source_attribute_projection.owner_sprite_id == REQUEST,"body projects original R own104 despite requested S/file B contradictions")
		check(body.source_attributes == ["8","128"] and body.source_attribute_owner_attributes == ["128","5"],"raw requested/file trace remains separate from original actor metadata")
		check(body.source_attribute_declarations[-1].alias_target == UNUSED_REMAP,"single file remap retains unused terminal alias without following again")
		check(clothes.size() == 3 and clothes[0].source_attribute_projection.flags == 8 and clothes[1].source_attribute_projection.flags == 128 and clothes[2].source_attribute_projection.flags == 8,"same physical clothes file keeps distinct requested owners and repeated operands")
		check(clothes[0].source_sprite_id == clothes[1].source_sprite_id and clothes[0].requested_sprite_id != clothes[1].requested_sprite_id,"physical equality cannot merge logical clothes requests")
		var keys: Dictionary = {}
		for layer: Dictionary in frame.layers+frame.effect_layers:
			keys[layer.source_layer_instance_key] = true
			check(layer.source_layer_instance_key == layer.native_binding_id,"verified native occurrence key is propagated")
		check(keys.size() == 5,"body/shadow and repeated105 operands have unique occurrence keys")
		check(not frame.layers[0].source_attribute_projection.ok and frame.layers[0].source_attribute_projection.origin == "shadow_requires_parent_actor_flags","shadow never substitutes its own104")
		check(bank.native_calls == 5 and bank.pixel_calls == 80,"attributes memoized once per occurrence, not per physical file or frame")
		check(loaded.tracks.selected.source_action_key == "list_9.spr:B10:A3","cross-file alias retains original requested action key")
		var other: Dictionary = loaded.tracks.selected.directions[0][1].effect_layers[0]
		var saved: Dictionary = other.duplicate(true)
		clothes[0].source_attribute_projection.flags = 256
		clothes[0].source_attribute_owner_declarations[0].literal_attribute_directives[0].body = "changed"
		check(bytes_equal(other,saved),"per-frame owner evidence and projections are deep independent values")
	check(JSON.stringify(native_source(),"",true) == source_before,"fixture source declarations remain unchanged")
	var spaced: Dictionary = load_native(NativeMetadataBank.new(),native_fixture(scratch.path_join("alias_whitespace"),"alias_whitespace"))
	check(spaced.get("ok",false),"source action alias permits original lexical spaces around equals")
	for mutation: String in ["partial_marker","numeric_marker","unknown_policy","origin_action_key","descriptor_file_pin","wrong_alias_target","wrong_alias_origin","frame_request","compact_request","duplicate_binding","wrong_body_owner","wrong_clothes_owner","wrong_file_link","wrong_owner_pin","duplicate_evidence","invalid_directive","wrong_instance","wrong_shadow_owner","body_binding_rewrite","missing_occurrence_binding","fractional_target_index"]:
		var rejected: Dictionary = load_native(NativeMetadataBank.new(),native_fixture(scratch.path_join(mutation),mutation))
		check(not rejected.get("ok",true),"reject repinned malformed native DTO: "+mutation)
	var unresolved: Dictionary = load_native(NativeMetadataBank.new(),native_fixture(scratch.path_join("malformed_own_decimal"),"malformed_own_decimal"))
	check(unresolved.get("ok",false),"malformed raw own104 remains explicit unresolved evidence")
	if unresolved.get("ok",false): check(not unresolved.tracks.selected.directions[0][0].layers[1].source_attribute_projection.ok,"invalid own decimal is not repaired by requested/file attrs")
	print("SOURCE_NATIVE_ATTACHMENT_BANK "+JSON.stringify({"checks":checks,"failures":failures,"scratch":scratch,"native_execution_verified":false,"synthetic_json_metadata_only":true}))
	quit(0 if failures.is_empty() else 1)
