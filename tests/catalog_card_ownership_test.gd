extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Ownership=preload("res://scripts/ui/catalog_card_ownership.gd")
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void:call_deferred("run")
func frames(count: int=5) -> void:
	for index: int in range(count):await process_frame
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("CARD_OWNERSHIP_FAIL ",why)
func ids(records: Array) -> Array[String]:
	var result: Array[String]=[]
	for record: Dictionary in records:result.append(Cards.card_id(record))
	return result
func expected(records: Array,owned: Dictionary) -> Array[String]:
	var acquired: Array[String]=[]
	var missing: Array[String]=[]
	for record: Dictionary in records:
		var id: String=Cards.card_id(record)
		if owned.has(id):acquired.append(id)
		else:missing.append(id)
	acquired.append_array(missing)
	return acquired
func check_page(hud: Node,permanent: Dictionary) -> void:
	for index: int in range(hud.catalog_results.size()):
		var record: Dictionary=hud.catalog_results[index]
		var acquired: bool=permanent.has(Cards.card_id(record))
		var icon: Texture2D=hud.catalog_list.get_item_icon(index)
		check(str(hud.catalog_list.get_item_metadata(index))==Cards.card_id(record),"dimmed native cells preserve exact stable IDs")
		check(hud.catalog_list.get_item_icon_modulate(index)==(Color.WHITE if acquired else Ownership.UNOWNED_ICON_TINT),"native tint uses permanent ownership, never duplicate quantity")
		check(icon.resource_path==str(record.image_path) if acquired else icon.get_image().get_format()==Image.FORMAT_LA8,"owned uses original art and missing uses a luminance thumbnail")
		if not acquired:
			check(icon==Ownership.icon_for(record,false),"missing luminance texture is shared across viewport changes")
			check(icon.get_size()==(load(str(record.image_path)) as Texture2D).get_size(),"missing presentation retains every source pixel")
	for card: Dictionary in hud.catalog_card_chrome.visible_cards:
		check(bool(card.owned)==permanent.has(Cards.card_id(hud.catalog_results[card.index])),"painted frame/aura receives the same authoritative ownership")
func cell_light(hud: Node) -> float:
	await RenderingServer.frame_post_draw
	var rect: Rect2=hud.catalog_list.get_item_rect(0,false)
	rect.position.y-=hud.catalog_list.get_v_scroll_bar().value
	var screen: Transform2D=root.get_final_transform()*hud.catalog_list.get_global_transform_with_canvas()
	var image: Image=root.get_texture().get_image()
	var pixels: Image=image.get_region(Rect2i(screen*rect.grow(-3)))
	pixels.convert(Image.FORMAT_RGB8)
	var energy: float=0.0
	for value: int in pixels.get_data():energy+=value
	return energy/maxi(1,pixels.get_data_size())
func swipe(list: ItemList) -> void:
	var at: Vector2=list.get_global_transform_with_canvas()*(list.size*.5)
	var down:=InputEventScreenTouch.new();down.index=741;down.position=at;down.pressed=true;root.push_input(down,true)
	var drag:=InputEventScreenDrag.new();drag.index=741;drag.position=at+Vector2(0,-170);drag.relative=Vector2(0,-170);root.push_input(drag,true)
	var up:=InputEventScreenTouch.new();up.index=741;up.position=drag.position;up.pressed=false;root.push_input(up,true)
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);await frames(8)
	check(QA.enter_game(world),"class confirmation")
	world.set_process(false);world.save_timer=-100000;world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	world.presentation_settings.reduced_motion=true
	var hud: Node=world.hud
	var catalog: Dictionary=hud.catalog_data.duplicate(true)
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var gold: int=world.gold
	var rng: int=world.card_draw_fusion.rng.state
	var world_cards: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		for category: String in Cards.CATEGORIES:
			var model=Cards.new();model.configure(world.catalog_db);model.rng.seed=741
			var records: Array=hud.catalog_data[category]
			for index: int in [5,43,83]:model.owned[category][Cards.card_id(records[index])]=true
			model.spare[category][Cards.card_id(records[43])]=4
			hud.set_card_collection_state(model.export_state())
			hud.catalog_view_state.erase(category);hud.open_catalog(category);await frames()
			check(ids(hud.catalog_filtered_results)==expected(records,model.owned[category]),"owned-first is stable across all grades and pages "+category+str(extent))
			check_page(hud,model.owned[category])
			var state: Dictionary=model.export_state().duplicate(true)
			var selection: String=Cards.card_id(hud.selected_catalog_record)
			swipe(hud.catalog_list);await frames()
			check(hud.catalog_list.get_v_scroll_bar().value>0 and Cards.card_id(hud.selected_catalog_record)==selection,"native swipe scrolls without selecting or consuming dimmed cards")
			hud.catalog_page=1;hud._apply_catalog_page();await frames()
			hud._select_catalog_index(30);await frames()
			selection=Cards.card_id(hud.selected_catalog_record)
			var scroll: float=hud.catalog_list.get_v_scroll_bar().value
			var award: Dictionary=model._receive(category,{"id":selection,"record":hud.selected_catalog_record})
			check(bool(award.new) and not model.spare[category].has(selection),"new acquisition has permanent ownership with zero duplicates")
			hud.set_card_collection_state(model.export_state());await frames()
			check(Cards.card_id(hud.selected_catalog_record)==selection and is_equal_approx(hud.catalog_list.get_v_scroll_bar().value,scroll),"live acquisition reorders across pages while preserving selection and scroll")
			check(ids(hud.catalog_filtered_results)==expected(records,model.owned[category]),"live acquisition updates stable owned-first order")
			check_page(hud,model.owned[category])
			# The same exact card is rendered before/after acquisition at one fixed
			# cell. This measures visible dimming rather than only inspecting tint.
			var missing: Dictionary=records[12]
			hud.catalog_search.text=str(missing.name);hud.catalog_search.text_changed.emit(hud.catalog_search.text);await frames()
			check(hud.catalog_results.size()==1 and Cards.card_id(hud.selected_catalog_record)==Cards.card_id(missing),"query keeps the selected exact source card")
			var dark: float=await cell_light(hud)
			model._receive(category,{"id":Cards.card_id(missing),"record":missing})
			hud.set_card_collection_state(model.export_state());await frames()
			var bright: float=await cell_light(hud)
			check(bright>dark*1.3,"actual acquired card is visibly brighter than its missing rendering "+category+str(extent))
			check(hud.catalog_search.text==str(missing.name) and Cards.card_id(hud.selected_catalog_record)==Cards.card_id(missing),"acquisition preserves active query and selected ID")
			hud.catalog_search.text="";hud.catalog_search.text_changed.emit("");await frames()
			hud.catalog_grade_filter="일반";hud._refresh_catalog_list("");await frames()
			var base: Array=[]
			for record: Dictionary in records:
				if str(record.grade)=="일반":base.append(record)
			check(ids(hud.catalog_filtered_results)==expected(base,model.owned[category]),"grade filter preserves stable order in both groups")
			var materials: Array=world.card_draw_fusion.pools[category]["일반"]
			for entry: Dictionary in materials.slice(0,2):model.owned[category][entry.id]=true;model.spare[category][entry.id]=2
			hud.set_card_collection_state(model.export_state());await frames()
			var outcome: Dictionary=model.fuse(category,"일반")
			check(bool(outcome.ok),"unchanged authoritative model executes actual fusion")
			hud.set_card_collection_state(model.export_state());await frames()
			var depleted: int=0
			for entry: Dictionary in materials.slice(0,2):
				if int(model.spare[category].get(entry.id,0))==0:
					depleted+=1
					check(model.owned[category].has(entry.id) and hud.catalog_filtered_results.slice(0,model.owned[category].size()).any(func(row: Dictionary) -> bool:return Cards.card_id(row)==str(entry.id)),"fusion depletion leaves permanent card in owned group")
			check(depleted>0,"fixture really consumes the last duplicate of a retained permanent card")
			check(ids(hud.catalog_filtered_results)==expected(base,model.owned[category]),"post-fusion order uses updated permanent ownership")
			check_page(hud,model.owned[category])
			selection=Cards.card_id(hud.selected_catalog_record)
			scroll=hud.catalog_list.get_v_scroll_bar().value
			hud.open_catalog("아이템");await frames()
			var late: Dictionary=base[base.size()-1]
			model._receive(category,{"id":Cards.card_id(late),"record":late})
			hud.set_card_collection_state(model.export_state());hud.open_catalog(category);await frames()
			check(hud.catalog_grade_filter=="일반" and Cards.card_id(hud.selected_catalog_record)==selection and is_equal_approx(hud.catalog_list.get_v_scroll_bar().value,scroll),"reopening retains filter/ID/scroll after acquisition while closed")
			check(ids(hud.catalog_filtered_results)==expected(base,model.owned[category]),"closed-window acquisition appears first on reopening")
			check(state!=model.export_state(),"fixture includes real acquisition and material consumption")
			hud._close_workspace();await frames()
	check(hud.catalog_data==catalog,"ownership partition never mutates the source catalog or card records")
	check(world.inventory==inventory and world.item_instances==instances and world.gold==gold and world.card_draw_fusion.export_state()==world_cards and world.card_draw_fusion.rng.state==rng,"UI-only acquisition fixtures preserve world item IDs, wallet, cards and RNG")
	check(Ownership.unowned_icons.size()<=Ownership.CACHE_LIMIT,"luminance cache stays bounded across categories and resolutions")
	world.queue_free();await process_frame
	print("CARD_OWNERSHIP_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
