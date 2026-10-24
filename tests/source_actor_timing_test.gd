extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
var failures := 0
var strikes := 0

func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: "+label)

func _initialize() -> void:
	var motion := MOTION.new()
	var frames := SpriteFrames.new()
	frames.add_animation("attack_0")
	for duration: float in [2.,1.,3.]:
		var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
		frames.add_frame("attack_0",ImageTexture.create_from_image(image),duration)
	frames.set_meta("twilight_source_tracks",{"attack_0":{"hit_frames":[1,2]}})
	motion.frame_source = frames
	motion.profile.layout = "directional8"
	motion.strike.connect(func(_sequence: int): strikes += 1)
	var sprite := Sprite2D.new()
	motion.begin_attack(.6,Vector2.RIGHT,"slash",.44)
	motion.advance(.19,Vector2.ZERO)
	motion.apply_frames(sprite)
	check(sprite.texture == frames.get_frame_texture("attack_0",0),"two ticks remain two sixths of combat interval")
	motion.advance(.02,Vector2.ZERO)
	motion.apply_frames(sprite)
	check(sprite.texture == frames.get_frame_texture("attack_0",1),"source second frame starts at2/6, not gameplay marker")
	check(strikes == 0,"source frame does not apply early damage")
	motion.advance(.06,Vector2.ZERO)
	check(strikes == 1,"existing .44 authoritative strike remains unchanged")
	motion.apply_frames(sprite)
	motion.advance(.05,Vector2.ZERO)
	motion.apply_frames(sprite)
	check(sprite.texture == frames.get_frame_texture("attack_0",2),"last frame occupies original three sixths")
	motion.advance(2.,Vector2.ZERO)
	check(strikes == 1,"multiple source marks cannot add damage callbacks")
	var source := MOTION.new()
	source.profile.movement_fps = 6.25
	source.profile.reference_speed = 87.
	var target := MOTION.new()
	target.profile.movement_fps = 6.25*66./87./.671875
	target.profile.reference_speed = 66.
	target.profile.movement_cadence_width_ratio = 1.054968287526427
	source.advance(1.,Vector2(87,0))
	target.advance(1.,Vector2(66,0))
	check(is_equal_approx(source.gait/87.,target.gait*.671875*1.054968287526427/66.),"same scaled stride per travelled pixel")
	sprite.free()
	print("SOURCE_ACTOR_TIMING checks=7 failures=",failures)
	if failures == 0: print("SOURCE_ACTOR_TIMING_OK")
	quit(1 if failures else 0)
