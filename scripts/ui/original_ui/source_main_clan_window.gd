extends RefCounted
## The original 523 혈맹 window (Clan_All) over the local one-person clan
## (world.clan523, scripts/clan523): without a clan the 창설 tab
## (Clan_Tab_Foundation: 혈맹명, 혈맹 창설), with a clan the 혈맹 정보 tab
## (Clan_Tab_Join_Info: 이름, 군주, 인원, 레벨, 경험치 게이지, 혜택, 문장, 기부)
## and the 기부 popup (Clan_Popup_Join_Donate: 일반 / 고급 / 최고급 기부 with
## their rewards, 소지 아데나·다이아, 주간 기부 보상 with 받기).
## Every rule, quote, debit, grant and save stays in scripts/clan523.
## Left inert or hidden (online only or no rule, docs/clan523_missing_rules.md):
## 추천 혈맹 / 신청 / 혈맹원 / 랭킹 / 경매 / 대여 / 퀘스트 / 병기 / 컬렉션 / 분배 tabs,
## 소개글 · 가입 설정 · 암호, 랭킹 · 아지트 · 레이드 · 공지 · 출석, 적대 / 동맹,
## 기억 / 채팅 / 알림 / 관계 요청 / 가입 설정 / 해산 / 보스 알림 / 연합 / 개인 퀘스트,
## the donation ranking, event notices and remaining-time texts.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Clan=preload("res://scripts/clan523/clan523.gd")
const ALL="UI/Clan/Clan_All.csb"
const TAB_BUTTON="UI/Clan/Clan_All_Tap_Btn.csb"
const FOUNDATION="UI/Clan/Clan_Tab_Foundation.csb"
const INFO="UI/Clan/Clan_Tab_Join_Info.csb"
const DONATE="UI/Clan/Clan_Popup_Join_Donate.csb"
const DONATE_ROWS: Array[String]=["UI/Clan/Clan_List_Join_Donate_A.csb","UI/Clan/Clan_List_Join_Donate_B.csb","UI/Clan/Clan_List_Join_Donate_C.csb"]
const WEEKLY_ROW="UI/Clan/Clan_List_Join_Donate_Reward.csb"
const REQUIRED: Array[String]=[ALL,TAB_BUTTON,FOUNDATION,INFO,DONATE,"UI/Clan/Clan_List_Join_Donate_A.csb","UI/Clan/Clan_List_Join_Donate_B.csb","UI/Clan/Clan_List_Join_Donate_C.csb",WEEKLY_ROW,"UI/Clan/Clan_Slot_Join_Donate_Item.csb","UI/Clan/Clan_Slot_Join_Donate_Point.csb"]
## Clan_WinTotal_Layout in ClanScene (600, 337.5).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
## Clan_All pages and popups this window never mounts.
const OTHER: Array[String]=["Clan_Tab_Auction","Clan_Tab_Foundation_Message","Clan_Tab_List","Clan_Tab_Request_List","Clan_Tab_Join_Request","Clan_Tab_Join_Rank","Clan_Tab_Join_Member","Clan_Tab_Join_Weapon","Clan_Tab_Distribution","Clan_Tab_Rental","Clan_Tab_Rental_Withdraw","Clan_Tab_Quest","Clan_Tab_Collection",
	"Clan_Popup_Symbol","Clan_Popup_Join_Appoint","Clan_Popup_Join","Clan_Popup_Join_Reward","Clan_Popup_Chat","Clan_Popup_Join_Report","Clan_Popup_Rank_Score","Clan_Popup_Memory","Clan_Popup_Relation_Request","Clan_Popup_Relation_Share","Nd_SiegePoint"]
const TAB_PANELS: Array[String]=["Panel_List","Panel_Request","Panel_Request_Join","Panel_Foundation","Panel_Distribution","Panel_ClanInfo","Panel_Party","Panel_Rank","Panel_Auction","Panel_Rental","Panel_Quest","Panel_Weapon","Panel_Collection"]
const INFO_OFFLINE: Array[String]=["Nd_Relation","Nd_Attendance","Nd_Info/Nd_Notice","Nd_Overview","Nd_Info/Btn_Quest","Nd_Info/Nd_Info/Btn_Set","Btn_Clan_Memory","Btn_Clan_Chat","Btn_Clan_Notice","Btn_Clan_Relation_Request","Btn_Clan_Set","Btn_Clan_Out","Btn_Clan_BossAlarm","Btn_Clan_Alliance","Clan_Popup_Join_Attendance","Clan_Popup_Input_Notice"]
## Clan_List_Join_Donate_* reward lines by the reward they show.
const REWARD_NODES: Dictionary={"ClanExperience":"Nd_Exp","Einasad":"Nd_BlessPoint","명예 코인":"Nd_Coin","기사단의 증표":"Nd_PledgeCoin","기사단의 기부 증서":"Nd_PledgeScroll"}
## Clan_Slot_Join_Donate_Point clips "Off" (0-3) and "Complete" (135-138).
const POINT_OFF_FRAME: float=0.0
const POINT_COMPLETE_FRAME: float=135.0
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _donate_open: bool=false
var _name_editor: LineEdit
var _last_out: Dictionary={}
var _popup_opacity: Dictionary={}
var last_result: Dictionary={}
var _weekly: WeeklyScroll=WeeklyScroll.new()

## The 주간 기부 보상 list's drag scroll. Rows wholly outside the list are
## hidden, so their pictures take no destination copies off screen.
class WeeklyScroll extends RefCounted:
	var content: Node2D
	var rows: Array[Node2D]=[]
	var row_height: float=1.0
	var view: float=0.0
	var y: float=0.0
	var minimum: float=0.0
	var drag: bool=false

	func bind(list_content: Node2D, row_nodes: Array[Node2D], height: float, view_height: float) -> void:
		content=list_content
		rows=row_nodes
		row_height=maxf(1.0,height)
		view=view_height
		minimum=minf(0.0,view-row_height*float(rows.size()))
		y=clampf(y,minimum,0.0)
		_apply()

	func input(event: InputEvent) -> void:
		if not is_instance_valid(content):return
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
			drag=event.pressed
			return
		var delta: float=0.0
		if event is InputEventScreenDrag:delta=event.relative.y
		elif event is InputEventMouseMotion and drag:delta=event.relative.y
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			delta=60.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
		if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
		y=clampf(y+delta,minimum,0.0)
		_apply()

	func scroll_to(value: float) -> void:
		y=clampf(value,minimum,0.0)
		_apply()

	func visible_rows() -> int:
		var count: int=0
		for row: Node2D in rows:
			if is_instance_valid(row) and row.visible:count+=1
		return count

	func _apply() -> void:
		if not is_instance_valid(content):return
		content.position.y=y
		for index: int in range(rows.size()):
			if not is_instance_valid(rows[index]):continue
			var top: float=row_height*float(index)+y
			rows[index].visible=top+row_height>0.0 and top<view

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_clan_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_clan_window_host_unavailable")
	if world.get("clan523")==null:return _fail("source_clan_window_clan_runtime_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_donate_open=false
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(_name_editor):
		_name_editor.queue_free()
	_name_editor=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func weekly_scroll() -> RefCounted:
	return _weekly

func donate_is_open() -> bool:
	return _donate_open and is_open()

func node_keys() -> Dictionary:
	return _last_out

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var world: Node=_world.get_ref() if _world!=null else null
	if parent==null or world==null:return _fail("source_clan_window_host_unavailable")
	var data: Dictionary=Clan.definition()
	if not data.get("ok",false):return {"ok":false,"handled":false,"code":"source_clan_window_definition_unavailable","problem":str(data.get("problem",""))}
	var runtime: Object=world.clan523
	var snap: Dictionary=runtime.snapshot(world)
	var joined: bool=bool(snap.get("has_clan",false))
	if not joined:_donate_open=false
	var spec: Dictionary=_frame_spec(joined)
	if joined:spec.merge(_info_spec(world,data,snap),true)
	else:spec.merge(_foundation_spec(snap),true)
	spec.merge(_donate_spec(world,data,snap),true)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ALL,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var tab: Dictionary=_fill_tab(next,out,joined)
	if tab.get("ok",false) and _donate_open:
		tab=_fill_donate(next,out,world,data)
		# The popup's ProjectNode previews it at alpha 0; the popup opens in
		# its own authored root opacity.
		if tab.get("ok",false):
			var popup: Variant=NamedTree.locate(next,out,"Clan_Popup_Join_Donate/Text_Title")
			if popup.get("ok",false) and popup.player.has_method("activate_authored_component_opacity"):_popup_opacity=popup.player.activate_authored_component_opacity()
	if not tab.get("ok",false):
		next.free()
		last_result=tab
		return tab
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	# The 혈맹명 field takes the existing LineEdit once it is mounted.
	var typed: bool=_attach_name(next,out).get("attached",false) if not joined else false
	last_result={"ok":true,"handled":true,"member":ALL,"joined":joined,"name_field":typed,"donate_open":_donate_open,"popup_opacity":_popup_opacity,"level":int(snap.get("level",0)),"create_ok":(snap.get("create",{}) as Dictionary).get("ok",false)}
	return last_result

func _frame_spec(joined: bool) -> Dictionary:
	var spec: Dictionary={}
	spec["FullFrameType_A/Fx_Img_BG_Particle"]={"exclude":true}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in OTHER:spec[name]={"exclude":true}
	spec["Nd_TabMenu"]={"visible":not joined}
	spec["Nd_TabMenu_Join"]={"visible":joined}
	spec["Clan_Tab_Foundation"]={"visible":not joined}
	spec["Clan_Tab_Join_Info"]={"visible":joined}
	spec["Clan_Popup_Join_Donate"]={"visible":_donate_open}
	if joined:spec["Clan_Tab_Foundation"]={"exclude":true}
	else:spec["Clan_Tab_Join_Info"]={"exclude":true}
	if not _donate_open:spec["Clan_Popup_Join_Donate"]={"exclude":true}
	return spec

## 창설: 혈맹명 (the existing name rule), 혈맹 창설 (the existing quote).
func _foundation_spec(snap: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	var p: String="Clan_Tab_Foundation/"
	for name: String in ["Nd_Overview","Nd_Symbol","Nd_Join","Nd_Password"]:spec[p+name]={"exclude":true}
	spec[p+"Nd_ClanName/Text_Help"]={"visible":false}
	spec[p+"Nd_ClanName/Nd_TextField/TextField_Name_Input"]={"role":"source_text_field","editor":_editor()}
	var quote: Dictionary=snap.get("create",{})
	var can: bool=quote.get("ok",false)
	spec[p+"Btn_Foundation"]={"activate":Callable(self,"_create_requested"),"displaystate":can}
	spec[p+"Btn_Foundation/Normal"]={"visible":can}
	spec[p+"Btn_Foundation/Disabled"]={"visible":not can}
	spec[p+"Nd_TitleBar/Label"]={"role":"source_text","text":"혈맹 창설을 위해 아래 정보를 입력해주세요." if can else str(quote.get("reason",""))}
	return spec

## 혈맹 정보: the existing snapshot's name, level, experience and buff.
func _info_spec(world: Node, data: Dictionary, snap: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	var p: String="Clan_Tab_Join_Info/"
	for name: String in INFO_OFFLINE:spec[p+name]={"exclude":true}
	# The clan mark is the 혈맹 문장 window's; the authored dummy stays hidden.
	spec[p+"Nd_Symbol/Icn_Mark_Dummy"]={"visible":false}
	spec[p+"Nd_Symbol/Btn_Set"]={"activate":Callable(self,"_emblem_requested")}
	var info: String=p+"Nd_Info/Nd_Info/"
	spec[info+"Text_Name_1"]={"role":"source_text","text":str(snap.get("name",""))}
	spec[info+"Text_Leader_1"]={"role":"source_text","text":_leader(world)}
	spec[info+"Text_Member_1"]={"role":"source_text","text":"1"}
	for name: String in ["Text_Rank_0","Text_Rank_1","Text_Agit_0","Text_Agit_1","Text_Agit_1_0","Text_Raid_0","Text_Raid_1","Text_Raid_Time","Text_Raid_Title","Text_Raid_Distribution"]:spec[info+name]={"visible":false}
	var level: int=int(snap.get("level",0))
	var experience: int=int(snap.get("experience",0))
	var need: int=int(snap.get("next_experience",-1))
	spec[info+"Text_Grade_1"]={"role":"source_text","text":str(level)}
	spec[info+"Text_Volume"]={"role":"source_text","text":("%s / %s" % [_number(experience),_number(need)]) if need>0 else _number(experience)}
	spec[info+"Gauge"]={"role":"source_percent","percent":clampf(100.0*float(experience)/float(need),0.0,100.0) if need>0 else 100.0}
	spec[p+"Btn_Clan_Benefit"]={"activate":Callable(self,"_benefit_requested")}
	spec[p+"Btn_Donate"]={"activate":Callable(self,"_open_donate")}
	spec[p+"Btn_Donate/Sp_Event"]={"visible":false}
	spec[p+"Btn_Donate/Sprite_New"]={"visible":false}
	return spec

func _donate_spec(world: Node, data: Dictionary, snap: Dictionary) -> Dictionary:
	if not _donate_open:return {}
	var spec: Dictionary={}
	var p: String="Clan_Popup_Join_Donate/"
	for name: String in ["Bg/FullFrameType_A","Nd_Notice","Label_Notice","Clan_Popup_Join_Donate_Rank","Clan_Donate_Shop_Popup_Info_Detail","Nd_Reward/Btn_Rank","Nd_Reward/Btn_Tooltip","Nd_Reward/Label_Time","Nd_Reward/Label_Time_Unqualified"]:spec[p+name]={"exclude":true}
	spec[p+"Btn_Close"]={"activate":Callable(self,"_close_donate")}
	# Authored hidden until the client's open animation; shown here.
	spec[p+"Nd_Adena"]={"visible":true}
	spec[p+"Nd_Diamond"]={"visible":true}
	spec[p+"Nd_Adena/Text_Volume"]={"role":"source_text","text":_number(int(world.get("gold")))}
	spec[p+"Nd_Diamond/Text_Volume"]={"role":"source_text","text":_number(Clan._balance(world,"다이아"))}
	var state: Dictionary=snap.get("state",{})
	spec[p+"Nd_Reward/Label_Point"]={"role":"source_text","text":"%s /%s" % [_number(int(state.get("week_points",0))),_number(int(data.policies.WeeklyMaxDonatePoint.value))]}
	var count: int=0
	for id: Variant in state.get("donations",{}):count+=int(state.donations[id])
	spec[p+"Nd_Reward/Label_DonationStatus"]={"role":"source_text","text":"일일 기부 진행 현황 %d/%d" % [count,int(data.policies.MaxDonateCount.value)]}
	spec[p+"ListView"]={"input":Callable(self,"_ignore_input")}
	spec[p+"Nd_Reward/ListView"]={"input":Callable(_weekly,"input")}
	return spec

## --- Lists ------------------------------------------------------------------

## The one tab of the clan state (창설 or 혈맹 정보), as a Clan_All_Tap_Btn.
func _fill_tab(root: Node2D, out: Dictionary, joined: bool) -> Dictionary:
	var suffix: String="Nd_TabMenu_Join/ListView" if joined else "Nd_TabMenu/ListView"
	var content: Variant=_list_content(root,out,suffix)
	if not content is Node2D:return _fail("source_clan_window_tab_list_missing")
	var shown: String="Panel_ClanInfo" if joined else "Panel_Foundation"
	var spec: Dictionary={}
	for panel: String in TAB_PANELS:
		if panel!=shown:spec[panel]={"exclude":true}
	var on: String="Btn_ClanInfo" if joined else "Btn_Foundation"
	spec[shown+"/"+on+"_On"]={"visible":true}
	spec[shown+"/"+on+"_Off"]={"visible":false}
	spec[shown+"/Sp_New"]={"visible":false}
	var built: Dictionary=_tree.scene_of(TAB_BUTTON,spec,{})
	if not built.get("ok",false):return built
	_add_column(content,TAB_BUTTON,built.scene,0,NamedTree.list_size(out,_pack,ALL,suffix),0.0,shown)
	return {"ok":true}

func _fill_donate(root: Node2D, out: Dictionary, world: Node, data: Dictionary) -> Dictionary:
	var runtime: Object=world.clan523
	var content: Variant=_list_content(root,out,"Clan_Popup_Join_Donate/ListView")
	if not content is Node2D:return _fail("source_clan_window_donate_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,DONATE,"Clan_Popup_Join_Donate/ListView")
	var placed: int=0
	for entry: Dictionary in data.donates:
		var slot: int=int(entry.slot)
		if slot<1 or slot>DONATE_ROWS.size():continue
		var member: String=DONATE_ROWS[slot-1]
		var quote: Dictionary=runtime.donate_quote(world,int(entry.id))
		var spec: Dictionary={"Panel/Sp_Event":{"visible":false},"Panel/Panel_L":{"visible":false},"Panel/Panel_R":{"visible":false}}
		spec["Panel/Text_Title"]={"role":"source_text","text":str(entry.name)}
		var shown: Dictionary={}
		for reward: Dictionary in entry.rewards:
			var key: String=str(reward.unit) if str(reward.unit) in ["ClanExperience","Einasad"] else str(reward.name)
			var node: String=str(REWARD_NODES.get(key,""))
			if node.is_empty():continue
			shown[node]=true
			spec["Panel/"+node]={"visible":true}
			spec["Panel/"+node+"/Text_Volume"]={"role":"source_text","text":_number(int(reward.amount))}
		for node: String in REWARD_NODES.values():
			if not shown.has(node):spec["Panel/"+node]={"visible":false}
		var can: bool=quote.get("ok",false)
		var label: String="기 부 (%d/%d)" % [int(quote.get("count",0)),int(quote.get("max_count",0))] if quote.has("max_count") else "기 부"
		spec["Panel/Btn_Donate"]={"activate":Callable(self,"_donate_requested").bind(int(entry.id)),"displaystate":can,"visible":true}
		for state: String in ["Normal","Disabled"]:
			spec["Panel/Btn_Donate/"+state]={"visible":(state=="Normal")==can}
			spec["Panel/Btn_Donate/"+state+"/Text_Volume"]={"role":"source_text","text":_number(int(entry.payment.amount))}
			spec["Panel/Btn_Donate/"+state+"/Label"]={"role":"source_text","text":label}
		# Only the Adena payment has its authored picture here.
		var adena: bool=Clan.payment_wallet(entry.payment)=="아데나"
		spec["Panel/Btn_Donate/Normal/Sp_Icon"]={"visible":adena}
		spec["Panel/Btn_Donate/Disabled/Sp_Icon"]={"visible":adena}
		var built: Dictionary=_tree.scene_of(member,spec,{})
		if not built.get("ok",false):return built
		_add_column(content,member,built.scene,placed,size,-20.0,"Panel")
		placed+=1
	var weekly: Variant=_list_content(root,out,"Clan_Popup_Join_Donate/Nd_Reward/ListView")
	if not weekly is Node2D:return _fail("source_clan_window_weekly_list_missing")
	var weekly_size: Vector2=NamedTree.list_size(out,_pack,DONATE,"Clan_Popup_Join_Donate/Nd_Reward/ListView")
	var points: int=int((runtime.view_state() as Dictionary).get("week_points",0))
	var previous: int=0
	var weekly_rows: Array[Node2D]=[]
	for index: int in range(data.weekly.size()):
		var row: Dictionary=data.weekly[index]
		var quote: Dictionary=runtime.weekly_quote(world,int(row.id))
		var claimed: bool=(runtime.view_state() as Dictionary).get("weekly_claimed",[]).has(int(row.id))
		var reached: bool=points>=int(row.points)
		var spec: Dictionary={}
		spec["Panel/Nd_Gauge_Up"]={"visible":index>0}
		spec["Panel/Nd_Gauge_Up/Gauge"]={"role":"source_percent","percent":100.0 if reached else 0.0}
		spec["Panel/Nd_Gauge_Down"]={"visible":index<data.weekly.size()-1}
		var next_points: int=int(data.weekly[index+1].points) if index<data.weekly.size()-1 else int(row.points)
		spec["Panel/Nd_Gauge_Down/Gauge"]={"role":"source_percent","percent":clampf(100.0*float(points-int(row.points))/float(maxi(1,next_points-int(row.points))),0.0,100.0)}
		spec["Panel/Btn_Accept"]={"activate":Callable(self,"_weekly_requested").bind(int(row.id)),"displaystate":quote.get("ok",false)}
		spec["Panel/Sp_Icn_Accept"]={"visible":not quote.get("ok",false)}
		spec["Panel/Clan_Slot_Item/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec["Panel/Clan_Slot_Item/Text_Amount"]={"role":"source_text","text":_number(int(row.amount)),"visible":int(row.amount)>1}
		spec["Panel/Clan_Slot_Item/Nd_Disabled"]={"visible":not reached}
		spec["Panel/Clan_Slot_Item/Nd_Lock"]={"visible":false}
		spec["Panel/Clan_Slot_Item/Nd_Complete"]={"visible":claimed}
		spec["Panel/Clan_Slot_Point/Nd_Progress/Sp_Bonus"]={"visible":bool(row.get("bonus",false))}
		spec["Panel/Clan_Slot_Point/Nd_Progress/Nd_Label_Num/Label_Num"]={"role":"source_text","text":str(int(row.points))}
		var row_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(WEEKLY_ROW,spec,row_out)
		if not built.get("ok",false):return built
		_tree.add_row(weekly,WEEKLY_ROW,built.scene,index,weekly_size)
		weekly_rows.append(built.scene)
		if str(row.kind)=="Item" and int(row.class_id)>0:_picture(built.scene,row_out,"Clan_Slot_Item/Sp_IconSample",int(row.class_id),str(row.name))
		_point_state(built.scene,row_out,reached)
		previous=int(row.points)
	_weekly.bind(weekly,weekly_rows,float(_tree.row_panel(WEEKLY_ROW).size[1]),weekly_size.y)
	return {"ok":true}

## Clan_Slot_Join_Donate_Point's own timeline states: "Off" (frames 0-3)
## before the week's points reach the row, "Complete" (135-138) after. The
## unplayed preview would show every Fx glow at once.
func _point_state(row: Node2D, out: Dictionary, reached: bool) -> bool:
	var located: Dictionary=NamedTree.locate(row,out,"Panel/Clan_Slot_Point")
	if not located.get("ok",false):return false
	var node: Variant=located.player.source_nodes.get(located.offset)
	var player: Variant=node.get_meta("source_project_player",null) if is_instance_valid(node) else null
	if not is_instance_valid(player):return false
	player.seek_frame(POINT_COMPLETE_FRAME if reached else POINT_OFF_FRAME)
	return true

func _list_content(root: Node2D, out: Dictionary, suffix: String) -> Variant:
	var list: Dictionary=NamedTree.locate(root,out,suffix)
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	return node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null

## A row of a horizontal ListView (left to right, vertically centred).
func _add_column(content: Node2D, member: String, row: Node2D, index: int, list_size: Vector2, gap: float, panel_name: String) -> void:
	var panel: Dictionary=_panel(member,panel_name)
	var w: float=float(panel.size[0])
	var h: float=float(panel.size[1])
	var left: float=(w+gap)*float(index)
	var bottom: float=(list_size.y-h)*0.5
	row.position=Vector2(left-(float(panel.position[0])-float(panel.anchor[0])*w),-(bottom-(float(panel.position[1])-float(panel.anchor[1])*h)))
	content.add_child(row)

func _panel(member: String, panel_name: String) -> Dictionary:
	for child: Dictionary in _pack.scene(member).get("nodeTree",{}).get("children",[]):
		var widget: Dictionary=child.get("options",{}).get("widgetOptions",{})
		if str(widget.get("name",""))==panel_name:return {"size":widget.get("size",[0,0]),"position":widget.get("position",[0,0]),"anchor":widget.get("anchorPoint",[0,0])}
	return _tree.row_panel(member)

func _picture(root: Node2D, out: Dictionary, suffix: String, item_class_id: int, title: String) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item_class(item_class_id,title)
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## The existing editor of the 혈맹명 text field (kept across restages).
func _editor() -> LineEdit:
	if not is_instance_valid(_name_editor):
		_name_editor=LineEdit.new()
		_name_editor.name="Clan523OriginalName"
		_name_editor.max_length=Clan.NAME_MAX
		_name_editor.visible=false
		var parent: Object=_parent.get_ref() if _parent!=null else null
		# The field returns the editor here (hidden) when its scene closes.
		if parent is Node:(parent as Node).add_child(_name_editor)
	return _name_editor

func _attach_name(root: Node2D, out: Dictionary) -> Dictionary:
	var located: Dictionary=NamedTree.locate(root,out,"Clan_Tab_Foundation/Nd_ClanName/Nd_TextField/TextField_Name_Input")
	if not located.get("ok",false):return {"ok":true}
	var node: Variant=located.player.source_nodes.get(located.offset)
	var field: Variant=node.get_meta("source_text_field",null) if is_instance_valid(node) and node.has_meta("source_text_field") else null
	if field==null or not field.has_method("attach_editor"):return {"ok":true}
	var attached: Dictionary=field.attach_editor()
	return {"ok":true,"attached":attached.get("ok",false)}

static func _leader(world: Node) -> String:
	var name: Variant=world.get("character_name")
	if name is String and not (name as String).is_empty():return name
	return str(world.get("job_class"))

## --- Actions -----------------------------------------------------------------

func _notify(result: Dictionary) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message") and not str(result.get("reason","")).is_empty():hud.call("show_message",str(result.reason))
	var staged: Dictionary=_stage()
	staged["action"]=result
	return staged

func _create_requested() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_clan_window_host_unavailable")
	var name: String=_name_editor.text if is_instance_valid(_name_editor) else ""
	return _notify(world.clan523.create(world,name))

func set_name_text(value: String) -> void:
	_editor().text=value

func _open_donate() -> Dictionary:
	_donate_open=true
	_weekly.y=0.0
	return _stage()

func _close_donate() -> Dictionary:
	_donate_open=false
	return _stage()

func _donate_requested(donate_id: int) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_clan_window_host_unavailable")
	return _notify(world.clan523.donate(world,donate_id))

func _weekly_requested(row_id: int) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_clan_window_host_unavailable")
	return _notify(world.clan523.claim_weekly(world,row_id))

## 혈맹 혜택: the level benefits of the existing tables, as a message.
func _benefit_requested() -> Dictionary:
	var data: Dictionary=Clan.definition()
	var world: Node=_world.get_ref() if _world!=null else null
	if not data.get("ok",false) or world==null:return _fail("source_clan_window_definition_unavailable")
	var level: int=int(world.clan523.level())
	var lines: PackedStringArray=[]
	for at: int in range(1,int(data.max_level)+1):
		lines.append("%sLv.%d %s" % ["▶ " if at==level else "",at,str(data.benefits.get(at,{}).get("text","")).replace("\n"," ")])
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.call("show_message"," / ".join(lines))
	return {"ok":true,"lines":lines.size()}

func _emblem_requested() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_clan_window_host_unavailable")
	close()
	hud.call("_navigate","clan_emblem523")
	return {"ok":true,"navigated":"clan_emblem523"}

func _ignore_input(_event: InputEvent) -> void:
	pass

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
