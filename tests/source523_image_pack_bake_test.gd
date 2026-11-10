extends SceneTree
## The image pack's device record bake answers exactly like the in-memory
## metadata it replaces (about 800 MB less memory with the real pack).
## Real input: -- --images=<pack images folder> --images-sha256=<manifest pin>.
## Without it: a failed open bakes nothing.
const PACK = preload("res://scripts/resources/source523_image_pack.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _plain(value: Variant) -> Variant:
	# Textures are separate objects per reader; compare their pixels' size.
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _plain(value[key])
		return result
	if value is Array:
		var items: Array = []
		for item: Variant in value: items.append(_plain(item))
		return items
	if value is Texture2D: return "texture:%dx%d" % [value.get_width(), value.get_height()]
	return value

func _answers(reader: RefCounted, ids: Dictionary) -> Dictionary:
	var result: Dictionary = {"metadata":reader.metadata()}
	for table: String in PACK.CONSUMER_FIELDS:
		for id: int in ids[table]:
			for field: String in PACK.CONSUMER_FIELDS[table]:
				result["%s:%d:%s" % [table, id, field]] = _plain(reader.resolve_consumer(table, id, field))
			result["row:%s:%d" % [table, id]] = reader.source_consumer_row(table, id)
	for id: int in ids.assets: result["asset:%d" % id] = _plain(reader.resolve_asset(id))
	for path: String in ids.paths: result["path:" + path] = _plain(reader.resolve_path(path))
	return result

func _initialize() -> void:
	var root: String = arg("--images=")
	var pin: String = arg("--images-sha256=")
	BAKE.clear(PACK.BAKE_NAME)
	if root.is_empty():
		check(not PACK.open("user://absent_image_pack", "0".repeat(64)).get("ok", true), "an absent pack does not open")
		check(not FileAccess.file_exists(BAKE.data_path(PACK.BAKE_NAME)), "a failed open bakes nothing")
		_finish({"real_input_checked":false})
		return
	PACK.bake_enabled = false
	var plain: Dictionary = PACK.open(root, pin)
	check(plain.get("ok", false) and plain.pack._records == null, "in-memory open")
	if not plain.get("ok", false): _finish({}); return
	var ids: Dictionary = {"assets":[0, 999999999],"paths":["no/such/path.png"]}
	for table: String in PACK.CONSUMER_FIELDS:
		var keys: Array = plain.pack._consumers[table].keys()
		ids[table] = [0, 999999999]
		for index: int in range(0, keys.size(), maxi(1, keys.size() / 150)): ids[table].append(keys[index])
	var asset_keys: Array = plain.pack._assets.keys()
	for index: int in range(0, asset_keys.size(), maxi(1, asset_keys.size() / 200)):
		ids.assets.append(asset_keys[index])
		if index % 7 == 0 and not str(plain.pack._assets[asset_keys[index]].path).is_empty(): ids.paths.append(str(plain.pack._assets[asset_keys[index]].path))
	var expected: Dictionary = _answers(plain.pack, ids)
	var plain_metrics: Dictionary = plain.metrics
	plain = {}
	PACK.bake_enabled = true
	var first: Dictionary = PACK.open(root, pin)
	check(first.get("ok", false) and first.pack._records != null and first.pack._assets.is_empty() and first.pack._source_tables.is_empty(), "the first open bakes and drops the in-memory metadata")
	check(first.get("metrics") == plain_metrics, "same metrics")
	var baked: Dictionary = PACK.open(root, pin)
	check(baked.get("ok", false) and baked.pack._records != null and baked.pack._manifest.get("members") == null, "the next open reads the bake")
	for reader: RefCounted in [first.pack, baked.pack]:
		var answers: Dictionary = _answers(reader, ids)
		check(answers.size() == expected.size(), "same answer count")
		for key: String in expected: check(answers.get(key) == expected[key], "same answer: " + key)
	var textures: int = 0
	for key: String in expected:
		if expected[key] is Dictionary and str(expected[key].get("texture", "")).begins_with("texture:"): textures += 1
	check(textures > 20, "real images were compared: %d" % textures)
	check(not PACK.open(root, "0".repeat(64)).get("ok", true), "another pin is refused even with a bake present")
	_finish({"real_input_checked":true,"answers":expected.size(),"textures":textures})

func _finish(extra: Dictionary) -> void:
	var result: Dictionary = {"checks":checks,"failures":failures}
	result.merge(extra)
	print("SOURCE523_IMAGE_PACK_BAKE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
