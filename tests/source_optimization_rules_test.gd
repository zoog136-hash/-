extends SceneTree
const RULES = preload("res://scripts/animation/source_optimization.gd")
const PROBE = preload("res://tests/source_overlay_probe.gd")
var checks: int = 0
var failures: Array[String] = []

class Owner extends Node2D:
	var rules = RULES.new()
	var low: bool = true
	func select_source_presentation_effect(id: int, records: Dictionary) -> int:
		return rules.simplified_sprite(id,low,records)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("SOURCE_OPTIMIZATION_FAIL: ",label)

func run() -> void:
	var owner := Owner.new()
	root.add_child(owner)
	var path: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	check(not path.is_empty(),"actual private patch523 input required")
	var loaded: Dictionary = owner.rules.load_directory(path)
	check(bool(loaded.ok),"four actual source SHA checks")
	if not bool(loaded.ok): quit(1); return
	check(owner.rules.territories.size()==195 and owner.rules.by_land.size()==99,"all actual territories and Lands")
	check(owner.rules.conditions.size()==3 and owner.rules.flash_paths.size()==90,"condition and flash rows retained")
	var resolved: int = 0
	var conditional: int = 0
	var overlapping: int = 0
	for row: Dictionary in owner.rules.territories:
		var id: int = int(row.ID)
		var defaults: Dictionary = owner.rules.defaults_for(id)
		check(defaults.limit_effect_count==row.DefaultLowEffectCount and defaults.hide_doll==row.DefaultHideMagicDoll,"raw defaults %d" % id)
		var point: Vector2 = Vector2((float(row.StartX)+float(row.EndX))*0.5,(float(row.StartY)+float(row.EndY))*0.5)
		var result: Dictionary = owner.rules.at_source_point({"source_snapshot":"patch523","coordinate_space":"lineagem_m","verified":true,"land_id":int(row.LandID),"point":point})
		check(result.status in ["source_default","condition_pending","overlap_pending","boundary_pending"],"every native center classified %d" % id)
		if result.status=="source_default": resolved+=1
		elif result.status=="condition_pending": conditional+=1
		elif result.status=="overlap_pending": overlapping+=1
	check(resolved==163 and conditional==13 and overlapping==0,"actual source centers: 163 equal-outcome defaults, 13 condition-dependent, 19 boundaries")
	for id: int in [242488,243638]:
		var row: Dictionary = owner.rules.by_id[id]
		var center := Vector2((float(row.StartX)+float(row.EndX))*0.5,(float(row.StartY)+float(row.EndY))*0.5)
		var result: Dictionary = owner.rules.at_source_point({"source_snapshot":"patch523","coordinate_space":"lineagem_m","verified":true,"land_id":int(row.LandID),"point":center})
		check(not owner.rules.condition_changes_settings(id) and result.get("condition_invariant")==true and result.settings.limit_effect_count and result.settings.hide_doll,"same source values apply independently of unobserved condition %d" % id)
	check(owner.rules.condition_changes_settings(53942),"different siege outcomes still need the real condition")
	check(owner.rules.condition_changes_settings(104202),"different hot-time outcomes still need the real condition")
	check(owner.rules.at_source_point({"source_snapshot":"pc","coordinate_space":"source_map84","verified":true,"land_id":4,"point":Vector2(32760,32250)}).settings.is_empty(),"same PC map4 is never M evidence")
	check(owner.rules.at_source_point({"source_snapshot":"patch523","coordinate_space":"lineagem_m","verified":true,"land_id":4,"point":Vector2(32750,32250)}).status=="boundary_pending","unknown rectangle boundary stays pending")
	var zip_path: String = OS.get_environment("TWILIGHT_PATCH523_ZIP")
	check(not zip_path.is_empty(),"actual original source ZIP required")
	var before_zip: String = JSON.stringify(owner.rules.territories)
	check(bool(owner.rules.load_zip(zip_path).ok) and JSON.stringify(owner.rules.territories)==before_zip,"verified ZIP consumes identical four source tables without extracting art")
	var old: String = JSON.stringify(owner.rules.territories)
	check(not bool(owner.rules.load_directory("user://not-an-original-source").ok) and JSON.stringify(owner.rules.territories)==old,"failed pack change preserves active source")
	var records: Dictionary = {"overlay:24941":{},"overlay:29044":{}}
	check(owner.rules.simplified_sprite(24941,false,records)==24941,"full preserves source ID")
	check(owner.rules.simplified_sprite(24941,true,records)==29044,"only exact native simplify mapping")
	check(owner.rules.simplified_sprite(123,true,records)==123,"unrelated effect unchanged")
	check(owner.rules.simplified_sprite(24941,true,{"overlay:24941":{}})==24941,"missing small definition preserves full")
	var validation = preload("res://scripts/animation/original_source_preview.gd").new()
	for broken: Dictionary in [{"source_sprite_id":1,"one_shot_overlay":true},{"source_sprite_id":29044,"one_shot_overlay":true,"tracks":[]},{"source_sprite_id":29044,"one_shot_overlay":true,"source_missing_attachments":5}]:
		validation._manifest_records = {"overlay:29044":broken}
		check(not validation._overlay_files_available(29044),"malformed small model preserves full without renderer errors")
	validation.free()
	var probe = PROBE.new()
	owner.add_child(probe)
	probe._playback_mode = "compatible"
	probe._manifest_records = records
	check(probe.spawn_source_overlay(24941,0),"actual overlay factory uses selector")
	check(probe._overlay_nodes.back().get_meta("selected_source_effect")==29044,"factory selects small variant")
	probe.files_available = false
	check(probe.spawn_source_overlay(24941,0) and probe._overlay_nodes.back().get_meta("selected_source_effect")==24941,"unavailable small files preserve full")
	probe.files_available = true
	PROBE.reject_small = true
	check(probe.spawn_source_overlay(24941,0) and probe._overlay_nodes.back().get_meta("selected_source_effect")==24941,"invalid small compositor preserves full")
	PROBE.reject_small = false
	owner.low = false
	check(probe.spawn_source_overlay(24941,0) and probe._overlay_nodes.back().get_meta("selected_source_effect")==24941,"user full choice reaches factory")
	owner.queue_free()
	await process_frame
	print("SOURCE_OPTIMIZATION_RULES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":195,"centers_resolved":resolved,"conditional":conditional,"overlapping":overlapping,"pixel_validation":"NOT_TESTED; factory probe contains no pixels"}))
	quit(0 if failures.is_empty() else 1)
