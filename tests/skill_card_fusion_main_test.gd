extends "res://tests/native_skill_coupon_main_test.gd"
## Actual Main, original compose/confirm/result controls, and the real save.
const SKILL_WINDOW=preload("res://scripts/ui/original_ui/source_main_skill_card_window.gd")

func run() -> void:
	var archive: String=OS.get_environment("TWILIGHT_SKILL_COUPON_DEFINITIONS")
	if not archive.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated save"):
		root.size=Vector2i(2048,919)
		w=load("res://Main.tscn").instantiate()
		root.add_child(w);w.set_process(false);w.save_timer=-100000
		if ck(QA.enter_game(w,"마법사"),"actual mage Main"):
			await process_frame
			w.field_population.set_process(false);w.player.set_physics_process(false)
			await fusion(archive)
			w.hud._close_workspace()
			await process_frame
		w.queue_free()
		await process_frame
	print("SKILL_CARD_FUSION_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func tap(control: Control) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=14;event.pressed=pressed
		event.position=control.get_global_transform_with_canvas()*(control.size*0.5)
		root.push_input(event,true)

func press(window: RefCounted, suffix: String) -> bool:
	var located: Dictionary=window._locate(window._scene,window._out,suffix)
	if not ck(located.get("ok",false),"authored control: "+suffix):return false
	var widget: Node2D=located.player.source_nodes[located.offset]
	var button: Control=widget.get_meta("source_button")._input_area
	if not ck(is_instance_valid(button) and button.is_visible_in_tree(),"visible input: "+suffix):return false
	tap(button)
	return true

func review() -> Variant:
	return w.hud.get_node_or_null("Root/TwilightConfirmation")

func opaque_caption(window: RefCounted, expected: String) -> bool:
	var located: Dictionary=window._locate(window._scene,window._out,SKILL_WINDOW.COMPOSE_INFO+"Nd_Card")
	if not located.get("ok",false):return false
	var host: Node2D=located.player.source_nodes[located.offset]
	for scene: Node in host.get_children():
		if scene.get("source_member")!=SKILL_WINDOW.FUSION_CARD:continue
		for frame: int in range(30):
			if not scene.playback_status().playing:break
			await process_frame
		for node: Node2D in scene.source_nodes.values():
			var label: Variant=node.get_meta("source_text",null)
			if is_instance_valid(label) and label.is_visible_in_tree() and label.original_options.text==expected:
				return label.modulate.a>=0.99
	return false

func accept_review() -> void:
	var dialog: Variant=review()
	var count: int=0
	while is_instance_valid(dialog) and not dialog.is_queued_for_deletion() and count<8:
		tap(dialog.confirm_button)
		count+=1
		await process_frame
	ck(count>0 and review()==null,"actual confirmation pages complete")

func reveal_fusion(window: RefCounted) -> void:
	var sealed: Dictionary=window.last_result.get("filled",{}).get("fusion_result",{})
	ck(not sealed.get("revealed",true) and not sealed.has("caption"),"commit mounts the card back without disclosing the result")
	var card: Node2D=window._scene.find_child("SkillFusionResultCard",true,false)
	if not ck(card!=null and card.source_nodes.has(1644),"original skill result has its own card button"):return
	var button: Control=card.source_nodes[1644].get_meta("source_button")._input_area
	if not ck(button.is_visible_in_tree(),"closed skill result can be tapped"):return
	tap(button)
	await create_timer(1.3).timeout
	ck(window.last_result.filled.fusion_result.get("revealed",false),"actual card tap reveals the committed skill result")

func fusion(archive: String) -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive);RAW.reset()
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	if not ck(RAW.identity().get("source_sha256")==RAW.SOURCE_SHA and w.tj_coupons.load_default_source(),"verified fusion and TJ definitions"):return
	var books: Dictionary=w.skill_cards523._book_items()
	if not ck(books.has(14991),"original ice spike book"):return
	var input: int=books[14991]
	register(input)
	var candidates: Array=w.skill_cards523.merge_candidates(4)
	for card: Dictionary in candidates:register(int(card.item_class_id))
	w._index_catalog_item_sources()
	var staged: Dictionary=INV.stage(w,[{"item_class_id":input,"amount":24,"bless_raw":1,"enchant":0}],
		{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not ck(staged.get("ok",false) and w._save_game(true,staged.overrides)==OK,"24 exact physical books saved"):return
	w.inventory=staged.overrides.inventory;w.item_instances=staged.overrides.item_instances
	var book_uid: String=uid_of(input)
	var hud: Node=w.hud
	hud.open_skill_cards()
	await process_frame
	var window: Variant=hud.original_main_ui_controller._feature_windows.get("skill_cards")
	if not ck(window!=null and window.is_open(),"real HUD opens the authored skill card window"):return
	if not press(window,"Nd_SkillCard_Tab/Btn_Compose_Off"):return
	var name: String=str(w.item_instances[book_uid].name)
	w.ui_preferences.item_locks[name+"@@@"+book_uid]=true
	var locked: Dictionary=window._slot_tap(0,{"physical_id":book_uid})
	ck(locked.get("code")=="source_skill_card_material_locked" and window.registered.is_empty(),"a locked physical book cannot register")
	w.ui_preferences.item_locks.erase(name+"@@@"+book_uid)
	if not press(window,SKILL_WINDOW.COMPOSE_INFO+"Btn_Auto"):return
	if not ck(window.registered=={book_uid:8},"AUTO registration uses the original eight-card rule"):return
	var compose_button: String=SKILL_WINDOW.COMPOSE_INFO+"Btn_Compose"
	var durable: String=FileAccess.get_sha256(w.save_path())
	if not press(window,compose_button):return
	var dialog: Variant=review()
	if not ck(is_instance_valid(dialog),"synthesis opens a review"):return
	tap(dialog.cancel_button);await process_frame
	ck(review()==null and FileAccess.get_sha256(w.save_path())==durable and STACK.proof(w,book_uid).get("remaining")==24,"cancellation preserves both materials and save")

	var rng_before: int=seed_for(false,10000)
	w.skill_cards523.rng.state=rng_before
	w.equipment_collections.test_save_writer=refuse
	if not press(window,compose_button):return
	ck(window.refresh().get("ok",false),"repaint while the review is open keeps the quote usable")
	await accept_review()
	w.equipment_collections.test_save_writer=Callable()
	ck(not rejected.is_empty() and window._fusion_result.is_empty() and STACK.proof(w,book_uid).get("remaining")==24
		and w.skill_cards523.rng.state==rng_before and FileAccess.get_sha256(w.save_path())==durable,"refused write never presents or consumes the staged result")
	if not press(window,compose_button):return
	await accept_review()
	await reveal_fusion(window)
	var failure: Dictionary=window.last_result.get("filled",{}).get("fusion_result",{})
	ck(failure.get("member")==SKILL_WINDOW.FUSION_CARD and failure.get("success",true)==false and failure.get("caption")=="재료 8장 소멸","committed failure displays the authored result panel")
	ck(await opaque_caption(window,"재료 8장 소멸"),"actual failure label remains visible and opaque")
	ck(STACK.proof(w,book_uid).get("remaining")==16 and w.tj_coupons.core.state.history.size()==1,"failure spends eight and records one TJ history")
	if not press(window,compose_button):return
	ck(window._fusion_result.is_empty() and STACK.proof(w,book_uid).get("remaining")==16,"result confirmation returns to compose without another attempt")

	if not press(window,SKILL_WINDOW.COMPOSE_INFO+"Btn_Auto"):return
	w.skill_cards523.rng.state=seed_for(true,10000)
	if not press(window,compose_button):return
	await accept_review()
	await reveal_fusion(window)
	var result: Dictionary=window._fusion_result
	if not ck(result.get("success",false) and result.get("result",{}).get("spell_class_id",0)>0,"committed success resolves the actual awarded spell"):return
	var shown: Dictionary=window.last_result.get("filled",{}).get("fusion_result",{})
	var card: Dictionary=result.result
	ck(shown.get("member")==SKILL_WINDOW.FUSION_CARD and shown.get("caption")==card.name,"original result presents the actual card name")
	ck(await opaque_caption(window,str(card.name)),"the result animation settles on the opaque original card label")
	if OS.has_environment("TWILIGHT_SOURCE523_IMAGES"):
		ck(window.last_result.filled.get("result_icon",false),"verified original spell or awarded item icon is mounted")
	ck(STACK.proof(w,book_uid).get("remaining")==8 and uid_of(int(card.item_class_id))==card.physical_id,"success spends eight and yields exactly the verified physical reward")
	w._load_game(true)
	ck(STACK.proof(w,book_uid).get("remaining")==8 and uid_of(int(card.item_class_id))==card.physical_id and w.tj_coupons.core.state.history.size()==1,"restart preserves both outcomes and the failure ledger")
