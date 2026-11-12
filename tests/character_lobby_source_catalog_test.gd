extends SceneTree
## Synthetic relation tests run by default. The explicit owned-input opt-in
## also checks all actual 523 pairs; neither mode proves pixels or rendering.
const CATALOG = preload("res://scripts/characters/lobby_source_catalog.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

class FixtureReader extends RefCounted:
	var calls: Dictionary = {}
	var identity_calls: int = 0
	var rows_calls: int = 0
	var source: Dictionary = {"kind":"twilight.current523.original-definitions.v1","source_snapshot":"patch523","source_sha256":DEFINITIONS.SOURCE_SHA,"source_bytes":DEFINITIONS.SOURCE_BYTES}
	var tables: Dictionary = {
		"Class":[{"ID":1,"CanCreateClient":true},{"ID":2,"CanCreateClient":true},{"ID":3,"CanCreateClient":false}],
		"Gender":[{"ID":1},{"ID":2}],
		"ClassAssets":[
			{"ClassID":1,"GenderID":1,"LobbySpineID":101,"LobbyBackEffectFile":201,"LobbyFrontEffectFile":202},
			{"ClassID":1,"GenderID":2,"LobbySpineID":102,"LobbyBackEffectFile":0,"LobbyFrontEffectFile":0},
			{"ClassID":2,"GenderID":1,"LobbySpineID":103,"LobbyBackEffectFile":203,"LobbyFrontEffectFile":0}],
		"UISpine":[
			{"ID":101,"AssetID":1001,"OffsetX":600,"OffsetY":0,"Flip":false},
			{"ID":102,"AssetID":1002,"OffsetX":-17.25,"OffsetY":13.5,"Flip":true},
			{"ID":103,"AssetID":1003,"OffsetX":0,"OffsetY":0,"Flip":false}],
		"AssetView":[
			{"AssetId":1001,"AssetTypeId":22,"FilePath":"Spine_Knight_Male.json"},
			{"AssetId":1002,"AssetTypeId":22,"FilePath":"nested/Spine_Knight_Female.json"},
			{"AssetId":1003,"AssetTypeId":22,"FilePath":"Spine_Other.json"},
			{"AssetId":201,"AssetTypeId":101,"FilePath":"FX_Back.csb"},
			{"AssetId":202,"AssetTypeId":101,"FilePath":"FX_Front.csb"}],
		"AssetType":[{"ID":22,"Name":"Spine","Path":"UI/Spine/"},{"ID":101,"Name":"UI_CsbFile","Path":"UI/CsbFile/"}]
	}
	func identity() -> Dictionary:
		identity_calls += 1
		return source.duplicate(true)
	func related(table: String, field: String, id: int) -> Array:
		var key: String = "%s:%s:%d" % [table,field,id]
		calls[key] = int(calls.get(key,0)) + 1
		var found: Array = []
		for row: Variant in tables.get(table,[]):
			if row is Dictionary and row.get(field) == id: found.append(row.duplicate(true))
		return found
	func rows(_table: String) -> Array:
		rows_calls += 1
		return []
	func total_calls() -> int:
		var total: int = 0
		for count: Variant in calls.values(): total += int(count)
		return total

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_LOBBY_SOURCE_FAIL ",label)
	return ok

func fixture() -> Dictionary:
	var reader := FixtureReader.new()
	var catalog = CATALOG.new()
	catalog.test_reader = reader
	return {"reader":reader,"catalog":catalog}

func invalid_field(table: String, index: int, field: String, value: Variant, label: String) -> void:
	var f: Dictionary = fixture()
	f.reader.tables[table][index][field] = value
	var result: Dictionary = f.catalog.resolve(1,1)
	check(not result.get("ok",true) and not str(result.get("problem","")).is_empty(),label)

func unit() -> void:
	var f: Dictionary = fixture()
	var result: Dictionary = f.catalog.resolve(1,1)
	if not check(result.get("ok",false),"valid original-ID relation resolves"): return
	check(result.get("synthetic",false),"fixture reader is explicitly synthetic")
	check(result.get("source_identity",{}) == f.reader.source,"archive identity retained as provenance")
	check(result.get("class_assets",{}) == f.reader.tables.ClassAssets[0],"complete source composite row retained")
	check(result.spine.get("status") == "resolved" and result.spine.get("uispine_id") == 101 and result.spine.get("asset_id") == 1001,"body uses exact UISpine and AssetView IDs")
	check(result.spine.get("path") == "UI/Spine/Spine_Knight_Male.json","exact source path composition preserves case")
	check(result.spine.get("offset_x") == 600 and result.spine.get("offset_y") == 0 and result.spine.get("flip") == false,"original presentation metadata retained")
	check(result.back_effect.get("path") == "UI/CsbFile/FX_Back.csb" and result.front_effect.get("path") == "UI/CsbFile/FX_Front.csb","back and front remain separate CSB references")
	check(result.back_effect.get("asset_type_id") == 101 and result.spine.get("asset_type_id") == 22,"CSB effects are not reclassified as skeletons")
	check(not result.spine.get("evidence",{}).is_empty() and not result.front_effect.get("evidence",{}).is_empty(),"resolved layers retain source evidence")
	check(result.get("missing",[]).is_empty() and not result.get("rendered",false),"metadata resolution claims neither missing references nor rendered pixels")
	var first_calls: int = f.reader.total_calls()
	result.spine["path"] = "tampered"
	result.class_assets["LobbySpineID"] = 999
	var repeat: Dictionary = f.catalog.resolve(1,1)
	check(f.reader.total_calls() == first_calls,"repeated selection reuses relation results")
	check(repeat.spine.get("path") == "UI/Spine/Spine_Knight_Male.json" and repeat.class_assets.get("LobbySpineID") == 101,"returned data cannot mutate cached provenance")
	check(f.reader.rows_calls == 0,"production API uses indexed relations rather than full-table rows")
	var female: Dictionary = f.catalog.resolve(1,2)
	check(female.get("ok",false) and female.spine.get("path") == "UI/Spine/nested/Spine_Knight_Female.json","gender chooses its exact composite row and nested path")
	check(female.spine.get("offset_x") == -17.25 and female.spine.get("offset_y") == 13.5 and female.spine.get("flip") == true,"signed and fractional metadata is preserved without coordinate guesses")
	check(female.back_effect.get("status") == "optional_zero" and female.front_effect.get("status") == "optional_zero" and female.get("missing",[]).is_empty(),"zero effect IDs mean explicitly absent optional layers")
	var missing: Dictionary = f.catalog.resolve(2,1)
	check(missing.get("ok",false) and missing.spine.get("status") == "resolved","missing one effect does not discard valid body relation")
	check(missing.back_effect.get("status") == "missing_reference" and missing.back_effect.get("asset_id") == 203 and str(missing.back_effect.get("path","")).is_empty(),"unknown nonzero effect is reported without invented path")
	check(missing.get("missing",[]).size() == 1 and missing.front_effect.get("status") == "optional_zero","missing reference is distinct from optional zero")
	check(not f.catalog.resolve(2,2).get("ok",true),"missing composite pair does not substitute another gender")
	check(not f.catalog.resolve(3,1).get("ok",true),"noncreatable source class cannot enter creation presentation")
	for value: Variant in [0,-1,1.5,"1",true,null,{},[],INF,NAN]:
		check(not f.catalog.resolve(value,1).get("ok",true),"invalid class identifier rejected: "+str(value))
		check(not f.catalog.resolve(1,value).get("ok",true),"invalid gender identifier rejected: "+str(value))
	check(not f.catalog.resolve(1,3).get("ok",true),"unsupported source gender rejected")
	for table: String in ["Class","Gender","ClassAssets","UISpine","AssetView","AssetType"]:
		var dup: Dictionary = fixture()
		dup.reader.tables[table].append(dup.reader.tables[table][0].duplicate(true))
		check(not dup.catalog.resolve(1,1).get("ok",true),"ambiguous source relation refused: "+table)
	for item: Array in [["ClassAssets","LobbySpineID",1.5],["ClassAssets","LobbySpineID",0],["ClassAssets","GenderID",true],["ClassAssets","LobbyBackEffectFile",-1],["ClassAssets","LobbyFrontEffectFile","202"],["ClassAssets","LobbyFrontEffectFile",true],["UISpine","AssetID",0],["UISpine","AssetID","1001"],["UISpine","OffsetX",INF],["UISpine","OffsetY","0"],["UISpine","Flip",1],["AssetView","AssetTypeId",101],["AssetType","Path",7]]:
		invalid_field(item[0],0,item[1],item[2],"malformed source field refused: %s.%s=%s" % [item[0],item[1],str(item[2])])
	invalid_field("AssetView",3,"AssetTypeId",22,"wrong optional effect type is a source error")
	invalid_field("Class",0,"CanCreateClient",1,"numeric truth cannot replace source eligibility boolean")
	for path: String in ["../escape.json","nested/../escape.json","/absolute.json","C:/escape.json","res://evil.json","https://invalid/evil.json","nested\\evil.json","nested//evil.json","./evil.json","evil.json\n"]:
		invalid_field("AssetView",0,"FilePath",path,"unsafe asset path refused: "+path.c_escape())
	for prefix: String in ["../Spine/","/UI/Spine/","res://UI/Spine/","UI\\Spine/","UI//Spine/","UI/./Spine/","UI/Spine"]:
		invalid_field("AssetType",0,"Path",prefix,"unsafe type prefix refused: "+prefix.c_escape())
	for change: Array in [["kind","other"],["source_snapshot","base508"],["source_sha256","wrong"],["source_bytes",DEFINITIONS.SOURCE_BYTES+1]]:
		var wrong: Dictionary = fixture()
		wrong.reader.source[change[0]] = change[1]
		check(not wrong.catalog.resolve(1,1).get("ok",true),"wrong source identity refused: "+str(change[0]))
	var stale: Dictionary = fixture()
	stale.catalog.resolve(1,1)
	stale.reader.source.source_sha256 = "wrong-after-first-selection"
	check(not stale.catalog.resolve(1,1).get("ok",true),"identity revalidated before returning cached selection")
	var absent: Dictionary = fixture()
	absent.reader.tables.AssetView.remove_at(0)
	absent.reader.tables.AssetView.append({"AssetId":9999,"AssetTypeId":22,"FilePath":"Spine_Knight_Male.json"})
	var exact_missing: Dictionary = absent.catalog.resolve(1,1)
	check(exact_missing.get("ok",false) and exact_missing.spine.get("status") == "missing_reference" and str(exact_missing.spine.get("path","")).is_empty(),"matching basename cannot replace missing referenced AssetId")
	var refreshed: Dictionary = fixture()
	refreshed.catalog.resolve(1,1)
	refreshed.reader.tables.AssetView[0].FilePath = "Spine_Knight_MALE.json"
	refreshed.catalog.clear_cache()
	check(refreshed.catalog.resolve(1,1).spine.get("path") == "UI/Spine/Spine_Knight_MALE.json","explicit cache reset rereads exact source case")
	var replacement := FixtureReader.new()
	replacement.tables.AssetView[0].FilePath = "Replacement.json"
	refreshed.catalog.test_reader = replacement
	check(refreshed.catalog.resolve(1,1).spine.get("path") == "UI/Spine/Replacement.json","changing injected reader cannot reuse another reader's cached row")

func owned_original() -> void:
	var catalog = CATALOG.new()
	var pairs: Array[Dictionary] = DEFINITIONS.rows("ClassAssets")
	if not check(pairs.size() == 25,"owned input has actual 25 class/gender pairs"): return
	var missing_ids: Dictionary = {}
	var offsets_600: int = 0
	for pair: Dictionary in pairs:
		var class_id: int = int(pair.ClassID)
		var gender_id: int = int(pair.GenderID)
		var label: String = "%d/%d" % [class_id,gender_id]
		var result: Dictionary = catalog.resolve(class_id,gender_id)
		if not check(result.get("ok",false),"original composite resolves "+label): continue
		check(not result.get("synthetic",true) and result.source_identity.get("source_sha256") == DEFINITIONS.SOURCE_SHA,"original input provenance "+label)
		check(result.class_assets == pair,"exact original composite row "+label)
		check(result.spine.get("status") == "resolved" and result.spine.get("uispine_id") == pair.LobbySpineID,"original body relation "+label)
		var source_spine: Dictionary = DEFINITIONS.related("UISpine","ID",int(pair.LobbySpineID))[0]
		var source_view: Dictionary = DEFINITIONS.related("AssetView","AssetId",int(source_spine.AssetID))[0]
		var source_type: Dictionary = DEFINITIONS.related("AssetType","ID",int(source_view.AssetTypeId))[0]
		check(result.spine.get("path") == str(source_type.Path)+str(source_view.FilePath),"original body path "+label)
		check(result.spine.get("offset_x") == source_spine.OffsetX and result.spine.get("offset_y") == source_spine.OffsetY and result.spine.get("flip") == source_spine.Flip,"original offsets and flip "+label)
		if result.spine.get("offset_x") == 600: offsets_600 += 1
		for field: String in ["LobbyBackEffectFile","LobbyFrontEffectFile"]:
			var layer: Dictionary = result.back_effect if field == "LobbyBackEffectFile" else result.front_effect
			var id: int = int(pair[field])
			if id == 0:
				check(layer.get("status") == "optional_zero","original optional zero %s %s" % [label,field])
			else:
				var views: Array[Dictionary] = DEFINITIONS.related("AssetView","AssetId",id)
				if views.is_empty():
					missing_ids[id] = true
					check(layer.get("status") == "missing_reference" and layer.get("asset_id") == id and str(layer.get("path","")).is_empty(),"original unresolved reference %s #%d" % [label,id])
				else:
					var effect_type: Dictionary = DEFINITIONS.related("AssetType","ID",int(views[0].AssetTypeId))[0]
					check(layer.get("status") == "resolved" and layer.get("asset_type_id") == 101 and layer.get("path") == str(effect_type.Path)+str(views[0].FilePath),"original CSB path %s #%d" % [label,id])
	check(offsets_600 == 5,"exactly five original combinations carry offset 600")
	check(missing_ids.size() == 6,"six unique current523 effect references remain unresolved")
	for id: int in [84513,84523,84533,84543,166222,166232]: check(missing_ids.has(id),"known original missing AssetView row #"+str(id))

func run() -> void:
	unit()
	var original: bool = not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty()
	if original: owned_original()
	print("CHARACTER_LOBBY_SOURCE_CATALOG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"owned_original_opt_in":original,"scope":"SOURCE_RELATIONS_ONLY_NOT_PIXELS_OR_RENDERING"}))
	quit(0 if failures.is_empty() else 1)
