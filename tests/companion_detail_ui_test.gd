extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var world: TwilightWorld
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=5) -> void:
	for i: int in range(count):await process_frame
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("COMPANION_UI_FAIL ",why)
func tap(control: Control) -> void:
	var at: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=642;event.position=at;event.pressed=down;root.push_input(event,true)
func modal() -> Control:return world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
func swipe(control: Control,delta: float) -> void:
	var visible: Rect2=control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents:
			visible=visible.intersection(ancestor.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,ancestor.size))
		ancestor=ancestor.get_parent()
	check(visible.has_area(),"option swipe starts inside actual clipping bounds")
	var at: Vector2=visible.get_center()
	var down:=InputEventScreenTouch.new()
	down.index=643;down.position=at;down.pressed=true;root.push_input(down,true)
	var drag:=InputEventScreenDrag.new()
	drag.index=643;drag.position=at+Vector2(0,delta);drag.relative=Vector2(0,delta);root.push_input(drag,true)
	var up:=InputEventScreenTouch.new()
	up.index=643;up.position=drag.position;up.pressed=false;root.push_input(up,true)
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"class confirmation")
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var hud: Node=world.hud
	for category: String in ["변신","마법인형"]:
		for row: Dictionary in hud.catalog_data[category]:
			if str(row.grade)=="일반":
				var id: String=Cards.card_id(row)
				world.card_draw_fusion.owned[category][id]=true
				world.card_draw_fusion.spare[category][id]=4
				break
	hud.set_card_collection_state(world.card_draw_fusion.export_state())
	var cards: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var rng_state: int=world.card_draw_fusion.rng.state
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var gold: int=world.gold
	var equipped: Dictionary=world.equipped_catalog.duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for category: String in ["변신","마법인형"]:
			for cycle: int in range(2):
				hud.catalog_view_state.erase(category)
				hud.open_catalog(category);await frames()
				var view: Node=hud.companion_detail_view
				check(view.active and view.category==category and view.name_label.text==str(hud.selected_catalog_record.name),"actual category detail "+category+str(extent))
				check(view.options.get_child_count()>0 and not hud.catalog_detail.visible and not hud.card_controls.is_visible_in_tree(),"options separated from existing fusion controls")
				check(hud.catalog_list.fixed_icon_size==Vector2i(94,116) if extent.x==1280 else hud.catalog_list.fixed_icon_size==Vector2i(78,92),"approved native card sizes preserved")
				check(view.tabs[2].disabled,"unimplemented collection never impersonates equipment collection")
				if hud.catalog_details_tab.is_visible_in_tree():tap(hud.catalog_details_tab);await frames()
				check(view.sheet.is_visible_in_tree() and hud.catalog_card_chrome.preview_frame.is_visible_in_tree(),"detail and approved frame/aura remain reachable")
				if view.sheet.get_v_scroll_bar().max_value>view.sheet.get_v_scroll_bar().page:
					swipe(view.sheet,-110);await frames()
					check(view.sheet.scroll_vertical>0,"native option scrolling on long real values "+category+str(extent))
				for value: Label in view.options.get_children():
					if value.name.begins_with("CompanionOptionValue"):check(value.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT and not value.text.is_empty(),"real numeric/unit column aligned")
				hud.catalog_body_actions.ensure_control_visible(hud.catalog_equip_button);await frames()
				tap(hud.catalog_equip_button);await frames()
				check(modal()!=null,"original apply/summon confirmation connected")
				if modal()!=null:tap(modal().cancel_button);await frames()
				check(world.equipped_catalog[category]==equipped[category],"cancel leaves equipped card untouched")
				var selected_id: String=Cards.card_id(hud.selected_catalog_record)
				tap(view.tabs[1]);await frames()
				var fusion: Control=hud.card_fusion_view
				check(hud.active_section=="card_fusion" and fusion.is_visible_in_tree() and not view.main_body.is_visible_in_tree() and not hud.card_controls.is_visible_in_tree(),"companion tab opens the current dedicated fusion screen")
				fusion._left.ensure_control_visible(fusion._grade_buttons["일반"]);await frames()
				tap(fusion._grade_buttons["일반"]);await frames()
				check(not fusion._fuse.disabled and fusion._cards.item_count>0,"actual duplicate fixture uses original eligibility")
				tap(fusion._fuse);await frames()
				check(modal()!=null,"original fusion confirmation connected")
				if modal()!=null:tap(modal().cancel_button);await frames()
				tap(hud.workspace.back_button);await frames()
				check(view.active and view.active_tab==0 and hud.active_section==category and Cards.card_id(hud.selected_catalog_record)==selected_id,"native Back returns from management to same selection")
				hud.catalog_search.text="not-a-card-642";hud.catalog_search.text_changed.emit(hud.catalog_search.text);await frames()
				check(hud.catalog_results.is_empty() and hud.catalog_equip_button.disabled and view.name_label.text=="카드를 선택하세요","empty filter clears stale detail/actions")
				hud.catalog_search.text="";hud.catalog_search.text_changed.emit("");await frames()
				hud.open_catalog("성물");await frames()
				check(not view.active and hud.relic_reference_view.active,"approved relic view preserved after companion navigation")
				hud.open_catalog("아이템");await frames()
				check(hud.catalog_detail.visible and hud.card_controls.get_parent()==view.controls_home,"shared detail/control parents restored")
				hud.open_catalog(category);await frames()
				tap(view.header.find_child("CompanionShopShortcut",true,false));await frames()
				check(hud.active_section=="shop" and not view.active,"shop shortcut uses existing shop route")
				hud._close_workspace()
	check(world.inventory==inventory and world.item_instances==instances and world.gold==gold and world.card_draw_fusion.export_state()==cards,"view/actions canceled preserve item IDs, money, ownership and fusion state")
	check(world.card_draw_fusion.rng.state==rng_state,"canceled fusion never advances the authoritative RNG")
	await RenderingServer.frame_post_draw
	world.queue_free();await frames()
	print("COMPANION_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
