extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 스케줄 window (Schedule_All with Schedule_Tap_Hunt) over
## the existing 자동사냥 지역 feature (world.auto_hunting_destinations,
## built from the original AutoSchedule / AutoScheduleCategory rows). The
## three category buttons are the original categories SpecialDungeon (특수
## 던전), Field (아덴 필드) and Hadin (하딘의 텔레포트); each hunting ground is
## its category's original row (Schedule_List_Hunt_Special / _Field /
## _Teleport: name, the original teleport cost, the Adena icon for an Adena
## charge). Selecting a ground shows the existing movement assessment;
## 스케줄 시작 moves there through world.auto_hunting_move (quote -> HUD
## confirmation; the world repeats every check, charges and saves) and turns
## AUTO on, 스케줄 중지 turns AUTO off. The 옵션 tab opens the existing 자동사냥
## panel (TWILIGHT movement settings, landing choice, maintenance).
## Left empty (no TWILIGHT feature): the schedule list and its time budgets,
## 1/2/3 SET, sort, 무접속 플레이, 스케줄 자동 등록, report and help.
const ROOT="UI/Schedule/Schedule_All.csb"
const ROWS={1:"UI/Schedule/Schedule_List_Hunt_Special.csb",11:"UI/Schedule/Schedule_List_Hunt_Field.csb",21:"UI/Schedule/Schedule_List_Hunt_Teleport.csb"}
## Original AutoScheduleCategory.ID -> Schedule_Tap_Hunt category panel.
const PANELS={1:"Panel_Special",11:"Panel_Field",21:"Panel_Teleport"}
var category: int=11
var selected: int=-1

func required_members() -> Array[String]:
	return [ROOT,ROWS[1],ROWS[11],ROWS[21]]

func _root_member() -> String:
	return ROOT

func _entries() -> Array:
	var owner: Object=world()
	if owner==null or not owner.has_method("auto_hunting_destinations"):return []
	return owner.call("auto_hunting_destinations").get("entries",[])

func open(parent: Node) -> Dictionary:
	if _entries().is_empty():return _fail("source_schedule_window_destinations_unavailable")
	selected=-1
	return open_window(parent)

func _auto_on() -> bool:
	var owner: Object=world()
	var player: Variant=owner.get("player") if owner!=null else null
	return player is Object and bool((player as Object).get("auto_enabled"))

static func entry_name(entry: Dictionary) -> String:
	if entry.get("hunting_territory") is Dictionary:return str(entry.hunting_territory.get("Name",""))
	var destinations: Array=entry.get("destinations",[])
	return str(destinations[0].territory.get("Name","")) if not destinations.is_empty() else ""

func _entry(schedule_id: int) -> Dictionary:
	for entry: Dictionary in _entries():
		if int(entry.schedule.ID)==schedule_id:return entry
	return {}

## The existing assessment for a ground's first landing.
func _assess(entry: Dictionary) -> Dictionary:
	var owner: Object=world()
	var destinations: Array=entry.get("destinations",[])
	if owner==null or destinations.is_empty():return {"ok":false,"reason":"도착 지역 없음"}
	return owner.call("auto_hunting_movement_assessment",int(entry.schedule.ID),int(destinations[0].link.ID))

func _spec() -> Dictionary:
	var spec: Dictionary={}
	for name: String in ["Fx_Img_BG_Particle","Btn_ScheduleReport","Btn_Registration","Btn_NoConnection","Schedule_Popup_Registration","Btn_Play/Label_NoConnection",
		"Nd_Hunt/ListView_Schedule","Sp_Title_ScheduleList","Label_Title_ScheduleList","Nd_Category","Nd_Menu","Btn_Help","Nd_Hunt/Label","Btn_Reset","Btn_Delete","Nd_Time","Btn_Sort","Label_SpecialNotice"]:spec[name]={"exclude":true}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_TabMenu/Btn_Hunt_On"]={"visible":true}
	spec["Nd_TabMenu/Btn_Hunt_Off"]={"visible":false}
	spec["Nd_TabMenu/Btn_Option_On"]={"visible":false}
	spec["Nd_TabMenu/Btn_Option_Off"]={"visible":true,"activate":Callable(self,"_options")}
	spec["Schedule_Tap_Option"]={"exclude":true}
	for id: int in PANELS:
		var on: bool=id==category
		spec["ListView_Button/"+PANELS[id]+"/Btn_Normal"]={"visible":not on,"activate":Callable(self,"_category").bind(id)}
		spec["ListView_Button/"+PANELS[id]+"/Btn_Pressed"]={"visible":on,"activate":Callable(self,"_category").bind(id)}
	# 스케줄 시작 / 중지: AUTO off with a usable ground / AUTO on.
	var auto: bool=_auto_on()
	var usable: bool=selected>=0 and bool(_assess(_entry(selected)).get("ok",false))
	spec["Btn_Play/Btn_Disabled"]={"visible":not auto and not usable,"activate":Callable(self,"_start")}
	spec["Btn_Play/Btn_Start"]={"visible":not auto and usable,"activate":Callable(self,"_start")}
	spec["Btn_Play/Btn_Stop"]={"visible":auto,"activate":Callable(self,"_stop")}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var rows: Array=[]
	for entry: Dictionary in _entries():
		if int(entry.category.ID)!=category or not ROWS.has(category):continue
		var id: int=int(entry.schedule.ID)
		var on: bool=id==selected
		var adena: bool=str(entry.currency.get("Name",""))=="Adena"
		var name: String=entry_name(entry)
		rows.append({"member":ROWS[category],"spec":{"Panel/Panel_Normal":{"visible":true},"Panel/Panel_Disabled":{"visible":false},"Panel/Btn_CheckBox":{"visible":false},
			"Panel_Normal/Btn_Select":{"activate":Callable(self,"_select").bind(id)},"Panel_Normal/Img_Check":{"visible":on},"Panel_Normal/Img_Bg":{"visible":false},
			"Panel_Normal/Nd_Title/ListView_Title/Label_Title":{"role":"source_text","text":name},"Panel_Normal/Nd_Title/ListView_Title/Panel_Badge":{"visible":false},
			"Panel_Normal/Label_NoConnection":{"visible":false},
			"Panel/Label_Pay":{"role":"source_text","text":_number(int(entry.teleport.get("TeleportCost",0)))},"Panel/Sp_Icn_Pay":{"visible":adena}}})
	var listed: Dictionary=_fill_list(root,out,"Nd_Hunt/ListView_Hunt",rows)
	if not listed.get("ok",false):return listed
	return {"ok":true,"category":category,"grounds":rows.size(),"selected":selected}

## --- Actions ------------------------------------------------------------------

func _category(id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if id==category:return {"ok":true,"same":true}
	category=id
	selected=-1
	return _stage()

func _select(schedule_id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	selected=schedule_id
	var assessed: Dictionary=_assess(_entry(schedule_id))
	_message(str(assessed.get("reason","이동 조건 확인 중")))
	return _stage()

## 스케줄 시작: the existing movement (cost confirmation, world checks and
## save) to the selected ground, then AUTO on.
func _start() -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var entry: Dictionary=_entry(selected)
	if entry.is_empty():
		_message("사냥터를 선택하세요")
		return {"ok":false}
	var assessed: Dictionary=_assess(entry)
	if not assessed.get("ok",false):
		_message(str(assessed.get("reason","이동할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_schedule_window_confirmation_unavailable")
	var schedule_id: int=int(entry.schedule.ID)
	var link_id: int=int(entry.destinations[0].link.ID)
	var cost: String="%s %s" % [_number(int(entry.teleport.get("TeleportCost",0))),"아데나" if str(entry.currency.get("Name",""))=="Adena" else "다이아"]
	owner.call("confirm_action","스케줄 시작","%s\n이동 비용 %s · 도착 후 AUTO 시작" % [entry_name(entry),cost],"시작",func(_count: int) -> void:
		var moved: Dictionary=world().call("auto_hunting_move",schedule_id,link_id)
		_message(str(moved.get("reason","이동 결과 확인 실패")))
		if moved.get("ok",false) and not _auto_on() and owner.has_signal("auto_pressed"):owner.emit_signal("auto_pressed")
		if is_open():_stage())
	return {"ok":true,"quoted":"auto_hunting_move","schedule":schedule_id}

func _stop() -> Dictionary:
	var owner: Object=hud()
	if _auto_on() and owner!=null and owner.has_signal("auto_pressed"):owner.emit_signal("auto_pressed")
	return _stage()

## 옵션: the existing 자동사냥 panel.
func _options() -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	return _route("open_macro_info")
