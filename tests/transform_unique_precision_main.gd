extends "res://tests/pr122_published_boss_approval_main.gd"
var actor: Node
var sheet: Image
var samples: Array=[]
var strikes: Array[int]=[]
var sheet_row=0
var world_ref: Node
var map_texture_checks: Dictionary={}
const CAPTURE_PHASES={"idle_before":{0:0},"run":{0:1,2:2,3:3,5:4},"idle_after":{0:5},"attack":{0:6,3:7,5:8},"hit":{3:9},"death":{0:10,5:11}}

func map_ready() -> bool:
	var renderer=world_ref.field_renderer
	if not check(renderer!=null and renderer.has_method("refresh_visible"),"Actual latest source84 renderer API exists"):return false
	for tick in range(600):
		renderer.refresh_visible()
		if not check(str(renderer.failure).is_empty(),"Actual source84 renderer failure remains empty"):return false
		if not bool(renderer.waiting_for_visible) and not renderer.chunks.is_empty():
			for chunk in renderer.chunks.values():
				if not check(chunk.texture!=null and chunk.texture.get_width()>0 and chunk.texture.get_height()>0,"Actual visible source-map chunk has native GPU texture"):return false
				var key=chunk.texture.get_instance_id()
				if not map_texture_checks.has(key):
					var bitmap=chunk.texture.get_image()
					if not check(bitmap!=null and not bitmap.is_empty(),"Visible chunk texture GPU image is not empty"):return false
					map_texture_checks[key]=true
			return true
		await process_frame
		await RenderingServer.frame_post_draw
	check(false,"Bounded source84 visible chunk admission completed")
	return false

func invariant(world: Node) -> String:
	return JSON.stringify([world.hp,world.mp,world.gold,world.inventory,world.equipped_items,world.equipped_catalog,world.item_instances,actor.move_speed,actor.attack_speed_multiplier,actor.collision_layer,actor.collision_mask,actor.get_node("CollisionShape2D").transform])

func sample(id: String,d: int,stage: String,tick: int) -> void:
	var sprite: AnimatedSprite2D=actor.transform_sprite
	var tex: Texture2D=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	var entry={"id":id,"direction":d,"stage":stage,"tick":tick,"clip":str(sprite.animation),"phase":sprite.frame,"actor_world":actor.global_position,"actor_velocity":actor.velocity,"actor_position_delta":actor.get_position_delta(),"motion_move_ratio":actor.motion.move_ratio,"motion_gait":actor.motion.gait,"sprite_position":sprite.position,"sprite_offset":sprite.offset,"sprite_scale":sprite.scale,"sprite_rotation":sprite.rotation,"base_scale":sprite.get_meta("base_scale"),"texture_canvas":tex.get_size(),"authored_motion_weight":actor.motion.profile.authored_motion_weight,"floating":actor.motion.profile.floating,"body_kind":actor.motion.profile.body_kind}
	if tex is AtlasTexture:
		entry["source"]=tex.atlas.resource_path
		entry["region"]=tex.region
		entry["margin"]=tex.margin
		# Raw-source point projected onto actor origin. This is registration C,
		# never inferred to be an anatomical sole or pelvis.
		entry["source_C_at_actor_root"]=tex.region.position+tex.get_size()*.5-tex.margin.position-sprite.offset-sprite.position/sprite.scale
	samples.append(entry)

func capture(column: int) -> void:
	actor.camera.force_update_scroll()
	if not await map_ready():return
	await process_frame
	await RenderingServer.frame_post_draw
	var point=actor.get_global_transform_with_canvas()*Vector2.ZERO
	var crop=root.get_texture().get_image().get_region(Rect2i(Vector2i(point)+Vector2i(-110,-205),Vector2i(220,240)))
	sheet.blit_rect(crop,Rect2i(0,0,220,240),Vector2i(column*220,sheet_row*240))

func window(id: String,d: int,stage: String) -> void:
	var aim=Vector2.RIGHT.rotated(d*PI/4.)
	var moving=stage=="run"
	var role="idle" if stage in ["idle_before","idle_after"] else stage
	var clip=role+"_"+str(d)
	var sprite: AnimatedSprite2D=actor.transform_sprite
	var frames=sprite.sprite_frames
	var count=frames.get_frame_count(clip)
	var stage_start=actor.global_position
	var before_strikes=strikes.size()
	var sequence=-1
	var marker_seen=false
	actor.set_touch_vector(aim if moving else Vector2.ZERO)
	actor.clear_click_path()
	var delta=1./60. if moving or role=="idle" else 1./120.
	var duration=6./frames.get_animation_speed(clip)*1.4 if role=="idle" else (1.2 if moving else .95)
	if role=="attack":sequence=actor.start_combat_attack(actor.global_position+aim*128.,.9,actor.motion.profile.motion_style)
	if role=="hit":
		actor.motion.react(false,Vector2.ZERO)
		duration=maxf(actor.motion.hit_duration,actor.motion._native_hit_duration)*1.25
	if role=="death":
		actor.motion.die()
		duration=actor.motion.profile.death_duration+.12
	var seen={}
	var previous=-1
	for tick in range(int(ceil(duration/delta))+4):
		if not check(not world_ref.is_processing() and not world_ref.is_physics_processing() and not actor.is_physics_processing(),"No automatic world/player callback during manual phase window"):return
		await physics_frame
		actor._physics_process(delta)
		if str(sprite.animation)==clip:
			var phase=sprite.frame
			if phase!=previous:sample(id,d,stage,tick);previous=phase
			if not seen.has(phase):
				seen[phase]=true
				if CAPTURE_PHASES[stage].has(phase):await capture(CAPTURE_PHASES[stage][phase])
		if role=="attack" and strikes.size()>before_strikes and not marker_seen:
			check(strikes.size()==before_strikes+1 and strikes.back()==sequence,"One authoritative marker "+id+" "+clip)
			check(str(sprite.animation)==clip and sprite.frame==actor.motion.profile.hit_frame_for("attack"),"Exact profile impact pose "+id+" "+clip)
			marker_seen=true
		check(not sprite.flip_h,"No mirror "+id+" "+clip)
	check(seen.size()==count,"Actual physics all existing phases "+id+" "+stage+" "+clip+" seen="+str(seen.keys()))
	check(marker_seen and strikes.size()==before_strikes+1 if role=="attack" else strikes.size()==before_strikes,"Marker ownership "+id+" "+clip)
	if role=="death":check(actor.motion.state=="corpse" and sprite.frame==count-1,"Terminal corpse hold "+id+" "+clip)
	report.cases.append({"id":id,"direction":d,"stage":stage,"expected":count,"seen":seen.keys(),"marker_seen":marker_seen,"start_world":stage_start,"end_world":actor.global_position,"actual_displacement":actor.global_position-stage_start})

func run() -> void:
	root.size=Vector2i(1280,720)
	var world=load("res://Main.tscn").instantiate()
	world_ref=world
	world.set_process(false);world.set_physics_process(false);root.add_child(world)
	await process_frame
	report["world_processing_after_ready_before_freeze"]={"process":world.is_processing(),"physics":world.is_physics_processing()}
	world.set_process(false);world.set_physics_process(false)
	for node in world.find_children("*","",true,false):node.set_process(false);node.set_physics_process(false)
	world.save_timer=-10000.
	if bool(world.hud.get("class_picker_initial")):world.hud.complete_class_selection()
	actor=world.player
	world.set_process(false);world.set_physics_process(false)
	actor.set_process(false);actor.set_physics_process(false)
	check(not world.is_processing() and not world.is_physics_processing() and not actor.is_physics_processing(),"One manual physics owner; world callbacks frozen after ready and picker")
	actor.camera.make_current()
	if not check(world.field_renderer!=null,"Real default field renderer requires existing map pack"):finish(1);return
	check(world.field_map!=null and bool(world.field_map.get_meta("source_map84",false)),"Latest-main source84 default field, no legacy missing-pack fallback")
	if not await map_ready():finish(1);return
	await physics_frame
	if not check(PhysicsServer2D.body_get_space(actor.get_rid()).is_valid(),"Real actor collider remains in real map space"):finish(1);return
	var origin=actor.position
	var origin_cell=world._world_to_cell(origin)
	var homes={}
	for d in range(8):
		var aim=Vector2.RIGHT.rotated(d*PI/4.)
		for radius in [0,8,16,32,48,64]:
			for side in range(24):
				var offset=Vector2.RIGHT.rotated(side*TAU/24.)*radius
				var candidate=world._cell_to_world(origin_cell+Vector2i(roundi(offset.x),roundi(offset.y)))
				var legal=true
				for step in range(23):
					if not world._is_walkable_world(candidate+aim*minf(step*15.,330.)):legal=false;break
				if not legal:continue
				if not world.field_map.source_line_clear(candidate,candidate+aim*330.):continue
				var from=actor.global_transform;from.origin=candidate
				if actor.test_move(from,Vector2.ZERO,null,.08,true) or actor.test_move(from,aim*330.):continue
				homes[d]=candidate;break
			if homes.has(d):break
		if not check(homes.has(d),"Direction-specific native map330px path and collider clearance "+str(d)):finish(1);return
	sheet=Image.create(2640,3840,false,Image.FORMAT_RGBA8)
	actor.attack_strike.connect(func(sequence: int)->void:strikes.append(sequence))
	for id: String in ["393","267"]:
		var selected={}
		for row: Dictionary in world.catalog_db["변신"]:
			if str(row.get("sourceId",""))==id:selected=row
		actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
		world._apply_transform_visual(selected)
		check(actor.transform_sprite.sprite_frames.resource_path==str(selected.animation_profile.frames_path),"Actual selected default, no injected art "+id)
		var before=invariant(world)
		for d in range(8):
			actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
			actor.position=homes[d];actor.velocity=Vector2.ZERO;actor.set_touch_vector(Vector2.ZERO)
			actor.motion.face(Vector2.RIGHT.rotated(d*PI/4.))
			actor.camera.force_update_scroll()
			if not await map_ready():finish(1);return
			await window(id,d,"idle_before")
			await window(id,d,"run")
			var stopped=actor.position
			await window(id,d,"idle_after")
			check(actor.position.distance_to(stopped)<.05,"Stop preserves actual body position "+id+" d"+str(d))
			check(stopped.distance_to(homes[d])>20.,"Actual physical displacement "+id+" d"+str(d))
			await window(id,d,"attack")
			await window(id,d,"hit")
			await window(id,d,"death")
			check(invariant(world)==before,"HP inventory equipment speed collider/save identity unchanged "+id+" d"+str(d))
			sheet_row+=1
			report["completion_status"]="RUNNING_NOT_QUALITY_APPROVED"
			report["samples"]=samples
			var checkpoint=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
			checkpoint.store_string(JSON.stringify(report,"\t")+"\n")
			checkpoint.close()
			sheet.save_jpg(output.path_join("unique2-actual-Main-overview.jpg"),.94)
			print("UNIQUE_FINE ",id," direction=",d," errors=",report.errors.size())
	actor.position=origin;actor.velocity=Vector2.ZERO;actor.set_touch_vector(Vector2.ZERO)
	sheet.save_jpg(output.path_join("unique2-actual-Main-overview.jpg"),.94)
	report["completion_status"]="COMPLETE"
	report["actual_visible_gpu_textures_checked"]=map_texture_checks.size()
	report["actual_map_id"]=world.active_map_id
	report["actual_field_script"]=world.field_map.get_script().resource_path
	report["samples"]=samples
	report["overview_rows"]="393 E/SE/S/SW/W/NW/N/NE, then267 same order"
	report["overview_columns"]="IDLE0,RUN0,RUN2,RUN3,RUN5,STOP-IDLE0,ATK0,ATK3,ATK5,HIT3,DEATH0,DEATH5"
	report["anatomical_landmarks_pending_manual_source_pins"]=true
	report["source_C_is_registration_not_anatomical_foot"]=true
	report["393_flying_ground_contact_not_required"]=true
	report["no_native_import_export_claim"]=true
	finish(0 if report.errors.is_empty() else 1)
