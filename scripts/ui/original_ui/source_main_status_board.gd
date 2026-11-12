extends RefCounted
## The original 523 콘텐츠 현황판 (할 일 목록): StatusBoard_All with its daily and
## weekly boards (StatusBoard_List_Contents rows), the 추천/직접 mode buttons
## and the contents setting view (StatusBoard_List_Type categories,
## StatusBoard_List_Contents_Setting entries, StatusBoard_List_Select
## registered slots, reset, 이벤트 컨텐츠 자동 등록). Entries, filters, limits
## and progress stay in world.routines (scripts/routine523); this file only
## mounts original nodes and routes their buttons.
## Not connected (reported): the category icon / board pictures (ToDoList
## UICategory AssetView files are not in the UI pack scope), the 바로 가기
## (Btn_Move) shortcuts, the 계정/서버 badges and the time-charge bar.
const RoutineTree=preload("res://scripts/ui/original_ui/source_main_routine_tree.gd")
const ROOT="UI/FloatingUi/StatusBoard_All.csb"
const ROW_CONTENTS="UI/FloatingUi/StatusBoard_List_Contents.csb"
const ROW_TYPE="UI/FloatingUi/StatusBoard_List_Type.csb"
const ROW_SETTING="UI/FloatingUi/StatusBoard_List_Contents_Setting.csb"
const ROW_SELECT="UI/FloatingUi/StatusBoard_List_Select.csb"
const REQUIRED: Array[String]=[ROOT,ROW_CONTENTS,ROW_TYPE,ROW_SETTING,ROW_SELECT]
const B="Nd_StatusBoard/"
## Daily / weekly board nodes (Nd_Weak is the original node name).
const BOARDS={"daily":"Nd_Contents_Info/Nd_Day","weekly":"Nd_Contents_Info/Nd_Weak"}
const RESET_LABELS={"daily":"일일","weekly":"주간"}
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _view: String="info"
var _reset: String="daily"
var _category: int=0
## ListView scroll state by list suffix: {content, min, value}.
var _scrolls: Dictionary={}
var _drag: bool=false
var last_result: Dictionary={}
## Node keys of the mounted window (tests and input probes).
var last_out: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_status_board_member_missing","member":member}
	_pack=pack
	_tree=RoutineTree.new(pack,hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world) or world.get("routines")==null:return _fail("source_status_board_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_view="info"
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func blocks_point(_point: Vector2) -> bool:
	return is_open()

func _runtime() -> Object:
	var world: Object=_world.get_ref() if _world!=null else null
	return world.get("routines") if world!=null else null

## The Clan category is online-only content (out of TWILIGHT's scope).
func _categories(runtime: Object) -> Array:
	var result: Array=[]
	for category: Dictionary in runtime.contract().get("todo",{}).get("categories",[]):
		if str(category.name)!="Clan":result.append(category)
	return result

func _offline(runtime: Object, entry: Dictionary) -> bool:
	return runtime.todo_offline(entry)

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var runtime: Object=_runtime()
	if parent==null or runtime==null:return _fail("source_status_board_host_unavailable")
	var available: bool=runtime.available()
	var custom: bool=str(runtime.state.todo.mode)=="custom"
	var spec: Dictionary={}
	spec[B+"Nd_Contents_Info"]={"visible":_view=="info"}
	spec[B+"Nd_Contents_Setting"]={"visible":_view=="setting"}
	spec[B+"Btn_Close"]={"visible":_view=="info","activate":Callable(self,"_close_requested")}
	spec[B+"Btn_Back"]={"visible":_view=="setting","activate":Callable(self,"_back")}
	spec[B+"Nd_ModeChange"]={"visible":_view=="info"}
	spec[B+"Nd_ModeChange/Btn_Recommend"]={"visible":not custom,"activate":Callable(self,"_set_mode").bind("custom")}
	spec[B+"Nd_ModeChange/Btn_Custom"]={"visible":custom,"activate":Callable(self,"_set_mode").bind("recommend")}
	spec[B+"Nd_ModeChange/Fx_Click_Recommend"]={"visible":false}
	spec[B+"Nd_ModeChange/Fx_Click_Custom"]={"visible":false}
	var boards: Dictionary={}
	for reset: String in BOARDS:
		var rows: Array=[]
		if available:
			for row: Dictionary in runtime.todo_board(reset):
				if _offline(runtime,row.entry):rows.append(row)
		boards[reset]=rows
		var node: String=B+BOARDS[reset]
		spec[node+"/Nd_Title/Btn_Setting"]={"visible":custom and available,"activate":Callable(self,"_open_setting").bind(reset)}
		spec[node+"/Btn_Setting"]={"visible":custom and available,"activate":Callable(self,"_open_setting").bind(reset)}
		spec[node+"/Label_Notice"]={"visible":rows.is_empty()}
		if not available:spec[node+"/Label_Notice"]["role"]="source_text"
		if not available:spec[node+"/Label_Notice"]["text"]=str(runtime.contract().get("problem",""))
	if _view=="setting":_setting_spec(runtime,spec)
	for suffix: String in [BOARDS.daily+"/ListView",BOARDS.weekly+"/ListView","Nd_Contents_Setting/Nd_List/ListView","Nd_List_Select/ListView","Nd_Type/ListView"]:
		spec[suffix]={"input":Callable(self,"_list_input").bind(suffix)}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var filled: Dictionary={"ok":true}
	if _view=="info":filled=_fill_info(next,out,boards)
	else:filled=_fill_setting(next,out,runtime)
	if not filled.get("ok",false):
		next.free()
		last_result=filled
		return filled
	var previous: Node2D=_scene
	# StatusBoard_All is authored around the design centre (600, 337.5).
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"view":_view,"mode":str(runtime.state.todo.mode),"filled":filled}
	return last_result

## Common row parts: names from the original rows, sample art hidden.
static func _entry_spec(spec: Dictionary, prefix: String, entry: Dictionary) -> void:
	spec[prefix+"Label_Type"]={"role":"source_text","text":str(entry.sub_name)}
	spec[prefix+"Label_Name"]={"role":"source_text","text":str(entry.text)}
	spec[prefix+"Img_Sample"]={"visible":false}
	spec[prefix+"Img_Account"]={"visible":false}
	spec[prefix+"Img_Server"]={"visible":false}
	spec["Nd_Icn/Sp_Glow"]={"visible":false}
	spec["Nd_Icn/Sp_Icn"]={"visible":false}
	spec["Nd_Icn/Sp_Event"]={"visible":bool(entry.is_event)}

func _fill_info(root: Node2D, out: Dictionary, boards: Dictionary) -> Dictionary:
	var placed: Dictionary={}
	for reset: String in BOARDS:
		var list: Dictionary=_tree.list_content(root,out,ROOT,BOARDS[reset]+"/ListView")
		if not list.get("ok",false):return list
		var rows: Array=boards[reset]
		var done: int=0
		for index: int in range(rows.size()):
			var entry: Dictionary=rows[index].entry
			var status: Dictionary=rows[index].status
			var spec: Dictionary={}
			_entry_spec(spec,"Panel/",entry)
			var known: bool=bool(status.get("known",false))
			spec["Nd_Time/Nd_Timebar"]={"visible":false}
			spec["Nd_Time/Label_Num"]={"role":"source_text","text":"%d / %d" % [int(status.current),int(status.total)] if known else "","visible":known}
			spec["Panel/Btn_Move"]={"visible":false}
			spec["Panel/Nd_Clear"]={"visible":known and bool(status.done)}
			spec["Panel/Nd_Lock"]={"visible":false}
			if known and bool(status.done):done+=1
			spec["Panel"]={"input":Callable(self,"_list_input").bind(BOARDS[reset]+"/ListView")}
			var built: Dictionary=_tree.scene_of(ROW_CONTENTS,spec,{})
			if not built.get("ok",false):return built
			_tree.add_row(list.content,ROW_CONTENTS,built.scene,index,list.size,2.0)
		_scroll_setup(BOARDS[reset]+"/ListView",list,ROW_CONTENTS,rows.size(),2.0)
		placed[reset]={"rows":rows.size(),"done":done}
	return {"ok":true,"boards":placed}

func _setting_spec(runtime: Object, spec: Dictionary) -> void:
	var registered: Array=runtime.state.todo.custom.get(_reset,[])
	var s: String=B+"Nd_Contents_Setting/"
	spec[s+"Nd_List_Select/Nd_Title/Label"]={"role":"source_text","text":"등록된 %s 컨텐츠 (%d/%d)" % [RESET_LABELS[_reset],registered.size(),runtime.todo_limit()]}
	var can_reset: bool=not registered.is_empty()
	spec[s+"Nd_List_Select/Btn_Reset"]={"activate":Callable(self,"_reset_list"),"displaystate":can_reset}
	spec[s+"Nd_List_Select/Btn_Reset/Normal"]={"visible":can_reset}
	spec[s+"Nd_List_Select/Btn_Reset/Disabled"]={"visible":not can_reset}
	var auto: bool=bool(runtime.state.todo.event_auto)
	spec[s+"Nd_Event_Check/Nd_CheckBox/Btn_Off"]={"visible":not auto,"activate":Callable(self,"_set_event_auto").bind(true)}
	spec[s+"Nd_Event_Check/Nd_CheckBox/Btn_On"]={"visible":auto,"activate":Callable(self,"_set_event_auto").bind(false)}

func _fill_setting(root: Node2D, out: Dictionary, runtime: Object) -> Dictionary:
	var categories: Array=_categories(runtime)
	var ids: Array=categories.map(func(c: Dictionary) -> int: return int(c.id))
	if _category not in ids and not ids.is_empty():_category=int(ids[0])
	var types: Dictionary=_tree.list_content(root,out,ROOT,"Nd_Type/ListView")
	if not types.get("ok",false):return types
	for index: int in range(categories.size()):
		var category: Dictionary=categories[index]
		var on: bool=int(category.id)==_category
		var spec: Dictionary={"Panel_Type/Btn_Normal":{"visible":not on,"activate":Callable(self,"_select_category").bind(int(category.id))},"Panel_Type/Btn_Pressed":{"visible":on,"activate":Callable(self,"_select_category").bind(int(category.id))},"Btn_Normal/Label":{"role":"source_text","text":str(category.name)},"Btn_Pressed/Label":{"role":"source_text","text":str(category.name)},"Btn_Normal/Sp_Icon":{"visible":false},"Btn_Pressed/Sp_Icon":{"visible":false}}
		var built: Dictionary=_tree.scene_of(ROW_TYPE,spec,{})
		if not built.get("ok",false):return built
		_tree.add_row(types.content,ROW_TYPE,built.scene,index,types.size,2.0)
	var list: Dictionary=_tree.list_content(root,out,ROOT,"Nd_Contents_Setting/Nd_List/ListView")
	if not list.get("ok",false):return list
	var catalog: Array[Dictionary]=[]
	for row: Dictionary in runtime.todo_catalog(_reset,_category):
		if _offline(runtime,row.entry):catalog.append(row)
	for index: int in range(catalog.size()):
		var row: Dictionary=catalog[index]
		var spec: Dictionary={}
		_entry_spec(spec,"Panel/",row.entry)
		spec["Panel/Nd_Select"]={"visible":true}
		spec["Nd_Select/Img_Select"]={"visible":bool(row.registered)}
		spec["Nd_Select/Fx_Glow"]={"visible":false}
		spec["Nd_Select/Panel_Mask"]={"visible":false}
		spec["Nd_Select/Btn_Select"]={"activate":Callable(self,"_toggle").bind(int(row.entry.id))}
		spec["Panel/Nd_Dimmed"]={"visible":false}
		spec["Panel/Nd_Lock"]={"visible":not bool(row.open)}
		spec["Nd_Lock/Label_Condition"]={"role":"source_text","text":"최소 레벨 : Lv %d" % int(row.lock_level)}
		spec["Panel"]={"input":Callable(self,"_list_input").bind("Nd_Contents_Setting/Nd_List/ListView")}
		var built: Dictionary=_tree.scene_of(ROW_SETTING,spec,{})
		if not built.get("ok",false):return built
		_tree.add_row(list.content,ROW_SETTING,built.scene,index,list.size,2.0)
	_scroll_setup("Nd_Contents_Setting/Nd_List/ListView",list,ROW_SETTING,catalog.size(),2.0)
	var chosen: Dictionary=_tree.list_content(root,out,ROOT,"Nd_List_Select/ListView")
	if not chosen.get("ok",false):return chosen
	var registered: Array=runtime.state.todo.custom.get(_reset,[])
	var entries: Dictionary=runtime.contract().get("todo",{}).get("entries",{})
	var slots: int=mini(runtime.todo_limit(),registered.size()+1)
	for index: int in range(slots):
		var spec: Dictionary={"Panel/Panel_Disabled":{"visible":false},"Panel/Fx_Off_Loop":{"visible":false},"Nd_Select/Img_Select":{"visible":false},"Nd_Select/Fx_Glow":{"visible":false},"Nd_Select/Panel_Mask":{"visible":false}}
		var filled: bool=index<registered.size() and entries.has(int(registered[index]))
		spec["Panel/Panel_Empty"]={"visible":not filled}
		spec["Panel/Panel_Normal"]={"visible":filled}
		spec["Panel_Empty/Label_Num"]={"role":"source_text","text":str(index+1)}
		spec["Panel_Normal/Label_Num"]={"role":"source_text","text":str(index+1)}
		spec["Panel_Empty/Img_Select"]={"visible":false}
		if filled:
			_entry_spec(spec,"Panel_Normal/",entries[int(registered[index])])
			spec["Nd_Select/Btn_Select"]={"activate":Callable(self,"_toggle").bind(int(registered[index]))}
		else:
			spec["Panel_Normal/Label_Name"]={"role":"source_text","text":""}
			spec["Panel_Normal/Label_Type"]={"role":"source_text","text":""}
		spec["Panel"]={"input":Callable(self,"_list_input").bind("Nd_List_Select/ListView")}
		var built: Dictionary=_tree.scene_of(ROW_SELECT,spec,{})
		if not built.get("ok",false):return built
		_tree.add_row(chosen.content,ROW_SELECT,built.scene,index,chosen.size,2.0)
	_scroll_setup("Nd_List_Select/ListView",chosen,ROW_SELECT,slots,2.0)
	return {"ok":true,"reset":_reset,"category":_category,"catalog":catalog.size(),"registered":registered.size()}

## Scroll range of one filled list (rows top-down, content moves up).
func _scroll_setup(suffix: String, list: Dictionary, member: String, rows: int, gap: float) -> void:
	var panel: Array=(_pack.scene(member).get("nodeTree",{}).get("children",[]) as Array)
	var height: float=float(panel[0].get("options",{}).get("widgetOptions",{}).get("size",[0,0])[1]) if not panel.is_empty() else 0.0
	var minimum: float=minf(0.0,float(list.size.y)-(height+gap)*float(rows))
	var value: float=clampf(float(_scrolls.get(suffix,{}).get("value",0.0)),minimum,0.0)
	var base: float=(list.content as Node2D).position.y
	_scrolls[suffix]={"content":list.content,"min":minimum,"value":value,"step":height+gap,"base":base}
	(list.content as Node2D).position.y=base+value

func _list_input(event: InputEvent, suffix: String) -> void:
	var entry: Dictionary=_scrolls.get(suffix,{})
	var content: Variant=entry.get("content")
	if not content is Node2D or not is_instance_valid(content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=float(entry.step)*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	entry.value=clampf(float(entry.value)+delta,float(entry.min),0.0)
	content.position.y=float(entry.base)+float(entry.value)

func _report(result: Dictionary) -> void:
	var hud: Object=_tree.hud.get_ref() if _tree.hud!=null else null
	if hud!=null and hud.has_method("show_message") and not result.get("ok",false):hud.show_message(str(result.get("error","")))

func _set_mode(mode: String) -> Dictionary:
	var result: Dictionary=_runtime().todo_set_mode(mode)
	_report(result)
	_stage()
	return result

func _open_setting(reset: String) -> Dictionary:
	_view="setting"
	_reset=reset
	_stage()
	return {"ok":true,"reset":reset}

func _back() -> Dictionary:
	_view="info"
	_stage()
	return {"ok":true}

func _select_category(category: int) -> Dictionary:
	_category=category
	_stage()
	return {"ok":true,"category":category}

func _toggle(id: int) -> Dictionary:
	var result: Dictionary=_runtime().todo_register(id)
	_report(result)
	_stage()
	return result

func _reset_list() -> Dictionary:
	var result: Dictionary=_runtime().todo_reset(_reset)
	_stage()
	return result

func _set_event_auto(on: bool) -> Dictionary:
	var result: Dictionary=_runtime().todo_set_event_auto(on)
	_stage()
	return result

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
