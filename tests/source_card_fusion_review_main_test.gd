extends "res://tests/source_option_awakening_main_test.gd"
## Disposable installed-pack Main. Register real duplicates on the original
## fusion page and touch the original quantity and confirmation controls.
const MIX = preload("res://scripts/ui/original_ui/source_main_card_fusion_window.gd")
const REVIEW = preload("res://scripts/ui/original_ui/source_main_awakening_review.gd")
const TREE = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")

func keypad_tap(popup: RefCounted, path: String) -> void:
	var hit: Dictionary = TREE.locate(popup._scene,popup._out,path)
	if check(hit.get("ok",false),"calculator has "+path): await _tap(_hit(hit.player.source_nodes[hit.offset]))

func fusion() -> void:
	root.size=Vector2i(2048,919)
	var w: Node=load("res://Main.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	w.set_process(false)
	if not check(QA.enter_game(w),"normal Main entry"): w.queue_free(); return
	await settle()
	w.player.set_physics_process(false)
	w.field_population.set_process(false)
	w.save_timer=-100000
	var material: String=""
	for row: Dictionary in w.catalog_db["변신"]:
		if row.get("grade")=="고급" and MIX._eligible(row):
			material=CARDS.card_id(row)
			if not material.is_empty(): break
	if not check(not material.is_empty(),"installed original fusion material"): w.queue_free(); return
	w.card_draw_fusion.owned["변신"][material]=true
	var c: Node=w.hud.original_main_ui_controller
	var calls: Array[int]=[]
	w.hud.card_fusion_requested.connect(func(_category: String,_grade: String,count: int) -> void: calls.append(count))
	for count: int in [1,2]:
		w.card_draw_fusion.spare["변신"]={material:count*4}
		w._update_hud()
		w.hud.open_card_fusion("변신")
		await settle()
		var page: RefCounted=c.feature_window("card_fusion")
		if not check(is_instance_valid(page) and page.is_open(),"authored fusion page mounted"): break
		var before: Dictionary = _ledger(w)
		var rng: int = w.card_draw_fusion.rng.state
		await _tap(_hit(_node(page,MIX.P+"Nd_CardMix/Btn_Auto")))
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
		if count==1:
			await _confirm(w.hud,true)
			check(calls.is_empty() and _ledger(w)==before and w.card_draw_fusion.rng.state==rng,"cancelling single fusion preserves duplicates")
		else:
			check(box._pages[0].contains("8장"),"batch review discloses all eight materials")
			await _confirm(w.hud,false)
			check(calls==[2] and w.card_draw_fusion.rng.state!=rng and w.card_draw_fusion.owned["변신"].get(material,false),"one confirmed request executes both rolls and retains the owned card")
	w.queue_free()
	await settle()

func run() -> void:
	if OS.get_environment("TWILIGHT_FUSION_SOURCE_REVIEW")!="1": quit(2); return
	await fusion()
	print("SOURCE_CARD_FUSION_REVIEW_RESULT ",JSON.stringify({"checks":_checks,"failures":_errors}))
	quit(0 if _errors.is_empty() else 1)
