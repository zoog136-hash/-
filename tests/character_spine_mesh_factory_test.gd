extends SceneTree
## Factory/consumer contract fixtures, never original Spine art or render proof.
## PNG bytes come unchanged from the existing repository boot icon. No new image
## or sprite is generated; source JSON/atlas/mesh below are declared test data.
const FACTORY = preload("res://scripts/characters/lobby_spine_mesh_factory.gd")
const VIEW = preload("res://scripts/characters/lobby_source_presentation.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const PAGE := "UI/Spine/Fixture.png"
const JSON_PATH := "UI/Spine/Fixture.json"
const ATLAS_PATH := "UI/Spine/Fixture.atlas"
const PNG_PATH := "res://assets/boot/twilight_icon_192.png"
var checks := 0
var failures: Array[String] = []
var fixture_root := ""
var serial := 0
var source_bytes: Dictionary = {}

class FixtureCatalog extends RefCounted:
	func resolve(_class_id: Variant, _gender_id: Variant) -> Dictionary:
		return {"ok":true,"class_id":1,"gender_id":1,"synthetic":true,
			"spine":{"ok":true,"status":"resolved","path":"UI/Spine/Fixture.json","asset_id":1,"offset_x":0,"offset_y":0,"flip":false},
			"back_effect":{"ok":true,"status":"optional_zero","path":"","asset_id":0},
			"front_effect":{"ok":true,"status":"optional_zero","path":"","asset_id":0}}

class ExternalAdapter extends Node2D:
	var stops := 0
	func stop() -> void: stops += 1

class ReentrantBoundsAdapter extends Node2D:
	var inspected: Callable
	func get_preview_bounds() -> Rect2:
		var callback: Callable = inspected
		inspected = Callable()
		if callback.is_valid(): callback.call()
		return Rect2(0,0,4,3)
	func stop() -> void: set_process(false)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_SPINE_MESH_FACTORY_FAIL ", label)
	return ok

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func write(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.close()
	return true

func bundle() -> Dictionary:
	return {"json_path":JSON_PATH,"json_bytes":source_bytes[JSON_PATH],"source_sha256":digest(source_bytes[JSON_PATH]),
		"atlas_path":ATLAS_PATH,"atlas_bytes":source_bytes[ATLAS_PATH],"spine_version":"3.6.52","major_minor":"3.6",
		"pages":{PAGE:{"bytes":source_bytes[PAGE],"sha256":digest(source_bytes[PAGE])}},
		"animations":["Exact_Idle"],"autoplay":false}

func batch(x: float = 0.0, alpha: float = 1.0) -> Dictionary:
	return {"page":PAGE,"blend":"normal","color":[1.0,1.0,1.0,alpha],"dark_color":[0.0,0.0,0.0,0.0],
		"positions":[x,0.0,x+4.0,0.0,x+4.0,3.0,x,3.0],"uvs":[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0],"indices":[0,1,2,2,3,0]}

func mesh() -> Dictionary:
	var input: Dictionary = bundle()
	return {"schema":FACTORY.SCHEMA,"coordinate_space":"godot_y_down","premultiplied_alpha":false,
		"source":{"runtime_git":FACTORY.RUNTIME_GIT,"json_sha256":input.source_sha256,"atlas_sha256":digest(input.atlas_bytes),
			"spine_version":"3.6.52","pages":{PAGE:{"sha256":input.pages[PAGE].sha256,"bytes":source_bytes[PAGE].size()}}},
		"setup":{"batches":[batch()]},"clips":{"Exact_Idle":{"duration":1.0,"fps":1.0,
			"frames":[{"time":0.0,"batches":[batch(0.0,0.0)]},{"time":1.0,"batches":[batch(20.0)]}]}}}

func entry_bytes(bytes: PackedByteArray) -> Dictionary:
	serial += 1
	var relative := "derived/spine/case%d.mesh.json" % serial
	check(write(fixture_root.path_join(relative),bytes),"owned mesh fixture written %d" % serial)
	return {"path":relative,"bytes":bytes.size(),"sha256":digest(bytes),"compression":"none"}

func entry(data: Dictionary) -> Dictionary: return entry_bytes(JSON.stringify(data).to_utf8_buffer())

func rejected(input: Dictionary, declaration: Dictionary, label: String, expected: String = "", root_path: String = "") -> void:
	var result: Dictionary = FACTORY.create(input,fixture_root if root_path.is_empty() else root_path,declaration)
	check(result.get("ok") == false and not str(result.get("error","")).is_empty(),label+" fails closed")
	if not expected.is_empty(): check(result.get("error") == expected,label+" reports exact guard")
	check(not result.has("node"),label+" returns no actor")
	if result.get("node") is Node and is_instance_valid(result.node): result.node.free()

func pack(use_mesh: bool, mesh_entry: Dictionary) -> RefCounted:
	serial += 1
	var root_path: String = fixture_root.path_join("pack%d" % serial)
	var files: Dictionary = {}
	for path: String in source_bytes:
		check(write(root_path.path_join("originals").path_join(path),source_bytes[path]),"pack fixture source bytes copied unchanged "+path)
		files[path] = {"bytes":source_bytes[path].size(),"sha256":digest(source_bytes[path])}
	var binding: Dictionary = {"atlas":ATLAS_PATH}
	if use_mesh:
		binding["mesh_bake"] = mesh_entry.duplicate(true)
		check(write(root_path.path_join(mesh_entry.path),FileAccess.get_file_as_bytes(fixture_root.path_join(mesh_entry.path))),"opt-in pack receives exact derived fixture")
	var manifest: Dictionary = {"schema":"twilight-original-ui-v1","files":files,"scenes":{},"atlases":{},"blockers":[],"lobby_spines":{JSON_PATH:binding}}
	var bytes: PackedByteArray = JSON.stringify(manifest).to_utf8_buffer()
	check(write(root_path.path_join("original_ui.json"),bytes),"explicit fixture pack manifest written")
	var result := PACK.new()
	check(result.open(root_path,digest(bytes)).get("ok",false),"fixture pack opens through production verifier")
	return result

func consumer_checks(declaration: Dictionary) -> void:
	var old_bake: bool = PACK.bake_enabled
	PACK.bake_enabled = false
	var selected: RefCounted = pack(true,declaration)
	var view = VIEW.new()
	view.catalog = FixtureCatalog.new()
	view.pack_provider = func() -> Dictionary: return {"ok":true,"selected":true,"pack":selected}
	view.size = Vector2(200,100)
	root.add_child(view)
	var result: Dictionary = view.select_profile(1,1)
	check(result.layers.spine.get("mounted",false),"explicit mesh_bake installs default verified mesh factory")
	check(result.layers.spine.get("playing") == false and not result.original_render_verified,"consumer mounting does not autoplay or certify rendering")
	var actor: Node = view._nodes.get("spine")
	if check(actor != null and actor.has_method("get_preview_bounds"),"consumer owns actual mesh-player node"):
		check(not actor.is_processing() and not actor.playback_status().playing,"mounted mesh remains stopped")
		var fitted: Dictionary = view.fit_preview()
		check(fitted.get("ok",false) and fitted.get("mesh_extents",0) == 1 and fitted.get("quads",-1) == 0,"mesh setup extent participates without fake Sprite2D quads")
		check(fitted.get("source_bounds") == Rect2(0,0,4,3),"host fit uses verified setup geometry")
		check(view.play_layer("spine","Exact_Idle",false).get("ok",false),"consumer explicitly plays exact authored clip name")
		actor.stop()
		fitted = view.fit_preview()
		check(fitted.get("source_bounds") == Rect2(20,0,4,3) and fitted.get("bounds_scope") == "visible_sprites_and_verified_spine_sampled_clip_extent","delayed visible sampled extent fits even while first pose is transparent")
		var weak: WeakRef = weakref(actor)
		view.clear_selection()
		check(view._nodes.is_empty() and actor.get_parent() == null and not actor.is_processing(),"selection clear detaches and stops old mesh synchronously")
		await process_frame
		check(weak.get_ref() == null,"cleared mesh is freed after deferred deletion")
	view.free()
	var unbound: RefCounted = pack(false,declaration)
	var no_mesh = VIEW.new()
	no_mesh.catalog = FixtureCatalog.new()
	no_mesh.pack_provider = func() -> Dictionary: return {"ok":true,"selected":true,"pack":unbound}
	root.add_child(no_mesh)
	var missing: Dictionary = no_mesh.select_profile(1,1)
	check(missing.layers.spine.get("status") == "missing_runtime" and not missing.layers.spine.get("mounted",false),"absence of explicit mesh_bake retains missing-runtime behavior")
	no_mesh.free()
	var external = VIEW.new()
	external.catalog = FixtureCatalog.new()
	external.pack_provider = func() -> Dictionary: return {"ok":true,"selected":true,"pack":selected}
	var external_calls := [0]
	external.spine_factory = func(input: Dictionary) -> Dictionary:
		external_calls[0] += 1
		check(input.autoplay == false and input.json_bytes == source_bytes[JSON_PATH],"external factory retains verified-byte/no-autoplay contract")
		return {"ok":true,"node":ExternalAdapter.new(),"source_sha256":input.source_sha256,"supported_major_minor":"3.6","autoplay_disabled":true}
	root.add_child(external)
	var prior: Dictionary = selected.manifest.lobby_spines[JSON_PATH].mesh_bake
	selected.manifest.lobby_spines[JSON_PATH].mesh_bake = {"path":"../invalid"}
	var mounted: Dictionary = external.select_profile(1,1)
	check(external_calls[0] == 1 and mounted.layers.spine.get("mounted",false),"supplied external adapter takes precedence over invalid optional mesh entry")
	selected.manifest.lobby_spines[JSON_PATH].mesh_bake = prior
	external.free()
	var reentrant = VIEW.new()
	reentrant.catalog = FixtureCatalog.new()
	reentrant.pack_provider = func() -> Dictionary: return {"ok":true,"selected":true,"pack":selected}
	reentrant.size = Vector2(200,100)
	reentrant.spine_factory = func(input: Dictionary) -> Dictionary:
		var adapter := ReentrantBoundsAdapter.new()
		adapter.inspected = func() -> void: reentrant.clear_selection()
		return {"ok":true,"node":adapter,"source_sha256":input.source_sha256,"supported_major_minor":"3.6","autoplay_disabled":true}
	root.add_child(reentrant)
	check(reentrant.select_profile(1,1).layers.spine.get("mounted",false),"bounds-reentry fixture mounts external adapter")
	var interrupted: Variant = reentrant.fit_preview()
	check(interrupted is Dictionary and interrupted.get("status") == "superseded" and reentrant.presentation_status().status == "cleared","bounds callback clearing/detaching its adapter supersedes fit without stale access")
	reentrant.free()
	for path: String in source_bytes:
		check(FileAccess.get_file_as_bytes(selected.root.path_join("originals").path_join(path)) == source_bytes[path],"consumer preserves original fixture file bytes "+path)
	PACK.bake_enabled = old_bake
	await process_frame

func run() -> void:
	fixture_root = ProjectSettings.globalize_path("user://character-spine-mesh-factory-" + str(Time.get_ticks_usec()))
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK,"unique isolated fixture directory created")
	var png: PackedByteArray = FileAccess.get_file_as_bytes(PNG_PATH)
	check(not png.is_empty(),"existing tracked PNG bytes available without generating images")
	source_bytes = {JSON_PATH:JSON.stringify({"skeleton":{"spine":"3.6.52"},"bones":[{"name":"root"}],"slots":[],"skins":{},"animations":{"Exact_Idle":{}}}).to_utf8_buffer(),
		ATLAS_PATH:"Fixture.png\nsize: 192,192\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\nregion\n  rotate: false\n  xy: 0,0\n  size: 192,192\n  orig: 192,192\n  offset: 0,0\n  index: -1\n".to_utf8_buffer(),PAGE:png}
	var originals: Dictionary = source_bytes.duplicate(true)
	var input: Dictionary = bundle()
	var data: Dictionary = mesh()
	var declaration: Dictionary = entry(data)
	var before_bundle: Dictionary = input.duplicate(true)
	var before_entry: Dictionary = declaration.duplicate(true)
	var before_file: PackedByteArray = FileAccess.get_file_as_bytes(fixture_root.path_join(declaration.path))
	var result: Dictionary = FACTORY.create(input,fixture_root,declaration)
	check(result.get("ok",false),"valid bound fixture creates node through production factory")
	check(input == before_bundle and declaration == before_entry and before_file == FileAccess.get_file_as_bytes(fixture_root.path_join(declaration.path)),"factory leaves caller metadata and mesh bytes unchanged")
	if result.get("ok",false):
		var node: Node2D = result.node
		check(node.get_parent() == null and node.has_method("play_source_animation"),"factory returns live unparented Node2D playback adapter")
		check(result.get("source_sha256") == input.source_sha256 and result.get("supported_major_minor") == "3.6" and result.get("autoplay_disabled") == true,"factory returns source/version/no-autoplay contract")
		check(result.get("original_render_verified") == false and result.get("original_lobby_layout_verified") == false,"fixture mount never claims original visual acceptance")
		root.add_child(node)
		check(not node.is_processing() and not node.playback_status().playing,"adding factory node to tree never autoplays")
		var texture: Texture2D = node.get_child(0).get_child(1).texture
		var image := Image.new()
		check(image.load_png_from_buffer(png) == OK and texture.get_image().get_data() == image.get_data(),"factory decodes exactly supplied existing PNG pixels")
		input.pages[PAGE].bytes = PackedByteArray([0])
		input.animations.clear()
		input.json_bytes = PackedByteArray([0])
		data.setup.batches[0].positions[0] = 9999
		check(write(fixture_root.path_join(declaration.path),"changed after successful creation".to_utf8_buffer()),"caller-owned derived fixture changed after successful creation")
		check(node.get_preview_bounds() == Rect2(0,0,4,3) and texture.get_image().get_data() == image.get_data(),"caller mutations cannot change node geometry or decoded texture")
		check(node.play_source_animation("Exact_Idle",false).get("ok",false),"node retains validated source clip after caller mutation")
		node.stop()
		var weak: WeakRef = weakref(node)
		node.free()
		check(weak.get_ref() == null,"factory result has independent explicitly releasable lifetime")
	# The same bound envelope also accepts the player's optional V1 topology
	# references. Positions remain per pose; only exact UV/index arrays share.
	var compact: Dictionary = mesh()
	var topology: Dictionary = compact.setup.batches[0]
	compact["geometries"] = {"quad":{"page":PAGE,"uvs":topology.uvs.duplicate(),"indices":topology.indices.duplicate()}}
	var compact_poses: Array = [compact.setup]
	compact_poses.append_array(compact.clips.Exact_Idle.frames)
	for pose: Dictionary in compact_poses:
		for item: Dictionary in pose.batches:
			item.erase("page"); item.erase("uvs"); item.erase("indices"); item["geometry"] = "quad"
	var compact_result: Dictionary = FACTORY.create(bundle(),fixture_root,entry(compact))
	check(compact_result.get("ok",false),"factory forwards optional shared geometry V1 without expanding source data")
	if compact_result.get("ok",false):
		var compact_node: Node2D = compact_result.node
		check(compact_node.playback_status().geometry_templates == 1 and compact_node.get_preview_bounds() == Rect2(0,0,4,3),"shared topology creates exact setup through factory")
		check(compact_node.play_source_animation("Exact_Idle",false).get("ok",false) and compact_node.advance(1.0).get("ok",false) and compact_node.playback_status().current_rendered_bounds == Rect2(20,0,4,3),"factory shared topology preserves actual per-pose positions")
		compact_node.free()
	compact.setup.batches[0].geometry = "missing"
	rejected(bundle(),entry(compact),"unknown shared geometry key","spine_mesh_unknown_geometry")
	# Rebuild pristine fixture after the deliberate caller-mutation checks.
	data = mesh()
	declaration = entry(data)
	for bad_path: Variant in ["../escape.mesh.json","derived/spine/../escape.mesh.json","derived/spine//x.mesh.json","derived/spine/./x.mesh.json","/derived/spine/x.mesh.json","derived\\spine\\x.mesh.json","derived/spine/x.mesh.json?x","derived/spine/%2e%2e/x.mesh.json","derived/spine/x.mesh.json#x","derived/spine/ x.mesh.json","derived/spine/x.mesh.json\n","derived/spine/x.json",3]:
		var invalid: Dictionary = declaration.duplicate(true); invalid.path = bad_path
		rejected(bundle(),invalid,"unsafe mesh path "+str(bad_path),"mesh_bake_entry_invalid")
	for value: Variant in [0,-1,FACTORY.MAX_MESH_BYTES+1,1.5,"100",true,NAN]:
		var invalid: Dictionary = declaration.duplicate(true); invalid.bytes = value
		rejected(bundle(),invalid,"invalid bounded byte declaration "+str(value),"mesh_bake_entry_invalid")
	for value: Variant in ["A".repeat(64),"g".repeat(64),"a".repeat(63),true]:
		var invalid: Dictionary = declaration.duplicate(true); invalid.sha256 = value
		rejected(bundle(),invalid,"invalid SHA syntax "+str(value),"mesh_bake_entry_invalid")
	var wrong: Dictionary = declaration.duplicate(true); wrong.compression = "gzip"
	rejected(bundle(),wrong,"implicit compressed mesh","mesh_bake_entry_invalid")
	rejected(bundle(),declaration,"relative root","mesh_bake_entry_invalid","relative/root")
	rejected(bundle(),declaration,"absent root","mesh_bake_root_missing",fixture_root.path_join("absent"))
	wrong = declaration.duplicate(true); wrong.path = "derived/spine/missing.mesh.json"
	rejected(bundle(),wrong,"missing mesh file","mesh_bake_file_missing")
	wrong = declaration.duplicate(true); wrong.bytes += 1
	rejected(bundle(),wrong,"changed file size","mesh_bake_size_mismatch")
	wrong = declaration.duplicate(true); wrong.sha256 = "0".repeat(64)
	rejected(bundle(),wrong,"changed mesh digest","mesh_bake_hash_mismatch")
	for raw: PackedByteArray in [PackedByteArray([255]),PackedByteArray([0xC0,0xAF]),PackedByteArray([0xED,0xA0,0x80]),PackedByteArray([0xF4,0x90,0x80,0x80])]:
		rejected(bundle(),entry_bytes(raw),"invalid UTF8 mesh","mesh_bake_utf8_invalid")
	for text: String in ["{", "[]", "null"]:
		rejected(bundle(),entry_bytes(text.to_utf8_buffer()),"malformed/different JSON root "+text,"mesh_bake_json_invalid")
	var unicode_data: Dictionary = mesh(); unicode_data["fixture_note"] = "한글 UTF8 보존"
	var unicode_result: Dictionary = FACTORY.create(bundle(),fixture_root,entry(unicode_data))
	check(unicode_result.get("ok",false),"well-formed UTF8 non-ASCII metadata accepted")
	if unicode_result.get("node") is Node: unicode_result.node.free()
	var access := DirAccess.open(fixture_root)
	var link_path := "derived/spine/linked.mesh.json"
	check(access.create_link(fixture_root.path_join(declaration.path),fixture_root.path_join(link_path)) == OK,"owned mesh-file symlink fixture created")
	wrong = declaration.duplicate(true); wrong.path = link_path
	rejected(bundle(),wrong,"symlinked mesh leaf","mesh_bake_link_not_allowed")
	check(access.create_link(fixture_root.path_join("derived/spine"),fixture_root.path_join("derived/spine/linked")) == OK,"owned mesh-directory symlink fixture created")
	wrong = declaration.duplicate(true); wrong.path = "derived/spine/linked/"+str(declaration.path).get_file()
	rejected(bundle(),wrong,"symlinked mesh parent","mesh_bake_link_not_allowed")
	for field: String in ["schema","coordinate_space","premultiplied_alpha"]:
		var invalid_data: Dictionary = mesh(); invalid_data[field] = "invalid"
		rejected(bundle(),entry(invalid_data),"invalid mesh policy "+field,"mesh_bake_schema_or_policy_invalid")
	for field: String in ["runtime_git","spine_version"]:
		var invalid_data: Dictionary = mesh(); invalid_data.source[field] = "invalid"
		rejected(bundle(),entry(invalid_data),"unmatched runtime metadata "+field,"mesh_bake_runtime_or_version_mismatch")
	var invalid_bundle: Dictionary = bundle(); invalid_bundle.major_minor = "4.0"
	rejected(invalid_bundle,declaration,"unsupported major/minor","mesh_bake_runtime_or_version_mismatch")
	for field: String in ["json_sha256","atlas_sha256"]:
		var invalid_data: Dictionary = mesh(); invalid_data.source[field] = "a".repeat(64)
		rejected(bundle(),entry(invalid_data),"wrong source identity "+field,"mesh_bake_original_hash_mismatch")
	invalid_bundle = bundle(); invalid_bundle.source_sha256 = "0".repeat(64)
	rejected(invalid_bundle,declaration,"wrong bundle source ID","mesh_bake_original_hash_mismatch")
	invalid_bundle = bundle(); invalid_bundle.json_bytes = "different source JSON".to_utf8_buffer()
	rejected(invalid_bundle,declaration,"changed original JSON bytes","mesh_bake_original_hash_mismatch")
	invalid_bundle = bundle(); invalid_bundle.atlas_bytes = "different source atlas".to_utf8_buffer()
	rejected(invalid_bundle,declaration,"changed original atlas bytes","mesh_bake_original_hash_mismatch")
	for field: String in ["json_bytes","atlas_bytes","source_sha256"]:
		invalid_bundle = bundle(); invalid_bundle.erase(field)
		rejected(invalid_bundle,declaration,"missing original bundle field "+field,"mesh_bake_original_bundle_invalid")
	var invalid_data: Dictionary = mesh(); invalid_data.source.pages = {}
	rejected(bundle(),entry(invalid_data),"missing page declaration","mesh_bake_page_set_mismatch")
	invalid_data = mesh(); invalid_data.source.pages["UI/Spine/Unknown.png"] = invalid_data.source.pages[PAGE]; invalid_data.source.pages.erase(PAGE)
	rejected(bundle(),entry(invalid_data),"unmatched page identity","mesh_bake_page_entry_invalid")
	invalid_bundle = bundle(); invalid_bundle.pages[PAGE].sha256 = "0".repeat(64)
	rejected(invalid_bundle,declaration,"wrong supplied page SHA","mesh_bake_page_hash_mismatch")
	invalid_data = mesh(); invalid_data.source.pages[PAGE].bytes += 1
	rejected(bundle(),entry(invalid_data),"wrong declared page byte count","mesh_bake_page_hash_mismatch")
	invalid_data = mesh(); invalid_data.setup.batches[0].page = "UI/Spine/Unknown.png"
	rejected(bundle(),entry(invalid_data),"mesh geometry references unknown page","spine_mesh_batch_page_or_blend")
	invalid_bundle = bundle(); invalid_bundle.animations = ["OtherClip"]
	rejected(invalid_bundle,declaration,"different clip names","mesh_bake_clip_set_mismatch")
	invalid_bundle = bundle(); invalid_bundle.animations = ["Exact_Idle","Exact_Idle"]
	rejected(invalid_bundle,declaration,"duplicate original clip names","mesh_bake_clip_set_mismatch")
	invalid_data = mesh(); invalid_data.clips["ExtraClip"] = invalid_data.clips.Exact_Idle
	rejected(bundle(),entry(invalid_data),"unexpected derived clip","mesh_bake_clip_set_mismatch")
	invalid_bundle = bundle(); invalid_bundle.spine_version = "3.60.52"
	invalid_data = mesh(); invalid_data.source.spine_version = "3.60.52"
	rejected(invalid_bundle,entry(invalid_data),"lookalike unsupported Spine version","spine_mesh_source_version")
	var bad_png: PackedByteArray = png.duplicate(); bad_png[0] = 0
	invalid_bundle = bundle(); invalid_bundle.pages[PAGE] = {"bytes":bad_png,"sha256":digest(bad_png)}
	invalid_data = mesh(); invalid_data.source.pages[PAGE] = {"bytes":bad_png.size(),"sha256":digest(bad_png)}
	rejected(invalid_bundle,entry(invalid_data),"non-PNG page despite matching metadata","mesh_bake_page_png_header_invalid")
	bad_png = png.duplicate(); bad_png[16] = 1
	invalid_bundle = bundle(); invalid_bundle.pages[PAGE] = {"bytes":bad_png,"sha256":digest(bad_png)}
	invalid_data = mesh(); invalid_data.source.pages[PAGE] = {"bytes":bad_png.size(),"sha256":digest(bad_png)}
	rejected(invalid_bundle,entry(invalid_data),"oversized PNG dimensions before decode","mesh_bake_page_png_header_invalid")
	await consumer_checks(declaration)
	check(source_bytes == originals and FileAccess.get_file_as_bytes(PNG_PATH) == png,"original fixture byte arrays and existing repository PNG remain unchanged")
	print("CHARACTER_SPINE_MESH_FACTORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"FACTORY_AND_CONSUMER_FIXTURES_REUSING_EXISTING_PNG_NOT_ORIGINAL_RENDER"}))
	quit(0 if failures.is_empty() else 1)
