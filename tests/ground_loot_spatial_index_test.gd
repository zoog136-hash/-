extends SceneTree
## Exercise actual placement/removal/restore with rendering isolated.
const MANAGER = preload("res://scripts/loot/ground_loot_manager.gd")
var checks: int = 0
var failures: Array[String] = []

class TestWorld extends Node:
	var drops_root := Node2D.new()
	var loot_catalog: Dictionary = {"by_name":{"물약":{"name":"물약","grade":"일반","slot":"consumable"}}}
	var maps_by_id: Dictionary = {"a":{},"b":{}}
	var item_instances: Dictionary = {}
	var next_item_instance_id: int = 1
	var walkability_checks: int = 0
	var walkable: bool = true
	func _is_walkable_world(point: Vector2) -> bool:
		walkability_checks += 1
		return walkable and point.is_finite()
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return true
	func _world_to_cell(point: Vector2) -> Vector2i: return Vector2i(point)
	func _nearest_walkable_cell(cell: Vector2i) -> Vector2i: return cell
	func _cell_to_world(cell: Vector2i) -> Vector2: return Vector2(cell)

class TestManager extends TwilightGroundLootManager:
	func _create_view(record: Dictionary) -> Button:
		var view := TwilightGroundLoot.new()
		view.set_meta("id",record.id)
		view.visible_since = Time.get_ticks_msec()-1000
		world.drops_root.add_child(view)
		views[str(record.id)] = view
		return view

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func linear_occupied(manager: TwilightGroundLootManager, point: Vector2) -> bool:
	for record: Dictionary in manager.records.values():
		if str(record.map_id) == manager.current_map and manager._position(record).distance_squared_to(point) < 36.0*36.0: return true
	return false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world.add_child(world.drops_root)
	var manager := TestManager.new()
	manager.configure(world)
	manager.current_map = "a"
	var saved: Array = []
	var expires: float = Time.get_unix_time_from_system()+300
	for map_id: String in ["a","b"]:
		for index: int in range(900):
			saved.append({"id":map_id+str(index),"item_name":"물약","quantity":1,"grade":"일반",
				"map_id":map_id,"position":[2000+index%30*72,2000+index/30*72],"expires_at":expires,"state":"ground"})
	manager.restore(saved)
	check(manager.records.size()==1800 and manager.views.size()==900,"restore keeps all maps but only active-map views")
	manager.occupancy_probes = 0
	check(not manager._occupied(Vector2.ZERO),"distant maps do not occupy local floor")
	check(manager.occupancy_probes == 0,"empty local placement performs no distant-record comparisons")
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	for index: int in range(250):
		var point := Vector2(rng.randf_range(1950,4200),rng.randf_range(1950,4200))
		check(manager._occupied(point)==linear_occupied(manager,point),"equivalent occupancy %d" % index)
	# Immediate spawn already checked its accepted position. A transaction
	# staging a record separately still has to reject later collision/map changes.
	world.walkability_checks = 0
	var ordinary: Button = manager.spawn("물약",Vector2(-1000,-1000))
	check(ordinary != null and world.walkability_checks == 1,"immediate spawn checks walkability once")
	var staged: Dictionary = manager.stage_spawn("물약",Vector2(-1500,-1500))
	world.walkable = false
	check(not staged.is_empty() and manager.publish_spawn(staged) == null and not manager.records.has(staged.id),"staged publish still rejects changed walkability")
	world.walkable = true
	check(manager.spawn("물약",Vector2(-1500,-1500)) != null and manager.publish_spawn(staged) == null,"staged publish still rejects occupied position")
	var dropped: Array[Button] = []
	for _index: int in range(12):
		var view: Button = manager.spawn("물약",Vector2.ZERO)
		check(view!=null,"burst drop gets a separate floor position")
		if view==null: continue
		dropped.append(view)
		var record: Dictionary = manager.records[str(view.get_meta("id"))]
		var p: Vector2 = manager._position(record)
		var overlaps: int = 0
		for other: Dictionary in manager.records.values():
			if other.map_id=="a" and manager._position(other).distance_squared_to(p)<36*36: overlaps+=1
		check(overlaps==1,"burst drop keeps the original 36px separation")
	var first: Button = dropped[0]
	var id: String = str(first.get_meta("id"))
	var position_value: Vector2 = manager._position(manager.records[id])
	check(not manager.take(first,position_value+Vector2(500,0),60).has("id"),"distant pickup cannot remove record")
	check(manager.take(first,position_value,60).get("id","")==id,"nearby pickup removes the authoritative ID")
	check(not manager._occupied(position_value),"collected position is released from spatial index")
	check(manager.take(first,position_value,60).is_empty(),"stale pickup cannot collect twice")
	var snapshot: Array = manager.snapshot()
	manager.restore(snapshot)
	check(manager.records.size()==snapshot.size(),"snapshot restore preserves record count")
	manager.activate("b")
	check(not manager._occupied(Vector2.ZERO),"map switch rebuilds index without previous-map drops")
	check(manager._occupied(Vector2(2000,2000)),"map switch indexes destination drops")
	manager.clear_map("b")
	check(manager.occupancy.is_empty() and manager.views.is_empty(),"clear_map removes every active bucket and view")
	manager.activate("a")
	for record: Dictionary in manager.records.values(): record.expires_at = 0.0
	manager.prune()
	check(manager.records.is_empty() and manager.occupancy.is_empty(),"expiry removes all remaining index entries")
	_test_floor_id_restore(world,manager)
	world.queue_free()
	await process_frame
	print("GROUND_LOOT_SPATIAL_INDEX_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _test_floor_id_restore(world: TestWorld, manager: TestManager) -> void:
	var expires: float = Time.get_unix_time_from_system()+300
	var records: Array = []
	for row: Array in [["bad-position","a","91"],["first","b","91"],["duplicate","a","91"],["first","a","92"],["other","a","92"],["bag","a","93"]]:
		records.append({"id":row[0],"map_id":row[1],"position":[] if row[0]=="bad-position" else [200,200],
			"expires_at":expires,"state":"ground","item_name":"물약","quantity":1,
			"physical_item":{"id":row[2],"data":{"name":"물약","level":9}}})
	world.item_instances["93"] = {"name":"물약"}
	var original: Array = records.duplicate(true)
	manager.restore(records)
	check(manager.records.keys()==["first","other"],"only accepted floor rows reserve IDs, even across maps")
	check(manager.records.first.map_id=="b" and manager.records.first.physical_item.id=="91","first valid owner survives a later duplicate")
	check(manager.records.other.physical_item.id=="92" and records==original,"duplicate ground ID leaves later valid physical owner and input intact")
	check(world.item_instances.has("93") and world.next_item_instance_id==93,"bag collision remains rejected and numeric allocator is preserved")
