extends SceneTree
## The actual Main bag and pickup buttons, in a disposable profile. A small
## walkable grid isolates the item route when the private map is not mounted.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const SOURCE_ITEMS = preload("res://scripts/loot/patch523_item_inventory.gd")
const STACKS = preload("res://scripts/loot/current523_native_stack.gd")

var world: TwilightWorld
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)

func restored_physical_picture(origin: Vector2) -> void:
	if not SOURCE_IMAGES.selected():return
	var award: Dictionary=SOURCE_ITEMS.stage(world,[{"item_class_id":137,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	check(award.get("ok",false),"an exact original item can be granted for a floor roundtrip")
	if not award.get("ok",false):return
	var uid: String=""
	for id: String in award.overrides.item_instances:
		if not world.item_instances.has(id):uid=id;break
	if uid.is_empty():
		check(false,"the original equipment has a new physical ID");return
	world.inventory=award.overrides.inventory
	world.item_instances=award.overrides.item_instances
	var item: Dictionary=world.item_instances[uid]
	var item_name: String=item.name
	check(world._drop_inventory_reference(item_name+"@@@"+uid,origin),"the existing bag drop action transfers the exact item")
	if world.ground_loot.records.size()!=1:return
	var old: Dictionary=world.ground_loot.records.values()[0].duplicate(true)
	old.erase("item_record")
	var inconsistent: Dictionary=old.duplicate(true)
	inconsistent["item_record"]={"name":item_name}
	world._restore_ground_drops([inconsistent])
	var mismatch: TwilightGroundLoot=world.ground_loot.views.get(old.id)
	if mismatch!=null:mismatch.visible_since=Time.get_ticks_msec()-1000
	check(mismatch!=null and not world._collect_ground_drop(mismatch) and not world.item_instances.has(uid),"a conflicting duplicate record cannot claim a real floor receipt")
	var by_name: Dictionary=world.loot_catalog.get("by_name",{})
	var catalog_record: Dictionary=by_name.get(item_name,{})
	by_name.erase(item_name)
	world._restore_ground_drops([old])
	if not catalog_record.is_empty():by_name[item_name]=catalog_record
	var view: TwilightGroundLoot=world.ground_loot.views.get(old.id)
	check(view!=null and (view.body_drawn() or is_instance_valid(view.fallback_sprite)),"the old floor entry uses its physical item's source picture")
	if view==null:return
	if is_instance_valid(view.fallback_sprite):
		check(view.fallback_sprite.texture==SOURCE_IMAGES.describe_item(item.record,item_name).get("texture"),"floor fallback uses exactly the owned item's icon")
	view.pressed.emit()
	view.visible_since=Time.get_ticks_msec()-1000
	world.loot_pickup.pickup_button.pressed.emit()
	var returned: Dictionary=world.item_instances.get(uid,{})
	check(returned.get("sourceId")==item.get("sourceId") and STACKS.proof(world,uid).get("remaining")==1 and not world.ground_loot.records.has(old.id),
		"ordinary pickup restores the physical ID and removes the floor record (present=%s floor=%s locked=%s distance=%s)" % [
			not returned.is_empty(),world.ground_loot.records.has(old.id),world.player.movement_locked,
			world.player.global_position.distance_to(view.get_meta("world_position"))])
	check(not world._collect_ground_drop(view),"restored item cannot be collected twice")
	world._load_game(true)
	check(STACKS.proof(world,uid).get("remaining")==1 and not world.ground_loot.records.has(old.id),"exact receipt and floor removal persist after reload")

func run() -> void:
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer=-10000
	world.field_population.set_process(false)
	check(CLASS_QA.enter_game(world),"actual Main enters through class selection")
	world.player.set_physics_process(false)
	world._clear_monsters()
	world._clear_drops()
	var origin: Vector2=world.player.global_position
	if not world._is_walkable_world(origin):
		world.field_map=null
		world.astar=AStarGrid2D.new()
		world.astar.region=Rect2i(world._world_to_cell(origin)-Vector2i(2,2),Vector2i(5,5))
		world.astar.update()
		world.player.movement_locked=false
	var combat_labels: int=world.combat_vfx.emitted
	world.player.show_miss()
	world.player.show_received_damage(1,true)
	world.player.show_status_text("GUARD")
	check(world.combat_vfx.emitted==combat_labels,"live player receives no overhead combat text")
	var installed: bool=SOURCE_IMAGES.selected()
	if installed:restored_physical_picture(origin)
	world.queue_free()
	await process_frame
	print("GROUND_ORIGINAL_ITEM_LINKS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_images":installed}))
	quit(0 if failures.is_empty() else 1)
