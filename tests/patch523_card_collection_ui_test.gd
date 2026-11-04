extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Presentation=preload("res://scripts/ui/source_collection_presentation.gd")
const API=preload("res://scripts/lineagem_base508.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var world: Node
var checks: int=0
var failures: Array[String]=[]
var folder: String=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func frames(count: int=5) -> void:
	for i: int in range(count):await process_frame
func tap(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=923;event.position=point;event.pressed=pressed;root.push_input(event,true)
func click(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	await frames(1)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.pressed=pressed;root.push_input(event,true)
		await frames(2)
func capture(label: String) -> void:
	if folder.is_empty():return
	await frames(3);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"capture "+label)
func run() -> void:
	folder=OS.get_environment("TWILIGHT_CARD523_CAPTURE")
	if not folder.is_empty():DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(10)
	check(QA.enter_game(world),"actual class confirmation")
	print("PATCH523_UI_STAGE actual Main entered")
	check(not world.map_bootstrap_blocked,"verified current source map boot")
	world.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_process(false);actor.set_physics_process(false)
	var hud: Node=world.hud
	var original_icons: int=0
	for card_category: String in Cards.CATEGORIES:
		for card: Dictionary in world.catalog_db[card_category]:
			if API.icon(card)!=null:original_icons+=1
	if OS.get_environment("TWILIGHT_CARD523_REQUIRE_PIXELS")=="1":check(original_icons==701,"actual verified private pack decodes701 existing card icons; new19 remain absent")
	for category: String in Cards.CATEGORIES:
		world.card_draw_fusion.owned[category]={};world.card_draw_fusion.spare[category]={}
	var cross: Dictionary={}
	for row: Dictionary in world.card_collections.core.definitions:
		if int(row.source_original.ID)==27343:cross=row;break
	check(not cross.is_empty(),"real cross-deck collection is in production runtime")
	for requirement: Dictionary in cross.requirements:
		world.card_draw_fusion.owned[requirement.category][requirement.id]=true
		world.card_draw_fusion.spare[requirement.category][requirement.id]=2
	world.card_collections.restore_from_owned();world._update_hud();await frames()
	var cards_before: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var rng_before: int=world.card_draw_fusion.rng.state
	var save_before: String=FileAccess.get_file_as_string(world.save_path())
	var expected: Dictionary={"변신":841,"마법인형":511,"성물":441}
	var card_counts: Dictionary={"변신":402,"마법인형":171,"성물":147}
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for category: String in Cards.CATEGORIES:
			print("PATCH523_UI_STAGE ",category," ",extent)
			hud.open_catalog(category);await frames()
			check(hud.catalog_data[category].size()==card_counts[category],"latest523 catalog enters actual "+category)
			await capture(str(Cards.CATEGORIES.find(category))+"-"+str(extent.x)+"-detail")
			var entry: Button=hud.relic_reference_view.tab_buttons[2] if category=="성물" else hud.companion_detail_view.tabs[2]
			tap(entry);await frames()
			check(hud.active_section=="card_collections","real touch entry opens "+category)
			var view=hud.normal_card_collection_view
			check(view.rows.size()==expected[category],"latest523 set count in actual view "+category)
			check(view.search.has_meta("original_ui_binding") and view.list.get_meta("original_ui_binding",{}).get("path","")=="Nd_Collection.ListView_Button","exact observed523 control bindings "+category)
			check(view.get_global_rect().end.x<=root.get_visible_rect().end.x+1 and view.get_global_rect().end.y<=root.get_visible_rect().end.y+1,"actual screen fits viewport "+category+str(extent))
			check(view.effects_filter.item_count>1,"effect filter populated "+category)
			await click(view.effects_filter);await frames()
			check(view.effects_filter.get_popup().visible,"actual pointer opens native effect dropdown "+category)
			check(view.effects_filter.get_popup().size.y<=360,"native effect popup remains bounded and scrollable "+category)
			if extent.x==1280 and category=="변신":await capture("effect-filter-popup")
			view.effects_filter.get_popup().hide();view.state.get_popup().hide();await frames()
			view.effects_filter.get_popup().index_pressed.emit(1);await frames()
			var identity: String=str(view.effects_filter.get_item_metadata(1))
			check(not view.filtered.is_empty() and view.filtered.all(func(r: Dictionary) -> bool:return r.effects.any(func(e: Dictionary) -> bool:return Presentation.effect_identity(e)==identity)),"effect filter affects real rows "+category)
			view._reset_filters();await frames()
			if view.compact_tabs.visible:
				var show_effects: Button=view.compact_tabs.get_child(1);tap(show_effects);await frames()
			tap(view.status_toggle);await frames()
			check(view.showing_status and view.status_body.visible and not view.totals_body.visible,"touch shows current collection status "+category)
			var progress: Array=view.status_body.find_children("*","ProgressBar",true,false)
			check(progress.size()==2 and int(progress[0].get_meta("total_count"))==card_counts[category] and int(progress[1].get_meta("total_count"))==expected[category],"status counts cards and collections, excluding class variants "+category)
			await capture(str(Cards.CATEGORIES.find(category))+"-"+str(extent.x)+"-status")
			tap(view.status_toggle);await frames()
			check(not view.showing_status and view.totals_body.visible,"touch returns to actual collection effects "+category)
			if view.compact_tabs.visible:tap(view.compact_tabs.get_child(0));await frames()
			await capture(str(Cards.CATEGORIES.find(category))+"-"+str(extent.x)+"-collections")
			hud._close_workspace();await frames()
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size);await frames()
	hud.open_normal_card_collections("마법인형");await frames()
	var view=hud.normal_card_collection_view
	view.search.text=str(cross.name);view.search.text_changed.emit(view.search.text);await frames()
	check(view.filtered.any(func(r: Dictionary) -> bool:return r.id==cross.id),"cross-deck set can be searched by source name")
	var real_cards: Array=view.views[0].find_children("NormalCollectionCard","Button",true,false)
	check(real_cards.size()==cross.requirements.size() and real_cards.all(func(b: Button) -> bool:return b.get_meta("card_category")=="변신" and b.get_meta("permanent_owned") and not b.disabled),"cross-deck portraits use member deck ownership and remain inspectable")
	check(view.views[0].find_children("NormalCollectionCardCopies","Label",true,false).all(func(l: Label) -> bool:return l.text=="3"),"cross-deck copy counts use member deck")
	var first: Dictionary=cross.requirements[0]
	world.card_draw_fusion.spare[first.category][first.id]=4;world._update_hud();await frames()
	check(view.views[0].find_children("NormalCollectionCardCopies","Label",true,false).any(func(l: Label) -> bool:return l.text=="5"),"open cross-deck row updates copies from another deck")
	world.card_draw_fusion.spare[first.category][first.id]=2;world._update_hud();await frames()
	await capture("cross-deck-owned")
	hud.open_normal_card_collections(str(first.category),str(first.id));await frames()
	view=hud.normal_card_collection_view
	check(view.rows.any(func(r: Dictionary) -> bool:return r.id==cross.id),"card-focused entry includes sets from other decks")
	tap(view.find_child("NormalCollectionReset",true,false));await frames()
	check(view.focus_card.is_empty() and view.rows.size()==841 and view.effects_filter.selected==0,"actual reset restores the full originating category")
	check(world.card_draw_fusion.export_state()==cards_before and world.card_draw_fusion.rng.state==rng_before,"all actual UI paths preserve owned/spare/RNG")
	check(FileAccess.get_file_as_string(world.save_path())==save_before,"UI navigation never writes player save bytes")

	# Configuration is an explicit saving action, tested after navigation's
	# no-write assertion. All prior navigation still preserves save bytes.
	root.size=Vector2i(854,480);DisplayServer.window_set_size(root.size);await frames()
	view.showing_effects=true;view._fit();await frames()
	await click(view.policy_button);await frames()
	var compact_dialog=world.hud.get_node_or_null("CollectionPolicyDialog")
	check(compact_dialog!=null and compact_dialog.visible and compact_dialog.size.y<=root.size.y-40,"compact estimate settings remain within actual viewport")
	if compact_dialog!=null:
		check(compact_dialog.get_ok_button().get_global_rect().end.y<=compact_dialog.size.y,"compact settings actions stay visible below the scroll area")
		await capture("policy-settings-854")
		compact_dialog.queue_free();await frames()
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size);await frames()
	view._fit();await frames()
	await click(view.policy_button);await frames()
	var dialog=world.hud.get_node_or_null("CollectionPolicyDialog")
	check(dialog!=null and dialog.visible,"actual rules button opens local estimate settings")
	if dialog!=null:
		var spin: SpinBox=dialog.controls.death_damage_per_point
		spin.value=2.0
		check(dialog.server_profile.item_count>1,"settings offers exact source server-condition profiles")
		dialog.server_profile.select(1)
		var owner_window: Window=root if root.gui_embed_subwindows else dialog
		var ok: Button=dialog.get_ok_button()
		var point: Vector2=ok.get_global_transform_with_canvas()*(ok.size*.5)+(Vector2(dialog.position) if root.gui_embed_subwindows else Vector2.ZERO)
		await capture("policy-settings-1280")
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;owner_window.push_input(motion,true);await frames(1)
		for pressed: bool in [true,false]:
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
			owner_window.push_input(event,true);await frames(2)
		await frames()
		check(float(world.card_collections.policy_values.death_damage_per_point)==2.0,"settings button applies edited estimate")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(saved.get("card_collection_policy",{}).get("values",{}).get("death_damage_per_point",0)==2.0,"edited local policy actually saved")
		check(saved.card_draw_fusion==JSON.parse_string(JSON.stringify(cards_before)),"settings save preserves owned/spare ledger")
		var policy_before: Variant=world.card_collections.export_policy()
		var bytes_before: String=FileAccess.get_file_as_string(world.save_path())
		world.equipment_collections.save_blocked=true
		var failed: Dictionary=world.card_collections.apply_policy({"death_damage_per_point":3.0})
		world.equipment_collections.save_blocked=false
		check(not failed.ok and world.card_collections.export_policy()==policy_before and FileAccess.get_file_as_string(world.save_path())==bytes_before,"failed settings save rolls back without ledger/file changes")
		world.card_collections.import_policy({})
		world._load_game(true)
		check(float(world.card_collections.policy_values.death_damage_per_point)==2.0,"actual load restores saved policy")
		check(world.card_draw_fusion.owned==cards_before.owned and world.card_draw_fusion.spare==cards_before.spare and world.card_draw_fusion.rng.state==rng_before,"actual reload preserves original IDs/counts and acquisition RNG")
		check(world.card_collections.source_server_context()==saved.card_collection_policy.server_context,"actual load restores explicitly selected condition profile")
		if is_instance_valid(dialog):dialog.queue_free()
	hud._close_workspace();world.queue_free();await frames()
	print("PATCH523_CARD_UI_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"original_icons_decoded":original_icons,"original_atlas":"absent; no frame/CSB equivalence claim"}))
	quit(0 if failures.is_empty() else 1)
