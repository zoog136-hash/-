extends Node2D
## Opt-in inspection of literal source pixels. This is NOT an approved compositor.
## No AnimationCatalog overrides, procedural transforms or gameplay hit clocks.
var _record: Dictionary = {}
var _root: String = ""
var _textures: Dictionary = {}
var _layers: Array[Sprite2D] = []
var _role: String = "idle"
var _clock: float = 0.0
var _sequence: int = -1
var _source_attack: bool = false
var _attack_completed: bool = false
var last_source_frame: int = -1

func configure(key: String, manifest_path: String) -> bool:
	clear()
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or int(parsed.get("schema", 0)) != 1: return false
	if str(parsed.get("mode", "")) != "literal_body_shadow_inspection_only": return false
	var records: Dictionary = parsed.get("records", {})
	if not records.has(key): return false
	var candidate: Dictionary = records[key]
	var tracks: Dictionary = candidate.get("tracks", {})
	_root = manifest_path.get_base_dir()
	if not tracks.has("idle"): return false
	var layer_count: int = 0
	for role: String in ["idle", "walk", "run", "attack"]:
		if not tracks.has(role): continue
		var track: Dictionary = tracks[role]
		var directions: Array = track.get("directions", [])
		if directions.size() != 8:
			clear()
			return false
		for frames: Array in directions:
			if frames.is_empty():
				clear()
				return false
			for frame: Dictionary in frames:
				if float(frame.get("duration", 0.0)) <= 0.0:
					clear()
					return false
				var frame_layers: Array = frame.get("layers", [])
				if frame_layers.is_empty():
					clear()
					return false
				layer_count = maxi(layer_count, frame_layers.size())
				for layer: Dictionary in frame_layers:
					var path: String = str(layer.get("path", ""))
					if path.is_absolute_path() or ".." in path.split("/"):
						clear()
						return false
					if not _textures.has(path):
						var image: Image = Image.load_from_file(_root.path_join(path))
						if image == null or image.is_empty():
							clear()
							return false
						_textures[path] = ImageTexture.create_from_image(image)
	_record = candidate
	for index: int in range(layer_count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_layers.append(sprite)
	visible = true
	return true

func clear() -> void:
	_record = {}
	_textures.clear()
	for sprite: Sprite2D in _layers:
		sprite.free()
	_layers.clear()
	_role = "idle"
	_clock = 0.0
	_sequence = -1
	_source_attack = false
	_attack_completed = false
	last_source_frame = -1
	hide()

func installed() -> bool:
	return not _record.is_empty()

func cancel_source_attack() -> void:
	# Manual movement calls player.cancel_attack every tick, even without an attack.
	# Preserve the locomotion clock in that case.
	if not _source_attack and _role != "attack": return
	_source_attack = false
	_attack_completed = false
	_role = "idle"
	_clock = 0.0

func advance_source(delta: float, state: String, facing: int, sequence: int, gameplay_active: bool) -> void:
	if not installed(): return
	if sequence != _sequence and (gameplay_active or state in ["attack", "recovery"]) and _record.tracks.has("attack"):
		_sequence = sequence
		_source_attack = true
		_attack_completed = false
		_role = "attack"
		_clock = 0.0
	var requested: String = state if state in ["walk", "run"] else "idle"
	if _source_attack:
		requested = "attack"
	elif gameplay_active and _attack_completed:
		requested = "attack"
	if not _record.tracks.has(requested): requested = "idle"
	if requested != _role:
		_role = requested
		_clock = 0.0
	_clock += maxf(0.0, delta)
	# Visual inspection maps front bit5 to game S2. Keep this explicit and unapproved.
	var source_direction: int = posmod(facing + 3, 8)
	var track: Dictionary = _record.tracks[_role]
	var frames: Array = track.directions[source_direction]
	var total: float = 0.0
	for item: Dictionary in frames: total += float(item.duration)
	var time: float = fmod(_clock, total) if bool(track.loop) else minf(_clock, total)
	var selected: Dictionary = frames[-1]
	for item: Dictionary in frames:
		if time < float(item.duration):
			selected = item
			break
		time -= float(item.duration)
	if _role == "attack" and _clock >= total:
		_source_attack = false
		_attack_completed = true
	last_source_frame = int(selected.source_frame)
	for index: int in range(_layers.size()):
		_layers[index].visible = index < selected.layers.size()
		if not _layers[index].visible: continue
		var layer: Dictionary = selected.layers[index]
		_layers[index].texture = _textures[str(layer.path)]
		_layers[index].position = Vector2(float(layer.offset[0]), float(layer.offset[1]))
