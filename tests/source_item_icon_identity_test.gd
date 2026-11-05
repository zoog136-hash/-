extends SceneTree
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const VISUAL = preload("res://scripts/ui/item_visual.gd")
var failures: Array[String] = []
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# Literal original table joins; no synthetic texture is an original input.
	var record: Dictionary = {"source_snapshot":"patch523", "source_item_class_id":26,
		"sourceId":"m523:item:26", "name":"아데나 · 원본#26", "grade":"신화",
		"image_path":"res://assets/ui/potionRed.png", "source_icon_identity":{
		"schema":"patch523-item-icon-identity-v1", "source_snapshot":"patch523",
		"item_class_id":26, "icon_id":2932, "asset_id":30962,
		"asset_type_id":1, "file_path":"Item/adena_3.png"}}
	var before: Dictionary = record.duplicate(true)
	for identity: String in ["m523:item:26", "m523:item:26:bless:2", "26"]:
		record.sourceId = identity
		for ground: bool in [false,true]:
			var info: Dictionary = RESOLVER.describe(record,"",{},ground)
			check(info.route == "source_original_unavailable", "no namespace fallback: "+identity)
			check(info.reason == "source_pixels_not_installed", "explicit missing pixels")
			check(info.source_icon_identity.icon_id == 2932, "literal IconID")
			check(RESOLVER.texture(record,"",{},ground) == null, "no guessed pixels")
	record.sourceId = before.sourceId
	for usage: String in ["inventory", "detail", "equipment", "quickslot", "list", "drag"]:
		var view := TextureRect.new()
		root.add_child(view)
		VISUAL.apply(view,record,record.name,{},usage)
		check(view.texture == null and view.material == null, "unaltered source surface: "+usage)
		check(view.get_meta("item_visual").source_icon_identity.asset_id == 30962, "shared identity: "+usage)
		check(view.get_node("SubstituteIconMark").text == "원본 미설치", "missing input label: "+usage)
		VISUAL.clear(view)
		view.queue_free()
	check(record == before, "visuals preserve save/option record")
	record.source_icon_identity.asset_type_id = 101
	record.source_icon_identity.file_path = "icon/Fx_Item_test.csb"
	check(RESOLVER.describe(record).reason == "source_scene_player_required", "CSB never a PNG substitute")
	record.source_icon_identity.file_path = ""
	check(RESOLVER.describe(record).reason == "source_empty_path", "empty path is not missing pixel")
	record.source_icon_identity.item_class_id = 27
	check(RESOLVER.describe(record).reason == "source_icon_identity_mismatch", "reject wrong ItemClass")
	record.erase("source_icon_identity")
	check(RESOLVER.describe(record).reason == "source_icon_identity_not_installed", "old pack stays explicit")
	check(not RESOLVER.SOURCE_IDENTITY.recognized({"sourceId":"26", "name":"아데나"}), "legacy web namespace not guessed")

	var pack_path: String = OS.get_environment("TWILIGHT_ICON_TEST_PACK")
	if not pack_path.is_empty():
		var packed: PackedByteArray = FileAccess.get_file_as_bytes(pack_path)
		var document: Dictionary = JSON.parse_string(packed.decompress_dynamic(64*1024*1024,FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
		var result: Dictionary = preload("res://scripts/loot/patch523_item_catalog.gd").register(document,catalog)
		check(result.native_definition_count == 30398, "all normal ItemClass records registered")
		var native_ids: Dictionary = {}
		var icon_ids: Dictionary = {}
		for current: Dictionary in catalog["아이템"]:
			if not RESOLVER.SOURCE_IDENTITY.recognized(current): continue
			var info: Dictionary = RESOLVER.describe(current)
			check(info.has("source_icon_identity"), "registered icon identity "+str(current.sourceId))
			if not info.has("source_icon_identity"): continue
			var link: Dictionary = info.source_icon_identity
			check(link.item_class_id == int(current.source_item_class_id), "same options/icon ItemClass")
			check(int(link.icon_id) == int(document.source_icon_index.items[str(link.item_class_id)]), "same original IconID")
			native_ids[str(link.item_class_id)] = true
			icon_ids[str(link.icon_id)] = true
		check(native_ids.size() == 30398, "normal ItemClass denominator")
		check(icon_ids.size() == 4144, "unique IconID denominator")
		var saved_before: Dictionary = record.duplicate(true)
		check(RESOLVER.describe(record).reason == "source_pixels_not_installed", "old physical record resolves exact registered ItemClass")
		check(record == saved_before, "resolving old physical icon leaves save bytes/fields untouched")
		RESOLVER.SOURCE_IDENTITY.configure({})
		check(RESOLVER.describe(record).reason == "source_icon_identity_not_installed", "older pack cannot reuse stale icon index")
	await process_frame
	print("SOURCE_ITEM_ICON_IDENTITY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"original_pixels_verified":0}))
	quit(0 if failures.is_empty() else 1)
