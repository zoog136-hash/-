extends SceneTree
## Acquisition history removal (save_provenance_trim.gd, user 2026-11-19
## "어떤몬스터가 떨어트렸는가 같은 ... 데이터들 다 삭제해").
## Rules (always): drop proofs, receipt ItemClass-row/archive copies, first
## grant origin detail and per-floor pickup receipts leave an old-shape save;
## every copy of one receipt (bag, use ledger, merge journal, partitions,
## ammo selection, offline character, shared journal) trims to one identical
## form; quantities, bless, enchant, element, locks, equip and placements are
## unchanged; trimming is idempotent and never edits its input.
## With the original definition ZIP: actual Main loads such an old save with
## the same bag/warehouse/gold/weight/locks, validates and re-saves smaller,
## save -> load -> save is byte-stable, and a new floor pickup stores no
## monster/drop rows.
const TRIM = preload("res://scripts/loot/save_provenance_trim.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const ACQUIRE = preload("res://scripts/loot/source523_ground_acquisition.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const LEATHER := 366
const POTION := 237
const ARMOR := 377
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SAVE_PROVENANCE_TRIM_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

const ROW := {"ID":366.0,"Name":"가죽","MaxStackAmount":10000.0,"IsStorable":true,"Weight":1.0}
const ARCHIVE := {"schema":"twilight.current523.definitions.v1","sha256":"ab12","member":"x.json"}
const PROOF := {"source_snapshot":"patch523","source_npc_id":45.0,"source_item_class_id":366.0,"bless_raw":1.0,"required_quest_id":0.0,"source_rows":[{"ID":9001.0,"NpcClassID":45.0,"ItemClassID":366.0,"Bless":1.0,"RequiredQuestID":0.0}],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}

func old_receipt(uid: String, quantity: int) -> Dictionary:
	return {"schema":1,"issued_physical_id":uid,"item_class_id":366,"bless_raw":1,"granted_quantity":quantity,"source_definition_archive":ARCHIVE.duplicate(true),"source_original_item":ROW.duplicate(true),"origin":{"kind":"source523_floor","floor_id":"f"+uid,"drop":PROOF.duplicate(true)}}

func old_record() -> Dictionary:
	return {"name":"가죽","slot":"material","source_m_native_item":true,"source_item_class_id":366,"source_bless_raw":1,"source_definition_archive":ARCHIVE.duplicate(true),"source_original_item":ROW.duplicate(true),"source_m_drop_proof":PROOF.duplicate(true),"source_m_item_id":366}

func old_save() -> Dictionary:
	var a: Dictionary = old_receipt("a".repeat(32), 5)
	var b: Dictionary = old_receipt("b".repeat(32), 3)
	var child: Dictionary = a.duplicate(true); child.issued_physical_id = "c".repeat(32); child.schema = 2; child.granted_quantity = 2
	child.origin = {"kind":"owned_quantity_partition","partition_id":"d".repeat(32),"parent_physical_id":"a".repeat(32),"parent_receipt":a.duplicate(true)}
	var merged: Dictionary = b.duplicate(true); merged.schema = 3; merged.issued_physical_id = "e".repeat(32); merged.granted_quantity = 3
	merged.origin = {"kind":"owned_quantity_merge","merge_id":"f".repeat(32),"components":[{"physical_id":"b".repeat(32),"quantity":3}]}
	var armor: Dictionary = {"name":"징박힌 가죽 갑옷","level":4,"element":"fire","element_level":2,"bless_state":"blessed","record":{"name":"징박힌 가죽 갑옷","slot":"armor","source_m_drop_proof":PROOF.duplicate(true)},"source_m_drop_proof":PROOF.duplicate(true)}
	var instances: Dictionary = {
		"a".repeat(32): {"name":"가죽","level":0,"record":old_record(),"source_native_stack_quantity":2,"source_native_stack_used_quantity":1,"source_native_stack_transferred_quantity":2,"source_native_stack_receipt":a.duplicate(true)},
		"c".repeat(32): {"name":"가죽","level":0,"record":old_record(),"source_native_stack_quantity":2,"source_native_stack_used_quantity":0,"source_native_stack_receipt":child.duplicate(true)},
		"e".repeat(32): {"name":"가죽","level":0,"record":old_record(),"source_native_stack_quantity":3,"source_native_stack_used_quantity":0,"source_native_stack_receipt":merged.duplicate(true)},
		"7": armor}
	var state: Dictionary = {
		"source_native_stack_uses": {"a".repeat(32): {"receipt":a.duplicate(true),"used_quantity":1,"remaining_quantity":2,"transferred_quantity":2}},
		"source_native_stack_partitions": {"d".repeat(32): {"schema":1,"parent_id":"a".repeat(32),"child_id":"c".repeat(32),"quantity":2,"before_remaining":4,"after_remaining":2,"before_transferred":0,"after_transferred":2,"used_at_partition":1,"parent_receipt":a.duplicate(true),"child_receipt":child.duplicate(true)}},
		"source_native_stack_merges": {"f".repeat(32): {"schema":1,"into":"e".repeat(32),"item_class_id":366,"bless_raw":1,"components":[{"physical_id":"b".repeat(32),"receipt":b.duplicate(true),"used_quantity":0,"transferred_quantity":0,"remaining_quantity":3}]}},
		"source_native_ammo_equipped": {"physical_id":"a".repeat(32),"name":"가죽","receipt":a.duplicate(true)},
		"source_ground_acquisitions": {"floor1":{"schema":1,"source_npc_id":45,"drop_proof_sha256":"00"}},
		"elixirs_used": 3}
	var dropped: Dictionary = instances["e".repeat(32)].duplicate(true)
	var flat: Dictionary = {"gold":1234,"inventory":{"가죽":7,"징박힌 가죽 갑옷":1},"item_instances":instances,"consumable_state":state,"equipped_items":{"armor":"7"},"ui_preferences":{"item_locks":{"가죽@@@"+"e".repeat(32):true}},
		"warehouse":{"stacks":{"가죽":3},"instances":{"w".repeat(32): {"name":"가죽","level":0,"record":old_record(),"source_native_stack_quantity":3,"source_native_stack_used_quantity":0,"source_native_stack_receipt":old_receipt("w".repeat(32),3)}}},
		"ground_drops":[{"id":"g1","player_dropped":true,"quantity":3,"item_name":"가죽","item_record":dropped.record.duplicate(true),"physical_item":{"id":"z".repeat(32),"data":dropped}}, {"id":"g2","quantity":1,"item_name":"가죽","item_record":old_record()}]}
	var shared: Dictionary = {"warehouse":flat.warehouse.duplicate(true),"consumable_state":{"source_native_stack_uses":state.source_native_stack_uses.duplicate(true),"source_native_stack_partitions":state.source_native_stack_partitions.duplicate(true),"source_native_stack_merges":state.source_native_stack_merges.duplicate(true)}}
	var selected: Dictionary = flat.duplicate(true); selected.erase("warehouse")
	var dormant: Dictionary = {"item_instances":{"q".repeat(32): {"name":"가죽","level":0,"record":old_record(),"source_native_stack_quantity":1,"source_native_stack_used_quantity":0,"source_native_stack_receipt":old_receipt("q".repeat(32),1)}},"consumable_state":{"source_ground_acquisitions":{"x":{}}}}
	var save: Dictionary = flat.duplicate(true)
	save["character_account"] = {"schema":"twilight.local-character-account.v2","selected":"1","shared":shared,"characters":[{"id":"1","state":selected},{"id":"2","state":dormant}]}
	return save

func collect_receipts(value: Variant, out: Array) -> void:
	if value is Dictionary:
		if value.has("issued_physical_id") and value.has("granted_quantity"): out.append(value)
		for key: Variant in value: collect_receipts(value[key], out)
	elif value is Array:
		for item: Variant in value: collect_receipts(item, out)

func has_text(value: Variant, needle: String) -> bool:
	return JSON.stringify(value).contains(needle)

func rules() -> void:
	var save: Dictionary = old_save()
	var before: Dictionary = save.duplicate(true)
	var flat_input: Dictionary = save.duplicate(true)
	var flat: Dictionary = TRIM.payload(flat_input)
	check(flat_input == before, "payload() never edits its input")
	TRIM.loaded_save(save)
	evidence["bytes"] = {"before":JSON.stringify(before).length(),"after":JSON.stringify(save).length()}
	check(JSON.stringify(save).length()*10 < JSON.stringify(before).length()*6, "old-shape save shrinks by more than 40%% (%s)" % str(evidence.bytes))
	# The unowned monster floor drop (ground_drops[1]) keeps the proof its
	# pickup reads; everything owned loses it.
	var owned_part: Dictionary = save.duplicate(true); owned_part.ground_drops = [owned_part.ground_drops[0]]
	owned_part.character_account.characters[0].state.ground_drops = [owned_part.ground_drops[0]]
	for needle: String in ["source_m_drop_proof","source_rows","drop_proof_sha256","source_ground_acquisitions","\"floor_id\""]:
		check(not has_text(owned_part, needle), "no owned %s left anywhere" % needle)
	var receipts: Array = []
	collect_receipts(owned_part, receipts)
	evidence["receipt_copies"] = receipts.size()
	check(receipts.size() >= 16, "every receipt copy found (%d)" % receipts.size())
	for receipt: Dictionary in receipts:
		check(not has_text(receipt, "source_definition_archive") and not has_text(receipt, "MaxStackAmount"), "receipt %s has no row/archive copy" % str(receipt.get("issued_physical_id","")).left(4))
	# Every copy of receipt a is one identical trimmed form.
	var a: Dictionary = save.item_instances["a".repeat(32)].source_native_stack_receipt
	check(FIELDS.lazy(a) and int(a.source_item_class_id) == 366 and a.origin == {"kind":"source523_floor"} and not a.has("source_original_item"), "trimmed receipt: catalog MARK + ItemClass ID + origin kind")
	var state: Dictionary = save.consumable_state
	check(state.source_native_stack_uses["a".repeat(32)].receipt == a and state.source_native_ammo_equipped.receipt == a and state.source_native_stack_partitions["d".repeat(32)].parent_receipt == a, "bag, ledger, ammo and partition copies stay identical")
	var child: Dictionary = save.item_instances["c".repeat(32)].source_native_stack_receipt
	check(child == state.source_native_stack_partitions["d".repeat(32)].child_receipt and child.origin.parent_receipt == a and child.origin.partition_id == "d".repeat(32), "partition child keeps its structure with the trimmed parent")
	var merged: Dictionary = save.item_instances["e".repeat(32)].source_native_stack_receipt
	check(merged.origin.kind == "owned_quantity_merge" and merged.origin.components == [{"physical_id":"b".repeat(32),"quantity":3}], "merge receipt structure kept")
	check(state.source_native_stack_merges["f".repeat(32)].components[0].receipt.origin == {"kind":"source523_floor"}, "merge journal component receipts trimmed")
	var shared: Dictionary = save.character_account.shared
	check(shared.consumable_state.source_native_stack_uses == state.source_native_stack_uses and shared.warehouse == save.warehouse, "account shared journals/warehouse trim to the same form as the flat body")
	check(save.character_account.characters[0].state.item_instances == save.item_instances, "selected character state == flat body")
	check(not save.character_account.characters[1].state.consumable_state.has("source_ground_acquisitions") and FIELDS.lazy(save.character_account.characters[1].state.item_instances["q".repeat(32)].source_native_stack_receipt), "offline character trimmed too")
	var floor: Dictionary = save.ground_drops[0]
	check(floor.item_record == floor.physical_item.data.record and not floor.item_record.has("source_m_drop_proof"), "player-dropped floor stack keeps item_record == physical record")
	check(save.ground_drops[1].item_record.has("source_m_drop_proof"), "an unowned monster floor drop keeps the proof its pickup reads")
	# Game state unchanged.
	var armor: Dictionary = save.item_instances["7"]
	check(armor.level == 4 and armor.element == "fire" and armor.element_level == 2 and armor.bless_state == "blessed" and not armor.has("source_m_drop_proof") and not armor.record.has("source_m_drop_proof"), "equipment keeps enchant/element/bless, loses only the drop proof")
	for uid: String in before.item_instances:
		var old_entry: Dictionary = before.item_instances[uid]; var new_entry: Dictionary = save.item_instances[uid]
		for key: String in ["name","level","source_native_stack_quantity","source_native_stack_used_quantity","source_native_stack_transferred_quantity","element","element_level","bless_state"]:
			check(old_entry.get(key) == new_entry.get(key), "%s keeps %s" % [uid.left(4), key])
		if old_entry.has("source_native_stack_receipt"):
			var r0: Dictionary = old_entry.source_native_stack_receipt; var r1: Dictionary = new_entry.source_native_stack_receipt
			check(r0.schema == r1.schema and r0.issued_physical_id == r1.issued_physical_id and r0.item_class_id == r1.item_class_id and r0.bless_raw == r1.bless_raw and r0.granted_quantity == r1.granted_quantity, "%s receipt identity/quantity kept" % uid.left(4))
	for key: String in ["gold","inventory","equipped_items","ui_preferences"]:
		check(save[key] == before[key], "%s unchanged" % key)
	check(save.warehouse.stacks == before.warehouse.stacks and save.consumable_state.elixirs_used == 3, "warehouse counts and other consumable state kept")
	check(FIELDS.full(a).get("source_original_item",{}) is Dictionary, "full() on a trimmed receipt asks the definition store")
	# Idempotent, and cheap when nothing is left to trim.
	var again: Dictionary = save.duplicate(true)
	TRIM.loaded_save(again)
	check(again == save, "second trim changes nothing")
	var clean: Dictionary = TRIM.payload(save)
	check(is_same(clean, save) and is_same(TRIM.entries(save.item_instances), save.item_instances) and is_same(TRIM.consumables(save.consumable_state), save.consumable_state), "an already trimmed payload is returned as is (no copy per save)")
	check(TRIM.receipt({"schema":1,"item_class_id":"x","source_original_item":{"a":1},"origin":{"kind":"k"}}).has("source_original_item"), "a receipt without an integer ItemClass ID keeps its row copy")

func counts(world: Node) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in world.inventory:
		if int(world.inventory[key]) != 0: result[str(key)] = int(world.inventory[key])
	return result

## Owned state independent of bag stacking (native_stack_merge may fold equal
## stacks on load): stack totals per item/bless/enchant, equipment per ID.
func physical(world: Node) -> Dictionary:
	var result: Dictionary = {}
	for uid: String in world.item_instances:
		var entry: Dictionary = world.item_instances[uid]
		var bless: int = int(entry.get("record",{}).get("source_bless_raw",0))
		if entry.has(STACK.RECEIPT):
			var key: String = "stack|%s|%d|%d" % [str(entry.get("name")), bless, int(entry.get("level",0))]
			result[key] = int(result.get(key,0)) + int(entry.get("source_native_stack_quantity",1))
		else:
			result["piece|"+uid] = "%s|%d|%s|%d|%s|%d" % [str(entry.get("name")), int(entry.get("level",0)), str(entry.get("element","")), int(entry.get("element_level",0)), str(entry.get("bless_state","")), bless]
	return result

func grant(world: Node, id: int, amount: int) -> bool:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [id, str(staged.get("error",""))]): return false
	if not check(world._save_game(true,staged.overrides) == OK, "grant #%d save" % id): return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return true

## Rewrites every receipt copy and record in a written save into the shape the
## game wrote before this change (row/archive copies, drop proof, floor id).
func age(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[key] = age(value[key])
		if out.get(FIELDS.MARK) == true and out.has("issued_physical_id"):
			out.erase(FIELDS.MARK); out.erase("source_item_class_id")
			out["source_original_item"] = SOURCE.row("ItemClass", int(out.item_class_id))
			out["source_definition_archive"] = SOURCE.identity()
			if out.get("origin",{}).get("kind") not in TRIM.STRUCTURAL: out["origin"] = {"kind":str(out.origin.kind),"floor_id":"old-floor","drop":PROOF.duplicate(true)}
		if out.has("source_m_native_item") and out.has("source_item_class_id") and not out.has(FIELDS.MARK) and out.has("name"): out["source_m_drop_proof"] = PROOF.duplicate(true)
		return out
	if value is Array:
		var list: Array = []
		for item: Variant in value: list.append(age(item))
		return list
	return value

func reload(world: Node) -> void:
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)

## user:// is shared by CI tests: put every save file back as it was.
var _prior_files: Dictionary = {}
func remember_user_files() -> void:
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save"): _prior_files[name] = FileAccess.get_file_as_bytes(directory.path_join(name))
func restore_user_files() -> void:
	var directory: String = ProjectSettings.globalize_path("user://")
	for name: String in DirAccess.get_files_at(directory):
		if name.begins_with("twilight_v20_save") and not _prior_files.has(name): DirAccess.remove_absolute(directory.path_join(name))
	for name: String in _prior_files:
		var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
		if file != null: file.store_buffer(_prior_files[name]); file.close()

func runtime() -> void:
	remember_user_files()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	check(world._save_game(true) == OK, "clean bag save")
	for index: int in range(2): grant(world, LEATHER, 3)
	grant(world, POTION, 4); grant(world, ARMOR, 1)
	var potion_id: String = ""
	for uid: String in world.item_instances:
		if world.item_instances[uid].get("name") == D.variant_item(D.definition_id(str(POTION)).get("native_record",{}),1).get("name"): potion_id = uid
	var owned: Dictionary = STACK.proof(world, potion_id)
	var debit: Dictionary = STACK.stage_debit(world,[{"physical_id":potion_id,"quantity":1,"expected_quantity":owned.get("remaining",0),"expected_remaining":int(owned.get("remaining",0))-1,"source_native_stack_receipt":owned.get("receipt",{})}])
	if check(debit.get("ok",false), "a use-ledger row: %s" % str(debit.get("reason",""))):
		check(world._save_game(true,debit.overrides) == OK, "debit save")
		world.inventory = debit.overrides.inventory; world.item_instances = debit.overrides.item_instances; world.consumable_service.import_state(debit.overrides.consumable_state)
	check(world._save_game(true) == OK, "current-shape save")
	var path: String = world.save_path()
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var old: Dictionary = age(current)
	old.consumable_state["source_ground_acquisitions"] = {"old-floor":{"schema":1,"source_npc_id":45,"source_row_ids":[9001],"drop_proof_sha256":"00"}}
	var old_text: String = JSON.stringify(old)
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(old_text); file.close()
	check(old_text.contains("source_m_drop_proof") and old_text.contains("MaxStackAmount"), "seeded the old shape (drop proofs, receipt row copies)")
	var before_counts: Dictionary = counts(world); var before_physical: Dictionary = physical(world)
	var before_gold: int = world.gold; var before_weight: int = world._inventory_total_weight()
	var before_locks: Dictionary = world.ui_preferences.get("item_locks",{}).duplicate(true)
	var before_equipped: Variant = world.equipped_items.duplicate(true)
	var before_ledger: Dictionary = {}
	for uid: String in world.consumable_service.export_state().get(STACK.USES,{}):
		var row: Dictionary = world.consumable_service.export_state()[STACK.USES][uid]
		before_ledger[uid] = [row.used_quantity, row.remaining_quantity]
	reload(world)
	evidence["owner_problem"] = world.patch523_owner_state_problem
	check(world.patch523_owner_state_problem.is_empty() and not world.source_item_save_blocked, "old save loads without an ownership problem")
	evidence["physical"] = {"before":before_physical,"after":physical(world)}
	check(counts(world) == before_counts and physical(world) == before_physical, "bag counts and every physical entry (qty/enchant/element/bless) unchanged")
	check(world.gold == before_gold and world._inventory_total_weight() == before_weight and world.ui_preferences.get("item_locks",{}) == before_locks and world.equipped_items == before_equipped, "gold, weight, locks and equipment unchanged")
	var after_ledger: Dictionary = {}
	for uid: String in world.consumable_service.export_state().get(STACK.USES,{}):
		var row: Dictionary = world.consumable_service.export_state()[STACK.USES][uid]
		after_ledger[uid] = [row.used_quantity, row.remaining_quantity]
	check(after_ledger == before_ledger and not after_ledger.is_empty(), "use ledger quantities unchanged")
	check(STACK.state_error(world.inventory,world.item_instances,world.consumable_service.export_state(),world.warehouse.snapshot(),world._ground_drops_snapshot(),world.dormant_character_items()).is_empty(), "trimmed ownership validates")
	for uid: String in world.item_instances:
		if world.item_instances[uid].has(STACK.RECEIPT): check(not STACK.proof(world, uid).is_empty(), "proof of %s" % uid.left(6))
	check(world._save_game(true) == OK, "re-save after migration")
	var migrated: String = FileAccess.get_file_as_string(path)
	evidence["bytes"] = {"old":old_text.to_utf8_buffer().size(),"migrated":migrated.to_utf8_buffer().size()}
	check(migrated.to_utf8_buffer().size() < old_text.to_utf8_buffer().size() and not migrated.contains("source_m_drop_proof") and not migrated.contains("source_ground_acquisitions") and not migrated.contains("drop_proof_sha256"), "migrated save is smaller and has no acquisition history (%s)" % str(evidence.bytes))
	var first_sha: String = FileAccess.get_sha256(path)
	for round: int in range(2):
		reload(world)
		check(world._save_game(true) == OK, "save after reload %d" % round)
	check(counts(world) == before_counts and physical(world) == before_physical, "save -> load repeated keeps the bag")
	evidence["stable_sha"] = [first_sha, FileAccess.get_sha256(path)]
	# A new floor pickup of an original material stores no drop rows/monster.
	var entry: Dictionary = {}
	for row: Dictionary in SOURCE.related("NpcItemDropView","ItemClassID",LEATHER):
		var npc: Dictionary = SOURCE.row("NpcClass",int(row.get("NpcClassID",0)))
		if npc.is_empty(): continue
		D._current_source_document({"source_input_identity":SOURCE.identity(),"current_source_admitted":true,"source_npc_id":int(npc.ID),"source_sprite_id":npc.get("Sprite"),"source_desc_id":npc.get("DescId"),"source_name":npc.get("Name")})
		var document: Dictionary = D.data()
		for drop: Variant in document.get("drops",{}).get(str(int(npc.ID)),[]):
			if not drop is Dictionary or int(drop.get("ItemClassID",0)) != LEATHER or int(drop.get("Bless",0)) != 1 or int(drop.get("RequiredQuestID",-1)) != 0: continue
			var item: Dictionary = D.variant_item(D.definition_id(str(LEATHER)).get("native_record",{}),1)
			item["source_m_item_id"] = LEATHER; item["bless_state"] = "normal"
			var proof: Dictionary = {"source_snapshot":"patch523","source_npc_id":int(npc.ID),"source_item_class_id":LEATHER,"bless_raw":1,"bless_state":"normal","required_quest_id":0,"source_rows":[drop.duplicate(true)],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}
			item["source_m_drop_proof"] = proof
			if ACQUIRE._proof_problem(item,proof,1).is_empty(): entry = {"item_name":str(item.name),"quantity":1,"item_record":item,"source_m_drop_proof":proof}
			break
		if not entry.is_empty(): break
	if check(not entry.is_empty(), "an original 가죽 drop row"):
		for frame: int in range(20): await process_frame
		var view: Button = world._spawn_ground_drop(str(entry.item_name), world.player.global_position, 1, "", D.ground_metadata(entry))
		var id: String = str(view.get_meta("id"))
		for step: int in range(60):
			await process_frame
			view = world.ground_loot.views.get(id)
			if is_instance_valid(view) and Time.get_ticks_msec()-int(view.get("visible_since")) >= world.ground_loot.MIN_VISIBLE_MS+20: break
			await create_timer(0.05).timeout
		var started: int = Time.get_ticks_usec()
		check(is_instance_valid(view) and world._collect_ground_drop(view), "actual floor pickup")
		evidence["pickup_usec"] = Time.get_ticks_usec()-started
		var text: String = FileAccess.get_file_as_string(path)
		check(not text.contains("source_m_drop_proof") and not text.contains("source_rows") and not text.contains("source_ground_acquisitions"), "pickup saves no monster/drop rows or floor receipt")
		check(int(world.inventory.get(str(entry.item_name),0)) == int(before_counts.get(str(entry.item_name),0))+1, "picked item counted once")
		reload(world)
		check(world.patch523_owner_state_problem.is_empty() and int(world.inventory.get(str(entry.item_name),0)) == int(before_counts.get(str(entry.item_name),0))+1, "pickup survives reload")
	world.queue_free()
	await process_frame
	restore_user_files()

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		await runtime()
	print("SAVE_PROVENANCE_TRIM_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
