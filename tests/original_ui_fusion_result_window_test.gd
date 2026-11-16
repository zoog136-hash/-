extends SceneTree
## The original 523 합성 결과 window (source_main_fusion_result_window.gd) for
## a fusion the existing rule already rolled. Without arguments (no
## original files): ten results a page, the full-screen tap turns pages then
## closes, a card names itself (the pity reward marked), the HUD guard runs
## once on close, and present_card_reveal uses the window only for fusions
## through the overlay path. Real input: -- --pack=<private original main UI
## pack directory>: Change_Fusion_All mounts the result cards.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_fusion_result_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _views(count: int) -> Array:
	var views: Array=[]
	for i: int in range(count):views.append({"id":"source:%d" % i,"name":"카드 %d" % i,"grade":"영웅" if i%2==0 else "희귀"})
	views[-1]["pity_reward"]=true
	return views

func _run() -> void:
	var hud:=FakeHud.new()
	root.add_child(hud)
	var window=WINDOW.new()
	window._hud=weakref(hud)
	var released: Array=[0]
	window.results=_views(12)
	window.on_closed=func() -> void:released[0]+=1
	check(window.pages()==2,"ten results a page")
	window._card(11)
	check(hud.messages[-1]=="합성 시도 보상 · 희귀 · 카드 11","a card names itself, the pity reward marked")
	window._next()
	check(window.page==1 and released[0]==0,"the full-screen tap turns to the next page")
	window._next()
	check(released[0]==1,"the last page closes and releases the HUD guard")
	window.close()
	check(released[0]==1,"the guard runs once")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("if is_fusion and _present_original_fusion(views,category,bool(awarded.get(\"success\",false))): return") and renewal.contains("try_open_overlay_window(\"fusion_result\""),"fusion reveals use the original window through the overlay path")
	var controller: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(controller.contains("func try_open_overlay_window("),"the overlay path keeps the other windows open")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	hud.queue_free()
	print("ORIGINAL_UI_FUSION_RESULT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var hud:=FakeHud.new()
	host.add_child(hud)
	root.add_child(host)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var released: Array=[0]
	var opened: Dictionary=window.open(parent,_views(12),"변신",true,func() -> void:released[0]+=1)
	check(opened.get("handled",false) and int(opened.filled.shown)==10 and int(opened.filled.pages)==2,"Change_Fusion_All mounts the first ten results: "+str(opened).left(300))
	var second: Dictionary=window._next()
	check(second.get("handled",false) and int(second.filled.shown)==2,"the second page mounts the rest")
	window._next()
	check(not window.is_open() and released[0]==1,"the last tap closes")
	await process_frame
	parent.queue_free()
	host.queue_free()
