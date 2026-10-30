extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var world: TwilightWorld
var failures: Array[String]=[]
var assertions: int=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=4) -> void:
	for i: int in range(count):await process_frame
func check(value: bool, message: String) -> void:
	assertions+=1
	if not value:failures.append(message);printerr("RELIC_UI_FAIL ",message)
func tap(control: Control) -> void:
	var position: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=418;event.position=position;event.pressed=down
		root.push_input(event,true)
func modal() -> Control:
	return world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
func tap_item(listing: ItemList,index: int) -> void:
	var local: Vector2=listing.get_item_rect(index).get_center()-Vector2(0,listing.get_v_scroll_bar().value)
	var position: Vector2=listing.get_global_transform_with_canvas()*local
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=419;event.position=position;event.pressed=down
		root.push_input(event,true)
func first_row_visible(listing: ItemList) -> bool:
	if listing.item_count==0:return false
	var row: Rect2=listing.get_item_rect(0)
	row.position.y-=listing.get_v_scroll_bar().value
	var visible: bool=is_zero_approx(listing.get_v_scroll_bar().value) and Rect2(Vector2.ZERO,listing.size).encloses(row)
	if not visible:print("RELIC_SCROLL_STATE ",str(listing.size)," ",row," scroll ",listing.get_v_scroll_bar().value)
	return visible
func swipe_list(listing: ItemList, delta: float) -> void:
	var local: Vector2=listing.size*Vector2(.5,.65)
	var screen: Vector2=listing.get_global_transform_with_canvas()*local
	var down:=InputEventScreenTouch.new()
	down.index=420;down.position=screen;down.pressed=true;root.push_input(down,true)
	var drag:=InputEventScreenDrag.new()
	drag.index=420;drag.position=screen+Vector2(0,delta);drag.relative=Vector2(0,delta);root.push_input(drag,true)
	var up:=InputEventScreenTouch.new()
	up.index=420;up.position=drag.position;up.pressed=false;root.push_input(up,true)
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"class confirmation")
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var hud: Node=world.hud
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var gold: int=world.gold
	var hud_positions: Array=[]
	for control: Control in [hud.v20_self_button,hud.v20_auto_button,hud.v20_layer.get_node("SelectTarget"),hud.get_node("Root/RightControls/AttackButton"),hud.v20_layer.get_node("MainShortcuts")]:hud_positions.append([control.position,control.size])
	# Use the existing acquisition sidecar as a deterministic isolated test fixture.
	var record: Dictionary={}
	for row: Dictionary in hud.catalog_data.get("성물",[]):
		if row.grade=="일반":record=row;break
	var id: String=Cards.card_id(record)
	world.card_draw_fusion.owned["성물"][id]=true
	world.card_draw_fusion.spare["성물"][id]=4
	hud.set_card_collection_state(world.card_draw_fusion.export_state())
	var card_state: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		# Each resolution begins with the first opening, without saved view state.
		hud.catalog_view_state.erase("성물")
		hud.open_catalog("성물");await frames(6)
		var view: Control=hud.relic_reference_view
		check(view.active and hud.catalog_list.is_visible_in_tree(),"live relic list "+str(extent))
		check(hud.catalog_list.item_count>=5,"real page populated "+str(extent))
		check(hud.catalog_page==0 and first_row_visible(hud.catalog_list),"first opening shows complete first row "+str(extent))
		var before_scroll_selection: PackedInt32Array=hud.catalog_list.get_selected_items()
		swipe_list(hud.catalog_list,-180);await frames()
		check(hud.catalog_list.get_v_scroll_bar().value>0,"native touch scroll moves catalog "+str(extent))
		check(hud.catalog_list.get_selected_items()==before_scroll_selection,"scroll does not select cards "+str(extent))
		swipe_list(hud.catalog_list,240);await frames()
		check(first_row_visible(hud.catalog_list),"native return to top restores complete row "+str(extent))

		var a: Rect2=hud.catalog_list.get_item_rect(0)
		var b: Rect2=hud.catalog_list.get_item_rect(3)
		var c: Rect2=hud.catalog_list.get_item_rect(4)
		check(is_equal_approx(a.position.y,b.position.y) and c.position.y>a.position.y and b.end.x<=hud.catalog_list.size.x+1,"four unclipped columns "+str(extent))
		tap_item(hud.catalog_list,1);await frames()
		check(str(hud.selected_catalog_record.sourceId)==str(hud.catalog_results[1].sourceId) and view.name_label.text==str(hud.catalog_results[1].name),"native card selection preserves ID "+str(extent))
		view.type_filter.select(1);view.type_filter.item_selected.emit(1);await frames()
		var kind: String=view.type_filter.get_item_text(1)
		check(hud.catalog_filtered_results.all(func(row: Dictionary) -> bool:return str(row.type)==kind),"type filter uses actual catalog type")
		check(first_row_visible(hud.catalog_list),"type change starts with complete first row")
		# Exercise a populated query after scrolling, not only an empty result.
		swipe_list(hud.catalog_list,-160);await frames()
		hud.catalog_search.text=str(hud.catalog_results[0].name);hud.catalog_search.text_changed.emit(hud.catalog_search.text);await frames()
		check(hud.catalog_list.item_count>0 and first_row_visible(hud.catalog_list),"search after scrolling starts at complete first row")

		hud.catalog_search.text="no-such-relic-418";hud.catalog_search.text_changed.emit(hud.catalog_search.text);await frames()
		check(hud.catalog_list.item_count==0 and hud.catalog_equip_button.disabled,"empty search cannot summon")
		tap(view.find_child("RelicResetFilters",true,false));await frames()
		check(view.type_filter.selected==0 and hud.catalog_search.text.is_empty() and hud.catalog_filtered_results.size()==144,"native reset restores actual catalog")
		check(first_row_visible(hud.catalog_list),"reset starts at complete first row")
		swipe_list(hud.catalog_list,-170);await frames()
		tap(hud.catalog_grade_buttons["영웅"]);await frames()
		check(hud.catalog_grade_filter=="영웅" and hud.catalog_filtered_results.all(func(row: Dictionary) -> bool:return str(row.grade)=="영웅"),"native grade switch uses actual catalog grade")
		check(first_row_visible(hud.catalog_list),"grade change after scrolling starts at complete first row")
		tap(hud.catalog_grade_buttons["전체"]);await frames()
		check(first_row_visible(hud.catalog_list),"all-grade switch starts at complete first row")

		tap(hud.catalog_next_button);await frames()
		check(hud.catalog_page==1 and hud.catalog_list.get_item_text(0)==" ","page switch preserves four-column count presentation")
		tap(view.tab_buttons[1]);await frames()
		check(hud.card_controls.is_visible_in_tree() and hud.card_fusion_button.is_visible_in_tree(),"fusion tab exposes original wired controls")
		hud.card_fusion_grade_select.select(0);hud._refresh_card_controls();await frames()
		check(not hud.card_fusion_button.disabled,"existing duplicates enable existing fusion")
		tap(hud.card_fusion_button);await frames()
		check(modal()!=null,"native fusion still requests original confirmation")
		if modal()!=null:tap(modal().cancel_button);await frames()
		check(world.card_draw_fusion.export_state()==card_state,"cancel never consumes duplicates or rolls fusion")
		tap(view.tab_buttons[0]);await frames()
		tap(hud.catalog_equip_button);await frames()
		check(modal()!=null,"native immediate summon retains confirmation")
		if modal()!=null:tap(modal().cancel_button);await frames()
		check(world.equipped_catalog["성물"].is_empty(),"cancel never applies selected relic")
		check(view.tab_buttons[2].disabled and view.find_child("RelicRegister",true,false).disabled,"absent collection/quick-registration service is not impersonated")
		swipe_list(hud.catalog_list,-75);await frames()
		var saved_page: int=hud.catalog_page
		var saved_scroll: float=hud.catalog_list.get_v_scroll_bar().value
		hud.open_catalog("변신");await frames()
		check(not view.active and not view.card_frames.visible,"relic-only frames hidden after navigation")
		var label: String=hud.catalog_list.get_item_text(0)
		check(label==str(hud.catalog_results[0].name)+"\n미보유" and hud.catalog_list.get_theme_constant("h_separation")==8,"shared catalog restores actual card name, ownership marker and spacing")
		tap_item(hud.catalog_list,0);await frames()
		check(Cards.card_id(hud.selected_catalog_record)==Cards.card_id(hud.catalog_results[0]) and hud.companion_detail_view.name_label.text==str(hud.catalog_results[0].name),"shared card label still selects the exact card ID and detail")
		hud.open_catalog("성물");await frames()
		check(hud.catalog_page==saved_page and is_equal_approx(hud.catalog_list.get_v_scroll_bar().value,saved_scroll),"reopening preserves intentional saved page and scroll")
		tap(hud.relic_reference_view.header.find_child("RelicShopShortcut",true,false));await frames()
		check(hud.active_section=="shop" and not view.active,"native shop shortcut uses existing route")
		hud._close_workspace()
	check(world.inventory==inventory and world.item_instances==instances and world.gold==gold,"navigation and canceled actions preserve IDs, quantities and gold")
	check(world.card_draw_fusion.export_state()==card_state,"all acquisition and probability state preserved")
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(Vector2i(1280,720));await frames();hud._fit_hud()
	var index: int=0
	for control: Control in [hud.v20_self_button,hud.v20_auto_button,hud.v20_layer.get_node("SelectTarget"),hud.get_node("Root/RightControls/AttackButton"),hud.v20_layer.get_node("MainShortcuts")]:
		check([control.position,control.size]==hud_positions[index],"approved HUD geometry remains fixed "+str(control.name));index+=1
	await RenderingServer.frame_post_draw
	world.queue_free();await frames()
	print("RELIC_UI_RESULT ",JSON.stringify({"assertions":assertions,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
