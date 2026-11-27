extends SceneTree
## The original 523 문양 window (source_main_symbol_window.gd) over the
## existing world.growth runtime. Without arguments (no original files): the
## seven gods match the growth emblems, every action goes quote ->
## HUD confirmation -> execute, a refused quote only shows its message, and
## the HUD opens the window first for 문양. Real input: -- --pack=<private
## original main UI pack directory>: Symbol_All mounts with the selected
## god's parts, odds, attempts and option rows.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_symbol_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE523=preload("res://scripts/growth/symbol_source523.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeGrowth extends RefCounted:
	var config: Dictionary={"emblems":[]}
	var state: Dictionary={"points":1234,"emblems":{}}
	var rerolls: Dictionary={"x":1}
	var source523=SOURCE523.new()
	var executed: Array=[]
	var refuse: Dictionary={}
	func _init() -> void:
		for id: String in ["eva","paagrio","maphr","sayha","grankain","einhasad","shilen"]:config.emblems.append({"id":id,"name":id})
	func progress(id: String) -> Dictionary:
		return state.emblems.get(id,{"stage":0,"attempts":0,"spent":0}).duplicate(true)
	func probabilities(_id: String) -> Array:
		return [62.5,33.0,4.5]
	func symbol_stage_limit() -> int:
		return 30
	func quote(action: String, id: String="", count: int=1) -> Dictionary:
		if refuse.has(action):return {"ok":false,"message":str(refuse[action])}
		return {"ok":true,"message":"%s %s %d" % [action,id,count],"points":100*count,"revision":7}
	func execute(action: String, id: String, count: int, revision: int, day: int=-1) -> Dictionary:
		executed.append([action,id,count,revision,day])
		return {"ok":true,"message":"done"}

class FakeWorld extends Node:
	var growth: RefCounted

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmations: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	world.growth=FakeGrowth.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	var config: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/lineage_growth.json"))
	var ids: Array=[]
	for row: Dictionary in config.get("emblems",[]):ids.append(str(row.id))
	check(ids.size()==7 and ids.all(func(id: String) -> bool: return WINDOW.GODS.has(id)),"the seven original gods match the growth emblems: "+str(ids))
	var host: Dictionary=_host()
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	var growth: FakeGrowth=host.world.growth
	var asked: Dictionary=window._ask("enhance","eva",5)
	check(asked.get("ok",false) and host.hud.confirmations.size()==1 and growth.executed==[["enhance","eva",5,7,-1]],"an action confirms and executes through world.growth: "+str(growth.executed))
	growth.refuse={"reroll":"확률 변경 불가"}
	asked=window._ask("reroll","eva",1)
	check(not asked.get("ok",true) and host.hud.messages.has("확률 변경 불가") and growth.executed.size()==1,"a refused quote only shows its message")
	window.selected="eva"
	window._select("einhasad")
	check(window.selected=="einhasad" and growth.rerolls.is_empty(),"changing the god restores base odds (rerolls cleared)")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_feature(\"emblems\")"),"문양 opens the original window first")
	var feature_paths: Dictionary=preload("res://scripts/ui/original_ui/source_main_hud.gd").FEATURE_WINDOW_PATHS
	check(load(feature_paths.get("emblems"))==WINDOW,"the main HUD controller owns the window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_SYMBOL_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	var growth: FakeGrowth=host.world.growth
	growth.state.emblems["eva"]={"stage":7,"attempts":4,"spent":10}
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent,"eva")
	var filled: Dictionary=opened.get("filled",{})
	check(opened.get("handled",false),"Symbol_All mounts: "+str(opened))
	check(int(filled.get("stage",-1))==7 and int(filled.get("attempts",-1))==4,"stage and attempts follow the runtime: "+str(filled))
	check(int(filled.get("clips",0))==WINDOW.PARTS+1,"every enchant part and the grade play their original clip: "+str(filled.get("clips")))
	check(int(filled.get("rows",0))>5,"option rows are listed: "+str(filled.get("rows")))
	var mounted: Node2D=window._scene
	var rows: Array=window._option_scenes.duplicate()
	var list_key: String=window._list(mounted,window._out,WINDOW.OPTION_LIST).key
	window._scroll_to(list_key,-100.0)
	var scroll: float=window._scrolls[list_key].value
	growth.state.emblems["eva"]={"stage":2,"attempts":1,"spent":20}
	growth.state.points=1214
	growth.refuse["enhance"]="fixture exhausted"
	var lowered: Dictionary=window._refresh_progress()
	check(lowered.filled.stage==2 and lowered.filled.attempts==1 and lowered.filled.clips==WINDOW.PARTS,
		"resetting updates parts, grade and attempts")
	check(window._scene==mounted and window._option_scenes==rows and window._scrolls[list_key].value==scroll,
		"the original page and each scrolled row stay mounted")
	var upgrade: Dictionary=window._locate(mounted,window._out,"Nd_Button/Btn_Upgrade")
	var button: Node=upgrade.player.source_nodes[upgrade.offset].get_meta("source_button")
	check(button.current_state=="disabled","the existing action reflects the new rejected quote")
	growth.state.emblems["eva"]={"stage":3,"attempts":2,"spent":40}
	growth.refuse.clear()
	check(window._refresh_progress().filled.clips==WINDOW.PARTS+1 and window._scene==mounted
		and button.current_state=="normal","crossing into a new grade and restoring the button keep the page")
	for id: String in WINDOW.GODS:
		var shown: Dictionary=window._select(id)
		check(id=="eva" or shown.get("handled",false),"god page mounts: "+id+" "+str(shown.get("code",shown.get("error",""))))
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
