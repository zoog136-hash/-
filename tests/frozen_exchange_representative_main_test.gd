extends SceneTree
## Installed representative observations; only the wallet/profile is synthetic.
## Requires the private original definitions and preserved official capture files.
## No coverage/listing fixture is created or substituted for production data.
const QA = preload("res://tests/qa_class_selection.gd")
const Exchange = preload("res://scripts/exchange/frozen_exchange.gd")
const Catalog = preload("res://scripts/exchange/frozen_catalog.gd")
const Definitions = preload("res://scripts/resources/current523_definition_rows.gd")
const NativeItems = preload("res://scripts/loot/patch523_monster_drops.gd")
const NativeStack = preload("res://scripts/loot/current523_native_stack.gd")
const AwakeningSupply = preload("res://scripts/cards/native_awakening_supply.gd")
const MAX_QUOTED_ROWS: int = 200
const MAX_EVIDENCE_FILES: int = 10000
var checks: int = 0
var failures: int = 0
var evidence_files: Dictionary = {}
var evidence_indexed: bool = false
var evidence_scan_complete: bool = true

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func same_text(value: Variant, expected: String) -> bool:
	return value is String and value == expected

func query_fields(url: String) -> Dictionary:
	var fields: Dictionary = {}
	if not url.contains("?"): return fields
	for part: String in url.get_slice("?",1).split("&",false):
		if part.count("=") != 1: return {}
		var key: String = part.get_slice("=",0).uri_decode()
		if fields.has(key): return {}
		fields[key] = part.get_slice("=",1).uri_decode()
	return fields

func index_evidence() -> void:
	if evidence_indexed: return
	evidence_indexed = true
	var roots: Array[String] = ["res://evidence/exchange"]
	var extra: String = OS.get_environment("TWILIGHT_EXCHANGE_CAPTURE_DIR")
	if not extra.is_empty(): roots.append(extra)
	var pending: Array[String] = roots.duplicate()
	var seen: Dictionary = {}
	var examined: int = 0
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		var canonical: String = ProjectSettings.globalize_path(directory)
		if seen.has(canonical): continue
		seen[canonical] = true
		if not DirAccess.dir_exists_absolute(directory): continue
		for child: String in DirAccess.get_directories_at(directory):
			if not child.begins_with("."): pending.append(directory.path_join(child))
		for name_value: String in DirAccess.get_files_at(directory):
			if not name_value.ends_with(".json"): continue
			examined += 1
			if examined > MAX_EVIDENCE_FILES: evidence_scan_complete = false; return
			var path: String = directory.path_join(name_value)
			var digest: String = FileAccess.get_sha256(path)
			if not digest.is_empty() and not evidence_files.has(digest): evidence_files[digest] = path

func observation_matches(row: Dictionary) -> bool:
	if not str(row.evidence_url).begins_with("https://api-goats.plaync.com/lms/v2.0/"): return false
	var observation: Variant = row.get("observation")
	if not observation is Dictionary or not Catalog._sha256(observation.get("body_sha256")) or not Catalog._sha256(observation.get("receipt_sha256")) or not Catalog.integer(observation.get("row_index"),0) or not observation.get("raw_row") is Dictionary: return false
	if not observation.get("listing_identity_verified") is bool or observation.listing_identity_verified: return false
	index_evidence()
	if not evidence_scan_complete or not evidence_files.has(observation.body_sha256) or not evidence_files.has(observation.receipt_sha256): return false
	var body: Variant = JSON.parse_string(FileAccess.get_file_as_string(evidence_files[observation.body_sha256]))
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(evidence_files[observation.receipt_sha256]))
	if not body is Dictionary or not body.get("contents") is Array or int(observation.row_index) >= body.contents.size() or not receipt is Dictionary: return false
	var raw: Dictionary = observation.raw_row
	if body.contents[int(observation.row_index)] != raw or not same_text(receipt.get("sha256"),observation.body_sha256) or not same_text(receipt.get("url"),row.evidence_url) or not Catalog.integer(receipt.get("http_status"),200,200): return false
	var query: Dictionary = query_fields(row.evidence_url)
	if not same_text(query.get("blessedType"),"1") or not same_text(query.get("enchantLevel"),str(int(row.enchant))) or not row.evidence_url.contains("/item/%d/stock?" % int(row.item_class_id)): return false
	if not Catalog.integer(raw.get("itemId"),int(row.item_class_id),int(row.item_class_id)) or not Catalog.integer(raw.get("quantity"),int(row.bundle_size),int(row.bundle_size)) or not Catalog.integer(raw.get("salePrice"),int(row.bundle_price),int(row.bundle_price)) or not Catalog.integer(raw.get("enchantLevel"),int(row.enchant),int(row.enchant)): return false
	if not raw.get("world") is bool or not Catalog.integer(raw.get("serverId"),1) or not same_text(query.get("serverId"),str(int(raw.serverId))) or not same_text(raw.get("itemName"),str(row.get("observed_item_name",""))): return false
	var market: String = ("world:" if raw.world else "server:") + str(int(raw.serverId))
	return market == row.server_id

func priority(row: Dictionary) -> int:
	var categories: Variant = row.get("category1_ids",[])
	if not categories is Array: return 2
	var consumable: bool = false
	for category: Variant in categories:
		if not Catalog.integer(category,1): continue
		if int(category) in [1,11,21]: return 0
		if int(category) in [31,41]: consumable = true
	return 1 if consumable else 2

func origin_matches(origin: Variant, row: Dictionary, snapshot_sha: String) -> bool:
	if not origin is Dictionary: return false
	return same_text(origin.get("kind"),"frozen_exchange") and same_text(origin.get("snapshot_sha256"),snapshot_sha) and same_text(origin.get("listing_key"),Catalog.key(row)) and same_text(origin.get("evidence_url"),row.evidence_url) and Catalog.integer(origin.get("bundle_price"),int(row.bundle_price),int(row.bundle_price)) and Catalog.integer(origin.get("bundle_size"),int(row.bundle_size),int(row.bundle_size)) and Catalog.integer(origin.get("bundles"),1,1) and Catalog.integer(origin.get("observed_blessed_type"),1,1) and Catalog.integer(origin.get("observed_enchant"),int(row.enchant),int(row.enchant))

func granted_units(world: Node, uid: String, row: Dictionary, snapshot_sha: String) -> int:
	var entry: Variant = world.item_instances.get(uid)
	if not entry is Dictionary or not entry.get("record") is Dictionary: return -1
	var record: Dictionary = entry.record
	if not same_text(record.get("source"),"lineagem_patch523") or not same_text(record.get("source_snapshot"),"patch523") or not same_text(record.get("sourceId"),"m523:item:" + str(int(row.item_class_id))) or not Catalog.integer(record.get("source_item_class_id"),int(row.item_class_id),int(row.item_class_id)): return -1
	var archive: Variant = record.get("source_definition_archive")
	if not archive is Dictionary or not same_text(archive.get("source_sha256"),Definitions.SOURCE_SHA): return -1
	var equipment_proof: Variant = entry.get("source_m_reward_proof")
	if equipment_proof is Dictionary:
		if not NativeItems.equipment(record) or not Catalog.integer(entry.get("level"),int(row.enchant),int(row.enchant)) or not Catalog.integer(equipment_proof.get("item_class_id"),int(row.item_class_id),int(row.item_class_id)) or not Catalog.integer(equipment_proof.get("bless"),1,1) or not Catalog.integer(equipment_proof.get("enchant"),int(row.enchant),int(row.enchant)) or not origin_matches(equipment_proof.get("supplier"),row,snapshot_sha): return -1
		return 1
	var stack_receipt: Variant = entry.get(NativeStack.RECEIPT)
	if stack_receipt is Dictionary:
		var owned: Dictionary = NativeStack.proof_entry(entry,uid)
		if owned.is_empty() or not Catalog.integer(stack_receipt.get("bless_raw"),1,1) or not Catalog.integer(stack_receipt.get("granted_quantity"),1) or int(owned.remaining) != int(stack_receipt.granted_quantity) or not origin_matches(stack_receipt.get("origin"),row,snapshot_sha): return -1
		return int(owned.remaining)
	var supply_receipt: Variant = entry.get("source_awakening_supply")
	if supply_receipt is Dictionary:
		var owned: Dictionary = AwakeningSupply.proof(world,uid,int(row.item_class_id))
		if not owned.get("ok",false) or not Catalog.integer(supply_receipt.get("granted_quantity"),1) or int(owned.quantity) != int(supply_receipt.granted_quantity) or not origin_matches(supply_receipt.get("origin"),row,snapshot_sha): return -1
		return int(owned.quantity)
	return -1

func finish(world: Node) -> void:
	if world != null:
		world.queue_free();await process_frame
	print("FROZEN_EXCHANGE_REPRESENTATIVE_MAIN_RESULT checks=%d failures=%d installed_observations_test_wallet" % [checks,failures])
	quit(1 if failures else 0)

func run() -> void:
	check(not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty(),"private original definition path is explicit")
	check(Definitions.identity().get("source_sha256") == Definitions.SOURCE_SHA,"exact original definitions selected")
	if failures: await finish(null);return
	var production_bytes: PackedByteArray = FileAccess.get_file_as_bytes(Catalog.PATH)
	var production_sha: String = FileAccess.get_sha256(Catalog.PATH)
	var production: Variant = JSON.parse_string(production_bytes.get_string_from_utf8())
	check(Catalog.validate(production).is_empty(),"installed production snapshot validates")
	if failures: await finish(null);return
	check(production.status == "captured" and production.get("test_fixture") == false and production.coverage.scope == "representative_server" and production.coverage.expected_server_ids == ["server:1"] and not production.coverage.complete and production.coverage.approximate and not production.listings.is_empty(),"installed representative server1 observations are partial real data")
	if failures: await finish(null);return
	var allowed: Dictionary = {"server:1":true,str(production.coverage.scope_proof.world_id):true}
	var markets_match: bool = true
	var ordered: Array[Dictionary] = []
	for row: Dictionary in production.listings:
		if not allowed.has(row.server_id): markets_match = false
	for tier: int in range(2):
		for row: Dictionary in production.listings:
			if priority(row) == tier: ordered.append(row)
	check(markets_match,"installed rows belong only to selected local server and its proven shared world")
	check(production.price_policy == "frozen_once" and production.reset.timezone == "Asia/Seoul" and Catalog.integer(production.reset.hour,5,5),"installed price and 05:00 KST policies stay frozen")
	if failures: await finish(null);return
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false)
	check(QA.enter_game(world),"actual Main enters game with original definitions")
	world.player.set_physics_process(false)
	var exchange = Exchange.new();exchange.configure(world)
	check(exchange.catalog.captured() and exchange.catalog.sha256 == production_sha,"runtime reads the installed production path without a listing fixture")
	var previous: Dictionary = world.source_shop.export_state().get(Exchange.STATE_KEY,Exchange.fresh_state())
	check(Exchange.validate_state(previous).is_empty() and str(previous.snapshot_sha256).is_empty() and previous.consumed.is_empty(),"isolated test profile has no prior exchange purchases")
	check(world._save_game(true) == OK,"isolated actual Main baseline can be saved")
	if failures: await finish(world);return
	var path: String = world.save_path()
	var search_disk: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var search_instances: Dictionary = world.item_instances.duplicate(true)
	var search_stock: Dictionary = world.source_shop.export_state()
	var selected: Dictionary = {}
	var selected_quote: Dictionary = {}
	var attempted: int = 0
	var refusal_counts: Dictionary = {}
	for row: Dictionary in ordered:
		if attempted >= MAX_QUOTED_ROWS: break
		if int(row.initial_bundles) != 1 or int(row.bundle_price) > int(Catalog.LIMIT / 2): continue
		attempted += 1
		world.inventory["다이아"] = int(row.bundle_price) * 2 # Explicit isolated test funding only.
		var wallet: Dictionary = world.inventory.duplicate(true)
		var quote: Dictionary = exchange.quote(Catalog.key(row))
		if world.inventory != wallet or world.item_instances != search_instances or world.source_shop.export_state() != search_stock or FileAccess.get_file_as_bytes(path) != search_disk:
			check(false,"candidate quotes preserve wallet physical items stock and disk")
			await finish(world);return
		if quote.get("ok",false): selected = row.duplicate(true);selected_quote = quote;break
		var reason: String = str(quote.get("reason","locked"))
		refusal_counts[reason] = int(refusal_counts.get(reason,0)) + 1
	check(not selected.is_empty(),"a verified production equipment or consumable row is purchasable within 200 quotes")
	if selected.is_empty():
		print("REPRESENTATIVE_MAIN_SEARCH tried=%d refusals=%s" % [attempted,JSON.stringify(refusal_counts)])
		await finish(world);return
	check(observation_matches(selected),"selected installed price quantity enhancement name and market match SHA-verified official response and receipt")
	check(selected.attributes.size() == 1 and Catalog.integer(selected.attributes.get("blessed_type"),1,1) and int(selected_quote.total) == int(selected.bundle_price) and int(selected_quote.quantity) == int(selected.bundle_size),"quote preserves explicitly observed normal blessing and exact whole bundle")
	if failures: await finish(world);return
	var price: int = int(selected.bundle_price)
	var quantity: int = int(selected.bundle_size)
	var native: Dictionary = world.source_item_definition(int(selected.item_class_id)).get("native_record",{})
	var native_name: String = str(native.get("name",""))
	check(not native_name.is_empty(),"selected production ItemClass has its native inventory identity")
	if failures: await finish(world);return
	var quantity_before: int = int(world.inventory.get(native_name,0))
	var legacy_before: int = int(world.inventory.get(str(selected.item_name),0))
	var instances_before: Dictionary = world.item_instances.duplicate(true)
	check(world._save_game(true) == OK,"explicit test wallet baseline is durable before purchase")
	if failures: await finish(world);return
	var outcome: Dictionary = exchange.buy(Catalog.key(selected))
	check(outcome.get("ok",false) and int(world.inventory.get("다이아",0)) == price and int(world.inventory.get(native_name,0)) == quantity_before + quantity and exchange.available(selected) == 0,"actual production purchase atomically debits the observed price grants full bundle and consumes its observation")
	if not outcome.get("ok",false):
		print("REPRESENTATIVE_MAIN_PURCHASE_REFUSED ",str(outcome.get("reason","unknown")))
		await finish(world);return
	check(int(world.inventory.get(str(selected.item_name),0)) == legacy_before,"production purchase adds no legacy name-keyed substitute")
	var new_ids: Array[String] = []
	var units: int = 0
	var proofs_ok: bool = true
	for uid: String in world.item_instances:
		if instances_before.has(uid): continue
		new_ids.append(uid)
		var supplied: int = granted_units(world,uid,selected,production_sha)
		if supplied < 1: proofs_ok = false
		else: units += supplied
	check(proofs_ok and not new_ids.is_empty() and units == quantity,"new native physical ownership proofs preserve source ID blessing enhancement supplier snapshot and full quantity")
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var saved: Variant = JSON.parse_string(saved_bytes.get_string_from_utf8())
	if not saved is Dictionary: check(false,"atomic purchase save is readable");await finish(world);return
	var ledger: Dictionary = saved.get("source_shop",{}).get(Exchange.STATE_KEY,{})
	check(same_text(ledger.get("snapshot_sha256"),production_sha) and Catalog.integer(ledger.get("consumed",{}).get(Catalog.key(selected)),1,1) and int(saved.inventory.get("다이아",0)) == price and int(saved.inventory.get(native_name,0)) == quantity_before + quantity and normalized(saved.item_instances) == normalized(world.item_instances),"same durable save contains wallet full native proof and consumed production stock")
	check(FileAccess.get_file_as_bytes(Catalog.PATH) == production_bytes,"first purchase never changes the installed frozen production snapshot")
	if failures: await finish(world);return
	world._load_game(true)
	var reload_ok: bool = not world.source_save_blocked and world.patch523_owner_state_problem.is_empty() and int(world.inventory.get("다이아",0)) == price and int(world.inventory.get(native_name,0)) == quantity_before + quantity and exchange.available(selected) == 0
	var reload_units: int = 0
	for uid: String in new_ids:
		var supplied: int = granted_units(world,uid,selected,production_sha)
		if supplied < 1: reload_ok = false
		else: reload_units += supplied
	check(reload_ok and reload_units == quantity,"actual reload preserves original physical proof wallet quantity and depleted production stock")
	var reloaded_wallet: Dictionary = world.inventory.duplicate(true)
	var reloaded_instances: Dictionary = world.item_instances.duplicate(true)
	var reloaded_stock: Dictionary = world.source_shop.export_state()
	var reloaded_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var repeated: Dictionary = exchange.buy(Catalog.key(selected))
	check(not repeated.get("ok",false) and world.inventory == reloaded_wallet and world.item_instances == reloaded_instances and world.source_shop.export_state() == reloaded_stock and FileAccess.get_file_as_bytes(path) == reloaded_bytes,"repeat purchase cannot double-charge despite sufficient remaining test funds")
	check(FileAccess.get_file_as_bytes(Catalog.PATH) == production_bytes and exchange.catalog.sha256 == production_sha,"production bytes and runtime identity remain frozen after purchase reload and repeat")
	print("REPRESENTATIVE_MAIN_SELECTED ",JSON.stringify({"server_id":selected.server_id,"item_class_id":selected.item_class_id,"bundle_price":price,"bundle_size":quantity,"enchant":selected.enchant,"quoted_rows":attempted,"native_quantity":units,"production_sha256":production_sha}))
	await finish(world)
