extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const CID: String="eqc_b10d34dbc266c4e869ca"
var world: TwilightWorld
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func frames(count: int=6) -> void:
	for index: int in range(count):await process_frame
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("COLLECTION_REFERENCE_FAIL ",why)
func tap(control: Control,canceled: bool=false) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=875;event.position=point;event.pressed=pressed;event.canceled=canceled and not pressed;root.push_input(event,true)
func tap_item(list: ItemList,index: int) -> void:
	var point: Vector2=list.get_item_rect(index,false).get_center()-Vector2(0,list.get_v_scroll_bar().value)
	point=list.get_global_transform_with_canvas()*point
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=876;event.position=point;event.pressed=pressed;root.push_input(event,true)
func swipe(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	var down:=InputEventScreenTouch.new();down.index=877;down.position=point;down.pressed=true;root.push_input(down,true)
	var drag:=InputEventScreenDrag.new();drag.index=877;drag.position=point-Vector2(0,100);drag.relative=Vector2(0,-100);root.push_input(drag,true)
	var up:=InputEventScreenTouch.new();up.index=877;up.position=drag.position;up.pressed=false;root.push_input(up,true)
func ensure(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
func modal() -> Control:return world.hud.get_node_or_null("Root/TwilightConfirmation")
func give(item_name: String,level: int) -> String:
	var record: Dictionary=world.equipment_collections.icon_record(item_name)
	check(not record.is_empty(),"fixture binds an actual equipment source")
	var id: String=str(world.next_item_instance_id);world.next_item_instance_id+=1
	var name_value: String=str(record.name)
	world.inventory[name_value]=int(world.inventory.get(name_value,0))+1
	world.item_instances[id]={"name":name_value,"level":level,"record":record.duplicate(true),"sourceId":str(record.sourceId)}
	return id
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"class confirmation")
	world.set_process(false);world.save_timer=-100000;world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	world.inventory={};world.item_instances={};world.equipped_items={};world.enhancement_levels={}
	var rt=world.equipment_collections
	var definitions: Array=rt.definitions().duplicate(true)
	var required: Array=rt.core.resolve(CID).requirements
	var fixtures: Array=[]
	for requirement: Dictionary in required:
		var normal: String=give(str(requirement.name),int(requirement.enchant))
		var engraved: String=give(str(requirement.name)+" (각인)",int(requirement.enchant))
		var wrong: String=give(str(requirement.name),int(requirement.enchant)+1)
		var locked: String=give(str(requirement.name),int(requirement.enchant))
		world.ui_preferences.item_locks[str(world.item_instances[locked].name)+"@@@"+locked]=true
		fixtures.append({"normal":normal,"engraved":engraved,"wrong":wrong,"locked":locked})
	check(world._save_game(true)==OK,"real isolated save is ready before native registration")
	var hud: Node=world.hud
	var cycle: int=0
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		hud._close_workspace();hud.toggle_menu();await frames()
		var tile: Control=hud.workspace.find_child("MenuTile_equipment_collections",true,false)
		ensure(tile);await frames();tap(tile);await frames()
		check(hud.active_section=="equipment_collections","native menu opens the actual collection service "+str(extent))
		var view: Node=hud.workspace.content.get_child(0)
		check(view.list.views.size()<12 and view.list.item_count==447,"original IDs remain in a bounded virtual list")
		view.status.select(5);view.status.item_selected.emit(5);await frames()
		check(view.filtered.any(func(row: Dictionary) -> bool:return str(row.id)==CID),"registration filter uses actual eligible inventory")
		view.query.text="마법 망토 (각인)";view.query.text_changed.emit(view.query.text);await frames()
		check(not view.filtered.is_empty() and view.filtered.all(func(row: Dictionary) -> bool:return str(row.requirements).contains("마법 망토")),"search strips engraving display without merging source IDs")
		tap(view.find_child("ResetCollectionFilters",true,false));await frames()
		check(view.query.text.is_empty() and view.grade.selected==0 and view.status.selected==0,"native reset restores all source definitions")
		var selection: String=view.selected_id
		swipe(view.list);await frames()
		if view.list.get_v_scroll_bar().value<=0 or view.selected_id!=selection:print("COLLECTION_SWIPE_TRACE ",extent," scroll=",view.list.get_v_scroll_bar().value," id=",view.selected_id," wanted=",selection," finger=",hud.workspace.active_scroll_touch)
		check(view.list.get_v_scroll_bar().value>0 and view.selected_id==selection,"native swipe never registers or selects a different collection")
		view.list.get_v_scroll_bar().value=0;await frames()
		view.selected_id=CID;view._filter();await frames()
		var req: Dictionary=required[cycle]
		view._choose(CID,str(req.slot_id));await frames()
		check(view.registration_dock.is_visible_in_tree() and hud.workspace.content.get_global_rect().grow(1).encloses(view.registration_dock.get_global_rect()),"registration remains pinned inside the current window")
		var list: ItemList=view.candidates_list
		check(list!=null and list.item_count==2,"physical picker excludes wrong enchantment and locked equipment")
		if list!=null:
			var index: int=-1
			for item: int in range(list.item_count):
				check(not list.get_item_text(item).contains("각인") and not list.get_item_tooltip(item).contains("각인"),"display omits engraving while keeping source metadata")
				if str(list.get_item_metadata(item))==str(fixtures[cycle].engraved):index=item
			check(index>=0,"engraved physical instance remains an independently selectable exact ID")
			view.detail_scroll.ensure_control_visible(list);await frames();tap_item(list,index);await frames()
			check(str(list.get_item_metadata(list.get_selected_items()[0]))==str(fixtures[cycle].engraved),"native candidate selection keeps its physical ID")
			var action: Button=view.find_child("RegisterCollectionItem",true,false)
			var state: Dictionary=rt.export_state().duplicate(true)
			var items: Dictionary=world.item_instances.duplicate(true)
			var disk: String=FileAccess.get_sha256(world.save_path())
			tap(action);await frames();check(modal()!=null,"native pinned action opens original destructive confirmation")
			if modal()!=null:tap(modal().cancel_button);await frames()
			check(rt.export_state()==state and world.item_instances==items and FileAccess.get_sha256(world.save_path())==disk,"cancel preserves receipts, inventory and durable save")
			tap(action);await frames()
			if modal()!=null:tap(modal().confirm_button);await frames()
			check(not world.item_instances.has(str(fixtures[cycle].engraved)) and world.item_instances.has(str(fixtures[cycle].normal)),"confirmation consumes only the chosen physical source instance")
			check(rt.slot_count(CID,str(req.slot_id))==1,"actual registered count refreshes in the live screen")
			var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
			check(saved.equipment_collections.receipts.has(str(fixtures[cycle].engraved)),"consumption is committed with its receipt")
		view.query.text="no-such-collection-875";view.query.text_changed.emit(view.query.text);await frames()
		check(view.filtered.is_empty() and view.registration_dock.get_child_count()==0,"empty filters expose no stale registration action")
		view.query.text="";view.query.text_changed.emit("");await frames()
		for row: Dictionary in view.rows:
			if row.requirements.size()==13:
				view.selected_id=str(row.id);view.selected_slot_id="";view.show_detail=true;view._render_detail();view._fit();break
		await frames()
		var all_materials: GridContainer=view.find_child("CollectionAllMaterials",true,false)
		check(all_materials!=null and all_materials.get_child_count()==13,"all thirteen source requirements stay reachable behind the bounded row preview")
		if all_materials!=null:
			var last: Control=all_materials.get_child(12)
			var last_slot: String=str(last.get_meta("slot_id"))
			view.detail_scroll.ensure_control_visible(last);await frames();tap(last);await frames()
			if view.selected_slot_id!=last_slot:print("COLLECTION_SLOT_TRACE ",extent," actual=",view.selected_slot_id," wanted=",last_slot," detail=",view.detail_scroll.get_global_rect()," scroll=",view.detail_scroll.scroll_vertical," finger=",hud.workspace.active_scroll_touch)
			check(view.selected_slot_id==last_slot,"native long-material selection keeps the exact source slot")
		tap(hud.workspace.back_button);await frames()
		check(hud.active_section=="menu","native Back returns to the menu")
		cycle+=1
	check(rt.completed(CID) and float(rt.totals.get("max_mp:flat",0))==10.0,"completing original slots activates the original reward once")
	check(rt.definitions()==definitions,"UI never edits permanent definitions, quantities, enhancement levels, original aliases or rewards")
	# Existing card collections are automatic and never consume permanent cards.
	for identity: String in ["source:5","source:8","source:54","source:9"]:world.card_draw_fusion.owned["마법인형"][identity]=true
	world.option_awakening.progress.cards["마법인형"]["source:5"]={"experience":0,"awakened":true,"attempts":1,"failures":0}
	world.option_awakening.progress.revision+=1;world._invalidate_equipment_static();world._update_hud()
	var before_cards: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var before_awakening: Dictionary=world.option_awakening.export_state().duplicate(true)
	var before_rng: int=world.card_draw_fusion.rng.state
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		hud.set_option_awakening_view(world.option_awakening.view("마법인형","source:5"));await frames()
		var view: Node=hud.option_awakening_view
		var panel: Node=view._collections
		check(panel.rows==world.option_awakening.collections_view() and panel.rows.size()==4,"only the four actual supported collections are displayed")
		panel.status.select(1);panel.status.item_selected.emit(1);await frames()
		check(panel.selected_id=="option_doll_levitation","in-progress filter reads actual requirement completion")
		var cards: Array[Node]=panel.find_children("CollectionCard","Button",true,false)
		check(cards.size()==3,"selected collection renders every actual requirement card")
		for card: Control in cards:
			var identity: String=str(card.get_meta("card_id"))
			check(card.find_child("CollectionCardArt",true,false).texture!=null,"actual card image is connected by exact source ID")
			if identity=="source:54":
				check(bool(card.get_meta("permanent_owned")) and not bool(card.get_meta("condition_met")),"owned zero-duplicate card remains owned while its awakening is unmet")
				ensure(card);await frames();tap(card);await frames()
				check(panel.selected_card==identity and str(view.snapshot.target_id)=="source:5","card inspection never changes the transaction target")
			if identity=="source:82":check(not bool(card.get_meta("permanent_owned")),"missing collection card stays distinguishable")
		panel.status.select(3);panel.status.item_selected.emit(3);await frames()
		check(panel.selected_id=="option_doll_love_courage" and panel.body.find_children("Collection_*","Button",false,false).size()==1,"complete filter shows the actual automatically active reward")
		panel.status.select(0);panel.status.item_selected.emit(0);await frames()
		view._info_scroll.scroll_vertical=roundi(panel.position.y);await frames();swipe(view._info_scroll);await frames()
		check(view._info_scroll.scroll_vertical>0,"card collection content remains touch scrollable")
	check(world.card_draw_fusion.export_state()==before_cards and world.option_awakening.export_state()==before_awakening and world.card_draw_fusion.rng.state==before_rng,"collection filtering and card inspection never consume cards, reroll or mutate saves")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	print("COLLECTION_REFERENCE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
