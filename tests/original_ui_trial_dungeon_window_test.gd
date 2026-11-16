extends SceneTree
## The original 523 시련 던전 window (source_main_trial_dungeon_window.gd) over
## the existing Challenge feature, and the 던전 window's 시련 tab list.
## Without arguments (no original files): working Challenge rows group by
## MiniAssetID in DisplayPriority order, the group title drops the step
## number, the page's own action requests run through the HUD confirmation
## and runtime.execute("challenge", ...) with the state revision and
## fingerprint, and the 시련 던전 row routes to the window. Real input:
## -- --pack=<private original main UI pack directory>: Dungeon_Trial_All
## mounts its ThumbNail and Detail tabs, and the 던전 window's 시련 tab mounts
## Mission_Dungeon_Trial with 시련의 탑 / 시련 던전.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_trial_dungeon_window.gd")
const DUNGEON=preload("res://scripts/ui/original_ui/source_main_dungeon_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeDomain extends RefCounted:
	var _challenges: Dictionary={
		671:{"ID":671,"Name":"[시련 던전][리뉴얼] 턴 언데드 1","IsWorking":true,"MiniAssetID":394131,"DisplayPriority":9,"TimeLimit":300,"TitleDescID":0,"ScenarioDescID":0},
		681:{"ID":681,"Name":"턴 언데드 2","IsWorking":true,"MiniAssetID":394131,"DisplayPriority":9,"TimeLimit":300},
		701:{"ID":701,"Name":"미믹 처치 1","IsWorking":true,"MiniAssetID":394111,"DisplayPriority":8,"TimeLimit":60},
		5:{"ID":5,"Name":"바포메트의 봉인","IsWorking":false,"MiniAssetID":1,"DisplayPriority":99}}
	func metadata(id: int) -> Dictionary:
		return {"prerequisites":[{"PrerequisiteTypeID":1,"Value":55}] if id==681 else [],"completion_reward_ids":[1]}
	func eligibility(id: int, context: Dictionary) -> String:
		return "" if int(context.get("level",0))>=(55 if id==681 else 40) else "challenge_level"
	func _resolve_rewards(_ids: Array, _context: Dictionary) -> Dictionary:
		return {"ok":true,"rewards":[{"kind":"currency","id":1,"amount":50000},{"kind":"experience","id":0,"amount":1200}]}
	func _instant_price(_id: int, _context: Dictionary) -> Dictionary:
		return {"ok":true,"cost":{"kind":"currency","id":4,"amount":300}}

class FakeSource extends RefCounted:
	func ready() -> bool:
		return true
	func row(_table: String, _id: int) -> Dictionary:
		return {}

class FakeRuntime extends RefCounted:
	var domains: Dictionary={"challenge":FakeDomain.new()}
	var source:=FakeSource.new()
	var state: Dictionary={"revision":12,"domains":{"challenge":{"active":{}}}}
	var executed: Array=[]
	func context() -> Dictionary:
		return {"level":50,"nowUnix":1000}
	func page(_key: String) -> Dictionary:
		return {"rows":[{"id":"challenge:671","actions":[{"label":"TWILIGHT 현재 맵 실전 시작","request":{"op":"challenge_start","challenge_id":671,"local_policy":true,"retry":false}},{"label":"즉시 완료 · 다이아 ×300","request":{"op":"challenge_instant","challenge_id":671,"retry":false}}]},{"id":"challenge:681","actions":[]}]}
	func fingerprint() -> String:
		return "fp"
	func execute(key: String, request: Dictionary, revision: int, expected: String) -> Dictionary:
		executed.append([key,request,revision,expected])
		return {"ok":true}

class FakeWorld extends Node:
	var unconfirmed523:=FakeRuntime.new()
	var level: int=50

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmations: Array=[]
	var routed: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null
	func open_trial_dungeon() -> void:
		routed.append("open_trial_dungeon")

class FakeFamily extends RefCounted:
	var selected: int=-1
	func select(value: int) -> void:
		selected=value

class FakeList extends RefCounted:
	func select(_row: int) -> void:
		pass

class FakeView extends Node:
	var family:=FakeFamily.new()
	var rows: Array=[]
	var selected: int=-1
	var listing:=FakeList.new()
	func _refresh() -> void:
		pass
	func _select(_row: int) -> void:
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
	var host: Dictionary=_host()
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	var groups: Array=window.groups()
	check(groups==[{"asset":394131,"ids":[671,681]},{"asset":394111,"ids":[701]}],"working challenges group by MiniAssetID in DisplayPriority order: "+str(groups))
	check(window.group_title([671])=="[시련 던전][리뉴얼] 턴 언데드" and window.group_title([701])=="미믹 처치","the group title drops the step number")
	check(window.level(681)==55 and window.level(671)==40,"입장레벨: the source MinLevel prerequisite, else the Challenge level 40")
	window._context=host.world.unconfirmed523.context()
	window._page=host.world.unconfirmed523.page("challenge")
	check(window.actions(671).keys()==["challenge_start","challenge_instant"] and window.actions(681).is_empty(),"actions are the page's own")
	check(window.rewards(671)==[{"name":"아데나","amount":50000},{"name":"경험치","amount":1200}],"completion rewards are the domain's resolution")
	window._act(window.actions(671).challenge_start)
	var runtime: FakeRuntime=host.world.unconfirmed523
	check(runtime.executed.size()==1 and runtime.executed[0]==["challenge",{"op":"challenge_start","challenge_id":671,"local_policy":true,"retry":false},12,"fp"],"도전하기 confirms and executes the page request with revision and fingerprint: "+str(runtime.executed))
	check(not window._act({}).get("ok",true) and runtime.executed.size()==1,"no action: nothing runs")
	check(WINDOW._clock(3725)=="01:02:05","time text")
	var dungeon=DUNGEON.new()
	dungeon._hud=weakref(host.hud)
	dungeon._trial_pressed("dungeon")
	check(host.hud.routed==["open_trial_dungeon"],"the 시련 던전 row opens the window")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("func open_trial_dungeon") and renewal.contains("_open_original_feature(\"trial_dungeon\")"),"the HUD opens the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_TRIAL_DUNGEON_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	check(opened.get("handled",false) and int(opened.filled.groups)==2,"Dungeon_Trial_All mounts the ThumbNail groups: "+str(opened).left(300))
	var detail: Dictionary=window._group(0)
	check(detail.get("handled",false) and int(detail.filled.challenges)==2 and int(detail.filled.selected)==671,"the Detail tab mounts the group's challenges: "+str(detail).left(300))
	check(window._select(1).get("handled",false),"a locked challenge mounts disabled")
	check(window._back().get("handled",false),"상위 메뉴로 이동 returns to the groups")
	window.close()
	var dungeon=DUNGEON.new()
	check(dungeon.configure(pack,host.hud).get("ok",false),"the dungeon window configures")
	var view:=FakeView.new()
	host.world.add_child(view)
	dungeon._parent=weakref(parent)
	dungeon._view=weakref(view)
	var trial: Dictionary=dungeon._set_tab("tower")
	check(trial.get("handled",false) and trial.get("trial_list",false),"the 시련 tab mounts Mission_Dungeon_Trial: "+str(trial).left(300))
	dungeon.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
