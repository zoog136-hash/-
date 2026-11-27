extends SceneTree
## User request 2026-11-27 "각성·강화 결과 확인창은 '한 번 터치하세요'가 나온 뒤에
## 결과가 나오게 해": the original two-touch result flow.
##  - 강화 (단일·다중): the original 강화 결과 screen (Enchant_Result.csb) opens
##    on "결과 확인 / 화면을 터치하세요."; a touch reveals the committed
##    outcome (Fx_Enchant_Result, Enchant_Popup_Message banner, stat lines);
##    the next touch closes it. No timer closes it; no 강화 확인 dialog.
##  - 각성 (변신·인형·성물 옵션 각성, 스킬 각성: all present through
##    Change_Upgrade_Skill_Awaken.csb): Start / Fx_Loop with Panel_Touch
##    "화면을 터치해 주세요." first; a touch plays Fx_Touch_Active and the
##    committed branch; the next touch closes it.
## Always (no original files): both state machines on opaque player doubles,
## the enchant window's routing and the absence of timers.
## With an original UI pack (TWILIGHT_TAP_REVEAL_UI=<main_pack dir>, a pack
## with Enchant_Result such as ui46): actual Main, real enchant transactions
## (single and 다중) and the actual awakening result scene, by real touches.
##   godot --headless --path <repo> --script res://tests/enchant_awakening_tap_reveal_test.gd
const ENCHANT_WINDOW=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
const RESULT_SCREEN=preload("res://scripts/ui/original_ui/source_main_enchant_result_window.gd")
const AWAKEN=preload("res://scripts/ui/original_ui/source_main_awakening_result_window.gd")
const KIT=preload("res://scripts/ui/original_ui/source_main_window_kit.gd")
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={}

## An opaque stand-in for sprite_scene's playback surface.
class Clips extends Node2D:
	var source_tree: Dictionary={}
	var calls: Array[String]=[]
	var playing: bool=false
	var clip: String=""
	var frame: float=0.0
	var repeat: bool=false
	func _init(clips: Array) -> void:
		var list: Array=[]
		for entry: Array in clips:list.append({"name":entry[0],"startIndex":entry[1],"endIndex":entry[2]})
		source_tree={"animationList":list}
	func play(name: String, loop: bool=false) -> Dictionary:
		for entry: Dictionary in source_tree.animationList:
			if entry.name==name:
				clip=name
				repeat=loop
				playing=true
				frame=float(entry.startIndex)
				calls.append(name+("*" if loop else ""))
				return {"ok":true}
		return {"ok":false}
	func stop() -> void:
		playing=false
		calls.append("stop")
	func seek_frame(at: float) -> void:
		frame=at
		calls.append("seek:%d" % int(at))
	func playback_status() -> Dictionary:
		return {"playing":playing,"clip":clip,"frame":frame,"loop":repeat}
	## The running clip reaches its end (a repeating clip never ends).
	func finish() -> void:
		if not repeat:playing=false

class FakeScreen extends RefCounted:
	signal finished
	var opened: Array=[]
	var open_now: bool=false
	func configure(_pack: RefCounted, _hud: Node) -> Dictionary:return {"ok":true}
	func open(_parent: Node, data: Dictionary, _settings: Dictionary={}) -> Dictionary:
		opened.append(data)
		open_now=true
		return {"ok":true}
	func is_open() -> bool:return open_now
	func close() -> void:open_now=false

class FakeInventory extends RefCounted:
	var inventory: Dictionary={}
	func _find_item_record(_reference: String) -> Dictionary:return {}
	func _item_visual_record(_reference: String, fallback: Dictionary) -> Dictionary:return fallback

class ProofWindow extends "res://scripts/ui/original_ui/source_main_enchant_window.gd":
	var refreshes: int=0
	func _restage() -> Dictionary:
		refreshes+=1
		return {"ok":true,"handled":true}

class FakeHud extends Node:
	signal enhancement_requested(scroll_name: String, target_name: String)
	var lineage_inventory_ui: FakeInventory=FakeInventory.new()
	var asked: Array=[]
	func confirm_action(title: String, body: String, _action: String, _callback: Callable, _maximum: int=0) -> Control:
		asked.append([title,body])
		return null
	func show_message(_text: String) -> void:pass

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ENCHANT_AWAKENING_TAP_REVEAL_FAIL: ",label)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_awakening_flow(false)
	_awakening_flow(true)
	_screen_flow(false,"success")
	_screen_flow(false,"destroy")
	_screen_flow(true,"decrease")
	await _window_routing()
	_sources()
	var ui: String=OS.get_environment("TWILIGHT_TAP_REVEAL_UI")
	if not ui.is_empty():
		var saved: Dictionary={}
		_snapshot("user://",saved)
		await _actual(ui)
		_restore("user://",saved)
	else:
		evidence["actual"]="no original UI pack given: actual Main part skipped"
	print("ENCHANT_AWAKENING_TAP_REVEAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

## --- Always ----------------------------------------------------------------

const AWAKEN_CLIPS: Array=[["Start",5,50],["Fx_Loop",55,175],["Fx_Touch_Active",180,225],["Fx_Success_Active",230,315],["Fx_Success_Loop",320,480],["Fx_Fail_Active",540,614],["Fx_Fail_Loop",615,702]]

func _awakening_flow(steady: bool) -> void:
	var page=AWAKEN.new()
	var scene:=Clips.new(AWAKEN_CLIPS)
	root.add_child(scene)
	page._scene=scene
	page._succeeded=not steady
	page._steady=steady
	page._waiting=true
	page._held=false
	var tag: String="reduced motion " if steady else ""
	if steady:
		page._settle(AWAKEN.WAIT_LOOP)
		check(scene.frame==175.0 and not scene.playing,tag+"the touch prompt (Fx_Loop) is the first settled frame")
	else:
		scene.play(AWAKEN.WAIT_INTRO,false)
		page._queue.assign([AWAKEN.WAIT_LOOP])
		scene.finish()
		page._after_frame()
		check(scene.clip=="Fx_Loop" and scene.repeat,"after Start the touch prompt loop repeats")
		for i: int in range(500):page._after_frame()
		check(page._waiting and not page._held and scene.clip=="Fx_Loop","no outcome and no close without a touch")
	check(not scene.calls.any(func(c: String) -> bool: return c.begins_with("Fx_Success") or c.begins_with("Fx_Fail")),tag+"the outcome clips do not play before the touch: "+str(scene.calls))
	page.advance_or_dismiss()
	var branch: String="Fx_Success" if not steady else "Fx_Fail"
	if steady:
		check(page._held and scene.frame==702.0,tag+"one touch settles the outcome loop's last frame")
	else:
		check(scene.clip=="Fx_Touch_Active" and not page._held,"the touch plays Fx_Touch_Active first")
		scene.finish();page._after_frame()
		check(scene.clip==branch+"_Active","then the committed branch reveals")
		scene.finish();page._after_frame()
		check(scene.clip==branch+"_Loop","then its outcome loop")
		scene.finish();page._after_frame()
		check(page._held and scene.frame==480.0 and not scene.playing,"the outcome settles on its opaque last frame and stays")
	check(page.is_open(),tag+"the outcome stays until another touch")
	page.advance_or_dismiss()
	check(not page.is_open(),tag+"the second touch closes it")

const SCREEN_CLIPS: Array=[["Fx_Result_EndLoop",300,420],["Fx_Result_Start",5,25],["Fx_Result_EndText",95,125],["Fx_Result_StartLoop",26,90]]

func _screen_flow(steady: bool, outcome: String) -> void:
	var screen=RESULT_SCREEN.new()
	var scene:=Clips.new(SCREEN_CLIPS)
	root.add_child(scene)
	screen._scene=scene
	screen._steady=steady
	screen._waiting=true
	screen.result={"kind":"success" if outcome=="success" else "fail","outcome":outcome,"text":"t","from":3,"to":4}
	var closed: Dictionary={"n":0}
	screen.finished.connect(func() -> void: closed.n+=1)
	var tag: String=("reduced motion " if steady else "")+outcome+": "
	if not steady:
		scene.play(RESULT_SCREEN.WAIT_INTRO,false)
		screen._queue.assign([RESULT_SCREEN.WAIT_LOOP])
		scene.finish()
		screen._after_frame()
		check(scene.clip=="Fx_Result_StartLoop" and scene.repeat,tag+"결과 확인 / 화면을 터치하세요 loop after the entrance")
		for i: int in range(500):screen._after_frame()
		check(screen.is_waiting() and not screen.is_held(),tag+"it waits for the touch (no timer)")
	else:
		RESULT_SCREEN._settle(scene,RESULT_SCREEN.WAIT_LOOP)
		check(scene.frame==90.0,tag+"the prompt loop's settled frame")
	screen.advance_or_dismiss()
	check(screen.is_revealed(),tag+"one touch reveals")
	if not steady:
		check(scene.clip=="Fx_Result_EndText" and not screen.is_held(),tag+"the reveal plays Fx_Result_EndText")
		scene.finish();screen._after_frame()
	check(screen.is_held() and scene.clip==("Fx_Result_EndLoop" if not steady else scene.clip),tag+"the settled outcome waits with its closing prompt")
	for i: int in range(500):screen._after_frame()
	check(screen.is_open() and int(closed.n)==0,tag+"the outcome does not close by itself")
	screen.advance_or_dismiss()
	check(not screen.is_open() and int(closed.n)==1,tag+"the second touch closes it once")

## The enchant window hands every committed roll to the 강화 결과 screen
## (single: one outcome; 다중: one line per target) without a confirmation,
## blocks its own buttons meanwhile and ends when the screen closes.
func _window_routing() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window:=ProofWindow.new()
	var screen:=FakeScreen.new()
	window._hud=weakref(hud)
	window._parent=weakref(parent)
	window._scene=Node2D.new()
	parent.add_child(window._scene)
	window._screen=screen
	screen.finished.connect(window._screen_finished)
	window._scroll="갑옷 마법 주문서"
	window._candidates=[{"name":"판금 갑옷 · 원본#20","target_id":"a","level":4,"count":1,"stats_now":{"defense":7.0},"stats_next":{"defense":8.0}}]
	window._selected="a"
	check(window.present_result("success",4,5) and window.is_presenting(),"a committed roll opens the result screen")
	var data: Dictionary=screen.opened[0] if not screen.opened.is_empty() else {}
	check(str(data.get("outcome",""))=="success" and int(data.get("from",-1))==4 and int(data.get("to",-1))==5 and str(data.get("text",""))=="+5 강화 성공","the screen gets the committed outcome: "+str(data))
	check(not str(data.get("title","")).contains("원본#"),"no developer key in the screen title")
	window.update("갑옷 마법 주문서",[{"name":"판금 갑옷 · 원본#20","target_id":"a","level":5,"count":1,"stats_now":{"defense":8.0}}])
	var rows: Array=(data.get("rows") as Callable).call() if data.get("rows") is Callable else []
	check(rows.size()==2 and rows[0].next=="+5" and rows[1].label=="AC" and rows[1].now=="-7" and str(rows[1].next).begins_with("-8"),"stat lines are the saved before / after rows: "+str(rows))
	var blocker: Control=window._blocker
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	if is_instance_valid(blocker):blocker.gui_input.emit(touch)
	check(window.is_presenting(),"a touch under the screen does not end the result (the screen owns touches)")
	check(hud.asked.is_empty(),"no 강화 확인 dialog")
	screen.close()
	screen.finished.emit()
	check(not window.is_presenting() and window._pending_result_refresh.is_empty() and window.refreshes==1,"closing the screen ends the result and applies the refreshed rows once")
	# 다중 강화: one line per target.
	window._presentation={}
	window._candidates=[{"name":"장검","target_id":"x","level":2},{"name":"단검","target_id":"y","level":0}]
	var before: Array=[{"name":"장검","target_id":"x","level":0},{"name":"단검","target_id":"y","level":0},{"name":"활","target_id":"z","level":1}]
	var multi: Dictionary=window._multi_detail(hud,before,"fail")
	check((multi.rows as Array).size()==3 and multi.rows[0].next=="+2" and multi.rows[2].next=="소실" and str(multi.outcome)=="maintain","다중 강화 lists each target's start and result: "+str(multi.rows))
	check(window.present("fail","다중 강화 중단",multi) and screen.opened.size()==2 and screen.opened[1].get("multi",false),"다중 강화 opens the same result screen")
	window.end_presentation()
	check(not screen.is_open(),"ending the result closes the screen")
	# A pack without the screen keeps the earlier in-window result.
	window._screen=null
	window._presents=false
	check(not window.present("success","x") and not window.is_presenting(),"no screen and no in-window members: the HUD fallback is used")
	window._scene.queue_free()
	parent.queue_free()
	hud.queue_free()
	await process_frame

func _sources() -> void:
	for path: String in ["res://scripts/ui/original_ui/source_main_enchant_result_window.gd","res://scripts/ui/original_ui/source_main_awakening_result_window.gd"]:
		var text: String=FileAccess.get_file_as_string(path)
		check(not text.contains("create_timer") and not text.contains("confirm_action"),"no timer or confirmation in "+path.get_file())
	check(RESULT_SCREEN.new().required_members().has("UI/FloatingUi/Enchant_Result.csb"),"the screen needs the original Enchant_Result scene")

## --- Actual Main with an original UI pack --------------------------------------

func _frames(n: int) -> void:
	for i: int in range(n):await process_frame

func _tap(at: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=0
		event.position=at
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

## [text, shown] of the original text node at `suffix` in a kit window.
func _text(window: RefCounted, suffix: String) -> Array:
	var located: Dictionary=KIT._locate(window._scene,window._out,suffix)
	if not located.get("ok",false):return ["",false]
	var node: Node2D=located.player.source_nodes.get(located.offset)
	if not is_instance_valid(node):return ["",false]
	var owner: Variant=node.get_meta("source_text") if node.has_meta("source_text") else null
	var text: String=""
	if owner is Object and owner.get("source_lines")!=null:text="\n".join(owner.get("source_lines"))
	elif owner is Object and owner.get("_options") is Dictionary:text=str(owner.get("_options").get("text",""))
	var color: Color=node.get_meta("source_display_color",Color.WHITE)
	return [text.strip_edges(),node.is_visible_in_tree() and color.a>0.5]

func _shown(window: RefCounted, suffix: String) -> bool:
	var located: Dictionary=KIT._locate(window._scene,window._out,suffix)
	if not located.get("ok",false):return false
	var node: Node2D=located.player.source_nodes.get(located.offset)
	return is_instance_valid(node) and node.is_visible_in_tree() and node.get_meta("source_display_color",Color.WHITE).a>0.05

func _confirmations(hud: Node) -> int:
	var count: int=0
	for node: Node in hud.find_children("TwilightConfirmation","",true,false):
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():count+=1
	return count

func _actual(ui: String) -> void:
	var pack=load("res://scripts/ui/original_ui/source_pack.gd").new()
	var opened: Dictionary=pack.open(ui,FileAccess.get_sha256(ui.path_join("original_ui.json")))
	if not check(opened.get("ok",false),"the original UI pack opens: "+str(opened.get("error",""))):return
	if not check(pack.manifest.scenes.has(RESULT_SCREEN.ROOT),"the pack has Enchant_Result"):return
	root.size=Vector2i(1600,900)
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer=-100000
	if not check(preload("res://tests/qa_class_selection.gd").enter_game(world),"actual Main class entry"):
		world.queue_free()
		return
	var hud: Node=world.hud
	var controller: Node=load("res://scripts/ui/original_ui/source_main_hud.gd").new()
	hud.add_child(controller)
	controller._pack=pack
	controller._hud=weakref(hud)
	controller._coordinates=Node2D.new()
	hud.get_node("Root").add_child(controller._coordinates)
	hud.original_main_ui_controller=controller
	world.presentation_settings["reduced_motion"]=false
	world.presentation_settings["impact_intensity"]=1.0
	await _enchant(world,hud,controller)
	await _awakening(world,hud,controller,true)
	await _awakening(world,hud,controller,false)
	world.source_save_blocked=true
	world.queue_free()
	await _frames(3)

func _enchant(world: Node, hud: Node, controller: Node) -> void:
	var scroll:="무기 마법 주문서 (각인)"
	var item:="낡은 장검"
	world.inventory={item:2,scroll:30}
	world.item_instances={}
	world.enhancement_levels={}
	world.equipped_items={}
	world.gold=10000000
	world._sync_item_instances()
	world._update_hud()
	world._on_inventory_item_activated(scroll)
	await _frames(4)
	var window: Variant=controller.enchant_window()
	if not check(window!=null and controller.enchant_window_is_open() and window.result_screen()!=null,"the enchant window opens with the original result screen: "+str(hud.original_main_ui_status.get("enchant_window",{}))):return
	var screen: RefCounted=window.result_screen()
	var chosen: String=window.selected()
	var id: String=str(world._parse_enhancement_target(chosen).get("id",""))
	var level_before: int=int(world.item_instances.get(id,{}).get("level",0))
	var scrolls: int=int(world.inventory.get(scroll,0))
	# 강 화 시 작 by a real touch.
	var start: Dictionary=preload("res://scripts/ui/original_ui/source_main_named_tree.gd").locate(window._scene,window._last_out,"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant")
	var button: Variant=start.player.source_nodes.get(start.offset).get_meta("source_button") if start.get("ok",false) else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if not check(area is Control,"강 화 시 작 is touchable"):return
	await _tap(_center(area))
	await _frames(4)
	check(_confirmations(hud)==0,"강 화 시 작 opens no confirmation")
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(world.inventory.get(scroll,0))==scrolls-1 and saved is Dictionary and int(saved.inventory.get(scroll,0))==scrolls-1,"the roll is committed and saved before the result shows")
	var level_after: int=int(world.item_instances.get(id,{}).get("level",-1))
	if not check(screen.is_open() and screen.is_waiting(),"the 강화 결과 screen opens on its touch prompt: "+window.presentation_problem()+" "+str(screen.last_result)):return
	await _frames(40)
	var confirm: Array=_text(screen,"Fx_Seet_Loop/Label_Confilm")
	var prompt: Array=_text(screen,"Fx_Seet_Loop/Label_TouchScreen_B")
	check(confirm[0]=="결과 확인" and confirm[1],"결과 확인 is shown: "+str(confirm))
	check(prompt[0]=="화면을 터치하세요.","the original prompt 화면을 터치하세요.: "+str(prompt))
	var kind: String="Success" if level_after>level_before else "Fail"
	var banner: Array=_text(screen,"Enchant_Popup_Message/Set/EnChant_"+kind+"/Text_Item")
	check(not banner[1] and not _shown(screen,"Fx_Enchant_Result") and not _shown(screen,"Nd_TextSet/ScrollView/TextSet/Text_List_1"),"the outcome is not on screen before the touch: "+str(banner))
	await _frames(240)
	check(screen.is_waiting() and window.is_presenting(),"it keeps waiting (no timer)")
	var input: Control=screen._scene.get_node("EnchantResultScreenTouch")
	await _tap(_center(input))
	check(screen.is_revealed(),"a touch reveals the outcome")
	for i: int in range(240):
		if screen.is_held():break
		await process_frame
	await _frames(30)
	banner=_text(screen,"Enchant_Popup_Message/Set/EnChant_"+kind+"/Text_Item")
	var line: Array=_text(screen,"Nd_TextSet/ScrollView/TextSet/Text_List_1_Value")
	var closing: Array=_text(screen,"Label_TouchScreen")
	check(screen.is_held() and banner[1] and not str(banner[0]).is_empty() and not str(banner[0]).contains("원본#"),"the committed outcome banner shows: "+str(banner))
	check(screen.result.get("problems",[]).is_empty() and _shown(screen,"Fx_Enchant_Result"),"the original outcome effect plays: "+str(screen.result.get("problems",[])))
	check(line[1] and str(line[0])==("+%d" % level_after if level_after>0 else "+0"),"the stat line shows the saved level: "+str(line)+" level %d->%d" % [level_before,level_after])
	check(closing[0]=="화면을 터치하세요.","the closing prompt is the original text: "+str(closing))
	evidence["single"]={"level":[level_before,level_after],"banner":banner[0],"rows":screen.result.get("shown_rows",[]).size()}
	await _frames(240)
	check(screen.is_open() and window.is_presenting(),"the outcome stays (no auto close)")
	var rng: int=world.rng.state
	await _tap(_center(input))
	await _frames(4)
	check(not screen.is_open() and not window.is_presenting() and world.rng.state==rng,"the second touch closes it without another roll")
	# 다중 강화 by touches.
	var NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
	for suffix: String in ["Tab/Nd_Multi/Btn_Multi_Off","ScrollView_Item/Inventory_Slot_Set/Nd_Slot/Slot_1/Btn","ScrollView_Item/Inventory_Slot_Set/Nd_Slot/Slot_2/Btn"]:
		var hit: Dictionary=NamedTree.locate(window._scene,window._last_out,suffix)
		var b: Variant=hit.player.source_nodes.get(hit.offset).get_meta("source_button") if hit.get("ok",false) else null
		if not check(is_instance_valid(b),"다중 강화 control "+suffix):return
		await _tap(_center(b.get("_input_area")))
		await _frames(4)
	var goal: int=0
	for entry: Dictionary in window._candidates:goal=maxi(goal,int(entry.get("level",0)))
	goal=mini(goal+1,10)
	var g: Dictionary=NamedTree.locate(window._scene,window._last_out,"Nd_Progress/Nd_Btn_%02d/Btn_Off" % goal)
	var gb: Variant=g.player.source_nodes.get(g.offset).get_meta("source_button") if g.get("ok",false) else null
	if is_instance_valid(gb):
		await _tap(_center(gb.get("_input_area")))
		await _frames(4)
	if not check(window.multi and window.picked().size()==2 and window.goal()==goal,"다중 강화 targets and goal by touch"):return
	start=NamedTree.locate(window._scene,window._last_out,"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant")
	button=start.player.source_nodes.get(start.offset).get_meta("source_button") if start.get("ok",false) else null
	scrolls=int(world.inventory.get(scroll,0))
	await _tap(_center(button.get("_input_area")))
	await _frames(6)
	check(_confirmations(hud)==0 and int(world.inventory.get(scroll,0))<scrolls,"다중 강화 시작 rolls at once")
	check(screen.is_open() and screen.is_waiting() and screen.result.get("multi",false),"다중 강화 opens the same screen on its touch prompt")
	await _frames(120)
	check(screen.is_waiting(),"다중 강화 result waits for the touch")
	input=screen._scene.get_node("EnchantResultScreenTouch")
	await _tap(_center(input))
	for i: int in range(240):
		if screen.is_held():break
		await process_frame
	var rows: Array=screen.result.get("shown_rows",[])
	check(rows.size()==2 and _text(screen,"Nd_TextSet/ScrollView/TextSet/Text_List_1")[1],"one line per 다중 강화 target: "+str(rows))
	evidence["multi"]={"rows":rows,"text":screen.result.get("text","")}
	await _tap(_center(input))
	await _frames(4)
	check(not screen.is_open() and not window.is_presenting(),"the second touch closes the 다중 강화 result")
	controller.close_enchant_window()
	await _frames(2)

func _awakening(world: Node, hud: Node, controller: Node, success: bool) -> void:
	var card: Dictionary={"name":"데스나이트","grade":"영웅","category":"변신"}
	var outcome: Dictionary={"ok":true,"success":success,"skill_name":"데스나이트" if not success else "헬파이어 · Lv.1","bonus_lines":["변신 각성 옵션 1"] if success else []}
	var tag: String=("성공 " if success else "실패 ")
	if not check(hud.present_source_awakening_result(card,outcome,world.presentation_settings),tag+"the original awakening result scene opens: "+str(hud.original_main_ui_status.get("awakening_result_window",{}))):return
	var page: RefCounted=controller.feature_window("awakening_result")
	await _frames(60)
	var prompt: Array=_text(page,"Panel_Touch/Label")
	var branch: String="Success" if success else "Fail"
	check(page.phase().waiting and prompt[0]=="화면을 터치해 주세요." and prompt[1],tag+"the original prompt 화면을 터치해 주세요. comes first: "+str(prompt)+" "+str(page.phase()))
	check(not _text(page,branch+"_Text")[1] and not _shown(page,"ListView"),tag+"no outcome text or options before the touch")
	check(not success or _text(page,"Nd_Card/Label_Skill")[0]=="데스나이트",tag+"the card shows the target before the touch")
	await _frames(240)
	check(page.is_open() and page.phase().waiting,tag+"it keeps waiting (no timer)")
	var input: Control=page._scene.get_node("AwakeningResultTouch")
	await _tap(_center(input))
	check(page.phase().revealed and page.phase().clip=="Fx_Touch_Active",tag+"a touch plays Fx_Touch_Active: "+str(page.phase()))
	for i: int in range(600):
		if page._held:break
		await process_frame
	var text: Array=_text(page,branch+"_Text")
	check(page._held and text[1] and text[0]==("각성에 성공 하였습니다." if success else "각성에 실패 하였습니다."),tag+"the outcome text settles: "+str(text))
	check(not success or _text(page,"Nd_Card/Label_Skill")[0]=="헬파이어 · Lv.1",tag+"the new skill shows after the touch")
	await _frames(120)
	check(page.is_open(),tag+"the outcome stays (no auto close)")
	await _tap(_center(input))
	await _frames(3)
	check(not page.is_open(),tag+"the second touch closes it")
	evidence["awakening_"+branch]=true

## user:// as it was: later suites in the same run read the saved character.
static func _snapshot(dir: String, into: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(dir):into[dir.path_join(file)]=FileAccess.get_file_as_bytes(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):_snapshot(dir.path_join(sub),into)

static func _restore(dir: String, saved: Dictionary) -> void:
	var now: Dictionary={}
	_snapshot(dir,now)
	for path: String in now:
		if not saved.has(path):DirAccess.remove_absolute(path)
	for path: String in saved:
		if not now.has(path) or now[path]!=saved[path]:
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file!=null:
				file.store_buffer(saved[path])
				file.close()
