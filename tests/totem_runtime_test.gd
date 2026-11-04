extends SceneTree

const Runtime = preload("res://scripts/progression/totem_runtime.gd")
var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(label)

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _initialize() -> void:
	if OS.get_environment("TWILIGHT_TOTEM_PACK").is_empty():
		print("TOTEM_RUNTIME SKIP: install the private 523 pack and set TWILIGHT_TOTEM_PACK")
		quit(0)
		return
	var runtime := Runtime.new()
	check(runtime.install(OS.get_environment("TWILIGHT_TOTEM_PACK")),"actual private pack")
	if not runtime.available():
		quit(1)
		return
	check(runtime.rows("Totem").size() == 3,"three totems")
	check(runtime.rows("NpcClassForNpcGroup").size() == 112,"activation membership")
	check(runtime.rows("NpcItemDropView").size() == 105,"drop membership stays distinct")
	var zeroes := 0
	var pools := 0
	for totem: Dictionary in runtime.rows("Totem"):
		var id := int(totem.ID)
		check(runtime.level_definition(id,0).get("Level") == 0,"opaque IDs resolve by level")
		for level in range(1,11):
			var stage: Dictionary = runtime.level_preview(id,level)
			check(stage.materials.size() == 2,"two separate material rows")
			check(stage.upgrade_available and stage.policy == Runtime.LOCAL_POLICY and is_equal_approx(stage.success_fraction,float(stage.level.Probability)/1000000.0),"explicit local target-level policy keeps source success axis separate")
			for slot: String in stage.option_pools:
				pools += 1
				var weights := 0
				for candidate: Dictionary in stage.option_pools[slot]:
					weights += int(candidate.source.Probability)
					if int(candidate.bonus.bonus.Value) == 0: zeroes += 1
				check(weights == 1000000,"per-slot weights")
		check(runtime.level_definition(id,6).Probability > runtime.level_definition(id,5).Probability,"nonmonotonic success data")
	check(pools == 52,"all option pools")
	check(zeroes == 6,"zero-value candidates retained")
	for npc: Dictionary in runtime.rows("NpcClassForNpcGroup"):
		runtime.state = {}
		check(runtime.record_kill(int(npc.NpcClassID)),"every activation NPC including bosses")
		var count := 0
		for p: Dictionary in runtime.state.values(): count += int(p.kills)
		check(count == 1,"no duplicate credit")
	runtime.state = {}
	check(not runtime.record_kill(-1),"unknown species no credit")
	for kill in range(2999): runtime.record_kill(47524)
	check(not runtime.progress(4).active,"2999 stays inactive")
	runtime.record_kill(47524)
	check(runtime.progress(4).active and runtime.progress(4).level == 0,"3000 activates at level zero")
	runtime.record_kill(47524)
	check(runtime.progress(4).kills == 3000,"activation counter capped")
	var roundtrip := runtime.export_state()
	check(runtime.accept_state(roundtrip),"state roundtrip")
	check(runtime.accept_state({"version":1,"totems":roundtrip.totems}) and runtime.export_state().version == 2,"v1 state upgrades without losing activation or selected outcomes")
	for total in range(31):
		runtime.state = {}
		var remaining := total
		for id in [4,14,24]:
			var level := mini(10,remaining)
			remaining -= level
			runtime.state[str(id)] = {"active":true,"kills":3000,"level":level,"selected":{}}
		var expected := 0 if total < 15 else mini(4,1 + floori(float(total-15)/5.0))
		check(is_equal_approx(runtime.resonance().pierce_reduction_fraction,float(expected)/100.0),"cumulative resonance %d" % total)
	var before := runtime.export_state()
	check(not runtime.install("/nonexistent/totem"),"bad replacement rejected")
	check(runtime.export_state() == before and runtime.available(),"replacement preserves state and active tables")
	var invalid_root := "user://totem-invalid-pack-probe"
	DirAccess.make_dir_recursive_absolute(invalid_root)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_TOTEM_PACK").path_join("manifest.json")))
	var body: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_TOTEM_PACK").path_join("totem_data.json")))
	body.tables.Totem[0] = 9
	write_json(invalid_root.path_join("totem_data.json"),body)
	manifest.sha256 = FileAccess.get_sha256(invalid_root.path_join("totem_data.json"))
	write_json(invalid_root.path_join("manifest.json"),manifest)
	check(not runtime.install(invalid_root),"malformed matching-hash rows rejected")
	check(runtime.export_state() == before and runtime.available(),"malformed row keeps previous pack and state")
	body.tables.Totem[0] = {"ID":4}
	write_json(invalid_root.path_join("totem_data.json"),body)
	manifest.sha256 = FileAccess.get_sha256(invalid_root.path_join("totem_data.json"))
	write_json(invalid_root.path_join("manifest.json"),manifest)
	check(not runtime.install(invalid_root),"missing required fields rejected safely")
	var invalid := before.duplicate(true)
	invalid.totems["4"].level = 11
	check(not runtime.accept_state(invalid),"malformed save rejected")
	check(runtime.export_state() == before and runtime.save_blocked,"malformed save preserved")
	check(runtime.accept_state(before),"good reload unblocks save")
	check(runtime.recipes().size() == 6,"only recipes with view")
	for recipe: Dictionary in runtime.recipes():
		check(not recipe.inputs.is_empty() and recipe.outputs.size() == 1,"crafting paths resolved")
	var invoke_values: Array = []
	for candidate: Dictionary in runtime.level_preview(4,10).option_pools["1"]:
		invoke_values.append(float(candidate.bonus.bonus.Value)/float(candidate.bonus.ui_unit.Denominator))
	check(invoke_values == [0.5,1.0,1.5],"combat proc values differ from selection and success")
	check(runtime.rows("ShieldGroup").size() == 1 and runtime.row("ShieldGroup",454).is_empty(),"missing shield body not substituted")
	runtime.state = {"4":{"active":true,"kills":3000,"level":0,"selected":{}}}
	for land: Dictionary in runtime.map_contexts.get("4",[]):
		check(is_equal_approx(runtime.map_experience_fraction(int(land.ID),str(land.AssetPath)),0.05),"exact native Land and asset enables regional EXP")
		check(runtime.map_experience_fraction(int(land.ID),"unrelated/") == 0,"same Land with wrong asset is rejected")
	check(runtime.map_experience_fraction(13158,"13158/") == 0,"legacy asset number is not native Land identity")
	print("TOTEM_RUNTIME checks=%d failures=%d" % [checks,failed])
	quit(1 if failed else 0)
