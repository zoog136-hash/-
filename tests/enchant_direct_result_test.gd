extends SceneTree
## 장비 강화: 강화 시작 rolls at once and the result plays in the original
## window (user report 2026-11-22 "원본 연출 유지하고 강화 확인창 없애", the
## result texts were drawn over the window's own texts, with "원본#2802").
## Always (synthetic, no original files):
##  - the original window's 강화 시작 (single and 다중) asks nothing: no
##    confirm_action, the request / series starts at once;
##  - the TWILIGHT forge's 강화 uses the same direct request;
##  - with the original window open the HUD hands the result to the window
##    (no full-screen TWILIGHT layer over it); is_enhancement_presenting
##    follows the window;
##  - the fallback reveal has no 연출 건너뛰기 / 확인 step: a tap skips, the
##    next closes, and it closes by itself after settling;
##  - no " · 원본#N" in the window title, the reveal or a confirmation body.
## With the real 523 pack and original UI (--source523-pack): actual Main and
## real touches on 강화 시작 (단일 and 다중): no confirmation, the roll is
## committed, Fx_Enchant_Start / Enchant_Popup_Message play, no window text
## is visible under the result banner, no TWILIGHT reveal layer, no 원본#
## in the window's texts, and the result ends by a tap or by itself.
##   godot --headless --path <repo> --script res://tests/enchant_direct_result_test.gd [-- --source523-pack=<pack>]
const WINDOW=preload("res://scripts/ui/original_ui/source_main_enchant_window.gd")
const FORGE=preload("res://scripts/ui/renewal_forge.gd")
const REVEAL=preload("res://scripts/ui/enhancement_reveal.gd")
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={}

class FakeWorld extends Node:
	var series: Array=[]
	func attempt_enhancement_series(scroll: String, targets: Array, goal: int) -> Dictionary:
		series.append([scroll,targets.duplicate(),goal])
		return {"ok":true,"rolls":2,"reached":1,"stop":""}

class FakeHud extends Node:
	signal enhancement_requested(scroll_name: String, target_name: String)
	var asked: Array=[]
	var shown: Array[String]=[]
	func confirm_action(title: String, body: String, _action: String, _callback: Callable, _maximum: int=0) -> Control:
		asked.append([title,body])
		return null
	func show_message(text: String) -> void:shown.append(text)

class FakeWindow extends RefCounted:
	var presented: Array=[]
	var presenting: bool=false
	func present_result(result: String, from_level: int, to_level: int) -> bool:
		presented.append([result,from_level,to_level])
		presenting=true
		return true
	func is_presenting() -> bool:return presenting

class FakeController extends Node:
	var window: FakeWindow=FakeWindow.new()
	func enchant_window_is_open() -> bool:return true
	func enchant_window() -> RefCounted:return window

class RoutingHud extends "res://scripts/ui/renewal_hud.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _sync_screen_focus() -> void:pass

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ENCHANT_DIRECT_RESULT_FAIL: ",label)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_direct_single()
	_direct_multi()
	_forge_direct()
	await _hud_routing()
	await _fallback_reveal()
	_texts()
	var pack: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-pack="):pack=arg.trim_prefix("--source523-pack=")
	if not pack.is_empty():
		var saved: Dictionary={}
		_snapshot("user://",saved)
		await _real_main()
		_restore("user://",saved)
	print("ENCHANT_DIRECT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func _window(hud: Node) -> RefCounted:
	var window=WINDOW.new()
	window._hud=weakref(hud)
	window._scroll="갑옷 마법 주문서 (각인)"
	window._candidates=[{"name":"암령의 장갑 (각인) · 원본#2802","target_id":"암령의 장갑 (각인) · 원본#2802@@@a","level":0,"count":1},{"name":"암령의 장갑 (각인) · 원본#2802","target_id":"암령의 장갑 (각인) · 원본#2802@@@b","level":2,"count":1}]
	window._selected="암령의 장갑 (각인) · 원본#2802@@@a"
	return window

func _direct_single() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var emitted: Array=[]
	hud.enhancement_requested.connect(func(scroll: String, target: String) -> void: emitted.append([scroll,target]))
	var window=_window(hud)
	var result: Dictionary=window._enchant_requested()
	check(result.get("ok",false) and hud.asked.is_empty(),"단일 강화 시작 asks nothing (no 강화 확인): "+str(hud.asked))
	check(emitted==[["갑옷 마법 주문서 (각인)","암령의 장갑 (각인) · 원본#2802@@@a"]],"단일 강화 시작 requests the roll at once")
	hud.free()

func _direct_multi() -> void:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var window=_window(hud)
	window.multi=true
	window._toggle_pick("암령의 장갑 (각인) · 원본#2802@@@a")
	window._set_goal(3)
	var result: Dictionary=window._enchant_requested()
	check(hud.asked.is_empty(),"다중 강화 시작 asks nothing (no 다중 강화 확인)")
	check(world.series.size()==1 and int(world.series[0][2])==3 and (world.series[0][1] as Array).size()==1 and str(result.get("started",""))=="multi","다중 강화 시작 starts the series at once: "+str(world.series))
	var spec: Dictionary={}
	window._multi_spec(hud,spec)
	check(spec.get(WINDOW.P_ALL+"Nd_Enchant_Multi",{}).get("visible",false),"the authored-hidden 다중 강화 page is shown on its tab")
	world.free()

func _forge_direct() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var emitted: Array=[]
	hud.enhancement_requested.connect(func(scroll: String, target: String) -> void: emitted.append([scroll,target]))
	check(FORGE.request_target(hud,"무기 마법 주문서",{"target_id":"장검@@@x","name":"장검"}) and emitted.size()==1 and hud.asked.is_empty(),"the TWILIGHT forge's 강화 requests at once too")
	check(not FORGE.request_target(hud,"무기 마법 주문서",{}) and emitted.size()==1,"no target: no request")
	var forge_script: Script=load("res://scripts/ui/renewal_forge.gd")
	check(forge_script.get_script_method_list().all(func(m: Dictionary) -> bool: return str(m.name)!="confirm_target"),"the 강화 확인 step is gone")
	hud.free()

func _hud_routing() -> void:
	var instance: Node=preload("res://scenes/ui/HUD.tscn").instantiate()
	instance.set_script(RoutingHud)
	var hud: RoutingHud=instance as RoutingHud
	root.add_child(hud)
	var controller:=FakeController.new()
	hud.add_child(controller)
	hud.original_main_ui_controller=controller
	hud.show_enhancement_result("success","암령의 장갑 (각인) · 원본#2802",0,1)
	check(controller.window.presented==[["success",0,1]],"over the original window the result goes to the window's own presentation")
	check(not is_instance_valid(hud.enhancement_reveal) and hud.find_child("EnhancementRevealLayer",true,false)==null,"no full-screen TWILIGHT layer is put over the original window")
	check(hud.is_enhancement_presenting(),"the HUD reports the window's presentation (no second roll meanwhile)")
	controller.window.presenting=false
	check(not hud.is_enhancement_presenting(),"the presentation ends with the window's")
	var dialog: Control=hud.confirm_action("축복 부여 확인","암령의 장갑 (각인) · 원본#2802 +1\n장검@@@abc12","확인",func(_n: int) -> void: pass)
	var texts: String=""
	for label: Node in dialog.find_children("*","Label",true,false):texts+=(label as Label).text+"\n"
	check(not texts.contains("원본#") and not texts.contains("@@@") and texts.contains("암령의 장갑 (각인) +1"),"a confirmation never shows internal item keys: "+texts.strip_edges())
	hud.original_main_ui_controller=null
	hud.free()
	await process_frame

func _fallback_reveal() -> void:
	var stage: Control=REVEAL.new()
	stage.silent=true
	root.add_child(stage)
	stage.set_process(false)
	stage.present("success","암령의 장갑 (각인) · 원본#2802",0,1,null)
	var shown: String=""
	for node: Node in stage.find_children("*","",true,false):
		check(not node is BaseButton,"the fallback reveal has no button: "+str(node.name))
		if node is Label:shown+=(node as Label).text+"\n"
	check(not shown.contains("원본#") and not shown.contains("연출 건너뛰기"),"the fallback reveal shows the player's item name only")
	var closed: Dictionary={"n":0}
	stage.finished.connect(func() -> void: closed.n+=1)
	stage._process(REVEAL.SETTLE_AT+0.01)
	check(stage.revealed and int(closed.n)==0,"the result shows after the charge")
	stage._process(REVEAL.HOLD_SECONDS+0.01)
	check(int(closed.n)==1,"it closes by itself (no 확인 step)")
	await process_frame
	var tapped: Control=REVEAL.new()
	tapped.silent=true
	root.add_child(tapped)
	tapped.set_process(false)
	tapped.present("destroy","장검",9,0,null)
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	tapped._gui_input(touch)
	check(tapped.revealed and not tapped.closed and tapped.result=="destroy","a tap skips to the committed result")
	tapped._gui_input(touch)
	check(tapped.closed,"the next tap closes it")
	await process_frame

func _texts() -> void:
	var title: String=WINDOW._title({"name":"암령의 장갑 (각인) · 원본#2802","level":1})
	check(title=="+1 암령의 장갑 (각인)을 강화 하시겠습니까?","the window title has no 원본# and 장갑 takes 을: "+title)
	check(WINDOW.result_text("success",0,1)=="+1 강화 성공" and WINDOW.result_text("destroy",9,0).contains("소실") and WINDOW.result_text("decrease",7,6).contains("+7 → +6"),"result banner texts")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_enchant_window.gd")
	check(not source.contains("confirm_action") and not source.contains("confirm_target"),"the enchant window never asks for a confirmation")
	check(not WINDOW.OTHER_PAGES.has("Fx_Enchant_Start") and not WINDOW.OTHER_PAGES.has("Enchant_Popup_Message"),"the original result members are mounted (not kept out)")

## --- Real Main ----------------------------------------------------------------

func _frames(n: int) -> void:
	for i: int in range(n):await process_frame

func _touch(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=0
		event.position=point
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func _point(window: RefCounted, suffix: String) -> Vector2:
	var located: Dictionary=NamedTree.locate(window._scene,window._last_out,suffix)
	if not located.get("ok",false):return Vector2.INF
	var node: Variant=located.player.source_nodes.get(located.offset)
	var button: Variant=node.get_meta("source_button") if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if not area is Control:return Vector2.INF
	return (area as Control).get_global_transform_with_canvas()*((area as Control).size*0.5)

func _confirmations(hud: Node) -> int:
	var count: int=0
	for node: Node in hud.find_children("TwilightConfirmation","",true,false):
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():count+=1
	return count

## Visible source texts of the window: [text, canvas point, inside popup].
func _window_texts(window: RefCounted) -> Array:
	var found: Array=[]
	var popup: Variant=NamedTree.locate(window._scene,window._last_out,WINDOW.P_POPUP)
	var popup_node: Variant=popup.player.source_nodes.get(popup.offset) if popup.get("ok",false) else null
	for node: Node in window._scene.find_children("*","Node2D",true,false):
		if not (node.has_meta("source_text") or node.has_meta("source_bitmap_text")) or not (node as CanvasItem).is_visible_in_tree():continue
		if (node as CanvasItem).modulate.a<=0.01 or (node as CanvasItem).self_modulate.a<=0.01:continue
		var owner: Variant=node.get_meta("source_text") if node.has_meta("source_text") else node.get_meta("source_bitmap_text")
		var text: String=""
		if owner is Object and owner.get("source_lines")!=null:text="\n".join(owner.get("source_lines"))
		elif owner is Object and owner.get("_options") is Dictionary:text=str(owner.get("_options").get("text",""))
		var inside: bool=popup_node is Node and (popup_node as Node).is_ancestor_of(node)
		found.append([text,(node as Node2D).get_global_transform_with_canvas().origin,inside])
	return found

func _banner_rect(window: RefCounted) -> Rect2:
	var located: Dictionary=NamedTree.locate(window._scene,window._last_out,WINDOW.P_POPUP+"/Set/EnChant_Success/Img_Title_BG")
	if not located.get("ok",false):return Rect2()
	var node: Node2D=located.player.source_nodes.get(located.offset)
	var center: Vector2=node.get_global_transform_with_canvas().origin
	var scale: Vector2=window._scene.get_global_transform_with_canvas().get_scale()
	var extent: Vector2=Vector2(339.0,64.0)*scale
	return Rect2(center-extent*0.5,extent)

func _real_main() -> void:
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await _frames(60)
	preload("res://tests/qa_class_selection.gd").enter_game(world)
	for i: int in range(600):
		await process_frame
		if world.current523_aden_source_active():break
	var hud: Node=world.hud
	var ctl: Variant=hud.get("original_main_ui_controller")
	if not world.current523_aden_source_active() or not is_instance_valid(ctl) or not ctl.has_method("try_open_enchant_window"):
		evidence["real_main"]="original 523 map / original UI pack not installed: Main part skipped"
		world.queue_free()
		await _frames(3)
		return
	world.save_timer=-100000
	world.gold=10000000
	var record: Dictionary=world.patch523_equipment.record("2802").duplicate(true)
	if not check(not record.is_empty(),"original equipment 2802 (암령의 장갑)"):
		world.queue_free()
		return
	record["bless_state"]="normal"
	if record.get("source_m_native_item",false):record["source_bless_raw"]=1
	world.inventory[str(record.name)]=2
	for id: String in ["90001","90002"]:
		world.item_instances[id]={"name":record.name,"record":record.duplicate(true),"level":0,"element":"","element_level":0,"bless_state":"normal","source_bless_code":1}
	world.next_item_instance_id=90003
	var scroll: String="갑옷 마법 주문서 (각인)"
	world.inventory[scroll]=20
	world._sync_item_instances()
	world._update_hud()
	world._on_inventory_item_activated(scroll)
	await _frames(20)
	var window: RefCounted=ctl.enchant_window()
	if not check(window!=null and ctl.enchant_window_is_open() and window.presents(),"the original window opens with its result members"):
		world.queue_free()
		return
	var level_before: int=int(world.item_instances["90001"].get("level",0))
	var scrolls_before: int=int(world.inventory.get(scroll,0))
	await _touch(_point(window,"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant"))
	await _frames(6)
	check(_confirmations(hud)==0,"a touch on 강화 시작 opens no confirmation")
	check(int(world.inventory.get(scroll,0))==scrolls_before-1,"the touch rolls at once (one scroll used)")
	evidence["single"]={"level":[level_before,int(world.item_instances.get("90001",{}).get("level",-1))],"played":window._presentation.get("played",[])}
	check(window.is_presenting() and hud.is_enhancement_presenting(),"the result plays in the window")
	check((window._presentation.get("played",[]) as Array).has("Fx_Enchant_Start") and (window._presentation.get("played",[]) as Array).size()==2,"Fx_Enchant_Start and the Enchant_Popup_Message clip play")
	check(not is_instance_valid(hud.enhancement_reveal) and hud.find_child("EnhancementRevealLayer",true,false)==null,"no TWILIGHT result layer over the window")
	await _frames(14)
	var banner: Rect2=_banner_rect(window)
	var under: Array=[]
	var dev: Array=[]
	for entry: Array in _window_texts(window):
		if str(entry[0]).contains("원본#") or str(entry[0]).contains("@@@"):dev.append(entry[0])
		if not bool(entry[2]) and not str(entry[0]).strip_edges().is_empty() and banner.has_point(entry[1]):under.append(entry[0])
	evidence["banner"]=str(banner)
	check(banner.size.x>0.0 and under.is_empty(),"no window text is visible under the result banner: "+str(under))
	check(dev.is_empty(),"no developer item key in the window: "+str(dev))
	await _frames(30)
	for i: int in range(240):
		if not window.is_presenting():break
		await process_frame
	check(not window.is_presenting(),"the result ends by itself")
	var tab: Dictionary=NamedTree.locate(window._scene,window._last_out,WINDOW.P_TAB)
	check(tab.get("ok",false) and (tab.player.source_nodes.get(tab.offset) as CanvasItem).visible,"the tab row is back after the result")
	scrolls_before=int(world.inventory.get(scroll,0))
	await _touch(_point(window,"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant"))
	await _frames(4)
	check(window.is_presenting() and int(world.inventory.get(scroll,0))==scrolls_before-1,"a second 강화 시작 rolls at once")
	var button: Vector2=_point(window,"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant")
	await _touch(button)
	await _frames(4)
	check(not window.is_presenting() and int(world.inventory.get(scroll,0))==scrolls_before-1,"a tap during the result ends it and starts no roll")
	# 다중 강화 by touch: tab, two targets, goal +3, 강화 시작.
	await _touch(_point(window,"Tab/Nd_Multi/Btn_Multi_Off"))
	await _frames(8)
	for slot: String in ["Slot_1","Slot_2"]:
		await _touch(_point(window,"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/%s/Btn" % slot))
		await _frames(6)
	var goal: int=maxi(int(world.item_instances["90001"].get("level",0)),0)+1
	await _touch(_point(window,"Nd_Progress/Nd_Btn_%02d/Btn_Off" % goal))
	await _frames(6)
	check(window.multi and window.picked().size()==2 and window.goal()==goal,"다중 강화 picks and goal by touch: %s %d" % [str(window.picked()),window.goal()])
	scrolls_before=int(world.inventory.get(scroll,0))
	await _touch(_point(window,"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant"))
	await _frames(6)
	check(_confirmations(hud)==0 and int(world.inventory.get(scroll,0))<scrolls_before,"다중 강화 시작 rolls at once without a confirmation")
	check(window.is_presenting() and not is_instance_valid(hud.enhancement_reveal),"the 다중 강화 result plays in the window")
	evidence["multi"]={"levels":[world.item_instances.get("90001",{}).get("level"),world.item_instances.get("90002",{}).get("level")],"text":window._presentation.get("text","")}
	window.end_presentation()
	ctl.close_enchant_window()
	world.queue_free()
	await _frames(4)

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
