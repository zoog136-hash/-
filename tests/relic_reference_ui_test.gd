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
	var position: Vector2=listing.get_global_transform_with_canvas()*listing.get_item_rect(index).get_center()
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=419;event.position=position;event.pressed=down
		root.push_input(event,true)
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
		hud.open_catalog("성물");await frames(6)
		var view: Control=hud.relic_reference_view
		check(view.active and hud.catalog_list.is_visible_in_tree(),"live relic list "+str(extent))
		check(hud.catalog_list.item_count>=5,"real page populated "+str(extent))
		var a: Rect2=hud.catalog_list.get_item_rect(0)
		var b: Rect2=hud.catalog_list.get_item_rect(3)
		var c: Rect2=hud.catalog_list.get_item_rect(4)
		check(is_equal_approx(a.position.y,b.position.y) and c.position.y>a.position.y and b.end.x<=hud.catalog_list.size.x+1,"four unclipped columns "+str(extent))
		tap_item(hud.catalog_list,1);await frames()
		check(str(hud.selected_catalog_record.sourceId)==str(hud.catalog_results[1].sourceId) and view.name_label.text==str(hud.catalog_results[1].name),"native card selection preserves ID "+str(extent))
		view.type_filter.select(1);view.type_filter.item_selected.emit(1);await frames()
		var kind: String=view.type_filter.get_item_text(1)
		check(hud.catalog_filtered_results.all(func(row: Dictionary) -> bool:return str(row.type)==kind),"type filter uses actual catalog type")
		hud.catalog_search.text="no-such-relic-418";hud.catalog_search.text_changed.emit(hud.catalog_search.text);await frames()
		check(hud.catalog_list.item_count==0 and hud.catalog_equip_button.disabled,"empty search cannot summon")
		tap(view.find_child("RelicResetFilters",true,false));await frames()
		check(view.type_filter.selected==0 and hud.catalog_search.text.is_empty() and hud.catalog_filtered_results.size()==144,"native reset restores actual catalog")
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
		hud.open_catalog("변신");await frames()
		check(not view.active and not view.card_frames.visible,"relic-only frames hidden after navigation")
		check(hud.catalog_list.get_item_text(0)==str(hud.catalog_results[0].name) and hud.catalog_list.get_theme_constant("h_separation")==8,"shared catalog labels and spacing restored")
		hud.open_catalog("성물");await frames()
		tap(hud.relic_reference_view.header.find_child("RelicShopShortcut",true,false));await frames()
		check(hud.active_section=="shop" and not view.active,"native shop shortcut uses existing route")
		hud._close_workspace()
	check(world.inventory==inventory and world.item_instances==instances and world.gold==gold,"navigation and canceled actions preserve IDs, quantities and gold")
	check(world.card_draw_fusion.export_state()==card_state,"all acquisition and probability state preserved")
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(Vector2i(1280,720));await frames();hud._fit_hud()
	var index: int=0
	for control: Control in [hud.v20_self_button,hud.v20_auto_button,hud.v20_layer.get_node("SelectTarget"),hud.get_node("Root/RightControls/AttackButton"),hud.v20_layer.get_node("MainShortcuts")]:
		check([control.position,control.size]==hud_positions[index],"approved HUD geometry remains fixed "+str(control.name));index+=1
	world.queue_free();await frames()
	print("RELIC_UI_RESULT ",JSON.stringify({"assertions":assertions,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
