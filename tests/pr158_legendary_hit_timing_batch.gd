extends "res://tests/pr122_published_boss_approval_main.gd"
## Same six-phase/terminal gate for every legendary NW hit; no art approval.
## Warm actual readback while paused, not merely frame submission.
func run() -> void:
	Engine.max_fps = 60
	report.actual_Main = false
	report.scope = "40 legendary NW hit clips; real-time capture diagnostic, not anatomical registration or production installation"
	report.final_approvals = 0
	root.size = Vector2i(1280,720)
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr158_hit_timing_batch.json"))
	for path: String in plan.pins:
		check(FileAccess.get_sha256("res://"+path)==plan.pins[path],"Pinned input: "+path)
	for start: int in range(0,plan.rows.size(),8):
		var batch: Array = []
		for index: int in range(start,mini(start+8,plan.rows.size())):
			var row: Dictionary = plan.rows[index]
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = load(row.selected_frames)
			sprite.animation = &"hit_5"
			check(sprite.sprite_frames.get_frame_count(sprite.animation)==6,"Six original poses: "+str(row.slot))
			var size := Vector2.ONE
			for phase: int in range(6):
				var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,phase)
				size = size.max(texture.get_size())
			var factor: float = minf(280.0/size.x,300.0/size.y)
			sprite.scale = Vector2.ONE*factor
			var tile := Vector2i((index-start)%4*320,(index-start)/4*360)
			sprite.position = Vector2(tile)+Vector2(160,180)
			root.add_child(sprite)
			batch.append({"sprite":sprite,"slot":row.slot,"tile":Rect2i(tile,Vector2i(320,360)),"seen":{},"images":{},"samples":[],"source":row.selected_frames})
		for phase: int in range(6):
			for state: Dictionary in batch: state.sprite.frame = phase
			await process_frame
			await RenderingServer.frame_post_draw
			# GPU submission warmup alone does not exercise synchronous readback.
			var warm: Image = root.get_texture().get_image()
			check(not warm.is_empty(),"Readback warmup returned pixels")
		for state: Dictionary in batch: state.sprite.frame = 0
		for settle: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var clock: int = Time.get_ticks_usec()
		for state: Dictionary in batch: state.sprite.play()
		while float(Time.get_ticks_usec()-clock)/1000000.0 < 0.7:
			await process_frame
			await RenderingServer.frame_post_draw
			var elapsed: float = float(Time.get_ticks_usec()-clock)/1000000.0
			var capture: Image = root.get_texture().get_image()
			for state: Dictionary in batch:
				var phase: int = state.sprite.frame
				state.samples.append([elapsed,phase])
				state.seen[phase] = true
				if not state.images.has(phase): state.images[phase] = capture.get_region(state.tile)
		for state: Dictionary in batch:
			var terminal: bool = state.sprite.frame==5 and not state.sprite.is_playing()
			check(state.seen.size()==6,"Rendered six timed phases: "+str(state.slot))
			check(terminal,"Terminal phase held: "+str(state.slot))
			var sheet := Image.create(1920,360,false,Image.FORMAT_RGBA8)
			for phase: int in state.images: sheet.blit_rect(state.images[phase],Rect2i(0,0,320,360),Vector2i(phase*320,0))
			var filename: String = str(state.slot[0]).replace(":","_")+"-NW-hit.png"
			check(sheet.save_png(output.path_join(filename))==OK,"Save timed capture")
			report.cases.append({"slot":state.slot,"seen":state.seen.keys(),"terminal_held":terminal,"samples":state.samples,"source":state.source,"capture":filename,"quality_approval":false})
			state.sprite.free()
	check(report.cases.size()==40,"Whole 40-actor NW-hit batch")
	finish(0 if report.errors.is_empty() else 1)
