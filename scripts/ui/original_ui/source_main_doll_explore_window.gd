extends "res://scripts/ui/original_ui/source_main_card_dispatch_window.gd"
## The original 523 마법인형 탐험 window: Change_WinTotal with its
## Change_ExploreView page for the 마법인형 deck (MagicDollExpeditionSpot
## BuffCardDeckID 2, one doll per spot). The 변신 파견 window's structure is
## reused; every rule, cost, roll and save stays in the existing expedition
## runtime (world.expedition_local prepare / start / resurrect / claim).
## User list 2026-11-21 #10.
##
## - Left: the owned 마법인형 cards as Change_Card_A_<grade>; a tap selects
##   the doll for the open spot (one per spot). Dolls of a running job carry
##   Change_Card_A_Explore (탐험 중 / 탐험 완료 / 사망).
## - Map: the page's own Sp_WorldMap picture stays; the Change_Explore_Btn
##   spots are laid out as a grid over it (as the 변신 파견 window does: the
##   spot coordinates have no projection onto that picture, TWILIGHT 근사).
## - A spot without a job opens Change_Popup_Explore_Set (the doll, grade,
##   HP, time, buffs as Change_List_Explore_Buff rows, cost, 불러오기,
##   탐험 시작 -> existing confirmation -> runtime.start); a spot with a job
##   opens Change_Popup_Explore_Info (HP, time, 부활 / 탐험 중단 / 확 인).
## Not connected (no TWILIGHT rule or data): 보관함 사용 toggle, 일괄 재탐험,
## daily count, reset, the item / reward / exp / log lists of the popups.
const EXPLORE_P="Change_ExploreView/Nd_Explore/"
const EXPLORE_SPOT="UI/Change/Change_Explore_Btn.csb"
const EXPLORE_STATE="UI/Change/Change_Card_A_Explore.csb"
const EXPLORE_SET="UI/Change/Change_Popup_Explore_Set.csb"
const EXPLORE_INFO="UI/Change/Change_Popup_Explore_Info.csb"
const EXPLORE_BUFF_ROW="UI/Change/Change_List_Explore_Buff.csb"
const DOLL_DECK: int=2

func _init() -> void:
	deck=DOLL_DECK

func required_members() -> Array[String]:
	var members: Array[String]=[WIN_TOTAL,GRADE_ROW,CARD_SET,EXPLORE_SPOT,EXPLORE_STATE,EXPLORE_SET,EXPLORE_INFO,EXPLORE_BUFF_ROW]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	return members

func _page() -> String:
	return "Change_ExploreView"

func _tab() -> String:
	return "explore"

func _p() -> String:
	return EXPLORE_P

func _spot_member() -> String:
	return EXPLORE_SPOT

func open(parent: Node) -> Dictionary:
	category="마법인형"
	var catalogue: Object=_catalogue()
	if _runtime()==null or catalogue==null or not catalogue.ready():return _fail("source_doll_explore_catalogue_unavailable")
	popup=""
	return open_window(parent)

func _spec() -> Dictionary:
	var spec: Dictionary=super._spec()
	# The page's map clouds are a looping effect over the picture.
	for loop: String in ["Fx_CloudLoop_01","Fx_CloudLoop_02"]:spec[EXPLORE_P+"Nd_Map/Panel_Map/"+loop]={"exclude":true}
	return spec

## Change_Card_A_Explore over a doll of a job.
func _card_state(card: Node2D, job: Dictionary) -> Dictionary:
	var status: String=str(job.get("status",""))
	var shown: String={"running":"Nd_Explore","completed":"Nd_Complete","dead":"Nd_Death"}.get(status,"Nd_Explore")
	var name: String=str(_spot(int(job.spot_id)).get("Name",""))
	var spec: Dictionary={"Panel_Explore/Btn_Bg":{"visible":false}}
	for node: String in ["Nd_Explore","Nd_Complete","Nd_Death","Nd_Rest","Nd_Call","Nd_Grade"]:
		spec["Panel_Explore/"+node]={"visible":node==shown}
	spec[shown+"/Label_Spot"]={"role":"source_text","text":name}
	if shown!="Nd_Complete":spec[shown+"/Label_Time"]={"role":"source_text","text":_clock(int(job.get("remaining",0)))}
	var built: Dictionary=_scene_of(EXPLORE_STATE,spec,{})
	if not built.get("ok",false):return built
	built.scene.position=Vector2(-CARD_STATE_CENTER.x,CARD_STATE_CENTER.y)
	card.add_child(built.scene)
	return {"ok":true}

func _spot_spec(spot: Dictionary, job: Dictionary) -> Dictionary:
	var status: String=str(job.get("status",""))
	var shown: String={"running":"Btn_Explore","completed":"Btn_Complete","dead":"Btn_Death"}.get(status,"Btn_Spot")
	var name: String=str(spot.get("Name",""))
	var tap: Callable=Callable(self,"_spot_pressed").bind(int(spot.ID))
	var spec: Dictionary={}
	for button: String in ["Btn_Spot","Btn_Explore","Btn_Complete","Btn_Death","Btn_Non"]:
		spec["Panel_Spot/"+button]={"visible":button==shown,"activate":tap}
	spec["Btn_Spot/Label"]={"role":"source_text","text":name}
	for button: String in ["Btn_Explore","Btn_Complete","Btn_Death"]:
		spec[button+"/Nd_Title/Label_Spot"]={"role":"source_text","text":name}
	for button: String in ["Btn_Explore","Btn_Complete","Btn_Death"]:
		for sample: String in ["CardSample","CardSample_Multi","CardSample_A"]:spec[button+"/"+sample]={"exclude":true}
	return spec

## --- Set popup ----------------------------------------------------------------

func _set_spec() -> Dictionary:
	var spot: Dictionary=_spot(popup_spot)
	var prepared: Dictionary=_prepare()
	var spec: Dictionary={"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true},"Fx_Btn_Explore":{"visible":false}}
	spec["Bg/Text_Title"]={"role":"source_text","text":str(spot.get("Name",""))}
	spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
	spec["Btn_Back"]={"activate":Callable(self,"_auto_party")}
	spec["Nd_Info/Btn_Probability"]={"activate":Callable(self,"_rules")}
	spec["Nd_Info/Nd_Time/Label_Time"]={"role":"source_text","text":"%d시간" % (int(spot.get("TimeLimitSecond",0))/3600)}
	var entry: Dictionary=_party_entry()
	var filled: bool=not entry.is_empty()
	spec["Nd_Card/Label_Notice"]={"visible":not filled}
	spec["Nd_Card/Text_Card_Name"]={"role":"source_text","text":str(entry.get("record",{}).get("name","")) if filled else "","visible":filled}
	spec["Nd_Card/Nd_Text"]={"visible":filled}
	if filled:
		spec["Nd_Card/Nd_Text/Text_Class_Value"]={"role":"source_text","text":str(GRADE_NAMES.get(int(entry.source.get("GradeID",0)),""))}
		spec["Nd_Card/Nd_Text/Text_HP_Value"]={"role":"source_text","text":str(int(prepared.get("profile",{}).get("hp",0))) if prepared.get("ok",false) else "-"}
	var cost: int=int(prepared.get("cost",int(spot.get("ExpeditionCost",0))))
	var ready: bool=prepared.get("ok",false)
	spec["Btn_Explore"]={"activate":Callable(self,"_start"),"displaystate":ready}
	spec["Btn_Explore/Normal"]={"visible":ready}
	spec["Btn_Explore/Disabled"]={"visible":not ready}
	spec["Btn_Explore/Text_Price"]={"role":"source_text","text":_number(cost)}
	return spec

func _party_entry() -> Dictionary:
	if party.is_empty():return {}
	for entry: Dictionary in _owned_cards():
		if str(entry.card.identity)==party[0]:return entry
	return {}

func _open_set(root: Node2D) -> Dictionary:
	var out: Dictionary={}
	var built: Dictionary=_scene_of(EXPLORE_SET,_set_spec(),out)
	if not built.get("ok",false):return built
	var entry: Dictionary=_party_entry()
	var picture: bool=not entry.is_empty() and _slot_card(built.scene,out,"Nd_Card/Card",entry.record)
	var buff_rows: Dictionary=_buff_rows(built.scene,out)
	if not buff_rows.get("ok",false):
		built.scene.free()
		return buff_rows
	built.scene.z_index=POPUP_Z
	root.add_child(built.scene)
	return {"ok":true,"popup":"set","picture":picture,"buffs":int(buff_rows.rows),"ready":_prepare().get("ok",false)}

## The spot's buff options as Change_List_Explore_Buff rows (tap: on / off;
## an unsupported buff says so; Img_Disabled marks a buff not chosen).
func _buff_rows(scene: Node2D, out: Dictionary) -> Dictionary:
	var options: Array=_runtime().buff_options(deck)
	var rows: Array=[]
	for option: Dictionary in options:
		var id: int=int(option.buff.ID)
		var on: bool=buffs.has(id)
		var supported: bool=bool(option.get("supported",false))
		rows.append({"member":EXPLORE_BUFF_ROW,"spec":{"Panel/Sp_IconSample":{"visible":false},"Panel/Img_Disabled":{"visible":not on},"Panel/Button":{"activate":Callable(self,"_buff_pressed").bind(id) if supported else Callable(self,"_buff_unsupported")}}})
	if rows.is_empty():return {"ok":true,"rows":0}
	var located: Dictionary=_locate(scene,out,"Nd_Info/Nd_Buff/ListView")
	if not located.get("ok",false):return {"ok":true,"rows":0,"missing":"Nd_Buff/ListView"}
	var node: Variant=located.player.source_nodes.get(located.offset)
	var content: Variant=node.get_meta("source_list_content") if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return {"ok":true,"rows":0,"missing":"Nd_Buff/ListView content"}
	var geometry: Dictionary=_row_geometry(EXPLORE_BUFF_ROW)
	var cell: Vector2=geometry.size
	var size: Vector2=_node_size(out,"Nd_Info/Nd_Buff/ListView")
	for index: int in range(rows.size()):
		var built: Dictionary=_scene_of(str(rows[index].member),rows[index].spec,{})
		if not built.get("ok",false):return built
		_place(content,built.scene,geometry,Vector2(float(index)*(cell.x+6.0),size.y-cell.y))
	return {"ok":true,"rows":rows.size()}

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
	var entry: Dictionary={}
	for owned: Dictionary in _owned_cards():
		if str(owned.card.identity)==str(job.get("identity","")):entry=owned
	spec["Nd_Card/Text_Card_Name"]={"role":"source_text","text":str(entry.get("record",{}).get("name","")),"visible":not entry.is_empty()}
	spec["Nd_Card/Nd_Death"]={"visible":dead}
	var hp: int=int(sim.get("hp",0))
	var max_hp: int=maxi(1,int(sim.get("max_hp",1)))
	spec["Nd_Card/Nd_HpMp/Bar_HP"]={"role":"source_percent","percent":clampf(100.0*float(hp)/float(max_hp),0.0,100.0)}
	spec["Nd_Card/Nd_HpMp/Text_HP"]={"role":"source_text","text":"%d / %d" % [hp,max_hp]}
	var duration: int=maxi(1,int(job.get("duration",1)))
	var remaining: int=clampi(int(job.get("remaining",0)),0,duration)
	spec["Nd_Info/Nd_Time/Bar_Time"]={"role":"source_percent","percent":100.0*float(duration-remaining)/float(duration)}
	spec["Nd_Info/Nd_Time/Label_Time"]={"role":"source_text","text":_clock(remaining)}
	spec["Nd_Info/Nd_Exp"]={"visible":false}
	return spec

func _open_info(root: Node2D) -> Dictionary:
	var job: Dictionary=_jobs().get(popup_spot,{})
	if job.is_empty():
		popup=""
		return {"ok":true,"popup":"","closed_without_job":true}
	var out: Dictionary={}
	var built: Dictionary=_scene_of(EXPLORE_INFO,_info_spec(job),out)
	if not built.get("ok",false):return built
	var picture: bool=false
	for owned: Dictionary in _owned_cards():
		if str(owned.card.identity)==str(job.get("identity","")):picture=_slot_card(built.scene,out,"Nd_Card/Card",owned.record)
	built.scene.z_index=POPUP_Z
	root.add_child(built.scene)
	return {"ok":true,"popup":"info","status":str(job.get("status","")),"picture":picture}

## --- Actions --------------------------------------------------------------------

## One doll per spot: a tap selects it (again: deselects).
func _card_pressed(_checked: bool, identity: String) -> Dictionary:
	if _dragged():return _stage()
	if party.has(identity):party.clear()
	elif _runtime().reserved(identity):_message("이미 탐험 중인 마법인형입니다")
	else:
		party.clear()
		party.append(identity)
	return _stage()

func _auto_party() -> Dictionary:
	var free: Array=[]
	for entry: Dictionary in _owned_cards():
		if not _runtime().reserved(str(entry.card.identity)):free.append(entry)
	free.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.source.get("GradeID",0))>int(b.source.get("GradeID",0)))
	party.clear()
	if not free.is_empty():party.append(str(free[0].card.identity))
	else:_message("탐험할 수 있는 마법인형이 없습니다")
	return _stage()

func _buff_unsupported() -> Dictionary:
	_message("이 탐험 버프는 지원하지 않습니다")
	return {"ok":false,"code":"doll_explore_buff_unsupported"}

func _start() -> Dictionary:
	var prepared: Dictionary=_prepare()
	if not prepared.get("ok",false):
		_message(str(prepared.get("error","탐험할 수 없습니다")))
		return {"ok":false,"code":"doll_explore_not_ready"}
	var spot_id: int=popup_spot
	var members: Array=party.duplicate()
	var chosen: Array=buffs.duplicate()
	var runtime: Object=_runtime()
	var spot: Dictionary=_spot(spot_id)
	hud().call("confirm_action","인형 탐험","%s · %d시간\n아데나 %s 소모 (입장 %s + 버프 %s)%s" % [str(spot.get("Name","")),int(spot.get("TimeLimitSecond",0))/3600,_number(int(prepared.cost)),_number(int(prepared.entry_cost)),_number(int(prepared.cost)-int(prepared.entry_cost)),(" + 로컬다이아 %d" % int(prepared.buffs.diamonds)) if int(prepared.buffs.diamonds)>0 else ""],"탐험 시작",func(_count: int=1) -> void:
		var result: Dictionary=runtime.start(spot_id,members,chosen)
		_message(str(result.get("message",result.get("error",""))))
		if result.get("ok",false):
			party.clear()
			buffs.clear()
			popup=""
		if is_open():_stage())
	return {"ok":true,"existing_confirmation":true,"spot":spot_id,"party":members.size()}

func _help() -> Dictionary:
	var shown: Dictionary=_open_help(HelpBox.DISPATCH)
	_message("인형 탐험: 스팟마다 마법인형 1개를 8시간 탐험 보냅니다 · 최대 3개 스팟 동시 탐험")
	return {"ok":true,"original_help":shown.get("handled",false)}
