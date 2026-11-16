extends "res://scripts/ui/original_ui/source_main_quick_card_base.gd"
## The original 523 빠른 변신 window (ChangeQuick_All). TWILIGHT 근사: see
## source_main_quick_card_base (favourites in the save, the existing equip).
## - 빠른 변신 tab: the nine Nd_Card_01..09 cells: a registered card shows
##   its client prefab Change_Card_A_<grade> with its own picture (a tap
##   transforms through the existing equip; the equipped one is checked),
##   an empty cell keeps Change_Card_A_Empty (its + opens 관리).
##   관리 opens the owned list; 해제 takes the polymorph off.
## - 관리 (ChangeQuick_Tap_QuickChangeList): the owned 변신 cards, nine per page
##   (◀ ▶), registered ones checked; a tap registers or takes out. 모두 초기화
##   clears the list, 변신 해제 takes the polymorph off, Btn_Back returns.
## - 등급 리스트 (ChangeQuick_Tap_QuickGradeList): 전체 / 유일 / ... / 일반 filter
##   the 관리 list.
## Left out: the event grade list (ListView_Grade_Event) and the popup effects.
const ROOT="UI/Change/ChangeQuick_All.csb"
const GRADE_LIST="UI/Change/ChangeQuick_Tap_QuickGradeList.csb"
const CARD_LIST="UI/Change/ChangeQuick_Tap_QuickChangeList.csb"
const EMPTY="UI/Change/Change_Card_A_Empty.csb"
const GRADE_BUTTONS={"Btn_All":"","Btn_Sole":"유일","Btn_Myth":"신화","Btn_Epic":"전설","Btn_Legend":"영웅","Btn_Unique":"희귀","Btn_Rare":"고급","Btn_Common":"일반"}
## quick / edit / grade
var mode: String="quick"
var grade: String=""

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,GRADE_LIST,CARD_LIST,EMPTY]
	members.append_array(_grade_members())
	return members

func _root_member() -> String:
	return ROOT

func _root_position() -> Vector2:
	return Vector2(191.3,-345.0)

func open(parent: Node) -> Dictionary:
	mode="quick"
	page=0
	return open_window(parent)

func _spec() -> Dictionary:
	var spec: Dictionary={}
	var editing: bool=mode!="quick"
	spec["Btn_Close"]={"visible":not editing,"activate":Callable(self,"_close_requested")}
	spec["Btn_Back"]={"visible":editing,"activate":Callable(self,"_set_mode").bind("quick")}
	for fx: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom"]:spec[fx]={"exclude":true}
	var tab_grade: bool=mode=="grade"
	spec["Tab/Btn_QuickChange_On"]={"visible":not tab_grade,"activate":Callable(self,"_set_mode").bind("edit" if editing else "quick")}
	spec["Tab/Btn_QuickChange_Off"]={"visible":tab_grade,"activate":Callable(self,"_set_mode").bind("edit")}
	spec["Tab/Btn_GradeList_On"]={"visible":tab_grade,"activate":Callable(self,"_ignore")}
	spec["Tab/Btn_GradeListOff"]={"visible":not tab_grade,"activate":Callable(self,"_set_mode").bind("grade")}
	# 빠른 변신: the nine cells.
	spec["Nd_Quick"]={"visible":mode=="quick"}
	var ids: Array[String]=registered()
	for index: int in range(SLOTS):
		var key: String="Nd_Quick/Nd_Card_%02d/Card_%02d" % [index+1,index+1]
		if index<ids.size():spec[key]={"exclude":true}
		else:
			spec[key+"/Panel_Root"]={"role":"consume"}
			spec[key+"/Panel_Root/Btn_Plus"]={"activate":Callable(self,"_set_mode").bind("edit")}
	# 관리 list and 등급 리스트.
	spec["ChageQuick_Tap_QuickChangeList"]={"visible":mode=="edit"}
	var l: String="ChageQuick_Tap_QuickChangeList/Nd_QuickChangeList/"
	spec[l+"Btn_Prev"]={"activate":Callable(self,"_page").bind(-1)}
	spec[l+"Btn_Next"]={"activate":Callable(self,"_page").bind(1)}
	var pages: int=maxi(1,ceili(float(owned_cards(grade).size())/float(PER_ROW*ROWS.size())))
	page=clampi(page,0,pages-1)
	spec[l+"Label_PageInfo"]={"role":"source_text","text":"(%d/%d)" % [page+1,pages]}
	spec["ChageQuick_Tap_QuickGradeList"]={"visible":tab_grade}
	var g: String="ChageQuick_Tap_QuickGradeList/Nd_QuickGradeList/"
	spec[g+"ListView_Grade_Event"]={"exclude":true}
	for button: String in GRADE_BUTTONS:spec[g+"ListView_Grade/"+button]={"activate":Callable(self,"_set_grade").bind(str(GRADE_BUTTONS[button]))}
	# Buttons.
	spec["Menu_Button"]={"visible":mode=="quick"}
	spec["Menu_Button/Btn_Management"]={"activate":Callable(self,"_set_mode").bind("edit")}
	var worn: bool=not equipped_id().is_empty()
	spec["Menu_Button/Btn_Reset"]={"activate":Callable(self,"_unequip"),"displaystate":worn}
	for state: String in ["Normal","Disabled"]:spec["Menu_Button/Btn_Reset/%s/Label" % state]={"role":"source_text","text":"변신 해제"}
	spec["Menu_Button/Btn_Reset/Normal"]={"visible":worn}
	spec["Menu_Button/Btn_Reset/Disabled"]={"visible":not worn}
	spec["Menu_Button_Edit"]={"visible":editing}
	spec["Menu_Button_Edit/Btn_AllReset"]={"activate":Callable(self,"_clear"),"displaystate":not ids.is_empty()}
	spec["Menu_Button_Edit/Btn_AllReset/Normal"]={"visible":not ids.is_empty()}
	spec["Menu_Button_Edit/Btn_AllReset/Disabled"]={"visible":ids.is_empty()}
	spec["Menu_Button_Edit/Btn_ChangeClear"]={"activate":Callable(self,"_unequip"),"displaystate":worn}
	spec["Menu_Button_Edit/Btn_ChangeClear/Normal"]={"visible":worn}
	spec["Menu_Button_Edit/Btn_ChangeClear/Disabled"]={"visible":not worn}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var ids: Array[String]=registered()
	var filled: Dictionary={"ok":true,"mode":mode,"registered":ids.size(),"grade":grade}
	if mode=="quick":
		var pictures: int=0
		var worn: String=equipped_id()
		for index: int in range(ids.size()):
			var record: Dictionary=_record(ids[index])
			var located: Dictionary=_locate(root,out,"Nd_Quick/Nd_Card_%02d" % (index+1))
			var cell: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
			if not cell is Node2D:continue
			var card_out: Dictionary={}
			var built: Dictionary=_scene_of(str(Page.GRADE_MEMBERS[str(record.grade)]),_prefab_spec(Callable(self,"_card_input").bind("equip",ids[index]),ids[index]==worn,Callable(self,"_checked").bind("equip",ids[index])),card_out)
			if not built.get("ok",false):return built
			(cell as Node2D).add_child(built.scene)
			if _prefab_picture(built.scene,card_out,record):pictures+=1
		filled["pictures"]=pictures
	elif mode=="edit":
		var listed: Dictionary=_fill_pages(root,out,"ChageQuick_Tap_QuickChangeList/Nd_QuickChangeList/ListView_Swipe/Panel_ListViews/",owned_cards(grade),"toggle",ids)
		if not listed.get("ok",false):return listed
		filled["shown"]=int(listed.shown)
		filled["pages"]=int(listed.pages)
	return filled

## --- Actions --------------------------------------------------------------------

func _set_mode(value: String) -> Dictionary:
	mode=value
	return _stage()

func _set_grade(value: String) -> Dictionary:
	grade=value
	page=0
	mode="edit"
	return _stage()

func toggle(id: String) -> Dictionary:
	var result: Dictionary=super.toggle(id)
	if is_open():_stage()
	return result

func equip(id: String) -> Dictionary:
	if id==equipped_id():
		_message("이미 변신 중입니다")
		return {"ok":true,"already":true}
	var result: Dictionary=super.equip(id)
	if is_open():_stage()
	return result

func _unequip() -> Dictionary:
	var result: Dictionary=super.equip("")
	if is_open():_stage()
	return result

func _clear() -> Dictionary:
	var result: Dictionary=clear_all()
	if is_open():_stage()
	return result
