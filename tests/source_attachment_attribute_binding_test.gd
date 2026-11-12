extends "res://tests/reference_sp2_load_memo_test.gd"
## Pinned JSON DTO regression. No raw SP2, original art or render equivalence:
## this probe replaces only pixel metadata lookup, using the real bank loader,
## declaration validation, per-role actor routing and action attribute memo.
const ALTERNATE: int = ACTOR + 4
const PHYSICAL_BODY: int = ACTOR + 100
const PHYSICAL_CLOTHES: int = ACTOR + 102
const ROUTED_BINDINGS: Dictionary = {"idle":0,"alternate":3}
const ROUTED_LOOPS: Dictionary = {"idle":true,"alternate":false}

class MetadataBank:
	extends "res://scripts/resources/reference_sp2_bank.gd"
	var attribute_calls: int = 0
	func _attributes(record: Dictionary, kind: String, sprite: int) -> Dictionary:
		attribute_calls += 1
		return super._attributes(record,kind,sprite)
	func _load_layer_metadata(layer: Dictionary, _memo: Dictionary) -> Dictionary:
		return {"ok":true,"empty":false,"offset":Vector2.ZERO,"provenance":{"member":layer.member,"synthetic_metadata_only":true}}

func path_entry(sprite: int, alias: Variant, values: Array) -> Dictionary:
	var entry: Dictionary = {"sprite_id":sprite,"alias_target":alias,"source_file":"list_9.spr","source_line":sprite,"source_sha256":"a".repeat(64),"literal_attribute_directives":[]}
	for index: int in range(values.size()): entry.literal_attribute_directives.append({"code":104,"body":values[index],"line":sprite+index})
	return entry

func install_path(source: Dictionary, layer_index: int, path: Array) -> void:
	var proof_path: Array = []
	for literal: Dictionary in path:
		var proof: Dictionary = literal.duplicate(true)
		proof.erase("literal_attribute_directives")
		proof_path.append(proof)
	source.source_proof.declarations[layer_index].declaration_path = proof_path
	source.source_layer_declarations[layer_index].declaration_path = path
	source.source_layer_declarations[layer_index].source_sprite_id = path[-1].sprite_id

func source_for(actor_id: int, action: int) -> Dictionary:
	var source: Dictionary = super.source_action(action)
	var role: String = "source_action:" + str(action)
	source.actor.source_sprite_id = actor_id
	source.source_proof.root_sprite_id = actor_id
	source.source_proof.body_sprite_id = PHYSICAL_BODY
	source.compact_roles[role].source_sprite_id = actor_id
	source.action_key = "list_9.spr:B%d:A%d" % [actor_id,action]
	install_path(source,0,[path_entry(actor_id,PHYSICAL_BODY,["128","5"] if actor_id == ACTOR else ["256"]),path_entry(PHYSICAL_BODY,null,["8"])])
	install_path(source,1,[path_entry(ACTOR+1,null,["128"])])
	install_path(source,2,[path_entry(ACTOR+2,PHYSICAL_CLOTHES,["8","128"]),path_entry(PHYSICAL_CLOTHES,null,["1"])])
	source.source_proof.declarations[2].edge_path = [{"kind":"clothes","from_sprite_id":actor_id,"target_sprite_id":ACTOR+2,"source_reference":"1 " + str(ACTOR+2)}]
	for spec: Dictionary in source.compact_roles[role].layers:
		if spec.kind == "body": spec.source_sprite_id = PHYSICAL_BODY
		if spec.kind == "clothes": spec.source_sprite_id = PHYSICAL_CLOTHES
	for frames: Array in source.actor.roles[role].directions:
		for frame: Dictionary in frames:
			for layer: Dictionary in frame.layers:
				if layer.kind == "body": layer.source_sprite_id = PHYSICAL_BODY
				if layer.kind == "clothes": layer.source_sprite_id = PHYSICAL_CLOTHES
				layer.member = "Sprite/%d-0.sp2" % int(layer.source_sprite_id)
	return source

func mutate(source: Dictionary, mutation: String) -> void:
	match mutation:
		"wrong_body_owner":
			source.source_proof.declarations[0].declaration_path[0].sprite_id = ALTERNATE
			source.source_layer_declarations[0].declaration_path[0].sprite_id = ALTERNATE
		"wrong_clothes_owner": source.source_proof.declarations[2].edge_path[-1].target_sprite_id = ACTOR+9
		"bad_alias_link":
			source.source_proof.declarations[0].declaration_path[0].alias_target = ACTOR+9
			source.source_layer_declarations[0].declaration_path[0].alias_target = ACTOR+9
		"ambiguous_physical_proof": source.source_proof.declarations.append(source.source_proof.declarations[0].duplicate(true))
		"ambiguous_physical_evidence": source.source_layer_declarations.append(source.source_layer_declarations[0].duplicate(true))
		"bad_pin": source.source_layer_declarations[0].declaration_path[0].source_sha256 = "c".repeat(64)
		"malformed_own": source.source_layer_declarations[0].declaration_path[0].literal_attribute_directives[0].body = "8 128"
		"malformed_alias": source.source_layer_declarations[0].declaration_path[-1].literal_attribute_directives[0].body = "not own decimal"
		"absent_own": source.source_layer_declarations[0].declaration_path[0].literal_attribute_directives = []

func metadata_fixture(directory: String, mutation: String = "") -> Dictionary:
	var actors: Dictionary = {}
	for actor_id: int in [ACTOR,ALTERNATE]:
		var action: int = 0 if actor_id == ACTOR else 3
		var source: Dictionary = source_for(actor_id,action)
		if actor_id == ACTOR: mutate(source,mutation)
		var relative: String = "actors/%d/action-%d.json" % [actor_id,action]
		actors["sprite:"+str(actor_id)] = {str(action):{"path":relative,"sha256":write_json(directory.path_join(relative),source)}}
	var manifest: Dictionary = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","consumer_contract":contract(),"source_dummy_exclusion_policy":BANK.SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{},"actors":actors,"members":{}}
	var path: String = directory.path_join("manifest.json")
	return {"path":path,"sha":write_json(path,manifest)}

func load_metadata(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_bank(data.path,data.sha,ACTOR,ROUTED_BINDINGS,ROUTED_LOOPS,"",{"alternate":ALTERNATE})

func projection(layer: Dictionary) -> Dictionary:
	return layer.get("source_attribute_projection",{})

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scratch = "user://source_attachment_attribute_binding_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var bank := MetadataBank.new()
	var data: Dictionary = metadata_fixture(scratch.path_join("valid"))
	var loaded: Dictionary = load_metadata(bank,data)
	check(loaded.get("ok",false),"actual pinned JSON bank DTO loads: " + str(loaded.get("error","")))
	if loaded.get("ok",false):
		var body: Dictionary = loaded.tracks.idle.directions[0][0].layers[0]
		var clothes: Dictionary = loaded.tracks.idle.directions[0][0].effect_layers[0]
		var alternate: Dictionary = loaded.tracks.alternate.directions[0][0].layers[0]
		var body_projection: Dictionary = projection(body)
		check(body_projection.get("ok",false) and body_projection.get("flags",-1) == 5 and body_projection.get("present",false),"body last own104 wins over own128 and contradictory alias8")
		check(body_projection.get("owner_sprite_id",-1) == ACTOR and body_projection.get("owner_proof",{}).get("physical_sprite_id",-1) == PHYSICAL_BODY,"projection proves original requested owner separately from physical file")
		check(projection(clothes).get("ok",false) and projection(clothes).get("flags",-1) == 128 and projection(clothes).get("owner_sprite_id",-1) == ACTOR+2,"105 target own128 wins over target alias1")
		check(projection(alternate).get("ok",false) and projection(alternate).get("flags",-1) == 256 and projection(alternate).get("owner_sprite_id",-1) == ALTERNATE,"role_actor_ids selects alternate role own metadata despite shared physical body")
		check(body.source_attributes == ["128","5","8"] and clothes.source_attributes == ["8","128","1"] and body.source_attributes_unresolved,"all-path raw trace and legacy unresolved status remain unchanged")
		var shadow_projection: Dictionary = projection(loaded.tracks.idle.directions[0][0].layers[1])
		check(not shadow_projection.get("ok",true) and shadow_projection.get("origin") == "shadow_requires_parent_actor_flags","101 does not substitute its own128 for parent actor draw flags")
		check(bank.attribute_calls == 6,"each role action validates its three identities once despite repeated directions and tokens")
		var other: Dictionary = loaded.tracks.idle.directions[0][1].layers[0]
		var other_before: Dictionary = other.duplicate(true)
		if body_projection.has("owner_proof"):
			body_projection.flags = 128
			body_projection.owner_proof.declaration.source_line = -1
			body.source_attribute_declarations[0].literal_attribute_directives[0].body = "mutated"
		check(bytes_equal(other,other_before),"converted frame projection and nested owner proof are deep independent values")
		var reloaded: Dictionary = load_metadata(bank,data)
		check(reloaded.get("ok",false) and projection(reloaded.tracks.idle.directions[0][0].layers[0]).get("flags",-1) == 5 and bank.attribute_calls == 12,"reloading clears action projection memo and restores pinned source values")

	# Direct real bank memo API receives JSON-decoded numbers and raw evidence.
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(source_for(ACTOR,0)))
	var source_before: Dictionary = decoded.duplicate(true)
	var memo_bank := MetadataBank.new()
	var memo: Dictionary = {}
	var first: Dictionary = memo_bank._load_action_attributes(decoded,"body",PHYSICAL_BODY,memo)
	var second: Dictionary = memo_bank._load_action_attributes(decoded,"body",PHYSICAL_BODY,memo)
	var cached_before: Dictionary = second.duplicate(true)
	check(first.get("projection",{}).get("ok",false) and first.get("projection",{}).get("flags",-1) == 5 and memo_bank.attribute_calls == 1,"JSON-decoded integral fields normalize only after proof validation and memoize exact projection")
	if first.has("projection"):
		first.projection.flags = 1
		first.projection.owner_proof.declaration.source_line = -1
	first.attributes.append("changed")
	var third: Dictionary = memo_bank._load_action_attributes(decoded,"body",PHYSICAL_BODY,memo)
	check(bytes_equal(second,cached_before) and bytes_equal(third,cached_before) and bytes_equal(decoded,source_before),"projection/raw trace mutations cannot alter memo or pinned DTO evidence")

	for mutation: String in ["wrong_body_owner","wrong_clothes_owner","bad_alias_link","ambiguous_physical_proof","ambiguous_physical_evidence","bad_pin"]:
		var rejected: Dictionary = load_metadata(MetadataBank.new(),metadata_fixture(scratch.path_join(mutation),mutation))
		check(not rejected.get("ok",true),"reject mismatched own/physical proof: " + mutation)
	for mutation: String in ["malformed_own","malformed_alias","absent_own"]:
		var result: Dictionary = load_metadata(MetadataBank.new(),metadata_fixture(scratch.path_join(mutation),mutation))
		check(result.get("ok",false),"keep raw legacy metadata available: " + mutation)
		if not result.get("ok",false): continue
		var layer: Dictionary = result.tracks.idle.directions[0][0].layers[0]
		var selected: Dictionary = projection(layer)
		if mutation == "malformed_own": check(not selected.get("ok",true) and layer.source_attributes == ["8 128","5","8"],"malformed own104 stays explicit unresolved without alias repair or raw deletion")
		elif mutation == "malformed_alias": check(selected.get("ok",false) and selected.get("flags",-1) == 5 and layer.source_attributes[-1] == "not own decimal","unused malformed alias104 remains evidence without poisoning own projection")
		else: check(selected.get("ok",false) and selected.get("flags",-1) == 0 and not selected.get("present",true) and layer.source_attributes == ["8"],"absent own104 remains zero even when alias104 exists")
	print("SOURCE_ATTACHMENT_ATTRIBUTE_BINDING " + JSON.stringify({"checks":checks,"failures":failures,"scratch":scratch,"scope":"pinned bank JSON metadata only; no raw assets, rendering or dynamic actor flags"}))
	quit(0 if failures.is_empty() else 1)
