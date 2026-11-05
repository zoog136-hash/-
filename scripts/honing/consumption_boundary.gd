extends RefCounted
## Optional public PR262 ABI bridge. Ownership staging is NEVER effect approval.
## No save/adopt/RNG/UI call exists here until the source outcome rules are known.
const Ownership = preload("res://scripts/honing/ownership.gd")
const ABI_PATH: String = "res://scripts/quests/quest_reward_consumption.gd"
const ABI_SHA: String = "a3043db1af182db8a80bf88fb5de6d9cc78980f14f19ca06cdf5e1443c4472b3"
const SOURCE_SHA: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SOURCE_BYTES: int = 25031173
const BLOCKERS: Array[String] = ["cost_relation_unverified", "probability_scale_unverified", "failure_transition_unverified", "destruction_transition_unverified", "source_effect_binding_unverified"]

static func fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"use_authorized":false}

static func _abi() -> Variant:
	# Do not vendor another owner's engine or silently accept an unreviewed ABI.
	if not FileAccess.file_exists(ABI_PATH) or FileAccess.get_sha256(ABI_PATH) != ABI_SHA: return null
	if not FileAccess.file_exists("res://scripts/quests/quest_reward_ownership.gd"): return null
	return load(ABI_PATH)

static func source_matches(path: String) -> bool:
	# Caller supplies an existing private path; never download, install or search.
	if path.is_empty() or not FileAccess.file_exists(path): return false
	var source: FileAccess = FileAccess.open(path,FileAccess.READ)
	if source == null or source.get_length() != SOURCE_BYTES: return false
	var bytes: PackedByteArray = source.get_buffer(SOURCE_BYTES + 1)
	var read_error: Error = source.get_error()
	source.close()
	if bytes.size() != SOURCE_BYTES or read_error not in [OK,ERR_FILE_EOF]: return false
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode() == SOURCE_SHA

static func review(world: Node, target_id: String, requests: Array, source_zip_path: String) -> Dictionary:
	if not source_matches(source_zip_path): return fail("verified_local_source_missing")
	var abi: Variant = _abi()
	if abi == null: return fail("public_262_consumption_abi_missing")
	return _review_with(world,target_id,requests,SOURCE_SHA,abi)

static func _review_with(world: Node, target_id: String, requests: Array, digest: String, abi: Variant) -> Dictionary:
	# This helper is also exercised with explicit synthetic ABI spies. Its output
	# remains a read-only ownership proposal, even if invoked directly.
	if digest != SOURCE_SHA: return fail("consumer_source_digest_mismatch")
	var target: Dictionary = Ownership.inspect(world.inventory,world.item_instances,target_id)
	if not target.get("ok",false): return fail(str(target.get("code","invalid_target")))
	if not world.has_method("_item_locked") or world.call("_item_locked",target.name,target_id): return fail("target_locked_or_lock_contract_missing")
	var record: Variant = target.instance.get("record",{})
	if not record is Dictionary: return fail("source_identity_unverified")
	var source_id: int = Ownership._count(record.get("source_item_class_id"))
	if source_id <= 0 or record.get("sourceId") != "m523:item:" + str(source_id): return fail("source_identity_unverified")
	if requests.is_empty(): return fail("no_selected_receipt_materials")
	var selected: Dictionary = {}
	for request: Variant in requests:
		if not request is Dictionary or request.size() != 5: return fail("invalid_request")
		for key: String in ["physical_id","quantity","expected_quantity","expected_remaining","quest_reward_receipt"]:
			if not request.has(key): return fail("invalid_request")
		var id: Variant = request.physical_id
		if not id is String or id.is_empty() or id == target_id or selected.has(id): return fail("duplicate_or_target_material")
		selected[id] = true
		var quantity: int = Ownership._count(request.quantity)
		var before: int = Ownership._count(request.expected_quantity)
		var after: int = Ownership._count(request.expected_remaining)
		if quantity <= 0 or before < quantity or after != before - quantity or not request.quest_reward_receipt is Dictionary: return fail("invalid_request")
	if not abi.available(world): return fail("public_262_ownership_state_missing")
	var step: Dictionary = abi.stage(world,requests.duplicate(true),digest)
	if not step.get("ok",false): return step.duplicate(true)
	if step.get("use_authorized",true) != false or not step.get("overrides") is Dictionary: return fail("invalid_abi_candidate")
	for key: String in ["inventory","item_instances","quest_state"]:
		if not step.overrides.get(key) is Dictionary: return fail("invalid_abi_candidate")
	# A material candidate must leave the target and its unknown state intact.
	if not same(step.overrides.item_instances.get(target_id),world.item_instances.get(target_id)): return fail("target_changed_during_stage")
	if not abi.current(world,step) or not abi.matches_payload(world,step,step.overrides): return fail("stale_ownership_candidate")
	return {"ok":true,"use_authorized":false,"blockers":BLOCKERS.duplicate(),
		"target_id":target_id,"source_item_class_id":source_id,"target_before":target.instance.duplicate(true),
		"consumer_data_sha256":digest,"abi_step":step.duplicate(true),
		"payload":step.overrides.duplicate(true)}

static func matches_payload(world: Node, review_result: Dictionary, payload: Dictionary, source_zip_path: String) -> bool:
	if not source_matches(source_zip_path): return false
	var abi: Variant = _abi()
	return abi != null and _matches_with(world,review_result,payload,abi)

static func _matches_with(world: Node, review_result: Dictionary, payload: Dictionary, abi: Variant) -> bool:
	if review_result.get("ok") != true or review_result.get("use_authorized") != false: return false
	var target_id: Variant = review_result.get("target_id")
	if not target_id is String or not same(world.item_instances.get(target_id),review_result.get("target_before")): return false
	# Until original outcome rules exist, even this preview rejects target edits.
	if not payload.get("item_instances") is Dictionary or not same(payload.item_instances.get(target_id),review_result.target_before): return false
	if not review_result.get("abi_step") is Dictionary: return false
	return abi.current(world,review_result.abi_step) and abi.matches_payload(world,review_result.abi_step,payload)

static func same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
