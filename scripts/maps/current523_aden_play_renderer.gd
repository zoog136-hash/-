extends "res://scripts/maps/source_map_runtime_renderer.gd"
## Stored-pixel display for source fields and the retained legacy overlay.
## The selected field owns movement; rendering never infers native collision.
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
signal safe_return_requested(reason: String)
## The actor stood on a blocked or unsupported cell and was moved back onto
## the map (nearest own-clear cell, else the owner's village fallback).
signal actor_position_recovered(detail: Dictionary)

const RAW = preload("res://scripts/maps/current523_aden_pack.gd")
const GENERIC_RAW = preload("res://scripts/maps/current523_source_pack.gd")
const GENERIC_TILES = preload("res://scripts/maps/current523_tile_pack.gd")
const TILES = preload("res://scripts/maps/current523_tile_review_pack.gd")
const REVIEW = preload("res://scripts/maps/current523_aden_review.gd")
const STATIC_SPR = preload("res://scripts/maps/current523_static_spr.gd")
const BANK_OBJECTS = preload("res://scripts/maps/current523_bank_objects.gd")
const USAGE=preload("res://scripts/maps/current523_map_usage.gd")
const GRID_SHA256: String = "30229ce7fd95656519ff73a47515ac2ac277983022ebc262b084c134a2b80d53"
const GRID_ORIGIN: Vector2i = Vector2i(32448, 32064)
const GRID_SIZE: Vector2i = Vector2i(1856, 1536)
const RAW_CHUNK_LIMIT: int = 48
const VISIBLE_CHUNK_LIMIT: int = 48
const VISIBLE_ATLAS_LIMIT: int = 256
const DRAW_COMMAND_LIMIT: int = 65536
const DELTA_LIMIT: float = 48.0
## Ground baking: the tile layers are drawn once per BLOCK x BLOCK world-pixel
## block into its own render target, and the screen draws the visible block
## images. Before, every refresh outside the built margin re-walked every
## record of every visible chunk (8,192 floor words each, plus covers and
## objects) and re-issued every 24 px tile draw (tens of thousands per frame
## build): the phone's map_renderer 130-150 ms/s and a stall per walk step.
## Each block holds every record whose 24 px rect meets it, in the original
## order (layer, then sorted member, then record), clipped to the block, so the
## block images side by side are the same picture as the direct layer pass.
const BLOCK: int = 512
const BLOCK_SHIFT: int = 9 # BLOCK == 1 << BLOCK_SHIFT
const TILE_PX: int = 24
## Baked blocks kept (1 MiB RGBA8 each, 32 MiB at most); a phone screen with
## the build margin uses ~12-20. Older blocks are freed and rebaked when seen
## again (523.637 ran with only 178 MB of device memory free, so this stays
## close to one screen and its margin).
const BLOCK_CACHE_LIMIT: int = 32
## New margin block images per refresh (blocks on screen always bake at once).
const MARGIN_BAKES_PER_REFRESH: int = 6
## Longest a new on-screen block waits for worker decodes before decoding the
## rest on the main thread (it shows nothing meanwhile). 250 ms was too short
## on the phone: after a teleport three blocks then decoded their atlases on
## the main thread in one frame (523.699: map.block_commands 2066 ms x3, a
## 2.1 s freeze). Workers finish well within this; it is only a safety net.
const ON_SCREEN_WAIT_MSEC: int = 3000
## On-screen blocks past the wait that may decode on the main thread in one
## refresh; the rest wait for the next refresh (0.05 s later).
const LATE_BAKES_PER_REFRESH: int = 1
## Decoded atlases kept for blocks still waiting to bake (~0.6 MB each).
const HELD_ATLAS_LIMIT: int = 128
## The built frame covers this much beyond the screen, so standing still or
## small moves reuse it instead of re-walking every visible chunk record.
const BUILD_MARGIN: float = 192.0
## Frame spread (user report 2026-11-20, phone recording: running diagonally
## into new ground stalled about every 0.25 s). A frame build that left margin
## blocks unbaked used to clear the built view, so every 0.25 s refresh
## re-walked the whole screen, re-requested every block's atlases and re-laid
## out the map objects until the last margin block was baked (Linux, 1.8x run
## into new ground: map.build_frame 22 times in 4 s). Now the built view stays
## and only the blocks still missing bake, a few per frame within this budget
## (on-screen blocks first). Measured on the device itself.
const PENDING_BAKE_BUDGET_USEC: int = 4000
## Margin blocks a frame build bakes itself stop at this much work; the rest
## join the pending blocks.
const BUILD_BAKE_BUDGET_USEC: int = 4000
## A pending block whose atlases are still decoding is asked again after this.
const PENDING_RETRY_MSEC: int = 50
## Name labels of NPCs and portals (within 1400 px) are refreshed when the
## actor moved this far since the last refresh, not on every 0.25 s tick.
const MARKER_REFRESH_DISTANCE: float = 96.0
## Position problems (scope / entry) the owner can repair by moving the actor.
const POSITION_SCOPE_PROBLEM: String = "원문 자체 통행의 지원 영역 밖이므로 복귀합니다."
const POSITION_ENTRY_PROBLEM: String = "기존 통행 API에서 현재 위치를 확인하지 못했습니다."
## Own search radius (source cells) for putting the actor back on the map.
const RECOVERY_RADIUS_CELLS: int = 24

class TileGround extends Node2D:
	var renderer: Node
	func _draw() -> void:
		if is_instance_valid(renderer): renderer.call("_draw_tiles", self)

var problem: String = ""
var include_objects: bool = true
var _raw_sources: RefCounted
var _tile_pack: RefCounted
var _visual_delta := Vector2.ZERO
var _tile_ground: Node2D
var _static_spr: Node2D
## Why the 523 bank could not draw this map's objects ("" when it does).
var map_objects_problem: String = ""
var _static_tails: Dictionary = {}
var _configured: bool = false
var _return_pending: bool = false
var _member_origins: Dictionary = {}
var _overlap: Dictionary = {}
var _legacy_origins: Dictionary = {}
var _chunk_rects: Dictionary = {}
var _raw_chunks: Dictionary = {}
var _raw_recent: Array[String] = []
var _frame_commands: Dictionary = {}
var _built_view := Rect2() # World rect the current frame commands cover.
var _frame_atlases: Dictionary = {}
## Block cell -> {viewport, canvas, commands {layer: PackedInt64Array},
## atlases {tile_id: Texture2D}, count (records owned), draws, raw_ff, unresolved}.
var _blocks: Dictionary = {}
var _block_recent: Array[Vector2i] = []
var _blocks_include_objects: bool = true
var _visible_blocks: Array[Vector2i] = []
## Blocks of the built view not baked yet (atlas decode pending, or past the
## build's bake budget), baked by _bake_pending within the frame budget.
var _pending_blocks: Array[Vector2i] = []
## Pending block cell -> earliest msec to ask its atlases again.
var _pending_retry: Dictionary = {}
## Pending block cell -> its atlas IDs (PackedInt32Array), see _pending_tiles_ready.
var _pending_tiles: Dictionary = {}
var _markers_at := Vector2.INF
var _collision_cell := Vector2i(-2147483648, -2147483648)
## On-screen block cell -> msec it started waiting for atlas decodes.
var _screen_wait: Dictionary = {}
## Chunk member -> block cell -> {layer: record indexes}; dropped with the chunk.
var _chunk_bins: Dictionary = {}
## Chunk member -> worker read job (see _prefetch_chunk).
var _chunk_jobs: Dictionary = {}
## S32 chunk reads in flight at once.
const MAX_CHUNK_JOBS: int = 4
var _metrics: Dictionary = {}
var _last_actor_cell := Vector2i(-2147483648, -2147483648)
var _refresh_clock: float = 0.0
var _scope_clipped_records: int = 0
var _off_floor_decoration_records: int = 0
var _draw_generation: int=0
var _usage_generation: int=-1
var _visible_members: Array[String]=[]
## The object layer and visible chunk list its records were last built from.
## A periodic rebuild (the screen left the built margin) with the same chunks
## hands the objects the same records: re-laying out every holder there was
## pure cost (map.object_refresh while walking). refresh_visible() and a new
## object layer still refresh.
var _objects_built_for: Array=[]
var _force_objects_refresh: bool=true
## Owner-supplied fallback point (village return) when no clear cell is near.
var recovery_fallback: Callable = Callable()
var position_recoveries: int = 0
var last_position_recovery: Dictionary = {}
## Tile references the installed pack does not resolve: drawn as holes and
## counted instead of closing the 523 session (logged once per tile).
var unresolved_tile_refs: int = 0
var _unresolved_logged: Dictionary = {}
var _unreadable_chunks: Dictionary = {}


static func valid_delta(value: Vector2) -> bool:
	return value.is_finite() and absf(value.x) <= DELTA_LIMIT and absf(value.y) <= DELTA_LIMIT


static func project_storage(coordinates: RefCounted, origin: Vector2i, half_x: int, row_y: int) -> Vector2:
	# This is the existing display convention, not proof of a native M foot point.
	return coordinates.half_tile_position(origin, half_x, row_y)


static func profile_problem(value: PlayableField) -> String:
	if value != null and bool(value.get_meta("current523_source_field",false)):
		return "" if bool(value.get("loaded")) else "M 원문 필드를 확인하지 못했습니다."
	if value == null or not value is RemakePlayableField or not bool(value.get_meta("source_map84", false)):
		return "기존 아덴 통행 필드가 필요합니다."
	if value.definition.get("map_id") != "aden_world" or value.definition.get("source_map_id") != 4 or value.definition.get("source_sha256") != GRID_SHA256:
		return "이 실험에서 지원하는 아덴 통행 프로필이 아닙니다."
	var coordinates: RefCounted = value.coordinates
	if not coordinates.valid or coordinates.origin != GRID_ORIGIN or coordinates.dimensions != GRID_SIZE or coordinates.basis_x != Vector2(24, -12) or coordinates.basis_y != Vector2(24, 12) or coordinates.translation != Vector2(0, 768):
		return "기존 아덴 좌표 표시 기준이 변경되었습니다."
	var runtime: Variant = value.get("runtime_record")
	if not runtime is Dictionary or runtime.get("source_map_id") != 4 or runtime.get("target_map_id") != "aden_world" or not runtime.get("chunks") is Array:
		return "기존 아덴 원본 영역 선언이 없습니다."
	var grid: Variant = value.get("raw_grid")
	if not grid is RefCounted or grid.get("source_id") != 4 or grid.get("origin") != GRID_ORIGIN or grid.get("width") != GRID_SIZE.x or grid.get("height") != GRID_SIZE.y:
		return "기존 아덴 통행 격자가 변경되었습니다."
	var bytes: Variant = grid.get("bytes")
	if not bytes is PackedByteArray or bytes.size() != GRID_SIZE.x * GRID_SIZE.y or RAW._hash(bytes) != GRID_SHA256:
		return "기존 아덴 통행 데이터의 SHA256이 다릅니다."
	return ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func try_configure(value: PlayableField, actor: Node2D, raw_root: String, tile_root: String, visual_delta: Vector2, tile_manifest_sha256: String = "", verified_catalog: RefCounted = null, verified_tiles: RefCounted = null) -> bool:
	if _configured:
		return false
	problem = ""
	failure = ""
	_return_pending = false
	var rejected: String = profile_problem(value)
	if not rejected.is_empty(): return _fail(rejected)
	if not is_instance_valid(actor) or not actor.is_inside_tree() or not actor.global_position.is_finite():
		return _fail("현재 플레이어 위치를 확인할 수 없습니다.")
	if not valid_delta(visual_delta): return _fail("표시 오프셋은 각 축 -48~48픽셀이어야 합니다.")
	var generic: bool=bool(value.get_meta("current523_generic_field",false))
	var originals: RefCounted
	var tiles: RefCounted
	if generic:
		if verified_catalog!=null:
			if verified_catalog.get_script()!=GENERIC_RAW or verified_catalog.catalog_directory()!=raw_root or verified_catalog.catalog_identity().get("manifest_sha256")!=str(value.get("catalog_sha256")): return _fail("표시 카탈로그의 원문 identity가 다릅니다.")
			originals=verified_catalog.fork_catalog()
			if not originals.select_asset(str(value.get("source_asset"))): return _fail(originals.problem)
		else:
			originals=GENERIC_RAW.new()
			if not originals.load_pack(raw_root,str(value.get("catalog_sha256")),str(value.get("source_asset"))): return _fail(originals.problem)
		if verified_tiles!=null:
			if verified_tiles.get_script()!=GENERIC_TILES or verified_tiles.verified_identity()!={"root":tile_root,"manifest_sha256":tile_manifest_sha256}: return _fail("표시 타일팩의 원문 identity가 다릅니다.")
			tiles=verified_tiles
		else:
			tiles=GENERIC_TILES.new()
			if not tiles.load_pack(tile_root,tile_manifest_sha256): return _fail(tiles.problem)
	else:
		originals=RAW.new()
		if not originals.load_pack(raw_root): return _fail(originals.problem)
		tiles=TILES.new()
		if not tiles.load_pack(tile_root): return _fail(tiles.problem)
	field = value
	source = value as OriginalPlayableField
	player = actor
	var source_owned: bool = bool(value.get_meta("current523_source_field",false))
	if source_owned:
		record = {"chunks":[]}
		for origin: Vector2i in value.source_chunk_origins().values():
			record.chunks.append({"world_bounds":[origin.x,origin.y,origin.x+63,origin.y+63]})
	else: record = value.get("runtime_record")
	_raw_sources = originals
	_tile_pack = tiles
	# Atlases are only read to bake ground blocks (see compress_for_gpu).
	if "compress_for_gpu" in tiles: tiles.set("compress_for_gpu", false)
	# Decoded atlases stay until the blocks waiting for them have baked.
	if "hold_published" in tiles: tiles.set("hold_published", true)
	# Draw lists on workers with the real pack (its tile table is read-only).
	block_jobs_enabled = "hold_published" in tiles
	_visual_delta = visual_delta
	_member_origins.clear(); _overlap.clear(); _legacy_origins.clear(); _chunk_rects.clear()
	_drop_chunk_jobs()
	_raw_chunks.clear(); _raw_recent.clear(); _frame_commands.clear(); _frame_atlases.clear()
	_chunk_bins.clear(); _clear_blocks()
	_scope_clipped_records = 0
	_off_floor_decoration_records = 0
	for row: Variant in record.chunks:
		var bounds: Variant = row.get("world_bounds") if row is Dictionary else null
		if not bounds is Array or bounds.size() != 4:
			return _fail("기존 아덴 그림 영역이 유효하지 않습니다.")
		for component: Variant in bounds:
			if not RAW._uint(component, 65535): return _fail("기존 아덴 그림 영역 좌표가 유효하지 않습니다.")
		var origin := Vector2i(int(bounds[0]), int(bounds[1]))
		if int(bounds[2]) - origin.x != 63 or int(bounds[3]) - origin.y != 63 or origin.x % 64 != 0 or origin.y % 64 != 0:
			return _fail("기존 아덴 그림 청크의 범위가 다릅니다.")
		_legacy_origins[origin] = true
	var members: Array = originals.supported_s32_members() if generic else originals.source_members()
	var source_origins: Dictionary=value.source_chunk_origins() if source_owned else {}
	for member: String in members:
		# Source navigation and pixels must consume the SAME explicit placement.
		# The legacy overlay still has no inferred member or native coordinate rule.
		var origin: Variant = source_origins.get(member) if source_owned else REVIEW.candidate_origin(member)
		if origin == null: continue
		_member_origins[member] = origin
		if _legacy_origins.has(origin):
			if _overlap.has(origin): return _fail("표시 원문의 배치가 기존 청크와 겹칩니다.")
			_overlap[origin] = member
			_chunk_rects[member] = _candidate_rect(origin)
	if _overlap.is_empty(): return _fail("기존 아덴 그림과 M 표시 후보의 공통 영역이 없습니다.")
	var scope: String = _scope_problem()
	if not scope.is_empty(): return _fail(scope)
	if not field.point_clear(player.global_position, 4.0):
		return _fail(POSITION_ENTRY_PROBLEM)
	_ensure_ground()
	var spr_options: Dictionary = STATIC_SPR.read_options()
	if spr_options.enabled:
		if not source_owned: return _fail("정적 SPR 자체 표시는 원문 통행 필드에서만 지원합니다.")
		_static_spr=STATIC_SPR.new()
		_static_spr.name="Current523SourceStaticSPR"
		if not _static_spr.configure(spr_options,field.coordinates):
			var detail: String=_static_spr.problem
			_static_spr.free();_static_spr=null
			return _fail(detail)
		add_child(_static_spr)
		_static_spr.position=_visual_delta
	elif source_owned and not BANK_OBJECTS.bank_selection().is_empty():
		# Without the separate static SPR selection, the installed 523 SP2 bank
		# draws the map's objects. A failure leaves the terrain shown as before.
		var objects: Node2D=BANK_OBJECTS.new()
		objects.name="Current523BankMapObjects"
		objects.sprite_load_budget_usec=objects.FRAME_SPRITE_LOAD_BUDGET_USEC
		if objects.configure(BANK_OBJECTS.bank_selection(),field.coordinates):
			_static_spr=objects
			add_child(_static_spr)
			_static_spr.position=_visual_delta
		else:
			map_objects_problem=objects.problem
			objects.free()
	_force_objects_refresh = true
	if not _build_frame(): return false
	_configured = true
	y_sort_enabled = true
	_last_actor_cell = field.world_to_cell(player.global_position)
	_refresh_markers()
	_refresh_collision()
	set_process(true)
	return true


func configure(value: PlayableField, actor: Node2D) -> void:
	# The controller supplies verified inputs through try_configure first.
	if not _configured or value != field or actor != player:
		_fail("M 표시 실험은 명시적인 팩과 통행 프로필 설정이 필요합니다.")
		return
	_built_view = Rect2()
	refresh_visible()


func _ensure_ground() -> void:
	if not is_instance_valid(_tile_ground):
		var node := TileGround.new()
		node.renderer = self
		node.name = "Current523ExperimentalTiles"
		node.z_index = -4096
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Block images hold colour already multiplied by alpha (mix blending
		# onto a transparent target), so they are laid down premultiplied.
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		node.material = blend
		add_child(node)
		_tile_ground = node
	_tile_ground.position = _visual_delta


func set_visual_delta(value: Vector2) -> bool:
	if not valid_delta(value): return false
	_visual_delta = value
	if is_instance_valid(_tile_ground): _tile_ground.position = value
	if is_instance_valid(_static_spr): _static_spr.position = value
	_built_view = Rect2()
	if _configured: refresh_visible()
	return _configured


func frame_metrics() -> Dictionary:
	var result: Dictionary=_metrics.duplicate(true)
	if is_instance_valid(_static_spr): result["static_spr"]=_static_spr.metrics()
	return result


func prepare_static_spr_options(value: Dictionary) -> Dictionary:
	# Runtime input for the existing settings button, not an inspection render.
	# Leave the current consumer and field untouched until settings are saved.
	if not _configured or field==null:return {"ok":false,"problem":"현재 지도 표시가 준비되지 않았습니다."}
	var checked: Dictionary=STATIC_SPR.validate(value)
	if checked.is_empty():return {"ok":false,"problem":"정적 SPR 설정을 읽을 수 없습니다."}
	var candidate: Node2D=null
	if checked.enabled:
		if not bool(field.get_meta("current523_source_field",false)):
			return {"ok":false,"problem":"정적 SPR은 원문 이동 필드에서 연결해 주세요."}
		candidate=STATIC_SPR.new()
		candidate.name="Current523SourceStaticSPR"
		if not candidate.configure(checked,field.coordinates):
			var detail: String=candidate.problem
			candidate.free()
			return {"ok":false,"problem":detail}
		candidate.position=_visual_delta
		var records: Dictionary=_visible_static_records()
		candidate.refresh(records.records,int(records.malformed))
	return {"ok":true,"candidate":candidate,"options":checked,"renderer_id":get_instance_id()}


func commit_static_spr_options(prepared: Dictionary) -> void:
	# Called synchronously by the owning controller after its atomic config save.
	# No field, movement, collision, portal, camera or map-time state is replaced.
	var prior: Node2D=_static_spr
	_static_spr=prepared.candidate
	if is_instance_valid(prior):
		prior.hide();prior.set_process(false)
		remove_child(prior);prior.queue_free()
	_metrics.erase("static_spr")
	if is_instance_valid(_static_spr):
		add_child(_static_spr)
		_static_spr.position=_visual_delta
		_static_spr.show();_static_spr.queue_redraw()
		_metrics["static_spr"]=_static_spr.metrics()


func _visible_static_records() -> Dictionary:
	var records: Array[Dictionary]=[]
	var malformed: int=0
	for member: String in _visible_members:
		var tail: Dictionary=_static_tails.get(member,{})
		if not tail.get("ok",false):malformed+=1;continue
		records.append_array(tail.records)
	return {"records":records,"malformed":malformed}


func _scope_problem() -> String:
	if field == null or not is_instance_valid(player): return "기존 아덴 필드가 없습니다."
	if bool(field.get_meta("current523_source_field",false)):
		if not bool(field.get("loaded")) or not str(field.get("problem")).is_empty(): return "M 원문 이동 필드에 오류가 있어 복귀합니다."
		if not actor_point_ok(player.global_position):
			# Runtime only (never during try_configure): move the actor back onto
			# the map rather than closing the session and dropping to the old map.
			if _recover_actor_position(): return ""
			return POSITION_SCOPE_PROBLEM
		return ""
	if field.definition.get("source_map_id") != 4 or field.definition.get("map_id") != "aden_world" or field.definition.get("source_sha256") != GRID_SHA256:
		return "기존 아덴 필드가 변경되어 표시 실험을 종료합니다."
	var grid: Variant = field.get("raw_grid")
	if not grid is RefCounted or not grid.get("bytes") is PackedByteArray or grid.bytes.size() != GRID_SIZE.x * GRID_SIZE.y:
		return "기존 아덴 통행 데이터가 더 이상 열려 있지 않습니다."
	if not player.global_position.is_finite(): return "플레이어 위치가 유효하지 않습니다."
	if not support_world_point(player.global_position):
		return "M 표시와 기존 아덴 통행의 공통 영역 밖이므로 기존 화면으로 돌아갑니다."
	return ""


## A point the 523 source session can keep the actor on.
func actor_point_ok(point: Vector2) -> bool:
	return field != null and point.is_finite() and support_world_point(point) and field.point_clear(point,4)


func _recover_actor_position() -> bool:
	if not _configured or not is_instance_valid(player) or field == null or not field.has_method("nearest_clear_point"): return false
	var from: Vector2 = player.global_position
	var found: Dictionary = field.call("nearest_clear_point",from,RECOVERY_RADIUS_CELLS,support_world_point) if from.is_finite() else {"ok":false,"reason":"non_finite_position"}
	var kind: String = "nearest_clear_cell"
	if not found.get("ok",false) and recovery_fallback.is_valid():
		var fallback: Variant = recovery_fallback.call()
		if fallback is Vector2 and actor_point_ok(fallback): found = {"ok":true,"position":fallback}; kind = "village_return"
	if not found.get("ok",false): return false
	player.global_position = found.position
	if player.has_method("clear_click_path"): player.call("clear_click_path")
	if player.has_method("set_touch_vector"): player.call("set_touch_vector",Vector2.ZERO)
	if player is CharacterBody2D: (player as CharacterBody2D).velocity = Vector2.ZERO
	var camera: Variant = player.get("camera")
	if camera is Camera2D: (camera as Camera2D).reset_smoothing(); (camera as Camera2D).force_update_scroll()
	_built_view = Rect2()
	position_recoveries += 1
	var from_cell: Vector2i = field.world_to_cell(from)+field.coordinates.origin if from.is_finite() else Vector2i(-1,-1)
	last_position_recovery = {"kind":kind,"from":[from.x,from.y],"from_source_cell":[from_cell.x,from_cell.y],"to":[found.position.x,found.position.y],"ring":int(found.get("ring",-1)),"count":position_recoveries}
	print("CURRENT523_POSITION_RECOVERED ", JSON.stringify(last_position_recovery))
	actor_position_recovered.emit(last_position_recovery.duplicate(true))
	return true


func support_world_point(point: Vector2) -> bool:
	if field == null or not point.is_finite(): return false
	var legacy: Vector2i = field.world_to_cell(point) + field.coordinates.origin
	var painted: Vector2i = field.coordinates.world_to_cell(point - _visual_delta) + field.coordinates.origin
	var legacy_origin := Vector2i(floori(float(legacy.x) / 64.0) * 64, floori(float(legacy.y) / 64.0) * 64)
	var painted_origin := Vector2i(floori(float(painted.x) / 64.0) * 64, floori(float(painted.y) / 64.0) * 64)
	return _legacy_origins.has(legacy_origin) and _overlap.has(painted_origin)


func _candidate_rect(origin: Vector2i) -> Rect2:
	var bounds := Rect2(project_storage(field.coordinates, origin, 0, 0), Vector2.ONE)
	for x: int in [0, 255]:
		for y: int in [0, 255]: bounds = bounds.expand(project_storage(field.coordinates, origin, x, y))
	return bounds.grow(24.0)


func _view_rect() -> Rect2:
	var viewport: Rect2 = player.get_viewport_rect()
	var inverse: Transform2D = player.get_canvas_transform().affine_inverse()
	var view := Rect2(inverse * viewport.position, Vector2.ZERO)
	for point: Vector2 in [Vector2(viewport.end.x, viewport.position.y), viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
		view = view.expand(inverse * point)
	view.position -= _visual_delta
	return view.grow(64.0)


func _read_chunk(member: String) -> Dictionary:
	if _raw_chunks.has(member):
		_raw_recent.erase(member); _raw_recent.append(member)
		return _raw_chunks[member]
	if _unreadable_chunks.has(member): return {}
	var job: Dictionary = _chunk_jobs.get(member, {})
	if not job.is_empty():
		# Already reading on a worker: wait for that one result.
		WorkerThreadPool.wait_for_task_completion(int(job.task))
		_chunk_jobs.erase(member)
		return _install_chunk(member, job)
	if not _raw_sources.has_method("read_member_job"):
		# Packs without a worker-safe reader (tests, Aden review pack).
		var decoded: Dictionary = _raw_sources.read_member(member)
		if decoded.is_empty():
			return _install_chunk(member, {"problem": str(_raw_sources.problem)})
		return _install_chunk(member, _decode_chunk(_chunk_params(member), decoded))
	job = _chunk_params(member)
	_chunk_job(job)
	return _install_chunk(member, job)

## Starts reading, checking and projecting `member` on a worker; true when it
## is already loaded. S32 reading, its SHA-256 checks and the record projection
## (~20 ms per chunk on a PC) used to run on the main thread while walking.
func _prefetch_chunk(member: String) -> bool:
	if _raw_chunks.has(member) or _unreadable_chunks.has(member): return true
	if _chunk_jobs.has(member) or _chunk_jobs.size() >= MAX_CHUNK_JOBS: return false
	if _raw_sources == null or not _raw_sources.has_method("read_member_job"): return true
	var job: Dictionary = _chunk_params(member)
	job["task"] = WorkerThreadPool.add_task(_chunk_job.bind(job), false, "S32 chunk read")
	_chunk_jobs[member] = job
	return false

## Installs finished worker reads (main thread).
func _pump_chunk_jobs() -> void:
	for member: String in _chunk_jobs.keys():
		var job: Dictionary = _chunk_jobs[member]
		if not WorkerThreadPool.is_task_completed(int(job.task)): continue
		WorkerThreadPool.wait_for_task_completion(int(job.task))
		_chunk_jobs.erase(member)
		_install_chunk(member, job)

func _drop_chunk_jobs() -> void:
	for job: Dictionary in _chunk_jobs.values(): WorkerThreadPool.wait_for_task_completion(int(job.task))
	_chunk_jobs.clear()

## Everything a chunk read needs, copied for a worker (the pack, field
## coordinates and overlap set are not changed while the map is configured).
func _chunk_params(member: String) -> Dictionary:
	var coordinates: RefCounted = field.coordinates
	return {"member": member, "sources": _raw_sources, "origin": _member_origins[member],
		"core_end": int(_raw_sources.source_metadata(member).get("core_end", 0)),
		"valid": bool(coordinates.valid), "basis_x": coordinates.basis_x, "basis_y": coordinates.basis_y,
		"shift": coordinates.translation, "grid_origin": coordinates.origin, "overlap": _overlap,
		"generic": bool(field.get_meta("current523_generic_field", false))}

static func _chunk_job(job: Dictionary) -> void:
	var decoded: Dictionary = (job.sources as Object).call("read_member_job", str(job.member))
	if decoded.has("_problem"):
		job["problem"] = str(decoded._problem)
		return
	job.merge(_decode_chunk(job, decoded), true)

## S32 sections -> static tail, projected lanes, block bins and clip counts.
static func _decode_chunk(params: Dictionary, decoded: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var tail: Dictionary = STATIC_SPR.parse_tail(decoded.sections.tail, int(params.core_end))
	if tail.ok:
		for row: Dictionary in tail.records:
			row["source_member"] = str(params.member)
			row["source_sha256"] = decoded.source_sha256
			row["source_bytes"] = decoded.source_bytes
	out["tail"] = tail
	# Records in file order (floor, covers, objects), then projected in one pass.
	var halves := PackedInt32Array(); var rows := PackedInt32Array(); var kinds := PackedInt32Array(); var refs := PackedInt64Array()
	var floor_bytes: PackedByteArray = decoded.sections.floor
	halves.resize(8192); rows.resize(8192); kinds.resize(8192); refs.resize(8192)
	for index: int in range(8192):
		halves[index] = index & 127; rows[index] = index >> 7; kinds[index] = -2; refs[index] = floor_bytes.decode_u32(index * 4)
	var covers: PackedByteArray = decoded.sections.covers
	for index: int in range(covers.decode_u16(0)):
		var offset: int = 2 + index * 6
		halves.append(covers[offset]); rows.append(covers[offset + 1]); kinds.append(-1); refs.append(covers.decode_u32(offset + 2))
	var objects: PackedByteArray = decoded.sections.objects
	var cursor: int = 4
	for _group: int in range(objects.decode_u32(0)):
		var count: int = objects.decode_u16(cursor + 2)
		cursor += 4
		for _part: int in range(count):
			halves.append(objects[cursor]); rows.append(objects[cursor + 1]); kinds.append(objects[cursor + 2]); refs.append(objects.decode_u32(cursor + 3))
			cursor += 7
	out["halves"] = halves; out["rows"] = rows; out["kinds"] = kinds; out["refs"] = refs
	if bool(params.valid):
		var projected: Dictionary = _project_static(params, halves, rows, kinds, refs)
		out["packed"] = projected.packed
		out["clipped"] = projected.clipped
		out["off_floor"] = projected.off_floor
		out["bins"] = _bin_chunk(projected.packed)
	return out

func _install_chunk(member: String, job: Dictionary) -> Dictionary:
	if job.has("problem") or not job.has("tail"):
		# One unreadable S32 member is a hole in the picture (its cells are
		# already non-walkable for the source field), not a session close.
		_unreadable_chunks[member] = str(job.get("problem", "unread"))
		print("CURRENT523_CHUNK_UNREADABLE ", JSON.stringify({"member":member,"problem":_unreadable_chunks[member]}))
		return {}
	# Retain the same currently loaded S32 tail even while SPR display is off.
	_static_tails[member] = job.tail
	var packed: Dictionary
	if job.has("packed"):
		packed = job.packed
		_scope_clipped_records += int(job.clipped)
		_off_floor_decoration_records += int(job.off_floor)
		_chunk_bins[member] = job.bins
	else:
		packed = _project_records(_member_origins[member], job.halves, job.rows, job.kinds, job.refs)
		_chunk_bins[member] = _bin_chunk(packed)
	_raw_chunks[member] = packed
	_raw_recent.append(member)
	while _raw_recent.size() > RAW_CHUNK_LIMIT:
		var oldest: String=_raw_recent.pop_front()
		_raw_chunks.erase(oldest);_static_tails.erase(oldest);_chunk_bins.erase(oldest)
	return packed


## The same result as _append for every record in order (scope check,
## off-floor decorations, projection, per-layer lanes), in one loop: the
## per-record path made five script calls per record (~20,000 per chunk) and
## was the largest map cost while moving (837,955 projections in 40 s).
func _project_records(origin: Vector2i, halves: PackedInt32Array, rows: PackedInt32Array, kinds: PackedInt32Array, refs: PackedInt64Array) -> Dictionary:
	var coordinates: RefCounted = field.coordinates
	if not bool(coordinates.valid):
		var slow: Dictionary = {}
		for index: int in halves.size(): _append(slow, origin, halves[index], rows[index], refs[index], kinds[index])
		var lanes: Dictionary = {}
		for layer: int in slow: lanes[layer] = PackedInt64Array(slow[layer])
		return lanes
	var params: Dictionary = {"origin": origin, "overlap": _overlap, "generic": bool(field.get_meta("current523_generic_field",false)),
		"basis_x": coordinates.basis_x, "basis_y": coordinates.basis_y, "shift": coordinates.translation, "grid_origin": coordinates.origin}
	var projected: Dictionary = _project_static(params, halves, rows, kinds, refs)
	_scope_clipped_records += int(projected.clipped)
	_off_floor_decoration_records += int(projected.off_floor)
	return projected.packed


## Worker-safe projection (valid coordinates only): lanes plus clip counts.
static func _project_static(params: Dictionary, halves: PackedInt32Array, rows: PackedInt32Array, kinds: PackedInt32Array, refs: PackedInt64Array) -> Dictionary:
	var lanes: Dictionary = {}
	var origin: Vector2i = params.origin
	var overlap: Dictionary = params.overlap
	var generic: bool = bool(params.generic)
	var bx: Vector2 = params.basis_x
	var by: Vector2 = params.basis_y
	var shift: Vector2 = params.shift
	var grid_origin: Vector2i = params.grid_origin
	var clipped: int = 0
	var off_floor: int = 0
	var odd: Vector2 = (bx + by) * 0.5
	var last_cover := Vector2i(-2147483647, -2147483647)
	var last_inside: bool = false
	for index: int in halves.size():
		var half_x: int = halves[index]
		var row_y: int = rows[index]
		var layer: int = kinds[index]
		var sx: int = origin.x + floori(float(half_x) / 2.0)
		var sy: int = origin.y + row_y
		var cover := Vector2i(floori(float(sx) / 64.0) * 64, floori(float(sy) / 64.0) * 64)
		if cover != last_cover:
			last_cover = cover
			last_inside = overlap.has(cover)
		if not last_inside:
			if layer == -2 or not generic:
				clipped += 1
				continue
			off_floor += 1
		# source_coordinates.half_tile_position -> to_world -> grid_to_world,
		# same operations in the same order (Vector2 float32 results).
		var gx: float = float(float(sx) - grid_origin.x + 0.5)
		var gy: float = float(float(sy) - grid_origin.y + 0.5)
		var world := Vector2(bx.x * gx + by.x * gy + shift.x, bx.y * gx + by.y * gy + shift.y)
		var point: Vector2 = world - by + float(half_x & 1) * odd
		# Arrays are shared references; a packed array taken from the
		# dictionary would be copied on every append.
		var lane: Variant = lanes.get(layer)
		if lane == null:
			lane = []
			lanes[layer] = lane
		var items: Array = lane
		items.append(int(point.x)); items.append(int(point.y)); items.append(refs[index])
	var packed: Dictionary = {}
	for layer: int in lanes: packed[layer] = PackedInt64Array(lanes[layer])
	return {"packed": packed, "clipped": clipped, "off_floor": off_floor}


func _append(layers: Dictionary, origin: Vector2i, half_x: int, row_y: int, raw_ref: int, layer: int) -> void:
	var source_point := Vector2i(origin.x + floori(float(half_x) / 2.0), origin.y + row_y)
	var coverage := Vector2i(floori(float(source_point.x) / 64.0) * 64, floori(float(source_point.y) / 64.0) * 64)
	if not _overlap.has(coverage):
		# A source packet's decorations can extend beyond its floor chunks.
		# Keep that original art at its own projected coordinate. It adds no
		# walkable floor. The old host-overlay intersection remains unchanged.
		if layer==-2 or not bool(field.get_meta("current523_generic_field",false)):
			_scope_clipped_records += 1
			return
		_off_floor_decoration_records += 1
	var point: Vector2 = project_storage(field.coordinates, origin, half_x, row_y)
	if not layers.has(layer): layers[layer] = []
	var lane: Array = layers[layer]
	lane.append(int(point.x)); lane.append(int(point.y)); lane.append(raw_ref)


## Record positions of one chunk by the blocks their 24 px rect meets:
## block cell -> {layer: PackedInt32Array(record index)}.
static func _bin_chunk(packed: Dictionary) -> Dictionary:
	var bins: Dictionary = {}
	for layer: int in packed:
		var records: PackedInt64Array = packed[layer]
		if records.is_empty(): continue
		# Shifts floor-divide negative coordinates too. Adjacent records
		# often belong to the same 512 px block.
		var lanes: Dictionary = {}
		var previous_cell := Vector2i(records[0] >> BLOCK_SHIFT, records[1] >> BLOCK_SHIFT)
		var lane: Array[int] = _bin_lane(lanes, previous_cell)
		for index: int in range(0, records.size(), 3):
			var x: int = records[index]
			var y: int = records[index + 1]
			var x0: int = x >> BLOCK_SHIFT
			var y0: int = y >> BLOCK_SHIFT
			var x1: int = (x + TILE_PX - 1) >> BLOCK_SHIFT
			var y1: int = (y + TILE_PX - 1) >> BLOCK_SHIFT
			var cell := Vector2i(x0, y0)
			if cell != previous_cell:
				lane = _bin_lane(lanes, cell)
				previous_cell = cell
			lane.append(index)
			if x1 != x0 or y1 != y0:
				for bx: int in range(x0, x1 + 1):
					for by: int in range(y0, y1 + 1):
						if bx == x0 and by == y0: continue
						_bin_lane(lanes, Vector2i(bx, by)).append(index)
		for cell: Vector2i in lanes:
			if not bins.has(cell): bins[cell] = {}
			(bins[cell] as Dictionary)[layer] = PackedInt32Array(lanes[cell])
	return bins


## Avoid copying the packed buffer on each append while it is stored in the
## dictionary. Pack each completed lane once before publishing the chunk.
static func _bin_lane(lanes: Dictionary, cell: Vector2i) -> Array[int]:
	if not lanes.has(cell):
		var lane: Array[int] = []
		lanes[cell] = lane
	return lanes[cell]


static func _block_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * BLOCK), Vector2(BLOCK, BLOCK))


## Draw records of one block (all layers, original order) or a problem text.
## A block always takes the chunks near it (not the screen's chunk set at bake
## time), so the cached image does not depend on where the player came from.
func _block_commands(cell: Vector2i) -> Dictionary:
	var rect: Rect2 = _block_rect(cell)
	var near: Rect2 = rect.grow(BUILD_MARGIN)
	var members: Array[String] = []
	for member: String in _chunk_rects:
		if (_chunk_rects[member] as Rect2).intersects(near): members.append(member)
	members.sort()
	var by_layer: Dictionary = {}
	var atlases: Dictionary = {}
	# Validity is fixed for this synchronous build. Retry failed texture
	# loads as before, and revalidate all references on the next build.
	var valid_refs: Dictionary = {}
	var has_subimage: bool = _tile_pack.has_method("has_subimage")
	var draws: int = 0
	# Metrics count a record once, in the block holding its top-left corner.
	var count: int = 0
	var raw_ff: int = 0
	var unresolved: int = 0
	for member: String in members:
		var layers: Dictionary = _read_chunk(member)
		if not problem.is_empty(): return {"problem": problem}
		if not _chunk_bins.has(member): _chunk_bins[member] = _bin_chunk(layers)
		var bins: Dictionary = (_chunk_bins[member] as Dictionary).get(cell, {})
		for layer: int in bins:
			if not include_objects and layer >= 0: continue
			var records: PackedInt64Array = layers[layer]
			for index: int in (bins[layer] as PackedInt32Array):
				var ref: int = records[index + 2]
				var owned: bool = floori(float(records[index]) / BLOCK) == cell.x and floori(float(records[index + 1]) / BLOCK) == cell.y
				if ref == 4294967295:
					if owned: raw_ff += 1
					continue
				var tile_id: int = ref >> 8
				if not valid_refs.has(ref):
					var valid: bool = _tile_pack.has_tile(tile_id)
					if not valid:
						_unresolved_tile(tile_id, "해결되지 않은 M 타일 원문: " + str(tile_id))
					elif has_subimage and not _tile_pack.call("has_subimage", tile_id, ref & 255):
						_unresolved_tile(tile_id, "원문에 없는 하위 타일 번호: %d/%d" % [tile_id, ref & 255])
						valid = false
					valid_refs[ref] = valid
				if not valid_refs[ref]:
					unresolved += int(owned)
					continue
				if draws >= DRAW_COMMAND_LIMIT or (not atlases.has(tile_id) and atlases.size() >= VISIBLE_ATLAS_LIMIT):
					return {"problem": "M 표시 실험의 타일 또는 아틀라스 예산을 초과했습니다."}
				if not atlases.has(tile_id):
					var texture: Texture2D = _frame_atlases.get(tile_id)
					if texture == null:
						var atlas_started: int = FRAME_HITCH.now()
						texture = _tile_pack.texture_for(tile_id)
						FRAME_HITCH.detail("map.block_atlas_acquire", atlas_started)
					if texture == null: _unresolved_tile(tile_id, "M 타일 아틀라스를 읽지 못함: %d %s" % [tile_id, str(_tile_pack.problem)]); unresolved += int(owned); continue
					atlases[tile_id] = texture
				var lane: Variant = by_layer.get(layer)
				if lane == null:
					lane = []
					by_layer[layer] = lane
				var target: Array = lane
				target.append(records[index])
				target.append(records[index + 1])
				target.append(ref)
				draws += 1
				count += int(owned)
	var commands: Dictionary = {}
	for layer: int in by_layer: commands[layer] = PackedInt64Array(by_layer[layer])
	return {"commands": commands, "atlases": atlases, "count": count, "draws": draws, "raw_ff": raw_ff, "unresolved": unresolved}


## Block draw lists built on worker threads (523.704: map.block_commands
## ~106 ms/s on the phone while walking: one GDScript pass over every record
## of a block). The pass only reads installed chunk lanes/bins and the tile
## pack's immutable tile table; atlases are taken on the main thread.
const MAX_BLOCK_JOBS: int = 4
var block_jobs_enabled: bool = false
var _block_jobs: Dictionary = {}

## Starts the worker pass for `cell` when its chunks are installed.
## On-screen blocks start regardless of MAX_BLOCK_JOBS (it bounds margin work).
func _start_block_job(cell: Vector2i, on_screen: bool) -> bool:
	if _block_jobs.has(cell): return true
	if not on_screen and _block_jobs.size() >= MAX_BLOCK_JOBS: return false
	var members: Array[String] = _block_members(cell)
	var inputs: Array = []
	for member: String in members:
		if not _raw_chunks.has(member): return false
		var layers: Dictionary = _raw_chunks[member]
		if not _chunk_bins.has(member): _chunk_bins[member] = _bin_chunk(layers)
		inputs.append([layers, (_chunk_bins[member] as Dictionary).get(cell, {})])
	var job: Dictionary = {"cell": cell, "inputs": inputs, "include_objects": include_objects, "tiles": _tile_pack,
		"has_subimage": _tile_pack.has_method("has_subimage")}
	job["task"] = WorkerThreadPool.add_task(_block_job.bind(job), false, "Current523 block draw list")
	_block_jobs[cell] = job
	return true

## Worker: _block_commands without the atlas lookups and logging.
static func _block_job(job: Dictionary) -> void:
	var cell: Vector2i = job.cell
	var tiles: Object = job.tiles
	var has_subimage: bool = job.has_subimage
	var by_layer: Dictionary = {}
	var tile_ids: Dictionary = {}
	var valid_refs: Dictionary = {}
	var invalid: Array = []
	var draws: int = 0
	var count: int = 0
	var raw_ff: int = 0
	var unresolved: int = 0
	for input: Array in job.inputs:
		var layers: Dictionary = input[0]
		var bins: Dictionary = input[1]
		for layer: int in bins:
			if not job.include_objects and layer >= 0: continue
			var records: PackedInt64Array = layers[layer]
			for index: int in (bins[layer] as PackedInt32Array):
				var ref: int = records[index + 2]
				var owned: bool = floori(float(records[index]) / BLOCK) == cell.x and floori(float(records[index + 1]) / BLOCK) == cell.y
				if ref == 4294967295:
					if owned: raw_ff += 1
					continue
				var tile_id: int = ref >> 8
				if not valid_refs.has(ref):
					var valid: bool = tiles.call("has_tile", tile_id)
					if not valid:
						invalid.append([tile_id, "해결되지 않은 M 타일 원문: " + str(tile_id)])
					elif has_subimage and not tiles.call("has_subimage", tile_id, ref & 255):
						invalid.append([tile_id, "원문에 없는 하위 타일 번호: %d/%d" % [tile_id, ref & 255]])
						valid = false
					valid_refs[ref] = valid
				if not valid_refs[ref]:
					unresolved += int(owned)
					continue
				if draws >= DRAW_COMMAND_LIMIT or (not tile_ids.has(tile_id) and tile_ids.size() >= VISIBLE_ATLAS_LIMIT):
					job["problem"] = "M 표시 실험의 타일 또는 아틀라스 예산을 초과했습니다."
					return
				tile_ids[tile_id] = true
				var lane: Variant = by_layer.get(layer)
				if lane == null:
					lane = []
					by_layer[layer] = lane
				var target: Array = lane
				target.append(records[index])
				target.append(records[index + 1])
				target.append(ref)
				draws += 1
				count += int(owned)
	var commands: Dictionary = {}
	for layer: int in by_layer: commands[layer] = PackedInt64Array(by_layer[layer])
	job["result"] = {"commands": commands, "tile_ids": tile_ids.keys(), "invalid": invalid, "count": count, "draws": draws, "raw_ff": raw_ff, "unresolved": unresolved}

## Chunks whose records may draw into `cell`, sorted.
func _block_members(cell: Vector2i) -> Array[String]:
	var near: Rect2 = _block_rect(cell).grow(BUILD_MARGIN)
	var members: Array[String] = []
	for member: String in _chunk_rects:
		if (_chunk_rects[member] as Rect2).intersects(near): members.append(member)
	members.sort()
	return members

## Main thread: a finished job -> the dictionary _block_commands returns,
## or {} when it is not finished (or an atlas could not be taken).
func _take_block_job(cell: Vector2i) -> Dictionary:
	var job: Dictionary = _block_jobs.get(cell, {})
	if job.is_empty() or not WorkerThreadPool.is_task_completed(int(job.task)): return {}
	WorkerThreadPool.wait_for_task_completion(int(job.task))
	_block_jobs.erase(cell)
	if bool(job.include_objects) != include_objects: return {}
	if job.has("problem"): return {"problem": job.problem}
	var result: Dictionary = job.result
	for entry: Array in result.invalid: _unresolved_tile(int(entry[0]), str(entry[1]))
	var atlases: Dictionary = {}
	for tile_id: int in result.tile_ids:
		var texture: Texture2D = _frame_atlases.get(tile_id)
		if texture == null:
			var atlas_started: int = FRAME_HITCH.now()
			texture = _tile_pack.texture_for(tile_id)
			FRAME_HITCH.detail("map.block_atlas_acquire", atlas_started)
		# A missing atlas: the synchronous pass skips its records and logs it.
		if texture == null: return {"sync": true}
		atlases[tile_id] = texture
	FRAME_HITCH.count("map.block_commands_worker")
	return {"commands": result.commands, "atlases": atlases, "count": result.count, "draws": result.draws, "raw_ff": result.raw_ff, "unresolved": result.unresolved}

## Both fresh and pending blocks consume completed jobs without waiting.
## A late or unavailable atlas keeps the existing synchronous fallback.
func _ready_block_commands(cell: Vector2i, on_screen: bool, force_sync: bool) -> Dictionary:
	var built: Dictionary = {}
	if _block_jobs.has(cell) or (block_jobs_enabled and not force_sync and not _block_members(cell).is_empty()):
		built = _take_block_job(cell)
		if built.is_empty():
			_start_block_job(cell, on_screen)
			return {}
	if built.is_empty() or built.has("sync"):
		var started: int = FRAME_HITCH.now()
		built = _block_commands(cell)
		FRAME_HITCH.detail("map.block_commands", started)
	return built


func _drop_block_jobs() -> void:
	for cell: Vector2i in _block_jobs: WorkerThreadPool.wait_for_task_completion(int((_block_jobs[cell] as Dictionary).task))
	_block_jobs.clear()


## Asks the tile pack to decode, on workers, every atlas the block draws;
## true when all of them are ready (or the pack decodes only on demand).
## `collected` (optional) receives {"tiles": the block's atlas IDs,
## "complete": every chunk near it was read}, so a pending block can later ask
## only those atlases again instead of walking its records.
func _request_block_tiles(cell: Vector2i, collected: Variant = null) -> bool:
	if not _tile_pack.has_method("prefetch"): return true
	var near: Rect2 = _block_rect(cell).grow(BUILD_MARGIN)
	var ready: bool = true
	var asked: Dictionary = {}
	var complete: bool = true
	for member: String in _chunk_rects:
		if not (_chunk_rects[member] as Rect2).intersects(near): continue
		# A chunk not read yet is read on a worker; the block waits for it.
		if not _prefetch_chunk(member):
			ready = false
			complete = false
			continue
		var layers: Dictionary = _read_chunk(member)
		if layers.is_empty(): continue
		if not _chunk_bins.has(member): _chunk_bins[member] = _bin_chunk(layers)
		var bins: Dictionary = (_chunk_bins[member] as Dictionary).get(cell, {})
		for layer: int in bins:
			if not include_objects and layer >= 0: continue
			var records: PackedInt64Array = layers[layer]
			for index: int in (bins[layer] as PackedInt32Array):
				var ref: int = records[index + 2]
				if ref == 4294967295: continue
				var tile_id: int = ref >> 8
				if asked.has(tile_id): continue
				asked[tile_id] = true
				if not _tile_pack.has_tile(tile_id): continue
				if not _tile_pack.call("prefetch", tile_id): ready = false
	if collected is Dictionary:
		var tiles := PackedInt32Array()
		for tile_id: int in asked:
			if _tile_pack.has_tile(tile_id): tiles.append(tile_id)
		(collected as Dictionary)["tiles"] = tiles
		(collected as Dictionary)["complete"] = complete
	return ready


## A pending block's readiness: its recorded atlas IDs only, once every chunk
## near it was read; else the full record walk (which records them).
func _pending_tiles_ready(cell: Vector2i) -> bool:
	if not _tile_pack.has_method("prefetch"): return true
	var tiles: Variant = _pending_tiles.get(cell)
	if tiles is PackedInt32Array:
		for tile_id: int in (tiles as PackedInt32Array):
			if not _tile_pack.call("prefetch", tile_id): return false
		return true
	var collected: Dictionary = {}
	var ready: bool = _request_block_tiles(cell, collected)
	if bool(collected.get("complete", false)): _pending_tiles[cell] = collected.tiles
	return ready


## One block's render target, drawn once (UPDATE_ONCE) from its commands.
func _bake_block(cell: Vector2i, built: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "Current523GroundBlock_%d_%d" % [cell.x, cell.y]
	viewport.size = Vector2i(BLOCK, BLOCK)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Node2D.new()
	canvas.name = "Tiles"
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var block: Dictionary = {"viewport": viewport, "commands": built.commands, "atlases": built.atlases, "atlas_ids": (built.atlases as Dictionary).keys(),
		"count": int(built.count), "draws": int(built.draws), "raw_ff": int(built.raw_ff), "unresolved": int(built.unresolved)}
	canvas.draw.connect(_draw_block.bind(canvas, cell, block))
	viewport.add_child(canvas)
	add_child(viewport)
	FRAME_HITCH.count("map.block_baked")
	# After the frame that drew it the block is only its image: let go of the
	# atlases (the tile cache may free them) and the drawing node.
	# One connection for all blocks baked this frame (bound callables of the
	# same method count as one connection).
	_unreleased.append([block, canvas])
	if not RenderingServer.frame_post_draw.is_connected(_release_baked):
		RenderingServer.frame_post_draw.connect(_release_baked, CONNECT_ONE_SHOT)
	return block


var _unreleased: Array = [] # [block, canvas] drawn in the coming frame

func _release_baked() -> void:
	for pair: Array in _unreleased:
		(pair[0] as Dictionary).erase("atlases")
		if is_instance_valid(pair[1]): (pair[1] as Node).queue_free()
	_unreleased.clear()


func _draw_block(canvas: Node2D, cell: Vector2i, block: Dictionary) -> void:
	var origin := Vector2(cell * BLOCK)
	var commands: Dictionary = block.commands
	var layers: Array = commands.keys()
	layers.sort()
	var atlases: Dictionary = block.get("atlases", {})
	if atlases.is_empty(): return
	for layer: int in layers:
		var lane: PackedInt64Array = commands[layer]
		for index: int in range(0, lane.size(), 3):
			var ref: int = lane[index + 2]
			canvas.draw_texture_rect_region(atlases[ref >> 8], Rect2(Vector2(lane[index], lane[index + 1]) - origin, Vector2(TILE_PX, TILE_PX)), TILES.source_rect(ref & 255))


## ref -> tile corners (x, y, ...) of one block's draw commands.
static func _usage_pending(commands: Dictionary) -> Dictionary:
	var lanes: Dictionary = {}
	for layer: int in commands:
		var lane: PackedInt64Array = commands[layer]
		for index: int in range(0, lane.size(), 3):
			var ref: int = lane[index + 2]
			var corners: Variant = lanes.get(ref)
			if corners == null:
				corners = []
				lanes[ref] = corners
			(corners as Array).append(lane[index]); (corners as Array).append(lane[index + 1])
	var pending: Dictionary = {}
	for ref: int in lanes: pending[ref] = PackedInt64Array(lanes[ref])
	return pending


func _free_block(cell: Vector2i) -> void:
	var block: Dictionary = _blocks.get(cell, {})
	_blocks.erase(cell)
	_block_recent.erase(cell)
	var viewport: Variant = block.get("viewport")
	if is_instance_valid(viewport): (viewport as Node).queue_free()


func _clear_blocks() -> void:
	_drop_block_jobs()
	for cell: Vector2i in _blocks.keys(): _free_block(cell)
	_block_recent.clear()
	_visible_blocks.clear()
	_screen_wait.clear()
	_pending_blocks.clear()
	_pending_retry.clear()
	_pending_tiles.clear()


func _build_frame() -> bool:
	var view: Rect2 = _view_rect().grow(BUILD_MARGIN)
	for cell: Vector2i in _block_jobs.keys():
		if _view_has_cell(view, cell): continue
		var task: int = int(_block_jobs[cell].task)
		if not WorkerThreadPool.is_task_completed(task): continue
		WorkerThreadPool.wait_for_task_completion(task)
		_block_jobs.erase(cell)
	var visible: Array[String] = []
	for member: String in _chunk_rects:
		if (_chunk_rects[member] as Rect2).intersects(view): visible.append(member)
	if visible.is_empty(): return _fail("현재 화면에 표시할 공통 원문 영역이 없습니다.")
	if visible.size() > VISIBLE_CHUNK_LIMIT: return _fail("M 표시 실험의 동시 청크 예산을 초과했습니다.")
	visible.sort()
	if _blocks_include_objects != include_objects:
		_clear_blocks()
		_blocks_include_objects = include_objects
	var screen: Rect2 = _view_rect()
	var first := Vector2i(floori(view.position.x / BLOCK), floori(view.position.y / BLOCK))
	var last := Vector2i(floori(view.end.x / BLOCK), floori(view.end.y / BLOCK))
	var cells: Array[Vector2i] = []
	var margin_bakes: int = 0
	var screen_ready: Dictionary = {}
	var screen_waiting: bool = false
	var late_bakes: int = 0
	var now_msec: int = Time.get_ticks_msec()
	var build_started: int = Time.get_ticks_usec()
	var pending: Array[Vector2i] = []
	for bx: int in range(first.x, last.x + 1):
		for by: int in range(first.y, last.y + 1):
			var wanted := Vector2i(bx, by)
			if not _blocks.has(wanted) and _block_rect(wanted).intersects(screen): screen_ready[wanted] = _request_block_tiles(wanted)
	var draws: int = 0
	var fresh_atlases: Dictionary = {}
	var partial: bool = false
	var count: int = 0
	var raw_ff: int = 0
	var unresolved: int = 0
	var atlases: Dictionary = {}
	for bx: int in range(first.x, last.x + 1):
		for by: int in range(first.y, last.y + 1):
			var cell := Vector2i(bx, by)
			if not _blocks.has(cell):
				# Blocks on screen bake now (their atlases were requested above
				# and decode in parallel); margin blocks bake a few per refresh,
				# once every atlas they use has decoded on a worker.
				var on_screen: bool = _block_rect(cell).intersects(screen)
				if not on_screen and (margin_bakes >= MARGIN_BAKES_PER_REFRESH or Time.get_ticks_usec() - build_started >= BUILD_BAKE_BUDGET_USEC or not _request_block_tiles(cell)):
					partial = true
					pending.append(cell)
					continue
				# A new block on screen waits up to ON_SCREEN_WAIT_MSEC for its
				# atlases to decode on workers instead of decoding them here (on
				# the phone ~60 ms each, several per teleport or fast walk).
				if on_screen and not bool(screen_ready.get(cell, true)):
					var since: int = int(_screen_wait.get(cell, now_msec))
					_screen_wait[cell] = since
					if now_msec - since < ON_SCREEN_WAIT_MSEC or late_bakes >= LATE_BAKES_PER_REFRESH:
						partial = true
						screen_waiting = true
						pending.push_front(cell)
						continue
					late_bakes += 1
				_screen_wait.erase(cell)
				var built: Dictionary = _ready_block_commands(cell, on_screen, on_screen and not bool(screen_ready.get(cell, true)))
				if built.is_empty():
					partial = true
					if on_screen: screen_waiting = true
					pending.append(cell)
					continue
				if built.has("problem"):
					if problem.is_empty(): return _fail(str(built.problem))
					return false
				if not on_screen: margin_bakes += 1
				_blocks[cell] = _bake_block(cell, built)
			_block_recent.erase(cell); _block_recent.append(cell)
			var block: Dictionary = _blocks[cell]
			cells.append(cell)
			count += int(block.count)
			draws += int(block.draws)
			raw_ff += int(block.raw_ff)
			unresolved += int(block.unresolved)
			for tile_id: int in block.atlas_ids: atlases[tile_id] = true
			for tile_id: int in block.get("atlases", {}): fresh_atlases[tile_id] = block.atlases[tile_id]
	if draws == 0 and unresolved == 0 and not screen_waiting: return _fail("현재 화면의 M 원문 타일을 표시하지 못했습니다.")
	# Blocks still missing bake a few per frame (_bake_pending); the frame
	# itself stays built for this view.
	_pending_blocks = pending
	for cell: Vector2i in _pending_retry.keys():
		if not pending.has(cell): _pending_retry.erase(cell)
	for cell: Vector2i in _pending_tiles.keys():
		if not pending.has(cell): _pending_tiles.erase(cell)
	while _block_recent.size() > BLOCK_CACHE_LIMIT:
		var oldest: Vector2i = _block_recent[0]
		if cells.has(oldest): break
		_free_block(oldest)
	unresolved_tile_refs = unresolved
	_frame_commands.clear()
	_draw_generation+=1
	for cell: Vector2i in cells: _frame_commands[cell] = (_blocks[cell] as Dictionary).commands
	_visible_blocks = cells
	# Only atlases of blocks still waiting their first draw are held here.
	_frame_atlases = fresh_atlases
	# Blocks still missing are pending; the built view stays (no full rebuild
	# on every refresh until the last margin block is baked).
	_built_view = view
	# Every block here is baked (blocks keep their own atlases until drawn):
	# let go of the decoded atlases held for them. Bounded while blocks wait.
	if _tile_pack != null and _tile_pack.has_method("release_held") and (not partial or int(_tile_pack.call("held_size")) > HELD_ATLAS_LIMIT):
		_tile_pack.call("release_held")
	var source_owned: bool = bool(field.get_meta("current523_source_field",false))
	_metrics = {"display_profile": "CURRENT523_S32_SOURCE_FIELD_OWN_INTERPRETATION" if source_owned else "M_DISPLAY_WITH_TWILIGHT_SOURCE360_NAVIGATION_ASSUMPTION",
		"registered_sources": _raw_sources.source_members().size() if _raw_sources!=null else 0, "candidate_placed_sources": _member_origins.size(), "unplaced_sources": field.unplaced_members.size() if source_owned else maxi(0,(_raw_sources.source_members().size() if _raw_sources!=null else 0)-_member_origins.size()),
		"overlap_chunks": _overlap.size(), "visible_chunks": visible.size(), "cached_chunks": _raw_chunks.size(),
		"visible_atlases": atlases.size(), "cached_atlases": _tile_pack.cache_size(), "draw_commands": count, "block_draw_commands": draws,
		"visible_blocks": cells.size(), "cached_blocks": _blocks.size(), "block_size": BLOCK,
		"uninterpreted_ffffffff_words": raw_ff, "unresolved_refs": unresolved, "unreadable_chunks": _unreadable_chunks.size(), "budget_skips": 0, "skipped_chunks": 0,
		"visual_delta": [_visual_delta.x, _visual_delta.y], "M_attributes_used": source_owned,
		"scope_clipped_records": _scope_clipped_records,
		"off_floor_decoration_records":_off_floor_decoration_records,
		"native_M_rules_verified": false, "navigation_owner": "CURRENT523_S32_OWN_ALLOWLIST" if source_owned else "EXISTING_TWILIGHT_FIELD"}
	if source_owned: _metrics["inferred_placements"]=field.inferred_placements.duplicate(true)
	_visible_members=visible.duplicate()
	if is_instance_valid(_static_spr):
		var built_for: Array=[_static_spr.get_instance_id(),visible.duplicate()]
		if _force_objects_refresh or built_for!=_objects_built_for:
			var objects_started: int = FRAME_HITCH.now()
			var static_records: Dictionary=_visible_static_records()
			_static_spr.refresh(static_records.records,int(static_records.malformed))
			FRAME_HITCH.detail("map.objects_refresh", objects_started)
			_objects_built_for=built_for
		else:
			FRAME_HITCH.count("map.object_refresh_skipped")
		_metrics["static_spr"]=_static_spr.metrics()
	_force_objects_refresh=false
	if bool(field.get_meta("current523_generic_field",false)): _metrics.merge(field.scope_metrics(),true)
	if is_instance_valid(_tile_ground): _tile_ground.queue_redraw()
	queue_redraw()  # Existing door labels depend on the live player distance.
	return true


## Callers outside the periodic refresh change what is shown: always rebuild.
func refresh_visible() -> void:
	_built_view = Rect2()
	_force_objects_refresh = true
	_refresh_view()
	if _configured: _refresh_markers_if_moved(true)


func _refresh_view() -> void:
	if not _configured: return
	var scope: String = _scope_problem()
	if not scope.is_empty(): _fail(scope); return
	# Rebuild only when the screen leaves the area the frame was built for.
	if not (_built_view.has_area() and _built_view.encloses(_view_rect())):
		var build_started: int = FRAME_HITCH.now()
		var built_ok: bool = _build_frame()
		FRAME_HITCH.detail("map.build_frame", build_started)
		if not built_ok: return
	_refresh_markers_if_moved(false)


## Name labels within 1400 px and the collision stream follow the actor: the
## labels after MARKER_REFRESH_DISTANCE of movement, the collision stream when
## the actor's cell changed (it keeps its own chunk early-out). Forced by
## refresh_visible() and configuration.
func _refresh_markers_if_moved(force: bool) -> void:
	if not is_instance_valid(player): return
	var at: Vector2 = player.global_position
	if force or not _markers_at.is_finite() or at.distance_to(_markers_at) >= MARKER_REFRESH_DISTANCE:
		_markers_at = at
		var markers_started: int = FRAME_HITCH.now()
		_refresh_markers()
		FRAME_HITCH.detail("map.markers", markers_started)
	var cell: Vector2i = field.world_to_cell(at) if field != null else Vector2i.ZERO
	if force or cell != _collision_cell:
		_collision_cell = cell
		var collision_started: int = FRAME_HITCH.now()
		_refresh_collision()
		FRAME_HITCH.detail("map.collision", collision_started)


## True when `cell` is one of the blocks a frame build of `view` walks.
static func _view_has_cell(view: Rect2, cell: Vector2i) -> bool:
	return cell.x >= floori(view.position.x / BLOCK) and cell.x <= floori(view.end.x / BLOCK) and cell.y >= floori(view.position.y / BLOCK) and cell.y <= floori(view.end.y / BLOCK)


## Bakes pending blocks of the built view, on-screen ones first, until
## `budget_usec` of work is spent (at least one bake per call; < 0 = all ready).
## A block whose atlases are still decoding is asked again PENDING_RETRY_MSEC
## later; an on-screen one bakes regardless after ON_SCREEN_WAIT_MSEC.
## Returns the number of blocks baked.
func _bake_pending(budget_usec: int) -> int:
	if _pending_blocks.is_empty(): return 0
	var started: int = Time.get_ticks_usec()
	var now_msec: int = Time.get_ticks_msec()
	var screen: Rect2 = _view_rect()
	var keep: Rect2 = _built_view
	var baked: int = 0
	var late_bakes: int = 0
	var order: Array[Vector2i] = []
	var later: Array[Vector2i] = []
	for cell: Vector2i in _pending_blocks:
		if _block_rect(cell).intersects(screen): order.append(cell)
		else: later.append(cell)
	order.append_array(later)
	var remaining: Array[Vector2i] = []
	for index: int in order.size():
		var cell: Vector2i = order[index]
		if _blocks.has(cell): continue
		# A block outside the current built view is no longer wanted.
		if keep.has_area() and not _view_has_cell(keep, cell): _pending_retry.erase(cell); _pending_tiles.erase(cell); continue
		if budget_usec >= 0 and baked > 0 and Time.get_ticks_usec() - started >= budget_usec:
			remaining.append_array(order.slice(index))
			break
		if now_msec < int(_pending_retry.get(cell, 0)):
			remaining.append(cell)
			continue
		var on_screen: bool = _block_rect(cell).intersects(screen)
		var force_sync: bool = not _pending_tiles_ready(cell)
		if force_sync:
			var waited: bool = false
			if on_screen:
				var since: int = int(_screen_wait.get(cell, now_msec))
				_screen_wait[cell] = since
				waited = now_msec - since >= ON_SCREEN_WAIT_MSEC and late_bakes < LATE_BAKES_PER_REFRESH
			if not waited:
				_pending_retry[cell] = now_msec + PENDING_RETRY_MSEC
				remaining.append(cell)
				continue
		var built: Dictionary = _ready_block_commands(cell, on_screen, force_sync)
		if built.is_empty():
			remaining.append(cell)
			continue
		late_bakes += int(force_sync)
		_screen_wait.erase(cell)
		_pending_retry.erase(cell)
		_pending_tiles.erase(cell)
		if built.has("problem"):
			if problem.is_empty(): _fail(str(built.problem))
			return baked
		_blocks[cell] = _bake_block(cell, built)
		_block_recent.erase(cell); _block_recent.append(cell)
		if not _visible_blocks.has(cell): _visible_blocks.append(cell)
		_frame_commands[cell] = (_blocks[cell] as Dictionary).commands
		for tile_id: int in built.get("atlases", {}): _frame_atlases[tile_id] = built.atlases[tile_id]
		baked += 1
	_pending_blocks = remaining
	if baked > 0:
		FRAME_HITCH.count("map.pending_blocks_baked", baked)
		while _block_recent.size() > BLOCK_CACHE_LIMIT:
			var oldest: Vector2i = _block_recent[0]
			if _visible_blocks.has(oldest): break
			_free_block(oldest)
		_metrics["visible_blocks"] = _visible_blocks.size()
		_metrics["cached_blocks"] = _blocks.size()
		_draw_generation += 1
		if is_instance_valid(_tile_ground): _tile_ground.queue_redraw()
	if _pending_blocks.is_empty() and _tile_pack != null and _tile_pack.has_method("release_held"):
		_tile_pack.call("release_held")
	return baked


func _refresh_collision() -> void:
	var stream: Variant = field.get("collision_stream") if field != null else null
	if is_instance_valid(stream): stream.refresh()


func _process(delta: float) -> void:
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_step(delta)
	FRAME_HITCH.add_self("map_renderer", hitch_started, hitch_nested)

func _process_step(delta: float) -> void:
	if not _configured: return
	if _tile_pack != null and _tile_pack.has_method("pump_gpu"): _tile_pack.pump_gpu()
	if not _chunk_jobs.is_empty():
		var chunks_started: int = FRAME_HITCH.now()
		_pump_chunk_jobs()
		FRAME_HITCH.detail("map.chunk_install", chunks_started)
	var scope_started: int = FRAME_HITCH.now()
	var scope: String = _scope_problem()
	FRAME_HITCH.detail("map.scope", scope_started)
	if not scope.is_empty(): _fail(scope); return
	var cell: Vector2i = field.world_to_cell(player.global_position)
	# The tile ground only draws _frame_commands, which change only in
	# _build_frame() (that queues its own redraw). Re-issuing every visible tile
	# draw on each 24 px step of the player was wasted work.
	if cell != _last_actor_cell:
		_last_actor_cell = cell
	_refresh_clock -= delta
	if _refresh_clock <= 0.0:
		_refresh_clock = 0.25
		_refresh_view()
	if _configured and not _pending_blocks.is_empty():
		var pending_started: int = FRAME_HITCH.now()
		_bake_pending(PENDING_BAKE_BUDGET_USEC)
		FRAME_HITCH.detail("map.pending_bake", pending_started)


func _draw_tiles(canvas: Node2D) -> void:
	if not _configured: return
	var observe: bool=USAGE.actual_main(self) and _usage_generation!=_draw_generation
	var view: Rect2=_view_rect().grow(-64.0) if observe else Rect2()
	var observed_refs: Dictionary={}
	for cell: Vector2i in _visible_blocks:
		var block: Dictionary = _blocks.get(cell, {})
		var viewport: Variant = block.get("viewport")
		if not is_instance_valid(viewport): continue
		canvas.draw_texture((viewport as SubViewport).get_texture(), Vector2(cell * BLOCK))
		if observe and _block_rect(cell).intersects(view):
			# Each ref is observed once: refs not yet seen on screen keep their
			# tile corners; a ref leaves the list when one of them is in view.
			# (Every rebuild used to walk every tile of every visible block.)
			if not block.has("usage_pending"): block["usage_pending"] = _usage_pending(block.commands)
			var pending: Dictionary = block.usage_pending
			for ref: int in pending.keys():
				var corners: PackedInt64Array = pending[ref]
				for index: int in range(0, corners.size(), 2):
					if Rect2(Vector2(corners[index], corners[index + 1]), Vector2(TILE_PX, TILE_PX)).intersects(view):
						observed_refs[ref] = true
						pending.erase(ref)
						break
	if observe:
		for ref: int in observed_refs:
			var source: Dictionary=_tile_pack.source_usage_identity(ref>>8)
			if not source.is_empty():USAGE.observe(self,str(source.member),int(source.bytes),str(source.sha256),"subimage:"+str(ref&255))
		_usage_generation=_draw_generation
		USAGE.flush()


func _draw() -> void:
	if _configured and not bool(field.get_meta("current523_source_field",false)): super._draw()


func _unhandled_input(event: InputEvent) -> void:
	# set_process(false) alone does not disable the inherited door input hook.
	if not _configured or _return_pending or not is_inside_tree() or not is_visible_in_tree() or field == null or not is_instance_valid(player): return
	if bool(field.get_meta("current523_source_field",false)): return
	super._unhandled_input(event)


func set_visual_mode(_mode: String) -> void:
	pass  # Preserve original candidate RGBA values rather than tinting the pack.


func _unresolved_tile(tile_id: int, detail: String) -> void:
	if _unresolved_logged.has(tile_id) or _unresolved_logged.size() >= 64: return
	_unresolved_logged[tile_id] = detail
	print("CURRENT523_TILE_UNRESOLVED ", detail)


func _fail(reason: String) -> bool:
	problem = reason
	failure = reason
	var active: bool = _configured and is_inside_tree() and is_visible_in_tree()
	_configured = false
	_frame_commands.clear(); _frame_atlases.clear(); _clear_blocks()
	if is_instance_valid(_tile_ground): _tile_ground.queue_redraw()
	set_process(false)
	if active and not _return_pending:
		_return_pending = true
		call_deferred("_emit_safe_return", reason)
	return false


func _emit_safe_return(reason: String) -> void:
	if is_inside_tree() and not is_queued_for_deletion(): safe_return_requested.emit(reason)


func _notification(what: int) -> void:
	# A render target may come back empty after the app returns; rebake.
	if what == NOTIFICATION_APPLICATION_RESUMED and _configured:
		_clear_blocks()
		_built_view = Rect2()


func _exit_tree() -> void:
	_configured = false
	_drop_chunk_jobs()
	_frame_commands.clear(); _frame_atlases.clear(); _raw_chunks.clear(); _raw_recent.clear(); _clear_blocks(); _chunk_bins.clear()
	_raw_sources = null; _tile_pack = null
	super._exit_tree()
