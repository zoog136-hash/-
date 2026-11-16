extends Node2D
## 523 map objects (the S32 tail's sprite records: buildings, trees, props)
## drawn from the installed 523 SP2 bank, the same source that draws actors.
##
## Each record names a client sprite ID and a raw map point. The sprite's own
## declared action 3 (the map display action every Aden object declares;
## else 0, else its lowest action) plays looping in stored direction 0; a
## sprite without actions shows its client static picture. Layers keep the
## bank's order and offsets; layers with source attributes use the shared
## playback policy (hidden in strict mode, as for actors).
##
## Drop-in for current523_static_spr.gd: configure / refresh / metrics.
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const PRESENTATION = preload("res://scripts/animation/source_presentation_policy.gd")
const SCOPE := "current523_map_objects"
const ACTION_PREFERENCE := [3, 0]
const MAX_DRAWN := 1024
const MAX_SPRITES := 512
const TEXTURE_BUDGET_BYTES := 96 * 1024 * 1024
## A teleport/map entry showed every new object sprite in one refresh: the
## phone-class run recorded map.object_refresh 932-1357 ms (10 cold bank loads
## of up to 424 ms) inside one "지도 그리기" frame. The field renderer sets this
## per-refresh load budget: once it is spent, remaining new sprites wait for
## the next frame's refresh (objects appear a few frames later, none is
## dropped, and an already loaded sprite is never delayed). -1 = load all.
const FRAME_SPRITE_LOAD_BUDGET_USEC := 12000
var sprite_load_budget_usec: int = -1
## With a load budget (the field renderer), cold sprite banks are prepared on
## worker threads (reference_sp2_bank.background_loading): a sprite whose
## inputs are not ready yet waits like a budget-deferred one, and the waiting
## refresh repeats only once a worker result arrived.
const LOADER = preload("res://scripts/resources/sp2_background_loader.gd")
var _waiting_serial: int = -1
var _malformed: int = 0
var _pending_refresh: bool = false

var problem: String = ""
var coordinates: RefCounted
var manifest_path: String = ""
var manifest_sha256: String = ""
var _mode: String = "strict"
var _bank: BANK = BANK.new()
var _sprites: Dictionary = {}
var _textures: Dictionary = {}
var _texture_bytes: int = 0
var _records: Array[Dictionary] = []
var _nodes: Array[Node2D] = []
# Source-order holders stay authoritative. This bounded index only avoids
# visiting static placements on every tick; clocks and redraw order are kept.
var _placement_sprite_ids: Dictionary = {}
var _animation_ids: Array = []
var _animated_nodes: Array[Node2D] = []
var _clock: float = 0.0
var _stats: Dictionary = {}
## Per-second CPU on the phone (523.545, 8 fps): map_objects 174 ms, i.e.
## every frame re-sampled and re-laid out every animated placement of the 25
## visible chunks, most of them off screen. Two bounds (approved ~90% quality):
## - the engine tick advances the shared clock at most ANIMATION_HZ times per
##   second (the elapsed time is carried, so the clock and frame choice stay
##   exact at each update, only drawn less often at 30 fps);
## - only placements whose drawn bounds meet the camera view grown by
##   CULL_MARGIN advance. The list is rebuilt when the view has moved more
##   than CULL_MARGIN - CULL_KEEP px, the animated set changed or a refresh
##   ran. A culled placement keeps its last frame until it comes back into
##   view, where its next update shows the clock's frame at once.
## Without a viewport (tools, tests out of the tree) every placement advances.
const ANIMATION_HZ: float = 15.0
const CULL_MARGIN: float = 160.0
const CULL_KEEP: float = 96.0
var offscreen_culling: bool = true
var animation_step: float = 1.0 / ANIMATION_HZ
var _tick_carry: float = 0.0
var _cull_view := Rect2()
var _shown_animated: Array[Node2D] = []

## The bank selection the resource pack installer wrote, or {}.
static func bank_selection() -> Dictionary:
	var options: Dictionary = preload("res://scripts/resources/current523_source_bank.gd").options()
	if not options.get("ok", false): return {}
	var value: Dictionary = options.get("options", {})
	if str(value.get("manifest_path", "")).is_empty() or not BANK.valid_sha(value.get("manifest_sha256")): return {}
	return {"manifest_path":str(value.manifest_path),"manifest_sha256":str(value.manifest_sha256)}

func configure(selection: Dictionary, mapping: RefCounted) -> bool:
	if mapping == null or not bool(mapping.get("valid")):
		problem = "523 지도 좌표계가 유효하지 않습니다."; return false
	manifest_path = str(selection.get("manifest_path", ""))
	manifest_sha256 = str(selection.get("manifest_sha256", ""))
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path) or not BANK.valid_sha(manifest_sha256):
		problem = "523 그림 은행이 설치되어 있지 않습니다."; return false
	coordinates = mapping
	_mode = POLICY.mode(manifest_path.get_base_dir())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Same own presentation layer as the static SPR renderer it replaces.
	z_index = int(preload("res://scripts/maps/current523_static_spr.gd").DEFAULTS.layer)
	set_process(true)
	return true

func refresh(records: Array[Dictionary], malformed: int = 0) -> void:
	var started: int = FRAME_HITCH.now()
	_records = records
	_malformed = malformed
	_pending_refresh = false
	var load_spent: int = 0
	var deferred: int = 0
	_placement_sprite_ids.clear()
	_animation_ids.clear()
	_animated_nodes.clear()
	_shown_animated.clear()
	_cull_view = Rect2()
	var created: int = 0
	var reused: int = 0
	var trimmed: int = 0
	var drawn: int = 0
	var unresolved: Dictionary = {}
	for row: Dictionary in records:
		if drawn >= MAX_DRAWN: break
		if sprite_load_budget_usec >= 0 and not _sprites.has(int(row.sprite_id)):
			if load_spent >= sprite_load_budget_usec:
				deferred += 1
				continue
			var load_started: int = Time.get_ticks_usec()
			var loading: Dictionary = _sprite(int(row.sprite_id))
			load_spent += Time.get_ticks_usec() - load_started
			if loading.get("background_pending", false):
				deferred += 1
				continue
		var sprite: Dictionary = _sprite(int(row.sprite_id))
		if not sprite.ok:
			unresolved[str(row.sprite_id)] = sprite.get("error", "unresolved")
			continue
		# These holders have no gameplay identity: keep the exact dense visible
		# source order, including duplicates, while reusing private presentation.
		var node: Node2D
		if drawn < _nodes.size():
			node = _nodes[drawn]
			reused += 1
		else:
			node = Node2D.new()
			add_child(node)
			_nodes.append(node)
			created += 1
		node.position = coordinates.to_world(Vector2(row.raw_x, row.raw_y), false)
		node.set_meta("sprite_id", int(row.sprite_id))
		_placement_sprite_ids[int(row.sprite_id)] = true
		# Refresh has always displayed frame zero, even for an unchanged ID.
		# Force the layer update so replacement records never keep old visuals.
		node.set_meta("frame", -1)
		_show(node, sprite, 0)
		drawn += 1
	while _nodes.size() > drawn:
		var unused: Node2D = _nodes.pop_back()
		remove_child(unused)
		unused.queue_free()
		trimmed += 1
	FRAME_HITCH.count("map.object_holders_created", created)
	FRAME_HITCH.count("map.object_holders_reused", reused)
	FRAME_HITCH.count("map.object_holders_trimmed", trimmed)
	_waiting_serial = LOADER.serial if deferred > 0 and LOADER.busy() else -1
	if deferred > 0:
		_pending_refresh = true
		FRAME_HITCH.count("map.object_sprites_deferred", deferred)
	_stats = {"policy":"OWN_BANK_ACTION3_DIRECTION0_LOOP_V1","raw_records":records.size(),"malformed_tails":malformed,"drawn_records":drawn,"unresolved_records":records.size() - drawn - deferred,"unresolved_source_ids":unresolved,"cached_sprites":_sprites.size(),"texture_bytes":_texture_bytes,"playback_mode":_mode,"native_M_placement_action_timing_verified":false}
	if sprite_load_budget_usec >= 0: _stats["deferred_records"] = deferred
	FRAME_HITCH.detail("map.object_refresh", started)

func metrics() -> Dictionary:
	return _stats.duplicate(true)

func _sprite(id: int) -> Dictionary:
	if _sprites.has(id): return _sprites[id]
	if _sprites.size() >= MAX_SPRITES: return {"ok":false,"error":"map_object_sprite_cache_full"}
	var started: int = FRAME_HITCH.now()
	BANK.background_loading = sprite_load_budget_usec >= 0 and LOADER.enabled
	var result: Dictionary = _load_sprite(id)
	BANK.background_loading = false
	FRAME_HITCH.detail("map.object_sprite_load", started)
	if result.get("background_pending", false):
		# Not a result: asked again after its worker tasks finished.
		FRAME_HITCH.count("map.object_sprite_background_wait")
		return result
	FRAME_HITCH.count("map.object_sprite_loads")
	_sprites[id] = result
	return result

func _load_sprite(id: int) -> Dictionary:
	var actions: Array = ACTION_PREFERENCE.duplicate()
	var last_error: String = ""
	var index: int = 0
	while index < actions.size():
		var action: int = int(actions[index])
		index += 1
		var loaded: Dictionary = _bank.load_bank(manifest_path, manifest_sha256, id, {"idle":action}, {"idle":true}, SCOPE)
		if not loaded.get("ok", false):
			last_error = str(loaded.get("error", ""))
			if last_error == BANK.ROLE_DEFERRED: return {"ok":false,"error":last_error,"background_pending":true}
			if not last_error.begins_with("Exact source action record"): break
			if index == ACTION_PREFERENCE.size():
				# Neither display action: the sprite's other declared actions, lowest first.
				var declared: Variant = _bank.call("_actor_registry", "sprite:" + str(id))
				if declared is Dictionary:
					var others: Array = []
					for key: Variant in declared:
						if str(key).is_valid_int() and not int(str(key)) in actions: others.append(int(str(key)))
					others.sort()
					actions.append_array(others)
			continue
		var track: Dictionary = loaded.record.tracks.get("idle", {})
		var directions: Variant = track.get("directions")
		var frames: Array = directions[0] if directions is Array and not directions.is_empty() else []
		if frames.is_empty(): continue
		var total: float = 0.0
		for frame: Dictionary in frames: total += PRESENTATION.duration(frame)
		return {"ok":true,"action":action,"frames":frames,"total":total,"static":bool(track.get("static_pending_timing", false)) or total <= 0.0}
	# A sprite without actions: its client static picture.
	var picture: Dictionary = _bank.load_static(manifest_path, manifest_sha256, id)
	if picture.get("error", "") == BANK.ROLE_DEFERRED: return {"ok":false,"error":BANK.ROLE_DEFERRED,"background_pending":true}
	if picture.get("ok", false):
		return {"ok":true,"action":-1,"frames":[{"layers":picture.layers,"duration":0.0}],"total":0.0,"static":true}
	return {"ok":false,"error":last_error if not last_error.is_empty() else str(picture.get("error", "map_object_source_absent"))}

func _frame_index(sprite: Dictionary) -> int:
	if sprite.static: return 0
	var time: float = fmod(_clock, sprite.total)
	var frames: Array = sprite.frames
	for index: int in frames.size():
		var length: float = PRESENTATION.duration(frames[index])
		if time < length: return index
		time -= length
	return frames.size() - 1

func _texture(layer: Dictionary) -> Texture2D:
	var key: String = "%s:%d:%d" % [str(layer.get("member", "")), int(layer.get("group_bit", -1)), int(layer.get("frame_index", -1))]
	if _textures.has(key): return _textures[key]
	var rendered: Dictionary = _bank.render_layer(layer, true)
	if not rendered.get("ok", false) or rendered.get("empty", false): _textures[key] = null; return null
	var image: Image = rendered.image
	var bytes: int = image.get_width() * image.get_height() * 4
	if _texture_bytes + bytes > TEXTURE_BUDGET_BYTES: return null
	var started: int = FRAME_HITCH.now()
	var texture := ImageTexture.create_from_image(image)
	FRAME_HITCH.detail("map.object_texture_create", started)
	_textures[key] = texture
	_texture_bytes += bytes
	return texture

func _show(node: Node2D, sprite: Dictionary, index: int) -> void:
	if int(node.get_meta("frame")) == index: return
	node.set_meta("frame", index)
	FRAME_HITCH.count("map.object_frames_shown")
	var frame: Dictionary = sprite.frames[index]
	var order: int = 0
	var created: int = 0
	for layer: Dictionary in frame.get("layers", []):
		if layer.has("client_null"): continue
		var attributes: Array = layer.get("source_attributes", [])
		var style: Dictionary = {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_MIX,"alpha":1.0}
		if not attributes.is_empty() or bool(layer.get("source_attributes_unresolved", false)):
			style = POLICY.effect(attributes, _mode)
			if bool(layer.get("source_attributes_unresolved", false)) or not bool(style.get("enabled", false)): continue
		var texture: Texture2D = _texture(layer)
		if texture == null: continue
		# Placement-owned children keep source-visible order; no shared playback
		# nodes or high-water pool retains unused textures after a smaller frame.
		var picture: Sprite2D = node.get_child(order) as Sprite2D if order < node.get_child_count() else null
		if picture == null:
			picture = Sprite2D.new()
			node.add_child(picture)
			node.move_child(picture, order)
			created += 1
		picture.centered = false
		picture.texture = texture
		picture.position = Vector2.ZERO
		var offset: Variant = layer.get("offset", [0, 0])
		if offset is Array and offset.size() == 2: picture.position = Vector2(float(offset[0]), float(offset[1]))
		elif layer.has("member"):
			var rendered: Dictionary = _bank.render_layer(layer, false)
			if rendered.get("ok", false): picture.position = Vector2(rendered.offset)
		picture.z_index = -1 if layer.get("kind") == "shadow" else order
		if int(style.blend_mode) != CanvasItemMaterial.BLEND_MODE_MIX:
			var material: CanvasItemMaterial = picture.material as CanvasItemMaterial
			if material == null:
				material = CanvasItemMaterial.new()
				picture.material = material
			material.blend_mode = int(style.blend_mode)
		else:
			picture.material = null
		picture.modulate = Color(1.0, 1.0, 1.0, float(style.alpha))
		order += 1
	# Detach before deferred deletion, including multiple updates in one frame.
	# Thus stale layers are neither reused nor drawn while deletion is queued.
	while node.get_child_count() > order:
		var unused: Node = node.get_child(node.get_child_count() - 1)
		node.remove_child(unused)
		unused.queue_free()
	FRAME_HITCH.count("map.object_layer_nodes_created", created)
	# Holder-local drawn bounds of this frame, for the off-screen cull.
	var bounds := Rect2()
	for index_child: int in order:
		var shown: Sprite2D = node.get_child(index_child) as Sprite2D
		var rect := Rect2(shown.position, shown.texture.get_size())
		bounds = rect if index_child == 0 else bounds.merge(rect)
	node.set_meta("bounds", bounds)

func _process(delta: float) -> void:
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_tick_carry += maxf(delta, 0.0)
	if _tick_carry + 0.0005 >= animation_step:
		var step: float = _tick_carry
		_tick_carry = 0.0
		_process_step(step)
	else:
		FRAME_HITCH.count("map.object_ticks_skipped")
	FRAME_HITCH.add_self("map_objects", hitch_started, hitch_nested)

## The camera view in this node's coordinates, or an empty rect without one.
func _local_view() -> Rect2:
	if not offscreen_culling or not is_inside_tree(): return Rect2()
	var screen: Rect2 = get_viewport_rect()
	if not screen.has_area(): return Rect2()
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var view := Rect2(inverse * screen.position, Vector2.ZERO)
	for point: Vector2 in [Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y)]:
		view = view.expand(inverse * point)
	return view

## The animated placements this update advances (all of them without a view).
func _advanced_nodes() -> Array[Node2D]:
	var view: Rect2 = _local_view()
	if not view.has_area(): return _animated_nodes
	if _cull_view.has_area() and _cull_view.encloses(view.grow(CULL_MARGIN - CULL_KEEP)): return _shown_animated
	var started: int = FRAME_HITCH.now()
	_cull_view = view.grow(CULL_MARGIN)
	_shown_animated.clear()
	for node: Node2D in _animated_nodes:
		var bounds: Variant = node.get_meta("bounds") if node.has_meta("bounds") else null
		if not bounds is Rect2 or _cull_view.intersects(Rect2(node.position + (bounds as Rect2).position, (bounds as Rect2).size).grow(1.0)):
			_shown_animated.append(node)
	FRAME_HITCH.count("map.object_cull_rebuilds")
	FRAME_HITCH.detail("map.object_cull", started)
	return _shown_animated

func _process_step(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	# A refresh waiting only for worker results repeats once one arrived.
	if _pending_refresh and (_waiting_serial < 0 or LOADER.serial != _waiting_serial or not LOADER.busy()): refresh(_records, _malformed)
	# Check the live cached record per visible source ID, including static IDs:
	# a replacement or static/animated transition must take effect this tick.
	var frames: Dictionary = {}
	for id: int in _placement_sprite_ids:
		var sprite: Dictionary = _sprites.get(id, {})
		if sprite.get("ok", false) and not sprite.static:
			frames[id] = _frame_index(sprite)
	var active_ids: Array = frames.keys()
	if active_ids != _animation_ids:
		_animation_ids = active_ids
		_animated_nodes.clear()
		_cull_view = Rect2()
		# Preserve dense source order, even for interleaved duplicate IDs.
		if not frames.is_empty():
			FRAME_HITCH.count("map.object_index_holders_scanned", _nodes.size())
			for node: Node2D in _nodes:
				if frames.has(int(node.get_meta("sprite_id"))): _animated_nodes.append(node)
	var advanced: Array[Node2D] = _advanced_nodes()
	for node: Node2D in advanced:
		var id: int = int(node.get_meta("sprite_id"))
		_show(node, _sprites[id], int(frames[id]))
	FRAME_HITCH.count("map.object_timeline_samples", frames.size())
	FRAME_HITCH.count("map.object_placements_visited", advanced.size())
	FRAME_HITCH.count("map.object_placements_culled", _animated_nodes.size() - advanced.size())
	FRAME_HITCH.count("map.object_sprite_states_checked", _placement_sprite_ids.size())
