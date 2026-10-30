extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);printerr("MERGED_UI_FAIL ",message)
func frames() -> void:
	for i: int in range(6):await process_frame
func touch(point: Vector2,index: int,down: bool) -> void:
	var event:=InputEventScreenTouch.new();event.position=point;event.index=index;event.pressed=down;root.push_input(event,true)
func tap(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5);touch(point,91,true);touch(point,91,false)
func swipe(scroll: ScrollContainer) -> void:
	var point: Vector2=scroll.get_global_transform_with_canvas()*(scroll.size*.5)
	touch(point,92,true)
	var drag:=InputEventScreenDrag.new();drag.index=92;drag.position=point+Vector2(0,-100);drag.relative=Vector2(0,-100);root.push_input(drag,true)
	touch(drag.position,92,false);await frames()
func labels(node: Node) -> Array[Label]:
	var found: Array[Label]=[]
	for child: Node in node.get_children():
		if child is Label:found.append(child)
		found.append_array(labels(child))
	return found
func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);await frames()
	check(QA.enter_game(world),"class selection")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in world.catalog_db[category]:
			if str(record.get("grade",""))=="일반":
				var identity: String=Cards.card_id(record)
				world.card_draw_fusion.owned[category][identity]=true
				world.card_draw_fusion.spare[category][identity]=4
				break
	world._update_hud()
	var candidates: Array=world._enhancement_candidates("weapon")
	check(not candidates.is_empty(),"real physical weapon fixture")
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var gold: int=world.gold
	var cards: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var rng_state: int=world.card_draw_fusion.rng.state
	var hud: Node=world.hud
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		hud.toggle_inventory();await frames()
		var bag: Control=hud.lineage_inventory_ui
		check(bag.category_tabs.is_visible_in_tree() and bag.category_tabs.get_global_rect().end.y<=hud.workspace.content.get_global_rect().position.y+1,"inventory categories occupy the existing header above the content")
		bag._select_item("HP 물약");tap(bag.find_child("InventoryDetail",true,false));await frames()
		check(bag.detail_active and root.get_visible_rect().grow(1).encloses(bag.detail_panel.get_global_rect()),"native detail opens inside the viewport")
		tap(hud.workspace.back_button);await frames()
		check(not bag.detail_active and hud.active_section=="inventory","Back closes detail before leaving inventory")
		hud.open_enhancement("무기 마법 주문서 (각인)",candidates);await frames()
		var forge: Control=hud.workspace.content.get_child(0)
		check(forge.scroll_icon.texture!=null and forge.preview.texture!=null and forge.scroll_icon.is_visible_in_tree() and forge.preview.is_visible_in_tree(),"actual scroll and selected target pictures are visible together")
		check(str(forge.values[forge.selected_index].target_id)==str(candidates[0].target_id),"presentation preserves the physical target ID")
		if forge.info_scroll.get_v_scroll_bar().max_value>forge.info_scroll.get_v_scroll_bar().page:
			await swipe(forge.info_scroll)
			check(forge.info_scroll.scroll_vertical>0,"native swipe reaches lower probability and effect information")
		check(hud.workspace.content.get_global_rect().grow(1).encloses(forge.action.get_global_rect()),"confirmation stays reachable beside scrollable details")
		tap(forge.action);await frames()
		var confirm: Control=hud.get_node_or_null("Root/TwilightConfirmation")
		check(confirm!=null,"presentation opens the existing enhancement confirmation")
		if confirm!=null:tap(confirm.cancel_button);await frames()
		hud.open_equipment_collections();await frames()
		var collections: Control=hud.workspace.content.get_child(0)
		check(collections.list.item_count==collections.filtered.size() and collections.list.views.size()<12,"collection pictures use bounded visible rows")
		var row: Button=collections.list.views[0]
		tap(row);await frames()
		check(collections.selected_id==str(collections.filtered[0].id),"native picture row keeps the authoritative collection ID")
		check(row.find_children("*","TextureRect",true,false).size()>0,"required equipment pictures are connected")
		hud.open_growth("emblems");await frames()
		var empty_found: bool=false
		for label: Label in labels(hud.workspace.content):
			if label.text=="없음":empty_found=true;check(label.get_line_count()==1,"empty applied-effect word stays on one line")
		check(empty_found,"actual stage-zero empty effect is shown")
		for category: String in Cards.CATEGORIES:
			hud.open_catalog(category);await frames()
			if category!="성물":tap(hud.companion_detail_view.tabs[1])
			else:hud.open_card_fusion(category)
			await frames()
			check(hud.active_section=="card_fusion","current dedicated fusion route is preserved "+category)
			if hud.active_section!="card_fusion":continue
			var fusion: Control=hud.card_fusion_view
			fusion._left.ensure_control_visible(fusion._grade_buttons["일반"]);await frames()
			tap(fusion._grade_buttons["일반"]);await frames()
			check(not fusion._fuse.disabled,"actual four-duplicate fixture remains eligible "+category)
			check(hud.workspace.content.get_global_rect().grow(1).encloses(fusion._fuse.get_global_rect()),"fusion confirmation fits inside the short window "+category)
			tap(fusion._fuse);await frames();confirm=hud.get_node_or_null("Root/TwilightConfirmation")
			check(confirm!=null,"native dedicated fusion confirmation is reachable "+category)
			if confirm!=null:tap(confirm.cancel_button);await frames()
			tap(hud.workspace.back_button);await frames()
			check(hud.active_section==category,"fusion Back returns to its source category "+category)
		hud._close_workspace();await frames()
	check(world.inventory==inventory and world.item_instances==instances and world.gold==gold,"browsing, scrolling and canceled confirmation preserve inventory, IDs and gold")
	check(world.card_draw_fusion.export_state()==cards,"fusion confirmation cancellation preserves permanent unlocks, duplicates and RNG state")
	check(world.card_draw_fusion.rng.state==rng_state,"canceled fusion confirmation never advances the authoritative RNG")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("UI_MERGED_PRESENTATION_OK");quit(0)
	else:print("UI_MERGED_PRESENTATION_FAILED ",failures);quit(1)
