extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	var opened: Dictionary=pack.open(args[0],receipt.manifest_sha256)
	if not opened.ok:print(opened);quit(1);return
	DirAccess.make_dir_recursive_absolute(args[1])
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1280,900)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rows: Array=[]
	for member: String in pack.manifest.entries:
		var scene=SCENE.new()
		var configured: Dictionary=scene.configure(pack,member,false)
		if not configured.ok:errors.append(member+":"+str(configured));scene.free();continue
		viewport.add_child(scene)
		scene.position=Vector2(640,700)
		scene.set_process(false)
		var emitters: Array=[]
		for node: Node in scene.source_nodes.values():
			if node.has_meta("source_particle"):
				var emitter: Node2D=node.get_meta("source_particle")
				emitter.set_process(false)
				emitter.state.random_source=func() -> float:return 0.0
				emitters.append(emitter)
		if emitters.is_empty():errors.append(member+":no original emitter")
		var captures: Array=[]
		for frame: int in range(120):
			scene.seek_frame(frame)
			for emitter: Node2D in emitters:emitter.advance(1.0/60.0)
			if frame not in [29,59,119]:continue
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image=viewport.get_texture().get_image()
			var filename: String=member.replace("/","_")+"_particle_"+str(frame)+".png"
			if pixels.save_png(args[1].path_join(filename))!=OK:errors.append(member+":capture failed")
			var statuses: Array=[]
			for emitter: Node2D in emitters:
				statuses.append(emitter.playback_status())
				if emitter.state.particles.size()>emitter.state.maximum:errors.append(member+":particle capacity")
			captures.append({"frame":frame,"has_pixels":pixels.get_used_rect().has_area(),"file":filename,"particles":statuses})
		# Consumers suspend the whole presentation via process_mode, because
		# stopping an action timeline alone does not freeze source particles.
		var clocks: Array=[]
		scene.process_mode=Node.PROCESS_MODE_DISABLED
		for emitter: Node2D in emitters:
			emitter.set_process(true)
			clocks.append(emitter.state.elapsed)
		await process_frame
		await process_frame
		for index: int in range(emitters.size()):
			if emitters[index].state.elapsed!=clocks[index]:errors.append(member+":suspended particle clock advanced")
		scene.process_mode=Node.PROCESS_MODE_INHERIT
		await process_frame
		await process_frame
		for index: int in range(emitters.size()):
			if emitters[index].state.active and emitters[index].state.elapsed<=clocks[index]:errors.append(member+":resumed particle clock did not advance")
		rows.append({"member":member,"captures":captures,"service_connected":false,"strict_configure":true,"suspend_resume_checked":true})
		scene.queue_free()
		await process_frame
	var result: Dictionary={"entries":rows,"errors":errors,"manifest_sha256":receipt.manifest_sha256,"scope":"original CSB/plist/PNG with fixed test randomness; strict source effect consumption and suspension, no original client seed or game service claim"}
	FileAccess.open(args[1].path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ORIGINAL_PARTICLE_RENDER "+JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
