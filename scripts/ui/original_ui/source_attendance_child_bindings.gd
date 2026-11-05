extends RefCounted
## Received Attendance children only. Source button names do not establish
## purchase, reward, tooltip, day, tab, or dismissal semantics.
const ROOTS={
 "UI/Attendance/Attendance_Tab_Daily.csb":{
  "sha256":"d31b0670b4b333e0eeeb2a740b3ef7be28b66dd38a33110b1c919a69c9280634",
  "buttons":[14224,9524],
  "projects":{2696:"UI/Attendance/Attendance_Slot.csb"}},
 "UI/Attendance/Attendance_Tab_Promotion.csb":{
  "sha256":"898961712895c5a02501b7a9d131d98d68342827f5efd2e1b45ac8c1bb3562a2",
  "buttons":[19772],
  "projects":{10464:"UI/Attendance/Attendance_SlotBonus.csb",3452:"UI/Attendance/Fx_Promotion_Title.csb"}},
 "UI/Attendance/Attendance_Slot.csb":{
  "sha256":"93c49505c39c3566e381b877d687d767837a2b5f69617e62cbf9f9dfabbfd0e8",
  "buttons":[160],"projects":{}},
 "UI/Attendance/Attendance_SlotBonus.csb":{
  "sha256":"c7afe796d27649b913281c506e6a23417daac362c0bffa0eec66426148c507b3",
  "buttons":[188],"projects":{}}
}

static func build(pack: RefCounted, member: String, session: RefCounted, remaining: Dictionary, declared_actions: Dictionary={}, declared_callbacks: Dictionary={}) -> Dictionary:
	if not ROOTS.has(member):return {"ok":false,"code":"source_attendance_child_unknown"}
	var root: Dictionary=ROOTS[member]
	if pack.manifest.get("files",{}).get(member,{}).get("sha256","")!=root.sha256:return {"ok":false,"code":"source_attendance_child_identity_mismatch"}
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!="attendance":return {"ok":false,"code":"source_attendance_child_model_mismatch"}
	var bindings: Dictionary=remaining.duplicate(true)
	for offset: int in root.projects:
		# The renderer follows the original fileName. Preserve its bindings
		# as a separate scope; do not flatten a child button into the tab.
		if not bindings.has(offset):bindings[offset]={"role":"project","bindings":{}}
	for offset: Variant in declared_actions:
		if offset not in root.buttons:return {"ok":false,"code":"source_attendance_child_action_node_unknown","offset":offset}
		if declared_callbacks.has(offset):return {"ok":false,"code":"source_attendance_child_duplicate_declaration","offset":offset}
		if not declared_actions[offset] is Dictionary:return {"ok":false,"code":"source_attendance_child_action_declaration_required","offset":offset}
		var declaration: Dictionary=declared_actions[offset]
		# Only the presenter can assert that this exact source button begins
		# this supplied row/action. No name-based reward interpretation.
		var result: Dictionary=session.action_binding(str(declaration.get("row_id","")),str(declaration.get("action_ref","")))
		if not result.get("ok",false):return result
		bindings[offset]=result.binding
	for offset: Variant in declared_callbacks:
		if offset not in root.buttons:return {"ok":false,"code":"source_attendance_child_callback_node_unknown","offset":offset}
		var callback: Variant=declared_callbacks[offset]
		if not callback is Callable or not callback.is_valid():return {"ok":false,"code":"source_attendance_child_callback_required","offset":offset}
		# A caller may provide an existing tooltip or child-dismiss callback.
		# Never substitute session.close() for an unproven child close.
		bindings[offset]={"role":"button","activate":callback}
	var missing: Array=[]
	for offset: int in root.buttons:
		if not declared_actions.has(offset) and not declared_callbacks.has(offset):missing.append(offset)
	return {"ok":true,"member":member,"sha256":root.sha256,"bindings":bindings,"project_members":root.projects.duplicate(true),"missing_button_declarations":missing,"complete_screen_contract":false}
