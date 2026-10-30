extends "res://tests/pr122_published_boss_approval_main.gd"
## Only existing gnoll E run/attack and albino monk SW run. QA record clones only.
func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280,720)
	var world = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	if bool(world.hud.get("class_picker_initial")): world.hud.complete_class_selection()
	world.player.camera.make_current(); world.player.camera.force_update_scroll()
	check(world.field_map.get_script().resource_path.ends_with("native_png_field.gd"), "Real bundled native map")
	var before := _world_state(world)
	report["scope"] = "QA candidate injection; not default connection or final visual approval"
	report["candidate_injections"] = 2
	var entries := {}
	for path: String in ["res://data/pr122_monster_animation_staging.json", "res://data/pr122_monster_monk_staging.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for key: String in data.actors:
			if key in ["monster:놀", "monster:알비노 몽크"]: entries[key] = data.actors[key]
	for key: String in entries:
		var selected: Dictionary = entries[key]
		var native: Resource = load(selected.native_profile)
		var record := {}
		for value: Dictionary in world.monster_db:
			if "monster:" + str(value.name) == key: record = value.duplicate(true)
		check(not record.is_empty(), "Real DB identity")
		var overrides := {}
		for property: Dictionary in native.get_property_list():
			if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
			var value: Variant = native.get(property.name)
			if value is Vector2: value = [value.x,value.y]
			elif value is Color: value = [value.r,value.g,value.b,value.a]
			overrides[property.name] = value
		record.animation_profile = overrides
		var actor = load("res://scenes/Monster.tscn").instantiate()
		world.monsters_root.add_child(actor)
		actor.position = world.player.position + Vector2(170,60)
		actor.setup(record,world.player,world,world._monster_texture(record))
		actor.set_physics_process(false)
		check(actor.motion.profile.frames_path == selected.frames, "Only explicit selected candidate")
		var body: Vector2 = actor.position
		var collision: Transform2D = actor.get_node("CollisionShape2D").transform
		for track: Dictionary in selected.tracks:
			var direction: int = ["E","SE","S","SW","W","NW","N","NE"].find(track.direction)
			var aim := Vector2.RIGHT.rotated(direction*PI/4.0)
			actor.motion.cancel_attack();actor.motion.face(aim)
			var strikes: Array = []
			var receive = func(sequence: int) -> void: strikes.append(sequence)
			actor.motion.strike.connect(receive)
			if track.role == "attack": actor.motion.begin_attack(.42,aim,actor.motion.profile.motion_style)
			var seen := {};var captures: Array = []
			for tick: int in range(180):
				actor.motion.advance(1.0/120.0,aim*actor.base_move_speed*1.25 if track.role == "run" else Vector2.ZERO)
				actor.motion.apply(actor.sprite,actor.animation_base_scale)
				check(actor.position == body and actor.get_node("CollisionShape2D").transform == collision, "Body/foot collision retained")
				check(not actor.sprite.flip_h and is_zero_approx(actor.sprite.rotation), "No mirror or rotation")
				if actor.motion._resolved_key == track.animation:
					var pose: Texture2D = actor.sprite.texture
					check((actor.sprite.position+Vector2(0,pose.get_height()/8.0)*actor.sprite.scale).length()<0.001, "Virtual foot anchor retained")
					if not seen.has(pose.get_instance_id()):
						seen[pose.get_instance_id()] = true
						await RenderingServer.frame_post_draw
						var file: String = output.path_join(str(entries.keys().find(key))+"-"+str(track.animation)+"-"+str(seen.size())+".png")
						check(root.get_texture().get_image().save_png(file)==OK,"Main capture")
						captures.append(file)
			check(seen.size()==track.geometry.frames.size(),"Every authored phase")
			if track.role=="attack":check(strikes.size()==1,"One attack marker")
			actor.motion.strike.disconnect(receive)
			report.cases.append({"id":key,"clip":track.animation,"poses_seen":seen.size(),"poses_required":track.geometry.frames.size(),"attack_markers":strikes.size(),"captures":captures,"new_quality_approval":false})
		actor.queue_free();await process_frame
	check(_world_state(world)==before,"Player state preserved")
	world.queue_free();await process_frame
	finish(0 if report.errors.is_empty() else 1)
