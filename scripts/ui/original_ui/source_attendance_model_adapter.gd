extends RefCounted
## Existing events service model -> supplied attendance controls. No attendance
## eligibility, server reward selection, purchase, grant or save rules live here.
const Children=preload("res://scripts/ui/original_ui/source_attendance_child_bindings.gd")
var _session: WeakRef
var _selected_version: int=0

func configure(session: RefCounted) -> Dictionary:
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!="attendance":return _fail("source_attendance_model_mismatch")
	_session=weakref(session)
	_selected_version=0
	return projection()

func projection() -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_attendance_session_unavailable")
	var versions: Dictionary={}
	var unresolved: Array=[]
	for row: Dictionary in session.snapshot().get("content",{}).get("rows",[]):
		var presented: Dictionary=_project_row(row)
		if not presented.get("ok",false):
			unresolved.append({"row_id":row.get("id",""),"code":presented.get("code","")})
			continue
		var id: int=int(presented.source_record.ID)
		if not versions.has(id):versions[id]={"source_record":presented.source_record.duplicate(true),"progress":presented.progress.duplicate(true),"rows":[]}
		versions[id].rows.append(presented)
	if _selected_version!=0 and not versions.has(_selected_version):_selected_version=0
	return {"ok":true,"versions":versions,"selected_version_id":_selected_version,"selection_required":_selected_version==0,"unresolved":unresolved,"complete_screen_contract":false}

func select_version(version_id: int) -> Dictionary:
	var projected: Dictionary=projection()
	if not projected.get("ok",false):return projected
	if not projected.versions.has(version_id):return _fail("source_attendance_version_not_in_model")
	_selected_version=version_id
	return projection()

func row_presentation(row_id: String) -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_attendance_session_unavailable")
	var found: Array=[]
	for row: Dictionary in session.snapshot().get("content",{}).get("rows",[]):
		if row.get("id")==row_id:found.append(row)
	if found.size()!=1:return _fail("source_attendance_row_not_unique")
	return _project_row(found[0])

func resolve_claim(row_id: String) -> Dictionary:
	var presented: Dictionary=row_presentation(row_id)
	if not presented.get("ok",false):return presented
	var matches: Array=[]
	for offered: Dictionary in presented.row.get("action_refs",[]):
		var request: Dictionary=offered.get("data",{}).get("request",{})
		if request.get("action")=="attendance_claim" and request.get("version_id")==presented.source_record.ID and request.get("index")==presented.reward_index:
			matches.append(offered)
	if matches.size()>1:return _fail("source_attendance_claim_not_unique")
	if matches.is_empty():return {"ok":true,"offered":false,"binding":{"role":"button","displaystate":false,"activate":Callable()},"presentation":presented}
	var bound: Dictionary=_live_session().action_binding(row_id,str(matches[0].get("action_ref","")))
	if not bound.get("ok",false):return bound
	return {"ok":true,"offered":true,"declaration":{"row_id":row_id,"action_ref":matches[0].action_ref},"binding":bound.binding,"data":bound.data,"presentation":presented}

func build_tab(pack: RefCounted, member: String, remaining: Dictionary) -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_attendance_session_unavailable")
	if member not in ["UI/Attendance/Attendance_Tab_Daily.csb","UI/Attendance/Attendance_Tab_Promotion.csb"]:return _fail("source_attendance_tab_unknown")
	var bindings: Dictionary=remaining.duplicate(true)
	var close_offset: int=14224 if member.ends_with("Attendance_Tab_Daily.csb") else 19772
	# Both source controls are the fullscreen component's Btn_Close. This is
	# page dismissal, never an inferred attendance claim on opening/closing.
	var callbacks: Dictionary={close_offset:Callable(session,"close")}
	if member.ends_with("Attendance_Tab_Daily.csb"):
		var projected: Dictionary=projection()
		if not projected.get("ok",false):return projected
		if _selected_version==0:return _fail("source_attendance_version_selection_required")
		var selected: Dictionary=projected.versions[_selected_version]
		# The service's existing attendance progress uses this original version
		# key and its documented absent-progress count=0. No clock/reset logic.
		bindings[5380]={"role":"source_text","text":str(int(selected.progress.get("count",0)))}
		# Btn_Buy is special attendance purchase. This ABI offers no purchase
		# action for attendance; it must never be repurposed as a claim button.
		bindings[9524]={"role":"button","displaystate":false,"activate":Callable()}
		bindings[10128]={"visible":false}
		bindings[9576]={"visible":true}
	var result: Dictionary=Children.build(pack,member,session,bindings,{},callbacks)
	if result.get("ok",false):
		if member.ends_with("Attendance_Tab_Daily.csb"):result.missing_button_declarations.erase(9524)
		result["unavailable_operations"]=["attendance_special_purchase"] if member.ends_with("Attendance_Tab_Daily.csb") else []
		result["complete_screen_contract"]=false
	return result

func build_slot(pack: RefCounted, member: String, row_id: String, remaining: Dictionary, tooltip: Callable) -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_attendance_session_unavailable")
	if member not in ["UI/Attendance/Attendance_Slot.csb","UI/Attendance/Attendance_SlotBonus.csb"]:return _fail("source_attendance_slot_unknown")
	if not tooltip.is_valid():return _fail("source_attendance_tooltip_handler_required")
	var presented: Dictionary=row_presentation(row_id)
	if not presented.get("ok",false):return presented
	if _selected_version==0 or presented.source_record.ID!=_selected_version:return _fail("source_attendance_slot_version_mismatch")
	var bonus: bool=member.ends_with("Attendance_SlotBonus.csb")
	var bindings: Dictionary=remaining.duplicate(true)
	# The serialized icon is explicitly a sample. It must not be delivered as
	# this reward's picture. Reuse the image owner's actual source-asset path,
	# rather than infer an item/amount from server alternatives or reward text.
	var icon_offset: int=5492 if bonus else 2972
	var amount_offset: int=5064 if bonus else 1780
	var icon_binding: Dictionary=bindings.get(icon_offset,{})
	var amount_binding: Dictionary=bindings.get(amount_offset,{})
	if icon_binding.get("role")!="source_asset" or not icon_binding.get("asset_ref") is Dictionary:return {"ok":false,"code":"source_attendance_reward_icon_reference_required","row_id":row_id,"offset":icon_offset}
	if amount_binding.get("role")!="source_text" or not amount_binding.get("text") is String:return {"ok":false,"code":"source_attendance_reward_amount_required","row_id":row_id,"offset":amount_offset}
	bindings[2716 if bonus else 688]={"visible":presented.claimed}
	if not bonus:bindings[2612]={"role":"source_text","text":str(presented.reward_index)}
	# The actual supplied button is Button_Tooltip, not a receive control.
	# Forward its exact row/source alternatives. Do not begin or auto-confirm
	# the available claim merely because this original slot was clicked.
	var callbacks: Dictionary={188 if bonus else 160:tooltip.bind(presented.duplicate(true))}
	var result: Dictionary=Children.build(pack,member,session,bindings,{},callbacks)
	if result.get("ok",false):
		result["row_presentation"]=presented
		result["unresolved_fields"]=["original_claim_presentation_event"]
		result["complete_screen_contract"]=false
	return result

func _project_row(row: Dictionary) -> Dictionary:
	var session: Object=_live_session()
	if session==null:return _fail("source_attendance_session_unavailable")
	var ui: Dictionary=row.get("source_ui",{})
	var version: Variant=ui.get("source_records",{}).get("AttendanceVersion")
	var reward_index: Variant=ui.get("reward_index")
	if ui.get("source_namespace")!="AttendanceVersion" or not version is Dictionary or version.get("ID")!=ui.get("source_id") or not (reward_index is int or reward_index is float):return _fail("source_attendance_row_identity_missing")
	var key: String="%d:%d:%s" % [int(version.ID),int(version.get("Version",0)),str(version.get("ServiceRegionCode",""))]
	if row.get("id")!="attendance:%s:%d" % [key,int(reward_index)]:return _fail("source_attendance_row_identity_mismatch")
	var progress: Dictionary=session.snapshot().get("progress",{}).get("attendance",{}).get(key,{}).duplicate(true)
	return {"ok":true,"row":row.duplicate(true),"source_record":version.duplicate(true),"server_reward_alternatives":ui.get("source_records",{}).get("AttendanceReward",{}).duplicate(true),"reward_index":int(reward_index),"progress":progress,"claimed":progress.get("claims",{}).has(str(int(reward_index)))}

func _live_session() -> Object:
	return _session.get_ref() if _session!=null else null

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
