extends RefCounted
## Exact ItemClass.SpriteID selection for an already admitted ground item.
## Ground dispatch remains an explicit caller contract, separate from UI icons.
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")

static func fail(reason: String, reference: Dictionary = {}) -> Dictionary:
	return {"ok":false,"enabled":true,"status":"source_only_pending","reason":reason,
		"consumer":"ground_item","source_snapshot":"patch523","source_reference":reference.duplicate(true)}

static func select(original_item: Dictionary, context: Dictionary = {}, binding: Dictionary = {}) -> Dictionary:
	var reference: Dictionary = {"table":"ItemClass","row":original_item.duplicate(true),"field":"SpriteID",
		"gameplay_admission":"existing_ground_loot_owner_only; no_spawn_pickup_quantity_or_save_changes_by_visual_loader"}
	if not BANK.integer(original_item.get("ID"),1): return fail("current523_ground_complete_source_item_required",reference)
	var supplied: Dictionary = SOURCE.source_tables(context,["ItemClass"])
	if not supplied.get("ok",false):
		var pending: Dictionary = fail(str(supplied.get("reason","current523_ground_source_tables_unavailable")),reference)
		pending["source_tables_status"] = supplied.duplicate(true)
		return pending
	var native: Dictionary = supplied.by_id.get("ItemClass",{}).get(int(original_item.ID),{})
	if native.is_empty() or native != original_item: return fail("current523_ground_complete_item_definition_differs",reference)
	if not native.get("TestItem") is bool or native.TestItem != false: return fail("current523_test_ground_item_not_admitted",reference)
	if not BANK.integer(native.get("SpriteID"),1): return fail("current523_ground_source_sprite_missing",reference)
	var sprite: int = int(native.SpriteID)
	reference["original_sprite_animation_id"] = native.get("SpriteAnimationID")
	reference["caller_binding"] = binding.duplicate(true)
	if binding.is_empty(): return fail("current523_ground_explicit_binding_required",reference)
	if binding.get("source_snapshot") != "patch523": return fail("current523_ground_binding_snapshot_differs",reference)
	if not BANK.integer(binding.get("item_class_id"),1) or int(binding.item_class_id) != int(native.ID): return fail("current523_ground_binding_item_class_differs",reference)
	if not BANK.integer(binding.get("sprite_id"),1) or int(binding.sprite_id) != sprite: return fail("current523_ground_binding_sprite_differs",reference)
	if not BANK.integer(binding.get("source_action_id")): return fail("current523_ground_explicit_source_action_required",reference)
	if not binding.get("loop_policy") is bool: return fail("current523_ground_explicit_loop_policy_required",reference)
	if not BANK.integer(binding.get("stored_direction"),0,7): return fail("current523_ground_explicit_stored_direction_required",reference)
	var evidence: Variant = binding.get("source_binding_evidence")
	if not evidence is Dictionary or evidence.is_empty(): return fail("current523_ground_binding_evidence_required",reference)
	var action: Dictionary = EFFECT._action(supplied.options,sprite,int(binding.source_action_id))
	if not action.get("ok",false):
		var pending: Dictionary = fail(str(action.get("reason","current523_ground_source_action_unavailable")),reference)
		pending["source_action_status"] = action.duplicate(true)
		return pending
	return {"ok":true,"enabled":true,"status":"selected","consumer":"ground_item","source_snapshot":"patch523",
		"request_key":"current523:item:%d:ground" % int(native.ID),"sprite_id":sprite,
		"role_actions":{"ground":int(action.action_id)},"loop_policy":{"ground":binding.loop_policy},
		"stored_direction":int(binding.stored_direction),"source_reference":reference,
		"source_action_domain":action.source_action_domain,"source_tables_sha256":supplied.source_tables_sha256,
		"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"source_bank_context":{"current523_source_bank":supplied.options.duplicate(true)},
		"host_policy":"existing_ground_position; explicit_caller_action_loop_and_stored_direction; native_dispatch_unverified"}
