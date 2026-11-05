extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Items=preload("res://scripts/cards/source_awakening_items.gd")
# Only floor geometry is a bounded fixture: original map packs are separate.
# Production map/save guards remain intact; this exercises the real collector.
class FloorFixture extends Node:
	var drops_root: Node
	var catalog_image_index: Dictionary={}
	var loot_catalog: Dictionary={}
	func _is_walkable_world(point: Vector2) -> bool:return point.is_finite()
	func _has_line_of_sight_world(_from: Vector2,_to: Vector2) -> bool:return true
	func _on_ground_drop_clicked(_drop: Button) -> void:pass
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world)
	for frame: int in range(8):await process_frame
	check(QA.enter_game(world),"actual class selection")
	world.set_process(false);world.save_timer=-100000;world.field_population.set_process(false);world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	var record: Dictionary={}
	for candidate: Dictionary in world.catalog_db["아이템"]:
		if candidate.get("source_item_class_id",0)==75184:record=candidate;break
	check(not record.is_empty(),"five source book definitions installed in actual World")
	if record.is_empty():world.queue_free();await process_frame;quit(1);return
	var before: int=world.item_instances.size()
	world.inventory[record.name]=3 # isolated legacy stack: never confer source provenance
	world._sync_item_instances()
	check(world.item_instances.size()==before,"legacy stack not backfilled on HUD sync")
	var floor_fixture:=FloorFixture.new();world.add_child(floor_fixture);floor_fixture.drops_root=world.drops_root;floor_fixture.loot_catalog=world.loot_catalog
	world.ground_loot.configure(floor_fixture)
	var drop: Button=world.ground_loot.spawn(str(record.name),world.player.global_position,2)
	check(is_instance_valid(drop),"actual ground spawn")
	if drop!=null:
		drop.visible_since=Time.get_ticks_msec()-1000
		check(world.ground_loot.records[str(drop.get_meta("id"))].get("item_record",{}).get("sourceId","")==record.sourceId,"spawn snapshots exact source identity")
		check(world._collect_ground_drop(drop),"actual pickup succeeds")
		check(int(world.inventory[record.name])==5 and world.item_instances.size()==before+2,"only two newly acquired copies gain physical provenance")
		world._update_hud()
		var bag: Node=world.hud.lineage_inventory_ui
		var rows: Array=bag._inventory_entries().filter(func(row: Dictionary)->bool:return row.name==record.name)
		check(rows.size()==1 and rows[0].amount==5,"actual inventory stacks five while transactions verify only two")
	var currency: int=world.gold;var rng: int=world.skill_awakening.selection_rng.state
	check(currency==world.gold and rng==world.skill_awakening.selection_rng.state,"pickup does not charge or select a skill")
	world.queue_free();await process_frame
	print("SKILL_GROUND_WORLD ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
