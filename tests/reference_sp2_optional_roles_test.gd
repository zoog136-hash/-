extends "res://tests/benchmark_reference_sp2_attributes.gd"
## Invented SP2/action records compare the complete selection to the prior
## independent optional probes. No original pack or timing threshold.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const ALT_ACTOR: int = ACTOR + 10

class LegacyPreview:
	extends "res://scripts/animation/original_source_preview.gd"
	# Exact pre-optimization dispatch, retained here as a result oracle.
	func _configure_selected_roles_measured(selected: Dictionary, initial_role: String) -> bool:
		# Selection/admission belongs to the existing card/NPC caller. Each optional
		# action is admitted independently, so missing HIT cannot remove valid RUN.
		var actions: Dictionary = selected.role_actions.duplicate()
		var loops: Dictionary = selected.loop_policy.duplicate()
		var role_actors: Dictionary = selected.get("role_actor_ids",{}).duplicate()
		var run_status: Dictionary = selected.get("run_status",{}).duplicate(true)
		var optional_status: Dictionary = {}
		for role: String in selected.get("optional_role_actions",{}):
			if actions.has(role): continue
			var loop: Variant = selected.get("optional_role_loop_policy",{}).get(role,true if role == "run" else null)
			var actor: Variant = selected.get("optional_role_actor_ids",{}).get(role)
			if not loop is bool or not REFERENCE_BANK.integer(actor,1):
				optional_status[role] = {"state":"optional_source_role_contract_missing"}
				continue
			var action: int = int(selected.optional_role_actions[role])
			var probe := REFERENCE_BANK.new()
			var loaded: Dictionary = probe.load_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),{role:action},{role:loop},str(selected.consumer),{role:int(actor)})
			if not loaded.ok:
				optional_status[role] = {"state":"optional_source_action_unavailable","bank_problem":loaded.get("error","")}
				continue
			actions[role] = action
			loops[role] = loop
			role_actors[role] = int(actor)
			optional_status[role] = {"state":"selected_source_declared_optional_action","action_id":action,"source_actor_id":int(actor)}
		var configured: bool = _configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),actions,loops,initial_role,str(selected.consumer),role_actors)
		if not configured and not optional_status.is_empty():
			var problem: String = str(reference_bank_status.get("error","optional_source_actions_unavailable"))
			for role: String in optional_status:
				optional_status[role] = {"state":"optional_source_action_unavailable","bank_problem":problem}
			actions = selected.role_actions.duplicate()
			loops = selected.loop_policy.duplicate()
			role_actors = selected.get("role_actor_ids",{}).duplicate()
			configured = _configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),actions,loops,initial_role,str(selected.consumer),role_actors)
		if selected.get("optional_role_actions",{}).has("run"):
			run_status["state"] = "selected_source_declared_run" if configured and actions.has("run") else "source_declared_run_unavailable_existing_walk"
			if optional_status.get("run",{}).has("bank_problem"): run_status["bank_problem"] = optional_status.run.bank_problem
		selected["role_actions"] = actions
		selected["loop_policy"] = loops
		selected["role_actor_ids"] = role_actors
		selected["run_status"] = run_status
		selected["optional_role_status"] = optional_status
		reference_bank_status["run_status"] = run_status.duplicate(true)
		reference_bank_status["optional_role_status"] = optional_status.duplicate(true)
		return configured

func dummy_exclusion(actor: int) -> Dictionary:
	return {"source_snapshot":"patch523","reason":"source_literal_dummy","originals_preserved":true,"raw_member_namespace_excluded":false,
		"dummy_declarations":[{"sprite_id":actor,"literal_name":"fixture_dummy","literal_declaration":"fixture_dummy","matched_literal":"dummy","source_file":"list_9.spr","source_line":1,"source_sha256":"d".repeat(64)}],
		"source_graph_paths":[{"kind":"source_declared_root","sprite_ids":[actor]}]}

func fixture(directory: String, mutation: String = "") -> Dictionary:
	var data: Dictionary = super.fixture(directory)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	var alternate: Dictionary = {}
	for index: int in range(3):
		var member: String = "Sprite/%d-0.sp2" % (ALT_ACTOR + index)
		var relative: String = "raw/" + member
		write_bytes(directory.path_join(relative),make_sp2(0x55 if index == 1 else 0xff,index == 2))
		manifest.members[member] = {"member":member,"path":relative,"sha256":FileAccess.get_sha256(directory.path_join(relative)),"bytes":FileAccess.get_size(directory.path_join(relative))}
	var text: String = JSON.stringify(source_action(7))
	for index: int in range(3): text = text.replace(str(ACTOR+index),str(ALT_ACTOR+index))
	var source: Dictionary = JSON.parse_string(text)
	var relative: String = "actors/%d/action-7.json" % ALT_ACTOR
	alternate["7"] = {"path":relative,"sha256":write_json(directory.path_join(relative),source)}
	manifest.actors["sprite:"+str(ALT_ACTOR)] = alternate
	var hit_path: String = directory.path_join("actors/%d/action-2.json" % ACTOR)
	if mutation == "malformed_optional":
		var hit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(hit_path))
		hit.source_layer_declarations[2].declaration_path[0].source_sha256 = "f".repeat(64)
		manifest.actors["sprite:"+str(ACTOR)]["2"].sha256 = write_json(hit_path,hit)
	elif mutation == "tampered_action":
		write_bytes(hit_path,FileAccess.get_file_as_bytes(hit_path)+PackedByteArray([32]))
	elif mutation == "tampered_member":
		write_bytes(data.raw,FileAccess.get_file_as_bytes(data.raw)+PackedByteArray([0]))
	elif mutation == "malformed_core":
		var core_path: String = directory.path_join("actors/%d/action-3.json" % ACTOR)
		var core: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(core_path))
		core.source_layer_declarations[2].declaration_path[0].source_sha256 = "f".repeat(64)
		manifest.actors["sprite:"+str(ACTOR)]["3"].sha256 = write_json(core_path,core)
	elif mutation == "excluded_root":
		manifest.excluded_source_actors["sprite:"+str(ACTOR)] = dummy_exclusion(ACTOR)
	elif mutation == "unsafe_optional_entry":
		manifest.actors["sprite:"+str(ALT_ACTOR)]["7"].path = "../outside.json"
	data.sha = write_json(data.path,manifest)
	return data

func selection(data: Dictionary, kind: String) -> Dictionary:
	var selected: Dictionary = {"manifest_path":data.path,"manifest_sha256":data.sha,"sprite_id":ACTOR,"consumer":"npc",
		"role_actions":{"idle":3,"walk":0,"attack":1,"death":8},"loop_policy":{"idle":true,"walk":true,"attack":false,"death":false},"role_actor_ids":{},
		"run_status":{"preserved_literal":"fixture_run"},"optional_role_actions":{"run":7,"hit":2},"optional_role_loop_policy":{"run":true,"hit":false},"optional_role_actor_ids":{"run":ALT_ACTOR,"hit":ACTOR}}
	match kind:
		"missing_one": selected.optional_role_actions.hit = 99
		"missing_both": selected.optional_role_actions = {"run":98,"hit":99}
		"missing_actor": selected.optional_role_actor_ids.run = ALT_ACTOR+100
		"bad_contract": selected.optional_role_actor_ids.hit = 0
		"missing_loop": selected.optional_role_loop_policy.erase("hit")
		"overlapping_core": selected.optional_role_actions.idle = 99
		"no_optional": selected.optional_role_actions.clear()
		"one_optional": selected.optional_role_actions.erase("hit")
		"bad_manifest_pin": selected.manifest_sha256 = "0".repeat(64)
	return selected

func observed(view: Node2D, selected: Dictionary) -> Dictionary:
	HITCH._details.clear()
	HITCH._counters.clear()
	var started: int = Time.get_ticks_usec()
	var ok: bool = view._configure_selected_roles(selected,"idle")
	var elapsed: int = Time.get_ticks_usec()-started
	var snapshot: Dictionary = {"ok":ok,"selected":selected,"status":view.reference_bank_status,"record":view._record,"tracks":view._playback_tracks,"role":view._role,"layer_count":view._layers.size()}
	return {"us":elapsed,"bank_calls":HITCH._details.get("sp2.bank_load",[0,0,0])[1],"counters":HITCH._counters.duplicate(),"snapshot":snapshot}

func run() -> void:
	token_count = 4
	var cases: Array = []
	for kind: String in ["valid","one_optional","no_optional","missing_one","missing_both","missing_actor","bad_contract","missing_loop","overlapping_core","malformed_optional","tampered_action","tampered_member","malformed_core","excluded_root","unsafe_optional_entry","bad_manifest_pin"]:
		var data: Dictionary = fixture("user://optional_roles_%d/%s" % [OS.get_process_id(),kind],kind)
		var before_view := LegacyPreview.new()
		var after_view := PREVIEW.new()
		var before: Dictionary = observed(before_view,selection(data,kind))
		var after: Dictionary = observed(after_view,selection(data,kind))
		check(bytes_equal(before.snapshot,after.snapshot),"complete dispatch/status/record/tracks equality: "+kind)
		check(before.snapshot.ok == (kind not in ["tampered_member","malformed_core","excluded_root","bad_manifest_pin"]),"expected admission result: "+kind)
		if kind in ["valid","one_optional","bad_contract","missing_loop","overlapping_core"]:
			check(after.bank_calls == 1 and before.bank_calls > after.bank_calls,"valid combined roles use one bank load: "+kind)
		elif kind in ["missing_one","missing_both","missing_actor","unsafe_optional_entry","bad_manifest_pin","no_optional"]:
			check(before.bank_calls == after.bank_calls,"known missing/unsafe optional entry avoids failed full attempt: "+kind)
			check(before.counters.get("sp2.layer_validate",0) == after.counters.get("sp2.layer_validate",0),"known missing path has identical layer work: "+kind)
		if kind in ["missing_one","malformed_optional","tampered_action"]:
			check(after.snapshot.selected.role_actions.has("run") and not after.snapshot.selected.role_actions.has("hit"),"valid alternate-actor RUN survives unavailable HIT: "+kind)
		if kind == "valid":
			check(before.counters.get("sp2.layer_validate") == 768 and after.counters.get("sp2.layer_validate") == 576,"optional expansion deterministic counters 768 to 576")
			check(after.counters.get("sp2.attribute_validate") == 18 and before.counters.get("sp2.attribute_validate") == 24,"existing action memo remains scoped to one load")
			check(after.snapshot.record.role_actor_ids.run == ALT_ACTOR,"separate RUN actor identity retained")
			for role: String in ["idle","walk","attack","death","run","hit"]:
				for direction: int in range(8):
					var first: Dictionary = before.snapshot.record.tracks[role].directions[direction][0].layers[0]
					var second: Dictionary = after.snapshot.record.tracks[role].directions[direction][0].layers[0]
					var old_pixels: Dictionary = before_view._reference_bank.render_layer(first)
					var new_pixels: Dictionary = after_view._reference_bank.render_layer(second)
					check(old_pixels.get("ok",false) and new_pixels.get("ok",false) and old_pixels.offset == new_pixels.offset and old_pixels.image.get_data() == new_pixels.image.get_data(),"role/direction exact pixels: %s %d" % [role,direction])
		before.erase("snapshot"); after.erase("snapshot")
		cases.append({"kind":kind,"before":before,"after":after})
		before_view.free(); after_view.free()
	# Reuse the same owner: neither a previous successful optional nor its
	# failed fallback may contaminate the next request.
	var valid_data: Dictionary = fixture("user://optional_reload_%d/valid" % OS.get_process_id())
	var missing_data: Dictionary = fixture("user://optional_reload_%d/missing" % OS.get_process_id())
	var previous := LegacyPreview.new()
	var current := PREVIEW.new()
	for request: String in ["valid","missing_one","valid"]:
		var data: Dictionary = valid_data if request == "valid" else missing_data
		check(bytes_equal(observed(previous,selection(data,request)).snapshot,observed(current,selection(data,request)).snapshot),"same-owner reload preserves exact optional state: "+request)
	previous.free(); current.free()
	var result: Dictionary = {"checks":checks,"failures":failures,"cases":cases,"synthetic_only":true,"android_measured":false}
	print("REFERENCE_SP2_OPTIONAL_ROLES_RESULT "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
