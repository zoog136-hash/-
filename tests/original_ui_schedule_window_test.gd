extends SceneTree
## The original 523 스케줄 window (source_main_schedule_window.gd) over the
## existing 자동사냥 지역 feature. Without arguments (no original files): the
## grounds come from world.auto_hunting_destinations by original category, a
## ground tap shows the existing assessment, 스케줄 시작 confirms then runs
## world.auto_hunting_move and turns AUTO on, 스케줄 중지 turns AUTO off and
## the 옵션 tab opens the existing 자동사냥 panel. Real input: -- --pack=<private
## original main UI pack directory>: Schedule_All mounts with each category.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_schedule_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePlayer extends Node:
	var auto_enabled: bool=false

class FakeWorld extends Node:
	var player: FakePlayer
	var moved: Array=[]
	func auto_hunting_destinations() -> Dictionary:
		var entries: Array=[]
		for pair: Array in [[101,11,"거친 황야","Adena"],[102,11,"풍요의 숲","Adena"],[201,1,"특수 던전","Gem"],[301,21,"하딘","Adena"]]:
			entries.append({"schedule":{"ID":pair[0],"RecommendLevel":30},"category":{"ID":pair[1]},"hunting_territory":{"Name":pair[2]},
				"destinations":[{"territory":{"Name":pair[2]},"link":{"ID":pair[0]*10}}],"teleport":{"TeleportCost":1500},"currency":{"Name":pair[3],"ID":1 if pair[3]=="Adena" else 4},"prerequisites":[]})
		return {"entries":entries}
	func auto_hunting_movement_assessment(schedule_id: int, _link: int) -> Dictionary:
		return {"ok":schedule_id!=102,"reason":"ok %d" % schedule_id if schedule_id!=102 else "입장 레벨 부족"}
	func auto_hunting_move(schedule_id: int, link: int) -> Dictionary:
		moved.append([schedule_id,link])
		return {"ok":true,"reason":"이동 완료"}

class FakeHud extends Node:
	signal auto_pressed
	var messages: Array[String]=[]
	var confirmations: Array=[]
	var routed: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null
	func open_macro_info() -> void:
		routed.append("open_macro_info")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	world.player=FakePlayer.new()
	world.add_child(world.player)
	var hud:=FakeHud.new()
	hud.auto_pressed.connect(func() -> void: world.player.auto_enabled=not world.player.auto_enabled)
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	var host: Dictionary=_host()
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	check(WINDOW.PANELS.keys()==[1,11,21] and WINDOW.ROWS.keys()==[1,11,21],"the three original working categories (SpecialDungeon, Field, Hadin)")
	window._select(102)
	check(host.hud.messages[-1]=="입장 레벨 부족","a ground tap shows the existing assessment")
	var refused: Dictionary=window._start()
	check(not refused.get("ok",true) and host.world.moved.is_empty(),"스케줄 시작 refuses a ground the world refuses")
	window._select(101)
	var started: Dictionary=window._start()
	check(started.get("ok",false) and host.world.moved==[[101,1010]] and host.world.player.auto_enabled,"스케줄 시작 confirms, moves through world.auto_hunting_move and turns AUTO on: "+str(host.world.moved))
	window._stop()
	check(not host.world.player.auto_enabled,"스케줄 중지 turns AUTO off")
	window._options()
	check(host.hud.routed==["open_macro_info"],"옵션 opens the existing 자동사냥 panel")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("\"auto\": open_schedule()") and renewal.contains("_open_original_feature(\"schedule\")"),"자동사냥 opens the original 스케줄 window first")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_SCHEDULE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	check(opened.get("handled",false) and int(opened.get("filled",{}).get("grounds",0))==2,"Schedule_All mounts with the Field grounds: "+str(opened).left(400))
	for id: int in [1,21]:
		var shown: Dictionary=window._category(id)
		check(shown.get("handled",false) and int(shown.filled.grounds)==1,"category %d mounts: %s" % [id,str(shown).left(300)])
	check(window._select(301).get("handled",false),"a selected ground mounts with 스케줄 시작")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
