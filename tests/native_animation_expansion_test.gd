extends SceneTree

## Exercise the production resources and timeline, including mixed track lengths
## and live actors whose appearance is evicted from the lookup cache.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const MONSTER_DB = preload("res://scripts/monsters/monster_catalog.gd")
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label); print("NATIVE_EXPANSION_FAIL: " + label)

func run() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG.PROFILE_PATH))
	var monster_records: Dictionary = {}
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	for row: Dictionary in MONSTER_DB.expand(original["몬스터"]): monster_records[str(row.name)]=row
	var resources: Dictionary = {}
	var global_pixels: Dictionary = {}
	var bindings := {"transform":0,"monster":0}
	var retained := AnimatedSprite2D.new()
	root.add_child(retained)
	var retained_key := ""
	var total_cost := 0
	for key: String in raw.profiles:
		var setting: Dictionary = raw.profiles[key]
		var path: String = str(setting.get("frames_path",""))
		if not path.begins_with("res://assets/actors/eight_direction/expanded/"): continue
		var kind := key.get_slice(":",0)
		var identity := key.trim_prefix(kind+":")
		var record := {"sourceId":identity} if kind=="transform" else {"name":identity}
		if kind=="transform":
			var found := false
			for row: Dictionary in db["변신"]:
				if str(row.sourceId)==identity:
					found=true
					record=row
					check(row.grade in ["영웅","전설","신화","유일"], "expanded real Hero+ ID "+key)
			check(found,"transformation remains in DB "+key)
		else:
			check(monster_records.has(identity),"monster remains in expanded production DB "+key)
			record=monster_records.get(identity,record)
		bindings[kind]+=1
		var profile = CATALOG.for_record(kind,record)
		check(profile.frames_path==path and profile.layout=="directional8","native production profile "+key)
		var frames: SpriteFrames = CATALOG.frames_for_profile(profile,"")
		check(frames!=null and CATALOG.first_texture(frames)!=null,"renderable resource "+key)
		if resources.has(path) or frames==null: continue
		resources[path]=true
		var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("provenance.json")))
		var compass_indices: Array = proof.source_direction_indices.map(func(value: Variant) -> int: return int(value))
		check(compass_indices==[4,3,2,1,0,7,6,5],"reviewed source compass convention "+path)
		check(Vector2(proof.foot[0],proof.foot[1])==Vector2(128,160) and Vector2(proof.cell[0],proof.cell[1])==Vector2(256,256),"fixed source foot canvas "+path)
		for role: String in ["idle","walk","attack","hit","death"]:
			check(proof.tracks.has(role),"five source actions "+path+role)
		for role: String in proof.tracks:
			for atlas: Dictionary in proof.tracks[role].atlas_files:
				check(FileAccess.get_sha256(atlas.path)==atlas.sha256,"actual runtime atlas hash "+str(atlas.path))
				check(atlas.size[0]<=1024 and atlas.size[1]<=2048,"bounded atlas page "+str(atlas.path))
			for direction: int in range(8):
				var track := "%s_%d" % [role,direction]
				check(frames.has_animation(track),"real directional track "+path+track)
				if not frames.has_animation(track): continue
				var images: Dictionary = {}
				for index: int in range(frames.get_frame_count(track)):
					var texture: Texture2D = frames.get_frame_texture(track,index)
					check(texture!=null and texture.get_size()==Vector2(256,256),"stable virtual canvas "+track)
					if texture==null: continue
					var pixels := texture.get_image()
					check(not pixels.is_invisible(),"no empty playback frame "+path+track)
					var hash := HashingContext.new()
					hash.start(HashingContext.HASH_SHA256);hash.update(pixels.get_data())
					var digest := hash.finish().hex_encode()
					images[digest]=true;global_pixels[digest]=true
				check(images.size()==int(proof.tracks[role].direction_unique_frames[proof.directions[direction]]),"measured distinct source poses "+path+track)
				if role in ["attack","ranged_attack","cast","special"]:
					verify_contact(profile,frames,role,direction)
		if retained_key.is_empty():
			retained.sprite_frames=frames
			retained.animation="idle_0"
			retained_key=path+":"+profile.layout
	# Make the eviction assertion independent of repeated shared-outfit bindings.
	CATALOG.frames(retained_key.trim_suffix(":directional8"),"directional8")
	for path: String in resources:
		if path+":directional8"==retained_key: continue
		CATALOG.frames(path,"directional8")
		total_cost+=int(CATALOG.frame_costs.get(path+":directional8",0))
	check(not resources.is_empty(),"real expansion resources installed")
	check(CATALOG.frame_cache_bytes<=CATALOG.MAX_FRAME_CACHE_BYTES,"decoded lookup cache stays within budget")
	if total_cost>CATALOG.MAX_FRAME_CACHE_BYTES:
		check(not CATALOG.frame_cache.has(retained_key),"old lookup entry evicted after many appearances")
	check(retained.sprite_frames!=null and not retained.sprite_frames.get_frame_texture("idle_0",0).get_image().is_invisible(),"eviction retains live actor artwork")
	retained.free()
	print("NATIVE_EXPANSION_RESULT "+JSON.stringify({"assertions":assertions,"failures":failures,"bindings":bindings,"shared_outfits":resources.size(),"distinct_rgba_frames_global":global_pixels.size(),"lookup_cache_bytes":CATALOG.frame_cache_bytes}))
	quit(0 if failures.is_empty() else 1)

func verify_contact(profile: TwilightAnimationProfile, frames: SpriteFrames, role: String, direction: int) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames=frames
	root.add_child(sprite)
	var aim := Vector2.from_angle(direction*PI/4.0)
	for duration: float in [1.44,.72,.18]:
		var motion = MOTION.new()
		motion.profile=profile
		var strikes: Array[int] = []
		motion.strike.connect(func(id: int) -> void: strikes.append(id))
		var cycle: int = motion.begin_attack(duration,aim,"slash",.44)
		motion.action_role=role
		motion.advance(duration*.439,Vector2.ZERO)
		motion.apply(sprite,Vector2.ONE*profile.pixel_scale)
		check(sprite.animation=="%s_%d" % [role,direction] and sprite.frame<profile.hit_frame_for(role) and strikes.is_empty(),"windup precedes per-action contact "+role)
		motion.advance(duration*.002,Vector2.ZERO)
		motion.apply(sprite,Vector2.ONE*profile.pixel_scale)
		check(sprite.frame==profile.hit_frame_for(role) and strikes==[cycle],"release pose and damage share timeline "+role)
		check(not sprite.flip_h and is_zero_approx(sprite.rotation) and sprite.position.is_equal_approx(profile.sprite_offset),"no invented direction or drifting foot "+role)
		motion.advance(duration*2.,Vector2.ZERO)
		motion.apply(sprite,Vector2.ONE*profile.pixel_scale)
		check(strikes==[cycle],"frame skip cannot add a duplicate strike "+role)
		var skipped = MOTION.new()
		skipped.profile=profile
		var skipped_hits: Array[int] = []
		skipped.strike.connect(func(id: int) -> void: skipped_hits.append(id))
		var skipped_cycle: int=skipped.begin_attack(duration,aim,"slash",.44)
		skipped.action_role=role
		skipped.advance(duration*2.,Vector2.ZERO)
		skipped.apply(sprite,Vector2.ONE*profile.pixel_scale)
		check(skipped_hits==[skipped_cycle] and sprite.frame==profile.hit_frame_for(role),"single slow frame still displays contact "+role)
	sprite.free()
