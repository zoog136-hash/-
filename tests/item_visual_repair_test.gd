extends SceneTree

const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const FOREGROUND = preload("res://scripts/ui/item_icon_foreground.gd")
const EFFECT = preload("res://scripts/ui/item_visual.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ITEM_VISUAL_REPAIR_FAIL: "+message)

func fixture(background: Color) -> Image:
	var pixels := Image.create(16,16,false,Image.FORMAT_RGBA8)
	pixels.fill(background)
	for y: int in range(4,12):
		for x: int in range(4,12):
			pixels.set_pixel(x,y,Color(0.8,0.3,0.2,1.0))
	pixels.set_pixel(7,7,Color.BLACK)
	return pixels

func test_alpha() -> void:
	var source: Image = fixture(Color(0.04,0.04,0.04,1.0))
	var before: PackedByteArray = source.get_data()
	var result: Dictionary = FOREGROUND.extract(source)
	var pixels: Image = result.image
	check(bool(result.ready),"dark border can be separated")
	check(int(result.removed_pixels) == 192,"only 192 exterior background pixels removed")
	check(pixels.get_pixel(0,0).a == 0.0,"corner is transparent")
	check(pixels.get_pixel(7,7) == Color.BLACK,"enclosed black item detail remains opaque")
	check(source.get_data() == before,"input image remains byte-identical")
	check(pixels.get_size() == source.get_size(),"no item resizing or recropping")
	for y: int in range(4,12):
		for x: int in range(4,12):
			check(pixels.get_pixel(x,y) == source.get_pixel(x,y),"foreground RGBA unchanged %d:%d" % [x,y])
	var white: Image = fixture(Color.WHITE)
	white.set_pixel(7,7,Color.WHITE)
	var white_result: Dictionary = FOREGROUND.extract(white)
	check(bool(white_result.ready),"consistent white outer matte can be separated")
	check((white_result.image as Image).get_pixel(0,0).a == 0.0,"white matte removed")
	check((white_result.image as Image).get_pixel(7,7) == Color.WHITE,"enclosed white detail preserved")
	var transparent: Image = fixture(Color.TRANSPARENT)
	var alpha_result: Dictionary = FOREGROUND.extract(transparent)
	check(bool(alpha_result.ready) and int(alpha_result.removed_pixels) == 0,"existing alpha is not re-keyed")
	check((alpha_result.image as Image).get_data() == transparent.get_data(),"existing transparent art is unchanged")
	var complex: Image = fixture(Color(0.25,0.4,0.6,1.0))
	complex.set_pixel(0,0,Color.RED)
	complex.set_pixel(15,0,Color.GREEN)
	complex.set_pixel(0,15,Color.BLUE)
	complex.set_pixel(15,15,Color.YELLOW)
	var complex_result: Dictionary = FOREGROUND.extract(complex)
	check(not bool(complex_result.ready),"unrecognized opaque backgrounds require review")
	check((complex_result.image as Image).get_data() == complex.get_data(),"unrecognized art is not destroyed")
	var blank := Image.create(16,16,false,Image.FORMAT_RGBA8)
	blank.fill(Color.BLACK)
	check(not bool(FOREGROUND.extract(blank).ready),"a blank matte is not a extracted item")
	check(not bool(FOREGROUND.prepare(null).ready),"missing texture is safe")
	FOREGROUND.clear_cache()
	var original: Texture2D = ImageTexture.create_from_image(source)
	var first: Dictionary = FOREGROUND.prepare(original)
	var again: Dictionary = FOREGROUND.prepare(original)
	check(first.texture == again.texture,"display cutout is cached instead of rebuilt every frame")
	check(original.get_image().get_data() == before,"source Texture2D is never modified")
	for i: int in range(FOREGROUND.MAX_CACHE+2):
		FOREGROUND.prepare(ImageTexture.create_from_image(source))
	check(FOREGROUND.cache_size() == FOREGROUND.MAX_CACHE,"cutout cache is bounded")
	FOREGROUND.clear_cache()

func _run() -> void:
	test_alpha()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var first: Dictionary = catalog["아이템"][0]
	var pinned_before: String = JSON.stringify(first)
	var old_ui: String = "res://assets/ui/shield.png"
	var sentinel: String = "__item_visual_legacy_restore_fixture__"
	var links: Dictionary = {sentinel:old_ui}
	var record: Dictionary = {"name":sentinel,"slot":"armor","grade":"희귀"}
	var record_before: String = JSON.stringify(record)
	var restored: Dictionary = RESOLVER.describe(record,sentinel,links)
	check(restored.path == old_ui,"valid original UI index link restored")
	check(restored.route == "legacy_exact_name_index","restored route is explicit")
	check(restored.status == "bundled_ui_art","restored placeholder is not claimed as source-verified art")
	check(RESOLVER.texture(record,sentinel,links) == load(old_ui),"restored texture is the original resource")
	check(RESOLVER.describe({},sentinel,links).path == old_ui,"empty record plus explicit name restores old link")
	check(JSON.stringify(record) == record_before,"legacy physical record is not mutated")
	check(RESOLVER.describe(first,first.name,{first.name:old_ui}).path == first.image_path,"new pinned art outranks an old index link")
	check(RESOLVER.texture(first,first.name,{first.name:old_ui}) == load(first.image_path),"new source pixels are retained")
	check(JSON.stringify(first) == pinned_before,"catalog record is not mutated")
	var wrong: Dictionary = first.duplicate(true)
	wrong.name = sentinel
	wrong.image_path = old_ui
	check(RESOLVER.describe(wrong,sentinel,links).path == "","wrong name cannot recover a known ID through record or index")
	check(RESOLVER.describe({"sourceId":"unknown","name":sentinel},sentinel,links).path == "","unknown source ID cannot borrow a name-only image")
	check(RESOLVER.describe(record,sentinel,{sentinel:"res://assets/../private.png"}).path == "","path traversal remains rejected")
	check(RESOLVER.describe(record,sentinel,{sentinel:"user://foreign.png"}).path == "","external path remains rejected")
	var explicit: Dictionary = {"name":sentinel,"image_path":old_ui}
	check(RESOLVER.describe(explicit,sentinel).path == old_ui,"working per-record image still loads")
	# Exercise recovery when canonical art is absent without touching DB files.
	var saved_ids: Dictionary = RESOLVER._ids.duplicate()
	var saved_names: Dictionary = RESOLVER._names.duplicate(true)
	RESOLVER._ids["__restore_fixture__"] = {"sourceId":"__restore_fixture__","name":sentinel,"image_path":"res://assets/__absent_restore_fixture__.png"}
	RESOLVER._names[sentinel] = ["__restore_fixture__"]
	var owned: Dictionary = {"sourceId":"__restore_fixture__","name":sentinel,"image_path":old_ui,"instanceId":"physical-42"}
	var owned_before: String = JSON.stringify(owned)
	check(RESOLVER.describe(owned,sentinel).route == "legacy_record_path","missing canonical replacement recovers a working physical-record path")
	check(RESOLVER.texture(owned,sentinel) == load(old_ui),"physical-record recovery loads the actual old texture")
	check(JSON.stringify(owned) == owned_before,"physical ID and data survive recovery")
	RESOLVER._names[sentinel] = ["__restore_fixture__","another_id"]
	check(RESOLVER.describe(record,sentinel,links).path == "","ambiguous names still do not recover through a shared index")
	RESOLVER._ids = saved_ids
	RESOLVER._names = saved_names
	# Both safe and unsupported alpha use the real ItemVisual material path.
	var view := TextureRect.new()
	view.size = Vector2(64,64)
	view.texture = ImageTexture.create_from_image(fixture(Color.TRANSPARENT))
	root.add_child(view)
	var effect: Node = EFFECT.new()
	view.add_child(effect)
	effect.target = view
	effect.rank = 5
	effect.foreground_ready = true
	effect.refresh_visibility()
	check(view.material != null and float((view.material as ShaderMaterial).get_shader_parameter("rank")) == 5.0,"transparent item reaches turning shader")
	effect.foreground_ready = false
	effect.refresh_visibility()
	check(view.material != null and float((view.material as ShaderMaterial).get_shader_parameter("rank")) == 4.0,"unsupported opaque background never reaches turning shader")
	check(view.rotation == 0.0 and view.scale == Vector2.ONE,"slot transform remains fixed")
	view.queue_free()
	await process_frame
	# Audit real high-grade PNGs separately from synthetic correctness. Pending
	# masks are reported, never counted as completed foreground extraction.
	var audit: Dictionary = {"high_grade_rows":0,"ready":0,"removed":0,"review_required":[]}
	for item: Dictionary in catalog.get("아이템",[]):
		if str(item.get("grade","")) not in ["신화","유일"]: continue
		audit.high_grade_rows += 1
		var source_texture: Texture2D = RESOLVER.texture(item,item.name)
		var display: Dictionary = FOREGROUND.prepare(source_texture)
		if bool(display.ready):
			audit.ready += 1
			if int(display.removed_pixels) > 0: audit.removed += 1
		else:
			audit.review_required.append({"sourceId":item.get("sourceId",""),"name":item.name,"reason":display.reason})
		check(RESOLVER.describe(item,item.name).path == item.image_path,"real high-grade source link is preserved "+str(item.get("sourceId","")))
	check(RESOLVER.cache_size() <= RESOLVER.MAX_CACHE,"resolver cache remains bounded")
	print("ITEM_VISUAL_REPAIR_RESULT ",JSON.stringify({"checks":checks,"foreground_audit":audit,"failures":failures}))
	if failures.is_empty(): print("ITEM_VISUAL_REPAIR_OK")
	quit(0 if failures.is_empty() else 1)
