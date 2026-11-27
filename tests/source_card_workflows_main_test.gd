extends "res://tests/source_card_fusion_review_main_test.gd"
## Installed definitions, images and UI with a fresh desktop Main save.
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const CASH = preload("res://scripts/shop/source523_cash_packages.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const PORTRAITS = preload("res://scripts/ui/source_card_presentation.gd")
const FALLBACK_REVEAL = preload("res://scripts/ui/option_awakening_reveal.gd")
const KNIGHT_PACK: int = 176972

func run() -> void:
	if OS.get_environment("TWILIGHT_CARD_WORKFLOWS_QA")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists("user://twilight_v20_save.json"):
		quit(2)
		return
	root.size=Vector2i(1280,720)
	var w: Node=load("res://Main.tscn").instantiate()
	w.set_script(FusionReviewWorld)
	root.add_child(w)
	current_scene=w
	w.set_process(false)
	if check(QA.enter_game(w,"기사"),"installed Main enters gameplay as a knight"):
		await settle()
		w.player.set_physics_process(false)
		w.field_population.set_process(false)
		w._clear_monsters()
		w._clear_drops()
		w.save_timer=-100000
		await clan_creation(w)
		for category: String in CARDS.CATEGORIES:
			await fusion_category(w,category)
		await skill_draw(w)
		await awakening_portraits(w)
	w.hud._close_workspace()
	await settle()
	w.queue_free()
	await settle()
	print("SOURCE_CARD_WORKFLOWS_MAIN_RESULT ",JSON.stringify({"checks":_checks,"failures":_errors}))
	quit(0 if _errors.is_empty() else 1)

func clan_creation(w: Node) -> void:
	w.level=45
	w.gold=500000
	w.hud.open_clan523()
	await settle()
	var ui: Node=w.hud.original_main_ui_controller
	if not check(ui.clan_window_is_open(),"authored clan window opens"):return
	var page: RefCounted=ui.clan_window()
	var editor: LineEdit=page._name_editor
	await _tap(editor)
	check(editor.has_focus(),"touch focuses the original name field")
	for glyph: int in [KEY_T, KEY_W, KEY_L]:
		var event := InputEventKey.new()
		event.pressed=true
		event.keycode=glyph
		event.unicode=glyph
		root.push_input(event,true)
	check(editor.text=="TWL","the focused editor accepts a name")
	var button: Dictionary=TREE.locate(page._scene,page._last_out,"Clan_Tab_Foundation/Btn_Foundation")
	if not check(button.get("ok",false),"authored create button is mounted"):return
	await _tap(_hit(button.player.source_nodes[button.offset]))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	check(w.clan523.has_clan() and w.gold==400000 and data.get("clan523",{}).get("name")=="TWL" and data.get("gold")==400000,
		"the focused name field permits one real touch, one debit and a persisted clan")
	w.hud._close_workspace()
	await settle()
	w.hud.open_clan523()
	check(ui.clan_window().last_result.get("joined",false) and w.gold==400000,"reopening shows the clan without charging again")
	w.hud._close_workspace()
	await settle()

func _book_quantities(w: Node) -> Dictionary:
	var totals: Dictionary={}
	for book: Dictionary in w.skill_cards523.materials():
		totals[book.card_id]=int(totals.get(book.card_id,0))+int(book.remaining)
	return totals

func skill_draw(w: Node) -> void:
	w.hud._close_workspace()
	var record: Dictionary=DROPS.variant_item(DROPS.definition_id(str(KNIGHT_PACK)).get("native_record",{}),1)
	if not check(not STACK.draw_ticket_profile(record).is_empty(),"the installed typed knight skill draw pack has an owned-item route"):return
	if w._find_catalog_item_record(str(record.name)).get("source_item_class_id",0)!=KNIGHT_PACK:
		w.catalog_db["아이템"].append(record)
		w._index_catalog_item_sources()
	if not check(INVENTORY.commit(w,[{"item_class_id":KNIGHT_PACK,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"qa_skill_draw_workflow"}),"two controlled original pack receipts enter the bag"):return
	var uid: String=""
	for key: String in w.item_instances:
		if STACK.proof(w,key).get("receipt",{}).get("item_class_id")==KNIGHT_PACK:
			uid=key
			break
	var name: String=str(record.name)
	var quote: Dictionary=w.source_shop.quote_inventory_ticket(name,{},uid)
	if not check(quote.get("ok",false) and quote.get("draw_count",0)==10,"the original knight pack quotes ten results: "+str(quote.get("reason",""))):return
	var before: Dictionary=_book_quantities(w)
	var learned: Dictionary=w.skill_cards523.export_state()
	var reference: String=name+"@@@"+uid
	w.hud.inventory_item_activated.emit(reference)
	await settle()
	var first: Control=w.hud.card_reveal_stage
	if not check(is_instance_valid(first) and first.category=="스킬 카드" and first.cards.size()==9,"real bag activation opens the first page of saved skill results"):return
	check(first.cards[0].face.artwork!=null,"the first skill result has a verified original book icon")
	var results: Array=first.results.duplicate()
	var disk: String=FileAccess.get_sha256(w.save_path())
	w.hud.inventory_item_activated.emit(reference)
	check(STACK.proof(w,uid).get("remaining")==1 and FileAccess.get_sha256(w.save_path())==disk,"trying to use another pack during reveal does not consume or save again")
	await _tap(first.cards[0].reveal_button)
	check(not first.cards[0].waiting_for_press and first.cards[1].waiting_for_press,"only the tapped card starts revealing")
	await _tap(first.board.get_node("SkipReveal"))
	first.seek(first.duration)
	await _tap(first.board.get_node("ConfirmReveal"))
	var second: Control=w.hud.card_reveal_stage
	if not check(is_instance_valid(second) and second!=first and second.cards.size()==1,"the tenth result remains available on page two"):return
	results.append_array(second.results)
	await _tap(second.cards[0].reveal_button)
	second.seek(second.duration)
	await _tap(second.board.get_node("ConfirmReveal"))
	for entry: Dictionary in results:
		var id: int=entry.source_buff_card_id
		check(CASH.skill_book_for(id)==int(entry.item_class_id) and CASH.skill_draw_allows_class(w.skill_cards523.card(id),CASH.current_class(w)),"each visible result is an exact eligible physical book")
		before[id]=int(before.get(id,0))+1
	check(not w.hud.is_card_reveal_busy() and _book_quantities(w)==before and w.skill_cards523.export_state()==learned
		and FileAccess.get_sha256(w.save_path())==disk,"the reveal neither learns, grants nor rerolls the ten books")

func awakening_portraits(w: Node) -> void:
	for category: String in CARDS.CATEGORIES:
		var shown: Dictionary={}
		for row: Dictionary in w.catalog_db[category]:
			if PORTRAITS.detail(row,true,false).get("texture") is Texture2D:
				shown=row
				break
		if not check(not shown.is_empty(),"selected pack has an exact "+category+" portrait"):continue
		for success: bool in [true,false]:
			w.hud.present_option_awakening_result(shown,{"ok":true,"success":success,"category":category},{"reduced_motion":true})
			await settle()
			if not check(w.hud.source_awakening_result_is_open(),"installed result scene mounts for "+category):continue
			await _read_result(w,success)
		var fallback: Control=FALLBACK_REVEAL.new()
		root.add_child(fallback)
		fallback.present(shown,{"success":false,"category":category},{"reduced_motion":true})
		fallback.skip_to_result()
		check(fallback.portrait.is_visible_in_tree() and fallback.portrait.texture==PORTRAITS.detail(shown,true,false).texture
			and fallback.portrait.get_rect().get_center()==fallback.center,"the alternate result also visibly mounts the exact portrait at the center")
		fallback.queue_free()
		await settle()
