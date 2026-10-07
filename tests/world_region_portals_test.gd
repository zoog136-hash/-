extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("PORTAL FAIL: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.save_timer = -10000
	var index: Array = JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH))
	world._set_map("aden_world",false)
	check(world.use_field_portal("oman_gate"),"Aden enters expanded tower")
	for i: int in range(index.size()):
		var id: String = str(index[i]["map_id"])
		check(world.active_map_id==id,"progression order: "+id)
		var field: PlayableField = world.field_map
		world.player.set_auto_enabled(true)
		world.player.set_click_path(field.path(world.player.global_position,COORD.array_vector(field.data["route_checks"][0])),Vector2.ZERO)
		var expected: String = str(index[i+1]["map_id"]) if i+1<index.size() else "aden_world"
		check(world.use_field_portal("next"),id+" next portal accepted")
		check(world.active_map_id==expected,id+" next destination")
		check(not world.player.auto_enabled and world.player.click_path.is_empty(),id+" stale hunt/path cleared")
		await physics_frame
		await process_frame
		check(world.field_map.walkable(world.player.global_position) and world.field_map.point_clear(world.player.global_position),expected+" landing clearance")
		check(world.field_minimap.field==world.field_map and world.field_renderer.field==world.field_map,expected+" renderer/minimap use new map")
		check(world.player.camera.limit_right==int(world.world_size.x) and world.player.camera.limit_bottom==int(world.world_size.y),expected+" new camera bounds")
		var body_count: int = 0
		for node: Node in world.get_children():
			if node is StaticBody2D and node.name=="FieldCollision":
				body_count += 1
		check(body_count==1,expected+" no leaked previous collision world")
		# Camera edges may clip walls but never expose outside world bounds.
		for point: Vector2 in [Vector2(180,180),world.world_size-Vector2(180,180)]:
			var old: Vector2 = world.player.global_position
			world.player.global_position=point
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			await process_frame
			var top: Vector2 = COORD.screen_to_world(root,Vector2.ZERO)
			var end: Vector2 = COORD.screen_to_world(root,Vector2(1280,720))
			check(top.x>=-.1 and top.y>=-.1 and end.x<=world.world_size.x+.1 and end.y<=world.world_size.y+.1,expected+" camera doesn't expose outside")
			world.player.global_position=old
	check(world.active_map_id=="aden_world","full progression returns to Aden")
	# Exercise the reverse link and actual proximity-triggered asynchronous travel.
	world._set_map("faith_01",false)
	check(world.use_field_portal("previous") and world.active_map_id=="albino_04","reverse family boundary")
	world._set_map("oman_02",false)
	world.portal_cooldown=0
	world.player.global_position=COORD.array_vector(world.field_map.data["portal"][0]["position"])
	world._update_field_triggers()
	await process_frame
	await process_frame
	check(world.active_map_id=="oman_01","walking onto a portal triggers real deferred map travel")
	world.queue_free()
	await process_frame
	print("PORTAL checks=",checks)
	if failures.is_empty():
		print("WORLD_REGION_PORTALS_OK")
		quit(0)
	else:
		print("WORLD_REGION_PORTALS_FAILED: ",failures.size())
		quit(1)

const COORD = preload("res://scripts/maps/world_coordinates.gd")
