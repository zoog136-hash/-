extends Node2D
## Literal SP2 effect frames; private pixels only, no icon/procedural substitute.
const CODEC = preload("res://scripts/monsters/base508_sp2_frames.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
var source_status: Dictionary = {}
var _root: String = ""
var _track: Dictionary = {}
var _clock: float = 0.0
var _facing: int = 0
var _layers: Array[Sprite2D] = []
var _mode: String = "strict"
var _last_frame: int = -1
var _decoded_pixels: int = 0
var _sprite_id: int = -1
var _action_id: int = -1

static func safe_relative(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains(":") and not path.contains("\\") and not ".." in path.split("/")
func configure(pack_root: String, sprite_id: int, action_id: int, facing: int, playback_mode: String = "strict") -> bool:
	clear()
	if sprite_id <= 0 or action_id != 0 or playback_mode not in ["strict","compatible"]: return false
	_root = pack_root; _facing = posmod(facing,8); _sprite_id=sprite_id; _action_id=action_id; _mode=playback_mode
	var path: String = _root.path_join("boss_vfx.json")
	if not FileAccess.file_exists(path): return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("kind","") != "base508_boss_literal_sp2_effects" or value.get("source_snapshot","") != "base508": return false
	var reference: Dictionary = value.get("models",{}).get(str(sprite_id),{})
	var relative: String = str(reference.get("path",""))
	if not safe_relative(relative) or not relative.begins_with("effects/") or not relative.ends_with(".json"): return false
	var model_path: String = _root.path_join(relative)
	if FileAccess.get_sha256(model_path) != str(reference.get("sha256","")): return false
	var model: Variant = JSON.parse_string(FileAccess.get_file_as_string(model_path))
	if not model is Dictionary or int(model.get("source_sprite_id",-1)) != sprite_id or model.get("source_snapshot","") != "base508": return false
	var tracks: Dictionary = POLICY.tracks(model,"overlay",playback_mode)
	_track = tracks.get("effect",{})
	if int(_track.get("source_action_id",-1)) != action_id or _track.get("directions",[]).size()!=8: return false
	var frames: Array = _track.directions[_facing]
	if frames.is_empty(): return false
	# A missing body direction stays unavailable; it does not invalidate a
	# different exact stored direction's clock. No direction is substituted.
	var rate: float = float(_track.get("effective_fps",0.0))
	var selected_ticks: float = 0.0
	for frame: Dictionary in frames: selected_ticks+=float(frame.get("source_ticks",0.0))
	if rate>0.0 and selected_ticks>0.0 and _track.get("timing_issues",[]).is_empty():
		_track["static_pending_timing"]=false
		_track["timing_origin"]="source_explicit_rate_requested_direction_only" if _track.get("fps")!=null else "compat_policy_rate_requested_direction_only_M_unverified"
	var layer_count: int = 0
	for frame: Dictionary in frames:
		if float(frame.get("source_ticks",-1.0)) < 0.0 or frame.get("layers",[]).is_empty() or frame.layers.size()>8: return false
		layer_count=maxi(layer_count,frame.layers.size())
		for layer: Dictionary in frame.layers:
			var packet: String = str(layer.get("path",""))
			if not safe_relative(packet) or not packet.begins_with("sp2/") or not packet.ends_with(".bin") or layer.get("codec","")!="base508_sp2_v1": return false
			if FileAccess.get_sha256(_root.path_join(packet))!=str(layer.get("sha256","")): return false
			if str(int(layer.get("layer_id",-1))) != packet.get_file().get_slice("-",0): return false
			if layer.get("relation","") == "body" and int(layer.get("layer_id",-1)) != int(model.get("body_id",-2)): return false
			if int(layer.get("source_direction_bit",-1)) not in range(8) or int(layer.get("source_frame_index",-1)) not in range(256): return false
	for index: int in range(layer_count):
		var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(sprite);_layers.append(sprite)
	source_status={"source_sprite_id":sprite_id,"source_action_id":action_id,"source_pixels_complete":bool(model.get("source_pixels_complete",false)),"source_gaps":model.get("source_gaps",[]),"playback_mode":playback_mode,"timing_origin":_track.get("timing_origin"),"native_FPS_verified":_track.get("fps")!=null,"native_blend_verified":false,"decoded_source_frames":0,"visible_source_layers":0}
	if not _sample(): clear();return false
	set_process(not bool(_track.get("static_pending_timing",true)))
	return true
func duration() -> float:
	if bool(_track.get("static_pending_timing",true)): return 0.0
	var total:float=0.0
	for frame:Dictionary in _track.directions[_facing]:total+=float(frame.get("duration",0.0))
	return total
func advance_effect(delta:float) -> void:
	if _track.is_empty():return
	_clock+=maxf(0.0,delta)
	_sample()
	var total:float=duration()
	if total>0.0 and _clock>=total:clear();queue_free()
func _process(delta:float) -> void:advance_effect(delta)
func _sample() -> bool:
	var frames:Array=_track.directions[_facing];var selected:Dictionary=frames[0];var index:int=0;var time:float=_clock
	if duration()>0.0:
		selected=frames[-1];index=frames.size()-1
		for i:int in range(frames.size()):
			if time<float(frames[i].get("duration",0.0)):selected=frames[i];index=i;break
			time-=float(frames[i].get("duration",0.0))
	if index==_last_frame:return true
	_last_frame=index;var visible_count:int=0
	for i:int in range(_layers.size()):
		var sprite:Sprite2D=_layers[i];sprite.hide()
		if i>=selected.layers.size():continue
		var layer:Dictionary=selected.layers[i]
		var decoded:Dictionary=CODEC.render(_root.path_join(str(layer.path)),str(layer.sha256),int(layer.source_direction_bit),int(layer.source_frame_index))
		if decoded.is_empty():return false
		var image:Image=decoded.image
		if image.get_width()!=int(layer.pixel_size[0]) or image.get_height()!=int(layer.pixel_size[1]) or int(decoded.offset[0])!=int(layer.offset[0]) or int(decoded.offset[1])!=int(layer.offset[1]):return false
		_decoded_pixels+=1
		sprite.texture=ImageTexture.create_from_image(image);sprite.position=Vector2(layer.offset[0],layer.offset[1])
		var style:Dictionary=POLICY.effect(layer.get("source_attributes",[]),_mode)
		if bool(style.get("enabled",false)):
			var material:=CanvasItemMaterial.new();material.blend_mode=int(style.blend_mode);sprite.material=material;sprite.modulate.a=float(style.alpha);sprite.show();visible_count+=1
	source_status["decoded_source_frames"]=_decoded_pixels;source_status["visible_source_layers"]=visible_count;source_status["source_frame_index"]=selected.source_frame
	return true
func clear() -> void:
	set_process(false)
	for sprite:Sprite2D in _layers:
		if is_instance_valid(sprite):sprite.free()
	_layers.clear();_track.clear();_clock=0.0;_last_frame=-1;_decoded_pixels=0
