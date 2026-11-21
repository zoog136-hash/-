extends SceneTree
## User list 2026-11-21 #25: a pickup button beside the 셀프 (self/auto)
## button. With the original UI pack it is the original Hud_AttackPad
## Nd_PickUp (Hud_Btn_Pad_Get.png, placed by the original beside Nd_Self),
## now always shown; a real ScreenTouch on it collects the nearby floor items
## one after another, walks to a farther one, and still takes a selected drop
## first. Without the pack the same controller entry is exercised directly.
## Everything written under user:// is put back at the end.
const QA = preload("res://tests/qa_class_selection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const COMBAT = preload("res://scripts/ui/original_ui/source_main_combat_bindings.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("HUD_PICKUP_NEARBY_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func tap(at: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0; event.position = at; event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await frames(6)

func snapshot_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file: String in dir.get_files(): user_files[path.path_join(file)] = FileAccess.get_file_as_bytes(path.path_join(file))
	for sub: String in dir.get_directories(): snapshot_user(path.path_join(sub))

func restore_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for sub: String in dir.get_directories(): restore_user(path.path_join(sub))
	for file: String in dir.get_files():
		var full: String = path.path_join(file)
		if not user_files.has(full): DirAccess.remove_absolute(full)
	for full: String in user_files:
		if full.get_base_dir() != path: continue
		var current: PackedByteArray = FileAccess.get_file_as_bytes(full) if FileAccess.file_exists(full) else PackedByteArray()
		if current != user_files[full]:
			var out := FileAccess.open(full,FileAccess.WRITE)
			if out != null: out.store_buffer(user_files[full]); out.close()

func spawn(world: Node, item: String, at: Vector2) -> Button:
	var view: Button = world._spawn_ground_drop(item,at)
	if is_instance_valid(view): view.set("visible_since",Time.get_ticks_msec()-900)
	return view

func floor_item(world: Node) -> String:
	for name_value: String in ["HP 물약",str(D.definition_id("233").get("native_record",{}).get("name",""))]:
		if not name_value.is_empty() and not world._find_catalog_item_record(name_value).is_empty(): return name_value
	return ""

## The original pickup button's touch area, or null.
func pickup_control(hud: Node) -> Control:
	var controller: Variant = hud.get("original_main_ui_controller")
	if not is_instance_valid(controller): return null
	var scene: Variant = controller.get("_combat_scene")
	if not is_instance_valid(scene): return null
	var node: Variant = scene.get("source_nodes").get(COMBAT.PICKUP_BUTTON)
	var button: Variant = node.get_meta("source_button") if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant = button.get("_input_area") if is_instance_valid(button) else null
	return area if area is Control else null

func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

func press(world: Node, control: Control) -> void:
	if control != null: await tap(center(control))
	else:
		world.loot_pickup.request_nearby()
		await frames(4)

func finish(world: Node) -> void:
	world.queue_free()
	await frames(4)
	restore_user("user://")
	print("HUD_PICKUP_NEARBY_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(1 if not failures.is_empty() else 0)

func run() -> void:
	snapshot_user("user://")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world._clear_monsters()
	if world.get("field_population") != null: world.field_population.set_process(false)
	await frames(30)
	var hud: Node = world.hud
	var player: Node2D = world.player
	if world.get("field_map") is NativePngField:
		# The arrival plaza is compact: use reachable combat floor (as ground_drop_smoke_test).
		var origin: Vector2 = preload("res://tests/active_source_test_positions.gd").combat(world,[Vector2(0,0),Vector2(14,0),Vector2(-12,8),Vector2(4,-14),Vector2(150,0)])
		if origin.is_finite(): player.global_position = origin
	evidence["origin"] = str(player.global_position)
	world._clear_drops()
	var item: String = floor_item(world)
	if not check(not item.is_empty(), "a floor item can be spawned"):
		await finish(world); return
	evidence["item"] = item
	check(world.loot_pickup.has_method("request_nearby"), "the pickup controller collects nearby drops")
	var control: Control = pickup_control(hud)
	evidence["original_button"] = control != null
	if control != null:
		var controller: Node = hud.original_main_ui_controller
		var scene: Node2D = controller._combat_scene
		var group: Node2D = scene.get("source_nodes").get(COMBAT.PICKUP_GROUP)
		check(is_instance_valid(group) and group.is_visible_in_tree() and control.is_visible_in_tree(), "the original pickup button shows with nothing selected")
		var self_node: Node2D = scene.get("source_nodes").get(22536)
		if is_instance_valid(self_node):
			var distance: float = center(control).distance_to(self_node.get_global_transform_with_canvas().origin)
			evidence["self_distance"] = distance
			check(distance < 140.0, "it sits beside the 셀프 button (%.0f px)" % distance)
	# 1. three drops within reach, nothing selected -> one press takes all
	var before: int = int(world.inventory.get(item,0))
	var spawned: int = 0
	for offset: Vector2 in [Vector2(14,0),Vector2(-12,8),Vector2(4,-14)]:
		if is_instance_valid(spawn(world,item,player.global_position+offset)): spawned += 1
	evidence["spawned"] = spawned
	if spawned == 0 and DEF.not_installed():
		# CI without the original pack has no source field to place drops on;
		# the button press has nothing to act on there.
		evidence["floor"] = "no source field without the original pack"
		check(not world.loot_pickup.request_nearby() and world.loot_pickup.mode == "idle", "no drop: the pickup request does nothing")
		await finish(world); return
	check(spawned == 3, "three floor drops are placed around the player")
	check(world.loot_pickup.selected_id.is_empty(), "no drop is selected")
	await press(world,control)
	evidence["near"] = [before,int(world.inventory.get(item,0)),world.ground_loot.views.size(),world.loot_pickup.mode,world.loot_pickup.blocked.size(),str(world.hud.get("last_message")) if world.hud.get("last_message") != null else ""]
	check(int(world.inventory.get(item,0)) == before+3 and world.ground_loot.views.is_empty(), "one press collects the three nearby drops")
	# 2. a farther drop: the press walks to it, then it is collected
	var far: Vector2 = player.global_position+Vector2(150,0)
	if bool(world._is_walkable_world(far)):
		spawn(world,item,far)
		before = int(world.inventory.get(item,0))
		await press(world,control)
		check(world.loot_pickup.mode == "manual" and not (player.get("click_path") as PackedVector2Array).is_empty(), "a farther drop starts the walk to it")
		player.global_position = far
		world._tick_manual_ground_pickup()
		await frames(2)
		check(int(world.inventory.get(item,0)) == before+1, "and it is collected on arrival")
	else: evidence["far"] = "not walkable here"
	# 3. a selected drop is taken first
	var selected: Button = spawn(world,item,player.global_position+Vector2(10,0))
	spawn(world,item,player.global_position+Vector2(-10,0))
	world.loot_pickup.select(selected)
	before = int(world.inventory.get(item,0))
	await press(world,control)
	check(not is_instance_valid(selected) or selected.is_queued_for_deletion() or not world.ground_loot.views.values().has(selected), "the selected drop is collected")
	check(int(world.inventory.get(item,0)) == before+2 and world.ground_loot.views.is_empty(), "the press takes the selected drop and then the other one")
	# 4. nothing around: the press does nothing
	before = int(world.inventory.get(item,0))
	await press(world,control)
	evidence["empty"] = [before,int(world.inventory.get(item,0)),world.loot_pickup.mode,world.ground_loot.views.size()]
	check(int(world.inventory.get(item,0)) == before and world.loot_pickup.mode == "idle", "with no drop around nothing happens")
	await finish(world)
