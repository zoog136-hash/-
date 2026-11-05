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

static func fail(reason: String) -> Dictionary:
	return {"ok":false,"status":"selection_pending","reason":reason,"consumer":"npc","source_snapshot":"patch523"}

static func select(record: Dictionary, admission: Dictionary) -> Dictionary:
	if admission.get("ok") != true or admission.get("applied") != true or admission.get("record") != record:
		return fail("current523_existing_spawn_policy_admission_required")
	var admitted: Variant = record.get("source_m_patch523_admission")
	var context: Variant = record.get("source_m_context")
	if record.get("source") != "lineagem_base508" or not admitted is Dictionary or not context is Dictionary:
		return fail("current523_explicit_npc_source_context_required")
	if admitted.get("snapshot") != "patch523" or not BANK.valid_sha(admitted.get("manifest_sha256")):
		return fail("current523_current_map_admission_required")
	for field: String in ["source_m_npc_id", "source_m_sprite_id", "source_m_spawn_view_id", "source_m_territory_link_id"]:
		if not BANK.integer(record.get(field),0 if field == "source_m_sprite_id" else 1):
			return fail("current523_explicit_npc_identity_required")
	var npc_id: int = int(record.source_m_npc_id)
	var sprite_id: int = int(record.source_m_sprite_id)
	var view_id: int = int(record.source_m_spawn_view_id)
	var territory_link_id: int = int(record.source_m_territory_link_id)
	var request_key: String = "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id,view_id,territory_link_id]
	if record.get("sourceId") != request_key or admitted.get("npc_id") != npc_id or admitted.get("spawn_view_id") != view_id or admitted.get("territory_link_id") != territory_link_id:
		return fail("current523_admitted_npc_identity_differs")
	if admitted.get("is_spawn") != 1 or admitted.get("server_limit_set_id") != 0 or str(admitted.get("host_map_id","")).is_empty() or admitted.get("placement_policy") != "EXISTING_HOST_POSITION_COUNT_RESPAWN_RETAINED":
		return fail("current523_existing_host_placement_admission_required")
	if bool(record.get("catalog_only",false)) or str(record.get("source_m_host_placement","")).is_empty():
		return fail("current523_catalog_record_is_not_a_host_encounter")
	for field: String in ["land", "territory", "territory_link", "spawn_view", "npc"]:
		if not context.get(field) is Dictionary: return fail("current523_complete_admitted_npc_context_required")
	if context.npc.get("ID") != npc_id or context.npc.get("Sprite") != sprite_id or context.spawn_view.get("ID") != view_id or context.spawn_view.get("NpcClassID") != npc_id or context.territory_link.get("ID") != territory_link_id:
		return fail("current523_npc_context_identity_differs")
	var supplied: Dictionary = SOURCE.source_tables(record)
	if not supplied.ok: return supplied
	var native: Dictionary = supplied.by_id.NpcClass.get(npc_id,{})
	if native.is_empty() or native.get("Sprite") != sprite_id:
		return fail("current523_exact_npcclass_sprite_missing")
	# The existing admission policy explicitly retains the baseline combat and
	# occupancy contract. A visual fallback cannot silently relabel changed stats.
	for field: String in ADMITTED_NPC_FIELDS:
		if not native.has(field) or native[field] != context.npc.get(field):
			return fail("current523_admitted_npc_contract_changed:" + field)
	if native.get("TestNPC") != false: return fail("current523_test_npc_not_admitted")
	var action_rows: Dictionary = {}
	for role: String in CORE_ACTIONS:
		var action: Dictionary = supplied.by_id.ListSprAction.get(int(CORE_ACTIONS[role]),{})
		if action.is_empty() or action.get("MotionType") != CORE_MOTIONS[role] or action.get("WeaponType") != 0 or action.get("WeaponAlterType") != 0:
			return fail("current523_existing_npc_core_action_family_differs:" + role)
		action_rows[role] = action.duplicate(true)
	var run_binding: Dictionary = SOURCE.source_run_binding(sprite_id,int(CORE_ACTIONS.walk),0)
	return {"ok":true,"enabled":true,"status":"selected","consumer":"npc","request_key":request_key,
		"source_snapshot":"patch523","npc_id":npc_id,"sprite_id":sprite_id,
		"spawn_view_id":view_id,"territory_link_id":territory_link_id,
		"npc_source_row":native.duplicate(true),"spawn_admission":admitted.duplicate(true),
		"source_tables_sha256":supplied.source_tables_sha256,"source_action_rows":action_rows,
		"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"role_actions":CORE_ACTIONS.duplicate(),"loop_policy":LOOPS.duplicate(),
		"optional_role_actions":run_binding.optional_role_actions,"optional_role_actor_ids":run_binding.optional_role_actor_ids,"run_status":run_binding.run_status,
		"overlay_whitelist_path":supplied.options.get("overlay_whitelist_path",""),
		"overlay_whitelist_sha256":supplied.options.get("overlay_whitelist_sha256",""),
		"stats_contract":"existing_base508_fields_unchanged_by_patch523_spawn_policy",
		"host_policy":"existing_npc_core_actions_and_facing_plus3; native_dispatch_unverified"}
