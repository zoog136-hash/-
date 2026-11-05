extends RefCounted
## Partial original inventory tooltip header for the existing timed name hint.
## The bag owns text, visibility and its five-second timer; this is not detail UI.
const MEMBER = "UI/ToolTip/ToolTip_HudType_Right.csb"
const SHA256 = "7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce"
const PARENT_MEMBER = "UI/ToolTipScene.csb"
const PARENT_SHA256 = "9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d"
const PARENT_PROJECT = 1012
const ROOT = 616
const NAME_TEXT = 44160
const CLOSE = 956
# Only Title's original text/decorative sprite and the actual Close button.
const SOURCE_OFFSETS: Array[int] = [44536,44160,956]

static func build(pack: RefCounted, bag: Object, close_callback: Callable) -> Dictionary:
	if not close_callback.is_valid(): return _fail("source_inventory_name_existing_hide_callback_required")
	var source: Dictionary = source_contract(pack)
	if not source.get("ok",false): return source
	var current: Dictionary = snapshot(bag)
	if not current.get("ok",false): return current
	return {
		"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":SOURCE_OFFSETS.duplicate(),
		"bindings":{ROOT:{"visible":current.visible},NAME_TEXT:{"role":"source_text","text":current.text},CLOSE:{"role":"button","activate":close_callback}},
		"parent_member":PARENT_MEMBER,"parent_sha256":PARENT_SHA256,"parent_project_offset":PARENT_PROJECT,"parent_project_path":[PARENT_PROJECT],
		"parent_original_position":Vector2(1008,345),"parent_original_visible":false,"parent_original_alpha":255,
		"parent_activation_owned_by_caller":true,"value_basis":"existing bag.item_name_hint.text/visible",
		"timer_owned_by_bag":true,"partial_scope":true,"partial_source_scene":true,"complete_screen_contract":false,"full_detail_connected":false,
		"unresolved_fields":["full_detail_body_attribute_row_bindings","full_detail_actions_and_modes","original_tooltip_open_close_playback_policy"]
	}

static func refresh(actual_child_renderer: Node2D, bag: Object) -> Dictionary:
	if not is_instance_valid(actual_child_renderer) or actual_child_renderer.get("source_member") != MEMBER or not actual_child_renderer.has_method("set_bound_text") or not actual_child_renderer.has_method("set_bound_visible"):
		return _fail("source_inventory_name_actual_original_renderer_required")
	var pack: Variant = actual_child_renderer.get("source_pack")
	if not pack is RefCounted: return _fail("source_inventory_name_original_pack_required")
	var source: Dictionary = source_contract(pack)
	if not source.get("ok",false): return source
	var nodes: Variant = actual_child_renderer.get("source_nodes")
	if not nodes is Dictionary or not nodes.has(NAME_TEXT) or not nodes.has(ROOT): return _fail("source_inventory_name_presented_scope_missing")
	var current: Dictionary = snapshot(bag)
	if not current.get("ok",false): return current
	var result: Dictionary = actual_child_renderer.set_bound_text(NAME_TEXT,current.text)
	if not result.get("ok",false): return result
	result = actual_child_renderer.set_bound_visible(ROOT,current.visible)
	if not result.get("ok",false): return result
	return {"ok":true,"text":current.text,"visible":current.visible,"timer_changed":false,"partial_source_scene":true,"complete_screen_contract":false}

static func snapshot(bag: Object) -> Dictionary:
	if not is_instance_valid(bag): return _fail("source_inventory_name_existing_bag_required")
	var hint: Variant = bag.get("item_name_hint")
	if not hint is Label or not is_instance_valid(hint): return _fail("source_inventory_name_existing_hint_required")
	return {"ok":true,"text":hint.text,"visible":hint.visible}

static func source_contract(pack: RefCounted) -> Dictionary:
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256:
		return _fail("source_inventory_name_original_identity_mismatch")
	if pack.manifest.get("files",{}).get(PARENT_MEMBER,{}).get("sha256","") != PARENT_SHA256:
		return _fail("source_inventory_name_original_parent_identity_mismatch")
	var tree: Dictionary = pack.scene(MEMBER)
	for offset: int in SOURCE_OFFSETS:
		if _find(tree.get("nodeTree",{}),offset).is_empty(): return _fail("source_inventory_name_nodes_not_in_active_scope")
	return {"ok":true}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset") == offset: return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary = _find(child,offset)
		if not found.is_empty(): return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"presentation_requires_hide":true}
