extends SceneTree
## The original 523 실패 이력 조회 window (source_main_fail_history_window.gd)
## over the existing TJ failure records. Without arguments (no original
## files): records of the chosen HistoryType only, newest first, the date
## text, and the card fusion window's 실패 이력 조회 button. Real input:
## -- --pack=<private original main UI pack directory>: FailHistory_All
## mounts a grade title and the records, the kind selector switches kinds.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_fail_history_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeCore extends RefCounted:
	var state: Dictionary={"history":[
		{"id":"failure-1","history_type":1,"deck":1,"grade":4,"time":1700000000},
		{"id":"failure-2","history_type":1,"deck":1,"grade":5,"time":1700003600},
		{"id":"failure-3","history_type":11,"deck":2,"grade":4,"time":1700007200},
		{"id":"failure-4","history_type":41,"deck":1,"grade":4,"time":1700010800}],"used":{"failure-1":"3"}}

class FakeTj extends RefCounted:
	var core:=FakeCore.new()

class FakeWorld extends Node:
	var tj_coupons:=FakeTj.new()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Dictionary=FakeCore.new().state
	var fusion: Array=WINDOW.records(state,1)
	check(fusion.size()==2 and fusion[0].id=="failure-2","변신 합성 records only, newest first")
	check(WINDOW.records(state,0).is_empty(),"a kind without TWILIGHT records lists nothing")
	check(WINDOW.date_text(0)=="1970.01.01 09:00","dates in the TJ offset (UTC+9)")
	var fusion_window: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_card_fusion_window.gd")
	check(fusion_window.contains("\"Nd_Fail_History/Btn_History\"]={\"activate\":Callable(self,\"_fail_history\")}") and fusion_window.contains("\"fail_history\",[start]"),"the card fusion window's 실패 이력 조회 opens the window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_HISTORY_LOG_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var opened: Dictionary=window.open(parent,"Btn_Change_Mix")
	check(opened.get("handled",false) and int(opened.filled.records)==2 and int(opened.filled.rows)==4,"FailHistory_All mounts two grade titles and two records: "+str(opened).left(300))
	check(window._toggle_choose().filled.choosing,"조회할 이력 선택 opens the kinds")
	var magic: Dictionary=window._choose("Btn_Magic_Mix")
	check(magic.get("handled",false) and int(magic.filled.records)==1 and not magic.filled.choosing,"a kind switches the list")
	check(int(window._choose("Btn_Skill_Mix").filled.records)==0,"스킬 합성 has no record")
	window.close()
	await process_frame
	parent.queue_free()
	world.queue_free()
