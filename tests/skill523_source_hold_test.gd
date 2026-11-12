extends SceneTree
## 523 skill profile loader: a held material (missing / TestItem=true /
## unproven original item) holds only that material and the skills that spend
## it, never the whole profile set. The original archive is optional (absent
## in CI); with it, the real Main load and a save/load round trip are checked.
const QA = preload("res://tests/qa_class_selection.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const ADAPTER = preload("res://scripts/skills/player_skills523.gd")
const FLASH_ID := "lmref_f7afaf54afcbb439"
var checks: int = 0
var failures: Array[String] = []
var real: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func unit() -> void:
	var adapter = ADAPTER.new()
	# Malformed public bridge: the binding file itself is invalid.
	var bad: Dictionary = adapter.source_material_holds({"material_inventory_keys":{"1":{"inventory_key":3,"native_item_id":254}}})
	check(bad.invalid, "malformed bridge invalidates the binding file")
	# Profile material collection covers SpellClass, SpellCost and InvokeOption rows.
	var profile: Dictionary = {"row":{"SpellMaterialTypeID":1,"SpellMaterialItemAmount":2},
		"costs":[{"SpellMaterialTypeID1":54,"SpellMaterialItemAmount1":1,"SpellMaterialTypeID2":6,"SpellMaterialItemAmount2":0}],
		"execution_graph":{"spells":[{"row":{"SpellMaterialTypeID":92,"SpellMaterialItemAmount":1},"costs":[]}],
			"invokes":[{"row":{"MaterialTypeID":33,"MaterialAmount":3}}]}}
	var types: Array[String] = ADAPTER.profile_material_types(profile)
	check(types == ["1","54","92","33"], "material types from row/cost/graph/invoke, zero amounts ignored: "+str(types))
	# A held bridge blocks only a cost that spends it.
	adapter.profiles = {"t":{"row":{"ID":1,"SpellMaterialTypeID":6,"SpellMaterialItemAmount":1,"SpellTypeID":1,"SpellCompositionNode":0,"SpellCategoryID":1,
		"MPCostUnit":1,"VPCost":0,"TargettingTypeID":1,"TargetKindID":1,"TargetAreaRadius":0,"CastRange":0,"MinCastRange":0,"CastDelay":0,"CastGroupID":0,"HPCost":0,"MPCost":5,"TargetLimitCount":0},
		"learn_limits":[{"ClassID":1,"IsTutorialSpell":false,"CharacterMinLevel":1}],"bonuses":[],"buffs":[],"costs":[],"cast_groups":[],
		"target_kind":{"Name":"Self"},"targeting_type":{"Name":"Self"}}}
	adapter.bindings = {"class_ids":{"기사":1},"material_inventory_keys":{"6":{"inventory_key":"흑마석","native_item_id":713}},"retained_host_items":[],"skills":{}}
	adapter.material_holds = {"6":{"native_item_id":713,"inventory_key":"흑마석","reason":"source_TestItem_true"}}
	var out: Dictionary = adapter.apply_to({"id":"t","activation":"active","mode":"buff","class":"기사"},"기사",false)
	check(str(out.get("source523_block_reason","")).contains("원본#713"), "spending a held material blocks only that skill: "+str(out.get("source523_block_reason","")))
	check(not out.get("items",{}).has("흑마석"), "a held material is never charged")
	if DEF.identity().is_empty():
		var none: Dictionary = adapter.source_material_holds(JSON.parse_string(FileAccess.get_file_as_string(ADAPTER.BINDINGS_PATH)))
		check(not none.invalid and none.holds.size() == 15, "no archive: every material held per item, binding file valid")
		check(not adapter.material_ready(JSON.parse_string(FileAccess.get_file_as_string(ADAPTER.BINDINGS_PATH)),"마력의 돌"), "no archive: no material is spendable")

func run() -> void:
	unit()
	var archive: bool = not DEF.identity().is_empty()
	real["archive"] = archive
	if archive:
		var world = load("res://Main.tscn").instantiate()
		root.add_child(world)
		world.set_process(false)
		world.save_timer = -100000.0
		check(QA.enter_game(world, "기사"), "actual Main class confirmation")
		var catalog = world.original_skills.catalog
		var adapter = catalog.source523
		var status: Dictionary = adapter.source_fallback_status
		var public: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ADAPTER.BINDINGS_PATH))
		var reasons: Dictionary = {}
		for id: String in status.get("deferred",{}):
			var key: String = str(status.deferred[id]).split(" ")[0].split(":")[0]
			reasons[key] = int(reasons.get(key,0)) + 1
		real["state"] = status.get("state","")
		real["mode"] = adapter.source_mode
		real["bound"] = public.skills.size()
		real["loaded"] = adapter.profiles.size()
		real["deferred"] = status.get("deferred",{}).size()
		real["deferred_reasons"] = reasons
		real["material_holds"] = adapter.material_holds
		check(adapter.source_mode == "original_bound_profiles" and status.get("state") == "loaded", "real archive: profiles load instead of a whole-set hold")
		check(status.get("reason","") != "native_material_binding_unconfirmed", "no whole-set material hold")
		check(adapter.material_holds.has("6") and int(adapter.material_holds["6"].native_item_id) == 713 and adapter.material_holds["6"].reason == "source_TestItem_true", "흑마석 bridge (original #713 TestItem=true) is held on its own")
		check(adapter.material_holds.size() == 1, "only the test-item material is held: "+str(adapter.material_holds.keys()))
		check(adapter.material_ready(public,"마력의 돌") and not adapter.material_ready(public,"흑마석"), "material spend gate is per material")
		var flash: Dictionary = catalog.record_for(FLASH_ID)
		real["flash_spell_move"] = not flash.is_empty() and catalog.resolve(flash).has("spell_move523")
		check(real.flash_spell_move, "original SpellMove plan now attaches through the profile loader")
		var records_with_source: int = 0
		for record: Dictionary in catalog.records:
			if adapter.profiles.has(str(record.get("id",""))) and adapter.apply_to(record.duplicate(true),str(record.get("class","")),false).has("source523"): records_with_source += 1
		real["records_with_source523"] = records_with_source
		check(records_with_source == adapter.profiles.size(), "every loaded profile reaches its record")
		# Save/load: profiles are derived from the archive, never persisted.
		var before: Dictionary = catalog.export_state().duplicate(true)
		check(world._save_game(true) == OK, "save succeeds with loaded profiles")
		var text: String = FileAccess.get_file_as_string(world.SAVE_PATH)
		check(not text.contains("row_json") and not text.contains("material_holds"), "save holds no original profile rows")
		world._load_game(true)
		check(catalog.export_state() == before, "original skill state survives save/load")
		check(adapter.profiles.size() == int(real.loaded) and adapter.material_holds.has("6"), "profiles unchanged after load")
		real["save_bytes"] = text.length()
	print("SKILL523_SOURCE_HOLD_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
	quit(0 if failures.is_empty() else 1)
