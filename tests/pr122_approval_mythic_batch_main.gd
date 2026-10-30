extends "res://tests/pr122_published_boss_approval_main.gd"
## All currently bound mythic selections in one batch; no unique or default switches.
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
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	report["scope"] = "Whole bound mythic batch; fresh actual Player scene in Main for each irreversible action; QA injection, no default catalog switch"
	report["new_quality_approvals"] = 0
	report["blocked"] = []
	report["actors"] = []
	var completed: int = 0
	var expected: int = 0
	var selected_repairs: Array = []
	var selection_path: String = OS.get_environment("PR122_APPROVAL_PLAN")
	if not selection_path.is_empty():
		var selection: Variant = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
		if not selection is Dictionary or not selection.get("repairs", []) is Array or selection.get("repairs", []).is_empty():
			check(false,"Repair selection must contain explicit nonempty repairs")
			finish(1);return
		selected_repairs = selection.repairs
		report["scope"] = "Explicit repaired mythic batch in actual Main/Player; original all-300 default unchanged"
		report["repair_plan"] = selection_path
	for key: String in register.actors:
		var entry: Dictionary = register.actors[key]
		if entry.get("grade", "") != "신화": continue
		if not entry.has("native_profile"):
			report.blocked.append({"id":key,"reason":"No authored locomotion sizing reference; no profile invented"});continue
		var tracks: Array = []
		for track: Dictionary in entry.tracks:
			if track.role in ["idle","run","attack","hit"] or track.role=="death" and track.direction=="S":
				var selected: bool = selected_repairs.is_empty()
				for repair: Dictionary in selected_repairs:
					if repair.id==key and repair.clip==track.animation:
						check(repair.source_sha256==track.source_sha256,"Exact repair source pin")
						selected=true
				if selected: tracks.append(track)
		if tracks.is_empty(): continue
		expected += tracks.size()
		var sheet := Image.create(1080,maxi(1,tracks.size())*150,false,Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08,0.08,0.08,1))
		var profile: Resource = load(entry.native_profile)
		var actor_report := {"id":key,"clips":[],"sheet_rows_follow_clip_order":true,"frames":entry.frames}
		for track: Dictionary in tracks:
			var actor = load("res://scenes/Player.tscn").instantiate()
			actor.get_node("Camera2D").enabled = false
			world.add_child(actor)
			await process_frame
			actor.set_physics_process(false)
			actor.position = original_player.position
			world.player = actor
			preload("res://scripts/maps/source_body_profile.gd").apply(actor,true)
			var body: Vector2 = actor.position
			var collision: Transform2D = actor.get_node("CollisionShape2D").transform
			var class_frames: SpriteFrames = actor.class_sprite.sprite_frames
			actor.set_transform_visual("",1.0,profile)
			check(actor.motion.profile == profile and actor.transform_sprite.sprite_frames.resource_path==entry.frames,"Exact selected profile and SpriteFrames")
			var sprite: AnimatedSprite2D = actor.transform_sprite
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
				motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
				if str(sprite.animation)==track.animation:
					check(not sprite.flip_h and is_zero_approx(sprite.rotation),"No mirror or warp")
					var canvas: Vector2 = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame).get_size()
					check((sprite.position+Vector2(0,canvas.y/8.0)*sprite.scale).is_equal_approx(Vector2.ZERO),"Saved virtual foot anchor")
					if not seen.has(sprite.frame):
						seen[sprite.frame]=true
						await RenderingServer.frame_post_draw
						var screen: Vector2 = actor.get_global_transform_with_canvas()*Vector2.ZERO
						var rect := Rect2i(Vector2i(screen)+Vector2i(-180,-240),Vector2i(360,300))
						var crop: Image = root.get_texture().get_image().get_region(rect)
						crop.resize(180,150,Image.INTERPOLATE_LANCZOS)
						sheet.blit_rect(crop,Rect2i(0,0,180,150),Vector2i(sprite.frame*180,tracks.find(track)*150))
				if track.role=="attack" and not strikes.is_empty() and not released:
					check(strikes==[sequence] and str(sprite.animation)==track.animation and sprite.frame==3,"Authoritative marker shows frame 3 once")
					check(absf(motion.attack_elapsed-duration*motion.attack_hit_ratio)<=1.0/120.0+.0001,"Attack release clock")
					released=true
			check(seen.size()==6,"All six authored phases")
			if track.role=="attack":check(released and strikes==[sequence],"Single attack marker")
			else:check(strikes.is_empty(),"No phantom marker")
			if track.role=="death":check(motion.state=="corpse" and sprite.frame==5,"Death final pose")
			check(actor.position==body and actor.get_node("CollisionShape2D").transform==collision and actor.class_sprite.sprite_frames==class_frames,"Body/collision/class resources preserved")
			actor_report.clips.append({"clip":track.animation,"phases":seen.keys(),"markers":strikes.size(),"final_quality_approval":false})
			world.player=original_player
			actor.queue_free();await process_frame
			completed+=1
		var path: String = output.path_join(key.replace(":","_")+"-Main-phases.png")
		check(sheet.save_png(path)==OK,"Save whole actor phase evidence")
		actor_report["phase_sheet"]=path
		report.actors.append(actor_report)
		print("MYTHIC_BATCH_PROGRESS clips=%d actor=%s approvals_added=0" % [completed,key])
	original_player.visible=original_visible
	check(_world_state(world)==before,"Main state preserved")
	report["completed_clips"]=completed;report["expected_clips"]=expected
	report["candidate_injections"]=completed
	check(completed==expected and expected==(300 if selected_repairs.is_empty() else selected_repairs.size()),"Exact whole or repaired mythic batch denominator")
	world.queue_free();await process_frame
	finish(0 if report.errors.is_empty() else 1)
