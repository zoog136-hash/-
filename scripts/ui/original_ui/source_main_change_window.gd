extends RefCounted
## The original 523 polymorph window: Change_WinTotal (full frame, tabs,
## title, close) with its Change_DetailView page. Every owned card of the
## category is one original Change_Card_A_<grade> card laid out three per row
## the way Change_Card_Set places them, in the page's card ListView. Each card
## shows its original card picture (BuffCard DisplayBaseAssetID through
## SourceCardPresentation); the detail side shows the selected card's
## illustration, name, grade and options. Tapping the selected card again or
## the original 즉시 변신 button runs the existing catalog equip
## (World._equip_catalog), so every rule and save stays with the game.
## The same window serves 마법인형 (the client reuses Change_WinTotal).
## Transcend (Change_Transcend_*) frames exist only in 508: out of scope.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const ROOT="UI/Change/Change_WinTotal.csb"
const DETAIL="UI/Change/Change_DetailView.csb"
const INFO="UI/Change/Change_Upgrade_Info_Swap.csb"
const SET="UI/Change/Change_Card_Set.csb"
const OPTION_ROW="UI/Change/Change_CardGradeOption_Text.csb"
## Change_WinTotal nodes.
const FRAME=27316
const CHANGE_ON=25140
const CHANGE_OFF=23736
const CHANGE_LABELS: Array[int]=[25596,23788]
const COLLECTION_LABELS: Array[int]=[18312,16480]
const MIX_ON=21464
const MIX_OFF=20064
const COLLECTION_ON=17856
const COLLECTION_OFF=16428
const EXPLORE_ON=12820
const EXPLORE_OFF=11392
const TITLE=3328
const CLOSE=2556
const DETAIL_PROJECT=1496
## Change_DetailView nodes.
const CARD_PANEL_BG=51440
const CARD_PANEL_DECO=50996
const DETAIL_BG=39548
const DETAIL_FX_BG=39200
const SAMPLE_PANEL=37708
const SAMPLE=38328
const INFO_PROJECT=37432
const CHANGE_GROUP=26468
const APPLY=26524
const BUTTON_GROUP=19380
const GROUP_LINES: Array[int]=[25964,25576]
const COLLECTION_BUTTON=21388
const TAB_BG=14276
const LIST=13180
const NOTICE=12616
const NOTICE_TEXT=12668
const LIST_SIZE:=Vector2(498,425)
const ROW_MARGIN: float=-4.0
const SET_PROJECTS: Array[int]=[724,444,176]
const SET_PANEL=120
## Change_Upgrade_Info_Swap nodes: [name, grade, title, option list, decor].
const INFO_CARD={"root":11952,"name":14400,"grade":14028,"title":13240,"list":12028,"decor":[13628,12792,12460]}
const INFO_DOLL={"root":5380,"name":11448,"grade":11120,"title":9064,"list":9416,"decor":[10180,9848,8308]}
const OPTION_PANEL=120
const OPTION_DESC=652
const OPTION_VALUE=172
const OPTION_HEIGHT: float=18.0
## TWILIGHT grade -> original card prefab. The 일반/고급/희귀/영웅/전설
## pairs are the client's own (Change_Card_List: Node_Common 일 반, Node_Rare
## 고 급, Node_Unique 희 귀, Node_Legend 영 웅, Node_Epic 전 설).
const GRADE_MEMBERS={"일반":"UI/Change/Change_Card_A_Common.csb","고급":"UI/Change/Change_Card_A_Rare.csb","희귀":"UI/Change/Change_Card_A_Unique.csb","영웅":"UI/Change/Change_Card_A_Legend.csb","전설":"UI/Change/Change_Card_A_Epic.csb","신화":"UI/Change/Change_Card_A_Myth.csb","유일":"UI/Change/Change_Card_A_Sole.csb"}
## Per prefab: Panel_Root, Img_Bg, Nd_Character, Sp_Card_<grade>, CardSample, CB_Check.
const CARD_NODES={
	"UI/Change/Change_Card_A_Common.csb":{"root":276,"bg":4024,"character":1928,"frame":2520,"sample":2256,"check":1244},
	"UI/Change/Change_Card_A_Rare.csb":{"root":276,"bg":4056,"character":1932,"frame":2524,"sample":2260,"check":1244},
	"UI/Change/Change_Card_A_Unique.csb":{"root":320,"bg":3104,"character":1976,"frame":2568,"sample":2304,"check":1288},
	"UI/Change/Change_Card_A_Epic.csb":{"root":320,"bg":3100,"character":1976,"frame":2568,"sample":2304,"check":1288},
	"UI/Change/Change_Card_A_Legend.csb":{"root":320,"bg":3104,"character":1976,"frame":2568,"sample":2304,"check":1288},
	"UI/Change/Change_Card_A_Myth.csb":{"root":320,"bg":3096,"character":1972,"frame":2564,"sample":2300,"check":1288},
	"UI/Change/Change_Card_A_Sole.csb":{"root":320,"bg":3128,"character":2004,"frame":2596,"sample":2332,"check":1320},
}
const MAX_CARDS: int=150
signal closed
var _pack: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _detail: Node2D
var _info: Node2D
var _content: Node2D
var _option_content: Node2D
var _category: String="변신"
var _cards: Array[Dictionary]=[]
var _card_scenes: Dictionary={}
var _selected: String=""
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	var members: Array[String]=[ROOT,DETAIL,INFO,SET,OPTION_ROW]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	for member: String in members:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_change_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func category() -> String:
	return _category

func open(parent: Node, category_name: String) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_change_window_host_unavailable")
	if category_name not in ["변신","마법인형"]:return _fail("source_change_window_category_unsupported")
	_parent=weakref(parent)
	if category_name!=_category:
		_selected=""
		_scroll=0.0
	_category=category_name
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_detail=null
	_info=null
	_content=null
	_option_content=null
	_card_scenes.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

## Owned cards of the category, highest grade first (catalog order within a grade).
func _owned_cards() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return result
	var owned: Dictionary=hud.get("card_collection_state").get("owned",{}).get(_category,{})
	var by_grade: Dictionary={}
	for raw: Variant in hud.get("catalog_data").get(_category,[]):
		if not raw is Dictionary or owned.get(Cards.card_id(raw),false)!=true:continue
		var grade: String=str(raw.get("grade",""))
		if not GRADE_MEMBERS.has(grade):continue
		if not by_grade.has(grade):by_grade[grade]=[]
		by_grade[grade].append(raw)
	var grades: Array[String]=Cards.GRADES.duplicate()
	grades.reverse()
	for grade: String in grades:
		for record: Dictionary in by_grade.get(grade,[]):
			if result.size()>=MAX_CARDS:return result
			result.append(record)
	return result

func _equipped_id() -> String:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return ""
	var equipped: Variant=hud.get("character_state").get("equipped",{}).get(_category,{})
	return Cards.card_id(equipped) if equipped is Dictionary and not equipped.is_empty() else ""

func _record(id: String) -> Dictionary:
	for record: Dictionary in _cards:
		if Cards.card_id(record)==id:return record
	return {}

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_change_window_host_unavailable")
	_cards=_owned_cards()
	var equipped: String=_equipped_id()
	if _record(_selected).is_empty():
		_selected=equipped if not _record(equipped).is_empty() else (Cards.card_id(_cards[0]) if not _cards.is_empty() else "")
	var doll: bool=_category=="마법인형"
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},
		CHANGE_ON:{"role":"button","visible":true,"activate":Callable(self,"_ignore")},
		CHANGE_OFF:{"role":"button","visible":false,"activate":Callable(self,"_ignore")},
		MIX_ON:{"role":"button","visible":false,"activate":Callable(self,"_fusion_requested")},
		MIX_OFF:{"role":"button","visible":true,"activate":Callable(self,"_fusion_requested")},
		COLLECTION_ON:{"role":"button","visible":false,"activate":Callable(self,"_collection_requested")},
		COLLECTION_OFF:{"role":"button","visible":true,"activate":Callable(self,"_collection_requested")}}
	var roots: Array[int]=[FRAME,CHANGE_ON,CHANGE_OFF,MIX_ON,MIX_OFF,COLLECTION_ON,COLLECTION_OFF,TITLE,CLOSE,DETAIL_PROJECT]
	if doll:
		# The 마법인형 window keeps the client's 마법인형 탐험 tab.
		roots.append_array([EXPLORE_ON,EXPLORE_OFF])
		bindings[EXPLORE_ON]={"role":"button","visible":false,"activate":Callable(self,"_explore_requested")}
		bindings[EXPLORE_OFF]={"role":"button","visible":true,"activate":Callable(self,"_explore_requested")}
		bindings[TITLE]={"role":"source_text","text":"마법인형"}
		for offset: int in CHANGE_LABELS:bindings[offset]={"role":"source_text","text":"마법인형"}
		for offset: int in COLLECTION_LABELS:bindings[offset]={"role":"source_text","text":"마법인형 컬렉션"}
	var page: Dictionary=_detail_bindings(equipped)
	bindings[DETAIL_PROJECT]={"role":"project","visible":true,"source_node_offsets":page.scope,"bindings":page.bindings}
	var root_scope: Array[int]=_subtree(ROOT,roots)
	_consume_touch(ROOT,root_scope,bindings)
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,root_scope,bindings)
	if not result.get("ok",false):next.free();last_result=result;return result
	var detail: Dictionary=next.project_player([DETAIL_PROJECT])
	if not detail.get("ok",false):next.free();last_result=detail;return detail
	var info: Dictionary=detail.player.project_player([INFO_PROJECT])
	if not info.get("ok",false):next.free();last_result=info;return info
	var list_node: Variant=detail.player.get("source_nodes").get(LIST)
	var content: Variant=list_node.get_meta("source_list_content",null) if is_instance_valid(list_node) else null
	var info_list: Variant=info.player.get("source_nodes").get(int((INFO_DOLL if doll else INFO_CARD).list))
	var option_content: Variant=info_list.get_meta("source_list_content",null) if is_instance_valid(info_list) else null
	if not content is Node2D or not option_content is Node2D:next.free();return _fail("source_change_window_list_content_missing")
	var geometry: Dictionary=_set_geometry()
	var card_scenes: Dictionary={}
	var pictures: int=0
	for index: int in range(_cards.size()):
		var card: Dictionary=_card(_cards[index])
		if not card.get("ok",false):continue
		if card.get("picture",false):pictures+=1
		var row: int=index/3
		var slot: Vector2=geometry.slots[index%3]
		# Rows run top-down from the list's top edge; a card's origin is its
		# Change_Card_Set ProjectNode position inside the centred row panel.
		var top: float=LIST_SIZE.y-float(row)*(geometry.row_height+ROW_MARGIN)
		card.scene.position=Vector2(geometry.row_x+slot.x,-(top-geometry.row_height+slot.y))
		content.add_child(card.scene)
		card_scenes[Cards.card_id(_cards[index])]=card.scene
	var previous: Node2D=_scene
	# Change_WinTotal is laid out on the design centre (600, 337.5).
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_detail=detail.player
	_info=info.player
	_content=content
	_option_content=option_content
	_card_scenes=card_scenes
	var rows: int=ceili(float(_cards.size())/3.0)
	_scroll_min=minf(0.0,LIST_SIZE.y-(float(rows)*(geometry.row_height+ROW_MARGIN)-ROW_MARGIN))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.y=_scroll
	var shown: Dictionary=_show_selected()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"category":_category,"cards":_cards.size(),"card_pictures":pictures,"selected":_selected,"equipped":equipped,"detail":shown}
	return last_result

## Row panel left edge and card positions from Change_Card_Set itself.
func _set_geometry() -> Dictionary:
	var tree: Dictionary=_pack.scene(SET).get("nodeTree",{})
	var panel: Dictionary=Scene._node_at_offset(tree,SET_PANEL).get("options",{}).get("widgetOptions",{})
	var size: Array=panel.get("size",[360,150])
	var slots: Array[Vector2]=[]
	for offset: int in SET_PROJECTS:
		var node: Dictionary=Scene._node_at_offset(tree,offset)
		var options: Dictionary=node.get("options",{})
		var widget: Dictionary=options.get("nodeOptions",options.get("widgetOptions",{}))
		var position: Array=widget.get("position",[0,0])
		slots.append(Vector2(float(position[0]),float(position[1])))
	# The ListView centres its items (Align_HorizontalCenter).
	return {"row_x":(LIST_SIZE.x-float(size[0]))*0.5,"row_height":float(size[1]),"slots":slots}

func _detail_bindings(equipped: String) -> Dictionary:
	var doll: bool=_category=="마법인형"
	var info_nodes: Dictionary=INFO_DOLL if doll else INFO_CARD
	var selected: Dictionary=_record(_selected)
	var applied: bool=not _selected.is_empty() and _selected==equipped
	var bindings: Dictionary={LIST:{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")},
		NOTICE:{"visible":_cards.is_empty()},NOTICE_TEXT:{"role":"static_source_text"},
		SAMPLE:{"role":"source_asset_slot","visible":false},
		APPLY:{"role":"button","displaystate":not selected.is_empty() and not applied,"activate":Callable(self,"_apply_selected")},
		COLLECTION_BUTTON:{"role":"button","activate":Callable(self,"_collection_requested")}}
	var scope: Array[int]=[CARD_PANEL_BG,CARD_PANEL_DECO,DETAIL_BG,DETAIL_FX_BG,SAMPLE_PANEL,SAMPLE,APPLY,TAB_BG,LIST,NOTICE,NOTICE_TEXT]
	scope.append_array(GROUP_LINES)
	scope.append_array(_subtree(DETAIL,[COLLECTION_BUTTON]))
	var info_scope: Array[int]=[int(info_nodes.name),int(info_nodes.grade),int(info_nodes.title),int(info_nodes.list)]
	for offset: Variant in info_nodes.decor:info_scope.append(int(offset))
	var info_bindings: Dictionary={int(info_nodes.name):{"role":"source_text","text":str(selected.get("name",""))},
		int(info_nodes.grade):{"role":"source_text","text":str(selected.get("grade",""))},
		int(info_nodes.title):{"role":"static_source_text"},
		int(info_nodes.list):{"role":"source_list","row_offsets":[],"input":Callable(self,"_ignore_input")}}
	_consume_touch(INFO,info_scope,info_bindings)
	bindings[INFO_PROJECT]={"role":"project","visible":true,"source_node_offsets":info_scope,"bindings":info_bindings}
	_consume_touch(DETAIL,scope,bindings)
	scope.append(INFO_PROJECT)
	return {"scope":scope,"bindings":bindings}

func _card(record: Dictionary) -> Dictionary:
	var member: String=GRADE_MEMBERS[str(record.grade)]
	var nodes: Dictionary=CARD_NODES[member]
	var id: String=Cards.card_id(record)
	var scope: Array[int]=[int(nodes.root),int(nodes.bg),int(nodes.character),int(nodes.frame),int(nodes.sample),int(nodes.check)]
	var bindings: Dictionary={int(nodes.root):{"input":Callable(self,"_list_input")},
		int(nodes.sample):{"role":"source_asset_slot","visible":false},
		int(nodes.check):{"role":"checkbox","selected":id==_selected,"activate":Callable(self,"_card_pressed").bind(id)}}
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,member,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	var owner: Dictionary=_picture(record,false)
	var picture: bool=false
	if owner.get("ok",false):
		var uploaded: Dictionary=scene.set_bound_source_visual_result(int(nodes.sample),owner)
		picture=uploaded.get("ok",false) and scene.set_bound_visible(int(nodes.sample),true).get("ok",false)
	scene.set_meta("source_change_card",{"id":id,"member":member,"picture":picture,"status":str(owner.get("status","")),"reason":str(owner.get("reason",""))})
	return {"ok":true,"scene":scene,"picture":picture}

## The card's own original picture: DisplayBaseAssetID on a list card, the
## illustration on the detail side (SourceCardPresentation picks the role).
static func _picture(record: Dictionary, detail_view: bool) -> Dictionary:
	var shown: Dictionary=Presentation.detail(record,true,detail_view)
	var owner: Dictionary={"ok":shown.get("status","")=="original" and shown.get("texture") is Texture2D,"status":str(shown.get("status","")),"reason":str(shown.get("reason",""))}
	if owner.ok:
		owner["texture"]=shown.texture
		owner["provenance"]=shown.get("provenance",{}).duplicate(true)
		owner["role"]=str(shown.get("role",""))
	return owner

## Detail side: illustration, name, grade and the card's option lines.
func _show_selected() -> Dictionary:
	if not is_instance_valid(_detail) or not is_instance_valid(_info):return {"ok":false}
	var record: Dictionary=_record(_selected)
	var nodes: Dictionary=INFO_DOLL if _category=="마법인형" else INFO_CARD
	_info.set_bound_text(int(nodes.name),str(record.get("name","")))
	_info.set_bound_text(int(nodes.grade),str(record.get("grade","")))
	var picture: bool=false
	var owner: Dictionary=_picture(record,true) if not record.is_empty() else {"ok":false}
	if owner.get("ok",false):
		var uploaded: Dictionary=_detail.set_bound_source_visual_result(SAMPLE,owner)
		picture=uploaded.get("ok",false) and _detail.set_bound_visible(SAMPLE,true).get("ok",false)
	else:_detail.set_bound_visible(SAMPLE,false)
	for child: Node in _option_content.get_children():
		_option_content.remove_child(child)
		child.queue_free()
	var lines: Array=record.get("sourceOptions",[]) if record.get("sourceOptions") is Array else []
	var options: int=0
	for line: Variant in lines:
		var row: Dictionary=_option_row(str(line))
		if not row.get("ok",false):continue
		# Rows run top-down from the option list's top edge.
		var list_height: float=260.0 if _category=="변신" else 230.0
		row.scene.position=Vector2(0.0,-(list_height-OPTION_HEIGHT*float(options+1)))
		_option_content.add_child(row.scene)
		options+=1
	var applied: bool=not _selected.is_empty() and _selected==_equipped_id()
	_detail.set_bound_displaystate(APPLY,not record.is_empty() and not applied)
	return {"ok":true,"selected":_selected,"illustration":picture,"illustration_status":str(owner.get("status","")),"options":options,"applied":applied}

func _option_row(line: String) -> Dictionary:
	# "SP +1" -> desc "SP", value "+1" (the row's two original labels).
	var desc: String=line
	var value: String=""
	var cut: int=line.rfind(" ")
	if cut>0 and line.substr(cut+1).left(1) in ["+","-"]:
		desc=line.left(cut)
		value=line.substr(cut+1)
	var bindings: Dictionary={OPTION_PANEL:{"role":"consume"},OPTION_DESC:{"role":"source_text","text":desc},OPTION_VALUE:{"role":"source_text","text":value,"visible":not value.is_empty()}}
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,OPTION_ROW,[OPTION_PANEL,OPTION_DESC,OPTION_VALUE],bindings)
	if not result.get("ok",false):scene.free();return result
	return {"ok":true,"scene":scene}

func _card_pressed(_checked: bool, id: String) -> Dictionary:
	if absf(_moved)>12.0:
		_sync_checks()
		return {"ok":true,"ignored_after_drag":true}
	if id==_selected:
		_sync_checks()
		return _apply_selected()
	_selected=id
	_sync_checks()
	return _show_selected()

func _sync_checks() -> void:
	for id: String in _card_scenes:
		var scene: Node2D=_card_scenes[id]
		if not is_instance_valid(scene):continue
		var info: Dictionary=scene.get_meta("source_change_card",{})
		scene.set_bound_selected_state(int(CARD_NODES[str(info.get("member",""))].check),id==_selected)

## The existing catalog equip: World._equip_catalog checks ownership, the
## original card conditions and saves; the window then shows the result.
func _apply_selected() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var record: Dictionary=_record(_selected)
	if hud==null or record.is_empty():return _fail("source_change_window_card_unselected")
	if _selected==_equipped_id():return {"ok":true,"already_applied":true,"id":_selected}
	hud.emit_signal("catalog_equip_requested",_category,record.duplicate(true))
	var shown: Dictionary=_show_selected()
	return {"ok":true,"existing_equip_requested":true,"id":_selected,"applied":shown.get("applied",false)}

func _fusion_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var target: String=_category
	close()
	if hud!=null and hud.has_method("open_card_fusion"):hud.call("open_card_fusion",target)
	return {"ok":true,"existing_fusion":true}

func _collection_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var target: String=_category
	var focus: String=_selected
	close()
	if hud!=null and hud.has_method("open_normal_card_collections"):hud.call("open_normal_card_collections",target,focus)
	return {"ok":true,"existing_collection":true}

func _explore_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	close()
	if hud!=null and hud.has_method("open_expedition"):hud.call("open_expedition")
	return {"ok":true,"existing_expedition":true}

func _ignore() -> Dictionary:
	return {"ok":true}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _ignore_input(_event: InputEvent) -> void:
	pass

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
		delta=146.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	# Dragging up (negative) reveals lower rows.
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll

## Touch-enabled original nodes in the mounted subtrees with no action of
## their own swallow their touch; labels it does not drive keep their text.
func _consume_touch(member: String, scope: Array[int], bindings: Dictionary) -> void:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	for offset: int in scope:_consume_subtree(Scene._node_at_offset(tree,offset),bindings,scope)

static func _consume_subtree(node: Dictionary, bindings: Dictionary, scope: Array[int]) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	if offset not in scope:return
	if bool(widget.get("touchEnabled",false)) and node.get("classname")!="ProjectNode":
		var binding: Dictionary=bindings.get(offset,{})
		if not binding.has("role") and not binding.has("input"):
			binding["role"]="consume"
			bindings[offset]=binding
	if node.get("classname") in ["Text","TextBMFont"] and not bindings.get(offset,{}).has("role"):
		var label: Dictionary=bindings.get(offset,{})
		label["role"]="static_source_text"
		bindings[offset]=label
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_consume_subtree(child,bindings,scope)

## A node scope keeps only the listed nodes and their ancestors: list every
## descendant of each mounted node (a nested ProjectNode keeps its own scope).
func _subtree(member: String, roots: Array[int]) -> Array[int]:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	var result: Array[int]=[]
	for offset: int in roots:_collect(Scene._node_at_offset(tree,offset),result)
	return result

static func _collect(node: Dictionary, result: Array[int]) -> void:
	if node.is_empty():return
	var offset: int=int(node.get("_offset",-1))
	if offset not in result:result.append(offset)
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_collect(child,result)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
