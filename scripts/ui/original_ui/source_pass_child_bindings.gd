extends RefCounted
## Exact received Pass child roots. Callers declare each original row/action;
## offsets, names and list position never determine reward semantics.
const ROOTS={
 "UI/Pass/Pass_List_Mission_All.csb":{"sha256":"4162ef2a01a39ffcd5a92db1a0dd1e711ab8082e31de0310b3710096f5519b87","actions":[7736],"projects":[10564,8520,5724,2708]},
 "UI/Pass/Pass_List_SlotSet_Daily.csb":{"sha256":"0a6c3f30478dfe7a6d67d7a7934bcb2b5b93783b1fca4a53f8e2bdf1eecacd0c","actions":[6428,5336,1476,384],"projects":[9912,9632,9384,7508,7116,5976,4828,2552,2160,1024]},
 "UI/Pass/Pass_List_SlotSet_Final.csb":{"sha256":"742ddb55543e1bf02397db1e2883d5dea6bdb4b4a8142d4f6a9cdf9c438665f1","actions":[1516,416],"projects":[8396,8144,7888,2684,2248,1056]},
 "UI/Pass/Pass_List_SlotSet_Start.csb":{"sha256":"b69b868a1d102b1e61bfb1c657f9fc3a733fd32739d9544023b887ca2036f379","actions":[6392,5292,1484,384],"projects":[9848,9596,9340,7480,7080,5932,4776,2568,2168,1024]}
}

static func build(pack: RefCounted, member: String, session: RefCounted, remaining: Dictionary, declared_actions: Dictionary={}) -> Dictionary:
	if not ROOTS.has(member):return {"ok":false,"code":"source_pass_child_unknown"}
	var root: Dictionary=ROOTS[member]
	if pack.manifest.get("files",{}).get(member,{}).get("sha256","")!=root.sha256:return {"ok":false,"code":"source_pass_child_identity_mismatch"}
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!="pass":return {"ok":false,"code":"source_pass_child_model_mismatch"}
	var bindings: Dictionary=remaining.duplicate(true)
	for offset: int in root.projects:
		# Keep each ProjectNode and its own child binding namespace. In
		# particular Final/Common_Slot references Pass_Slot_Premium.csb.
		if not bindings.has(offset):bindings[offset]={"role":"project","bindings":{}}
	var missing: Array=[]
	for offset: Variant in declared_actions:
		if offset not in root.actions:return {"ok":false,"code":"source_pass_child_action_node_unknown","offset":offset}
		if not declared_actions[offset] is Dictionary:return {"ok":false,"code":"source_pass_child_action_declaration_required","offset":offset}
		var declaration: Dictionary=declared_actions[offset]
		var result: Dictionary=session.action_binding(str(declaration.get("row_id","")),str(declaration.get("action_ref","")))
		if not result.get("ok",false):return result
		bindings[offset]=result.binding
	for offset: int in root.actions:
		if not declared_actions.has(offset):missing.append(offset)
	return {"ok":true,"member":member,"sha256":root.sha256,"bindings":bindings,"missing_action_declarations":missing,"complete_screen_contract":false}
