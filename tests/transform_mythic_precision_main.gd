extends "res://tests/transform_unique_precision_main.gd"
# Actual selected checkout catalog and resources,
# real map, single manual physics owner. No inferred anatomical alpha landmarks.
var previous_phase=-1
var actor_row=0
var projection_samples:Array=[]
var compact:Image
var run_pose_sheet:Image

func reset_action() -> void:
	actor.motion.dead=false;actor.motion.cancel_attack();actor.motion.hit_clock=0.
	actor.set_touch_vector(Vector2.ZERO);actor.velocity=Vector2.ZERO;actor.clear_click_path()
	actor.motion.advance(.5,Vector2.ZERO)

func pose_tick(velocity:Vector2=Vector2.ZERO) -> void:
	actor.motion.advance(1./120.,velocity)
	actor.motion.apply(actor.transform_sprite,actor.transform_sprite.get_meta("base_scale",Vector2.ONE))

func record_pose(id:String,d:int,role:String) -> void:
	sample(id,d,role,projection_samples.size())
	var sprite:AnimatedSprite2D=actor.transform_sprite
	var texture:Texture2D=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	projection_samples.append({"id":id,"direction":d,"role":role,"phase":sprite.frame,"position":actor.position,"sprite_position":sprite.position,"sprite_scale":sprite.scale,"sprite_offset":sprite.offset,"texture_size":texture.get_size(),"source":texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path,"registration":sprite.sprite_frames.get_meta("twilight_reviewed_frame_registration",{}).get(str(sprite.animation),{})})

func take_compact(column:int) -> void:
	actor.camera.force_update_scroll()
	if not await map_ready():return
	await process_frame
	await RenderingServer.frame_post_draw
	var point=actor.get_global_transform_with_canvas()*Vector2.ZERO
	var crop=root.get_texture().get_image().get_region(Rect2i(Vector2i(point)+Vector2i(-100,-190),Vector2i(200,220)))
	compact.blit_rect(crop,Rect2i(0,0,200,220),Vector2i(column*200,actor_row*220))

func take_run_pose(d:int,phase:int) -> void:
	actor.camera.force_update_scroll()
	if not await map_ready():return
	await process_frame
	await RenderingServer.frame_post_draw
	var point=actor.get_global_transform_with_canvas()*Vector2.ZERO
	var crop=root.get_texture().get_image().get_region(Rect2i(Vector2i(point)+Vector2i(-100,-190),Vector2i(200,220)))
	run_pose_sheet.blit_rect(crop,Rect2i(0,0,200,220),Vector2i(phase*200,d*220))

func controlled_role(id:String,d:int,role:String) -> void:
	var sprite:AnimatedSprite2D=actor.transform_sprite
	var frames=sprite.sprite_frames
	var aim=Vector2.RIGHT.rotated(d*PI/4.)
	var clip=role+"_"+str(2 if role=="death" else d)
	reset_action();actor.motion.face(aim)
	var expected=frames.get_frame_count(clip)
	check(expected>0,"Selected default required clip exists "+id+" "+clip)
	var before_strikes=strikes.size();var seq=-1;var marker=false
	if role=="attack":seq=actor.start_combat_attack(actor.global_position+aim*128.,.9,actor.motion.profile.motion_style)
	elif role=="hit":actor.motion.react(false,Vector2.ZERO)
	elif role=="death":actor.motion.die()
	var seconds=1.2
	if role=="idle":
		var units=0.
		for phase in range(expected):units+=frames.get_frame_duration(clip,phase)
		seconds=units/frames.get_animation_speed(clip)*1.1+.03
	elif role=="hit":seconds=maxf(actor.motion.hit_duration,actor.motion._native_hit_duration)*1.25+.02
	elif role=="death":seconds=actor.motion.profile.death_duration+.1
	var seen={}
	for tick in range(int(ceil(seconds*120.))+5):
		pose_tick()
		var phase=precision_source_phase(id,d,role,clip)
		if phase>=0:
			if not seen.has(phase):
				seen[phase]=true;record_pose(id,d,role)
				if role=="idle" and phase==0:await take_compact(d*5)
				if role=="attack" and phase==actor.motion.profile.hit_frame_for("attack"):await take_compact(d*5+4)
		if role=="attack" and strikes.size()>before_strikes and not marker:
			check(strikes.size()==before_strikes+1 and strikes.back()==seq and sprite.frame==actor.motion.profile.hit_frame_for("attack") and str(sprite.animation)==clip,"Exactly one current profile attack marker "+id+" "+clip);marker=true
		check(not sprite.flip_h and not sprite.sprite_frames==null,"No mirroring or absent visual "+id)
	check(seen.size()==expected,"Every actual authored timeline phase "+id+" "+clip+" "+str(seen.keys())+"/"+str(expected))
	if role=="attack":check(marker and strikes.size()==before_strikes+1,"Authoritative marker count "+id+" "+clip)
	else:check(strikes.size()==before_strikes,"Nonattack emits no combat strike "+id+" "+clip)
	if role=="death":check(actor.motion.state=="corpse" and sprite.frame==expected-1,"Original terminal South corpse "+id)
	report.cases.append({"id":id,"direction":d,"role":role,"expected":expected,"seen":seen.keys(),"marker_pass":marker})

func physical_run(id:String,d:int,home:Vector2) -> void:
	reset_action();actor.position=home
	var aim=Vector2.RIGHT.rotated(d*PI/4.)
	actor.motion.face(aim);actor.set_touch_vector(aim)
	actor.camera.force_update_scroll()
	if not await map_ready():return
	await physics_frame;await physics_frame
	var sprite:AnimatedSprite2D=actor.transform_sprite
	var clip="run_"+str(d);var frames=sprite.sprite_frames
	var seen={};var start=actor.position
	for tick in range(56):
		check(not world_ref.is_processing() and not world_ref.is_physics_processing() and not actor.is_physics_processing(),"Single manual physics owner after ready and picker")
		await physics_frame
		actor._physics_process(1./60.)
		if str(sprite.animation)==clip:
			var phase=sprite.frame
			if not seen.has(phase):
				seen[phase]=true;record_pose(id,d,"physical_run")
				if run_pose_sheet!=null:await take_run_pose(d,phase)
				var targets=[0,2,frames.get_frame_count(clip)-1]
				if phase in targets:await take_compact(d*5+1+targets.find(phase))
		check(not sprite.flip_h,"No physical run mirroring")
	check(seen.size()==frames.get_frame_count(clip),"All actual RUN phases under real physics "+id+" d"+str(d)+" "+str(seen.keys()))
	check(actor.position.distance_to(start)>20. and actor.position.distance_to(start)<330.,"Actual map-space displacement bounded by verified330px path "+id)
	actor.set_touch_vector(Vector2.ZERO)
	await physics_frame;actor._physics_process(1./60.)
	var stopped=actor.position
	for tick in range(4):await physics_frame;actor._physics_process(1./60.)
	check(actor.position.distance_to(stopped)<.05 and str(sprite.animation).begins_with("idle_"),"Real movement stop returns to IDLE without body drift "+id)
	report.cases.append({"id":id,"direction":d,"role":"physical_run_stop","expected":frames.get_frame_count(clip),"seen":seen.keys(),"displacement":actor.position-start,"stopped":stopped})

func precision_actor_ids(world:Node) -> Array:
	var selected_ids=["413","412","258"]
	for row:Dictionary in world.catalog_db["변신"]:
		if str(row.get("grade",""))=="신화" and not str(row.get("sourceId","")) in selected_ids:selected_ids.append(str(row.sourceId))
	check(selected_ids.size()==29,"Exact current catalog29 mythic scope")
	return selected_ids

func expected_visual_route(selected:Dictionary) -> Dictionary:
	return {"path":str(selected.animation_profile.frames_path)}

func precision_source_phase(_id:String,_d:int,_role:String,clip:String) -> int:
	return actor.transform_sprite.frame if str(actor.transform_sprite.animation)==clip else -1

func precision_actor_finished(_id:String) -> void:
	pass

func precision_output_name() -> String:
	return "mythic29-actual-Main-overview.jpg"

func run() -> void:
	root.size=Vector2i(1280,720)
	var world=load("res://Main.tscn").instantiate();world_ref=world;root.add_child(world)
	await process_frame
	world.set_process(false);world.set_physics_process(false)
	for node in world.find_children("*","",true,false):node.set_process(false);node.set_physics_process(false)
	if bool(world.hud.get("class_picker_initial")):world.hud.complete_class_selection()
	world.set_process(false);world.set_physics_process(false);world.save_timer=-10000.
	actor=world.player;actor.set_process(false);actor.set_physics_process(false);actor.camera.make_current()
	check(world.field_map!=null and bool(world.field_map.get_meta("source_map84",false)),"Current main real source84 map, no fallback")
	if not await map_ready():finish(1);return
	await physics_frame;await physics_frame
	check(PhysicsServer2D.body_get_space(actor.get_rid()).is_valid(),"Actual Player collider remains in actual map space")
	var origin=actor.position;var origin_cell=world._world_to_cell(origin);var homes={}
	for d in range(8):
		var aim=Vector2.RIGHT.rotated(d*PI/4.)
		for radius in [0,8,16,32,48,64]:
			for side in range(24):
				var offset=Vector2.RIGHT.rotated(side*TAU/24.)*radius
				var candidate=world._cell_to_world(origin_cell+Vector2i(roundi(offset.x),roundi(offset.y)))
				if not world.field_map.source_line_clear(candidate,candidate+aim*330.):continue
				var legal=true
				for step in range(23):
					if not world._is_walkable_world(candidate+aim*minf(step*15.,330.)):legal=false;break
				if not legal:continue
				var from=actor.global_transform;from.origin=candidate
				if actor.test_move(from,Vector2.ZERO,null,.08,true) or actor.test_move(from,aim*330.):continue
				homes[d]=candidate;break
			if homes.has(d):break
		if not check(homes.has(d),"Actual native330px route/collider clearance "+str(d)):finish(1);return
	var selected_ids=precision_actor_ids(world)
	var requested=OS.get_environment("TRANSFORM_PRECISION_IDS").split(",",false)
	if not requested.is_empty():
		for key:String in requested:check(key in selected_ids,"Explicit precision scope belongs to the requested catalog group")
		selected_ids=Array(requested)
		if selected_ids.size()==1:
			run_pose_sheet=Image.create(1200,1760,false,Image.FORMAT_RGBA8)
			run_pose_sheet.fill(Color(.1,.11,.13,1.))
	compact=Image.create(8000,selected_ids.size()*220,false,Image.FORMAT_RGBA8);compact.fill(Color(.1,.11,.13,1.))
	actor.attack_strike.connect(func(sequence:int)->void:strikes.append(sequence))
	for id:String in selected_ids:
		var selected={}
		for row:Dictionary in world.catalog_db["변신"]:
			if str(row.get("sourceId",""))==id:selected=row
		reset_action();world._apply_transform_visual(selected)
		var route=expected_visual_route(selected)
		var selected_path=str(route.path)
		check(actor.transform_active and actor.transform_sprite.visible and actor.transform_sprite.sprite_frames.resource_path==selected_path,"Actual independently expected default resource, no fallback/injected candidate "+id)
		if route.has("sha256"):check(FileAccess.get_sha256(selected_path)==str(route.sha256),"Selected resource matches independent expected SHA "+id)
		if not report.has("selected_visual_routes"):report["selected_visual_routes"]=[]
		report.selected_visual_routes.append({"id":id,"catalog_path":str(selected.animation_profile.frames_path),"actual_path":actor.transform_sprite.sprite_frames.resource_path,"expected_path":selected_path,"profile_id":actor.motion.profile.profile_id,"explicit_source_override":bool(route.get("source_override",false))})
		var baseline=JSON.stringify([world.hp,world.mp,world.gold,world.inventory,world.equipped_items,world.equipped_catalog,world.item_instances,actor.move_speed,actor.attack_speed_multiplier,actor.collision_layer,actor.collision_mask,actor.get_node("CollisionShape2D").transform,selected])
		for d in range(8):
			reset_action();actor.position=homes[d]
			await controlled_role(id,d,"idle")
			await physical_run(id,d,homes[d])
			await controlled_role(id,d,"idle")
			await controlled_role(id,d,"attack")
			await controlled_role(id,d,"hit")
		await controlled_role(id,2,"death")
		check(JSON.stringify([world.hp,world.mp,world.gold,world.inventory,world.equipped_items,world.equipped_catalog,world.item_instances,actor.move_speed,actor.attack_speed_multiplier,actor.collision_layer,actor.collision_mask,actor.get_node("CollisionShape2D").transform,selected])==baseline,"HP stats inventory physical equipment collider and saved identity unchanged "+id)
		precision_actor_finished(id)
		actor_row+=1
		report["actor_order"]=selected_ids;report["completed_actors"]=actor_row
		report["projection_samples"]=projection_samples;report["samples"]=samples
		var f=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t")+"\n");f.close()
		compact.save_jpg(output.path_join(precision_output_name()),.9)
		print("CURRENT_MAIN_MYTHIC ",id," completed=",actor_row," errors=",report.errors.size())
	if run_pose_sheet!=null:run_pose_sheet.save_jpg(output.path_join("scope-RUN-all-existing-poses.jpg"),.94)
	actor.position=origin;reset_action()
	report["actual_visible_gpu_textures_checked"]=map_texture_checks.size()
	report["runtime_source_sha256"]={"world":FileAccess.get_sha256("res://scripts/world.gd"),"actor_motion":FileAccess.get_sha256("res://scripts/animation/actor_motion.gd"),"catalog":FileAccess.get_sha256("res://data/catalog_v19.json")}
	report["compact_columns_each_view"]="idle0, physicalRUN0/2/5, attack authoritative impact"
	report["projection_is_not_anatomical_landmark_inference"]=true
	finish(0 if report.errors.is_empty() else 1)
