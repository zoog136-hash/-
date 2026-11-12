extends "res://tests/reference_sp2_load_memo_test.gd"
## Synthetic pinned JSON/raw-byte fixtures, not original art or admission proof.
## The actual bank loader and decoder run; only test files in isolated user://
## are created. Distinct clothes IDs deliberately share identical fixture bytes.
const PREFIX_POLICY: String = "first_null_asset_retains_successful_clothes_prefix"

class ObservedBank:
	extends "res://scripts/resources/reference_sp2_bank.gd"
	var member_reads: Array[String] = []
	func _member(member: String) -> Dictionary:
		member_reads.append(member)
		return super._member(member)

func frame_set_empty_sp2() -> PackedByteArray:
	var bytes := PackedByteArray([254,4])
	for word: int in [0xf800,0x07e0,0x001f,0xffff]: put16(bytes,word)
	bytes.append(255)
	for direction: int in range(8):
		bytes.append(0) # Present direction, zero stored frames.
		bytes.append_array(PackedByteArray([0,0,0,0])) # Zero blocks.
	return bytes

func five_layer_source(action: int, options: Dictionary) -> Dictionary:
	var source: Dictionary = super.source_action(action)
	var role: String = "source_action:" + str(action)
	for layer_index: int in [3,4]:
		var sprite: int = ACTOR+layer_index
		var spec: Dictionary = source.compact_roles[role].layers[2].duplicate(true)
		spec.source_sprite_id = sprite
		source.compact_roles[role].layers.append(spec)
		var proof: Dictionary = source.source_proof.declarations[2].duplicate(true)
		proof.declaration_path[0].sprite_id = sprite
		proof.declaration_path[0].source_line = 10+layer_index
		source.source_proof.declarations.append(proof)
		var attributes: Dictionary = source.source_layer_declarations[2].duplicate(true)
		attributes.source_sprite_id = sprite
		attributes.declaration_path[0].sprite_id = sprite
		attributes.declaration_path[0].source_line = 10+layer_index
		source.source_layer_declarations.append(attributes)
		for frames: Array in source.actor.roles[role].directions:
			for frame: Dictionary in frames:
				var layer: Dictionary = frame.layers[2].duplicate(true)
				layer.source_sprite_id = sprite
				layer.member = "Sprite/%d-0.sp2" % sprite
				frame.layers.append(layer)
	var reset: bool = bool(options.get("reset",false))
	if reset:
		for token_index: int in [1,3]:
			source.compact_roles[role].tokens[token_index][0] = 8
			source.source_proof.roles[role].tokens[token_index][0] = 8
		for frames: Array in source.actor.roles[role].directions:
			for token_index: int in [1,3]:
				for layer: Dictionary in frames[token_index].layers:
					layer.member = "Sprite/%d-8.sp2" % int(layer.source_sprite_id)
	for direction: int in range(8):
		for token_index: int in range(TOKENS.size()):
			var layers: Array = source.actor.roles[role].directions[direction][token_index].layers
			if options.get("middle_missing",false): layers[3]["client_null"] = "direction_absent"
			if options.get("all_blocked",false): layers[2]["client_null"] = "direction_absent"
			if options.get("body_missing",false): layers[0]["client_null"] = "direction_absent"
			if options.get("shadow_missing",false): layers[1]["client_null"] = "direction_absent"
			if options.get("empty_frame_set",false): layers[2]["client_null"] = "empty_frame_set"
			if reset and direction == 0 and token_index in [0,2]: layers[2]["client_null"] = "direction_absent"
			if options.get("explicit_stop",false):
				layers[4]["client_null"] = "clothes_prefix_stopped"
				layers[4]["clothes_prefix_stop_layer_index"] = options.get("stop_index",3)
			if options.get("orphan_stop",false):
				layers[2]["client_null"] = "clothes_prefix_stopped"
				layers[2]["clothes_prefix_stop_layer_index"] = 2
			if options.get("unknown_marker",false): layers[2]["client_null"] = "invented_null_reason"
	var declared_contract: Dictionary = contract()
	if not options.get("legacy",false): declared_contract["clothes_collection_policy"] = options.get("policy",PREFIX_POLICY)
	source.consumer_contract = declared_contract
	return source

func prefix_fixture(directory: String, options: Dictionary = {}) -> Dictionary:
	var members: Dictionary = {}
	var first_clothes_path: String = ""
	for group: int in ([0,8] if options.get("reset",false) else [0]):
		for layer_index: int in range(5):
			var member: String = "Sprite/%d-%d.sp2" % [ACTOR+layer_index,group]
			var mask: int = 0x55 if layer_index == 1 else 0xff
			if options.get("middle_missing",false) and layer_index == 3: mask = 0
			if options.get("all_blocked",false) and layer_index == 2: mask = 0
			if options.get("body_missing",false) and layer_index == 0: mask = 0
			if options.get("shadow_missing",false) and layer_index == 1: mask = 0
			if options.get("reset",false) and layer_index == 2 and group == 0: mask = 0xfe
			var bytes: PackedByteArray = frame_set_empty_sp2() if options.get("empty_frame_set",false) and layer_index == 2 else make_sp2(mask,layer_index >= 2)
			var raw_path: String = directory.path_join("raw/"+member)
			if not (options.get("omit_later_raw",false) and layer_index >= 3): write_bytes(raw_path,bytes)
			members[member] = {"member":member,"path":"raw/"+member,"sha256":BANK.digest(bytes),"bytes":bytes.size()}
			if layer_index == 2 and group == 0: first_clothes_path = raw_path
	var actions: Dictionary = {}
	var declared_contract: Dictionary = {}
	for action: int in [0,3]:
		var source: Dictionary = five_layer_source(action,options)
		declared_contract = source.consumer_contract
		var relative: String = "actors/%d/action-%d.json" % [ACTOR,action]
		actions[str(action)] = {"path":relative,"sha256":write_json(directory.path_join(relative),source)}
	var manifest: Dictionary = {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","consumer_contract":declared_contract,"source_dummy_exclusion_policy":BANK.SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{},"members":members,"actors":{"sprite:"+str(ACTOR):actions}}
	var path: String = directory.path_join("manifest.json")
	return {"path":path,"sha":write_json(path,manifest),"first_clothes":first_clothes_path,"members":members}

func selected(loaded: Dictionary, role: String = "idle", direction: int = 0, token: int = 0) -> Array:
	return loaded.tracks[role].directions[direction][token].effect_layers

func no_prefix_stop(layers: Array) -> bool:
	for layer: Dictionary in layers:
		if layer.get("client_null","") == "clothes_prefix_stopped": return false
	return true

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scratch = "user://source_clothes_prefix_bank_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	ASSETS.reset_for_tests()
	BANK.forget_verified_members()
	var normal_data: Dictionary = prefix_fixture(scratch.path_join("success"))
	var normal := ObservedBank.new()
	var success: Dictionary = open(normal,normal_data)
	check(success.get("ok",false),"five-layer pinned JSON and synthetic byte bank loads: "+str(success.get("error","")))
	if success.get("ok",false):
		var clothes: Array = selected(success)
		check(clothes.size() == 3 and no_prefix_stop(clothes),"three successful clothes keep source order and none is dropped")
		check(clothes.map(func(layer: Dictionary) -> int: return int(layer.layer_id)) == [ACTOR+2,ACTOR+3,ACTOR+4],"identical raw bytes retain three physical source identities")
		check(normal_data.members["Sprite/9003-0.sp2"].sha256 == normal_data.members["Sprite/9004-0.sp2"].sha256 and normal_data.members["Sprite/9004-0.sp2"].sha256 == normal_data.members["Sprite/9005-0.sp2"].sha256,"the three distinct clothes files deliberately have identical fixture bytes")

	var prefix_bank := ObservedBank.new()
	var prefix: Dictionary = open(prefix_bank,prefix_fixture(scratch.path_join("middle_missing"),{"middle_missing":true}))
	check(prefix.get("ok",false),"first missing middle clothes asset retains successful prefix")
	if prefix.get("ok",false):
		var clothes: Array = selected(prefix)
		check(not clothes[0].texture_key.is_empty() and not clothes[0].has("client_null"),"successful first clothes remains loadable")
		check(clothes[1].client_null == "direction_absent" and clothes[2].get("client_null") == "clothes_prefix_stopped","first null is retained and later clothes becomes a provenance placeholder")
		check(clothes[2].get("clothes_prefix_stop_layer_index",-1) == 3,"stop provenance uses frame.layers index3, not clothes-local index1")
		check(not prefix_bank.member_reads.has("Sprite/9005-0.sp2"),"later clothes raw file is never opened after middle null")
		check(selected(prefix,"idle",0,1)[0].get("frame_provenance",{}).get("empty",false),"a legitimate transparent frame in successful first asset does not itself stop collection")

	var blocked_data: Dictionary = prefix_fixture(scratch.path_join("all_blocked"),{"all_blocked":true,"omit_later_raw":true})
	var blocked_bank := ObservedBank.new()
	var blocked: Dictionary = open(blocked_bank,blocked_data)
	check(blocked.get("ok",false),"all-blocked prefix loads without nonexistent later raw files: "+str(blocked.get("error","")))
	check(not FileAccess.file_exists(blocked_data.path.get_base_dir().path_join("raw/Sprite/9004-0.sp2")) and not FileAccess.file_exists(blocked_data.path.get_base_dir().path_join("raw/Sprite/9005-0.sp2")),"later raw files are actually absent in the isolated fixture")
	check(not blocked_bank.member_reads.has("Sprite/9004-0.sp2") and not blocked_bank.member_reads.has("Sprite/9005-0.sp2"),"stop prevents all later raw reads across every direction, token and role")
	if blocked.get("ok",false):
		var clothes: Array = selected(blocked)
		check(clothes[0].client_null == "direction_absent" and clothes[1].get("clothes_prefix_stop_layer_index",-1) == 2 and clothes[2].get("clothes_prefix_stop_layer_index",-1) == 2,"first clothes null keeps both later placeholders bound to frame layer2")

	for missing: String in ["body_missing","shadow_missing"]:
		var result: Dictionary = open(ObservedBank.new(),prefix_fixture(scratch.path_join(missing),{missing:true}))
		check(result.get("ok",false),"non-clothes null permits bank load: "+missing)
		if result.get("ok",false): check(no_prefix_stop(selected(result)) and not selected(result)[2].texture_key.is_empty(),"body/shadow null never gates three clothes: "+missing)

	var reset: Dictionary = open(ObservedBank.new(),prefix_fixture(scratch.path_join("reset"),{"reset":true}))
	check(reset.get("ok",false),"different parent-addressed group fixtures load for reset checks")
	if reset.get("ok",false):
		check(selected(reset,"idle",0,0)[2].get("client_null") == "clothes_prefix_stopped","group0 absent direction0 starts a prefix stop")
		check(no_prefix_stop(selected(reset,"idle",0,1)) and not selected(reset,"idle",0,1)[2].texture_key.is_empty(),"next frame group8 succeeds without prior frame stop state")
		check(no_prefix_stop(selected(reset,"idle",1,0)) and not selected(reset,"idle",1,0)[2].texture_key.is_empty(),"next direction starts a fresh prefix despite a null shadow")
		check(no_prefix_stop(selected(reset,"attack",1,0)),"another role action does not inherit an earlier stop")

	var empty_data: Dictionary = prefix_fixture(scratch.path_join("empty_frame_set"),{"empty_frame_set":true})
	var decoded: Dictionary = DECODER.parse(FileAccess.get_file_as_bytes(empty_data.first_clothes))
	check(decoded.get("ok",false) and decoded.groups.size() == 8,"empty frame-set fixture is a valid decoded asset with eight directions")
	if decoded.get("ok",false):
		for group: Dictionary in decoded.groups: check(group.frames.is_empty(),"present direction has zero stored frames")
	var empty_bank := ObservedBank.new()
	var empty_result: Dictionary = open(empty_bank,empty_data)
	check(empty_result.get("ok",false),"empty Graphics frame vector remains a valid collected asset")
	if empty_result.get("ok",false):
		check(selected(empty_result)[0].client_null == "empty_frame_set" and no_prefix_stop(selected(empty_result)),"empty frame-set null marker differs from null asset direction")
		check(empty_bank.member_reads.has("Sprite/9004-0.sp2") and empty_bank.member_reads.has("Sprite/9005-0.sp2"),"valid empty first asset permits all later clothes raw reads")

	var explicit: Dictionary = open(ObservedBank.new(),prefix_fixture(scratch.path_join("explicit_stop"),{"middle_missing":true,"explicit_stop":true}))
	check(explicit.get("ok",false),"compiler-supplied correct prefix placeholder provenance is accepted")
	for bad: Dictionary in [{"middle_missing":true,"explicit_stop":true,"stop_index":2},{"middle_missing":true,"explicit_stop":true,"stop_index":3.5},{"orphan_stop":true},{"unknown_marker":true},{"policy":"invented_policy"},{"policy":0}]:
		var rejected: Dictionary = open(ObservedBank.new(),prefix_fixture(scratch.path_join("bad_%d" % checks),bad))
		check(not rejected.get("ok",true),"reject orphan, invalid provenance, marker or unknown policy: "+JSON.stringify(bad))

	var legacy_bank := ObservedBank.new()
	var legacy: Dictionary = open(legacy_bank,prefix_fixture(scratch.path_join("legacy"),{"legacy":true,"middle_missing":true}))
	check(legacy.get("ok",false),"old contract without collection policy still loads")
	if legacy.get("ok",false): check(selected(legacy)[1].client_null == "direction_absent" and not selected(legacy)[2].has("client_null") and legacy_bank.member_reads.has("Sprite/9005-0.sp2"),"legacy explicitly continues to later clothes as before")
	var legacy_blocked: Dictionary = open(ObservedBank.new(),prefix_fixture(scratch.path_join("legacy_missing_later"),{"legacy":true,"all_blocked":true,"omit_later_raw":true}))
	check(not legacy_blocked.get("ok",true),"legacy continuation still requires the later raw bytes it attempts")
	print("SOURCE_CLOTHES_PREFIX_BANK "+JSON.stringify({"checks":checks,"failures":failures,"scratch":scratch,"synthetic_only":true,"original_admission_or_pixels_verified":false}))
	quit(0 if failures.is_empty() else 1)
