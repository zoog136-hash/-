extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 실패 이력 조회 window (FailHistory_All) over the failure
## records the existing TJ의 쿠폰 feature already keeps
## (world.tj_coupons.core.state.history: card_draw_fusion and the awakening
## engine record every failed 합성 / 각성 with its HistoryType, GradeID and
## time). Read only: nothing is recorded, used or removed here.
## - 조회할 이력 선택 (Btn_Sort -> FailHistory_ButtonSet): 변신 / 마법인형 / 성물
##   합성 and 각성 (HistoryType 1 / 11 / 21 and 41 / 51 / 61).
## - The list: per original grade (highest first) a FailHistory_List_Text_Title
##   row, then one FailHistory_List_Text_Info row per failure (what failed and
##   when; a record a coupon already retried says so).
## - 집계 기간: from the oldest shown record.
## The client panel has no close button: a tap outside it closes it (a
## transparent catcher under the panel also keeps taps off the HUD).
## Left empty (no TWILIGHT record): 스킬 합성 and the 장비 복구 kinds (their
## lists say 실패 이력이 없습니다).
const ROOT="UI/FloatingUi/FailHistory_All.csb"
const BUTTONS="UI/FloatingUi/FailHistory_ButtonSet.csb"
const TITLE_ROW="UI/FloatingUi/FailHistory_List_Text_Title.csb"
const INFO_ROW="UI/FloatingUi/FailHistory_List_Text_Info.csb"
## FailHistory_ButtonSet button -> [label, HistoryType (0: no record kind)].
const KINDS={"Btn_Change_Mix":["변신 합성",1],"Btn_Change_Awaken":["변신 각성",41],"Btn_Magic_Mix":["마법인형 합성",11],"Btn_Magic_Awaken":["마법인형 각성",51],
	"Btn_HolyRelics_Mix":["성물 합성",21],"Btn_HolyRelics_Awaken":["성물 각성",61],"Btn_Skill_Mix":["스킬 합성",0],
	"Btn_Rune_Equip_Repair":["룬 장비 복구",0],"Btn_Shop_Equip_Repair":["상점 장비 복구",0],"Btn_Normal_Equip_Repair":["일반 장비 복구",0]}
const GRADE_NAMES={1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}
const GRADE_ORDER: Array[int]=[52,32,5,4,3,2,1]
const UTC_OFFSET_MINUTES: int=540
var kind: String="Btn_Change_Mix"
var choosing: bool=false

func required_members() -> Array[String]:
	return [ROOT,BUTTONS,TITLE_ROW,INFO_ROW]

func _root_member() -> String:
	return ROOT

## The FloatingUi side-panel position (FloatingUiScene names no FailHistory layout).
func _root_position() -> Vector2:
	return Vector2(191.3,-345.0)

func open(parent: Node, start_kind: String="") -> Dictionary:
	if KINDS.has(start_kind):kind=start_kind
	choosing=false
	return open_window(parent)

## The TJ failure records and the ids a coupon already retried.
func _state() -> Dictionary:
	var owner: Object=world()
	var tj: Variant=owner.get("tj_coupons") if owner!=null else null
	var core: Variant=tj.get("core") if tj is Object else null
	var state: Variant=core.get("state") if core is Object else null
	return state if state is Dictionary else {}

## The records of HistoryType `history_type`, newest first.
static func records(state: Dictionary, history_type: int) -> Array:
	var found: Array=[]
	if history_type<=0:return found
	for event: Variant in state.get("history",[]):
		if event is Dictionary and int(event.get("history_type",-1))==history_type:found.append(event)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:return int(a.get("time",0))>int(b.get("time",0)))
	return found

static func date_text(epoch: int) -> String:
	var d: Dictionary=Time.get_datetime_dict_from_unix_time(epoch+UTC_OFFSET_MINUTES*60)
	return "%04d.%02d.%02d %02d:%02d" % [int(d.year),int(d.month),int(d.day),int(d.hour),int(d.minute)]

func _spec() -> Dictionary:
	var spec: Dictionary={}
	for fx: String in ["Nd_Bg/Fx_Popup_RightBottom","Nd_Bg/Fx_Popup_LeftUp"]:spec[fx]={"exclude":true}
	var label: String=str(KINDS[kind][0])
	spec["Nd_HistorySelect/Btn_Sort"]={"activate":Callable(self,"_toggle_choose")}
	spec["Nd_HistorySelect/Btn_Sort/Normal"]={"visible":not choosing}
	spec["Nd_HistorySelect/Btn_Sort/Enable"]={"visible":choosing}
	for state: String in ["Normal","Enable"]:spec["Nd_HistorySelect/Btn_Sort/%s/Label_Menu" % state]={"role":"source_text","text":label}
	spec["FailHistory_ButtonSet"]={"visible":choosing}
	spec["FailHistory_ButtonSet/Nd_ButtonSet/Img_Bg"]={"role":"consume"}
	for button: String in KINDS:
		var on: bool=button==kind
		spec["Nd_ButtonSet/%s_On" % button]={"visible":on,"activate":Callable(self,"_choose").bind(button)}
		spec["Nd_ButtonSet/%s_Off" % button]={"visible":not on,"activate":Callable(self,"_choose").bind(button)}
	var shown: Array=records(_state(),int(KINDS[kind][1]))
	spec["Label_Notice"]={"visible":shown.is_empty()}
	spec["Label_Date_Info"]={"role":"source_text","text":(date_text(int(shown[-1].get("time",0)))+" ~") if not shown.is_empty() else "-","visible":true}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var state: Dictionary=_state()
	var used: Dictionary=state.get("used",{})
	var shown: Array=records(state,int(KINDS[kind][1]))
	var by_grade: Dictionary={}
	for event: Dictionary in shown:
		var grade: int=int(event.get("grade",0))
		if not by_grade.has(grade):by_grade[grade]=[]
		by_grade[grade].append(event)
	var grades: Array=GRADE_ORDER.duplicate()
	for grade: Variant in by_grade:
		if not int(grade) in grades:grades.append(int(grade))
	var rows: Array=[]
	var label: String=str(KINDS[kind][0])
	for grade: int in grades:
		if not by_grade.has(grade):continue
		rows.append({"member":TITLE_ROW,"spec":{"Panel_Title02":{"exclude":true},"Panel_Title01/Label_Grade":{"role":"source_text","text":str(GRADE_NAMES.get(grade,str(grade)))}}})
		for event: Dictionary in by_grade[grade]:
			var retried: bool=used.has(str(event.get("id","")))
			rows.append({"member":INFO_ROW,"spec":{"Panel_Info01":{"exclude":true},
				"Panel_Info02/Label_Item":{"role":"source_text","text":"%s %s 실패%s" % [str(GRADE_NAMES.get(grade,"")),label,(" · 재도전함" if retried else "")]},
				"Panel_Info02/Label_Date":{"role":"source_text","text":date_text(int(event.get("time",0)))}}})
	var placed: Dictionary=_fill_list(root,out,"ListView",rows)
	if not placed.get("ok",false):return placed
	var catcher:=Control.new()
	catcher.name="FailHistoryOutsideClose"
	catcher.position=Vector2(-4000.0,-4000.0)
	catcher.size=Vector2(8000.0,8000.0)
	catcher.mouse_filter=Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_outside_input)
	root.add_child(catcher)
	root.move_child(catcher,0)
	return {"ok":true,"kind":kind,"records":shown.size(),"rows":rows.size(),"choosing":choosing}

func _outside_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)) and not event.pressed:
		close.call_deferred()

func _toggle_choose() -> Dictionary:
	choosing=not choosing
	return _stage()

func _choose(button: String) -> Dictionary:
	kind=button
	choosing=false
	return _stage()

## Only this window closes.
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
