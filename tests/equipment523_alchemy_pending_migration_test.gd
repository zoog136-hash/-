extends SceneTree
## Original-free fixtures. This verifies a candidate reducer, not acquisition.
const Subject = preload("res://scripts/equipment523/alchemy_pending_migration.gd")
const C = preload("res://scripts/equipment523/common.gd")
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const RULES: String = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
const ID: String = "same-physical-id"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)

func fixture() -> Dictionary:
	var raw: Dictionary = {"ID":10,"Name":"SyntheticSword","TestItem":false,"GradeID":1}
	var pack: Dictionary = {"source_sha256":C.SOURCE_SHA,"items":{"10":{"name":"Synthetic sword","raw":raw.duplicate(true)}},"tables":{
		"AlchemyResult":[{"ID":20,"RecipeTypeID":63,"ItemClassID":10,"Amount":1,"Enchant":0,"BlessCode":1,"ServerLimitSetID":0,"Probability":1}],
		"AlchemyRecipeType":[{"ID":63,"IsEnabled":true},{"ID":113,"IsEnabled":true},{"ID":74,"IsEnabled":false}]}}
	var native: Dictionary = {"name":"Synthetic sword · native#10","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:10","source_item_class_id":10,"source_m_native_item":true,"source_bless_raw":1,"source_display_name":"Synthetic sword","slot":"weapon","type":"Synthetic","grade":"Synthetic"}
	var authority: Dictionary = {"record":native.duplicate(true),"expected":native.duplicate(true),"definition":{"original_item":raw.duplicate(true),"native_record":native.duplicate(true)},"identity":{"schema":3,"source_snapshot":"patch523","sha256":"b".repeat(64)},"equipment":true,"registered":true}
	var old: Dictionary = {"name":"[원본보상]Synthetic sword","source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:10","source_item_class_id":10,"source_original_item":true,"source_bless_code_id":1,"source_reward_quantity":1,"source_reward_id":20,"desc":Subject.LEGACY_DESCRIPTION,"bless_state":"normal","blessed":false}
	var physical: Dictionary = {"name":old.name,"record":old,"source_reward_quantity":1,"source_bless_code":1,"bless_state":"normal","level":0,"element":"","element_level":0}
	return {"pack":pack,"before":{"inventory":{old.name:1,"unrelated":3},"item_instances":{ID:physical,"other":{"name":"unrelated","untouched":{"note":"keep"}}},"references":{}},"authorities":{ID:authority}}

func stage(f: Dictionary) -> Dictionary:
	return Subject.stage_snapshot(f.pack,f.before,f.authorities,RULES)

func held(f: Dictionary, message: String) -> void:
	var before: Dictionary = f.before.duplicate(true)
	var result: Dictionary = stage(f)
	check(result.ok and not result.changed and result.overrides.is_empty() and result.held.size() == 1,message)
	check(Native.same(before,f.before),message+" leaves input untouched")

func test_batches() -> void:
	var f: Dictionary = fixture()
	var second: String = "second-physical-id"
	var old_name: String = str(f.before.item_instances[ID].name)
	var native_name: String = str(f.authorities[ID].record.name)
	f.before.item_instances[second] = f.before.item_instances[ID].duplicate(true)
	f.authorities[second] = f.authorities[ID].duplicate(true)
	f.before.inventory[old_name] = 2
	var before: Dictionary = f.before.duplicate(true)
	var result: Dictionary = stage(f)
	check(result.changed and result.migrated_ids.size() == 2 and result.migrated_ids.has(ID) and result.migrated_ids.has(second),"two eligible same-name units each migrate exactly once")
	check(not result.overrides.inventory.has(old_name) and result.overrides.inventory[native_name] == 2 and result.overrides.inventory.unrelated == 3,"same-name batch moves two owned units without replacing the earlier candidate debit")
	check(result.overrides.item_instances.keys() == before.item_instances.keys() and Native.same(before,f.before),"same-name batch preserves all physical IDs and caller state")
	for id: String in [ID,second]:
		var rebound: Dictionary = result.overrides.item_instances[id]
		check(rebound.name == native_name and rebound.source_reward_quantity == 1 and rebound.level == 0 and rebound.source_bless_code == 1 and Native.same(rebound.equipment523_alchemy_catalog_migration.original_record,before.item_instances[id].record),"same-name batch retains each exact original record and physical state: "+id)
	f = fixture()
	f.before.item_instances[second] = f.before.item_instances[ID].duplicate(true)
	f.before.item_instances[second]["unknown_state"] = {"note":"hold this exact instance"}
	f.authorities[second] = f.authorities[ID].duplicate(true)
	f.before.inventory[old_name] = 2
	f.before.inventory[native_name] = 3
	for index: int in range(3):
		f.before.item_instances["existing-native-"+str(index)] = {"name":native_name,"record":f.authorities[ID].record.duplicate(true),"source_reward_quantity":1,"level":0,"source_bless_code":1,"bless_state":"normal"}
	before = f.before.duplicate(true)
	result = stage(f)
	check(result.changed and result.migrated_ids == [ID] and result.held.size() == 1 and result.held[0].physical_id == second,"eligible and held same-name units retain independent outcomes")
	check(result.overrides.inventory[old_name] == 1 and result.overrides.inventory[native_name] == 4 and result.overrides.inventory.unrelated == 3,"partial batch preserves old remainder and adds one unit to three existing native units")
	check(result.overrides.item_instances.keys() == before.item_instances.keys() and Native.same(before,f.before),"partial batch creates no IDs and leaves source state untouched")
	check(Native.same(result.overrides.item_instances[second],before.item_instances[second]),"held instance keeps its complete original metadata and quantity")
	for index: int in range(3):
		var id: String = "existing-native-"+str(index)
		check(Native.same(result.overrides.item_instances[id],before.item_instances[id]),"existing native instance remains unchanged: "+id)
	check(Native.same(result.overrides.item_instances[ID].equipment523_alchemy_catalog_migration.original_record,before.item_instances[ID].record),"partial migration retains the eligible instance's original record")

func _initialize() -> void:
	test_batches()
	var f: Dictionary = fixture()
	var before: Dictionary = f.before.duplicate(true)
	var result: Dictionary = stage(f)
	check(result.ok and result.changed and result.migrated_ids == [ID],"exact legacy output contract rebinds its existing physical ID")
	check(result.migration_basis[ID] == "legacy_exact_result_contract","absence of a later proof is labeled as the exact historical schema")
	check(Native.same(before,f.before),"staging never changes live/caller state")
	check(result.overrides.item_instances.keys() == before.item_instances.keys(),"no physical instance is created, erased, or renumbered")
	check(result.overrides.inventory == {f.authorities[ID].record.name:1,"unrelated":3},"only the owned unit moves between inventory keys")
	var rebound: Dictionary = result.overrides.item_instances[ID]
	check(rebound.source_reward_quantity == 1 and rebound.level == 0 and rebound.source_bless_code == 1 and rebound.element == "","physical quantity, enhancement, blessing and element stay unchanged")
	check(Native.same(rebound.equipment523_alchemy_catalog_migration.original_record,before.item_instances[ID].record),"original record is retained without minting a supplier receipt")
	check(not rebound.has("source_m_reward_proof") and not rebound.has("quest_reward_receipt"),"rebind fabricates neither a grant nor a quest receipt")
	var again: Dictionary = f.before.duplicate(true)
	again.inventory = result.overrides.inventory
	again.item_instances = result.overrides.item_instances
	check(not Subject.stage_snapshot(f.pack,again,f.authorities,RULES).changed,"already native equipment is idempotent")
	f = fixture()
	f.before.item_instances[ID].equipment523_last_processing = {"kind":"alchemy","source_sha256":C.SOURCE_SHA,"consumer_data_sha256":RULES,"result_id":20}
	result = stage(f)
	check(result.changed and result.migration_basis[ID] == "verified_processing_proof" and Native.same(result.overrides.item_instances[ID].equipment523_last_processing,f.before.item_instances[ID].equipment523_last_processing),"a verified later proof is checked and retained")
	for field: String in ["kind","source_sha256","consumer_data_sha256","result_id"]:
		var changed: Dictionary = f.duplicate(true)
		changed.before.item_instances[ID].equipment523_last_processing[field] = 99 if field == "result_id" else "wrong"
		held(changed,"changed retained proof "+field+" is preserved")
	for field: String in ["level","element_level","source_reward_quantity","source_bless_code"]:
		var changed: Dictionary = fixture()
		changed.before.item_instances[ID][field] = 2
		held(changed,"changed physical "+field+" is preserved")
	for field: String in ["Amount","Enchant","BlessCode","ServerLimitSetID","RecipeTypeID"]:
		var changed: Dictionary = fixture()
		changed.pack.tables.AlchemyResult[0][field] = 74 if field == "RecipeTypeID" else 2
		held(changed,"unsupported original result "+field+" is preserved")
	for value: Variant in [null,true,"20",20.5]:
		var changed: Dictionary = fixture()
		changed.before.item_instances[ID].record.source_reward_id = value
		held(changed,"result ID is an exact numeric source ID: "+str(value))
	for reference: Dictionary in [{"equipped_items":{"weapon":{"instance_id":ID}}},{"warehouse":{"inventory":{"[원본보상]Synthetic sword":1}}},{"quickslots":["[원본보상]Synthetic sword"]},{"ui_preferences":{"item_locks":{"[원본보상]Synthetic sword@@@same-physical-id":true}}}]:
		var changed: Dictionary = fixture()
		changed.before.references = reference
		held(changed,"external reference is preserved: "+str(reference.keys()[0]))
	f = fixture()
	f.before.item_instances[ID].quest_reward_receipt = {"schema":1}
	held(f,"quest ownership is never adopted")
	f = fixture()
	f.before.item_instances[ID].record.unknown_option = 999
	held(f,"unknown legacy record fields cannot become canonical effects")
	f = fixture()
	f.before.item_instances[ID].unknown_state = {"note":"keep"}
	held(f,"unknown physical state is held intact")
	f = fixture()
	f.before.inventory[f.before.item_instances[ID].name] = 2
	held(f,"inventory-only surplus cannot fabricate equipment")
	f = fixture()
	f.before.inventory[f.authorities[ID].record.name] = 1
	held(f,"ambiguous destination gear ownership is preserved")
	f = fixture()
	f.authorities.clear()
	result = stage(f)
	check(not result.changed and result.retry_when_catalog_available and result.held[0].reason == "native_catalog_unavailable","missing private native definitions request a later availability event without changing ownership")
	f = fixture()
	f.authorities[ID].registered = false
	check(stage(f).retry_when_catalog_available,"unregistered actual catalog remains deferred")
	f = fixture()
	f.authorities[ID].equipment = false
	f.authorities[ID].record.slot = "consumable"
	f.authorities[ID].expected.slot = "consumable"
	held(f,"non-equipment awaits its physical remainder consumer contract")
	f = fixture()
	f.authorities[ID].definition.original_item.GradeID = 2
	held(f,"native sidecar must match retained original item fields")
	f = fixture()
	f.pack.tables.AlchemyResult[0].RecipeTypeID = 113
	check(stage(f).changed,"enabled Law result retains the same exact contract")
	print("EQUIPMENT523_ALCHEMY_PENDING_MIGRATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_PURE_EXISTING_OWNERSHIP_CANDIDATE_ONLY"}))
	quit(0 if failures.is_empty() else 1)
