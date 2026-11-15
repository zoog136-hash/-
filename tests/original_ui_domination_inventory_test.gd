extends SceneTree
## The 지배석 합성 tab's stone inventory (source_main_domination_stone_window).
## Without arguments (no original files): the inventory tabs follow the
## tower of each stone's group, tapping registers / removes a stone under the
## 일괄 등록 rules. Real input: -- --pack=<private original main UI
## pack directory>: the panel mounts with Inventory_Slot_Set lines.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_domination_stone_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var failures: Array[String]=[]
var checks: int=0

class FakeRuntime extends RefCounted:
	var stones: Array[Dictionary]=[]
	func contract() -> Dictionary:
		return {"groups":{3:{"id":3,"tower_contents_id":1053},103:{"id":103,"tower_contents_id":1063},143:{"id":143,"tower_contents_id":1073}},
			"towers":{3:{"id":3,"contents_id":1053,"name":"오만의 탑"},13:{"id":13,"contents_id":1063,"name":"신념의 탑"},23:{"id":23,"contents_id":1073,"name":"지배의 탑"}}}
	func bag_stones() -> Array[Dictionary]:
		return stones
	func merge_quote(_ids: Array) -> Dictionary:
		return {"ok":false,"error":"x"}
	func _record_of(_id: String) -> Dictionary:
		return {}
	func active_set() -> Dictionary:
		return {"active":false,"equipped":0}
	func slot(_index: int) -> Dictionary:
		return {}
	func slot_unlocked(_index: int) -> bool:
		return true
	func slot_count() -> int:
		return 3

class FakeWorld extends Node:
	var domination_stones: RefCounted

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

static func _stone(id: String, group: int, locked: bool=false, price: int=1) -> Dictionary:
	return {"instance_id":id,"record":{"name":"stone "+id},"info":{"group":group,"grade":3,"merge_price":price},"locked":locked}

func _run() -> void:
	var runtime:=FakeRuntime.new()
	runtime.stones=[_stone("1",3),_stone("2",103),_stone("3",143),_stone("4",3,true),_stone("5",3,false,0),_stone("6",3),_stone("7",3),_stone("8",3)]
	var window=WINDOW.new()
	window._inventory_tab="Btn_All"
	check(window._inventory_rows(runtime).size()==8,"전체 lists every bag stone")
	window._inventory_tab="Btn_Oman"
	check(window._inventory_rows(runtime).map(func(s: Dictionary) -> String: return s.instance_id)==["1","4","5","6","7","8"],"오만 lists the 오만의 탑 groups")
	window._inventory_tab="Btn_Faith"
	check(window._inventory_rows(runtime).map(func(s: Dictionary) -> String: return s.instance_id)==["2"],"신념 lists the 신념의 탑 groups")
	window._inventory_tab="Btn_Control"
	check(window._inventory_rows(runtime).map(func(s: Dictionary) -> String: return s.instance_id)==["3"],"지배 lists the 지배의 탑 groups")
	# Registration rules (the window restages after each tap; no host here).
	window._inventory_tab="Btn_All"
	window._inventory_stones=window._inventory_rows(runtime)
	var hud:=FakeHud.new()
	window._hud=weakref(hud)
	check(window._inventory_pressed(0).get("registered","")=="1" and window._fusion==["1"],"a tap registers the stone")
	check(window._inventory_pressed(0).get("removed","")=="1" and window._fusion.is_empty(),"a second tap removes it")
	check(not window._inventory_pressed(3).get("ok",true) and window._fusion.is_empty(),"a locked stone is refused")
	check(not window._inventory_pressed(4).get("ok",true),"a stone without a merge price is refused")
	for index: int in [0,1,2,5,6]:window._inventory_pressed(index)
	check(window._fusion.size()==5 and not window._inventory_pressed(7).get("ok",true),"the FusionBox holds five")
	check(window._inventory_pressed(99).get("empty_slot",false),"an empty slot does nothing")
	hud.free()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_DOMINATION_INVENTORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var hud:=FakeHud.new()
	root.add_child(hud)
	var world:=FakeWorld.new()
	var runtime:=FakeRuntime.new()
	for index: int in range(6):runtime.stones.append(_stone(str(index+1),3 if index<4 else 103))
	world.domination_stones=runtime
	root.add_child(world)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	window._tab="fusion"
	var opened: Dictionary=window.open(parent,world)
	var inventory: Dictionary=opened.get("filled",{}).get("inventory",{})
	check(opened.get("handled",false) and inventory.get("mounted",false) and int(inventory.get("lines",0))==2 and int(inventory.get("stones",0))==6,"the fusion tab mounts the stone inventory: "+str(inventory))
	var registered: Dictionary=window._inventory_pressed(1)
	check(registered.get("registered","")=="2" and window.last_result.get("filled",{}).get("registered",0)==1,"a tapped stone joins the FusionBox: "+str(registered))
	window._select_inventory_tab("Btn_Faith")
	check(int(window.last_result.get("filled",{}).get("inventory",{}).get("stones",-1))==2,"the 신념 tab lists its stones")
	window.close()
	await process_frame
	parent.queue_free()
	world.queue_free()
	hud.queue_free()
