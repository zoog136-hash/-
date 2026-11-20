extends SceneTree
## The original 523 재화 정보 window (source_main_currency_window.gd) and the
## HUD wallet's Btn_Info. Without arguments (no original files): the balances
## are the existing ones (world gold, renewal_hud.currency_balances) in the
## HUD's own order, the wallet contract stays read-only without a window and
## binds Btn_Info (with its arrow icon) when the window exists. Real input:
## -- --pack=<private original main UI pack directory>: Gem_All mounts one
## Gem_List row per currency and the wallet mounts with its info button.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_currency_window.gd")
const WALLET=preload("res://scripts/ui/original_ui/source_main_wallet_bindings.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var checks: int=0
var failures: Array[String]=[]

class CountedPack extends "res://scripts/ui/original_ui/source_pack.gd":
	var scene_reads: Dictionary={}
	func scene(member: String) -> Dictionary:
		scene_reads[member]=int(scene_reads.get(member,0))+1
		return super.scene(member)

class FakeWorld extends Node:
	var gold: int=1234567
	func _find_catalog_item_record(_name: String) -> Dictionary:
		return {}

class FakeHud extends Node:
	var currency_balances: Dictionary={"다이아":42,"명예 코인":7,"변신 제작 코인":1,"마법인형 제작 코인":0,"성물 제작 코인":3}
	var opened: int=0
	func open_currency_info() -> void:
		opened+=1

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
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	check(window.balances()=={"아데나":1234567,"다이아":42,"명예 코인":7,"변신 제작 코인":1,"마법인형 제작 코인":0,"성물 제작 코인":3},"the existing balances in the HUD order: "+str(window.balances()))
	check(WINDOW._number(1234567)=="1,234,567","amount text")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	var controller: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(renewal.contains("func open_currency_info") and renewal.contains("_open_original_feature(\"currency_info\")") and controller.contains("Callable(self,\"_wallet_info\")"),"the wallet Btn_Info opens the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_CURRENCY_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack:=CountedPack.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	var read_only: Dictionary=WALLET.build(pack,10,{"다이아":2})
	check(read_only.get("ok",false) and not read_only.source_node_offsets.has(WALLET.INFO_BUTTON) and read_only.unresolved_fields.has("original_info_button_action"),"without the window the wallet stays read-only")
	var opened: Array=[0]
	var contract: Dictionary=WALLET.build(pack,10,{"다이아":2},func() -> Dictionary:
		opened[0]+=1
		return {"ok":true})
	check(contract.get("ok",false) and contract.source_node_offsets.has(WALLET.INFO_BUTTON) and contract.bindings[WALLET.INFO_BUTTON].role=="button","the wallet binds Btn_Info")
	var wallet=SCENE.new()
	var configured: Dictionary=wallet.configure_project(pack,"UI/HUDScene.csb",1540,contract.bindings,contract.source_node_offsets)
	check(configured.get("ok",false),"the wallet mounts with its info button: "+str(configured).left(300))
	wallet.free()
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	pack.scene_reads.clear()
	var shown: Dictionary=window.open(parent)
	check(shown.get("handled",false) and int(shown.filled.rows)==6,"Gem_All mounts one row per currency: "+str(shown).left(300))
	check(int(pack.scene_reads.get(WINDOW.ROW,0)) in [1,2],"six rows share one metadata read, plus at most one scoped renderer read")
	pack.scene_reads.clear()
	host.world.gold=7654321
	var refreshed: Dictionary=window.refresh()
	check(refreshed.get("ok",false) and int(refreshed.get("filled",{}).get("amounts",{}).get("아데나",0))==7654321,"a new stage takes live balances")
	var displayed: Array[String]=[]
	if window.is_open():
		for label: Node in window._scene.find_children("OriginalText","Node2D",true,false):displayed.append(str(label.original_options.text))
		for label: Node in window._scene.find_children("OriginalBitmapText","Node2D",true,false):displayed.append(str(label._options.text))
	check("7,654,321" in displayed,"the original text node receives the updated balance")
	check(int(pack.scene_reads.get(WINDOW.ROW,0)) in [1,2],"the next stage reads the row afresh and shares it within the stage")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
