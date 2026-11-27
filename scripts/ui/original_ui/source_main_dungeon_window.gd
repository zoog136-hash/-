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
## The extra parts read the dungeon data API (world.dungeon_play, #614;
## TWILIGHT 근사 where its basis says so):
##   시련의 탑 버프 구매 (Nd_BuffInfo: one Mission_Dungeon_TracesOrim_SlotBtn per
##   TrialTowerBuff offer, tower_buy_buff), 스피드 모드 (tower_speed_mode /
##   tower_set_speed_mode), 클리어 타임 랭킹 (Btn_Ranking -> Nd_Popup_Ranking,
##   Mission_List_TrialTower_Rank rows of tower_ranking; a tap outside the list
##   closes it), 상점 (dungeon_shop: the HUD's own shop route; 오림 has none),
##   오림 업적 (Nd_Achievement: Nd_New while one is claimable; a tap claims it
##   or names the progress) and the chapter story (Btn_Story_On / Off,
##   orim_chapter_story; a locked chapter says so).
## Left empty (no picture or rule in the original data here): dungeon
## thumbnails (SpecialDungeon.EntranceAssetID / Orim chapter and hero
## art are not in the packs), the 시련의 탑
## help (Mission_Tooltip_TrialTower is the 2019 event text), the floor tower
## art (no original floor picture), the rank class / medal icons, the 오림
## shop, bookmarks, share and notices. The 오림의 흔적
## Btn_HelpBox opens the original HelpBox_Mission_TracesOrim.
## Party dungeons are excluded (user decision 2026-11-12).
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Rows=preload("res://scripts/resources/current523_definition_rows.gd")
const COMPETITION=preload("res://scripts/dungeons/competition_dungeon523.gd")
const HelpBox=preload("res://scripts/ui/original_ui/source_main_help_box.gd")
const ROOT="UI/Mission/Mission_Dungeon_All.csb"
const TAB="UI/Mission/Mission_List_Dungeon.csb"
const TOWER="UI/Mission/Mission_Dungeon_TrialTower.csb"
const ORIM="UI/Mission/Mission_Dungeon_TracesOrim.csb"
const SPECIAL="UI/Mission/Mission_Dungeon_Special.csb"
const SPECIAL_ROW="UI/Mission/Mission_DungeonSpecial_Btn.csb"
const TIME="UI/Mission/Mission_Popup_Time.csb"
const TIME_ROW="UI/Mission/Mission_List_Time.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## 오림의 흔적 버프 구매 rows (optional: an older UI pack keeps the list out).
const BUFF_ROW="UI/Mission/Mission_Dungeon_TracesOrim_SlotBtn.csb"
## The 클리어 타임 랭킹 row (optional like BUFF_ROW: an older pack keeps the popup out).
const RANK_ROW="UI/Mission/Mission_List_TrialTower_Rank.csb"
const RANK_GAP: float=2.0
## The largest buff picture (px) the 64px buff slot shows.
const ICON_MAX: float=128.0
const CURRENCY_NAMES={1:"아데나",4:"다이아"}
const MEMBER_SCOPES={SLOT:[15728,15316,15012,6880]}
const REQUIRED: Array[String]=[ROOT,TAB,TOWER,ORIM,SPECIAL,SPECIAL_ROW,TIME,TIME_ROW,SLOT]
## Mission_Dungeon_All_Layout in MissionScene (600, 337.5).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
## Tab order: UIDungeonCategory ViewOrder (특수 0, 시련 1), then 오림.
const TABS: Array=[["special","특수 던전"],["tower","시련"],["orim","오림의 흔적"],["world","월드 던전"],["master","마스터 던전"]]
## 시련 tab (user decision 2026-11-16): the original 시련 page
## Mission_Dungeon_Trial lists 시련의 탑 (this window's TrialTower page, whose
## Btn_Back returns here) and 시련 던전 (the Dungeon_Trial_All window over the
## existing Challenge feature) as Mission_DungeonTrial_Btn rows. Without those
## members the tab opens the TrialTower page as before.
const TRIAL="UI/Mission/Mission_Dungeon_Trial.csb"
const TRIAL_ROW="UI/Mission/Mission_DungeonTrial_Btn.csb"
const P_TRIAL="Mission_Dungeon_Trial/"
const TRIAL_ROWS: Array=[["tower","시련의 탑"],["dungeon","시련 던전"]]
const TRIAL_GAP: float=4.0
const PAGES={"special":"Mission_Dungeon_Special","tower":"Mission_Dungeon_TrialTower","orim":"Mission_Dungeon_TracesOrim"}
## Pages of Mission_Dungeon_All this window never mounts (party excluded).
const OTHER: Array[String]=["Mission_Dungeon_MasterDungeon","Mission_Dungeon_GlobalMaster","Mission_Dungeon_Competition_Theberas","Mission_Dungeon_Competition_Lastavard","Mission_Dungeon_Siege","Mission_Dungeon_Defense","Mission_Dungeon_Arena","Mission_Dungeon_ElfDefense","Mission_Dungeon_Season","Mission_Dungeon_PartyDungeon","Fx_Loading"]
## The existing view's families (source_dungeon_view.FAMILIES).
const FAMILY={"tower":0,"tower_hard":1,"orim":2,"orim_hard":3,"special":4,"rechargers":5,"world":6,"master":7}
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
var _help_box: RefCounted
var _view: WeakRef
var _scene: Node2D
var _last_out: Dictionary={}
var tab: String="special"
const ESCAROS_ID: int=314
var _focused_escaros: bool=false
## 시련 tab: the Mission_Dungeon_Trial list (true) or the TrialTower page.
var trial_list: bool=true
var hard: bool=false
## Selected tower floor / orim stage (row index of the current family).
var index: int=0
## Orim hero (OrimsTrailCharacter selectable index; -1: none chosen).
var hero: int=-1
## 시간 충전석 popup open, and the special row's time group it shows (0: all).
var time_open: bool=false
var ranking_open: bool=false
var story_open: bool=false
var _rank: Scroller=Scroller.new()
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
	var visible_row: Callable

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
			if items[i].visible and visible_row.is_valid():visible_row.call(items[i],i)

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
func open(parent: Node, view: Object, initial_tab: String="special", focus: int=0) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(view) or not view.has_method("_refresh"):return _fail("source_dungeon_window_host_unavailable")
	_parent=weakref(parent)
	_view=weakref(view)
	tab=initial_tab if initial_tab in FAMILY and initial_tab not in ["rechargers","tower_hard","orim_hard"] else "special"
	_focused_escaros=tab=="world" and focus==ESCAROS_ID
	hard=false
	index=0
	hero=-1
	time_open=false
	time_group=0
	ranking_open=false
	story_open=false
	_special.at=0.0
	_time.at=0.0
	return _stage()

func refresh() -> Dictionary:
	if not is_open():return {"ok":true,"handled":false}
	return _stage()

func close() -> void:
	if _help_box!=null:_help_box.close()
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

func _competition_page() -> bool:
	return COMPETITION.FAMILY.has(tab)

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
	if _focused_escaros:
		rows=rows.filter(func(row: Dictionary) -> bool:return int(row.get("id",0))==ESCAROS_ID)
		if rows.is_empty():return _fail("source_dungeon_escaros_declaration_unavailable")
	index=clampi(index,0,maxi(0,rows.size()-1))
	var spec: Dictionary={}
	for name: String in OTHER:spec[name]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["ListView_Button"]={"input":Callable(self,"_ignore_input")}
	for page: String in PAGES:
		if (page==tab or (page=="special" and _competition_page())) and not _trial_mode():spec[PAGES[page]]={"visible":true}
		else:spec[PAGES[page]]={"exclude":true}
	if _trial_mode():spec.merge(_trial_spec(world),true)
	else:spec["Mission_Dungeon_Trial"]={"exclude":true}
	if not time_open:spec["Mission_Popup_Time"]={"exclude":true}
	match tab:
		"tower":if not _trial_mode():spec.merge(_tower_spec(world,view),true)
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
			"tower" when _trial_mode():filled=_fill_trial(next,out,world)
			"tower":
				filled=_fill_slots(next,out,P_TOWER+"Nd_TowerInfo_All/Nd_Reward/ListView",TOWER,reward_slots(_rewards(rows[index] if index<rows.size() else {})))
				if filled.get("ok",false) and _has(BUFF_ROW) and world.dungeon_play.has_method("tower_buff_offers") and not ranking_open:
					var offers: Dictionary=_fill_buff_rows(next,out,P_TOWER+"Nd_TowerInfo_All/Nd_BuffInfo/ListView",TOWER,_tower_buff_rows(world))
					filled=offers if not offers.get("ok",false) else filled.merged({"buffs":int(offers.buffs),"pictures":int(filled.get("pictures",0))+int(offers.pictures)},true)
				if filled.get("ok",false) and ranking_open:
					var ranked: Dictionary=_fill_ranking(next,out,world)
					filled=ranked if not ranked.get("ok",false) else filled.merged({"ranks":int(ranked.ranks)},true)
			"orim":
				filled=_fill_slots(next,out,P_ORIM+"Nd_OrimInfo_All/Nd_Info/Nd_Reward/ListView",ORIM,reward_slots(_rewards(rows[index] if index<rows.size() else {})))
				if filled.get("ok",false) and _pack.manifest.get("scenes",{}).has(BUFF_ROW):
					var buffs: Dictionary=_fill_buff_rows(next,out,P_ORIM+"Nd_OrimInfo_All/Nd_Info/Nd_Buff/ListView",ORIM,_orim_buff_rows(world))
					filled=buffs if not buffs.get("ok",false) else filled.merged({"buffs":int(buffs.buffs),"pictures":int(filled.get("pictures",0))+int(buffs.pictures)},true)
			_:filled=_fill_competition(next,out,world) if _competition_page() else _fill_special(next,out,world)
		pictures+=int(filled.get("pictures",0))
	if filled.get("ok",false) and time_open:
		filled=_fill_time(next,out,world,time_rows)
		pictures+=int(filled.get("pictures",0))
	if not filled.get("ok",false):
		next.free()
		last_result=filled
		return filled
	# The 오림 page starts transparent at its Popup_On keyframe: its own loop clip.
	if tab=="orim":
		var page: Dictionary=NamedTree.locate(next,out,"Mission_Dungeon_TracesOrim")
		var holder: Variant=page.player.source_nodes.get(page.offset) if page.get("ok",false) else null
		var nested: Variant=(holder as Node).get_meta("source_project_player") if holder is Node and (holder as Node).has_meta("source_project_player") else null
		if nested is Node2D:nested.play("Fx_Loop_Hard" if hard else "Fx_Loop",true)
		# The chapter story fades in on its own Fx_Story_On clip.
		if story_open:
			var chapter: Dictionary=NamedTree.locate(next,out,"Nd_Chapter")
			var chapter_node: Variant=chapter.player.source_nodes.get(chapter.offset) if chapter.get("ok",false) else null
			var chapter_player: Variant=(chapter_node as Node).get_meta("source_project_player") if chapter_node is Node and (chapter_node as Node).has_meta("source_project_player") else null
			if chapter_player is Node2D:chapter_player.play("Fx_Story_On",false)
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"tab":tab,"trial_list":_trial_mode(),"hard":hard,"rows":rows.size(),"index":index,"time_open":time_open,"time_rows":time_rows.size(),"pictures":pictures,"buffs":int(filled.get("buffs",0)),"ranking_open":ranking_open,"ranks":int(filled.get("ranks",0)),"story_open":story_open}
	return last_result

## The original OrimsTrailBuff rows: [{buff_id, currency, cost}].
static func orim_buffs(world: Node) -> Array:
	var service: Variant=world.get("dungeon_play") if world!=null else null
	var rules: Variant=service.get("rules") if service is Object else null
	var data: Variant=rules.get("data") if rules is Object else null
	var rows_value: Variant=data.get("declarations",{}).get("OrimsTrailBuff",[]) if data is Dictionary else []
	var found: Array=[]
	for row: Variant in rows_value:
		if row is Dictionary and int(row.get("BuffClassID",0))>0:found.append({"buff_id":int(row.BuffClassID),"currency":int(row.get("CurrencyID",0)),"cost":int(row.get("CurrencyCost",0))})
	return found

func _has(member: String) -> bool:
	return _pack.manifest.get("scenes",{}).has(member)

## 오림 버프 구매 rows: the original OrimsTrailBuff (bought ones checked).
func _orim_buff_rows(world: Node) -> Array:
	var run: Dictionary=world.dungeon_play.state.active
	var bought: Dictionary=run.get("buffs",{}) if run.get("kind","")=="orim" else {}
	var found: Array=[]
	for buff: Dictionary in orim_buffs(world):
		found.append({"buff_class_id":int(buff.buff_id),"cost":int(buff.cost),"owned":bought.has(str(buff.buff_id)),"activate":Callable(self,"_buy_orim_buff").bind(int(buff.buff_id))})
	return found

## 시련의 탑 버프 구매 rows: tower_buff_offers of this mode (the active one checked).
func _tower_buff_rows(world: Node) -> Array:
	var found: Array=[]
	var floor: int=int((rows[index] if index<rows.size() else {}).get("stage",{}).get("StageIndex",0))
	for offer: Dictionary in world.dungeon_play.tower_buff_offers(floor):
		found.append({"buff_class_id":int(offer.get("buff_class_id",0)),"cost":int(offer.get("cost",{}).get("amount",0)),"owned":bool(offer.get("active",false)),"activate":Callable(self,"_buy_tower_buff").bind(int(offer.get("buff_id",0)))})
	return found

## 버프 구매: one Mission_Dungeon_TracesOrim_SlotBtn per buff row (its
## BuffClass OnIconID picture, the price; bought / active ones checked).
func _fill_buff_rows(root: Node2D, out: Dictionary, suffix: String, member: String, buff_rows: Array) -> Dictionary:
	var content: Variant=_list_content(root,out,suffix)
	if not content is Node2D:return _fail("source_dungeon_window_buff_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,member,suffix)
	var pictures: int=0
	for i: int in range(buff_rows.size()):
		var buff: Dictionary=buff_rows[i]
		var owned: bool=bool(buff.owned)
		var cell_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(BUFF_ROW,{
			"Panel/Sp_IconSample":{"role":"source_asset_slot","visible":false},
			"Panel/Sp_Icon_TokenOfOrim":{"visible":false},
			"Panel/Text_Price":{"role":"source_text","text":number_text(int(buff.cost))},
			"Panel/Btn_Normal":{"visible":not owned,"activate":buff.activate},
			"Panel/Btn_Pressed":{"visible":owned,"activate":buff.activate},
		},cell_out)
		if not built.get("ok",false):return built
		_add_column(content,BUFF_ROW,built.scene,i,size,0.0)
		var icon: Dictionary=SourceImages.resolve_consumer("BuffClass",int(buff.buff_class_id),"OnIconID")
		# Only an icon-sized picture fits the slot (some OnIconIDs name a large effect frame).
		var texture: Variant=icon.get("texture")
		if texture is Texture2D and maxf((texture as Texture2D).get_width(),(texture as Texture2D).get_height())<=ICON_MAX and _apply_picture(built.scene,cell_out,"Panel/Sp_IconSample",icon):pictures+=1
	return {"ok":true,"buffs":buff_rows.size(),"pictures":pictures}

func _buy_orim_buff(buff_id: int) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	if world==null:return _fail("source_dungeon_window_host_unavailable")
	var cost: String=""
	for buff: Dictionary in orim_buffs(world):
		if int(buff.buff_id)==buff_id:cost="%s %s" % [str(CURRENCY_NAMES.get(int(buff.currency),"재화")),number_text(int(buff.cost))]
	var result: Dictionary=world.dungeon_play.buy_buff(buff_id)
	hud.show_message(("버프를 구매했습니다 · "+cost) if result.get("ok",false) else "%s (%s)" % [str(result.get("reason","구매할 수 없습니다")),cost])
	var staged: Dictionary=refresh()
	staged["buy"]=result
	return staged

func _buy_tower_buff(buff_id: int) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	if world==null:return _fail("source_dungeon_window_host_unavailable")
	var cost: String=""
	for offer: Dictionary in world.dungeon_play.tower_buff_offers():
		if int(offer.get("buff_id",0))==buff_id:cost="%s %s" % [str(offer.get("cost",{}).get("currency","재화")),number_text(int(offer.get("cost",{}).get("amount",0)))]
	var result: Dictionary=world.dungeon_play.tower_buy_buff(buff_id)
	hud.show_message(str(result.get("message","버프를 구매했습니다"))+" · "+cost if result.get("ok",false) else "%s (%s)" % [str(result.get("reason","구매할 수 없습니다")),cost])
	var staged: Dictionary=refresh()
	staged["buy"]=result
	return staged

## 클리어 타임 랭킹: Mission_List_TrialTower_Rank rows of this floor's
## tower_ranking (rank, name, clear time; the player's own rows marked), and
## a transparent catcher under the list that closes the popup (its authored
## full-screen Btn_Close carries a title in a font the pack does not ship).
func _fill_ranking(root: Node2D, out: Dictionary, world: Node) -> Dictionary:
	var suffix: String=P_TOWER+"Nd_Popup_Ranking/ListView_Rank"
	var content: Variant=_list_content(root,out,suffix)
	if not content is Node2D:return _fail("source_dungeon_window_rank_list_missing")
	var located: Dictionary=NamedTree.locate(root,out,P_TOWER+"Nd_Popup_Ranking")
	var popup: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	if popup is Node2D:
		var catcher:=Control.new()
		catcher.name="DungeonRankingOutsideClose"
		catcher.position=Vector2(-4000.0,-4000.0)
		catcher.size=Vector2(8000.0,8000.0)
		catcher.mouse_filter=Control.MOUSE_FILTER_STOP
		catcher.gui_input.connect(_ranking_outside)
		(popup as Node2D).add_child(catcher)
		(popup as Node2D).move_child(catcher,0)
	var size: Vector2=NamedTree.list_size(out,_pack,TOWER,suffix)
	var panel: Dictionary=_tree.row_panel(RANK_ROW)
	var w: float=float(panel.size[0])
	var h: float=float(panel.size[1])
	var entry: Dictionary=rows[index] if index<rows.size() else {}
	var ranking: Dictionary=world.dungeon_play.tower_ranking(int(entry.get("stage",{}).get("StageIndex",0)),hard)
	var me: String=str(world.get("character_display_name")) if world.get("character_display_name")!=null else ""
	var built_rows: Array[Node2D]=[]
	for i: int in range(ranking.get("rows",[]).size()):
		var row: Dictionary=ranking.rows[i]
		var seconds: int=int(row.get("clear_sec",0))
		var built: Dictionary=_tree.scene_of(RANK_ROW,{
			"Panel":{"input":Callable(_rank,"input")},
			"Panel/Nd_Me":{"visible":not me.is_empty() and str(row.get("name",""))==me},
			"Panel/Label_Rank":{"role":"source_text","text":str(int(row.get("rank",i+1)))},
			"Panel/Label_Name":{"role":"source_text","text":str(row.get("name",""))},
			"Panel/Label_Clan":{"role":"source_text","text":str(row.get("class",""))},
			"Panel/Nd_Time/Label_Min":{"role":"source_text","text":"%02d분 %02d초" % [seconds/60,seconds%60]},
			"Panel/Sp_Rank":{"visible":false},"Panel/Icon_Keep":{"visible":false},"Panel/Sp_Class":{"visible":false},
		},{})
		if not built.get("ok",false):return built
		var top: float=size.y-(h+RANK_GAP)*float(i)
		built.scene.position=Vector2((size.x-w)*0.5-(float(panel.position[0])-float(panel.anchor[0])*w),-(top-h-(float(panel.position[1])-float(panel.anchor[1])*h)))
		(content as Node2D).add_child(built.scene)
		built_rows.append(built.scene)
	_rank.bind(content,built_rows,h+RANK_GAP,size.y,false)
	if built_rows.is_empty():
		var hud: Node=_hud.get_ref() if _hud!=null else null
		if hud!=null:hud.show_message("%d층 클리어 기록이 없습니다 (이 기기의 기록)" % int(entry.get("stage",{}).get("StageIndex",0)))
	return {"ok":true,"ranks":built_rows.size()}

func _ranking_outside(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)) and not event.pressed:
		_toggle_ranking.call_deferred()

func _toggle_ranking() -> Dictionary:
	ranking_open=not ranking_open
	_rank.at=0.0
	return _stage()

func _speed_mode() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	if world==null:return _fail("source_dungeon_window_host_unavailable")
	var mode: Dictionary=world.dungeon_play.tower_speed_mode()
	if not bool(mode.get("available",false)):
		hud.show_message(str(mode.get("reason","스피드 모드를 바꿀 수 없습니다")))
		return {"ok":false,"handled":true}
	var result: Dictionary=world.dungeon_play.tower_set_speed_mode(not bool(mode.get("on",false)))
	var now: Dictionary=world.dungeon_play.tower_speed_mode()
	hud.show_message(("스피드 모드 %s · %s" % ["켜짐" if bool(now.get("on",false)) else "꺼짐",str(now.get("basis",""))]) if result.get("ok",false) else str(result.get("reason","바꿀 수 없습니다")))
	var staged: Dictionary=refresh()
	staged["speed"]=result
	return staged

## 상점: the dungeon's own shop route (dungeon_shop), else a message.
func _shop(kind: String) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	if world==null:return _fail("source_dungeon_window_host_unavailable")
	var route: Dictionary=world.dungeon_play.dungeon_shop(kind)
	var method: String=str(route.get("open_method",""))
	if method.is_empty() or not hud.has_method(method):
		hud.show_message("이 던전의 상점이 없습니다")
		return {"ok":false,"handled":true}
	close()
	hud.callv(method,route.get("args",[]))
	return {"ok":true,"handled":true,"routed":method}

func _chapter() -> int:
	return int((rows[index] if index<rows.size() else {}).get("stage",{}).get("StageIndex",0))

## 오림 업적: claims a claimable chapter achievement, else names the progress.
func _achievement() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var world: Node=hud.get_parent() if hud!=null else null
	if world==null:return _fail("source_dungeon_window_host_unavailable")
	var lines: PackedStringArray=[]
	for row: Dictionary in world.dungeon_play.orim_achievements(_chapter()):
		if bool(row.get("can_claim",false)):
			var result: Dictionary=world.dungeon_play.orim_claim_achievement(str(row.id))
			hud.show_message("%s · %s" % [str(row.get("name","")),str(result.get("message","")) if result.get("ok",false) else str(result.get("reason",""))])
			var staged: Dictionary=refresh()
			staged["claim"]=result
			return staged
		lines.append("%s %s" % [str(row.get("name","")),"완료" if bool(row.get("claimed",false)) else "%d/%d" % [int(row.get("progress",0)),int(row.get("goal",1))]])
	hud.show_message(" · ".join(lines) if not lines.is_empty() else "이 장의 업적이 없습니다")
	return {"ok":true,"handled":true,"claim":{}}

func _toggle_story() -> Dictionary:
	story_open=not story_open
	return _stage()

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
		var caption: String=COMPETITION.title(id) if COMPETITION.FAMILY.has(id) else str(TABS[i][1])
		var built: Dictionary=_tree.scene_of(TAB,{
			"Panel":{"input":Callable(self,"_ignore_input")},
			"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_set_tab").bind(id)},
			"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_set_tab").bind(id)},
			"Btn_Normal/Label":{"role":"source_text","text":caption},
			"Btn_Pressed/Label":{"role":"source_text","text":caption},
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
	if _trial_available():spec[p+"Btn_Back"]={"activate":Callable(self,"_trial_back")}
	else:spec[p+"Btn_Back"]={"exclude":true}
	for name: String in ["Label_Notice","Btn_HelpBox","Nd_MoveFloor/Nd_Navi","Nd_TowerInfo_All/Nd_StageInfo/Btn_InfoView","Nd_TowerInfo_All/Nd_ReChallenge/Common_Slot_Layout"]:spec[p+name]={"exclude":true}
	var extras: bool=world.dungeon_play.has_method("tower_buff_offers")
	# 버프 구매 (TrialTowerBuff offers in the SlotBtn rows).
	# The ranking popup covers the buff list (its rows would draw over the popup).
	if extras and _has(BUFF_ROW) and not ranking_open:spec[i+"Nd_BuffInfo/ListView"]={"input":Callable(self,"_ignore_input")}
	else:spec[i+"Nd_BuffInfo"]={"exclude":true}
	# 스피드 모드 (the existing local tower time scale).
	if extras:
		var speed: Dictionary=world.dungeon_play.tower_speed_mode()
		var on: bool=bool(speed.get("on",false))
		var usable: bool=bool(speed.get("available",false))
		spec[i+"Nd_SpeedMode/Btn_Off"]={"visible":usable and not on,"activate":Callable(self,"_speed_mode")}
		spec[i+"Nd_SpeedMode/Btn_On"]={"visible":usable and on,"activate":Callable(self,"_speed_mode")}
		spec[i+"Nd_SpeedMode/Btn_Disabled"]={"visible":not usable,"activate":Callable(self,"_speed_mode")}
		spec[p+"Btn_Shop"]={"activate":Callable(self,"_shop").bind("tower")}
	else:
		for name: String in ["Nd_TowerInfo_All/Nd_SpeedMode","Btn_Shop"]:spec[p+name]={"exclude":true}
	# 클리어 타임 랭킹 (this device's records).
	if extras and _has(RANK_ROW):
		spec[p+"Btn_Ranking"]={"activate":Callable(self,"_toggle_ranking")}
		if ranking_open:
			spec[p+"Nd_Popup_Ranking"]={"visible":true}
			spec[p+"Nd_Popup_Ranking/Btn_Close"]={"exclude":true}
			spec[p+"Nd_Popup_Ranking/ListView_Rank"]={"input":Callable(_rank,"input")}
		else:spec[p+"Nd_Popup_Ranking"]={"exclude":true}
	else:
		for name: String in ["Btn_Ranking","Nd_Popup_Ranking"]:spec[p+name]={"exclude":true}
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
	spec[p+"Btn_HelpBox"]={"activate":Callable(self,"_orim_help")}
	for name: String in ["Label_Notice","Btn_Shop","Btn_Back","Fx_Img_BG_Particle","Sp_Light","Nd_PanelOrim/Panel_OrimPage/Nd_Page_Move","Nd_OrimInfo_All/Nd_CardInfo/Nd_CardOn/Panel_Card/Nd_Character"]:spec[p+name]={"exclude":true}
	# 업적 and the chapter story (orim_achievements / orim_chapter_story).
	if world.dungeon_play.has_method("orim_achievements"):
		var chapter: int=int((rows[index] if index<rows.size() else {}).get("stage",{}).get("StageIndex",0))
		var claimable: bool=world.dungeon_play.orim_achievements(chapter).any(func(row: Dictionary) -> bool: return bool(row.get("can_claim",false)))
		spec[p+"Nd_Achievement/Button"]={"activate":Callable(self,"_achievement")}
		spec[p+"Nd_Achievement/Button/Nd_Orim/Nd_New"]={"visible":claimable}
		# The badge's glow sprites start on clip keyframes (left out; the NEW mark stays).
		for glow: String in ["Nd_Orim/Fx_Glow","Nd_Orim/Fx_Lighting_Rotation","Nd_Orim/Panel_Shining","Nd_Orim/Nd_New/Img_Light_Back","Nd_Orim/Nd_New/Sp_New_Blend","Nd_Orim/Nd_New/Fx_Glow"]:spec[p+"Nd_Achievement/Button/"+glow]={"exclude":true}
		var story: Dictionary=world.dungeon_play.orim_chapter_story(chapter)
		var told: String=str(story.get("text","")) if bool(story.get("unlocked",false)) else "이전 장을 클리어하면 열립니다."
		spec[p+"Nd_Chapter/Nd_ChapterStory/Nd_Story"]={"visible":story_open}
		spec[p+"Nd_Chapter/Nd_ChapterStory/Nd_Story/Label_Story"]={"role":"source_text","text":told if not story.is_empty() else "-"}
		spec[p+"Nd_Chapter/Nd_ChapterStory/Btn_Story_Off"]={"visible":not story_open,"activate":Callable(self,"_toggle_story")}
		spec[p+"Nd_Chapter/Nd_ChapterStory/Btn_Story_On"]={"visible":story_open,"activate":Callable(self,"_toggle_story")}
	else:
		for name: String in ["Nd_Achievement","Nd_Chapter/Nd_ChapterStory"]:spec[p+name]={"exclude":true}
	spec[p+"Fx_HardLoop"]={"visible":hard}
	spec[p+"Nd_Title_Orim/Sp_Normal"]={"visible":not hard}
	spec[p+"Nd_Title_Orim/Sp_Hard"]={"visible":hard}
	spec[i+"Nd_CheckBox/Btn_Off"]={"visible":not hard,"activate":Callable(self,"_toggle_hard")}
	spec[i+"Nd_CheckBox/Btn_On"]={"visible":hard,"activate":Callable(self,"_toggle_hard")}
	spec[i+"Nd_Info/Nd_Reward/ListView"]={"input":Callable(self,"_ignore_input")}
	# 버프 구매: the original OrimsTrailBuff rows over the existing buy_buff.
	if _pack.manifest.get("scenes",{}).has(BUFF_ROW):spec[i+"Nd_Info/Nd_Buff/ListView"]={"input":Callable(self,"_ignore_input")}
	else:spec[i+"Nd_Info/Nd_Buff"]={"exclude":true}
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
	spec[P_SPECIAL+"Label_Notice"]={"role":"source_text","text":"오프라인 원본 입구 이동 · 서버 던전 입장 아님" if not rows.is_empty() else "원본 523 던전 정의를 설치하세요."} if _competition_page() else {"exclude":true}
	spec[P_SPECIAL+"Nd_Touchable"]={"exclude":true}
	spec[P_SPECIAL+"Fx_HighLight"]={"exclude":true}
	spec[P_SPECIAL+"ListView_Daily"]={"input":Callable(_special,"input")}
	return spec

func _fill_special(root: Node2D, out: Dictionary, world: Node) -> Dictionary:
	_special.visible_row=Callable()
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
		# A dungeon whose map is not in the installed pack (or no original
		# field) is locked with that reason instead of its level.
		var blocked: String=world.dungeon_play.special_block(entry)
		var locked: bool=int(world.level)<level or not blocked.is_empty()
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
			"Panel/Nd_Lock/Label_Condition":{"role":"source_text","text":"Lv %d" % level if blocked.is_empty() else "입장 불가"},
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

## Uses the installed source mission tab/card component, not mock-up artwork.
## The competition card slot only accepts the exact source role for this ID.
func _fill_competition(root: Node2D, out: Dictionary, world: Node) -> Dictionary:
	var content: Variant=_list_content(root,out,P_SPECIAL+"ListView_Daily")
	if not content is Node2D:return _fail("source_dungeon_window_competition_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,SPECIAL,"ListView_Daily")
	var width: float=float(_tree.row_panel(SPECIAL_ROW).size[0])
	var list: Array[Node2D]=[]
	var here: int=int(world.orim_current_land().get("land_id",-1))
	var lobby: Dictionary=COMPETITION.lobby(here)
	for i: int in range(rows.size()):
		var entry: Dictionary=rows[i]
		var id: int=int(entry.id)
		var focused: bool=_focused_escaros and id==ESCAROS_ID
		var can_return: bool=not focused and id in lobby.get("ids",[])
		var quote: Dictionary=world.content523.escaros_entry_quote() if focused else world.competition523_quote(id)
		var label: String=str(entry.name)
		if rows.any(func(v: Dictionary) -> bool: return v.id!=id and v.name==entry.name):label+=" #%d" % id
		var price: String=number_text(int(entry.tariff.get("TeleportCost",0)))
		var adena: bool=int(entry.tariff.get("CurrencyID",0))==1
		var spec: Dictionary={
			"Panel":{"input":Callable(_special,"input")},
			# NamedTree supplies the external slot role when the installed
			# source manifest declares it; older packs keep a working list.
			"Panel/Img_Special":{"visible":false},
			"Panel/Button":{"activate":Callable(self,"_competition_pressed").bind(id)},
			"Panel/Label_Dungeon":{"role":"source_text","text":label},
			"Panel/Label_Charge":{"role":"source_text","text":"기란으로 귀환" if can_return else (price if adena else price+" "+str(entry.currency_name))},
			"Panel/Sp_Adena":{"visible":adena and not can_return},
			"Panel/Nd_Lock":{"visible":not can_return and not quote.get("ok",false)},
			"Panel/Nd_Lock/Label_Condition":{"role":"source_text","text":("Lv %d" % int(quote.get("route",{}).get("min_level",0))) if focused and int(quote.get("route",{}).get("min_level",0))>int(world.level) else "이동 보류 · 눌러서 이유 확인"},
		}
		for name: String in ["Btn_Fix","Btn_Item","Btn_Notice","Btn_Share","Btn_HelpBox","Nd_Penalty","Nd_Round","Nd_Closed","Nd_Timebar","Nd_Timebar_Share","Nd_Time","Sp_New","Sp_Event","Label_Retry"]:spec["Panel/"+name]={"exclude":true}
		# This exact CSB uses an ImageView with Mission_Dummy.png, not a
		# declared dynamic Sprite slot. Bind the verified world entrance
		# pixels through the existing ImageView owner at its authored geometry.
		var painting: Dictionary=COMPETITION.picture(entry) if focused else {}
		if painting.get("ok",false):
			var raw: Array[Dictionary]=Rows.related("AssetView","AssetId",int(entry.asset_id))
			var type: Dictionary=Rows.row("AssetType",int(entry.asset_type))
			if raw.size()==1 and not type.is_empty():
				spec["Panel/Img_Special"]={"role":"source_asset","visible":true,"asset_ref":{"AssetView":raw[0],"AssetType":type,"asset_id":int(entry.asset_id),"declared_path":str(entry.asset_path)}}
		var row_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(SPECIAL_ROW,spec,row_out)
		if not built.get("ok",false):return built
		var node: Node2D=built.scene
		node.set_meta("competition523_dungeon_id",id)
		if focused and painting.get("ok",false):
			var slot: Dictionary=NamedTree.locate(node,row_out,"Panel/Img_Special")
			var image: Node2D=slot.player.source_nodes.get(slot.offset) if slot.get("ok",false) else null
			var pixels: Variant=image.get_meta("source_image") if is_instance_valid(image) and image.has_meta("source_image") else null
			node.set_meta("competition523_art_loaded",is_instance_valid(image) and image.visible and pixels is TextureRect and pixels.texture!=null and spec["Panel/Img_Special"].get("role")=="source_asset")
		else:node.set_meta("competition523_art_tree",row_out)
		_add_column(content,SPECIAL_ROW,node,i,size,SPECIAL_GAP)
		list.append(node)
		Storage_forward(node,row_out,"Panel/Button",_special)
	_special.visible_row=Callable(self,"_competition_picture")
	_special.bind(content,list,width+SPECIAL_GAP,size.x,true)
	return {"ok":true,"pictures":list.filter(func(n: Node2D) -> bool: return n.get_meta("competition523_art_loaded",false)).size()}

func _competition_picture(node: Node2D, _index: int) -> void:
	if not node.has_meta("competition523_art_tree"):return
	var out: Dictionary=node.get_meta("competition523_art_tree")
	node.remove_meta("competition523_art_tree")
	var info: Dictionary=COMPETITION.picture(COMPETITION.entry(int(node.get_meta("competition523_dungeon_id"))))
	var shown: bool=_apply_picture(node,out,"Panel/Img_Special",info)
	node.set_meta("competition523_art_status","source_competition_entrance_slot_unavailable" if info.get("ok",false) and not shown else str(info.get("status","")))
	node.set_meta("competition523_art_loaded",shown)

## --- 시련 (Mission_Dungeon_Trial) -------------------------------------------------

func _trial_available() -> bool:
	var scenes: Dictionary=_pack.manifest.get("scenes",{}) if _pack!=null else {}
	return scenes.has(TRIAL) and scenes.has(TRIAL_ROW)

func _trial_mode() -> bool:
	return tab=="tower" and trial_list and _trial_available()

func _trial_spec(_world: Node) -> Dictionary:
	var spec: Dictionary={"Mission_Dungeon_Trial":{"visible":true}}
	for name: String in ["Btn_HelpBox","Btn_Rank","Nd_Rank","Img_Block","Btn_Use","Btn_Complete_All","Common_Slot_Layout_1","Common_Slot_Layout_2","Btn_Buy_All","Label_Event"]:spec[P_TRIAL+name]={"exclude":true}
	# The authored notice also names the 70-level extra dungeons and the
	# original reset; only the TWILIGHT 05:00 reset applies here.
	spec[P_TRIAL+"Label_Notice"]={"role":"source_text","text":"※ 매일 오전 5시 초기화 됩니다."}
	spec[P_TRIAL+"ListView_Daily"]={"input":Callable(self,"_ignore_input")}
	return spec

## 시련의 탑 and 시련 던전 as Mission_DungeonTrial_Btn rows (name; 시련 던전
## locked below the ordinary Challenge level 40).
func _fill_trial(root: Node2D, out: Dictionary, world: Node) -> Dictionary:
	var content: Variant=_list_content(root,out,P_TRIAL+"ListView_Daily")
	if not content is Node2D:return _fail("source_dungeon_window_trial_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,TRIAL,"ListView_Daily")
	for i: int in range(TRIAL_ROWS.size()):
		var id: String=str(TRIAL_ROWS[i][0])
		var locked: bool=id=="dungeon" and int(world.level)<40
		var spec: Dictionary={
			"Panel":{"input":Callable(self,"_ignore_input")},
			"Panel/Img_Daily":{"visible":false},
			"Panel/Button":{"activate":Callable(self,"_trial_pressed").bind(id)},
			"Panel/Label_Dungeon":{"role":"source_text","text":str(TRIAL_ROWS[i][1])},
			"Panel/Nd_Lock":{"visible":locked},
			"Panel/Nd_Lock/Label_Condition":{"role":"source_text","text":"Lv 40","visible":locked},
		}
		for name: String in ["Panel/Nd_Event_Reward","Panel/Sp_Power","Panel/Label_Power","Panel/Sp_Infinity","Panel/Sp_Event","Panel/Nd_Buy","Panel/Btn_Recovery_Free","Panel/Common_Slot_Layout","Panel/Label_Retry"]:spec[name]={"exclude":true}
		var built: Dictionary=_tree.scene_of(TRIAL_ROW,spec,{})
		if not built.get("ok",false):return built
		_add_column(content,TRIAL_ROW,built.scene,i,size,TRIAL_GAP)
	return {"ok":true,"pictures":0,"trial_rows":TRIAL_ROWS.size()}

func _trial_pressed(id: String) -> Dictionary:
	if id=="tower":
		trial_list=false
		index=0
		hard=false
		return _stage()
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("open_trial_dungeon"):return _fail("source_dungeon_window_trial_route_unavailable")
	close()
	hud.call("open_trial_dungeon")
	return {"ok":true,"routed":"open_trial_dungeon"}

func _trial_back() -> Dictionary:
	trial_list=true
	return _stage()

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
			"Btn":{"activate":Callable(self,"_slot_pressed").bind(str(slot.name),int(slot.amount),int(slot.class_id))},
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
	return _apply_item_picture(root,out,suffix,SourceImages.describe_item_class(class_id,title))

func _item_row_picture(root: Node2D, out: Dictionary, suffix: String, item_row: Dictionary, title: String) -> bool:
	return _apply_item_picture(root,out,suffix,SourceImages.describe_item_class_row(item_row,title))

func _apply_item_picture(root: Node2D, out: Dictionary, suffix: String, info: Dictionary) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	return located.get("ok",false) and NativeIcons.show_item(located.player, located.offset, info, _hud.get_ref())

func _apply_picture(root: Node2D, out: Dictionary, suffix: String, info: Dictionary) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## --- Actions -----------------------------------------------------------------

func _set_tab(value: String) -> Dictionary:
	_focused_escaros=false
	tab=value
	trial_list=true
	hard=false
	index=0
	time_open=false
	ranking_open=false
	story_open=false
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

func _slot_pressed(name: String, amount: int, item_class_id: int=0) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if item_class_id>0:
		var popup: Dictionary=preload("res://scripts/ui/original_ui/source_reward_item_info.gd").toggle(hud,item_class_id)
		if popup.get("ok",false):return popup
	if hud!=null:hud.show_message("%s × %s" % [name,number_text(amount)])
	return {"ok":true,"shown":name}

## The confirmation, then the existing view's action on the selected row;
## its notice (the existing result text) is shown.
func _confirm(title: String, body: String, button: String, run: Callable) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_dungeon_window_host_unavailable")
	var accept := func(_count: int) -> void:
		if not is_open():return
		run.call()
		refresh()
	hud.confirm_source_action(title,body,button,accept)
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
		if bound!=null:await bound._perform(action)
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
		await bound._play_action(action)
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
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var play: RefCounted=hud.get_parent().dungeon_play if hud!=null else null
	# Inside a special dungeon its row button is 나가기 (back to the village).
	if play!=null and str(play.state.active.get("kind",""))=="special":
		var current: Dictionary=play.rules.special_by_id.get(int(play.state.active.stage_id),{})
		return _confirm("특수 던전 · 나가기","%s\n남은 이용 시간: %s\n던전에서 나가 마을로 귀환합니다." % [special_name(current) if not current.is_empty() else special_name(entry),clock_text(play.special_left())],"나가기",func() -> void:
			var result: Dictionary=await play.stop_loading()
			if is_instance_valid(hud) and not result.get("ok",false):hud.show_message(str(result.get("reason","")))
			if is_open():refresh())
	# A dungeon that cannot be entered says why; nothing is charged.
	var blocked: String=play.special_block(entry) if play!=null else ""
	if not blocked.is_empty():
		if hud!=null:hud.show_message(blocked)
		return {"ok":true,"blocked":blocked}
	var body: String="%s\n이동 비용: %s %s\n필요 레벨: %d" % [special_name(entry),number_text(int(entry.teleport.TeleportCost)),str(entry.currency.name),special_level(entry)]
	var title: String=special_name(entry)
	return _confirm("특수 던전 · 입장",body,"입장",func() -> void:
		var bound: Object=_bind_view("special",i)
		if bound==null:return
		await bound._play_action("begin")
		if play!=null and str(play.state.active.get("kind",""))=="special":
			# Entered: the window closes over the dungeon Land.
			call_deferred("_close_requested")
			if hud!=null:hud.show_message("%s에 입장했습니다." % title)
			return
		_notice(bound))

func _escaros_pressed(world: Node, hud: Node) -> Dictionary:
	# Native card is presentation only; quote and execution stay with the
	# existing actual Escaros activity, not the local lobby exploration owner.
	var quote: Dictionary=world.content523.escaros_entry_quote()
	if not quote.get("ok",false):
		hud.show_message(str(quote.get("reason","에스카로스 입장 불가")))
		return {"ok":false,"handled":true,"blocked":str(quote.get("reason",""))}
	var route: Dictionary=quote.route
	return _confirm("에스카로스 · 입장","%s\n필요 레벨 %d · 아데나 %s" % [str(route.land_name),int(route.min_level),number_text(int(route.cost))],"입장",func() -> void:
		var entered: Dictionary=world.content523.enter_escaros()
		if entered.get("ok",false):
			hud.show_message("에스카로스에 입장했습니다.")
			call_deferred("_close_requested")
		else:hud.show_message(str(entered.get("reason","에스카로스 입장 불가"))))

func _competition_pressed(id: int) -> Dictionary:
	if _special.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_dungeon_window_host_unavailable")
	var world: Node=hud.get_parent()
	if _focused_escaros and id==ESCAROS_ID:return _escaros_pressed(world,hud)
	var here: Dictionary=COMPETITION.lobby(int(world.orim_current_land().get("land_id",-1)))
	if id in here.get("ids",[]):
		return _confirm("원본 입구 · 귀환","기란 마을로 돌아갑니다. 이동 비용 없음.","귀환",func() -> void:
			var result: Dictionary=world.competition523_return()
			hud.show_message(str(result.get("reason","귀환 보류")))
			if result.get("ok",false):call_deferred("_close_requested"))
	var quote: Dictionary=world.competition523_quote(id)
	if not quote.get("ok",false):
		hud.show_message(str(quote.get("reason","입구 이동 보류")))
		return {"ok":false,"handled":true,"blocked":str(quote.get("reason",""))}
	var entry: Dictionary=quote.row
	return _confirm("원본 입구 이동 · 오프라인","%s\n이동 비용: %s %s\n원본 서버·전투 입장이 아닌 입구 탐방입니다." % [str(entry.name),number_text(int(entry.tariff.TeleportCost)),str(entry.currency_name)],"입구 이동",func() -> void:
		var result: Dictionary=await world.run_dungeon_loading(Callable(world,"competition523_enter_loading").bind(id,quote.ticket))
		hud.show_message(str(result.get("reason","입구 이동 보류")))
		if result.get("ok",false):call_deferred("_close_requested"))

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
		await bound._play_action(action)
		_notice(bound))

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _fail(code: String) -> Dictionary:
	last_result={"ok":false,"handled":false,"code":code}
	return last_result

## 오림의 흔적 Btn_HelpBox: the original HelpBox_Mission_TracesOrim popup.
func _orim_help() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if _help_box==null:
		_help_box=HelpBox.new()
		_help_box.configure(_pack)
	if not parent is Node or not _help_box.available(HelpBox.ORIM):return _fail("source_help_box_member_missing")
	return _help_box.open(parent,HelpBox.ORIM)
