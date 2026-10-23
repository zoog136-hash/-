extends RefCounted
## New independent temples can be entered in the ordinary game with a verified
## private pack. Replacing existing Albino/Escaros geometry remains explicit
## until their legacy gameplay coordinates have a supported correspondence.
const PLAN_PATH := "res://data/maps/native_png_plan.json"
const EXTRA_PLAN_PATH := "res://data/maps/aden_faith_png_plan.json"
const BUNDLED_EXTRA_ROOT := "res://external_map_packs/aden_faith_png_v1"
const EXTRA_RECEIPT_PATH := "res://data/maps/aden_faith_png_pack.json"
const REVIEW_PATH := "res://data/maps/native_png_review.json"
const FIELD = preload("res://scripts/maps/native_png_field.gd")
const BUNDLED_ROOT := "res://external_map_packs/native_png_v5"
const LEGACY_ROOT := "user://native_png_maps"
# Accepted default packs keep their identity after on-disk removal.
static var extra_pack_seen: bool=false

static func enabled() -> bool:
	return "--native-png-maps" in OS.get_cmdline_user_args() and not "--legacy-map-layouts" in OS.get_cmdline_user_args()

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func base_plan() -> Dictionary:
	return read_json(PLAN_PATH)

static func plan() -> Dictionary:
	# Geometry review belongs to code; the already delivered, hash-pinned art
	# archive stays immutable. Reject mismatched reviews before changing a field.
	var value: Dictionary=base_plan()
	var review: Dictionary=read_json(REVIEW_PATH)
	value=merge_review(value,review,FileAccess.get_sha256(PLAN_PATH))
	if value.is_empty(): return {}
	var extra: Dictionary=read_json(EXTRA_PLAN_PATH)
	value.sources.merge(extra.get("sources",{}))
	value.maps.merge(extra.get("maps",{}))
	return value

static func valid_point(value: Variant, size: Array) -> bool:
	return value is Array and value.size()==2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int) and is_finite(float(value[0])) and is_finite(float(value[1])) and value[0]>=0 and value[1]>=0 and value[0]<size[0] and value[1]<size[1]

static func valid_polygon(points: Variant, size: Array) -> bool:
	if not points is Array or points.size()<3: return false
	var vertices:=PackedVector2Array()
	for point: Variant in points:
		if not valid_point(point,size): return false
		vertices.append(Vector2(point[0],point[1]))
	return not Geometry2D.triangulate_polygon(vertices).is_empty()

static func merge_review(base: Dictionary, review: Dictionary, base_hash: String) -> Dictionary:
	if review.get("schema")!=1 or review.get("base_plan_sha256","")!=base_hash or int(review.get("revision",0))<=int(base.get("revision",0)): return {}
	var value: Dictionary=base.duplicate(true)
	if not review.get("maps") is Dictionary: return {}
	for mid: String in review.get("maps",{}):
		if not value.get("maps",{}).has(mid): return {}
		var spec: Dictionary=value.maps[mid]
		var patch: Dictionary=review.maps[mid]
		if patch.get("source_sha256","")!=value.sources[spec.file].sha256: return {}
		var size: Array=value.sources[spec.file].size
		for key: String in ["route_checks","blocked_probes"]:
			for point: Variant in patch.get(key+"_add",[]):
				if not valid_point(point,size): return {}
		for points: Variant in patch.get("walk_polygons_add",[]):
			if not valid_polygon(points,size): return {}
		for shape: Dictionary in patch.get("collision_add",[])+patch.get("collision_replace",[]):
			if shape.get("shape")=="circle":
				if not valid_point(shape.get("center"),size) or float(shape.get("radius",0))<=0: return {}
			elif shape.get("shape")=="polygon":
				if not valid_polygon(shape.get("points"),size): return {}
			else: return {}
		var ids: Dictionary={}
		for cut: Dictionary in patch.get("foreground",[]):
			if not valid_polygon(cut.get("polygon_image"),size) or not valid_point(cut.get("foot_image"),size): return {}
			var polygon: Array=cut.polygon_image
			var box:=Rect2(Vector2(polygon[0][0],polygon[0][1]),Vector2.ZERO)
			for point: Array in polygon: box=box.expand(Vector2(point[0],point[1]))
			if box.size.x>1024 or box.size.y>1024 or str(cut.get("id","")).is_empty() or ids.has(str(cut.id)): return {}
			ids[str(cut.id)]=true
		for key: String in ["collision","walk_polygons","route_checks","blocked_probes"]:
			if patch.has(key+"_add"): spec[key]=spec.get(key,[])+patch[key+"_add"]
		for replacement: Dictionary in patch.get("collision_replace",[]):
			var found: bool=false
			for i: int in range(spec.collision.size()):
				if spec.collision[i].get("id")==replacement.get("id"):
					spec.collision[i]=replacement;found=true;break
			if not found: return {}
		spec["runtime_foreground"]=patch.get("foreground",[])
	value.revision=int(review.revision)
	return value

static func extra_map(mid: String) -> bool:
	return read_json(EXTRA_PLAN_PATH).get("maps",{}).has(mid)

static func plan_hash(mid: String) -> String:
	return FileAccess.get_sha256(EXTRA_PLAN_PATH if extra_map(mid) else PLAN_PATH)

static func review_hash(mid: String="") -> String:
	return plan_hash(mid) if extra_map(mid) else FileAccess.get_sha256(REVIEW_PATH)

static func extra_root() -> String:
	var configured: String=OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	if not configured.is_empty(): return configured.trim_suffix("/")
	return BUNDLED_EXTRA_ROOT if FileAccess.file_exists(BUNDLED_EXTRA_ROOT+"/index.json") else "user://aden_faith_png_maps"

static func extra_installed() -> bool:
	var receipt: Dictionary=read_json(EXTRA_RECEIPT_PATH)
	var path: String=extra_root()+"/index.json"
	var verified: bool=FileAccess.file_exists(path) and FileAccess.get_sha256(path)==receipt.get("index_sha256","")
	if verified: extra_pack_seen=true
	return verified


static func root_path() -> String:
	# Explicit test/user pack always wins, including intentionally missing paths.
	var configured: String = OS.get_environment("TWILIGHT_NATIVE_PNG_PACK")
	if not configured.is_empty(): return configured.trim_suffix("/")
	# Repo ZIP + Termux updater both contain this versioned runtime map pack.
	# Fail closed on corrupted index; never silently substitute guessed art.
	if FileAccess.file_exists(BUNDLED_ROOT+"/index.json"): return BUNDLED_ROOT
	return LEGACY_ROOT

static func bundled_enabled() -> bool:
	# In the ordinary game show verified repo PNGs automatically, keeping the
	# ordinary save namespace and 25 historical map IDs. Explicit diagnostics
	# and legacy switches continue to opt out of runtime map replacement.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return installed() and not "--legacy-map-layouts" in args and not "--png-review" in args and not "--no-native-png-auto" in args

static func map_for_art(mid: String) -> String:
	if mid in ["escaros_01","escaros_02","escaros_03","escaros_04","escaros_05"]: return "escaros_world"
	# Deprecated Albino 3/4 are never constructed, even via direct API callers.
	if mid in ["albino_03","albino_04"]: return "albino_02"
	return mid

static func installed() -> bool:
	var receipt: Dictionary=read_json("res://data/maps/native_png_pack.json")
	var path: String=root_path()+"/index.json"
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path)==receipt.get("index_sha256","")

static func canonical(mid: String) -> String:
	# Redirect old save IDs in both normal and explicit PNG modes; no stale field.
	if mid in ["albino_03","albino_04"]: return "albino_02"
	if not enabled(): return mid
	if mid in ["escaros_01","escaros_02","escaros_03","escaros_04","escaros_05"]: return "escaros_world"
	return mid

static func supports(mid: String) -> bool:
	if mid in ["albino_03","albino_04"]: return false
	# Keep old map IDs in ordinary saves; Escaros 01–05 share source artwork
	# but not the saved alias. Review mode keeps its original canonical names.
	var art_id: String = map_for_art(canonical(mid))
	if extra_map(art_id):
		var configured: bool=not OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK").is_empty()
		var args: PackedStringArray=OS.get_cmdline_user_args()
		var ordinary: bool=not "--legacy-map-layouts" in args and not "--legacy-aden-faith-layouts" in args and not "--png-review" in args and not "--no-native-png-auto" in args
		# Explicit missing/corrupt paths must fail before releasing live gameplay.
		var verified: bool=extra_installed()
		var present: bool=FileAccess.file_exists(extra_root()+"/index.json")
		return (verified or present or extra_pack_seen or configured) and (enabled() or ordinary) and not "--legacy-aden-faith-layouts" in args
	return base_plan().get("maps",{}).has(art_id) and (enabled() or bundled_enabled() or mid in ["yahee_temple","balrog_temple"])

static func catalog_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not enabled() and not installed(): return entries
	var specs: Dictionary = base_plan().get("maps",{})
	for mid: String in ["escaros_world","yahee_temple","balrog_temple"]:
		if mid=="escaros_world" and not enabled(): continue
		entries.append({"id":mid,"name":specs[mid].name,"width":1,"height":1,"tile_size_world":32,"native_png":true})
	return entries

static func menu_entries(records: Array) -> Array:
	# Always remove Albino 3/4 from the visible catalog; do not depend on CLI mode.
	var visible: Array=records.filter(func(record: Dictionary) -> bool:
		return str(record.id) not in ["albino_03","albino_04"])
	if not enabled(): return visible
	visible=visible.filter(func(record: Dictionary) -> bool:
		return str(record.id) not in ["escaros_01","escaros_02","escaros_03","escaros_04","escaros_05"])
	var specs: Dictionary=plan().maps
	var menu: Array=[]
	for record: Dictionary in visible:
		var row: Dictionary=record.duplicate()
		if specs.has(str(row.id)): row.name=specs[str(row.id)].name
		menu.append(row)
	return menu

static func load_field(mid: String) -> PlayableField:
	mid = map_for_art(mid)
	var spec_plan: Dictionary = plan()
	var specs: Dictionary = spec_plan.get("maps",{})
	if not specs.has(mid): return null
	var local_root: String = extra_root() if extra_map(mid) else root_path()
	var receipt: Dictionary = read_json(EXTRA_RECEIPT_PATH if extra_map(mid) else "res://data/maps/native_png_pack.json")
	if FileAccess.get_sha256(local_root+"/index.json") != receipt.get("index_sha256",""): return null
	var index: Dictionary = read_json(local_root+"/index.json")
	if index.get("schema") != 1 or index.get("plan_sha256") != plan_hash(mid): return null
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
	# The native PNG map can have a runtime artwork-to-world scale distinct
	# from source pixels; validate the *world* spawn after conversion.
	if not field.walkable(Vector2(field.data.spawn_position[0],field.data.spawn_position[1])): return null
	return field
