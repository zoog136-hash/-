extends Node2D
## Literal original body/shadow layers. Source timing remains separate from damage.
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
static var _textures: Dictionary = {}
var _layers: Array[Sprite2D] = []
var _tracks: Dictionary = {}
var _root: String = ""
var _role: String = "idle"
var _clock: float = 0.0
var _sequence: int = -1
var _source_attack: bool = false
var last_source_frame: int = -1
var timing_status: Dictionary = {}

func configure(record: Dictionary, manifest_path: String) -> bool:
	_root = manifest_path.get_base_dir()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("kind", "") != "base508_monster_pack" or manifest.get("source_snapshot", "") != "base508": return false
	var actor: Dictionary = manifest.get("records", {}).get(str(int(record.get("source_m_npc_id", -1))), {})
	for pair: Array in [["npc_id", "source_m_npc_id"], ["sprite_id", "source_m_sprite_id"], ["spawn_view_id", "source_m_spawn_view_id"], ["territory_link_id", "source_m_territory_link_id"]]:
		if int(actor.get(pair[0], -1)) != int(record.get(pair[1], -2)): return false
	var install = preload("res://scripts/lineagem_pack_install.gd")
	var settings_root: String = _root if FileAccess.file_exists(install.resolve_file(_root, "playback_settings.json")) else install.active_root()
	_tracks = POLICY.tracks(actor, "monster", POLICY.mode(settings_root))
	var layer_count: int = 0
	for role: String in ["idle", "walk", "attack", "hit", "death"]:
		var track: Dictionary = _tracks.get(role, {})
		if track.get("directions", []).size() != 8: return false
		timing_status[role] = {"effective_fps":track.get("effective_fps"), "origin":track.get("timing_origin"), "source_fps":track.get("fps")}
		for frames: Array in track.directions:
			if frames.is_empty(): return false
			for frame: Dictionary in frames:
				if frame.get("layers", []).is_empty(): return false
				layer_count = maxi(layer_count, frame.layers.size())
				for layer: Dictionary in frame.layers:
					var path: String = str(layer.path)
					if path.is_absolute_path() or ".." in path.split("/"): return false
					var full: String = _root.path_join(path)
					if not _textures.has(full):
						if FileAccess.get_sha256(full) != str(layer.get("sha256", "")): return false
						var image: Image = Image.load_from_file(full)
						if image == null or image.is_empty(): return false
						_textures[full] = ImageTexture.create_from_image(image)
	for index: int in range(layer_count):
		var layer := Sprite2D.new()
		layer.centered = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(layer)
		_layers.append(layer)
	advance(0.0, "idle", 2, 0, false, false)
	return true

func duration(role: String) -> float:
	var track: Dictionary = _tracks.get(role, {})
	if bool(track.get("static_pending_timing", true)): return 0.0
	var result: float = 0.0
	for frame: Dictionary in track.directions[0]: result += float(frame.get("duration", 0.0))
	return result

func advance(delta: float, state: String, facing: int, sequence: int, attacking: bool, dead: bool) -> void:
	if _tracks.is_empty(): return
	if sequence != _sequence and attacking:
		_sequence = sequence
		_source_attack = true
		_role = "attack"
		_clock = 0.0
	var role: String = "death" if dead else ("attack" if _source_attack or attacking else ("hit" if state == "hit" else ("walk" if state in ["walk", "run", "patrol", "chase"] else "idle")))
	if role != _role:
		_role = role
		_clock = 0.0
	_clock += maxf(delta, 0.0)
	var track: Dictionary = _tracks[_role]
	var frames: Array = track.directions[posmod(facing + 3, 8)]
	var total: float = duration(_role)
	var selected: Dictionary = frames[0]
	if total > 0.0:
		var time: float = fmod(_clock, total) if bool(track.loop) else minf(_clock, total)
		selected = frames[-1]
		for frame: Dictionary in frames:
			if time < float(frame.duration):
				selected = frame
				break
			time -= float(frame.duration)
	if _role == "attack" and (total <= 0.0 or _clock >= total): _source_attack = false
	last_source_frame = int(selected.source_frame)
	for index: int in range(_layers.size()):
		_layers[index].visible = index < selected.layers.size()
		if not _layers[index].visible: continue
		var layer: Dictionary = selected.layers[index]
		_layers[index].texture = _textures[_root.path_join(str(layer.path))]
		_layers[index].position = Vector2(float(layer.offset[0]), float(layer.offset[1]))
