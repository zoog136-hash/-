extends SceneTree
## Metadata rejection and optional real private-pack presentation checks.
## No image fixtures, grants, inventory writes or save operations.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const VISUAL = preload("res://scripts/ui/item_visual.gd")
var checks: int = 0
var failures: Array[String] = []
var real_pack_checked: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("SOURCE523_ITEM_IMAGES_FAIL: " + message)

func record_for(id: int) -> Dictionary:
	return {"source_snapshot":"patch523","source_m_native_item":true,
		"source_item_class_id":id,"sourceId":"presentation-probe","name":"presentation probe",
		"grade":"신화","instanceId":"preserved-physical-probe"}

func _run() -> void:
	var request: Dictionary = IMAGES.selection(OS.get_cmdline_user_args(),OS.get_environment("TWILIGHT_SOURCE523_IMAGES"),OS.get_environment("TWILIGHT_SOURCE523_IMAGES_SHA256"))
	IMAGES.clear_selection()
	var record: Dictionary = record_for(1)
	check(IMAGES.recognized_item(record),"exact native marker and integral class ID recognized")
	for mutation: Dictionary in [{"source_snapshot":"base508"},{"source_snapshot":"current523"},
		{"source_m_native_item":false},{"source_m_native_item":1},{"source_item_class_id":true},
		{"source_item_class_id":1.5},{"source_item_class_id":"1"},{"source_item_class_id":0}]:
		check(not IMAGES.recognized_item(record.merged(mutation,true)),"non-native or inexact identity rejected")
	check(not IMAGES.recognized_item({"sourceId":"1","name":"presentation probe"}),"bare ID and name are not native identity")
	check(IMAGES.recognized_item(record.merged({"source_item_class_id":1.0},true)),"JSON integral float retains exact class identity")
	check(not IMAGES.selection(PackedStringArray()).selected,"unselected by default")
	check(IMAGES.selection(PackedStringArray(["--source523-images=/explicit"])).has("error"),"partial CLI pair rejected")
	check(IMAGES.selection(PackedStringArray(["--source523-images=/explicit"]),"/environment","pin").has("error"),"CLI and environment halves never mix")
	check(IMAGES.selection(PackedStringArray(["--source523-images=/one","--source523-images=/two"])).has("error"),"conflicting CLI selection rejected")
	check(IMAGES.selection(PackedStringArray(),"/environment","pin").selected,"explicit environment pair detected")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var legacy: Dictionary = catalog["아이템"][0].duplicate(true)
	record.merge({"sourceId":legacy.sourceId,"name":legacy.name,"image_path":legacy.image_path},true)
	var original_record: String = JSON.stringify(record)
	var legacy_info: Dictionary = RESOLVER.describe(legacy,str(legacy.name))
	var ground_info: Dictionary = RESOLVER.describe(record,str(record.name),{},true)
	check(not IMAGES.handles_item(record),"unselected native record preserves existing route")
	var missing: Dictionary = IMAGES.configure("user://missing-source523-image-pack","0".repeat(64))
	check(not missing.ok and IMAGES.selected() and IMAGES.active() == null,"selected invalid pack remains explicit missing")
	check(RESOLVER.texture(record,str(record.name)) == null,"selected native icon never borrows legacy pixels")
	check(RESOLVER.describe(record,str(record.name)).route == "source523_images","native alias is resolved before legacy canonicalization")
	check(RESOLVER.describe(legacy,str(legacy.name)) == legacy_info,"non-native route preserved while image pack selected")
	check(RESOLVER.describe(record,str(record.name),{},true) == ground_info,"floor route does not borrow inventory IconID")
	var view := TextureRect.new()
	view.size = Vector2(64,64)
	root.add_child(view)
	VISUAL.apply(view,record,str(record.name))
	check(view.texture == null and view.material == null,"missing original has no placeholder or rarity shader")
	check(view.get_meta("source523_image",{}).get("reason","") != "","missing source status is attached to the view")
	check(not view.get_meta("item_visual",{}).has("foreground_removed_pixels"),"native presentation never enters cutout preparation")
	check(not view.get_node("ItemVisual").refresh_visibility(),"native presentation does not schedule authored motion")
	check(JSON.stringify(record) == original_record,"source identity and physical record remain unchanged")
	if bool(request.get("selected",false)) and not request.has("error"):
		await _real_pack(view,request)
	else:
		check(not request.has("error"),"real-pack test selection is a complete explicit pair")
	IMAGES.clear_selection()
	VISUAL.apply(view,legacy,str(legacy.name),{},"list")
	check(not view.has_meta("source523_image") and not view.has_meta("source523_image_provenance"),"reused legacy view clears source evidence")
	check(not view.get_node("ItemVisual").source_presentation,"reused legacy view restores prior presentation policy")
	view.queue_free()
	await process_frame
	await process_frame
	print("SOURCE523_ITEM_IMAGES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"real_pack_checked":real_pack_checked,"display":DisplayServer.get_name(),
		"actual_game_use_observed":false,"images_generated":false}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(view: TextureRect, request: Dictionary) -> void:
	var opened: Dictionary = IMAGES.configure(str(request.root),str(request.sha256))
	check(bool(opened.get("ok",false)),"real explicitly pinned pack opens")
	if not bool(opened.get("ok",false)): return
	real_pack_checked = true
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(request.root).path_join("manifest.json")))
	var icons: Dictionary = {}
	var assets: Dictionary = {}
	for icon: Dictionary in manifest.icons: icons[int(icon.id)] = icon
	for asset: Dictionary in manifest.assets: assets[int(asset.asset_id)] = asset
	# Source TestItem rows are excluded by the resolver (checked below); probe a non-test row.
	var test_items: Dictionary = {}
	var source_items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(request.root).path_join(str(manifest.source_tables.ItemClass.path))))
	for row: Dictionary in source_items.get("rows",[]):
		if row.get("TestItem",false) == true: test_items[int(row.ID)] = true
	var native_id: int = 0
	var csb_id: int = 0
	for consumer: Dictionary in manifest.consumers.ItemClass:
		if test_items.has(int(consumer.id)): continue
		var icon: Dictionary = icons.get(int(consumer.roles.IconID),{})
		var asset: Dictionary = assets.get(int(icon.get("asset_id",0)),{})
		if int(consumer.id) > 0 and asset.get("status","") == "verified_original" and native_id == 0: native_id = int(consumer.id)
		if int(consumer.id) > 0 and asset.get("status","") == "unsupported_csb" and csb_id == 0: csb_id = int(consumer.id)
		if native_id > 0 and csb_id > 0: break
	check(native_id > 0,"real pack contains an exact static item-icon consumer")
	if native_id == 0: return
	var record: Dictionary = record_for(native_id)
	var saved: String = JSON.stringify(record)
	var result: Dictionary = RESOLVER.describe(record,str(record.name))
	check(result.status == "original_linked" and result.texture is Texture2D,"exact source icon resolves to verified original texture")
	if not result.texture is Texture2D: return
	var member: Dictionary = result.provenance.member
	var source: Image = Image.load_from_file(str(request.root).path_join(str(member.file)))
	var actual: Image = result.texture.get_image()
	check(source != null and actual.get_size() == source.get_size() and actual.get_data() == source.get_data(),"texture pixels equal directly loaded original bytes including alpha")
	VISUAL.apply(view,record,str(record.name))
	check(view.texture == result.texture and view.material == null,"native myth icon bypasses material and foreground replacement")
	check(view.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"native aspect ratio preserved")
	check(view.get_meta("source523_image_provenance",{}).get("member",{}).get("sha256","") == member.sha256,"decoder original-file identity is exposed on presentation node")
	check(view.get_meta("source523_image",{}).get("actual_game_consumption_observed",true) == false,"load/presentation does not increment actual-use evidence")
	check(JSON.stringify(record) == saved,"real image resolution leaves physical record unchanged")
	var failed: Dictionary = IMAGES.configure("user://missing-source523-image-pack","0".repeat(64))
	check(not failed.ok and failed.previous_pack_preserved and IMAGES.active() != null,"failed pack replacement preserves prior verified reader")
	if csb_id > 0:
		var unsupported: Dictionary = RESOLVER.describe(record_for(csb_id),"presentation probe")
		check(unsupported.reason == "unsupported_csb" and unsupported.texture == null,"source CSB remains explicit UI-owner work without substitute")
	var excluded: Dictionary = RESOLVER.describe(record.merged({"source_test_item":true},true),"presentation probe")
	check(excluded.reason == "source_test_item_excluded" and excluded.texture == null,"source test flag does not activate new image consumption")
	await process_frame
