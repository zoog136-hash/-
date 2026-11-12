extends SceneTree
## Opt-in integration using the owned SHA-pinned original523 archive. Every
## character switch crosses the actual account writer and a JSON disk reload.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG = preload("res://scripts/characters/class_catalog.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const WAREHOUSE = preload("res://scripts/warehouse/local_warehouse.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: Array[String] = []
var observations: Dictionary = {}
var test_path: String = ""

class FloorView extends RefCounted:
	var records: Dictionary = {}
class ConsumableView extends RefCounted:
	var state: Dictionary = {}
	func export_state() -> Dictionary: return state.duplicate(true)
	func import_state(value: Dictionary) -> void: state = value.duplicate(true)
class QuestView extends RefCounted:
	var save_blocked: bool = false
class DeferredView extends RefCounted:
	var cancels: int = 0
	func cancel() -> void: cancels += 1
class OwnerView extends Node:
	## Only the surrounding World interfaces are bounded here. The transfer,
	## partition, proof checks, account staging and durable writer are production.
	var path: String
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var warehouse = WAREHOUSE.new()
	var ground_loot = FloorView.new()
	var consumable_service = ConsumableView.new()
	var quest_service = QuestView.new()
	var deferred_save = DeferredView.new()
	var patch523_owner_state_problem: String = ""
	var item_weight_index: Dictionary = {}
	var fail_write: bool = false
	func configure(target: String, payload: Dictionary) -> void:
		path = target
		inventory = payload.get("inventory", {}).duplicate(true)
		item_instances = payload.get("item_instances", {}).duplicate(true)
		warehouse.restore(payload.get("warehouse", {}))
		consumable_service.import_state(payload.get("consumable_state", {}))
	func _item_locked(_name: String, _id: String = "") -> bool: return false
	func _is_instance_equipped(_id: String) -> bool: return false
	func _inventory_total_weight() -> int: return 0
	func _carrying_capacity() -> int: return 1000000
	func _save_game(_quiet: bool, overrides: Dictionary) -> Error:
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return ERR_FILE_CORRUPT
		var candidate: Dictionary = parser.data
		SOURCE.normalize_loaded_save(candidate)
		candidate.merge(overrides, true)
		var issue: String = STACK.state_error(candidate.get("inventory", {}), candidate.get("item_instances", {}), candidate.get("consumable_state", {}), candidate.get("warehouse", {}), candidate.get("ground_drops", []), ACCOUNT.dormant_items(candidate))
		if not issue.is_empty(): return ERR_INVALID_DATA
		var staged: Dictionary = ACCOUNT.stage_save(path, candidate)
		if not staged.get("ok", false): return ERR_INVALID_DATA
		if fail_write: return ERR_CANT_CREATE
		return WRITER.write(path, staged.payload)

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_NATIVE_WAREHOUSE_FAIL ", label)
	return ok

func read_payload(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func typed(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var pairs: Array = []
		for key: Variant in keys: pairs.append([str(key), typed(value[key])])
		return [TYPE_DICTIONARY, pairs]
	if value is Array:
		var values: Array = []
		for entry: Variant in value: values.append(typed(entry))
		return [TYPE_ARRAY, values]
	return [typeof(value), value]

func heavy_values(value: Variant, prefix: String, out: Array) -> void:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key: Variant in keys:
			var child: String = prefix + "/" + str(key)
			if str(key) in FIELDS.HEAVY: out.append([child, typed(value[key])])
			else: heavy_values(value[key], child, out)
	elif value is Array:
		for index: int in value.size(): heavy_values(value[index], prefix + "/" + str(index), out)

func heavy_digest(payload: Dictionary) -> String:
	var values: Array = []
	heavy_values(payload, "", values)
	return JSON.stringify(values, "", true, true).sha256_text()

func write_candidate(store: RefCounted, payload: Dictionary, label: String) -> bool:
	var before: String = JSON.stringify(payload, "", true, true)
	var staged: Dictionary = ACCOUNT.stage_save(store.path, payload)
	check(JSON.stringify(payload, "", true, true) == before, label + ": staging preserves caller")
	if not check(staged.get("ok", false), label + ": production account staging"):
		printerr(staged.get("problem", ""))
		return false
	return check(WRITER.write(store.path, staged.payload) == OK, label + ": atomic writer") and check(store.open().get("ok", false), label + ": disk account reopens")

func load_view(store: RefCounted, label: String) -> Dictionary:
	var payload: Dictionary = read_payload(store.path)
	if not check(not payload.is_empty() and ACCOUNT.validate(payload).is_empty(), label + ": full account validates before load"): return {"ok":false}
	var before_sha: String = FileAccess.get_sha256(store.path)
	var before_heavy: String = heavy_digest(payload)
	SOURCE.normalize_loaded_save(payload)
	var dormant: Dictionary = ACCOUNT.dormant_items(payload)
	check(heavy_digest(payload) == before_heavy, label + ": HEAVY original values and numeric types preserved")
	check(FileAccess.get_sha256(store.path) == before_sha, label + ": load leaves durable bytes unchanged")
	check(ACCOUNT.validate(payload).is_empty(), label + ": canonical account remains consistent after proof normalization")
	var issue: String = STACK.state_error(payload.get("inventory", {}), payload.get("item_instances", {}), payload.get("consumable_state", {}), payload.get("warehouse", {}), payload.get("ground_drops", []), dormant)
	observations[label] = issue
	var accepted: bool = check(issue.is_empty(), label + ": production ownership accepts JSON reload")
	if not issue.is_empty(): printerr("OWNERSHIP_REASON ", label, ": ", issue)
	return {"ok":accepted, "payload":payload, "dormant":dormant}

func tamper_negatives(view: Dictionary, uid: String, item_name: String) -> void:
	var data: Dictionary = view.payload
	var state: Dictionary = data.consumable_state
	var dormant: Dictionary = view.dormant
	check(not STACK.state_error({}, {}, state, data.warehouse).is_empty(), "missing dormant remaining owner rejected")
	check(not STACK.state_error({item_name:6}, dormant, state, data.warehouse, [], dormant).is_empty(), "active/dormant duplicate physical owner rejected")
	var bad: Dictionary = dormant.duplicate(true)
	bad[uid][STACK.QUANTITY] = 7
	check(not STACK.state_error({}, {}, state, data.warehouse, [], bad).is_empty(), "dormant quantity tamper rejected")
	bad = dormant.duplicate(true)
	bad[uid][STACK.RECEIPT].source_definition_archive.source_sha256 = "untrusted"
	check(not STACK.state_error({}, {}, state, data.warehouse, [], bad).is_empty(), "dormant receipt archive tamper rejected")
	bad = dormant.duplicate(true)
	bad[uid][STACK.RECEIPT].source_original_item.ID = 999999
	check(not STACK.state_error({}, {}, state, data.warehouse, [], bad).is_empty(), "copied original ItemClass tamper rejected")
	var bad_ledger: Dictionary = state.duplicate(true)
	bad_ledger[STACK.USES][uid].remaining_quantity = 7
	check(not STACK.state_error({}, {}, bad_ledger, data.warehouse, [], dormant).is_empty(), "shared ledger conservation tamper rejected")

func finish() -> void:
	ACCOUNT.session.clear()
	print("CHARACTER_NATIVE_WAREHOUSE523_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"owned original523 catalog/grant/warehouse transfer/partition/account writer and full JSON reload; bounded World adapter; no HP effect, Main, art or device claim"}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if OS.get_environment("TWILIGHT_CHARACTER_REGRESSION_ISOLATED") != "1" or FileAccess.file_exists(ACCOUNT.DEFAULT_PATH):
		printerr("CHARACTER_NATIVE_WAREHOUSE_FAIL explicit fresh isolated profile required; player save untouched")
		quit(2)
		return
	var identity: Dictionary = SOURCE.identity()
	if not check(identity.get("source_sha256") == SOURCE.SOURCE_SHA and identity.get("source_bytes") == SOURCE.SOURCE_BYTES, "exact original523 archive verified"): finish(); return
	var catalog = CATALOG.new()
	if not check(catalog.configure(), "actual source character catalog configures"): finish(); return
	var store = ACCOUNT.new()
	test_path = "user://character-native-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	store.path = test_path
	if not check(store.open().get("ok", false), "fresh isolated account opens"): finish(); return
	var first: Dictionary = store.create_character("창고검증기사", 1, 1, catalog)
	var second: Dictionary = store.create_character("창고검증요정", 2, 2, catalog)
	if not check(first.get("ok", false) and second.get("ok", false), "A and B created with actual source identities"): finish(); return
	if not check(store.select_character(first.id).get("ok", false), "A selected"): finish(); return
	var definition: Dictionary = DROPS.definition_id("233")
	var record: Dictionary = DROPS.variant_item(definition.get("native_record", {}), 1)
	var grant: Dictionary = STACK.stage_grant(record, 10, {}, {"kind":"character_native_warehouse_test"})
	if not check(grant.get("ok", false), "production item233 grant issues ten units"): finish(); return
	var uid: String = grant.id
	var item: Dictionary = grant.item_instances[uid].duplicate(true)
	var item_name: String = item.name
	# Seed the exact production receipt of one consumed unit. HP use/effect is
	# covered by the native consumable suites, not claimed by this owner test.
	item[STACK.QUANTITY] = 9
	item.source_native_stack_used_quantity = 1
	var proof: Dictionary = STACK.proof_entry(item, uid)
	var state: Dictionary = {STACK.USES:{uid:STACK.ledger_row(proof, 1, 9)}}
	check(proof.get("remaining") == 9 and proof.get("used") == 1 and STACK.state_error({item_name:9}, {uid:item}, state).is_empty(), "consumed production receipt conserves nine units before JSON")
	var payload: Dictionary = read_payload(store.path)
	payload.inventory = {item_name:9}
	payload.item_instances = {uid:item}
	payload.warehouse = {"stacks":{}, "instances":{}}
	payload.ground_drops = []
	payload.consumable_state = state
	if not write_candidate(store, payload, "A consumption") or not check(store.select_character(second.id).get("ok", false), "B selected after consumed A disk save"): finish(); return
	var consumed_b: Dictionary = load_view(store, "B with consumed dormant A")
	if consumed_b.get("ok", false):
		check(consumed_b.payload.get("inventory", {}).is_empty() and consumed_b.payload.get("item_instances", {}).is_empty(), "dormant proof does not grant B inventory or weight")
	# Continue independently so a broken dormant proof cannot hide the partition case.
	if not check(store.select_character(first.id).get("ok", false), "A selected for deposit"): finish(); return
	var active_a: Dictionary = load_view(store, "A active before deposit")
	if not active_a.get("ok", false): finish(); return
	var owner = OwnerView.new()
	owner.configure(store.path, active_a.payload)
	var deposited: Dictionary = STACK.transfer_warehouse(owner, item_name, 3, "deposit", uid)
	if not check(deposited.get("ok", false) and deposited.get("saved", false), "production partial warehouse deposit commits"):
		printerr(deposited); owner.free(); finish(); return
	var child_id: String = str(deposited.physical_id)
	check(child_id != uid and owner.item_instances[uid][STACK.QUANTITY] == 6 and owner.warehouse.instances[child_id][STACK.QUANTITY] == 3, "production partition retains six parent plus three child")
	check(owner.deferred_save.cancels == 1, "successful warehouse commit cancels deferred duplicate save")
	owner.free()
	if not check(store.open().get("ok", false) and store.select_character(second.id).get("ok", false), "B selects partitioned account from disk"): finish(); return
	var split_b: Dictionary = load_view(store, "B with dormant partitioned A")
	if not split_b.get("ok", false): finish(); return
	tamper_negatives(split_b, uid, item_name)
	owner = OwnerView.new()
	owner.configure(store.path, split_b.payload)
	check(STACK.proof(owner, uid).is_empty(), "A dormant parent cannot be selected from B bag")
	var withdrawn: Dictionary = STACK.transfer_warehouse(owner, item_name, 3, "withdraw", child_id)
	if not check(withdrawn.get("ok", false) and withdrawn.get("saved", false), "B production withdrawal commits same physical child"):
		printerr(withdrawn); owner.free(); finish(); return
	check(STACK.proof(owner, child_id).get("remaining") == 3 and owner.inventory.get(item_name) == 3, "B owns only its three withdrawn units")
	payload = read_payload(store.path)
	SOURCE.normalize_loaded_save(payload)
	var child: Dictionary = payload.item_instances[child_id].duplicate(true)
	child[STACK.QUANTITY] = 2
	child.source_native_stack_used_quantity = 1
	var child_proof: Dictionary = STACK.proof_entry(child, child_id)
	payload.item_instances = {child_id:child}
	payload.inventory = {item_name:2}
	payload.consumable_state[STACK.USES][child_id] = STACK.ledger_row(child_proof, 1, 2)
	if not write_candidate(store, payload, "B child consumption"): owner.free(); finish(); return
	var consumed_child: Dictionary = load_view(store, "B child consumed from disk")
	if not consumed_child.get("ok", false): owner.free(); finish(); return
	owner.configure(store.path, consumed_child.payload)
	owner.fail_write = true
	var before_sha: String = FileAccess.get_sha256(store.path)
	var before_items: String = JSON.stringify(owner.item_instances, "", true, true)
	var failed: Dictionary = STACK.transfer_warehouse(owner, item_name, 1, "deposit", child_id)
	check(not failed.get("ok", true), "failed partial warehouse write is reported")
	check(FileAccess.get_sha256(store.path) == before_sha and JSON.stringify(owner.item_instances, "", true, true) == before_items and owner.inventory.get(item_name) == 2, "failed partial transfer preserves durable and live child ownership")
	owner.free()
	if not check(store.open().get("ok", false) and store.select_character(first.id).get("ok", false), "A reselected after B and failed transfer"): finish(); return
	var returned_a: Dictionary = load_view(store, "A returns with dormant consumed B child")
	if returned_a.get("ok", false):
		check(returned_a.payload.inventory.get(item_name) == 6 and not returned_a.payload.item_instances.has(child_id), "A retains six own units without resurrecting B child")
		check(STACK.proof_entry(returned_a.payload.item_instances[uid], uid).get("remaining") == 6, "A parent remains usable exact source ownership")
	finish()
