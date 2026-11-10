extends SceneTree
## Standalone, synthetic (no original installed): the two card statics that
## held whole derived models resident (current523_option_combat_input.gd
## `_data`, patch523_slot_data.gd `relic` / `relic_combat`) keep only a small
## head resident and read their per-key parts from a device record bake
## (current523_keyed_records.gd) through a bounded LRU.
##
## Checked on synthetic models: every accessor returns exactly (var bytes) what
## the former resident dictionaries held, in resident mode, after the record
## write and after a reopen (next start); key order; missing keys; the
## consumers that read them (doll subslot rows, doll/relic unlock items,
## option economy); the LRU bound; the build-only diagnostics stay
## retrievable; the head is smaller than the model; the former whole bake is
## removed; and every storage failure stage under both policies
## (disk-required: explicit failure, nothing activated, cause reported;
## otherwise the former resident model).

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const RECORDS = preload("res://scripts/resources/current523_keyed_records.gd")
const SLOTS = preload("res://scripts/cards/patch523_slot_data.gd")
const INPUT = preload("res://scripts/cards/current523_option_combat_input.gd")
const DOLL_SUBSLOT = preload("res://scripts/cards/native_doll_subslot.gd")
const DOLL_UNLOCK = preload("res://scripts/cards/native_doll_unlock_item.gd")
const RELIC_UNLOCK = preload("res://scripts/cards/native_relic_unlock_item.gd")
const ECONOMY = preload("res://scripts/cards/native_option_economy.gd")

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok and failures.size() < 40: failures.append(description)

func same(description: String, left: Variant, right: Variant) -> bool:
	var ok: bool = typeof(left) == typeof(right) and var_to_bytes(left) == var_to_bytes(right)
	check(ok, description)
	return ok

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	OS.set_environment(BAKE.DISK_REQUIRED_ENV, "0")
	_clear_all()
	test_keyed_records()
	test_slot_data()
	test_option_input()
	_clear_all()
	BAKE.fault = ""
	OS.unset_environment(BAKE.DISK_REQUIRED_ENV)
	SLOTS.adopt_for_test({}, "")
	INPUT.reset_for_test()
	print("CARDS_STATIC_RECORDS_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _clear_all() -> void:
	for name: String in ["cards_static_synthetic", SLOTS.RECORDS_NAME, SLOTS.BAKE_NAME, INPUT.RECORDS_NAME]:
		BAKE.clear(name)
		DirAccess.remove_absolute(BAKE.data_path(name) + ".part")
	BAKE.store_failures.clear()

func _no_part(name: String) -> bool:
	return not FileAccess.file_exists(BAKE.data_path(name) + ".part")

# --- Synthetic rows shaped like the original definition rows -----------------

func effect(link_id: int, type_name: String, unit_name: String, value: float, target: int = 0, application: int = 0, denominator: int = 0) -> Dictionary:
	var unit_id: float = 3.0 if unit_name == "Percentage" else 1.0
	return {"link": {"ID": float(link_id), "BonusID": float(link_id + 1000), "Level": 1.0, "IsPossession": false, "CharacterLevel": 0.0, "CharacterClass": 0.0, "MinSpellLevel": 0.0},
		"bonus": {"ID": float(link_id + 1000), "BonusTypeID": 7.0, "Value": value, "BonusApplicationTypeID": float(application), "BonusApplicationTargetID": float(target)},
		"type": {"ID": 7.0, "Name": type_name, "UnitID": unit_id},
		"unit": {"ID": unit_id, "Name": unit_name},
		"ui_unit": {"ID": 1.0, "UnitID": unit_id, "Denominator": float(denominator)} if denominator > 0 else {}}

func card_row(id: int, deck: int, grade: int) -> Dictionary:
	return {"ID": float(id), "BuffCardDeckID": float(deck), "GradeID": float(grade), "Name": "카드" + str(id), "ServerLimitSetID": 0.0, "StartDateTimeID": 0.0, "EndDateTimeID": 0.0, "BuffClassID": float(id + 50000), "DisplaySpriteID": float(id + 9)}

func unlock_item(item_id: int, buff_id: int, bonus_id: int, opened: String) -> Dictionary:
	var link: Dictionary = effect(bonus_id - 1000, "BuffClassID", "BuffClassID", float(buff_id))
	link.bonus.ID = float(bonus_id)
	link.type.UnitID = 16.0
	return {"item": {"ID": float(item_id), "GradeID": 3.0, "MaxStackAmount": 1.0, "IsDroppable": true, "IsStorable": false, "TestItem": false, "Name": "해금"},
		"category": {"ID": 4.0, "IsConsumable": true}, "grade": {"ID": 3.0, "Name": "희귀"}, "name": "해금 아이템",
		"buff": {"ID": float(buff_id)}, "effects": [link, effect(903, "BuffDurationInfinite", "Value", 1.0)],
		"buff_effects": [effect(901, opened, "Value", 1.0), effect(902, "SaveDB", "Value", 1.0)]}

func relic_candidate() -> Dictionary:
	var cards: Dictionary = {}
	var groups: Dictionary = {}
	var subslot: Dictionary = {}
	for index: int in 30:
		var id: int = 20500 + index * 3
		var key: String = "98:" + str(id)
		var card: Dictionary = card_row(id, 98, 1 + index % 4)
		if index % 7 == 3:
			cards[key] = {"card": card, "source_buff": {"ID": float(id + 50000)}, "source_primary_effects": [effect(id, "HPPlus", "Value", 5.0)], "effects": [], "summon_binding": {"npc_class_id": 0, "sprite_id": 0}, "source_problem": "missing_typed_SubSlotBuffClassID"}
			continue
		var effects: Array = [effect(id * 10, "MeleeHit", "Value", 1.0), effect(id * 10 + 1, "HPPlusPercent", "Percentage", 10000.0, 0, 0, 10000)]
		cards[key] = {"card": card, "source_buff": {"ID": float(id + 50000)}, "source_primary_effects": [effect(id, "SubSlotBuffClassID", "BuffClassID", float(id + 60000))],
			"subslot_link": effect(id, "SubSlotBuffClassID", "BuffClassID", float(id + 60000)), "subslot_buff": {"ID": float(id + 60000)}, "effects": effects,
			"summon_binding": {"npc_class_id": 83000 + index, "sprite_id": 7000 + index, "display_sprite_verified": false}}
		subslot[key] = {"card": card, "effects": effects}
		if index % 2 == 0:
			groups[key + ":11"] = {"identity": "source:m523:" + key, "card": card, "group": {"ID": float(id + 70000), "ServerLimitsetID": 0.0 if index % 4 == 0 else 772.0},
				"effects": [effect(id * 10 + 5, "StatusEffectID", "Value", float(id + 1))], "secondary_groups": [], "source_server_limits": [], "reference_only": true}
	var limits: Array = []
	for index: int in 12:
		# Interleaved sets, as table order puts them.
		limits.append({"ID": float(index + 1), "ServerLimitSetID": [772.0, 274.0, 5.0][index % 3], "ServiceRegionCode": ["KR", "TW"][index % 2], "WorldNo": float(1 + index)})
	limits.append({"ID": 99.0, "ServerLimitSetID": 0.0, "ServiceRegionCode": "KR", "WorldNo": 0.0})
	return {"schema": "twilight.card-slots523.v1", "source_snapshot": "patch523",
		"new_cards": {"catalog": {}, "option_definitions": [], "skill_cards": {}, "source_server_limits": [], "primary_doll_buffs": {}, "subslot_buffs": {}, "subslot_npc_bindings": {}},
		"options": {"groups": {}, "reviewed_primary_keys": [], "changed_primary_keys": [], "bonuses": {}, "types": {}, "units": {}, "ui_units": {}, "type_labels": {}},
		"relic": {"cards": cards, "option_groups": groups, "source_server_limits": limits, "unlock_item": unlock_item(365748, 95648, 2357388, "HolyStuffSubSlotOpened")},
		"relic_combat": {"relic_subslot_buffs": subslot, "invoke_options": [{"ID": 16572.0, "InvokeOptionTypeID": 1.0, "Param1": 77.0}], "invoke_spells": {"77": {"source_spell": {"ID": 77.0, "CastDelay": 1000.0}, "effects": []}}},
		"card_acquisition": {"guaranteed_nemesis": {"view": {"raw": {"ItemCraftID": 1.0}}}}, "relic_acquisition": {"box": {"item": {"raw": {"ID": 2.0}}, "contents": []}},
		"source_acquisition_input_status": {}, "unavailable_source_definitions": [{"card": card_row(1, 98, 1), "problem": "x"}], "source_exclusion_evidence": [],
		"input_identity": {"input_kind": "current523_original_memory", "payload_sha256": "00"}}

func identity() -> Dictionary:
	return {"kind": "twilight.current523.original-definitions.v1", "source_snapshot": "patch523", "source_sha256": "synthetic", "source_bytes": 1}

func option_session() -> Dictionary:
	var source_identity: Dictionary = identity()
	var primary: Dictionary = {}
	var subslot: Dictionary = {}
	var bindings: Dictionary = {}
	for index: int in 40:
		var id: int = 25000 + index
		var key: String = "source:m523:2:" + str(id)
		var card: Dictionary = card_row(id, 2, 1 + index % 5)
		primary[key] = {"card": card, "source_buff": {"ID": float(id + 50000), "Name": "buff"}, "effects": [effect(id, "InvokeOption", "Percentage", 80000.0, 3323, 10), effect(id + 1, "HPPlus", "Value", 3.0)], "source_input_identity": source_identity}
		if index % 3 == 0:
			subslot[key] = {"card": card, "link": effect(id, "SubSlotBuffClassID", "BuffClassID", 1.0), "source_buff": {"ID": float(id + 60000)}, "effects": [effect(id + 2, "Strength", "Value", 2.0), effect(id + 3, "BuffCardSummonNPCClassID", "NPCClassID", float(id + 100), 11, 461)], "source_input_identity": source_identity}
			bindings[key] = {"npc_class_id": id + 100, "sprite_id": id + 200, "display_sprite_verified": false, "source_npc": {"ID": float(id + 100), "Sprite": float(id + 200)}, "source_input_identity": source_identity}
	var spells: Dictionary = {}
	var buffs: Dictionary = {}
	for index: int in 6:
		spells[str(300 + index)] = {"source_spell": {"ID": float(300 + index), "TestSpell": false, "CastDelay": 1000.0}, "effects": [effect(400 + index, "BuffClassID", "BuffClassID", float(500 + index))], "source_input_identity": source_identity}
		buffs[str(500 + index)] = [effect(600 + index, "MeleeHit", "Value", 1.0)]
	var economy: Dictionary = {}
	for grade: int in [1, 2, 3]:
		economy["2:" + str(grade)] = {"EnchantMaxExp": {"BuffCardDeckID": 2.0, "GradeID": float(grade), "Value": float(grade * 100)}, "AwakenAdenaCost": {"BuffCardDeckID": 2.0, "GradeID": float(grade), "Value": float(grade * 1000)}}
	var unlock: Dictionary = unlock_item(346901, 91531, 2171301, "MagicDollSubSlotOpened")
	unlock.source_input_identity = source_identity
	var groups: Array = []
	for index: int in 50: groups.append({"identity": "source:m523:2:" + str(25000 + index), "card": card_row(25000 + index, 2, 1), "effects": [effect(7000 + index, "HPPlus", "Value", 1.0)]})
	return {"schema": 1, "source_snapshot": "patch523", "ready": true, "source_input_identity": source_identity,
		"primary_doll_buffs": primary, "subslot_buffs": subslot, "subslot_npc_bindings": bindings, "option_groups": groups,
		"invoke_options": [{"ID": 3323.0, "InvokeOptionTypeID": 1.0, "Param1": 300.0}], "invoke_spells": spells, "invoke_buffs": buffs,
		"spell_material_types": [{"ID": 0.0, "Name": "None"}], "economy": economy, "subslot_unlock_item": unlock,
		"invoke_references": [{"row": {"ID": 3323.0}}], "unavailable_source_definitions": [{"table": "BuffCard", "row_id": 1.0, "problem": "x"}],
		"source_exclusion_evidence": [{"table": "BuffCard", "row": {"ID": 2.0}, "evidence": {"excluded_from_connection": true}}], "problem": ""}

# --- current523_keyed_records.gd ---------------------------------------------

func test_keyed_records() -> void:
	var name: String = "cards_static_synthetic"
	var sections: Dictionary = {"a": {}, "b": {"only": [1, 2.5, "x"]}, "empty": {}}
	for index: int in 20: sections.a["k" + str(19 - index)] = {"value": index, "row": {"Name": "행" + str(index), "Value": float(index) / 3.0}, "typed": PackedInt32Array([index])}
	var head: Dictionary = {"problem": "", "count": 20}
	var store: RECORDS.Store = RECORDS.write(name, "key-1", head, sections, 4)
	check(store != null, "records written and reopened")
	if store == null: return
	same("head round trip", store.head, head)
	same("section key order kept", store.section_keys("a"), PackedStringArray(sections.a.keys()))
	check(store.section_keys("empty").is_empty() and store.section_keys("missing").is_empty(), "empty and unknown sections list no keys")
	var all_same: bool = true
	for key: String in sections.a:
		all_same = all_same and var_to_bytes(store.value("a", key)) == var_to_bytes(sections.a[key])
	check(all_same, "every entry reads back byte-identical")
	same("other section entry", store.value("b", "only"), sections.b.only)
	check(store.value("a", "nope", {"fallback": 1}) == {"fallback": 1} and not store.has("a", "nope") and store.has("a", "k3"), "missing key returns the caller's fallback")
	check(store.cached() <= 4, "LRU keeps at most its capacity")
	var reads: int = store.reads
	var first: Variant = store.value("a", "k0")
	var again: Variant = store.value("a", "k0")
	check(store.reads == reads + 1 or store.reads == reads, "a repeated read is served from the LRU")
	check(is_same(first, again), "LRU hit returns the same instance")
	var reopened: RECORDS.Store = RECORDS.open(name, "key-1")
	check(reopened != null and var_to_bytes(reopened.value("a", "k7")) == var_to_bytes(sections.a.k7), "reopen (next start) reads the same values")
	check(RECORDS.open(name, "key-2") == null and RECORDS.open(name, "") == null, "another key or no key is a miss")
	reopened = null
	store = null
	# Every storage failure stage fails the write; nothing half-written stays.
	for stage: String in ["create", "append:3", "commit", "reopen", "index"]:
		BAKE.clear(name)
		BAKE.store_failures.clear()
		BAKE.fault = name + "|" + stage
		var failed: RECORDS.Store = RECORDS.write(name, "key-1", head, sections)
		BAKE.fault = ""
		check(failed == null, "write fails at " + stage)
		check(BAKE.store_failures.has(name), "failure recorded at " + stage)
		check(_no_part(name), "no unfinished part file after " + stage)
	BAKE.clear(name)
	BAKE.store_failures.clear()

# --- patch523_slot_data.gd -----------------------------------------------------

func slot_outputs() -> Dictionary:
	var out: Dictionary = {"keys": SLOTS.relic_card_keys(), "group_keys": SLOTS.relic_option_group_keys(), "subslot_keys": SLOTS.relic_subslot_buff_keys(),
		"unlock": SLOTS.relic_unlock_item(), "installed": SLOTS.installed(), "problem": SLOTS.problem, "schema": SLOTS.loaded_schema,
		"invoke_options": SLOTS.relic_combat.get("invoke_options"), "invoke_spells": SLOTS.relic_combat.get("invoke_spells"),
		"card_acquisition": SLOTS.card_acquisition, "relic_acquisition": SLOTS.relic_acquisition, "new_cards": SLOTS.new_cards, "options": SLOTS.options,
		"unlock_record": RELIC_UNLOCK.record(), "unlock_rules": RELIC_UNLOCK.source_rules_valid()}
	var cards: Dictionary = {}
	for key: String in SLOTS.relic_card_keys(): cards[key] = [SLOTS.relic_card(key), SLOTS.has_relic_card(key), SLOTS.relic_subslot_buff(key), SLOTS.relic_option_group(key + ":11")]
	for key: String in ["98:1", "2:20500", ""]: cards["missing:" + key] = [SLOTS.relic_card(key), SLOTS.has_relic_card(key), SLOTS.relic_subslot_buff(key), SLOTS.relic_option_group(key + ":11")]
	out["cards"] = cards
	var limits: Dictionary = {}
	for set_id: int in [772, 274, 5, 0, 9, -1]: limits[str(set_id)] = SLOTS.relic_server_limits_for(set_id)
	out["limits"] = limits
	return out

## The former readers, written against the former resident dictionaries.
func former_slot_outputs(candidate: Dictionary) -> Dictionary:
	var relic: Dictionary = candidate.relic
	var combat: Dictionary = candidate.relic_combat
	var out: Dictionary = {"keys": PackedStringArray(relic.cards.keys()), "group_keys": PackedStringArray(relic.option_groups.keys()), "subslot_keys": PackedStringArray(combat.relic_subslot_buffs.keys()),
		"unlock": relic.unlock_item, "installed": true, "problem": "", "schema": candidate.schema,
		"invoke_options": combat.invoke_options, "invoke_spells": combat.invoke_spells,
		"card_acquisition": candidate.card_acquisition, "relic_acquisition": candidate.relic_acquisition, "new_cards": candidate.new_cards, "options": candidate.options}
	var cards: Dictionary = {}
	for key: String in relic.cards: cards[key] = [relic.cards.get(key, {}), relic.cards.has(key), combat.relic_subslot_buffs.get(key, {}), relic.option_groups.get(key + ":11", {})]
	for key: String in ["98:1", "2:20500", ""]: cards["missing:" + key] = [relic.cards.get(key, {}), relic.cards.has(key), combat.relic_subslot_buffs.get(key, {}), relic.option_groups.get(key + ":11", {})]
	out["cards"] = cards
	var limits: Dictionary = {}
	for set_id: int in [772, 274, 5, 0, 9, -1]:
		var rows: Array = []
		for row: Dictionary in relic.source_server_limits:
			if int(row.ServerLimitSetID) == set_id: rows.append(row)
		limits[str(set_id)] = rows
	out["limits"] = limits
	return out

func without_unlock_consumer(value: Dictionary) -> Dictionary:
	var copy: Dictionary = value.duplicate(false)
	copy.erase("unlock_record"); copy.erase("unlock_rules")
	return copy

func test_slot_data() -> void:
	var candidate: Dictionary = relic_candidate()
	var former: Dictionary = former_slot_outputs(candidate.duplicate(true))
	SLOTS.adopt_for_test(candidate.duplicate(true), "")
	var resident: Dictionary = slot_outputs()
	same("slot accessors (resident) equal the former dictionaries", without_unlock_consumer(resident), former)
	check(resident.unlock_rules == true and not resident.unlock_record.is_empty(), "relic unlock consumer reads the unlock item")
	# A former whole-pack bake of this device is replaced by the records.
	BAKE.write(SLOTS.BAKE_NAME, "old", {"candidate": {"schema": "x"}, "problem": ""})
	SLOTS.adopt_for_test(candidate.duplicate(true), "slot-key")
	check(SLOTS._store != null, "slot records written")
	same("slot accessors (records) equal resident", slot_outputs(), resident)
	check(not FileAccess.file_exists(BAKE.data_path(SLOTS.BAKE_NAME)), "former whole-pack bake removed")
	check(not SLOTS.relic.has("cards") and not SLOTS.relic.has("option_groups") and not SLOTS.relic.has("source_server_limits") and not SLOTS.relic.has("unlock_item") and not SLOTS.relic_combat.has("relic_subslot_buffs"), "per-key relic parts are not resident")
	check(var_to_bytes(SLOTS.pack).size() * 4 < var_to_bytes(candidate).size(), "resident head is a fraction of the model")
	check(SLOTS._store.cached() <= RECORDS.DEFAULT_CAPACITY, "slot LRU bounded")
	check(SLOTS.reopen_for_test("slot-key"), "slot records reopen")
	same("slot accessors (reopened) equal resident", slot_outputs(), resident)
	check(not SLOTS.reopen_for_test("other-key"), "slot records of another key are a miss")
	# Storage failure, disk-required: explicit failure, nothing activated.
	for stage: String in ["create", "append:2", "commit", "reopen", "index"]:
		_clear_all()
		OS.set_environment(BAKE.DISK_REQUIRED_ENV, "1")
		BAKE.fault = SLOTS.RECORDS_NAME + "|" + stage
		SLOTS.adopt_for_test(candidate.duplicate(true), "slot-key")
		BAKE.fault = ""
		check(not SLOTS.installed() and SLOTS.pack.is_empty() and SLOTS._store == null, "disk-required failure activates nothing at " + stage)
		check(SLOTS.problem.contains("다시 시도") and SLOTS.store_result().get("reason") == "card_slots_store_failed", "disk-required failure reports its cause at " + stage)
		check(SLOTS.relic_card("98:20500").is_empty() and SLOTS.relic_server_limits_for(772).is_empty() and SLOTS.relic_unlock_item().is_empty(), "nothing readable after failure at " + stage)
		check(BAKE.store_failures.has(SLOTS.RECORDS_NAME) and _no_part(SLOTS.RECORDS_NAME), "failure recorded, no part file at " + stage)
		# Elsewhere: the former resident model.
		OS.set_environment(BAKE.DISK_REQUIRED_ENV, "0")
		BAKE.fault = SLOTS.RECORDS_NAME + "|" + stage
		SLOTS.adopt_for_test(candidate.duplicate(true), "slot-key")
		BAKE.fault = ""
		check(SLOTS._store == null and SLOTS.store_result().is_empty(), "resident fallback at " + stage)
		same("resident fallback values at " + stage, slot_outputs(), resident)
	_clear_all()

# --- current523_option_combat_input.gd ----------------------------------------

func input_outputs(keys: Array) -> Dictionary:
	var session: Dictionary = INPUT.session()
	var out: Dictionary = {"economy": session.get("economy"), "spell_material_types": session.get("spell_material_types"), "invoke_options": session.get("invoke_options"),
		"unlock": session.get("subslot_unlock_item"), "identity": session.get("source_input_identity"), "ready": session.get("ready"), "problem": INPUT.problem,
		"unlock_record": DOLL_UNLOCK.record(), "unlock_rules": DOLL_UNLOCK.source_rules_valid(),
		"economy_raw": [ECONOMY.raw(2, 1, "EnchantMaxExp"), ECONOMY.raw(2, 3, "AwakenAdenaCost"), ECONOMY.raw(2, 9, "EnchantMaxExp"), ECONOMY.raw(1, 1, "Missing")]}
	var rows: Dictionary = {}
	for key: String in keys: rows[key] = [INPUT.primary_doll_buff(key), INPUT.subslot_buff(key), INPUT.subslot_npc_binding(key), DOLL_SUBSLOT.subslot_row(key)]
	out["rows"] = rows
	var spells: Dictionary = {}
	for id: int in range(298, 310): spells[str(id)] = [INPUT.invoke_spell(str(id)), INPUT.invoke_buff(str(id + 200))]
	out["spells"] = spells
	for section: String in INPUT.KEYED: out["keys:" + section] = INPUT.section_keys(section)
	out["diagnostics"] = INPUT.diagnostics()
	return out

func former_input_outputs(result: Dictionary, keys: Array) -> Dictionary:
	var out: Dictionary = {"economy": result.economy, "spell_material_types": result.spell_material_types, "invoke_options": result.invoke_options,
		"unlock": result.subslot_unlock_item, "identity": result.source_input_identity, "ready": true, "problem": result.problem}
	var rows: Dictionary = {}
	for key: String in keys: rows[key] = [result.primary_doll_buffs.get(key, {}), result.subslot_buffs.get(key, {}), result.subslot_npc_bindings.get(key, {}), result.subslot_buffs.get(key, {})]
	out["rows"] = rows
	var spells: Dictionary = {}
	for id: int in range(298, 310): spells[str(id)] = [result.invoke_spells.get(str(id)), result.invoke_buffs.get(str(id + 200), [])]
	out["spells"] = spells
	for section: String in INPUT.KEYED: out["keys:" + section] = PackedStringArray(result[section].keys())
	var diagnostics: Dictionary = {}
	for field: String in INPUT.DIAGNOSTIC: diagnostics[field] = result[field]
	out["diagnostics"] = diagnostics
	return out

func test_option_input() -> void:
	var result: Dictionary = option_session()
	var keys: Array = result.primary_doll_buffs.keys()
	keys.append_array(["source:m523:2:1", "", "source:m508:98:20500"])
	var former: Dictionary = former_input_outputs(result.duplicate(true), keys)
	INPUT.adopt_for_test(result.duplicate(true), "")
	var resident: Dictionary = input_outputs(keys)
	same("option accessors (resident) equal the former session", _drop(resident, ["unlock_record", "unlock_rules", "economy_raw"]), former)
	check(resident.unlock_rules == true and resident.unlock_record.get("source_item_class_id") == 346901, "doll unlock consumer reads the session's unlock item")
	same("option economy consumer reads the session's economy", resident.economy_raw, [100.0, 3000.0, null, null])
	INPUT.adopt_for_test(result.duplicate(true), "input-key")
	check(INPUT._store != null, "option records written")
	same("option accessors (records) equal resident", input_outputs(keys), resident)
	var head: Dictionary = INPUT.session()
	var resident_keys: bool = true
	for field: String in INPUT.KEYED + INPUT.DIAGNOSTIC: resident_keys = resident_keys and not head.has(field)
	check(resident_keys, "keyed and build-only parts are not resident")
	check(var_to_bytes(head).size() * 4 < var_to_bytes(result).size(), "resident head is a fraction of the session")
	check(INPUT._store.cached() <= RECORDS.DEFAULT_CAPACITY, "option LRU bounded")
	check(INPUT.reopen_for_test("input-key"), "option records reopen")
	same("option accessors (reopened) equal resident", input_outputs(keys), resident)
	for stage: String in ["create", "append:5", "commit", "reopen", "index"]:
		_clear_all()
		OS.set_environment(BAKE.DISK_REQUIRED_ENV, "1")
		BAKE.fault = INPUT.RECORDS_NAME + "|" + stage
		INPUT.adopt_for_test(result.duplicate(true), "input-key")
		BAKE.fault = ""
		var failed: Dictionary = INPUT.session()
		check(INPUT._store == null and failed.get("ready") == true and failed.primary_doll_buffs.is_empty() and failed.subslot_unlock_item.is_empty() and failed.economy.is_empty(), "disk-required failure activates nothing at " + stage)
		check(INPUT.problem.contains("다시 시도") and failed.problem == INPUT.problem and INPUT.store_result().get("reason") == "option_combat_store_failed", "disk-required failure reports its cause at " + stage)
		check(INPUT.primary_doll_buff(str(keys[0])).is_empty() and INPUT.invoke_spell("300") == null and not DOLL_UNLOCK.source_rules_valid(), "nothing readable after failure at " + stage)
		check(BAKE.store_failures.has(INPUT.RECORDS_NAME) and _no_part(INPUT.RECORDS_NAME), "failure recorded, no part file at " + stage)
		OS.set_environment(BAKE.DISK_REQUIRED_ENV, "0")
		BAKE.fault = INPUT.RECORDS_NAME + "|" + stage
		INPUT.adopt_for_test(result.duplicate(true), "input-key")
		BAKE.fault = ""
		check(INPUT._store == null and INPUT.store_result().is_empty(), "resident fallback at " + stage)
		same("resident fallback values at " + stage, input_outputs(keys), resident)
	INPUT.reset_for_test()
	_clear_all()

func _drop(value: Dictionary, fields: Array) -> Dictionary:
	var copy: Dictionary = value.duplicate(false)
	for field: Variant in fields: copy.erase(field)
	return copy
