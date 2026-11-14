extends RefCounted
## The original 523 skill window: Skill_All (frame, close, tab strip,
## ScrollView_All, 상세 보기) at its FloatingUiScene place. The current job's
## skills (the existing skills window's list: hud.job_skills filtered by job,
## grade then name) are original MainFloating/Slot_Skill slots, four per row
## inside ScrollView_All; each shows the skill's original picture
## (Source523SkillBuffImages), the authored Img_Disabled cover while the
## skill is not learned and the authored passive mark. Tapping a slot selects
## it (Sp_slot_select); 상세 보기 or a second tap opens the existing skills
## window on that skill, where learning, use and quick-slot registration stay.
## Left empty (no rule here): the 정령 / 특수 / 착용 tabs, 스킬 카드, 속성
## 변경 and 디버프 buttons, cooldown and count labels.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
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
const MAX_SLOTS: int=160
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
	return _stage()

func close() -> void:
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
	if list.size()>MAX_SLOTS:list.resize(MAX_SLOTS)
	return list

static func _id(record: Dictionary) -> String:
	return str(record.get("id",record.get("name","")))

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_skill_window_host_unavailable")
	_records=_skills(hud)
	var ids: Array=_records.map(func(r: Dictionary) -> String: return _id(r))
	if _selected not in ids:_selected=""
	var spec: Dictionary={
		"Btn_Close":{"activate":Callable(self,"_close_requested")},
		"ScrollView_All":{"role":"source_scroll","input":Callable(self,"_list_input")},
		"ScrollView_Special":{"visible":false},
		"ScrollView_MythSkill":{"visible":false},
		"Nd_ItempEquip":{"visible":false},
		"Tab/ListView":{"role":"source_list","row_offsets":[],"input":Callable(_tree,"_ignore_input")},
		"Menu_Button/Btn_Search":{"activate":Callable(self,"_detail_requested"),"displaystate":not _selected.is_empty()},
		"Menu_Button/Btn_Search/Normal":{"visible":not _selected.is_empty()},
		"Menu_Button/Btn_Search/Disabled":{"visible":_selected.is_empty()},
		"Menu_Button/Btn_SkillCard":{"visible":false},
		"Menu_Button/Btn_Property":{"visible":false},
		"Menu_Button/Btn_MagicMaster":{"visible":false},
	}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var scroll: Dictionary=NamedTree.locate(next,out,"ScrollView_All")
	var scroll_node: Variant=scroll.player.source_nodes.get(scroll.offset) if scroll.get("ok",false) else null
	var content: Node2D=_scroll_content(scroll_node)
	if content==null:
		next.free()
		return _fail("source_skill_window_scroll_content_missing")
	var view: Vector2=NamedTree.list_size(out,_pack,ROOT,"ScrollView_All")
	var pictures: int=0
	for index: int in range(_records.size()):
		var slot: Dictionary=_slot(hud,_records[index])
		if not slot.get("ok",false):continue
		if slot.get("picture",false):pictures+=1
		var column: int=index%COLUMNS
		var row: int=index/COLUMNS
		# Four 78-wide Slot_Skill buttons centred in the 326-wide view, rows top-down.
		var left: float=(view.x-PITCH*float(COLUMNS))*0.5
		# Content-local: the view's top edge is -view.y in the ScrollView and
		# the content sits at its authored offset (_scroll_base) below it.
		slot.scene.position=Vector2(left+PITCH*(float(column)+0.5),-view.y-_scroll_base+PITCH*(float(row)+0.5))
		content.add_child(slot.scene)
	# The 전체 tab (Skill_Tab_Btn Panel_All) heads the tab strip.
	var tab_out: Dictionary={}
	var tab: Dictionary=_tree.scene_of(TAB,{"Panel_Skill":{"visible":false},"Panel_MythSkill":{"visible":false},"Panel_EquipSkill":{"visible":false},"Panel_All/Btn_All_Off":{"visible":false},"Panel_All/Sp_New":{"visible":false}},tab_out)
	var tabs: Dictionary=NamedTree.locate(next,out,"Tab/ListView")
	var tab_node: Variant=tabs.player.source_nodes.get(tabs.offset) if tabs.get("ok",false) else null
	var tab_content: Variant=(tab_node.get_meta("source_list_content") if tab_node.has_meta("source_list_content") else null) if is_instance_valid(tab_node) else null
	if tab.get("ok",false) and tab_content is Node2D:
		tab.scene.position=Vector2(35.0,-23.0)
		tab_content.add_child(tab.scene)
	elif tab.get("ok",false):tab.scene.free()
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
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"skills":_records.size(),"pictures":pictures,"selected":_selected}
	return last_result

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
	var spec: Dictionary={
		"Btn_Skill_Slot_1":{"activate":Callable(self,"_slot_pressed").bind(id)},
		"Nd_Skill_1/Sp_IconSample":{"role":"source_asset_slot","visible":false},
		"Nd_Skill_1/Text_Amount":{"visible":false},
		"Nd_Skill_1/Label_Center":{"visible":false},
		"Nd_Skill_1/Label_CoolTime":{"visible":false},
		"Nd_Skill_1/Img_Disabled":{"visible":not learned},
		"Sp_slot_select":{"visible":id==_selected},
	}
	for mark: String in ["Sp_Inven_Slot_Icon_Equip","Sp_Inven_Slot_Icon_Aura","Sp_Inven_Slot_Icon_Target","Sp_Inven_Slot_Repair","Sp_Inven_Slot_Icon_Auto","Sp_Inven_Slot_Icon_Self","Sp_Inven_Slot_Icon_Party","Sp_Inven_Slot_Icon_Increase","Sp_Item_Equip_Spell_Icon","Sp_Item_Infinity_Icon","Nd_Grace"]:
		spec["Nd_Icon/"+mark]={"visible":false}
	spec["Nd_Icon/Sp_Inven_Slot_Icon_Passive"]={"visible":passive}
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
		if area is Control:area.gui_input.connect(_list_input)
	return {"ok":true,"scene":built.scene,"picture":picture}

func _slot_pressed(id: String) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	if id==_selected:return _detail_requested()
	_selected=id
	return _stage()

## The existing skills window on the selected skill (learn, use, quick slot).
func _detail_requested() -> Dictionary:
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
	# Dragging up (negative) reveals lower rows.
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll_base+_scroll

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
