extends SceneTree
## The original 523 수호성 window (source_main_guardian_window.gd) over the
## existing world.growth guardians. Without arguments (no original files): the
## six stars match the growth guardians, the estimated layout is declared as
## TWILIGHT 추정 in one data file, slot cells follow SkillTreeSlot UIPosX/Y,
## 초기화 goes quote -> confirmation -> execute and a slot opens the existing
## 수호성 view on it. Real input: -- --pack=<private original main UI pack
## directory>: the graph mounts with every slot and prerequisite line.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_guardian_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeSource extends RefCounted:
	func constant(_name: String) -> float:
		return 1200.0

class FakeGrowth extends RefCounted:
	var config: Dictionary={}
	var state: Dictionary={"nodes":[],"pending":{},"guardian_representatives":{}}
	var guardian_source=FakeSource.new()
	var world: Object
	var executed: Array=[]
	func _init() -> void:
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/guardian_source523.json"))
		config={"guardians":parsed.get("guardians",[])}
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
	var routed: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(_title: String, _body: String, _action: String, callback: Callable, _maximum: int=0) -> Control:
		callback.call(1)
		return null
	func open_growth_native(section: String, group: String="", node: String="") -> void:
		routed.append([section,group,node])

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
	check(reset.get("ok",false) and growth.executed==[["guardian_reset","joe",1,3,-1]],"초기화 confirms and executes the existing guardian_reset: "+str(growth.executed))
	window._slot_pressed("source523_2022")
	check(host.hud.routed==[["guardians","joe","source523_2022"]],"a slot opens the existing 수호성 view on it: "+str(host.hud.routed))
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_feature(\"guardians\")") and renewal.contains("func open_growth_native"),"수호성 opens the original window first, a pending card choice stays native")
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
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
