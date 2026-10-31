extends "res://tests/transform_unique_precision_main.gd"
## Local forced-unavailable/invalid native-class fixtures. Not an Android-device test.
var releases:Array=[]
var local_comparison:Image

func reset_motion() -> void:
	actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
	actor.motion.advance(.5,Vector2.ZERO)
	actor.motion.face(Vector2.DOWN)

func stable_gameplay() -> String:
	return JSON.stringify([world_ref.hp,world_ref.mp,world_ref.gold,world_ref.inventory,world_ref.equipped_items,world_ref.equipped_catalog,world_ref.item_instances,world_ref.class_index,actor.move_speed,actor.base_move_speed,actor.attack_speed_multiplier,actor.equipment_move_speed_multiplier,actor.skill_speed_multiplier,actor.collision_layer,actor.collision_mask,actor.get_node("CollisionShape2D").transform])

func combat_settings(profile:TwilightAnimationProfile) -> String:
	return JSON.stringify([profile.profile_id,profile.motion_style,profile.movement_fps,profile.reference_speed,profile.attack_hit_ratio,profile.attack_hit_frame,profile.action_hit_frames,profile.use_profile_hit_ratio,profile.attack_animation_speed,profile.projectile_origin,profile.hit_position])

func check_aims(expected:TwilightAnimationProfile) -> void:
	for direction in range(8):
		var aim=Vector2.RIGHT.rotated(direction*PI/4.)
		actor.motion.face(aim)
		check(actor.combat_projectile_origin().is_equal_approx(actor.global_position+expected.projectile_offset(aim)),"Original current projectile origin / eight-aim combat layout preserved")

func check_strike(expected:TwilightAnimationProfile) -> Dictionary:
	reset_motion()
	var before=releases.size()
	var sequence=actor.start_combat_attack(actor.global_position+Vector2.DOWN*128.,.9,expected.motion_style)
	var marker=false
	for tick in range(125):
		actor.motion.advance(1./120.,Vector2.ZERO)
		actor.motion.apply(actor.class_sprite,actor.class_sprite.get_meta("base_scale",Vector2.ONE))
		if releases.size()>before and not marker:
			check(releases.size()==before+1 and releases.back()[0]==sequence,"One authoritative class attack release")
			check(actor.class_sprite.frame==expected.hit_frame_for("attack"),"Original class authored impact marker preserved")
			check(absf(float(releases.back()[1])-.9*expected.attack_hit_ratio)<=1./120.+.00001,"Original combat release time / cooldown interval preserved")
			marker=true
	check(marker and not actor.motion.active,"Class attack completes at unchanged gameplay duration")
	return {"release_time":releases.back()[1],"duration":actor.motion.attack_duration,"ratio":actor.motion.attack_hit_ratio}

func fixture_resource(index:int,kind:String) -> String:
	var path="user://class-"+str(index)+"-"+kind+".tres"
	if kind=="missing":return path
	var frames=SpriteFrames.new();frames.remove_animation("default")
	if kind=="invalid_atlas":
		frames.add_animation("idle_2")
		var valid=AtlasTexture.new()
		valid.atlas=load(actor.CLASS_SHEETS[index]);valid.region=Rect2(0,0,148,116)
		frames.add_frame("idle_2",valid)
		frames.add_frame("idle_2",AtlasTexture.new())
	check(ResourceSaver.save(frames,path)==OK,"Isolated optional-class fixture resource saved")
	return path

func capture_local(column:int) -> void:
	actor.motion.face(Vector2.DOWN)
	actor.motion.gait=0.
	actor.motion.advance(0.,Vector2.ZERO)
	actor.motion.apply(actor.class_sprite,actor.class_sprite.get_meta("base_scale",Vector2.ONE))
	actor.camera.force_update_scroll()
	if not await map_ready():return
	await process_frame;await RenderingServer.frame_post_draw
	var point=actor.get_global_transform_with_canvas()*Vector2.ZERO
	var crop=root.get_texture().get_image().get_region(Rect2i(Vector2i(point)+Vector2i(-130,-190),Vector2i(260,230)))
	local_comparison.blit_rect(crop,Rect2i(0,0,260,230),Vector2i(column*260,0))

func run() -> void:
	root.size=Vector2i(1280,720)
	var world=load("res://Main.tscn").instantiate();world_ref=world;root.add_child(world)
	await process_frame
	world.set_process(false);world.set_physics_process(false)
	for node in world.find_children("*","",true,false):node.set_process(false);node.set_physics_process(false)
	if bool(world.hud.get("class_picker_initial")):world.hud.complete_class_selection()
	world.set_process(false);world.set_physics_process(false);world.save_timer=-10000.
	actor=world.player;actor.set_process(false);actor.set_physics_process(false);actor.camera.make_current()
	if not await map_ready():finish(1);return
	await physics_frame
	check(PhysicsServer2D.body_get_space(actor.get_rid()).is_valid(),"Real Main body/collider remains in map space")
	var saved_transform_profile=actor.transform_profile
	var saved_transform_active=actor.transform_active
	var saved_class=actor.class_index
	actor.clear_transform_visual()
	var invariant_before=stable_gameplay()
	actor.attack_strike.connect(func(sequence:int)->void:releases.append([sequence,actor.motion.attack_elapsed]))
	local_comparison=Image.create(520,230,false,Image.FORMAT_RGBA8)
	local_comparison.fill(Color(.1,.11,.13,1.))
	for index in range(4):
		actor.set_class_index(index)
		var native=actor.class_profile
		var native_settings=combat_settings(native)
		var native_frames=actor.class_sprite.sprite_frames
		check(not native.frames_path.is_empty() and native_frames.resource_path==native.frames_path and actor._class_fallback_combat_profile==null,"Normal native class selected without altered profile/cache "+str(index))
		check(native_frames==world.ANIMATION_CATALOG.frames(native.frames_path,native.layout),"Normal native SpriteFrames cache identity retained")
		actor.motion.profile=native
		check_aims(native)
		var normal_attack=check_strike(native)
		for kind:String in ["missing","empty","invalid_atlas"]:
			reset_motion()
			var unavailable=native.duplicate(true)
			unavailable.frames_path=fixture_resource(index,kind)
			actor.class_profile=unavailable;actor.motion.profile=unavailable
			if index==0 and kind=="missing":
				# Replay the old loader result explicitly; never include a device photo.
				actor.class_sprite.sprite_frames=world.ANIMATION_CATALOG.frames_for_profile(unavailable,actor.CLASS_SHEETS[index])
				actor.class_sprite.set_meta("base_scale",Vector2.ONE*unavailable.pixel_scale)
				await capture_local(0)
			actor._build_class_frames(actor.CLASS_SHEETS[index])
			check(actor.class_index==index and actor.class_profile.profile_id==native.profile_id,"Class visual and saved identity unchanged")
			check(actor.class_profile.layout=="class5" and actor.class_profile.frames_path.is_empty() and actor.class_profile.animation_names.is_empty(),"Effective legacy class profile matches actual five-by-five pixels")
			check(combat_settings(actor.class_profile)==native_settings,"All class gameplay clocks/speed/marker/origin values unchanged")
			var fallback=actor.class_sprite.sprite_frames
			check(fallback.get_animation_names().size()==5,"Exactly five existing legacy class rows")
			var raw=Image.load_from_file(actor.CLASS_SHEETS[index])
			for row in range(5):
				var clip=["walk_down","walk_up","walk_left","walk_right","attack"][row]
				check(fallback.get_frame_count(clip)==5,"Five genuine legacy class columns")
				for phase in range(5):
					var texture:AtlasTexture=fallback.get_frame_texture(clip,phase)
					check(texture.region==Rect2(phase*148,row*116,148,116) and texture.get_image().get_data()==raw.get_region(Rect2i(phase*148,row*116,148,116)).get_data(),"Exact original full class cell, no clipped neighbour or image edits")
			if index==0 and kind=="missing":await capture_local(1)
			check_aims(native)
			var attack=check_strike(native)
			check(attack==normal_attack,"Fallback changes no authoritative attack/cooldown trace")
			var changed=native.duplicate(true);changed.projectile_origin=Vector2(31,-57)
			actor.class_profile.projectile_origin=changed.projectile_origin
			check_aims(changed)
			actor.class_profile.projectile_origin=native.projectile_origin
			# A live transform must use its own current profile, never class backup.
			var transformed=native.duplicate(true);transformed.projectile_origin=Vector2(8,-23)
			actor.set_transform_visual(actor.CLASS_SHEETS[index],1.,transformed)
			check_aims(transformed)
			actor.clear_transform_visual()
			check_aims(native)
			check(stable_gameplay()==invariant_before,"HP/movement/equipment physical IDs/inventory/save records/collision unchanged")
			report.cases.append({"class_index":index,"fixture":kind,"native_source":native.frames_path,"effective_layout":actor.class_profile.layout,"fallback_sheet":actor.CLASS_SHEETS[index],"legacy_columns":5,"legacy_rows":5,"authoritative_attack_trace":attack})
		actor.set_class_index((index+1)%4)
		check(actor._class_fallback_combat_profile==null and not actor.class_profile.frames_path.is_empty(),"Class change clears old fallback combat origin")
		actor.set_class_index(index)
		check(actor._class_fallback_combat_profile==null and actor.class_sprite.sprite_frames==native_frames,"Available native class recovers exact cached resource")
		check(combat_settings(actor.class_profile)==native_settings,"Normal native profile remains unmodified after recovery")
	local_comparison.save_png(output.path_join("local-forced-class-fallback-before-after.png"))
	actor.set_class_index(saved_class)
	if saved_transform_active:actor.set_transform_visual(saved_transform_profile.resource_path_hint,1.,saved_transform_profile)
	check(stable_gameplay()==invariant_before,"Final original gameplay/save/equipment state preserved")
	report["purpose"]="Local forced optional-class unavailable/invalid fixture, not Android-device reproduction or APK export proof"
	report["known_legacy_sheet_grid"]=[5,5]
	report["existing_native_profiles_unmodified"]=true
	world.queue_free();await process_frame;await process_frame
	finish(0 if report.errors.is_empty() else 1)
