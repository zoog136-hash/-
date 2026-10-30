extends "res://tests/pr122_published_boss_approval_main.gd"
const Registration = preload("res://scripts/animation/reviewed_frame_registration.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func run() -> void:
	report.actual_Main = false
	report.scope = "Registration arithmetic, opt-in isolation, offset restoration, authoritative attack clock"
	var im := Image.create(20,30,false,Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(im)
	var source := SpriteFrames.new()
	source.remove_animation("default")
	var entries: Array = []
	for phase: int in range(6): entries.append({"anchor":Vector2(5+phase,25),"scale":Vector2.ONE*.5,"target":Vector2.ZERO})
	for name: String in ["idle_0","attack_0"]:
		source.add_animation(name)
		source.set_animation_speed(name,6.0)
		for phase: int in range(6):source.add_frame(name,texture)
	source.set_meta("twilight_native_locomotion_staging",true)
	source.set_meta(Registration.META,{"idle_0":{"semantic_review":"PASS","frames":entries},"attack_0":{"semantic_review":"PASS","frames":entries}})
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames=source;sprite.offset=Vector2(3,4)
	root.add_child(sprite)
	var motion := Motion.new()
	motion.profile.layout="directional8";motion.profile.authored_motion_weight=0;motion.profile.sprite_offset=Vector2(0,-12)
	motion.profile.frames_path="res://explicit-unit-resource.tres";motion.profile.attack_hit_frame=3;motion.profile.action_hit_frames={"attack":3}
	motion.face(Vector2.RIGHT)
	var base := Vector2(1.2,1.0)
	for phase: int in range(6):
		Registration.restore_offset(sprite)
		check(Registration.apply(sprite,source,"idle_0",phase,base),"Reviewed phase applies")
		check((sprite.position+(sprite.offset-texture.get_size()*.5+entries[phase].anchor)*sprite.scale).is_equal_approx(Vector2.ZERO),"Exact semantic origin")
		check(sprite.scale.is_equal_approx(base*.5),"Uniform raw-source scale with preserved Player width convention")
	Registration.restore_offset(sprite)
	check(sprite.offset==Vector2(3,4),"Original offset restored")
	var rejected: Dictionary=source.get_meta(Registration.META).duplicate(true)
	rejected.idle_0.semantic_review="PENDING"
	source.set_meta(Registration.META,rejected)
	check(not Registration.apply(sprite,source,"idle_0",0,base),"Unreviewed proposals rejected")
	check(sprite.offset==Vector2(3,4),"Rejected proposal leaves offset untouched")
	rejected.idle_0.semantic_review="PASS";source.set_meta(Registration.META,rejected)
	var events: Array=[]
	var on_strike: Callable = func(sequence: int) -> void: events.append([sequence,motion.attack_elapsed])
	motion.strike.connect(on_strike)
	var sequence: int=motion.begin_attack(1.0,Vector2.RIGHT)
	for tick: int in range(75):
		motion.advance(1.0/60.0,Vector2.ZERO);motion.apply(sprite,base)
	check(events.size()==1 and events[0][0]==sequence,"One authoritative strike")
	check(absf(float(events[0][1])-motion.attack_hit_ratio)<=1.0/60.0+.0001,"Original authoritative strike time")
	var plain: SpriteFrames=source.duplicate(true)
	plain.remove_meta(Registration.META);sprite.sprite_frames=plain
	motion.apply(sprite,base)
	check(sprite.offset==Vector2(3,4),"Profile/resource switch restores original offset")
	check(sprite.scale.is_equal_approx(base),"Unregistered healthy source keeps baseline scale")
	motion.strike.disconnect(on_strike)
	sprite.free()
	await process_frame
	finish(0 if report.errors.is_empty() else 1)
