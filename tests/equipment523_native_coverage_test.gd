extends SceneTree
## Exhaustive relevant identity joins, never grants, acquisition or activation.
const C = preload("res://scripts/equipment523/common.gd")
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const Store = preload("res://scripts/equipment523/pack_store.gd")
const Service = preload("res://scripts/equipment523/service.gd")
const RULE_SHA: String = "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
const NATIVE_SHA: String = "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
var checks: int = 0
var failures: Array[String] = []
var blockers: Array[String] = []
var pack: Dictionary = {}
var document: Dictionary = {}
var owner: Variant
var groups: Dictionary = {}
var variants: Dictionary = {}
var selectors: Dictionary = {}
var equip_slots: Dictionary = {}
var source_counts: Dictionary = {}
var join_issues: Array[Dictionary] = []
var identity_issues: Array[Dictionary] = []
var status_counts: Dictionary = {}
var group_reports: Dictionary = {}
var timings: Dictionary = {}

class CatalogHost extends Node:
	var catalog_db: Dictionary = {"아이템":[]}
	var item_db: Array = []
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	func _enhancement_kind_for_record(record: Dictionary) -> String:
		return "equipment" if str(record.get("slot","")) not in ["","material","consumable","currency"] else ""

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_NATIVE_COVERAGE_FAIL ",label)

func _run() -> void:
	var path: String = OS.get_environment("EQUIPMENT523_RULES_FILE")
	var digest: String = RULE_SHA
	var native_root_given: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-sha256="): digest = arg.trim_prefix("--equipment523-sha256=")
		if arg.begins_with("--patch523-drop-root="): native_root_given = true
	if path.is_empty() or digest != RULE_SHA or not native_root_given or not ResourceLoader.exists(Native.OWNER_PATH):
		blockers.append("Exact processing rules and the existing native owner with an explicit --patch523-drop-root are required.")
		_finish()
		return
	var store = Store.new()
	var loaded: Dictionary = store.load_verified(path,RULE_SHA)
	_check(bool(loaded.get("ok",false)),"existing processing loader verifies the exact immutable base SHA and source schema")
	if not loaded.get("ok",false):
		blockers.append(str(loaded.get("error","processing cache unavailable")))
		_finish()
		return
	pack = store.pack
	owner = load(Native.OWNER_PATH)
	var identity: Dictionary = owner.pack_identity()
	_check(identity.get("sha256") == NATIVE_SHA and identity.get("schema") == 3 and identity.get("source_snapshot") == "patch523","public native loader verifies the exact regenerated original pin")
	if identity.get("sha256") != NATIVE_SHA:
		blockers.append("The exact verified full native catalog is unavailable.")
		_finish()
		return
	document = owner.data()
	_check(document.get("full_item_catalog",false) and document.get("item_shard_index",{}).size() == 34743,"the original full catalog contains all 34743 indexed definitions")
	_build_indexes()
	_collect()
	_validate_all()
	_measure_output_catalog(store)
	_finish()

func _build_indexes() -> void:
	for row: Dictionary in C.rows(pack,"ItemBonus"):
		var id: int = int(row.get("ItemClassID",0))
		var entry: Dictionary = C.bonus(pack,int(row.get("BonusID",0)))
		var type: Dictionary = entry.get("type",{})
		var name: String = str(type.get("Name",entry.get("name","")))
		if name not in ["WeaponType","EnchantEquipGroupID","ItemInvokeReplacementID","ScrollElementalSmith","ScrollElementalType","SpiritSmelt","GuaranteeBlessProb","DeleteTime"]: continue
		var raw: Dictionary = entry.get("raw",{})
		if not selectors.has(id): selectors[id] = {}
		if not selectors[id].has(name): selectors[id][name] = []
		selectors[id][name].append({"value":int(raw.get("Value",0)),"link":row,"raw":raw})
	for row: Dictionary in C.rows(pack,"ItemEquipSlot"):
		var id: int = int(row.get("ItemClassID",0))
		if not equip_slots.has(id): equip_slots[id] = []
		if not equip_slots[id].has(int(row.get("EquipSlotID",0))): equip_slots[id].append(int(row.get("EquipSlotID",0)))

func _selector(id: int, name: String, fallback: int = 0) -> int:
	var values: Dictionary = {}
	for entry: Dictionary in selectors.get(id,{}).get(name,[]): values[int(entry.value)] = true
	if values.size() > 1:
		join_issues.append({"kind":"ambiguous_selector","source_id":id,"selector":name,"distinct_values":values.keys()})
		return -1
	return int(values.keys()[0]) if values.size() == 1 else fallback

func _add(group: String, id: int, bless: int, basis: String) -> void:
	if not groups.has(group): groups[group] = {"variants":{},"source_rows":0,"basis":basis}
	groups[group].source_rows += 1
	var key: String = str(id)+":"+str(bless)
	groups[group].variants[key] = true
	if not variants.has(key): variants[key] = {"source_id":id,"bless":bless}

func _domain_states(group: String, id: int) -> void:
	for bless: int in [1,2]: _add(group,id,bless,"existing_processing_domain_normal_and_blessed; not_a_source_acquisition_claim")

func _supplied_states(group: String, id: int) -> void:
	var states: Array = document.get("needed_bless_states",{}).get(str(id),[])
	if states.is_empty():
		join_issues.append({"kind":"no_declared_native_bless_variant","source_id":id,"group":group})
		_add(group,id,-1,"missing_declared_source_variant; minus_one_is_a_report_sentinel_not_a_source_enum")
		return
	for bless: Variant in states: _add(group,id,int(bless),"original_full_catalog_needed_bless_states; declaration_not_acquisition")

func _collect() -> void:
	var elemental: Dictionary = {}
	for row: Dictionary in C.rows(pack,"ElementalSmith"):
		var key: String = str(int(row.WeaponTypeID))+":"+str(int(row.GradeID))
		if not elemental.has(key): elemental[key] = []
		elemental[key].append(int(row.ID))
	var grades: Dictionary = {}
	for row: Dictionary in C.rows(pack,"ItemBlessReinforcementGrade"): grades["%d:%d:%d" % [int(row.EquipSlotID),int(row.WeaponTypeID),int(row.GradeID)]] = true
	var slot_amounts: Dictionary = {}
	for row: Dictionary in C.rows(pack,"ItemBlessReinforcementSlotAmount"): slot_amounts["%d:%d" % [int(row.EquipSlotID),int(row.GradeID)]] = int(row.SlotAmount)
	var bless_configs: Dictionary = {}
	for row: Dictionary in C.rows(pack,"ItemBlessReinforcement"):
		var key: String = "%d:%d:%d" % [int(row.EquipSlotID),int(row.WeaponTypeID),int(row.GradeID)]
		if bool(row.get("IsTest",false)) or not grades.has(key) or int(slot_amounts.get("%d:%d" % [int(row.EquipSlotID),int(row.GradeID)],0)) <= 0:
			join_issues.append({"kind":"inactive_bless_configuration","parent_id":int(row.ID),"is_test":bool(row.get("IsTest",false)),"grade_join":grades.has(key)})
			continue
		if not bless_configs.has(key): bless_configs[key] = []
		bless_configs[key].append(int(row.ID))
	for key: Variant in pack.items:
		var id: int = int(key)
		var raw: Dictionary = C.item(pack,id).get("raw",{})
		var weapon: int = _selector(id,"WeaponType")
		var grade: int = int(raw.get("GradeID",0))
		var matches: Array = elemental.get(str(weapon)+":"+str(grade),[])
		if matches.size() == 1: _domain_states("elemental_smith.target",id)
		elif matches.size() > 1: join_issues.append({"kind":"ambiguous_elemental_target_configuration","source_id":id,"parents":matches})
		for slot: int in equip_slots.get(id,[]):
			var configurations: Array = bless_configs.get("%d:%d:%d" % [slot,weapon,grade],[])
			if configurations.size() == 1: _add("bless_reinforcement.target",id,2,"exact_slot_weapon_grade_grade_config_slot_amount_and_blessed_target")
			elif configurations.size() > 1: join_issues.append({"kind":"ambiguous_bless_target_configuration","source_id":id,"parents":configurations})
		if _selector(id,"ScrollElementalSmith") == 1 and _selector(id,"ScrollElementalType") in [1,2,3,4]: _supplied_states("elemental_smith.material",id)
		if int(raw.get("CategoryID",0)) == 151 and _selector(id,"GuaranteeBlessProb") == 0: _supplied_states("bless_reinforcement.material",id)
		if _selector(id,"SpiritSmelt") > 0: _supplied_states("spirit_smelt.material",id)
		var replacement: int = _selector(id,"ItemInvokeReplacementID")
		if replacement > 0:
			var found: bool = false
			for row: Dictionary in C.rows(pack,"ItemInvokeReplacementEntityView"):
				if int(row.get("ItemInvokeReplacementID",0)) == replacement: found = true; break
			if found and not C.find(pack,"ItemInvokeReplacement",replacement).is_empty(): _domain_states("invoke_replacement.target",id)
			else: join_issues.append({"kind":"missing_invoke_replacement_path","source_id":id,"replacement_id":replacement})
	_supplied_states("smelt.material",289162)
	for id: int in [169994,170004]: _supplied_states("invoke_replacement.material",id)
	for row: Dictionary in C.rows(pack,"ItemSmeltEntity"):
		if C.find(pack,"ItemSmelt",int(row.get("ItemSmeltID",0))).is_empty(): join_issues.append({"kind":"missing_smelt_parent","row_id":int(row.get("ID",0))}); continue
		_domain_states("smelt.target",int(row.ItemClassID))
	for row: Dictionary in C.rows(pack,"ItemSpiritSmeltEntity"):
		_add("spirit_smelt.target_source_exact",int(row.ItemClassID),int(row.BlessCode),"source_exact_BlessCode; zero_is_not_a_normal_or_blessed_enum")
		if int(row.BlessCode) == 0: _domain_states("spirit_smelt.target_local_wildcard",int(row.ItemClassID))
	var active_results: int = 0
	for row: Dictionary in C.rows(pack,"AlchemyResult"):
		if int(row.get("RecipeTypeID",0)) not in [63,113]: continue
		active_results += 1
		_add("alchemy.result",int(row.ItemClassID),int(row.BlessCode),"active_recipe_63_113_original_AlchemyResult_item_and_BlessCode")
	source_counts["active_alchemy_result_rows"] = active_results
	_check(active_results == 5095,"all 5095 original active-recipe AlchemyResult rows are covered")
	for row: Dictionary in C.rows(pack,"AlchemyItem"):
		var recipe: int = int(row.get("RecipeTypeID",0))
		if recipe not in [63,113] or bool(row.get("IsRecipeItem",false)): continue
		var id: int = int(row.ItemClassID)
		var raw: Dictionary = C.item(pack,id).get("raw",{})
		var grade: Dictionary = C.find(pack,"Grade",int(raw.get("GradeID",0)))
		if int(grade.get("GradeValue",0)) < (3 if recipe == 113 else 2): continue
		_domain_states("alchemy.material_processing_domain",id)
		_supplied_states("alchemy.material_source_variants",id)
	for row: Dictionary in C.rows(pack,"ItemForItemSet"):
		_domain_states("sets.member",int(row.ItemClassID))
		if C.find(pack,"ItemSet",int(row.ItemSetID)).is_empty(): join_issues.append({"kind":"missing_set_parent","set_id":int(row.ItemSetID),"source_id":int(row.ItemClassID)})
	for name: String in ["ElementalSmith","ItemBlessReinforcement","ItemSmeltEntity","ItemSpiritSmeltEntity","AlchemyItem","ItemForItemSet","ItemInvokeReplacementEntityView"]: source_counts[name] = C.rows(pack,name).size()
	source_counts["ItemInvokeReplacementBonus"] = C.rows(pack,"ItemInvokeReplacementBonus").size()
	source_counts["processing_item_rows"] = pack.items.size()
	source_counts["unique_requested_variants"] = variants.size()
	# Independent whole-cache cardinalities for this pinned source. These keep
	# an accidentally empty selector join from looking like complete coverage.
	for expected: Array in [["elemental_smith.target",2090],["bless_reinforcement.target",398],["smelt.target",130],["sets.member",438],["invoke_replacement.target",96],["alchemy.result",273]]:
		_check(groups.get(str(expected[0]),{}).get("variants",{}).size() == int(expected[1]),"whole-source variant cardinality: "+str(expected[0]))

func _classify(spec: Dictionary) -> Dictionary:
	var id: int = int(spec.source_id)
	var bless: int = int(spec.bless)
	var raw: Dictionary = C.item(pack,id).get("raw",{})
	if raw.is_empty(): return {"status":"missing_processing_item"}
	if bool(raw.get("TestItem",false)): return {"status":"source_test_item"}
	if bless == -1: return {"status":"missing_declared_source_variant"}
	if bless not in [1,2]: return {"status":"unsupported_processing_bless","raw_bless":bless}
	var definition: Dictionary = owner.definition_id(str(id))
	if definition.is_empty(): return {"status":"missing_native_definition"}
	var original: Dictionary = definition.get("original_item",{})
	for key: Variant in raw:
		if not original.has(key) or not Native.same(original[key],raw[key]): return {"status":"itemclass_raw_mismatch","field":str(key)}
	var base: Dictionary = definition.get("native_record",{})
	if base.is_empty(): return {"status":"unsupported_native_record"}
	var record: Dictionary = owner.variant_item(base,bless)
	var expected: Dictionary = owner.expected_variant(base,record)
	if expected.is_empty() or not owner.matches(record,expected): return {"status":"ambiguous_or_rejected_expected_variant"}
	if owner.item_definition(record).is_empty(): return {"status":"rejected_public_item_definition"}
	var resolved: Dictionary = Native.resolve(pack,record)
	if int(resolved.get("source_id",0)) != id or int(resolved.get("bless_code",0)) != bless: return {"status":"rejected_native_adapter"}
	return {"status":"validated_exact_variant"}

func _validate_all() -> void:
	var ordered: Array = variants.keys()
	ordered.sort_custom(func(a: String,b: String) -> bool:
		var left: int = int(variants[a].source_id)
		var right: int = int(variants[b].source_id)
		return left < right if left != right else int(variants[a].bless) < int(variants[b].bless))
	var started: int = Time.get_ticks_usec()
	var index: int = 0
	for key: String in ordered:
		var result: Dictionary = _classify(variants[key])
		variants[key]["result"] = result
		var status: String = str(result.status)
		status_counts[status] = int(status_counts.get(status,0))+1
		if status not in ["validated_exact_variant","source_test_item","unsupported_processing_bless","missing_declared_source_variant"]:
			identity_issues.append({"variant":key,"result":result})
		index += 1
		if index % 500 == 0: print("EQUIPMENT523_NATIVE_COVERAGE_PROGRESS ",JSON.stringify({"checked":index,"total":ordered.size(),"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0}))
	timings["relevant_variant_join_ms"] = (Time.get_ticks_usec()-started)/1000.0
	for name: String in groups:
		var report: Dictionary = {"source_rows":int(groups[name].source_rows),"unique_variants":groups[name].variants.size(),"basis":groups[name].basis,"statuses":{}}
		var unique_items: Dictionary = {}
		for key: String in groups[name].variants:
			unique_items[int(variants[key].source_id)] = true
			var status: String = str(variants[key].result.status)
			report.statuses[status] = int(report.statuses.get(status,0))+1
		report["unique_source_ids"] = unique_items.size()
		group_reports[name] = report
	_check(identity_issues.is_empty(),"all non-test supported relevant variants pass the actual public owner and adapter joins")

func _measure_output_catalog(store: RefCounted) -> void:
	var host := CatalogHost.new()
	var started: int = Time.get_ticks_usec()
	var registered: Dictionary = owner.register_catalog(document,host.catalog_db)
	timings["public_full_catalog_registration_ms"] = (Time.get_ticks_usec()-started)/1000.0
	source_counts["registered_catalog_records"] = host.catalog_db["아이템"].size()
	source_counts["registration_report"] = registered
	var service = Service.new()
	service.store = store
	print("EQUIPMENT523_NATIVE_COVERAGE_OUTPUT_INDEX_BEGIN ",JSON.stringify({"catalog_records":host.catalog_db["아이템"].size()}))
	started = Time.get_ticks_usec()
	var output_index: Dictionary = service._output_catalog(host)
	timings["service_full_catalog_output_index_ms"] = (Time.get_ticks_usec()-started)/1000.0
	source_counts["output_index_keys"] = output_index.size()-1
	var ambiguous: int = 0
	for key: Variant in output_index:
		if key != "_built" and output_index[key] is Dictionary and output_index[key].is_empty(): ambiguous += 1
	source_counts["ambiguous_output_index_keys"] = ambiguous
	_check(host.inventory.is_empty() and host.item_instances.is_empty(),"whole-catalog identity registration and output indexing grant no inventory or physical ownership")
	host.free()

func _finish() -> void:
	print("EQUIPMENT523_NATIVE_COVERAGE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"blockers":blockers,"rules_sha256":RULE_SHA,"native_sha256":NATIVE_SHA,"source_counts":source_counts,"variant_statuses":status_counts,"groups":group_reports,"join_issues":join_issues,"identity_issues":identity_issues,"timings_ms":timings,"scope":"ALL_RELEVANT_SOURCE_IDENTITY_VARIANTS_AND_FULL_CATALOG_OUTPUT_INDEX; NO_GRANTS_ACQUISITION_EFFECT_ACTIVATION_OR_PIXEL_CLAIM; SOURCE_BLESS_ZERO_SEPARATE_FROM_LOCAL_WILDCARD"}))
	quit(0 if failures.is_empty() and blockers.is_empty() else 1)
