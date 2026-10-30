extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		print("EQUIPMENT_RECORD_CACHE_RESULT missing Main scene")
		quit(1)
		return
	var world: TwilightWorld = scene.instantiate() as TwilightWorld
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	world.equipped_items = {}
	world.equipped_catalog = {"변신":{},"마법인형":{},"성물":{}}
	world._invalidate_equipment_static()
	var initial_hp: int = world._effective_max_hp()
	var first_rebuilds: int = world.equipment_record_rebuilds
	for index: int in range(40):
		world._effective_max_hp()
		world._effective_max_mp()
		world._equipped_numeric_sum("atk")
	if world.equipment_record_rebuilds != first_rebuilds:
		failures.append("unchanged equipment records rebuilt")
	world.equipped_items["ring1"] = {"name":"__cache_probe__","slot":"ring","hpFlat":30,"instance_id":"cache-probe"}
	world._invalidate_equipment_static()
	if world._effective_max_hp() != initial_hp + 30:
		failures.append("equipped HP did not invalidate")
	var before_unequip: int = world.equipment_record_rebuilds
	world._unequip_item_reference("__cache_probe__@@@cache-probe")
	if world._effective_max_hp() != initial_hp:
		failures.append("unequip retained cached HP")
	if world.equipment_record_rebuilds <= before_unequip:
		failures.append("unequip did not rebuild records")
	print("EQUIPMENT_RECORD_CACHE_RESULT ",JSON.stringify({"failures":failures,"repeat_queries":120,"rebuilds":world.equipment_record_rebuilds}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
