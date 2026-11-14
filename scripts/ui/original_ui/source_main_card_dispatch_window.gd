extends "res://scripts/ui/original_ui/source_main_change_page.gd"
## The original 523 변신 파견 window: Change_WinTotal with its
## Change_DispatchView page for the 변신 deck (MagicDollExpeditionSpot
## BuffCardDeckID 1). Every rule, cost, roll and save stays in the existing
## expedition runtime (world.expedition_local prepare / start / resurrect /
## claim, scripts/expedition/local_runtime.gd); this window only shows it.
##
## - Left: the owned 변신 cards (world.expedition_owned_cards, deck 1) as
##   Change_Card_A_<grade> with their own pictures; a tap toggles the card in
##   the dispatch party. Cards of a running job carry the original
##   Change_Card_A_Dispatch state (파견 중 / 파견 완료 / 사망).
## - Map: by decision (2026-11-14) no map picture; the original
##   Change_Dispatch_Btn spot buttons are laid out as a list grid inside the
##   empty Panel_Map (the spot CoordinateX/Y have no map to place them on).
## - A spot without a job opens the original Change_Popup_Dispatch_Set
##   (party slots, time, buffs, synergy, cost, 불러오기, 파견 시작 -> existing
##   confirmation -> runtime.start); a spot with a job opens
##   Change_Popup_Dispatch_Info (HP, time, 부활 / 파견 중단 / 확 인).
## Not connected (no TWILIGHT rule or data): 보관함 사용 toggle, 일괄 재파견,
## daily count, reset, the reward / item / exp / log lists of the popups
## (the TWILIGHT expedition view keeps storage, settlement and rules).
const P="Change_DispatchView/Nd_Dispatch/"
const SPOT_BUTTON="UI/Change/Change_Dispatch_Btn.csb"
const CARD_STATE="UI/Change/Change_Card_A_Dispatch.csb"
const SET_POPUP="UI/Change/Change_Popup_Dispatch_Set.csb"
const INFO_POPUP="UI/Change/Change_Popup_Dispatch_Info.csb"
const DECK: int=1
const POPUP_Z: int=100
## Change_Card_A_Dispatch's root panel centre (its 124x142 panel matches the
## card prefab's, whose centre is the card origin).
const CARD_STATE_CENTER=Vector2(64.0,76.0)
const SPOT_COLUMNS: int=3
const SET_SLOTS: Array[String]=["Panel_","Panel__0","Panel__1","Panel__1_0"]
const BUFF_PANELS: Array[String]=["Panel","Panel_0","Panel_1"]
const INFO_SLOTS: Array[String]=["Nd_Card01","Nd_Card02","Nd_Card03","Nd_Card04"]
const GRADE_NAMES={1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}
var party: Array[String]=[]
var buffs: Array[int]=[]
## "" (no popup), "set" or "info"; spot of the open popup.
var popup: String=""
var popup_spot: int=0

func required_members() -> Array[String]:
	var members: Array[String]=[WIN_TOTAL,GRADE_ROW,CARD_SET,SPOT_BUTTON,CARD_STATE,SET_POPUP,INFO_POPUP]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	return members

func _page() -> String:
	return "Change_DispatchView"

func _tab() -> String:
	return "dispatch"

func open(parent: Node) -> Dictionary:
	category="변신"
	var catalogue: Object=_catalogue()
	if _runtime()==null or catalogue==null or not catalogue.ready():return _fail("source_card_dispatch_catalogue_unavailable")
	popup=""
	return open_window(parent)

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("expedition_local") if owner!=null else null

func _catalogue() -> Object:
	var owner: Object=world()
	return owner.call("get_expedition_catalog") if owner!=null and owner.has_method("get_expedition_catalog") else null

func _spots() -> Array:
	var result: Array=[]
	for spot: Dictionary in _catalogue().spots():
		if int(spot.get("BuffCardDeckID",0))==DECK:result.append(spot)
	return result

func _spot(id: int) -> Dictionary:
	return _catalogue().record("MagicDollExpeditionSpot",id)

## The newest job of each spot (running, dead or completed until claimed).
func _jobs() -> Dictionary:
	var result: Dictionary={}
	for job: Dictionary in _runtime().jobs_view():
		if int(job.get("deck_id",0))==DECK:result[int(job.spot_id)]=job
	return result

## Owned deck-1 cards: {identity: {card, record}} (record is the catalog card
## for the picture), in the existing order.
func _owned_cards() -> Array:
	var records: Dictionary={}
	var owner: Object=hud()
	for record: Variant in owner.get("catalog_data").get(category,[]):
		if record is Dictionary:records[Cards.card_id(record)]=record
	var result: Array=[]
	for card: Dictionary in world().call("expedition_owned_cards"):
		var source: Dictionary=_catalogue().record("BuffCard",int(card.source_id))
		if int(source.get("BuffCardDeckID",0))!=DECK:continue
		result.append({"card":card,"record":records.get(str(card.identity),{}),"source":source})
	return result

## identity -> job status for the cards of a running job.
func _busy_cards() -> Dictionary:
	var result: Dictionary={}
	for job: Dictionary in _jobs().values():
		for identity: Variant in job.get("member_ids",[job.get("identity","")]):result[str(identity)]=job
	return result

func _prepare() -> Dictionary:
	if popup_spot==0 or party.is_empty():return {"ok":false,"error":"파견할 카드를 선택하세요"}
	return _runtime().prepare(popup_spot,party.duplicate(),buffs.duplicate())

func _spec() -> Dictionary:
	var spec: Dictionary=_frame_spec()
	spec[P+"Nd_CardList/Nd_Notice"]={"visible":_owned_cards().is_empty()}
	spec[P+"Nd_Map/Nd_Option/Nd_Storage/Nd_Use"]={"visible":false}
	spec[P+"Nd_Map/Nd_Option/Nd_Storage/Btn_Storage"]={"activate":Callable(self,"_storage")}
	spec[P+"Nd_Map/Nd_Option/Nd_Retry"]={"visible":false}
	spec[P+"Nd_Map/Nd_Option/Nd_Reset"]={"visible":false}
	spec[P+"Btn_Help"]={"activate":Callable(self,"_help")}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var busy: Dictionary=_busy_cards()
	var owned: Array=_owned_cards()
	var cards: Array=[]
	var shown: Array=[]
	for entry: Dictionary in owned:
		if entry.record.is_empty():continue
		var identity: String=str(entry.card.identity)
		var row: Dictionary=_card_row(entry.record,party.has(identity),Callable(self,"_card_pressed").bind(identity))
		if row.is_empty():continue
		cards.append(row)
		shown.append(entry)
	var grid: Dictionary=_optional(_fill_card_grid(root,out,P+"Nd_CardList/ListView",cards))
	if not grid.get("ok",false):return grid
	var pictures: int=0
	var states: int=0
	for index: int in range((grid.scenes as Array).size()):
		if _card_picture(grid.scenes[index],grid.outs[index],shown[index].record):pictures+=1
		var job: Dictionary=busy.get(str(shown[index].card.identity),{})
		if not job.is_empty():
			var placed: Dictionary=_card_state(grid.scenes[index],job)
			if not placed.get("ok",false):return placed
			states+=1
	var spots: Dictionary=_place_spots(root,out)
	if not spots.get("ok",false):return spots
	var shown_popup: Dictionary={}
	if popup=="set":shown_popup=_open_set(root)
	elif popup=="info":shown_popup=_open_info(root)
	if not shown_popup.is_empty() and not shown_popup.get("ok",false):return shown_popup
	return {"ok":true,"cards":cards.size(),"pictures":pictures,"card_states":states,"spots":int(spots.spots),"party":party.size(),"popup":popup,"popup_spot":popup_spot,"popup_fill":shown_popup}

## Change_Card_A_Dispatch over a card of a job (its root panel on the card's).
func _card_state(card: Node2D, job: Dictionary) -> Dictionary:
	var status: String=str(job.get("status",""))
	var shown: String={"running":"Nd_Dispatch","completed":"Nd_Complete","dead":"Nd_Death"}.get(status,"Nd_Dispatch")
	var name: String=str(_spot(int(job.spot_id)).get("Name",""))
	var spec: Dictionary={"Panel_Explore/Btn_Bg":{"visible":false}}
	for node: String in ["Nd_Dispatch","Nd_Complete","Nd_Death","Nd_Rest","Nd_Call","Nd_Clan"]:
		spec["Panel_Explore/"+node]={"visible":node==shown}
	spec[shown+"/Label_Spot"]={"role":"source_text","text":name}
	if shown!="Nd_Complete":spec[shown+"/Label_Time"]={"role":"source_text","text":_clock(int(job.get("remaining",0)))}
	var built: Dictionary=_scene_of(CARD_STATE,spec,{})
	if not built.get("ok",false):return built
	built.scene.position=Vector2(-CARD_STATE_CENTER.x,CARD_STATE_CENTER.y)
	card.add_child(built.scene)
	return {"ok":true}

## The deck's Change_Dispatch_Btn spots as a list grid in the empty Panel_Map.
func _place_spots(root: Node2D, out: Dictionary) -> Dictionary:
	var located: Dictionary=_locate(root,out,P+"Nd_Map/Panel_Map")
	if not located.get("ok",false):return {"ok":true,"spots":0,"missing":"Panel_Map"}
	var panel: Node=located.player.source_nodes.get(located.offset)
	var host: Node=panel.find_child("SourceClippedOrigin",true,false) if is_instance_valid(panel) else null
	if host==null:return {"ok":true,"spots":0,"missing":"Panel_Map/SourceClippedOrigin"}
	var size: Vector2=_node_size(out,P+"Nd_Map/Panel_Map")
	var geometry: Dictionary=_row_geometry(SPOT_BUTTON)
	var cell: Vector2=geometry.size
	var spots: Array=_spots()
	var rows: int=ceili(float(spots.size())/float(SPOT_COLUMNS))
	var gap: Vector2=Vector2((size.x-cell.x*SPOT_COLUMNS)/float(SPOT_COLUMNS+1),(size.y-cell.y*rows)/float(rows+1))
	var jobs: Dictionary=_jobs()
	for index: int in range(spots.size()):
		var spot: Dictionary=spots[index]
		var built: Dictionary=_scene_of(SPOT_BUTTON,_spot_spec(spot,jobs.get(int(spot.ID),{})),{})
		if not built.get("ok",false):return built
		var column: int=index%SPOT_COLUMNS
		var row: int=index/SPOT_COLUMNS
		var bottom_left:=Vector2(gap.x+float(column)*(cell.x+gap.x),size.y-float(row+1)*(cell.y+gap.y))
		_place(host,built.scene,geometry,bottom_left)
	return {"ok":true,"spots":spots.size()}

func _spot_spec(spot: Dictionary, job: Dictionary) -> Dictionary:
	var status: String=str(job.get("status",""))
	var shown: String={"running":"Btn_Dispatch","completed":"Btn_Complete","dead":"Btn_Death"}.get(status,"Btn_Castle")
	var name: String=str(spot.get("Name",""))
	var tap: Callable=Callable(self,"_spot_pressed").bind(int(spot.ID))
	var spec: Dictionary={}
	for button: String in ["Btn_Castle","Btn_Dispatch","Btn_Complete","Btn_Death","Btn_Non"]:
		spec["Panel_Castle/"+button]={"visible":button==shown,"activate":tap}
	spec["Btn_Castle/Label"]={"role":"source_text","text":name}
	for button: String in ["Btn_Dispatch","Btn_Complete","Btn_Death"]:
		spec[button+"/Nd_Title/Label_Spot"]={"role":"source_text","text":name}
	return spec

## --- Set popup ----------------------------------------------------------------

func _set_spec() -> Dictionary:
	var spot: Dictionary=_spot(popup_spot)
	var prepared: Dictionary=_prepare()
	var spec: Dictionary={"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true},"Fx_Btn_Dispatch":{"visible":false}}
	spec["Bg/Text_Title"]={"role":"source_text","text":str(spot.get("Name",""))}
	spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
	spec["Btn_Back"]={"activate":Callable(self,"_auto_party")}
	spec["Nd_Info/Btn_Probability"]={"activate":Callable(self,"_rules")}
	spec["Btn_SynergyList"]={"activate":Callable(self,"_synergies")}
	spec["Nd_Info/Nd_Time/Label_Time"]={"role":"source_text","text":"%d시간" % (int(spot.get("TimeLimitSecond",0))/3600)}
	spec["Nd_Card/Label_Notice"]={"visible":party.is_empty()}
	var lookup: Dictionary={}
	for entry: Dictionary in _owned_cards():lookup[str(entry.card.identity)]=entry
	for index: int in range(SET_SLOTS.size()):
		var slot: String="ListView_1/"+SET_SLOTS[index]+"/"
		var filled: bool=index<party.size() and lookup.has(party[index])
		spec[slot+"Nd_Text"]={"visible":filled}
		if filled:
			var source: Dictionary=lookup[party[index]].source
			spec[slot+"Nd_Text/Text_Class_Value"]={"role":"source_text","text":str(GRADE_NAMES.get(int(source.get("GradeID",0)),""))}
			spec[slot+"Nd_Text/Text_HP"]={"visible":false}
			spec[slot+"Nd_Text/Text_HP_Value"]={"visible":false}
	var representative: Dictionary=prepared.get("inspection",{}).get("party",{}).get("representative",{}) if prepared.get("ok",false) else {}
	var rep_source: Dictionary=_catalogue().record("BuffCard",int(representative.get("source_id",0))) if not representative.is_empty() else {}
	spec["Nd_Card/Nd_Info"]={"visible":prepared.get("ok",false)}
	spec["Nd_Card/Nd_Info/Text_Class_Value"]={"role":"source_text","text":str(GRADE_NAMES.get(int(rep_source.get("GradeID",0)),""))}
	spec["Nd_Card/Nd_Info/Text_HP_Value"]={"role":"source_text","text":str(int(prepared.get("profile",{}).get("hp",0)))}
	var options: Array=_runtime().buff_options(DECK)
	for index: int in range(BUFF_PANELS.size()):
		var panel: String="Nd_Buff/ListView/"+BUFF_PANELS[index]
		if index>=options.size():
			spec[panel]={"visible":false}
			continue
		var option: Dictionary=options[index]
		var id: int=int(option.buff.ID)
		var on: bool=buffs.has(id)
		var supported: bool=bool(option.get("supported",false))
		spec[panel+"/Text_Price"]={"role":"source_text","text":_number(int(option.buff.Cost))}
		spec[panel+"/Btn_Normal"]={"visible":not on,"activate":Callable(self,"_buff_pressed").bind(id),"displaystate":supported}
		spec[panel+"/Btn_Pressed"]={"visible":on,"activate":Callable(self,"_buff_pressed").bind(id)}
	var synergies: Array=prepared.get("inspection",{}).get("party",{}).get("synergy_ids",[]) if prepared.get("ok",false) else []
	spec["Nd_SynergyInfo/Nd_On"]={"visible":not synergies.is_empty()}
	spec["Nd_SynergyInfo/Nd_Off"]={"visible":synergies.is_empty()}
	if not synergies.is_empty():spec["Nd_SynergyInfo/Nd_On/Text_Dsc"]={"role":"source_text","text":_synergy_names(synergies)}
	var cost: int=int(prepared.get("cost",int(spot.get("ExpeditionCost",0))))
	var ready: bool=prepared.get("ok",false)
	spec["Btn_Dispatch"]={"activate":Callable(self,"_start"),"displaystate":ready}
	spec["Btn_Dispatch/Normal"]={"visible":ready}
	spec["Btn_Dispatch/Disabled"]={"visible":not ready}
	spec["Btn_Dispatch/Text_Price"]={"role":"source_text","text":_number(cost)}
	return spec

func _open_set(root: Node2D) -> Dictionary:
	var out: Dictionary={}
	var built: Dictionary=_scene_of(SET_POPUP,_set_spec(),out)
	if not built.get("ok",false):return built
	var lookup: Dictionary={}
	for entry: Dictionary in _owned_cards():lookup[str(entry.card.identity)]=entry
	var pictures: int=0
	for index: int in range(mini(party.size(),SET_SLOTS.size())):
		if not lookup.has(party[index]):continue
		if _slot_card(built.scene,out,"ListView_1/"+SET_SLOTS[index]+"/Nd_Card_Set/Card",lookup[party[index]].record):pictures+=1
	built.scene.z_index=POPUP_Z
	root.add_child(built.scene)
	return {"ok":true,"popup":"set","slots":mini(party.size(),SET_SLOTS.size()),"pictures":pictures,"ready":_prepare().get("ok",false)}

## A party card's own Change_Card_A_<grade> over an original empty card slot.
func _slot_card(scene: Node2D, out: Dictionary, slot_suffix: String, record: Dictionary) -> bool:
	if record.is_empty():return false
	var located: Dictionary=_locate(scene,out,slot_suffix)
	if not located.get("ok",false):return false
	var slot: Node=located.player.source_nodes.get(located.offset)
	if not slot is Node2D:return false
	var row: Dictionary=_card_row(record,false,Callable(self,"_ignore_card"))
	if row.is_empty():return false
	var card_out: Dictionary={}
	var built: Dictionary=_scene_of(str(row.member),row.spec,card_out)
	if not built.get("ok",false):return false
	(slot as Node2D).add_child(built.scene)
	return _card_picture(built.scene,card_out,record)

func _ignore_card(_checked: bool) -> Dictionary:
	return {"ok":true}

## --- Info popup ---------------------------------------------------------------

func _info_spec(job: Dictionary) -> Dictionary:
	var spot: Dictionary=_spot(popup_spot)
	var status: String=str(job.get("status",""))
	var sim: Dictionary=job.get("sim",{})
	var limit: int=int(spot.get("ResurrectionLimit",3))
	var revives: int=int(sim.get("resurrections",0))
	var spec: Dictionary={"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true}}
	spec["Bg/Text_Title"]={"role":"source_text","text":str(spot.get("Name",""))}
	spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
	var dead: bool=status=="dead"
	var done: bool=status=="completed"
	var can_revive: bool=dead and revives<limit
	spec["Btn_Resurrection"]={"visible":dead,"activate":Callable(self,"_job_action").bind("revive"),"displaystate":can_revive}
	spec["Btn_Resurrection/Normal"]={"visible":can_revive}
	spec["Btn_Resurrection/Disabled"]={"visible":not can_revive}
	for state: String in ["Normal","Disabled"]:spec["Btn_Resurrection/%s/Label" % state]={"role":"source_text","text":"부활 (%d/%d)" % [revives,limit]}
	spec["Btn_Stop"]={"visible":not done,"activate":Callable(self,"_job_action").bind("abort")}
	spec["Btn_Confirm"]={"visible":done,"activate":Callable(self,"_job_action").bind("claim")}
	var members: Array=job.get("member_ids",[job.get("identity","")])
	for index: int in range(INFO_SLOTS.size()):
		spec["Nd_Card/"+INFO_SLOTS[index]]={"visible":index<members.size()}
		spec["Nd_Card/"+INFO_SLOTS[index]+"/Nd_Death"]={"visible":dead}
	var hp: int=int(sim.get("hp",0))
	var max_hp: int=maxi(1,int(sim.get("max_hp",1)))
	spec["Nd_Card/Nd_HpMp/Bar_HP"]={"role":"source_percent","percent":clampf(100.0*float(hp)/float(max_hp),0.0,100.0)}
	spec["Nd_Card/Nd_HpMp/Text_HP"]={"role":"source_text","text":"%d / %d" % [hp,max_hp]}
	var duration: int=maxi(1,int(job.get("duration",1)))
	var remaining: int=clampi(int(job.get("remaining",0)),0,duration)
	spec["Nd_Info/Nd_Time/Bar_Time"]={"role":"source_percent","percent":100.0*float(duration-remaining)/float(duration)}
	spec["Nd_Info/Nd_Time/Label_Time"]={"role":"source_text","text":_clock(remaining)}
	spec["Nd_Info/Nd_Exp/ListView/Panel"]={"visible":false}
	spec["Nd_Info/Nd_Exp/ListView/Panel_0"]={"visible":false}
	return spec

func _open_info(root: Node2D) -> Dictionary:
	var job: Dictionary=_jobs().get(popup_spot,{})
	if job.is_empty():
		popup=""
		return {"ok":true,"popup":"","closed_without_job":true}
	var out: Dictionary={}
	var built: Dictionary=_scene_of(INFO_POPUP,_info_spec(job),out)
	if not built.get("ok",false):return built
	var lookup: Dictionary={}
	for entry: Dictionary in _owned_cards():lookup[str(entry.card.identity)]=entry
	var members: Array=job.get("member_ids",[job.get("identity","")])
	var pictures: int=0
	for index: int in range(mini(members.size(),INFO_SLOTS.size())):
		var entry: Dictionary=lookup.get(str(members[index]),{})
		if not entry.is_empty() and _slot_card(built.scene,out,"Nd_Card/"+INFO_SLOTS[index]+"/Card",entry.record):pictures+=1
	built.scene.z_index=POPUP_Z
	root.add_child(built.scene)
	return {"ok":true,"popup":"info","status":str(job.get("status","")),"members":members.size(),"pictures":pictures}

## --- Actions --------------------------------------------------------------------

func _card_pressed(_checked: bool, identity: String) -> Dictionary:
	if _dragged():return _stage()
	if party.has(identity):party.erase(identity)
	elif _runtime().reserved(identity):_message("이미 파견 중인 카드입니다")
	else:
		var limit: int=int(_spot(popup_spot).get("CardCount",4)) if popup_spot!=0 else 4
		if party.size()>=limit:_message("파견단은 %d장까지 선택할 수 있습니다" % limit)
		else:party.append(identity)
	return _stage()

func _spot_pressed(spot_id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	popup_spot=spot_id
	popup="info" if _jobs().has(spot_id) else "set"
	return _stage()

func _close_popup() -> Dictionary:
	popup=""
	return _stage()

func _buff_pressed(id: int) -> Dictionary:
	if buffs.has(id):buffs.erase(id)
	else:buffs.append(id)
	return _stage()

## 불러오기: the strongest free cards up to the spot's card count.
func _auto_party() -> Dictionary:
	var limit: int=int(_spot(popup_spot).get("CardCount",4))
	var free: Array=[]
	for entry: Dictionary in _owned_cards():
		if not _runtime().reserved(str(entry.card.identity)):free.append(entry)
	free.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.source.get("GradeID",0))>int(b.source.get("GradeID",0)))
	party.clear()
	for index: int in range(mini(limit,free.size())):party.append(str(free[index].card.identity))
	if party.is_empty():_message("파견할 수 있는 변신 카드가 없습니다")
	return _stage()

func _start() -> Dictionary:
	var prepared: Dictionary=_prepare()
	if not prepared.get("ok",false):
		_message(str(prepared.get("error","파견할 수 없습니다")))
		return {"ok":false,"code":"card_dispatch_not_ready"}
	var spot_id: int=popup_spot
	var members: Array=party.duplicate()
	var chosen: Array=buffs.duplicate()
	var runtime: Object=_runtime()
	var spot: Dictionary=_spot(spot_id)
	hud().call("confirm_action","변신 파견","%s · %d시간\n아데나 %s 소모 (입장 %s + 버프 %s)%s\n원본 수치를 우선하며, 부족한 전투·이벤트 규칙은 TWILIGHT 추정 설정으로 진행합니다." % [str(spot.get("Name","")),int(spot.get("TimeLimitSecond",0))/3600,_number(int(prepared.cost)),_number(int(prepared.entry_cost)),_number(int(prepared.cost)-int(prepared.entry_cost)),(" + 로컬다이아 %d" % int(prepared.buffs.diamonds)) if int(prepared.buffs.diamonds)>0 else ""],"파견 시작",func(_count: int=1) -> void:
		var result: Dictionary=runtime.start(spot_id,members,chosen)
		_message(str(result.get("message",result.get("error",""))))
		if result.get("ok",false):
			party.clear()
			buffs.clear()
			popup=""
		if is_open():_stage())
	return {"ok":true,"existing_confirmation":true,"spot":spot_id,"party":members.size()}

func _job_action(action: String) -> Dictionary:
	var job: Dictionary=_jobs().get(popup_spot,{})
	if job.is_empty():return _close_popup()
	var runtime: Object=_runtime()
	var view: Dictionary=runtime.settlement_view(int(job.id))
	var body: String="완주 보상과 카드 경험치를 1회 수령합니다."
	if action=="revive":body="원본 파견 비용 50다이아 · HP 50%로 부활합니다. TWILIGHT 탐험 로컬다이아 잔액에서 소모합니다."
	if action=="abort" and view.get("ok",false):body="파견을 중단하고 발견한 아이템·경험치의 %.1f%%를 수령합니다. 회수율은 추정 설정이며 완료 상자는 없습니다." % (float(view.job.sim.policy.abort_recovery_permyriad)/100.0)
	var id: int=int(job.id)
	hud().call("confirm_action","변신 파견",body,{"claim":"확 인","revive":"부활","abort":"파견 중단"}.get(action,action),func(_count: int=1) -> void:
		var result: Dictionary=runtime.resurrect(id) if action=="revive" else runtime.claim(id,action=="abort")
		_message(str(result.get("message",result.get("error",""))))
		if result.get("ok",false) and action!="revive":popup=""
		if is_open():_stage())
	return {"ok":true,"existing_confirmation":true,"action":action,"job":id}

func _storage() -> Dictionary:
	return _route("open_expedition")

func _help() -> Dictionary:
	_message("변신 파견: 변신 카드 최대 4장을 스팟에 8시간 파견합니다 · 원본 비용·시간·HP·보상, 전투·이벤트는 TWILIGHT 추정 규칙")
	return {"ok":true}

func _rules() -> Dictionary:
	var rules: Dictionary=_runtime().rules_view()
	_message("원본: 장소·카드 조건·입장비·시간·HP·보상 후보와 가중치·부활 3회 · TWILIGHT 추정: 이벤트 %d초 주기, 중단 회수율 %.1f%%" % [int(rules.get("event_interval_seconds",0)),float(rules.get("abort_recovery_permyriad",0))/100.0])
	return {"ok":true}

func _synergies() -> Dictionary:
	var names: PackedStringArray=[]
	for entry: Dictionary in _catalogue().synergy_evidence():names.append(str(entry.synergy.get("Name","")))
	_message("시너지: "+(", ".join(names) if not names.is_empty() else "없음"))
	return {"ok":true}

func _synergy_names(ids: Array) -> String:
	var names: PackedStringArray=[]
	for id: Variant in ids:names.append(str(_catalogue().record("BuffCardExpeditionSynergy",int(id)).get("Name",id)))
	return ", ".join(names)

static func _clock(seconds: int) -> String:
	seconds=maxi(0,seconds)
	return "%02d:%02d" % [seconds/3600,(seconds%3600)/60]
