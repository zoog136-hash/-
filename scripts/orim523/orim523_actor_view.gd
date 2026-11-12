extends "res://scripts/monsters/current523_source_bank_view.gd"
## Original pixels of an 오림의 흔적 NPC: NpcClass.Sprite from the installed
## 523 source bank, the same core action family/preview the field NPCs use.
## Orim NPCs are placed by OrimsTrailSpawn, not NpcSpawn, so the selection is
## built from the NpcClass row instead of an NpcSpawn admission. Nothing is
## drawn when the sprite or an action is missing (no substitute image).
const BANK_SOURCE = preload("res://scripts/resources/current523_source_bank.gd")

static func selection(npc_id: int) -> Dictionary:
	var supplied: Dictionary = BANK_SOURCE.source_tables({})
	if not supplied.get("ok",false): return {"ok":false,"reason":str(supplied.get("reason","current523_source_bank_unavailable"))}
	var native: Dictionary = BANK_SOURCE.table_row("NpcClass",npc_id)
	if native.is_empty() or native.get("TestNPC")!=false: return {"ok":false,"reason":"orim_npc_class_missing_or_test"}
	var sprite_id: int = int(native.get("Sprite",0))
	if sprite_id<=0: return {"ok":false,"reason":"orim_npc_sprite_missing"}
	var action_rows: Dictionary = {}
	for role: String in SELECTION.CORE_ACTIONS:
		var action: Dictionary = BANK_SOURCE.table_row("ListSprAction",int(SELECTION.CORE_ACTIONS[role]))
		if action.is_empty() or action.get("MotionType")!=SELECTION.CORE_MOTIONS[role]: return {"ok":false,"reason":"orim_npc_core_action_family_differs:"+role}
		action_rows[role] = action.duplicate(true)
	var run_binding: Dictionary = BANK_SOURCE.source_run_binding(sprite_id,int(SELECTION.CORE_ACTIONS.walk),0)
	return {"ok":true,"enabled":true,"status":"selected","consumer":"npc","request_key":"orim523:npc:%d" % npc_id,
		"source_snapshot":"patch523","content_snapshot":"patch523","npc_id":npc_id,"sprite_id":sprite_id,
		"source_only":true,"legacy_media_fallback_allowed":false,"definition_selection_only":false,"runtime_actor_registry_required":false,
		"selection_phase":"orim523_npc_class_visual","npc_source_row":native.duplicate(true),
		"source_tables_sha256":supplied.source_tables_sha256,"source_action_rows":action_rows,
		"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"source_bank_context":{"current523_source_bank":supplied.options.duplicate(true)},
		"role_actions":SELECTION.CORE_ACTIONS.duplicate(),"loop_policy":SELECTION.LOOPS.duplicate(),
		"optional_role_actions":run_binding.get("optional_role_actions",{}),"optional_role_actor_ids":run_binding.get("optional_role_actor_ids",{}),"run_status":run_binding.get("run_status",{}),
		"overlay_whitelist_path":supplied.options.get("overlay_whitelist_path",""),"overlay_whitelist_sha256":supplied.options.get("overlay_whitelist_sha256",""),
		"host_policy":"existing_npc_core_actions_and_facing_plus3; orim523_spawn_table"}

func configure_orim(npc_id: int) -> bool:
	selection_status = selection(npc_id)
	if not selection_status.get("ok",false): return false
	var selected: Dictionary = selection_status
	var candidate := PREVIEW.new()
	if not candidate._configure_selected_roles(selected,"idle"):
		selection_status["ok"] = false
		selection_status["reason"] = candidate.reference_bank_status.get("error","orim_npc_source_action_unavailable")
		candidate.free()
		return false
	_preview = candidate
	_preview._reference_request_context = selected.get("source_bank_context",{}).duplicate(true)
	_preview._reference_card_context = selected.duplicate(true)
	_preview.source_selection_status = selected.duplicate(true)
	_preview.reference_bank_status["purpose"] = "orim523_npc"
	_preview.reference_bank_status["host_policy"] = selected.host_policy
	_preview._load_reference_overlay_bindings(selected)
	add_child(_preview)
	_tracks = _preview._playback_tracks
	_mode = _preview.source_playback_mode()
	_root = str(selected.manifest_path).get_base_dir()
	attachment_status = _preview.attachment_status()
	_role = "idle"
	_clock = 0.0
	_sequence = -1
	_source_attack = false
	if not _preview.advance_reference_source(0.0,"idle",posmod(2 + 3,8)):
		selection_status["ok"] = false
		selection_status["reason"] = _preview.reference_bank_status.get("error","orim_npc_initial_source_frame_unavailable")
		return false
	return true
