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
		var sprite:AnimatedSprite2D=actor.transform_sprite
		var frames:SpriteFrames=sprite.sprite_frames
		var state_before:=invariant(world)
		var record_before:=JSON.stringify(selected)
		print("PR158_DEFAULT_BINDING ",key," ",frames.resource_path)
		if before_mode:
			actor.motion.advance(.5,Vector2.ZERO)
			for n in range(6):tick(actor,Vector2(1,-1).normalized()*300.)
		else:
			check(frames.resource_path.contains("native_production/") if key=="413" else frames.resource_path.contains("reaper_"),"Expected authored default path "+key)
			for d in range(8):
				var aim:=Vector2.RIGHT.rotated(d*PI/4.)
				for role: String in ["idle","run","attack","hit"]:
					actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
					actor.motion.advance(2.,Vector2.ZERO);actor.motion.face(aim)
					var name:=role+"_"+str(d)
					check(frames.has_animation(name),"Dedicated actual track "+key+" "+name)
					var expected:=frames.get_frame_count(name)
					if role=="run":check(expected==6,"Six genuine RUN poses")
					var velocity: Vector2=aim*actor.motion.profile.reference_speed*1.25 if role=="run" else Vector2.ZERO
					var strike_start:=strikes.size()
					var sequence: int=-1
					if role=="attack":sequence=actor.start_combat_attack(actor.global_position+aim,.9,actor.motion.profile.motion_style)
					if role=="hit":actor.motion.react(false,Vector2.ZERO)
					var seen:Dictionary={};var marker_seen:=false
					for n in range(300):
						tick(actor,velocity)
						if str(sprite.animation)==name:seen[sprite.frame]=true
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
				var death_name:="death_"+str(d) if frames.has_animation("death_"+str(d)) else "death_2"
				var death_seen:Dictionary={}
				for n in range(180):
					tick(actor,Vector2.ZERO)
					check(str(sprite.animation)==death_name,"Preserved same-form death direction policy")
					death_seen[sprite.frame]=true
				check(death_seen.size()==frames.get_frame_count(death_name),"Every death phase")
				check(sprite.frame==frames.get_frame_count(death_name)-1 and actor.motion.state=="corpse","Terminal death hold")
			actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
			actor.motion.advance(.5,Vector2.ZERO)
			for n in range(6):tick(actor,Vector2(1,-1).normalized()*300.)
			check(JSON.stringify(selected)==record_before,"Catalog record unchanged by playback")
		await RenderingServer.frame_post_draw
		var screen:Vector2=actor.get_global_transform_with_canvas()*Vector2.ZERO
		var crop:=root.get_texture().get_image().get_region(Rect2i(Vector2i(screen)+Vector2i(-150,-220),Vector2i(300,300)))
		check(crop.save_png(output.path_join(key+".png"))==OK,"Actual game comparison capture")
		if not before_mode and report.errors.is_empty():
			var count:=frames.get_animation_names().size()
			if key=="413":
				print("PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:",key," tracks=",count," poses=",count*6," candidate_injection=0")
			else:
				print("PR158_REAPER_DEFAULT_PASS id=",key," run_tracks=8 run_poses=48 candidate_injection=0")
	world.queue_free();await process_frame
	finish(0 if report.errors.is_empty() else 1)
