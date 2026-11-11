extends RefCounted
## Presentation of an already resolved existing dialogue. No choice is selected here.
const MEMBER = "UI/NpcDialogue/NpcDialogue_All.csb"
const SHA256 = "f27872592f0f7f6b74b81308bc64f98f4bc337beff60c030f4f1ac060aed4ccf"
const PARENT_MEMBER = "UI/NpcDialogueScene.csb"
const PARENT_SHA256 = "6626721d95d1ca4c2b097730b44d97ce8aa8afb371b5e7806158db788f043765"
const PARENT_PROJECT = 132
const BASE_OFFSETS: Array[int] = [6800,6172,3512,3940,272,780,324]
const NEXT_BUTTON = 1872
const NEXT_CUE: Array[int] = [2624,3016,2680]
const PORTRAIT = 4912

static func build(pack: RefCounted, resolved: Dictionary, close: Callable, next: Callable = Callable(), portrait_requested: bool=false) -> Dictionary:
	if not resolved.get("ok",false) or not resolved.get("npc_name") is String or not resolved.get("text") is String:
		return _fail("source_npc_dialogue_success_name_and_text_required")
	if not close.is_valid(): return _fail("source_npc_dialogue_existing_close_callback_required")
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256:
		return _fail("source_npc_dialogue_original_identity_mismatch")
	if pack.manifest.get("files",{}).get(PARENT_MEMBER,{}).get("sha256","") != PARENT_SHA256:
		return _fail("source_npc_dialogue_original_parent_identity_mismatch")
	var offsets: Array[int] = BASE_OFFSETS.duplicate()
	# With a connected Btn_Next the original next cue (Fx_NextBtn arrow + light) shows too.
	if next.is_valid(): offsets.append_array([NEXT_BUTTON] + NEXT_CUE)
	var portrait_declared: bool=portrait_requested and PORTRAIT in pack.manifest.get("externally_bound_texture_nodes",{}).get(MEMBER,[])
	if portrait_declared:offsets.append(PORTRAIT)
	var tree: Dictionary = pack.scene(MEMBER)
	var missing: Array[int] = []
	for offset: int in offsets:
		if _find(tree.get("nodeTree",{}),offset).is_empty(): missing.append(offset)
	if not missing.is_empty():
		return {"ok":false,"code":"source_npc_dialogue_nodes_not_in_active_pack_scope","missing_source_offsets":missing}
	var bindings: Dictionary = {
		6800:{"role":"consume"},
		3512:{"role":"source_text","text":resolved["npc_name"]},
		3940:{"role":"source_text","text":resolved["text"],"cocos_wrap":true},
		272:{"role":"button","activate":close},
		324:{"role":"static_source_text"}
	}
	if next.is_valid(): bindings[NEXT_BUTTON] = {"role":"button","activate":next}
	if portrait_declared:bindings[PORTRAIT]={"role":"source_asset_slot","visible":false}
	var excluded: Array[int]=[4604,5744,5416]
	if not next.is_valid():excluded.append(2624)
	if not portrait_declared:excluded.append(PORTRAIT)
	return {
		"ok":true,"member":MEMBER,"sha256":SHA256,
		"source_node_offsets":offsets,"bindings":bindings,
		"parent_member":PARENT_MEMBER,"parent_sha256":PARENT_SHA256,
		"parent_project_offset":PARENT_PROJECT,"parent_project_path":[PARENT_PROJECT],
		"parent_original_position":Vector2.ZERO,"parent_original_visible":true,"parent_original_alpha":255,
		"clips":[{"name":"Npc_On","startIndex":5,"endIndex":45},{"name":"Npc_Loop","startIndex":50,"endIndex":80}],
		"playback_policy_inferred":false,"next_connected":next.is_valid(),
		"portrait_target_declared":portrait_declared,"portrait_initially_hidden":true,
		"value_basis":"original 523 town NPC name (DescData_Korean) and talk (DialogData_Korean)",
		"partial_source_scene":true,"complete_screen_contract":false,
		"unresolved_fields":["NPC_record_to_original_portrait_asset_role","original_clip_playback_policy","choice_to_original_next_contract_owned_by_caller"],
		"excluded_source_offsets":excluded
	}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset") == offset: return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary = _find(child,offset)
		if not found.is_empty(): return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
