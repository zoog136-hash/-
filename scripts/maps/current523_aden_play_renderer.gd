extends "res://scripts/maps/source_map_runtime_renderer.gd"
## Stored-pixel display for source fields and the retained legacy overlay.
## The selected field owns movement; rendering never infers native collision.
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
signal safe_return_requested(reason: String)

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
## The built frame covers this much beyond the screen, so standing still or
## small moves reuse it instead of re-walking every visible chunk record.
const BUILD_MARGIN: float = 192.0

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
var _metrics: Dictionary = {}
var _last_actor_cell := Vector2i(-2147483648, -2147483648)
var _refresh_clock: float = 0.0
var _scope_clipped_records: int = 0
var _off_floor_decoration_records: int = 0
var _draw_generation: int=0
var _usage_generation: int=-1
var _visible_members: Array[String]=[]


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
	_visual_delta = visual_delta
	_member_origins.clear(); _overlap.clear(); _legacy_origins.clear(); _chunk_rects.clear()
	_raw_chunks.clear(); _raw_recent.clear(); _frame_commands.clear(); _frame_atlases.clear()
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
		return _fail("기존 통행 API에서 현재 위치를 확인하지 못했습니다.")
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
		if objects.configure(BANK_OBJECTS.bank_selection(),field.coordinates):
			_static_spr=objects
			add_child(_static_spr)
			_static_spr.position=_visual_delta
		else:
			map_objects_problem=objects.problem
			objects.free()
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
		if not player.global_position.is_finite() or not support_world_point(player.global_position) or not field.point_clear(player.global_position,4): return "원문 자체 통행의 지원 영역 밖이므로 복귀합니다."
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
	var decoded: Dictionary = _raw_sources.read_member(member)
	if decoded.is_empty(): _fail(_raw_sources.problem); return {}
	var origin: Vector2i = _member_origins[member]
	# Retain the same currently loaded S32 tail even while SPR display is off.
	# Enabling the existing consumer does not need another map entry or a source scan.
	var tail: Dictionary=STATIC_SPR.parse_tail(decoded.sections.tail,int(_raw_sources.source_metadata(member).get("core_end",0)))
	if tail.ok:
		for row: Dictionary in tail.records:
			row["source_member"]=member
			row["source_sha256"]=decoded.source_sha256
			row["source_bytes"]=decoded.source_bytes
	_static_tails[member]=tail
	var layers: Dictionary = {}
	var floor_bytes: PackedByteArray = decoded.sections.floor
	for index: int in range(8192): _append(layers, origin, index & 127, index >> 7, floor_bytes.decode_u32(index * 4), -2)
	var covers: PackedByteArray = decoded.sections.covers
	for index: int in range(covers.decode_u16(0)):
		var offset: int = 2 + index * 6
		_append(layers, origin, covers[offset], covers[offset + 1], covers.decode_u32(offset + 2), -1)
	var objects: PackedByteArray = decoded.sections.objects
	var cursor: int = 4
	for _group: int in range(objects.decode_u32(0)):
		var count: int = objects.decode_u16(cursor + 2)
		cursor += 4
		for _part: int in range(count):
			_append(layers, origin, objects[cursor], objects[cursor + 1], objects.decode_u32(cursor + 3), objects[cursor + 2])
			cursor += 7
	var packed: Dictionary = {}
	for layer: int in layers: packed[layer] = PackedInt64Array(layers[layer])
	_raw_chunks[member] = packed
	_raw_recent.append(member)
	while _raw_recent.size() > RAW_CHUNK_LIMIT:
		var oldest: String=_raw_recent.pop_front()
		_raw_chunks.erase(oldest);_static_tails.erase(oldest)
	return packed


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


func _build_frame() -> bool:
	var view: Rect2 = _view_rect().grow(BUILD_MARGIN)
	var visible: Array[String] = []
	for member: String in _chunk_rects:
		if (_chunk_rects[member] as Rect2).intersects(view): visible.append(member)
	if visible.is_empty(): return _fail("현재 화면에 표시할 공통 원문 영역이 없습니다.")
	if visible.size() > VISIBLE_CHUNK_LIMIT: return _fail("M 표시 실험의 동시 청크 예산을 초과했습니다.")
	visible.sort()
	var commands: Dictionary = {}
	var atlases: Dictionary = {}
	var count: int = 0
	var raw_ff: int = 0
	for member: String in visible:
		var layers: Dictionary = _read_chunk(member)
		if not problem.is_empty(): return false
		for layer: int in layers:
			if not include_objects and layer >= 0: continue
			var records: PackedInt64Array = layers[layer]
			for index: int in range(0, records.size(), 3):
				var point := Vector2(records[index], records[index + 1])
				if not view.has_point(point): continue
				var ref: int = records[index + 2]
				if ref == 4294967295: raw_ff += 1; continue
				var tile_id: int = ref >> 8
				if not _tile_pack.has_tile(tile_id): return _fail("해결되지 않은 M 타일 원문: " + str(tile_id))
				if _tile_pack.has_method("has_subimage") and not _tile_pack.call("has_subimage",tile_id,ref & 255): return _fail("원문에 없는 하위 타일 번호: %d/%d" % [tile_id,ref & 255])
				if count >= DRAW_COMMAND_LIMIT or (not atlases.has(tile_id) and atlases.size() >= VISIBLE_ATLAS_LIMIT):
					return _fail("M 표시 실험의 타일 또는 아틀라스 예산을 초과했습니다.")
				if not atlases.has(tile_id):
					var texture: Texture2D = _frame_atlases.get(tile_id)
					if texture == null: texture = _tile_pack.texture_for(tile_id)
					if texture == null: return _fail(_tile_pack.problem)
					atlases[tile_id] = texture
				if not commands.has(layer): commands[layer] = []
				var lane: Array = commands[layer]
				lane.append(records[index]); lane.append(records[index + 1]); lane.append(ref)
				count += 1
	if count == 0: return _fail("현재 화면의 M 원문 타일을 표시하지 못했습니다.")
	_frame_commands.clear()
	_draw_generation+=1
	for layer: int in commands: _frame_commands[layer] = PackedInt64Array(commands[layer])
	_frame_atlases = atlases
	_built_view = view
	var source_owned: bool = bool(field.get_meta("current523_source_field",false))
	_metrics = {"display_profile": "CURRENT523_S32_SOURCE_FIELD_OWN_INTERPRETATION" if source_owned else "M_DISPLAY_WITH_TWILIGHT_SOURCE360_NAVIGATION_ASSUMPTION",
		"registered_sources": _raw_sources.source_members().size() if _raw_sources!=null else 0, "candidate_placed_sources": _member_origins.size(), "unplaced_sources": field.unplaced_members.size() if source_owned else maxi(0,(_raw_sources.source_members().size() if _raw_sources!=null else 0)-_member_origins.size()),
		"overlap_chunks": _overlap.size(), "visible_chunks": visible.size(), "cached_chunks": _raw_chunks.size(),
		"visible_atlases": atlases.size(), "cached_atlases": _tile_pack.cache_size(), "draw_commands": count,
		"uninterpreted_ffffffff_words": raw_ff, "unresolved_refs": 0, "budget_skips": 0, "skipped_chunks": 0,
		"visual_delta": [_visual_delta.x, _visual_delta.y], "M_attributes_used": source_owned,
		"scope_clipped_records": _scope_clipped_records,
		"off_floor_decoration_records":_off_floor_decoration_records,
		"native_M_rules_verified": false, "navigation_owner": "CURRENT523_S32_OWN_ALLOWLIST" if source_owned else "EXISTING_TWILIGHT_FIELD"}
	if source_owned: _metrics["inferred_placements"]=field.inferred_placements.duplicate(true)
	_visible_members=visible.duplicate()
	if is_instance_valid(_static_spr):
		var static_records: Dictionary=_visible_static_records()
		_static_spr.refresh(static_records.records,int(static_records.malformed))
		_metrics["static_spr"]=_static_spr.metrics()
	if bool(field.get_meta("current523_generic_field",false)): _metrics.merge(field.scope_metrics(),true)
	if is_instance_valid(_tile_ground): _tile_ground.queue_redraw()
	queue_redraw()  # Existing door labels depend on the live player distance.
	return true


## Callers outside the periodic refresh change what is shown: always rebuild.
func refresh_visible() -> void:
	_built_view = Rect2()
	_refresh_view()


func _refresh_view() -> void:
	if not _configured: return
	var scope: String = _scope_problem()
	if not scope.is_empty(): _fail(scope); return
	# Rebuild only when the screen leaves the area the frame was built for.
	if not (_built_view.has_area() and _built_view.encloses(_view_rect())):
		if not _build_frame(): return
	_refresh_markers()
	_refresh_collision()


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
	var scope: String = _scope_problem()
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


func _draw_tiles(canvas: Node2D) -> void:
	if not _configured: return
	var observe: bool=USAGE.actual_main(self) and _usage_generation!=_draw_generation
	var view: Rect2=_view_rect().grow(-64.0) if observe else Rect2()
	var observed_refs: Dictionary={}
	var layers: Array = _frame_commands.keys()
	layers.sort()
	for layer: int in layers:
		var lane: PackedInt64Array = _frame_commands[layer]
		for index: int in range(0, lane.size(), 3):
			var ref: int = lane[index + 2]
			var rect:=Rect2(Vector2(lane[index],lane[index+1]),Vector2(24,24))
			canvas.draw_texture_rect_region(_frame_atlases[ref >> 8],rect,TILES.source_rect(ref & 255))
			if observe and not observed_refs.has(ref) and rect.intersects(view):observed_refs[ref]=true
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


func _fail(reason: String) -> bool:
	problem = reason
	failure = reason
	var active: bool = _configured and is_inside_tree() and is_visible_in_tree()
	_configured = false
	_frame_commands.clear(); _frame_atlases.clear()
	if is_instance_valid(_tile_ground): _tile_ground.queue_redraw()
	set_process(false)
	if active and not _return_pending:
		_return_pending = true
		call_deferred("_emit_safe_return", reason)
	return false


func _emit_safe_return(reason: String) -> void:
	if is_inside_tree() and not is_queued_for_deletion(): safe_return_requested.emit(reason)


func _exit_tree() -> void:
	_configured = false
	_frame_commands.clear(); _frame_atlases.clear(); _raw_chunks.clear(); _raw_recent.clear()
	_raw_sources = null; _tile_pack = null
	super._exit_tree()
