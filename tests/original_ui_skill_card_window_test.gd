extends SceneTree
## The original 523 스킬카드 window (source_main_skill_card_window.gd) over the
## existing skill card deck 41 feature (world.skill_card523_*). Without
## arguments (no original files): the grade text, compose registration and
## its limit, 카드 자동 등록 through the feature's own pick, 합 성 and 강화
## through quote -> confirmation -> execute with the quote's token, the feed
## toggles and the menu entry. Real input: -- --pack=<private original main
## UI pack directory>: SkillCard_All mounts its 스킬 and 합성 tabs and the
## SkillCard_Popup_Enchant popup.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_skill_card_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeWorld extends Node:
	var item_instances: Dictionary={}
	var calls: Array=[]
	func skill_card523_deck() -> Array:
		return [{"card_id":4101,"name":"아이스 스파이크","grade_id":1,"grade":"일반","spell_class_id":0,"level":1,"max_level":3,"exp":20,"required_exp":100,"enhanceable":true,"stage_descriptions":{1:"피해 +5"}},
			{"card_id":4401,"name":"헬 사이드","grade_id":4,"grade":"영웅","spell_class_id":0,"level":3,"max_level":3,"exp":0,"required_exp":0,"enhanceable":false,"stage_descriptions":{}}]
	func skill_card523_materials(grade_id: int=-1) -> Array:
		if grade_id!=1:return []
		return [{"physical_id":"b1","name":"스킬서 A","card_id":4102,"card_name":"A","grade_id":1,"grade":"일반","remaining":5,"locked":false},
			{"physical_id":"b2","name":"스킬서 B","card_id":4103,"card_name":"B","grade_id":1,"grade":"일반","remaining":4,"locked":false}]
	func skill_card523_merge_quote(grade_id: int, selection: Dictionary={}) -> Dictionary:
		calls.append(["merge_quote",grade_id,selection.duplicate()])
		var picked: Array=[{"physical_id":"b1","quantity":5},{"physical_id":"b2","quantity":3}] if selection.is_empty() else []
		return {"ok":true,"token":"m%d" % calls.size(),"grade_id":grade_id,"source_amount":8,"probability_percent":1.0,"materials":picked}
	func skill_card523_merge_execute(token: String) -> Dictionary:
		calls.append(["merge_execute",token])
		return {"ok":true,"success":false,"result":{}}
	func skill_card523_levelup_quote(card_id: int, feed: Dictionary={}, attempt: bool=true) -> Dictionary:
		calls.append(["levelup_quote",card_id,feed.duplicate(),attempt])
		var fed: int=0
		for key: String in feed:fed+=int(feed[key])*20
		var after: int=mini(100,20+fed)
		if attempt and after<100:return {"ok":false,"reason":"경험치가 부족합니다"}
		return {"ok":true,"token":"l%d" % calls.size(),"name":"아이스 스파이크","level":1,"exp":20,"exp_after_feed":after,"required_exp":100,"probability_percent":66.7,"attempt":attempt and after>=100,"cost":{"amount":100000*(1+fed/20)},"wasted_exp":0}
	func skill_card523_levelup_execute(token: String) -> Dictionary:
		calls.append(["levelup_execute",token])
		return {"ok":true,"message":"강화 성공"}

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmations: Array=[]
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null

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
	check(WINDOW.grade_text(4)=="영 웅" and WINDOW.percent_text(66.7)=="66.7%" and WINDOW.percent_text(1.0)=="1%","grade and percent texts")
	var host: Dictionary=_host()
	var world: FakeWorld=host.world
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	window.tab="compose"
	window.compose_grade=1
	for i: int in range(9):window._slot_tap(0 if i<5 else 1)
	check(window.registered=={"b1":5,"b2":3},"registration stops at each book's count and the merge amount: "+str(window.registered))
	window._unregister("b2")
	check(window.registered=={"b1":5,"b2":2},"a registered card taps out")
	window._auto_register()
	check(window.registered=={"b1":5,"b2":3},"카드 자동 등록 takes the feature's own pick")
	window._merge()
	check(world.calls[-1][0]=="merge_execute" and str(world.calls[-1][1]).begins_with("m") and host.hud.confirmations[-1][1].contains("성공 확률 1%") and window.registered.is_empty(),"합 성 confirms and executes the quote token: "+str(world.calls.slice(-2)))
	window.tab="skill"
	window.grade=1
	window.selected=0
	window._enchant()
	check(window.tab=="enchant","스킬 강화 opens the enchant popup")
	window._toggle_feed("b1",5)
	window._toggle_feed("b1",5)
	check(window.feed=={"b1":2},"a tap adds one book")
	window._levelup()
	check(world.calls[-1]==["levelup_execute","l%d" % (world.calls.size()-1)] and world.calls[-2][3]==false and host.hud.confirmations[-1][1].contains("카드 먹이기만"),"short of the gauge: feed only through the confirmation: "+str(world.calls.slice(-3)))
	window._auto_feed()
	check(window.feed=={"b1":4},"자동 선택 fills the gauge: "+str(window.feed))
	window._levelup()
	check(host.hud.confirmations[-1][1].contains("강화 시도 (성공 확률 66.7%)"),"a full gauge tries the enhancement")
	window._clear_feed()
	check(window.feed.is_empty(),"취소 clears the books")
	window.selected=0
	window.grade=4
	window.tab="skill"
	check(not window._enchant().get("ok",true) and host.hud.messages[-1]=="최고 강화 단계입니다","a maxed card stays on MAX")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("[\"skill_card523\",\"스킬 카드\"]") and renewal.contains("_open_original_feature(\"skill_cards\")"),"the menu opens the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_SKILL_CARD_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	check(opened.get("handled",false) and int(opened.filled.cards)==1,"SkillCard_All 스킬 tab mounts the learned cards: "+str(opened).left(300))
	check(window._slot_tap(0).get("handled",false),"a card shows its info")
	var popup: Dictionary=window._enchant()
	check(popup.get("handled",false) and popup.member==WINDOW.POPUP and int(popup.filled.page_books)==2,"SkillCard_Popup_Enchant mounts with the books: "+str(popup).left(300))
	check(window._toggle_feed("b1",5).get("handled",false),"a fed book mounts")
	check(window._tab("skill").get("handled",false),"closing the popup returns to the 스킬 tab")
	var compose: Dictionary=window._tab("compose")
	check(compose.get("handled",false) and int(compose.filled.cards)==2,"the 합성 tab mounts the books: "+str(compose).left(300))
	var auto: Dictionary=window._auto_register()
	check(auto.get("handled",false) and int(auto.filled.registered)==8,"카드 자동 등록 mounts the registered cards")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
