extends RefCounted
## Isolated source-map input adapter. This schema NEVER supplies playable fields.
## World and ordinary saves keep their existing layouts until semantic review,
## entry/return validation and a hash-pinned save migration are implemented.
const RECEIPT = "res://data/maps/source_map_review_pack.json"
const LINKAGE_SHA = "33e0b552f1cbd75aef1d299886603107185df1e89cd76432268f94c5bd3b5c77"
const PROTECTED: Array[String] = ["albino_01","albino_02","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05","faith_01","faith_02","faith_03","faith_04"]
const RETIRED: Array[int] = [639,1930,1931,2042,2043,2044]
var root_path: String = ""
var index: Dictionary = {}
var problem: String = ""

static func read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func reject(message: String) -> bool:
	problem = message
	return false

func open_pack(path: String) -> bool:
	index = {}
	problem = ""
	root_path = path.trim_suffix("/")
	var receipt: Dictionary = read_object(RECEIPT)
	if receipt.get("linkage_sha256") != LINKAGE_SHA: return reject("Unknown input contract")
	if not FileAccess.file_exists(root_path+"/index.json"): return reject("Review pack missing")
	if FileAccess.get_sha256(root_path+"/index.json") != receipt.get("index_sha256"): return reject("Review pack index changed")
	var candidate: Dictionary = read_object(root_path+"/index.json")
	if candidate.get("schema") != 1 or candidate.get("kind") != "source-map-review-only" or candidate.get("playable") != false: return reject("Not an isolated review pack")
	if candidate.get("linkage_sha256") != LINKAGE_SHA or not candidate.get("maps") is Dictionary or candidate.maps.size() != 84: return reject("Incomplete map contract")
	if candidate.get("protected_ids") != PROTECTED: return reject("Protected maps changed")
	var safety_entry: Dictionary = candidate.get("safety",{})
	if safety_entry.get("file") != "runtime_safety.json" or FileAccess.get_sha256(root_path+"/runtime_safety.json") != safety_entry.get("sha256"): return reject("Safety manifest changed")
	var safety: Dictionary = read_object(root_path+"/runtime_safety.json")
	if safety.get("runtime_playability_claim_allowed") != false or safety.get("semantic_collision_validation_incomplete") != true: return reject("Unreviewed playability change")
	for mid: String in candidate.maps:
		if mid in PROTECTED or mid in ["albino_03","albino_04","yahee_temple","balrog_temple"]: return reject("Existing map identity is protected")
		var row: Dictionary = candidate.maps[mid]
		if row.get("playable") != false or row.get("file") != "maps/"+mid+".json": return reject("Unsafe map entry")
		if row.get("source_map_id") != null and int(row.source_map_id) in RETIRED: return reject("Retired source map")
	index = candidate
	return true

func load_map(mid: String) -> Dictionary:
	problem = ""
	if not index.get("maps",{}).has(mid): reject("Unknown review map"); return {}
	var entry: Dictionary = index.maps[mid]
	var path: String = root_path+"/"+str(entry.file)
	if FileAccess.get_sha256(path) != entry.sha256: reject("Map manifest changed"); return {}
	var record: Dictionary = read_object(path)
	if record.get("target_map_id") != mid or record.get("playable") != false or record.get("semantic_collision_verified") != false:
		reject("Unsafe map manifest"); return {}
	if not record.get("chunks") is Array or record.chunks.is_empty(): reject("No full resolution artwork"); return {}
	for row: Dictionary in record.chunks:
		var file: String = str(row.get("file",""))
		if not file.begins_with("chunks/") or file.get_file() != file.trim_prefix("chunks/") or not file.ends_with(".webp"):
			reject("Unsafe artwork path"); return {}
		if not FileAccess.file_exists(root_path+"/"+file) or FileAccess.get_sha256(root_path+"/"+file) != row.get("sha256"):
			reject("Full resolution chunk missing or changed: "+file); return {}
	for row: Dictionary in record.get("routes",[])+record.get("doors",[]):
		if row.get("enabled") != false: reject("Unreviewed travel or door enabled"); return {}
	if not record.get("monster_spawns",[]).is_empty(): reject("Spawn import is outside this task"); return {}
	return record

func load_texture(row: Dictionary) -> Texture2D:
	var path: String = root_path+"/"+str(row.file)
	if FileAccess.get_sha256(path) != row.sha256: reject("Chunk changed during review"); return null
	var bitmap := Image.new()
	if bitmap.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: reject("WebP decode failed"); return null
	if bitmap.get_width() != int(row.size[0]) or bitmap.get_height() != int(row.size[1]): reject("WebP dimensions changed"); return null
	return ImageTexture.create_from_image(bitmap)

static func source_to_canvas(record: Dictionary, point: Vector2) -> Vector2:
	var d := point-Vector2(record.origin_source[0],record.origin_source[1])
	# These are source cell centers, not registered player feet.
	return Vector2(24.0*(d.x+d.y)+24.0,12.0*(d.y-d.x)+768.0)

static func canvas_to_source(record: Dictionary, point: Vector2) -> Vector2:
	var a: float = (point.x-24.0)/24.0
	var b: float = (point.y-768.0)/12.0
	return Vector2(record.origin_source[0],record.origin_source[1])+Vector2((a-b)*0.5,(a+b)*0.5)

func gameplay_entries() -> Array:
	# No flag, mutable manifest bit or missing pack may enable these candidates.
	return []

func save_migration_status(mid: String) -> String:
	if mid in PROTECTED: return "unchanged_protected"
	if not index.get("maps",{}).has(mid): return "unchanged_existing"
	if mid == "aden_world" or mid == "domination_summit" or mid.begins_with("oman_"):
		# Future migration must validate old/new map+layout+grid+art hashes,
		# SHA-verify an immutable original backup, stage player/ground-drop/
		# population coordinates together, validate body clearance + reachability,
		# then use the existing atomic save writer. Unknown revisions fail closed.
		# In particular 111 -> 200 is not an identity transform or a scale ratio.
		return "blocked_pending_semantics_and_explicit_coordinate_migration"
	return "new_map_inactive"
