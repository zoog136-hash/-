extends RefCounted
## Exact current source visuals for an encounter already admitted by map policy.
## Source stats, placement, counts and respawn remain with the existing monster path.
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
# tools/monsters/build_base508_monster_pack_v2.py uses these same core roles.
# Current ListSprAction supplies their typed MotionType/weapon family below.
const CORE_ACTIONS = {"idle":3, "walk":0, "attack":1, "hit":2, "death":8}
const CORE_MOTIONS = {"idle":4, "walk":1, "attack":2, "hit":3, "death":5}
const LOOPS = {"idle":true, "walk":true, "attack":false, "hit":false, "death":false}
const ADMITTED_NPC_FIELDS = ["ID", "Sprite", "HP", "MP", "AC", "MR", "Exp", "Category", "IsOccupyLandTile", "TestNPC"]
const SOURCE_ONLY_REQUEST = "current523_source_only"
const CURRENT_ADMISSION_IDENTITY = "current523_npc_source_identity"

static func source_only_request(record: Dictionary) -> bool:
	# This explicit Sprite request flag is a caller contract, not a saved ABI or
	# an invented field in the source tables. Current definition provenance also
	# keeps a new m508-identified record from reopening the historical media path.
	if record.get(SOURCE_ONLY_REQUEST) == true or record.get("source_m_current523_final") == true or record.get("source_m_definition_snapshot") == "patch523": return true
	for field: String in ["content_snapshot", "source_content_snapshot"]:
		if record.get(field) == "patch523": return true
	var original: Variant = record.get("source_m_original")
	if not original is Dictionary: return false
	if original.get("source_snapshot") == "patch523" or original.get("content_snapshot") == "patch523": return true
	var archive: Variant = original.get("source_definition_archive")
	return archive is Dictionary and archive.get("source_snapshot") == "patch523"

static func fail(reason: String, source_only: bool = false) -> Dictionary:
	return {"ok":false,"status":"source_only_pending" if source_only else "selection_pending","reason":reason,"consumer":"npc","source_snapshot":"patch523",SOURCE_ONLY_REQUEST:source_only,"source_only":source_only,"legacy_media_fallback_allowed":not source_only}

static func select(record: Dictionary, admission: Dictionary) -> Dictionary:
	var source_only: bool = source_only_request(record)
	if admission.get("ok") != true or admission.get("applied") != true or admission.get("record") != record:
		return fail("current523_existing_spawn_policy_admission_required",source_only)
	var admitted: Variant = record.get("source_m_patch523_admission")
	var context: Variant = record.get("source_m_context")
	if record.get("source") != "lineagem_base508" or not admitted is Dictionary or not context is Dictionary:
		return fail("current523_explicit_npc_source_context_required",source_only)
	if admitted.get("snapshot") != "patch523" or not BANK.valid_sha(admitted.get("manifest_sha256")):
		return fail("current523_current_map_admission_required",source_only)
	for field: String in ["source_m_npc_id", "source_m_sprite_id", "source_m_spawn_view_id", "source_m_territory_link_id"]:
		if not BANK.integer(record.get(field),0 if field == "source_m_sprite_id" else 1):
			return fail("current523_explicit_npc_identity_required",source_only)
	var npc_id: int = int(record.source_m_npc_id)
	var sprite_id: int = int(record.source_m_sprite_id)
	var view_id: int = int(record.source_m_spawn_view_id)
	var territory_link_id: int = int(record.source_m_territory_link_id)
	var request_key: String = "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id,view_id,territory_link_id]
	if record.get("sourceId") != request_key or admitted.get("npc_id") != npc_id or admitted.get("spawn_view_id") != view_id or admitted.get("territory_link_id") != territory_link_id:
		return fail("current523_admitted_npc_identity_differs",source_only)
	if admitted.get("is_spawn") != 1 or admitted.get("server_limit_set_id") != 0 or str(admitted.get("host_map_id","")).is_empty() or admitted.get("placement_policy") != "EXISTING_HOST_POSITION_COUNT_RESPAWN_RETAINED":
		return fail("current523_existing_host_placement_admission_required",source_only)
	if bool(record.get("catalog_only",false)) or str(record.get("source_m_host_placement","")).is_empty():
		return fail("current523_catalog_record_is_not_a_host_encounter",source_only)
	for field: String in ["land", "territory", "territory_link", "spawn_view", "npc"]:
		if not context.get(field) is Dictionary: return fail("current523_complete_admitted_npc_context_required",source_only)
	if context.npc.get("ID") != npc_id or context.npc.get("Sprite") != sprite_id or context.spawn_view.get("ID") != view_id or context.spawn_view.get("NpcClassID") != npc_id or context.territory_link.get("ID") != territory_link_id:
		return fail("current523_npc_context_identity_differs",source_only)
	var supplied: Dictionary = SOURCE.source_tables(record)
	if not supplied.ok: return fail(str(supplied.get("reason","current523_original_visual_input_unavailable")),source_only)
	var native: Dictionary = SOURCE.table_row("NpcClass",npc_id)
	if native.is_empty() or native.get("Sprite") != sprite_id:
		return fail("current523_exact_npcclass_sprite_missing",source_only)
	var definition_admission: Dictionary = {}
	var definition_archive: Dictionary = {}
	var definition_selection_only: bool = false
	if source_only:
		# Pre-spawn selection cannot require an actor registry that is created
		# only later by Monster.setup. Its explicit final-input marker, archive
		# pin and complete original row establish definition selection only.
		var current_final: bool = record.get("source_m_current523_final") == true
		var original: Variant = record.get("source_m_original")
		if not original is Dictionary or (not current_final and record.get("source_m_definition_snapshot") != "patch523") or record.get("source_m_definition_archive_sha256") != supplied.source_tables_sha256:
			return fail("current523_original_npc_definition_origin_required",true)
		for field: String in native:
			if not original.has(field) or original[field] != native[field]:
				return fail("current523_complete_original_npc_definition_differs:" + field,true)
		for field: String in ["ID", "Sprite", "DescId"]:
			if not BANK.integer(native.get(field)) or original.get(field) != native[field] or context.npc.get(field) != native[field]:
				return fail("current523_explicit_npc_definition_identity_differs:" + field,true)
		if admission.has(CURRENT_ADMISSION_IDENTITY):
			# A supplied bad/empty identity is a failure, never an invitation to
			# downgrade to the pre-spawn metadata-only path.
			var identity: Variant = admission[CURRENT_ADMISSION_IDENTITY]
			if not identity is Dictionary or identity.get("source_snapshot") != "patch523" or identity.get("source_archive_sha256") != supplied.source_tables_sha256 or identity.get("npc_class_id") != npc_id or identity.get("sprite") != sprite_id or identity.get("desc_id") != native.get("DescId"):
				return fail("current523_admitted_original_npc_identity_differs",true)
			definition_admission = identity.duplicate(true)
		elif current_final:
			definition_selection_only = true
		else:
			return fail("current523_admitted_original_npc_definition_required",true)
		definition_archive = {"source_snapshot":"patch523","source_sha256":record.source_m_definition_archive_sha256,"origin":"current523_final_definition_selection" if definition_selection_only else "admitted_current523_npc_source_identity"}
	else:
		# Historical compatibility retains its old admission contract. The final
		# source-only request takes the data owner's new definition values above.
		for field: String in ADMITTED_NPC_FIELDS:
			if not native.has(field) or native[field] != context.npc.get(field):
				return fail("current523_admitted_npc_contract_changed:" + field)
	if native.get("TestNPC") != false: return fail("current523_test_npc_not_admitted",source_only)
	var action_rows: Dictionary = {}
	for role: String in CORE_ACTIONS:
		var action: Dictionary = SOURCE.table_row("ListSprAction",int(CORE_ACTIONS[role]))
		if action.is_empty() or action.get("MotionType") != CORE_MOTIONS[role] or action.get("WeaponType") != 0 or action.get("WeaponAlterType") != 0:
			return fail("current523_existing_npc_core_action_family_differs:" + role,source_only)
		action_rows[role] = action.duplicate(true)
	var run_binding: Dictionary = SOURCE.source_run_binding(sprite_id,int(CORE_ACTIONS.walk),0)
	return {"ok":true,"enabled":true,"status":"selected","consumer":"npc","request_key":request_key,
		"source_snapshot":"patch523","content_snapshot":"patch523","source_content_snapshot":"patch523","npc_id":npc_id,"sprite_id":sprite_id,
		SOURCE_ONLY_REQUEST:source_only,"source_only":source_only,"legacy_media_fallback_allowed":not source_only,
		"definition_selection_only":definition_selection_only,"runtime_actor_registry_required":source_only,
		"runtime_actor_registry_present":not definition_admission.is_empty(),
		"selection_phase":"definition_metadata_only" if definition_selection_only else "existing_actor_visual_input",
		"source_definition_archive":definition_archive,"current523_npc_source_identity":definition_admission,
		"spawn_view_id":view_id,"territory_link_id":territory_link_id,
		"npc_source_row":native.duplicate(true),"spawn_admission":admitted.duplicate(true),
		"source_tables_sha256":supplied.source_tables_sha256,"source_action_rows":action_rows,
		"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"source_bank_context":{"current523_source_bank":supplied.options.duplicate(true)},
		"role_actions":CORE_ACTIONS.duplicate(),"loop_policy":LOOPS.duplicate(),
		"optional_role_actions":run_binding.optional_role_actions,"optional_role_actor_ids":run_binding.optional_role_actor_ids,"run_status":run_binding.run_status,
		"overlay_whitelist_path":supplied.options.get("overlay_whitelist_path",""),
		"overlay_whitelist_sha256":supplied.options.get("overlay_whitelist_sha256",""),
		"stats_contract":("current523_final_definition_selection_only; actor_registry_still_required" if definition_selection_only else "current523_admitted_original_registry; saved_encounter_identity_ABI_only") if source_only else "existing_base508_fields_unchanged_by_patch523_spawn_policy",
		"host_policy":"existing_npc_core_actions_and_facing_plus3; native_dispatch_unverified"}
