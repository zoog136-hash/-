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
		if grade_id not in [-1,1]:return []
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
		if attempt and after<100:return {"ok":false,"reason":"경험치가 부족합니다","probability_percent":66.7}
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

class LargeWorld extends FakeWorld:
	const COUNT: int=289
	var last_remaining: int=2
	func skill_card523_deck() -> Array:
		var cards: Array=super.skill_card523_deck()
		for i: int in COUNT-1:
			cards.append({"card_id":5000+i,"name":"스킬 카드 %d" % i,"grade_id":1,"spell_class_id":0,
				"level":2,"max_level":3,"exp":42,"required_exp":100,"enhanceable":true,"stage_descriptions":{}})
		return cards
	func skill_card523_materials(id: int=-1) -> Array:
		var books: Array=[]
		if id in [-1,1]:
			for i: int in COUNT:
				books.append({"physical_id":"book-%d" % i,"name":"스킬서 %d" % i,"grade_id":1,"remaining":last_remaining if i==COUNT-1 else 2})
		return books

class CheckedWindow extends WINDOW:
	var slots_before_failure: int=-1
	func _scene_of(member: String, spec: Dictionary, out: Dictionary, list_key: String="") -> Dictionary:
		if member==SLOT:
			if slots_before_failure==0:return {"ok":false,"code":"fixture_source_slot_read_failed"}
			if slots_before_failure>0:slots_before_failure-=1
		return super._scene_of(member,spec,out,list_key)

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
	window._enchant_probability()
	check(host.hud.messages[-1].contains("Lv.1 → Lv.2 강화 성공 확률 66.7%"),"성공 확률 shows the quote's chance: "+host.hud.messages[-1])
	var books: Array=[{"name":"B","remaining":2},{"name":"A","remaining":5},{"name":"C","remaining":2}]
	check(WINDOW.ordered_books(books,0)==books and WINDOW.ordered_books(books,1).map(func(e: Dictionary) -> String:return e.name)==["A","B","C"] and WINDOW.ordered_books(books,2).map(func(e: Dictionary) -> String:return e.name)==["A","B","C"],"the popup's book orders")
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
	parent.position=Vector2(0,675)
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
	await _large_grid(pack,parent)
	await process_frame
	parent.queue_free()
	host.world.queue_free()

func _large_grid(pack: RefCounted, parent: Node2D) -> void:
	var world:=LargeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var window:=CheckedWindow.new()
	window.configure(pack,hud)
	var opened: Dictionary=window.open(parent)
	if not opened.get("ok",false):
		check(false,"large skill grid opens: "+str(opened))
		world.queue_free()
		return
	var key: String=_grid_key(window)
	var state: Dictionary=window._scrolls[key]
	var mounted: Dictionary=state.mounted
	var capacity: int=(ceili(state.size.y/state.pitch)+3)*WINDOW.GRID_COLUMNS
	check(opened.filled.cards==LargeWorld.COUNT and mounted.size()<=capacity and opened.filled.icons==0,"missing optional pictures keep a bounded grid with the full card count")
	var extent: Vector2=state.geometry.size
	check(is_equal_approx(mounted[3].position.x-mounted[0].position.x,3.0*(extent.x+state.gap))
		and is_equal_approx(mounted[4].position.y-mounted[0].position.y,state.pitch),
		"the original slot size and gap still place four cards per row")
	await process_frame
	var first_slot: Node2D=mounted[0]
	var root_scene: Node2D=window._scene
	_touch_slot(window,first_slot)
	await process_frame
	check(window.selected==0 and window._scene==root_scene and mounted[0]==first_slot,"tap updates the detail without rebuilding the window or slot")
	var title: String=WINDOW.SKILL_DETAIL+"/Nd_Detail/Nd_Title/Label_Skill"
	check(_label_text(window,title)=="아이스 스파이크","the authored detail displays the selected card name")
	var old_nodes: Dictionary=mounted.duplicate()
	window.slots_before_failure=1
	window._scroll_to(key,state.min)
	check(state.value==0 and state.content.position.y==0 and mounted==old_nodes and state.content.get_child_count()==mounted.size(),"failure after one prepared slot preserves the old scroll and rows")
	window.slots_before_failure=-1
	_touch_slot(window,first_slot,float(state.min))
	await process_frame
	check(window.selected==0 and state.value==state.min and not mounted.has(0),"fast drag reaches the bottom and releases the old hit control without selecting a card")
	var last: int=LargeWorld.COUNT-1
	check(mounted.has(last) and state.content.get_child_count()==mounted.size() and mounted.size()<=capacity,"bottom includes the partial last row without retaining offscreen scenes")
	if not mounted.has(last):
		window.close()
		world.queue_free()
		return
	var last_slot: Node2D=mounted[last]
	_touch_slot(window,last_slot)
	await process_frame
	check(window.selected==last and window._scene==root_scene and mounted[last]==last_slot and state.value==state.min,"last card can be tapped without resetting the window or scroll")
	check(_label_text(window,title)=="스킬 카드 287","last card binds the correct detail rather than the local slot index")
	for i: int in 4:
		window._scroll_to(key,0.0)
		window._scroll_to(key,state.min)
	check(mounted.size()<=capacity and mounted.has(last) and window.selected==last,"quick round trips keep scenes bounded and preserve selection")
	var compose: Dictionary=window._tab("compose")
	var compose_key: String=_grid_key(window)
	var compose_state: Dictionary=window._scrolls[compose_key]
	check(compose.get("ok",false) and compose.filled.cards==LargeWorld.COUNT and compose_state.mounted.size()<=capacity,"large compose material grid is also bounded")
	window._scroll_to(compose_key,compose_state.min)
	var compose_root: Node2D=window._scene
	var material_slot: Node2D=compose_state.mounted[last]
	_touch_slot(window,compose_state.mounted[last])
	await process_frame
	var rebuilt: Dictionary=window._scrolls[compose_key]
	check(window.registered=={"book-288":1} and rebuilt.value==compose_state.min and rebuilt.mounted.has(last),"last material touch registers the correct physical book and preserves compose scroll")
	_touch_slot(window,material_slot)
	await process_frame
	var disabled: Node2D=material_slot.get_meta("compose_disabled")
	check(window._scene==compose_root and rebuilt.mounted[last]==material_slot and window.registered=={"book-288":2} and disabled.visible,
		"registering the second copy keeps the material scene and updates its disabled state")
	check(_label_text(window,WINDOW.COMPOSE_INFO+"Label_Title")=="등록한 카드 2 / 8","the original compose title updates in place")
	window.slots_before_failure=0
	check(not window._unregister("book-288").get("ok",false) and window.registered=={"book-288":2} and window._scrolls[compose_key]==rebuilt and disabled.visible,
		"failed compose refresh keeps the visible rows and registered material")
	window.slots_before_failure=-1
	var registered: Dictionary=window._list(window._scene,window._out,WINDOW.REGISTERED_LIST)
	_touch_slot(window,registered.content.get_child(0))
	await process_frame
	check(window._scene==compose_root and window.registered=={"book-288":1} and not disabled.visible,"registered slot touch releases a copy and keeps the material grid")
	world.last_remaining=3
	window._slot_tap(last)
	check(window._scene!=compose_root and window._scrolls[compose_key].value==compose_state.min and window.registered=={"book-288":2},
		"changed inventory refreshes the authoritative material list at the saved scroll position")
	window._tab("skill")
	state=window._scrolls[key]
	check(state.value==state.min and state.mounted.has(last) and window.selected==last and _label_text(window,title)=="스킬 카드 287","returning from compose restores the skill selection and scroll")
	window._grade(4)
	check(window._scrolls[key].value==0 and window._scrolls[key].mounted.size()==1 and window.selected==-1,"a different grade starts at its own scroll position")
	window._grade(1)
	state=window._scrolls[key]
	check(state.min<0 and state.value==state.min and state.mounted.has(last),"filter re-entry restores its earlier scroll and the final card")
	window.close()
	world.queue_free()

func _grid_key(window: RefCounted) -> String:
	for key: String in window._scrolls:
		if window._scrolls[key].has("skill_grid"):return key
	return ""

func _label_text(window: RefCounted, suffix: String) -> String:
	var found: Dictionary=window._locate(window._scene,window._out,suffix)
	var node: Node=found.player.source_nodes.get(found.offset)
	return str(node.get_meta("source_text").original_options.text)

func _touch_slot(window: RefCounted, scene: Node2D, drag: float=0.0) -> void:
	var out: Dictionary={}
	window._bind(WINDOW.SLOT,"",[],{},out)
	var located: Dictionary=window._locate(scene,out,"Panel/Panel_Slot")
	var node: Node=located.player.source_nodes.get(located.offset)
	var control: Control=node.get_node("SourceContentOrigin/OriginalSourceInput")
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*0.5)
	var touch:=InputEventScreenTouch.new()
	touch.position=point
	touch.pressed=true
	root.push_input(touch,true)
	if drag!=0.0:
		var movement:=InputEventScreenDrag.new()
		movement.position=point+Vector2(0,drag)
		movement.relative.y=drag
		root.push_input(movement,true)
	touch.position=point+Vector2(0,drag)
	touch.pressed=false
	root.push_input(touch,true)
