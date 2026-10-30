extends "res://tests/pr122_published_boss_approval_main.gd"

func finish(code: int) -> void:
	print("PR158_GIRTAS_DEFAULT_EXIT ", code, " errors=", report.errors)
	quit(code)

func run() -> void:
	root.size = Vector2i(1280,720)
	var world = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	if bool(world.hud.get("class_picker_initial")): world.hud.complete_class_selection()
	var selected: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("변신", []):
		if str(record.get("sourceId", "")) == "267": selected = record
	check(not selected.is_empty(), "Default Girtas catalog record exists")
	world._apply_transform_visual(selected)
	var actor = world.player
	actor.camera.make_current(); actor.camera.force_update_scroll()
	var sprite: AnimatedSprite2D = actor.transform_sprite
	check(sprite.sprite_frames.resource_path.contains("native_production/girtas_267/"), "Actual default production binding")
	var body: Vector2 = actor.position
	var collision: Transform2D = actor.get_node("CollisionShape2D").transform
	print("PR158_GIRTAS_DEFAULT_FRAMES ",sprite.sprite_frames.resource_path)
	for direction in range(8):
		var aim := Vector2.RIGHT.rotated(direction*PI/4.0)
		actor.motion.advance(.5,Vector2.ZERO)
		var seen := {}
		for tick in range(150):
			actor.motion.advance(1.0/120.0, aim*300)
			actor.motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
			if str(sprite.animation)=="run_"+str(direction):
				if not seen.has(sprite.frame):
					seen[sprite.frame]=true
					check(not sprite.flip_h, "No mirrored directional substitute")
					if direction==7 and sprite.frame in [0,5]:
						await RenderingServer.frame_post_draw
						var screen: Vector2 = actor.get_global_transform_with_canvas()*Vector2.ZERO
						var crop := root.get_texture().get_image().get_region(Rect2i(Vector2i(screen)+Vector2i(-200,-250),Vector2i(400,350)))
						check(crop.save_png(output.path_join("NE-run-"+str(sprite.frame)+".png"))==OK,"Capture actual default Player")
		check(seen.size()==6,"All six default RUN phases for direction "+str(direction))
		print("PR158_GIRTAS_RUN ",direction," phases=",seen.keys())
	check(actor.position==body and actor.get_node("CollisionShape2D").transform==collision,"Movement body/collision unchanged by visual probe")
	world.queue_free();await process_frame
	finish(0 if report.errors.is_empty() else 1)
