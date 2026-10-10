extends SceneTree

# Full-catalog GL evidence through the same production renderers as the game.
# This is automatic render evidence, not a claim of manual artistic approval.
const MANIFEST = preload("res://scripts/animation/visual_manifest.gd")
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
const RELIC = preload("res://scripts/animation/relic_motion.gd")
var failures: Array[String] = []
var results: Array[Dictionary] = []
var directory := "user://all-catalog-render-review"
var page: Image
var page_index: int = 0
var page_slots: int = 0
var title: Label

func _initialize() -> void: call_deferred("_run")

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		print("ALL_CATALOG_RENDER_FAIL: ", label)

func _pixels() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_region(Rect2i(530, 160, 220, 280))

func _hash(image: Image) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(image.get_data())
	return digest.finish().hex_encode()

func _sampled_frame(frames: SpriteFrames, track: String, texture: Texture2D) -> int:
	for index: int in range(frames.get_frame_count(track)):
		if frames.get_frame_texture(track,index) == texture: return index
	return -1

func _flush() -> void:
	if page_slots == 0: return
	_check(page.save_png(directory + "/page-%02d.png" % page_index) == OK, "contact sheet saved")
	page_index += 1
	page_slots = 0

func _record(key: String, first: Image, second: Image, track: String, first_frame: int, second_frame: int) -> void:
	var hash_a: String = _hash(first)
	var hash_b: String = _hash(second)
	_check(hash_a != hash_b, "actual raster pixels change " + key)
	_check(first_frame != second_frame, "authored frame changes " + key)
	if page_slots == 0:
		page = Image.create(1280, 1280, false, Image.FORMAT_RGBA8)
		page.fill(Color("17202d"))
	var point := Vector2i((page_slots % 4) * 320, (page_slots / 4) * 160)
	first.resize(160, 160, Image.INTERPOLATE_LANCZOS)
	second.resize(160, 160, Image.INTERPOLATE_LANCZOS)
	page.blit_rect(first, Rect2i(0, 0, 160, 160), point)
	page.blit_rect(second, Rect2i(0, 0, 160, 160), point + Vector2i(160, 0))
	results.append({"game_key":key, "track":track, "frames":[first_frame,second_frame],
		"render_sha256":[hash_a,hash_b], "page":page_index, "slot":page_slots,
		"automatic_gpu_render_verified":hash_a != hash_b and first_frame != second_frame, "manual_art_review":false})
	page_slots += 1
	if page_slots == 32: _flush()
	if results.size() % 50 == 0: print("ALL_CATALOG_RENDER_PROGRESS ", results.size(), "/723")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	_check(str(RenderingServer.get_video_adapter_name()) != "", "real renderer present")
	_check(int(MANIFEST.stats().catalog) == 723, "entire real atlas pack installed")
	if not failures.is_empty(): quit(1); return
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("17202d")
	background.size = Vector2(1280,720)
	root.add_child(background)
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.camera.enabled = false
	actor.position = Vector2(640,420)
	var anchor := Node2D.new()
	root.add_child(anchor)
	var doll := AnimatedSprite2D.new()
	anchor.add_child(doll)
	var relic := Sprite2D.new()
	root.add_child(relic)
	title = Label.new()
	title.position = Vector2(532,164)
	title.size = Vector2(216,28)
	title.add_theme_font_size_override("font_size",14)
	title.add_theme_font_override("font",preload("res://assets/fonts/NotoSansKR.ttf"))
	root.add_child(title)
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	anchor.hide(); relic.hide()
	for record: Dictionary in db["변신"]:
		var key := "transform:" + str(record.sourceId)
		title.text = key + " · " + str(record.name)
		actor.set_transform_visual(record.image_path, 1.0, CATALOG.for_record("transform", record, record.image_path))
		actor.cancel_attack()
		actor.motion.face(Vector2.DOWN)
		actor.motion.advance(.02,Vector2.DOWN * 180)
		actor.motion.gait = 0.0
		actor.motion.apply(actor.transform_sprite, actor.transform_sprite.get_meta("base_scale"))
		var first_frame: int = actor.transform_sprite.frame
		var first: Image = await _pixels()
		actor.motion.gait = 2.0
		actor.motion.apply_frames(actor.transform_sprite)
		var second_frame: int = actor.transform_sprite.frame
		var second: Image = await _pixels()
		_record(key,first,second,str(actor.transform_sprite.animation),first_frame,second_frame)
	actor.clear_transform_visual()
	actor.hide(); anchor.show()
	var follower: TwilightFollowerMotion = FOLLOWER.new()
	for record: Dictionary in db["마법인형"]:
		var key := "doll:" + str(record.sourceId)
		title.text = key + " · " + str(record.name)
		actor.position = Vector2(670,420)
		follower.configure(record, record.image_path, anchor, doll, actor)
		for i: int in range(30): follower.update(.05,anchor,doll,actor)
		actor.position += Vector2(20,0)
		follower.update(.04,anchor,doll,actor)
		follower.motion.gait = 0.0
		follower.motion.apply_frames(doll)
		var first_frame: int = doll.frame
		var first: Image = await _pixels()
		follower.motion.gait = 2.0
		follower.motion.apply_frames(doll)
		var second_frame: int = doll.frame
		var second: Image = await _pixels()
		_record(key,first,second,str(doll.animation),first_frame,second_frame)
	anchor.hide(); relic.show()
	actor.position = Vector2(592,420)
	var relic_motion: TwilightRelicMotion = RELIC.new()
	for record: Dictionary in db["성물"]:
		var key := "relic:" + str(record.sourceId)
		title.text = key + " · " + str(record.name)
		relic_motion.configure(record,relic,actor,Color("ffd060"))
		for i: int in range(30): relic_motion.update(.05,relic,actor)
		relic_motion.motion.state_clock = 0.0
		relic_motion.motion.apply_frames(relic)
		var first_frame: int = _sampled_frame(relic_motion.motion.frame_source,"float",relic.texture)
		var first: Image = await _pixels()
		relic_motion.motion.state_clock = .25
		relic_motion.motion.apply_frames(relic)
		var second_frame: int = _sampled_frame(relic_motion.motion.frame_source,"float",relic.texture)
		var second: Image = await _pixels()
		_record(key,first,second,"float",first_frame,second_frame)
	_flush()
	_check(results.size() == 723, "full registered catalog rendered")
	var report := FileAccess.open(directory + "/render-results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_video_adapter_name(),"total":results.size(),
		"failures":failures,"records":results,"manual_art_review":false},"\t"))
	print("ALL_CATALOG_RENDER_", "OK" if failures.is_empty() else "FAILED",
		" count=",results.size()," report=",ProjectSettings.globalize_path(directory))
	actor.queue_free(); anchor.queue_free(); relic.queue_free(); title.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
