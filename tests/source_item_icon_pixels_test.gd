extends SceneTree
## Consumer plumbing test with an existing authored fixture, NOT original art.
## Fixture bindings never enter the distributed catalog or an active user pack.
const IDENTITY = preload("res://scripts/ui/source_item_icon_identity.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const VISUAL = preload("res://scripts/ui/item_visual.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var preview: Dictionary = INSTALL.preview_selection(OS.get_cmdline_user_args())
	if preview.path != "user://item-pixel-unit-fixture/manifest.json":
		push_error("Requires the isolated fixture preview argument"); quit(2); return
	var directory: String = preview.path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory.path_join("ui/icon/Item"))
	var manifest := FileAccess.open(preview.path, FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema":1,"source_snapshot":"base508","mode":"literal_body_shadow_inspection_only","records":{}}))
	manifest.close()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/ui/potionRed.png")
	var original := Image.new()
	check(original.load_png_from_buffer(bytes) == OK, "existing authored fixture decodes")
	var file_path: String = directory.path_join("ui/icon/Item/unit_fixture.png")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
	var identity: Dictionary = {"schema":"patch523-item-icon-identity-v1","source_snapshot":"patch523","item_class_id":900000,"icon_id":900001,"asset_id":900002,"asset_type_id":1,"file_path":"Item/unit_fixture.png"}
	var spec: Dictionary = identity.duplicate(true)
	spec.merge({"base508_container_sha256":"1".repeat(64),"current523_container_sha256":"1".repeat(64),"sha256":INSTALL.sha(bytes),"bytes":bytes.size(),"width":original.get_width(),"height":original.get_height()})
	var document: Dictionary = {"source_icon_index":{"schema":"patch523-item-icon-index-v1","items":{"900000":900001},"icons":{"900001":{"asset_id":900002,"asset_type_id":1,"file_path":"Item/unit_fixture.png"}}},"source_icon_pixels":{"schema":"patch523-base508-identical-icon-pixels-v1","icons":{"900001":spec}}}
	var record: Dictionary = {"source_snapshot":"patch523","source_item_class_id":900000,"source_icon_identity":identity,"name":"UNIT FIXTURE NOT ORIGINAL","grade":"신화"}
	var before: Dictionary = record.duplicate(true)
	IDENTITY.configure(document)
	var texture: Texture2D = RESOLVER.texture(record)
	check(texture != null, "active source API reaches exact fixture bytes")
	if texture != null:
		check(texture.get_image().get_data() == original.get_data(), "decoded pixels and alpha preserved")
		check(Vector2i(texture.get_size()) == original.get_size(), "dimensions preserved")
	check(RESOLVER.texture(record,"",{},true) == null, "inventory pixels never substitute ground assets")
	for usage: String in ["inventory","detail","equipment","quickslot","list","drag"]:
		var view := TextureRect.new()
		root.add_child(view)
		VISUAL.apply(view,record,record.name,{},usage)
		check(view.texture != null and view.material == null, "shared consumer without authored shader: " + usage)
		check(not view.get_node("SubstituteIconMark").visible, "no missing marker on decoded fixture: " + usage)
		view.queue_free()
	check(record == before, "physical record untouched")
	for field: String in ["current523_container_sha256","sha256","bytes","width","asset_id"]:
		var invalid: Dictionary = document.duplicate(true)
		invalid.source_icon_pixels.icons["900001"][field] = "2".repeat(64) if field.ends_with("sha256") else -1
		IDENTITY.configure(invalid)
		check(RESOLVER.texture(record) == null, "reject changed " + field)
	IDENTITY.configure(document)
	var wrong: Dictionary = record.duplicate(true)
	wrong.source_item_class_id = 900003
	wrong.source_icon_identity.item_class_id = 900003
	check(RESOLVER.texture(wrong) == null, "reject wrong ItemClass even with valid icon metadata")
	check(RESOLVER.texture(record) != null, "populate valid texture cache before file mutation")
	file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0,8)); file.close()
	check(RESOLVER.texture(record) == null, "changed file rejected even after texture cache population")
	IDENTITY.configure({})
	check(IDENTITY.PIXELS.bindings.is_empty() and IDENTITY.PIXELS.textures.is_empty(), "old/absent catalog resets bindings and cache")
	await process_frame
	print("SOURCE_ITEM_PIXEL_CONSUMER_TEST checks=%d failures=%d original_pixels_verified=0 fixture_only=true" % [checks, failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
