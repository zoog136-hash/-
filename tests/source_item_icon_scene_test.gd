extends SceneTree
## Uses real UI v2 classes with a no-pixel contract fixture. Not original CSB.
const ADAPTER = preload("res://scripts/ui/source_item_icon_scene.gd")
const IDENTITY = preload("res://scripts/ui/source_item_icon_identity.gd")
const VISUAL = preload("res://scripts/ui/item_visual.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var directory: String = "user://item-scene-unit-fixture"
	var literal: String = "icon/UNIT_CONTRACT_FIXTURE.csb"
	var member: String = "UI/CsbFile/" + literal
	DirAccess.make_dir_recursive_absolute(directory.path_join("originals/UI/CsbFile/icon"))
	var bytes: PackedByteArray = "UNIT CONTRACT FIXTURE; NOT ORIGINAL CSB".to_utf8_buffer()
	var source_hash: String = INSTALL.sha(bytes)
	var file := FileAccess.open(directory.path_join("originals/" + member), FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
	var widget: Dictionary = {"name":"ContractFixture","rotationSkew":[0,0],"scale":[1,1],"position":[0,0],"visible":true,"zOrder":0,"color":[255,255,255,255],"alpha":255,"anchorPoint":[0,0],"size":[64,64],"actionTag":1}
	var tree: Dictionary = {"_source_sha256":source_hash,"_decode_blockers":[],"nodeTree":{"classname":"Node","_offset":1,"options":widget,"children":[]},"action":{"speed":1,"timeLines":[]},"animationList":[{"name":"fixture_source_clip","startIndex":0,"endIndex":60}]}
	var manifest: Dictionary = {"schema":"twilight-original-ui-v1","files":{member:{"sha256":source_hash,"bytes":bytes.size()}},"scenes":{member:tree},"atlases":{},"blockers":[]}
	var raw: PackedByteArray = JSON.stringify(manifest).to_utf8_buffer()
	var manifest_hash: String = INSTALL.sha(raw)
	file = FileAccess.open(directory.path_join("original_ui.json"), FileAccess.WRITE)
	file.store_buffer(raw); file.close()
	check(ADAPTER.open_pack(directory,manifest_hash).get("ok",false), "actual v2 source pack opens fixture")
	var prior: RefCounted = ADAPTER.pack
	check(not ADAPTER.open_pack(directory,"0".repeat(64)).get("ok",false), "bad manifest rejected")
	check(ADAPTER.pack == prior, "failed replacement preserves verified pack")
	var identity: Dictionary = {"schema":"patch523-item-icon-identity-v1","source_snapshot":"patch523","item_class_id":900000,"icon_id":900001,"asset_id":900002,"asset_type_id":101,"file_path":literal}
	var spec: Dictionary = {"asset_id":900002,"asset_type_id":101,"file_path":literal,"member":member,"reviewed_current523_manifest_sha256":manifest_hash,"current523_scene_sha256":source_hash,"clip":"fixture_source_clip","repeat":false}
	var document: Dictionary = {"source_icon_index":{"schema":"patch523-item-icon-index-v1","items":{"900000":900001},"icons":{"900001":{"asset_id":900002,"asset_type_id":101,"file_path":literal}}},"source_icon_scenes":{"schema":"patch523-original-ui-icon-scenes-v1","icons":{"900001":spec}}}
	var record: Dictionary = {"source_snapshot":"patch523","source_item_class_id":900000,"source_icon_identity":identity,"name":"CONTRACT FIXTURE NOT ORIGINAL"}
	var before: Dictionary = record.duplicate(true)
	IDENTITY.configure(document)
	var view := TextureRect.new()
	root.add_child(view)
	for usage: String in ["inventory","detail","equipment","quickslot","list","drag"]:
		VISUAL.apply(view,record,record.name,{},usage)
		var host: Node = view.get_node_or_null(ADAPTER.NODE_NAME)
		check(host != null, "common surface mount: " + usage)
		if host != null:
			check(not host.get_child(0).inspection_only, "never inspection mode: " + usage)
		check(view.texture == null and view.material == null, "no substitute PNG/shader: " + usage)
		VISUAL.clear(view)
		check(view.get_node_or_null(ADAPTER.NODE_NAME) == null, "clear detaches immediately: " + usage)
	check(record == before, "physical record preserved")
	for key: String in ["member","reviewed_current523_manifest_sha256","current523_scene_sha256","clip","asset_id"]:
		var bad: Dictionary = document.duplicate(true)
		bad.source_icon_scenes.icons["900001"][key] = -1 if key == "asset_id" else "wrong"
		IDENTITY.configure(bad)
		check(not ADAPTER.attach(view,identity).get("ok",false), "reject mismatched " + key)
		check(view.get_node_or_null(ADAPTER.NODE_NAME) == null, "no partial node after failure")
	IDENTITY.configure(document)
	prior.manifest.scenes[member].nodeTree.options.touchEnabled = true
	var blocked: Dictionary = ADAPTER.attach(view,identity)
	check(not blocked.get("ok",false) and blocked.get("error") == "unsupported_source_scene", "source input rejects normal consumption; no inspection bypass")
	prior.manifest.scenes[member].nodeTree.options.erase("touchEnabled")
	var wrong_item: Dictionary = identity.duplicate(true)
	wrong_item.item_class_id = 900003
	check(not ADAPTER.attach(view,wrong_item).get("ok",false), "wrong ItemClass cannot select a valid scene")
	check(ADAPTER.attach(view,identity).get("ok",false), "mount before slot reuse")
	var old_host: Node = view.get_node_or_null(ADAPTER.NODE_NAME)
	check(ADAPTER.attach(view,identity).get("ok",false), "slot reuse mounts replacement")
	check(old_host.get_parent() == null and old_host.process_mode == Node.PROCESS_MODE_DISABLED, "old scene detached and stopped on slot reuse")
	VISUAL.apply(view,record,record.name,{},"ground")
	check(view.get_node_or_null(ADAPTER.NODE_NAME) == null, "ground does not use inventory scene")
	VISUAL.apply(view,record,record.name)
	var host: Node = view.get_node_or_null(ADAPTER.NODE_NAME)
	var reference: WeakRef = weakref(host)
	view.queue_free()
	await process_frame
	check(reference.get_ref() == null, "view destruction releases player")
	IDENTITY.configure({})
	check(ADAPTER.bindings.is_empty(), "absent catalog clears scene bindings")
	print("SOURCE_ITEM_SCENE_CONTRACT checks=%d failures=%d original_pixels_verified=0 original_scenes_verified=0" % [checks,failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
