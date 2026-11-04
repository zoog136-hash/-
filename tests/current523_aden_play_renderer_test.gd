extends SceneTree
## Small synthetic display/profile regressions, not native M behavior evidence.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const REVIEW = preload("res://scripts/maps/current523_aden_review.gd")
const COORDINATES = preload("res://scripts/maps/source_coordinates.gd")
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
var checks: int = 0
var failures: Array[String] = []

class FakeTiles extends RefCounted:
	var loads: Array[int] = []
	var problem: String = ""
	var supported: bool = true
	var image: Texture2D
	func _init() -> void:
		var pixels := Image.create_empty(384, 384, false, Image.FORMAT_RGBA8)
		pixels.fill(Color(1, 0, 0, 1))
		image = ImageTexture.create_from_image(pixels)
	func has_tile(_id: int) -> bool: return supported
	func texture_for(id: int) -> Texture2D:
		loads.append(id)
		return image
	func cache_size() -> int: return 1

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func synthetic_field() -> RefCounted:
	var value = FIELD.new()
	value.set_meta("source_map84", true)
	value.definition = {"map_id":"aden_world", "source_map_id":4, "source_sha256":PLAY.GRID_SHA256}
	value.data = {"map_id":"aden_world", "npc_spawn":[], "portal":[]}
	value.coordinates.configure([32448, 32064], [1856, 1536], {"basis_x":[24,-12], "basis_y":[24,12], "translation":[0,768]})
	value.runtime_record = {"source_map_id":4, "target_map_id":"aden_world", "chunks":[]}
	value.raw_grid.source_id = 4
	value.raw_grid.origin = PLAY.GRID_ORIGIN
	value.raw_grid.width = PLAY.GRID_SIZE.x
	value.raw_grid.height = PLAY.GRID_SIZE.y
	value.raw_grid.bytes.resize(PLAY.GRID_SIZE.x * PLAY.GRID_SIZE.y)
	value.raw_grid.bytes.fill(0)
	return value

func run() -> void:
	var coordinates = COORDINATES.new()
	check(coordinates.configure([32448,32064], [1856,1536], {"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]}), "existing display coordinates configure")
	for origin: Vector2i in [Vector2i(32448,32064), Vector2i(33408,32768), Vector2i(34048,33152)]:
		for half_x: int in [0,1,126,127,128,255]:
			for row: int in [0,63,64,255]:
				var local: Vector2i = REVIEW.project_half_storage(2 * (origin.x - coordinates.origin.x) + half_x, origin.y - coordinates.origin.y + row)
				var expected: Vector2 = Vector2(local) + coordinates.translation + Vector2(0,-12)
				check(PLAY.project_storage(coordinates, origin, half_x, row) == expected, "canonical existing half-tile parity")
	var base := Vector2i(33408,32768)
	check(PLAY.project_storage(coordinates, base, 128, 0) == PLAY.project_storage(coordinates, base + Vector2i(64,0), 0, 0), "horizontal chunk continuity")
	check(PLAY.project_storage(coordinates, base, 0, 64) == PLAY.project_storage(coordinates, base + Vector2i(0,64), 0, 0), "vertical chunk continuity")
	for value: Vector2 in [Vector2.ZERO, Vector2(-48,48), Vector2(.5,-12)]:
		check(PLAY.valid_delta(value), "bounded display offset accepted")
	for value: Vector2 in [Vector2(49,0), Vector2(0,-49), Vector2(INF,0), Vector2(NAN,0)]:
		check(not PLAY.valid_delta(value), "unsafe display offset rejected")
	check(not PLAY.profile_problem(null).is_empty(), "missing live field rejects")
	var field = synthetic_field()
	check(PLAY.profile_problem(field).contains("SHA256"), "claimed grid identity cannot replace actual byte hash")
	field.definition.source_map_id = 75
	check(not PLAY.profile_problem(field).is_empty(), "other source map rejects")
	field.definition.source_map_id = 4
	var renderer = PLAY.new()
	root.add_child(renderer)
	var actor := Node2D.new()
	root.add_child(actor)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	renderer._unhandled_input(click)
	check(renderer.field == null, "unconfigured candidate ignores inherited door input safely")
	check(not renderer.try_configure(field, actor, "/missing/raw", "/missing/tiles", Vector2.ZERO), "synthetic untrusted field cannot activate renderer")
	check(field.raw_grid.bytes.count(0) == field.raw_grid.bytes.size(), "profile rejection preserves synthetic navigation bytes")
	# Isolate coverage and cache behavior; production try_configure has no mock hook.
	renderer.field = field
	renderer.player = actor
	renderer.problem = ""
	renderer._legacy_origins = {PLAY.GRID_ORIGIN:true}
	renderer._overlap = {PLAY.GRID_ORIGIN:"synthetic"}
	var point: Vector2 = field.coordinates.cell_to_world(Vector2i(0,0))
	check(renderer.support_world_point(point), "shared artwork coverage admits point without reading movement flags")
	check(not renderer.support_world_point(field.coordinates.cell_to_world(Vector2i(64,0))), "unsupported artwork chunk rejects")
	renderer._visual_delta = Vector2(48,0)
	check(not renderer.support_world_point(point), "display offset participates in painted coverage boundary")
	renderer._visual_delta = Vector2.ZERO
	var lanes: Dictionary = {}
	renderer._append(lanes, PLAY.GRID_ORIGIN, 0, 0, 4294967295, -2)
	renderer._append(lanes, PLAY.GRID_ORIGIN, 1, 0, 2147483903, -2)
	check(lanes[-2][2] == 4294967295 and lanes[-2][5] == 2147483903, "raw packed references stay unsigned32")
	check(lanes[-2].size() == 6, "blocked synthetic navigation does not erase artwork")
	renderer._append(lanes, PLAY.GRID_ORIGIN, 128, 0, 0, -2)
	check(lanes[-2].size() == 6, "painting outside shared supplied coverage is excluded")
	var decorations: Dictionary={}
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,123,0)
	check(decorations.is_empty(),"legacy overlay retains its original intersection limit")
	field.set_meta("current523_generic_field",true)
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,123,0)
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,456,-1)
	renderer._append(decorations,PLAY.GRID_ORIGIN,128,0,789,-2)
	check(decorations[0][2]==123 and decorations[-1][2]==456 and not decorations.has(-2),"source packet decorations span absent floor chunks without inventing floor")
	check(field.raw_grid.bytes.count(0)==field.raw_grid.bytes.size(),"off-floor artwork never changes navigation bytes")
	field.remove_meta("current523_generic_field")
	var tiles := FakeTiles.new()
	renderer._tile_pack = tiles
	renderer._chunk_rects = {"synthetic":Rect2(-32,-32,64,64)}
	renderer._raw_chunks = {"synthetic":{-2:PackedInt64Array([0,0,2147483903,0,0,4294967295])}}
	check(renderer._build_frame(), "synthetic bounded frame builds")
	check(tiles.loads == [8388608], "upper24 bits are preserved; all-ones word is not an asset lookup")
	check(renderer._build_frame() and tiles.loads.size() == 1, "visible frame textures reused across refreshes")
	check(renderer.frame_metrics().uninterpreted_ffffffff_words == 1 and renderer.frame_metrics().draw_commands == 1, "sentinel and visible drawing metrics separate")
	var requested: Array[String] = []
	renderer.safe_return_requested.connect(func(reason: String) -> void: requested.append(reason))
	var too_many := PackedInt64Array()
	too_many.resize((PLAY.DRAW_COMMAND_LIMIT + 1) * 3)
	for index: int in range(0, too_many.size(), 3): too_many[index + 2] = 2147483903
	renderer._raw_chunks = {"synthetic":{-2:too_many}}
	renderer._configured = true
	check(not renderer._build_frame() and renderer.problem.contains("예산"), "draw budget failure does not keep a partial successful frame")
	await process_frame
	check(requested.size() == 1, "runtime rendering failure requests safe return once")
	check(not renderer._configured and renderer._frame_commands.is_empty(), "failed experimental display stops drawing")
	field.local_doors = {"synthetic":[Vector2i(0,0)]}
	field.local_door_states = {"synthetic":false}
	actor.global_position = point
	click.position = renderer.get_canvas_transform() * point
	renderer._unhandled_input(click)
	check(not field.local_door_states.synthetic, "failed candidate cannot toggle existing doors while return is pending")
	renderer.queue_free(); actor.queue_free()
	await process_frame
	print("CURRENT523_ADEN_PLAY_RENDERER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_DISPLAY_AND_GUARDS; NO_NATIVE_M_BEHAVIOR_CLAIM"}))
	quit(0 if failures.is_empty() else 1)
