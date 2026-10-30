extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	for i: int in range(8):await process_frame
func check(ok: bool,why: String) -> void:
	if not ok:failures.append(why);printerr("FUSION_REFERENCE_FAIL ",why)
func tap(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var touch:=InputEventScreenTouch.new();touch.index=912;touch.position=point;touch.pressed=down;root.push_input(touch,true)
func tap_card(listing: ItemList,index: int) -> void:
	var at: Vector2=listing.get_item_rect(index).get_center()-Vector2(0,listing.get_v_scroll_bar().value)
	for down: bool in [true,false]:
		var touch:=InputEventScreenTouch.new();touch.index=913;touch.position=listing.get_global_transform_with_canvas()*at;touch.pressed=down;root.push_input(touch,true)
func swipe(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*Vector2(.5,.65))
	var down:=InputEventScreenTouch.new();down.index=914;down.position=point;down.pressed=true;root.push_input(down,true)
	var drag:=InputEventScreenDrag.new();drag.index=914;drag.position=point+Vector2(0,-110);drag.relative=Vector2(0,-110);root.push_input(drag,true)
	var up:=InputEventScreenTouch.new();up.index=914;up.position=drag.position;up.pressed=false;root.push_input(up,true)
	await frames()
func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);await frames();check(QA.enter_game(world),"class selection")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	for category: String in Cards.CATEGORIES:
		for grade: String in Cards.GRADES:
			var count: int=0
			for record: Dictionary in world.catalog_db[category]:
				if str(record.grade)!=grade:continue
				var id: String=Cards.card_id(record);world.card_draw_fusion.owned[category][id]=true;world.card_draw_fusion.spare[category][id]=3;count+=1
				if count==3:break
	world._update_hud()
	var before: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var gold: int=world.gold
	var rng: int=world.card_draw_fusion.rng.state
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for category: String in Cards.CATEGORIES:
			var hud: Node=world.hud
			hud.open_catalog(category);await frames();hud.open_card_fusion(category);await frames()
			var view: Control=hud.card_fusion_view
			check(view._cards.max_columns==4 and view._cards.icon_mode==ItemList.ICON_MODE_TOP,"portrait roster uses reference grid "+category+str(extent))
			check(view._cards.item_count>=4,"actual owned grade fixture populates the grid")
			var first: Rect2=view._cards.get_item_rect(0)
			var fourth: Rect2=view._cards.get_item_rect(3)
			check(is_equal_approx(first.position.y,fourth.position.y) and fourth.end.x<=view._cards.size.x+1,"four actual columns fit without clipping "+str(extent))
			check(view._left.get_global_rect().end.x<=view._cards.get_global_rect().position.x and view._cards.get_global_rect().end.x<=view._right.get_global_rect().position.x,"filters, portraits and registered materials occupy separate columns")
			if view._cards.get_v_scroll_bar().max_value>view._cards.get_v_scroll_bar().page:
				var selected: PackedInt32Array=view._cards.get_selected_items()
				await swipe(view._cards)
				check(view._cards.get_v_scroll_bar().value>0 and view._cards.get_selected_items()==selected,"native portrait scrolling never registers a different card")
				view._cards.get_v_scroll_bar().value=0;await frames()
			tap_card(view._cards,0);await frames()
			check(view.grade==str((view._cards.get_item_metadata(0) as Dictionary).grade),"native portrait chooses its actual grade")
			view._left.ensure_control_visible(view._grade_buttons["일반"]);await frames();tap(view._grade_buttons["일반"]);await frames()
			check(view.grade=="일반" and view.filter_grade=="일반" and not view._fuse.disabled,"native grade filter keeps current eligibility")
			check(hud.workspace.active_scroll_touch==-1,"grade release never strands a finger in the window gesture owner")
			for preview: Control in view._previews:
				check(view._details_scroll.get_global_rect().grow(1).encloses((preview.get_child(0) as Control).get_global_rect()),"default registered portrait and count fit before scrolling")
			var model=Cards.new();model.configure(world.catalog_db);model.import_state(before);model.rng.state=rng
			var outcome: Dictionary=model.fuse(category,"일반")
			check(bool(outcome.ok),"authoritative comparison model fuses the unchanged fixture")
			var consumed: int=0
			for entry: Dictionary in view.registered_materials:
				consumed+=int(entry.count)
				var awarded: int=1 if str(outcome.result.id)==str(entry.id) and not bool(outcome.result.new) else 0
				var remaining: int=int(model.spare[category].get(entry.id,0))-awarded
				check(int(before.spare[category][entry.id])-remaining==int(entry.count),"displayed exact material ID/count agrees with Cards.fuse")
			check(consumed==Cards.FUSION_MATERIALS["일반"],"preview counts the actual required duplicates")
			tap(view.find_child("CardFusionProbability",true,false));await frames()
			check(view._note.is_visible_in_tree() and view._note.text.contains("35.00%"),"visible probability is the current game's rule")
			check(hud.workspace.active_scroll_touch==-1,"probability button releases the previous scroll finger")
			if view._details_scroll.get_v_scroll_bar().max_value>view._details_scroll.get_v_scroll_bar().page:
				await swipe(view._details_scroll)
				if view._details_scroll.scroll_vertical==0:print("FUSION_SCROLL_TRACE ",category," ",extent," ",view._details_scroll.get_global_rect()," range ",view._details_scroll.get_v_scroll_bar().max_value,"/",view._details_scroll.get_v_scroll_bar().page," gesture ",hud.workspace.scroll_gestures.get(view._details_scroll.get_instance_id(),{})," active ",hud.workspace.active_scroll_touch," host ",view._scroll_host.name)
				check(view._details_scroll.scroll_vertical>0,"native swipe reaches probability and lower registered material details")
			check(hud.workspace.content.get_global_rect().grow(1).encloses(view._fuse.get_global_rect()),"confirmation stays inside the existing window with probability expanded")
			check(view._fuse.size.y*view._fuse.get_global_transform_with_canvas().y.length()*root.get_screen_transform().y.length()>=43.9,"confirmation keeps 44 physical pixels "+str(extent))
			tap(view._auto);await frames();tap(view._fuse);await frames()
			var dialog: Control=hud.get_node_or_null("Root/TwilightConfirmation")
			check(dialog!=null,"native synthesis opens the existing confirmation")
			if dialog!=null:tap(dialog.cancel_button);await frames()
			check(world.card_draw_fusion.export_state()==before and world.card_draw_fusion.rng.state==rng,"preview/auto register/cancel never consume or roll")
			view.set_collection_state({"owned":{},"spare":{},"pity":{}});await frames()
			check(view._cards.item_count==0 and view.registered_materials.is_empty() and view._fuse.disabled,"empty state clears all stale art, counts and actions")
			view.set_collection_state(before);await frames();tap(hud.workspace.back_button);await frames()
			check(hud.active_section==category,"Back returns to the actual source catalog")
			hud._close_workspace();await frames()
	check(world.inventory==inventory and world.item_instances==instances and world.gold==gold,"UI preserves physical IDs and wallet")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("FUSION_REFERENCE_LAYOUT_OK");quit(0)
	else:print("FUSION_REFERENCE_LAYOUT_FAILED ",failures);quit(1)
