extends "res://tests/source_option_awakening_main_test.gd"
## Disposable installed-pack Main. Register real duplicates on the original
## fusion page and touch the original quantity and confirmation controls.
const MIX = preload("res://scripts/ui/original_ui/source_main_card_fusion_window.gd")
const REVIEW = preload("res://scripts/ui/original_ui/source_main_awakening_review.gd")
const TREE = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")

class FusionReviewWorld extends "res://scripts/potion_feedback_world.gd":
	var fusion_requests: Array[Dictionary]=[]
	func _on_card_fusion_requested(category: String, grade: String, count: int=1, selection: Array[String]=[]) -> void:
		fusion_requests.append({"category":category,"grade":grade,"count":count,"selection":selection.duplicate()})
		super._on_card_fusion_requested(category,grade,count,selection)

func keypad_tap(popup: RefCounted, path: String) -> void:
	var hit: Dictionary = TREE.locate(popup._scene,popup._out,path)
	if check(hit.get("ok",false),"calculator has "+path): await _tap(_hit(hit.player.source_nodes[hit.offset]))

func _first_copy(page: RefCounted, suffix: String) -> Control:
	var list: Dictionary = page._list(page._scene,page._out,suffix)
	var entry: Dictionary = page._scrolls.get(list.get("key",""),{}).get("grid",{}).get("built",{}).get(0,{})
	if entry.is_empty(): return null
	var target: Dictionary = page._locate(entry.scene,entry.out,"Panel_Root/CB_Check")
	return _hit(target.player.source_nodes[target.offset]) if target.get("ok",false) else null

var _confirmed_fusion_usec: Dictionary={}

func fusion() -> void:
	root.size=Vector2i(2048,919)
	var w: Node=load("res://Main.tscn").instantiate()
	w.set_script(FusionReviewWorld)
	root.add_child(w)
	current_scene=w
	w.set_process(false)
	if not check(QA.enter_game(w),"normal Main entry"): w.queue_free(); return
	await settle()
	w.player.set_physics_process(false)
	w.field_population.set_process(false)
	w.save_timer=-100000
	for category: String in CARDS.CATEGORIES:
		await fusion_category(w,category)
	w.queue_free()
	await settle()

func fusion_category(w: Node, category: String) -> void:
	w.hud._close_workspace()
	var material: String=""
	for row: Dictionary in w.catalog_db[category]:
		if row.get("grade")=="고급" and MIX._eligible(row):
			material=CARDS.card_id(row)
			if not material.is_empty(): break
	if not check(not material.is_empty(),"installed original fusion material for "+category): return
	w.card_draw_fusion.owned[category][material]=true
	var c: Node=w.hud.original_main_ui_controller
	var calls: Array[Dictionary]=w.fusion_requests
	calls.clear()
	for count: int in ([1,2] if category=="변신" else [1]):
		w.card_draw_fusion.spare[category]={material:count*4}
		w._update_hud()
		w.hud.open_card_fusion(category)
		await settle()
		var page: RefCounted=c.feature_window("card_fusion")
		if not check(is_instance_valid(page) and page.is_open(),"authored fusion page mounted"): break
		var before: Dictionary = _ledger(w)
		var rng: int = w.card_draw_fusion.rng.state
		var roster: Node2D = _node(page,MIX.P+"Nd_CardList/ListView")
		var stage: Node2D = _node(page,MIX.P+"Nd_CardMix/Nd_Card/ListView")
		check(roster!=null and stage!=null and roster.get_global_transform_with_canvas().origin.x>stage.get_global_transform_with_canvas().origin.x,"spare cards are right of the registered cards")
		check(page.last_result.filled.cards==1 and page._registered.is_empty(),"one spendable identity on the right and an empty center")
		await _tap(_first_copy(page,MIX.P+"Nd_CardList/ListView"))
		check(page._registered==[material] and _ledger(w)==before,"a right-hand touch registers that one copy without payment")
		await _tap(_first_copy(page,MIX.P+"Nd_CardMix/Nd_Card/ListView"))
		check(page._registered.is_empty() and _ledger(w)==before,"touching the registered card removes only that one copy")
		await _tap(_hit(_node(page,MIX.P+"Nd_CardMix/Btn_Auto")))
		check(page._registered.size()==count*4 and page._registered.all(func(id: String) -> bool:return id==material),"original auto button registers exactly the available duplicate groups")
		var request: Dictionary={"category":category,"grade":"고급","count":count,"selection":page._registered.duplicate()}
		await _tap(_hit(_node(page,MIX.P+"Nd_CardMix/Btn_Merge")))
		if count==2:
			var keypad: RefCounted=c.drop_confirm_popup()
			if not check(is_instance_valid(keypad) and keypad.is_open() and keypad.last_result.get("member")==keypad.KEYPAD,"batch opens Common_Calculator"): break
			await keypad_tap(keypad,"Btn_Cancel")
			check(calls.is_empty() and _ledger(w)==before and w.card_draw_fusion.rng.state==rng,"cancelling quantity preserves cards and RNG")
			await _tap(_hit(_node(page,MIX.P+"Nd_CardMix/Btn_Merge")))
			await keypad_tap(keypad,"Btn_Max")
			check(keypad.count()==2,"maximum follows available duplicates")
			await keypad_tap(keypad,"Btn_Select")
		var box: Node = w.hud.get_node_or_null("Root/TwilightConfirmation")
		if not check(is_instance_valid(box) and box.get_script()==REVIEW,"original Common_MessageBox for the selected quantity"): break
		check(calls.is_empty() and _ledger(w)==before and w.card_draw_fusion.rng.state==rng,"opening the review never rolls or pays")
		if count==1 and category=="변신":
			await _confirm(w.hud,true)
			check(calls.is_empty() and _ledger(w)==before and w.card_draw_fusion.rng.state==rng,"cancelling single fusion preserves duplicates")
			check(w._save_game(true)==OK,"isolated fusion balance is on disk before testing a refused save")
			await _tap(_hit(_node(page,MIX.P+"Nd_CardMix/Btn_Merge")))
			var disk: String=FileAccess.get_sha256(w.save_path())
			w.source_save_blocked=true
			await _confirm(w.hud,false)
			w.source_save_blocked=false
			check(calls==[request] and _ledger(w)==before and disk.length()==64 and FileAccess.get_sha256(w.save_path())==disk,"refused save restores the exact cards, RNG and disk bytes")
			check(page.is_open() and page._scene.is_visible_in_tree() and not w.hud.is_card_reveal_busy(),"a rejected commit leaves the fusion form operable")
			calls.clear()
		else:
			if count==2: check(box._pages[0].contains("8장"),"batch review discloses all eight materials")
			var setup: Node2D=page._scene
			await _confirm(w.hud,false)
			_confirmed_fusion_usec[category]=_touch_usec.back()
			check(calls==[request] and w.card_draw_fusion.rng.state!=rng and w.card_draw_fusion.owned[category].get(material,false),"one confirmed request executes the registered rolls and retains the owned card")
			var reveal: RefCounted=c.feature_window("fusion_result")
			if check(reveal!=null and reveal.is_open(),"original saved fusion results are presented"):
				check(reveal.results.size()==count,"the overlay presents one card per committed roll")
				for index: int in range(reveal.results.size()):
					check(not reveal.is_revealed(index),"the committed result waits for its card tap")
				check(page._scene==setup and not setup.is_visible_in_tree() and page._covered_by_reveal,"committed ownership does not rebuild the covered setup")
				var committed: Dictionary=_ledger(w)
				await _tap(_hit(_node(reveal,"Nd_ButtonSet/Btn_Open")))
				for frame: int in range(reveal.PER_PAGE+2):await process_frame
				for index: int in range(reveal.results.size()):
					check(reveal.is_revealed(index) or reveal._opening.has(index),"actual Main routes the native Open All button to each committed result")
				await _tap(_hit(_node(reveal,"Nd_TopMenu/Btn_Close")))
				check(not reveal.is_open(),"actual Main routes the native Close button to the result overlay")
				if reveal.is_open():reveal.close()
				await settle()
				check(page.is_open() and page._scene!=setup and page._scene.is_visible_in_tree() and page.last_result.filled.registered==0,"dismissing results refreshes the setup from the committed cards")
				check(_ledger(w)==committed,"dismissal cannot roll or consume again")

func run() -> void:
	if OS.get_environment("TWILIGHT_FUSION_SOURCE_REVIEW")!="1": quit(2); return
	await fusion()
	print("SOURCE_CARD_FUSION_REVIEW_RESULT ",JSON.stringify({"checks":_checks,"failures":_errors,"confirm_release_usec":_confirmed_fusion_usec}))
	quit(0 if _errors.is_empty() else 1)
