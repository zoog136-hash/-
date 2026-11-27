extends SceneTree
## The original 523 제작 결과 window (source_main_craft_result_window.gd) for
## a finished craft of the existing crafting log. Without arguments (no
## original files): the 대성공 / 성공 / 실패 counts, the outcome label by the
## produced item, and the 제작 window opening the result once after its own
## craft saved a new log entry. Real input: -- --pack=<private original main
## UI pack directory>: ProductionResultScene mounts the counts and the row.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_craft_result_window.gd")
const PRODUCTION=preload("res://scripts/ui/original_ui/source_main_production_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeCrafting extends RefCounted:
	var recipes: Dictionary={"r1":{"outcomes":[{"label":"성공","item":"강철 검","probability":1000000,"level":0,"quantity":1},{"label":"대성공","item":"축복받은 강철 검","probability":0,"level":0,"quantity":1},{"label":"실패","item":"지급 없음","probability":0,"empty_result":true}]},"r2":{}}

class FakeGame extends Node:
	var crafting:=FakeCrafting.new()
	var crafting_log: Array[Dictionary]=[]
	var write_result: bool=false
	func _craft_quote(_id: String, _count: int) -> Dictionary:
		return {"ok":true}
	func craft(id: String, count: int) -> void:
		if write_result:crafting_log.append({"recipe_id":id,"output":"강철 검","quantity":count,"batch":count,"at":10.0})
	func _find_catalog_item_record(name: String) -> Dictionary:
		return {"source_item_class_id":77} if name=="축복받은 강철 검" else {}

class FakeController extends RefCounted:
	var opened: Array=[]
	func try_open_feature_window(key: String, args: Array=[]) -> Dictionary:
		opened.append([key,args])
		return {"ok":true,"handled":true}

class FakeHud extends Node:
	signal craft_requested(recipe_id: String, batch: int)
	var original_main_ui_controller:=FakeController.new()
	var pending: Callable
	func confirm_crafting_action(_title: String, _body: String, _action: String, callback: Callable) -> Control:
		pending=callback
		var popup:=Control.new()
		add_child(popup)
		return popup
	func confirm() -> void:
		var callback: Callable=pending
		pending=Callable()
		if callback.is_valid():callback.call(1)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(WINDOW.counts({"label":"대성공","quantity":1})=={"대성공":1,"성공":0,"실패":0},"an outcome craft counts its label")
	check(WINDOW.counts({"label":"","quantity":3,"batch":3})=={"대성공":0,"성공":3,"실패":0},"a plain craft counts its batches as 성공")
	check(WINDOW.counts({"label":"성공","quantity":0})["실패"]==1,"지급 없음 is 실패")
	var game:=FakeGame.new()
	root.add_child(game)
	var shown: Dictionary=PRODUCTION.craft_result(game,{"recipe_id":"r1","output":"축복받은 강철 검","quantity":1,"batch":1})
	check(shown.label=="대성공" and shown.item_class_id==77 and shown.name=="축복받은 강철 검","the produced item names the outcome label and picture")
	check(PRODUCTION.craft_result(game,{"recipe_id":"r2","output":"물약","quantity":5,"batch":5}).label=="","a recipe without outcomes has no label")
	var hud:=FakeHud.new()
	root.add_child(hud)
	hud.craft_requested.connect(game.craft)
	var window=PRODUCTION.new()
	window._hud=weakref(hud)
	window._world=weakref(game)
	window._scene=Node2D.new()
	root.add_child(window._scene)
	window._selected="r1"
	check(window._craft_requested().get("ok",false),"the production button opens confirmation")
	hud.confirm()
	check(hud.original_main_ui_controller.opened.is_empty(),"no new log entry: no result")
	game.crafting_log.append({"recipe_id":"r1","output":"지급 없음","quantity":0,"batch":1,"at":10.0})
	game.write_result=true
	check(window._craft_requested().get("ok",false),"a retry opens confirmation without replaying the old log")
	hud.confirm()
	var opened: Array=hud.original_main_ui_controller.opened
	check(opened.size()==1 and opened[0][0]=="craft_result" and opened[0][1][0].label=="성공","the new confirmed craft opens 제작 결과 even at the previous timestamp: "+str(opened))
	hud.confirm()
	check(opened.size()==1,"the result opens once")
	window.close()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	game.queue_free()
	hud.queue_free()
	print("ORIGINAL_UI_CRAFT_RESULT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host:=Node.new()
	var hud:=Node.new()
	host.add_child(hud)
	root.add_child(host)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent,{"name":"강철 검","quantity":2,"batch":2,"label":"","item_class_id":0})
	check(opened.get("handled",false) and int(opened.filled.rows)==1 and int(opened.filled.counts["성공"])==2,"ProductionResultScene mounts the counts and the row: "+str(opened).left(300))
	var failed: Dictionary=window.open(parent,{"name":"지급 없음","quantity":0,"label":"실패"})
	check(failed.get("handled",false) and int(failed.filled.rows)==0,"지급 없음 mounts no row")
	window.close()
	await process_frame
	parent.queue_free()
	host.queue_free()
