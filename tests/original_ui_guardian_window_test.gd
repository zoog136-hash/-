extends SceneTree
## The original 523 수호성 window (source_main_guardian_window.gd) over the
## existing world.growth guardians. Without arguments (no original files): the
## six stars match the growth guardians, the estimated layout is declared as
## TWILIGHT 추정 in one data file, slot cells follow SkillTreeSlot UIPosX/Y,
## The original popup runs each quoted action after confirmation and keeps
## unavailable source steps inside the current window.
## Real input: -- --pack=<private original main UI pack directory>: the graph
## mounts with every slot and prerequisite line, the opened-slot effect list
## and the slot info popup.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_guardian_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeSource extends RefCounted:
	func constant(_name: String) -> float:
		return 1200.0
	func has_node(_id: String) -> bool:
		return true
	func effects(_id: String, level: int) -> Dictionary:
		return {"max_hp:flat":10+level}
	func detail(_id: String, level: int) -> String:
		return "detail %d" % level

class FakeGrowth extends RefCounted:
	var config: Dictionary={}
	var state: Dictionary={"nodes":[],"pending":{},"guardian_representatives":{}}
	var guardian_source=FakeSource.new()
	var world: Object
	var executed: Array=[]
	func _init() -> void:
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/guardian_source523.json"))
		config={"guardians":parsed.get("guardians",[])}
	func guardian_level(_id: String) -> int:
		return 1
	func guardian_representative(category: int) -> String:
		return str(state.guardian_representatives.get(str(category),""))
	func node(id: String) -> Dictionary:
		for group: Dictionary in config.guardians:
			for row: Dictionary in group.nodes:
				if str(row.id)==id:return row
		return {}
	func quote(action: String, id: String="", _count: int=1) -> Dictionary:
		return {"ok":true,"message":"%s %s" % [action,id],"revision":3}
	func execute(action: String, id: String, count: int, revision: int, day: int=-1) -> Dictionary:
		executed.append([action,id,count,revision,day])
		return {"ok":true,"message":"done"}

class FakeWorld extends Node:
	var growth: RefCounted
	var inventory: Dictionary={"수호석":12}

class FakeHud extends Node:
	var messages: Array[String]=[]
	var original_main_ui_controller: Node
	var review: Control
	var accept: Callable
	var review_available: bool=true
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(_title: String, _body: String, _action: String, _callback: Callable, _maximum: int=0) -> Control:
		return null
	func confirm_source_action(_title: String, _body: String, _action: String, callback: Callable) -> Control:
		if not review_available:return null
		accept=callback
		review=Control.new()
		add_child(review)
		return review
	func accept_review() -> void:
		if not is_instance_valid(review):return
		review.free()
		var callback: Callable=accept
		accept=Callable()
		if callback.is_valid():callback.call(1)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	var growth:=FakeGrowth.new()
	growth.world=world
	world.growth=growth
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud,"growth":growth}

func _run() -> void:
	var host: Dictionary=_host()
	var growth: FakeGrowth=host.growth
	var ids: Array=growth.config.guardians.map(func(g: Dictionary) -> String: return str(g.id))
	check(ids.size()==6 and ids.all(func(id: String) -> bool: return WINDOW.STARS.has(id)),"the six original stars match the growth guardians: "+str(ids))
	var values: Dictionary=WINDOW.layout()
	check(str(values.get("status",""))=="TWILIGHT 추정" and float(values.get("column_pitch",0))>0 and float(values.get("row_pitch",0))>0,"the cell pitch is one declared TWILIGHT estimate")
	check(WINDOW.cell_centre(values,1,1)==Vector2(59.0,430.0-43.0) and WINDOW.cell_centre(values,2,2)-WINDOW.cell_centre(values,1,1)==Vector2(float(values.column_pitch),-float(values.row_pitch)),"cells follow UIPosX right and UIPosY down")
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	window.selected="joe"
	var reset: Dictionary=window._reset()
	check(growth.executed.is_empty(),"초기화 waits for the confirmation")
	host.hud.accept_review()
	check(reset.get("ok",false) and growth.executed==[["guardian_reset","joe",1,3,-1]],"초기화 confirms and executes the existing guardian_reset: "+str(growth.executed))
	check(window._slot_pressed("source523_2022").get("code")=="source_guardian_window_info_unavailable" and not host.hud.messages.is_empty(),"a missing slot-info scene keeps the action pending without a substitute")
	# The slot info popup's actions and lines (existing guardian runtime).
	var slot: Dictionary=growth.config.guardians[0].nodes[1]
	window.info=str(slot.id)
	var activated: Dictionary=window._info_ok()
	host.hud.accept_review()
	check(activated.get("ok",false) and growth.executed[-1]==["activate",str(slot.id),1,3,-1],"활성화 confirms and executes the existing activate: "+str(growth.executed))
	window.info=str(slot.id)
	var represented: Dictionary=window._represent()
	host.hud.accept_review()
	check(represented.get("ok",false) and growth.executed[-1]==["representative",str(slot.id),1,3,-1],"ON executes the existing representative action")
	var info_rows: Array=window._info_rows(growth,str(slot.id))
	var titles: Array=info_rows.map(func(row: Dictionary) -> String: return str(row.spec["Nd_Skill/Text_Title"].text))
	check(titles.has("비용") and titles.has("능력치") and info_rows.all(func(row: Dictionary) -> bool: return row.member==WINDOW.INFO_ROW),"popup lines come from the guardian source: "+str(titles))
	var opened: Dictionary={}
	var active: Dictionary={}
	for group: Dictionary in growth.config.guardians:
		for row: Dictionary in group.nodes:
			if row.kind=="active":active=row
			elif int(row.get("max_level",0))>1:opened=row
	check(not opened.is_empty() and not active.is_empty(),"the source models have an upgradable slot and an active skill")
	if not opened.is_empty():
		growth.state.nodes=[str(opened.id)]
		window.info=str(opened.id)
		check(window._info_ok().get("code")=="source_guardian_enchant_window_unavailable" and window.info==opened.id,"a missing upgrade keeps the original info and selection")
	if not active.is_empty():
		growth.state.nodes=[str(active.id)]
		window.info=str(active.id)
		var before: int=growth.executed.size()
		host.hud.review_available=false
		check(not window._info_ok().get("ok",false) and growth.executed.size()==before,"a missing cast confirmation leaves the runtime untouched")
		host.hud.review_available=true
		check(window._info_ok().get("quoted")=="guardian_cast" and growth.executed.size()==before,"the authored skill action opens its confirmation")
		host.hud.accept_review()
		check(growth.executed.size()==before+1 and growth.executed[-1]==["guardian_cast",str(active.id),1,3,-1],"confirming executes the existing guardian cast once")
	growth.state.nodes=[]
	growth.state.pending={"node":str(slot.id),"cards":3}
	check(window._slot_pressed("another").get("code")=="source_guardian_window_card_pending","another slot does not discard a pending selection")
	check(window._slot_pressed(str(slot.id)).get("code")=="source_guardian_find_window_unavailable" and growth.state.pending.node==slot.id,"a missing card scene preserves the exact pending selection")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_feature(\"guardians\")") and not renewal.contains("func open_growth_native"),"수호성 opens the original window first, a pending card choice stays native")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_GUARDIAN_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var growth: FakeGrowth=host.growth
	var first: Dictionary=growth.config.guardians[0].nodes[0]
	growth.state.nodes=[str(first.id)]
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	for group: Dictionary in growth.config.guardians:
		var lines: int=0
		for node: Dictionary in group.nodes:lines+=(node.get("prerequisites",[]) as Array).size()
		var opened: Dictionary=window.open(parent,str(group.id)) if group==growth.config.guardians[0] else window._select(str(group.id))
		var filled: Dictionary=opened.get("filled",{})
		check(opened.get("handled",false) and int(filled.get("slots",0))==(group.nodes as Array).size() and int(filled.get("lines",-1))==lines,"star graph mounts: %s %s" % [str(group.id),str(opened).left(400)])
	window._select(str(growth.config.guardians[0].id))
	check(int(window.last_result.filled.get("effects",-1))==1,"the opened slot is listed in the effect list: "+str(window.last_result.filled))
	var shown: Dictionary=window._slot_pressed(str(first.id))
	check(shown.get("handled",false) and str(shown.filled.get("info",""))==str(first.id),"a slot opens the original info popup: "+str(shown).left(300))
	check(window._close_info().get("handled",false) and window.info.is_empty(),"닫기 closes the popup")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
