extends Node2D
class_name TwilightSourceSPXPlayer

## One clock for body/shadow/clothing or effect layers. Events are cosmetic;
## combat damage remains exclusively owned by TwilightActorMotion.strike.
signal source_marker(sprite_id: String, source_frame: int)
signal sound_requested(sound_id: String)
signal finished

const MANIFEST := "res://data/external_spx/source_motion.json"
const PREFIX := "res://assets/external_spx/source_motion/"
static var _resources: Dictionary = {}
static var _manifest_cache: Dictionary = {}
const CACHE_LIMIT_BYTES := 96 * 1024 * 1024
static var _resource_order: Array[String] = []
static var _resource_costs: Dictionary = {}
static var _resource_bytes := 0
var _layers: Array[Sprite2D] = []
var _data: Dictionary = {}
var _action: Dictionary = {}
var _group := ""
var _elapsed := 0.0
var _rate := 24.0
var _running := false
var _loop := false
var _marker_sent := false
var _event_cursor := 0
var _source_direction := 0
var _track_name := ""
var _sprite_ids: Array[String] = []
var _audio: AudioStreamPlayer2D = null
var play_source_audio := false
var speed_scale := 1.0
var free_on_finish := true

static func clear_cache() -> void:
	_resources.clear()
	_manifest_cache.clear()
	_resource_order.clear()
	_resource_costs.clear()
	_resource_bytes = 0

static func read_manifest() -> Dictionary:
	if not _manifest_cache.is_empty(): return _manifest_cache
	if not FileAccess.file_exists(MANIFEST): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if value is Dictionary: _manifest_cache = value
	return _manifest_cache

static func frames_for(sprite_id: String, track_name: String = "") -> SpriteFrames:
	if not sprite_id.is_valid_int(): return null
	var key := sprite_id + ":" + track_name
	if _resources.has(key):
		_resource_order.erase(key)
		_resource_order.append(key)
		return _resources[key]
	var path := PREFIX + sprite_id + "/SpriteFrames.tres"
	if not track_name.is_empty():
		if not track_name.is_valid_filename(): return null
		var lazy := PREFIX + sprite_id + "/tracks/" + track_name + ".tres"
		if ResourceLoader.exists(lazy): path = lazy
	if not ResourceLoader.exists(path): return null
	var value := load(path) as SpriteFrames
	if value != null:
		var pages: Dictionary = {}
		var cost := 0
		for animation in value.get_animation_names():
			for i in range(value.get_frame_count(animation)):
				var texture := value.get_frame_texture(animation,i)
				if texture is AtlasTexture: texture = (texture as AtlasTexture).atlas
				if texture != null and not pages.has(texture.get_rid()):
					pages[texture.get_rid()] = true
					cost += texture.get_width()*texture.get_height()*4
		while not _resource_order.is_empty() and _resource_bytes + cost > CACHE_LIMIT_BYTES:
			var old: String = _resource_order.pop_front()
			_resource_bytes -= int(_resource_costs[old])
			_resource_costs.erase(old)
			_resources.erase(old)
		if cost <= CACHE_LIMIT_BYTES:
			_resources[key] = value
			_resource_order.append(key)
			_resource_costs[key] = cost
			_resource_bytes += cost
	return value

func configure(sprite_id: String, action_id: String, direction: int = 0, preview: bool = false) -> bool:
	var manifest := read_manifest()
	if manifest.is_empty() or direction < 0 or direction > 7: return false
	var entry: Dictionary = manifest.get("actors", {}).get(sprite_id, manifest.get("effects", {}).get(sprite_id, {}))
	if entry.is_empty() or not entry.get("actions", {}).has(action_id): return false
	# Unknown blend/order, game ID and attachment are never approved by loading.
	if not preview and not bool(entry.get("production_approved", false)): return false
	var action: Dictionary = entry.actions[action_id]
	var source_direction: int = int(manifest.direction_map[direction]) if action.directional else 0
	var track_name := "source_action_%s_dir_%d" % [action_id, direction if action.directional else 0]
	var sprite_ids: Array[String] = []
	var resources: Array[SpriteFrames] = []
	for layer_id: Variant in entry.get("layers", [sprite_id]):
		var id := str(layer_id)
		var layer_data: Dictionary = manifest.get("groups",{}).get(id,{})
		if not preview and not bool(layer_data.get("blend_verified",false)): return false
		var resource := frames_for(id,track_name)
		if resource == null or not resource.has_animation(track_name): return false
		if resource.get_frame_count(track_name) == 0: return false
		if not resources.is_empty():
			var body := resources[0]
			if resource.get_frame_count(track_name) != body.get_frame_count(track_name): return false
			if resource.get_animation_speed(track_name) != body.get_animation_speed(track_name): return false
			for index in range(body.get_frame_count(track_name)):
				if resource.get_frame_duration(track_name,index) != body.get_frame_duration(track_name,index): return false
		resources.append(resource)
		sprite_ids.append(id)
	# All references preflight before replacing an already-playing candidate.
	stop()
	for child in _layers:
		remove_child(child)
		child.queue_free()
	_layers.clear()
	_data = manifest
	_action = action
	_group = sprite_id
	_source_direction = source_direction
	_track_name = track_name
	_sprite_ids = sprite_ids
	_rate = float(manifest.tick_rate)
	for i in range(resources.size()):
		var sprite := Sprite2D.new()
		sprite.centered = false
		if manifest.get("actors",{}).has(sprite_id):
			# The A3 shadow reference is explicit. Clothing order/blending is
			# still a preview candidate, never a production approval.
			sprite.z_index = -1 if i == 1 else (0 if i == 0 else 1)
		var bounds: Array = manifest.groups[sprite_ids[i]].bounds
		sprite.position = Vector2(float(bounds[0]), float(bounds[1]))
		# Normal preview only. attr8/128 and source tile types are retained in
		# metadata, never guessed as additive. Production remains gated above.
		sprite.set_meta("source_attributes", manifest.groups[sprite_ids[i]].attributes)
		var layer_data: Dictionary = manifest.groups[sprite_ids[i]]
		if bool(layer_data.get("blend_verified",false)):
			var modes := {"mix":CanvasItemMaterial.BLEND_MODE_MIX,"add":CanvasItemMaterial.BLEND_MODE_ADD,
				"multiply":CanvasItemMaterial.BLEND_MODE_MUL,"subtract":CanvasItemMaterial.BLEND_MODE_SUB,
				"premult_alpha":CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA}
			var mode: String = str(layer_data.get("blend",""))
			if modes.has(mode):
				var material := CanvasItemMaterial.new()
				material.blend_mode = modes[mode]
				sprite.material = material
		sprite.set_meta("source_sprite_id", sprite_ids[i])
		sprite.set_meta("frames", resources[i])
		add_child(sprite)
		_layers.append(sprite)
	return true

func play(looping: bool = false) -> void:
	if _action.is_empty(): return
	if _audio != null: _audio.stop()
	_elapsed = 0.0
	_event_cursor = 0
	_marker_sent = false
	_loop = looping
	_running = true
	_sample(0.0)
	_dispatch_events(0.0)

func stop() -> void:
	_running = false
	if _audio != null: _audio.stop()
	_elapsed = 0.0
	_event_cursor = 0
	_marker_sent = false

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not _running or delta <= 0.0 or speed_scale <= 0.0: return
	var total := float(_action.total_ticks)
	var next := _elapsed + delta * _rate * speed_scale
	# Visit every event even across a long tick; no duplicate hit marker per play.
	_dispatch_events(minf(next, total))
	if next >= total:
		if _loop:
			_elapsed = fposmod(next, total)
			_event_cursor = 0
			_dispatch_events(_elapsed)
		else:
			_elapsed = total
			_sample(total)
			_running = false
			finished.emit()
			if free_on_finish: queue_free()
			return
	else:
		_elapsed = next
	_sample(_elapsed)

func _dispatch_events(tick: float) -> void:
	var at := 0.0
	for i in range(_action.frames.size()):
		var record: Dictionary = _action.frames[i]
		if i >= _event_cursor:
			if at > tick: return
			_event_cursor = i + 1
			if record.hit_marker and not _marker_sent:
				_marker_sent = true
				source_marker.emit(_group, int(record.frame))
			for sound_id: Variant in record.get("sound_ids", []):
				sound_requested.emit(str(sound_id))
				if play_source_audio: _play_sound(str(sound_id))
		at += float(record.ticks)

func _play_sound(id: String) -> void:
	if not id.is_valid_int(): return
	var path := "res://assets/external_spx/source_sounds/" + id + ".ogg"
	# Missing10831/10832 or actor footsteps never stop visual playback.
	if not ResourceLoader.exists(path): return
	var key := "sound:" + id
	if not _resources.has(key): _resources[key] = load(path) as AudioStream
	if _resources[key] == null: return
	if _audio == null:
		_audio = AudioStreamPlayer2D.new()
		add_child(_audio)
	_audio.stream = _resources[key]
	_audio.play()

func _sample(tick: float) -> void:
	var at := 0.0
	var index := -1
	var selected := 0
	for record: Dictionary in _action.frames:
		if int(record.ticks) == 0: continue
		index += 1
		selected = index
		at += float(record.ticks)
		if tick < at: break
	for layer in _layers:
		var resource: SpriteFrames = layer.get_meta("frames")
		layer.texture = resource.get_frame_texture(_track_name, selected)
