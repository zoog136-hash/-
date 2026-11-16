extends SceneTree
## The original 523 선택 보상 window (source_main_reward_select_window.gd)
## over the existing reward choice dialog (patch523_reward_choice.gd).
## Without arguments (no original files): the reward names, 보상 받기 needs a
## chosen row and claims it through the dialog, a refused claim keeps the
## window, 취소 frees the dialog (the box is kept), and the dialog opens the
## window. Real input: -- --pack=<private original main UI pack directory>:
## RewardSelectBoxScene mounts the box slot and one Common_Slot per reward.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_reward_select_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeDialog extends Node:
	var claims: Array=[]
	var accept: bool=false
	func original_rows() -> Array:
		return [{"entity_id":11,"item_class_id":0,"name":"가","amount":1,"blessing":2,"enchant":0},
			{"entity_id":12,"item_class_id":0,"name":"나","amount":3,"blessing":1,"enchant":7}]
	func box_info() -> Dictionary:
		return {"name":"선택 상자","item_class_id":0}
	func claim_entity(entity_id: int) -> bool:
		claims.append(entity_id)
		return accept

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=Node.new()
	var hud:=FakeHud.new()
	var dialog:=FakeDialog.new()
	world.add_child(hud)
	hud.add_child(dialog)
	root.add_child(world)
	return {"world":world,"hud":hud,"dialog":dialog}

func _run() -> void:
	var rows: Array=FakeDialog.new().original_rows()
	check(WINDOW.reward_name(rows[0])=="축복받은 가 ×1" and WINDOW.reward_name(rows[1])=="+7 나 ×3","reward names")
	var host: Dictionary=_host()
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	window._dialog=weakref(host.dialog)
	window._rows=rows
	check(not window._confirm().get("ok",true) and host.dialog.claims.is_empty(),"보상 받기 needs a chosen row")
	window._choose(1)
	check(window.chosen==1 and host.hud.messages[-1]=="+7 나 ×3","a tap chooses and names the reward")
	check(not window._confirm().get("ok",true) and host.dialog.claims==[12],"a refused claim keeps the box and the window")
	host.dialog.accept=true
	check(window._confirm().get("claimed",false) and host.dialog.claims==[12,12],"보상 받기 claims through the dialog")
	window._cancel()
	await process_frame
	check(not is_instance_valid(host.dialog),"취소 frees the dialog (the box stays)")
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/patch523_reward_choice.gd")
	check(source.contains("try_open_feature_window(\"reward_select\",[self])") and source.contains("func claim_entity("),"the reward choice dialog opens the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_REWARD_SELECT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var opened: Dictionary=window.open(parent,host.dialog)
	check(opened.get("handled",false) and int(opened.filled.rows)==2,"RewardSelectBoxScene mounts the rewards: "+str(opened).left(300))
	var chosen: Dictionary=window._choose(0)
	check(chosen.get("handled",false) and int(chosen.filled.chosen)==0,"a chosen reward mounts")
	host.dialog.queue_free()
	await process_frame
	check(not window.is_open(),"the window closes with its dialog")
	parent.queue_free()
	host.world.queue_free()
