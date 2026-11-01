extends "res://tests/pr122_published_boss_approval_main.gd"
## Real Main scene and input/normal-attack path; isolated user directory required.
var world: Node
var actor: Node
var label: Label
var samples: Array = []
var strikes := 0
var started_usec := 0
var started_frame := 0

func run() -> void:
	assert("--girtas-shared-skin" in OS.get_cmdline_user_args())
	assert(not output.is_empty())
	Engine.max_fps = 30
	root.size = Vector2i(1280,720)
	# Freeze QA ambient actors before the first physics frame, including pooled spawns.
	node_added.connect(func(node: Node):
		if node.has_signal("player_hit") and node.has_signal("died"): node.process_mode=Node.PROCESS_MODE_DISABLED)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(preload("res://tests/qa_class_selection.gd").enter_game(world))
	world.save_timer = -10000.0
	world.hud._hide_aux_panels()
	assert(world.field_map != null and not world.map_bootstrap_blocked)
	actor = world.player
	actor.set_auto_enabled(false)
	# Controlled animation QA: hold ambient AI, not player physics or combat.
	# Damage still goes through normal world selection/range/strike resolution.
	for monster in world.monsters_root.get_children():
		monster.process_mode=Node.PROCESS_MODE_DISABLED
	world.monsters_root.child_entered_tree.connect(func(monster: Node): monster.set("process_mode",Node.PROCESS_MODE_DISABLED))
	var record: Dictionary = {}
	for row in world.catalog_db["변신"]:
		if str(row.get("sourceId","")) == "267": record = row;break
	assert(not record.is_empty())
	# Transient catalog presentation: no collection grant, currency or save mutation.
	world._apply_transform_visual(record)
	assert(actor.transform_profile.profile_id == "transform:267")
	assert(actor.girtas_skin_preview != null)
	actor.attack_strike.connect(func(_id: int): strikes+=1)
	var layer := CanvasLayer.new();layer.layer=100;root.add_child(layer)
	var bg:=ColorRect.new();bg.color=Color(0.03,0.04,0.06,0.95);bg.size=Vector2(1280,45);layer.add_child(bg)
	label=Label.new();label.position=Vector2(18,10);label.add_theme_font_size_override("font_size",20);layer.add_child(label)
	started_usec=Time.get_ticks_usec();started_frame=Engine.get_frames_drawn()
	print("GIRTAS_MAIN_START frame=",started_frame," map=",world.active_map_id)
	for direction in [Vector2.RIGHT,Vector2.DOWN]:
		var start: Vector2 = find_route(direction)
		actor.global_position=start
		actor.camera.reset_smoothing()
		actor.motion.face(direction)
		await play_stage("IDLE",1.0,Vector2.ZERO)
		await play_stage("RUN",2.0,direction)
		await play_stage("STOP",0.5,Vector2.ZERO)
		var target: Node = null
		for candidate in world.monsters_root.get_children():
			if not candidate.dead:target=candidate;break
		assert(target!=null)
		target.global_position=actor.global_position+direction*24.0
		world.selected_monster=target
		var hp_before: int = target.hp
		world._attack()
		if not actor.motion.active:
			push_error("Normal attack rejected: range="+str(world._weapon_cell_distance(target))+" los="+str(world._has_line_of_sight_world(actor.global_position,target.global_position))+" stun="+str(actor.is_stunned())+" pending="+str(not world.pending_attack.is_empty()))
			quit(1);return
		await play_stage("NORMAL ATTACK / real hit clock",1.4,Vector2.ZERO)
		print("GIRTAS_MAIN_ATTACK hp_before=",hp_before," hp_after=",target.hp," strikes=",strikes)
		await play_stage("RESTART",1.0,direction)
		await play_stage("STOP",0.5,Vector2.ZERO)
	# Unsupported direction must restore the real original renderer.
	actor.motion.face(Vector2.LEFT)
	await play_stage("W / ORIGINAL RESOURCE FALLBACK",0.5,Vector2.ZERO)
	assert(not actor.girtas_skin_preview.visible and actor.transform_sprite.visible)
	world._apply_transform_visual({})
	await play_stage("CLASS / ORIGINAL RESOURCE",0.2,Vector2.ZERO)
	assert(not actor.girtas_skin_preview.visible and actor.class_sprite.visible)
	var unrecorded_fps := 0.0
	if "--live-capture" in OS.get_cmdline_user_args():
		print("GIRTAS_CAPTURE_END")
		await create_timer(1.0).timeout
		world._apply_transform_visual(record)
		actor.global_position=find_route(Vector2.RIGHT)
		var bench_started:=Time.get_ticks_usec()
		var bench_frames:=Engine.get_frames_drawn()
		await play_stage("UNRECORDED FPS / RUN",2.0,Vector2.RIGHT)
		await play_stage("UNRECORDED FPS / STOP",1.0,Vector2.ZERO)
		actor.global_position=find_route(Vector2.DOWN)
		await play_stage("UNRECORDED FPS / RUN",2.0,Vector2.DOWN)
		unrecorded_fps=float(Engine.get_frames_drawn()-bench_frames)/(float(Time.get_ticks_usec()-bench_started)/1000000.0)
		print("GIRTAS_UNRECORDED_FPS ",unrecorded_fps)
	var wall_seconds := float(Time.get_ticks_usec()-started_usec)/1000000.0
	var rendered := Engine.get_frames_drawn()-started_frame
	var f:=FileAccess.open(output.path_join("main-telemetry.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"actual_Main":true,"unrecorded_fps":unrecorded_fps,"map":world.active_map_id,"strikes":strikes,"wall_seconds":wall_seconds,"rendered_frames":rendered,"wall_fps":float(rendered)/wall_seconds,"samples":samples}));f.close()
	print("GIRTAS_MAIN_COMPLETE fps=",float(rendered)/wall_seconds," strikes=",strikes," samples=",samples.size())
	quit(0)

func play_stage(stage: String, duration: float, direction: Vector2) -> void:
	actor.touch_vector=direction
	label.text="MAIN / GIRTAS E+S / AI HELD FOR QA / "+stage+" / other directions: original"
	var simulated:=0.0
	while simulated<duration:
		await process_frame
		simulated+=world.get_process_delta_time()
		samples.append({"stage":stage,"frame":Engine.get_frames_drawn(),"position":[actor.position.x,actor.position.y],"facing":actor.facing8,"state":actor.motion.state,"preview":actor.girtas_skin_preview.visible,"attack_progress":actor.motion.visual_progress,"sequence":actor.motion.sequence,"hit_ratio":actor.motion.attack_hit_ratio,"gait_phase":actor.girtas_skin_preview.ground.phase,"gait_distance":actor.girtas_skin_preview.ground.distance,"velocity":[actor.velocity.x,actor.velocity.y]})
	actor.touch_vector=Vector2.ZERO

func find_route(direction: Vector2) -> Vector2:
	var origin: Vector2=actor.global_position
	for radius in range(0,2049,64):
		for turn in range(16):
			var candidate: Vector2=origin+Vector2.RIGHT.rotated(turn*TAU/16.0)*radius
			var clear:=true
			var previous:=candidate
			for step in range(0,701,20):
				var point:=candidate+direction*step
				if not world._is_walkable_world(point):clear=false;break
				if world.field_map.has_method("point_clear") and not world.field_map.point_clear(point):clear=false;break
				if not world.field_map.line_clear(previous,point):clear=false;break
				previous=point
			if clear:return candidate
	assert(false,"No real map route available")
	return origin
