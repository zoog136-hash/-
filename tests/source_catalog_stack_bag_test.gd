extends "res://tests/native_symbol_reward_bag_test.gd"
## Run with an isolated Godot user directory and the installed original packs.
## Seed the old save representation, reload, and use the player's touch path.
const SLOTS = preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const CATALOG_STACK = preload("res://scripts/loot/current523_catalog_stack.gd")
const SORT = preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const CASH = preload("res://scripts/shop/source523_cash_packages.gd")
const LABELS = preload("res://scripts/ui/source523_item_identity.gd")
const BOXES := [6161,9031,154074,315294,326313]

func open_bag(world: Node) -> RefCounted:
	var controller: Node = world.hud.original_main_ui_controller
	if not world.hud.original_inventory_is_open():
		var button: Node = controller._menu_scene.source_nodes[TOP.INVENTORY]
		await tap(button.get_meta("source_button")._input_area)
		await frames()
	return controller._inventory_view

func slot(world: Node, ref: String) -> Dictionary:
	var view: RefCounted = await open_bag(world)
	if view._hits.has(ref):
		var existing: Control = view._hits[ref].control
		var point: Vector2 = existing.get_global_transform_with_canvas()*(existing.size/2)
		if world.hud.original_inventory_hit_at(point).get("reference") == ref: return view._hits[ref]
	var up := InputEventScreenDrag.new()
	up.relative = Vector2(0,100000)
	view._forward_scroll_input(up)
	for attempt: int in 30:
		if view._hits.has(ref):
			var hit: Dictionary = view._hits[ref]
			var button: Control = hit.control
			var center: Vector2 = button.get_global_transform_with_canvas() * (button.size/2)
			if world.hud.original_inventory_hit_at(center).get("reference") == ref: return hit
		var step := InputEventScreenDrag.new()
		step.relative = Vector2(0,-65)
		view._forward_scroll_input(step)
		await process_frame
	print("CATALOG_STACK_LOOKUP ",ref," count=",world.inventory.get(ref)," visible=",view._hits.keys()," rows=",world.hud.lineage_inventory_ui.sorted_references)
	return {}

func marker_pixels(node: Node2D, control: Control) -> int:
	await RenderingServer.frame_post_draw
	var shown := root.get_texture().get_image()
	node.hide()
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	node.show()
	await RenderingServer.frame_post_draw
	var projected := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,control.size)
	var pixel_scale := Vector2(shown.get_size())/root.get_visible_rect().size
	var area := Rect2i(Rect2(projected.position*pixel_scale,projected.size*pixel_scale))
	area = area.intersection(Rect2i(Vector2i.ZERO,shown.get_size()))
	var changed := 0
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			if shown.get_pixel(x,y) != hidden.get_pixel(x,y): changed += 1
	return changed

func arm(world: Node, ref: String, expected: String, pixels: bool=false) -> bool:
	var hit: Dictionary = await slot(world,ref)
	if not check(not hit.is_empty(),"original visible slot "+ref): return false
	await tap(hit.control)
	if not check(world.hud.lineage_inventory_ui.selected_item == ref,"touch selected "+ref): return false
	# A HUD refresh may replace the rendered slots during the touch.
	hit = await slot(world,ref)
	if not check(not hit.is_empty(),"live selected slot "+ref): return false
	var node: Node2D = hit.native_slot_scene.source_nodes.get(SLOTS.ACTION)
	if not check(is_instance_valid(node) and node.is_visible_in_tree() and node.get_meta("source_text").original_options.text == expected,"authored label "+ref): return false
	if pixels:
		var icon: Node2D = hit.native_slot_scene.source_nodes.get(SLOTS.ICON)
		var ic: int = await marker_pixels(icon,hit.control) if is_instance_valid(icon) else 0
		var letters: int = await marker_pixels(node,hit.control)
		print("CATALOG_STACK_PIXELS ",ref," icon=",ic," label=",letters)
		check(ic > 20 and letters > 10,"item and action both contribute visible pixels "+ref)
	return true

func use(world: Node, ref: String, label: String="사용", pixels: bool=false) -> bool:
	if not await arm(world,ref,label,pixels): return false
	var hit: Dictionary = await slot(world,ref)
	if not check(not hit.is_empty(),"same live slot before second tap"): return false
	await tap(hit.control)
	await frames()
	return true

func original_controls(world: Node, boxes: Dictionary) -> void:
	var c: Node = world.hud.original_main_ui_controller
	var view: RefCounted = await open_bag(world)
	var chrome: RefCounted = view._chrome
	var sort_scene: Node2D = chrome._sort_scene()
	if check(is_instance_valid(sort_scene),"original sort controls"):
		await tap(sort_scene.source_nodes[SORT.SORT_BUTTON].get_meta("source_button")._input_area)
		check(chrome._sort_open,"touch opens the sort options")
		await tap(sort_scene.source_nodes[SORT.SORT_KEYS.weight].get_meta("source_button")._input_area)
		var order: Array = world.ui_preferences.inventory_order
		check(order.find(boxes[154074]) < order.find(boxes[6161]),"descending uses the two originals' different weights")
		sort_scene = chrome._sort_scene()
		await tap(sort_scene.source_nodes[SORT.SORT_KEYS.weight].get_meta("source_button")._input_area)
		order = world.ui_preferences.inventory_order
		check(order.find(boxes[6161]) < order.find(boxes[154074]),"second weight touch reverses real legacy rows")
		chrome.close_sort()
	if await arm(world,boxes[6161],"사용"):
		if check(is_instance_valid(view._detail_area),"selected bag item has its original detail button"):
			await tap(view._detail_area)
			var popup: RefCounted = c.item_tooltip()
			var detail: Dictionary = popup.last_result if is_instance_valid(popup) else {}
			check(detail.get("member") == "UI/ToolTip/ToolTip_CommonType.csb" and detail.get("item_class_id") == 6161 and detail.get("picture",false) and not str(detail.get("description","")).is_empty(),"actual box detail has its original scene, icon and description")
			world.hud.lineage_inventory_ui.close_item_info()
	c.close_inventory()
	var profile: Node2D = c._char_scene.source_nodes[20552]
	await tap(profile.get_meta("source_button")._input_area)
	check(world.hud.active_section=="character" and c.character_is_open(),"touching the HUD character button opens the original character equipment screen")
	world.hud._close_workspace()

func inventory_pictures(world: Node) -> void:
	# Actual inventory scene, including an animated CSB card and the two
	# original weapon/armor scroll-box PNGs. No reward is consumed here.
	for id: int in [133013,133023,139781,160062]:
		var issued := [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}]
		if not check(SUPPLY.commit(world,issued,{"kind":"catalog_slot_pixel_test"}),"supply exact picture test item "+str(id)): continue
		await frames()
		var key: String = world._catalog_item_from_source_id("m523:item:"+str(id)).name
		var ref: String = ""
		for entry: Dictionary in world.hud.lineage_inventory_ui._inventory_entries():
			if entry.name == key: ref = str(entry.reference); break
		var hit: Dictionary = await slot(world,ref)
		if not check(not hit.is_empty(),"real bag picture slot "+str(id)): continue
		var art: Node2D = hit.native_slot_scene.source_nodes.get(SLOTS.ICON)
		var pixels: int = await marker_pixels(art,hit.control) if is_instance_valid(art) else 0
		print("CATALOG_STACK_ICON ",id," pixels=",pixels)
		check(pixels>20,"original slot displays the selected item's pixels "+str(id))

func tap_enchant(forge: RefCounted, target: String) -> void:
	if not check(forge.select_target(target).get("ok",false),"select an exact target in EnchantScene"): return
	var node: Node2D = forge._row(forge._scene,forge._last_out,forge.P_SMELT_START)
	if check(is_instance_valid(node) and node.has_meta("source_button"),"authored enhancement button"):
		await tap(node.get_meta("source_button")._input_area)
		await frames()

func original_bag() -> void:
	root.size = Vector2i(2048,919)
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	if not check(QA.enter_game(world),"normal Main content startup"): world.queue_free(); return
	await frames()
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer = -100000
	world.level = 85
	world.gold = 100000
	var initial: Dictionary = {}
	for id: int in BOXES + [182411,320802,117284,117304,607]:
		var key: String = LABELS.original_name(id)
		initial[id] = key
		world.inventory[key] = 2
	if not check(world._save_game(true) == OK,"write legacy balance fixture"): world.queue_free(); return
	world._load_game(true)
	await frames()
	await original_controls(world,initial)
	var cash_scroll: Dictionary = world._find_catalog_item_record(initial[320802])
	check(cash_scroll.get("sourceId") == "cash523:320802","plain leaf comes from the actual cash catalog")
	var forged: Dictionary = world._find_catalog_item_record(initial[6161]).duplicate()
	forged.sourceUrl = "https://lineagem.inven.co.kr/db/item/9031"
	check(CATALOG_STACK.native_record(world,forged).is_empty(),"same label, mismatching URL rejected")
	var original_key: String = initial[6161]
	world._set_item_locked(original_key,true)
	var digest: String = FileAccess.get_sha256(world.save_path())
	var rng: int = world.rng.state
	await use(world,original_key)
	check(world.inventory.get(original_key) == 2 and world.rng.state == rng and FileAccess.get_sha256(world.save_path()) == digest,"locked box cannot consume, roll or write")
	world._set_item_locked(original_key,false)
	for id: int in BOXES:
		var key: String = initial[id]
		var before: Dictionary = world.inventory.duplicate()
		await use(world,key,"사용",id == 6161)
		var rewards: Dictionary = {}
		for target: String in world.inventory:
			var added := int(world.inventory[target])-int(before.get(target,0))
			if added > 0: rewards[target] = added
		print("CATALOG_STACK_USE ",id," left=",world.inventory.get(key)," rewards=",JSON.stringify(rewards))
		check(world.inventory.get(key) == 1 and not rewards.is_empty(),"one saved box pays a real original reward "+str(id))
		if id == 6161:
			var next: Dictionary = world._catalog_item_from_source_id("m523:item:6851")
			check(rewards.get(next.name) == 1,"knight gets its authored class box")
	var points: int = world.growth.state.points
	await use(world,initial[117284],"사용",true)
	check(world.inventory.get(initial[117284]) == 1 and world.growth.state.points == points+10,"old small water pays ten points in the same save")
	check(world.growth.source523.plain_recharge(world,world._find_catalog_item_record(initial[117304])).is_empty(),"permanent and dated large water cannot be identified by a shared bare label")
	var supplied: Dictionary = CASH.resolve(world,117304)
	check(supplied.get("kind") == "symbol_material","a new exact large water has a physical supplier")
	var before: Dictionary = world.inventory.duplicate()
	var travel: bool = OS.get_environment("TWILIGHT_CATALOG_STACK_TRAVEL") == "1"
	if travel:
		if check(world.current523_aden_source_active(),"installed original map active"):
			var setup: Dictionary = world.content523_enter_land(46952,[32787,32715,32787,32715],preload("res://tests/items523_location_teleport_test.gd").SETUP_WAIVE)
			check(setup.get("ok",false),"setup character at authored Tower entrance")
			world.portal_cooldown = 0.0 # The fixture pauses the World clock.
			check(world._item_requests_map_loading(initial[182411]),"old faith scroll uses the game's loading path")
			await use(world,initial[182411])
			for tick: int in 600:
				if not world.MAP_LOADING.busy(world): break
				await process_frame
			check(int(world.orim_current_land().get("land_id",-1)) == 47914 and world.inventory.get(initial[182411]) == 1,"touch arrives on original faith floor and pays once")
	else:
		await use(world,initial[182411])
		check(world.inventory == before and world.hud.message_label.text.contains("지도"),"actual travel owner refuses unavailable map without a debit")
	var target_grant := [{"item_class_id":629,"amount":1,"bless_raw":1,"enchant":0}]
	check(SUPPLY.commit(world,target_grant,{"kind":"enhancement_target_regression"}),"issue one compatible original accessory")
	await frames()
	await use(world,initial[320802])
	print("CATALOG_STACK_ENHANCE ",world.hud.active_section," ",world.hud.message_label.text," candidate_count=",world.hud.enhancement_candidates.size())
	check(world.hud.active_section == "enhance" and world.inventory.get(initial[320802]) == 2,"shining scroll opens the target chooser without spending")
	var targets: Array = world.hud.enhancement_candidates
	var compatible: Array = targets.filter(func(row: Dictionary) -> bool: return world.item_instances.get(row.instance_id,{}).get("record",{}).get("source_item_class_id")==629)
	if check(compatible.size()==1 and is_equal_approx(float(compatible[0].success_chance),70.0) and int(compatible[0].cost)==1000,"the actual chooser quotes original target #629, 70 percent and 1000 adena"):
		var forge: RefCounted = world.hud.original_main_ui_controller.enchant_window()
		if check(is_instance_valid(forge) and forge.is_open(),"original EnchantScene mounted"):
			var uid: String = compatible[0].instance_id
			var previous_gold: int = world.gold
			var previous_rng: int = world.rng.state
			var previous_file := FileAccess.get_sha256(world.save_path())
			world.source_save_blocked = true
			await tap_enchant(forge,compatible[0].target_id)
			world.source_save_blocked = false
			check(world.inventory.get(initial[320802])==2 and world.gold==previous_gold and world.rng.state==previous_rng and FileAccess.get_sha256(world.save_path())==previous_file,"failed save restores the scroll, adena, RNG and saved bytes")
			await tap_enchant(forge,compatible[0].target_id)
			check(world.inventory.get(initial[320802])==1 and world.gold==previous_gold-1000,"original roll spends one old scroll and 1000 adena")
			check(not world.item_instances.has(uid) or world._item_instance_level(uid,compatible[0].name)==1,"original roll resolves the exact accessory UID")
	world.hud._close_workspace()
	var guard: String = world._chosen_instance(initial[607])
	await use(world,initial[607]+"@@@"+guard,"장착")
	check(world.equipped_items.offhand.get("instance_id") == guard,"bag equips selected guarder")
	world._load_game(true)
	await frames()
	for id: int in BOXES: check(world.inventory.get(initial[id]) == 1,"exact legacy balance after reload "+str(id))
	check(world.inventory.get(initial[117284]) == 1 and world.growth.state.points == points+10,"reloaded water debit and points")
	check(world.inventory.get(initial[320802])==1,"reloaded original scroll debit")
	if travel: check(int(world.orim_current_land().get("land_id",-1)) == 47914 and world.inventory.get(initial[182411]) == 1,"real reload keeps arrival and exactly one payment")
	await inventory_pictures(world)
	world.queue_free()
	await frames()

func run() -> void:
	if OS.get_environment("TWILIGHT_CATALOG_STACK_BAG") != "1":
		print("Set TWILIGHT_CATALOG_STACK_BAG=1 in a disposable profile with the selected original packs")
		quit(2)
		return
	await original_bag()
	print("CATALOG_STACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
