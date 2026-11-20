extends SceneTree
## The original level-up presentation (source_main_level_up, Hud_LevelUp):
## it names the original Hud_LevelUp / Fx_Level_Up_Top / Fx_Level_Up_Bottom
## members and refuses a pack without them; with the 523 definition archive
## the LevelUpEffectDesc rows of a class and level come in DescOrder with
## their DescData_Korean texts; with a real UI pack
## (TWILIGHT_SOURCE_UI_PACK=<pack root holding source523_addons.json>) the
## top shows the level, the rows take the three bottom nodes one second
## apart (a fourth reuses the first) and the scene frees itself.
##   godot --headless --path <repo> --script res://tests/original_ui_level_up_test.gd
const LEVEL_UP=preload("res://scripts/ui/original_ui/source_main_level_up.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Dictionary={}

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_LEVEL_UP_FAIL: "+label)

func _initialize() -> void:_run.call_deferred()

func _run() -> void:
	var window=LEVEL_UP.new()
	check(window.required_members()==["UI/Main/Hud_LevelUp.csb","UI/Effect/Effect_Source/Fx_Level_Up_Top.csb","UI/Effect/Effect_Source/Fx_Level_Up_Bottom.csb"],"the original members are named")
	var host:=Node.new()
	root.add_child(host)
	check(not window.configure(FakePack.new(),host).get("ok",true),"a pack without Hud_LevelUp is refused")
	check(LEVEL_UP.rows_for(0,[10]).is_empty() and LEVEL_UP.rows_for(8,[]).is_empty(),"no class or no level, no rows")
	samples["definitions"]=SOURCE.problem().is_empty() and not SOURCE.not_installed() and SOURCE.row_count("LevelUpEffectDesc")>0
	if samples.definitions:_rows()
	var pack_root: String=OS.get_environment("TWILIGHT_SOURCE_UI_PACK")
	samples["real_pack"]=not pack_root.is_empty()
	if not pack_root.is_empty():await _real(pack_root,host)
	host.free()
	print("ORIGINAL_UI_LEVEL_UP_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _rows() -> void:
	# Class 8 at level 24: [능력치 향상] then [새로운 스킬] (523 tables).
	var rows: Array[Dictionary]=LEVEL_UP.rows_for(8,[24])
	samples["class8_level24"]=rows.map(func(r: Dictionary) -> String:return str(r.title))
	check(rows.size()>=2,"class 8 level 24 has guidance rows")
	var ordered: bool=true
	for index: int in range(1,rows.size()):
		if int(rows[index].level)<int(rows[index-1].level):ordered=false
	check(ordered and rows.all(func(r: Dictionary) -> bool:return int(r.level)==24 and not (str(r.title)+str(r.text)).is_empty()),"rows of that level with their texts")
	var two: Array[Dictionary]=LEVEL_UP.rows_for(8,[24,40])
	check(two.size()>rows.size() and int(two[0].level)==24 and int(two[-1].level)==40,"several levels reached keep level order")

func _real(pack_root: String, host: Node) -> void:
	PACK.bake_enabled=false
	var addons: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_root.path_join("source523_addons.json")))
	var pack=PACK.new()
	var opened: Dictionary=pack.open(pack_root.path_join("ui"),str(addons.ui.manifest_sha256))
	check(opened.get("ok",false),"the real UI pack opens")
	if not opened.get("ok",false):return
	var window=LEVEL_UP.new()
	var configured: Dictionary=window.configure(pack,host)
	samples["pack_has_level_up"]=configured.get("ok",false)
	check(configured.get("ok",false),"the real pack has Hud_LevelUp (%s)" % str(configured.get("member","")))
	if not configured.get("ok",false):return
	var parent:=Node2D.new()
	root.add_child(parent)
	var guidance: Array[Dictionary]=[]
	for index: int in range(4):guidance.append({"title":"[제목 %d]" % index,"text":"안내 %d" % index})
	var started_usec: int=Time.get_ticks_usec()
	var played: Dictionary=window.play_level_up(parent,24,guidance)
	samples["open_ms"]=float(Time.get_ticks_usec()-started_usec)/1000.0
	check(played.get("ok",false) and int(played.get("rows",0))==4,"the presentation opens (%s)" % str(played.get("code",played.get("error",""))))
	if not played.get("ok",false):
		parent.free()
		return
	var top: Dictionary=window._locate(window._scene,window._out,"Fx_Level_Up_Top/BitmapFontLabel_1")
	check(top.get("ok",false),"the top level label is bound")
	check(window.started.size()==1 and window.started[0].node=="Fx_Level_Up_Bottom_01","the first row starts at once on the first bottom node")
	var hidden: Dictionary=window._out.get("/Fx_Level_Up_Bottom_02",{})
	check(not hidden.is_empty() and not (window._scene.source_nodes.get(int(hidden.offset)) as Node2D).visible,"later bottom nodes wait hidden")
	var first: Dictionary=window._out.get("/Fx_Level_Up_Bottom_01",{})
	check(not first.is_empty() and (window._scene.source_nodes.get(int(first.offset)) as Node2D).visible,"the first bottom node is shown")
	await create_timer(1.2).timeout
	check(window.started.size()==2 and window.started[1].node=="Fx_Level_Up_Bottom_02","the second row starts a second later")
	await create_timer(2.1).timeout
	check(window.started.size()==4 and window.started[3].node=="Fx_Level_Up_Bottom_01","the fourth row reuses the first node after its clip")
	samples["started"]=window.started.duplicate(true)
	await create_timer(3.4).timeout
	await process_frame
	check(not window.is_open(),"the scene frees itself after the last clip")
	parent.free()
