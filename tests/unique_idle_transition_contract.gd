extends SceneTree
## Presentation/clock regression only; never a source-art quality approval.
const Motion = preload("res://scripts/animation/actor_motion.gd")
const Profile = preload("res://scripts/animation/animation_profile.gd")
const Catalog = preload("res://scripts/animation/animation_catalog.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.set_meta("twilight_native_locomotion_staging",true)
	var im := Image.create(8,8,false,Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(im)
	for d in range(8):
		for role in ["idle","walk","run","attack"]:
			var key := "%s_%d" % [role,d]
			frames.add_animation(key)
			for j in range(6):frames.add_frame(key,texture)
	var parent := Node2D.new()
	root.add_child(parent)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames=frames
	parent.add_child(sprite)
	var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for ident in ["267","393"]:
		var record: Dictionary={}
		for entry: Dictionary in records["변신"]:
			if str(entry.sourceId)==ident:record=entry
		var profile=Catalog.for_record("transform",record)
		check(profile.stable_idle_pose and profile.restart_gait_on_move,"Actual catalog opt-in "+ident)
		for zoom in [1.0,2.0]:
			parent.scale=Vector2.ONE*zoom
			for d in range(8):
				var motion=Motion.new();motion.profile=profile
				var aim:=Vector2.RIGHT.rotated(d*PI/4.0)
				motion.face(aim)
				for tick in range(90):
					motion.advance(1.0/30.0,Vector2.ZERO);motion.apply(sprite,Vector2.ONE)
					check(sprite.frame==0,"One actual idle pose")
					check(absf(sprite.position.y-profile.sprite_offset.y)*zoom<=0.501,"Screen-pixel breathing bound")
					check(sprite.scale==Vector2.ONE and sprite.rotation==0.0 and sprite.position.x==profile.sprite_offset.x,"No idle stretch/rotation/lateral movement")
				motion.gait=4.7
				motion.advance(1.0/30.0,aim*210.0);motion.apply(sprite,Vector2.ONE)
				check(sprite.frame==0,"Start at existing contact pose")
				for tick in range(8): motion.advance(1.0/30.0,aim*210.0)
				motion.apply(sprite,Vector2.ONE)
				check(sprite.frame>0,"Do not freeze or repeat locomotion frames")
				motion.advance(1.0/30.0,Vector2.ZERO);motion.apply(sprite,Vector2.ONE)
				check(sprite.frame==0,"Return to selected idle")
				var releases: Array=[]
				var listener: Callable=func(sequence: int):releases.append([sequence,motion.attack_elapsed])
				motion.strike.connect(listener)
				var seq:int=motion.begin_attack(.8,aim,profile.motion_style,profile.marker_for(profile.motion_style))
				for tick in range(30):
					motion.advance(1.0/30.0,Vector2.ZERO);motion.apply(sprite,Vector2.ONE)
					if motion.presenting_attack or sprite.animation.begins_with("attack"):
						check(sprite.position==profile.sprite_offset,"Idle breath must not displace an attack")
				check(releases.size()==1 and releases[0][0]==seq,"One authoritative strike")
				check(absf(releases[0][1]-.8*profile.marker_for(profile.motion_style))<=1.0/30.0+.0001,"Existing attack marker time")
				motion.strike.disconnect(listener)
	check(parent.position==Vector2.ZERO,"Physical parent remains fixed")
	print("UNIQUE_IDLE_TRANSITION_CONTRACT failures=",failures.size()," visual_approval=false")
	parent.free()
	quit(0 if failures.is_empty() else 1)
