extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 몬스터 도감 window: MonsterBook_All (frame, 일반 도감 tab,
## title, close, guide) with its MonsterBook_CollectionView page. The book
## list is one MonsterBook_CollectionList row per current book of
## world.monsterbook523 (current stage, kill count and gauge); the info side
## shows the selected book's period, name, stage progress and the original
## 보상 받기 / 즉시 완료 buttons, which run the existing
## World.request_monsterbook_action (달성 기록 first when a stage is reached
## but not yet registered). 효과 정보 (Btn_InfoView) lists the stage options
## in the page's own ListView_Effect rows. Not connected (no TWILIGHT
## feature): 미션 도감, 도감 컬렉션, the grade sidebar, the story page and
## the representative-monster list; the reward item slots stay empty.
const ROOT="UI/MonsterBook/MonsterBook_All.csb"
const PAGE="UI/MonsterBook/MonsterBook_CollectionView.csb"
const ROW="UI/MonsterBook/MonsterBook_CollectionList.csb"
const P="MonsterBook_CollectionView/"
const EFFECT_STEP: float=20.0
var selected: int=0
var showing_effects: bool=false
var _books: Array=[]

func required_members() -> Array[String]:
	return [ROOT,PAGE,ROW]

func _root_member() -> String:
	return ROOT

func _service() -> Object:
	var owner: Object=world()
	return owner.get("monsterbook523") if owner!=null else null

func open(parent: Node) -> Dictionary:
	var service: Object=_service()
	if service==null or not service.loaded():return _fail("source_monsterbook_definitions_unavailable")
	return open_window(parent)

## The book's current stage: the first not yet claimed (else the last).
func _current_stage(id: int) -> Dictionary:
	var service: Object=_service()
	var progress: Dictionary=service.progress(id)
	var levels: Array=service.levels(id)
	for stage: Dictionary in levels:
		if not progress.get("claimed",[]).has(int(stage.ID)):return stage
	return levels[-1] if not levels.is_empty() else {}

func _count(id: int, stage: Dictionary) -> int:
	return int(_service().progress(id).get("counts",{}).get(str(int(stage.get("ID",0))),0))

func _description(table: String, id: int) -> String:
	var service: Object=_service()
	var raw: Dictionary=service.row(table,id)
	var desc: Dictionary=service.row("DescData_Korean",int(raw.get("DescID",0)))
	return str(desc.get("Description",raw.get("Name",str(id))))

static func _date(value: Dictionary) -> String:
	if value.is_empty():return "-"
	return "%04d.%02d.%02d %02d:%02d" % [int(value.Year),int(value.Month),int(value.Day),int(value.Hour),int(value.Minute)]

func _spec() -> Dictionary:
	var service: Object=_service()
	_books=service.books(true)
	var known: bool=false
	for book: Dictionary in _books:
		if int(book.ID)==selected:known=true
	if not known:selected=int(_books[0].ID) if not _books.is_empty() else 0
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_Change_Tab/Btn_MonsterBook_On"]={"visible":true}
	spec["Nd_Change_Tab/Btn_MonsterBook_Off"]={"visible":false}
	for tab: String in ["Btn_MonsterMission","Btn_MonsterCollection"]:
		spec["Nd_Change_Tab/"+tab+"_On"]={"visible":false}
		spec["Nd_Change_Tab/"+tab+"_Off"]={"visible":false}
	for guide: String in ["Label_MissionGuide","Label_CollectionGuide","Label_Event"]:spec[guide]={"visible":false}
	spec[P+"Text_Notice"]={"visible":false}
	spec[P+"Nd_Story"]={"exclude":true}
	spec[P+"Nd_Effect"]={"visible":false}
	spec[P+"Nd_Grade"]={"visible":false}
	spec[P+"Btn_Sort"]={"visible":false}
	spec[P+"Nd_Monster_List/Text_Notice"]={"visible":_books.is_empty()}
	var info: String=P+"Nd_Monster_Info/"
	spec[info+"Text_Notice"]={"visible":selected==0}
	spec[info+"Nd_Info"]={"visible":selected!=0 and not showing_effects}
	spec[P+"Nd_Effect_Info"]={"visible":selected!=0 and showing_effects}
	spec[P+"Nd_Effect_Info/Btn_Back"]={"activate":Callable(self,"_toggle_effects")}
	spec[P+"Nd_Effect_Info/Nd_Info_Effect/ListView_Effect/Panel_set"]={"visible":false}
	spec[info+"Nd_Info/Btn_InfoView"]={"activate":Callable(self,"_toggle_effects")}
	if selected==0:return spec
	var book: Dictionary=service.row("MonsterBook",selected)
	var period: Dictionary=service.raw_period(selected)
	var live: Variant=world().get("monsterbook523_runtime")
	if live!=null and service.has_method("local_period"):period=service.local_period(selected,live.local.source_clock())
	var stage: Dictionary=_current_stage(selected)
	var level_id: int=int(stage.get("ID",0))
	var count: int=_count(selected,stage)
	spec[info+"Text_Time"]={"role":"source_text","text":"기간 : %s ~ %s" % [_date(period.get("StartDateTimeID",{})),_date(period.get("CountingEndDateTimeID",{}))]}
	spec[info+"Nd_Info/Text_Monster_Name"]={"role":"source_text","text":str(book.get("Name",""))}
	spec[info+"Nd_Info/Text_Progress"]={"role":"source_text","text":"%d단계 %s / %s" % [int(stage.get("Level",0)),_number(count),_number(int(stage.get("Amount",0)))]}
	spec[info+"Nd_Info/Nd_Reward/Text_Reward"]={"role":"source_text","text":"%d단계 보상" % int(stage.get("Level",0))}
	var claim: String=_claim_action(level_id)
	var can_claim: bool=not claim.is_empty()
	spec[info+"Nd_Info/Nd_Reward/Btn_Reward"]={"activate":Callable(self,"_request").bind(claim if can_claim else "claim",level_id),"displaystate":can_claim}
	spec[info+"Nd_Info/Nd_Reward/Btn_Reward/Normal"]={"visible":can_claim}
	spec[info+"Nd_Info/Nd_Reward/Btn_Reward/Disabled"]={"visible":not can_claim}
	var instant: bool=int(stage.get("CurrencyCost",0))>0
	var can_instant: bool=instant and str(world().call("monsterbook_action_status","instant",selected,level_id)).is_empty()
	spec[info+"Nd_Info/Nd_Reward/Nd_Complete"]={"visible":instant}
	spec[info+"Nd_Info/Nd_Reward/Nd_Complete/Btn_Complete"]={"activate":Callable(self,"_request").bind("instant",level_id),"displaystate":can_instant}
	spec[info+"Btn_Complete/Normal"]={"visible":can_instant}
	spec[info+"Btn_Complete/Disabled"]={"visible":not can_instant}
	spec[P+"Nd_Effect_Info/Text_SubTitle"]={"role":"source_text","text":"[%02d단계] %s" % [int(stage.get("Level",0)),str(book.get("Name",""))]}
	return spec

## register first, then claim (the existing action order).
func _claim_action(level_id: int) -> String:
	for action: String in ["register","claim"]:
		if str(world().call("monsterbook_action_status",action,selected,level_id)).is_empty():return action
	return ""

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var rows: Array=[]
	for book: Dictionary in _books:
		var id: int=int(book.ID)
		var stage: Dictionary=_current_stage(id)
		var amount: int=maxi(1,int(stage.get("Amount",1)))
		var count: int=_count(id,stage)
		var on: bool=id==selected
		rows.append({"member":ROW,"spec":{"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_select").bind(id)},
			"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_select").bind(id)},
			"Panel/Label_Title":{"role":"source_text","text":"[%d단계] %s" % [int(stage.get("Level",0)),str(book.get("Name",""))]},
			"Panel/Label_Num":{"role":"source_text","text":"%s / %s" % [_number(mini(count,amount)),_number(amount)]},
			"Panel/Gauge":{"role":"source_percent","percent":clampf(100.0*float(count)/float(amount),0.0,100.0)},
			"Panel/Label_Day":{"visible":false},"Panel/Label_Time":{"visible":false},"Panel/Icn_Join":{"visible":false}}})
	var listed: Dictionary=_fill_list(root,out,P+"Nd_Monster_List/ListView_Folders",rows)
	if not listed.get("ok",false):return listed
	var effects: int=0
	if selected!=0 and showing_effects:
		var specs: Array=[]
		var service: Object=_service()
		for raw: Dictionary in _current_stage(selected).get("bonuses",[]):
			var type: Dictionary=service.row("BonusType",int(raw.BonusTypeID))
			var unit: Dictionary=service.row("Unit",int(type.get("UnitID",0)))
			specs.append({"Panel_set/Text_Title":{"role":"source_text","text":_description("BonusType",int(raw.BonusTypeID))},
				"Panel_set/Text_Effect":{"role":"source_text","text":"%s%s" % [str(raw.Value),str(unit.get("Name",""))]}})
		var located: Dictionary=_locate(root,out,P+"Nd_Effect_Info")
		if not located.get("ok",false):return located
		var repeated: Dictionary=_repeat_template(located.player,PAGE,"Nd_Effect_Info/Nd_Info_Effect/ListView_Effect/Panel_set",specs,EFFECT_STEP,Vector2.ZERO,18)
		if not repeated.get("ok",false):return repeated
		effects=int(repeated.rows)
	return {"ok":true,"books":_books.size(),"selected":selected,"effects":effects,"showing_effects":showing_effects}

func _select(id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	selected=id
	showing_effects=false
	return _stage()

func _toggle_effects() -> Dictionary:
	showing_effects=not showing_effects
	return _stage()

func _request(action: String, level_id: int) -> Dictionary:
	var outcome: Dictionary=world().call("request_monsterbook_action",action,selected,level_id)
	_message(str(outcome.get("message","처리를 완료하지 못했습니다.")))
	_stage()
	return outcome
