extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 대장간 window (ForgeScene / Forge_All) over the existing
## 대장간 연마 feature (#579, scripts/honing/honing523_service.gd: original
## ItemHoning* tables + TWILIGHT 근사). Rules, costs, rolls and saves stay in
## the service; every action is quote -> HUD confirmation -> attempt.
## - 연마 tab (Forge_Panel_Item / Forge_Panel_Item_Sharpen): the chosen weapon
##   (Forge_List_Item_Sharpen with its own original item picture and name),
##   the original material rows (Forge_List_Slot: item picture, owned /
##   needed) and the 연마 button (Nd_Btn_Sharpen) with the original success
##   chance (Nd_Notice Btn_Probability).
## - 연마 재료 (Forge_Inventory): the weapons the service lists (+7 이상 신화
##   무기), four per Inventory_Slot_Set line (A안), +N on each; a tap chooses.
## - Btn_Help opens the original HelpBox_Forge.
## Left empty (no TWILIGHT feature): the 제작 tab (Forge_Panel_Item_Craft,
## Btn_Craft) and 상세 (Btn_Detail), 연출 스킵, 창고 수수료 and the result
## animation (Forge_Result; the HUD message and log carry the result).
## The 전체 / 장비 / 소모 / 기타 bag tabs filter the 연마 재료 list: every
## candidate is a weapon, so 장비 lists them and 소모 / 기타 are empty.
const HONING=preload("res://scripts/honing/honing523_service.gd")
const REFINE=preload("res://scripts/refine523/bless_refine523_service.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Storage=preload("res://scripts/ui/original_ui/source_main_storage_window.gd")
const ROOT="UI/Forge/Forge_All.csb"
const INVENTORY="UI/Forge/Forge_Inventory.csb"
const PANEL="UI/Forge/Forge_Panel_Item.csb"
const SHARPEN="UI/Forge/Forge_Panel_Item_Sharpen.csb"
const TARGET="UI/Forge/Forge_List_Item_Sharpen.csb"
const MATERIAL="UI/Forge/Forge_List_Slot.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const HELP="UI/CsbFile/Help/HelpBox_Forge.csb"
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
## The authored Inventory_Slot_Set line of Forge_Inventory's ScrollView.
const FIRST_LINE=Vector2(153.5222,-458.2034)
const P_INV="Forge_Inventory/Nd_Inventory/"
const P_PANEL="Forge_Panel_Item/"
const P_SHARPEN="Forge_Panel_Item_Sharpen/"
## Common_Slot nodes left out (badges and states no rule here sets).
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
var selected: String=""
var bag_tab: String="all"
const BAG_TABS={"all":"Btn_All","equip":"Btn_Equipment","consume":"Btn_Consume","etc":"Btn_Etc"}
var _weapons: Array=[]
var _all_weapons: Array=[]
var _scroller=Storage.Scroller.new()

func required_members() -> Array[String]:
	return [ROOT,INVENTORY,PANEL,SHARPEN,TARGET,MATERIAL,SET,SLOT]

func _root_member() -> String:
	return ROOT

func open(parent: Node) -> Dictionary:
	selected=""
	bag_tab="all"
	_scroller=Storage.Scroller.new()
	return open_window(parent)

## --- Model (the service; tests override these) --------------------------------

func candidates() -> Array:
	var owner: Object=world()
	return HONING.candidates(owner) if owner!=null else []

func quote(uid: String) -> Dictionary:
	var owner: Object=world()
	return HONING.quote(owner,uid) if owner!=null else {"ok":false,"reason":"게임을 찾을 수 없습니다"}

func attempt(uid: String) -> Dictionary:
	var owner: Object=world()
	return HONING.attempt(owner,uid) if owner!=null else {"ok":false,"reason":"게임을 찾을 수 없습니다"}

func owned(item_class_id: int) -> int:
	var owner: Object=world()
	return int(REFINE.stacks_of(owner,item_class_id).get("total",0)) if owner!=null else 0

## The weapon's original ItemClassID (its physical record).
func item_class(uid: String) -> int:
	var owner: Object=world()
	var instances: Variant=owner.get("item_instances") if owner!=null else null
	var physical: Variant=instances.get(uid,{}) if instances is Dictionary else {}
	return int(physical.get("record",{}).get("source_item_class_id",0)) if physical is Dictionary else 0

static func item_name(item_class_id: int) -> String:
	return HONING.item_name(item_class_id).get_slice(" · 원본#",0)

## "+N" of a candidate label ("+9 진명황의 집행검").
static func enchant_text(label: String) -> String:
	return label.get_slice(" ",0) if label.begins_with("+") else ""

## --- Spec -----------------------------------------------------------------------

func _spec() -> Dictionary:
	_all_weapons=candidates()
	# Every 연마 candidate is a weapon (장비); 소모 / 기타 list nothing.
	_weapons=_all_weapons if bag_tab in ["all","equip"] else []
	var known: bool=false
	for row: Dictionary in _all_weapons:
		if str(row.uid)==selected:known=true
	if not known:selected=""
	var current: Dictionary=_current()
	var offer: Dictionary=quote(selected) if not selected.is_empty() else {}
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Fx_Img_BG_Particle"]={"exclude":true}
	spec["Nd_Help/Btn_Help"]={"activate":Callable(self,"_help")}
	for name: String in ["Nd_Btn_Craft","Nd_Btn_Detail","Nd_Skip","Nd_StorageFee","Forge_Result"]:spec[name]={"exclude":true}
	var can: bool=bool(offer.get("ok",false))
	spec["Nd_Btn_Sharpen/Btn_Sharpen"]={"activate":Callable(self,"_hone"),"displaystate":can}
	spec["Nd_Btn_Sharpen/Btn_Sharpen/Normal"]={"visible":can}
	spec["Nd_Btn_Sharpen/Btn_Sharpen/Disabled"]={"visible":not can}
	spec["Nd_Notice/Btn_Probability"]={"visible":not selected.is_empty(),"activate":Callable(self,"_probability")}
	# 연마 / 제작 tabs: 연마 is the feature; 제작 has no TWILIGHT feature.
	spec[P_PANEL+"Nd_Tab/Btn_Sharpen_On"]={"visible":true}
	spec[P_PANEL+"Nd_Tab/Btn_Sharpen_Off"]={"visible":false}
	spec[P_PANEL+"Nd_Tab/Btn_Craft_On"]={"visible":false}
	spec[P_PANEL+"Nd_Tab/Btn_Craft_Off"]={"visible":true,"activate":Callable(self,"_craft_missing")}
	spec[P_PANEL+"Forge_Panel_Item_Craft"]={"exclude":true}
	# The chosen weapon.
	var t: String=P_SHARPEN+"Nd_TargetItem/"
	spec[P_SHARPEN+"Nd_Notice"]={"visible":selected.is_empty()}
	spec[t+"Label"]={"role":"source_text","text":str(current.get("label","")),"visible":not selected.is_empty()}
	spec[t+"Forge_List_Item_Sharpen"]={"visible":not selected.is_empty()}
	var s: String=t+"Forge_List_Item_Sharpen/"
	for name: String in ["Fx_Root","Nd_Slot/Fx_Light","Nd_Slot/Fx_Inventory_Slot"]:spec[s+name]={"exclude":true}
	_slot_spec(spec,s+"Nd_Slot/Common_Slot/")
	spec[s+"Nd_Slot/Common_Slot/Btn"]={"activate":Callable(self,"_clear")}
	spec[s+"Nd_Slot/Common_Slot/Text_Amount"]={"role":"source_text","text":enchant_text(str(current.get("label",""))),"visible":not selected.is_empty()}
	spec[s+"Nd_Slot/Common_Slot/Sp_Select"]={"visible":false}
	spec[P_SHARPEN+"Nd_Material"]={"visible":not selected.is_empty()}
	# 연마 재료: the weapons, rows added in _fill.
	for fx: String in ["ToolTip"]:spec[P_INV+fx]={"exclude":true}
	spec[P_INV+"ScrollView/Inventory_Slot_Set"]={"exclude":true}
	spec[P_INV+"ScrollView"]={"role":"source_scroll","input":Callable(_scroller,"input")}
	spec[P_INV+"Nd_Number"]={"visible":false}
	for tab: String in BAG_TABS:
		spec[P_INV+"Tab/"+BAG_TABS[tab]+"_On"]={"visible":tab==bag_tab}
		spec[P_INV+"Tab/"+BAG_TABS[tab]+"_Off"]={"visible":tab!=bag_tab,"activate":Callable(self,"_set_bag_tab").bind(tab)}
	return spec

func _slot_spec(spec: Dictionary, p: String) -> void:
	spec[p+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	for name: String in SLOT_EXCLUDED:spec[p+name]={"exclude":true}

func _current() -> Dictionary:
	for row: Dictionary in _all_weapons:
		if str(row.uid)==selected:return row
	return {}

## --- Fill -----------------------------------------------------------------------

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var filled: Dictionary={"ok":true,"weapons":_weapons.size(),"selected":selected}
	var pictures: int=0
	if not selected.is_empty():
		var icon: Dictionary=_locate(root,out,"Forge_List_Item_Sharpen/Nd_Slot/Common_Slot/Sp_IconSample")
		if icon.get("ok",false) and _show_item_icon(icon.player,icon.offset,_item_picture(item_class(selected),str(_current().get("label","")))):pictures+=1
		var materials: Dictionary=_fill_materials(root,out)
		if not materials.get("ok",false):return materials
		filled["materials"]=int(materials.rows)
		pictures+=int(materials.pictures)
	var bag: Dictionary=_fill_inventory(root,out)
	if not bag.get("ok",false):return bag
	filled["lines"]=int(bag.lines)
	filled["pictures"]=pictures+int(bag.pictures)
	return filled

## The weapon's original cost rows: picture and owned / needed.
func _fill_materials(root: Node2D, out: Dictionary) -> Dictionary:
	var offer: Dictionary=quote(selected)
	var costs: Array=offer.get("rule",{}).get("costs",[])
	var rows: Array=[]
	for cost: Dictionary in costs:
		var have: int=owned(int(cost.item_class_id))
		var spec: Dictionary={"Panel/Label":{"role":"source_text","text":"%s/%s" % [_number(have),_number(int(cost.amount))]}}
		_slot_spec(spec,"Panel/Common_Slot/")
		spec["Panel/Common_Slot/Sp_Select"]={"visible":false}
		spec["Panel/Common_Slot/Text_Amount"]={"visible":false}
		spec["Panel/Common_Slot/Btn"]={"activate":Callable(self,"_material_info").bind(int(cost.item_class_id))}
		rows.append({"member":MATERIAL,"spec":spec,"cost":cost})
	var placed: Dictionary=_fill_list(root,out,P_SHARPEN+"Nd_Material/ListView",rows,NAN,true)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	for index: int in range(rows.size()):
		var icon: Dictionary=_locate(placed.scenes[index],placed.outs[index],"Common_Slot/Sp_IconSample")
		var id: int=int(rows[index].cost.item_class_id)
		if icon.get("ok",false) and _show_item_icon(icon.player,icon.offset,_item_picture(id,item_name(id))):pictures+=1
	return {"ok":true,"rows":rows.size(),"pictures":pictures}

## Inventory_Slot_Set lines (A안), four weapons each, in the ScrollView.
func _fill_inventory(root: Node2D, out: Dictionary) -> Dictionary:
	var located: Dictionary=_locate(root,out,P_INV+"ScrollView")
	if not located.get("ok",false):return located
	var scroll: Variant=located.player.source_nodes.get(located.offset)
	var content: Variant=(scroll as Node).find_child("SourceOriginalScrollContent",true,false) if is_instance_valid(scroll) else null
	if not content is Node2D:return _fail("source_forge_inventory_content_missing")
	var lines: int=maxi(1,ceili(float(_weapons.size())/float(SET_SLOTS.size())))
	var pictures: int=0
	for line: int in range(lines):
		var spec: Dictionary={"Nd_Slot/Fx_Slot_UnLock":{"exclude":true},"Nd_Slot_Extension":{"exclude":true},"Nd_Slot_Extension_Lock":{"exclude":true}}
		for index: int in range(SET_SLOTS.size()):
			var at: int=line*SET_SLOTS.size()+index
			var row: Dictionary=_weapons[at] if at<_weapons.size() else {}
			var key: String="Nd_Slot/"+SET_SLOTS[index]+"/"
			_slot_spec(spec,key)
			spec[key+"Sp_Select"]={"visible":not row.is_empty() and str(row.uid)==selected}
			var text: String=enchant_text(str(row.get("label","")))
			spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
			spec[key+"Btn"]={"activate":Callable(self,"_pressed").bind(at)}
		var row_out: Dictionary={}
		var built: Dictionary=_scene_of(SET,spec,row_out)
		if not built.get("ok",false):return built
		built.scene.position=FIRST_LINE+Vector2(0.0,Storage.ROW_PITCH*float(line))
		(content as Node2D).add_child(built.scene)
		for index: int in range(SET_SLOTS.size()):
			var at: int=line*SET_SLOTS.size()+index
			_forward_drag(built.scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn")
			if at>=_weapons.size():continue
			var icon: Dictionary=_locate(built.scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample")
			var uid: String=str(_weapons[at].uid)
			if icon.get("ok",false) and _show_item_icon(icon.player,icon.offset,_item_picture(item_class(uid),str(_weapons[at].label))):pictures+=1
	# The ScrollView's drag area sits under its content (slot taps first).
	var area: Variant=scroll.get_meta("source_scroll").input_control() if scroll.has_meta("source_scroll") else null
	if area is Control and area.get_parent()!=null:area.get_parent().move_child(area,0)
	_scroller.bind(content,FIRST_LINE.y,lines)
	return {"ok":true,"lines":lines,"pictures":pictures}

func _forward_drag(root: Node2D, out: Dictionary, suffix: String) -> void:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if area is Control and not area.gui_input.is_connected(_scroller.input):area.gui_input.connect(_scroller.input)

static func _item_picture(item_class_id: int, title: String) -> Dictionary:
	if item_class_id<=0:return {"ok":false}
	return SourceImages.describe_item_class(item_class_id,title)

## --- Actions --------------------------------------------------------------------

func _pressed(index: int) -> Dictionary:
	if _scroller.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	if index<0 or index>=_weapons.size():return {"ok":true,"empty_slot":true}
	var row: Dictionary=_weapons[index]
	selected="" if str(row.uid)==selected else str(row.uid)
	if not selected.is_empty() and not bool(row.get("ok",false)):_message(str(row.get("reason","")) if not bool(row.get("honed",false)) else "이미 연마된 무기입니다")
	_scroller.keep()
	return _stage()

func _set_bag_tab(tab: String) -> Dictionary:
	if not BAG_TABS.has(tab):return _fail("source_forge_window_tab_unknown")
	bag_tab=tab
	_scroller=Storage.Scroller.new()
	return _stage()

func select(uid: String) -> Dictionary:
	selected=uid
	return _stage()

func _clear() -> Dictionary:
	selected=""
	_scroller.keep()
	return _stage()

func _material_info(item_class_id: int) -> Dictionary:
	_message("%s 보유 %s개" % [item_name(item_class_id),_number(owned(item_class_id))])
	return {"ok":true}

func _probability() -> Dictionary:
	var offer: Dictionary=quote(selected)
	var rule: Dictionary=offer.get("rule",{})
	if rule.is_empty():
		_message(str(offer.get("reason","연마 확률을 확인할 수 없습니다")))
		return {"ok":false}
	_message("연마 성공 확률 %d%% · 성공 시 수식어 '%s' · 실패 시 재료만 소모되고 무기는 그대로입니다" % [int(rule.probability)*100/HONING.SCALE,str(rule.get("epithet",{}).get("name",""))])
	return {"ok":true}

func _craft_missing() -> Dictionary:
	_message("대장간 제작은 TWILIGHT에 기능이 없어 연마만 할 수 있습니다")
	return {"ok":true}

func _help() -> Dictionary:
	return _open_help(HELP)

## 연마: the service's quote, the HUD confirmation, then the attempt.
func _hone() -> Dictionary:
	if selected.is_empty():
		_message("연마할 무기를 고르세요")
		return {"ok":false}
	var offer: Dictionary=quote(selected)
	if not offer.get("ok",false):
		_message(str(offer.get("reason","연마할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_forge_window_confirmation_unavailable")
	var names: PackedStringArray=[]
	for cost: Dictionary in offer.rule.costs:names.append("%s %d" % [item_name(int(cost.item_class_id)),int(cost.amount)])
	var uid: String=selected
	owner.call("confirm_action","대장간 연마","%s\n재료: %s\n성공 확률 %s · 실패하면 재료만 사라집니다" % [str(_current().get("label","")),", ".join(names),str(offer.get("percent",""))],"연마",func(_count: int=1) -> void:
		var result: Dictionary=attempt(uid)
		var text: String=str(result.get("detail",result.get("reason","")))
		_message(text)
		if result.get("ok",false) and owner.has_method("append_log"):owner.call("append_log",text)
		if is_open():
			_scroller.keep()
			_stage())
	return {"ok":true,"existing_confirmation":true,"uid":uid}
