extends SceneTree
## The original 523 오만의 탑 리스트 (source_main_oman_tower_window) opened by
## the 순간이동 window's 오만의 탑 tab. Without arguments (no original files):
## the floors are the world's oman maps in order, and the teleport window
## wires the tab and selects a picked floor. Real input: -- --pack=<private
## original main UI pack directory>: OmanTower_All mounts one row per floor,
## a tap hands the floor to the opener and closes only the list.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_oman_tower_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]
var picked: Array[String]=[]

class FakeWorld extends Node:
	var maps_by_id: Dictionary={"oman_02":{},"oman_01":{},"oman_10":{},"giran":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _pick(map_id: String) -> void:
	picked.append(map_id)

func _run() -> void:
	var world:=FakeWorld.new()
	check(WINDOW.floors(world)==[{"map_id":"oman_01","floor":1},{"map_id":"oman_02","floor":2},{"map_id":"oman_10","floor":10}],"the world's oman floors in order")
	check(WINDOW.floors(null).is_empty(),"no world, no floors")
	world.free()
	var teleport: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_teleport_window.gd")
	check(teleport.contains("\"Nd_TabMenu/Btn_Dungeon_Off/Label\"]={\"role\":\"source_text\",\"text\":\"오만의 탑\"}") and teleport.contains("try_open_overlay_window(\"oman_tower\",[Callable(self,\"_select_oman\")])"),"the teleport window's 오만의 탑 tab opens the list")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_OMAN_TOWER_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var world:=FakeWorld.new()
	var hud:=Node.new()
	world.add_child(hud)
	root.add_child(world)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent,Callable(self,"_pick"))
	check(opened.get("handled",false) and int(opened.get("filled",{}).get("floors",0))==3,"OmanTower_All mounts one row per floor: "+str(opened).left(300))
	var chosen: Dictionary=window._choose("oman_02")
	check(chosen.get("picked","")=="oman_02" and picked==["oman_02"] and not window.is_open(),"a floor goes to the opener and the list closes")
	await process_frame
	parent.queue_free()
	world.queue_free()
