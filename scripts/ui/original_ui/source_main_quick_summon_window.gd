extends "res://scripts/ui/original_ui/source_main_quick_card_base.gd"
## The original 523 빠른 소환 window (SummonQuick_All) for 마법인형.
## TWILIGHT 근사: see source_main_quick_card_base (favourites in the save,
## the existing equip).
## - 빠른 소환 tab: the registered dolls (SummonQuick_Tap_QuickSummonList,
##   client prefab Change_Card_A_<grade> with its own picture, the summoned
##   one checked); a tap summons through the existing equip.
## - 소환 리스트 tab: the owned dolls, nine per page (◀ ▶), registered ones
##   checked; a tap registers or takes out.
## - 소환 해제 takes the doll off.
const ROOT="UI/FloatingUi/SummonQuick_All.csb"
const CARD_LIST="UI/FloatingUi/SummonQuick_Tap_QuickSummonList.csb"
## quick / list
var tab: String="quick"

func category() -> String:
	return "마법인형"

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,CARD_LIST]
	members.append_array(_grade_members())
	return members

func _root_member() -> String:
	return ROOT

func _root_position() -> Vector2:
	return Vector2(191.3,-345.0)

func open(parent: Node) -> Dictionary:
	tab="quick"
	page=0
	return open_window(parent)

func _records() -> Array[Dictionary]:
	if tab=="list":return owned_cards()
	var shown: Array[Dictionary]=[]
	for id: String in registered():shown.append(_record(id))
	return shown

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for fx: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom"]:spec[fx]={"exclude":true}
	var listing: bool=tab=="list"
	spec["Tab/Btn_QuickSummon_On"]={"visible":not listing,"activate":Callable(self,"_ignore")}
	spec["Tab/Btn_QuickSummon_Off"]={"visible":listing,"activate":Callable(self,"_set_tab").bind("quick")}
	spec["Tab/Btn_SummonList_On"]={"visible":listing,"activate":Callable(self,"_ignore")}
	spec["Tab/Btn_SummonListOff"]={"visible":not listing,"activate":Callable(self,"_set_tab").bind("list")}
	var l: String="SummonQuick_Tap_QuickSummonList/Nd_QuickChangeList/"
	spec[l+"Btn_Prev"]={"activate":Callable(self,"_page").bind(-1)}
	spec[l+"Btn_Next"]={"activate":Callable(self,"_page").bind(1)}
	var pages: int=maxi(1,ceili(float(_records().size())/float(PER_ROW*ROWS.size())))
	page=clampi(page,0,pages-1)
	spec[l+"Label_PageInfo"]={"role":"source_text","text":"(%d/%d)" % [page+1,pages]}
	var worn: bool=not equipped_id().is_empty()
	spec["Menu_Button/Btn_Reset"]={"activate":Callable(self,"_unequip"),"displaystate":worn}
	spec["Menu_Button/Btn_Reset/Normal"]={"visible":worn}
	spec["Menu_Button/Btn_Reset/Disabled"]={"visible":not worn}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var marked: Array[String]=registered() if tab=="list" else ([equipped_id()] as Array[String])
	var listed: Dictionary=_fill_pages(root,out,"SummonQuick_Tap_QuickSummonList/Nd_QuickChangeList/ListView_Swipe/Panel_ListViews/",_records(),"toggle" if tab=="list" else "equip",marked)
	if not listed.get("ok",false):return listed
	return {"ok":true,"tab":tab,"registered":registered().size(),"shown":int(listed.shown),"pages":int(listed.pages)}

func _set_tab(value: String) -> Dictionary:
	tab=value
	page=0
	return _stage()

func toggle(id: String) -> Dictionary:
	var result: Dictionary=super.toggle(id)
	if is_open():_stage()
	return result

func equip(id: String) -> Dictionary:
	if id==equipped_id():
		_message("이미 소환 중입니다")
		return {"ok":true,"already":true}
	var result: Dictionary=super.equip(id)
	if is_open():_stage()
	return result

func _unequip() -> Dictionary:
	var result: Dictionary=super.equip("")
	if is_open():_stage()
	return result
