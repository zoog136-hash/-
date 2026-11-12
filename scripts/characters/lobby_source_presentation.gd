extends Control
## A TWILIGHT preview host for separately verified original layers. Definitions,
## available bytes, mounted nodes and visual acceptance are distinct states.
## Optional verified mesh samples use the installed player; no substitute art.
signal presentation_changed(state: Dictionary)
const CATALOG = preload("res://scripts/characters/lobby_source_catalog.gd")
const SELECTION = preload("res://scripts/characters/lobby_source_selection.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE_PATH := "res://scripts/ui/original_ui/sprite_scene.gd"
const ROLES := ["back_effect", "spine", "front_effect"]
const MOUNT_NAMES := ["BackEffect", "SpineBody", "FrontEffect"]
const SCOPE := "HOST_PREVIEW_NOT_ORIGINAL_LAYOUT_OR_RENDER_ACCEPTANCE"
const MAX_SOURCE_BYTES: int = 32 * 1024 * 1024
const MAX_ATLAS_BYTES: int = 4 * 1024 * 1024
const FIT_FRAME_BUDGET: int = 4
const MESH_FACTORY_PATH := "res://scripts/characters/lobby_spine_mesh_factory.gd"
var catalog: Object
## Explicit test seam; production reads only the separately selected private lobby pack.
var pack_provider: Callable
## Optional installed-runtime adapter. Never defaults to the M122 contract model.
## Receives verified bytes and autoplay=false, returns an unparented Node2D,
## source_sha256, supported_major_minor and autoplay_disabled=true. Its success
## proves mounting only. An adapter may expose play_source_animation(name,loop).
var spine_factory: Callable
var _generation: int = 0
var _closing: bool = false
var _fit_epoch: int = 0
var _stage: Node2D
var _mounts: Dictionary = {}
var _nodes: Dictionary = {}
var _pack: RefCounted
var _state: Dictionary = {}

func _enter_tree() -> void:
	_closing = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_ensure_mounts()
	if not resized.is_connected(_layout_preview): resized.connect(_layout_preview)
	_layout_preview()

func _exit_tree() -> void:
	_closing = true
	clear_selection()

func _ensure_mounts() -> void:
	if is_instance_valid(_stage): return
	_stage = Node2D.new()
	_stage.name = "SourcePreviewRoot"
	add_child(_stage)
	for index: int in ROLES.size():
		var mount := Node2D.new()
		mount.name = MOUNT_NAMES[index]
		mount.z_index = index
		_stage.add_child(mount)
		_mounts[ROLES[index]] = mount
	_layout_preview()

func _layout_preview() -> void:
	# This is an explicit host preview origin, not recovered original geometry.
	if not is_instance_valid(_stage) or not _finite_vector(size): return
	_stage.position = Vector2(size.x * 0.5, size.y)
	if _state.get("has_layers",false): _schedule_fit(_generation)

func _empty_state() -> Dictionary:
	return {"ok":true, "status":"cleared", "class_id":0, "gender_id":0,
		"layers":{}, "has_layers":false, "rendered":false,
		"original_render_verified":false, "original_lobby_layout_verified":false,
		"source_offset_applied":false, "scope":SCOPE}

func presentation_status() -> Dictionary:
	return (_empty_state() if _state.is_empty() else _state).duplicate(true)

func clear_selection() -> void:
	_generation += 1
	var ticket: int = _generation
	_reset_content()
	if ticket != _generation: return
	_state = _empty_state()
	presentation_changed.emit(presentation_status())

func _reset_content() -> void:
	# stop() is an installed adapter's external call. Retire our ownership
	# first so a synchronous callback can choose a new profile independently.
	var retired_nodes: Dictionary = _nodes
	var retired_pack: RefCounted = _pack
	_nodes = {}
	_pack = null
	_fit_epoch += 1
	# SourcePack guarantees already-issued textures remain valid. Release CPU
	# leases before stop() can reenter and acquire new pages on this same pack.
	if retired_pack != null: retired_pack.release_cache_leases()
	for node: Variant in retired_nodes.values(): _discard_node(node)

func _discard_node(value: Variant) -> void:
	if not value is Node or not is_instance_valid(value): return
	if value.has_method("stop"): value.call("stop")
	if not is_instance_valid(value): return
	if value.get_parent() != null: value.get_parent().remove_child(value)
	value.queue_free()

func _superseded() -> Dictionary:
	return {"ok":false, "status":"superseded", "error":"selection_changed", "rendered":false, "scope":SCOPE}

func select_profile(class_id: Variant, gender_id: Variant) -> Dictionary:
	if _closing: return {"ok":false,"status":"closed","error":"presentation_view_closed","rendered":false,"scope":SCOPE}
	_generation += 1
	var ticket: int = _generation
	_reset_content()
	if ticket != _generation: return _superseded()
	_ensure_mounts()
	_state = _empty_state()
	if catalog == null: catalog = CATALOG.new()
	if not catalog.has_method("resolve"):
		_state.merge({"ok":false, "status":"definition_error", "problem":"원본 로비 연결 reader가 없습니다."},true)
		return _publish(ticket)
	var raw: Variant = catalog.call("resolve",class_id,gender_id)
	if ticket != _generation: return _superseded()
	if not raw is Dictionary or not _true(raw.get("ok")):
		_state.merge({"ok":false, "status":"definition_error", "problem":str(raw.get("problem","원본 로비 연결을 확인하지 못했습니다.")) if raw is Dictionary else "원본 로비 연결 형식 오류"},true)
		return _publish(ticket)
	var definition: Dictionary = raw
	_state.merge({"status":"unavailable", "class_id":definition.get("class_id",class_id), "gender_id":definition.get("gender_id",gender_id),
		"source_identity":definition.get("source_identity",{}).duplicate(true), "synthetic":definition.get("synthetic",false)},true)
	for role: String in ROLES:
		var source: Variant = definition.get(role,{})
		var layer: Dictionary = source.duplicate(true) if source is Dictionary else {}
		layer["mounted"] = false
		layer["clips"] = []
		layer["rendered"] = false
		layer["original_render_verified"] = false
		layer["source_offset_applied"] = false
		_state.layers[role] = layer
	var selected: Variant = pack_provider.call() if pack_provider.is_valid() else SELECTION.selected_pack()
	if ticket != _generation:
		_release_unadopted_pack(selected)
		return _superseded()
	if not selected is Dictionary or not _true(selected.get("ok")):
		_release_unadopted_pack(selected)
		_mark_pack_failure("pack_error",str(selected.get("error",selected.get("code","source_pack_failed"))) if selected is Dictionary else "source_pack_result_invalid")
		return _publish(ticket)
	if not selected.get("selected") is bool:
		_release_unadopted_pack(selected)
		_mark_pack_failure("pack_error","source_pack_selected_flag_required")
		return _publish(ticket)
	if not selected.selected:
		_release_unadopted_pack(selected)
		_mark_pack_failure("pack_unselected","original_lobby_pack_not_selected")
		return _publish(ticket)
	var candidate: Variant = selected.get("pack")
	if not candidate is PACK or not candidate.manifest.get("schema") is String or candidate.manifest.schema != "twilight-original-ui-v1" or not _sha256_string(candidate.manifest_sha256) or candidate.root.is_empty():
		_release_unadopted_pack(selected)
		_mark_pack_failure("pack_error","verified_source_pack_required")
		return _publish(ticket)
	_pack = candidate
	for role: String in ROLES:
		var layer: Dictionary = _state.layers[role]
		if layer.get("status") != "resolved": continue
		var prepared: Dictionary = _prepare_spine(layer,ticket) if role == "spine" else _prepare_csb(layer,role,ticket)
		if ticket != _generation: return _superseded()
		_state.layers[role] = prepared
	return _publish(ticket)

func _release_unadopted_pack(selected: Variant) -> void:
	if not selected is Dictionary: return
	var value: Variant = selected.get("pack")
	# A reentrant newer selection may own this exact shared pack already.
	if value is PACK and value != _pack: value.release_cache_leases()

func _mark_pack_failure(status: String, error: String) -> void:
	for role: String in ROLES:
		if _state.layers[role].get("status") == "resolved":
			_state.layers[role]["status"] = status
			_state.layers[role]["error"] = error

func _publish(ticket: int) -> Dictionary:
	if ticket != _generation: return _superseded()
	var count: int = 0
	for layer: Dictionary in _state.get("layers",{}).values():
		if layer.get("mounted",false): count += 1
	_state["has_layers"] = count > 0
	if _state.get("ok",false) and _state.get("status") not in ["cleared","definition_error"]:
		_state["status"] = "mounted" if count > 0 else "unavailable"
	var result: Dictionary = presentation_status()
	presentation_changed.emit(result.duplicate(true))
	if ticket != _generation: return _superseded()
	if _state.get("has_layers",false): _schedule_fit(ticket)
	return result

func _layer_error(layer: Dictionary, status: String, error: String, missing: Array = []) -> Dictionary:
	var result: Dictionary = layer.duplicate(true)
	result["status"] = status
	result["error"] = error
	result["mounted"] = false
	if not missing.is_empty(): result["missing"] = missing.duplicate()
	return result

func _prepare_csb(layer: Dictionary, role: String, ticket: int) -> Dictionary:
	var path: String = str(layer.get("path",""))
	var checked: Dictionary = _read_original(path,MAX_SOURCE_BYTES)
	if not checked.ok: return _layer_error(layer,checked.status,checked.error,checked.get("missing",[]))
	var tree: Dictionary = _pack.scene(path)
	if ticket != _generation: return _superseded()
	if tree.is_empty(): return _layer_error(layer,"missing_files","decoded_source_csb_missing",[path])
	if tree.get("_source_sha256") != checked.sha256: return _layer_error(layer,"invalid_files","decoded_csb_source_hash_mismatch")
	var clips: Array = []
	var original_clips: Variant = tree.get("animationList",[])
	if not original_clips is Array: return _layer_error(layer,"invalid_files","source_clip_list_invalid")
	for clip: Variant in original_clips:
		if not clip is Dictionary or not clip.get("name") is String or clip.name.is_empty() or clip.name in clips:
			return _layer_error(layer,"invalid_files","ambiguous_source_clip")
		clips.append(clip.name)
	# Missing/unselected lobby art must not initialize the shared renderer's
	# image/card dependency graph during an ordinary roster launch.
	if not ResourceLoader.exists(SCENE_PATH): return _layer_error(layer,"renderer_error","source_csb_renderer_missing")
	var renderer_script: Script = load(SCENE_PATH) as Script
	if ticket != _generation: return _superseded()
	if renderer_script == null: return _layer_error(layer,"renderer_error","source_csb_renderer_missing")
	var renderer: Node2D = renderer_script.new()
	if ticket != _generation:
		_discard_node(renderer)
		return _superseded()
	var configured: Dictionary = renderer.configure(_pack,path,false,{})
	if ticket != _generation:
		_discard_node(renderer)
		return _superseded()
	if not _true(configured.get("ok")):
		_discard_node(renderer)
		return _layer_error(layer,"renderer_error",str(configured.get("error","source_csb_configure_failed")))
	_nodes[role] = renderer
	_mounts[role].add_child(renderer)
	if ticket != _generation:
		_discard_node(renderer)
		return _superseded()
	var result: Dictionary = layer.duplicate(true)
	result.merge({"status":"mounted", "mounted":true, "clips":clips, "source_sha256":checked.sha256, "playing":false},true)
	return result

func _prepare_spine(layer: Dictionary, ticket: int) -> Dictionary:
	var path: String = str(layer.get("path",""))
	var checked: Dictionary = _read_original(path,MAX_SOURCE_BYTES)
	if not checked.ok: return _layer_error(layer,checked.status,checked.error,checked.get("missing",[]))
	if not _utf8_valid(checked.bytes): return _layer_error(layer,"invalid_files","source_spine_utf8_invalid")
	var parser := JSON.new()
	if parser.parse(checked.bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _layer_error(layer,"invalid_files","source_spine_json_invalid")
	var data: Dictionary = parser.data
	var skeleton: Variant = data.get("skeleton")
	var animations: Variant = data.get("animations")
	if not skeleton is Dictionary or not skeleton.get("spine") is String or not animations is Dictionary:
		return _layer_error(layer,"invalid_files","source_spine_version_or_animations_missing")
	var version: String = skeleton.spine
	var version_parts: PackedStringArray = version.split(".")
	if version_parts.size() < 2 or not _decimal(version_parts[0]) or not _decimal(version_parts[1]) or int(version_parts[0]) <= 0:
		return _layer_error(layer,"invalid_files","source_spine_version_invalid")
	var explicit: Variant = _pack.manifest.get("lobby_spines",{}).get(path) if _pack.manifest.get("lobby_spines",{}) is Dictionary else null
	if not explicit is Dictionary or not explicit.get("atlas") is String:
		return _layer_error(layer,"missing_binding","explicit_lobby_spine_atlas_binding_required")
	var atlas_path: String = explicit.atlas
	var atlas: Dictionary = _read_original(atlas_path,MAX_ATLAS_BYTES)
	if not atlas.ok: return _layer_error(layer,atlas.status,atlas.error,atlas.get("missing",[]))
	if not _utf8_valid(atlas.bytes): return _layer_error(layer,"invalid_files","source_atlas_utf8_invalid")
	var pages: Dictionary = _atlas_pages(atlas_path,atlas.bytes.get_string_from_utf8())
	if not pages.ok: return _layer_error(layer,"invalid_files",pages.error)
	var verified_pages: Dictionary = {}
	for page: String in pages.paths:
		var page_result: Dictionary = _read_original(page,MAX_SOURCE_BYTES)
		if not page_result.ok: return _layer_error(layer,page_result.status,page_result.error,page_result.get("missing",[]))
		verified_pages[page] = {"sha256":page_result.sha256, "bytes":page_result.bytes}
	var result: Dictionary = layer.duplicate(true)
	result["source_sha256"] = checked.sha256
	result["spine_version"] = version
	result["atlas_path"] = atlas_path
	result["page_paths"] = pages.paths.duplicate()
	result["clips"] = animations.keys()
	var use_baked_mesh: bool = not spine_factory.is_valid() and explicit.get("mesh_bake") is Dictionary
	if not spine_factory.is_valid() and not use_baked_mesh: return _layer_error(result,"missing_runtime","original_spine_runtime_not_installed")
	var major_minor: String = version_parts[0] + "." + version_parts[1]
	var bundle: Dictionary = {"json_path":path, "json_bytes":checked.bytes, "source_sha256":checked.sha256,
		"spine_version":version, "major_minor":major_minor, "atlas_path":atlas_path, "atlas_bytes":atlas.bytes,
		"pages":verified_pages, "animations":animations.keys(), "autoplay":false}
	var created: Variant
	if use_baked_mesh:
		var pack_root: String = _pack.root
		var entry: Dictionary = explicit.mesh_bake.duplicate(true)
		var factory_script: Script = load(MESH_FACTORY_PATH) as Script if ResourceLoader.exists(MESH_FACTORY_PATH) else null
		if factory_script == null: return _layer_error(result,"missing_runtime","source_mesh_player_not_installed")
		created = factory_script.create(bundle,pack_root,entry)
	else:
		created = spine_factory.call(bundle)
	if ticket != _generation:
		if created is Dictionary: _discard_unparented(created.get("node"))
		return _superseded()
	if not created is Dictionary or not _true(created.get("ok")):
		if created is Dictionary: _discard_unparented(created.get("node"))
		return _layer_error(result,"renderer_error",str(created.get("error","spine_factory_failed")) if use_baked_mesh and created is Dictionary else "spine_factory_failed")
	var node: Variant = created.get("node")
	if not node is Node2D or not is_instance_valid(node) or node.get_parent() != null:
		_discard_unparented(node)
		return _layer_error(result,"renderer_error","unparented_spine_node_required")
	if not created.get("supported_major_minor") is String or not created.get("source_sha256") is String or created.supported_major_minor != major_minor or created.source_sha256 != checked.sha256 or not _true(created.get("autoplay_disabled")):
		_discard_unparented(node)
		return _layer_error(result,"renderer_error","spine_runtime_source_contract_mismatch")
	_nodes["spine"] = node
	_mounts.spine.add_child(node)
	if ticket != _generation:
		_discard_node(node)
		return _superseded()
	result.merge({"status":"mounted", "mounted":true, "playing":false, "runtime_bound":true},true)
	return result

func _discard_unparented(value: Variant) -> void:
	if value is Node and is_instance_valid(value) and value.get_parent() == null: _discard_node(value)

func play_layer(role: String, source_clip: String, repeat: bool = false) -> Dictionary:
	if role not in ROLES or not _nodes.has(role) or not is_instance_valid(_nodes[role]): return {"ok":false,"error":"source_layer_unavailable"}
	var layer: Dictionary = _state.layers[role]
	if source_clip.is_empty() or source_clip not in layer.get("clips",[]): return {"ok":false,"error":"source_clip_missing"}
	var node: Node = _nodes[role]
	var ticket: int = _generation
	var result: Variant
	if role == "spine":
		if not node.has_method("play_source_animation"): return {"ok":false,"error":"spine_playback_adapter_missing"}
		result = node.call("play_source_animation",source_clip,repeat)
	else:
		result = node.call("play",source_clip,repeat)
	if ticket != _generation: return _superseded()
	if not result is Dictionary or not _true(result.get("ok")): return {"ok":false,"error":"source_playback_failed"}
	_state.layers[role]["playing"] = true
	_state.layers[role]["clip"] = source_clip
	_state.layers[role]["loop"] = repeat
	presentation_changed.emit(presentation_status())
	if ticket != _generation: return _superseded()
	_schedule_fit(ticket)
	return {"ok":true,"rendered":false,"original_render_verified":false,"scope":SCOPE}

## Fit only the host transform to currently visible Sprite2D quads that inherit
## it through an uninterrupted, non-top-level CanvasItem chain.
## This does not recover the original lobby's geometry, modify source nodes,
## infer particle envelopes, or imply original rendering acceptance.
func fit_preview(allow_upscale: bool = false) -> Dictionary:
	var ticket: int = _generation
	if _closing: return {"ok":false,"status":"closed","scope":SCOPE}
	if not is_instance_valid(_stage) or not is_inside_tree(): return {"ok":false,"status":"no_visible_quads","scope":SCOPE}
	if _stage.is_set_as_top_level(): return {"ok":false,"status":"invalid_transform","scope":SCOPE}
	if not _finite_vector(size) or size.x <= 0.0 or size.y <= 0.0: return {"ok":false,"status":"empty_viewport","scope":SCOPE}
	var world: Transform2D = _stage.get_global_transform()
	if not _finite_transform(world) or world.determinant() == 0.0: return {"ok":false,"status":"invalid_transform","scope":SCOPE}
	var inverse: Transform2D = world.affine_inverse()
	if not _finite_transform(inverse): return {"ok":false,"status":"invalid_transform","scope":SCOPE}
	var source_bounds := Rect2()
	var quads: int = 0
	var mesh_extents: int = 0
	var excluded_boundaries: int = 0
	var pending: Array[Node] = [_stage]
	while not pending.is_empty():
		if ticket != _generation: return _superseded()
		var current: Node = pending.pop_back()
		if not is_instance_valid(current): continue
		if current != _stage and (not current is CanvasItem or current.is_set_as_top_level()):
			excluded_boundaries += 1
			continue
		for child: Node in current.get_children(): pending.append(child)
		var rect := Rect2()
		var item: CanvasItem
		var is_mesh_extent: bool = current == _nodes.get("spine") and current is Node2D and current.has_method("get_preview_bounds")
		if is_mesh_extent:
			item = current
			if not item.is_visible_in_tree(): continue
			var supplied: Variant = current.call("get_preview_bounds")
			if not supplied is Rect2: return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
			rect = supplied
		else:
			if not current is Sprite2D: continue
			var sprite: Sprite2D = current
			item = sprite
			if not sprite.is_visible_in_tree() or sprite.texture == null: continue
			if sprite.texture.get_width() <= 0 or sprite.texture.get_height() <= 0: continue
			if sprite.region_enabled:
				if not _finite_rect(sprite.region_rect): return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
				# Empty sprite regions draw no source quad.
				if sprite.region_rect.size.x <= 0.0 or sprite.region_rect.size.y <= 0.0: continue
			rect = sprite.get_rect()
		if not _finite_rect(rect): return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
		if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
		var relative: Transform2D = inverse * item.get_global_transform()
		if not _finite_transform(relative): return {"ok":false,"status":"invalid_transform","scope":SCOPE}
		if relative.determinant() == 0.0: continue
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)]
		var quad := Rect2()
		for index: int in corners.size():
			var point: Vector2 = relative * corners[index]
			if not _finite_vector(point): return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
			quad = Rect2(point,Vector2.ZERO) if index == 0 else quad.expand(point)
		if not _finite_rect(quad): return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
		if quad.size.x <= 0.0 or quad.size.y <= 0.0: continue
		source_bounds = quad if quads + mesh_extents == 0 else source_bounds.merge(quad)
		if is_mesh_extent: mesh_extents += 1
		else: quads += 1
	if quads + mesh_extents == 0: return {"ok":false,"status":"no_visible_quads","excluded_transform_boundaries":excluded_boundaries,"scope":SCOPE}
	if not _finite_rect(source_bounds) or source_bounds.size.x <= 0.0 or source_bounds.size.y <= 0.0: return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
	var zoom: float = minf(size.x / source_bounds.size.x,size.y / source_bounds.size.y)
	if not allow_upscale: zoom = minf(1.0,zoom)
	if not is_finite(zoom) or zoom <= 0.0: return {"ok":false,"status":"invalid_transform","scope":SCOPE}
	var host_position: Vector2 = (size - source_bounds.size * zoom) * 0.5 - source_bounds.position * zoom
	var target := Transform2D(Vector2(zoom,0.0),Vector2(0.0,zoom),host_position)
	if not _finite_transform(target) or target.determinant() == 0.0: return {"ok":false,"status":"invalid_transform","scope":SCOPE}
	var host_bounds := Rect2(host_position + source_bounds.position * zoom,source_bounds.size * zoom)
	if not _finite_rect(host_bounds): return {"ok":false,"status":"invalid_bounds","scope":SCOPE}
	if ticket != _generation: return _superseded()
	_stage.transform = target
	var result: Dictionary = {"ok":true,"status":"fitted","source_bounds":source_bounds,"host_bounds":host_bounds,
		"scale":zoom,"position":host_position,"quads":quads,"excluded_transform_boundaries":excluded_boundaries,
		"bounds_scope":"visible_sprites_inheriting_host_transform","original_source_geometry_changed":false,
		"original_lobby_layout_verified":false,"rendered":false,"scope":SCOPE}
	if mesh_extents > 0:
		result["mesh_extents"] = mesh_extents
		result["bounds_scope"] = "visible_sprites_and_verified_spine_sampled_clip_extent"
	_state["preview_fit"] = result.duplicate(true)
	# A host-only fit does not change layer availability. Do not emit the
	# presentation signal here: rebuilding its UI can cause resize-fit cycles.
	return result

func _schedule_fit(ticket: int) -> void:
	if ticket != _generation or _closing or not is_inside_tree(): return
	_fit_epoch += 1
	_queue_fit_step.call_deferred(ticket,_fit_epoch,FIT_FRAME_BUDGET)

func _queue_fit_step(ticket: int, epoch: int, remaining: int) -> void:
	if ticket != _generation or epoch != _fit_epoch or _closing or not is_inside_tree(): return
	var callback: Callable = _deferred_fit_step.bind(ticket,epoch,remaining)
	if not get_tree().process_frame.is_connected(callback): get_tree().process_frame.connect(callback,CONNECT_ONE_SHOT)

func _deferred_fit_step(ticket: int, epoch: int, remaining: int) -> void:
	if ticket != _generation or epoch != _fit_epoch or _closing or not is_inside_tree(): return
	fit_preview()
	if remaining > 1 and ticket == _generation and epoch == _fit_epoch:
		# Connect outside this signal emission, so each retry observes another
		# actual process frame rather than repeating the same empty snapshot.
		_queue_fit_step.call_deferred(ticket,epoch,remaining - 1)

static func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

static func _finite_transform(value: Transform2D) -> bool:
	return _finite_vector(value.x) and _finite_vector(value.y) and _finite_vector(value.origin) and is_finite(value.determinant())

static func _finite_rect(value: Rect2) -> bool:
	return _finite_vector(value.position) and _finite_vector(value.size) and _finite_vector(value.end)

func _read_original(member: String, maximum: int) -> Dictionary:
	if not _safe_member(member): return {"ok":false,"status":"invalid_files","error":"unsafe_source_path"}
	var files: Variant = _pack.manifest.get("files",{})
	if not files is Dictionary or not files.has(member): return {"ok":false,"status":"missing_files","error":"source_file_not_in_pack","missing":[member]}
	var entry: Variant = files[member]
	if not entry is Dictionary or not _sha256_string(entry.get("sha256")) or not _whole(entry.get("bytes")) or entry.bytes > maximum:
		return {"ok":false,"status":"invalid_files","error":"source_file_entry_invalid"}
	var absolute: String = _pack.root.path_join("originals").path_join(member)
	if not FileAccess.file_exists(absolute): return {"ok":false,"status":"missing_files","error":"source_file_missing","missing":[member]}
	var file := FileAccess.open(absolute,FileAccess.READ)
	if file == null or file.get_length() != int(entry.bytes): return {"ok":false,"status":"invalid_files","error":"source_file_size_mismatch"}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	var sha: String = context.finish().hex_encode()
	if sha != entry.sha256: return {"ok":false,"status":"invalid_files","error":"source_file_hash_mismatch"}
	return {"ok":true,"bytes":bytes,"sha256":sha}

static func _atlas_pages(atlas_path: String, text: String) -> Dictionary:
	# Spine's atlas format separates pages with blank lines. Page properties
	# are optional and whitespace (other than line breaks) is optional. This
	# reads dependency paths, not region geometry or a rendering substitute.
	var pages: Array[String] = []
	var awaiting_page: bool = true
	for line: String in text.split("\n"):
		var value: String = line.strip_edges()
		if value.is_empty():
			awaiting_page = true
			continue
		if awaiting_page:
			if ":" in value or not _safe_member(value): return {"ok":false,"error":"unsafe_source_atlas_page"}
			var page: String = atlas_path.get_base_dir().path_join(value)
			if not _safe_member(page) or page in pages or pages.size() >= 64: return {"ok":false,"error":"source_atlas_page_ambiguous"}
			pages.append(page)
			awaiting_page = false
	if pages.is_empty(): return {"ok":false,"error":"source_atlas_pages_missing"}
	return {"ok":true,"paths":pages}

static func _safe_member(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges() or value.begins_with("/") or value.ends_with("/") or "\\" in value or ":" in value or "%" in value or "?" in value or "#" in value: return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if code < 32 or code == 127: return false
	for part: String in value.split("/",true):
		if part in ["", ".", ".."] or part != part.strip_edges(): return false
	return true

static func _sha256_string(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for index: int in value.length():
		if not "0123456789abcdef".contains(value.substr(index,1)): return false
	return true

static func _utf8_valid(bytes: PackedByteArray) -> bool:
	# Validate before Godot's UTF-8 decoder, which prints engine errors on bad
	# byte sequences even when the subsequent JSON failure is handled.
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 128:
			index += 1
			continue
		var count: int = 0
		var second_min: int = 128
		var second_max: int = 191
		if first >= 194 and first <= 223: count = 1
		elif first >= 224 and first <= 239:
			count = 2
			if first == 224: second_min = 160
			elif first == 237: second_max = 159
		elif first >= 240 and first <= 244:
			count = 3
			if first == 240: second_min = 144
			elif first == 244: second_max = 143
		else: return false
		if index + count >= bytes.size(): return false
		if bytes[index + 1] < second_min or bytes[index + 1] > second_max: return false
		for offset: int in range(2,count + 1):
			if bytes[index + offset] < 128 or bytes[index + offset] > 191: return false
		index += count + 1
	return true

static func _true(value: Variant) -> bool:
	return value is bool and value == true

static func _decimal(value: String) -> bool:
	if value.is_empty(): return false
	for index: int in value.length():
		if not "0123456789".contains(value.substr(index,1)): return false
	return true

static func _whole(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value == floorf(float(value)) and value <= MAX_SOURCE_BYTES
