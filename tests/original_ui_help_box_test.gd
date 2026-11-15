extends SceneTree
## The original 523 help popups (source_main_help_box.gd) of the connected
## windows. Without arguments (no original files): a pack without the help
## members fails closed and every window names its own original help member.
## Real input: -- --pack=<private original main UI pack directory>: each help
## mounts over HelpBoxLayout, pages through its Panel_N and closes.
const HELP=preload("res://scripts/ui/original_ui/source_main_help_box.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var box=HELP.new()
	check(box.configure(FakePack.new()).get("ok",false),"configures without members")
	check(not box.available(HELP.REFINE),"a pack without the help member is not available")
	var parent:=Node2D.new()
	root.add_child(parent)
	check(not box.open(parent,HELP.REFINE).get("handled",true) and not box.is_open(),"opening a missing help fails closed")
	# Each window opens its own original help.
	for pair: Array in [["source_main_refine_window.gd","HelpBox.REFINE"],["source_main_totem_window.gd","HelpBox.TOTEM"],["source_main_half_elixir_window.gd","HelpBox.ELIXIR"],["source_main_card_dispatch_window.gd","HelpBox.DISPATCH"],["source_main_title_window.gd","HelpBox.TITLE"],["source_main_dungeon_window.gd","HelpBox.ORIM"]]:
		var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/"+str(pair[0]))
		check(source.contains(str(pair[1])),"window opens its original help: "+str(pair[0]))
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir,parent)
	parent.queue_free()
	print("ORIGINAL_UI_HELP_BOX_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String, parent: Node2D) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var box=HELP.new()
	box.configure(pack)
	var pages: Dictionary={HELP.REFINE:4,HELP.TOTEM:4,HELP.ELIXIR:4,HELP.DISPATCH:6,HELP.ORIM:5,HELP.TITLE:1}
	for member: String in pages:
		var opened: Dictionary=box.open(parent,member)
		check(opened.get("handled",false) and box.is_open(),"help mounts: "+member+" "+str(opened))
		check(int(opened.get("pages",0))==int(pages[member]),"original page count: "+member+" "+str(opened.get("pages")))
		if int(pages[member])>1:
			check(int(box.step(1).get("page",0))==2,"Btn_Right shows the next page: "+member)
			check(int(box.step(99).get("page",0))==int(pages[member]),"the last page stays: "+member)
			check(int(box.step(-99).get("page",0))==1,"Btn_Left back to the first page: "+member)
		box.close()
		await process_frame
		check(not box.is_open(),"Btn_Close closes: "+member)
