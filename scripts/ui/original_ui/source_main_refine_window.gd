extends RefCounted
## The original 523 질서의 연금 window: RefineScene with Refine_All (frame,
## title, close, +100/+1000/Min/Max/직접입력, 연금 시작 with its Adena cost,
## system message, "연금술 재료가 없습니다."), Refine_Item (대상 아이템 /
## 기본재료 / 특수재료 slots, 최소·최대 수량, 성공 확률) and Refine_Inventory
## (연금 재료: one original Inventory_Slot_Set row of four Common_Slots per
## line). Every rule, roll, cost and save stays in
## scripts/refine523/bless_refine523_service.gd; this file mounts original
## nodes and routes their buttons.
## Left as authored or empty (no rule in the tables, see
## docs/bless_refine523_missing_rules.md): +100/+1000/직접입력 (amounts between
## the Min and Max endpoints have no probability formula) are shown disabled;
## the 특수재료 slot stays locked; the magic ball effect (frame events) is not mounted; 연금 결과물 목록 (Refine_Popup_Result),
## the help box, the Refine_Roulette result animation, the recipe caption and
## the bag tabs stay inert.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const SERVICE=preload("res://scripts/refine523/bless_refine523_service.gd")
const RULES=preload("res://scripts/refine523/bless_refine523_rules.gd")
const EnchantWindow=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
const ROOT="UI/RefineScene.csb"
const ALL="UI/Refine/Refine_All.csb"
const ITEM="UI/Refine/Refine_Item.csb"
const INVENTORY="UI/Refine/Refine_Inventory.csb"
const REFINE_SLOT="UI/Refine/Refine_Slot.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## Common_Slot keeps its button, frame, item picture, selection and amount.
const SLOT_BUTTON=15728
const SLOT_BACKGROUND=15316
const SLOT_ICON=15012
const SLOT_SELECT=9004
const SLOT_AMOUNT=6880
const MEMBER_SCOPES={SLOT:[SLOT_BUTTON,SLOT_BACKGROUND,SLOT_ICON,SLOT_SELECT,SLOT_AMOUNT]}
const REQUIRED: Array[String]=[ROOT,ALL,ITEM,INVENTORY,REFINE_SLOT,SET,SLOT]
const P_ALL="Refine_All_Layout/"
const P_ITEM="Refine_All_Layout/Refine_Item/Nd_Slot/"
const P_INV="Refine_All_Layout/Refine_Inventory/Nd_Inventory/"
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
## Vertical pitch between slot rows: the authored horizontal slot pitch of
## Inventory_Slot_Set (-117, -41, 35, 111), as the main inventory uses.
const ROW_PITCH: float=76.0
const ROW_TAIL: float=40.0
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _selected: String=""
var _mode: String="min"
var _notice: String=""
var _scroll_content: Node2D
var _scroll_top: float=0.0
var _scroll_bottom: float=0.0
var _scroll_y: Variant=null
var _drag: bool=false
var _moved: float=0.0
var _last_out: Dictionary={}
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_refine_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_refine_window_host_unavailable")
	if not RULES.installed():return _fail("source_refine_window_definitions_not_installed")
	_parent=weakref(parent)
	_world=weakref(world)
	_selected=""
	_mode="min"
	_notice=""
	_scroll_y=null
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_scroll_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func selected() -> String:
	return _selected

func mode() -> String:
	return _mode

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

## Bag entries of the 연금 재료 panel: every 질서의 연금 target the service
## lists (with its ItemClass for the picture), then the owned 상급 축복의 가루.
func _materials(world: Node, snapshot: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for row: Dictionary in snapshot.get("refine",[]):
		var info: Dictionary=SERVICE.equipment(world,str(row.uid))
		if not info.get("ok",false):continue
		var entry: Dictionary=row.duplicate(true)
		entry["kind"]="target"
		entry["item_class_id"]=int(info.item_class_id)
		entry["name"]=str(info.name)
		entry["enchant"]=int(info.enchant)
		rows.append(entry)
	if int(snapshot.get("powder",0))>0:
		rows.append({"kind":"powder","uid":"","item_class_id":RULES.ADVANCED_BLESS_POWDER_ITEM,"name":_item_name(RULES.ADVANCED_BLESS_POWDER_ITEM),"amount":int(snapshot.powder)})
	return rows

static func _item_name(item_class_id: int) -> String:
	var row: Dictionary=RULES.item_row(item_class_id)
	var info: Dictionary=SERVICE.D.definition_id(str(item_class_id)).get("native_record",{})
	return str(info.get("name",row.get("Name",""))).get_slice(" · 원본#",0)

func _target(materials: Array[Dictionary]) -> Dictionary:
	for entry: Dictionary in materials:
		if entry.kind=="target" and str(entry.uid)==_selected:return entry
	return {}

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var world: Node=_world.get_ref() if _world!=null else null
	if parent==null or world==null:return _fail("source_refine_window_host_unavailable")
	var snapshot: Dictionary=SERVICE.snapshot(world)
	var materials: Array[Dictionary]=_materials(world,snapshot)
	var target: Dictionary=_target(materials)
	if target.is_empty():_selected=""
	var quote: Dictionary=SERVICE.refine_quote(world,_selected,_mode) if not target.is_empty() else {}
	var spec: Dictionary=_spec(snapshot,materials,target,quote)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var pictures: int=0
	if not target.is_empty():
		if _slot_picture(next,out,P_ITEM+"Nd_Slot_Target/Refine_Slot/Nd_Slot/Common_Slot/Sp_IconSample",int(target.item_class_id),str(target.name)):pictures+=1
		if _slot_picture(next,out,P_ITEM+"Nd_Slot/Refine_Slot/Nd_Slot/Common_Slot/Sp_IconSample",RULES.ADVANCED_BLESS_POWDER_ITEM,""):pictures+=1
	var filled: Dictionary=_fill_inventory(next,out,materials)
	if not filled.get("ok",false):
		next.free()
		last_result=filled
		return filled
	pictures+=int(filled.pictures)
	var previous: Node2D=_scene
	# RefineScene is laid out on the 1200x675 design frame.
	next.position=Vector2(0.0,0.0)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	_bind_scroll(next,out,int(filled.lines))
	# Slot buttons above the ScrollView's drag area keep their taps.
	EnchantWindow._input_below_content(next,out,P_INV+"ScrollView")
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"materials":materials.size(),"targets":materials.filter(func(e: Dictionary) -> bool: return e.kind=="target").size(),
		"selected":_selected,"mode":_mode,"quote_ok":quote.get("ok",false),"quote_reason":str(quote.get("reason","")),"pictures":pictures,"notice":_notice,"powder":int(snapshot.get("powder",0)),"gold":int(snapshot.get("gold",0))}
	return last_result

func _spec(snapshot: Dictionary, materials: Array[Dictionary], target: Dictionary, quote: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	# Particle/animation layers with no data role here stay out of the scene.
	spec[P_ALL+"Refine_Roulette"]={"exclude":true}
	# Fx_Refine_MagicBall drives frame events (sound): not mounted.
	spec[P_ALL+"Fx_Refine_MagicBall"]={"exclude":true}
	spec[P_ALL+"Refine_Item/Fx_Glow"]={"exclude":true}
	spec[P_ITEM+"Nd_Fx"]={"exclude":true}
	for slot: String in ["Nd_Slot/Refine_Slot","Nd_Slot_Target/Refine_Slot","Nd_Slot_Special/Refine_Slot"]:
		for fx: String in ["Fx_Root","Nd_Slot/Fx_Light","Nd_Slot/Fx_Inventory_Slot","Nd_Slot/Sp_Frame_Light_01","Nd_Slot/Sp_Frame_Light_02"]:
			spec[P_ITEM+slot+"/"+fx]={"exclude":true}
	for fx: String in ["Fx_Popup_RightBottom","Fx_Popup_LeftUp","ToolTip"]:spec[P_INV+fx]={"exclude":true}
	spec[P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot/Fx_Slot_UnLock"]={"exclude":true}
	spec[P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot_Extension"]={"exclude":true}
	spec[P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot_Extension_Lock"]={"exclude":true}
	spec[P_ALL+"Btn_Alchemy/Normal/Fx_Active"]={"exclude":true}
	# Frame.
	spec[P_ALL+"Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	# Min / Max are the two registered amounts the tables give; the other
	# amount buttons have no probability rule and show their disabled state.
	spec[P_ALL+"Nd_ButtonSet/Btn_Min"]={"activate":Callable(self,"_set_mode").bind("min"),"displaystate":not target.is_empty()}
	spec[P_ALL+"Nd_ButtonSet/Btn_Max"]={"activate":Callable(self,"_set_mode").bind("max"),"displaystate":not target.is_empty()}
	for name: String in ["Btn_100","Btn_1000","Btn_Input"]:
		spec[P_ALL+"Nd_ButtonSet/"+name]={"activate":Callable(self,"_amount_unavailable"),"displaystate":false}
	var can: bool=quote.get("ok",false)
	spec[P_ALL+"Btn_Alchemy"]={"activate":Callable(self,"_refine_requested"),"displaystate":can}
	spec[P_ALL+"Btn_Alchemy/Normal"]={"visible":can}
	spec[P_ALL+"Btn_Alchemy/Disabled"]={"visible":not can}
	var cost: int=int(quote.get("cost",0)) if not target.is_empty() else 0
	spec[P_ALL+"Btn_Alchemy/Normal/Label_Amount"]={"role":"source_text","text":_number(cost)}
	var notice: String=_notice
	if notice.is_empty() and not target.is_empty() and not can:notice=str(quote.get("reason",""))
	if notice.is_empty() and snapshot.get("refine_contents_enabled")==false:notice="원본 523에서는 질서의 연금이 꺼져 있습니다 (ContentsControl Refine)"
	spec[P_ALL+"Label_Notice"]={"role":"source_text","text":notice,"visible":not notice.is_empty()}
	var targets: int=materials.filter(func(e: Dictionary) -> bool: return e.kind=="target").size()
	spec[P_ALL+"Nd_NoItem"]={"visible":targets==0}
	# Refine_Item: target, basic material (상급 축복의 가루), special (held).
	var has: bool=not target.is_empty()
	var min_amount: int=int(target.get("min",0))
	var max_amount: int=int(target.get("max",0))
	var amount: int=min_amount if _mode=="min" else max_amount
	var percent: String=str(target.get("min_percent" if _mode=="min" else "max_percent",""))
	spec[P_ITEM+"Nd_Probability"]={"visible":has}
	spec[P_ITEM+"Nd_Probability/Label"]={"role":"source_text","text":"성공 확률 %s" % percent}
	for slot: String in ["Nd_Slot","Nd_Slot_Target","Nd_Slot_Special"]:
		var key: String=P_ITEM+slot+"/Refine_Slot/Nd_Slot/"
		spec[key+"Nd_Lock"]={"visible":slot=="Nd_Slot_Special"}
		spec[key+"Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec[key+"Common_Slot/Sp_Select"]={"visible":false}
		spec[key+"Common_Slot/Text_Amount"]={"role":"source_text","text":str(amount) if slot=="Nd_Slot" else "","visible":slot=="Nd_Slot" and has}
	spec[P_ITEM+"Nd_Slot_Target/Refine_Slot/Nd_Slot/Common_Slot/Btn"]={"activate":Callable(self,"_clear_target")}
	spec[P_ITEM+"Nd_Slot/Nd_TextSet"]={"visible":has}
	spec[P_ITEM+"Nd_Slot/Nd_TextSet/Label_Min"]={"role":"source_text","text":"최소:%d" % min_amount}
	spec[P_ITEM+"Nd_Slot/Nd_TextSet/Label_Max"]={"role":"source_text","text":"최대:%d" % max_amount}
	spec[P_ITEM+"Nd_Slot_Special/Nd_TextSet"]={"visible":false}
	# The recipe caption has no table text: its authored placeholder stays hidden.
	spec[P_ALL+"Refine_Item/Nd_Recipe"]={"visible":false}
	# Refine_Inventory: the authored first row; further rows are added in _fill_inventory.
	spec[P_INV+"ScrollView"]={"role":"source_scroll","input":Callable(self,"_scroll_input")}
	spec[P_INV+"Nd_Number"]={"visible":false}
	var tabs: Dictionary={"Btn_All":true,"Btn_Equipment":false,"Btn_Consume":false,"Btn_Etc":false}
	for tab: String in tabs:
		spec[P_INV+"Tab/"+tab+"_On"]={"visible":tabs[tab]}
		spec[P_INV+"Tab/"+tab+"_Off"]={"visible":not tabs[tab]}
	var first: Dictionary=_row_spec(materials,0,P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot/")
	spec.merge(first,true)
	return spec

## Spec of one Inventory_Slot_Set line (four slots from `line`*4).
func _row_spec(materials: Array[Dictionary], line: int, prefix: String) -> Dictionary:
	var spec: Dictionary={}
	for index: int in range(SET_SLOTS.size()):
		var key: String=prefix+SET_SLOTS[index]+"/"
		var at: int=line*SET_SLOTS.size()+index
		var entry: Dictionary=materials[at] if at<materials.size() else {}
		spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec[key+"Sp_Select"]={"visible":not entry.is_empty() and entry.kind=="target" and str(entry.uid)==_selected}
		var text: String=""
		if not entry.is_empty():text=str(entry.amount) if entry.kind=="powder" else ("+%d" % int(entry.enchant) if int(entry.enchant)>0 else "")
		spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
		spec[key+"Btn"]={"activate":Callable(self,"_slot_pressed").bind(at)}
	return spec

func _fill_inventory(root: Node2D, out: Dictionary, materials: Array[Dictionary]) -> Dictionary:
	var pictures: int=0
	var lines: int=maxi(1,ceili(float(materials.size())/float(SET_SLOTS.size())))
	for index: int in range(SET_SLOTS.size()):
		_forward_scroll(root,out,P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot/"+SET_SLOTS[index]+"/Btn")
		if index>=materials.size():continue
		if _slot_picture(root,out,P_INV+"ScrollView/Inventory_Slot_Set/Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",int(materials[index].item_class_id),str(materials[index].name)):pictures+=1
	if lines==1:return {"ok":true,"pictures":pictures,"lines":1}
	var authored: Dictionary=NamedTree.locate(root,out,P_INV+"ScrollView/Inventory_Slot_Set")
	if not authored.get("ok",false):return authored
	var row: Variant=authored.player.source_nodes.get(authored.offset)
	if not row is Node2D or row.get_parent()==null:return _fail("source_refine_window_slot_row_missing")
	for line: int in range(1,lines):
		var row_out: Dictionary={}
		var spec: Dictionary=_row_spec(materials,line,"Nd_Slot/")
		spec["Nd_Slot/Fx_Slot_UnLock"]={"exclude":true}
		spec["Nd_Slot_Extension"]={"exclude":true}
		spec["Nd_Slot_Extension_Lock"]={"exclude":true}
		var built: Dictionary=_tree.scene_of(SET,spec,row_out)
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		scene.position=row.position+Vector2(0.0,ROW_PITCH*float(line))
		row.get_parent().add_child(scene)
		for index: int in range(SET_SLOTS.size()):
			_forward_scroll(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn")
			var at: int=line*SET_SLOTS.size()+index
			if at>=materials.size():continue
			if _slot_picture(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",int(materials[at].item_class_id),str(materials[at].name)):pictures+=1
	return {"ok":true,"pictures":pictures,"lines":lines}

## Dragging over a slot scrolls the list (the slot button keeps its tap).
func _forward_scroll(root: Node2D, out: Dictionary, suffix: String) -> void:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if area is Control and not area.gui_input.is_connected(_scroll_input):area.gui_input.connect(_scroll_input)

func _slot_picture(root: Node2D, out: Dictionary, suffix: String, item_class_id: int, title: String) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item_class(item_class_id,title)
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## Rows below the authored one extend the original scroll content; the
## content moves from its authored top down to the last row.
func _bind_scroll(root: Node2D, out: Dictionary, lines: int) -> void:
	_scroll_content=null
	var authored: Dictionary=NamedTree.locate(root,out,P_INV+"ScrollView/Inventory_Slot_Set")
	if not authored.get("ok",false):return
	var row: Variant=authored.player.source_nodes.get(authored.offset)
	if not row is Node2D:return
	var content: Node=row.get_parent()
	var row_offset: float=row.position.y
	while content!=null and content.name!="SourceOriginalScrollContent":
		if content is Node2D:row_offset+=(content as Node2D).position.y
		content=content.get_parent()
	if not content is Node2D:return
	_scroll_content=content
	_scroll_top=content.position.y
	var last_row_bottom: float=row_offset+ROW_PITCH*float(lines-1)+ROW_TAIL
	_scroll_bottom=minf(_scroll_top,-last_row_bottom)
	if _scroll_y!=null:_scroll_content.position.y=clampf(float(_scroll_y),_scroll_bottom,_scroll_top)

func _scroll_input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=ROW_PITCH*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_scroll_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=absf(delta)
	_scroll_content.position.y=clampf(_scroll_content.position.y+delta,_scroll_bottom,_scroll_top)
	_scroll_y=_scroll_content.position.y

## --- Actions -----------------------------------------------------------------

func _slot_pressed(index: int) -> Dictionary:
	if _moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_refine_window_host_unavailable")
	var materials: Array[Dictionary]=_materials(world,SERVICE.snapshot(world))
	if index<0 or index>=materials.size():return {"ok":true,"empty_slot":true}
	var entry: Dictionary=materials[index]
	if entry.kind!="target":
		_notice="대상 아이템을 먼저 선택하세요"
		return _restage()
	_selected="" if str(entry.uid)==_selected else str(entry.uid)
	_notice=""
	return _restage()

func select_target(uid: String) -> Dictionary:
	_selected=uid
	_notice=""
	return _restage()

func _clear_target() -> Dictionary:
	_selected=""
	_notice=""
	return _restage()

func _set_mode(value: String) -> Dictionary:
	_mode=value
	_notice=""
	return _restage()

func _amount_unavailable() -> Dictionary:
	_notice="최소·최대 사이 수량의 확률은 원본 표에 없어 최소·최대만 등록합니다"
	return _restage()

func _refine_requested() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if world==null or _selected.is_empty():return _fail("source_refine_window_target_unselected")
	var result: Dictionary=SERVICE.refine(world,_selected,_mode)
	if result.get("ok",false):
		_notice=str(result.get("detail",""))
		if hud!=null and hud.has_method("append_log"):hud.call("append_log",_notice)
		if not bool(result.get("success",false)):pass
		elif world.get("item_instances") is Dictionary and not world.item_instances.has(_selected):_selected=""
	else:_notice=str(result.get("reason","질서의 연금 실패"))
	# Label_Notice is shown by the client's Notice_On clip; the HUD message
	# line carries the same result meanwhile.
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",_notice)
	var staged: Dictionary=_restage()
	staged["refine"]=result
	return staged

func _restage() -> Dictionary:
	if is_instance_valid(_scroll_content):_scroll_y=_scroll_content.position.y
	return _stage()

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
