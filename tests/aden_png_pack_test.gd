extends SceneTree
## Loader contracts only; synthetic metadata is never original-art delivery.
const PACK = preload("res://scripts/maps/aden_png_pack.gd")
const REGISTRY = preload("res://scripts/maps/aden_remake_registry.gd")
const CHUNK = preload("res://scripts/maps/aden_png_chunk.gd")
const REVIEW = preload("res://scripts/maps/source_png_review_pack.gd")
var failures: Array[String] = []
var checks: int = 0
var field: RemakePlayableField

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("ADEN_PNG_PACK_FAIL ",label)

func save_manifest(value: Dictionary) -> void:
	var file := FileAccess.open("user://pack-contract/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(value));file.close()

func rejected(value: Dictionary, expected: String) -> void:
	save_manifest(value)
	var pack := PACK.new()
	check(not pack.configure("user://pack-contract",field) and pack.regions.is_empty() and pack.rejection == expected,expected)

func run() -> void:
	field = REGISTRY.load_field()
	check(field != null,"real source pack loaded")
	if field == null: finish();return
	DirAccess.make_dir_recursive_absolute("user://pack-contract")
	var row: Dictionary = {"id":"contract-fixture","status":"VERIFIED","collision_status":"VERIFIED","occlusion_status":"VERIFIED",
		"world_to_image":[1,0,0,0,1,0],"source_rect":[960,736,32,32],"image_origin":[0,0],
		"file":"missing.png","sha256":"0".repeat(64),"cuts":[],"control_points":[]}
	for source: Vector2i in [Vector2i(960,736),Vector2i(991,736),Vector2i(991,767),Vector2i(960,767),Vector2i(975,750)]:
		var p: Vector2 = field.cell_to_world(source)
		row.control_points.append({"status":"VERIFIED","world":[p.x,p.y],"image":[p.x,p.y]})
	var value: Dictionary = {"schema":1,"map_id":"aden_world","original_png_sha256":PACK.PNG_SHA,"source_grid_sha256":PACK.GRID_SHA,
		"source_definition_sha256":FileAccess.get_sha256(REGISTRY.ROOT+"definitions/aden_world.json"),"regions":[row]}
	var wrong: Dictionary = value.duplicate(true);wrong.original_png_sha256 = "0".repeat(64);rejected(wrong,"IDENTITY_MISMATCH")
	wrong = value.duplicate(true);wrong.regions[0].status = "REVIEW_REQUIRED";rejected(wrong,"REGION_NOT_VERIFIED")
	wrong = value.duplicate(true);wrong.regions[0].control_points[0].status = "CANDIDATE";rejected(wrong,"UNVERIFIED_CONTROL_POINT")
	wrong = value.duplicate(true);wrong.regions[0].control_points.pop_back();rejected(wrong,"INSUFFICIENT_CONTROL_POINTS")
	wrong = value.duplicate(true);wrong.regions[0].control_points[0].image[0] += 5;rejected(wrong,"CONTROL_POINT_RESIDUAL")
	wrong = value.duplicate(true);wrong.regions[0].world_to_image = [0,0,0,0,0,0];rejected(wrong,"SINGULAR_TRANSFORM")
	wrong = value.duplicate(true);wrong.regions[0].world_to_image[0] = "1";rejected(wrong,"SINGULAR_TRANSFORM")
	wrong = value.duplicate(true);wrong.regions[0].control_points[4] = wrong.regions[0].control_points[0].duplicate(true);rejected(wrong,"DUPLICATE_CONTROL_POINT")
	wrong = value.duplicate(true)
	for i: int in range(5):wrong.regions[0].control_points[i] = {"status":"VERIFIED","world":[i*48,0],"image":[i*48,0]}
	rejected(wrong,"DEGENERATE_SURVEY")
	wrong = value.duplicate(true);wrong.regions[0].source_rect[0] = -1;rejected(wrong,"REGION_OUTSIDE_SOURCE")
	wrong = value.duplicate(true);wrong.regions[0].source_rect[0] += .5;rejected(wrong,"FRACTIONAL_REGION")
	wrong = value.duplicate(true);wrong.regions[0].file = "../escape.png";rejected(wrong,"INVALID_LAYER_PATH")
	wrong = value.duplicate(true);wrong.regions[0].cuts = [17];rejected(wrong,"INVALID_CUT")
	rejected(value,"LAYER_HASH_MISMATCH")
	# A tiny synthetic texture tests the accepted mesh/cut path, not original
	# Aden imagery or a playable scene. No collision fixture is manufactured.
	var image := Image.create(256,256,false,Image.FORMAT_RGBA8)
	image.fill(Color(.2,.3,.4,1));image.save_png("user://pack-contract/fixture.png")
	var cut := Image.create(8,8,false,Image.FORMAT_RGBA8)
	cut.fill(Color(.2,.3,.4,1));cut.save_png("user://pack-contract/cut.png")
	row.file = "fixture.png";row.sha256 = FileAccess.get_sha256("user://pack-contract/fixture.png")
	row.world_to_image = [.125,0,-5088,0,.125,-2688]
	var transform: Transform2D = PACK.matrix(row.world_to_image)
	for point: Dictionary in row.control_points:
		var at: Vector2 = transform*Vector2(point.world[0],point.world[1])
		point.image = [at.x,at.y]
	var foot: Vector2 = field.cell_to_world(Vector2i(975,750))
	row.cuts = [{"id":"contract-cut","file":"cut.png","sha256":FileAccess.get_sha256("user://pack-contract/cut.png"),"image_origin":[8,8],"foot_world":[foot.x,foot.y]}]
	value.regions = [row];save_manifest(value)
	# A repeated layer path with a different digest must still fail even if
	# its dimensions were memoized earlier in the same manifest inspection.
	var inconsistent: Dictionary = value.duplicate(true)
	inconsistent.regions.append(row.duplicate(true))
	inconsistent.regions[1].cuts[0].sha256 = "0".repeat(64)
	rejected(inconsistent,"LAYER_HASH_MISMATCH")
	save_manifest(value)
	var valid := PACK.new()
	check(valid.configure("user://pack-contract",field),"accepted synthetic layer contract")
	check(valid.textures.is_empty(),"verified pack defers all GPU texture uploads until visible")
	check(not valid.region_for(Vector2i(30,23)).is_empty() and valid.region_for(Vector2i.ZERO).is_empty(),"region clips to reviewed source chunks")
	if not valid.regions.is_empty():
		var chunk := CHUNK.new();root.add_child(chunk);chunk.texture_cache = valid.textures
		chunk.build_png(field,Vector2i(30,23),valid,valid.regions[0])
		check(valid.textures.has("user://pack-contract/fixture.png") and valid.textures.has("user://pack-contract/cut.png"),"visible ground and foreground load on first use")
		check(chunk.get_child_count() == 2 and chunk.has_node("Ground") and chunk.y_sort_enabled,"ground and one foreground instance")
		var foreground := chunk.get_node_or_null("Foreground_contract-cut") as Sprite2D
		check(foreground != null and foreground.global_position.distance_to(foot)<.01,"foreground Y-sort origin uses world foot")
		if foreground != null:
			check((foreground.transform*foreground.offset).distance_to(transform.affine_inverse()*Vector2(8,8))<.01,"foreground image pixels preserve measured transform")
		chunk.free()
	# Candidate PNG packs must never replace an ordinary saved game's art by
	# installation alone, even if a manifest calls itself verified.
	DirAccess.make_dir_recursive_absolute("user://png-review-contract/aden_world")
	var candidate: Dictionary = {"schema":2,"map_id":"aden_world","png_sha256":PACK.PNG_SHA,"png_size":[15728,7987],
		"source_map_id":4,"source_grid_sha256":PACK.GRID_SHA,"status":"REVIEW_REQUIRED","regions":[{}]}
	for claimed_status: String in ["REVIEW_REQUIRED","VERIFIED"]:
		candidate.status = claimed_status
		var candidate_file := FileAccess.open("user://png-review-contract/aden_world/manifest.json",FileAccess.WRITE)
		candidate_file.store_string(JSON.stringify(candidate));candidate_file.close()
		var review := REVIEW.new()
		check(not review.configure("user://png-review-contract",field) and not review.review_active and review.rejection == "REVIEW_SESSION_REQUIRED","candidate cannot activate in ordinary gameplay "+claimed_status)
	field.close();finish()

func finish() -> void:
	print("ADEN_PNG_PACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_png_rendered":false}))
	quit(0 if failures.is_empty() else 1)
