extends RefCounted
## Explicit caller-selected original equipment page, exact-name slot subset.
## The side UI owns equipped records, physical reference construction and input.
const COMMON="UI/CommonUi/Common_Slot.csb"
const COMMON_SHA="b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6"
## Every original slot of the two equipment pages. physical_slot names the
## TWILIGHT equipped_items key the slot shows; "" keeps the original empty
## slot (insignia, leggings, spaulder, earrings, loons, bangles... have no
## TWILIGHT equipment slot yet).
const PAGES={
 "UI/FloatingUi/CharacterInfo_EquipSlotSet_A.csb":{
  "sha256":"124721703e192879c6fbcf9bfaa62ae118b51b7b143a072e4595471d799678f5","panel":304,
  "slots":{24680:{"source_name":"Slot_Helmet","physical_slot":"helmet"},22860:{"source_name":"Slot_Insignia","physical_slot":""},21044:{"source_name":"Slot_Weapon","physical_slot":"weapon"},19228:{"source_name":"Slot_Armor","physical_slot":"body"},17416:{"source_name":"Slot_Boot","physical_slot":"boots"},15596:{"source_name":"Slot_Legging","physical_slot":""},13780:{"source_name":"Slot_Shirt","physical_slot":"tshirt"},11960:{"source_name":"Slot_Spaulder","physical_slot":""},10148:{"source_name":"Slot_Cape","physical_slot":"cloak"},8332:{"source_name":"Slot_Shield","physical_slot":"offhand"},6516:{"source_name":"Slot_Glove","physical_slot":"gloves"},396:{"source_name":"Slot_Etc","physical_slot":""}}},
 "UI/FloatingUi/CharacterInfo_EquipSlotSet_B.csb":{
  "sha256":"404798592672d54ef558ceaf18c0e6d0889cbf881a3b17a17c9bf83f1072c0af","panel":436,
  "slots":{22332:{"source_name":"Slot_Earring","physical_slot":""},20520:{"source_name":"Slot_Belt","physical_slot":"belt"},18708:{"source_name":"Slot_Ring","physical_slot":"ring1"},16896:{"source_name":"Slot_Ring_2","physical_slot":""},15080:{"source_name":"Slot_Loon","physical_slot":""},13260:{"source_name":"Slot_Earring_1","physical_slot":""},11440:{"source_name":"Slot_Necklace","physical_slot":"necklace"},9628:{"source_name":"Slot_Ring_1","physical_slot":"ring2"},7816:{"source_name":"Slot_Ring_3","physical_slot":""},5996:{"source_name":"Slot_Loon_1","physical_slot":""}}}
}
## TWILIGHT physical slots shown by the pages above.
const PHYSICAL_SLOTS: Array[String]=["helmet","weapon","body","boots","tshirt","cloak","offhand","gloves","belt","ring1","ring2","necklace"]
## Korean slot names for the empty-slot notice (TWILIGHT 근사: an empty slot
## opens the bag to choose the item; a slot TWILIGHT has no equipment for
## says so instead of staying silent).
const SLOT_TITLES={"Slot_Helmet":"투구","Slot_Insignia":"휘장","Slot_Weapon":"무기","Slot_Armor":"갑옷","Slot_Boot":"부츠","Slot_Legging":"각반","Slot_Shirt":"티셔츠","Slot_Spaulder":"견갑","Slot_Cape":"망토","Slot_Shield":"방패·보조","Slot_Glove":"장갑","Slot_Etc":"기타","Slot_Earring":"귀걸이","Slot_Earring_1":"귀걸이","Slot_Belt":"벨트","Slot_Ring":"반지","Slot_Ring_1":"반지","Slot_Ring_2":"반지","Slot_Ring_3":"반지","Slot_Loon":"룬","Slot_Loon_1":"룬","Slot_Necklace":"목걸이"}
const BUTTON=15728
const BACKGROUND=15316
const ICON=15012
var _pack: RefCounted
var _side: WeakRef
var _image_provider: Callable
var _hud: WeakRef

func configure(pack: RefCounted, hud: Node, image_provider: Callable) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_equipment_existing_hud_required")
	var side: Variant=hud.get("lineage_side_ui")
	if not is_instance_valid(side) or not side.has_signal("equipment_requested"):return _fail("source_equipment_existing_side_input_required")
	_pack=pack
	_side=weakref(side)
	_hud=weakref(hud)
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
	var panel: Dictionary=_node_at(tree.get("nodeTree",{}),int(spec.panel))
	if panel.get("classname")!="Panel":return _fail("source_equipment_original_page_panel_missing")
	var panel_widget: Dictionary=_widget(panel)
	var bindings: Dictionary={}
	# Page B's normal-server Panel is authored hidden (the client shows it or
	# Panel_Reboot by server type); the chosen page panel is shown.
	bindings[int(spec.panel)]={"role":"consume","visible":true} if bool(panel_widget.get("touchEnabled",false)) else {"visible":true}
	var scope: Array[int]=[]
	var rows: Array=[]
	var owners: Dictionary={}
	var missing: Dictionary={}
	for offset: int in spec.slots:
		var slot: Dictionary=spec.slots[offset]
		var raw: Dictionary=_node_at(panel,offset)
		if raw.get("classname")!="ProjectNode" or _widget(raw).get("name")!=slot.source_name or raw.get("options",{}).get("fileName")!="CommonUi/Common_Slot.csb":return _fail("source_equipment_exact_original_slot_mismatch")
		var physical_slot: String=slot.physical_slot
		var input_button: Variant=buttons.get(physical_slot) if not physical_slot.is_empty() else null
		if not physical_slot.is_empty() and (not input_button is BaseButton or not is_instance_valid(input_button)):return {"ok":false,"code":"source_equipment_existing_physical_button_missing","physical_slot":physical_slot}
		var record: Variant=state.equipped_items.get(physical_slot,{}) if not physical_slot.is_empty() else {}
		if not record is Dictionary:return _fail("source_equipment_existing_record_invalid")
		var common_scope: Array[int]=[BUTTON,BACKGROUND]
		var common_bindings: Dictionary={BUTTON:{"role":"button","activate":Callable(self,"empty_slot").bind(physical_slot,str(slot.source_name))}}
		if not record.is_empty():
			if input_button.disabled:return {"ok":false,"code":"source_equipment_owner_input_unavailable","physical_slot":physical_slot}
			if not _image_provider.is_valid():return _fail("source_equipment_existing_image_provider_required")
			var owner: Variant=_image_provider.call(record.duplicate(true),{"physical_slot":physical_slot,"page_member":member,"slot_project_offset":offset,"member":COMMON,"node_offset":ICON})
			# One equipped item without a resolvable original picture used to
			# reject the whole original page (the phone then showed the TWILIGHT
			# equipment panel). That slot keeps its original frame and input and
			# only its picture stays empty, like the original bag.
			if owner is Dictionary and owner.get("ok",false) and (owner.get("texture") is Texture2D or owner.get("source_scene_descriptor") is Dictionary):
				owners[offset]=owner
				common_scope.append(ICON)
				common_bindings[ICON]={"role":"source_asset_slot","visible":false}
			else:
				missing[physical_slot]=owner.duplicate(true) if owner is Dictionary else {"ok":false}
			common_bindings[BUTTON]={"role":"button","activate":Callable(self,"activate").bind(physical_slot)}
		scope.append(offset)
		bindings[offset]={"role":"project","source_node_offsets":common_scope,"bindings":common_bindings}
		rows.append({"source_project_offset":offset,"source_name":slot.source_name,"physical_slot":physical_slot,"record":record.duplicate(true),"owner_button":input_button,"input_basis":"existing equipment_buttons[physical_slot].pressed callback owns equipment_requested/reference construction","original_widget":_widget(raw).duplicate(true)})
	return {"ok":true,"member":member,"sha256":spec.sha256,"source_node_offsets":scope,"bindings":bindings,"rows":rows,"owner_results":owners,"missing_pictures":missing,"panel_offset":spec.panel,"original_panel_widget":panel_widget.duplicate(true),"viewport_extent":Vector2(326,428),"page_registration_ready":true,"page_registration_basis":"Cocos2d-x3.6 PageView preserves original Layout anchor; changes position/size only","page_selection_inferred":false,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original class/mode to caller-selected page member and page order","remaining physical slot aliases/numbering and source modes","original per-slot Border/Broken/Clear visibility and unsupported detail/unequip modes"]}

func activate(physical_slot: String) -> Dictionary:
	if physical_slot not in PHYSICAL_SLOTS:return _fail("source_equipment_unmapped_physical_slot")
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

## An empty slot: a TWILIGHT equipment slot opens the bag (choose the item
## there); a slot without TWILIGHT equipment shows why nothing can go in it.
func empty_slot(physical_slot: String, source_name: String) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var title: String=str(SLOT_TITLES.get(source_name,source_name))
	if physical_slot.is_empty():
		_message(hud,"%s 칸에 장착할 장비는 TWILIGHT에 없습니다" % title)
		return {"ok":true,"notice":"no_twilight_slot","source_name":source_name}
	_message(hud,"가방에서 장착할 %s%s 고르세요" % [title,_object_particle(title)])
	if hud!=null and hud.has_signal("inventory_pressed"):
		hud.emit_signal("inventory_pressed")
		return {"ok":true,"opened":"inventory","physical_slot":physical_slot}
	return {"ok":true,"notice":"bag_unavailable","physical_slot":physical_slot}

static func _object_particle(word: String) -> String:
	if word.is_empty():return "를"
	var code: int=word.unicode_at(word.length()-1)
	if code<0xAC00 or code>0xD7A3:return "를"
	return "을" if (code-0xAC00)%28!=0 else "를"

static func _message(hud: Object, text: String) -> void:
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",text)

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
