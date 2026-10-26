extends SceneTree

const QA=preload("res://tests/qa_class_selection.gd")
const UI=preload("res://scripts/ui/renewal_theme.gd")
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
	if not ok:failures.append(why);print("WORKSHOP FAIL ",why)
func settle() -> void:
	for frame: int in range(5):await process_frame
func tap(control: Control,index: int=89) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	touch(point,index,true);touch(point,index,false)
func touch(point: Vector2,index: int,down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.position=point;event.index=index;event.pressed=down
	root.push_input(event,true)
func swipe(control: Control,index: int) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	touch(point,index,true)
	var drag:=InputEventScreenDrag.new()
	drag.index=index;drag.position=point+Vector2(0,-90);drag.relative=Vector2(0,-90)
	root.push_input(drag,true);touch(drag.position,index,false)

func run() -> void:
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await settle()
	check(QA.enter_game(world),"class selection")
	world.save_timer=-100000
	world.set_process(false);world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	world.inventory={"강철 한손검":4,"강력 HP 물약":5,"미스릴 원석":8,"정령의 가루":3,"희귀 제작 비법서":1,"무기 마법 주문서 (각인)":10}
	world.item_instances.clear();world.equipped_items.clear();world.gold=20000
	world._sync_item_instances()
	var ids: Array[String]=[]
	for id: String in world.item_instances:
		if str(world.item_instances[id].get("name",""))=="강철 한손검":ids.append(id)
	ids.sort()
	world.item_instances[ids[0]]["level"]=3
	world.equipped_items["weapon"]={"instance_id":ids[1],"name":"강철 한손검","level":0}
	world._update_hud()
	var hud: Node=world.hud
	var inventory_before: Dictionary=world.inventory.duplicate(true)
	var physical_before: Dictionary=world.item_instances.duplicate(true)
	hud.open_crafting()
	var craft: Control=hud.workspace.content.get_child(0)
	craft.current_id="blade_mithril";craft._rebuild_listing()
	await settle()
	check(craft.product.texture==UI.item_icon(world._craft_item_index()["미스릴 한손검"],"미스릴 한손검",hud.item_image_index.get("아이템",{})),"preview uses exact output art")
	check(craft._available_material("강철 한손검",world._craft_item_index())==2,"material count excludes equipped and upgraded physical copies")
	check(not craft.action.disabled,"authoritative valid recipe can proceed")
	craft.amount.value=2
	check(craft.action.disabled and craft.product_name.text.ends_with("×2"),"batch changes output and blocks insufficient physical ingredients")
	check(craft.cost.text=="7,200 아데나","batch cost follows existing recipe")
	craft.amount.value=1
	tap(craft.action)
	await settle()
	var confirm: Control=hud.get_node("Root/TwilightConfirmation")
	check(confirm!=null,"native craft tap opens existing confirmation")
	if confirm!=null:tap(confirm.cancel_button)
	await settle()
	check(world.inventory==inventory_before and world.item_instances==physical_before and world.gold==20000,"selection and canceled crafting do not mutate items or wallet")
	craft.name_filter.text="없는 제작법"
	craft.name_filter.text_changed.emit(craft.name_filter.text)
	check(craft.recipe_ids.is_empty() and craft.action.disabled and craft.product.texture==null,"empty search clears stale output and disables transaction")
	craft.name_filter.clear();craft.name_filter.text_changed.emit("")
	craft.grade_filter.select(3);craft.grade_filter.item_selected.emit(3)
	check(not craft.recipe_ids.is_empty(),"grade filter retains real recipes")
	for id: String in craft.recipe_ids:
		var name_value: String=world.crafting.recipes[id].result.item
		check(str(world._craft_item_index()[name_value].grade)=="희귀","filter never changes recipe identity")
	craft.grade_filter.select(0);craft.grade_filter.item_selected.emit(0)
	await settle()
	var point: Vector2=craft.listing.get_global_transform_with_canvas()*craft.listing.get_item_rect(2).get_center()
	var expected: String=craft.recipe_ids[2]
	touch(point,90,true);touch(point,90,false)
	await settle()
	check(craft.current_id==expected,"native recipe tap selects matching recipe ID")
	for extent: Vector2i in [Vector2i(854,480),Vector2i(640,480)]:
		root.size=extent;DisplayServer.window_set_size(extent)
		await settle()
		hud.open_crafting();craft=hud.workspace.content.get_child(0)
		craft.current_id="blade_mithril";craft._rebuild_listing()
		await settle()
		if craft.layout.tabs.visible:
			tap(craft.layout.tabs.get_child(1));await settle()
		check(craft.action.is_visible_in_tree() and craft.action.get_global_rect().end.y<=hud.workspace.content.get_global_rect().end.y+1,"small crafting action remains visible "+str(extent))
		check(craft.material_scroll.size.y>=80,"small crafting preview retains a usable swipe region "+str(extent))
		if craft.material_scroll.get_v_scroll_bar().max_value>craft.material_scroll.get_v_scroll_bar().page:
			swipe(craft.material_scroll,91)
			await settle()
			check(craft.material_scroll.scroll_vertical>0,"native material swipe reaches hidden requirements "+str(extent))
		var candidates: Array=world._enhancement_candidates("weapon","normal")
		hud.open_enhancement("무기 마법 주문서 (각인)",candidates)
		await settle()
		var forge: Control=hud.workspace.content.get_child(0)
		if forge.browser.tabs.visible:
			tap(forge.browser.tabs.get_child(1));await settle()
		check(forge.action.is_visible_in_tree() and forge.action.get_global_rect().end.y<=hud.workspace.content.get_global_rect().end.y+1,"small enhancement action remains visible "+str(extent))
		check(forge.detail.get_parsed_text().contains("소실") and forge.detail.get_parsed_text().contains("100.0%"),"all authoritative probability rows remain present")
		if forge.info_scroll.get_v_scroll_bar().max_value>forge.info_scroll.get_v_scroll_bar().page:
			swipe(forge.info_scroll,92)
			await settle()
			check(forge.info_scroll.scroll_vertical>0,"native forge swipe reaches probabilities "+str(extent))
		hud._close_workspace()
		hud._open_enhance_chooser()
		await settle()
		forge=hud.workspace.content.get_child(0)
		check(forge.mode=="scroll" and not forge.values.is_empty(),"reopen returns to owned scrolls")
		tap(hud.workspace.find_child("CloseWindow",true,false))
		await settle()
		check(not hud.workspace.visible,"native close remains functional")
	check(world.inventory==inventory_before and world.item_instances==physical_before,"browse, filter, swipe and reopen preserve physical inventory")
	await RenderingServer.frame_post_draw
	world.queue_free();await process_frame
	if failures.is_empty():print("UI_WORKSHOP_FLOW_OK");quit(0)
	else:print("UI_WORKSHOP_FLOW_FAILED ",failures);quit(1)
