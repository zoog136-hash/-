extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const LAYOUT = preload("res://tests/ground_capture_layout.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	if not QA.enter_game(world):
		world.queue_free()
		quit(1)
		return
	world.set_process(false)
	world.save_timer = -10000
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world._clear_monsters()
	world._clear_drops()
	var layout: Dictionary = LAYOUT.find_layout(world)
	check(not layout.is_empty(), "installed map has a valid twelve-sample gallery floor")
	if not layout.is_empty():
		var offsets: Array = layout.offsets
		check(offsets.size()==12, "all twelve samples retained")
		var record: Dictionary = {}
		for item: Dictionary in world.catalog_db.get("아이템",[]):
			if str(item.get("name",""))=="HP 물약": record=item; break
		check(not record.is_empty(), "real potion catalog record")
		var views: Array[Button] = []
		for offset: Vector2 in offsets:
			var point: Vector2 = layout.anchor+offset
			check(world.field_map.walkable(point) and world.field_map.point_clear(point), "drop origin on actual passable floor")
			var view: Button = world.ground_loot.spawn("HP 물약",point,1,"",{"item_record":record})
			check(is_instance_valid(view), "actual loot manager creates each sample")
			if is_instance_valid(view):
				var actual: Vector2 = view.get_meta("world_position")
				check(actual.distance_to(point)<0.01, "no relocation off the planned grid")
				views.append(view)
		check(views.size()==12, "twelve real drop views created without changing loot rules")
		world._clear_drops()
	print("GROUND_CAPTURE_LAYOUT_OK checks=%d" % checks if failures.is_empty() else "GROUND_CAPTURE_LAYOUT_FAILED "+JSON.stringify(failures))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
