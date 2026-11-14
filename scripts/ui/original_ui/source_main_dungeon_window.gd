extends RefCounted
## The original 523 던전 list window: Mission_Dungeon_All (frame, close, the
## ListView_Button tab column of Mission_List_Dungeon buttons) with one page
## of the existing dungeon screen's categories at a time:
##   특수 던전   -> Mission_Dungeon_Special (ListView_Daily of
##                 Mission_DungeonSpecial_Btn: name, cost, time pool, level lock)
##   시련의 탑   -> Mission_Dungeon_TrialTower (normal / 하드 모드 toggle,
##                 floor ▲▼, stage info, goal, best floor, rewards, 도전 /
##                 즉시 완료 / 횟수 구매 / 보상 받기 / 도전 포기)
##   오림의 흔적 -> Mission_Dungeon_TracesOrim (normal / 하드 모드, 이전 장 /
##                 다음 장, 캐릭터 선택, rewards, 도전 / 보상 받기 / 종료)
##   시간 충전석 -> Mission_Popup_Time over the 특수 던전 page (the special
##                 row's ⊕ opens it: Mission_List_Time rows, 기본/추가 이용 시간)
## Rows are the existing screen's rows (world.source_dungeon_entries through
## the mounted source_dungeon_view); every entry check, confirmation and
## action is the existing view's (_check_entry / _perform / _play_action)
## behind the HUD's confirmation. Nothing here decides a dungeon rule.
## Left empty (no picture or rule in the original data here): dungeon
## thumbnails (SpecialDungeon.EntranceAssetID / Orim chapter and hero
## art are not in the packs), buffs, 스피드 모드, ranking, shop, help, the
## floor tower art, story, achievements, bookmarks, share and notices.
## Party dungeons are excluded (user decision 2026-11-12).
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Rows=preload("res://scripts/resources/current523_definition_rows.gd")
const ROOT="UI/Mission/Mission_Dungeon_All.csb"
const TAB="UI/Mission/Mission_List_Dungeon.csb"
const TOWER="UI/Mission/Mission_Dungeon_TrialTower.csb"
const ORIM="UI/Mission/Mission_Dungeon_TracesOrim.csb"
const SPECIAL="UI/Mission/Mission_Dungeon_Special.csb"
const SPECIAL_ROW="UI/Mission/Mission_DungeonSpecial_Btn.csb"
const TIME="UI/Mission/Mission_Popup_Time.csb"
const TIME_ROW="UI/Mission/Mission_List_Time.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316,15012,6880]}
const REQUIRED: Array[String]=[ROOT,TAB,TOWER,ORIM,SPECIAL,SPECIAL_ROW,TIME,TIME_ROW,SLOT]
## Mission_Dungeon_All_Layout in MissionScene (600, 337.5).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
## Tab order: UIDungeonCategory ViewOrder (특수 0, 시련 1), then 오림.
const TABS: Array=[["special","특수 던전"],["tower","시련의 탑"],["orim","오림의 흔적"]]
const PAGES={"special":"Mission_Dungeon_Special","tower":"Mission_Dungeon_TrialTower","orim":"Mission_Dungeon_TracesOrim"}
## Pages of Mission_Dungeon_All this window never mounts (party excluded).
const OTHER: Array[String]=["Mission_Dungeon_MasterDungeon","Mission_Dungeon_GlobalMaster","Mission_Dungeon_Competition_Theberas","Mission_Dungeon_Competition_Lastavard","Mission_Dungeon_Siege","Mission_Dungeon_Defense","Mission_Dungeon_Arena","Mission_Dungeon_ElfDefense","Mission_Dungeon_Trial","Mission_Dungeon_Season","Mission_Dungeon_PartyDungeon","Fx_Loading"]
## The existing view's families (source_dungeon_view.FAMILIES).
const FAMILY={"tower":0,"tower_hard":1,"orim":2,"orim_hard":3,"special":4,"rechargers":5}
const P_TOWER="Mission_Dungeon_TrialTower/"
const P_ORIM="Mission_Dungeon_TracesOrim/"
const P_SPECIAL="Mission_Dungeon_Special/"
const P_TIME="Mission_Popup_Time/"
const SLOT_PITCH: float=80.0
const SPECIAL_GAP: float=4.0
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _view: WeakRef
var _scene: Node2D
var _last_out: Dictionary={}
var tab: String="special"
var hard: bool=false
## Selected tower floor / orim stage (row index of the current family).
var index: int=0
## Orim hero (OrimsTrailCharacter selectable index; -1: none chosen).
var hero: int=-1
## 시간 충전석 popup open, and the special row's time group it shows (0: all).
var time_open: bool=false
var time_group: int=0
var rows: Array=[]
var last_result: Dictionary={}
var _special: Scroller=Scroller.new()
var _time: Scroller=Scroller.new()

## Drag scroll of a ListView's content along one axis (rows not wholly inside
## the list are hidden: nothing clips them, and off-screen pictures take no copies).
class Scroller extends RefCounted:
	var content: Node2D
	var horizontal: bool=false
	var items: Array[Node2D]=[]
	var pitch: float=1.0
	var view: float=0.0
	var at: float=0.0
	var minimum: float=0.0
	var drag: bool=false
	var moved: float=0.0

	func bind(list_content: Node2D, row_nodes: Array[Node2D], row_pitch: float, view_size: float, along_x: bool) -> void:
		content=list_content
		items=row_nodes
		pitch=maxf(1.0,row_pitch)
		view=view_size
		horizontal=along_x
		minimum=minf(0.0,view-pitch*float(items.size()))
		at=clampf(at,minimum,0.0)
		_apply()

	func input(event: InputEvent) -> void:
		if not is_instance_valid(content):return
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
			drag=event.pressed
			if event.pressed:moved=0.0
			return
		var delta: float=0.0
		if event is InputEventScreenDrag:delta=event.relative.x if horizontal else event.relative.y
		elif event is InputEventMouseMotion and drag:delta=event.relative.x if horizontal else event.relative.y
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			delta=pitch*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale: Vector2=content.get_global_transform_with_canvas().get_scale()
		var factor: float=absf(scale.x if horizontal else scale.y)
		if factor>0.0 and not event is InputEventMouseButton:delta/=factor
		# Godot y grows down: dragging up moves a vertical list's rows up.
		moved+=absf(delta)
		at=clampf(at+(delta if horizontal else -delta),minimum,0.0)
		_apply()

	func _apply() -> void:
		if not is_instance_valid(content):return
		if horizontal:content.position.x=at
		else:content.position.y=-at
		for i: int in range(items.size()):
			if not is_instance_valid(items[i]):continue
			var start: float=pitch*float(i)+at
			# Only whole rows show: the list does not clip a row cut by its edge.
			items[i].visible=start>=-0.5 and start+pitch<=view+0.5

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_dungeon_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## `view` is the existing dungeon screen (source_dungeon_view) mounted in the
## hidden workspace: its rows, checks and actions are the window's.
func open(parent: Node, view: Object) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(view) or not view.has_method("_refresh"):return _fail("source_dungeon_window_host_unavailable")
	_parent=weakref(parent)
	_view=weakref(view)
	tab="special"
	hard=false
	index=0
	hero=-1
	time_open=false
	time_group=0
	_special.at=0.0
	_time.at=0.0
	return _stage()

func refresh() -> Dictionary:
	if not is_open():return {"ok":true,"handled":false}
	return _stage()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_special.content=null
	_time.content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

func _family() -> String:
	if time_open:return "rechargers"
	if tab in ["tower","orim"] and hard:return tab+"_hard"
	return tab

## The existing view on this window's family (its _refresh reads the rows
## from world.source_dungeon_entries), with `row` selected.
func _bind_view(family: String, row: int=-1) -> Object:
	var view: Object=_view.get_ref() if _view!=null else null
	if not is_instance_valid(view):return null
	var wanted: int=int(FAMILY[family])
	if view.family.selected!=wanted or view.rows.is_empty():
		view.family.select(wanted)
		view._refresh()
	if row>=0 and row<view.rows.size() and view.selected!=row:
		view.listing.select(row)
		view._select(row)
	return view

static func clock_text(seconds: int) -> String:
	var minutes: int=maxi(0,seconds)/60
	return "%02d시간%02d분" % [minutes/60,minutes%60]

static func number_text(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

static func special_name(entry: Dictionary) -> String:
	var names: Array[String]=[]
	for destination: Dictionary in entry.get("destinations",[]):
		var name: String=str(destination.get("place",{}).get("name",""))
		if not name.is_empty() and not names.has(name):names.append(name)
	return " / ".join(names) if not names.is_empty() else "목적지 확인 필요"

static func special_level(entry: Dictionary) -> int:
	var minimum: int=0
	for condition: Dictionary in entry.get("prerequisites",[]):
		if str(condition.get("type",""))=="MinLevel":minimum=maxi(minimum,int(condition.row.Value))
	return minimum

static func special_groups(entry: Dictionary) -> Array[int]:
	var groups: Array[int]=[]
	var destinations: Array=entry.get("destinations",[])
	if destinations.is_empty():return groups
	for group: Dictionary in destinations[0].get("place",{}).get("time_groups",[]):groups.append(int(group.row.ID))
	return groups

## The stage's own UI name (UIOrimsTrailStage StageNameID text, else its
## StageName) for 이전 장 / 다음 장's title; "N단계" without the table.
static func orim_title(stage_index: int) -> String:
	for row: Dictionary in Rows.related("UIOrimsTrailStage","OrimsTrailStageIndex",stage_index):
		var described: Array[Dictionary]=Rows.related("DescData_Korean","ID",int(row.get("StageNameID",0)))
		var text: String=str(described[-1].get("Description","")) if not described.is_empty() else ""
		return text if not text.is_empty() else str(row.get("StageName",""))
	return "%d단계" % stage_index

## Reward rows (TrialTowerReward / OrimsTrailReward) as {class_id, name, amount}.
static func reward_slots(rewards: Array) -> Array:
	var out: Array=[]
	for reward: Dictionary in rewards:
		var item: Variant=reward.get("item")
		var amount: int=int(reward.get("row",{}).get("Amount",0))
		if item is Dictionary:out.append({"class_id":int(item.row.ID),"name":str(item.name),"amount":amount})
		elif str(reward.get("type",""))=="Exp":out.append({"class_id":0,"name":"경험치","amount":amount})
	return out

## The best floor cleared in this mode (TrialTower clears of the run state).
static func best_floor(clears: Dictionary, tower_rows: Array) -> int:
	var best: int=0
	for entry: Dictionary in tower_rows:
		if clears.has(str(int(entry.stage.ID))):best=maxi(best,int(entry.stage.StageIndex))
	return best

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var view: Object=_bind_view("special" if time_open else _family())
	if parent==null or hud==null or view==null:return _fail("source_dungeon_window_host_unavailable")
	var world: Node=hud.get_parent()
	rows=view.rows.duplicate()
	index=clampi(index,0,maxi(0,rows.size()-1))
	var spec: Dictionary={}
	for name: String in OTHER:spec[name]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["ListView_Button"]={"input":Callable(self,"_ignore_input")}
	for page: String in PAGES:
		if page==tab:spec[PAGES[page]]={"visible":true}
		else:spec[PAGES[page]]={"exclude":true}
	if not time_open:spec["Mission_Popup_Time"]={"exclude":true}
	match tab:
		"tower":spec.merge(_tower_spec(world,view),true)
		"orim":spec.merge(_orim_spec(world,view),true)
		_:spec.merge(_special_spec(),true)
	var time_rows: Array=[]
	if time_open:
		time_rows=_recharger_rows(world)
		spec.merge(_time_spec(world,time_rows),true)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var filled: Dictionary=_fill_tabs(next,out)
	var pictures: int=0
	if filled.get("ok",false):
		match tab:
			"tower":filled=_fill_slots(next,out,P_TOWER+"Nd_TowerInfo_All/Nd_Reward/ListView",TOWER,reward_slots(_rewards(rows[index] if index<rows.size() else {})))
			"orim":filled=_fill_slots(next,out,P_ORIM+"Nd_OrimInfo_All/Nd_Info/Nd_Reward/ListView",ORIM,reward_slots(_rewards(rows[index] if index<rows.size() else {})))
			_:filled=_fill_special(next,out,world)
		pictures+=int(filled.get("pictures",0))
	if filled.get("ok",false) and time_open:
		filled=_fill_time(next,out,world,time_rows)
		pictures+=int(filled.get("pictures",0))
	if not filled.get("ok",false):
		next.free()
		last_result=filled
		return filled
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"tab":tab,"hard":hard,"rows":rows.size(),"index":index,"time_open":time_open,"time_rows":time_rows.size(),"pictures":pictures}
	return last_result

func _rewards(entry: Dictionary) -> Array:
	return entry.get("normal_rewards",[])

func _ignore_input(_event: InputEvent) -> void:
	pass

func _fill_tabs(root: Node2D, out: Dictionary) -> Dictionary:
	var content: Variant=_list_content(root,out,"ListView_Button")
	if not content is Node2D:return _fail("source_dungeon_window_tab_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,ROOT,"ListView_Button")
	for i: int in range(TABS.size()):
		var id: String=str(TABS[i][0])
		var on: bool=id==tab
		var built: Dictionary=_tree.scene_of(TAB,{
			"Panel":{"input":Callable(self,"_ignore_input")},
			"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_set_tab").bind(id)},
			"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_set_tab").bind(id)},
			"Btn_Normal/Label":{"role":"source_text","text":str(TABS[i][1])},
			"Btn_Pressed/Label":{"role":"source_text","text":str(TABS[i][1])},
			"Panel/Sp_RedDot":{"visible":false},
		},{})
		if not built.get("ok",false):return built
		_tree.add_row(content,TAB,built.scene,i,size)
	return {"ok":true}

## --- 시련의 탑 ------------------------------------------------------------------

func _tower_state(world: Node, entry: Dictionary) -> Dictionary:
	var runs: Object=world.source_dungeon_runs
	var stage_id: int=int(entry.stage.ID)
	var run: Dictionary=runs.state.active
	var mine: bool=not run.is_empty() and int(run.get("stage_id",0))==stage_id
	if not world.pending_dungeon_events.is_empty():return {"action":"retry","caption":"저장 재시도","ok":true}
	if mine and run.get("status","")=="cleared":return {"action":"claim","caption":"보상 받기","ok":true}
	if mine and run.get("status","")=="active":return {"action":"leave","caption":"도전 포기","ok":true}
	var normal: Dictionary=runs.check(stage_id)
	var host: Dictionary=normal.get("host",{})
	var tries: int=0
	var limit: int=1
	if not host.is_empty() and runs.has_method("_cycle_key"):
		var cycle: Dictionary=runs.state.cycles.get(runs._cycle_key(runs.rules.stage("tower",stage_id),host),{"tries":0,"purchases":0})
		tries=int(cycle.tries)
		limit=1+int(cycle.purchases)
	var counted: String="도전 (%d/%d)" % [maxi(0,limit-tries),limit] if not host.is_empty() else "도전"
	if normal.get("ok",false):return {"action":"begin","caption":counted,"ok":true,"reasons":[]}
	var reasons: Array=normal.get("reasons",[])
	if not host.is_empty() and tries>=limit and limit<2 and run.is_empty():return {"action":"purchase","caption":counted,"ok":true,"buy":true,"reasons":reasons}
	return {"action":"","caption":counted,"ok":false,"reasons":reasons}

func _tower_spec(world: Node, view: Object) -> Dictionary:
	var spec: Dictionary={}
	var p: String=P_TOWER
	var i: String=p+"Nd_TowerInfo_All/"
	for name: String in ["Label_Notice","Btn_HelpBox","Btn_Shop","Btn_Ranking","Nd_Popup_Ranking","Btn_Back","Nd_TowerInfo_All/Nd_BuffInfo","Nd_MoveFloor/Nd_Navi","Nd_TowerInfo_All/Nd_SpeedMode","Nd_TowerInfo_All/Nd_StageInfo/Btn_InfoView","Nd_TowerInfo_All/Nd_ReChallenge/Common_Slot_Layout"]:spec[p+name]={"exclude":true}
	spec[p+"BG"]={"visible":not hard}
	spec[p+"BG_Hard"]={"visible":hard}
	spec[p+"Nd_Title_Tower/Nd_Title_Normal"]={"visible":not hard}
	spec[p+"Nd_Title_Tower/Nd_Title_Hard"]={"visible":hard}
	spec[i+"Nd_HardMode/Btn_Off"]={"visible":not hard,"activate":Callable(self,"_toggle_hard")}
	spec[i+"Nd_HardMode/Btn_On"]={"visible":hard,"activate":Callable(self,"_toggle_hard")}
	spec[p+"Nd_MoveFloor/Nd_Btn/Btn_Up"]={"activate":Callable(self,"_step").bind(1),"displaystate":index+1<rows.size()}
	spec[p+"Nd_MoveFloor/Nd_Btn/Btn_Down"]={"activate":Callable(self,"_step").bind(-1),"displaystate":index>0}
	spec[p+"Nd_PanelTower/Panel_Tower/ListView_Tower"]={"visible":not hard,"input":Callable(self,"_ignore_input")}
	spec[p+"Nd_PanelTower/Panel_Tower/ListView_Tower_Hard"]={"visible":hard,"input":Callable(self,"_ignore_input")}
	spec[i+"Nd_Reward/ListView"]={"input":Callable(self,"_ignore_input")}
	var entry: Dictionary=rows[index] if index<rows.size() else {}
	var floor: int=int(entry.get("stage",{}).get("StageIndex",0))
	spec[p+"Nd_Title_Tower/Label_Floor"]={"role":"source_text","text":"%d층" % floor if not entry.is_empty() else "-"}
	spec[p+"Nd_PanelTower/Panel_Tower/Nd_BestRecord/Label_BestRecord"]={"role":"source_text","text":"최고 도달층 : %d층" % best_floor(world.source_dungeon_runs.state.clears,rows)}
	var goals: Array[String]=[]
	for goal: Dictionary in entry.get("goals",[]):
		if goal.type=="AnyNpcKill":goals.append("몬스터 %d마리 처치" % int(goal.row.Amount))
		elif goal.type=="ItemCollect":goals.append("%s %d개 수집" % [str(goal.item.name),int(goal.row.Amount)])
	spec[p+"Nd_PanelTower/Panel_Tower/Nd_Goal/Label_Goal"]={"role":"source_text","text":"목표 : "+(", ".join(goals) if not goals.is_empty() else "-")}
	spec[i+"Nd_StageInfo/Text_Title"]={"role":"source_text","text":"%d층 스테이지 정보" % floor if not entry.is_empty() else "스테이지 정보"}
	var seconds: int=int(entry.get("stage",{}).get("TimeLimit",0))
	var local: Dictionary=world.LOCAL_TOWER.settings(world.source_dungeon_runs.state)
	if bool(local.get("enabled",false)):seconds*=int(local.get("time_scale",1))
	spec[i+"Nd_StageInfo/Text_Dis01"]={"role":"source_text","text":"·입장 제한 레벨 : %d레벨" % int(entry.get("stage",{}).get("MinLevel",0))}
	spec[i+"Nd_StageInfo/Text_Dis02"]={"role":"source_text","text":"·제한 시간 : %d분" % (seconds/60) if seconds%60==0 else "·제한 시간 : %d분 %d초" % [seconds/60,seconds%60]}
	spec[i+"Nd_StageInfo/Text_Dis04"]={"visible":false}
	var state: Dictionary=_tower_state(world,entry) if not entry.is_empty() else {"action":"","caption":"도전","ok":false,"reasons":[str(view.notice.text)]}
	var immediate: Dictionary=world.source_dungeon_runs.check(int(entry.stage.ID),true) if not entry.is_empty() else {"ok":false}
	var again: bool=immediate.get("ok",false) and state.action=="begin"
	var reasons: Array=state.get("reasons",[])
	spec[i+"Text_Reason"]={"role":"source_text","text":str(reasons[0]) if not reasons.is_empty() else ""}
	var cost: int=int(world.source_dungeon_tower_cost(hard).get("BaseTryCurrencyCost",0))
	spec[i+"Nd_ReChallenge"]={"visible":again}
	spec[i+"Nd_Challenge"]={"visible":not again}
	for holder: String in ["Nd_Challenge/","Nd_ReChallenge/"]:
		for button: String in ["Btn_Challenge","Btn_Challenge_Hard"]:
			var key: String=i+holder+button
			var shown: bool=(button=="Btn_Challenge_Hard")==hard
			spec[key]={"visible":shown,"activate":Callable(self,"_tower_pressed").bind(str(state.action)),"displaystate":bool(state.ok)}
			spec[key+"/Nd_Normal"]={"visible":bool(state.ok)}
			spec[key+"/Nd_Disable"]={"visible":not bool(state.ok)}
			spec[key+"/Nd_Normal/Text_Challenge"]={"role":"source_text","text":str(state.caption)}
			spec[key+"/Nd_Normal/Text_Challenge_Num"]={"role":"source_text","text":number_text(cost),"visible":state.action=="begin"}
			spec[key+"/Nd_Normal/Sp_Icon_A0"]={"visible":state.action=="begin"}
			spec[key+"/Nd_Normal/Img_Bg"]={"visible":state.action=="begin"}
			spec[key+"/Nd_Normal/Text_Buy"]={"visible":bool(state.get("buy",false))}
	spec[i+"Nd_ReChallenge/Btn_Recovery_Free"]={"activate":Callable(self,"_tower_pressed").bind("immediate"),"displaystate":again}
	return spec

## --- 오림의 흔적 ----------------------------------------------------------------

func _heroes(view: Object) -> Array:
	var out: Array=[]
	for i: int in range(view.orim_hero.item_count):out.append({"id":view.orim_hero.get_item_id(i),"text":view.orim_hero.get_item_text(i)})
	return out

func _orim_state(world: Node, entry: Dictionary) -> Dictionary:
	var service: Object=world.dungeon_play
	var run: Dictionary=service.state.active
	if not run.is_empty() and run.get("kind","")=="orim":
		if run.get("status","")=="cleared" and int(run.get("stage_id",0))==int(entry.get("stage",{}).get("ID",0)):return {"action":"claim","caption":"보상 받기","ok":not service.save_blocked}
		return {"action":"stop","caption":"도전 종료","ok":not service.save_blocked}
	var idle: String=service.check_idle()
	return {"action":"begin","caption":"도전","ok":idle.is_empty() and not entry.is_empty(),"reason":idle}

func _orim_spec(world: Node, view: Object) -> Dictionary:
	var spec: Dictionary={}
	var p: String=P_ORIM
	var i: String=p+"Nd_OrimInfo_All/"
	for name: String in ["Label_Notice","Btn_HelpBox","Nd_Achievement","Btn_Shop","Btn_Back","Nd_Chapter/Nd_ChapterStory","Nd_PanelOrim/Panel_OrimPage/Nd_Page_Move","Nd_OrimInfo_All/Nd_Info/Nd_Buff","Nd_OrimInfo_All/Nd_CardInfo/Nd_CardOn/Panel_Card/Nd_Character"]:spec[p+name]={"exclude":true}
	spec[p+"Fx_HardLoop"]={"visible":hard}
	spec[p+"Nd_Title_Orim/Sp_Normal"]={"visible":not hard}
	spec[p+"Nd_Title_Orim/Sp_Hard"]={"visible":hard}
	spec[i+"Nd_CheckBox/Btn_Off"]={"visible":not hard,"activate":Callable(self,"_toggle_hard")}
	spec[i+"Nd_CheckBox/Btn_On"]={"visible":hard,"activate":Callable(self,"_toggle_hard")}
	spec[i+"Nd_Info/Nd_Reward/ListView"]={"input":Callable(self,"_ignore_input")}
	var entry: Dictionary=rows[index] if index<rows.size() else {}
	var before: bool=index>0
	var after: bool=index+1<rows.size()
	spec[p+"Nd_Chapter/Btn_BeforeChapter"]={"activate":Callable(self,"_step").bind(-1),"displaystate":before}
	spec[p+"Nd_Chapter/Btn_BeforeChapter/Normal"]={"visible":before}
	spec[p+"Nd_Chapter/Btn_BeforeChapter/Disabled"]={"visible":not before}
	spec[p+"Nd_Chapter/Btn_NextChapter"]={"activate":Callable(self,"_step").bind(1),"displaystate":after}
	spec[p+"Nd_Chapter/Btn_NextChapter/Normal"]={"visible":after}
	spec[p+"Nd_Chapter/Btn_NextChapter/Disabled"]={"visible":not after}
	spec[p+"Nd_Chapter/Label_ChapterTitle"]={"role":"source_text","text":orim_title(int(entry.stage.StageIndex)) if not entry.is_empty() else "-"}
	var heroes: Array=_heroes(view)
	var chosen: bool=hero>=0 and hero<heroes.size()
	spec[i+"Nd_CardInfo/Nd_CardOff"]={"visible":not chosen}
	spec[i+"Nd_CardInfo/Nd_CardOn"]={"visible":chosen}
	spec[i+"Nd_CardInfo/Nd_CardOff/Panel_Card/Btn_Plus"]={"activate":Callable(self,"_next_hero")}
	spec[i+"Nd_CardInfo/Nd_CardOn/Panel_Card/Btn_Clear"]={"activate":Callable(self,"_clear_hero")}
	var title: String=str(heroes[hero].text) if chosen else ""
	spec[i+"Nd_CardInfo/Nd_CardOn/Text_Card_Name"]={"role":"source_text","text":title.get_slice(" · ",0)}
	spec[i+"Nd_CardInfo/Nd_CardOn/Text_SkillInfo"]={"role":"source_text","text":title.get_slice(" · ",2) if title.get_slice_count(" · ")>2 else ""}
	var state: Dictionary=_orim_state(world,entry)
	spec[i+"Text_Reason"]={"role":"source_text","text":str(state.get("reason",""))}
	spec[i+"Nd_Challenge"]={"visible":not hard}
	spec[i+"Nd_Challenge_Hard"]={"visible":hard}
	for key: String in [i+"Nd_Challenge/Btn_Challenge",i+"Nd_Challenge_Hard/Btn_Challenge_Hard"]:
		spec[key]={"activate":Callable(self,"_orim_pressed").bind(str(state.action)),"displaystate":bool(state.ok)}
		spec[key+"/Nd_Normal"]={"visible":bool(state.ok)}
		spec[key+"/Nd_Disable"]={"visible":not bool(state.ok)}
		spec[key+"/Nd_Normal/Text_Challenge"]={"role":"source_text","text":str(state.caption)}
		spec[key+"/Nd_Normal/Text_Challenge_Num"]={"visible":false}
		spec[key+"/Nd_Normal/Sp_Icon_A0"]={"visible":false}
		spec[key+"/Nd_Normal/Img_Bg"]={"visible":false}
	return spec

## --- 특수 던전 ------------------------------------------------------------------

func _special_spec() -> Dictionary:
	var spec: Dictionary={}
	spec[P_SPECIAL+"Label_Notice"]={"exclude":true}
	spec[P_SPECIAL+"Nd_Touchable"]={"exclude":true}
	spec[P_SPECIAL+"Fx_HighLight"]={"exclude":true}
	spec[P_SPECIAL+"ListView_Daily"]={"input":Callable(_special,"input")}
	return spec

func _fill_special(root: Node2D, out: Dictionary, world: Node) -> Dictionary:
	var content: Variant=_list_content(root,out,P_SPECIAL+"ListView_Daily")
	if not content is Node2D:return _fail("source_dungeon_window_special_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,SPECIAL,"ListView_Daily")
	var panel: Dictionary=_tree.row_panel(SPECIAL_ROW)
	var width: float=float(panel.size[0])
	var now: int=int(Time.get_unix_time_from_system())
	var built_rows: Array[Node2D]=[]
	for i: int in range(rows.size()):
		var entry: Dictionary=rows[i]
		var level: int=special_level(entry)
		var locked: bool=int(world.level)<level
		var groups: Array[int]=special_groups(entry)
		var seconds: int=0
		var limit: int=0
		for group_id: int in groups:
			var pool: Dictionary=world.dungeon_play.pool(group_id,now)
			seconds+=int(pool.base)+int(pool.bonus)
			var group: Dictionary=world.dungeon_play.rules.time_by_id.get(group_id,{})
			limit+=int(group.get("row",{}).get("TimeLimit",0))*int(world.dungeon_play.state.settings.group_time_scale)
		var adena: bool=str(entry.get("currency",{}).get("name",""))=="아데나"
		var cost: String=number_text(int(entry.teleport.TeleportCost))+("" if adena else " "+str(entry.get("currency",{}).get("name","")))
		var spec: Dictionary={
			"Panel":{"input":Callable(_special,"input")},
			"Panel/Img_Special":{"visible":false},
			"Panel/Button":{"activate":Callable(self,"_special_pressed").bind(i)},
			"Panel/Label_Dungeon":{"role":"source_text","text":special_name(entry)},
			"Panel/Label_Charge":{"role":"source_text","text":cost},
			"Panel/Sp_Adena":{"visible":adena},
			"Panel/Nd_Timebar":{"visible":not groups.is_empty()},
			"Panel/Nd_Timebar/Label_Time":{"role":"source_text","text":clock_text(seconds)},
			"Panel/Nd_Timebar/Bar":{"role":"source_percent","percent":clampf(100.0*float(seconds)/float(maxi(1,limit)),0.0,100.0)},
			"Panel/Nd_Timebar/Btn_Recharge":{"activate":Callable(self,"_open_time").bind(groups[0] if not groups.is_empty() else 0)},
			"Panel/Nd_Lock":{"visible":locked},
			"Panel/Nd_Lock/Label_Condition":{"role":"source_text","text":"Lv %d" % level},
		}
		for name: String in ["Panel/Btn_Fix","Panel/Btn_Item","Panel/Btn_Notice","Panel/Btn_Share","Panel/Btn_HelpBox","Panel/Nd_Penalty","Panel/Nd_Round","Panel/Nd_Closed","Panel/Nd_Timebar_Share","Panel/Nd_Time","Panel/Sp_New","Panel/Sp_Event","Panel/Label_Retry"]:spec[name]={"exclude":true}
		var row_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(SPECIAL_ROW,spec,row_out)
		if not built.get("ok",false):return built
		_add_column(content,SPECIAL_ROW,built.scene,i,size,SPECIAL_GAP)
		built_rows.append(built.scene)
		Storage_forward(built.scene,row_out,"Panel/Button",_special)
	_special.bind(content,built_rows,width+SPECIAL_GAP,size.x,true)
	return {"ok":true,"pictures":0}

## --- 시간 충전석 ----------------------------------------------------------------

func _recharger_rows(world: Node) -> Array:
	var view: Object=_bind_view("rechargers")
	if view==null:return []
	var out: Array=[]
	for i: int in range(view.rows.size()):
		var entry: Dictionary=view.rows[i]
		var preview: Dictionary=world.source_dungeon_recharge_preview(int(entry.item.row.ID))
		var group_id: int=int(preview.get("group",{}).get("row",{}).get("ID",0))
		if time_group!=0 and group_id!=time_group:continue
		var name: String=str(entry.item.name)
		var owned: int=int(world.inventory.get(name,0))+int(world.inventory.get("TWILIGHT · "+name,0))
		out.append({"row":i,"item_id":int(entry.item.row.ID),"item_row":entry.item.row,"name":name,"group":group_id,"owned":owned})
	_bind_view("special")
	return recharger_list(out)

## One row per shown name (owned stacks first, then the source order): the
## source declares several same-named variants of one charger.
static func recharger_list(candidates: Array) -> Array:
	var ordered: Array=candidates.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (int(a.owned)>0 and int(b.owned)<=0) or ((int(a.owned)>0)==(int(b.owned)>0) and int(a.row)<int(b.row)))
	var seen: Dictionary={}
	var out: Array=[]
	for entry: Dictionary in ordered:
		if seen.has(str(entry.name)):continue
		seen[str(entry.name)]=true
		out.append(entry)
	return out

func _time_spec(world: Node, time_rows: Array) -> Dictionary:
	var spec: Dictionary={}
	var p: String=P_TIME
	spec[p+"Btn_Close"]={"activate":Callable(self,"_close_time")}
	spec[p+"Nd_Popup_Time/Btn_Cancel"]={"activate":Callable(self,"_close_time")}
	spec[p+"Nd_Popup_Time/Nd_Timebar_Share"]={"exclude":true}
	spec[p+"Nd_Popup_Time/Fx_Popup_LeftUp"]={"exclude":true}
	spec[p+"Nd_Popup_Time/Fx_Popup_RightBottom"]={"exclude":true}
	spec[p+"Nd_Popup_Time/ListView"]={"input":Callable(_time,"input")}
	var group_id: int=time_group if time_group!=0 else (int(time_rows[0].group) if not time_rows.is_empty() else 0)
	var pool: Dictionary=world.dungeon_play.pool(group_id,int(Time.get_unix_time_from_system())) if group_id!=0 else {"base":0,"bonus":0}
	var group: Dictionary=world.dungeon_play.rules.time_by_id.get(group_id,{})
	var scale: int=int(world.dungeon_play.state.settings.group_time_scale)
	var base_limit: int=int(group.get("row",{}).get("TimeLimit",0))*scale
	var cap: int=int(group.get("row",{}).get("MaxRechargeTime",0))*scale
	if cap==0:cap=int(world.dungeon_play.state.settings.zero_cap)
	var t: String=p+"Nd_Popup_Time/Nd_Timebar/"
	spec[p+"Nd_Popup_Time/Nd_Timebar"]={"visible":group_id!=0}
	spec[t+"Label_Time_Basic"]={"role":"source_text","text":clock_text(int(pool.base))}
	spec[t+"Label_Time__Add"]={"role":"source_text","text":clock_text(int(pool.bonus))}
	spec[t+"Bar_Basic"]={"role":"source_percent","percent":clampf(100.0*float(pool.base)/float(maxi(1,base_limit)),0.0,100.0)}
	spec[t+"Bar_Recharge"]={"role":"source_percent","percent":clampf(100.0*float(pool.bonus)/float(maxi(1,cap)),0.0,100.0)}
	return spec

func _fill_time(root: Node2D, out: Dictionary, world: Node, time_rows: Array) -> Dictionary:
	var content: Variant=_list_content(root,out,P_TIME+"Nd_Popup_Time/ListView")
	if not content is Node2D:return _fail("source_dungeon_window_time_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,TIME,"Nd_Popup_Time/ListView")
	var height: float=float(_tree.row_panel(TIME_ROW).size[1])
	var pictures: int=0
	var built_rows: Array[Node2D]=[]
	for i: int in range(time_rows.size()):
		var entry: Dictionary=time_rows[i]
		var usable: bool=int(entry.owned)>0
		var row_out: Dictionary={}
		var row_spec: Dictionary={
			"Panel":{"input":Callable(_time,"input")},
			# Label_Item is a 180x40 custom-size Text: the client wraps the
			# name in it (two lines); a longer name keeps its single line.
			"Panel/Label_Item":{"role":"source_text","text":str(entry.name),"cocos_wrap":true},
			"Panel/Button":{"activate":Callable(self,"_recharge_pressed").bind(i)},
			"Panel/Button/Normal/Label":{"role":"source_text","text":"사용" if usable else "구입"},
			"Item_Slot/Btn":{"displaystate":false},
			"Item_Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false},
			"Item_Slot/Text_Amount":{"role":"source_text","text":number_text(int(entry.owned)),"visible":usable},
		}
		var built: Dictionary=_tree.scene_of(TIME_ROW,row_spec,row_out)
		if not built.get("ok",false):
			row_spec["Panel/Label_Item"]={"role":"source_text","text":str(entry.name)}
			row_out={}
			built=_tree.scene_of(TIME_ROW,row_spec,row_out)
		if not built.get("ok",false):return built
		_tree.add_row(content,TIME_ROW,built.scene,i,size)
		built_rows.append(built.scene)
		Storage_forward(built.scene,row_out,"Panel/Button",_time)
		if _item_row_picture(built.scene,row_out,"Item_Slot/Sp_IconSample",entry.item_row,str(entry.name)):pictures+=1
	_time.bind(content,built_rows,height,size.y,false)
	return {"ok":true,"pictures":pictures}

## --- Rows ---------------------------------------------------------------------

## Common_Slot reward cells left to right in a horizontal ListView.
func _fill_slots(root: Node2D, out: Dictionary, suffix: String, member: String, slots: Array) -> Dictionary:
	var content: Variant=_list_content(root,out,suffix)
	if not content is Node2D:return _fail("source_dungeon_window_reward_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,member,suffix)
	var pictures: int=0
	for i: int in range(slots.size()):
		var slot: Dictionary=slots[i]
		var cell_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(SLOT,{
			"Btn":{"activate":Callable(self,"_slot_pressed").bind(str(slot.name),int(slot.amount))},
			"Sp_IconSample":{"role":"source_asset_slot","visible":false},
			"Text_Amount":{"role":"source_text","text":number_text(int(slot.amount)),"visible":int(slot.amount)>1},
		},cell_out)
		if not built.get("ok",false):return built
		var cell: Node2D=built.scene
		cell.position=Vector2(SLOT_PITCH*0.5+SLOT_PITCH*float(i),-size.y*0.5)
		cell.visible=SLOT_PITCH*float(i+1)<=size.x+1.0
		content.add_child(cell)
		if int(slot.class_id)>0 and _class_picture(cell,cell_out,"Sp_IconSample",int(slot.class_id),str(slot.name)):pictures+=1
	return {"ok":true,"pictures":pictures}

func _list_content(root: Node2D, out: Dictionary, suffix: String) -> Variant:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	return node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null

## A row of a horizontal ListView (left to right, vertically centred).
func _add_column(content: Node2D, member: String, row: Node2D, i: int, list_size: Vector2, gap: float) -> void:
	var panel: Dictionary=_tree.row_panel(member)
	var w: float=float(panel.size[0])
	var h: float=float(panel.size[1])
	var left: float=(w+gap)*float(i)
	var bottom: float=(list_size.y-h)*0.5
	row.position=Vector2(left-(float(panel.position[0])-float(panel.anchor[0])*w),-(bottom-(float(panel.position[1])-float(panel.anchor[1])*h)))
	content.add_child(row)

## Drags that start on a row button still scroll its list.
static func Storage_forward(root: Node2D, out: Dictionary, suffix: String, scroller: Scroller) -> void:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if area is Control and not area.gui_input.is_connected(scroller.input):area.gui_input.connect(scroller.input)

func _class_picture(root: Node2D, out: Dictionary, suffix: String, class_id: int, title: String) -> bool:
	return _apply_picture(root,out,suffix,SourceImages.describe_item_class(class_id,title))

func _item_row_picture(root: Node2D, out: Dictionary, suffix: String, item_row: Dictionary, title: String) -> bool:
	return _apply_picture(root,out,suffix,SourceImages.describe_item_class_row(item_row,title))

func _apply_picture(root: Node2D, out: Dictionary, suffix: String, info: Dictionary) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## --- Actions -----------------------------------------------------------------

func _set_tab(value: String) -> Dictionary:
	tab=value
	hard=false
	index=0
	time_open=false
	_special.at=0.0
	return _stage()

func _toggle_hard() -> Dictionary:
	hard=not hard
	index=0
	return _stage()

func _step(delta: int) -> Dictionary:
	index=clampi(index+delta,0,maxi(0,rows.size()-1))
	return _stage()

func _next_hero() -> Dictionary:
	var view: Object=_view.get_ref() if _view!=null else null
	if view==null:return _fail("source_dungeon_window_host_unavailable")
	var count: int=view.orim_hero.item_count
	hero=(hero+1)%count if count>0 else -1
	return _stage()

func _clear_hero() -> Dictionary:
	hero=-1
	return _stage()

func _open_time(group_id: int) -> Dictionary:
	if _special.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	time_open=true
	time_group=group_id
	_time.at=0.0
	return _stage()

func _close_time() -> Dictionary:
	time_open=false
	time_group=0
	return _stage()

func _slot_pressed(name: String, amount: int) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null:hud.show_message("%s × %s" % [name,number_text(amount)])
	return {"ok":true,"shown":name}

## The confirmation, then the existing view's action on the selected row;
## its notice (the existing result text) is shown.
func _confirm(title: String, body: String, button: String, run: Callable) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_dungeon_window_host_unavailable")
	hud.confirm_action(title,body,button,func(_count: int) -> void:
		run.call()
		refresh())
	return {"ok":true,"confirming":title}

func _notice(view: Object) -> void:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null and is_instance_valid(view) and not str(view.notice.text).is_empty():hud.show_message(str(view.notice.text))

func _tower_pressed(action: String) -> Dictionary:
	if action.is_empty() or index>=rows.size():return {"ok":true,"empty":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var view: Object=_bind_view(_family(),index)
	if hud==null or view==null:return _fail("source_dungeon_window_host_unavailable")
	var world: Node=hud.get_parent()
	var entry: Dictionary=rows[index]
	var floor: String="%d층 · %s" % [int(entry.stage.StageIndex),str(entry.place.name)]
	var run: Callable=func() -> void:
		var bound: Object=_bind_view(_family(),index)
		if bound!=null:bound._perform(action)
	match action:
		"begin":
			var costs: Dictionary=world.source_dungeon_tower_cost(hard)
			return _confirm("시련의 탑 · 도전",floor+"\n입장 비용: 아인하사드 %d\n도전 중 이탈하면 실패하며 입장 비용은 환급되지 않습니다." % int(costs.get("BaseTryCurrencyCost",0)),"도전",run)
		"immediate":
			return _confirm("시련의 탑 · 즉시 완료",floor+"\n즉시 완료 비용: %d %s" % [int(entry.immediate.payment.Amount),str(entry.immediate.currency.name)],"즉시 완료",run)
		"purchase":
			return _confirm("시련의 탑 · 횟수 구매",floor+"\n이 모드의 추가 도전 횟수를 구매합니다.","횟수 구매",run)
		"leave":
			return _confirm("시련의 탑 · 도전 포기",floor+"\n도전을 포기하면 실패하며 입장 비용은 환급되지 않습니다.","도전 포기",run)
		_:
			run.call()
			return refresh()

func _orim_pressed(action: String) -> Dictionary:
	if index>=rows.size():return {"ok":true,"empty":true}
	var view: Object=_bind_view(_family(),index)
	if view==null:return _fail("source_dungeon_window_host_unavailable")
	if action=="begin" and hero<0:
		var hud: Node=_hud.get_ref() if _hud!=null else null
		if hud!=null:hud.show_message("캐릭터를 선택하세요.")
		return {"ok":true,"hero_required":true}
	var entry: Dictionary=rows[index]
	var stage: String=orim_title(int(entry.stage.StageIndex))
	var chosen: int=hero
	var run: Callable=func() -> void:
		var bound: Object=_bind_view(_family(),index)
		if bound==null:return
		if action=="begin" and chosen>=0 and chosen<bound.orim_hero.item_count:bound.orim_hero.select(chosen)
		bound._play_action(action)
		_notice(bound)
	match action:
		"begin":return _confirm("오림의 흔적 · 도전",stage+"\n캐릭터: "+str(view.orim_hero.get_item_text(chosen)).get_slice(" · ",0),"도전",run)
		"stop":return _confirm("오림의 흔적 · 종료",stage+"\n진행 중인 도전을 종료하고 정산을 폐기합니다.","종료",run)
		_:
			run.call()
			return refresh()

func _special_pressed(i: int) -> Dictionary:
	if _special.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	if i<0 or i>=rows.size():return {"ok":true,"empty":true}
	var view: Object=_bind_view("special",i)
	if view==null:return _fail("source_dungeon_window_host_unavailable")
	var entry: Dictionary=rows[i]
	var body: String="%s\n이동 비용: %s %s\n필요 레벨: %d" % [special_name(entry),number_text(int(entry.teleport.TeleportCost)),str(entry.currency.name),special_level(entry)]
	return _confirm("특수 던전 · 입장",body,"입장",func() -> void:
		var bound: Object=_bind_view("special",i)
		if bound==null:return
		bound._play_action("begin")
		_notice(bound))

func _recharge_pressed(i: int) -> Dictionary:
	if _time.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_dungeon_window_host_unavailable")
	var time_rows: Array=_recharger_rows(hud.get_parent())
	if i<0 or i>=time_rows.size():return {"ok":true,"empty":true}
	var entry: Dictionary=time_rows[i]
	var buy: bool=int(entry.owned)<=0
	var row: int=int(entry.row)
	var action: String="buy_charge" if buy else "recharge"
	var body: String=str(entry.name)+("\nTWILIGHT 자체 충전석을 %d아데나에 구입합니다." % int(hud.get_parent().dungeon_play.state.settings.recharger_price) if buy else "\n사용 시 추가 이용 시간 1시간이 충전됩니다.")
	return _confirm("시간 충전석 사용" if not buy else "시간 충전석 구입",body,"구입" if buy else "사용",func() -> void:
		var bound: Object=_bind_view("rechargers",row)
		if bound==null:return
		bound._play_action(action)
		_notice(bound))

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _fail(code: String) -> Dictionary:
	last_result={"ok":false,"handled":false,"code":code}
	return last_result
