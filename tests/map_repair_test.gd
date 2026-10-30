extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const PNG=preload("res://scripts/maps/native_png_registry.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MAP_REPAIR_FAIL ",label)
func run() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world)
	world.set_process(false);world.save_timer=-100000
	var specs: Dictionary=PNG.read_json(PNG.EXTRA_PLAN_PATH).maps
	for mid: String in ["faith_01","faith_02","faith_03","faith_04"]:
		world._set_map(mid,false);world.portal_cooldown=100000
		world.field_population.set_process(false)
		for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
		var field: NativePngField=world.field_map
		var spec: Dictionary=specs[mid]
		check(is_equal_approx(field.artwork_scale,1.3),mid+" scale")
		check(field.bounds.size.is_equal_approx(Vector2(field.png_manifest.bounds[2],field.png_manifest.bounds[3])*1.3),mid+" exact linear bounds")
		var spawn:=Vector2(spec.spawn[0],spec.spawn[1])*1.3
		check(Vector2(field.data.spawn_position[0],field.data.spawn_position[1]).distance_to(spawn)<.01 and world.player.global_position.distance_to(spawn)<field.cell_size,mid+" spawn transform with cell-center landing")
		check(world.player.scale==Vector2.ONE and world.player.move_speed==210,mid+" unchanged actor")
		for raw: Array in field.data.route_checks:
			var point:=Vector2(raw[0],raw[1])
			check(field.walkable(point) and not field.path(spawn,point).is_empty(),mid+" route "+str(raw))
		for raw: Array in field.data.blocked_probes:check(not field.walkable(Vector2(raw[0],raw[1])),mid+" blocked probe")
		for monster: Node2D in world.monsters_root.get_children():check(field.walkable(monster.global_position) and field.point_clear(monster.global_position,4),mid+" live spawn")
		for direction: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var cell: Vector2i=field.world_to_cell(spawn)
			while field.astar.is_in_boundsv(cell+direction) and not field.astar.is_point_solid(cell+direction):cell+=direction
			world.player.global_position=field.cell_to_world(cell)
			await physics_frame;await physics_frame
			check(world.player.test_move(world.player.global_transform,Vector2(direction)*field.cell_size),mid+" physical boundary")
		world.player.global_position=field.cell_to_world(field.world_to_cell(spawn))
		var start: Vector2=world.player.global_position
		var walk_target:=Vector2.INF
		for offset: Vector2 in [Vector2(48,0),Vector2(-48,0),Vector2(0,48),Vector2(0,-48)]:
			if field.line_clear(start,start+offset):walk_target=start+offset;break
		check(walk_target.is_finite(),mid+" short actual walking route exists")
		if walk_target.is_finite():
			world._set_click_destination(walk_target)
			for frame: int in range(90):
				await physics_frame
				if world.player.global_position.distance_to(walk_target)<10:break
			check(world.player.global_position.distance_to(walk_target)<10 and field.walkable(world.player.global_position),mid+" actual player walks scaled floor")
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		world.player.global_position=spawn;world._save_game(true)
		var saved: Dictionary=PNG.read_json(world.save_path());saved.position=spec.spawn.duplicate();saved.map_layout_revision=2026102002
		WRITER.write(world.save_path(),saved)
		var hash: String=FileAccess.get_sha256(world.save_path());world._load_game(true)
		check(not world.source_save_blocked and world.player.global_position.distance_to(spawn)<1,mid+" legacy save scaled once")
		check(FileAccess.get_sha256(world.save_path())==hash and FileAccess.get_sha256(world.save_path()+".pre-aden-scale-"+hash)==hash,mid+" original save backup")
		world._save_game(true);world._load_game(true)
		check(world.player.global_position.distance_to(spawn)<1,mid+" repeated save load no double scale")
		for portal: Dictionary in field.data.portal:
			check(field.walkable(Vector2(portal.position[0],portal.position[1])),mid+" portal floor")
			check(world.use_field_portal(str(portal.id)) and world.active_map_id==str(portal.target_map),mid+" actual travel "+str(portal.id))
			world._set_map(mid,false)
	world._set_map("escaros_01",false)
	check(world.field_population.slots.size()==165,"Escaros retains 165 spawn slots")

	for slot: Dictionary in world.field_population.slots:
		if not is_instance_valid(slot.monster):continue
		var monster: TwilightMonster=slot.monster
		if monster.global_position.distance_to(world.player.global_position)<2500:continue
		monster.poison_remaining=1.0;world.field_population._update_activity(monster)
		check(monster.is_physics_processing(),"remote status keeps ticking")
		monster.poison_remaining=0;monster.dead=true;world.field_population._update_activity(monster)
		check(monster.is_physics_processing(),"remote corpse completes recycling")
		break
	print("MAP_REPAIR_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
