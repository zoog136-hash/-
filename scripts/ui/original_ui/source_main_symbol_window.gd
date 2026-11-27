extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 문양 window: Symbol_All (frame, title, close, 축복 포인트,
## the seven god tabs 에바·파아그리오·마프르·사이하·그랑카인·아인하사드·실렌)
## with the selected god's Symbol_Tap_<god> page (its 30 Enchant parts play
## the original On_Loop / Off clips up to the current stage), Symbol_Percent
## (+1 / +2 / +3 단계 odds), Symbol_Listview_Buff (강화 횟수, Symbol_Grade
## playing its Grade_<n> clip, the option rows as Symbol_List_Buff: each
## stage option and the 절대 옵션 I~V rows with their point / key buttons)
## and the Nd_Button actions 문양 강화 / 5회, 확률 변경, 확률, 강화 초기화,
## 강화 정보 저장, 강화 복구 and 축복 포인트 상점 (축복의 열쇠).
## Every quote, cost, roll and save is the existing world.growth runtime
## (quote -> HUD confirmation -> execute), the same requests as the growth
## view. Committed stages light up using the original Enchant part clips.
## Bt_Compose_Touch lets the player reveal the saved result immediately.
## Btn_HelpBox
## opens the original Symbol_Popup_Help (source_main_help_box).
const ROOT="UI/Symbol/Symbol_All.csb"
const ROW="UI/Symbol/Symbol_List_Buff.csb"
const PERCENT="UI/Symbol/Symbol_Percent.csb"
const BUFF_LIST="UI/Symbol/Symbol_Listview_Buff.csb"
const GRADE="UI/Symbol/Symbol_Grade.csb"
const REVEAL_TOUCH="UI/Symbol/Bt_Compose_Touch.csb"
## growth emblem id -> original tab / page name.
const GODS={"eva":"Eva","paagrio":"Paagrio","maphr":"Maphr","sayha":"Sayha","grankain":"Grankain","einhasad":"Einhasad","shilen":"Silen"}
const PARTS: int=30
const ROMAN: Array[String]=["Ⅰ","Ⅱ","Ⅲ","Ⅳ","Ⅴ","Ⅵ","Ⅶ","Ⅷ","Ⅸ","Ⅹ"]
const ATTEMPT_LIMIT: int=20
const OPTION_LIST="Symbol_Listview_Buff/Nd_Buff/ListView"
const GRADE_PART="Symbol_Listview_Buff/Symbol_Grade"
const BOUND_PROPERTIES=["text","visible","percent","displaystate"]
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
var selected: String="eva"
var _next_spec: Dictionary={}
var _shown_spec: Dictionary={}
var _shown_options: Array=[]
var _option_scenes: Array[Node2D]=[]
var _option_bindings: Array[Dictionary]=[]
var _reveal_stages: Array[int]=[]
var _revealed_stage: int=0
var _reveal_message: String=""
var _reveal_press: int=-2

func required_members() -> Array[String]:
	return [ROOT,ROW,PERCENT,BUFF_LIST,GRADE]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("growth") if owner!=null else null

func open(parent: Node, id: String="") -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null or runtime.get("config")==null or runtime.config.get("emblems",[]).is_empty():return _fail("source_symbol_window_runtime_unavailable")
	if GODS.has(id):selected=id
	_clear_reveal()
	return open_window(parent)

func close() -> void:
	_clear_reveal()
	_next_spec.clear()
	_shown_spec.clear()
	_shown_options.clear()
	_option_scenes.clear()
	_option_bindings.clear()
	super.close()

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var p: Dictionary=runtime.progress(selected)
	var stage: int=int(p.stage)
	var spec: Dictionary={}
	for name: String in ["Bt_Compose_Touch","Symbol_OptionFX_Fullscreen_Layout","Fx_Registration","ProjectNode_1","Nd_Fx","Nd_Reset_Fx","Nd_Reset_Fx_Ein","Panel_1","Nd_Option_Fx","FullFrameType_A/Fx_Img_BG_Particle","Fx_Img_BG_Particle"]:spec[name]={"exclude":true}
	for id: String in GODS:
		var god: String=GODS[id]
		var on: bool=id==selected
		if not on:spec["Symbol_Tap_"+god]={"exclude":true}
		else:spec["Symbol_Tap_"+god]={"visible":true}
		spec["ListView_Tab/Btn_"+god]={"activate":Callable(self,"_select").bind(id)}
		spec["ListView_Tab/Btn_"+god+"/On"]={"visible":on}
		spec["ListView_Tab/Btn_"+god+"/Off"]={"visible":not on}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_TopMenu/Nd_Point/Label"]={"role":"source_text","text":_number(int(runtime.state.get("points",0)))}
	spec["Nd_Clear"]={"visible":stage>=runtime.symbol_stage_limit()}
	# Odds of +1 / +2 / +3 단계 (the runtime's current, rerolled odds).
	var odds: Array=runtime.probabilities(selected)
	var done: bool=stage>=runtime.symbol_stage_limit()
	for index: int in range(3):
		var value: float=0.0 if done or index>=odds.size() else float(odds[index])
		var panel: String="Symbol_Percent/Nd/Panel_0%d/" % (index+1)
		spec[panel+"Label_Per"]={"role":"source_text","text":"%s%%" % String.num(value,2)}
		spec[panel+"Progress"]={"role":"source_percent","percent":clampf(value,0.0,100.0)}
		spec[panel+"Label_Max"]={"visible":false}
	spec["Symbol_Listview_Buff/Nd_Buff/Nd_Num/Label_Num"]={"role":"source_text","text":"%d / %d" % [int(p.attempts),ATTEMPT_LIMIT]}
	spec["Symbol_Listview_Buff/Symbol_Grade"]={"visible":stage>=3}
	# Actions: each quote decides the button state and its price.
	for pair: Array in [["Btn_Upgrade","enhance",1],["Btn_Upgrade_Five","enhance",5],["Btn_Change","reroll",1],["Btn_Reset","reset",1],["Btn_Save","save_emblem",1],["Btn_Repair","restore_emblem",1]]:
		var offer: Dictionary=runtime.quote(str(pair[1]),selected,int(pair[2]))
		var ok: bool=bool(offer.get("ok",false))
		var key: String="Nd_Button/"+str(pair[0])
		spec[key]={"activate":Callable(self,"_ask").bind(str(pair[1]),selected,int(pair[2])),"displaystate":ok}
		# Symbol_All authors 저장 / 복구 with touchEnabled off (the client turns
		# it on in code); the features exist here, so they take a tap.
		if str(pair[0]) in ["Btn_Save","Btn_Repair"]:spec[key]["touch_enabled"]=true
		spec[key+"/Normal"]={"visible":ok}
		spec[key+"/Disabled"]={"visible":not ok}
		if str(pair[0]) in ["Btn_Upgrade","Btn_Upgrade_Five","Btn_Change"]:
			spec[key+"/Text_Price"]={"role":"source_text","text":_number(int(offer.get("points",0))) if ok else "-"}
	spec["Nd_Button/Btn_Reset/Disabled/Label_Complete"]={"visible":done}
	spec["Nd_Button/Btn_Probability"]={"activate":Callable(self,"_probability")}
	spec["Nd_Button/Btn_Probability/Disabled"]={"visible":false}
	spec["Btn_HelpBox"]={"activate":Callable(self,"_help")}
	spec["Btn_Shop"]={"activate":Callable(self,"_ask").bind("buy_key","",1)}
	_next_spec=spec
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var p: Dictionary=runtime.progress(selected)
	var stage: int=int(p.stage)
	var clips: int=0
	# The page's enchant parts follow the original clips.
	var god: String=GODS[selected]
	for index: int in range(1,PARTS+1):
		if _play(root,out,"Symbol_Tap_%s/Nd_Symbol/Nd_Parts/Enchant_%d" % [god,index],"On_Loop" if index<=stage else "Off",index<=stage)!=null:
			clips+=1
	if stage>=3 and _play(root,out,GRADE_PART,"Grade_%d" % (mini(stage,30)/3*3),false)!=null:clips+=1
	var rows: Array=_option_rows(runtime,stage,p.get("absolute_grades",[]))
	var listed: Dictionary=_fill_list(root,out,OPTION_LIST,rows)
	if not listed.get("ok",false):return listed
	_shown_spec=_next_spec
	_shown_options=rows
	_option_scenes=listed.scenes
	_option_bindings=listed.outs
	return {"ok":true,"selected":selected,"stage":stage,"attempts":int(p.attempts),"rows":rows.size(),"clips":clips}

## The selected god's tree and option rows have fixed geometry. After a
## transaction update the changed bindings on those nodes. Tab changes
## and an authored binding that cannot be updated still use the normal build.
func _refresh_progress() -> Dictionary:
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=last_result if _update_progress_bindings() else _stage()
	FRAME_HITCH.detail("growth.symbol_progress",started)
	return result

func _update_progress_bindings() -> bool:
	var rendered: Dictionary=last_result.get("filled",{})
	if not is_open() or rendered.get("selected")!=selected:return false
	var runtime: Object=_runtime()
	var progress: Dictionary=runtime.progress(selected)
	var stage: int=int(progress.stage)
	var previous: int=int(rendered.stage)
	var rows: Array=_option_rows(runtime,stage,progress.get("absolute_grades",[]))
	if rows.size()!=_option_scenes.size():return false
	var updated: Dictionary=_spec()
	if not _apply_changed_bindings(_scene,_out,_shown_spec,updated):return false
	for index: int in rows.size():
		if rows[index].member!=_shown_options[index].member:return false
		if not _apply_changed_bindings(_option_scenes[index],_option_bindings[index],_shown_options[index].spec,rows[index].spec):return false
	for index: int in range(mini(previous,stage)+1,maxi(previous,stage)+1):
		var active: bool=index<=stage
		var part: String="Symbol_Tap_%s/Nd_Symbol/Nd_Parts/Enchant_%d" % [GODS[selected],index]
		if _play(_scene,_out,part,"On_Loop" if active else "Off",active)==null:return false
	if stage>=3 and mini(previous,30)/3!=mini(stage,30)/3:
		if _play(_scene,_out,GRADE_PART,"Grade_%d" % (mini(stage,30)/3*3),false)==null:return false
	rendered["stage"]=stage
	rendered["attempts"]=int(progress.attempts)
	rendered["clips"]=PARTS+int(stage>=3)
	_shown_spec=updated
	_shown_options=rows
	return true

static func _apply_changed_bindings(scene: Node2D, out: Dictionary, before: Dictionary, after: Dictionary) -> bool:
	for suffix: String in after:
		var update: Dictionary=after[suffix]
		var previous: Dictionary=before.get(suffix,{})
		if update==previous:continue
		var target: Dictionary={}
		for property: String in BOUND_PROPERTIES:
			if not update.has(property) or update[property]==previous.get(property):continue
			if target.is_empty():
				target=_locate(scene,out,suffix)
				if not target.get("ok",false):return false
			if not target.player.call("set_bound_"+property,target.offset,update[property]).get("ok",false):return false
	return true

## Stage option rows (Ⅰ~Ⅹ by the option's stage) then 절대 옵션 I~V.
func _option_rows(runtime: Object, stage: int, grades: Array) -> Array:
	var rows: Array=[]
	var native: Dictionary=runtime.source523.data.get("emblems",{}).get(selected,{})
	for detail: Dictionary in native.get("normal",[]):
		var at: int=int(detail.row.Enchant)
		var on: bool=stage>=at
		var text: String="%d단계 %s" % [at,runtime.source523.option_text(detail)]
		var numeral: String=ROMAN[clampi(at/3-1,0,ROMAN.size()-1)]
		rows.append({"member":ROW,"spec":_row_spec(on,false,numeral,text,{})})
	for grade: int in range(1,6):
		var block: Dictionary=runtime.source523.absolute(selected,grade)
		if block.is_empty():continue
		var parts: PackedStringArray=[]
		for detail: Dictionary in block.get("options",[]):parts.append(runtime.source523.option_text(detail))
		var opened: bool=grades.has(grade)
		var actions: Dictionary={}
		for action: String in ["absolute_chance","absolute"]:actions[action]=runtime.quote(action,selected,grade)
		rows.append({"member":ROW,"spec":_row_spec(opened,true,"","절대 %d · %s" % [grade,", ".join(parts)],actions,grade)})
	return rows

func _row_spec(on: bool, absolute: bool, numeral: String, text: String, actions: Dictionary, grade: int=0) -> Dictionary:
	var spec: Dictionary={"Panel_List/Nd_Off":{"visible":not on and not absolute},"Panel_List/Nd_On":{"visible":on and not absolute},"Panel_List/Nd_On_MaxOption":{"visible":absolute}}
	for state: String in ["Nd_Off","Nd_On","Nd_On_MaxOption"]:
		spec["Panel_List/"+state+"/Label_Buff"]={"role":"source_text","text":text}
		if state!="Nd_On_MaxOption":spec["Panel_List/"+state+"/Label_Num"]={"role":"source_text","text":numeral}
	var chance: bool=bool(actions.get("absolute_chance",{}).get("ok",false))
	var key: bool=bool(actions.get("absolute",{}).get("ok",false))
	var shown: bool=absolute and not on
	spec["Panel_List/Btn_Open"]={"visible":shown,"displaystate":chance,"activate":Callable(self,"_ask").bind("absolute_chance",selected,grade)}
	spec["Panel_List/Btn_Open/Normal"]={"visible":chance}
	spec["Panel_List/Btn_Open/Disabled"]={"visible":not chance}
	spec["Panel_List/Btn_Open_Key"]={"visible":shown,"displaystate":key,"activate":Callable(self,"_ask").bind("absolute",selected,grade)}
	spec["Panel_List/Btn_Open_Key/Normal"]={"visible":key}
	spec["Panel_List/Btn_Open_Key/Disabled"]={"visible":not key}
	spec["Panel_List/Nd_Lock"]={"visible":shown and not chance and not key}
	return spec

func _play(root: Node2D, out: Dictionary, suffix: String, clip: String, repeat: bool) -> Node2D:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return null
	var holder: Variant=located.player.source_nodes.get(located.offset)
	var player: Variant=(holder.get_meta("source_project_player") if holder.has_meta("source_project_player") else null) if is_instance_valid(holder) else null
	if player==null or not player.play(clip,repeat).get("ok",false):return null
	return player

func _present_enhancement(previous_stage: int, response: Dictionary) -> bool:
	var stages: Array=response.get("enhancement_stages",[])
	if not is_open() or stages.is_empty() or not _pack.manifest.get("scenes",{}).has(REVEAL_TOUCH):return false
	# The original touch panel carries the displayed skip hint. Its rectangle
	# is animated, so a stationary modal area receives the first tap as well.
	var prompt: Dictionary=_scene_of(REVEAL_TOUCH,{"Panel_Touch/Bt_Touch":{"exclude":true}}, {})
	if not prompt.get("ok",false):return false
	var scene: Node2D=_scene
	var art: Node2D=prompt.scene
	art.name="SymbolEnhancementPrompt"
	scene.add_child(art)
	if not art.play("Loop",true).get("ok",false):
		art.queue_free()
		return false
	var input:=Control.new()
	input.name="SymbolEnhancementTouch"
	input.position=Vector2(-800.0,-400.0)
	input.size=Vector2(1600.0,800.0)
	input.mouse_filter=Control.MOUSE_FILTER_STOP
	input.gui_input.connect(_reveal_input.bind(scene))
	scene.add_child(input)
	_reveal_stages.assign(stages)
	_revealed_stage=previous_stage
	_reveal_message=str(response.message)
	_play_next_enhancement(scene)
	return true

func _play_next_enhancement(scene: Node2D) -> void:
	if not is_open() or _scene!=scene or _reveal_message.is_empty():return
	if _reveal_stages.is_empty():
		_finish_enhancement(scene)
		return
	var from_stage: int=_revealed_stage+1
	_revealed_stage=_reveal_stages.pop_front()
	var last: Node2D
	for index: int in range(from_stage,_revealed_stage+1):
		var part: Node2D=_play(scene,_out,"Symbol_Tap_%s/Nd_Symbol/Nd_Parts/Enchant_%d" % [GODS[selected],index],"On",false)
		if part!=null:last=part
	if last==null:
		_play_next_enhancement.call_deferred(scene)
		return
	last.clip_finished.connect(_enhancement_step_finished.bind(scene,from_stage,_revealed_stage),CONNECT_ONE_SHOT)

func _enhancement_step_finished(_clip: String, scene: Node2D, from_stage: int, through_stage: int) -> void:
	if not is_open() or _scene!=scene or _reveal_message.is_empty():return
	for index: int in range(from_stage,through_stage+1):
		_play(scene,_out,"Symbol_Tap_%s/Nd_Symbol/Nd_Parts/Enchant_%d" % [GODS[selected],index],"On_Loop",true)
	_play_next_enhancement.call_deferred(scene)

func _reveal_input(event: InputEvent, scene: Node2D) -> void:
	if not is_open() or _scene!=scene or _reveal_message.is_empty():return
	var index: int=-2
	if event is InputEventScreenTouch:index=event.index
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:index=-1
	if index==-2:return
	if event.pressed:
		if _reveal_press==-2:_reveal_press=index
	elif _reveal_press==index:
		if event is InputEventScreenTouch and event.canceled:_reveal_press=-2
		else:_finish_enhancement(scene)

func handle_reveal_input(event: InputEvent) -> bool:
	if not is_open() or _reveal_message.is_empty():return false
	_reveal_input(event,_scene)
	return true

func _finish_enhancement(scene: Node2D) -> void:
	if not is_open() or _scene!=scene or _reveal_message.is_empty():return
	var message: String=_reveal_message
	_clear_reveal()
	_message(message)
	# The transaction already completed. Remove its touch area before
	# publishing the final values to the live page.
	for name: String in ["SymbolEnhancementTouch","SymbolEnhancementPrompt"]:
		var node: CanvasItem=scene.get_node_or_null(name)
		if is_instance_valid(node):node.hide();node.queue_free()
	_refresh_progress()

func _clear_reveal() -> void:
	_reveal_message=""
	_reveal_stages.clear()
	_reveal_press=-2

## --- Actions ------------------------------------------------------------------

func _select(id: String) -> Dictionary:
	if not _reveal_message.is_empty():return {"ok":true,"ignored":true}
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if id==selected:return {"ok":true,"same":true}
	var runtime: Object=_runtime()
	# Leaving a symbol restores its base odds (the growth view's rule).
	if runtime!=null:runtime.rerolls.clear()
	selected=id
	return _stage()

## The existing quote -> confirmation -> execute of world.growth.
func _ask(action: String, id: String, count: int) -> Dictionary:
	if not _reveal_message.is_empty():return {"ok":true,"ignored":true}
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var runtime: Object=_runtime()
	if runtime==null:return _fail("source_symbol_window_runtime_unavailable")
	var offer: Dictionary=runtime.quote(action,id,count)
	if not offer.get("ok",false):
		_message(str(offer.get("message","요청할 수 없습니다")))
		return {"ok":false,"quoted":action}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_symbol_window_confirmation_unavailable")
	var revision: int=int(offer.get("revision",0))
	var day: int=int(offer.get("day",-1))
	var request_scene: Node2D=_scene
	var was_open: bool=is_open()
	var confirm: String="confirm_source_action" if owner.has_method("confirm_source_action") else "confirm_action"
	owner.call(confirm,"문양",str(offer.message),"확인",func(_count: int) -> void:
		if was_open and (not is_open() or _scene!=request_scene):return
		var previous_stage: int=int(runtime.progress(id).stage) if action=="enhance" else 0
		var response: Dictionary=runtime.execute(action,id,count,revision,day)
		if action=="enhance" and response.get("ok",false) and _present_enhancement(previous_stage,response):return
		_message(str(response.get("message","")))
		if is_open():_refresh_progress())
	return {"ok":true,"quoted":action,"count":count}

func _probability() -> Dictionary:
	var runtime: Object=_runtime()
	var odds: Array=runtime.probabilities(selected) if runtime!=null else []
	var parts: PackedStringArray=[]
	for index: int in range(odds.size()):parts.append("+%d단계 %s%%" % [index+1,String.num(float(odds[index]),2)])
	_message("문양 강화 확률 · "+(" · ".join(parts) if not parts.is_empty() else "완료"))
	return {"ok":true,"odds":odds}

## Btn_HelpBox: the original Symbol_Popup_Help over the window.
func _help() -> Dictionary:
	var shown: Dictionary=_open_help(HelpBox.SYMBOL)
	if not shown.get("handled",false):_message("문양 도움말: 원본 도움말(Symbol_Popup_Help)이 UI 팩에 없습니다")
	return {"ok":true,"original_help":shown.get("handled",false)}
