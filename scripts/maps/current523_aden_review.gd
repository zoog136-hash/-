extends Control
signal close_requested
## Opt-in Main display of M originals using an explicitly unverified projection.
## Camera inspection is independent of actor movement and never opens terrain.
const TILES = preload("res://scripts/maps/current523_tile_review_pack.gd")
const MAX_VISIBLE_CHUNKS = 48
const MAX_CACHED_CHUNKS = 48
const MAX_VISIBLE_ATLASES = 256
const MAX_DRAW_COMMANDS = 65536
var problem: String = ""
var selected_member: String = ""
var include_objects: bool = true
var _world: Node
var _tiles = TILES.new()
var _members: Array = []
var _origins: Dictionary = {}
var _chunks: Dictionary = {}
var _recent: Array[String] = []
var _commands: Dictionary = {}
var _frame_textures: Dictionary = {}
var _metrics: Dictionary = {}
var _center := Vector2.ZERO
var _zoom: float = 0.65
var _local_only: bool = false
var _dirty: bool = true
var _dragging: bool = false
var _rebuild_clock: float = 0.0
var _selector: OptionButton
var _status: Label
var _coordinates: Label
var close_button: Button

static func requested() -> bool:
	return "--aden523-review" in OS.get_cmdline_user_args()

static func argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

static func candidate_origin(member: String) -> Variant:
	var stem: String = member.get_file().trim_suffix(".s32")
	if stem.length() != 8: return null
	for c: String in stem:
		if not c in "0123456789abcdefABCDEF": return null
	return Vector2i((stem.substr(0, 4).hex_to_int() - 0x7e00) * 64, (stem.substr(4, 4).hex_to_int() - 0x7e00) * 64)

static func project_half_storage(half_x: int, row_y: int) -> Vector2i:
	# Reviewed-tool hypothesis only. No M world/cell/foot contract is inferred.
	return Vector2i(24 * (floori(float(half_x + 1) / 2.0) + row_y), 12 * (row_y - floori(float(half_x) / 2.0)))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_build_ui()
	resized.connect(func() -> void: _dirty = true)

func _build_ui() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.04, 0.065, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 120
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := Label.new()
	title.text = "아덴 523 · M 원본 타일 검토 | 좌표·투영 가설 · 통행/충돌 미검증"
	title.position = Vector2(16, 9)
	title.add_theme_font_size_override("font_size", 19)
	add_child(title)
	_selector = OptionButton.new()
	_selector.position = Vector2(16, 39)
	_selector.size = Vector2(325, 32)
	_selector.item_selected.connect(func(index: int) -> void: center_on_member(str(_members[index])))
	add_child(_selector)
	var objects := CheckBox.new()
	objects.text = "사물 타일 (레이어 가설)"
	objects.button_pressed = include_objects
	objects.position = Vector2(355, 39)
	objects.toggled.connect(func(value: bool) -> void: include_objects = value; _dirty = true)
	add_child(objects)
	close_button = Button.new()
	close_button.name = "CloseAdenReview"
	close_button.text = "검토 닫기"
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -158
	close_button.offset_right = -16
	close_button.offset_top = 39
	close_button.offset_bottom = 72
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)
	_coordinates = Label.new()
	_coordinates.position = Vector2(16, 76)
	add_child(_coordinates)
	_status = Label.new()
	_status.position = Vector2(16, 98)
	_status.add_theme_font_size_override("font_size", 13)
	add_child(_status)
	var help := Label.new()
	help.text = "WASD/드래그: 검토 카메라 · 휠: 확대 | 원본 저장 픽셀 표시 · 가림/SPR 미적용 · 저장 비활성"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 16
	help.offset_right = 1200
	help.offset_top = -27
	help.offset_bottom = -3
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	add_child(help)

func show_problem(message: String) -> void:
	problem = message
	_commands.clear()
	_frame_textures.clear()
	if is_instance_valid(_status): _status.text = "원본 검토 팩 오류: " + message
	queue_redraw()

func configure(world: Node, tiles_root: String, member: String) -> bool:
	_world = world
	if not _tiles.load_pack(tiles_root): show_problem(_tiles.problem); return false
	_members = world.call("current523_aden_source_members")
	if _members.size() != 677: show_problem("아덴 원문 677개가 등록되지 않았습니다"); return false
	_selector.clear()
	for item: String in _members:
		var origin: Variant = candidate_origin(item)
		if origin != null: _origins[item] = origin
		_selector.add_item(item.get_file() + (" · 좌표 미확정 / 단독" if origin == null else ""))
	if member.is_empty(): member = "Map/Aden/800a8000.s32"
	if not center_on_member(member): return false
	_rebuild()
	return problem.is_empty()

func center_on_member(member: String) -> bool:
	if not member in _members: show_problem("등록되지 않은 원문: " + member); return false
	selected_member = member
	problem = ""
	_local_only = not _origins.has(member)
	var origin: Vector2i = _origins.get(member, Vector2i.ZERO)
	_center = Vector2(project_half_storage(2 * (origin.x + 32), origin.y + 32))
	_selector.select(_members.find(member))
	_coordinates.text = member + (" | 좌표 미확정: 원문 저장 인덱스 단독 보기" if _local_only else " | 파일명 좌표 가설: " + str(origin) + " · M 실행 좌표 미확정")
	_dirty = true
	return true

func frame_metrics() -> Dictionary:
	return _metrics.duplicate(true)

func camera_state() -> Dictionary:
	return {"center": _center, "zoom": _zoom, "member": selected_member, "local_only": _local_only}

func pan_pixels(delta: Vector2) -> void:
	_center += delta / _zoom
	_dirty = true

func _process(delta: float) -> void:
	if _world == null or not problem.is_empty(): return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if direction != Vector2.ZERO: pan_pixels(direction.normalized() * delta * 650.0)
	_rebuild_clock -= delta
	if _dirty and _rebuild_clock <= 0.0:
		_rebuild()
		_rebuild_clock = 0.10
	if direction != Vector2.ZERO or _dragging: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var offset: Vector2 = event.position - get_viewport_rect().size * 0.5
			var before: Vector2 = _center + offset / _zoom
			_zoom = clampf(_zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.20, 3.0)
			_center = before - offset / _zoom
			_dirty = true
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan_pixels(-event.relative)
		queue_redraw()
		accept_event()

func _view_rect() -> Rect2:
	var extent: Vector2 = get_viewport_rect().size / _zoom
	return Rect2(_center - extent * 0.5, extent).grow(48.0)

static func _possible_rect(origin: Vector2i) -> Rect2:
	# Only floor and raw u8 cover/object storage extents are considered. Effect
	# coordinates never become a chunk dimension (the viewer RealBounds bug).
	var bounds := Rect2(Vector2(project_half_storage(origin.x * 2, origin.y)), Vector2.ONE)
	for x: int in [0, 255]:
		for y: int in [0, 255]: bounds = bounds.expand(Vector2(project_half_storage(origin.x * 2 + x, origin.y + y)))
	return bounds.grow(24.0)

func _chunk(member: String) -> Dictionary:
	if _chunks.has(member):
		_recent.erase(member)
		_recent.append(member)
		return _chunks[member]
	var source: Dictionary = _world.call("read_current523_aden_source", member)
	if source.is_empty(): show_problem(str(_world.get("current523_aden_problem"))); return {}
	var origin: Vector2i = _origins.get(member, Vector2i.ZERO)
	var layers: Dictionary = {}
	var floor_bytes: PackedByteArray = source.sections.floor
	for index: int in range(8192): _append(layers, origin, index & 127, index >> 7, floor_bytes.decode_u32(index * 4), -2)
	var covers: PackedByteArray = source.sections.covers
	for index: int in range(covers.decode_u16(0)):
		var offset: int = 2 + index * 6
		_append(layers, origin, covers[offset], covers[offset + 1], covers.decode_u32(offset + 2), -1)
	var objects: PackedByteArray = source.sections.objects
	var cursor: int = 4
	for _group: int in range(objects.decode_u32(0)):
		var count: int = objects.decode_u16(cursor + 2)
		cursor += 4
		for _part: int in range(count):
			_append(layers, origin, objects[cursor], objects[cursor + 1], objects.decode_u32(cursor + 3), objects[cursor + 2])
			cursor += 7
	var packed: Dictionary = {}
	for layer: int in layers: packed[layer] = PackedInt64Array(layers[layer])
	_chunks[member] = packed
	_recent.append(member)
	while _recent.size() > MAX_CACHED_CHUNKS: _chunks.erase(_recent.pop_front())
	return packed

static func _append(layers: Dictionary, origin: Vector2i, x: int, y: int, raw_ref: int, layer: int) -> void:
	var point: Vector2i = project_half_storage(origin.x * 2 + x, origin.y + y)
	if not layers.has(layer): layers[layer] = []
	var values: Array = layers[layer]
	values.append(point.x)
	values.append(point.y)
	values.append(raw_ref) # Full unsigned32 value, including0xffffffff.

func _rebuild() -> void:
	if _world == null or not problem.is_empty(): return
	_dirty = false
	var view: Rect2 = _view_rect()
	var visible: Array[String] = []
	if _local_only: visible.append(selected_member)
	else:
		for member: String in _origins:
			if _possible_rect(_origins[member]).intersects(view): visible.append(member)
		visible.sort_custom(func(a: String, b: String) -> bool: return _possible_rect(_origins[a]).get_center().distance_squared_to(_center) < _possible_rect(_origins[b]).get_center().distance_squared_to(_center))
	var skipped_chunks: int = maxi(0, visible.size() - MAX_VISIBLE_CHUNKS)
	visible.resize(mini(visible.size(), MAX_VISIBLE_CHUNKS))
	var commands: Dictionary = {}
	var textures: Dictionary = {}
	var unresolved: int = 0
	var uninterpreted_ff: int = 0
	var budget_skips: int = 0
	var command_count: int = 0
	var raw_unresolved: Array[int] = []
	for member: String in visible:
		var layers: Dictionary = _chunk(member)
		if not problem.is_empty(): return
		for layer: int in layers:
			if not include_objects and layer >= 0: continue
			var records: PackedInt64Array = layers[layer]
			for index: int in range(0, records.size(), 3):
				var point := Vector2(records[index], records[index + 1])
				if not view.has_point(point): continue
				var ref: int = records[index + 2]
				if ref == 4294967295:
					# Preserve this word separately as an uninterpreted sentinel/empty
					# candidate, never a demand for a missing Tile/16777215 asset.
					uninterpreted_ff += 1
					continue
				var tile_id: int = ref >> 8
				if not _tiles.has_tile(tile_id):
					unresolved += 1
					if raw_unresolved.size() < 8 and not ref in raw_unresolved: raw_unresolved.append(ref)
					continue
				if command_count >= MAX_DRAW_COMMANDS or (not textures.has(tile_id) and textures.size() >= MAX_VISIBLE_ATLASES): budget_skips += 1; continue
				if not textures.has(tile_id):
					var atlas: Texture2D = _tiles.texture_for(tile_id)
					if atlas == null: show_problem(_tiles.problem); return
					textures[tile_id] = atlas
				if not commands.has(layer): commands[layer] = []
				var lane: Array = commands[layer]
				lane.append(records[index])
				lane.append(records[index + 1])
				lane.append(ref)
				command_count += 1
	_commands.clear()
	for layer: int in commands: _commands[layer] = PackedInt64Array(commands[layer])
	_frame_textures = textures
	_metrics = {"member": selected_member, "registered_sources": _members.size(), "candidate_placed_sources": _origins.size(), "unplaced_sources": _members.size() - _origins.size(), "local_only": _local_only, "visible_chunks": visible.size(), "cached_chunks": _chunks.size(), "visible_atlases": textures.size(), "cached_atlases": _tiles.cache_size(), "draw_commands": command_count, "unresolved_refs": unresolved, "uninterpreted_ffffffff_words": uninterpreted_ff, "raw_unresolved_examples": raw_unresolved, "budget_skips": budget_skips, "skipped_chunks": skipped_chunks, "movement_implemented": false, "M_projection_verified": false}
	_status.text = "표시 %d타일 / %d청크 · 미해석 %d (0xffffffff %d) · 예산 제외 %d/%d · 좌표 가설676 + 미확정1" % [command_count, visible.size(), unresolved, uninterpreted_ff, budget_skips, skipped_chunks]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("17202b"))
	var layers: Array = _commands.keys()
	layers.sort()
	var half_view: Vector2 = get_viewport_rect().size * 0.5
	for layer: int in layers:
		var lane: PackedInt64Array = _commands[layer]
		for index: int in range(0, lane.size(), 3):
			var ref: int = lane[index + 2]
			var position: Vector2 = (Vector2(lane[index], lane[index + 1]) - _center) * _zoom + half_view
			draw_texture_rect_region(_frame_textures[ref >> 8], Rect2(position, Vector2(24, 24) * _zoom), TILES.source_rect(ref & 255))
