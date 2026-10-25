extends "res://tests/pr122_published_boss_approval_main.gd"
## All unpublished boss candidates in one batch; published Main results are preserved.
func run() -> void:
	Engine.max_fps = 120
	root.size = Vector2i(1280,720)
	var world = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	if bool(world.hud.get("class_picker_initial")): world.hud.complete_class_selection()
	world.player.camera.make_current(); world.player.camera.force_update_scroll()
	check(world.field_map.get_script().resource_path.ends_with("native_png_field.gd"), "Actual bundled PNG map")
	var before := _world_state(world)
	var original_player = world.player
	var original_visible: bool = original_player.visible
	original_player.hide()
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_boss_repair_staging.json"))
	report["scope"] = "All 13 unpublished boss candidates; fresh actual Monster scene in NativePngField Main per action. QA visual profile injection, no default catalog switch; six published bosses are not replayed."
	report["new_quality_approvals"] = 0
	report["blocked"] = []
	report["actors"] = []
	var completed: int = 0
	var expected: int = 0
	for key: String in register.actors:
		var entry: Dictionary = register.actors[key]
		if entry.get("kind", "") != "boss" or entry.get("production_connected", false): continue
		if not entry.has("native_profile"):
			report.blocked.append({"id":key,"reason":"No authored locomotion sizing reference; no profile invented"});continue
		var tracks: Array = []
		for track: Dictionary in entry.tracks:
			if track.role in ["idle","run","attack","hit"] or track.role=="death" and track.direction=="S": tracks.append(track)
		expected += tracks.size()
		var sheet := Image.create(1080,maxi(1,tracks.size())*150,false,Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08,0.08,0.08,1))
		var profile: Resource = load(entry.native_profile)
		var actor_report := {"id":key,"clips":[],"sheet_rows_follow_clip_order":true,"frames":entry.frames}
		for track: Dictionary in tracks:
			var record: Dictionary = {}
			for value: Dictionary in world.monster_db:
				if "monster:"+str(value.get("name",""))==key: record=value.duplicate(true)
			check(not record.is_empty(),"Real monster DB record: "+key)
			var actor = load("res://scenes/Monster.tscn").instantiate()
			world.monsters_root.add_child(actor)
			actor.position = original_player.position+Vector2(170,60)
			actor.setup(record,original_player,world,world._monster_texture(record))
			actor.set_physics_process(false)
			var body: Vector2 = actor.position
			var collision: Transform2D = actor.get_node("CollisionShape2D").transform
			var prior_hp: int = actor.max_hp
			var prior_interval: float = actor.attack_interval
			actor.motion.profile=profile
			actor.motion.frame_source=load(entry.frames)
			actor.sprite.material=null
			actor.animation_base_scale=Vector2.ONE*profile.pixel_scale
			actor.animation_base_scale.x*=profile.native_width_ratio
			check(actor.motion.profile == profile and actor.motion.frame_source.resource_path==entry.frames,"Exact selected profile and SpriteFrames")
			var sprite: Sprite2D = actor.sprite
			var frames: SpriteFrames = actor.motion.frame_source
			var motion = actor.motion
			var direction: int = ["E","SE","S","SW","W","NW","N","NE"].find(track.direction)
			var aim := Vector2.RIGHT.rotated(direction*PI/4.0)
			motion.face(aim);motion.advance(.25,Vector2.ZERO)
			var strikes: Array = []
			motion.strike.connect(func(sequence: int) -> void:strikes.append(sequence))
			var duration: float = 1.5
			var sequence: int = -1
			match str(track.role):
				"attack": duration=.9;sequence=motion.begin_attack(duration,aim,profile.motion_style)
				"hit":motion.react(false,Vector2.ZERO)
				"death":motion.die();duration=profile.death_duration
			var seen := {};var released: bool = false
			for tick: int in range(int(ceil((duration+.5)*120.0))):
				motion.advance(1.0/120.0,aim*profile.reference_speed*1.25 if track.role=="run" else Vector2.ZERO)
				motion.apply(sprite,actor.animation_base_scale)
				if motion._resolved_key==track.animation:
					check(not sprite.flip_h and is_zero_approx(sprite.rotation),"No mirror or warp")
					var pose_index: int = -1
					for candidate_index in range(frames.get_frame_count(track.animation)):
						if frames.get_frame_texture(track.animation,candidate_index)==sprite.texture: pose_index=candidate_index
					check(pose_index>=0,"Actual Sprite2D owns a selected authored pose")
					var canvas: Vector2 = sprite.texture.get_size()
					check((sprite.position+Vector2(0,canvas.y/8.0)*sprite.scale).is_equal_approx(Vector2.ZERO),"Saved virtual foot anchor: "+key+" "+track.animation)
					if not seen.has(pose_index):
						seen[pose_index]=true
						await RenderingServer.frame_post_draw
						var screen: Vector2 = actor.get_global_transform_with_canvas()*Vector2.ZERO
						var rect := Rect2i(Vector2i(screen)+Vector2i(-180,-240),Vector2i(360,300))
						var crop: Image = root.get_texture().get_image().get_region(rect)
						crop.resize(180,150,Image.INTERPOLATE_LANCZOS)
						sheet.blit_rect(crop,Rect2i(0,0,180,150),Vector2i(pose_index*180,tracks.find(track)*150))
				if track.role=="attack" and not strikes.is_empty() and not released:
					check(strikes==[sequence] and motion._resolved_key==track.animation and sprite.texture==frames.get_frame_texture(track.animation,profile.hit_frame_for("attack")),"Authoritative marker shows existing profile frame once")
					check(absf(motion.attack_elapsed-duration*motion.attack_hit_ratio)<=1.0/120.0+.0001,"Attack release clock")
					released=true
			check(seen.size()==6,"All six authored phases: "+key+" "+track.animation)
			if track.role=="attack":check(released and strikes==[sequence],"Single attack marker")
			else:check(strikes.is_empty(),"No phantom marker")
			if track.role=="death":check(motion.state=="corpse" and sprite.texture==frames.get_frame_texture(track.animation,5),"Death final pose")
			check(actor.position==body and actor.get_node("CollisionShape2D").transform==collision and actor.max_hp==prior_hp and actor.attack_interval==prior_interval,"Body/collision/HP/attack interval preserved")
			actor_report.clips.append({"clip":track.animation,"phases":seen.keys(),"markers":strikes.size(),"authored_frame_count":frames.get_frame_count(track.animation),"required_quality_pose_count":6,"quality_pose_gate_pass":seen.size()==6,"final_quality_approval":false})
			world.player=original_player
			actor.queue_free();await process_frame
			completed+=1
		var path: String = output.path_join(key.replace(":","_")+"-Main-phases.png")
		check(sheet.save_png(path)==OK,"Save whole actor phase evidence")
		actor_report["phase_sheet"]=path
		report.actors.append(actor_report)
		print("BOSS_UNPUBLISHED_BATCH_PROGRESS clips=%d actor=%s approvals_added=0" % [completed,key])
	original_player.visible=original_visible
	check(_world_state(world)==before,"Main state preserved")
	report["candidate_injections"]=completed
	report["completed_clips"]=completed;report["expected_clips"]=expected
	check(completed==expected and expected==392,"Whole unpublished boss candidate denominator")
	world.queue_free();await process_frame
	finish(0 if report.errors.is_empty() else 1)
