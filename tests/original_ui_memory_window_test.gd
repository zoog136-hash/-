extends SceneTree
## The original 523 나의 기억장소 window (source_main_memory_window.gd) over the
## existing remembered locations (growth.travel). Without arguments (no
## original files): a teleport source turns the rows into their move face,
## a move quotes then confirms growth.travel.travel with the quoted revision
## and closes, 삭제 forgets the selected mark through the confirmation, 편집
## opens the existing page, and growth.travel.open tries the original window
## first. Real input: -- --pack=<private original main UI pack directory>:
## Memory_All mounts with and without marks, with a source, and a selection.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_memory_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeGrowthRuntime extends RefCounted:
	var state: Dictionary={"revision":4}

class FakeTravel extends RefCounted:
	const POLICY={"bookmark_limit":16}
	var runtime:=FakeGrowthRuntime.new()
	var list: Array=[{"name":"용의 계곡 입구","map_id":"m1"},{"name":"사냥터","map_id":"m2"}]
	var calls: Array=[]
	func marks() -> Array:
		return list.duplicate(true)
	func quote(index: int, source: Dictionary, origin: String, revision: int) -> Dictionary:
		calls.append(["quote",index,source.get("kind",""),origin,revision])
		return {"ok":index==0,"message":"순간이동 주문서 → 용의 계곡 입구 · 소모: 순간이동 주문서 1개" if index==0 else "이동할 수 없습니다"}
	func travel(index: int, source: Dictionary, origin: String, revision: int) -> Dictionary:
		calls.append(["travel",index,source.get("kind",""),origin,revision])
		return {"ok":true,"message":"기억 장소로 순간이동했습니다"}
	func forget(index: int, revision: int) -> Dictionary:
		calls.append(["forget",index,revision])
		list.remove_at(index)
		return {"ok":true,"message":"기억 장소를 삭제했습니다"}
	func open_native(source: Dictionary) -> void:
		calls.append(["open_native",source.get("kind","")])

class FakeGrowth extends RefCounted:
	var travel:=FakeTravel.new()

class FakeWorld extends Node:
	var growth:=FakeGrowth.new()
	var active_map_id: String="m1"
	var maps_by_id: Dictionary={"m1":{"name":"용의 계곡"},"m2":{"name":"기란 감옥"}}
	var inventory: Dictionary={"순간이동 주문서":7}

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
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	var host: Dictionary=_host()
	var travel: FakeTravel=host.world.growth.travel
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	window.source={"kind":"scroll","name":"순간이동 주문서"}
	window.origin="m1"
	check(window._region({"map_id":"m2"})=="기란 감옥","Label_Name is the mark's region")
	check(not window._move(1).get("ok",true) and host.hud.messages[-1]=="이동할 수 없습니다" and host.hud.confirmations.is_empty(),"a refused quote shows its reason and confirms nothing")
	window.selected=0
	window._select(0)
	check(travel.calls.slice(-2)==[["quote",0,"scroll","m1",4],["travel",0,"scroll","m1",4]] and host.hud.confirmations[-1][1].contains("소모"),"a tap on the selected row (teleport mark) quotes, confirms and runs the existing travel with the quoted revision: "+str(travel.calls))
	window.selected=-1
	check(not window._forget().get("ok",true),"삭제 needs a selection")
	window.selected=1
	window._forget()
	check(travel.calls[-1]==["forget",1,4] and travel.list.size()==1 and window.selected==-1,"삭제 forgets the selected mark through the confirmation")
	window._edit()
	check(travel.calls[-1]==["open_native","scroll"],"편집 opens the existing 기억 장소 page with the same source")
	var growth: String=FileAccess.get_file_as_string("res://scripts/growth/symbol_travel.gd")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(growth.contains("open_memory_places") and growth.contains("func open_native") and renewal.contains("_open_original_feature(\"memory_places\",[source])"),"growth.travel.open tries the original window first")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_MEMORY_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var shown: Dictionary=window.open(parent)
	check(shown.get("handled",false) and int(shown.filled.marks)==2 and not shown.filled.moving,"Memory_All mounts the marks: "+str(shown).left(300))
	check(window._select(1).get("handled",false) and int(window.last_result.filled.selected)==1,"a tap selects a mark")
	var moving: Dictionary=window.open(parent,{"kind":"scroll","name":"순간이동 주문서"})
	check(moving.get("handled",false) and moving.filled.moving and window._select(0).get("handled",false),"with a teleport source a tap selects the row to move to")
	host.world.growth.travel.list.clear()
	check(window.open(parent).get("handled",false),"no marks: the original notice")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
