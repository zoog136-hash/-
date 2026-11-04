extends RefCounted
## Literal patch523 settings stay outside Git. Loading never changes preferences.
const HASHES: Dictionary = {
	"OptimizedTerritoryView.json":"6faeba60ccac99d111f196cbff6afa38358d4a3db7108b6899dfc2696e106f97",
	"ClientOptimizeTerritoryConditionType.json":"3022f3d5f19dbf280aac360b88b7decac78e728ea1f4dc04d5cf510ae07bfba1",
	"EffectSpriteSimplify.json":"a5d81dc541e08e4b5c0739b0f4fcebae38d900469561071276db496370b644ab",
	"UIFlashEffectHideList.json":"af7460c9cd4de6d3e894c1fd6c7ca280acbdb1268020d39c489344abeb5cb099"
}
var directory: String = ""
var territories: Array[Dictionary] = []
var by_id: Dictionary = {}
var by_land: Dictionary = {}
var conditions: Dictionary = {}
var simplify: Dictionary = {}
var flash_paths: Array[Dictionary] = []

func load_directory(path: String) -> Dictionary:
	var staged: Dictionary = {}
	for name: String in HASHES:
		var full: String = path.path_join(name)
		var file := FileAccess.open(full,FileAccess.READ)
		if file == null or file.get_length() > 256*1024:
			return {"ok":false,"error":"원본 설정 파일이 없거나 크기가 다릅니다: " + name}
		file.close()
		if FileAccess.get_sha256(full) != HASHES[name]:
			return {"ok":false,"error":"523 원본 설정 해시가 다릅니다: " + name}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full).trim_prefix("\ufeff"))
		if not parsed is Dictionary or not parsed.get("rows") is Array:
			return {"ok":false,"error":"원본 설정 형식이 다릅니다: " + name}
		staged[name] = parsed.rows
	return _install_tables(staged,path)

func load_zip(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()!=25031173:
		return {"ok":false,"error":"검증된523 원본 자료 ZIP이 아닙니다."}
	file.close()
	if FileAccess.get_sha256(path)!="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832":
		return {"ok":false,"error":"523 원본 ZIP 해시가 다릅니다."}
	var zip := ZIPReader.new()
	if zip.open(path)!=OK: return {"ok":false,"error":"원본 ZIP을 열 수 없습니다."}
	var staged: Dictionary = {}
	for name: String in HASHES:
		var bytes: PackedByteArray = zip.read_file("content/" + name)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if bytes.size()>256*1024 or bytes.is_empty() or hash.finish().hex_encode()!=HASHES[name]:
			zip.close()
			return {"ok":false,"error":"523 원본 ZIP의 설정 파일이 다릅니다: " + name}
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8().trim_prefix("\ufeff"))
		if not parsed is Dictionary or not parsed.get("rows") is Array:
			zip.close()
			return {"ok":false,"error":"원본 ZIP의 설정 형식이 다릅니다."}
		staged[name] = parsed.rows
	zip.close()
	return _install_tables(staged,path)

func _install_tables(staged: Dictionary, path: String) -> Dictionary:
	if staged["OptimizedTerritoryView.json"].size()!=195 or staged["EffectSpriteSimplify.json"].size()!=1 or staged["ClientOptimizeTerritoryConditionType.json"].size()!=3 or staged["UIFlashEffectHideList.json"].size()!=90:
		return {"ok":false,"error":"523 원본 설정 개수가 다릅니다."}
	# All content is hash-bound; install only after every file passed.
	var next_rows: Array[Dictionary] = []
	var next_ids: Dictionary = {}
	var next_lands: Dictionary = {}
	for raw: Dictionary in staged["OptimizedTerritoryView.json"]:
		var row: Dictionary = raw.duplicate(true)
		var id: int = int(row.ID)
		var land: int = int(row.LandID)
		next_rows.append(row)
		next_ids[id] = row
		if not next_lands.has(land): next_lands[land] = []
		next_lands[land].append(row)
	var next_conditions: Dictionary = {}
	for row: Dictionary in staged["ClientOptimizeTerritoryConditionType.json"]: next_conditions[int(row.ID)] = str(row.Name)
	var next_simplify: Dictionary = {}
	for row: Dictionary in staged["EffectSpriteSimplify.json"]: next_simplify[int(row.DefaultEffect)] = int(row.SmallEffect)
	territories = next_rows
	by_id = next_ids
	by_land = next_lands
	conditions = next_conditions
	simplify = next_simplify
	flash_paths.assign(staged["UIFlashEffectHideList.json"])
	directory = path
	return {"ok":true,"territories":territories.size(),"lands":by_land.size(),"simplify":simplify.size()}

func defaults_for(id: int) -> Dictionary:
	var row: Dictionary = by_id.get(id,{})
	if row.is_empty(): return {}
	return {"limit_effect_count":bool(row.DefaultLowEffectCount),"hide_doll":bool(row.DefaultHideMagicDoll)}

func condition_changes_settings(id: int) -> bool:
	var row: Dictionary = by_id.get(id,{})
	return not row.is_empty() and int(row.ConditionTypeId)!=0 and (row.DefaultLowEffectCount!=row.ConditionLowEffectCount or row.DefaultHideMagicDoll!=row.ConditionHideMagicDoll)

func at_source_point(context: Dictionary) -> Dictionary:
	if territories.is_empty(): return {"status":"source_not_loaded","settings":{}}
	# Never accept current PC map4, a same-name map, or an unverified projection.
	if context.get("source_snapshot") != "patch523" or context.get("coordinate_space") != "lineagem_m" or not context.get("verified") is bool or context.get("verified") != true:
		return {"status":"M_coordinates_unverified","settings":{}}
	var land: Variant = context.get("land_id")
	if not (land is int or land is float) or not is_finite(float(land)) or float(land)<0.0 or float(land)!=floorf(float(land)):
		return {"status":"invalid_land","settings":{}}
	var point: Variant = context.get("point")
	if not point is Vector2 or not point.is_finite(): return {"status":"invalid_point","settings":{}}
	var matches: Array[Dictionary] = []
	for row: Dictionary in by_land.get(int(land),[]):
		if point.x < float(row.StartX) or point.y < float(row.StartY) or point.x > float(row.EndX) or point.y > float(row.EndY): continue
		# Interior membership is common to inclusive/exclusive rectangle rules.
		# Unknown boundary ownership stays pending instead of guessing an edge.
		if point.x == float(row.StartX) or point.x == float(row.EndX) or point.y == float(row.StartY) or point.y == float(row.EndY):
			return {"status":"boundary_pending","settings":{}}
		matches.append(row)
	if matches.is_empty(): return {"status":"outside","settings":{}}
	# Overlap is safe only when every possible priority produces the same
	# outcome. Keep all IDs and rows; do not invent a native winner.
	var row: Dictionary = matches[0]
	var ids: Array[int] = []
	for candidate: Dictionary in matches:
		ids.append(int(candidate.ID))
		for key: String in ["DefaultLowEffectCount","DefaultHideMagicDoll","ConditionLowEffectCount","ConditionHideMagicDoll","ConditionTypeId"]:
			if candidate[key] != row[key]: return {"status":"overlap_pending","settings":{},"matches":matches.duplicate(true)}
	var condition: int = int(row.ConditionTypeId)
	if condition_changes_settings(int(row.ID)): return {"status":"condition_pending","settings":{},"row_ids":ids,"condition":conditions.get(condition,"")}
	# Equal source values produce the same display under either condition state.
	# This never asserts that a siege/hot-time condition is active or inactive.
	return {"status":"source_default","settings":defaults_for(int(row.ID)),"row_ids":ids,"condition_invariant":condition!=0}

func simplified_sprite(sprite_id: int, low: bool, records: Dictionary) -> int:
	if not low or not simplify.has(sprite_id): return sprite_id
	var small: int = int(simplify[sprite_id])
	# The source effect namespace is literal; never change PC SPX group IDs,
	# actor bodies, unrelated effects, or a manifest without the small variant.
	return small if records.has("overlay:" + str(small)) else sprite_id
