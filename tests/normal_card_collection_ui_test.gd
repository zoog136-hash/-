extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("NORMAL_COLLECTION_UI_FAIL ",why)
func frames(count: int=5) -> void:
	for index: int in range(count):await process_frame
func tap(control: Control,canceled: bool=false) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=923;event.position=point;event.pressed=pressed;event.canceled=canceled and not pressed;root.push_input(event,true)
func swipe(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	var down:=InputEventScreenTouch.new();down.index=924;down.position=point;down.pressed=true;root.push_input(down,true)
	var drag:=InputEventScreenDrag.new();drag.index=924;drag.position=point-Vector2(0,100);drag.relative=Vector2(0,-100);root.push_input(drag,true)
	var up:=InputEventScreenTouch.new();up.index=924;up.position=drag.position;up.pressed=false;root.push_input(up,true)
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"class confirmation")
	world.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_process(false);actor.set_physics_process(false)
	for category: String in ["변신","마법인형","성물"]:world.card_draw_fusion.owned[category]={};world.card_draw_fusion.spare[category]={}
	world.card_draw_fusion.owned["변신"]={"source:62":true,"source:61":true,"source:281":true}
	world.card_draw_fusion.owned["마법인형"]={"source:21":true,"source:24":true,"source:128":true}
	world.card_draw_fusion.owned["성물"]={"source:1008":true,"source:1007":true,"source:1001":true,"source:1004":true}
	world._update_hud()
	var saved_cards: Dictionary=world.card_draw_fusion.export_state();var rng: int=world.card_draw_fusion.rng.state
	var save_text: String=FileAccess.get_file_as_string(world.save_path())
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for category: String in ["변신","마법인형","성물"]:
			world.hud.open_catalog(category);await frames()
			var entry: Button=world.hud.companion_detail_view.tabs[2] if category!="성물" else world.hud.relic_reference_view.tab_buttons[2]
			check(not entry.disabled,"normal collection tab enabled "+category)
			tap(entry,true);await frames();check(world.hud.active_section==category,"canceled tap does not navigate "+category)
			tap(entry);await frames()
			check(world.hud.active_section=="card_collections","native tab enters real collection screen "+category)
			var view=world.hud.normal_card_collection_view
			check(view.category==category and not view.rows.is_empty(),"correct category definitions "+category)
			check(view.find_children("*Register*","Button",true,false).is_empty(),"no manual registration action or consumption "+category)
			check(view.get_global_rect().end.x<=root.get_visible_rect().end.x+1 and view.get_global_rect().end.y<=root.get_visible_rect().end.y+1,"collection screen fits actual viewport "+str(extent)+category)
			var capture_dir: String=OS.get_environment("TWILIGHT_NORMAL_COLLECTION_CAPTURE")
			if not capture_dir.is_empty():
				DirAccess.make_dir_recursive_absolute(capture_dir)
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(capture_dir+"/"+str(["변신","마법인형","성물"].find(category))+"-"+str(extent.x)+"-after.png")==OK,"actual collection capture saved")
			view.search.text="no matching card xyz";view.search.text_changed.emit(view.search.text);await frames()
			check(view.filtered.is_empty() and view.summary.text.contains("없음"),"search empty state "+category)
			view.search.text="";view.search.text_changed.emit("");await frames()
			var grade: Button=view.grades[-1]
			view.grade_side.ensure_control_visible(grade);await frames()
			tap(grade);await frames()
			check(view.selected_grade=="일반" and view.filtered.all(func(row: Dictionary) -> bool:return row.grade=="일반"),"native grade filter retains IDs "+category)
			for panel: Control in view.views:
				if not panel.visible:continue
				for card: Button in panel.find_children("NormalCollectionCard","Button",true,false):
					var identity: String=str(card.get_meta("card_id"))
					check(bool(card.get_meta("permanent_owned"))==bool(saved_cards.owned[category].get(identity,false)),"zero-duplicate acquired card uses permanent owned state "+identity)
					if card.get_global_rect().end.y<=view.list.get_global_rect().end.y and not card.disabled:
						tap(card);await frames();check(view.selected_card==identity,"native card inspection preserves exact ID "+identity)
			view.state.select(3);view.state.item_selected.emit(3);await frames()
			check(view.filtered.all(func(row: Dictionary) -> bool:return row.completed),"completed state filter "+category)
			view.state.select(0);view.state.item_selected.emit(0);view.selected_grade="전체";view._filter();await frames()
			swipe(view.list);await frames()
			check(view.list.scroll_vertical>0,"native swipe reaches further collections "+category)
			check(view.views.size()<=ceili(view.list.size.y/196.0)+2,"bounded visible row pool, not one animated tree per collection "+category)
			var old_scroll: int=view.list.scroll_vertical
			var revision: int=view.last_revision
			world._update_hud();await frames()
			check(view.last_revision==revision and view.list.scroll_vertical==old_scroll,"unchanged publications preserve scroll and row cache "+category)
			world.hud._go_back();await frames()
			check(world.hud.active_section==category,"back restores originating catalog "+category)
			world.hud._close_workspace();await frames()
			world.hud.open_normal_card_collections(category);await frames();world.hud._close_workspace();await frames()
			check(not world.hud.workspace.visible,"repeated open/close "+category)
	check(world.card_draw_fusion.export_state()==saved_cards and world.card_draw_fusion.rng.state==rng,"UI inspection never changes cards/spares/RNG")
	check(FileAccess.get_file_as_string(world.save_path())==save_text,"UI inspection never writes new save records")
	world.hud.open_normal_card_collections("마법인형");await frames()
	var live=world.hud.normal_card_collection_view
	live.search.text="그저 빛";live.search.text_changed.emit(live.search.text);await frames()
	check(live.filtered.size()==1 and not live.filtered[0].completed,"live acquisition starts with the real incomplete Holy Swordsman pair")
	for entry: Dictionary in world.card_draw_fusion.pools["마법인형"]["고급"]:
		if entry.id=="source:101":world.card_draw_fusion._receive("마법인형",entry);break
	check(world._save_game(true)==OK,"live first acquisition reaches the existing durable save")
	world._update_hud();await frames()
	check(live.filtered.size()==1 and live.filtered[0].completed,"already open collection updates completion after acquisition publication")
	check(live.views[0].get_meta("completed",false) and live.views[0].find_children("NormalCollectionCard","Button",true,false).all(func(button: Button) -> bool:return bool(button.get_meta("permanent_owned"))),"visible recycled row and each portrait update immediately")
	var old_revision: int=world.card_collections.current_revision()
	world.card_draw_fusion.spare["마법인형"]["source:101"]=2;world._update_hud();await frames()
	var copies: Label=live.views[0].find_child("NormalCollectionCardCopies",true,false)
	check(copies!=null and copies.text=="3" and world.card_collections.current_revision()==old_revision,"duplicate counter refreshes without recomputing or regranting permanent collection")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("NORMAL_CARD_COLLECTION_UI_OK ",checks," checks")
	else:print("NORMAL_CARD_COLLECTION_UI_FAILED ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
