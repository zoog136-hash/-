extends RefCounted
## Exact supplied M files; candidate raster/timing/blend is visibly configurable.
const EFFECT = preload("res://scripts/monsters/patch523_effect_sprite.gd")
var records: Dictionary = {}
var root_path: String = ""
var error: String = "not_installed"
var settings_path: String = "user://patch523_effect_settings.cfg"
var enabled: bool = false
var fallback_fps: float = 24.0
var opacity: float = 1.0
var visual_scale: float = 1.0
var additive: bool = true
var compose_children: bool = false

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK: return
	if int(config.get_value("effects","schema",0)) != 1: return
	enabled = bool(config.get_value("effects","enabled",false))
	fallback_fps = bounded(config.get_value("effects","fallback_fps",24.0),1,120,24)
	opacity = bounded(config.get_value("effects","opacity",1.0),0,1,1)
	visual_scale = bounded(config.get_value("effects","visual_scale",1.0),.25,2,1)
	additive = bool(config.get_value("effects","additive",true))
	compose_children = bool(config.get_value("effects","compose_children",false))

func bounded(value: Variant, low: float, high: float, fallback: float) -> float:
	if not value is int and not value is float: return fallback
	return clampf(float(value),low,high) if is_finite(float(value)) else fallback

func save_settings() -> Error:
	var config := ConfigFile.new()
	for key: String in ["enabled","fallback_fps","opacity","visual_scale","additive","compose_children"]:
		config.set_value("effects",key,get(key))
	config.set_value("effects","schema",1)
	# This visual preference is separate from progression/currency/save migration.
	return config.save(settings_path)

func load_pack(path: String, digest: String) -> bool:
	records.clear(); root_path = ""; error = "manifest_rejected"
	if digest.length() != 64 or not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 2*1024*1024 or FileAccess.get_sha256(path) != digest: return false
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or int(value.get("schema",0)) != 1 or value.get("kind") != "patch523_source_effect_frames" or value.get("source_snapshot") != "patch523": return false
	if value.get("mode") != "M_commandwise_RGB565_candidate" or value.get("native_runtime_verified") != false or not value.get("records") is Dictionary: return false
	if value.get("catalog_sha256") != "2d43c3da5e26afc917cb73e599181eb0c57d7982cee13e496576cd6d9bda808b": return false
	if value.records.size() > 70: return false
	for id: String in value.records:
		if not valid_row(value.records[id],id): return false
	records = value.records; root_path = path.get_base_dir(); error = ""
	return true

func valid_row(row: Variant, id: String, depth: int = 0) -> bool:
	if depth > 8: return false
	if not row is Dictionary or str(int(row.get("source_sprite_id",-1))) != id or int(row.get("source_action_id",-1)) != 0 or not row.get("frames") is Array: return false
	if row.frames.is_empty() or row.frames.size() > 256: return false
	var source_fps: Variant = row.get("source_fps")
	if source_fps != null and (not source_fps is int and not source_fps is float): return false
	if source_fps != null and (not is_finite(float(source_fps)) or float(source_fps) < 1 or float(source_fps) > 120): return false
	var ticks: float = 0
	for frame: Variant in row.frames:
		if not frame is Dictionary: return false
		var relative: String = str(frame.get("path",""))
		if relative.is_absolute_path() or ".." in relative.split("/") or relative.contains("\\") or relative.contains(":") or not relative.begins_with("frames/") or not relative.ends_with(".png"): return false
		if not frame.get("offset") is Array or frame.offset.size() != 2: return false
		for offset: Variant in frame.offset:
			if not offset is int and not offset is float: return false
			if not is_finite(float(offset)) or absf(float(offset)) > 16384: return false
		if int(frame.get("bytes",0)) <= 0 or int(frame.get("bytes",0)) > 4*1024*1024 or str(frame.get("sha256","")).length() != 64: return false
		var duration: float = float(frame.get("source_ticks",-1))
		if not is_finite(duration) or duration < 0 or duration > 10000: return false
		ticks += duration
	if ticks <= 0: return false
	var children: Variant = row.get("children",[])
	if not children is Array or children.size() > 8: return false
	for child: Variant in children:
		if not child is Dictionary or not valid_row(child,str(int(child.get("source_sprite_id",-1))),depth+1): return false
	return true

func make_effect(sprite_id: int, action: int = 0, remaining_bytes: int = 64*1024*1024) -> Node2D:
	if not enabled or action != 0 or not records.has(str(sprite_id)): return null
	if not compose_children and not records[str(sprite_id)].get("children",[]).is_empty(): return null
	if int(records[str(sprite_id)].get("runtime_rgba_bytes",64*1024*1024+1)) > remaining_bytes: return null
	var result = EFFECT.new()
	if not result.configure(root_path,records[str(sprite_id)],fallback_fps,opacity,visual_scale,additive):
		error = "frame_hash_or_size_rejected"; result.free(); return null
	result.set_meta("patch523_frame_bytes",result.decoded_budget)
	return result

func first_sprite(spell: Dictionary) -> int:
	for key: String in ["CasterEffectSpriteID","EffectSpriteID","EffectExplosionSpriteID","SuccessEffectSpriteID","FailEffectSpriteID"]:
		var id: int = int(spell.get(key,0))
		if records.has(str(id)) and (key != "EffectSpriteID" or int(spell.get("EffectSpriteActionNo",0)) == 0): return id
	return 0
