extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 나의 기억장소 window: Memory_All (frame, title, close) over
## the existing remembered locations (growth.travel: 에바 III 순간이동 조종,
## marks / quote / travel / forget). Opened where the game opens its 기억 장소
## page (a teleport scroll or spell with the control, or the growth page).
## - Each mark is one Memory_List row (name; its region in Label_Name). A tap
##   selects it (Btn_Pressed, the original teleport mark). With a teleport
##   source a tap on the selected row quotes the existing travel (cost, MP,
##   region entry) behind the HUD confirmation and runs
##   growth.travel.travel, which repeats every check, pays and saves.
##   Btn_Move (the reorder face) stays out: TWILIGHT keeps no mark order edit.
## - 삭제 forgets the selected mark (growth.travel.forget, confirmed); 편집
##   opens the existing 기억 장소 page, which remembers the current position
##   under a typed name; the count shows n/limit.
## Left empty (no TWILIGHT feature): 혈맹 기억장소 (tab and Btn_ClanMemory),
## 이름 change, 공유, the slot extension row and random teleport row.
const ROOT="UI/FloatingUi/Memory_All.csb"
const ROW="UI/FloatingUi/Memory_List.csb"
var source: Dictionary={}
var origin: String=""
var selected: int=-1

func required_members() -> Array[String]:
	return [ROOT,ROW]

func _root_member() -> String:
	return ROOT

## Memory_All_Layout sits at (191.3, 345) in FloatingUiScene.
func _root_position() -> Vector2:
	return Vector2(191.3,-345.0)

func _travel() -> Object:
	var owner: Object=world()
	var growth: Variant=owner.get("growth") if owner!=null else null
	return growth.get("travel") if growth is Object else null

func open(parent: Node, request: Dictionary={}) -> Dictionary:
	var travel: Object=_travel()
	if travel==null:return _fail("source_memory_window_runtime_unavailable")
	source=request.duplicate(true)
	origin=str(world().get("active_map_id"))
	selected=-1
	return open_window(parent)

func _revision() -> int:
	return int(_travel().runtime.state.get("revision",0))

func _region(mark: Dictionary) -> String:
	var maps: Variant=world().get("maps_by_id")
	var entry: Variant=maps.get(str(mark.get("map_id","")),{}) if maps is Dictionary else {}
	return str(entry.get("name",mark.get("map_id",""))) if entry is Dictionary else str(mark.get("map_id",""))

func _spec() -> Dictionary:
	var travel: Object=_travel()
	var marks: Array=travel.marks()
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Tab","Btn_ClanMemory","Btn_Cancel","Menu_Button/Btn_Share","Menu_Button/Btn_Save","Nd_Number/Sp_Icon","Nd_Number/Sp_Icon_Normal"]:spec[name]={"exclude":true}
	var limit: int=int(travel.POLICY.get("bookmark_limit",0))
	spec["Nd_Number/Text_Number"]={"role":"source_text","text":"%d/%d" % [marks.size(),limit]}
	var scroll: bool=str(source.get("kind",""))=="scroll"
	var owned: int=int(world().get("inventory").get(str(source.get("name","")),0)) if scroll else 0
	spec["Nd_Number/Sp_Icon_Teleport"]={"visible":scroll}
	spec["Nd_Number/Text_Number_1"]={"role":"source_text","text":_number(owned),"visible":scroll}
	spec["Nd_Notice"]={"visible":marks.is_empty()}
	spec["Nd_Notice/Text_Info"]={"role":"source_text","text":"편집에서 현재 위치를\n기억할 수 있습니다."}
	var chosen: bool=selected>=0 and selected<marks.size()
	spec["Menu_Button/Btn_Move"]={"activate":Callable(self,"_edit")}
	spec["Menu_Button/Btn_Delete"]={"activate":Callable(self,"_forget")}
	spec["Btn_Delete/Normal"]={"visible":chosen}
	spec["Btn_Delete/Disabled"]={"visible":not chosen}
	spec["Menu_Button/Btn_Edit"]={"activate":Callable(self,"_rename")}
	spec["Btn_Edit/Normal"]={"visible":false}
	spec["Btn_Edit/Disabled"]={"visible":true}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var marks: Array=_travel().marks()
	var moving: bool=not source.is_empty()
	var rows: Array=[]
	for i: int in range(marks.size()):
		var mark: Dictionary=marks[i]
		var name: String=str(mark.get("name",""))
		var on: bool=i==selected
		rows.append({"member":ROW,"spec":{
			"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_select").bind(i)},
			"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_select").bind(i)},
			"Panel/Btn_Move":{"exclude":true},
			"Btn_Normal/Label":{"role":"source_text","text":name},
			"Btn_Pressed/Label":{"role":"source_text","text":name},
			"Panel/Label_Name":{"role":"source_text","text":_region(mark)}}})
	var placed: Dictionary=_fill_list(root,out,"ListView",rows)
	if not placed.get("ok",false):return placed
	return {"ok":true,"marks":rows.size(),"moving":moving,"selected":selected}

## --- Actions -----------------------------------------------------------------

func _select(i: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if selected==i and not source.is_empty():return _move(i)
	selected=-1 if selected==i else i
	return _stage()

## A remembered place: the existing quote behind the HUD confirmation, then
## growth.travel.travel (its own checks, payment and save).
func _move(i: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var travel: Object=_travel()
	var revision: int=_revision()
	var offer: Dictionary=travel.quote(i,source,origin,revision)
	if not offer.get("ok",false):
		_message(str(offer.get("message","이동할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_memory_window_confirmation_unavailable")
	var request: Dictionary=source.duplicate(true)
	var from: String=origin
	owner.call("confirm_action","기억 장소",str(offer.message),"이동",func(_count: int) -> void:
		var done: Dictionary=travel.travel(i,request,from,revision)
		_message(str(done.get("message","")))
		if done.get("ok",false):_close_requested()
		elif is_open():_stage())
	return {"ok":true,"quoted":"travel"}

func _forget() -> Dictionary:
	var travel: Object=_travel()
	var marks: Array=travel.marks()
	if selected<0 or selected>=marks.size():
		_message("삭제할 기억 장소를 선택하세요")
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_memory_window_confirmation_unavailable")
	var index: int=selected
	var revision: int=_revision()
	owner.call("confirm_action","기억 장소 삭제",str(marks[index].get("name","")),"삭제",func(_count: int) -> void:
		var done: Dictionary=travel.forget(index,revision)
		_message(str(done.get("message","")))
		if done.get("ok",false):selected=-1
		if is_open():_stage())
	return {"ok":true,"quoted":"forget"}

## 편집: the existing 기억 장소 page (remember the current position by name).
func _edit() -> Dictionary:
	var travel: Object=_travel()
	var request: Dictionary=source.duplicate(true)
	close()
	travel.open_native(request)
	return {"ok":true,"routed":"open_native"}

func _rename() -> Dictionary:
	_message("기억 장소 이름 변경은 지원하지 않습니다")
	return {"ok":false}
