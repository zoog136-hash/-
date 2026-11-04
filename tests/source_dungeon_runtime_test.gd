extends SceneTree
const RULES = preload("res://scripts/dungeons/source_dungeon_runtime.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	var runtime = RULES.new()
	check(not runtime.load_pack("user://missing/manifest.json").ok,"missing optional data")
	check(runtime.entries("tower").is_empty(),"no fabricated tower data")
	check(not runtime.entry_check("tower",4,100).ok,"no entry without data")
	var path := OS.get_environment("TWILIGHT_DUNGEON523_PACK")
	if path.is_empty():
		print("DUNGEON523_REAL_PACK_SKIPPED: set TWILIGHT_DUNGEON523_PACK to private manifest")
		_finish()
		return
	check(runtime.load_pack(path).ok,"real pinned source pack loads")
	check(runtime.entries("tower").size() == 100 and runtime.entries("tower",true).size() == 100,"tower modes")
	check(runtime.entries("orim").size() == 10 and runtime.entries("orim",true).size() == 10,"orim modes")
	check(runtime.entries("special").size() == 22,"special UI entries")
	check(runtime.entries("rechargers").size() == 450,"recharge entries")
	var shared: Dictionary = runtime.context_for_land(48752)
	check(shared.stage_candidates.size() == 2,"same Land retains both difficulty candidates")
	check(int(shared.stage_candidates[0].stage_id) != int(shared.stage_candidates[1].stage_id),"Land never selects Stage")
	var waves: int = 0
	for entry: Dictionary in runtime.data.orim:
		var stage_id := int(entry.stage.ID)
		waves += runtime.waves(stage_id).size()
		var boundary := 28.0 if bool(entry.stage.IsHard) else 40.0
		var section: Dictionary = runtime.orim_sections(stage_id,boundary)
		check(section.candidates.size() == 2 and section.boundary_unresolved and not section.grantable,"unresolved shared boundary")
		check(not runtime.orim_sections(stage_id,boundary + 0.5).boundary_unresolved,"interior section")
		check(not runtime.entry_check("orim",stage_id,100).ok,"closed mode never grants entry")
	check(waves == 2110,"all authored spawn rows")
	check(not runtime.orim_sections(2,-1).ok and not runtime.orim_sections(2,NAN).ok,"invalid clocks")
	check(runtime.reward_preview("orim",2,true).is_empty(),"no invented immediate Orim rewards")
	var normal: Array = runtime.reward_preview("tower",4)
	var immediate: Array = runtime.reward_preview("tower",4,true)
	check(normal.size() == 6 and immediate.size() == 7,"distinct normal and immediate rewards")
	check(int(normal[0].row.Amount) != int(immediate[0].row.Amount),"different reward amounts preserved")
	var tower: Dictionary = runtime.stage("tower",4)
	check(int(tower.immediate.payment.ClassID) == 764,"dragon diamond currency, not Gem4")
	check(int(tower.stage.TimeLimit) == 300,"raw timer not converted")
	check(not runtime.entry_check("tower",4,69).ok,"minimum level guard")
	check(runtime.stage("tower",0).is_empty(),"unknown Stage never defaults")
	check(int(runtime.context_for_land(47543).time_group.row.ID) == 31393,"direct time group wins over competition summary30582")
	check(runtime.context_for_land(46952).time_group.is_empty(),"lobby does not inherit competition timer")
	check(runtime.recharge_preview(185124).is_empty(),"link test item not ordinary recharger")
	var recharge: Dictionary = runtime.recharge_preview(374041)
	check(recharge.seconds == 3600 and int(recharge.group.row.ID) == 31982 and not recharge.usable,"correct recharge target and unit, no fabricated cap handler")
	check(int(recharge.item.deletion[0].date.Day) == 11,"TargetDateTime expiry, not Value0=permanent")
	tower.stage.IsHard = true
	check(not runtime.stage("tower",4).stage.IsHard,"preview copies cannot alter source identity")
	var invalid_dir := "user://dungeon-test-invalid"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(invalid_dir))
	var original_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	for patch: Dictionary in [{"version":508},{"payload":"../dungeons.json"},{"schema":{}},{"bytes":"6050456"},{"sha256":"bad"}]:
		var malformed: Dictionary = original_manifest.duplicate(true)
		malformed.merge(patch,true)
		var file := FileAccess.open(invalid_dir.path_join("manifest.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(malformed))
		file.close()
		check(not runtime.load_pack(invalid_dir.path_join("manifest.json")).ok,"bad manifest rejected")
		check(runtime.entries("tower").size() == 100,"bad replacement preserves active catalogue")
	check(runtime.install_pack(path).ok,"verified bytes install into isolated user data")
	var restored = RULES.new()
	check(restored.load_pack().ok,"installed pack restored after restart")
	_finish()

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("DUNGEON523_RUNTIME: %d checks / %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
