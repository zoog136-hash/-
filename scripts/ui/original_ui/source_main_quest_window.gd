extends RefCounted
## The original 523 quest window: Quest_All (frame, tabs, title, close) with
## its Quest_Tab_Main page. The quest list is one original row scene per quest
## (Quest_List_Reward when it can be received, Quest_List_Progress while it is
## not yet available, Quest_List_Complete when done) stacked in the page's
## ListView, the way the client fills it. The detail side shows the selected
## quest's goals, story and original reward slots (Quest_Slot_Set).
## quest_service and the World claim handler keep every rule, reward and save.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const InventoryImages=preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const RoutinePage=preload("res://scripts/ui/original_ui/source_main_routine_page.gd")
const ROOT="UI/Quest/Quest_All.csb"
const TAB_MAIN="UI/Quest/Quest_Tab_Main.csb"
const ROW_REWARD="UI/Quest/Quest_List_Reward.csb"
const ROW_PROGRESS="UI/Quest/Quest_List_Progress.csb"
const ROW_COMPLETE="UI/Quest/Quest_List_Complete.csb"
const SLOT_SET="UI/Quest/Quest_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MAIN_PROJECT=1728
const CLOSE=2412
const TITLE=3176
const ROOT_SCOPE: Array[int]=[32064,31608,28632,26500,25048,22696,21288,18928,17520,2412,3176,2092,MAIN_PROJECT]
## Tab buttons: [on, off] per TWILIGHT quest category; "mission" is the 523
## routine tab (Btn_Mission_On/Off, ProjectNode 1000, world.routines).
const TABS={"main":[26500,25048],"common":[22696,21288],"achievement":[18928,17520],"mission":[15168,13764]}
const TAB_LABELS={26500:26952,25048:25100,22696:23148,21288:21340,18928:19380,17520:17572,15168:15620,13764:13816}
## Quest_Tab_Main nodes.
const PAGE_SCOPE: Array[int]=[8084,7696,7308,6904,6444,5564,5124,4312,3984,3636,3380,2756,2332,1912,1284,172]
const GOAL_TEXT=5616
const STORY_TEXT=4364
const DETAIL_TITLE=6444
const REWARD_TITLE=3636
const LIST=1912
const NOTICE=172
const NOTICE_TEXT=224
const REWARD_SLOTS: Array[int]=[1200,900,660,420,136]
const SLOT_ICON=15012
const SLOT_BUTTON=15728
const SLOT_BACKGROUND=15316
const SLOT_AMOUNT=6880
## Row nodes per original row member: panel, label, normal/pressed buttons,
## receive button, new mark.
const ROWS={
	ROW_REWARD:{"panel":196,"label":6024,"icon":5584,"bg":6496,"normal":4872,"pressed":3924,"receive":616,"new":276},
	ROW_PROGRESS:{"panel":192,"label":5728,"icon":5292,"bg":6200,"normal":4580,"pressed":3584,"receive":268,"new":-1},
	ROW_COMPLETE:{"panel":160,"label":3932,"icon":3492,"bg":4404,"normal":2780,"pressed":1784,"receive":628,"new":236,"complete":1380},
}
const ROW_HEIGHT: float=80.0
const LIST_SIZE:=Vector2(450,460)
## The list content origin sits this far below the ListView's top edge.
const LIST_TOP_INSET: float=50.0
## Rows shown at once in the list (the client lists the current chapter).
const MAX_ROWS: int=60
signal closed
var _pack: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _claim: Callable
var _scene: Node2D
var _page: Node2D
var _rows_content: Node2D
var _row_scenes: Array[Node2D]=[]
var _category: String="main"
var _selected_id: String=""
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _parent: WeakRef
## The 미션 tab page, or null when its original members are not in the pack.
var _routine_page: RefCounted

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in [ROOT,TAB_MAIN,ROW_REWARD,ROW_PROGRESS,ROW_COMPLETE,SLOT_SET]:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_quest_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	var page=RoutinePage.new()
	_routine_page=page if page.configure(pack,hud,Callable(self,"refresh")).get("ok",false) else null
	return {"ok":true,"configured":true,"mission_tab":_routine_page!=null}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node, claim: Callable) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_quest_window_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_claim=claim
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_page=null
	_rows_content=null
	_row_scenes.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func blocks_point(_point: Vector2) -> bool:
	return is_open()

func _rows() -> Array[Dictionary]:
	var shown: Array[Dictionary]=[]
	var world: Object=_world.get_ref() if _world!=null else null
	if world==null:return shown
	var service: Variant=world.get("quest_service")
	if service==null or not service.has_method("entries"):return shown
	var auto: Variant=world.get("quest_auto")
	if auto!=null and auto.has_method("refresh_context"):auto.refresh_context(world)
	var ready: Array[Dictionary]=[]
	var waiting: Array[Dictionary]=[]
	var done: Array[Dictionary]=[]
	for quest: Dictionary in service.entries(int(world.get("level")),world.get("inventory")):
		if not quest.has("source_id") or str(quest.get("category",""))!=_category:continue
		if bool(quest.get("completed",false)):done.append(quest)
		elif _receivable(quest):ready.append(quest)
		else:waiting.append(quest)
	# Receivable first, then the next ones still waiting, then finished ones.
	for group: Array[Dictionary] in [ready,waiting,done]:
		for quest: Dictionary in group:
			if shown.size()>=MAX_ROWS:return shown
			shown.append(quest)
	return shown

func _tab_bindings(scope: Array[int], bindings: Dictionary) -> void:
	for category: String in TABS:
		var pair: Array=TABS[category]
		var shown: bool=category!="mission" or _routine_page!=null
		for index: int in range(2):
			var offset: int=int(pair[index])
			if category=="mission":scope.append(offset)
			bindings[offset]={"role":"button","visible":shown and ((category==_category) if index==0 else (category!=_category)),"activate":Callable(self,"_select_category").bind(category)}
	for offset: int in TAB_LABELS:
		scope.append(int(TAB_LABELS[offset]))
		bindings[int(TAB_LABELS[offset])]={"role":"static_source_text"}

## The 미션 tab: Quest_All with ProjectNode 1000 (Quest_Tab_Mission) in place
## of the main page.
func _stage_mission(parent: Object) -> Dictionary:
	var world: Object=_world.get_ref() if _world!=null else null
	if world==null or world.get("routines")==null:return _fail("source_quest_window_routines_unavailable")
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},TITLE:{"role":"static_source_text"}}
	var scope: Array[int]=[]
	for offset: int in ROOT_SCOPE:
		if offset!=MAIN_PROJECT:scope.append(offset)
	_tab_bindings(scope,bindings)
	_consume_touch(ROOT,scope,bindings)
	var out: Dictionary={}
	var page: Dictionary=_routine_page.project_binding(world,out)
	scope.append(RoutinePage.PROJECT)
	bindings[RoutinePage.PROJECT]=page.binding
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,scope,bindings)
	if not result.get("ok",false):next.free();return result
	var filled: Dictionary=_routine_page.fill(next,out,page)
	if not filled.get("ok",false):next.free();return filled
	var previous: Node2D=_scene
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_page=null
	_rows_content=null
	_row_scenes.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return {"ok":true,"handled":true,"member":ROOT,"category":_category,"mission":filled}

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fail("source_quest_window_host_unavailable")
	if _category=="mission" and _routine_page!=null:return _stage_mission(parent)
	var rows: Array[Dictionary]=_rows()
	var selected: Dictionary={}
	for quest: Dictionary in rows:
		if str(quest.id)==_selected_id:selected=quest
	if selected.is_empty() and not rows.is_empty():
		selected=rows[0]
		_selected_id=str(selected.id)
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},TITLE:{"role":"static_source_text"}}
	var scope: Array[int]=ROOT_SCOPE.duplicate()
	_tab_bindings(scope,bindings)
	var page: Dictionary=_page_bindings(selected,rows.is_empty())
	if not page.get("ok",false):return page
	_consume_touch(ROOT,scope,bindings)
	_consume_touch(TAB_MAIN,page.scope,page.bindings)
	bindings[MAIN_PROJECT]={"role":"project","visible":true,"source_node_offsets":page.scope,"bindings":page.bindings}
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,scope,bindings)
	if not result.get("ok",false):next.free();return result
	var main: Dictionary=next.project_player([MAIN_PROJECT])
	if not main.get("ok",false):next.free();return main
	var page_player: Node2D=main.player
	# Reward slots: the selected quest's original reward items.
	for index: int in range(page.reward_owners.size()):
		var owner: Dictionary=page.reward_owners[index]
		var slot: Dictionary=page_player.project_player([3380,REWARD_SLOTS[index]])
		if not slot.get("ok",false):continue
		var uploaded: Dictionary=slot.player.set_bound_source_visual_result(SLOT_ICON,owner)
		if uploaded.get("ok",false):slot.player.set_bound_visible(SLOT_ICON,true)
	var list_node: Variant=page_player.get("source_nodes").get(LIST)
	var content: Variant=list_node.get_meta("source_list_content",null) if is_instance_valid(list_node) else null
	if not content is Node2D:next.free();return _fail("source_quest_window_list_content_missing")
	var row_scenes: Array[Node2D]=[]
	for index: int in range(rows.size()):
		var row: Dictionary=_row(rows[index],str(rows[index].id)==_selected_id)
		if not row.get("ok",false):
			for built: Node2D in row_scenes:built.free()
			next.free()
			return row
		var row_scene: Node2D=row.scene
		# Row panels are 450x80 with their origin at the lower-left; rows run
		# top-down from the list's top edge.
		row_scene.position=Vector2(-float(row.panel_x),-LIST_SIZE.y-LIST_TOP_INSET+ROW_HEIGHT*float(index+1))
		content.add_child(row_scene)
		row_scenes.append(row_scene)
	var previous: Node2D=_scene
	# QuestScene places Quest_All_Layout at the design centre (600, 337.5).
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_page=page_player
	_rows_content=content
	_row_scenes=row_scenes
	_scroll_min=minf(0.0,LIST_SIZE.y-ROW_HEIGHT*float(rows.size()))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.y=_scroll
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return {"ok":true,"handled":true,"member":ROOT,"category":_category,"rows":rows.size(),"selected_id":_selected_id}

func _page_bindings(selected: Dictionary, empty: bool) -> Dictionary:
	var scope: Array[int]=PAGE_SCOPE.duplicate()
	var bindings: Dictionary={DETAIL_TITLE:{"role":"static_source_text"},REWARD_TITLE:{"role":"static_source_text"},LIST:{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")},NOTICE:{"visible":empty},NOTICE_TEXT:{"role":"static_source_text"}}
	# The two detail ListViews hold their one authored text row each.
	bindings[5564]={"role":"source_list","row_offsets":[GOAL_TEXT],"input":Callable(self,"_ignore_input")}
	bindings[4312]={"role":"source_list","row_offsets":[STORY_TEXT],"input":Callable(self,"_ignore_input")}
	scope.append(NOTICE_TEXT)
	scope.append(GOAL_TEXT)
	scope.append(STORY_TEXT)
	var goals: PackedStringArray=[]
	for goal: Dictionary in selected.get("goals",[]):goals.append(str(goal.get("description",goal.get("type_name",""))))
	var count: int=int((selected.get("objective",{}) as Dictionary).get("count",1)) if selected.get("objective") is Dictionary else 1
	var goal_text: String="\n".join(goals) if not goals.is_empty() else str(selected.get("title",""))
	if not selected.is_empty():goal_text+=" (%d/%d)"%[int(selected.get("progress",0)),count]
	bindings[GOAL_TEXT]={"role":"source_text","text":goal_text}
	var status: String="완료" if bool(selected.get("completed",false)) else str(selected.get("status_reason",""))
	bindings[STORY_TEXT]={"role":"source_text","text":(str(selected.get("title",""))+"\n"+status).strip_edges()}
	# Reward slots (Quest_Slot_Set): original item pictures of the rewards.
	var slot_scope: Array[int]=[]
	var slot_bindings: Dictionary={}
	var owners: Array[Dictionary]=[]
	var rewards: Array=[]
	for reward: Variant in selected.get("source_rewards",[]):
		if reward is Dictionary and int(reward.get("RewardEnhancementTypeID",1))==1 and reward.get("source_item") is Dictionary:rewards.append(reward)
	for index: int in range(REWARD_SLOTS.size()):
		var offset: int=REWARD_SLOTS[index]
		slot_scope.append(offset)
		var common_scope: Array[int]=[SLOT_BUTTON,SLOT_BACKGROUND]
		var common: Dictionary={SLOT_BUTTON:{"role":"button","displaystate":false,"activate":Callable()}}
		if index<rewards.size():
			var owner: Dictionary=_reward_picture(rewards[index],offset)
			if owner.get("ok",false):
				owners.append(owner)
				common_scope.append(SLOT_ICON)
				common[SLOT_ICON]={"role":"source_asset_slot","visible":false}
				common_scope.append(SLOT_AMOUNT)
				common[SLOT_AMOUNT]={"role":"source_text","text":str(int(rewards[index].get("Amount",0))),"visible":true}
		slot_bindings[offset]={"role":"project","source_node_offsets":common_scope,"bindings":common}
	bindings[3380]={"role":"project","source_node_offsets":slot_scope,"bindings":slot_bindings}
	return {"ok":true,"scope":scope,"bindings":bindings,"reward_owners":owners}

func _reward_picture(reward: Dictionary, offset: int) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Object=_world.get_ref() if _world!=null else null
	if hud==null or world==null:return {"ok":false}
	var item: Dictionary=reward.get("source_item",{})
	var record: Dictionary=world.call("_catalog_item_from_source_id","m523:item:%d"%int(item.get("ItemClassID",item.get("ID",0))))
	if record.is_empty():return {"ok":false}
	var name: String=str(record.get("name",""))
	var context: Dictionary={"member":SLOT,"node_offset":SLOT_ICON,"slot_project_offset":offset,"reference":name}
	context["source_slot_contract"]=Scene.external_scene_slot_contract(_pack,SLOT,SLOT_ICON)
	return InventoryImages.resolve_owned(hud,{"name":name,"reference":name,"record":record},context)

func _row(quest: Dictionary, is_selected: bool) -> Dictionary:
	var member: String=ROW_COMPLETE if bool(quest.get("completed",false)) else (ROW_REWARD if _receivable(quest) else ROW_PROGRESS)
	var spec: Dictionary=ROWS[member]
	var id: String=str(quest.id)
	var scope: Array[int]=[int(spec.panel),int(spec.bg),int(spec.label),int(spec.icon),int(spec.normal),int(spec.pressed)]
	var bindings: Dictionary={int(spec.label):{"role":"source_text","text":str(quest.get("title",""))},int(spec.normal):{"role":"button","visible":not is_selected,"activate":Callable(self,"_select_quest").bind(id)},int(spec.pressed):{"role":"button","visible":is_selected,"activate":Callable(self,"_select_quest").bind(id)},int(spec.panel):{"input":Callable(self,"_list_input")}}
	if member==ROW_REWARD:
		scope.append(int(spec.receive))
		bindings[int(spec.receive)]={"role":"button","activate":Callable(self,"_receive").bind(id)}
	if spec.has("complete"):
		scope.append(int(spec.complete))
		bindings[int(spec.complete)]={"role":"static_source_text"}
	_consume_touch(member,scope,bindings)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,member,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	var panel: Dictionary=Scene._node_at_offset(_pack.scene(member).get("nodeTree",{}),int(spec.panel))
	var widget: Dictionary=panel.get("options",{}).get("widgetOptions",{})
	# Left edge of the row panel relative to the row root (position minus
	# anchor share): Quest_List_Reward is anchored 0 at -225, the others 0.5 at 0.
	var anchor: Array=widget.get("anchorPoint",[0,0])
	var panel_x: float=float(widget.get("position",[0,0])[0])-float(anchor[0])*float(widget.get("size",[0,0])[0])
	return {"ok":true,"scene":scene,"panel_x":panel_x}

## Received with the original receive button once its goal count is met.
static func _receivable(quest: Dictionary) -> bool:
	if bool(quest.get("completed",false)) or not bool(quest.get("available",false)):return false
	var objective: Variant=quest.get("objective",{})
	var count: int=int(objective.get("count",1)) if objective is Dictionary else 1
	return int(quest.get("progress",0))>=count

func _select_quest(id: String) -> Dictionary:
	_selected_id=id
	_stage()
	return {"ok":true,"selected_id":id}

func _select_category(category: String) -> Dictionary:
	_category=category
	_selected_id=""
	_scroll=0.0
	_stage()
	return {"ok":true,"category":category}

func _receive(id: String) -> Dictionary:
	_selected_id=id
	if _claim.is_valid():_claim.call(id)
	_stage()
	return {"ok":true,"emitted":true,"quest_id":id}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _ignore_input(_event: InputEvent) -> void:
	pass

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_rows_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=ROW_HEIGHT*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_rows_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_rows_content.position.y=_scroll

## Touch-enabled original nodes inside the mounted subtrees that this window
## gives no action swallow their touch (as the client's modal window does).
func _consume_touch(member: String, scope: Array[int], bindings: Dictionary) -> void:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	for offset: int in scope:
		_consume_subtree(Scene._node_at_offset(tree,offset),bindings)

static func _consume_subtree(node: Dictionary, bindings: Dictionary) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	if bool(widget.get("touchEnabled",false)) and node.get("classname")!="ProjectNode":
		var binding: Dictionary=bindings.get(offset,{})
		if not binding.has("role") and not binding.has("input"):
			binding["role"]="consume"
			bindings[offset]=binding
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_consume_subtree(child,bindings)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
