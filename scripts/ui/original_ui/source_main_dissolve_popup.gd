extends RefCounted
## The original 523 용해 confirmation popup (Common_MessageBox_Dissolution)
## for the equipment chosen in the 용해·질서의 연금 panel: "N개의 아이템을
## 용해하시겠습니까?", the 예상 결과물 slot with the 축복의 가루 picture and
## "축복의 가루 <total>" from the service's BlessPowderAmount quote, 확인 runs
## the existing dissolve transaction (scripts/refine523), 취소 closes.
## Text_Info and the Panel_L / Panel_R arrows have no rule here and stay hidden.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const SERVICE=preload("res://scripts/refine523/bless_refine523_service.gd")
const ROOT="UI/CommonUi/Common_MessageBox_Dissolution.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316,15012,6880]}
signal closed
signal finished(result: Dictionary)
var _pack: RefCounted
var _tree: RefCounted
var _world: WeakRef
var _scene: Node2D
var _uids: Array=[]
var last_result: Dictionary={}

func configure(pack: RefCounted) -> Dictionary:
	for member: String in [ROOT,SLOT]:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_dissolve_popup_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node, uids: Array) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_dissolve_popup_host_unavailable")
	var quote: Dictionary=SERVICE.dissolve_quote(world,uids)
	if not quote.get("ok",false):return {"ok":false,"handled":false,"code":"source_dissolve_quote_refused","reason":str(quote.get("reason",""))}
	_world=weakref(world)
	_uids=uids.duplicate()
	# The record name may carry a " · 원본#<id>" disambiguation suffix.
	var name: String=str(SERVICE.D.definition_id(str(int(quote.output_item_class_id))).get("native_record",{}).get("name","축복의 가루")).get_slice(" · 원본#",0)
	var spec: Dictionary={
		"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true},
		"Text_Message":{"role":"source_text","text":"%d개의 아이템을 용해하시겠습니까?" % (quote.items as Array).size()},
		"Text_Info":{"visible":false},
		"Nd_Result/Label_Notice":{"visible":false},
		"Nd_Result/Nd_Slot/Label_Item":{"role":"source_text","text":"%s %d" % [name,int(quote.total)]},
		"Nd_Result/Nd_Slot/Panel_R":{"visible":false},
		"Nd_Result/Nd_Slot/Panel_L":{"visible":false},
		"Nd_Result/Nd_Slot/Common_Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false},
		"Nd_Result/Nd_Slot/Common_Slot/Text_Amount":{"visible":false},
		"Btn_Cancel":{"activate":Callable(self,"_close_requested")},
		"Btn_Yes":{"activate":Callable(self,"_confirm")},
	}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var picture: bool=false
	var located: Dictionary=NamedTree.locate(next,out,"Nd_Result/Nd_Slot/Common_Slot/Sp_IconSample")
	if located.get("ok",false):
		var info: Dictionary=SourceImages.describe_item_class(int(quote.output_item_class_id),name)
		if info.get("texture") is Texture2D:
			var owner: Dictionary={"ok":true,"texture":info.texture,"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
			picture=located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false) and located.player.set_bound_visible(located.offset,true).get("ok",false)
	close()
	# A full-screen layer under the popup keeps the field from taking taps.
	var blocker:=Control.new()
	blocker.name="DissolveModalArea"
	blocker.position=Vector2(-800.0,-337.5)
	blocker.size=Vector2(1600.0,675.0)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	next.add_child(blocker)
	next.move_child(blocker,0)
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=170
	_scene=next
	last_result={"ok":true,"handled":true,"member":ROOT,"items":(quote.items as Array).size(),"total":int(quote.total),"output_item_class_id":int(quote.output_item_class_id),"picture":picture}
	return last_result

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _confirm() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_dissolve_popup_host_unavailable")
	var result: Dictionary=SERVICE.dissolve(world,_uids)
	close()
	finished.emit(result)
	closed.emit()
	return result

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
