extends RefCounted
## The original 523 혈맹 문장 선택 popup (Clan_Popup_Symbol) for the local
## character, filled from scripts/emblem523/emblem523.gd:
##  - 이미지 문장 tab (Clan_Tab_Mark): every Korean selection-list emblem is one
##    original Clan_Mark_FlagSlot (its original Guild_* picture from the 523 UI
##    pack, its name), five per Clan_Mark_FlagSlot_Set row. A locked emblem
##    shows the original Btn_Disabled cover with its OpenGrade (혈맹 레벨).
##  - Nd_Preview: the selected emblem's picture; 확인 equips it (saved),
##    닫기 closes.
##  - 텍스트 문장 tab (Clan_Tab_Mark_Request): typed clan text marks have no
##    table rows and are online clan data; the tab is not connected.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Emblems=preload("res://scripts/emblem523/emblem523.gd")
const ROOT="UI/Clan/Clan_Popup_Symbol.csb"
const TAB="UI/Clan/Clan_Tab_Mark.csb"
const SET="UI/Clan/Clan_Mark_FlagSlot_Set.csb"
const SLOT="UI/Clan/Clan_Mark_FlagSlot.csb"
const REQUIRED: Array[String]=[ROOT,TAB,SET,SLOT]
const PER_ROW: int=5
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _content: Node2D
var _selected: int=0
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var last_result: Dictionary={}
var last_choice: Dictionary={}
var _list_size: Vector2=Vector2.ZERO
var _row_height: float=146.0
var _total_rows: int=0
var _built_rows: int=0
var _pictures: int=0

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_emblem_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func _runtime() -> Object:
	var world: Object=_world.get_ref() if _world!=null else null
	return world.get("emblem523") if world!=null else null

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world) or world.get("emblem523")==null:return _fail("source_emblem_window_host_unavailable")
	var data: Dictionary=Emblems.definition()
	if not data.get("ok",false):return {"ok":false,"handled":false,"code":"source_emblem_rows_unavailable","problem":str(data.get("problem",""))}
	_parent=weakref(parent)
	_world=weakref(world)
	_selected=int(world.emblem523.emblem_id)
	if not data.by_id.has(_selected):_selected=0
	_scroll=0.0
	return _stage()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func selected() -> int:
	return _selected

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var runtime: Object=_runtime()
	if parent==null or runtime==null:return _fail("source_emblem_window_host_unavailable")
	var data: Dictionary=Emblems.definition()
	var options: Array=data.options
	var spec: Dictionary={
		"Btn_Confirm":{"activate":Callable(self,"_confirm")},
		"Btn_Cancel":{"activate":Callable(self,"_close_requested")},
		"Clan_Tab_Mark_Request":{"exclude":true},
		"Btn_Mark_On":{"visible":true},"Btn_Mark_Off":{"visible":false},
		"Btn_Request_On":{"visible":false},"Btn_Request_Off":{"visible":true,"activate":Callable(self,"_text_tab")},
		"Clan_Tab_Mark/ListView_List":{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")},
		"Nd_Preview/Icn_Mark_Dummy":{"role":"source_asset_slot","visible":false},
	}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var list: Dictionary=NamedTree.locate(next,out,"Clan_Tab_Mark/ListView_List")
	var list_node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=list_node.get_meta("source_list_content",null) if is_instance_valid(list_node) else null
	if not content is Node2D:
		next.free()
		return _fail("source_emblem_window_list_content_missing")
	var list_size: Vector2=NamedTree.list_size(out,_pack,TAB,"ListView_List")
	var selectable: int=0
	var host: Object=_world.get_ref() if _world!=null else null
	for option: Dictionary in options:
		if Emblems.option_selectable(host,option):selectable+=1
	_list_size=list_size
	_row_height=float(_tree.row_panel(SET).size[1])
	_total_rows=ceili(float(options.size())/float(PER_ROW))
	_built_rows=0
	_pictures=0
	_content=content
	var height: float=_row_height*float(_total_rows)
	_scroll_min=minf(0.0,list_size.y-height)
	_scroll=clampf(_scroll,_scroll_min,0.0)
	var built_rows: Dictionary=_build_visible_rows()
	if not built_rows.get("ok",false):
		next.free()
		_content=null
		last_result=built_rows
		return built_rows
	var preview: bool=false
	if _selected>0:preview=_picture(next,out,"Nd_Preview/Icn_Mark_Dummy",str(data.by_id[_selected].large))
	var previous: Node2D=_scene
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	content.position.y=_scroll
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"emblems":options.size(),"rows":_total_rows,"rows_built":_built_rows,"pictures":_pictures,"selectable":selectable,"selected":_selected,"equipped":int(runtime.emblem_id),"preview":preview}
	return last_result

## Rows are built when they scroll into view (all 60 at once cost seconds).
func _build_visible_rows() -> Dictionary:
	var options: Array=Emblems.definition().get("options",[])
	var wanted: int=mini(_total_rows,ceili((_list_size.y-_scroll)/_row_height)+1)
	while _built_rows<wanted:
		var index: int=_built_rows*PER_ROW
		var row_spec: Dictionary={"Panel_Set":{"input":Callable(self,"_list_input")}}
		for side: int in range(PER_ROW):
			var key: String="Clan_Mark_FlagSlot_%d/Panel/" % (side+1)
			if index+side>=options.size():
				row_spec["Clan_Mark_FlagSlot_%d" % (side+1)]={"visible":false}
				continue
			var option: Dictionary=options[index+side]
			var id: int=int(option.id)
			var open: bool=Emblems.option_selectable(_world.get_ref() if _world!=null else null,option)
			row_spec["Clan_Mark_FlagSlot_%d/Panel" % (side+1)]={"input":Callable(self,"_list_input")}
			row_spec[key+"Icn_Mark_Dummy"]={"role":"source_asset_slot","visible":false}
			row_spec[key+"Label_Name"]={"role":"source_text","text":str(option.name)}
			row_spec[key+"Btn_Normal"]={"visible":open and id!=_selected,"activate":Callable(self,"_slot_pressed").bind(id)}
			row_spec[key+"Btn_Pressed"]={"visible":id==_selected,"activate":Callable(self,"_slot_pressed").bind(id)}
			row_spec[key+"Btn_Disabled"]={"visible":not open,"activate":Callable(self,"_slot_pressed").bind(id)}
			row_spec[key+"Btn_Disabled/Label_Help"]={"role":"source_text","text":str(int(option.open_grade))}
			row_spec[key+"Btn_Disabled/Label_Lock_Alliance"]={"visible":false}
		var row_out: Dictionary={}
		var built_row: Dictionary=_tree.scene_of(SET,row_spec,row_out)
		if not built_row.get("ok",false):return built_row
		for side: int in range(PER_ROW):
			if index+side>=options.size():continue
			if _picture(built_row.scene,row_out,"Clan_Mark_FlagSlot_%d/Panel/Icn_Mark_Dummy" % (side+1),str(options[index+side].large)):_pictures+=1
		_tree.add_row(_content,SET,built_row.scene,_built_rows,_list_size)
		_built_rows+=1
	return {"ok":true,"rows_built":_built_rows}

func _picture(root: Node2D, out: Dictionary, suffix: String, path: String) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var owner: Dictionary=NamedTree.pack_picture(_pack,path)
	if not owner.get("ok",false):return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

func _message(text: String) -> void:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",text)

func _slot_pressed(id: int) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	var option: Dictionary=Emblems.definition().get("by_id",{}).get(id,{})
	if option.is_empty():return _fail("source_emblem_unknown")
	if not Emblems.option_selectable(_world.get_ref() if _world!=null else null,option):
		var reason: String="혈맹 레벨 %d에 열리는 문장입니다 · 현재 %d" % [int(option.open_grade),Emblems.grade_for(_world.get_ref() if _world!=null else null)] if option.type=="Predefined" else "혈맹 전용 문장(%s)입니다 · 로컬 선택 불가" % str(option.type)
		_message(reason)
		return {"ok":false,"locked":true,"reason":reason}
	_selected=id
	var kept: float=_scroll
	var staged: Dictionary=_stage()
	_scroll=kept
	if is_instance_valid(_content):_content.position.y=clampf(_scroll,_scroll_min,0.0)
	return staged

func _confirm() -> Dictionary:
	var runtime: Object=_runtime()
	var world: Object=_world.get_ref() if _world!=null else null
	if runtime==null:return _fail("source_emblem_window_host_unavailable")
	var result: Dictionary=runtime.choose(world,_selected)
	last_choice=result
	if result.get("ok",false):
		var option: Dictionary=Emblems.definition().get("by_id",{}).get(_selected,{})
		_message("문장 장착: "+str(option.get("name","")) if _selected>0 else "문장 해제")
		return _stage()
	_message(str(result.get("error","문장 장착 실패")))
	return result

func _text_tab() -> Dictionary:
	_message("텍스트 문장은 혈맹(온라인) 전용이며 원본 표에 행이 없어 연결하지 않았습니다")
	return {"ok":false,"online_only":true}

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
	scroll_by(delta)

func scroll_by(delta: float) -> void:
	if not is_instance_valid(_content):return
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll
	_build_visible_rows()

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
