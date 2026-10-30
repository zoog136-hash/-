extends "res://tests/pr122_published_boss_approval_main.gd"
## Actual catalog entry path; never substitutes a candidate record or profile.

func finish(code: int) -> void:
	print("PR158_MYTHIC_DEFAULT_EXIT ",code," errors=",report.errors)
	quit(code)

func tick(actor: Node, velocity: Vector2) -> void:
	actor.motion.advance(1.0/120.0,velocity)
	actor.motion.apply(actor.transform_sprite,actor.transform_sprite.get_meta("base_scale",Vector2.ONE))

func invariant(world: Node) -> String:
	return JSON.stringify([world.hp,world.gold,world.inventory,world.equipped_items,world.equipped_catalog,world.player.position,world.player.get_node("CollisionShape2D").transform,world.player.move_speed,world.player.attack_speed_multiplier])

func run() -> void:
	root.size=Vector2i(1280,720)
	var before_mode:=OS.get_environment("PR158_REVIEW_MODE")=="before"
	var keys:=OS.get_environment("PR158_REVIEW_KEYS").split(",",false)
	check(not keys.is_empty(),"Explicit changed actor scope")
	var world=load("res://Main.tscn").instantiate()
	world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world)
	await process_frame
	world.save_timer=-10000.
	if bool(world.hud.get("class_picker_initial")):world.hud.complete_class_selection()
	var strikes:Array[int]=[]
	world.player.attack_strike.connect(func(sequence:int)->void:strikes.append(sequence))
	for key in keys:
		var selected:Dictionary={}
		for r:Dictionary in world.catalog_db.get("변신",[]):
			if str(r.get("sourceId",""))==key:selected=r
		check(not selected.is_empty(),"Actual catalog record "+key)
		world.player.motion.dead=false;world.player.motion.cancel_attack()
		world._apply_transform_visual(selected)
		var actor=world.player
		actor.camera.make_current();actor.camera.force_update_scroll()
		# A disabled QA world must still finish the production renderer's
		# pending source chunks before comparing the same actor on screen.
		if world.field_renderer!=null and world.field_renderer.has_method("settle_visible"):
			check(await world.field_renderer.settle_visible(10000),"Actual visible map chunks ready before capture")
			actor.camera.force_update_scroll()
		var sprite:AnimatedSprite2D=actor.transform_sprite
		var frames:SpriteFrames=sprite.sprite_frames
		var legendary:=frames.resource_path.contains("legendary_production/")
		var retained4:=int(frames.get_meta("twilight_retained_source_directions",0))==4
		var state_before:=invariant(world)
		var record_before:=JSON.stringify(selected)
		if frames.has_meta("twilight_new_S_death_source"):
			var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actors/eight_direction/native_production/mythic-new-r165-source-provenance.json"))
			var old_saved: Dictionary=selected.duplicate(true)
			old_saved.animation_profile=contract.actors[key].prior_default_profile.duplicate(true)
			var old_saved_before:=JSON.stringify(old_saved)
			world._apply_transform_visual(old_saved)
			check(actor.transform_sprite.sprite_frames.resource_path==str(selected.animation_profile.frames_path),"Old saved visual record uses current selected frames "+key)
			check(JSON.stringify(old_saved)==old_saved_before and invariant(world)==state_before,"Old saved record/stats/physical collision state remain unchanged "+key)

		var exercised_poses: Dictionary={}
		var exercised_tracks: Dictionary={}
		print("PR158_DEFAULT_BINDING ",key," ",frames.resource_path)
		if before_mode:
			actor.motion.advance(.5,Vector2.ZERO)
			for n in range(6):tick(actor,Vector2(1,-1).normalized()*actor.move_speed)
		else:
			var expected_default: String = str(selected.get("animation_profile", {}).get("frames_path", ""))
			check(not expected_default.is_empty() and frames.resource_path == expected_default,"Exact authored catalog default path "+key)
			for d in range(8):
				var aim:=Vector2.RIGHT.rotated(d*PI/4.)
				for role: String in ["idle","run","attack","hit"]:
					actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
					actor.motion.advance(2.,Vector2.ZERO);actor.motion.face(aim*actor.move_speed if role=="run" else aim)
					var suffix: String=["down","up","left","right"][actor.motion.facing4] if retained4 else str(d)
					var name:=role+"_"+suffix
					check(frames.has_animation(name),"Dedicated actual track "+key+" "+name)
					var expected:=frames.get_frame_count(name)
					if role=="run":check(expected==6,"Six genuine RUN poses")
					var velocity: Vector2=aim*actor.move_speed if role=="run" else Vector2.ZERO
					var strike_start:=strikes.size()
					var sequence: int=-1
					if role=="attack":
						sequence=actor.start_combat_attack(actor.global_position+aim,.9,"magic" if key=="136" and retained4 else ("bow" if key in ["331","177","275"] and retained4 else actor.motion.profile.motion_style))
						if retained4:
							actor.motion._resolve_frames(frames)
							name=str(actor.motion._resolved_key)
							var actual_suffix: String=["down","up","left","right"][actor.motion.facing4]
							check(name in ["attack_"+actual_suffix,"cast_"+actual_suffix,"ranged_attack_"+actual_suffix],"Existing retained attack/cast source direction")
					if role=="hit":actor.motion.react(false,Vector2.ZERO)
					var seen:Dictionary={};var marker_seen:=false
					for n in range(300):
						tick(actor,velocity)
						if str(sprite.animation)==name:
							seen[sprite.frame]=true
							exercised_tracks[name]=true
							exercised_poses[name+":"+str(sprite.frame)]=true
						if role=="run" and str(sprite.animation)==name and frames.has_meta("twilight_reviewed_frame_registration"):
							var registered: Dictionary=frames.get_meta("twilight_reviewed_frame_registration")[name]
							check(registered.semantic_review=="PASS","Reviewed RUN registration")
							var anchor: Vector2=registered.frames[sprite.frame].anchor
							var texture: Texture2D=frames.get_frame_texture(name,sprite.frame)
							var root_on_screen:=sprite.to_global(anchor-texture.get_size()*.5+sprite.offset)
							check(root_on_screen.distance_to(actor.global_position)<.001,"Registered foot plane remains on actor root")
						check(not sprite.flip_h,"No mirrored substitution")
						if role=="attack" and strikes.size()>strike_start and not marker_seen:
							check(strikes.size()==strike_start+1 and strikes.back()==sequence,"Single authoritative attack strike")
							check(str(sprite.animation)==name and sprite.frame==actor.motion.profile.hit_frame_for("attack"),"Actual attack marker frame")
							marker_seen=true
					check(seen.size()==expected,"Every phase plays "+key+" "+name)
					check(marker_seen if role=="attack" else strikes.size()==strike_start,"Marker ownership "+name)
					check(invariant(world)==state_before,"Gameplay/collision state preserved")
				actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
				actor.motion.face(aim);actor.motion.die()
				var death_name: String="death_"+["down","up","left","right"][actor.motion.facing4] if retained4 else ("death_"+str(d) if frames.has_animation("death_"+str(d)) else "death_2")
				var death_seen:Dictionary={}
				for n in range(180):
					tick(actor,Vector2.ZERO)
					check(str(sprite.animation)==death_name,"Preserved same-form death direction policy")
					death_seen[sprite.frame]=true
					exercised_tracks[death_name]=true
					exercised_poses[death_name+":"+str(sprite.frame)]=true
				check(death_seen.size()==frames.get_frame_count(death_name),"Every death phase")
				check(sprite.frame==frames.get_frame_count(death_name)-1 and actor.motion.state=="corpse","Terminal death hold")
			actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
			actor.motion.advance(.5,Vector2.ZERO)
			for n in range(6):tick(actor,Vector2(1,-1).normalized()*actor.move_speed)
			check(JSON.stringify(selected)==record_before,"Catalog record unchanged by playback")
		await RenderingServer.frame_post_draw
		var screen:Vector2=actor.get_global_transform_with_canvas()*Vector2.ZERO
		var crop:=root.get_texture().get_image().get_region(Rect2i(Vector2i(screen)+Vector2i(-150,-220),Vector2i(300,300)))
		check(crop.save_png(output.path_join(key+".png"))==OK,"Actual game comparison capture")
		if not before_mode and report.errors.is_empty():
			var count:=frames.get_animation_names().size()
			if legendary and not retained4:
				check(exercised_tracks.size()==33 and exercised_poses.size()==198,"All legendary required tracks and poses actually played")
				if report.errors.is_empty():
					print("PR158_LEGENDARY_DEFAULT_PASS id=",key," tracks=33 poses=198 candidate_injection=0")
			elif retained4:
				check(exercised_tracks.size()==20 and exercised_poses.size()==120,"All policy-required retained cardinal directions and poses actually played; existing WALK extras preserved")
				check(count==int(frames.get_meta("twilight_retained_track_count")) and count in [24,28],"All original retained source tracks preserved, including optional CAST or ranged attacks")
				check(int(frames.get_meta("twilight_new_authored_directions"))==0,"Retained four-view routing creates no new eight-direction artwork")
				if report.errors.is_empty():
					print("PR158_RETAINED_DEFAULT_PASS id=",key," source_directions=4 policy_tracks=20 policy_poses=120 retained_tracks=",count," candidate_injection=0")
			elif frames.has_meta("twilight_new_S_death_source"):
				check(exercised_tracks.size()==33 and exercised_poses.size()==198,"All33 runtime tracks/198timeline references, including declared guards")
				var guards: Dictionary=frames.get_meta("twilight_declared_static_guard_aliases",{})
				var registration: Dictionary=frames.get_meta("twilight_reviewed_frame_registration",{})
				check(guards.is_empty() or guards.size()==8,"All eight exact-view static guard aliases are explicitly declared")
				check(int(frames.get_meta("twilight_authored_track_count"))==(25 if not guards.is_empty() else 33),"Authored tracks exclude reused static IDLE guards")
				check(int(frames.get_meta("twilight_authored_pose_count"))==(150 if not guards.is_empty() else 198),"Authored source slots exclude repeated guard timeline refs")
				for alias: String in guards:
					var original: String=str(guards[alias].source_clip)
					check(original==alias.replace("idle_","attack_") and int(guards[alias].source_phase)==0 and int(guards[alias].timeline_references)==6 and int(guards[alias].distinct_source_poses)==1 and int(guards[alias].new_authored_poses)==0,"Exact same-view existing ready0 only; not six new idle poses")
					for phase in range(6):
						check(frames.get_frame_texture(alias,phase)==frames.get_frame_texture(original,0),"Static IDLE reuses exact same-view source guard")
						check(registration[alias].frames[phase]==registration[original].frames[0],"Static guard source C/scale/target remain exact")
				var south: Dictionary=frames.get_meta("twilight_new_S_death_source")
				check(int(south.selected_picture_row)==2 and int(south.production_death_directions)==1 and int(south.selected_pose_slots)==6,"Only actual South death row selected; no eight-death completion claim")
			elif frames.has_meta("twilight_retained_death_source"):
				check(exercised_tracks.size()==33 and exercised_poses.size()==198,"Eight-view living tracks plus declared existing same-form S death all play")
				check(int(frames.get_meta("twilight_authored_track_count"))==32 and int(frames.get_meta("twilight_authored_pose_count"))==192,"Authored counts exclude existing retained death references")
				var retained_death: Dictionary=frames.get_meta("twilight_retained_death_source")
				check(retained_death.same_actor=="transform:"+key and retained_death.source_track=="death_down" and int(retained_death.new_authored_poses)==0,"Same actor retained South death only; no new death art claim")
				for phase in range(6):
					check(frames.get_frame_texture("death_2",phase).atlas.resource_path==str(retained_death.source),"Existing own death atlas preserved")
			elif frames.has_meta("twilight_declared_presentation_aliases"):
				check(exercised_tracks.size()==33 and exercised_poses.size()==198,"Every declared reaction-fallback presentation reference played")
				check(int(frames.get_meta("twilight_authored_track_count"))==32 and int(frames.get_meta("twilight_authored_pose_count"))==192,"Authored count excludes six reaction alias references")
				var aliases: Dictionary=frames.get_meta("twilight_declared_presentation_aliases")
				for alias: String in aliases:
					var original: String=str(aliases[alias].source)
					check(alias.begins_with("hit_") and original==alias.replace("hit_","idle_") and int(aliases[alias].new_authored_poses)==0,"Explicit same-facing idle reaction fallback only")
					for phase in range(6):
						check(frames.get_frame_texture(alias,phase)==frames.get_frame_texture(original,phase),"Reaction alias reuses exact existing idle texture")
				if report.errors.is_empty():
					print("PR158_MYTHIC_REACTION_FALLBACK_PASS id=",key," authored_tracks=32 authored_poses=192 alias_refs=6 candidate_injection=0")
			elif frames.resource_path.contains("native_production/mythic_"):
				check(exercised_tracks.size()==33 and exercised_poses.size()==198,"All required native mythic tracks and poses actually played")
				if report.errors.is_empty():
					print("PR158_MYTHIC_DEFAULT_PASS id=",key," tracks=33 poses=198 candidate_injection=0")
			elif key=="413":
				print("PR158_DEFAULT_RUNTIME_COVERAGE key=transform:",key," exercised_tracks=",exercised_tracks.size()," exercised_poses=",exercised_poses.size()," authored_tracks=",count," authored_poses=",count*6," WALK excluded by existing transform scope")
				check(exercised_tracks.size()==38 and exercised_poses.size()==228,"Every policy-required track and pose actually played")
				if report.errors.is_empty():
					print("PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:",key," tracks=",exercised_tracks.size()," poses=",exercised_poses.size()," candidate_injection=0")
			else:
				print("PR158_REAPER_DEFAULT_PASS id=",key," run_tracks=8 run_poses=48 candidate_injection=0")
	world.queue_free();await process_frame
	finish(0 if report.errors.is_empty() else 1)
