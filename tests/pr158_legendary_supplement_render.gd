extends "res://tests/pr122_published_boss_approval_main.gd"
## Supplemental draft texture/render proof, deliberately NOT Player integration.
func run() -> void:
	report["actual_Main"] = false
	report["scope"] = "Standalone authored legendary supplement; native registration and Player installation remain HOLD"
	report["new_quality_approvals"] = 0
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/evidence/pr122-final-approval-20261025/source-repair-batch/legendary274-supplement.json"))
	check(FileAccess.get_sha256(receipt.frames)==receipt.frames_sha256,"Exact SpriteFrames pin")
	check(FileAccess.get_sha256("res://"+receipt.source_track.texture)==receipt.source_track.source_sha256,"Exact authored PNG pin")
	var frames: SpriteFrames = load(receipt.frames)
	check(frames.get_frame_count("attack_7")==6,"Six authored source poses")
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames=frames
	sprite.animation="attack_7"
	sprite.position=Vector2(320,300)
	sprite.scale=Vector2.ONE*.5
	root.size=Vector2i(640,640)
	root.add_child(sprite)
	var sheet := Image.create(640*6,640,false,Image.FORMAT_RGBA8)
	for phase: int in range(6):
		sprite.frame=phase
		await process_frame
		await RenderingServer.frame_post_draw
		sheet.blit_rect(root.get_texture().get_image(),Rect2i(0,0,640,640),Vector2i(phase*640,0))
	check(sheet.save_png(output.path_join("six-authored-poses.png"))==OK,"Save rendered poses")
	sprite.frame=0
	sprite.play()
	await create_timer(1.0).timeout
	check(not sprite.is_playing() and sprite.frame==5,"One-shot playback finishes and retains final frame")
	report["rendered_poses"]=6
	report["production_connected"]=false
	sprite.queue_free()
	finish(0 if report.errors.is_empty() else 1)
