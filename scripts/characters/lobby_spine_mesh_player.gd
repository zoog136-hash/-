extends Node2D
## Indexed meshes evaluated from verified Spine 3.6 source by the separate baker.
## This contains no skeletal evaluator, replacement images or original-layout claim.
## Sampling and alpha policy belong to the preview, not recovered client behavior.
const SCHEMA := "twilight.spine36.mesh.v1"
const MAJOR_MINOR := "3.6"
const MAX_PAGES := 128
const MAX_CLIPS := 64
const MAX_FRAMES := 72001
const MAX_BATCHES := 4096
const MAX_VERTICES := 262144
const MAX_GEOMETRY_VALUES := 64000000
const MAX_UNIQUE_GEOMETRY_VALUES := 16000000
const MAX_GEOMETRIES := 16384
const MAX_COORDINATE := 10000000.0
const TIME_EPSILON := 0.0001
const BLENDS := ["normal", "additive", "multiply", "screen"]
const VERIFIED_GL_HASH := "ed1daf0bf001b61586d9930840f2f1394092c079"
const SOURCE_BLEND = preload("res://scripts/ui/original_ui/source_blend.gd")

class MeshBackBuffer extends BackBufferCopy:
	var target: MeshInstance2D
	var local_bounds := Rect2()
	func _enter_tree() -> void:
		copy_mode = COPY_MODE_VIEWPORT if SOURCE_BLEND.screen_copy_available else COPY_MODE_DISABLED
		if not RenderingServer.frame_pre_draw.is_connected(_sync): RenderingServer.frame_pre_draw.connect(_sync)
	func _exit_tree() -> void:
		if RenderingServer.frame_pre_draw.is_connected(_sync): RenderingServer.frame_pre_draw.disconnect(_sync)
	func _sync() -> void:
		if not SOURCE_BLEND.screen_copy_available or not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree() or not local_bounds.has_area():
			copy_mode = COPY_MODE_DISABLED
			return
		var version: Dictionary = Engine.get_version_info()
		var supported: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility" and str(version.get("hash","")) == "ed1daf0bf001b61586d9930840f2f1394092c079"
		if not supported or target.get_tree().is_physics_interpolation_enabled():
			copy_mode = COPY_MODE_VIEWPORT
			return
		var parent: Node = target
		while parent != null and not parent is Viewport:
			if parent is CanvasGroup or parent.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON or (parent is CanvasItem and parent.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED):
				copy_mode = COPY_MODE_VIEWPORT
				return
			parent = parent.get_parent()
		var transform: Transform2D = target.get_viewport_transform() * target.get_global_transform()
		if not transform.is_finite():
			copy_mode = COPY_MODE_VIEWPORT
			return
		var bounds: Rect2 = transform * local_bounds
		if not bounds.is_finite() or not bounds.has_area():
			copy_mode = COPY_MODE_VIEWPORT
			return
		var first: Vector2 = bounds.position.floor() - Vector2.ONE
		var last: Vector2 = bounds.end.ceil() + Vector2.ONE
		rect = Rect2(first,last-first)
		copy_mode = COPY_MODE_RECT

## Hosts may lower these limits; input data cannot raise the hard caps.
var geometry_value_budget: int = MAX_GEOMETRY_VALUES
var unique_geometry_value_budget: int = MAX_UNIQUE_GEOMETRY_VALUES
var _unique_geometry_values := 0
var _geometry_count := 0
var _configured := false
var _playing := false
var _repeat := false
var _time := 0.0
var _clip := ""
var _frame_index := -1
var _source: Dictionary = {}
var _pages: Dictionary = {}
var _clips: Dictionary = {}
var _setup: Dictionary = {}
var _pool: Array[Dictionary] = []
var _shaders: Dictionary = {}
var _blend_policy_state: int = -1
var _bounds := Rect2()
var _has_bounds := false
var _pma := false
var _values := 0
var _poses := 0
var _error := ""
var _draw_updates := 0

func _ready() -> void:
	set_process(_playing)

func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_refresh_blend_policy): RenderingServer.frame_pre_draw.connect(_refresh_blend_policy)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_refresh_blend_policy): RenderingServer.frame_pre_draw.disconnect(_refresh_blend_policy)
	stop()

func stop() -> void:
	_playing = false
	set_process(false)

func clear() -> void:
	stop()
	for entry: Dictionary in _pool:
		var group: Node = entry.group
		if group.get_parent() == self: remove_child(group)
		group.queue_free()
	_pool.clear()
	_shaders.clear()
	_blend_policy_state = -1
	_pages.clear()
	_clips.clear()
	_setup.clear()
	_source.clear()
	_configured = false
	_repeat = false
	_time = 0.0
	_clip = ""
	_frame_index = -1
	_bounds = Rect2()
	_has_bounds = false
	_draw_updates = 0
	_pma = false
	_values = 0
	_poses = 0
	_unique_geometry_values = 0
	_geometry_count = 0
	_error = ""

func _fail(code: String) -> Dictionary:
	_error = code
	return {"ok":false,"error":code}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for index: int in value.length():
		if value.unicode_at(index) not in range(48,58) and value.unicode_at(index) not in range(97,103): return false
	return true

static func _version(value: Variant) -> bool:
	if not value is String or value.length() > 64: return false
	var parts: PackedStringArray = value.split(".")
	if parts.size() != 3 or parts[0] != "3" or parts[1] != "6" or parts[2].is_empty(): return false
	for index: int in parts[2].length():
		if parts[2].unicode_at(index) < 48 or parts[2].unicode_at(index) > 57: return false
	return true

static func _page_path(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 1024 or not value.begins_with("UI/"): return false
	if value.contains("\\") or value.contains(":"): return false
	for index: int in value.length():
		if value.unicode_at(index) < 32: return false
	for component: String in value.split("/"):
		if component in ["", ".", ".."]: return false
	return true

func configure(data: Dictionary, pages: Dictionary) -> Dictionary:
	clear()
	_error = ""
	_values = 0
	_poses = 0
	if not _integer(geometry_value_budget,1,MAX_GEOMETRY_VALUES) or not _integer(unique_geometry_value_budget,1,MAX_UNIQUE_GEOMETRY_VALUES): return _fail("spine_mesh_budget_policy")
	if data.get("schema") != SCHEMA or data.get("coordinate_space") != "godot_y_down": return _fail("spine_mesh_schema_or_coordinates")
	if not data.get("premultiplied_alpha") is bool: return _fail("spine_mesh_alpha_policy_required")
	_pma = data.premultiplied_alpha
	var source: Variant = data.get("source")
	if not source is Dictionary or not _sha(source.get("json_sha256")) or not _sha(source.get("atlas_sha256")): return _fail("spine_mesh_source_identity")
	var version: Variant = source.get("spine_version")
	if not _version(version): return _fail("spine_mesh_source_version")
	var declared: Variant = source.get("pages")
	if not declared is Dictionary or declared.is_empty() or declared.size() > MAX_PAGES or declared.size() != pages.size(): return _fail("spine_mesh_page_set")
	var page_values: Dictionary = {}
	for page: Variant in declared:
		if not _page_path(page) or not declared[page] is Dictionary or not _sha(declared[page].get("sha256")) or not _integer(declared[page].get("bytes"),1,33554432): return _fail("spine_mesh_page_identity")
		var texture: Variant = pages.get(page)
		if not texture is Texture2D or texture.get_width() <= 0 or texture.get_height() <= 0 or texture.get_width() > 16384 or texture.get_height() > 16384: return _fail("spine_mesh_page_texture")
		page_values[page] = texture
	var input_clips: Variant = data.get("clips")
	if not input_clips is Dictionary or input_clips.is_empty() or input_clips.size() > MAX_CLIPS: return _fail("spine_mesh_clips")
	var input_geometries: Variant = data.get("geometries",{})
	if not input_geometries is Dictionary or input_geometries.size() > MAX_GEOMETRIES: return _fail("spine_mesh_geometry_templates")
	var geometries: Dictionary = {}
	for key: Variant in input_geometries:
		if not key is String or key.is_empty() or key.length() > 256 or not input_geometries[key] is Dictionary: return _fail("spine_mesh_geometry_id")
		var geometry: Dictionary = _topology(input_geometries[key],page_values,true)
		if not _error.is_empty(): return _fail(_error)
		geometries[key] = geometry
	_geometry_count = geometries.size()
	var setup: Dictionary = _pose(data.get("setup"),page_values,geometries)
	if not _error.is_empty(): return _fail(_error)
	var normalized: Dictionary = {}
	for name: Variant in input_clips:
		if not name is String or name.is_empty() or name.length() > 256: return _fail("spine_mesh_clip_name")
		var input: Variant = input_clips[name]
		if not input is Dictionary or not _number(input.get("duration")) or float(input.duration) < 0 or float(input.duration) > 600 or not _number(input.get("fps")) or float(input.fps) <= 0 or float(input.fps) > 240: return _fail("spine_mesh_clip_time")
		var frames: Variant = input.get("frames")
		if not frames is Array or frames.is_empty() or frames.size() > MAX_FRAMES or (float(input.duration) > 0.0 and frames.size() < 2): return _fail("spine_mesh_frame_count")
		var result: Array[Dictionary] = []
		var previous := -1.0
		var clip_bounds := Rect2()
		var clip_has_bounds := false
		for frame: Variant in frames:
			if not frame is Dictionary or not _number(frame.get("time")): return _fail("spine_mesh_frame_time")
			var time: float = float(frame.time)
			if result.size() == frames.size()-1 and not result.is_empty() and absf(time-float(input.duration)) <= TIME_EPSILON:
				time = float(input.duration)
			if time < 0 or time > float(input.duration) or time <= previous or (result.is_empty() and time != 0.0): return _fail("spine_mesh_frame_order")
			previous = time
			var pose: Dictionary = _pose(frame,page_values,geometries)
			if not _error.is_empty(): return _fail(_error)
			pose["time"] = time
			if pose.has_bounds:
				clip_bounds = pose.bounds if not clip_has_bounds else clip_bounds.merge(pose.bounds)
				clip_has_bounds = true
			result.append(pose)
		if absf(previous-float(input.duration)) > TIME_EPSILON: return _fail("spine_mesh_last_frame")
		if float(input.duration) == 0.0 and frames.size() != 1: return _fail("spine_mesh_zero_duration")
		normalized[name] = {"duration":float(input.duration),"fps":float(input.fps),"frames":result,"bounds":clip_bounds,"has_bounds":clip_has_bounds}
	# Never retain caller-owned mutable JSON arrays or build GPU objects before
	# the complete input has passed validation and bounded normalization.
	_source = {"json_sha256":source.json_sha256,"atlas_sha256":source.atlas_sha256,"spine_version":version}
	_pages = page_values
	_clips = normalized
	_setup = setup
	_configured = true
	_apply_pose(_setup)
	return {"ok":true,"source_sha256":_source.json_sha256,"supported_major_minor":MAJOR_MINOR,"autoplay_disabled":true}

func _reserve_values(count: int, unique: bool = false) -> bool:
	if count < 0 or count > geometry_value_budget - _values:
		_error = "spine_mesh_geometry_budget"; return false
	if unique and count > unique_geometry_value_budget - _unique_geometry_values:
		_error = "spine_mesh_unique_geometry_budget"; return false
	_values += count
	if unique: _unique_geometry_values += count
	return true

func _topology(input: Dictionary, pages: Dictionary, unique: bool) -> Dictionary:
	if not input.get("page") is String or not pages.has(input.page):
		_error = "spine_mesh_batch_page_or_blend"; return {}
	var uvs: Variant = input.get("uvs")
	var indices: Variant = input.get("indices")
	if not uvs is Array or not indices is Array or uvs.size() < 6 or uvs.size() % 2 != 0 or uvs.size()/2 > MAX_VERTICES or indices.size() < 3 or indices.size() % 3 != 0:
		_error = "spine_mesh_triangle_shape"; return {}
	if not _reserve_values(uvs.size()+indices.size(),unique): return {}
	var coords := PackedVector2Array()
	var topology := PackedInt32Array()
	var referenced := PackedInt32Array()
	var seen := PackedByteArray()
	coords.resize(uvs.size()/2);topology.resize(indices.size());seen.resize(coords.size())
	for index: int in coords.size():
		if not _number(uvs[index*2]) or not _number(uvs[index*2+1]) or float(uvs[index*2]) < -0.0001 or float(uvs[index*2]) > 1.0001 or float(uvs[index*2+1]) < -0.0001 or float(uvs[index*2+1]) > 1.0001:
			_error = "spine_mesh_uv_nonfinite_or_range"; return {}
		coords[index] = Vector2(float(uvs[index*2]),float(uvs[index*2+1]))
	for index: int in indices.size():
		if not _integer(indices[index],0,coords.size()-1): _error = "spine_mesh_triangle_index"; return {}
		var vertex: int = int(indices[index])
		topology[index] = vertex
		if not seen[vertex]:
			seen[vertex] = 1
			referenced.append(vertex)
	return {"page":input.page,"uvs":coords,"indices":topology,"referenced":referenced}

func _pose(value: Variant, pages: Dictionary, geometries: Dictionary = {}) -> Dictionary:
	_poses += 1
	if _poses > MAX_FRAMES or not value is Dictionary or not value.get("batches") is Array or value.batches.size() > MAX_BATCHES:
		_error = "spine_mesh_pose_budget_or_shape"
		return {}
	var batches: Array[Dictionary] = []
	var bounds := Rect2()
	var has_bounds := false
	for input: Variant in value.batches:
		if not input is Dictionary or input.get("blend") not in BLENDS:
			_error = "spine_mesh_batch_page_or_blend"; return {}
		var key: String = ""
		var geometry: Dictionary
		if input.has("geometry"):
			if not input.geometry is String or input.geometry.is_empty() or not geometries.has(input.geometry):
				_error = "spine_mesh_unknown_geometry"; return {}
			if input.has("page") or input.has("uvs") or input.has("indices"):
				_error = "spine_mesh_mixed_geometry"; return {}
			key = input.geometry
			geometry = geometries[key]
		else:
			geometry = _topology(input,pages,false)
			if not _error.is_empty(): return {}
		var positions: Variant = input.get("positions")
		if not positions is Array or positions.size() != geometry.uvs.size()*2:
			_error = "spine_mesh_triangle_shape"; return {}
		if not _reserve_values(positions.size()): return {}
		var points := PackedVector2Array()
		points.resize(positions.size()/2)
		for index: int in points.size():
			if not _number(positions[index*2]) or not _number(positions[index*2+1]) or absf(float(positions[index*2])) > MAX_COORDINATE or absf(float(positions[index*2+1])) > MAX_COORDINATE:
				_error = "spine_mesh_vertex_nonfinite_or_range"; return {}
			points[index] = Vector2(float(positions[index*2]),float(positions[index*2+1]))
		var color: Color = _color(input.get("color"))
		if not _error.is_empty(): return {}
		var dark := Color(0,0,0,0)
		if input.has("dark_color") and input.dark_color != null:
			dark = _color(input.dark_color)
			if not _error.is_empty(): return {}
		var local := Rect2()
		var first := true
		# Referenced vertex IDs are computed once with the shared topology. This
		# remains exact while avoiding repeated triangle-corner visits per pose.
		for index: int in geometry.referenced:
			if first: local = Rect2(points[index],Vector2.ZERO);first=false
			else: local = local.expand(points[index])
		if color.a > 0.0:
			bounds = local if not has_bounds else bounds.merge(local)
			has_bounds = true
		batches.append({"page":geometry.page,"blend":input.blend,"color":color,"dark":dark,"points":points,"uvs":geometry.uvs,"indices":geometry.indices,"geometry_key":key,"bounds":local})
	return {"batches":batches,"bounds":bounds,"has_bounds":has_bounds}

func _color(value: Variant) -> Color:
	if not value is Array or value.size() != 4:
		_error = "spine_mesh_color_shape";return Color()
	for channel: Variant in value:
		if not _number(channel) or float(channel)<0.0 or float(channel)>1.0:
			_error = "spine_mesh_color_nonfinite_or_range";return Color()
	return Color(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

func _shader(blend: String) -> Shader:
	var key: String = blend + ":" + str(_pma) + ":" + str(SOURCE_BLEND.screen_copy_available)
	if _shaders.has(key): return _shaders[key]
	var source_factor: String = "vec4(1.0)" if _pma else "vec4(source.a)"
	var destination_factor := "vec4(1.0-source.a)"
	if blend == "additive": destination_factor = "vec4(1.0)"
	elif blend == "multiply": source_factor = "destination"
	elif blend == "screen": source_factor = "vec4(1.0)";destination_factor = "vec4(1.0)-source"
	var shader := Shader.new()
	var render_mode := "blend_disabled"
	var destination_uniform := "uniform sampler2D mesh_destination : hint_screen_texture, repeat_disable, filter_nearest;"
	var output: String = "vec4 destination = textureLod(mesh_destination, SCREEN_UV, 0.0);\n    COLOR = clamp(source * %s + destination * %s, vec4(0.0), vec4(1.0));" % [source_factor,destination_factor]
	if not SOURCE_BLEND.screen_copy_available:
		destination_uniform = ""
		render_mode = "blend_premul_alpha" if _pma else "blend_mix"
		output = "COLOR = clamp(source, vec4(0.0), vec4(1.0));"
		if blend == "additive" or blend == "screen":
			# Screen has no exact canvas fixed blend: additive is a host approximation.
			render_mode = "blend_add"
			# PMA/additive and screen's ONE source factor must not gain another alpha weight.
			if _pma or blend == "screen": output = "COLOR = vec4(clamp(source.rgb, vec3(0.0), vec3(1.0)), 1.0);"
		elif blend == "multiply":
			render_mode = "blend_mul"
			output = "COLOR = vec4(clamp(source.rgb + vec3(1.0-source.a), vec3(0.0), vec3(1.0)), 1.0);"
	# Light/dark equation follows the Spine 3.6 two-colour reference. D.a is
	# the preview's PMA flag, not the source slot's otherwise unused dark alpha.
	shader.code = """shader_type canvas_item;
render_mode unshaded, %s;
%s
uniform vec4 mesh_light = vec4(1.0);
uniform vec4 mesh_dark = vec4(0.0);
uniform bool mesh_pma = false;
varying vec4 mesh_modulation;
void vertex() { mesh_modulation = COLOR; }
void fragment() {
    vec4 texel = texture(TEXTURE, UV);
    vec4 light = mesh_light * mesh_modulation;
    vec3 dark = mesh_dark.rgb * mesh_modulation.rgb;
    if (mesh_pma) { light.rgb *= light.a; dark *= light.a; }
    float dark_alpha = mesh_pma ? 1.0 : 0.0;
    vec4 source;
    source.a = texel.a * light.a;
    source.rgb = ((texel.a - 1.0) * dark_alpha + 1.0 - texel.rgb) * dark + texel.rgb * light.rgb;
    %s
}
""" % [render_mode,destination_uniform,output]
	_shaders[key] = shader
	return shader

func _refresh_blend_policy() -> void:
	# Also refresh stopped/setup poses when a host changes copy policy.
	var state: int = int(SOURCE_BLEND.screen_copy_available)
	if state == _blend_policy_state: return
	_blend_policy_state = state
	for entry: Dictionary in _pool:
		if str(entry.blend).is_empty(): continue
		var item: MeshInstance2D = entry.item
		var shader: Shader = _shader(entry.blend)
		if item.material.shader != shader: item.material.shader = shader
		entry.copy._sync()

func _new_entry() -> Dictionary:
	var group := Node2D.new()
	group.name = "SpineMeshBatch%d" % _pool.size()
	var copy := MeshBackBuffer.new()
	var item := MeshInstance2D.new()
	copy.target = item
	group.add_child(copy);group.add_child(item)
	add_child(group)
	return {"group":group,"copy":copy,"item":item,"points":PackedVector2Array(),"uvs":PackedVector2Array(),"indices":PackedInt32Array(),"blend":"","geometry_key":"","mesh":null}

func _apply_pose(pose: Dictionary) -> void:
	var batches: Array = pose.batches
	while _pool.size() < batches.size(): _pool.append(_new_entry())
	for index: int in _pool.size():
		var entry: Dictionary = _pool[index]
		var item: MeshInstance2D = entry.item
		if index >= batches.size():
			item.hide();entry.copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED
			continue
		var batch: Dictionary = batches[index]
		item.visible = batch.color.a > 0.0
		entry.copy.local_bounds = batch.bounds
		item.texture = _pages[batch.page]
		if entry.blend != batch.blend:
			var material := ShaderMaterial.new()
			material.shader = _shader(batch.blend)
			material.set_shader_parameter("mesh_pma",_pma)
			item.material = material
			entry.blend = batch.blend
		item.material.set_shader_parameter("mesh_light",batch.color)
		item.material.set_shader_parameter("mesh_dark",batch.dark)
		var same_reference: bool = not batch.geometry_key.is_empty() and batch.geometry_key == entry.geometry_key
		if entry.mesh == null or (not same_reference and (entry.uvs != batch.uvs or entry.indices != batch.indices or entry.points.size() != batch.points.size())):
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = batch.points
			arrays[Mesh.ARRAY_TEX_UV] = batch.uvs
			arrays[Mesh.ARRAY_INDEX] = batch.indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			item.mesh = mesh;entry.mesh = mesh
		elif entry.points != batch.points:
			entry.mesh.surface_update_vertex_region(0,0,batch.points.to_byte_array())
		entry.points=batch.points;entry.uvs=batch.uvs;entry.indices=batch.indices;entry.geometry_key=batch.geometry_key
	_bounds = pose.bounds
	_has_bounds = pose.has_bounds
	_refresh_blend_policy()
	_draw_updates += 1

func play_source_animation(name: String, repeat: bool = false) -> Dictionary:
	if not _configured or not _clips.has(name): return {"ok":false,"error":"spine_mesh_clip_unavailable"}
	_clip = name
	_repeat = repeat
	_time = 0.0
	_frame_index = 0
	_apply_pose(_clips[name].frames[0])
	_playing = float(_clips[name].duration) > 0.0
	set_process(_playing)
	return {"ok":true,"clip":name,"loop":repeat}

func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0: return {"ok":false,"error":"spine_mesh_delta_invalid"}
	if not _configured or not _playing: return {"ok":true,"advanced":false}
	var clip: Dictionary = _clips[_clip]
	var duration: float = clip.duration
	var next: float = _time + delta
	if not is_finite(next): return {"ok":false,"error":"spine_mesh_time_overflow"}
	if _repeat: _time = fmod(next,duration)
	else:
		_time = minf(next,duration)
		if _time >= duration: stop()
	var frames: Array = clip.frames
	var low := 0
	var high: int = frames.size()-1
	while low < high:
		var middle: int = (low+high+1)/2
		if float(frames[middle].time) <= _time: low=middle
		else: high=middle-1
	if low != _frame_index:
		_frame_index = low
		_apply_pose(frames[low])
	return {"ok":true,"advanced":true,"frame":_frame_index}

func _process(delta: float) -> void:
	advance(delta)

func get_preview_bounds() -> Rect2:
	if not _clip.is_empty() and _clips.has(_clip):
		return _clips[_clip].bounds if _clips[_clip].has_bounds else Rect2()
	return _bounds if _has_bounds else Rect2()

func playback_status() -> Dictionary:
	return {"configured":_configured,"playing":_playing,"clip":_clip,"loop":_repeat,"time":_time,"frame":_frame_index,"clips":_clips.keys(),"source_sha256":_source.get("json_sha256",""),"spine_version":_source.get("spine_version",""),"supported_major_minor":MAJOR_MINOR,"premultiplied_alpha":_pma,"batch_nodes":_pool.size(),"geometry_values":_values,"unique_geometry_values":_unique_geometry_values,"geometry_templates":_geometry_count,"poses":_poses,"draw_updates":_draw_updates,"bounds_scope":"sampled_clip_extent" if not _clip.is_empty() else "setup_extent","current_rendered_bounds":_bounds if _has_bounds else Rect2(),"original_render_verified":false,"original_lobby_layout_verified":false,"error":_error}
