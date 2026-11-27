extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 강화 결과 screen (UI/FloatingUi/Enchant_Result.csb) for a
## roll the world already committed and saved. It never rolls, pays or
## stores; source_main_enchant_window opens it over EnchantScene.
## The client's own two-touch flow (user request 2026-11-27 "한 번 터치하세요가
## 나온 뒤에 결과"), all from the scene's own clips and texts:
##  1. Fx_Result_Start (5..25) then Fx_Result_StartLoop (26..90, repeating):
##     the item slot, Fx_Seet_Loop/Label_Confilm "결과 확인" and
##     Label_TouchScreen_B "화면을 터치하세요." (UIStaticTextData
##     ENCHANT_RESULT\FX_SEET_LOOP\LABEL_CONFILM / LABEL_TOUCHSCREEN_B).
##     The outcome is not on screen yet.
##  2. A touch: Fx_Result_EndText (95..125) fades in Nd_TextSet (the stat
##     lines) while Fx_Enchant_Result plays the outcome (Fx_Enchant_Success /
##     Fx_Enchant_SideEffect = 실패 / Fx_Enchant_Vaporize = 소실) with its
##     Enchant_Popup_Message banner (Success / Fail), and
##     Fx_Enchant_Result_Loop loops behind the slot (Fx_Success_Loop /
##     Fx_SideEffect_Loop). Then Fx_Result_EndLoop (300..420, repeating)
##     blinks Label_TouchScreen "화면을 터치하세요.".
##  3. Another touch closes it. Nothing closes it by itself.
## A touch while the outcome animates jumps to its settled state.
## TWILIGHT 근사: the banner's Text_Item text and the stat line values (the
## client fills them from server packets not in the 523 tables); 다중 강화
## lists one line per target (+시작 → +결과).
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const ROOT="UI/FloatingUi/Enchant_Result.csb"
const FX_RESULT="UI/Effect/Effect_Source/Fx_Enchant_Result.csb"
const FX_LOOP="UI/Effect/Effect_Source/Fx_Enchant_Result_Loop.csb"
const POPUP="UI/FloatingUi/Enchant_Popup_Message.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const TEXT_SET="UI/FloatingUi/Enchant_Text_Set.csb"
const TEXT_SET_SKILL="UI/FloatingUi/Enchant_Text_Set_Skill.csb"
const WAIT_INTRO="Fx_Result_Start"
const WAIT_LOOP="Fx_Result_StartLoop"
const REVEAL="Fx_Result_EndText"
const SETTLED_LOOP="Fx_Result_EndLoop"
const P_FX="Fx_Enchant_Result"
const P_LOOP="Fx_Enchant_Result_Loop"
const P_POPUP="Fx_Enchant_Result/Enchant_Popup_Message"
const P_TEXT="Nd_TextSet/ScrollView/TextSet"
const P_SLOT="Inventory_Slot"
## Enchant_Text_Set authors one 40 px line; further lines follow it (the
## enchant window's TEXT_PITCH).
const TEXT_PITCH: float=30.0
const TEXT_LINES: int=10
## Enchant_Popup_Message's fully opaque keys (its clips fade the text out).
const BANNER_HOLD: Dictionary={"Success":40.0,"Fail":145.0}
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
signal finished
## {kind: success | fail, outcome: success | maintain | decrease | destroy,
##  text, title, record, from, to, rows (Callable -> Array of {label,now,next})}
var result: Dictionary={}
var _steady: bool=false
var _waiting: bool=false
var _held: bool=false
var _queue: Array[String]=[]
var _banner: Node2D
var _banner_held: bool=false
var _tree_ref: WeakRef
var _pressed: bool=false
var _drag: float=0.0
var pictures: int=0

func required_members() -> Array[String]:
	return [ROOT,FX_RESULT,FX_LOOP,POPUP,SLOT,TEXT_SET]

func _root_member() -> String:
	return ROOT

## Opens on the committed `outcome` (see `result`); `settings` is the world's
## presentation_settings (reduced motion enters each settled frame at once).
func open(parent: Node, outcome: Dictionary, settings: Dictionary={}) -> Dictionary:
	if is_open():return _fail("source_enchant_result_already_open")
	result=outcome.duplicate()
	_steady=bool(settings.get("reduced_motion",false)) or float(settings.get("impact_intensity",1.0))<=0.0
	_waiting=true
	_held=false
	_queue=[]
	_banner=null
	_banner_held=false
	_pressed=false
	var built: Dictionary=open_window(parent)
	if not built.get("ok",false):return built
	_scene.z_index=190
	for clip: String in [WAIT_INTRO,WAIT_LOOP,REVEAL,SETTLED_LOOP]:
		if _clip_range(_scene,clip).is_empty():
			close()
			return _fail("source_enchant_result_clip_missing")
	if _steady:
		_settle(_scene,WAIT_LOOP)
	else:
		_scene.play(WAIT_INTRO,false)
		_queue=[WAIT_LOOP]
		_tree_ref=weakref(parent.get_tree())
		parent.get_tree().process_frame.connect(_after_frame)
	# Input coverage only; every visible pixel and text is the source scene.
	var input:=Control.new()
	input.name="EnchantResultScreenTouch"
	input.mouse_filter=Control.MOUSE_FILTER_STOP
	input.position=Vector2(-1800,-1200)
	input.size=Vector2(3600,2400)
	input.gui_input.connect(_touch.bind(input))
	_scene.add_child(input)
	return built

func _spec() -> Dictionary:
	var spec: Dictionary={}
	for set_name: String in ["EnChant_Success","EnChant_Fail"]:
		spec[P_POPUP+"/Set/"+set_name+"/Text_Item"]={"role":"source_text","text":" "}
	spec["Nd_TextSet/ScrollView/TextSet_Skill"]={"exclude":true}
	for name: String in SLOT_EXCLUDED:spec[P_SLOT+"/"+name]={"exclude":true}
	spec[P_SLOT+"/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	var amount: String=_level_text(int(result.get("from",0)))
	spec[P_SLOT+"/Text_Amount"]={"role":"source_text","text":amount,"visible":not amount.is_empty()}
	# Stat lines are filled at the reveal (blank before it).
	spec[P_TEXT+"/Text_List_1"]={"role":"source_text","text":" "}
	spec[P_TEXT+"/Text_List_1_0"]={"role":"source_text","text":" "}
	spec[P_TEXT+"/Text_List_1_Value"]={"role":"source_text","text":" "}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	pictures=0
	# The outcome layers rest hidden until the touch (their authored rest
	# frames would show the result early). Fx_Enchant_Result.csb has an inner
	# node of the same name, so only the scene's own top-level node is used.
	for name: String in [P_FX,P_LOOP]:
		var top: Dictionary=_top(root,out,name)
		if not top.get("ok",false):return _fail("source_enchant_result_layer_missing")
		(top.node as Node2D).visible=false
	var record: Dictionary=result.get("record",{}) if result.get("record") is Dictionary else {}
	if record.is_empty():return {"ok":true}
	var icon: Dictionary=_locate(root,out,P_SLOT+"/Sp_IconSample")
	if icon.get("ok",false):
		var info: Dictionary=SourceImages.describe_item(record,str(result.get("title","")))
		if NativeIcons.show_item(icon.player,icon.offset,info,hud()):pictures+=1
	return {"ok":true,"pictures":pictures}

static func _level_text(level: int) -> String:
	return "+%d" % level if level>0 else ""

## --- Flow ---------------------------------------------------------------------

func is_waiting() -> bool:
	return is_open() and _waiting

func is_revealed() -> bool:
	return is_open() and not _waiting

func is_held() -> bool:
	return is_open() and _held

## {waiting, revealed, held, clip}
func phase() -> Dictionary:
	var status: Dictionary=_scene.playback_status() if is_open() else {}
	return {"waiting":is_waiting(),"revealed":is_revealed(),"held":is_held(),"clip":str(status.get("clip",""))}

## One touch: prompt -> outcome, running outcome -> settled, settled -> close.
func advance_or_dismiss() -> void:
	if not is_open():return
	if _held:_close_requested()
	elif _waiting:_reveal()
	else:_hold()

func _reveal() -> void:
	_waiting=false
	_fill_rows()
	var amount: Dictionary=_locate(_scene,_out,P_SLOT+"/Text_Amount")
	if amount.get("ok",false):
		var text: String="" if str(result.get("outcome",""))=="destroy" else _level_text(int(result.get("to",0)))
		amount.player.set_bound_text(amount.offset,text if not text.is_empty() else " ")
	var fail: bool=str(result.get("kind",""))!="success"
	var effect: String="Fx_Enchant_Success"
	if fail:effect="Fx_Enchant_Vaporize" if str(result.get("outcome",""))=="destroy" else "Fx_Enchant_SideEffect"
	_play_project(P_FX,effect,false)
	_play_project(P_LOOP,"Fx_SideEffect_Loop" if fail else "Fx_Success_Loop",true)
	var banner_clip: String="Fail" if fail else "Success"
	var banner: Dictionary=_locate(_scene,_out,P_POPUP)
	if banner.get("ok",false):
		var projected: Dictionary=banner.player.project_player([banner.offset])
		if projected.get("ok",false) and projected.player.play(banner_clip,false).get("ok",false):
			_banner=projected.player
	var label: Dictionary=_locate(_scene,_out,P_POPUP+"/Set/EnChant_"+banner_clip+"/Text_Item")
	if label.get("ok",false):label.player.set_bound_text(label.offset,str(result.get("text","")))
	if _steady:
		_hold()
		return
	_queue=[SETTLED_LOOP]
	_scene.play(REVEAL,false)

## The outcome is settled: stat lines opaque, banner on its opaque key and
## the closing prompt loop running (reduced motion: its first frame).
func _hold() -> void:
	_waiting=false
	_queue=[]
	_settle(_scene,REVEAL)
	_hold_banner()
	if _steady:
		_settle(_scene,SETTLED_LOOP,false)
		_stop_checking()
	else:
		_scene.play(SETTLED_LOOP,true)
	_held=true

func _hold_banner() -> void:
	if _banner_held or not is_instance_valid(_banner):return
	_banner.seek_frame(float(BANNER_HOLD.get("Success" if str(result.get("kind",""))=="success" else "Fail")))
	_banner.stop()
	_banner_held=true

func _after_frame() -> void:
	if not is_open():
		_stop_checking()
		return
	if not _waiting and not _banner_held and is_instance_valid(_banner) and not _banner.playback_status().playing:_hold_banner()
	if _scene.playback_status().playing:return
	if _queue.is_empty():
		if not _waiting and not _held:_hold()
		return
	var next: String=_queue.pop_front()
	if next==SETTLED_LOOP:
		_hold()
		return
	_scene.play(next,next==WAIT_LOOP)

## The top-level node `name` of the mounted Enchant_Result (not a nested
## scene's node of the same name).
static func _top(root: Node2D, out: Dictionary, name: String) -> Dictionary:
	for key: String in out:
		var entry: Dictionary=out[key]
		if key.get_file()!=name or not (entry.chain as Array).is_empty() or key.count("/")!=1:continue
		var node: Variant=root.source_nodes.get(int(entry.offset))
		if node is Node2D:return {"ok":true,"node":node,"offset":int(entry.offset)}
	return {"ok":false,"error":"source_enchant_result_layer_missing"}

func _play_project(suffix: String, clip: String, repeat: bool) -> bool:
	var located: Dictionary=_top(_scene,_out,suffix)
	if not located.get("ok",false):return _problem(suffix,located)
	(located.node as Node2D).visible=true
	var projected: Dictionary=_scene.project_player([located.offset])
	if not projected.get("ok",false):return _problem(suffix,projected)
	var player: Variant=projected.player
	var played: Dictionary=player.play(clip,repeat)
	if not played.get("ok",false):return _problem(suffix,played)
	if _steady:
		var span: Dictionary=_clip_range(player,clip)
		if not span.is_empty():
			player.seek_frame(float(span.endIndex) if not repeat else float(span.startIndex))
			player.stop()
	return true

## Stat lines in Nd_TextSet: the authored TextSet line, then more of its
## own scene below it.
func _fill_rows() -> void:
	var source: Variant=result.get("rows")
	var rows: Array=source.call() if source is Callable and (source as Callable).is_valid() else (source if source is Array else [])
	rows=rows.slice(0,TEXT_LINES)
	var first: Dictionary=rows[0] if not rows.is_empty() else {}
	for pair: Array in [["Text_List_1","label"],["Text_List_1_0","now"],["Text_List_1_Value","next"]]:
		var located: Dictionary=_locate(_scene,_out,P_TEXT+"/"+str(pair[0]))
		if located.get("ok",false):located.player.set_bound_text(located.offset,_text_of(first,str(pair[1])))
	result["shown_rows"]=rows
	if rows.size()<=1:return
	var anchor: Dictionary=_locate(_scene,_out,P_TEXT)
	if not anchor.get("ok",false):return
	var row: Node2D=anchor.player.source_nodes.get(anchor.offset)
	if not is_instance_valid(row) or row.get_parent()==null:return
	for index: int in range(1,rows.size()):
		var line: Dictionary=rows[index]
		var spec: Dictionary={"Text_List_1":{"role":"source_text","text":_text_of(line,"label")},
			"Text_List_1_0":{"role":"source_text","text":_text_of(line,"now")},
			"Text_List_1_Value":{"role":"source_text","text":_text_of(line,"next")}}
		var built: Dictionary=_scene_of(TEXT_SET,spec,{})
		if not built.get("ok",false):return
		var scene: Node2D=built.scene
		scene.position=row.position+Vector2(0.0,TEXT_PITCH*float(index))
		row.get_parent().add_child(scene)

## Records why an outcome layer could not play (result.problems).
func _problem(suffix: String, why: Dictionary) -> bool:
	var problems: Array=result.get("problems",[])
	problems.append("%s:%s" % [suffix,str(why.get("error",why.get("code","")))])
	result["problems"]=problems
	return false

static func _text_of(row: Dictionary, key: String) -> String:
	var value: String=str(row.get(key,""))
	return value if not value.is_empty() else " "

static func _clip_range(player: Node, name: String) -> Dictionary:
	for clip: Dictionary in player.source_tree.get("animationList",[]):
		if clip.name==name:return clip
	return {}

## Enters the last (or, with `end` false, the first) authored frame of `name`.
static func _settle(player: Node, name: String, end: bool=true) -> void:
	var span: Dictionary=_clip_range(player,name)
	if span.is_empty():return
	player.seek_frame(float(span.endIndex if end else span.startIndex))
	player.stop()

func _touch(event: InputEvent, input: Control) -> void:
	if _pressed and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_drag+=absf(event.relative.y)
		input.accept_event()
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		input.accept_event()
		# Mouse clicks also arrive as emulated touches.
		if event is InputEventMouseButton:return
		if event.pressed:
			_pressed=true
			_drag=0.0
		elif _pressed:
			_pressed=false
			if _drag<8.0:advance_or_dismiss()

func _stop_checking() -> void:
	var tree: Variant=_tree_ref.get_ref() if _tree_ref!=null else null
	if is_instance_valid(tree) and tree.process_frame.is_connected(_after_frame):
		tree.process_frame.disconnect(_after_frame)
	_tree_ref=null

func close() -> void:
	_stop_checking()
	_banner=null
	super.close()

func _close_requested() -> Dictionary:
	close()
	finished.emit()
	return {"ok":true,"closed":true}
