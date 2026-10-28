extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);print("SELECTION SHEET FAIL ",message)
func frames() -> void:
	for i: int in range(6):await process_frame
func touch(point: Vector2,index: int,down: bool) -> void:
	var event:=InputEventScreenTouch.new();event.position=point;event.index=index;event.pressed=down;root.push_input(event,true)
func tap(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	touch(point,83,true);touch(point,83,false)
func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);await frames()
	check(QA.enter_game(world),"class selection")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	world._update_hud()
	var hud: Node=world.hud
	var inventory_before: Dictionary=world.inventory.duplicate(true)
	var gold_before: int=world.gold
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		hud.open_shop();await frames()
		var shop: Control=hud.workspace.content.get_child(0)
		shop.purchase_quantity.value=3;await frames()
		check(shop.selection_sheet.title.text==str(shop.selected[0]),"shop picture header follows selected offer")
		check(shop.selection_sheet.total.text==str(int(shop.selected[1])*3)+" 아데나","pinned total follows original quantity and price")
		check(shop.selection_sheet.picture.texture!=null,"real item picture is connected")
		tap(shop.purchase);await frames()
		var confirm: Control=hud.get_node_or_null("Root/TwilightConfirmation")
		check(confirm!=null,"native purchase still enters the existing confirmation")
		if confirm!=null:tap(confirm.cancel_button);await frames()
		shop.search_field.text="__NO_OFFER__";shop.search_field.text_changed.emit(shop.search_field.text);await frames()
		check(shop.selection_sheet.picture.texture==null and shop.selection_sheet.total.text=="—" and shop.purchase.disabled,"empty offer clears image and amount")
		hud.open_skills();await frames()
		var view: Control=hud.skills_view
		var index: int=-1
		for i: int in range(view.filtered.size()):
			if str(view.filtered[i].name)=="에너지 볼트":index=i;break
		check(index>=0,"existing common spell fixture")
		if index<0:continue
		view.select(index)
		var browser: Control=view.cards.get_parent().get_parent();browser.detail_active=true;browser.reflow();await frames()
		var sheet: Control=view.selection_sheet
		check(sheet.title.text==str(view.selected.name) and sheet.picture.texture==view.cards.get_item_icon(index),"programmatic selection keeps the exact spell and icon even before the list selection changes")
		check(view.use_button.is_visible_in_tree() and not view.learn_button.is_visible_in_tree(),"learned spell exposes use and quickslot actions")
		check(sheet.scroll.size.y>=80,"short screen retains a usable information swipe area")
		if sheet.scroll.get_v_scroll_bar().max_value>sheet.scroll.get_v_scroll_bar().page:
			var point: Vector2=sheet.scroll.get_global_transform_with_canvas()*(sheet.scroll.size*.5)
			touch(point,84,true)
			var drag:=InputEventScreenDrag.new();drag.index=84;drag.position=point+Vector2(0,-100);drag.relative=Vector2(0,-100);root.push_input(drag,true);touch(drag.position,84,false);await frames()
			check(sheet.scroll.scroll_vertical>0,"native swipe over the detail sheet reaches lower information")
		sheet.scroll.scroll_vertical=0;await frames()
		tap(sheet.source_tab);await frames()
		check(sheet.source_active and view.detail.text==sheet.raw_skill_text,"native source tab keeps existing acquisition/provenance content")
		tap(sheet.info_tab);await frames()
		check(not sheet.source_active and view.detail.text==sheet.info_text,"native information tab restores current game values")
		check(view.detail.text.contains("소모 MP / HP"),"consumption appears in the information table")
		sheet.scroll.scroll_vertical=0;await frames()
		tap(view.preview_button);await frames()
		check(view.preview_container.visible,"native preview uses the existing effect implementation")
		tap(hud.workspace.back_button);await frames()
		check(hud.active_section=="skills" and not browser.detail_active,"first native back returns to the spell list")
		tap(hud.workspace.back_button);await frames()
		check(hud.active_section=="shop","second native back returns to the existing shop route")
		hud._close_workspace()
	check(world.inventory==inventory_before and world.gold==gold_before,"browsing and canceled confirmation preserve inventory and wallet")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("UI_SELECTION_SHEET_OK");quit(0)
	else:print("UI_SELECTION_SHEET_FAILED ",failures);quit(1)
