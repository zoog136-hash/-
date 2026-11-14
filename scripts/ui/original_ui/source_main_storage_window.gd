extends RefCounted
## The original 523 창고 window: Storage_All (frame, 창 고 / 맡기기 title,
## close) with the 창고 grid (Storage_AccountInvGridMode, left) and the 소지품
## grid (Storage_Inventory, right), each listing four items per
## Inventory_Slot_Set line with the 전체 / 장비 / (소모) / 기타 tabs.
## The 소지품 grid of the client names QuickSlotEdit_SlotSet, absent from the
## 523 client; by the user's decision (A안) it shows the same Inventory_Slot_Set
## lines as the 창고 grid. Rows, rules and transfers stay with the existing
## warehouse screen (renewal_warehouse): tapping a 소지품 item asks 보관 and a
## 창고 item asks 찾기 through its confirmation, the world moves the items and
## refreshes this window.
## Left out (no rule here): 모두 찾기 / 모두 맡기기, the 1 / 10 / 100 / 직접 입력
## batch buttons, 자동 보관 and its settings, the cart (weight / cost), list
## mode, 이동 / 정렬, help, tooltips and every effect layer.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const ROOT="UI/Storage/Storage_All.csb"
const BAG="UI/Storage/Storage_Inventory.csb"
const STORE="UI/Storage/Storage_AccountInvGridMode.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316,15012,9004,6880]}
const REQUIRED: Array[String]=[ROOT,BAG,STORE,SET,SLOT]
## Storage_All_Layout in StorageScene (600, 337.5).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
const P_BAG="Inventory/Nd_Inventory/"
const P_STORE="AccountInv_GridMode/Nd_Inventory/"
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
## Inventory_Slot_Set's horizontal slot pitch as the line pitch (the main
## inventory, refine and enchant windows' rule).
const ROW_PITCH: float=76.0
const ROW_TAIL: float=40.0
## Storage_Inventory's SlotSet sits one unit right of the 창고 grid's.
const BAG_ROW_SHIFT=Vector2(1.0,0.0)
const OTHER: Array[String]=["Cart","Storage_KeepAuto","Storage_KeepAuto_Equipment","AccountInv_ListMode","Btn_Confirm_On","Btn_Sell_On","Nd_SaleButton","Nd_AutoKeep","Nd_Auto_Set_Group","Btn_Help","Hud_AutoMessage_Dungeon","FullFrameType_A/Fx_Img_BG_Particle","Nd_Spine"]
const BAG_TABS: Array[String]=["all","equip","consume","etc"]
const STORE_TABS: Array[String]=["all","equip","etc"]
const TAB_NODES={"all":"Btn_All","equip":"Btn_Equipment","consume":"Btn_Consume","etc":"Btn_Etc"}
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _screen: WeakRef
var _scene: Node2D
var _tabs: Dictionary={"bag":"all","store":"all"}
var _scrollers: Dictionary={"bag":Scroller.new(),"store":Scroller.new()}
var _rows: Dictionary={"bag":[],"store":[]}
var _last_out: Dictionary={}
var last_result: Dictionary={}

## Drag scrolling of one original ScrollView whose first line is extended by
## added lines (the refine / enchant windows' rule).
class Scroller extends RefCounted:
	var content: Node2D
	var top: float=0.0
	var bottom: float=0.0
	var y: Variant=null
	var drag: bool=false
	var moved: float=0.0

	func bind(list_content: Node2D, row_offset: float, lines: int) -> void:
		content=list_content
		if not is_instance_valid(content):return
		top=content.position.y
		bottom=minf(top,-(row_offset+ROW_PITCH*float(lines-1)+ROW_TAIL))
		if y!=null:content.position.y=clampf(float(y),bottom,top)

	func keep() -> void:
		if is_instance_valid(content):y=content.position.y

	func input(event: InputEvent) -> void:
		if not is_instance_valid(content):return
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
			drag=event.pressed
			if event.pressed:moved=0.0
			return
		var delta: float=0.0
		if event is InputEventScreenDrag:delta=event.relative.y
		elif event is InputEventMouseMotion and drag:delta=event.relative.y
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			delta=ROW_PITCH*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
		if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
		moved+=absf(delta)
		content.position.y=clampf(content.position.y+delta,bottom,top)
		y=content.position.y

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_storage_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## `screen` is the existing warehouse screen (renewal_warehouse) that owns the
## rows and the transfer confirmation.
func open(parent: Node, screen: Object) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(screen):return _fail("source_storage_window_host_unavailable")
	_parent=weakref(parent)
	_screen=weakref(screen)
	_tabs={"bag":"all","store":"all"}
	for scroller: Scroller in _scrollers.values():scroller.y=null
	return _stage()

func refresh() -> Dictionary:
	if not is_open():return {"ok":true,"handled":false}
	for scroller: Scroller in _scrollers.values():scroller.keep()
	return _stage()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	for scroller: Scroller in _scrollers.values():scroller.content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func node_keys() -> Dictionary:
	return _last_out

func rows(side: String) -> Array:
	return _rows.get(side,[])

func tab(side: String) -> String:
	return str(_tabs.get(side,"all"))

## --- Model ------------------------------------------------------------------

## The warehouse screen's rows of one side filtered by its tab.
static func filter(rows_in: Array, tab_name: String, classify: Callable) -> Array:
	if tab_name=="all":return rows_in.duplicate()
	var out: Array=[]
	for row: Variant in rows_in:
		if row is Dictionary and str(classify.call(row))==tab_name:out.append(row)
	return out

## 장비 / 소모 / 기타 by the item's catalog record (the bag's own split).
static func kind_of(record: Dictionary, equipment: bool) -> String:
	if equipment:return "equip"
	if str(record.get("slot","")).to_lower()=="consumable" or str(record.get("type",""))=="소모품":return "consume"
	return "etc"

static func reference_of(row: Dictionary) -> String:
	var id: String=str(row.get("instance_id",""))
	return str(row.get("name",""))+("@@@"+id if not id.is_empty() else "")

static func amount_text(row: Dictionary) -> String:
	if not str(row.get("instance_id","")).is_empty():
		var level: int=int(row.get("level",0))
		return "+%d" % level if level>0 else ""
	var count: int=int(row.get("count",0))
	return str(count) if count>1 else ""

func _side_rows(side: String) -> Array:
	var screen: Object=_screen.get_ref() if _screen!=null else null
	if screen==null:return []
	var all_rows: Array=screen.call("rows_for",side=="bag")
	var store_tab: String=str(_tabs[side])
	# 창고 has no 소모 tab: its 기타 holds consumables too.
	var classify: Callable=func(row: Dictionary) -> String:
		var kind: String=kind_of(_record(row,side),bool(screen.call("_is_equipment",str(row.get("name","")))))
		return "etc" if side=="store" and kind=="consume" else kind
	return filter(all_rows,store_tab,classify)

func _record(row: Dictionary, side: String) -> Dictionary:
	var screen: Object=_screen.get_ref() if _screen!=null else null
	if screen==null:return {}
	var world: Object=screen.get("world")
	var name: String=str(row.get("name",""))
	var record: Dictionary=world.call("_find_catalog_item_record",name)
	var id: String=str(row.get("instance_id",""))
	var physical: Variant=world.get("item_instances") if side=="bag" else world.get("warehouse").get("instances")
	if not id.is_empty() and physical is Dictionary and physical.has(id) and physical[id] is Dictionary:record=physical[id].get("record",record)
	return record

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null or _screen==null or _screen.get_ref()==null:return _fail("source_storage_window_host_unavailable")
	_rows={"bag":_side_rows("bag"),"store":_side_rows("store")}
	var spec: Dictionary={}
	for name: String in OTHER:spec[name]={"exclude":true}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for side: String in ["bag","store"]:
		var p: String=P_BAG if side=="bag" else P_STORE
		var tabs: Array[String]=BAG_TABS if side=="bag" else STORE_TABS
		for tab_name: String in tabs:
			var on: bool=_tabs[side]==tab_name
			spec[p+"Tab/"+TAB_NODES[tab_name]+"_On"]={"visible":on}
			spec[p+"Tab/"+TAB_NODES[tab_name]+"_Off"]={"visible":not on,"activate":Callable(self,"_set_tab").bind(side,tab_name)}
		spec[p+"Nd_Number/Label_Count"]={"role":"source_text","text":str((_rows[side] as Array).size())}
		spec[p+"ScrollView"]={"role":"source_scroll","input":Callable(_scrollers[side],"input")}
	# The 창고 grid's own first line; the 소지품 grid gets its lines below.
	spec.merge(_row_spec("store",0,P_STORE+"ScrollView/SlotSet/Nd_Slot/"),true)
	for name: String in ["Nd_Slot/Fx_Slot_UnLock","Nd_Slot_Extension","Nd_Slot_Extension_Lock"]:spec[P_STORE+"ScrollView/SlotSet/"+name]={"exclude":true}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var first: Variant=_node(next,out,P_STORE+"ScrollView/SlotSet")
	var store_content: Variant=_content(first)
	var bag_content: Variant=_scroll_content(next,out,P_BAG+"ScrollView")
	if not first is Node2D or not store_content is Node2D or not bag_content is Node2D:
		next.free()
		last_result=_fail("source_storage_window_slot_rows_missing")
		return last_result
	var row_position: Vector2=_offset_in(first,store_content)
	var pictures: int=0
	for index: int in range(SET_SLOTS.size()):
		_forward(next,out,P_STORE+"ScrollView/SlotSet/Nd_Slot/"+SET_SLOTS[index]+"/Btn",_scrollers.store)
		if index<_rows.store.size() and _picture(next,out,P_STORE+"ScrollView/SlotSet/Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",_record(_rows.store[index],"store"),str(_rows.store[index].get("name",""))):pictures+=1
	var added: Dictionary=_add_lines("store",store_content,row_position,1)
	if added.get("ok",false):added=_add_lines("bag",bag_content,row_position+BAG_ROW_SHIFT,0)
	if not added.get("ok",false):
		next.free()
		last_result=added
		return added
	pictures+=int(added.get("pictures",0))
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	for side: String in ["bag","store"]:
		_input_below_content(next,out,(P_BAG if side=="bag" else P_STORE)+"ScrollView")
		var content: Variant=bag_content if side=="bag" else store_content
		(_scrollers[side] as Scroller).bind(content,row_position.y,_lines(side))
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"bag_rows":_rows.bag.size(),"store_rows":_rows.store.size(),"pictures":pictures,"bag_tab":_tabs.bag,"store_tab":_tabs.store}
	return last_result

func _lines(side: String) -> int:
	return maxi(1,ceili(float((_rows[side] as Array).size())/float(SET_SLOTS.size())))

## Adds Inventory_Slot_Set lines `from`.. of one side under its list content.
func _add_lines(side: String, content: Node2D, first_position: Vector2, from: int) -> Dictionary:
	var pictures: int=0
	var listing: Array=_rows[side]
	for line: int in range(from,_lines(side)):
		var row_out: Dictionary={}
		var spec: Dictionary=_row_spec(side,line,"Nd_Slot/")
		for name: String in ["Nd_Slot/Fx_Slot_UnLock","Nd_Slot_Extension","Nd_Slot_Extension_Lock"]:spec[name]={"exclude":true}
		var built: Dictionary=_tree.scene_of(SET,spec,row_out)
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		scene.position=first_position+Vector2(0.0,ROW_PITCH*float(line))
		content.add_child(scene)
		for index: int in range(SET_SLOTS.size()):
			_forward(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn",_scrollers[side])
			var at: int=line*SET_SLOTS.size()+index
			if at<listing.size() and _picture(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",_record(listing[at],side),str(listing[at].get("name",""))):pictures+=1
	return {"ok":true,"pictures":pictures}

## Spec of one Inventory_Slot_Set line (four slots from `line`*4).
func _row_spec(side: String, line: int, prefix: String) -> Dictionary:
	var spec: Dictionary={}
	var listing: Array=_rows[side]
	for index: int in range(SET_SLOTS.size()):
		var key: String=prefix+SET_SLOTS[index]+"/"
		var at: int=line*SET_SLOTS.size()+index
		var row: Dictionary=listing[at] if at<listing.size() else {}
		spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec[key+"Sp_Select"]={"visible":false}
		var text: String=amount_text(row) if not row.is_empty() else ""
		spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
		spec[key+"Btn"]={"activate":Callable(self,"_slot_pressed").bind(side,at)}
	return spec

func _node(root: Node2D, out: Dictionary, suffix: String) -> Variant:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return null
	return located.player.source_nodes.get(located.offset)

## The ScrollView's moving content (SourceOriginalScrollContent).
static func _content(row: Variant) -> Variant:
	if not row is Node:return null
	var node: Node=(row as Node).get_parent()
	while node!=null and node.name!="SourceOriginalScrollContent":node=node.get_parent()
	return node

func _scroll_content(root: Node2D, out: Dictionary, suffix: String) -> Variant:
	var node: Variant=_node(root,out,suffix)
	return (node as Node).find_child("SourceOriginalScrollContent",true,false) if node is Node else null

## `row`'s position in `content`'s space.
static func _offset_in(row: Node2D, content: Node2D) -> Vector2:
	var offset: Vector2=row.position
	var node: Node=row.get_parent()
	while node!=null and node!=content:
		if node is Node2D:offset+=(node as Node2D).position
		node=node.get_parent()
	return offset

## The ScrollView's drag area is created above its content; under the content
## the slot buttons receive their taps (drags over them are forwarded back).
static func _input_below_content(root: Node2D, out: Dictionary, suffix: String) -> void:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var scroll: Variant=node.get_meta("source_scroll") if is_instance_valid(node) and node.has_meta("source_scroll") else null
	var area: Variant=scroll.input_control() if is_instance_valid(scroll) else null
	if area is Control and area.get_parent()==scroll:scroll.move_child(area,0)

func _forward(root: Node2D, out: Dictionary, suffix: String, scroller: Scroller) -> void:
	var node: Variant=_node(root,out,suffix)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if area is Control and not area.gui_input.is_connected(scroller.input):area.gui_input.connect(scroller.input)

## The item picture the existing image owner resolves; none -> the slot stays empty.
func _picture(root: Node2D, out: Dictionary, suffix: String, record: Dictionary, title: String) -> bool:
	if record.is_empty():return false
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item(record,title)
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## --- Actions -----------------------------------------------------------------

## 소지품 item -> 보관, 창고 item -> 찾기 (the warehouse screen's confirmation).
func _slot_pressed(side: String, index: int) -> Dictionary:
	if (_scrollers[side] as Scroller).moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var listing: Array=_rows.get(side,[])
	if index<0 or index>=listing.size():return {"ok":true,"empty_slot":true}
	var screen: Object=_screen.get_ref() if _screen!=null else null
	if screen==null:return _fail("source_storage_window_host_unavailable")
	var reference: String=reference_of(listing[index])
	screen.call("request_drop" if side=="bag" else "request_withdraw",reference)
	return {"ok":true,"requested":"deposit" if side=="bag" else "withdraw","reference":reference}

func _set_tab(side: String, tab_name: String) -> Dictionary:
	_tabs[side]=tab_name
	(_scrollers[side] as Scroller).y=null
	(_scrollers[("store" if side=="bag" else "bag")] as Scroller).keep()
	return _stage()

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
