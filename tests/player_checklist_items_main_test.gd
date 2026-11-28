extends "res://tests/source_catalog_stack_bag_test.gd"
## Use a disposable character and the installed 523 definition, image and UI packs.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const QUICK = preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
const COIN: int = 3631
const DAGGER: int = 326
const TWO_HANDED: int = 179094
const GUARDER: int = 607
const SECOND_GUARDER: int = 609
const SCROLL: int = 137
const NAMED: int = 139781
const MYSTERY: int = 126363

func named_card(world: Node, refs: Dictionary) -> void:
	var named: Dictionary = world._catalog_item_from_source_id("m523:item:"+str(NAMED))
	var spec: Dictionary = STACK.profile(named).get("spec",{})
	var category: String = str(spec.get("card_kind",""))
	var card: Dictionary = STACK.card_binding(world,category,int(spec.get("card_id",0)))
	if not check(not card.is_empty(),"named card has the installed original catalog binding"):return
	var identity: String = world.card_draw_fusion.card_id(card)
	var before: int = world.card_draw_fusion.total_count(category,identity)
	var rng_before: int = world.rng.state
	var key: String = str(refs[NAMED])
	var uid: String = key.get_slice("@@@",1)
	if await use(world,key):
		check(not world.hud.is_card_reveal_busy() and world.card_draw_fusion.total_count(category,identity)==before+1 and not world.item_instances.has(uid) and world.rng.state==rng_before,"named card uses one physical receipt and adds the exact card without a reel or roll")
		world._load_game(true)
		check(not world.item_instances.has(uid) and world.card_draw_fusion.total_count(category,identity)==before+1,"named card debit and collection entry survive reload")
		check(not world.hud.lineage_inventory_ui.new_items_pending,"a reload does not report old items as new acquisitions")
	key = str(refs[MYSTERY])
	if await use(world,key):
		check(world.hud.is_card_reveal_busy() and not world.item_instances.has(key.get_slice("@@@",1)),"random mystery card still shows its committed draw")
		if is_instance_valid(world.hud.card_reveal_stage) and world.hud.card_reveal_stage.has_method("close_reveal"):
			world.hud.card_reveal_stage.close_reveal()

func quickslot_cooldown(world: Node) -> void:
	var controller: Node=world.hud.original_main_ui_controller
	var view: RefCounted=controller._quickslot_view
	if not check(is_instance_valid(view) and view.is_open(),"the actual active quickslot view is mounted"):return
	var skill_slot: Dictionary={}
	for hit: Dictionary in view._hits.values():
		if hit.entry.get("kind")=="skill":
			skill_slot=hit
			break
	if not check(not skill_slot.is_empty(),"the active quickslot has a skill"):return
	var shade: Node2D=skill_slot.native_slot_scene.source_nodes.get(QUICK.COOLDOWN_SHADE)
	if not check(is_instance_valid(shade) and not shade.is_visible_in_tree(),"the original skill-slot overlay is initially hidden"):return
	var key: String=str(skill_slot.entry.id)
	world._start_skill_cooldown({"name":key,"cooldown":8.0})
	controller.refresh_quickslots()
	var sprite: Sprite2D=shade.get_meta("source_sprite")
	if not check(shade.is_visible_in_tree() and sprite.texture!=null and sprite.get_meta("source_radial_fill",-1.0)==1.0,"the authored overlay covers the skill icon on a fresh cooldown"):return
	var material: Material=sprite.material
	world._tick_skill_cooldowns(4.0)
	controller.refresh_quickslots()
	check(shade.is_visible_in_tree() and sprite.material==material and sprite.get_meta("source_radial_fill",-1.0)==0.5,"half-time draws half a turn without replacing the slot material")
	world._tick_skill_cooldowns(4.0)
	controller.refresh_quickslots()
	check(not shade.is_visible_in_tree() and not world.skill_cooldown_totals.has(key),"expiry clears the overlay and its timer state")

func run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	if check(QA.enter_game(world),"normal Main enters as knight"):
		world.field_population.set_process(false)
		world.player.set_physics_process(false)
		world.level=90
		await frames()
		quickslot_cooldown(world)
		var menu_scene: Node2D=world.hud.original_main_ui_controller._menu_scene
		var badge: Node2D=menu_scene.source_nodes.get(TOP.INVENTORY_NOTICE)
		check(is_instance_valid(badge) and not badge.is_visible_in_tree(),"the original bag red dot starts hidden")
		var items: Array=[]
		for id: int in [COIN,SECOND_GUARDER,GUARDER,TWO_HANDED,DAGGER,NAMED,MYSTERY,SCROLL]:
			items.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
		if check(SUPPLY.commit(world,items,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}),"original coin, gear, scroll and two kinds of card are owned"):
			await frames()
			check(is_instance_valid(badge) and badge.is_visible_in_tree(),"a new bag acquisition lights the original red dot")
			var refs: Dictionary={COIN:"명예 코인"}
			for uid: String in world.item_instances:
				var row: Dictionary=world.item_instances[uid]
				refs[int(row.get("record",{}).get("source_item_class_id",0))]=str(row.name)+"@@@"+uid
			var view: RefCounted=await open_bag(world)
			check(is_instance_valid(badge) and not badge.is_visible_in_tree(),"opening the bag acknowledges the red dot")
			if check(is_instance_valid(view) and [DAGGER,TWO_HANDED,GUARDER,SECOND_GUARDER,SCROLL,NAMED,MYSTERY].all(func(id: int)->bool:return refs.has(id)),"native bag shows the acquired fixture"):
				var sort_scene: Node2D=view._chrome._sort_scene()
				await tap(sort_scene.source_nodes[SORT.SORT_BUTTON].get_meta("source_button")._input_area)
				var order_scene: Node2D=view._chrome._sort_scene()
				await tap(order_scene.source_nodes[SORT.SORT_KEYS.category].get_meta("source_button")._input_area)
				var order: Array=world.ui_preferences.inventory_order
				var sorted: Array=[COIN,DAGGER,GUARDER,SECOND_GUARDER,TWO_HANDED,SCROLL,MYSTERY,NAMED].map(func(id: int)->String:return refs[id])
				var shown: Array=order.filter(func(ref: String)->bool:return ref in sorted)
				check(shown==sorted,"authored category sort shows currency, gear and consumables in ItemClass order: "+str(shown))
				view._chrome.close_sort()
				if await use(world,refs[TWO_HANDED],"장착"):
					check(world.equipped_items.weapon.get("source_item_class_id")==TWO_HANDED,"two-handed weapon is equipped through real touch")
				for id: int in [GUARDER,SECOND_GUARDER]:
					if await use(world,refs[id],"장착"):
						check(world.equipped_items.offhand.get("source_item_class_id")==id and world.equipped_items.weapon.get("source_item_class_id")==TWO_HANDED,"original guarder and two-handed weapon equip together #"+str(id))
				await named_card(world,refs)
	world.queue_free()
	await frames()
	print("PLAYER_CHECKLIST_ITEMS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
