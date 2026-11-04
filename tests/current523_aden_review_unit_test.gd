extends SceneTree
const REVIEW = preload("res://scripts/maps/current523_aden_review.gd")
const TILES = preload("res://scripts/maps/current523_tile_review_pack.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	check(REVIEW.candidate_origin("Map/Aden/800f7ff3e.s32") == null, "nonstandard source receives no candidate world origin")
	check(REVIEW.candidate_origin("Map/Aden/800a8000.s32") == Vector2i(33408, 32768), "explicitly named coordinate hypothesis remains separate")
	for y: int in [0, 1, 31, 63]:
		check(REVIEW.project_half_storage(2 * 33408 + 128, 32768 + y) == REVIEW.project_half_storage(2 * 33472, 32768 + y), "candidate adjacent storage edges align without modifying source coordinates")
	var layers: Dictionary = {}
	REVIEW._append(layers, Vector2i.ZERO, 0, 0, 4294967295, -2)
	check(layers[-2][2] == 4294967295, "raw0xffffffff survives the display command path")
	for subimage: int in [0, 15, 16, 255]:
		var region: Rect2 = TILES.source_rect(subimage)
		check(Rect2(0, 0, 384, 384).encloses(region) and region.size == Vector2(24, 24), "subimage address stays inside the candidate atlas")
	var image := Image.create(384, 384, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	var encoded: PackedByteArray = image.save_png_to_buffer()
	check(TILES.bounded_png_header(encoded), "bounded RGBA atlas header accepted")
	encoded[16] = 127
	check(not TILES.bounded_png_header(encoded), "huge PNG dimensions reject before image allocation")
	check(not TILES.bounded_png_header(PackedByteArray([137, 80, 78, 71])), "truncated PNG header rejects")
	var pack = TILES.new()
	check(TILES.supported_layout(JSON.parse_string('{"blocks":256,"atlas_size":[384,384]}')), "JSON numeric atlas dimensions accept without strict array-type mismatch")
	check(not TILES.supported_layout({"blocks":256, "atlas_size":[384.5,384]}), "fractional atlas dimensions reject")
	check(not pack.load_pack("/nonexistent/aden523-tile-review") and not pack.loaded, "missing tile pack refuses display")
	print("CURRENT523_ADEN_REVIEW_UNIT_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "M_projection_verified":false, "movement_verified":false}))
	quit(0 if failures.is_empty() else 1)
