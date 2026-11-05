extends RefCounted
## Generic authored system-message text, with priority chosen explicitly by caller.
## The existing HUD owns message lifetime and clears its own label on expiration.
const PARENT_MEMBER = "UI/SystemMessageScene.csb"
const PARENT_SHA256 = "26fa5e9e1ef875f3e3aa8fbd68a77641a8c69a198a765f4d56e182d427128759"
const TEXT_OFFSET = 124
const PRIORITIES = {
	1:{"member":"UI/SystemMessage/MessBoxHUDTopLayout.csb","sha256":"a10604343f1c0c6dbb01eb68be3c9a7c44c2abcf8cbb9883656a515153c427a3","project_offset":4768,"position":Vector2(600,601),"source_name":"MessBoxHUDTopLayout","source_literal":"제 1 우선순위 시스템 메시지 "},
	2:{"member":"UI/SystemMessage/MessBoxHUDBotLayout.csb","sha256":"707a598e106c5107d631295b30fb90f164a411919ad0ed2498a0df7d747838d0","project_offset":5048,"position":Vector2(600,140),"source_name":"MessBoxHUDBotLayout","source_literal":"제 2 우선순위 시스템 메시지 "}
}

static func build(pack: RefCounted, hud: Object, explicit_priority: int) -> Dictionary:
	if not PRIORITIES.has(explicit_priority): return _fail("source_system_message_explicit_priority_1_or_2_required")
	var spec: Dictionary = PRIORITIES[explicit_priority]
	var source: Dictionary = _active_source(pack,spec)
	if not source.get("ok",false): return source
	var current: Dictionary = snapshot(hud)
	if not current.get("ok",false): return current
	return {
		"ok":true,"member":spec.member,"sha256":spec.sha256,
		"source_node_offsets":[TEXT_OFFSET],
		"bindings":{TEXT_OFFSET:{"role":"source_text","text":current.text}},
		"explicit_priority":explicit_priority,"priority_policy_inferred":false,
		"parent_member":PARENT_MEMBER,"parent_sha256":PARENT_SHA256,
		"parent_project_offset":spec.project_offset,"parent_project_path":[spec.project_offset],
		"parent_original_name":spec.source_name,"parent_original_position":spec.position,
		"parent_original_visible":true,"parent_original_alpha":255,
		"clips":[{"name":"Ani_Off","startIndex":5,"endIndex":25}],
		"playback_policy_inferred":false,"timer_owner":"existing hud.show_message/_process",
		"value_basis":"existing hud.message_label.text",
		"partial_source_scene":true,"complete_screen_contract":false,
		"unresolved_fields":["original_priority_routing_policy","original_Ani_Off_playback_policy"]
	}

static func refresh(actual_text_renderer: Node2D, hud: Object) -> Dictionary:
	if not is_instance_valid(actual_text_renderer) or not actual_text_renderer.has_method("set_bound_text"):
		return _fail("source_system_message_actual_renderer_required")
	var member: Variant = actual_text_renderer.get("source_member")
	var spec: Dictionary = {}
	for priority: int in PRIORITIES:
		if PRIORITIES[priority].member == member: spec = PRIORITIES[priority]
	if spec.is_empty(): return _fail("source_system_message_original_renderer_member_required")
	var pack: Variant = actual_text_renderer.get("source_pack")
	if not pack is RefCounted: return _fail("source_system_message_actual_pack_required")
	var source: Dictionary = _active_source(pack,spec)
	if not source.get("ok",false): return source
	var nodes: Variant = actual_text_renderer.get("source_nodes")
	if not nodes is Dictionary or not nodes.has(TEXT_OFFSET): return _fail("source_system_message_text_not_in_presented_scope")
	var current: Dictionary = snapshot(hud)
	if not current.get("ok",false): return current
	var result: Dictionary = actual_text_renderer.set_bound_text(TEXT_OFFSET,current.text)
	if not result.get("ok",false): return result
	return {"ok":true,"text":current.text,"timer_changed":false,"priority_policy_inferred":false,"game_state_written":false}

static func snapshot(hud: Object) -> Dictionary:
	if not is_instance_valid(hud): return _fail("source_system_message_existing_hud_required")
	var label: Variant = hud.get("message_label")
	if not label is Label or not is_instance_valid(label): return _fail("source_system_message_existing_message_label_required")
	var text: Variant = label.get("text")
	if not text is String: return _fail("source_system_message_actual_string_required")
	return {"ok":true,"text":text}

static func _active_source(pack: RefCounted, spec: Dictionary) -> Dictionary:
	if pack == null or pack.manifest.get("files",{}).get(spec.member,{}).get("sha256","") != spec.sha256:
		return _fail("source_system_message_original_identity_mismatch")
	if pack.manifest.get("files",{}).get(PARENT_MEMBER,{}).get("sha256","") != PARENT_SHA256:
		return _fail("source_system_message_original_parent_identity_mismatch")
	var tree: Dictionary = pack.scene(spec.member)
	var node: Dictionary = _find(tree.get("nodeTree",{}),TEXT_OFFSET)
	if node.get("classname") != "Text" or node.get("options",{}).get("text") != spec.source_literal:
		return _fail("source_system_message_original_text_not_in_active_scope")
	return {"ok":true}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset") == offset: return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary = _find(child,offset)
		if not found.is_empty(): return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"presentation_requires_hide":true}
