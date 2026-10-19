extends RefCounted
## New independent temples can be entered in the ordinary game with a verified
## private pack. Replacing existing Albino/Escaros geometry remains explicit
## until their legacy gameplay coordinates have a supported correspondence.
const PLAN_PATH := "res://data/maps/native_png_plan.json"
const FIELD = preload("res://scripts/maps/native_png_field.gd")

static func enabled() -> bool:
	return "--native-png-maps" in OS.get_cmdline_user_args() and not "--legacy-map-layouts" in OS.get_cmdline_user_args()

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func plan() -> Dictionary:
	return read_json(PLAN_PATH)

static func root_path() -> String:
	var configured := OS.get_environment("TWILIGHT_NATIVE_PNG_PACK")
	return configured.trim_suffix("/") if not configured.is_empty() else "user://native_png_maps"

static func installed() -> bool:
	var receipt: Dictionary=read_json("res://data/maps/native_png_pack.json")
	var path: String=root_path()+"/index.json"
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path)==receipt.get("index_sha256","")

static func canonical(mid: String) -> String:
	if not enabled(): return mid
	if mid in ["escaros_01","escaros_02","escaros_03","escaros_04","escaros_05"]: return "escaros_world"
	if mid == "albino_04": return "albino_03"
	return mid

static func supports(mid: String) -> bool:
	return plan().get("maps",{}).has(canonical(mid)) and (enabled() or (mid in ["yahee_temple","balrog_temple"] and installed()))

static func catalog_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not enabled() and not installed(): return entries
	var specs: Dictionary = plan().get("maps",{})
	for mid: String in ["escaros_world","yahee_temple","balrog_temple"]:
		if mid=="escaros_world" and not enabled(): continue
		entries.append({"id":mid,"name":specs[mid].name,"width":1,"height":1,"tile_size_world":32,"native_png":true})
	return entries

static func menu_entries(records: Array) -> Array:
	if not enabled(): return records
	var visible: Array=records.filter(func(record: Dictionary) -> bool:
		return str(record.id) not in ["albino_04","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05"])
	var specs: Dictionary=plan().maps
	var menu: Array=[]
	for record: Dictionary in visible:
		var row: Dictionary=record.duplicate()
		if specs.has(str(row.id)): row.name=specs[str(row.id)].name
		menu.append(row)
	return menu

static func load_field(mid: String) -> PlayableField:
	var spec_plan: Dictionary = plan()
	var specs: Dictionary = spec_plan.get("maps",{})
	if not specs.has(mid): return null
	var local_root: String = root_path()
	var receipt: Dictionary = read_json("res://data/maps/native_png_pack.json")
	if FileAccess.get_sha256(local_root+"/index.json") != receipt.get("index_sha256",""): return null
	var index: Dictionary = read_json(local_root+"/index.json")
	if index.get("schema") != 1 or index.get("plan_sha256") != FileAccess.get_sha256(PLAN_PATH): return null
	var entry: Dictionary = index.get("maps",{}).get(mid,{})
	if entry.get("manifest","") != mid+"/manifest.json": return null
	var manifest_path: String = local_root+"/"+mid+"/manifest.json"
	if FileAccess.get_sha256(manifest_path) != entry.get("sha256",""): return null
	var manifest: Dictionary = read_json(manifest_path)
	var source: Dictionary = spec_plan.sources.get(specs[mid].file,{})
	if manifest.get("source_sha256") != source.get("sha256") or manifest.get("map_id") != mid: return null
	if manifest.get("plan_sha256") != index.get("plan_sha256") or manifest.get("native_pixel_scale") != 1: return null
	# Validate real byte hashes and bounded PNG headers BEFORE replacing the map.
	# This uses no ImageTexture and never uploads the full source to the GPU.
	var rows: Variant = manifest.get("chunks")
	if not rows is Array or rows.is_empty(): return null
	var positions: Dictionary = {}
	for chunk: Dictionary in rows+manifest.get("foreground",[]):
		var filename: String = str(chunk.get("file",""))
		if filename.get_file() != filename or not filename.ends_with(".png"): return null
		if not chunk.get("size") is Array or chunk["size"].size()!=2: return null
		var dimensions: Array = chunk["size"]
		if dimensions[0] < 1 or dimensions[1] < 1 or dimensions[0]>1024 or dimensions[1]>1024: return null
		if not chunk.get("position") is Array or chunk.position.size()!=2: return null
		var key: String = filename
		if positions.has(key): return null
		positions[key] = true
		var path: String = local_root+"/"+mid+"/"+filename
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != chunk.get("sha256",""): return null
		var handle := FileAccess.open(path,FileAccess.READ)
		if handle == null: return null
		handle.big_endian = true
		if handle.get_buffer(8) != PackedByteArray([137,80,78,71,13,10,26,10]): return null
		handle.seek(16)
		if handle.get_32() != int(dimensions[0]) or handle.get_32() != int(dimensions[1]): return null
	var field: NativePngField = FIELD.new()
	field.configure_png(mid,spec_plan,manifest,local_root+"/"+mid)
	if not field.walkable(Vector2(specs[mid].spawn[0],specs[mid].spawn[1])): return null
	return field
