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
var _clock: float = 0.0
var _stats: Dictionary = {}

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
	_records = records
	for node: Node2D in _nodes: node.queue_free()
	_nodes.clear()
	var drawn: int = 0
	var unresolved: Dictionary = {}
	for row: Dictionary in records:
		if drawn >= MAX_DRAWN: break
		var sprite: Dictionary = _sprite(int(row.sprite_id))
		if not sprite.ok:
			unresolved[str(row.sprite_id)] = sprite.get("error", "unresolved")
			continue
		var node := Node2D.new()
		node.position = coordinates.to_world(Vector2(row.raw_x, row.raw_y), false)
		node.set_meta("sprite_id", int(row.sprite_id))
		node.set_meta("frame", -1)
		add_child(node)
		_nodes.append(node)
		_show(node, sprite, 0)
		drawn += 1
	_stats = {"policy":"OWN_BANK_ACTION3_DIRECTION0_LOOP_V1","raw_records":records.size(),"malformed_tails":malformed,"drawn_records":drawn,"unresolved_records":records.size() - drawn,"unresolved_source_ids":unresolved,"cached_sprites":_sprites.size(),"texture_bytes":_texture_bytes,"playback_mode":_mode,"native_M_placement_action_timing_verified":false}

func metrics() -> Dictionary:
	return _stats.duplicate(true)

func _sprite(id: int) -> Dictionary:
	if _sprites.has(id): return _sprites[id]
	if _sprites.size() >= MAX_SPRITES: return {"ok":false,"error":"map_object_sprite_cache_full"}
	var result: Dictionary = _load_sprite(id)
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
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	_texture_bytes += bytes
	return texture

func _show(node: Node2D, sprite: Dictionary, index: int) -> void:
	if int(node.get_meta("frame")) == index: return
	node.set_meta("frame", index)
	FRAME_HITCH.count("map.object_frames_shown")
	for child: Node in node.get_children(): child.queue_free()
	var frame: Dictionary = sprite.frames[index]
	var order: int = 0
	for layer: Dictionary in frame.get("layers", []):
		if layer.has("client_null"): continue
		var attributes: Array = layer.get("source_attributes", [])
		var style: Dictionary = {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_MIX,"alpha":1.0}
		if not attributes.is_empty() or bool(layer.get("source_attributes_unresolved", false)):
			style = POLICY.effect(attributes, _mode)
			if bool(layer.get("source_attributes_unresolved", false)) or not bool(style.get("enabled", false)): continue
		var texture: Texture2D = _texture(layer)
		if texture == null: continue
		var picture := Sprite2D.new()
		picture.centered = false
		picture.texture = texture
		var offset: Variant = layer.get("offset", [0, 0])
		if offset is Array and offset.size() == 2: picture.position = Vector2(float(offset[0]), float(offset[1]))
		elif layer.has("member"):
			var rendered: Dictionary = _bank.render_layer(layer, false)
			if rendered.get("ok", false): picture.position = Vector2(rendered.offset)
		picture.z_index = -1 if layer.get("kind") == "shadow" else order
		if int(style.blend_mode) != CanvasItemMaterial.BLEND_MODE_MIX:
			var material := CanvasItemMaterial.new()
			material.blend_mode = int(style.blend_mode)
			picture.material = material
		picture.modulate.a = float(style.alpha)
		node.add_child(picture)
		order += 1
	FRAME_HITCH.count("map.object_layer_nodes_created", order)

func _process(delta: float) -> void:
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_step(delta)
	FRAME_HITCH.add_self("map_objects", hitch_started, hitch_nested)

func _process_step(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	# All placements use this same clock and immutable per-ID sprite record.
	# Share only this update's frame selection; never instance playback state.
	var frames: Dictionary = {}
	for node: Node2D in _nodes:
		var id: int = int(node.get_meta("sprite_id"))
		var sprite: Dictionary = _sprites.get(id, {})
		if sprite.get("ok", false) and not sprite.static:
			if not frames.has(id): frames[id] = _frame_index(sprite)
			_show(node, sprite, int(frames[id]))
	FRAME_HITCH.count("map.object_timeline_samples", frames.size())
	FRAME_HITCH.count("map.object_placements_visited", _nodes.size())
