extends SceneTree
## Fast contract fixtures only: no Main, archive load, loot drop or original render.
## The adapter must supply names proved by current source rows; the core keeps
## physical full names and receipt originals while using that trusted binding.
const Core = preload("res://scripts/collections/equipment_collection_service.gd")
const Runtime = preload("res://scripts/collections/equipment_collection_runtime.gd")
const Source = preload("res://scripts/resources/current523_definition_rows.gd")
const ITEM_ID: int = 914
const CID: String = "fixture_native_cloak"
const SLOT: String = "cloak"
const LABEL: String = "마법 망토"
const FULL_NAME: String = LABEL + " · 원본#914"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("EQUIPMENT_COLLECTION_NATIVE_IDENTITY_FAIL: " + message)

func _identity() -> Dictionary:
	return {"kind":"twilight.current523.original-definitions.v1", "source_snapshot":"patch523",
		"source_sha256":Source.SOURCE_SHA, "source_bytes":Source.SOURCE_BYTES}

func _raw() -> Dictionary:
	# A small declared fixture, not a claim that this row was read from the ZIP.
	return {"ID":ITEM_ID, "Name":"[방어구-망토] 마법 망토", "DescID":5678,
		"IdentifiedDescID":5699, "TestItem":false}

func _record() -> Dictionary:
	return {"name":FULL_NAME, "source_display_name":LABEL, "source":"lineagem_patch523",
		"source_snapshot":"patch523", "source_item_class_id":ITEM_ID,
		"sourceId":"m523:item:914", "source_m_native_item":true,
		"source_definition_archive":_identity(),
		"source_projection":"current523_original_typed_game_dto_v1", "source_original_item":_raw()}

func _definitions(name_value: String = LABEL) -> Dictionary:
	return {"collections":[{"id":CID, "name":"Fixture cloak +5", "data_ready":true,
		"review_reasons":[], "requirements":[{"slot_id":SLOT,"name":name_value,"enchant":5,"quantity":1}],
		"effects":[{"key":"max_mp","unit":"flat","value":10,"raw":"MP +10"}]}]}

func _catalog(name_value: String = FULL_NAME, canonical: String = LABEL) -> Dictionary:
	var row: Dictionary = {"source_id":"m523:item:914","name":name_value,"kind":"equipment"}
	if not canonical.is_empty():
		row["collection_name"] = canonical
	return row

func _core(row: Dictionary = {}):
	var out = Core.new()
	check(out.configure(_definitions(), [_catalog() if row.is_empty() else row], ["max_mp:flat"]), "fixture service configured")
	return out

func _gear(name_value: String = FULL_NAME) -> Dictionary:
	return {"instance_id":"native-cloak-instance", "source_id":"m523:item:914", "name":name_value,
		"enchant":5, "quantity":1, "equipped":false, "locked":false}

func _snapshot(item: Dictionary = {}) -> Dictionary:
	var state: Dictionary = Core.fresh_state()
	var physical: Dictionary = _gear() if item.is_empty() else item
	state.gear[str(physical.instance_id)] = physical
	return state

func _request() -> Dictionary:
	return {"collection_id":CID,"slot_id":SLOT,"instance_ids":["native-cloak-instance"],
		"expected_revision":0,"request_id":"native-identity-fixture-request","timestamp":"fixture-time"}

func _run() -> void:
	var record: Dictionary = _record()
	var identity: Dictionary = _identity()
	var raw: Dictionary = _raw()
	check(Runtime.verified_native_collection_name(record, identity, raw, LABEL) == LABEL,
		"pinned native DTO and exact raw/display identity yield guide name")
	for entry: Array in [
		["source_m_native_item",false], ["source_m_native_item",1],
		["source","other"], ["source_snapshot","patch520"],
		["source_projection","other"], ["source_item_class_id",915],
		["source_item_class_id","914"], ["source_item_class_id",true],
		["source_item_class_id",914.5], ["source_item_class_id",0],
		["sourceId","m523:item:915"], ["sourceId","legacy:914"],
		["name",LABEL + " · 원본#0914"], ["name",LABEL + " · 원본#915"],
		["name",LABEL], ["name","다른 장비 · 원본#914"],
		["source_display_name","다른 장비"], ["source_original_item",{}],
		["source_definition_archive",{}]
	]:
		var altered: Dictionary = record.duplicate(true)
		altered[str(entry[0])] = entry[1]
		check(Runtime.verified_native_collection_name(altered, identity, raw, LABEL).is_empty(),
			"reject forged native proof " + str(entry[0]) + "=" + str(entry[1]))
	var duplicate_gate = Runtime.new()
	check(duplicate_gate._native_collection_name(record, {LABEL:true}, {"m523:item:914":2}).is_empty(), "duplicate native source ID cannot receive canonical alias")
	check(not duplicate_gate._native_identity_loaded, "duplicate source ID is rejected before opening original archive")
	var unrelated_gate = Runtime.new()
	check(unrelated_gate._native_collection_name(record, {"다른 장비":true}, {"m523:item:914":1}).is_empty(), "non-guide candidate cannot receive canonical alias")
	check(not unrelated_gate._native_identity_loaded, "non-guide candidate avoids archive/full-field load")
	var numeric_id: Dictionary = record.duplicate(true)
	numeric_id.source_item_class_id = 914.0
	check(Runtime.verified_native_collection_name(numeric_id, identity, raw, LABEL) == LABEL, "whole JSON numeric DTO ID is accepted")
	var unknown_identity: Dictionary = identity.duplicate(true)
	unknown_identity.source_sha256 = "forged"
	var unknown_record: Dictionary = record.duplicate(true)
	unknown_record.source_definition_archive = unknown_identity
	check(Runtime.verified_native_collection_name(unknown_record, unknown_identity, raw, LABEL).is_empty(), "caller supplied self-consistent archive still must be pinned current identity")
	var changed_archive: Dictionary = record.duplicate(true)
	changed_archive.source_definition_archive.source_sha256 = "forged"
	check(Runtime.verified_native_collection_name(changed_archive, identity, raw, LABEL).is_empty(), "reject different archive SHA")
	check(Runtime.verified_native_collection_name(record, {}, raw, LABEL).is_empty(), "missing current verified identity fails closed")
	for field: String in ["ID", "Name", "IdentifiedDescID"]:
		var altered_raw: Dictionary = raw.duplicate(true)
		altered_raw[field] = 915 if field == "ID" else "forged" if field == "Name" else 5700
		check(Runtime.verified_native_collection_name(record, identity, altered_raw, LABEL).is_empty(), "reject mismatched actual raw row " + field)
	var test_raw: Dictionary = raw.duplicate(true)
	test_raw.TestItem = true
	var test_record: Dictionary = record.duplicate(true)
	test_record.source_original_item = test_raw
	check(Runtime.verified_native_collection_name(test_record, identity, test_raw, LABEL).is_empty(), "source TestItem cannot be guide equipment")
	check(Runtime.verified_native_collection_name(record, identity, raw, "다른 장비").is_empty(), "actual source descriptor must match DTO display")
	check(Runtime.verified_native_collection_name(record, identity, raw, "").is_empty(), "missing descriptor fails closed")
	var engraved: Dictionary = record.duplicate(true)
	engraved.source_display_name = LABEL + " (각인)"
	engraved.name = str(engraved.source_display_name) + " · 원본#914"
	check(Runtime.verified_native_collection_name(engraved, identity, raw, LABEL + " (각인)") == LABEL, "existing engraving normalization retained after exact DTO proof")
	for variant: String in ["축복받은 " + LABEL, LABEL + " (이벤트)"]:
		var variant_record: Dictionary = record.duplicate(true)
		variant_record.source_display_name = variant
		variant_record.name = variant + " · 원본#914"
		check(Runtime.verified_native_collection_name(variant_record, identity, raw, variant) == variant,
			"existing blessing/event words retained: " + variant)
	for invalid_alias: Variant in ["", "마법 망토 (각인)", 914]:
		var invalid_row: Dictionary = _catalog()
		invalid_row.collection_name = invalid_alias
		var invalid_core = Core.new()
		check(not invalid_core.configure(_definitions(),[invalid_row],["max_mp:flat"]), "malformed trusted catalog canonical is rejected: " + str(invalid_alias))
	var core = _core()
	var req: Dictionary = _definitions().collections[0].requirements[0]
	check(core.availability(CID).get("ok",false), "verified catalog canonical unlocks existing guide requirement")
	check(core.candidate_reason(_gear(), req).is_empty(), "full native physical name matches verified canonical guide binding")
	var suffix_only = _core(_catalog(FULL_NAME, ""))
	check(not suffix_only.availability(CID).get("ok",false), "full suffix alone does not add an unverified guide binding")
	var forged_physical: Dictionary = _gear()
	forged_physical.collection_name = LABEL
	check(not suffix_only.candidate_reason(forged_physical,req).is_empty(), "physical collection_name cannot create trusted catalog alias")
	for field: String in ["name", "source_id", "enchant", "locked", "equipped"]:
		var bad: Dictionary = _gear()
		bad[field] = LABEL if field == "name" else "m523:item:915" if field == "source_id" else 6 if field == "enchant" else true
		check(not core.candidate_reason(bad,req).is_empty(), "physical identity/exact enchant/lock/equip check retained: " + field)
	var snapshot: Dictionary = _snapshot()
	var original_snapshot: Dictionary = snapshot.duplicate(true)
	var result: Dictionary = core.prepare_registration(snapshot, _request())
	check(result.get("ok",false), "trusted native full-name instance can register")
	check(snapshot == original_snapshot, "prepare does not alter original snapshot")
	if result.get("ok",false):
		var finished: Dictionary = result.state
		var receipt: Dictionary = finished.receipts["native-cloak-instance"]
		check(receipt.original_name == FULL_NAME and receipt.canonical_name == LABEL, "receipt preserves original full DTO name and guide canonical separately")
		check(finished.gear.is_empty() and finished.revision == 1, "single owned instance consumed exactly once in proposed state")
		check(core.complete(finished,CID), "completion recomputes trusted native source canonical")
		check(core.bonuses(finished) == {"max_mp:flat":10.0}, "completion reward recomputes exactly once")
		check(core.prepare_registration(finished,_request()).get("already_applied",false), "same registration request remains idempotent")
		check(not suffix_only.complete(finished,CID), "receipt cannot retain bonus when verified catalog binding is absent")
		var redirected = _core(_catalog(FULL_NAME,"다른 장비"))
		check(not redirected.complete(finished,CID), "receipt cannot retain bonus when source canonical no longer matches guide")
		var wrong_source: Dictionary = finished.duplicate(true)
		wrong_source.receipts["native-cloak-instance"].source_id = "m523:item:915"
		check(not core.complete(wrong_source,CID), "receipt source ID is recomputed rather than trusting saved canonical")
		var wrong_enchant: Dictionary = finished.duplicate(true)
		wrong_enchant.receipts["native-cloak-instance"].enchant = 6
		check(not core.complete(wrong_enchant,CID), "receipt exact enchant is recomputed")
	var legacy = _core(_catalog(LABEL,""))
	var legacy_result: Dictionary = legacy.prepare_registration(_snapshot(_gear(LABEL)),_request())
	check(legacy_result.get("ok",false), "legacy catalog without optional canonical keeps existing registration")
	if legacy_result.get("ok",false):
		check(legacy.complete(legacy_result.state,CID) and legacy_result.state.receipts["native-cloak-instance"].original_name == LABEL,
			"legacy receipt completion and original name remain compatible")
	print("EQUIPMENT_COLLECTION_NATIVE_IDENTITY_RESULT " + JSON.stringify({"scope":"pure_identity_and_core_fixtures_not_original_render", "checks":checks,"failures":failures}))
	if failures.is_empty():
		print("EQUIPMENT_COLLECTION_NATIVE_IDENTITY_OK")
	quit(0 if failures.is_empty() else 1)
