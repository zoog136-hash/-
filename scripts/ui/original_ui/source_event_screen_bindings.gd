extends RefCounted
## Supplied content components, not an inferred MainMenu-to-content route.
const ROOTS={
 "attendance":{"member":"UI/Attendance/Attendance_All.csb","sha256":"14bd5519b2d97f9ec179c3cf8cb44dc351d511398c6033b0150171c18d1ffd5a","projects":[24332,24016]},
 "pass":{"member":"UI/Pass/Pass_All.csb","sha256":"d17e0c932137e81b81ee32b4fff0f6869c8d2e435a6f70bad2109c819666423f","projects":[19904,16496,1696,684,428]}
}
const PASS_CLOSE=29652
const PASS_ACTION_BUTTONS=[16964,13548,7352]

static func build(pack: RefCounted, kind: String, session: RefCounted, remaining: Dictionary, declared_actions: Dictionary={}) -> Dictionary:
	if not ROOTS.has(kind):return {"ok":false,"code":"source_event_component_unknown"}
	var root: Dictionary=ROOTS[kind]
	if pack.manifest.get("files",{}).get(root.member,{}).get("sha256","")!=root.sha256:return {"ok":false,"code":"source_event_component_identity_mismatch"}
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!=kind:return {"ok":false,"code":"source_event_component_model_mismatch"}
	var bindings: Dictionary=remaining.duplicate(true)
	for offset: int in root.projects:
		if not bindings.has(offset):bindings[offset]={"role":"project","bindings":{}}
	if kind=="pass":
		bindings[PASS_CLOSE]={"role":"button","activate":Callable(session,"close")}
		for offset: Variant in declared_actions:
			if offset not in PASS_ACTION_BUTTONS:return {"ok":false,"code":"source_pass_action_node_unknown"}
			var declaration: Dictionary=declared_actions[offset]
			var result: Dictionary=session.action_binding(str(declaration.get("row_id","")),str(declaration.get("action_ref","")))
			if not result.ok:return result
			var node_binding: Dictionary=result.binding
			if declaration.has("callback_name"):node_binding.callback_name=declaration.callback_name
			bindings[offset]=node_binding
	elif not declared_actions.is_empty():
		# Attendance reward actions belong to its actual child slot contract.
		return {"ok":false,"code":"source_attendance_child_action_contract_required"}
	return {"ok":true,"member":root.member,"sha256":root.sha256,"bindings":bindings,"complete_screen_contract":false}

static func declared_pass_node(pack: RefCounted, source_ui: Dictionary) -> Dictionary:
	if source_ui.get("source_namespace")!="PassSystem":return {"ok":false,"code":"source_pass_namespace_mismatch"}
	var record: Variant=source_ui.get("source_records",{}).get("PassSystem")
	var name_value: Variant=source_ui.get("native_fields",{}).get("PassImageNode")
	if not record is Dictionary or record.get("ID")!=source_ui.get("source_id") or not name_value is String or name_value.is_empty() or record.get("PassImageNode")!=name_value:return {"ok":false,"code":"source_pass_node_declaration_missing"}
	var root: Dictionary=ROOTS["pass"]
	if pack.manifest.get("files",{}).get(root.member,{}).get("sha256","")!=root.sha256:return {"ok":false,"code":"source_event_component_identity_mismatch"}
	var nodes: Array[Dictionary]=pack.nodes_named(root.member,name_value)
	if nodes.size()!=1:return {"ok":false,"code":"source_pass_node_not_unique","declared_node":name_value}
	# Preserve the exact declared node and asset roles. Do not assign three
	# distinct image assets to a guessed child or derive a filename from IDs.
	return {"ok":true,"member":root.member,"source_id":source_ui.source_id,"node":nodes[0].duplicate(true),"asset_refs":source_ui.get("asset_refs",{}).duplicate(true),"image_role_mapping_complete":false}
