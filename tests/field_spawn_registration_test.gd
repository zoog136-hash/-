extends SceneTree
## Real Main population registration: a new body must enter at its spawn,
## rather than sweeping the distance from the world origin next physics tick.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var entries: Dictionary={}
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func entered(actor: Node) -> void:
	if actor is TwilightMonster:
		entries[actor.get_instance_id()]={"tree":actor.global_position,"physics":(PhysicsServer2D.body_get_state(actor.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin}
func run() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"Main class entry")
	world.process_mode=Node.PROCESS_MODE_DISABLED;world.save_timer=-100000
	world.monsters_root.child_entered_tree.connect(entered)
	var map_id: String="escaros_world" if REGISTRY.enabled() else "oman_01"
	world.rng.seed=20261025;world._set_map(map_id,false)
	check(world.active_map_id==map_id,"actual requested map")
	var roster: Array=[]
	var pool_actor: TwilightMonster
	var pool_slot: Dictionary={}
	for slot: Dictionary in world.field_population.slots:
		var actor: TwilightMonster=slot.monster
		if not is_instance_valid(actor):continue
		var entry: Dictionary=entries.get(actor.get_instance_id(),{})
		check(not entry.is_empty(),"new actor enters tree")
		if entry.is_empty():continue
		check(entry.tree==actor.home_position,"tree registration equals final spawn")
		check(entry.physics==actor.home_position,"physics registration equals final spawn")
		check(actor.global_position==actor.home_position,"final position preserved")
		var shape: CollisionShape2D=actor.get_node("CollisionShape2D")
		if world.field_map is NativePngField or world.field_map is RemakePlayableField:
			check(shape.shape is CircleShape2D and shape.shape.radius==4. and shape.position==Vector2.ZERO,"existing map foot unchanged")
		check(actor.collision_layer==2 and actor.collision_mask==4,"existing collision filters unchanged")
		roster.append({"slot":slot.slot_id,"name":actor.monster_name,"position":[actor.global_position.x,actor.global_position.y],"hp":actor.hp,"attack":actor.attack_power,"speed":actor.move_speed,"attack_interval":actor.attack_interval,"cooldown":actor.attack_cooldown,"boss":actor.is_boss})
		if pool_actor==null and not actor.is_boss:pool_actor=actor;pool_slot=slot
	check(roster.size()==133 if REGISTRY.enabled() else not roster.is_empty(),"existing seeded population count")
	var count: int=world.monsters_root.get_child_count()
	world.field_population._spawn_slot(pool_slot)
	check(world.monsters_root.get_child_count()==count and pool_slot.monster==pool_actor,"live occupant not duplicated")
	pool_actor.dead=true
	check(world.field_population.recycle(pool_actor),"dead actor enters existing pool")
	pool_slot.monster=null
	world.field_population._spawn_slot(pool_slot)
	check(pool_slot.monster==pool_actor and not pool_actor.dead,"pooled actor reused and reset")
	check(world.monsters_root.get_child_count()==count,"pool reuse preserves count")
	check(pool_actor.global_position==pool_actor.home_position,"pooled final spawn preserved")
	check(pool_actor.collision_layer==2 and pool_actor.collision_mask==4,"pooled collision filters restored")
	var file_path: String=OS.get_environment("TWILIGHT_SPAWN_OUTPUT")
	if not file_path.is_empty():
		var file:=FileAccess.open(file_path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"roster":roster,"rng_state":world.rng.state},"\t"))
	print("SPAWN_REGISTRATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actors":roster.size()}))
	world.queue_free();quit(0 if failures.is_empty() else 1)
