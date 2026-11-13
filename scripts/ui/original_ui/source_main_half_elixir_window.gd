extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 하프 엘릭서 window: Elixir_All (frame, 엘릭서 tab, title,
## close, help) with Elixir_Tab_StatInfo showing its
## Elixir_Tab_StatInfo_Group_Elixir page: 능력치 포인트 (unused points),
## 하프 엘릭서 (used / charged), 확장 횟수, one Elixir_List_Elixir row per
## investable bonus of the selected context (label, invested / cap, value,
## point cost, Max) and the original 복 용 / 확 장 / 능력치 초기화 buttons.
## Every action is the existing world.half_elixir request -> confirmation ->
## execute (scripts/growth/half_elixir_view.gd), so revision/nonce checks,
## costs and saves stay there. The context picker and the 523 ZIP install
## stay in the TWILIGHT view: without a chosen context the window does not
## open. Not connected: 엘릭서 제조 (Elixir_Tab_Recipe), the 스탯 group,
## 엘릭서 현황 and per-row withdrawal (Btn_Down; the runtime only resets).
const ROOT="UI/Elixir/Elixir_All.csb"
const ROW="UI/Elixir/Elixir_List_Elixir.csb"
const TAB="UI/Elixir/Elixir_List_Button.csb"
const G="Elixir_Tab_StatInfo/Nd_StatInfo_Group/Elixir_Tab_StatInfo_Group_Elixir/"

func required_members() -> Array[String]:
	return [ROOT,ROW,TAB]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("half_elixir") if owner!=null else null

func open(parent: Node, _item_name: String="") -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return _fail("source_half_elixir_runtime_unavailable")
	runtime.source=runtime.source_for(runtime.state)
	# Without an installed source and a chosen context the TWILIGHT view opens
	# instead (install + context picker); choosing a context there reopens this.
	if not _context_ready():return _fail("source_half_elixir_context_required")
	return open_window(parent)

## True while the runtime has a source and the saved context is one of its
## pairs. Every action is refused (no crash) otherwise.
func _context_ready() -> bool:
	var runtime: Object=_runtime()
	return runtime!=null and runtime.source!=null and runtime.source.pairs.has(runtime.state.context)

## A refresh after the context is gone (load, reset) closes the window
## instead of reading a missing source.
func _stage() -> Dictionary:
	if not _context_ready():
		close()
		return _fail("source_half_elixir_context_required")
	return super._stage()

func _refused() -> Dictionary:
	_message("지역과 월드를 먼저 선택해 주세요")
	return {"ok":false,"code":"source_half_elixir_context_required"}

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var source: Object=runtime.source
	var state: Dictionary=runtime.state
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_TopMenu/Label_Title"]={"role":"source_text","text":"하프 엘릭서"}
	spec["Btn_Help"]={"activate":Callable(self,"_help")}
	spec["Nd_Tab/Btn_Elixir_On"]={"visible":true}
	spec["Nd_Tab/Btn_Elixir_Off"]={"visible":false}
	spec["Nd_Tab/Btn_ElixirProduction_On"]={"visible":false}
	spec["Nd_Tab/Btn_ElixirProduction_Off"]={"visible":false}
	spec["Nd_Info_Set"]={"visible":false}
	spec["Elixir_Tab_Recipe"]={"exclude":true}
	spec["Elixir_Popup_ItemSet"]={"exclude":true}
	spec["Elixir_Tab_StatInfo_Group_Stat"]={"visible":false}
	var used: int=runtime.points_used()
	var points: int=int(state.points)
	spec[G+"Nd_ElixirInfo/Nd_Etc/Text_Point_Value"]={"role":"source_text","text":str(points-used)}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Text_Elixir_Value"]={"role":"source_text","text":"%d / %d" % [used,points]}
	var extended: bool=int(state.extension)>0
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_PointExtand/Nd_Extand_On"]={"visible":extended}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_PointExtand/Nd_Extand_Off"]={"visible":not extended}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_PointExtand/Nd_Extand_On/Text_Bonus_Value_0_0"]={"role":"source_text","text":str(int(state.extension))}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_PointExtand/Nd_Extand_Off/Text_Bonus_Value_0"]={"role":"source_text","text":str(int(state.extension))}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_ElixirExtand/Nd_Extand_On"]={"visible":extended}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_ElixirExtand/Nd_Extand_Off"]={"visible":not extended}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_ElixirExtand/Nd_Extand_On/Text_Elixir_Value_0"]={"role":"source_text","text":"%d / %d" % [int(state.extension),source.costs.size()]}
	spec[G+"Nd_ElixirInfo/Nd_Etc/Nd_ElixirExtand/Nd_Extand_Off/Text_Elixir_Value_0_0"]={"role":"source_text","text":"%d / %d" % [int(state.extension),source.costs.size()]}
	var next: Dictionary=source.costs.get(int(state.extension),{})
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Extand"]={"activate":Callable(self,"_extend"),"displaystate":not next.is_empty()}
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Extand/Normal"]={"visible":not next.is_empty()}
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Extand/Disabled"]={"visible":next.is_empty()}
	var can_reset: bool=not source.resets.is_empty() and used>0
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Reset"]={"activate":Callable(self,"_reset"),"displaystate":can_reset}
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Reset/Normal"]={"visible":can_reset}
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Reset/Disabled"]={"visible":not can_reset}
	spec[G+"Nd_ElixirInfo/Btn_Elixir_Decision"]={"visible":false}
	var charge: String=_charge_id()
	spec[G+"Nd_Amount_Elixir/Nd_Item_1/BTN_Plus"]={"activate":Callable(self,"_charge"),"displaystate":not charge.is_empty()}
	spec[G+"Nd_Amount_Elixir/Nd_Item_1/BTN_Plus/Normal"]={"visible":not charge.is_empty()}
	spec[G+"Nd_Amount_Elixir/Nd_Item_1/BTN_Plus/Disable"]={"visible":charge.is_empty()}
	return spec

## The first charge item the player owns (the existing view lists them all).
func _charge_id() -> String:
	var runtime: Object=_runtime()
	if not _context_ready():return ""
	for id: String in runtime.source.charges:
		if int(world().inventory.get(str(runtime.source.charges[id].name),0))>0:return id
	return ""

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var source: Object=runtime.source
	var state: Dictionary=runtime.state
	var tabs: Dictionary=_fill_list(root,out,"Elixir_Tab_StatInfo/Nd_Tab/ListView_Elixir",[{"member":TAB,"spec":{"Panel/Btn_Normal":{"visible":false},"Panel/Btn_Pressed":{"activate":Callable(self,"_ignore")},
		"Btn_Pressed/Label_Pressed":{"role":"source_text","text":"하프 엘릭서"}}}])
	if not tabs.get("ok",false):return tabs
	var selected: Dictionary=source.profile(state.context)
	var ids: Array=selected.keys()
	ids.sort_custom(func(a: String,b: String) -> bool:return int(a)<int(b))
	var left: Array=[]
	var right: Array=[]
	for index: int in range(ids.size()):
		var id: String=ids[index]
		var rule: Dictionary=selected[id]
		var count: int=int(state.allocations.get(id,0))
		var cost: int=int(rule.raw.Cost)
		var cap: int=int(source.cap(id,int(state.extension)))
		var effect: Dictionary=source.effect(id,1)
		var target: String=" · "+str(rule.target) if not str(rule.target).is_empty() else ""
		var row: Dictionary={"member":ROW,"spec":{"Panel_ElixirInfo/Text_Title":{"role":"source_text","text":str(rule.label)+target},
			"Panel_ElixirInfo/Text_Title_Value":{"role":"source_text","text":"%d/%d" % [count*cost,cap]},
			"Panel_ElixirInfo/Text_Title_ExtendValue":{"role":"source_text","text":"+"+str(effect.get("value",""))},
			"Panel_ElixirInfo/Text_Title_Max":{"visible":count*cost>=cap},
			"Panel_ElixirInfo/Text_Point_Value":{"role":"source_text","text":str(cost)},
			"Panel_ElixirInfo/Btn_Down":{"visible":false},
			"Panel_ElixirInfo/Btn_Up":{"activate":Callable(self,"_invest").bind(id,"%s%s · +%s · 비용 %d" % [str(rule.label),target,str(effect.get("value","")),cost])}}}
		if index%2==0:left.append(row)
		else:right.append(row)
	for pair: Array in [["ListView_StatInfo_Left",left],["ListView_StatInfo_Right",right]]:
		var listed: Dictionary=_fill_list(root,out,G+"Nd_ElixirInfo/"+str(pair[0]),pair[1])
		if not listed.get("ok",false):return listed
	return {"ok":true,"rows":ids.size(),"points":int(state.points),"used":runtime.points_used(),"extension":int(state.extension),"context":str(state.context)}

func _quote(command: Dictionary, description: String) -> Dictionary:
	if command.is_empty() or not command.get("ok",true):
		_message(str(command.get("message","요청할 수 없습니다")))
		return {"ok":false}
	var runtime: Object=_runtime()
	hud().call("confirm_action","하프 엘릭서",description,"확인",func(_count: int) -> void:
		var outcome: Dictionary=runtime.execute(command)
		_message(str(outcome.get("message","")))
		if is_open():_stage())
	return {"ok":true,"quoted":str(command.get("action",""))}

func _invest(id: String, label: String) -> Dictionary:
	if not _context_ready():return _refused()
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	return _quote(_runtime().request("invest",id),label+"\n미사용 포인트를 차감하고 능력치 1회분을 투자합니다.")

func _extend() -> Dictionary:
	if not _context_ready():return _refused()
	var runtime: Object=_runtime()
	var next: Dictionary=runtime.source.costs.get(int(runtime.state.extension),{})
	if next.is_empty():
		_message("원문 비용표의 마지막 확장 단계입니다")
		return {"ok":false}
	return _quote(runtime.request("extend"),"확장 %d → %d · 비용 %d · 자체 확률 %.2f%%" % [int(runtime.state.extension),int(next.AfterExtendPoint),int(next.Cost),100.0*float(next.Probability)/float(runtime.policy.probability_divisor)])

func _reset() -> Dictionary:
	if not _context_ready():return _refused()
	var runtime: Object=_runtime()
	if runtime.source.resets.is_empty():return {"ok":false}
	var id: String=str(runtime.source.resets.keys()[0])
	return _quote(runtime.request("reset",id),str(runtime.source.resets[id].name)+" 1개로 투자 포인트를 돌려받습니다. 확장 단계는 초기화하지 않습니다.")

func _charge() -> Dictionary:
	if not _context_ready():return _refused()
	var id: String=_charge_id()
	if id.is_empty():
		_message("사용할 하프 엘릭서가 없습니다")
		return {"ok":false}
	var runtime: Object=_runtime()
	return _quote(runtime.request("charge",id),"%s 1개를 소모해 사용 포인트를 충전합니다." % str(runtime.source.charges[id].name))

func _help() -> Dictionary:
	_message("하프 엘릭서: 복용으로 포인트를 충전하고 능력치에 투자합니다 · 확률 분모와 실패 차감은 TWILIGHT 자체 설정")
	return {"ok":true}
