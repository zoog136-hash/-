extends SceneTree
## The original boss overhead mark (source_main_boss_overhead): with the
## 523 definition archive a boss NPC's UIBossNpcClass row names its
## UIBossNpcOverhead node and an ordinary NPC has none; with a real UI pack
## (TWILIGHT_SOURCE_UI_PACK=<pack root holding source523_addons.json>) the
## mark shows only that Nd_Level node through its Fx_On clip and keeps it
## while Fx_Loop repeats, and takes no touch (Btn_Icon out of scope).
## Without the member the mark is refused.
##   godot --headless --path <repo> --script res://tests/original_ui_boss_overhead_test.gd
const OVERHEAD=preload("res://scripts/ui/original_ui/source_main_boss_overhead.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Dictionary={}

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_BOSS_OVERHEAD_FAIL: "+label)
	return ok

func _initialize() -> void:_run.call_deferred()

func _run() -> void:
	check(not OVERHEAD.build(FakePack.new(),"Nd_Level_0").get("ok",true),"a pack without the boss card is refused")
	check(OVERHEAD.resource_name(-1)=="","no NPC, no mark")
	samples["definitions"]=SOURCE.problem().is_empty() and not SOURCE.not_installed() and SOURCE.row_count("UIBossNpcClass")>0
	if samples.definitions:
		# 523 UIBossNpcClass: 79142 -> 21 (Nd_Level_2); 301 -> 0 (none).
		check(OVERHEAD.resource_name(79142)=="Nd_Level_2","a boss NPC names its original mark")
		check(OVERHEAD.resource_name(301)=="","an NPC with overhead 0 has none")
		var kinds: Dictionary={}
		for row: Dictionary in SOURCE.rows("UIBossNpcClass"):
			var name: String=OVERHEAD.resource_name(int(row.NpcClassID))
			if not name.is_empty():kinds[name]=int(kinds.get(name,0))+1
		samples["marks"]=kinds
		check(kinds.size()==4,"all four original marks are reachable (%s)" % str(kinds))
	var pack_root: String=OS.get_environment("TWILIGHT_SOURCE_UI_PACK")
	samples["real_pack"]=not pack_root.is_empty()
	if not pack_root.is_empty():await _real(pack_root)
	print("ORIGINAL_UI_BOSS_OVERHEAD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _controls(node: Node) -> int:
	var count: int=1 if node is Control and (node as Control).mouse_filter!=Control.MOUSE_FILTER_IGNORE else 0
	for child: Node in node.get_children():count+=_controls(child)
	return count

func _real(pack_root: String) -> void:
	PACK.bake_enabled=false
	var addons: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_root.path_join("source523_addons.json")))
	var pack=PACK.new()
	var opened: Dictionary=pack.open(pack_root.path_join("ui"),str(addons.ui.manifest_sha256))
	check(opened.get("ok",false),"the real UI pack opens")
	if not opened.get("ok",false):return
	var host:=Node2D.new()
	root.add_child(host)
	for level: String in OVERHEAD.LEVELS:
		var built: Dictionary=OVERHEAD.build(pack,level)
		if not check(built.get("ok",false),level+" builds (%s)" % str(built.get("code",built.get("error","")))):continue
		host.add_child(built.scene)
		check(OVERHEAD.shown_levels(built.scene,built.out)==[level],level+": only its node is shown at the start")
		check(_controls(built.scene)==0,level+": the mark takes no touch")
	await create_timer(0.5).timeout
	for scene: Node in host.get_children():
		var status: Dictionary=scene.playback_status()
		check(status.clip=="Fx_Loop" and status.playing and status.loop,"after Fx_On the mark loops Fx_Loop")
	var built: Dictionary=OVERHEAD.build(pack,"Nd_Level_3")
	if built.get("ok",false):
		host.add_child(built.scene)
		await create_timer(1.5).timeout
		check(OVERHEAD.shown_levels(built.scene,built.out)==["Nd_Level_3"],"the chosen node stays the only one while looping")
	host.free()
