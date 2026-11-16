extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 시련 던전 window: Dungeon_Trial_All (full frame, title,
## close) over the existing Challenge feature (world.unconfirmed523, domain
## "challenge": page / execute). Opened from the 던전 window's 시련 tab
## (user decision 2026-11-16: 시련 던전 and 시련의 탑 both under 시련).
## - ThumbNail tab (Dungeon_Trial_Tab_ThumbNail): one
##   Dungeon_Trial_List_ThumbNail per group of working Challenge rows that
##   share their MiniAssetID (턴 언데드 1~3, 미믹 처치 1~3): the group title
##   (TitleDescID text without its step number), ScenarioDescID text, the
##   lock with 오픈 레벨 when no member is eligible.
## - Detail tab (Dungeon_Trial_Tab_Detail): the group's challenges as
##   Dungeon_Trial_List_Detail rows (TitleDescID, 입장레벨), the selected
##   one's title, scenario, completion rewards (A/B/C: name and amount of the
##   domain's own reward resolution), the running attempt's remaining time,
##   도전하기 / 보상 받기 / 도전 포기 and 즉시완료 (its original price). Every
##   button runs the page's own action request through the HUD confirmation
##   and runtime.execute("challenge", ...), which checks, pays and saves.
## Left empty (no picture in the packs / no TWILIGHT data): the thumbnails
## and location pictures (MiniAssetID / FullAssetID art), reward icons, the
## event badge and the per-row time limit tag.
const ROOT="UI/Dungeon_Trial/Dungeon_Trial_All.csb"
const THUMB_ROW="UI/Dungeon_Trial/Dungeon_Trial_List_ThumbNail.csb"
const DETAIL_ROW="UI/Dungeon_Trial/Dungeon_Trial_List_Detail.csb"
const Rows=preload("res://scripts/resources/current523_definition_rows.gd")
const T="Dungeon_Trial_Tab_ThumbNail/"
const D="Dungeon_Trial_Tab_Detail/Nd_Detail/"
## minimum level of an ordinary Challenge (challenge_domain eligibility).
const BASE_LEVEL: int=40
var group: int=-1
var selected: int=0
var _context: Dictionary={}
var _page: Dictionary={}

func required_members() -> Array[String]:
	return [ROOT,THUMB_ROW,DETAIL_ROW]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("unconfirmed523") if owner!=null else null

func _domain() -> Object:
	var runtime: Object=_runtime()
	if runtime==null:return null
	var domains: Variant=runtime.get("domains")
	return domains.get("challenge") if domains is Dictionary else null

func open(parent: Node) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null or _domain()==null or not runtime.source.ready():return _fail("source_trial_window_runtime_unavailable")
	if groups().is_empty():return _fail("source_trial_window_challenges_unavailable")
	group=-1
	selected=0
	return open_window(parent)

## Working Challenge rows grouped by their shared MiniAssetID, ordered by
## DisplayPriority (high first) then ID: [{asset, ids:[...]}].
func groups() -> Array:
	var domain: Object=_domain()
	if domain==null:return []
	var rows: Array=[]
	for value: Variant in (domain.get("_challenges") as Dictionary).values():
		if value is Dictionary and bool(value.get("IsWorking",false)):rows.append(value)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("DisplayPriority",0))!=int(b.get("DisplayPriority",0)):return int(a.get("DisplayPriority",0))>int(b.get("DisplayPriority",0))
		return int(a.ID)<int(b.ID))
	var found: Array=[]
	for row: Dictionary in rows:
		var asset: int=int(row.get("MiniAssetID",0))
		var into: Dictionary={}
		for existing: Dictionary in found:
			if int(existing.asset)==asset:into=existing
		if into.is_empty():
			into={"asset":asset,"ids":[]}
			found.append(into)
		(into.ids as Array).append(int(row.ID))
	return found

static func desc(id: int) -> String:
	var rows: Array[Dictionary]=Rows.related("DescData_Korean","ID",id)
	return str(rows[-1].get("Description","")).replace("\r\n","\n") if not rows.is_empty() else ""

## The challenge's own title (TitleDescID text, else its Name).
func title(id: int) -> String:
	var row: Dictionary=_row(id)
	var text: String=desc(int(row.get("TitleDescID",0)))
	return text if not text.is_empty() else str(row.get("Name",id))

## A group's title: its first member's title without the step number.
func group_title(ids: Array) -> String:
	var text: String=title(int(ids[0]))
	var cut: RegExMatch=RegEx.create_from_string("^(.*\\S)\\s+\\d+$").search(text)
	return cut.get_string(1) if cut!=null else text

func _row(id: int) -> Dictionary:
	var domain: Object=_domain()
	return (domain.get("_challenges") as Dictionary).get(id,{}) if domain!=null else {}

func level(id: int) -> int:
	var minimum: int=BASE_LEVEL
	var domain: Object=_domain()
	for prerequisite: Dictionary in domain.metadata(id).get("prerequisites",[]):
		if int(prerequisite.get("PrerequisiteTypeID",0))==1:minimum=maxi(minimum,int(prerequisite.get("Value",0)))
	return minimum

func _eligible(id: int) -> bool:
	return str(_domain().eligibility(id,_context)).is_empty()

## The page's actions of challenge `id` (and of the running attempt).
func actions(id: int) -> Dictionary:
	var found: Dictionary={}
	for row: Dictionary in _page.get("rows",[]):
		var key: String=str(row.get("id",""))
		if key=="challenge:%d" % id or (key=="challenge_active" and int(_active().get("challenge_id",0))==id):
			for action: Dictionary in row.get("actions",[]):found[str(action.request.get("op",""))]=action
	return found

func _active() -> Dictionary:
	var runtime: Object=_runtime()
	return runtime.state.get("domains",{}).get("challenge",{}).get("active",{}) if runtime!=null else {}

## Completion rewards as [{name, amount}] (the domain's own resolution).
func rewards(id: int) -> Array:
	var domain: Object=_domain()
	var runtime: Object=_runtime()
	var resolved: Dictionary=domain.call("_resolve_rewards",domain.metadata(id).get("completion_reward_ids",[]),_context)
	var out: Array=[]
	for reward: Dictionary in resolved.get("rewards",[]):
		var name: String=""
		match str(reward.get("kind","")):
			"item":name=str(runtime.source.row("ItemClass",int(reward.id)).get("Name",""))
			"currency":name="아데나" if int(reward.id)==1 else str(runtime.source.row("Currency",int(reward.id)).get("Name",""))
			"experience":name="경험치"
			"blessing":name="아인하사드의 축복"
			_:name=str(reward.get("kind",""))
		out.append({"name":name,"amount":int(reward.get("amount",0))})
	return out

## --- Spec / fill -------------------------------------------------------------

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	_context=runtime.context()
	_page=runtime.page("challenge")
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	# The full frame is modal: its background takes the touches the HUD
	# beneath would otherwise receive.
	spec["Nd_FullScreenBG/Img_bg1"]={"role":"consume"}
	if group<0:
		spec["Dungeon_Trial_Tab_Detail"]={"exclude":true}
		return spec
	spec["Dungeon_Trial_Tab_ThumbNail"]={"exclude":true}
	var ids: Array=groups()[group].ids
	selected=clampi(selected,0,ids.size()-1)
	var id: int=int(ids[selected])
	var row: Dictionary=_row(id)
	spec[D+"Label_Title"]={"role":"source_text","text":title(id)}
	spec[D+"Nd_Info/Img_Location"]={"visible":false}
	spec[D+"Nd_Info/Label_Info"]={"role":"source_text","text":desc(int(row.get("ScenarioDescID",0)))}
	var shown: Array=rewards(id)
	for i: int in range(3):
		var letter: String=["A","B","C"][i]
		var r: String=D+"Nd_RewardInfo/"
		var has: bool=i<shown.size()
		spec[r+"Nd_RewardSlot_"+letter]={"visible":has}
		spec[r+"Nd_RewardSlot_"+letter+"/Sp_Icon"]={"visible":false}
		spec[r+"Label_Reward_"+letter]={"role":"source_text","text":str(shown[i].name) if has else "","visible":has}
		spec[r+"Label_Reward_"+letter+"_Count"]={"role":"source_text","text":_number(int(shown[i].amount)) if has else "","visible":has}
	var active: Dictionary=_active()
	var running: bool=not active.is_empty() and int(active.get("challenge_id",0))==id
	var t: String=D+"Nd_RewardInfo/Nd_Time/"
	spec[t+"Label_Time"]={"role":"source_text","text":_clock(maxi(0,int(active.get("deadline",0))-int(_context.get("nowUnix",0)))) if running else _clock(int(row.get("TimeLimit",0)))}
	spec[t+"Label_Title"]={"role":"source_text","text":"남은시간 : " if running else "제한시간 : "}
	spec[t+"Label_Info"]={"role":"source_text","text":"매일 05시 도전횟수 초기화"}
	var acts: Dictionary=actions(id)
	var main: Dictionary=acts.get("challenge_claim",acts.get("challenge_start",acts.get("challenge_abandon",{})))
	var label: String="보상 받기" if acts.has("challenge_claim") else ("도전 포기" if acts.has("challenge_abandon") and not acts.has("challenge_start") else "도전하기")
	var b: String=D+"Nd_ButtonSet/Btn_Confirm"
	spec[b]={"activate":Callable(self,"_act").bind(main)}
	spec[b+"/Normal"]={"visible":not main.is_empty()}
	spec[b+"/Disabled"]={"visible":main.is_empty()}
	spec[b+"/Normal/Label"]={"role":"source_text","text":label}
	spec[b+"/Disabled/Label"]={"role":"source_text","text":label}
	var instant: Dictionary=acts.get("challenge_instant",{})
	var price: Dictionary=_domain().call("_instant_price",id,_context)
	var g: String=D+"Nd_ButtonSet/Btn_Confirm_Gem"
	spec[g]={"activate":Callable(self,"_act").bind(instant),"visible":price.get("ok",false)}
	spec[g+"/Normal"]={"visible":not instant.is_empty()}
	spec[g+"/Disabled"]={"visible":instant.is_empty()}
	spec[g+"/Label"]={"role":"source_text","text":_number(int(price.get("cost",{}).get("amount",0)))}
	spec["Dungeon_Trial_Tab_Detail/Btn_Back"]={"activate":Callable(self,"_back")}
	return spec

static func _clock(seconds: int) -> String:
	var s: int=maxi(0,seconds)
	return "%02d:%02d:%02d" % [s/3600,(s/60)%60,s%60]

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var all: Array=groups()
	var rows: Array=[]
	if group<0:
		for i: int in range(all.size()):
			var ids: Array=all[i].ids
			var open: bool=false
			var minimum: int=999
			for id: Variant in ids:
				open=open or _eligible(int(id))
				minimum=mini(minimum,level(int(id)))
			var first: Dictionary=_row(int(ids[0]))
			rows.append({"member":THUMB_ROW,"spec":{"Panel/Img_Sample":{"visible":false},
				"Panel/Label_Title":{"role":"source_text","text":group_title(ids)},
				"Panel/Label_Info":{"role":"source_text","text":desc(int(first.get("ScenarioDescID",0)))},
				"Panel/Btn_Normal":{"visible":open,"activate":Callable(self,"_group").bind(i)},
				"Btn_Normal/Sp_IconNew":{"visible":false},"Btn_Normal/Nd_Time":{"visible":false},
				"Panel/Btn_Disabled":{"visible":not open,"activate":Callable(self,"_group").bind(i)},
				"Btn_Disabled/Label_Info":{"role":"source_text","text":desc(int(first.get("ScenarioDescID",0)))},
				"Btn_Disabled/Nd_Notice/Label_Time":{"role":"source_text","text":"오픈 레벨 : %dLv" % minimum}}})
		var placed: Dictionary=_fill_list(root,out,T+"Nd_MenuButton/ListView",rows,NAN,true)
		if not placed.get("ok",false):return placed
		return {"ok":true,"tab":"thumbnail","groups":rows.size()}
	var ids: Array=all[group].ids
	for i: int in range(ids.size()):
		var id: int=int(ids[i])
		var on: bool=i==selected
		var open: bool=_eligible(id)
		var spec: Dictionary={}
		for state: String in ["Btn_Normal","Btn_Pressed","Btn_Disabled"]:
			var shown: bool=state=="Btn_Disabled" if not open else (state=="Btn_Pressed")==on and state!="Btn_Disabled"
			spec["Panel/"+state]={"visible":shown,"activate":Callable(self,"_select").bind(i)}
			spec[state+"/Sprite_Location"]={"visible":false}
			spec[state+"/Label_Title"]={"role":"source_text","text":title(id)}
			spec[state+"/Label_Level"]={"role":"source_text","text":"입장레벨 %d" % level(id)}
		rows.append({"member":DETAIL_ROW,"spec":spec})
	var listed: Dictionary=_fill_list(root,out,D+"Nd_DungeonList/ListView",rows)
	if not listed.get("ok",false):return listed
	return {"ok":true,"tab":"detail","group":group,"challenges":rows.size(),"selected":int(ids[selected]),"actions":actions(int(ids[selected])).keys()}

## --- Actions -----------------------------------------------------------------

func _group(i: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	group=i
	selected=0
	return _stage()

func _select(i: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	selected=i
	return _stage()

func _back() -> Dictionary:
	group=-1
	return _stage()

## A page action of the selected challenge through the HUD confirmation; the
## runtime repeats every check, pays, rewards and saves.
func _act(action: Dictionary) -> Dictionary:
	if action.is_empty():
		_message("지금은 할 수 없습니다")
		return {"ok":false}
	var owner: Object=hud()
	var runtime: Object=_runtime()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_trial_window_confirmation_unavailable")
	var request: Dictionary=action.request.duplicate(true)
	var revision: int=int(runtime.state.get("revision",-1))
	var expected: String=str(runtime.fingerprint())
	var id: int=int(request.get("challenge_id",_active().get("challenge_id",0)))
	owner.call("confirm_action","시련 던전","%s\n%s" % [title(id),str(action.get("label",""))],"확인",func(_count: int) -> void:
		var result: Dictionary=runtime.execute("challenge",request,revision,expected)
		_message(str(result.get("error",result.get("message","완료"))) if not result.get("ok",false) else "완료했습니다")
		if is_open():_stage())
	return {"ok":true,"quoted":str(request.get("op",""))}
