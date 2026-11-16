extends SceneTree
## The original 523 수호성 찾기 window (source_main_guardian_find_window) over
## the existing pending card choice (world.growth). Without arguments (no
## original files): failed cards leave play, the cards sit centred in rows,
## and the 수호성 window opens it for a pending choice. Real input:
## -- --pack=<private original main UI pack directory>: SkillTreeRandomOpenScene
## mounts one SkillTree_Card_Default per card in play, a tap confirms the
## 수호석 cost and chooses through the existing execute, the result card shows.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_guardian_find_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeSource extends RefCounted:
	func has_node(_id: String) -> bool:
		return true

class FakeGrowth extends RefCounted:
	var state: Dictionary={"nodes":[],"pending":{"node":"slot_a","cards":5},"searches":{"slot_a":{"cards":5,"winner":2,"failed":[1,3],"attempts":2}}}
	var guardian_source=FakeSource.new()
	var executed: Array=[]
	func node(_id: String) -> Dictionary:
		return {"name":"조우의 별"}
	func quote(action: String, _id: String="", count: int=1) -> Dictionary:
		if action=="choose" and state.searches.slot_a.failed.has(count):return {"ok":false,"message":"이미 실패한 카드입니다"}
		return {"ok":true,"message":"수호석 1개 소모 · 선택한 카드 결과 확인","revision":7}
	func execute(action: String, id: String, count: int, revision: int, day: int=-1) -> Dictionary:
		executed.append([action,id,count,revision,day])
		if count==int(state.searches.slot_a.winner):state.nodes.append("slot_a")
		else:state.searches.slot_a.failed.append(count)
		state.pending={}
		return {"ok":true,"message":"수호성 찾기 실패 · 다시 도전할 수 있습니다"}

class FakeWorld extends Node:
	var growth:=FakeGrowth.new()

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmed: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, _body: String, _action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmed.append(title)
		callback.call(1)
		return null

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Dictionary=FakeGrowth.new().state
	check(WINDOW.cards_in_play(state)==[0,2,4],"failed cards leave play")
	check(WINDOW.cards_in_play({"pending":{}}).is_empty(),"nothing pending, no cards")
	var layout: Dictionary=WINDOW.card_layout(3,Vector2(1200.0,530.0))
	check(is_equal_approx(float(layout.scale),1.0) and (layout.centres[1] as Vector2).is_equal_approx(Vector2(600.0,265.0)) and is_equal_approx((layout.centres[2] as Vector2).x-(layout.centres[1] as Vector2).x,226.0),"three cards centred in one row: "+str(layout))
	var many: Dictionary=WINDOW.card_layout(12,Vector2(1200.0,530.0))
	check(float(many.scale)<1.0 and (many.centres[0] as Vector2).y>(many.centres[8] as Vector2).y,"twelve cards: two rows, scaled into the box")
	var guardian: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_guardian_window.gd")
	check(guardian.contains("try_open_feature_window(\"guardian_find\",[group])") and guardian.contains("return _find(selected,id)"),"the 수호성 window opens it for a pending choice")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_GUARDIAN_FIND_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent,"joe")
	check(opened.get("handled",false) and int(opened.get("filled",{}).get("cards",0))==3,"SkillTreeRandomOpenScene mounts the three cards in play: "+str(opened).left(300))
	var refused: Dictionary=window._pick(1)
	check(not refused.get("ok",true) and world.growth.executed.is_empty(),"a failed card is refused by the existing quote")
	var picked: Dictionary=window._pick(0)
	check(hud.confirmed==["수호성 찾기"] and world.growth.executed==[["choose","",0,7,-1]],"a tap confirms the cost and chooses through execute: "+str(world.growth.executed))
	check(window.stage=="result" and not window.won and window.is_open(),"the 실패 result shows: "+str(picked).left(200))
	var back: Dictionary=window._back()
	check(back.get("closed",false) and not window.is_open(),"without the 수호성 window, the close closes")
	await process_frame
	parent.queue_free()
	world.queue_free()
