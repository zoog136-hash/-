extends RefCounted
## Model projection for PR264 ABI 8488ada80cb0d0d647be9aa15986e82b059afb86.
## Request identities resolve opaque references; original node assignment is a
## separate contract. No reward, eligibility, purchase or save calculations.
const Screen=preload("res://scripts/ui/original_ui/source_event_screen_bindings.gd")
const Children=preload("res://scripts/ui/original_ui/source_pass_child_bindings.gd")
var _session: WeakRef
var _selected_pass: int=0
# Literal original root text only. No dates, amounts, placeholders or
# conditional no-products message are assigned a display value here.
const ROOT_LITERAL_TEXT_OFFSETS=[30416,26628,26072,24200,23644,17612,17068,14200,13652,8056,7456,4224,1960]

func configure(session: RefCounted) -> Dictionary:
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!="pass":return _fail("source_pass_model_mismatch")
	_session=weakref(session)
	_selected_pass=0
	return projection()

func select_pass(pass_id: int) -> Dictionary:
	var projected: Dictionary=projection()
	if not projected.get("ok",false):return projected
	if not projected.passes.has(pass_id):return _fail("source_pass_selection_not_in_model")
	_selected_pass=pass_id
	return projection()

func projection() -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_pass_session_unavailable")
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!="pass":return _fail("source_pass_model_mismatch")
	var passes: Dictionary={}
	var unresolved: Array=[]
	for row: Dictionary in model.get("content",{}).get("rows",[]):
		var ui: Dictionary=row.get("source_ui",{})
		var source: Variant=ui.get("source_records",{}).get("PassSystem")
		if ui.get("source_namespace")!="PassSystem" or not source is Dictionary or source.get("ID")!=ui.get("source_id"):
			unresolved.append({"row_id":row.get("id",""),"field":"source_ui.source_records.PassSystem"})
			continue
		var pass_id: int=int(source.ID)
		if not passes.has(pass_id):
			passes[pass_id]={"source_record":source.duplicate(true),"rows":[],"purchase_rows":[],"tier_rows":[],"quest_rows":[],"progress":model.get("progress",{}).get("passes",{}).get(str(pass_id),{}).duplicate(true)}
		var entry: Dictionary={"row":row.duplicate(true),"selectors":[]}
		for offered: Dictionary in row.get("action_refs",[]):
			var request: Dictionary=offered.get("data",{}).get("request",{})
			var selector: Dictionary=_selector(request)
			if selector.is_empty() or selector.get("pass_id")!=pass_id:
				unresolved.append({"row_id":row.get("id",""),"field":"action_refs.data.request","request":request.duplicate(true)})
				continue
			entry.selectors.append(selector)
		passes[pass_id].rows.append(entry)
		var parts: PackedStringArray=str(row.get("id","")).split(":")
		# These row shapes are emitted by events_domain.view, not CSB names.
		if parts.size()==2 and parts[0]=="pass":passes[pass_id].purchase_rows.append(entry)
		elif parts.size()==4 and parts[0]=="pass":passes[pass_id].tier_rows.append(entry)
		elif parts.size()==3 and parts[0]=="pass-quest":passes[pass_id].quest_rows.append(entry)
	if _selected_pass!=0 and not passes.has(_selected_pass):_selected_pass=0
	return {"ok":true,"passes":passes,"selected_pass_id":_selected_pass,"selection_required":_selected_pass==0,"unresolved":unresolved,"complete_screen_contract":false}

func resolve_action(selector: Dictionary) -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_pass_session_unavailable")
	if _selected_pass==0:return _fail("source_pass_selection_required")
	# Require the complete known request identity, including the actual bool
	# premium value. build_root maps the two proven purchase controls;
	# reward slot placement still requires its own source contract.
	if _selector(selector)!=selector or selector.is_empty() or selector.get("pass_id")!=_selected_pass:return _fail("source_pass_action_selector_invalid")
	var matches: Array=[]
	for row: Dictionary in session.snapshot().get("content",{}).get("rows",[]):
		var ui: Dictionary=row.get("source_ui",{})
		if ui.get("source_namespace")!="PassSystem" or ui.get("source_id")!=_selected_pass:continue
		for offered: Dictionary in row.get("action_refs",[]):
			if _selector(offered.get("data",{}).get("request",{}))==selector:
				matches.append({"row_id":str(row.get("id","")),"action_ref":str(offered.get("action_ref",""))})
	if matches.size()!=1:return {"ok":false,"code":"source_pass_action_not_unique","matches":matches.size(),"selector":selector.duplicate(true)}
	var declaration: Dictionary=matches[0]
	var bound: Dictionary=session.action_binding(declaration.row_id,declaration.action_ref)
	if not bound.get("ok",false):return bound
	return {"ok":true,"declaration":declaration,"binding":bound.binding,"data":bound.data}

func build_bindings(pack: RefCounted, member: String, remaining: Dictionary, node_selectors: Dictionary={}) -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_pass_session_unavailable")
	if _selected_pass==0:return _fail("source_pass_selection_required")
	var declarations: Dictionary={}
	for offset: Variant in node_selectors:
		if not node_selectors[offset] is Dictionary:return _fail("source_pass_node_selector_required")
		var resolved: Dictionary=resolve_action(node_selectors[offset])
		if not resolved.get("ok",false):return resolved
		declarations[offset]=resolved.declaration
	var result: Dictionary
	var required_nodes: Array
	if member==Screen.ROOTS["pass"].member:
		result=Screen.build(pack,"pass",session,remaining,declarations)
		required_nodes=Screen.PASS_ACTION_BUTTONS
	elif Children.ROOTS.has(member):
		result=Children.build(pack,member,session,remaining,declarations)
		required_nodes=Children.ROOTS[member].actions
	else:return _fail("source_pass_binding_member_unknown")
	if not result.get("ok",false):return result
	var unresolved: Array=[]
	for offset: int in required_nodes:
		if not node_selectors.has(offset):unresolved.append({"member":member,"offset":offset,"field":"original_node_to_request_selector","required_selector_fields":["action","pass_id","premium (purchase/claim)","level_id (claim)","quest_id (quest claim)"]})
	result["declared_actions"]=declarations
	result["unresolved_node_selectors"]=unresolved
	result["complete_screen_contract"]=false
	return result

func build_root(pack: RefCounted, remaining: Dictionary) -> Dictionary:
	# Original Pass_All purchase intents: Btn_Buy_Common and Btn_BuyPremium.
	# Service availability is represented only by its currently offered refs.
	var projected: Dictionary=projection()
	if not projected.get("ok",false):return projected
	if _selected_pass==0:return _fail("source_pass_selection_required")
	var session: Object=_live_session()
	if session==null:return _fail("source_pass_session_unavailable")
	var bindings: Dictionary=remaining.duplicate(true)
	var declarations: Dictionary={}
	var unavailable: Array=[]
	var purchase_costs: Dictionary={}
	var unresolved_cost_roles: Array=[]
	for text_offset: int in ROOT_LITERAL_TEXT_OFFSETS:
		if not bindings.has(text_offset):bindings[text_offset]={"role":"static_source_text"}
	for offset: int in [16964,13548]:
		var selector: Dictionary={"action":"pass_purchase","pass_id":_selected_pass,"premium":offset==13548}
		var resolved: Dictionary=resolve_action(selector)
		if resolved.get("ok",false):
			bindings[offset]=resolved.binding
			declarations[offset]=resolved.declaration
			var costs: Variant=resolved.data.get("costs")
			# Pass_All's purchase branches contain only Normal/Disabled
			# literal Label controls. Neither is an amount text role.
			purchase_costs[offset]=costs.duplicate(true) if costs is Array or costs is Dictionary else costs
			var missing: Dictionary={"member":Screen.ROOTS["pass"].member,"purchase_button_offset":offset,"field":"original_purchase_price_text_node_role","literal_label_offsets":[17612,17068] if offset==16964 else [14200,13652]}
			if not costs is Array or costs.size()!=1:
				missing["cost_amount_contract"]="single_supplied_cost_required"
			elif not costs[0] is Dictionary or not costs[0].has("amount"):
				missing["cost_amount_contract"]="supplied_cost_amount_missing"
			unresolved_cost_roles.append(missing)
		elif resolved.get("code")=="source_pass_action_not_unique" and resolved.get("matches")==0:
			# Absence means only that the service offers no purchase here.
			# Do not reconstruct eligibility, prices or ownership conditions.
			bindings[offset]={"role":"button","displaystate":false,"activate":Callable()}
			unavailable.append({"offset":offset,"selector":selector})
		else:return resolved
	# Passing the bindings through remaining also preserves disabled controls,
	# for which there is intentionally no action_ref/declaration to begin.
	var result: Dictionary=Screen.build(pack,"pass",session,bindings)
	if not result.get("ok",false):return result
	result["declared_actions"]=declarations
	result["unavailable_purchase_actions"]=unavailable
	result["purchase_costs"]=purchase_costs
	result["unresolved_purchase_cost_roles"]=unresolved_cost_roles
	result["unresolved_node_selectors"]=[
		{"member":Screen.ROOTS["pass"].member,"offset":7352,"field":"original_claim_all_action_contract"},
		{"member":Screen.ROOTS["pass"].member,"field":"original_tab_selection_and_list_row_placement_contract"}
	]
	result["complete_screen_contract"]=false
	return result

func selected_presentation() -> Dictionary:
	var projected: Dictionary=projection()
	if not projected.get("ok",false):return projected
	if _selected_pass==0:return _fail("source_pass_selection_required")
	var selected: Dictionary=projected.passes[_selected_pass]
	var tiers: Array=[]
	var quests: Array=[]
	var unresolved: Array=[]
	var claims: Dictionary=selected.progress.get("claims",{})
	for entry: Dictionary in selected.tier_rows:
		var row: Dictionary=entry.row
		var parts: PackedStringArray=str(row.get("id","")).split(":")
		var record: Variant=row.get("source_ui",{}).get("source_records",{}).get("PassSystemLevel")
		if not record is Dictionary or parts.size()!=4 or record.get("ID")!=int(parts[2]) or record.get("PassSystemID")!=_selected_pass or parts[3] not in ["true","false"]:
			unresolved.append({"row_id":row.get("id",""),"field":"source_ui.source_records.PassSystemLevel"})
			continue
		var premium: bool=parts[3]=="true"
		# Exact events_domain._tier_key. Presence is the backend's claim
		# marker; no XP threshold or availability is calculated here.
		var claim_key: String="%d:%s" % [int(record.ID),"premium" if premium else "base"]
		tiers.append({"row":row.duplicate(true),"source_record":record.duplicate(true),"selectors":entry.selectors.duplicate(true),"premium":premium,"claim_key":claim_key,"claimed":claims.has(claim_key),"claim_marker":claims.get(claim_key),"unresolved_fields":["original_slot_placement","original_reward_asset_role","original_reward_amount_role"]})
	for entry: Dictionary in selected.quest_rows:
		var row: Dictionary=entry.row
		var records: Variant=row.get("source_ui",{}).get("source_records",{}).get("PassSystemQuest")
		if not records is Dictionary and not records is Array:
			unresolved.append({"row_id":row.get("id",""),"field":"source_ui.source_records.PassSystemQuest"})
			continue
		quests.append({"row":row.duplicate(true),"source_records":records.duplicate(true),"selectors":entry.selectors.duplicate(true),"unresolved_fields":["original_mission_row_placement","original_reward_asset_role","original_reward_amount_role","quest_claim_token_not_supplied"]})
	return {"ok":true,"pass_id":_selected_pass,"source_record":selected.source_record.duplicate(true),"progress":selected.progress.duplicate(true),"tier_rows":tiers,"quest_rows":quests,"unresolved":unresolved,"complete_screen_contract":false}

func build_mission(pack: RefCounted, quest_id: int, remaining: Dictionary) -> Dictionary:
	# Received Pass_List_Mission_All button 7736 has source text 보상 받기
	# (receive reward), not a tooltip. It begins only this exact quest ref.
	var projected: Dictionary=projection()
	if not projected.get("ok",false):return projected
	if _selected_pass==0:return _fail("source_pass_selection_required")
	var row_id: String="pass-quest:%d:%d" % [_selected_pass,quest_id]
	var found: int=0
	for entry: Dictionary in projected.passes[_selected_pass].quest_rows:
		if entry.row.get("id")==row_id:found+=1
	if found!=1:return _fail("source_pass_mission_row_not_unique")
	var selector: Dictionary={"action":"pass_quest_claim","pass_id":_selected_pass,"quest_id":quest_id}
	var resolved: Dictionary=resolve_action(selector)
	var bindings: Dictionary=remaining.duplicate(true)
	var declarations: Dictionary={}
	if resolved.get("ok",false):
		declarations[7736]=resolved.declaration
	elif resolved.get("code")=="source_pass_action_not_unique" and resolved.get("matches")==0:
		bindings[7736]={"role":"button","displaystate":false,"activate":Callable()}
	else:return resolved
	var result: Dictionary=Children.build(pack,"UI/Pass/Pass_List_Mission_All.csb",_live_session(),bindings,declarations)
	if not result.get("ok",false):return result
	result["declared_actions"]=declarations
	# A disabled absent offer is fully assigned, rather than an unknown
	# button mapping. Child reward slot presentation remains unresolved.
	result["missing_action_declarations"]=[]
	result["action_offered"]=resolved.get("ok",false)
	result["quest_id"]=quest_id
	result["unresolved_fields"]=["original_mission_row_placement","original_reward_slot_asset_and_amount_roles"]
	result["complete_screen_contract"]=false
	return result

func begin(selector: Dictionary) -> Dictionary:
	var resolved: Dictionary=resolve_action(selector)
	if not resolved.get("ok",false):return resolved
	return _live_session().begin(resolved.declaration.action_ref)

func choose(key: String, option_indices: Array) -> Dictionary:
	var session: Object=_live_session()
	return session.choose(key,option_indices) if session!=null else _fail("source_pass_session_unavailable")

func confirm() -> Dictionary:
	var session: Object=_live_session()
	return session.confirm() if session!=null else _fail("source_pass_session_unavailable")

func cancel() -> Dictionary:
	var session: Object=_live_session()
	return session.cancel() if session!=null else _fail("source_pass_session_unavailable")

func _live_session() -> Object:
	return _session.get_ref() if _session!=null else null

static func _selector(request: Dictionary) -> Dictionary:
	var operation: String=str(request.get("action",""))
	if operation not in ["pass_purchase","pass_claim","pass_quest_claim"] or not request.has("pass_id"):return {}
	var result: Dictionary={"action":operation,"pass_id":request.pass_id}
	if operation in ["pass_purchase","pass_claim"]:
		if not request.get("premium") is bool:return {}
		result["premium"]=request.premium
	if operation=="pass_claim":
		if not request.has("level_id"):return {}
		result["level_id"]=request.level_id
	elif operation=="pass_quest_claim":
		if not request.has("quest_id"):return {}
		result["quest_id"]=request.quest_id
	return result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
