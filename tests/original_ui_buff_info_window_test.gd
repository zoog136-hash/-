extends SceneTree
## The original 523 버프 정보 window (source_main_buff_info_window.gd) over the
## existing active effects. Without arguments (no original files): remaining
## time text, the world's _combined_active_buffs as the source, the HUD
## active effect row opening the window first. Real input: -- --pack=<private
## original main UI pack directory>: Inventory_Buff_Info_All mounts one row
## per effect, the 디버프 / 발동 마법 tabs mount empty with their notices, and
## the per-second refresh follows the live times and a changed effect set.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_buff_info_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeWorld extends Node:
	var buffs: Dictionary={"헤이스트":{"remaining":299.2,"speed":1.3},"민첩 강화 물약":{"remaining":4000.0,"desc":"민첩 +5 · 지속 시간 1시간\n두 번째 줄"}}
	func _combined_active_buffs() -> Dictionary:
		return buffs.duplicate(true)

class FakeHud extends Node:
	func show_message(_text: String) -> void:
		pass

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
	check(WINDOW.remaining_text(299.2)=="05:00" and WINDOW.remaining_text(4000.0)=="1:06:40" and WINDOW.remaining_text(-3.0)=="00:00","remaining time text")
	var host: Dictionary=_host()
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	check(window._buffs().keys()==["헤이스트","민첩 강화 물약"],"the existing combined active effects")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("UI.button(\"\",open_buff_info,") and renewal.contains("_open_original_feature(\"buff_info\")"),"the active effect row opens the original window first")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_BUFF_INFO_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and int(opened.filled.rows)==2,"Inventory_Buff_Info_All mounts one row per effect: "+str(opened).left(300))
	host.world.buffs["헤이스트"].remaining=61.0
	window._tick()
	var time: Dictionary=window._times[0]
	var node: Node2D=time.player.source_nodes.get(int(time.offset))
	check(node!=null and time.player.set_bound_text(int(time.offset),"x").get("ok",false),"the remaining time text is a live source text")
	var before: Node2D=window._scene
	host.world.buffs.erase("민첩 강화 물약")
	window._tick()
	check(window._scene!=before and int(window.last_result.filled.rows)==1,"a changed effect set rebuilds the list")
	for tab: String in ["debuff","spell"]:
		var shown: Dictionary=window._tab(tab)
		check(shown.get("handled",false) and int(shown.filled.rows)==0,tab+" tab mounts empty with its notice")
	host.world.buffs.clear()
	var empty: Dictionary=window._tab("buff")
	check(empty.get("handled",false) and int(empty.filled.rows)==0,"no effect: the 버프 notice")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
