extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 작위 window: Title_All (frame, title, close, help) with
## the stage list (Title_List_Badge per SubTitle stage: name, its effect
## lines, achieved or locked), the 누적 작위 혜택 list (Title_List_Benefit)
## and the current-title column (name, status lines as Title_List_Text).
## Tapping the next stage opens the original Title_Popup_Upgrade: 일반 심사
## lists the stage's trial quests (Title_List_Upgrade_Common, selection,
## progress) with 퀘스트 수락 / 승급 심사 도전, 기부 심사 the powder cost
## (Title_List_Upgrade_Donation) with 기부 승급 도전. Every rule, roll, cost
## and save stays in world.titles (scripts/titles/title_runtime523.gd); the
## reviews go through the existing confirmation dialog.
## Not connected: the stage grade backgrounds and symbol art per stage
## (no stage -> grade rule in the tables), the authored probability labels
## (100%/55%/20%: TWILIGHT uses its own policy) and the personal title
## editor (kept in the TWILIGHT view).
const ROOT="UI/Title/Title_All.csb"
const BADGE="UI/Title/Title_List_Badge.csb"
const BENEFIT="UI/Title/Title_List_Benefit.csb"
const TEXT="UI/Title/Title_List_Text.csb"
const COMMON="UI/Title/Title_List_Upgrade_Common.csb"
const DONATION="UI/Title/Title_List_Upgrade_Donation.csb"
const POPUP="Title_Popup_Upgrade/"
const POPUP_Z: int=100
var _popup: bool=false
var _quest: int=-1

func required_members() -> Array[String]:
	return [ROOT,BADGE,BENEFIT,TEXT,COMMON,DONATION]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("titles") if owner!=null else null

func open(parent: Node) -> Dictionary:
	var runtime: Object=_runtime()
	# Without the 523 definitions the TWILIGHT view keeps its install button.
	if runtime==null or not str(runtime.source.problem).is_empty():return _fail("source_title_definitions_unavailable")
	_popup=false
	return open_window(parent)

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Btn_Help"]={"activate":Callable(self,"_help")}
	var achieved: bool=not runtime.state.achieved.is_empty()
	spec["Nd_Symbol/Label_Title"]={"role":"source_text","text":runtime.current_name(),"visible":achieved}
	spec["Nd_Symbol/Label_Title_Disabled"]={"role":"source_text","text":runtime.current_name(),"visible":not achieved}
	spec["Nd_Symbol/Nd_Icon/Img_Disabled"]={"visible":not achieved}
	# The popup is mounted only while it is open.
	if _popup:spec.merge(_popup_spec(runtime))
	else:spec["Title_Popup_Upgrade"]={"exclude":true}
	return spec

func _popup_spec(runtime: Object) -> Dictionary:
	# Title_All authors the popup ProjectNode hidden; the client shows it.
	var spec: Dictionary={"Title_Popup_Upgrade":{"visible":true}}
	var stage: Dictionary=runtime.next_stage()
	var active: bool=not runtime.state.active.is_empty() and runtime.now()<int(runtime.state.active.expires)
	spec[POPUP+"Btn_Close"]={"activate":Callable(self,"_close_popup")}
	spec[POPUP+"Nd_Bg/Label_Title"]={"role":"source_text","text":"%s 승급 심사" % str(stage.get("name",""))}
	spec[POPUP+"Nd_Common/Btn_Quest"]={"visible":not active,"activate":Callable(self,"_start_trial")}
	spec[POPUP+"Nd_Common/Btn_Challenge"]={"visible":active,"activate":Callable(self,"_review").bind("quest")}
	spec[POPUP+"Nd_Donation/Btn_Donation"]={"activate":Callable(self,"_review").bind("donation")}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var stages: Array=runtime.source.stages
	var achieved: int=runtime.state.achieved.size()
	var rows: Array=[]
	for index: int in range(stages.size()):
		var stage: Dictionary=stages[index]
		var done: bool=index<achieved
		var lines: Array[String]=[]
		for id: Variant in stage.get("sub_effects",[]):
			var effect: Dictionary=runtime.source.effects.get(int(id),{})
			if not effect.is_empty():lines.append(_effect_text(runtime,effect))
		var spec: Dictionary={"Panel/Btn_Sub":{"activate":Callable(self,"_stage_pressed").bind(index)},
			"Btn_Sub/Normal":{"visible":done or index==achieved},"Btn_Sub/Disabled":{"visible":not done and index!=achieved},
			"Normal/Label_Title":{"role":"source_text","text":str(stage.get("name",""))},
			"Nd_Badge/Sp_Disabled":{"visible":not done}}
		for bg: String in ["Bg_Rare","Bg_Unique","Bg_Legend","Bg_Epic","Bg_Myth"]:spec["Nd_Bg/"+bg]={"visible":false}
		for line: int in range(4):
			spec["ListView/Panel_%d" % (line+1)]={"visible":line<lines.size()}
			spec["Panel_%d/Label" % (line+1)]={"role":"source_text","text":lines[line] if line<lines.size() else ""}
		rows.append({"member":BADGE,"spec":spec})
	var badges: Dictionary=_fill_list(root,out,"Nd_Badge/ListView",rows)
	if not badges.get("ok",false):return badges
	var benefits: Array=[]
	var totals: Dictionary=runtime.totals()
	for kind: String in totals:
		benefits.append({"member":BENEFIT,"spec":{"Panel/Label_Main":{"role":"source_text","text":"%s %s" % [runtime.effect_label(kind),_signed(float(totals[kind]))]},"Panel/Label_Sub":{"visible":false}}})
	if benefits.is_empty():benefits.append({"member":BENEFIT,"spec":{"Panel/Label_Main":{"role":"source_text","text":"아직 달성한 작위가 없습니다."},"Panel/Label_Sub":{"visible":false}}})
	var listed: Dictionary=_fill_list(root,out,"Nd_Benefit/ListView",benefits)
	if not listed.get("ok",false):return listed
	var status: Array=[]
	for line: String in _status_lines(runtime):
		status.append({"member":TEXT,"spec":{"Panel/Label":{"role":"source_text","text":line},"Panel/Label_Disabled":{"visible":false}}})
	var symbol: Dictionary=_fill_list(root,out,"Nd_Symbol/ListView",status)
	if not symbol.get("ok",false):return symbol
	var popup: Dictionary={}
	if _popup:
		popup=_fill_popup(root,out,runtime)
		if not popup.get("ok",false):return popup
		# Original zOrder is per sibling in Cocos but accumulates as a relative
		# z_index here, and the stage rows (added to their ListView after the
		# tree is built, each row z by index) would draw over the popup; keep
		# the popup above every row.
		var located: Dictionary=_locate(root,out,"Title_Popup_Upgrade")
		var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
		if node is CanvasItem:(node as CanvasItem).z_index=POPUP_Z
	return {"ok":true,"stages":stages.size(),"achieved":achieved,"benefits":totals.size(),"status":status.size(),"popup":_popup,"popup_rows":popup}

func _fill_popup(root: Node2D, out: Dictionary, runtime: Object) -> Dictionary:
	var stage: Dictionary=runtime.next_stage()
	var active: Dictionary=runtime.state.active if runtime.state.active is Dictionary else {}
	var rows: Array=[]
	var quests: Array=stage.get("quests",[])
	if _quest not in quests and not quests.is_empty():_quest=int(active.get("quest",quests[0])) if not active.is_empty() else int(quests[0])
	for raw: Variant in quests:
		var id: int=int(raw)
		var quest: Dictionary=runtime.source.quests.get(id,{})
		var access: String=runtime.trial_access(id,runtime.now())
		var running: bool=not active.is_empty() and int(active.get("quest",-1))==id
		var count: int=int(active.get("count",0)) if running else 0
		var hours: int=int(quest.get("limit_seconds",0))/3600
		var spec: Dictionary={"Panel/Nd_Normal":{"visible":access.is_empty()},"Panel/Nd_Disabled":{"visible":not access.is_empty()},"Panel/Nd_Complete":{"visible":false},
			"Panel/Nd_Probability":{"visible":false},"Nd_Normal/Label_Time_R":{"visible":false},
			"Nd_CheckBox/Btn_Pressed":{"visible":id==_quest,"activate":Callable(self,"_select_quest").bind(id)},
			"Nd_CheckBox/Btn_Normal":{"visible":id!=_quest,"activate":Callable(self,"_select_quest").bind(id)},
			"Nd_Disabled/Label_Fail":{"visible":false}}
		for state: String in ["Nd_Normal","Nd_Disabled"]:
			spec[state+"/Label"]={"role":"source_text","text":str(quest.get("name",""))}
			spec[state+"/Label_Amount"]={"role":"source_text","text":"(%d/%d)%s" % [count,int(quest.get("amount",0))," · "+access if not access.is_empty() else ""]}
			spec[state+"/Label_Time"]={"role":"source_text","text":"%d시간" % hours}
		rows.append({"member":COMMON,"spec":spec})
	var common: Dictionary=_fill_list(root,out,"Nd_Common/ListView",rows)
	if not common.get("ok",false):return common
	var cost: int=int(stage.get("cost",0))
	var have: int=runtime.powder_count()
	var donation: Array=[{"member":DONATION,"spec":{"Nd_CheckBox/Btn_Pressed":{"visible":true},"Nd_CheckBox/Btn_Normal":{"visible":false},
		"Panel/Label":{"role":"source_text","text":str(runtime.source.powder_record.get("name","상급 축복의 가루"))},
		"Panel/Label_Amount":{"role":"source_text","text":"%s/%s" % [_number(have),_number(cost)]}}}]
	var gift: Dictionary=_fill_list(root,out,"Nd_Donation/ListView",donation)
	if not gift.get("ok",false):return gift
	return {"ok":true,"quests":rows.size(),"selected":_quest,"powder":have,"cost":cost}

static func _signed(value: float) -> String:
	return ("+" if value>0 else "")+(str(int(value)) if value==floorf(value) else String.num(value,2))

func _effect_text(runtime: Object, effect: Dictionary) -> String:
	return "%s %s" % [runtime.effect_label(str(effect.get("type",""))),_signed(float(effect.get("value",0)))]

func _status_lines(runtime: Object) -> Array[String]:
	var lines: Array[String]=[]
	if not runtime.state.active.is_empty():
		var quest: Dictionary=runtime.source.quests.get(int(runtime.state.active.quest),{})
		lines.append("%s %d/%d" % [str(quest.get("name","")),int(runtime.state.active.count),int(quest.get("amount",0))])
	var used: int=int(runtime.state.attempts) if int(runtime.state.day)==runtime.day(runtime.now()) else 0
	lines.append("오늘 일반 심사 %d / %d" % [used,int(runtime.source.daily_limit)])
	lines.append("상급 축복의 가루 %s개" % _number(runtime.powder_count()))
	return lines

func _stage_pressed(index: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var runtime: Object=_runtime()
	var achieved: int=runtime.state.achieved.size()
	if index<achieved:
		_message("%s 달성" % str(runtime.source.stages[index].name))
		return {"ok":true,"achieved":true}
	if index>achieved:
		_message("이전 작위를 먼저 달성해야 합니다")
		return {"ok":false,"code":"title_stage_locked"}
	_popup=true
	return _stage()

func _close_popup() -> Dictionary:
	_popup=false
	return _stage()

func _select_quest(id: int) -> Dictionary:
	_quest=id
	return _stage()

func _start_trial() -> Dictionary:
	var runtime: Object=_runtime()
	var result: Dictionary=runtime.start_trial(_quest,int(runtime.state.revision))
	_message(str(result.get("message","")))
	_stage()
	return result

## The existing review text, then the existing attempt after confirmation.
func _review(route: String) -> Dictionary:
	var runtime: Object=_runtime()
	var revision: int=int(runtime.state.revision)
	var reviewed: Dictionary=runtime.review(route,revision)
	if not reviewed.get("ok",false):
		_message(str(reviewed.get("message","")))
		return reviewed
	var owner: Object=hud()
	owner.call("confirm_action","작위 승급 심사",str(reviewed.message),"심사",func(_count: int) -> void:
		var result: Dictionary=runtime.attempt(route,revision)
		_message(str(result.get("message","")))
		if is_open():_stage())
	return {"ok":true,"review":route}

func _help() -> Dictionary:
	_message("85레벨부터 순차 승급 · 선택 목표 24시간 · 일반 심사 하루 %d회 · 성공률은 TWILIGHT 자체 정책" % int(_runtime().source.daily_limit))
	return {"ok":true}
