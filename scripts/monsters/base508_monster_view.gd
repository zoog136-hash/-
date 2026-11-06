extends Node2D
## Literal original body/shadow layers. Source timing remains separate from damage.
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const PACK_CACHE = preload("res://scripts/monsters/base508_monster_pack_cache.gd")
const SP2 = preload("res://scripts/monsters/base508_sp2_frames.gd")
const TEXTURE_BUDGET_BYTES: int = 96 * 1024 * 1024
const GPU_ACTOR_TEXTURE = preload("res://scripts/resources/gpu_actor_texture.gd")
static var _textures: Dictionary = {}
static var _texture_order: Array[String] = []
static var _texture_costs: Dictionary = {}
static var _texture_bytes: int = 0
static var _materials: Dictionary = {}
var attachment_status: Dictionary = {}
var _mode: String = "strict"
var _layers: Array[Sprite2D] = []
var _tracks: Dictionary = {}
var _root: String = ""
var _role: String = "idle"
var _clock: float = 0.0
var _sequence: int = -1
var _source_attack: bool = false
var last_source_frame: int = -1
var timing_status: Dictionary = {}
var source_state_status: Dictionary = {}
var _explicit_source_action: bool = false
var _explicit_sequence: int = -1
var _raw_source_tracks: Dictionary={}
var _actor_source: Dictionary={}
var _partial_source_directions: bool=false
var _fixed_source_slot: int=-1

func configure(record: Dictionary, manifest_path: String) -> bool:
	_root = manifest_path.get_base_dir()
	var manifest: Dictionary = PACK_CACHE.manifest(manifest_path)
	if not manifest is Dictionary or manifest.get("kind", "") != "base508_monster_pack" or manifest.get("source_snapshot", "") != "base508": return false
	var actor: Dictionary = PACK_CACHE.actor(manifest_path, int(record.get("source_m_npc_id", -1)))
	for pair: Array in [["npc_id", "source_m_npc_id"], ["sprite_id", "source_m_sprite_id"]]:
		if int(actor.get(pair[0], -1)) != int(record.get(pair[1], -2)): return false
	var context_allowed: bool = false
	for context: Dictionary in actor.get("source_contexts", [actor]):
		if int(context.get("spawn_view_id", -1)) == int(record.get("source_m_spawn_view_id", -2)) and int(context.get("territory_link_id", -1)) == int(record.get("source_m_territory_link_id", -2)):
			context_allowed = true
	if not context_allowed: return false
	var install = preload("res://scripts/lineagem_pack_install.gd")
	var settings_root: String = _root if FileAccess.file_exists(install.resolve_file(_root, "playback_settings.json")) else install.active_root()
	_mode = POLICY.mode(settings_root)
	_raw_source_tracks=actor.get("tracks",{})
	_actor_source=actor
	_partial_source_directions=int(actor.get("source_partial_direction_contract",0))==1
	_fixed_source_slot=-1
	if _partial_source_directions and bool(record.get("source_m_visual_only",false)):
		var fixed: int=int(record.get("source_m_fixed_source_slot",-1))
		if fixed>=0 and fixed<8:
			for raw: Dictionary in _raw_source_tracks.values():
				if raw.get("directions",[]).size()!=8 or raw.directions[fixed].is_empty(): return false
			_fixed_source_slot=fixed
	_tracks = PACK_CACHE.prepared_tracks(manifest_path, int(record.source_m_npc_id), actor, _mode)
	var layer_count: int = 0
	var roles: Array = _tracks.keys() if int(actor.get("source_capability_contract",0))==1 else ["idle", "walk", "attack", "hit", "death"]
	if roles.is_empty() and _raw_source_tracks.is_empty(): return false
	for role: String in roles:
		var track: Dictionary = _tracks.get(role, {})
		if track.get("directions", []).size() != 8: return false
		var has_source_direction: bool=false
		timing_status[role] = {"effective_fps":track.get("effective_fps"), "origin":track.get("timing_origin"), "source_fps":track.get("fps")}
		for frames: Array in track.directions:
			if frames.is_empty():
				if _partial_source_directions: continue
				return false
			has_source_direction=true
			for frame: Dictionary in frames:
				if frame.get("layers", []).is_empty(): return false
				layer_count = maxi(layer_count, frame.layers.size())
				for layer: Dictionary in frame.layers:
					var path: String = str(layer.path)
					if path.is_absolute_path() or ".." in path.split("/"): return false
					var full: String = _root.path_join(path)
					if not PACK_CACHE.verify_pixel(full, str(layer.get("sha256", ""))): return false
					if layer.get("relation", "") == "SPR105.clothes":
						attachment_status[str(layer.layer_id)] = POLICY.effect(layer.get("source_attributes", []), _mode)
		if not has_source_direction: return false
	for index: int in range(layer_count):
		var layer := Sprite2D.new()
		layer.centered = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(layer)
		_layers.append(layer)
	if _tracks.has("idle"):
		advance(0.0, "idle", 2, 0, false, false)
	else:
		_unavailable("idle", "source_default_state_not_declared; explicit_source_action_required")
	return true

func duration(role: String) -> float:
	var track: Dictionary = _tracks.get(role, {})
	if bool(track.get("static_pending_timing", true)): return 0.0
	var result: float = 0.0
	for frame: Dictionary in track.directions[0]: result += float(frame.get("duration", 0.0))
	return result

func advance(delta: float, state: String, facing: int, sequence: int, attacking: bool, dead: bool) -> void:
	if _tracks.is_empty(): return
	if _explicit_source_action: return
	if sequence != _sequence and attacking:
		_sequence = sequence
		_source_attack = true
		_role = "attack"
		_clock = 0.0
	var role: String = "death" if dead else ("attack" if _source_attack or attacking else ("hit" if state == "hit" else ("walk" if state in ["walk", "run", "patrol", "chase"] else "idle")))
	if state == "run" and role == "walk" and _tracks.has("run"): role = "run"
	if not _tracks.has(role):
		_unavailable(role,"source_state_unavailable; no_substitute_animation")
		return
	if role != _role:
		_role = role
		_clock = 0.0
	_clock += maxf(delta, 0.0)
	_render_track(facing)

func _render_track(facing: int) -> void:
	source_state_status={"status":"authored_source_track","role":_role}
	var track: Dictionary = _tracks[_role]
	var source_slot: int=_fixed_source_slot if _fixed_source_slot>=0 else posmod(facing + 3, 8)
	var frames: Array = track.directions[source_slot]
	if frames.is_empty():
		_unavailable(_role,"source_direction_slot_unavailable; no_mirror_or_substitute")
		return
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
		var style: Dictionary = attachment_status.get(str(layer.layer_id), {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_MIX,"alpha":1.0})
		if not bool(style.get("enabled", false)):
			_layers[index].hide()
			continue
		var texture: Texture2D = _texture(_root.path_join(str(layer.path)), layer)
		if texture == null:
			_layers[index].hide()
			continue
		_layers[index].texture = texture
		_layers[index].modulate.a = float(style.get("alpha", 1.0))
		_layers[index].material = _material(int(style.get("blend_mode", CanvasItemMaterial.BLEND_MODE_MIX)))
		_layers[index].position = Vector2(float(layer.offset[0]), float(layer.offset[1]))

static func _texture(source_path: String, layer: Dictionary = {}) -> Texture2D:
	var packet: bool = layer.get("codec", "") == "base508_sp2_v1"
	var path: String = source_path + (":" + str(layer.get("source_direction_bit")) + ":" + str(layer.get("source_frame_index")) if packet else "")
	if _textures.has(path):
		_texture_order.erase(path)
		_texture_order.append(path)
		return _textures[path]
	var image: Image
	if packet:
		var decoded: Dictionary = SP2.render(source_path, str(layer.get("sha256", "")), int(layer.get("source_direction_bit", -1)), int(layer.get("source_frame_index", -1)))
		if decoded.is_empty(): return null
		image = decoded.image
	else:
		image = Image.load_from_file(source_path)
	if image == null or image.is_empty(): return null
	var texture: Texture2D = GPU_ACTOR_TEXTURE.from_image(image)
	var cost: int = GPU_ACTOR_TEXTURE.bytes_of(texture, image.get_width() * image.get_height() * 4)
	while not _texture_order.is_empty() and _texture_bytes + cost > TEXTURE_BUDGET_BYTES:
		var old: String = _texture_order.pop_front()
		_texture_bytes -= int(_texture_costs[old])
		_texture_costs.erase(old)
		_textures.erase(old)
	if cost <= TEXTURE_BUDGET_BYTES:
		_textures[path] = texture
		_texture_costs[path] = cost
		_texture_bytes += cost
		_texture_order.append(path)
	return texture

static func _material(blend_mode: int) -> CanvasItemMaterial:
	if not _materials.has(blend_mode):
		var material := CanvasItemMaterial.new()
		material.blend_mode = blend_mode
		_materials[blend_mode] = material
	return _materials[blend_mode]

static func cache_bytes() -> int:
	return _texture_bytes

func _unavailable(role: String, reason: String) -> void:
	_explicit_source_action=false
	if role=="attack": _source_attack=false
	_role=role
	_clock=0.0
	source_state_status={"status":"unavailable","requested_role":role,"reason":reason}
	last_source_frame=-1
	for sprite: Sprite2D in _layers: sprite.hide()
func supports_state(role: String) -> bool:
	return _tracks.has(role)
func advance_source_action(action_id: int, delta: float, facing: int, sequence: int) -> bool:
	var selected: String=""
	for key: String in _raw_source_tracks:
		if int(_raw_source_tracks[key].get("source_action_id",-1))==action_id: selected=key;break
	if not selected.is_empty() and not _tracks.has(selected):
		if not _prepare_source_track(selected): return false
	if selected.is_empty():
		_unavailable("source_action_"+str(action_id),"authored_source_action_unavailable")
		return false
	if not _explicit_source_action or _explicit_sequence!=sequence or _role!=selected: _clock=0.0
	_explicit_source_action=true
	_explicit_sequence=sequence
	_role=selected
	_clock+=maxf(delta,0.0)
	_render_track(facing)
	return source_state_status.get("status","")=="authored_source_track"
func clear_source_action() -> void:
	_explicit_source_action=false
	_explicit_sequence=-1
	_clock=0.0
func source_action_duration(action_id: int) -> float:
	for key: String in _tracks:
		if int(_tracks[key].get("source_action_id",-1))==action_id: return duration(key)
	return 0.0

func _prepare_source_track(key: String) -> bool:
	var raw: Dictionary=_raw_source_tracks.get(key,{})
	if raw.is_empty() or raw.get("directions",[]).size()!=8: return false
	var count: int=0
	var has_source_direction: bool=false
	for frames: Array in raw.directions:
		if frames.is_empty():
			if _partial_source_directions: continue
			return false
		has_source_direction=true
		for frame: Dictionary in frames:
			if frame.get("layers",[]).is_empty(): return false
			count=maxi(count,frame.layers.size())
			for layer: Dictionary in frame.layers:
				var path: String=str(layer.get("path",""))
				if path.is_absolute_path() or ".." in path.split("/") or not PACK_CACHE.verify_pixel(_root.path_join(path),str(layer.get("sha256",""))): return false
				if layer.get("relation","")=="SPR105.clothes": attachment_status[str(layer.layer_id)]=POLICY.effect(layer.get("source_attributes",[]),_mode)
	if not has_source_direction: return false
	var payload: Dictionary=_actor_source.duplicate(false)
	payload["tracks"]={key:raw}
	_tracks[key]=POLICY.tracks(payload,"monster",_mode)[key]
	while _layers.size()<count:
		var sprite:=Sprite2D.new()
		sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite);_layers.append(sprite)
	return true
