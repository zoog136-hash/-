extends RefCounted
## Shared original 523 quantity and item confirmation scenes. The floor-drop
## flow is recorded in docs/INVENTORY_DRAG_DROP_KO.md.
## - a stack (more than one) first opens the original quantity keypad
##   Common_Calculator (0-9, MAX, ←, -/+, 취소/확인), default 1;
## - then the original message box Common_MessageBox_Dissolution asks
##   displays the operation, quantity and item; 확인 calls `on_confirm(count)`.
## Nothing here moves an item: the caller's existing transfer does that.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const BOX="UI/CommonUi/Common_MessageBox_Dissolution.csb"
const KEYPAD="UI/CommonUi/Common_Calculator.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const QUESTIONS={
	"drop":"%s %d개를 바닥에 내려놓으시겠습니까?",
	"deposit":"%s %d개를 창고에 맡기시겠습니까?",
	"withdraw":"%s %d개를 창고에서 찾으시겠습니까?",
}
const MEMBER_SCOPES={SLOT:[15728,15316,15012,6880]}
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _scene: Node2D
var _parent: Node
var _out: Dictionary={}
var _item_name: String=""
var _item_class_id: int=0
var _maximum: int=1
var _count: int=1
var _typed: String=""
var _on_confirm: Callable
var _can_confirm: Callable
var _operation: String="drop"
var stage: String=""
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node=null) -> Dictionary:
	for member: String in [BOX,KEYPAD,SLOT]:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_drop_popup_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud) if hud!=null else null
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## `maximum` > 1 starts with the keypad; otherwise the confirmation directly.
func open(parent: Node, item_name: String, item_class_id: int, maximum: int, on_confirm: Callable, permanent_delete: bool=false, quantity_only: bool=false) -> Dictionary:
	var operation: String="quantity" if quantity_only else ("delete" if permanent_delete else "drop")
	return _open(parent,item_name,item_class_id,maximum,on_confirm,operation)

func open_storage(parent: Node, item_name: String, item_class_id: int, maximum: int, on_confirm: Callable, direction: String, can_confirm: Callable=Callable()) -> Dictionary:
	if direction not in ["deposit","withdraw"]:return {"ok":false,"handled":false,"code":"source_storage_transfer_direction_invalid"}
	return _open(parent,item_name,item_class_id,maximum,on_confirm,direction,can_confirm)

func _open(parent: Node, item_name: String, item_class_id: int, maximum: int, on_confirm: Callable, operation: String, can_confirm: Callable=Callable()) -> Dictionary:
	if not is_instance_valid(parent) or (item_name.is_empty() and operation!="quantity") or maximum<1:return {"ok":false,"handled":false,"code":"source_drop_popup_input_invalid"}
	if _pack==null or (operation!="quantity" and not _pack.manifest.get("scenes",{}).has(BOX)):
		return {"ok":false,"handled":false,"code":"source_drop_popup_member_missing","member":BOX}
	_parent=parent
	_item_name=item_name
	_item_class_id=item_class_id
	_maximum=maximum
	_count=1
	_typed=""
	_on_confirm=on_confirm
	_can_confirm=can_confirm
	_operation=operation
	var result: Dictionary=_open_keypad() if maximum>1 or operation=="quantity" else _open_box()
	if not result.get("handled",false):
		_on_confirm=Callable()
		_can_confirm=Callable()
	return result

func _open_keypad() -> Dictionary:
	var spec: Dictionary={
		"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true},
		"Label_Volume":{"role":"source_text","text":str(_count)},
		"Btn_Max":{"activate":Callable(self,"_set_count").bind(-1)},
		"Btn_Back":{"activate":Callable(self,"_back")},
		"Btn_Minus":{"activate":Callable(self,"_step").bind(-1)},
		"Btn_Plus":{"activate":Callable(self,"_step").bind(1)},
		"Btn_Cancel":{"activate":Callable(self,"_close_requested")},
		"Btn_Select":{"activate":Callable(self,"_keypad_done")},
	}
	for digit: int in range(10): spec["Btn_No_%d" % digit]={"activate":Callable(self,"_digit").bind(digit)}
	return _show(KEYPAD,spec,"keypad")

func _open_box() -> Dictionary:
	var question: String="선택한 아이템 %d개를 영구 삭제하시겠습니까?" % _count if _operation=="delete" else (QUESTIONS[_operation] % [_item_name,_count])
	var spec: Dictionary={
		"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true},
		"Text_Message":{"role":"source_text","text":question},
		"Text_Info":{"visible":false},
		"Nd_Result/Label_Notice":{"visible":false},
		"Nd_Result/Nd_Slot/Label_Title":{"visible":false},
		"Nd_Result/Nd_Slot/Label_Item":{"role":"source_text","text":"%s %d" % [_item_name,_count]},
		"Nd_Result/Nd_Slot/Panel_R":{"visible":false},
		"Nd_Result/Nd_Slot/Panel_L":{"visible":false},
		"Nd_Result/Nd_Slot/Common_Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false},
		"Nd_Result/Nd_Slot/Common_Slot/Text_Amount":{"visible":false},
		"Btn_Cancel":{"activate":Callable(self,"_close_requested")},
		"Btn_Yes":{"activate":Callable(self,"_confirm")},
	}
	var shown: Dictionary=_show(BOX,spec,"confirm")
	if not shown.get("ok",false) or _item_class_id <= 0:return shown
	var located: Dictionary=NamedTree.locate(_scene,_out,"Nd_Result/Nd_Slot/Common_Slot/Sp_IconSample")
	if located.get("ok",false):
		var info: Dictionary=SourceImages.describe_item_class(_item_class_id,_item_name)
		shown["picture"]=NativeIcons.show_item(located.player, located.offset, info, _hud.get_ref() if _hud!=null else null)
	last_result=shown
	return shown

func _show(member: String, spec: Dictionary, next_stage: String) -> Dictionary:
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(member,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	close(false)
	var next: Node2D=built.scene
	# A full-screen layer under the popup keeps the field and HUD from taking taps.
	var blocker:=Control.new()
	blocker.name="DropModalArea"
	blocker.position=Vector2(-800.0,-337.5)
	blocker.size=Vector2(1600.0,675.0)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	next.add_child(blocker)
	next.move_child(blocker,0)
	next.position=Vector2(600.0,-337.5)
	_parent.add_child(next)
	next.z_index=170
	_scene=next
	_out=out
	stage=next_stage
	last_result={"ok":true,"handled":true,"member":member,"stage":next_stage,"count":_count,"maximum":_maximum,"permanent_delete":_operation=="delete"}
	return last_result

func _refresh_volume() -> void:
	if stage != "keypad" or not is_open():return
	var located: Dictionary=NamedTree.locate(_scene,_out,"Label_Volume")
	if located.get("ok",false):located.player.set_bound_text(located.offset,str(_count))

func _digit(value: int) -> Dictionary:
	_typed=(_typed+str(value)).lstrip("0")
	if _typed.length() > 12 or (not _typed.is_empty() and int(_typed) > _maximum):_typed=str(_maximum)
	_count=clampi(int(_typed) if not _typed.is_empty() else 1,1,_maximum)
	_refresh_volume()
	return {"ok":true,"count":_count}

func _back() -> Dictionary:
	_typed=_typed.left(maxi(0,_typed.length()-1))
	_count=clampi(int(_typed) if not _typed.is_empty() else 1,1,_maximum)
	_refresh_volume()
	return {"ok":true,"count":_count}

func _step(delta: int) -> Dictionary:
	_count=clampi(_count+delta,1,_maximum)
	_typed=str(_count)
	_refresh_volume()
	return {"ok":true,"count":_count}

## -1 = MAX.
func _set_count(value: int) -> Dictionary:
	_count=_maximum if value < 0 else clampi(value,1,_maximum)
	_typed=str(_count)
	_refresh_volume()
	return {"ok":true,"count":_count}

func _keypad_done() -> Dictionary:
	if _operation=="quantity":
		if stage != "keypad" or not is_open(): return {"ok":false}
		var next: Callable = _on_confirm
		var chosen: int = _count
		close()
		if next.is_valid(): next.call(chosen)
		return {"ok":true,"count":chosen}
	var shown: Dictionary=_open_box()
	if not shown.get("handled",false):
		close()
		var hud: Node=_hud.get_ref() if _hud!=null else null
		if hud!=null and hud.has_method("_report_original_window_unavailable"):
			hud._report_original_window_unavailable("아이템 확인",shown)
	return shown

func _confirm() -> Dictionary:
	if stage!="confirm" or not is_open():return {"ok":false,"code":"inventory_confirmation_not_open"}
	if _can_confirm.is_valid() and not _can_confirm.call():
		var message: Dictionary=NamedTree.locate(_scene,_out,"Text_Message")
		if message.get("ok",false):message.player.set_bound_text(message.offset,"저장 처리 중입니다. 완료 후 확인을 다시 누르세요.")
		return {"ok":false,"code":"storage_save_pending"}
	var callback: Callable=_on_confirm
	var count: int=_count
	close()
	var result: Variant=callback.call(count) if callback.is_valid() else false
	return {"ok":true,"confirmed":true,"count":count,"result":result}

func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}

func count() -> int:
	return _count

func close(emit: bool=true) -> void:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	if emit:
		stage=""
		_on_confirm=Callable()
		_can_confirm=Callable()
		closed.emit()
