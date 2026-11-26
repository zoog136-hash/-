extends RefCounted
## The original 523 skill window: Skill_All (frame, close, tab strip,
## ScrollView_All, 상세 보기) at its FloatingUiScene place. The current job's
## skills (the existing skills window's list: hud.job_skills filtered by job,
## grade then name) are original MainFloating/Slot_Skill slots, four per row
## inside ScrollView_All; each shows the skill's original picture
## (Source523SkillBuffImages), the authored Img_Disabled cover while the
## skill is not learned and the authored passive mark. Tapping a slot selects
## it (Sp_slot_select). 상세 보기 uses the original 523 skill tooltip when
## available. A second tap retains the existing skill actions (learn, use,
## quick-slot registration) without adding unauthored buttons to the tooltip.
## The tab strip is one Skill_Tab_Btn per tab: 전체 (every listed skill),
## 정령 (요정 only: the elemental school skills, record school fire / earth /
## water / wind; ScrollView_Special), 특수 (the card-bound skills, original
## SpellLearnLimit.LimitBuffCardID -> record approx_required_card;
## ScrollView_MythSkill) and 착용 (the skills worn equipment gives, record
## equipment_spell523; Nd_ItempEquip with its 착용 스킬 notice). A slot shows
## the remaining cooldown (world.skill_cooldowns, Label_CoolTime), the ammo /
## material count the skill can still be cast with (Text_Amount: the quick
## slot's ammo source, else the material items in the bag) and the equipment
## mark of an equipment skill; times refresh four times a second.
## 스킬 카드 opens the 스킬 카드 window; 속성 변경 (요정) and 디버프 (마법사,
## the MagicMaster groups) open the existing 스킬 계열 전환 screen, which
## holds the original GameClassSpellGroup choice, cost and save.
## Every listed skill is reachable: rows are built only near the view.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Detail=preload("res://scripts/ui/original_ui/source_main_skill_detail.gd")
const Images=preload("res://scripts/ui/source523_skill_buff_images.gd")
const RULES=preload("res://scripts/skill_rules.gd")
const ROOT="UI/FloatingUi/Skill_All.csb"
const TAB="UI/FloatingUi/Skill_Tab_Btn.csb"
const SLOT="UI/MainFloating/Slot_Skill.csb"
## Slot_Skill keeps its button, skill picture group, marks and selection.
const MEMBER_SCOPES={SLOT:[20348,16896,10540,1228]}
const REQUIRED: Array[String]=[ROOT,TAB,SLOT]
const GRADES: Array[String]=["일반","고급","희귀","영웅","전설","신화","유일"]
const COLUMNS: int=4
const PITCH: float=78.0
## tab -> [Skill_Tab_Btn panel, pressed button, released button, scroll view]
const TABS: Dictionary={
	"all":["Panel_All","Btn_All_On","Btn_All_Off","ScrollView_All"],
	"spirit":["Panel_Skill","Btn_Skill_On","Btn_Skill_Off","ScrollView_Special"],
	"myth":["Panel_MythSkill","Btn_MythSkill_On","Btn_MythSkill_Off","ScrollView_MythSkill"],
	"equip":["Panel_EquipSkill","Btn_EquipSkill_On","Btn_Equip_Off","Nd_ItempEquip/ScrollView_EquipSkill"],
}
const SPIRIT_SCHOOLS: Array[String]=["fire","earth","water","wind"]
const TAB_PITCH: float=70.0
const REFRESH_SECONDS: float=0.25
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _content: Node2D
var _records: Array[Dictionary]=[]
var _selected: String=""
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var last_result: Dictionary={}
var tab: String="all"
var _timer: Timer
var _detail: RefCounted
## Only the rows near the visible part of the list exist as nodes: a class
## lists 200+ skills, each Slot_Skill is ~40 nodes, and building
## all of them (again on every selection tap) froze phones for many seconds
## (2026-11-14 phone record: 11,133 nodes, 18.8 s frame after "ui.scene_scope
## ×243"). Rows are added/removed as the list scrolls.
const ROW_MARGIN: int=1
var _slots: Dictionary={}
var _view: Vector2=Vector2.ZERO
var _left: float=0.0
var _pictures: int=0

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_skill_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_skill_window_host_unavailable")
	_parent=weakref(parent)
	_scroll=0.0
	tab="all"
	return _stage()

func close() -> void:
	if _detail!=null:_detail.close()
	_detail=null
	var previous: Node2D=_scene
	_scene=null
	_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func selected() -> String:
	return _selected

func records() -> Array[Dictionary]:
	return _records

## The current job's skills, the way the existing window lists them.
func _skills(hud: Node) -> Array[Dictionary]:
	var world: Node=hud.get_parent()
	var catalog: Object=world.original_skills.catalog
	var job: String=str(hud.character_state.get("job_class","기사"))
	var source_class: int=int(world.BASE508.source_class_id(job))
	var list: Array[Dictionary]=[]
	for value: Variant in hud.job_skills:
		if not value is Dictionary:continue
		var record: Dictionary=value
		var status: Dictionary=catalog.source_learning_status(record)
		var source_for_job: bool=not status.is_empty() and int(status.learned_class_id)==source_class
		var allowed: Array=record.get("classes",[record.get("class","공용")])
		if not allowed.has(job) and not allowed.has("공용") and str(record.get("class",""))!="공용" and not source_for_job:continue
		list.append(record)
	list.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ga: int=GRADES.find(str(a.get("grade","일반")))
		var gb: int=GRADES.find(str(b.get("grade","일반")))
		return str(a.get("name",""))<str(b.get("name","")) if ga==gb else ga<gb)
	return list.filter(func(record: Dictionary) -> bool: return in_tab(record,tab))

## True when `record` belongs to tab `name`.
static func in_tab(record: Dictionary, name: String) -> bool:
	match name:
		"spirit":return str(record.get("class",""))=="요정" and str(record.get("school","")) in SPIRIT_SCHOOLS
		"myth":return int(record.get("approx_required_card",0))!=0
		"equip":return record.has("equipment_spell523")
	return true

## The tabs the current job shows (정령 is the 요정's).
static func tabs_for(job: String) -> Array[String]:
	var names: Array[String]=["all"]
	if job=="요정":names.append("spirit")
	names.append_array(["myth","equip"])
	return names

## The 계열 전환 button the job shows: 속성 변경 (요정), 디버프 (마법사) or none.
const GROUP_CONVERSION_SHOWN: bool=false

static func group_button(job: String) -> String:
	return {"요정":"Btn_Property","마법사":"Btn_MagicMaster"}.get(job,"")

static func _id(record: Dictionary) -> String:
	return str(record.get("id",record.get("name","")))

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_skill_window_host_unavailable")
	var job: String=str(hud.character_state.get("job_class","기사"))
	var shown_tabs: Array[String]=tabs_for(job)
	if tab not in shown_tabs:tab="all"
	_records=_skills(hud)
	var ids: Array=_records.map(func(r: Dictionary) -> String: return _id(r))
	if _selected not in ids:_selected=""
	var scroll_name: String=str(TABS[tab][3])
	var spec: Dictionary={
		"Btn_Close":{"activate":Callable(self,"_close_requested")},
		"ScrollView_All":{"visible":false},
		"ScrollView_Special":{"visible":false},
		"ScrollView_MythSkill":{"visible":false},
		"Nd_ItempEquip":{"visible":tab=="equip"},
		"Nd_ItempEquip/Label_Notice":{"visible":tab=="equip" and _records.is_empty()},
		"Tab/ListView":{"role":"source_list","row_offsets":[],"input":Callable(_tree,"_ignore_input")},
		"Menu_Button/Btn_Search":{"activate":Callable(self,"_detail_requested"),"displaystate":not _selected.is_empty()},
		"Menu_Button/Btn_Search/Normal":{"visible":not _selected.is_empty()},
		"Menu_Button/Btn_Search/Disabled":{"visible":_selected.is_empty()},
		"Menu_Button/Btn_SkillCard":{"activate":Callable(self,"_skill_cards_requested")},
		"Menu_Button/Btn_Property":{"visible":false},
		"Menu_Button/Btn_MagicMaster":{"visible":false},
	}
	spec[scroll_name]={"visible":true,"role":"source_scroll","input":Callable(self,"_list_input")}
	# 스킬 계열 전환 (a TWILIGHT screen) is off the player's screens (user list
	# 2026-11-21 #1): the 속성 변경 / 디버프 buttons stay hidden.
	var group: String=group_button(job) if GROUP_CONVERSION_SHOWN else ""
	if not group.is_empty():
		var ready: bool=_group_conversion_ready(hud)
		spec["Menu_Button/"+group]={"visible":true,"activate":Callable(self,"_group_requested"),"displaystate":ready}
		spec["Menu_Button/"+group+"/Normal"]={"visible":ready}
		spec["Menu_Button/"+group+"/Disabled"]={"visible":not ready}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var scroll: Dictionary=NamedTree.locate(next,out,scroll_name)
	var scroll_node: Variant=scroll.player.source_nodes.get(scroll.offset) if scroll.get("ok",false) else null
	var content: Node2D=_scroll_content(scroll_node)
	if content==null:
		next.free()
		return _fail("source_skill_window_scroll_content_missing")
	var view: Vector2=NamedTree.list_size(out,_pack,ROOT,scroll_name)
	_view=view
	# Four 78-wide Slot_Skill buttons centred in the 326-wide view, rows top-down.
	_left=(view.x-PITCH*float(COLUMNS))*0.5
	_slots={}
	_pictures=0
	# One Skill_Tab_Btn per shown tab, left to right in the tab strip.
	var tabs: Dictionary=NamedTree.locate(next,out,"Tab/ListView")
	var tab_node: Variant=tabs.player.source_nodes.get(tabs.offset) if tabs.get("ok",false) else null
	var tab_content: Variant=(tab_node.get_meta("source_list_content") if tab_node.has_meta("source_list_content") else null) if is_instance_valid(tab_node) else null
	var tab_scenes: int=0
	for index: int in shown_tabs.size():
		var name: String=shown_tabs[index]
		var tab_spec: Dictionary={}
		for other: String in TABS:
			if other!=name:tab_spec[str(TABS[other][0])]={"visible":false}
		var panel: String=str(TABS[name][0])
		tab_spec[panel+"/"+str(TABS[name][1])]={"visible":name==tab,"activate":Callable(self,"_tab_requested").bind(name)}
		tab_spec[panel+"/"+str(TABS[name][2])]={"visible":name!=tab,"activate":Callable(self,"_tab_requested").bind(name)}
		tab_spec[panel+"/Sp_New"]={"visible":false}
		if name=="equip":
			# Panel_EquipSkill's authored captions read 특수 (the MythSkill text).
			tab_spec[panel+"/"+str(TABS[name][1])+"/Label"]={"role":"source_text","text":"착용"}
			tab_spec[panel+"/"+str(TABS[name][2])+"/Label"]={"role":"source_text","text":"착용"}
		var tab_out: Dictionary={}
		var tab_scene: Dictionary=_tree.scene_of(TAB,tab_spec,tab_out)
		if not tab_scene.get("ok",false):continue
		if tab_content is Node2D:
			tab_scene.scene.position=Vector2(35.0+TAB_PITCH*float(index),-23.0)
			tab_content.add_child(tab_scene.scene)
			tab_scenes+=1
		else:tab_scene.scene.free()
	var previous: Node2D=_scene
	# Skill_All_Layout sits at (1008, 345) in FloatingUiScene.
	next.position=Vector2(1008.0,-345.0)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_content=content
	var rows: int=ceili(float(_records.size())/float(COLUMNS))
	_scroll_min=minf(0.0,view.y-PITCH*float(rows))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	_content.position.y=_scroll_base+_scroll
	_ensure_visible_rows()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	_timer=Timer.new()
	_timer.wait_time=REFRESH_SECONDS
	_timer.autostart=true
	_timer.timeout.connect(refresh_times)
	next.add_child(_timer)
	last_result={"ok":true,"handled":true,"member":ROOT,"skills":_records.size(),"pictures":_pictures,"selected":_selected,"built_slots":_slots.size(),"tab":tab,"tabs":shown_tabs,"tab_scenes":tab_scenes,"group_button":group}
	return last_result

func _tab_requested(name: String) -> Dictionary:
	if name==tab:return {"ok":true,"same":true}
	tab=name
	_scroll=0.0
	return _stage()

## The remaining cooldown of `record` (seconds; 0 ready).
func cooldown_of(record: Dictionary) -> float:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	var cooldowns: Variant=world.get("skill_cooldowns") if world!=null else null
	if not cooldowns is Dictionary:return 0.0
	return maxf(float(cooldowns.get(str(record.get("name","")),0.0)),float(cooldowns.get(_id(record),0.0)))

static func cooldown_text(seconds: float) -> String:
	if seconds<=0.0:return ""
	return "%.1f" % seconds if seconds<10.0 else str(ceili(seconds))

## How many more casts the bag allows (-1: the skill uses no ammo or material).
func uses_of(record: Dictionary) -> int:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	if world==null:return -1
	if world.has_method("_quickslot_ammo_source"):
		var ammo: Dictionary=world.call("_quickslot_ammo_source",{"kind":"skill","id":str(record.get("name",""))})
		if not ammo.is_empty():return int(ammo.get("ammo_count",0))
	var items: Variant=record.get("items",{})
	if not items is Dictionary or (items as Dictionary).is_empty() or not world.get("inventory") is Dictionary:return -1
	var inventory: Dictionary=world.get("inventory")
	var source523: Variant=world.original_skills.catalog.get("source523") if world.get("original_skills")!=null else null
	var uses: int=-1
	for item: Variant in items:
		var need: int=int(items[item])
		if need<=0:continue
		var keys: Array=[str(item)]
		if source523!=null and source523.has_method("inventory_keys"):keys=source523.inventory_keys(record,str(item))
		var have: int=0
		for key: Variant in keys:have+=int(inventory.get(str(key),0))
		uses=have/need if uses<0 else mini(uses,have/need)
	return uses

## Live cooldown / count labels of the built slots.
func refresh_times() -> int:
	var changed: int=0
	for index: int in _slots:
		var slot: Dictionary=_slots[index]
		if index>=_records.size():continue
		var record: Dictionary=_records[index]
		for pair: Array in [["cooldown",cooldown_text(cooldown_of(record))],["amount",_amount_text(record)]]:
			var label: Variant=slot.get(pair[0])
			if not label is Dictionary or not is_instance_valid(label.player):continue
			var text: String=str(pair[1])
			if str(label.get("text",""))==text:continue
			label.text=text
			if not text.is_empty():label.player.set_bound_text(int(label.offset),text)
			label.player.set_bound_visible(int(label.offset),not text.is_empty())
			changed+=1
	return changed

func _amount_text(record: Dictionary) -> String:
	var uses: int=uses_of(record)
	return "" if uses<0 else str(uses)

func _group_conversion_ready(hud: Node) -> bool:
	var world: Node=hud.get_parent()
	var conversion: Variant=world.get("spell_group_conversion") if world!=null else null
	return conversion is Object and str((conversion as Object).get("problem"))=="" and hud.has_method("_navigate")

## 스킬 카드: the 스킬 카드 window (the menu's own entry).
func _skill_cards_requested() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("_navigate"):return _fail("source_skill_window_host_unavailable")
	close()
	hud.call("_navigate","skill_card523")
	return {"ok":true,"routed":"skill_card523"}

## 속성 변경 / 디버프: the existing 스킬 계열 전환 screen.
func _group_requested() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_skill_window_host_unavailable")
	if not _group_conversion_ready(hud):
		var world: Node=hud.get_parent()
		var conversion: Variant=world.get("spell_group_conversion") if world!=null else null
		var problem: String=str((conversion as Object).get("problem")) if conversion is Object else "계열 전환을 사용할 수 없습니다"
		if hud.has_method("show_message"):hud.call("show_message",problem)
		return {"ok":false,"handled":true,"code":"source_skill_window_group_conversion_unavailable","reason":problem}
	close()
	hud.call("_navigate","spell_groups")
	return {"ok":true,"routed":"spell_groups"}

## Rows from the first partly visible one to the last, plus ROW_MARGIN.
func visible_row_range() -> Vector2i:
	var rows: int=ceili(float(_records.size())/float(COLUMNS))
	var first: int=maxi(0,floori(-_scroll/PITCH)-ROW_MARGIN)
	var last: int=mini(rows-1,ceili((-_scroll+_view.y)/PITCH)+ROW_MARGIN)
	return Vector2i(first,last)

func _ensure_visible_rows() -> void:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_content):return
	var rows: Vector2i=visible_row_range()
	for index: int in _slots.keys():
		var row: int=int(index)/COLUMNS
		if row<rows.x or row>rows.y:
			var old: Variant=_slots[index].get("scene")
			if is_instance_valid(old):old.queue_free()
			_slots.erase(index)
	for row: int in range(rows.x,rows.y+1):
		for column: int in COLUMNS:
			var index: int=row*COLUMNS+column
			if index>=_records.size() or _slots.has(index):continue
			var slot: Dictionary=_slot(hud,_records[index])
			if not slot.get("ok",false):continue
			if slot.get("picture",false):_pictures+=1
			# Content-local: the view's top edge is -view.y in the ScrollView and
			# the content sits at its authored offset (_scroll_base) below it.
			slot.scene.position=Vector2(_left+PITCH*(float(column)+0.5),-_view.y-_scroll_base+PITCH*(float(row)+0.5))
			_content.add_child(slot.scene)
			_slots[index]=slot

var _scroll_base: float=0.0

## The content node of an original ScrollView (its inner container).
func _scroll_content(scroll_node: Variant) -> Node2D:
	if not is_instance_valid(scroll_node):return null
	var found: Node=scroll_node.find_child("SourceOriginalScrollContent",true,false)
	if found is Node2D:
		_scroll_base=(found as Node2D).position.y
		return found
	return null

func _slot(hud: Node, record: Dictionary) -> Dictionary:
	var world: Node=hud.get_parent()
	var catalog: Object=world.original_skills.catalog
	var learned: bool=bool(catalog.owned(record)) or not (catalog.source_learning_status(record) as Dictionary).is_empty()
	var passive: bool=RULES.is_passive(catalog.resolve(record))
	var id: String=_id(record)
	var amount: String=_amount_text(record)
	var cool: String=cooldown_text(cooldown_of(record))
	var spec: Dictionary={
		"Btn_Skill_Slot_1":{"activate":Callable(self,"_slot_pressed").bind(id)},
		"Nd_Skill_1/Sp_IconSample":{"role":"source_asset_slot","visible":false},
		"Nd_Skill_1/Text_Amount":{"role":"source_text","text":amount if not amount.is_empty() else "0","visible":not amount.is_empty()},
		"Nd_Skill_1/Label_Center":{"visible":false},
		"Nd_Skill_1/Label_CoolTime":{"role":"source_text","text":cool if not cool.is_empty() else "0","visible":not cool.is_empty()},
		"Nd_Skill_1/Img_Disabled":{"visible":not learned},
		"Sp_slot_select":{"visible":id==_selected},
	}
	for mark: String in ["Sp_Inven_Slot_Icon_Equip","Sp_Inven_Slot_Icon_Aura","Sp_Inven_Slot_Icon_Target","Sp_Inven_Slot_Repair","Sp_Inven_Slot_Icon_Auto","Sp_Inven_Slot_Icon_Self","Sp_Inven_Slot_Icon_Party","Sp_Inven_Slot_Icon_Increase","Sp_Item_Equip_Spell_Icon","Sp_Item_Infinity_Icon","Nd_Grace"]:
		spec["Nd_Icon/"+mark]={"visible":false}
	spec["Nd_Icon/Sp_Inven_Slot_Icon_Passive"]={"visible":passive}
	spec["Nd_Icon/Sp_Item_Equip_Spell_Icon"]={"visible":record.has("equipment_spell523")}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(SLOT,spec,out)
	if not built.get("ok",false):return built
	var picture: bool=false
	var image: Dictionary=Images.describe_skill(record)
	if image.get("handled",false) and image.get("texture") is Texture2D:
		var located: Dictionary=NamedTree.locate(built.scene,out,"Nd_Skill_1/Sp_IconSample")
		if located.get("ok",false):
			var owner: Dictionary={"ok":true,"texture":image.texture,"status":str(image.get("status","")),"provenance":image.get("provenance",{})}
			picture=located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false) and located.player.set_bound_visible(located.offset,true).get("ok",false)
	# Dragging over a slot scrolls the list; the slot keeps its tap.
	var button: Dictionary=NamedTree.locate(built.scene,out,"Btn_Skill_Slot_1")
	if button.get("ok",false):
		var node: Variant=button.player.source_nodes.get(button.offset)
		var source_button: Variant=(node.get_meta("source_button") if node.has_meta("source_button") else null) if is_instance_valid(node) else null
		var area: Variant=source_button.get("_input_area") if is_instance_valid(source_button) else null
		if area is Control:
			area.gui_input.connect(_list_input)
			button["area"]=area
	var labels: Dictionary={}
	for pair: Array in [["cooldown","Nd_Skill_1/Label_CoolTime",cool],["amount","Nd_Skill_1/Text_Amount",amount]]:
		var located_label: Dictionary=NamedTree.locate(built.scene,out,str(pair[1]))
		if located_label.get("ok",false):labels[pair[0]]={"player":located_label.player,"offset":int(located_label.offset),"text":str(pair[2])}
	var slot: Dictionary={"ok":true,"scene":built.scene,"picture":picture,"out":out,"id":id,"name":str(record.get("name","")),"area":button.get("area"),"texture":image.get("texture") if picture else null}
	slot.merge(labels)
	return slot

## The source viewport borrows PointerTransfer's single captured gesture
## for both the slots and the spaces between them. A clipped or empty slot
## can scroll but it cannot select/carry a skill.
func hit_at(viewport_point: Vector2) -> Dictionary:
	if not is_open() or not viewport_point.is_finite():return {}
	var scroll_area: Control=_scroll_area()
	if not _contains(scroll_area,viewport_point):return {}
	var found: Dictionary={"from":"skill","id":"","entry":{},"source_native":true,"source_skill_window":true,"skill_window_epoch":_scene.get_instance_id()}
	for index: int in _slots:
		var slot: Dictionary=_slots[index]
		var area: Variant=slot.get("area")
		if not area is Control or not _contains(area,viewport_point):continue
		var exact_id: String=str(slot.get("id",""))
		if exact_id.is_empty():break
		found.merge({"id":exact_id,"entry":{"kind":"skill","id":exact_id},"texture":slot.get("texture")},true)
		break
	return found

func gesture_is_live(epoch: int) -> bool:
	return is_open() and _scene.visible and _scene.get_instance_id()==epoch

func tap_from_pointer(epoch: int, skill_id: String, release_point: Vector2) -> Dictionary:
	if skill_id.is_empty() or not gesture_is_live(epoch) or str(hit_at(release_point).get("id",""))!=skill_id:
		return {"ok":false,"handled":false}
	# This pointer never delivered a press to the native slot's GUI handler.
	# Do not reuse an old wheel/drag offset as this new tap's movement.
	_moved=0.0
	return _slot_pressed(skill_id)

func scroll_from_pointer(epoch: int, viewport_delta_y: float) -> void:
	if not gesture_is_live(epoch) or not is_finite(viewport_delta_y):return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0:_move_scroll(viewport_delta_y/scale_y)

func _scroll_area() -> Control:
	if not is_instance_valid(_content):return null
	var node: Node=_content.get_parent()
	while node!=null and node!=_scene:
		if node.has_meta("source_scroll"):
			var scroll: Variant=node.get_meta("source_scroll")
			var control: Variant=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
			return control if control is Control else null
		node=node.get_parent()
	return null

static func _contains(control: Control, point: Vector2) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)

func _slot_pressed(id: String) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	if id==_selected:return _open_existing_skill_actions()
	var first_selection: bool=_selected.is_empty()
	_selected=id
	# The search button changes state only on the first selection; later taps
	# move the highlight without rebuilding the window.
	if first_selection or not _move_highlight():return _stage()
	last_result["selected"]=_selected
	return last_result

func _move_highlight() -> bool:
	for index: int in _slots:
		var slot: Dictionary=_slots[index]
		var located: Dictionary=NamedTree.locate(slot.scene,slot.out,"Sp_slot_select")
		if not located.get("ok",false):return false
		var node: Variant=located.player.source_nodes.get(located.offset)
		if not is_instance_valid(node):return false
		(node as CanvasItem).visible=str(slot.id)==_selected
	return true

## 상세 보기 is a presentation only. Keep the original selection and
## scroll position alive underneath; the authored X restores the list.
func _detail_requested() -> Dictionary:
	if _selected.is_empty() or not is_open():return _fail("source_skill_window_skill_unselected")
	for record: Dictionary in _records:
		if _id(record)!=_selected:continue
		_detail=Detail.new()
		var hud: Node=_hud.get_ref() if _hud!=null else null
		var result: Dictionary=_detail.open(_pack,_scene.get_parent(),record,hud,Callable(self,"close_detail"))
		if result.get("ok",false):
			_scene.hide()
			return result
		_detail=null
		break
	return _open_existing_skill_actions()

func detail_is_open() -> bool:
	return _detail!=null and _detail.is_open()

func close_detail() -> void:
	if _detail==null:return
	_detail.close()
	_detail=null
	if is_open():_scene.show()

## The existing skill actions stay reachable and are also the older-pack fallback.
func _open_existing_skill_actions() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or _selected.is_empty():return _fail("source_skill_window_skill_unselected")
	var focus: String=_selected
	close()
	hud.call("open_skills_workspace",focus)
	return {"ok":true,"existing_skill_window":true,"skill":focus}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=PITCH*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	_move_scroll(delta)

func _move_scroll(delta: float) -> void:
	# Dragging up (negative) reveals lower rows. Stay cheap while a
	# captured finger pushes against either end of the list.
	var next: float=clampf(_scroll+delta,_scroll_min,0.0)
	if next==_scroll:return
	_scroll=next
	_content.position.y=_scroll_base+_scroll
	_ensure_visible_rows()

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
