extends RefCounted
## The original 523 장비 강화 window: EnchantScene with Enchant_All (단일 강화
## page: "+N 이름을 강화 하시겠습니까?", 주문서 + 대상 slots, 안전 / 비안전 구간,
## stat rows (Enchant_Text_Set), 수수료 / 주문서 수, 강화 확률, 강 화 시 작)
## and Enchant_Inventory (장비 / 주문서 tabs over Inventory_Slot_Set rows,
## 보유 아데나, close). Candidates, chances, costs, the confirmation and the
## roll stay with the existing owners: world._enhancement_candidates supplies
## the rows, renewal_forge.confirm_target asks and emits
## hud.enhancement_requested, the world rolls and reopens this window.
## Left inert or empty (no rule for them in this project): 다중 강화 tab (its
## Off state is shown; tapping says so), the other Enchant_All pages
## (축복 부여 / 제련 / 속성 / 은총 / 스킬 / 용해 / 삭제), 자동 강화, 실패 기록,
## the grade filters, 상세보기 / 일괄 선택, the result popup, tooltips and
## every effect layer.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Forge=preload("res://scripts/ui/renewal_forge.gd")
const ENCHANT=preload("res://scripts/original_enhancement.gd")
const ROOT="UI/EnchantScene.csb"
const ALL="UI/FloatingUi/Enchant_All.csb"
const INVENTORY="UI/FloatingUi/Enchant_Inventory.csb"
const TEXT_SET="UI/FloatingUi/Enchant_Text_Set.csb"
const TITLE="UI/CommonUi/Inven_Icon_TitleLayout.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## Common_Slot keeps its button, frame, item picture, selection and amount.
const MEMBER_SCOPES={SLOT:[15728,15316,15012,9004,6880]}
const REQUIRED: Array[String]=[ROOT,ALL,INVENTORY,TEXT_SET,TITLE,SET,SLOT]
const P_ALL="Enchant_All_Layout/"
const P_COMMON="Enchant_All_Layout/Nd_Common/"
const P_ENCHANT="Enchant_All_Layout/Nd_Enchant/"
const P_INV="Enchant_Inventory_Layout/Nd_Inven/Nd_InvenMode/"
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
## Inventory_Slot_Set's authored horizontal slot pitch (-117, -41, 35, 111)
## as the line pitch, as the main inventory and the refine window use.
const ROW_PITCH: float=76.0
const ROW_TAIL: float=40.0
## Enchant_Text_Set authors one 40 px line; further stat lines follow it.
const TEXT_PITCH: float=30.0
const TEXT_TAIL: float=20.0
## Enchant_All pages with no rule here, kept out of the scene.
const OTHER_PAGES: Array[String]=["Nd_Enchant_Bless","Nd_Enchant_Smelt","Nd_Enchant_Multi","Nd_Enchant_Grace","Nd_ChangeProperty","Nd_Enchant_Properties_Smelt","Nd_Enchant_Skill","Nd_Dissolve","Nd_Delete",
	"Nd_Btn_Auto","Nd_Enchant_Btn/Nd_Auto_Enchant","Fx_Enchant_Start","Enchant_Popup_Message","Enchant_ToolTip_Bless","Enchant_ToolTip_Skill","Enchant_ToolTip_Smelt","Enchant_ToolTip_Grace","Enchant_ToolTip_Properties_Smelt","Btn_FailHistory"]
const OTHER_TABS: Array[String]=["Nd_Properties","Nd_Bless","Nd_Magic","Nd_Smelt","Nd_Grace","Nd_Properties_Smelt","Nd_Label"]
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _scroll: String=""
var _candidates: Array=[]
var _selected: String=""
var _tab: String="equip"
var _bag: Scroller=Scroller.new()
var _text: Scroller=Scroller.new()
var _last_out: Dictionary={}
var last_result: Dictionary={}

## Drag scrolling of one original ScrollView whose authored first line is
## extended by added lines (the refine window's rule).
class Scroller extends RefCounted:
	var content: Node2D
	var top: float=0.0
	var bottom: float=0.0
	var y: Variant=null
	var drag: bool=false
	var moved: float=0.0
	var pitch: float=76.0

	func bind(row: Variant, lines: int, line_pitch: float, tail: float) -> void:
		content=null
		pitch=line_pitch
		if not row is Node2D:return
		var node: Node=(row as Node2D).get_parent()
		var row_offset: float=(row as Node2D).position.y
		while node!=null and node.name!="SourceOriginalScrollContent":
			if node is Node2D:row_offset+=(node as Node2D).position.y
			node=node.get_parent()
		if not node is Node2D:return
		content=node
		top=content.position.y
		bottom=minf(top,-(row_offset+line_pitch*float(lines-1)+tail))
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
			delta=pitch*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
		if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
		moved+=absf(delta)
		content.position.y=clampf(content.position.y+delta,bottom,top)
		y=content.position.y

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_enchant_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## Opens on `scroll`'s targets (장비 tab), or on the 주문서 tab without one.
func open(parent: Node, scroll: String, candidates: Array) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_enchant_window_host_unavailable")
	_parent=weakref(parent)
	_bag.y=null
	_text.y=null
	_selected=""
	return update(scroll,candidates)

## New candidates after an attempt (or another scroll): keeps the selected
## physical item when it is still listed.
func update(scroll: String, candidates: Array) -> Dictionary:
	if scroll!=_scroll:_bag.y=null
	_scroll=scroll
	_candidates=candidates.duplicate(true)
	_tab="equip" if not scroll.is_empty() else "scroll"
	if _entry().is_empty():_selected=str(_candidates[0].get("target_id","")) if not _candidates.is_empty() else ""
	return _restage()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_bag.content=null
	_text.content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func scroll_name() -> String:
	return _scroll

func selected() -> String:
	return _selected

func tab() -> String:
	return _tab

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

func _entry() -> Dictionary:
	for entry: Variant in _candidates:
		if entry is Dictionary and str(entry.get("target_id",""))==_selected and not _selected.is_empty():return entry
	return {}

func _listing(hud: Node) -> Array:
	return _candidates if _tab=="equip" else Forge.owned_scrolls(hud)

## Stat lines: every stat the item has now or after success, with the
## current and the success value.
func _stat_rows(entry: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var now: Dictionary=entry.get("stats_now",{}) if entry.get("stats_now") is Dictionary else {}
	var next: Dictionary=entry.get("stats_next",{}) if entry.get("stats_next") is Dictionary else {}
	var keys: Array=now.keys()
	for key: Variant in next.keys():
		if not keys.has(key):keys.append(key)
	for key: Variant in keys:
		var a: float=float(now.get(key,0.0))
		var b: float=float(next.get(key,0.0))
		if is_zero_approx(a) and is_zero_approx(b):continue
		var label: String=ENCHANT.stat_label(str(key))
		var sign: float=1.0
		if str(key)=="defense":
			label="AC"
			sign=-1.0
		rows.append({"label":label,"now":_value(a*sign),"next":"%s(%s)" % [_value(b*sign),_delta((b-a)*sign)]})
	return rows

static func _value(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value,round(value)) else "%.2f" % value

static func _delta(value: float) -> String:
	return ("+" if value>=0.0 else "")+_value(value)

## "+11 마법 지팡이를 강화 하시겠습니까?" with the particle of the last syllable.
static func _title(entry: Dictionary) -> String:
	var name: String=str(entry.get("name","")).get_slice(" · 원본#",0)
	var particle: String="를"
	if not name.is_empty():
		var code: int=name.unicode_at(name.length()-1)
		if code>=0xAC00 and code<=0xD7A3 and (code-0xAC00)%28!=0:particle="을"
	var level: int=int(entry.get("level",0))
	return "%s%s%s 강화 하시겠습니까?" % ["+%d " % level if level>0 else "",name,particle]

## --- Stage ------------------------------------------------------------------

func _restage() -> Dictionary:
	_bag.keep()
	_text.keep()
	return _stage()

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_enchant_window_host_unavailable")
	var entry: Dictionary=_entry()
	var listing: Array=_listing(hud)
	var rows: Array[Dictionary]=_stat_rows(entry)
	var spec: Dictionary=_spec(hud,entry,listing,rows)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var pictures: int=0
	if not _scroll.is_empty() and _picture(next,out,P_COMMON+"Nd_Slot/Inventory_Slot0/Sp_IconSample",_scroll_record(hud,_scroll),_scroll):pictures+=1
	if not entry.is_empty() and _picture(next,out,P_COMMON+"Nd_Slot/Inventory_Slot1/Sp_IconSample",Forge.image_record_of(hud,entry),str(entry.get("name",""))):pictures+=1
	var filled: Dictionary=_fill_bag(hud,next,out,listing)
	var texts: Dictionary=_fill_text(next,out,rows) if filled.get("ok",false) else filled
	if not texts.get("ok",false):
		next.free()
		last_result=texts
		return texts
	pictures+=int(filled.get("pictures",0))
	var previous: Node2D=_scene
	# EnchantScene is laid out on the 1200x675 design frame.
	next.position=Vector2.ZERO
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	_input_below_content(next,out,P_INV+"ScrollView_Item")
	_input_below_content(next,out,P_ENCHANT+"Nd_TextSet/ScrollView")
	_bag.bind(_row(next,out,P_INV+"ScrollView_Item/Inventory_Slot_Set"),maxi(1,ceili(float(listing.size())/float(SET_SLOTS.size()))),ROW_PITCH,ROW_TAIL)
	_text.bind(_row(next,out,P_ENCHANT+"Nd_TextSet/ScrollView/TextSet"),maxi(1,rows.size()),TEXT_PITCH,TEXT_TAIL)
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"scroll":_scroll,"tab":_tab,"candidates":_candidates.size(),"listed":listing.size(),"selected":_selected,
		"stat_rows":rows.size(),"pictures":pictures,"bag_pictures":int(filled.get("bag_pictures",0)),"can_enchant":not entry.is_empty()}
	return last_result

func _spec(hud: Node, entry: Dictionary, listing: Array, rows: Array[Dictionary]) -> Dictionary:
	var spec: Dictionary={}
	for page: String in OTHER_PAGES:spec[P_ALL+page]={"exclude":true}
	for tab_name: String in OTHER_TABS:spec[P_COMMON+"Tab/"+tab_name]={"exclude":true}
	for fx: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom","Fx_Enchant_Safety","Fx_Item_Active_Right"]:spec[fx]={"exclude":true}
	var has: bool=not entry.is_empty()
	var level: int=int(entry.get("level",0))
	var safe: bool=has and level<int(entry.get("safe_level",0))
	var cursed: bool=_scroll.contains("저주")
	# Frame: 저주 주문서 → Curse; past the safe level → Unsafety; else Bless.
	spec[P_COMMON+"Enchant_Base_Curse"]={"visible":cursed}
	spec[P_COMMON+"Enchant_Base_Unsafety"]={"visible":not cursed and has and not safe}
	spec[P_COMMON+"Enchant_Base_Bless"]={"visible":not cursed and not (has and not safe)}
	# 단일 강화 is the page shown; 다중 강화 keeps its Off state.
	spec[P_COMMON+"Tab/Nd_Single"]={"visible":true}
	spec[P_COMMON+"Tab/Nd_Multi"]={"visible":true}
	spec[P_COMMON+"Tab/Nd_Single/Btn_Single_On"]={"visible":true}
	spec[P_COMMON+"Tab/Nd_Single/Btn_Single_Off"]={"visible":false}
	spec[P_COMMON+"Tab/Nd_Multi/Btn_Multi_On"]={"visible":false}
	spec[P_COMMON+"Tab/Nd_Multi/Btn_Multi_Off"]={"activate":Callable(self,"_notice").bind("다중 강화는 원본 규칙이 없어 단일 강화만 진행합니다")}
	spec[P_COMMON+"Label_Title"]={"role":"source_text","text":_title(entry) if has else ("강화할 장비를 선택하세요" if not _scroll.is_empty() else "강화 주문서를 선택하세요")}
	# Slot0: the scroll; Slot1: the target (TWILIGHT forge order 주문서 + 대상).
	var owned: int=int(hud.lineage_inventory_ui.inventory.get(_scroll,0)) if not _scroll.is_empty() else 0
	for slot: String in ["Inventory_Slot0","Inventory_Slot1"]:
		var key: String=P_COMMON+"Nd_Slot/"+slot+"/"
		spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec[key+"Sp_Select"]={"visible":false}
		var amount: String=(str(owned) if owned>0 else "") if slot=="Inventory_Slot0" else ("+%d" % level if has and level>0 else "")
		spec[key+"Text_Amount"]={"role":"source_text","text":amount,"visible":not amount.is_empty()}
	spec[P_COMMON+"Nd_Slot/Inventory_Slot0/Btn"]={"activate":Callable(self,"_set_tab").bind("scroll")}
	spec[P_COMMON+"Nd_Slot/Inventory_Slot1/Btn"]={"activate":Callable(self,"_set_tab").bind("equip")}
	# Nd_Enchant: zone, stats, cost, probability.
	spec[P_ENCHANT+"Label_Safe"]={"visible":has and safe}
	spec[P_ENCHANT+"Label_Unsafe"]={"visible":has and not safe}
	spec[P_ENCHANT+"Nd_TextSet"]={"visible":has and not rows.is_empty()}
	spec[P_ENCHANT+"Nd_TextSet/ScrollView"]={"role":"source_scroll","input":Callable(_text,"input")}
	spec.merge(_text_spec(rows,0,P_ENCHANT+"Nd_TextSet/ScrollView/TextSet/"),true)
	var count: int=int(entry.get("count",1))
	var cost: int=int(entry.get("cost",0))
	spec[P_ENCHANT+"Nd_Money"]={"visible":has and count<=1}
	spec[P_ENCHANT+"Nd_Money/Sp_Icon_Bless"]={"visible":false}
	spec[P_ENCHANT+"Nd_Money/Text_Price"]={"role":"source_text","text":_number(cost)}
	spec[P_ENCHANT+"Nd_Blessed_Cost"]={"visible":has and count>1}
	spec[P_ENCHANT+"Nd_Blessed_Cost/Text_Price"]={"role":"source_text","text":_number(cost)}
	spec[P_ENCHANT+"Nd_Blessed_Cost/Text_Scroll_Amount"]={"role":"source_text","text":_number(count)}
	spec[P_ENCHANT+"Btn_Probability"]={"visible":has,"activate":Callable(self,"_probability")}
	spec[P_ENCHANT+"Btn_Probability_Bless"]={"visible":false}
	spec[P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant"]={"activate":Callable(self,"_enchant_requested"),"displaystate":has}
	spec[P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant/Normal"]={"visible":has}
	spec[P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant/Disabled"]={"visible":not has}
	# Enchant_Inventory: 장비 / 주문서 tabs, owned list, Adena, close.
	spec["Enchant_Inventory_Layout/Nd_Inven/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Nd_Tab/Nd_Dissolve","Nd_Tab/Nd_Delete","Nd_Number","Nd_Grade","Menu_Button"]:spec[P_INV+name]={"exclude":true}
	spec["Enchant_Inventory_Layout/Nd_Inven/Nd_SelectMode"]={"exclude":true}
	var equip: bool=_tab=="equip"
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_All_On"]={"visible":equip}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_All_Off"]={"visible":not equip,"activate":Callable(self,"_set_tab").bind("equip")}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_Equip_On"]={"visible":not equip}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_Equip_Off"]={"visible":equip,"activate":Callable(self,"_set_tab").bind("scroll")}
	spec[P_INV+"Nd_Adena/Text_Volume"]={"role":"source_text","text":_number(int(hud.character_state.get("gold",0)))}
	spec[P_INV+"ScrollView_Item"]={"role":"source_scroll","input":Callable(_bag,"input")}
	spec[P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/Fx_Slot_UnLock"]={"exclude":true}
	spec[P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot_Extension"]={"exclude":true}
	spec[P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot_Extension_Lock"]={"exclude":true}
	spec.merge(_row_spec(listing,0,P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/"),true)
	return spec

func _text_spec(rows: Array[Dictionary], index: int, prefix: String) -> Dictionary:
	var row: Dictionary=rows[index] if index<rows.size() else {}
	return {prefix+"Text_List_1":{"role":"source_text","text":str(row.get("label",""))},
		prefix+"Text_List_1_0":{"role":"source_text","text":str(row.get("now",""))},
		prefix+"Text_List_1_Value":{"role":"source_text","text":str(row.get("next",""))}}

## Spec of one Inventory_Slot_Set line (four slots from `line`*4).
func _row_spec(listing: Array, line: int, prefix: String) -> Dictionary:
	var spec: Dictionary={}
	for index: int in range(SET_SLOTS.size()):
		var key: String=prefix+SET_SLOTS[index]+"/"
		var at: int=line*SET_SLOTS.size()+index
		var entry: Dictionary=listing[at] if at<listing.size() else {}
		spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		var chosen: bool=not entry.is_empty() and (str(entry.get("target_id",""))==_selected if _tab=="equip" else str(entry.get("name",""))==_scroll)
		spec[key+"Sp_Select"]={"visible":chosen}
		var text: String=""
		if not entry.is_empty():
			if _tab=="equip":text="+%d" % int(entry.get("level",0)) if int(entry.get("level",0))>0 else ""
			else:text=_number(int(entry.get("count",0)))
		spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
		spec[key+"Btn"]={"activate":Callable(self,"_slot_pressed").bind(at)}
	return spec

func _fill_bag(hud: Node, root: Node2D, out: Dictionary, listing: Array) -> Dictionary:
	var pictures: int=0
	var lines: int=maxi(1,ceili(float(listing.size())/float(SET_SLOTS.size())))
	var prefix: String=P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/"
	for index: int in range(SET_SLOTS.size()):
		_forward(root,out,prefix+SET_SLOTS[index]+"/Btn",_bag)
		if index<listing.size() and _picture(root,out,prefix+SET_SLOTS[index]+"/Sp_IconSample",_listing_record(hud,listing[index]),str(listing[index].get("name",""))):pictures+=1
	if lines>1:
		var row: Variant=_row(root,out,P_INV+"ScrollView_Item/Inventory_Slot_Set")
		if not row is Node2D or row.get_parent()==null:return _fail("source_enchant_window_slot_row_missing")
		for line: int in range(1,lines):
			var row_out: Dictionary={}
			var spec: Dictionary=_row_spec(listing,line,"Nd_Slot/")
			spec["Nd_Slot/Fx_Slot_UnLock"]={"exclude":true}
			spec["Nd_Slot_Extension"]={"exclude":true}
			spec["Nd_Slot_Extension_Lock"]={"exclude":true}
			var built: Dictionary=_tree.scene_of(SET,spec,row_out)
			if not built.get("ok",false):return built
			var scene: Node2D=built.scene
			scene.position=row.position+Vector2(0.0,ROW_PITCH*float(line))
			row.get_parent().add_child(scene)
			for index: int in range(SET_SLOTS.size()):
				_forward(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn",_bag)
				var at: int=line*SET_SLOTS.size()+index
				if at<listing.size() and _picture(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",_listing_record(hud,listing[at]),str(listing[at].get("name",""))):pictures+=1
	return {"ok":true,"bag_pictures":pictures,"pictures":pictures}

func _fill_text(root: Node2D, out: Dictionary, rows: Array[Dictionary]) -> Dictionary:
	if rows.size()<=1:return {"ok":true}
	var row: Variant=_row(root,out,P_ENCHANT+"Nd_TextSet/ScrollView/TextSet")
	if not row is Node2D or row.get_parent()==null:return _fail("source_enchant_window_text_row_missing")
	for index: int in range(1,rows.size()):
		var built: Dictionary=_tree.scene_of(TEXT_SET,_text_spec(rows,index,""),{})
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		scene.position=row.position+Vector2(0.0,TEXT_PITCH*float(index))
		row.get_parent().add_child(scene)
	return {"ok":true}

func _row(root: Node2D, out: Dictionary, suffix: String) -> Variant:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return null
	return located.player.source_nodes.get(located.offset)

func _listing_record(hud: Node, entry: Dictionary) -> Dictionary:
	return Forge.image_record_of(hud,entry) if _tab=="equip" else _scroll_record(hud,str(entry.get("name","")))

static func _scroll_record(hud: Node, name: String) -> Dictionary:
	return hud.lineage_inventory_ui._find_item_record(name)

## The ScrollView's drag area is created above its content; under the
## content the slot buttons receive their taps (drags over them are forwarded
## back to the scroll by _forward).
static func _input_below_content(root: Node2D, out: Dictionary, suffix: String) -> void:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var scroll: Variant=node.get_meta("source_scroll") if is_instance_valid(node) and node.has_meta("source_scroll") else null
	var area: Variant=scroll.input_control() if is_instance_valid(scroll) else null
	if area is Control and area.get_parent()==scroll:scroll.move_child(area,0)

## Dragging over a slot scrolls the list (the slot button keeps its tap).
func _forward(root: Node2D, out: Dictionary, suffix: String, scroller: Scroller) -> void:
	var node: Variant=_row(root,out,suffix)
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

func _slot_pressed(index: int) -> Dictionary:
	if _bag.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_enchant_window_host_unavailable")
	var listing: Array=_listing(hud)
	if index<0 or index>=listing.size():return {"ok":true,"empty_slot":true}
	var entry: Dictionary=listing[index]
	if _tab=="equip":
		_selected=str(entry.get("target_id",""))
		return _restage()
	var name: String=str(entry.get("name",""))
	if name==_scroll:return _set_tab("equip")
	# The existing scroll activation: the world reopens this window with that
	# scroll's targets (a 축복 부여 scroll opens its own blessing list).
	hud.inventory_item_activated.emit(name)
	return {"ok":true,"scroll_activated":name}

func select_target(target_id: String) -> Dictionary:
	_selected=target_id
	_tab="equip"
	return _restage()

func _set_tab(value: String) -> Dictionary:
	if value=="equip" and _scroll.is_empty():return _notice("강화 주문서를 먼저 선택하세요")
	if value!=_tab:_bag.y=null
	_tab=value
	return _restage()

func _notice(text: String) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",text)
	return {"ok":true,"notice":text}

## 강화 확률: the chances the existing rule supplies for this target.
func _probability() -> Dictionary:
	var entry: Dictionary=_entry()
	if entry.is_empty():return _fail("source_enchant_window_target_unselected")
	return _notice("성공 %.1f%% · 유지 %.1f%% · 하락 %.1f%% · 소실 %.1f%% · 성공 강화폭 %s" % [float(entry.get("success_chance",0.0)),float(entry.get("no_change_chance",0.0)),float(entry.get("decrease_chance",0.0)),float(entry.get("destroy_chance",0.0)),str(entry.get("gain_text","+1"))])

func _enchant_requested() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var entry: Dictionary=_entry()
	if hud==null or entry.is_empty() or _scroll.is_empty():return _fail("source_enchant_window_target_unselected")
	return {"ok":Forge.confirm_target(hud,_scroll,entry),"confirmation_owner":"renewal_forge.confirm_target"}

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
