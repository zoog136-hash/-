extends SceneTree
## Synthetic controller/ownership fixtures. Never original artwork or rendering proof.
const VIEW = preload("res://scripts/characters/lobby_source_presentation.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture_root: String = ""
var pack_counter: int = 0
var cases_finished: bool = false

class FixtureCatalog extends RefCounted:
	var rejected: bool = false
	var missing_back: bool = false
	func resolve(class_id: Variant, gender_id: Variant) -> Dictionary:
		if rejected or class_id not in [1, 2] or gender_id != 1:
			return {"ok":false,"status":"invalid_request","problem":"controlled fixture identity error"}
		var number: int = int(class_id)
		var result: Dictionary = {"ok":true,"status":"resolved","class_id":number,"gender_id":1,"synthetic":true,"scope":"SYNTHETIC_RELATION_TEST_NOT_ORIGINAL_DELIVERY","spine":{"ok":true,"status":"resolved","path":"UI/Spine/Body.json","asset_id":100 + number,"offset_x":600,"offset_y":0,"flip":false},"back_effect":{"ok":true,"status":"resolved","path":"UI/CsbFile/Back%d.csb" % number,"asset_id":200 + number},"front_effect":{"ok":true,"status":"optional_zero","path":"","asset_id":0},"missing":[]}
		if missing_back: result.back_effect = {"ok":false,"status":"missing_reference","path":"","asset_id":999,"problem":"controlled missing source row"}
		return result

class FixtureSpineAdapter extends Node2D:
	var last_animation: String = ""
	var last_repeat: bool = false
	var stop_count: int = 0
	func play_source_animation(source_clip: String, repeat: bool) -> Dictionary:
		last_animation = source_clip
		last_repeat = repeat
		return {"ok":true}
	func stop() -> void:
		stop_count += 1

class ReadySpineAdapter extends FixtureSpineAdapter:
	var entered: Callable
	func _ready() -> void:
		if entered.is_valid(): entered.call()

class StopCatalog extends FixtureCatalog:
	func resolve(class_id: Variant, gender_id: Variant) -> Dictionary:
		var result: Dictionary = super.resolve(2 if class_id == 3 else class_id,gender_id)
		if result.get("ok",false) and class_id != 1:
			result["class_id"] = class_id
			result.spine["path"] = "UI/Spine/Next.json"
		return result

class StopSpineAdapter extends FixtureSpineAdapter:
	var stopped: Callable
	func stop() -> void:
		super.stop()
		# A real stop handler can synchronously trigger the next UI selection.
		# Disarm before calling it so the negative fixture cannot recurse forever.
		var callback: Callable = stopped
		stopped = Callable()
		if callback.is_valid(): callback.call()

class CountingPresentation extends "res://scripts/characters/lobby_source_presentation.gd":
	var fit_calls: int = 0
	func fit_preview(allow_upscale: bool = false) -> Dictionary:
		fit_calls += 1
		return super.fit_preview(allow_upscale)

class LateQuadAdapter extends FixtureSpineAdapter:
	var quad: Sprite2D
	var frames: int = 0
	func _process(_delta: float) -> void:
		frames += 1
		if frames == 2:
			add_child(quad)
			set_process(false)

class TrackingPack extends "res://scripts/ui/original_ui/source_pack.gd":
	var releases: int = 0
	func release_cache_leases() -> void:
		releases += 1
		super.release_cache_leases()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_LOBBY_PRESENTATION_FAIL ", label)
	return ok

func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _write(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.close()
	return true

func _options(name: String) -> Dictionary:
	return {"name":name,"rotationSkew":[0,0],"scale":[1,1],"position":[17,23],"size":[120,80],"anchorPoint":[0.5,0.5],"visible":true,"zOrder":0,"color":[255,255,255,255],"alpha":255,"actionTag":1,"touchEnabled":false,"flipX":false,"flipY":false,"customProperty":"","frameEvent":"","callBackName":"","callBackType":""}

func _tree(member: String, sha: String) -> Dictionary:
	return {"_source_sha256":sha,"_decode_blockers":[],"nodeTree":{"_offset":1,"classname":"Node","customClassName":"","options":_options(member.get_file()),"children":[]},"action":{"duration":10,"speed":1.0,"timeLines":[]},"animationList":[{"name":"AuthoredLoop","startIndex":0,"endIndex":10}]}

func _pack(mode: String = "missing_json", version: String = "3.6.52", atlas_page: String = "Body.png", second_body: bool = false) -> TrackingPack:
	pack_counter += 1
	var directory: String = fixture_root.path_join("pack%d" % pack_counter)
	var files: Dictionary = {}
	var scenes: Dictionary = {}
	for number: int in [1,2]:
		var member: String = "UI/CsbFile/Back%d.csb" % number
		# Bytes stand in only for the input to an explicitly synthetic decoded tree.
		var bytes: PackedByteArray = ("synthetic-csb-controller-fixture-%d" % number).to_utf8_buffer()
		check(_write(directory.path_join("originals").path_join(member), bytes), "fixture CSB bytes written")
		files[member] = {"bytes":bytes.size(),"sha256":_sha(bytes)}
		scenes[member] = _tree(member, _sha(bytes))
	if mode != "missing_json":
		var json_bytes: PackedByteArray = JSON.stringify({"skeleton":{"spine":version},"bones":[{"name":"root"}],"slots":[],"skins":{},"animations":{"AuthoredIdle":{}}}).to_utf8_buffer()
		if mode == "malformed_json": json_bytes = "[{".to_utf8_buffer()
		if mode == "invalid_utf8_json": json_bytes = PackedByteArray([255])
		var body: String = "UI/Spine/Body.json"
		check(_write(directory.path_join("originals").path_join(body), json_bytes), "fixture skeleton metadata written")
		files[body] = {"bytes":json_bytes.size(),"sha256":_sha(json_bytes)}
		if mode != "missing_atlas":
			var atlas: String = "UI/Spine/Body.atlas"
			var atlas_bytes: PackedByteArray = (atlas_page + "\nsize: 1,1\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\nregion\n  rotate: false\n  xy: 0,0\n  size: 1,1\n  orig: 1,1\n  offset: 0,0\n  index: -1\n").to_utf8_buffer()
			if mode == "invalid_utf8_atlas": atlas_bytes = PackedByteArray([255])
			if mode == "minimal_atlas": atlas_bytes = "Body.png\n".to_utf8_buffer()
			if mode == "indented_atlas": atlas_bytes = " Body.png \n  size: 1,1\n  format: RGBA8888\n".to_utf8_buffer()
			check(_write(directory.path_join("originals").path_join(atlas), atlas_bytes), "fixture atlas metadata written")
			files[atlas] = {"bytes":atlas_bytes.size(),"sha256":_sha(atlas_bytes)}
			if mode != "missing_page":
				# A one-pixel fixture tests file integrity only; never game art.
				var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
				image.fill(Color.TRANSPARENT)
				var page_bytes: PackedByteArray = image.save_png_to_buffer()
				var page: String = "UI/Spine/Body.png"
				check(_write(directory.path_join("originals").path_join(page), page_bytes), "fixture atlas page written")
				files[page] = {"bytes":page_bytes.size(),"sha256":_sha(page_bytes)}
	var manifest: Dictionary = {"schema":"twilight-original-ui-v1","scenes":scenes,"files":files,"atlases":{},"blockers":[],"lobby_spines":{"UI/Spine/Body.json":{"atlas":"UI/Spine/Body.atlas"}}}
	if second_body:
		for extension: String in ["json","atlas","png"]:
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(directory.path_join("originals/UI/Spine/Body." + extension))
			if extension == "atlas": bytes = bytes.get_string_from_utf8().replace("Body.png","Next.png").to_utf8_buffer()
			var member: String = "UI/Spine/Next." + extension
			check(_write(directory.path_join("originals").path_join(member),bytes), "independent next-character source dependency written")
			files[member] = {"bytes":bytes.size(),"sha256":_sha(bytes)}
		manifest.files = files
		manifest.lobby_spines["UI/Spine/Next.json"] = {"atlas":"UI/Spine/Next.atlas"}
	var manifest_bytes: PackedByteArray = JSON.stringify(manifest).to_utf8_buffer()
	check(_write(directory.path_join("original_ui.json"), manifest_bytes), "fixture pack manifest written")
	var pack := TrackingPack.new()
	check(pack.open(directory, _sha(manifest_bytes)).get("ok", false), "real source pack opens synthetic fixture")
	return pack

func _view(catalog: RefCounted, provider: Callable) -> Control:
	var view = VIEW.new()
	view.catalog = catalog
	view.pack_provider = provider
	root.add_child(view)
	return view

func _layer(view: Control, role: String) -> Dictionary:
	return view.presentation_status().get("layers", {}).get(role, {})

func _scene(view: Control, mount: String) -> Node:
	var holder: Node = view.get_node_or_null("SourcePreviewRoot/" + mount)
	return holder.get_child(0) if holder != null and holder.get_child_count() > 0 else null

func _save_hashes() -> Dictionary:
	var out: Dictionary = {}
	for name: String in ["twilight_v20_save.json","twilight_native_png_save.json","twilight_full_cards_test_v1.json","twilight_native_png_full_cards_test_v1.json","twilight_growth_lab_v1.json"]:
		for suffix: String in ["", ".source-map-current.json"]:
			var path: String = "user://" + name + suffix
			out[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return out

func run() -> void:
	fixture_root = "user://lobby_presentation_test_%d" % Time.get_ticks_usec()
	if DirAccess.dir_exists_absolute(fixture_root): quit(2); return
	var before_saves: Dictionary = _save_hashes()
	var old_bake: bool = PACK.bake_enabled
	PACK.bake_enabled = false
	await _run_cases()
	check(cases_finished, "every presentation and fit case reached its final completion point")
	PACK.bake_enabled = old_bake
	check(_save_hashes() == before_saves, "presentation never creates or changes account/save pointer bytes")
	print("CHARACTER_LOBBY_PRESENTATION_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"scope":"synthetic source relations, pack integrity and actual CSB controller; not original art, original placement, Spine rendering or device acceptance"}))
	quit(0 if failures.is_empty() else 1)

func _run_cases() -> void:
	var catalog := FixtureCatalog.new()
	var unselected: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":false})
	var unavailable: Dictionary = unselected.select_profile(1,1)
	check(unavailable.get("ok",false), "optional missing art does not invalidate the character selection")
	check(_layer(unselected,"spine").get("status") == "pack_unselected", "unselected original pack is explicit")
	check(_layer(unselected,"back_effect").get("status") == "pack_unselected" and _layer(unselected,"front_effect").get("status") == "optional_zero", "optional zero is independent of unavailable pack")
	check(not unavailable.get("has_layers",true) and not unavailable.get("rendered",true) and not unavailable.get("original_render_verified",true), "missing pack never claims source rendering")
	unselected.queue_free()
	await process_frame

	var pack: TrackingPack = _pack()
	var before_release: int = pack.releases
	var view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":pack})
	var ready: Dictionary = view.select_profile(1,1)
	check(ready.get("ok",false) and ready.get("has_layers",false), "valid source CSB component is mounted without requiring a skeleton")
	check(_layer(view,"back_effect").get("status") == "mounted", "actual production CSB renderer mounts the exact member")
	check(_layer(view,"spine").get("status") == "missing_files", "uninstalled skeleton JSON is distinguished from renderer absence")
	check(_layer(view,"front_effect").get("status") == "optional_zero", "zero foreground reference creates no replacement")
	var stage: Node2D = view.get_node("SourcePreviewRoot")
	check(stage.get_child_count() == 3 and stage.get_child(0).name == "BackEffect" and stage.get_child(1).name == "SpineBody" and stage.get_child(2).name == "FrontEffect", "source layer mount order is back-body-front")
	check(stage.get_child(0).z_index < stage.get_child(1).z_index and stage.get_child(1).z_index < stage.get_child(2).z_index, "source layer z order remains explicit")
	var first: Node = _scene(view,"BackEffect")
	if check(first != null, "CSB scene exists below the back mount"):
		check(first.source_member == "UI/CsbFile/Back1.csb", "class identity selects its exact CSB source path")
		check(first.position == Vector2.ZERO and first.scale == Vector2.ONE, "source offset metadata is not guessed into component geometry")
		check(first.get_child(0).position == Vector2(17,-23), "decoded original node geometry is retained")
		check(not first.playback_status().playing, "mounting does not guess an original default clip")
		check(_layer(view,"back_effect").get("clips",[]) == ["AuthoredLoop"], "only original animationList names are exposed")
		check(not view.play_layer("back_effect","invented_clip").get("ok",true) and not first.playback_status().playing, "missing clip cannot start substitute playback")
		check(view.play_layer("back_effect","AuthoredLoop",true).get("ok",false), "explicitly selected original clip starts")
		check(first.playback_status().playing and first.playback_status().loop, "explicit loop policy reaches production source playback")
		check(not view.play_layer("spine","AuthoredIdle").get("ok",true), "missing Spine runtime cannot report animation playback")
		check(not view.play_layer("other","AuthoredLoop").get("ok",true), "unknown layer cannot hijack another mount")
	var tampered: Dictionary = view.presentation_status()
	tampered.layers.back_effect["path"] = "changed"
	check(_layer(view,"back_effect").get("path") == "UI/CsbFile/Back1.csb", "status callers cannot mutate current source identity")
	var first_ref: WeakRef = weakref(first) if first != null else null
	check(view.select_profile(2,1).get("ok",false), "new identity replaces prior presentation")
	await process_frame
	check(first_ref == null or first_ref.get_ref() == null, "old character scene is freed on selection change")
	check(_scene(view,"BackEffect") != null and _scene(view,"BackEffect").source_member == "UI/CsbFile/Back2.csb", "new character never retains prior effect")
	check(pack.releases > before_release, "selection change releases prior pack leases")
	view.clear_selection()
	await process_frame
	check(not view.presentation_status().get("has_layers",true) and _scene(view,"BackEffect") == null, "cancel removes all active components")
	check(not view.play_layer("back_effect","AuthoredLoop").get("ok",true), "cancelled effects cannot resume")
	view.queue_free()
	await process_frame

	var invalid_catalog := FixtureCatalog.new()
	invalid_catalog.rejected = true
	var provider_calls: Array[int] = [0]
	var invalid: Control = _view(invalid_catalog, func() -> Dictionary: provider_calls[0] += 1; return {"ok":true,"selected":true,"pack":pack})
	check(not invalid.select_profile(1,1).get("ok",true) and provider_calls[0] == 0, "invalid definition selection never reaches an asset provider")
	check(not invalid.presentation_status().get("has_layers",true), "invalid definition leaves no mounted content")
	invalid.queue_free()
	await process_frame

	for response: Dictionary in [{"ok":false,"selected":true,"error":"controlled pack failure"},{"ok":true,"selected":true,"pack":null},{"ok":true,"selected":true,"pack":{}},{"ok":1,"selected":true,"pack":pack},{"ok":true,"selected":1,"pack":pack}]:
		var failed: Control = _view(catalog, func() -> Dictionary: return response)
		failed.select_profile(1,1)
		check(_layer(failed,"back_effect").get("status") == "pack_error" and not failed.presentation_status().get("has_layers",true), "provider errors preserve an empty, explicit unavailable state")
		failed.queue_free()
		await process_frame

	var missing_catalog := FixtureCatalog.new()
	missing_catalog.missing_back = true
	var missing: Control = _view(missing_catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":pack})
	missing.select_profile(1,1)
	check(_layer(missing,"back_effect").get("status") == "missing_reference" and _scene(missing,"BackEffect") == null, "missing nonzero source row is not filled from another class")
	check(_layer(missing,"front_effect").get("status") == "optional_zero", "missing and authored absent effects remain separate")
	missing.queue_free()
	await process_frame

	for mode: String in ["missing_atlas","missing_page","complete"]:
		var body_pack: TrackingPack = _pack(mode)
		var body_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":body_pack})
		body_view.select_profile(1,1)
		check(_layer(body_view,"spine").get("status") == ("missing_runtime" if mode == "complete" else "missing_files"), "skeleton dependency state is exact: " + mode)
		check(not body_view.presentation_status().get("original_render_verified",true) and _scene(body_view,"SpineBody") == null, "file presence never becomes Spine or original-render success")
		body_view.queue_free()
		await process_frame

	var no_binding_pack: TrackingPack = _pack("complete")
	no_binding_pack.manifest.erase("lobby_spines")
	var no_binding: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":no_binding_pack})
	no_binding.select_profile(1,1)
	check(_layer(no_binding,"spine").get("status") == "missing_binding", "matching atlas filename alone does not invent a source relation")
	no_binding.queue_free()
	await process_frame

	var traversal_pack: TrackingPack = _pack("complete")
	traversal_pack.manifest.lobby_spines["UI/Spine/Body.json"].atlas = "../outside.atlas"
	var traversal: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":traversal_pack})
	traversal.select_profile(1,1)
	check(_layer(traversal,"spine").get("status") == "invalid_files", "atlas path traversal is refused before any read")
	traversal.queue_free()
	await process_frame

	var changed_pack: TrackingPack = _pack()
	check(_write(changed_pack.root.path_join("originals/UI/CsbFile/Back1.csb"), "externally changed source".to_utf8_buffer()), "controlled source-byte modification written")
	var changed: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":changed_pack})
	changed.select_profile(1,1)
	check(_layer(changed,"back_effect").get("status") == "invalid_files" and _scene(changed,"BackEffect") == null, "post-open source size/hash changes cannot draw the cached scene")
	changed.queue_free()
	await process_frame

	var mismatch_pack: TrackingPack = _pack()
	mismatch_pack.manifest.scenes["UI/CsbFile/Back1.csb"]._source_sha256 = "0".repeat(64)
	var mismatch: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":mismatch_pack})
	mismatch.select_profile(1,1)
	check(_layer(mismatch,"back_effect").get("status") == "invalid_files" and _scene(mismatch,"BackEffect") == null, "decoded tree must name the exact verified raw CSB bytes")
	mismatch.queue_free()
	await process_frame

	var unsupported_pack: TrackingPack = _pack()
	unsupported_pack.manifest.scenes["UI/CsbFile/Back1.csb"].nodeTree.classname = "UnknownSkeleton"
	var unsupported: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":unsupported_pack})
	unsupported.select_profile(1,1)
	check(_layer(unsupported,"back_effect").get("status") == "renderer_error" and _scene(unsupported,"BackEffect") == null, "unsupported decoded scene is rejected by production renderer")
	unsupported.queue_free()
	await process_frame

	var stale_pack: TrackingPack = _pack()
	var current_pack: TrackingPack = _pack()
	var stale_releases: int = stale_pack.releases
	var call_number: Array[int] = [0]
	var reentrant = VIEW.new()
	reentrant.catalog = catalog
	reentrant.pack_provider = func() -> Dictionary:
		call_number[0] += 1
		if call_number[0] == 1:
			reentrant.select_profile(2,1)
			return {"ok":true,"selected":true,"pack":stale_pack}
		return {"ok":true,"selected":true,"pack":current_pack}
	root.add_child(reentrant)
	var stale_result: Dictionary = reentrant.select_profile(1,1)
	check(not stale_result.get("ok",true) and stale_result.get("status") == "superseded", "late prior selection result is reported as superseded")
	check(reentrant.presentation_status().get("class_id") == 2 and _scene(reentrant,"BackEffect").source_member == "UI/CsbFile/Back2.csb", "late provider cannot replace a newer character")
	check(stale_pack.releases > stale_releases, "late unused pack leases are released")
	var detach_releases: int = current_pack.releases
	root.remove_child(reentrant)
	await process_frame
	check(current_pack.releases > detach_releases and _scene(reentrant,"BackEffect") == null, "screen removal stops, frees and releases current presentation")
	reentrant.free()

	var adapter_pack: TrackingPack = _pack("complete")
	var adapted: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":adapter_pack})
	var adapter := FixtureSpineAdapter.new()
	var verified_bundle: Dictionary = {}
	adapted.spine_factory = func(bundle: Dictionary) -> Dictionary:
		verified_bundle.merge(bundle,true)
		return {"ok":true,"node":adapter,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	adapted.select_profile(1,1)
	check(_layer(adapted,"spine").get("status") == "mounted" and _scene(adapted,"SpineBody") == adapter, "explicit compatible adapter mounts only after dependency verification")
	check(verified_bundle.get("autoplay") == false and verified_bundle.get("major_minor") == "3.6" and verified_bundle.get("json_path") == "UI/Spine/Body.json", "adapter receives actual source version and disabled autoplay")
	check(verified_bundle.get("pages",{}).has("UI/Spine/Body.png") and not verified_bundle.get("json_bytes",PackedByteArray()).is_empty(), "adapter receives only verified skeleton/atlas/page bytes")
	check(adapter.position == Vector2.ZERO and adapter.scale == Vector2.ONE and not adapted.presentation_status().get("source_offset_applied",true), "Spine metadata does not become an invented source placement")
	check(adapter.last_animation.is_empty(), "adapter mounting never chooses a clip automatically")
	check(not adapted.play_layer("spine","made_up").get("ok",true) and adapter.last_animation.is_empty(), "unknown Spine animation cannot reach an adapter")
	check(adapted.play_layer("spine","AuthoredIdle",false).get("ok",false) and adapter.last_animation == "AuthoredIdle" and not adapter.last_repeat, "explicit actual skeleton animation reaches the adapter")
	check(not adapted.presentation_status().get("rendered",true) and not adapted.presentation_status().get("original_render_verified",true), "synthetic adapter success remains separate from original visual acceptance")
	var adapter_ref: WeakRef = weakref(adapter)
	adapted.clear_selection()
	check(adapter.stop_count == 1, "adapter receives stop before removal")
	await process_frame
	check(adapter_ref.get_ref() == null, "adapter is freed on cancellation")
	adapted.queue_free()
	await process_frame

	for fault: String in ["factory_failed","numeric_ok","version","source_hash","autoplay","numeric_autoplay"]:
		var fault_pack: TrackingPack = _pack("complete")
		var fault_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":fault_pack})
		var fault_node := FixtureSpineAdapter.new()
		var fault_ref: WeakRef = weakref(fault_node)
		fault_view.spine_factory = func(bundle: Dictionary) -> Dictionary:
			var returned: Dictionary = {"ok":true,"node":fault_node,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
			match fault:
				"factory_failed": returned.ok = false
				"numeric_ok": returned.ok = 1
				"version": returned.supported_major_minor = "4.2"
				"source_hash": returned.source_sha256 = "0".repeat(64)
				"autoplay": returned.autoplay_disabled = false
				"numeric_autoplay": returned.autoplay_disabled = 1
			return returned
		fault_view.select_profile(1,1)
		check(_layer(fault_view,"spine").get("status") == "renderer_error" and _scene(fault_view,"SpineBody") == null, "invalid adapter contract is refused: " + fault)
		await process_frame
		check(fault_ref.get_ref() == null, "failed adapter node is disposed: " + fault)
		if fault_ref.get_ref() != null and fault_node.get_parent() == null: fault_node.free()
		fault_view.queue_free()
		await process_frame

	var occupied_pack: TrackingPack = _pack("complete")
	var owner := Node2D.new()
	root.add_child(owner)
	var occupied_node := FixtureSpineAdapter.new()
	owner.add_child(occupied_node)
	var occupied: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":occupied_pack})
	occupied.spine_factory = func(bundle: Dictionary) -> Dictionary: return {"ok":true,"node":occupied_node,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	occupied.select_profile(1,1)
	check(_layer(occupied,"spine").get("status") == "renderer_error" and occupied_node.get_parent() == owner, "adapter cannot steal an already-owned node")
	occupied.queue_free()
	await process_frame
	check(is_instance_valid(occupied_node) and occupied_node.get_parent() == owner, "rejecting a foreign node does not dispose its actual owner's content")
	owner.queue_free()
	await process_frame

	var cancelled_pack: TrackingPack = _pack("complete")
	var cancelled: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":cancelled_pack})
	var cancelled_node := FixtureSpineAdapter.new()
	var cancelled_ref: WeakRef = weakref(cancelled_node)
	cancelled.spine_factory = func(bundle: Dictionary) -> Dictionary:
		cancelled.clear_selection()
		return {"ok":true,"node":cancelled_node,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	var cancelled_result: Dictionary = cancelled.select_profile(1,1)
	check(cancelled_result.get("status") == "superseded" and not cancelled.presentation_status().get("has_layers",true), "cancellation during factory creation cannot remount a prior selection")
	await process_frame
	check(cancelled_ref.get_ref() == null and _scene(cancelled,"SpineBody") == null, "superseded adapter output is disposed")
	cancelled.queue_free()
	await process_frame

	for version: String in ["", "3", "-1.6", "0.6", "3.-1", "3.x"]:
		var version_pack: TrackingPack = _pack("complete",version)
		var version_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":version_pack})
		version_view.select_profile(1,1)
		check(_layer(version_view,"spine").get("status") == "invalid_files", "malformed exported runtime version is refused: " + version)
		version_view.queue_free()
		await process_frame

	var bad_atlas_pack: TrackingPack = _pack("complete","3.6.52","../outside.png")
	var bad_atlas: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":bad_atlas_pack})
	bad_atlas.select_profile(1,1)
	check(_layer(bad_atlas,"spine").get("status") == "invalid_files", "atlas page traversal is rejected independently of an explicit safe atlas binding")
	bad_atlas.queue_free()
	await process_frame

	for bad_clips: Variant in [{},17,"clip",null,[{"name":"Repeated"},{"name":"Repeated"}]]:
		var clip_pack: TrackingPack = _pack()
		clip_pack.manifest.scenes["UI/CsbFile/Back1.csb"].animationList = bad_clips
		var clip_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":clip_pack})
		clip_view.select_profile(1,1)
		check(_layer(clip_view,"back_effect").get("status") == "invalid_files" and _scene(clip_view,"BackEffect") == null, "invalid source clip list is refused before renderer calls")
		clip_view.queue_free()
		await process_frame

	var signal_pack: TrackingPack = _pack()
	var signal_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":signal_pack})
	signal_view.presentation_changed.connect(func(state: Dictionary) -> void:
		if state.get("class_id") == 1: signal_view.clear_selection())
	var signal_result: Dictionary = signal_view.select_profile(1,1)
	check(signal_result.get("status") == "superseded" and not signal_view.presentation_status().get("has_layers",true), "selection change from a published signal supersedes the returned old state")
	signal_view.queue_free()
	await process_frame

	var play_signal_pack: TrackingPack = _pack()
	var play_signal: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":play_signal_pack})
	play_signal.select_profile(1,1)
	play_signal.presentation_changed.connect(func(state: Dictionary) -> void:
		if state.get("layers",{}).get("back_effect",{}).get("playing",false): play_signal.clear_selection())
	var play_result: Dictionary = play_signal.play_layer("back_effect","AuthoredLoop")
	check(play_result.get("status") == "superseded" and not play_signal.presentation_status().get("has_layers",true), "cancellation from a playback signal cannot return stale success")
	play_signal.queue_free()
	await process_frame

	var ready_pack: TrackingPack = _pack("complete")
	var ready_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":ready_pack})
	var ready_adapter := ReadySpineAdapter.new()
	var ready_ref: WeakRef = weakref(ready_adapter)
	ready_adapter.entered = func() -> void: ready_view.clear_selection()
	ready_view.spine_factory = func(bundle: Dictionary) -> Dictionary: return {"ok":true,"node":ready_adapter,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	var ready_result: Dictionary = ready_view.select_profile(1,1)
	check(ready_result.get("status") == "superseded" and not ready_view.presentation_status().get("has_layers",true), "ready callback cannot leave a stale newly mounted adapter behind")
	await process_frame
	check(ready_ref.get_ref() == null and _scene(ready_view,"SpineBody") == null, "ready callback cancellation releases the node that was entering the tree")
	ready_view.queue_free()
	await process_frame

	for format_mode: String in ["minimal_atlas", "indented_atlas", "malformed_json"]:
		var format_pack: TrackingPack = _pack(format_mode)
		var format_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":format_pack})
		format_view.select_profile(1,1)
		check(_layer(format_view,"spine").get("status") == ("invalid_files" if format_mode == "malformed_json" else "missing_runtime"), "documented source input form is handled without engine errors: " + format_mode)
		format_view.queue_free()
		await process_frame

	var page_change_pack: TrackingPack = _pack("complete")
	check(_write(page_change_pack.root.path_join("originals/UI/Spine/Body.png"), "changed page bytes".to_utf8_buffer()), "controlled source-page modification written")
	var page_change: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":page_change_pack})
	var factory_calls: Array[int] = [0]
	page_change.spine_factory = func(_bundle: Dictionary) -> Dictionary: factory_calls[0] += 1; return {"ok":false}
	page_change.select_profile(1,1)
	check(_layer(page_change,"spine").get("status") == "invalid_files" and factory_calls[0] == 0, "every atlas page is hash-checked before any installed runtime receives bytes")
	page_change.queue_free()
	await process_frame

	for unused_response: Dictionary in [{"ok":false,"selected":true,"pack":pack},{"ok":true,"selected":false,"pack":pack}]:
		var unused_before: int = pack.releases
		var unused: Control = _view(catalog, func() -> Dictionary: return unused_response)
		unused.select_profile(1,1)
		check(pack.releases > unused_before and not unused.presentation_status().get("has_layers",true), "unused failure/unselected provider pack releases its leases")
		unused.queue_free()
		await process_frame

	for encoding_mode: String in ["invalid_utf8_json", "invalid_utf8_atlas"]:
		var encoding_pack: TrackingPack = _pack(encoding_mode)
		var encoding_view: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":encoding_pack})
		encoding_view.select_profile(1,1)
		check(_layer(encoding_view,"spine").get("status") == "invalid_files", "invalid UTF-8 source is refused without text-decoding engine errors: " + encoding_mode)
		encoding_view.queue_free()
		await process_frame

	var exit_pack: TrackingPack = _pack()
	var exiting: Control = _view(catalog, func() -> Dictionary: return {"ok":true,"selected":true,"pack":exit_pack})
	exiting.select_profile(1,1)
	var attempted_exit_reentry: Array[bool] = [false]
	exiting.presentation_changed.connect(func(state: Dictionary) -> void:
		if state.get("status") == "cleared" and not attempted_exit_reentry[0]:
			attempted_exit_reentry[0] = true
			exiting.select_profile(2,1))
	root.remove_child(exiting)
	await process_frame
	check(attempted_exit_reentry[0] and not exiting.presentation_status().get("has_layers",true) and _scene(exiting,"BackEffect") == null, "a stale cleared-signal callback cannot resurrect content after screen exit")
	exiting.free()
	await process_frame

	for valid_text: String in ["", "ASCII", "한글", "é", "🙂", "\u0085"]:
		check(VIEW._utf8_valid(valid_text.to_utf8_buffer()), "valid UTF-8 scalar sequence is preserved: " + valid_text)
	for invalid_utf8: Array in [[255],[192,175],[237,160,128],[244,144,128,128],[226,130],[226,40,161],[128],[245,128,128,128]]:
		check(not VIEW._utf8_valid(PackedByteArray(invalid_utf8)), "noncanonical or invalid UTF-8 scalar sequence is rejected")

	await _stop_reentry_case(false,false)
	await _stop_reentry_case(true,false)
	await _stop_reentry_case(false,true)
	await _stop_reentry_case(true,true)
	await _stop_cancel_case()
	await _fit_cases()

func _stop_reentry_case(shared_pack: bool, clearing: bool) -> void:
	var identity := StopCatalog.new()
	var first_pack: TrackingPack = _pack("complete","3.6.52","Body.png",true)
	var latest_pack: TrackingPack = first_pack if shared_pack else _pack("complete","3.6.52","Body.png",true)
	var first_adapter := StopSpineAdapter.new()
	var latest_adapter := StopSpineAdapter.new()
	var current = VIEW.new()
	current.catalog = identity
	current.pack_provider = func() -> Dictionary:
		var active: TrackingPack = first_pack if current.presentation_status().get("class_id") == 1 else latest_pack
		return {"ok":true,"selected":true,"pack":active}
	current.spine_factory = func(bundle: Dictionary) -> Dictionary:
		var first_selection: bool = current.presentation_status().get("class_id") == 1
		var active: TrackingPack = first_pack if first_selection else latest_pack
		var page_member: String = str(bundle.pages.keys()[0])
		var image: Image = active._page(page_member)
		check(image != null, "stop reentry fixture acquires a real source-pack page lease")
		return {"ok":true,"node":first_adapter if first_selection else latest_adapter,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	root.add_child(current)
	current.select_profile(1,1)
	check(_layer(current,"spine").get("status") == "mounted" and first_pack.cache_stats().get("instance_page_leases",0) > 0, "first adapter owns its verified source-page lease")
	var destination: int = 2 if clearing else 3
	first_adapter.stopped = func() -> void: current.select_profile(destination,1)
	var older_result: Dictionary = {}
	if clearing:
		current.clear_selection()
	else:
		older_result = current.select_profile(2,1)
	var context: String = ("shared" if shared_pack else "separate") + (" clear" if clearing else " select")
	if not clearing: check(older_result.get("status") == "superseded", "older request reports its stop-callback replacement: " + context)
	check(current.presentation_status().get("class_id") == destination and current.presentation_status().get("has_layers",false), "stop callback's latest selection remains current: " + context)
	check(_scene(current,"SpineBody") == latest_adapter and current.play_layer("spine","AuthoredIdle").get("ok",false), "latest adapter remains registered after outer cleanup: " + context)
	check(latest_pack.cache_stats().get("instance_page_leases",0) > 0, "outer cleanup cannot release the latest selection's source-page lease: " + context)
	check(latest_pack.cache_stats().get("instance_page_leases",0) == 1, "retired character pages are returned while the independent latest page stays leased: " + context)
	check(first_adapter.stop_count == 1, "retiring adapter is stopped once despite a synchronous new selection: " + context)
	current.queue_free()
	await process_frame
	check(latest_pack.cache_stats().get("instance_page_leases",0) == 0, "closing the latest selection returns its source-page lease: " + context)

func _stop_cancel_case() -> void:
	var identity := StopCatalog.new()
	var pack: TrackingPack = _pack("complete")
	var adapter := StopSpineAdapter.new()
	var current: Control = _view(identity,func() -> Dictionary: return {"ok":true,"selected":true,"pack":pack})
	current.spine_factory = func(bundle: Dictionary) -> Dictionary: return {"ok":true,"node":adapter,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	current.select_profile(1,1)
	adapter.stopped = func() -> void: current.clear_selection()
	var result: Dictionary = current.select_profile(2,1)
	check(result.get("status") == "superseded" and current.presentation_status().get("class_id") == 0 and not current.presentation_status().get("has_layers",true), "cancel from a stop callback cannot be overwritten by the older selection")
	check(adapter.stop_count == 1 and _scene(current,"SpineBody") == null, "stop cancellation cannot recursively stop the same old adapter")
	current.queue_free()
	await process_frame

func _quad(texture_size: Vector2i) -> Sprite2D:
	# Geometric test input, never an original or replacement game image.
	var image := Image.create(texture_size.x,texture_size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	return sprite

func _geometry_view(adapter: Node2D, host_size: Vector2 = Vector2(160,120)) -> CountingPresentation:
	var pack: TrackingPack = _pack("complete")
	var view := CountingPresentation.new()
	view.size = host_size
	view.catalog = FixtureCatalog.new()
	view.pack_provider = func() -> Dictionary: return {"ok":true,"selected":true,"pack":pack}
	view.spine_factory = func(bundle: Dictionary) -> Dictionary: return {"ok":true,"node":adapter,"supported_major_minor":bundle.major_minor,"source_sha256":bundle.source_sha256,"autoplay_disabled":true}
	root.add_child(view)
	view.select_profile(1,1)
	return view

func _sprite_snapshot(sprite: Sprite2D) -> Dictionary:
	return {"transform":sprite.transform,"offset":sprite.offset,"centered":sprite.centered,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,"region_enabled":sprite.region_enabled,"region_rect":sprite.region_rect,"hframes":sprite.hframes,"vframes":sprite.vframes,"frame":sprite.frame,"texture":sprite.texture,"visible":sprite.visible,"modulate":sprite.modulate,"self_modulate":sprite.self_modulate}

func _inside_host(view: Control, sprite: Sprite2D) -> bool:
	var to_host: Transform2D = view.get_global_transform().affine_inverse() * sprite.get_global_transform()
	var rect: Rect2 = sprite.get_rect()
	var bounds := Rect2(Vector2.ZERO,view.size).grow(0.01)
	for corner: Vector2 in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var point: Vector2 = to_host * corner
		if not is_finite(point.x) or not is_finite(point.y) or not bounds.has_point(point): return false
	return true

func _frames(count: int) -> void:
	for index: int in count: await process_frame

func _fit_cases() -> void:
	var adapter := FixtureSpineAdapter.new()
	adapter.position = Vector2(-170,310)
	adapter.rotation = 0.35
	adapter.scale = Vector2(1.3,0.8)
	var large: Sprite2D = _quad(Vector2i(512,256))
	large.position = Vector2(830,-620)
	large.rotation = -0.71
	large.scale = Vector2(-1.8,1.2)
	large.offset = Vector2(11,-7)
	large.flip_h = true
	adapter.add_child(large)
	var geometry: CountingPresentation = _geometry_view(adapter)
	geometry.rotation = 0.21
	geometry.scale = Vector2(0.75,1.4)
	var sprite_before: Dictionary = _sprite_snapshot(large)
	var adapter_before: Transform2D = adapter.transform
	var mount_before: Transform2D = geometry.get_node("SourcePreviewRoot/SpineBody").transform
	var view_before: Transform2D = geometry.get_transform()
	var fit_signals: Array[int] = [0]
	geometry.presentation_changed.connect(func(_state: Dictionary) -> void: fit_signals[0] += 1)
	var fitted: Dictionary = geometry.fit_preview()
	check(fitted.get("ok",false) and fitted.get("status") == "fitted" and fitted.get("quads") == 1, "large offset/rotated/mirrored source quad is fitted from its actual geometry")
	check(float(fitted.get("scale",0)) > 0 and float(fitted.get("scale",2)) < 1 and _inside_host(geometry,large), "actual transformed corners fit the host under rotated nonuniform parent transforms")
	check(_sprite_snapshot(large) == sprite_before and adapter.transform == adapter_before and geometry.get_node("SourcePreviewRoot/SpineBody").transform == mount_before and geometry.get_transform() == view_before, "only the preview host changes, preserving every source/local geometry field")
	check(fitted.get("original_source_geometry_changed") == false and fitted.get("rendered") == false and not fitted.get("original_lobby_layout_verified",true), "host fit is not original source layout or rendering acceptance")
	check(fit_signals[0] == 0, "fit does not emit a presentation signal that could cause resize feedback")
	var again: Dictionary = geometry.fit_preview()
	check(fitted.get("source_bounds").position.distance_to(again.get("source_bounds").position) <= 0.01 and fitted.get("source_bounds").size.distance_to(again.get("source_bounds").size) <= 0.01 and absf(float(fitted.get("scale")) - float(again.get("scale"))) <= 0.000001 and fitted.get("position").distance_to(again.get("position")) <= 0.01 and _inside_host(geometry,large), "fit is stable within subpixel float precision rather than accumulating its prior host transform")
	var stage: Node2D = geometry.get_node("SourcePreviewRoot")
	stage.transform = Transform2D(Vector2.ZERO,Vector2.ZERO,stage.position)
	check(geometry.fit_preview().get("status") == "invalid_transform", "singular stage transform cannot be inverted or fitted")
	stage.transform = Transform2D.IDENTITY
	geometry.size = Vector2.ZERO
	check(geometry.fit_preview().get("status") == "empty_viewport", "zero-size host refuses a meaningless fit")
	geometry.queue_free()
	await process_frame

	var small_adapter := FixtureSpineAdapter.new()
	var small: Sprite2D = _quad(Vector2i(8,4))
	small.position = Vector2(15,-8)
	small_adapter.add_child(small)
	var small_view: CountingPresentation = _geometry_view(small_adapter)
	var small_before: Dictionary = _sprite_snapshot(small)
	var capped: Dictionary = small_view.fit_preview()
	check(capped.get("status") == "fitted" and is_equal_approx(float(capped.get("scale",0)),1), "default preview policy never enlarges a small source quad")
	var enlarged: Dictionary = small_view.fit_preview(true)
	check(enlarged.get("status") == "fitted" and float(enlarged.get("scale",0)) > 1 and _inside_host(small_view,small), "explicit host upscale can enlarge and still contain the source quad")
	check(_sprite_snapshot(small) == small_before, "upscale policy also leaves the original source sprite unchanged")
	small_view.queue_free()
	await process_frame

	var empty_adapter := FixtureSpineAdapter.new()
	var hidden: Sprite2D = _quad(Vector2i(20,10))
	hidden.visible = false
	empty_adapter.add_child(hidden)
	var no_texture := Sprite2D.new()
	empty_adapter.add_child(no_texture)
	var empty_rect: Sprite2D = _quad(Vector2i(20,10))
	empty_rect.region_enabled = true
	empty_rect.region_rect = Rect2()
	empty_adapter.add_child(empty_rect)
	var singular_quad: Sprite2D = _quad(Vector2i(20,10))
	singular_quad.transform = Transform2D(Vector2.ZERO,Vector2(-sin(0.5),cos(0.5)),Vector2.ZERO)
	empty_adapter.add_child(singular_quad)
	var empty_view: CountingPresentation = _geometry_view(empty_adapter)
	check(empty_view.fit_preview().get("status") == "no_visible_quads", "hidden, null-texture, empty and singular source quads do not fabricate visible bounds")
	empty_view.queue_free()
	await process_frame

	var boundaries_adapter := FixtureSpineAdapter.new()
	var owned: Sprite2D = _quad(Vector2i(64,32))
	owned.position = Vector2(100,-200)
	boundaries_adapter.add_child(owned)
	var independent: Sprite2D = _quad(Vector2i(10,10))
	independent.top_level = true
	independent.position = Vector2(1000,1000)
	boundaries_adapter.add_child(independent)
	var plain := Node.new()
	boundaries_adapter.add_child(plain)
	var plain_child: Sprite2D = _quad(Vector2i(10,10))
	plain_child.position = Vector2(-1000,-1000)
	plain.add_child(plain_child)
	var canvas := CanvasLayer.new()
	boundaries_adapter.add_child(canvas)
	var canvas_child: Sprite2D = _quad(Vector2i(10,10))
	canvas_child.position = Vector2(2000,-2000)
	canvas.add_child(canvas_child)
	var boundary_view: CountingPresentation = _geometry_view(boundaries_adapter)
	var independent_before: Transform2D = independent.get_global_transform()
	var plain_before: Transform2D = plain_child.get_global_transform()
	var canvas_before: Transform2D = canvas_child.get_global_transform()
	var bounded: Dictionary = boundary_view.fit_preview()
	check(bounded.get("status") == "fitted" and bounded.get("quads") == 1 and int(bounded.get("excluded_transform_boundaries",0)) >= 3, "independent transform/canvas branches do not enter the host-fit denominator")
	check(bounded.get("bounds_scope") == "visible_sprites_inheriting_host_transform" and _inside_host(boundary_view,owned), "reported fit scope covers the actual owned visible quad")
	check(independent.get_global_transform() == independent_before and plain_child.get_global_transform() == plain_before and canvas_child.get_global_transform() == canvas_before, "fitting owned content never alters independent canvas content")
	boundary_view.get_node("SourcePreviewRoot").top_level = true
	check(boundary_view.fit_preview().get("status") == "invalid_transform", "a top-level stage cannot claim coordinates relative to the host")
	boundary_view.queue_free()
	await process_frame

	var bounded_pack: TrackingPack = _pack()
	var bounded_view := CountingPresentation.new()
	bounded_view.size = Vector2(160,120)
	bounded_view.catalog = FixtureCatalog.new()
	bounded_view.pack_provider = func() -> Dictionary: return {"ok":true,"selected":true,"pack":bounded_pack}
	root.add_child(bounded_view)
	bounded_view.select_profile(1,1)
	bounded_view.fit_calls = 0
	await _frames(8)
	var bounded_calls: int = bounded_view.fit_calls
	check(bounded_calls > 0 and bounded_calls <= 4, "empty first-frame retry work is bounded to four future frames")
	await _frames(5)
	check(bounded_view.fit_calls == bounded_calls and not bounded_view.is_processing(), "preview does not keep a permanent per-frame geometry traversal")
	bounded_view.select_profile(1,1)
	bounded_view.clear_selection()
	bounded_view.fit_calls = 0
	await _frames(8)
	check(bounded_view.fit_calls == 0 and not bounded_view.presentation_status().get("has_layers",true), "cancel invalidates deferred fit work from the previous selection")
	bounded_view.queue_free()
	await process_frame

	var late_adapter := LateQuadAdapter.new()
	late_adapter.quad = _quad(Vector2i(400,200))
	late_adapter.quad.position = Vector2(700,-500)
	var late_view: CountingPresentation = _geometry_view(late_adapter)
	late_view.fit_calls = 0
	await _frames(8)
	check(late_adapter.frames == 2 and late_adapter.quad.get_parent() == late_adapter and late_view.presentation_status().get("preview_fit",{}).get("status") == "fitted", "bounded later-frame retries discover quads created by an emitter after startup")
	check(late_view.fit_calls > 0 and late_view.fit_calls <= 4 and _inside_host(late_view,late_adapter.quad), "late-created source quads are actually within the host after bounded fitting")
	var late_calls: int = late_view.fit_calls
	await _frames(5)
	check(late_view.fit_calls == late_calls, "successful late fitting also stops retry traversal after its bounded window")
	late_view.queue_free()
	await process_frame
	cases_finished = true
