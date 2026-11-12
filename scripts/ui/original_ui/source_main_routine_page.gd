extends RefCounted
## The original 523 quest window's 미션 tab (Quest_All ProjectNode 1000 =
## Quest_Tab_Mission): the mission type buttons (Quest_List_Button), the
## mission rows (Quest_List_Mission_Progress / _Reward / _Complete), the
## "미션 달성" bonus bar (Nd_Achieve) and 모두 받기. Every rule, count, reset and
## reward stays in world.routines (scripts/routine523); this file only mounts
## original nodes and routes their buttons.
## Not connected (reported): the row 바로 가기 button (the missions' RoutineView
## TeleportTerritoriesID is 0: no destination in the tables).
const RoutineTree=preload("res://scripts/ui/original_ui/source_main_routine_tree.gd")
const SRC=preload("res://scripts/routine523/routine523_source.gd")
const TAB_MISSION="UI/Quest/Quest_Tab_Mission.csb"
const ROW_PROGRESS="UI/Quest/Quest_List_Mission_Progress.csb"
const ROW_REWARD="UI/Quest/Quest_List_Mission_Reward.csb"
const ROW_COMPLETE="UI/Quest/Quest_List_Mission_Complete.csb"
const ROW_BUTTON="UI/Quest/Quest_List_Button.csb"
const REQUIRED: Array[String]=[TAB_MISSION,ROW_PROGRESS,ROW_REWARD,ROW_COMPLETE,ROW_BUTTON]
## Quest_All ProjectNode of Quest_Tab_Mission.
const PROJECT=1000
const P=""
const ROW_HEIGHT: float=80.0
var _tree: RefCounted
var _world: WeakRef
var _refresh: Callable
var _type: int=4
var _content: Node2D
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node, refresh: Callable) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"code":"source_routine_page_member_missing","member":member}
	_tree=RoutineTree.new(pack,hud)
	_refresh=refresh
	return {"ok":true}

func _runtime() -> Object:
	var world: Object=_world.get_ref() if _world!=null else null
	return world.get("routines") if world!=null else null

## {binding} of ProjectNode 1000 for Quest_All, filling `out` with node keys.
func project_binding(world: Node, out: Dictionary) -> Dictionary:
	_world=weakref(world)
	var runtime: Object=_runtime()
	var spec: Dictionary={}
	var c: Dictionary=runtime.contract() if runtime!=null else {}
	var available: bool=runtime!=null and c.get("ok",false)
	var rows: Array[Dictionary]=runtime.missions_of(_type) if available else []
	var receivable: bool=false
	for row: Dictionary in rows:
		if row.status=="receivable":receivable=true
	# Nd_Achieve: the MissionComplete routine counting this type (none for
	# MissionWorldWeekly).
	var complete_id: int=int(c.get("complete_by_type",{}).get(_type,0)) if available else 0
	var complete: Dictionary=runtime.view(complete_id) if complete_id>0 else {}
	spec[P+"Nd_Achieve"]={"visible":not complete.is_empty()}
	if not complete.is_empty():
		var amount: int=maxi(1,int(complete.amount))
		spec[P+"Nd_Achieve/Label"]={"role":"source_text","text":"%s(%d/%d)" % [str(complete.title),int(complete.progress),int(complete.amount)]}
		spec[P+"Nd_Achieve/Gauge"]={"role":"source_percent","percent":100.0*float(complete.progress)/float(amount)}
		var can: bool=complete.status=="receivable"
		spec[P+"Nd_Achieve/Button"]={"activate":Callable(self,"_claim").bind(complete_id),"displaystate":can}
		spec[P+"Nd_Achieve/Button/Label_Normal"]={"visible":can}
		spec[P+"Nd_Achieve/Button/Label_Disabled"]={"visible":not can}
		_slot_spec(spec,P+"Nd_Achieve/Common_Slim_ItemSlot/",complete.rewards)
	spec[P+"Nd_List/ListView"]={"input":Callable(self,"_list_input")}
	spec[P+"Nd_Notice"]={"visible":rows.is_empty()}
	if rows.is_empty():
		spec[P+"Nd_Notice/Text_Info"]={"role":"source_text","text":str(c.get("problem","")) if not available and runtime!=null else "진행 중인 퀘스트가 없습니다."}
	spec[P+"Btn_All_Receive"]={"activate":Callable(self,"_claim_all"),"displaystate":receivable}
	spec[P+"Btn_All_Receive/Normal"]={"visible":receivable}
	spec[P+"Btn_All_Receive/Disabled"]={"visible":not receivable}
	var bound: Dictionary=_tree.bind(TAB_MISSION,"",[PROJECT],spec,out)
	last_result={"type":_type,"rows":rows.size(),"receivable":receivable,"complete_id":complete_id}
	return {"ok":true,"binding":{"role":"project","visible":true,"source_node_offsets":bound.scope,"bindings":bound.bindings},"rows":rows,"complete":complete}

## Reward slot of Common_Slot: original picture (item) and amount.
func _slot_spec(spec: Dictionary, prefix: String, rewards: Array) -> void:
	var first: Dictionary=rewards[0] if not rewards.is_empty() else {}
	spec[prefix+"Btn"]={"displaystate":false}
	spec[prefix+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec[prefix+"Text_Amount"]={"role":"source_text","text":str(int(first.get("amount",0))),"visible":not first.is_empty()}

## Fills the type buttons, the mission rows and the reward pictures.
func fill(root: Node2D, out: Dictionary, staged: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var c: Dictionary=runtime.contract() if runtime!=null else {}
	var pictures: int=0
	if not staged.complete.is_empty() and _reward_picture(root,out,"Nd_Achieve/Common_Slim_ItemSlot/Sp_IconSample",staged.complete.rewards):pictures+=1
	# Mission type buttons.
	var buttons: Dictionary=_tree.list_content(root,out,TAB_MISSION,"Nd_Button/ListView")
	if not buttons.get("ok",false):return buttons
	var types: Array[int]=SRC.TYPE_ORDER if c.get("ok",false) else []
	for index: int in range(types.size()):
		var type_id: int=types[index]
		var on: bool=type_id==_type
		var label: String=str(c.get("type_labels",{}).get(type_id,""))
		var waiting: bool=false
		for id: int in c.by_type.get(type_id,[]):
			if runtime.receivable(id):waiting=true
		for id: int in c.by_type.get(SRC.COMPLETE_TYPE,[]):
			if int(c.missions[id].get("counts_type",0))==type_id and runtime.receivable(id):waiting=true
		var spec: Dictionary={"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_select_type").bind(type_id)},"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_select_type").bind(type_id)},"Btn_Normal/Label":{"role":"source_text","text":label},"Btn_Pressed/Label":{"role":"source_text","text":label},"Panel/Sp_Lock":{"visible":false},"Panel/Sprite_New":{"visible":waiting},"Panel/Sp_Event":{"visible":false}}
		var built: Dictionary=_tree.scene_of(ROW_BUTTON,spec,{})
		if not built.get("ok",false):return built
		_tree.add_row(buttons.content,ROW_BUTTON,built.scene,index,buttons.size,0.0)
	# Mission rows: receivable first, then in progress, then received.
	var list: Dictionary=_tree.list_content(root,out,TAB_MISSION,"Nd_List/ListView")
	if not list.get("ok",false):return list
	var ordered: Array[Dictionary]=[]
	for status: Array in [["receivable"],["progress","refused"],["claimed"]]:
		for row: Dictionary in staged.rows:
			if row.status in status:ordered.append(row)
	for index: int in range(ordered.size()):
		var row: Dictionary=ordered[index]
		var member: String=ROW_COMPLETE if row.status=="claimed" else (ROW_REWARD if row.status=="receivable" else ROW_PROGRESS)
		var amount: int=maxi(1,int(row.amount))
		var goal: String=str(row.goal_text) if not str(row.goal_text).is_empty() else str(row.scenario)
		var detail: String="%s (%d/%d)" % [goal,int(row.progress),int(row.amount)] if int(row.amount)>0 else "%s · 목표 미연결" % goal
		var blessing: int=0
		for reward: Dictionary in row.rewards:
			if reward.kind=="blessing":blessing+=int(reward.amount)
		if blessing>0:detail+=" · 아인하사드의 축복 %d" % blessing
		var spec: Dictionary={"Panel/Label":{"role":"source_text","text":str(row.title) if not str(row.title).is_empty() else str(row.scenario)},"Panel/Label_1":{"role":"source_text","text":detail},"Panel/Gauge":{"role":"source_percent","percent":100.0*float(row.progress)/float(amount)},"Panel":{"input":Callable(self,"_list_input")}}
		_slot_spec(spec,"Common_Slim_ItemSlot/",row.rewards.filter(func(r: Dictionary) -> bool: return r.kind=="item"))
		match member:
			ROW_PROGRESS:
				spec["Panel/Label_Progress"]={"role":"source_text","text":"진행 중" if row.status=="progress" else "보류"}
				spec["Panel/Button_Into"]={"visible":false}
			ROW_REWARD:
				spec["Panel/Button"]={"activate":Callable(self,"_claim").bind(int(row.id))}
				spec["Panel/Sprite_New"]={"visible":true}
		var built: Dictionary=_tree.scene_of(member,spec,{})
		if not built.get("ok",false):return built
		var row_out: Dictionary={}
		_tree.bind(member,"",[],{},row_out)
		if _reward_picture(built.scene,row_out,"Common_Slim_ItemSlot/Sp_IconSample",row.rewards):pictures+=1
		_tree.add_row(list.content,member,built.scene,index,list.size,0.0)
	_content=list.content
	_scroll_min=minf(0.0,list.size.y-ROW_HEIGHT*float(ordered.size()))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	_content.position.y=_scroll
	return {"ok":true,"type":_type,"rows":ordered.size(),"buttons":types.size(),"pictures":pictures}

func _reward_picture(root: Node2D, out: Dictionary, suffix: String, rewards: Array) -> bool:
	var world: Object=_world.get_ref() if _world!=null else null
	if world==null:return false
	for reward: Dictionary in rewards:
		if reward.kind!="item":continue
		var record: Dictionary=world._catalog_item_from_source_id("m523:item:%d" % int(reward.item_class_id))
		var located: Dictionary=RoutineTree.locate(root,out,suffix)
		return located.get("ok",false) and _tree.picture(located.player,located.offset,record)
	return false

func _select_type(type_id: int) -> Dictionary:
	_type=type_id
	_scroll=0.0
	if _refresh.is_valid():_refresh.call()
	return {"ok":true,"type":type_id}

func _claim(id: int) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return {"ok":false}
	var result: Dictionary=runtime.claim(id)
	_report(result)
	if _refresh.is_valid():_refresh.call()
	return result

func _claim_all() -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return {"ok":false}
	var result: Dictionary=runtime.claim_all(_type)
	_report(result)
	if _refresh.is_valid():_refresh.call()
	return result

func _report(result: Dictionary) -> void:
	var hud: Object=_tree.hud.get_ref() if _tree!=null and _tree.hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.show_message(str(result.get("detail","")) if result.get("ok",false) else str(result.get("error","")))

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=ROW_HEIGHT*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll
