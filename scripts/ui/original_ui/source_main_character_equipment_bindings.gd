extends RefCounted
## Explicit caller-selected original equipment page, exact-name slot subset.
## The side UI owns equipped records, physical reference construction and input.
const COMMON="UI/CommonUi/Common_Slot.csb"
const COMMON_SHA="b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6"
const PAGES={
 "UI/FloatingUi/CharacterInfo_EquipSlotSet_A.csb":{
  "sha256":"124721703e192879c6fbcf9bfaa62ae118b51b7b143a072e4595471d799678f5","panel":304,
  "slots":{24680:{"source_name":"Slot_Helmet","physical_slot":"helmet"},21044:{"source_name":"Slot_Weapon","physical_slot":"weapon"}}},
 "UI/FloatingUi/CharacterInfo_EquipSlotSet_B.csb":{
  "sha256":"404798592672d54ef558ceaf18c0e6d0889cbf881a3b17a17c9bf83f1072c0af","panel":24496,
  "slots":{44584:{"source_name":"Slot_Belt","physical_slot":"belt"},35504:{"source_name":"Slot_Necklace","physical_slot":"necklace"}}}
}
const BUTTON=15728
const BACKGROUND=15316
const ICON=15012
var _pack: RefCounted
var _side: WeakRef
var _image_provider: Callable

func configure(pack: RefCounted, hud: Node, image_provider: Callable) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_equipment_existing_hud_required")
	var side: Variant=hud.get("lineage_side_ui")
	if not is_instance_valid(side) or not side.has_signal("equipment_requested"):return _fail("source_equipment_existing_side_input_required")
	_pack=pack
	_side=weakref(side)
	_image_provider=image_provider
	return {"ok":true,"page_selection_required":true,"partial_source_scene":true,"complete_screen_contract":false}

func build(member: String) -> Dictionary:
	if not PAGES.has(member):return _fail("source_equipment_explicit_original_page_required")
	var spec: Dictionary=PAGES[member]
	if _pack==null or _pack.manifest.get("files",{}).get(member,{}).get("sha256")!=spec.sha256 or _pack.manifest.get("files",{}).get(COMMON,{}).get("sha256")!=COMMON_SHA:return _fail("source_equipment_original_identity_mismatch")
	var side: Object=_side.get_ref() if _side!=null else null
	if side==null:return _fail("source_equipment_existing_side_unavailable")
	var state: Variant=side.get("character_state")
	var buttons: Variant=side.get("equipment_buttons")
	if not state is Dictionary or not state.get("equipped_items") is Dictionary or not buttons is Dictionary:return _fail("source_equipment_current_owner_model_required")
	var tree: Dictionary=_layout_or_scene(member)
	if tree.is_empty():tree=_pack.scene(member)
	var panel: Dictionary=_node_at(tree.get("nodeTree",{}),int(spec.panel))
	if panel.get("classname")!="Panel":return _fail("source_equipment_original_page_panel_missing")
	var panel_widget: Dictionary=_widget(panel)
	var bindings: Dictionary={}
	if bool(panel_widget.get("touchEnabled",false)):bindings[int(spec.panel)]={"role":"consume"}
	var scope: Array[int]=[]
	var rows: Array=[]
	var owners: Dictionary={}
	for offset: int in spec.slots:
		var slot: Dictionary=spec.slots[offset]
		var raw: Dictionary=_node_at(panel,offset)
		if raw.get("classname")!="ProjectNode" or _widget(raw).get("name")!=slot.source_name or raw.get("options",{}).get("fileName")!="CommonUi/Common_Slot.csb":return _fail("source_equipment_exact_original_slot_mismatch")
		var physical_slot: String=slot.physical_slot
		var input_button: Variant=buttons.get(physical_slot)
		if not input_button is BaseButton or not is_instance_valid(input_button):return {"ok":false,"code":"source_equipment_existing_physical_button_missing","physical_slot":physical_slot}
		var record: Variant=state.equipped_items.get(physical_slot,{})
		if not record is Dictionary:return _fail("source_equipment_existing_record_invalid")
		var common_scope: Array[int]=[BUTTON,BACKGROUND]
		var common_bindings: Dictionary={BUTTON:{"role":"button","displaystate":false,"activate":Callable()}}
		if not record.is_empty():
			if input_button.disabled:return {"ok":false,"code":"source_equipment_owner_input_unavailable","physical_slot":physical_slot}
			if not _image_provider.is_valid():return _fail("source_equipment_existing_image_provider_required")
			var owner: Variant=_image_provider.call(record.duplicate(true),{"physical_slot":physical_slot,"page_member":member,"slot_project_offset":offset,"member":COMMON,"node_offset":ICON})
			if not owner is Dictionary or not owner.get("ok",false) or not owner.get("texture") is Texture2D:return {"ok":false,"code":"source_equipment_actual_owner_icon_required","physical_slot":physical_slot,"owner_result":owner}
			owners[offset]=owner
			common_scope.append(ICON)
			common_bindings[ICON]={"role":"source_asset_slot","visible":false}
			common_bindings[BUTTON]={"role":"button","activate":Callable(self,"activate").bind(physical_slot)}
		scope.append(offset)
		bindings[offset]={"role":"project","source_node_offsets":common_scope,"bindings":common_bindings}
		rows.append({"source_project_offset":offset,"source_name":slot.source_name,"physical_slot":physical_slot,"record":record.duplicate(true),"owner_button":input_button,"input_basis":"existing equipment_buttons[physical_slot].pressed callback owns equipment_requested/reference construction","original_widget":_widget(raw).duplicate(true)})
	return {"ok":true,"member":member,"sha256":spec.sha256,"source_node_offsets":scope,"bindings":bindings,"rows":rows,"owner_results":owners,"panel_offset":spec.panel,"original_panel_widget":panel_widget.duplicate(true),"viewport_extent":Vector2(326,428),"page_registration_ready":true,"page_registration_basis":"Cocos2d-x3.6 PageView preserves original Layout anchor; changes position/size only","page_selection_inferred":false,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original class/mode to caller-selected page member and page order","remaining physical slot aliases/numbering and source modes","original per-slot Border/Broken/Clear visibility and unsupported detail/unequip modes"]}

func activate(physical_slot: String) -> Dictionary:
	if physical_slot not in ["helmet","weapon","belt","necklace"]:return _fail("source_equipment_unmapped_physical_slot")
	var side: Object=_side.get_ref() if _side!=null else null
	if side==null:return _fail("source_equipment_existing_side_unavailable")
	var state: Variant=side.get("character_state")
	var buttons: Variant=side.get("equipment_buttons")
	if not state is Dictionary or not state.get("equipped_items") is Dictionary or not buttons is Dictionary:return _fail("source_equipment_current_owner_model_required")
	var record: Variant=state.equipped_items.get(physical_slot)
	var button: Variant=buttons.get(physical_slot)
	if not record is Dictionary or record.is_empty() or not button is BaseButton or not is_instance_valid(button) or button.disabled:return _fail("source_equipment_current_owner_input_unavailable")
	# Reuse the actual current owner callback. No name@@@instance_id parsing,
	# physical reference construction, selection, unequip or save is duplicated.
	button.emit_signal("pressed")
	return {"ok":true,"dispatched":true,"physical_slot":physical_slot,"signal":"existing equipment_buttons.pressed -> equipment_requested","action_result_known":false}

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _widget(node: Dictionary) -> Dictionary:
	var options: Dictionary=node.get("options",{})
	return options.get("widgetOptions",options.get("nodeOptions",options))

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}

## A member listed in layout_sources (parent reference geometry) is read from
## there; every other member is an ordinary pack scene. layout_source() returns
## {} for scenes, which used to fail every original window as "layout missing".
func _layout_or_scene(member: String) -> Dictionary:
	var tree: Dictionary=_pack.call("layout_source",member) if _pack.has_method("layout_source") else {}
	return tree if tree.get("nodeTree") is Dictionary else _pack.scene(member)
