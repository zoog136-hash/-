extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 선택 보상 window (RewardSelectBoxScene /
## Common_Reward_SelectBox) over the existing reward choice
## (scripts/ui/patch523_reward_choice.gd: the box's original rows, the class
## filter, the claim and its save). The dialog opens this window and stays,
## hidden, as the owner its callers know; 확인 claims the chosen row through
## dialog.claim_entity, 취소 closes both (the box is kept).
## - Nd_Slot: the box's own original item picture; ListView: one Common_Slot
##   per reward (original picture, ×amount, Sp_Select on the chosen one),
##   a tap chooses it and names it (+N, 축복/저주).
## The quantity row's title and count line name the chosen reward.
## Left empty (no TWILIGHT feature): the quantity buttons (+1 / +10 / Max /
## 직접입력 / 초기화: TWILIGHT opens one box at a time), the calculator and the
## LuckyBag layouts.
const Choices=preload("res://scripts/ui/patch523_reward_choice.gd")
const ROOT="UI/RewardSelectBoxScene.csb"
const BOX="UI/CommonUi/Common_Reward_SelectBox.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const P="Common_Reward_SelectBox_Layout/Nd_Reward_SelectBox/"
## Common_Slot nodes left out (badges and states no rule here sets).
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
const BLESSING={2:"축복받은 ",3:"저주받은 "}
var chosen: int=-1
var _dialog: WeakRef
var _rows: Array=[]
## The mounted rows' Sp_Select nodes ([player, offset] per row): a tap only
## moves the selection mark, renames the chosen reward and enables 보상 받기
## in place instead of building the window again (a 40-row card box).
var _marks: Array=[]
var _row_buttons: Array=[]
var _labels: Array=[]
## Full builds of the window (tests).
var builds: int=0

func required_members() -> Array[String]:
	return [ROOT,BOX,SLOT]

func _root_member() -> String:
	return ROOT

## RewardSelectBoxScene is laid out on the 1200x675 design frame.
func _root_position() -> Vector2:
	return Vector2.ZERO

func open(parent: Node, dialog: Object) -> Dictionary:
	if not is_instance_valid(dialog) or not dialog.has_method("original_rows") or not dialog.has_method("claim_entity"):return _fail("source_reward_select_dialog_unavailable")
	_dialog=weakref(dialog)
	_rows=dialog.original_rows()
	if _rows.is_empty():return _fail("source_reward_select_rows_empty")
	chosen=-1
	if dialog is Node and not (dialog as Node).tree_exiting.is_connected(close):(dialog as Node).tree_exiting.connect(close)
	return open_window(parent)

func input_scene() -> Node2D:
	return _scene if is_open() else null

func append_row_buttons(found: Array) -> void:
	# Common_Slot controls are intentionally skipped by the ordinary bag
	# router. Here these exact buttons are owned by the displayed chooser.
	for button: Variant in _row_buttons:
		if is_instance_valid(button) and not found.has(button):found.append(button)

func dialog() -> Object:
	return _dialog.get_ref() if _dialog!=null else null

static func reward_name(row: Dictionary) -> String:
	var enchant: int=int(row.get("enchant",0))
	return "%s%s%s ×%d" % ["+%d " % enchant if enchant>0 else "",str(BLESSING.get(int(row.get("blessing",0)),"")),str(row.get("name","")),int(row.get("amount",1))]

## --- Spec -----------------------------------------------------------------------

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Common_Reward_SelectBox_Layout"]={"visible":true}
	for name: String in ["Common_Reward_SelectBox_LuckyBag01_Layout","Common_Reward_SelectBox_LuckyBag02_Layout"]:spec[name]={"exclude":true}
	spec["Black_BG"]={"role":"consume"}
	spec["Common_Reward_SelectBox_Layout/Nd_Common_Calculator"]={"exclude":true}
	# The quantity row's buttons have no TWILIGHT feature; its title and
	# count line name the chosen reward (TWILIGHT 근사).
	for name: String in ["Btn_1","Btn_10","Btn_Max","Btn_Self","Btn_Reset"]:spec[P+"Nd_Amount/"+name]={"exclude":true}
	spec[P+"Nd_Amount/Label_SubTitle"]={"role":"source_text","text":"선택한 보상"}
	spec[P+"Nd_Amount/Label_Num"]={"role":"source_text","text":reward_name(_rows[chosen]) if chosen>=0 and chosen<_rows.size() else "받을 보상을 고르세요"}
	for fx: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom"]:spec[P+fx]={"exclude":true}
	var owner: Object=dialog()
	var box: Dictionary=owner.box_info() if owner!=null and owner.has_method("box_info") else {}
	var title: String=str(box.get("name",""))
	spec[P+"Bg/Label_Title"]={"role":"source_text","text":title if not title.is_empty() else "선택 보상"}
	spec[P+"Bg/Label_Num"]={"visible":false}
	_slot_spec(spec,P+"Nd_Slot/Common_Slot/")
	spec[P+"Nd_Slot/Common_Slot/Sp_Select"]={"visible":false}
	spec[P+"Nd_Slot/Common_Slot/Text_Amount"]={"visible":false}
	spec[P+"Nd_Slot/Common_Slot/Btn"]={"activate":_open_item_info.bind(int(box.get("item_class_id",0))),"displaystate":int(box.get("item_class_id",0))>0}
	var ready: bool=chosen>=0
	spec[P+"Btn_OK"]={"activate":Callable(self,"_confirm"),"displaystate":ready}
	spec[P+"Btn_OK/Normal"]={"visible":ready}
	spec[P+"Btn_OK/Disabled"]={"visible":not ready}
	for state: String in ["Normal","Disabled"]:spec[P+"Btn_OK/%s/Label" % state]={"role":"source_text","text":"보상 받기"}
	spec[P+"Btn_Cancel"]={"activate":Callable(self,"_cancel")}
	return spec

func _slot_spec(spec: Dictionary, p: String) -> void:
	spec[p+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	for name: String in SLOT_EXCLUDED:spec[p+name]={"exclude":true}

## --- Fill -----------------------------------------------------------------------

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	builds+=1
	_marks=[]
	_row_buttons=[]
	_labels=[]
	var pictures: int=0
	var owner: Object=dialog()
	var box: Dictionary=owner.box_info() if owner!=null and owner.has_method("box_info") else {}
	var icon: Dictionary=_locate(root,out,"Nd_Slot/Common_Slot/Sp_IconSample")
	if icon.get("ok",false) and _show_item_icon(icon.player,icon.offset,_item_picture(int(box.get("item_class_id",0)),str(box.get("name","")))):pictures+=1
	var rows: Array=[]
	for index: int in range(_rows.size()):
		var row: Dictionary=_rows[index]
		var spec: Dictionary={}
		_slot_spec(spec,"")
		spec["Sp_Select"]={"visible":index==chosen}
		spec["Text_Amount"]={"role":"source_text","text":_number(int(row.get("amount",1))),"visible":int(row.get("amount",1))>1}
		spec["Btn"]={"activate":Callable(self,"_choose").bind(index)}
		rows.append({"member":SLOT,"spec":spec})
	var placed: Dictionary=_fill_list(root,out,P+"ListView",rows,NAN,false,5)
	if not placed.get("ok",false):return placed
	for index: int in range(rows.size()):
		var action: Dictionary=_locate(placed.scenes[index],placed.outs[index],"Btn")
		var action_node: Node=action.player.source_nodes.get(action.offset) if action.get("ok",false) else null
		_row_buttons.append(action_node.get_meta("source_button",null) if is_instance_valid(action_node) and action_node.has_meta("source_button") else null)
		var located: Dictionary=_locate(placed.scenes[index],placed.outs[index],"Sp_IconSample")
		var row: Dictionary=_rows[index]
		if located.get("ok",false) and _show_item_icon(located.player,located.offset,_item_picture(int(row.get("item_class_id",0)),str(row.get("name","")))):pictures+=1
		var mark: Dictionary=_locate(placed.scenes[index],placed.outs[index],"Sp_Select")
		_marks.append([mark.player,int(mark.offset)] if mark.get("ok",false) else [])
	for suffix: String in [P+"Nd_Amount/Label_Num",P+"Btn_OK",P+"Btn_OK/Normal",P+"Btn_OK/Disabled"]:
		var found: Dictionary=_locate(root,out,suffix)
		_labels.append([found.player,int(found.offset)] if found.get("ok",false) else [])
	return {"ok":true,"rows":rows.size(),"chosen":chosen,"pictures":pictures}

static func _item_picture(item_class_id: int, title: String) -> Dictionary:
	if item_class_id<=0:return {"ok":false}
	return Choices.describe_choice_icon(item_class_id,title)

## --- Actions --------------------------------------------------------------------

func _choose(index: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if index<0 or index>=_rows.size():return {"ok":false}
	chosen=index
	_message(reward_name(_rows[index]))
	if _mark_in_place():return {"ok":true,"handled":true,"in_place":true,"chosen":chosen}
	return _stage()

## Moves the selection to `chosen` in the mounted window; false when it has
## to be built again (not open, or a node is missing).
func _mark_in_place() -> bool:
	if not is_open() or _marks.size()!=_rows.size() or _labels.size()!=4:return false
	for entry: Array in _marks+_labels:
		if entry.is_empty() or not is_instance_valid(entry[0]):return false
	for index: int in range(_marks.size()):
		if not _marks[index][0].set_bound_visible(_marks[index][1],index==chosen).get("ok",false):return false
	var ok: bool=_labels[0][0].set_bound_text(_labels[0][1],reward_name(_rows[chosen])).get("ok",false)
	ok=ok and _labels[1][0].set_bound_displaystate(_labels[1][1],true).get("ok",false)
	ok=ok and _labels[2][0].set_bound_visible(_labels[2][1],true).get("ok",false)
	ok=ok and _labels[3][0].set_bound_visible(_labels[3][1],false).get("ok",false)
	return ok

## 보상 받기: the dialog's own claim of the chosen row.
func _confirm() -> Dictionary:
	var owner: Object=dialog()
	if chosen<0 or chosen>=_rows.size():
		_message("받을 보상을 고르세요")
		return {"ok":false}
	if owner==null:
		close()
		return _fail("source_reward_select_dialog_unavailable")
	var claimed: bool=bool(owner.claim_entity(int(_rows[chosen].entity_id)))
	if claimed:close()
	return {"ok":claimed,"claimed":claimed}

## 취소: the box stays; the dialog and this window close.
func _cancel() -> Dictionary:
	var owner: Object=dialog()
	close()
	if owner is Node and is_instance_valid(owner):(owner as Node).queue_free()
	return {"ok":true,"cancelled":true}

func _close_requested() -> Dictionary:
	return _cancel()
