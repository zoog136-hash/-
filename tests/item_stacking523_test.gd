extends SceneTree
## Bag stacking (scripts/loot/native_stack_merge.gd, user request 2026-11-17).
## Synthetic receipt-shape rules always run. With the original definition ZIP,
## actual Main: separate receipted stacks from an old save fold into one slot
## on load (counts, weight, receipts, use ledger kept); repeated floor pickups
## of one original material end in one slot; potions/scrolls stack; equipment
## stays per instance; the original MaxStackAmount caps a stack; the same item
## picked up from different monsters and granted by the shop/quest path still
## ends in one slot (2026-11-19 regression: 공성 포인트 2·1·8·2, 가죽 4·2); a floor
## drop/re-pickup (partition) and a later use still save and reload.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const MERGE = preload("res://scripts/loot/native_stack_merge.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const ACQUIRE = preload("res://scripts/loot/source523_ground_acquisition.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const LEATHER := 366 ## [재료] 가죽, MaxStackAmount 10000
const HALPAS := 767 ## [재료] 할파스의 집념 (red flame icon), MaxStackAmount 10000
const SIEGE_POINT := 195371 ## [화폐] 공성 포인트: the silver coin of the 2026-11-19 recording (Item/siege_point.png)
const POTION := 237 ## [물약-회복] 고급 체력 회복제 (각인)
const SCROLL := 313 ## [주문서-이동] 순간이동 주문서 (각인)
const ARMOR := 377 ## [방어구-갑옷] 징박힌 가죽 갑옷, MaxStackAmount 1
const FINE_LEATHER := 3642 ## [재료] 고급 가죽: another item ID, never merged with 가죽
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEM_STACKING523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var good: Dictionary = {"granted_quantity":3,"origin":{"kind":"owned_quantity_merge","merge_id":"0123456789abcdef0123456789abcdef","components":[{"physical_id":"a","quantity":1},{"physical_id":"b","quantity":2}]}}
	check(MERGE.receipt_shape_valid(good), "a merge receipt whose parts add up is well formed")
	var wrong: Dictionary = good.duplicate(true); wrong.granted_quantity = 4
	check(not MERGE.receipt_shape_valid(wrong), "parts must add up to the granted quantity")
	var twice: Dictionary = good.duplicate(true); twice.origin.components[1].physical_id = "a"
	check(not MERGE.receipt_shape_valid(twice), "one physical ID may not be absorbed twice")
	check(MERGE.max_stack({"source_original_item":{"MaxStackAmount":10000.0}}) == 10000, "original MaxStackAmount is the cap")
	check(MERGE.max_stack({"source_original_item":{}}) == MERGE.APPROX_MAX_STACK, "TWILIGHT 근사 cap when the row has no MaxStackAmount")
	check(not MERGE.plan({}, {}, {}).get("changed", true), "an empty bag plans nothing")
	check(MERGE.merges_error({}, {}, {}, {}).is_empty(), "no journal is valid")
	var a: Dictionary = {"name":"x","level":0,"record":{"slot":"material","source_item_class_id":1,"source_m_drop_proof":{"source_npc_id":1}}}
	var b: Dictionary = {"name":"x","level":0,"record":{"slot":"material","source_item_class_id":1,"source_m_drop_proof":{"source_npc_id":2}}}
	var c: Dictionary = {"name":"x","level":0,"record":{"slot":"material","source_item_class_id":1,"source_m_reward_proof":{"quest":3}}}
	check(MERGE.stack_identity(a) == MERGE.stack_identity(b) and MERGE.stack_identity(a) == MERGE.stack_identity(c), "drop/reward provenance (which monster or reward) does not split a stack")
	var loaded: Dictionary = a.duplicate(true); loaded.level = 0.0; loaded.record.source_item_class_id = 1.0
	check(MERGE.stack_identity(a) == MERGE.stack_identity(loaded), "a stack read back from the save (JSON 1.0) matches a fresh grant (1)")
	var d: Dictionary = a.duplicate(true); d.record["source_delete_time"] = 60
	var e: Dictionary = a.duplicate(true); e["element"] = "fire"
	check(MERGE.stack_identity(a) != MERGE.stack_identity(d) and MERGE.stack_identity(a) != MERGE.stack_identity(e), "any other record or instance field still keeps stacks apart")

func counts(world: Node) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in world.inventory:
		if int(world.inventory[key]) != 0: result[str(key)] = int(world.inventory[key])
	return result

func diff(left: Dictionary, right: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in left.keys() + right.keys():
		if left.get(key) != right.get(key): result[key] = [left.get(key), right.get(key)]
	return result

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func slots(world: Node, id: int) -> Array:
	var name_value: String = str(record(id).name)
	var result: Array = []
	for uid: String in world.item_instances:
		var entry: Variant = world.item_instances[uid]
		if entry is Dictionary and entry.get("name") == name_value:
			result.append(int(entry.get("source_native_stack_quantity", 1)))
	return result

func grant(world: Node, id: int, amount: int) -> bool:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [id, str(staged.get("error",""))]): return false
	if not check(world._save_game(true,staged.overrides) == OK, "grant #%d save" % id): return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return true

func reload(world: Node) -> void:
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)

## An unconditional original drop row of a stackable material: #767 when the
## installed drop membership has one, else the first such material.
## Drop membership is read per admitted NPC (as a real kill does); admit the
## original NPCs whose NpcItemDropView rows name this item.
func admit_droppers(id: int) -> void:
	var count: int = 0
	for row: Dictionary in SOURCE.related("NpcItemDropView","ItemClassID",id):
		var npc: Dictionary = SOURCE.row("NpcClass",int(row.get("NpcClassID",0)))
		if npc.is_empty(): continue
		D._current_source_document({"source_input_identity":SOURCE.identity(),"current_source_admitted":true,"source_npc_id":int(npc.ID),"source_sprite_id":npc.get("Sprite"),"source_desc_id":npc.get("DescId"),"source_name":npc.get("Name")})
		count += 1
		if count >= 40: break

func floor_entry(id: int) -> Dictionary:
	admit_droppers(id)
	var found: Dictionary = _floor_entry(id)
	if not found.is_empty(): return found
	var document: Dictionary = D.data()
	var tried: Dictionary = {}
	for npc_key: Variant in document.get("drops",{}):
		for row: Variant in document.drops[npc_key]:
			if not row is Dictionary: continue
			var other: int = int(row.get("ItemClassID",0))
			if tried.has(other): continue
			tried[other] = true
			var item: Dictionary = record(other)
			if item.is_empty() or item.get("slot") != "material" or STACK.supply_profile(item).is_empty() or MERGE.max_stack(item) < 100: continue
			found = _floor_entry(other)
			if not found.is_empty(): return found
	return {}

func _floor_entry(id: int) -> Dictionary:
	var document: Dictionary = D.data()
	var item: Dictionary = record(id)
	if item.is_empty(): return {}
	item["source_m_item_id"] = id; item["bless_state"] = "normal"
	for npc_key: Variant in document.get("drops",{}):
		for row: Variant in document.drops[npc_key]:
			if not row is Dictionary or int(row.get("ItemClassID",0)) != id or int(row.get("Bless",0)) != 1 or int(row.get("RequiredQuestID",-1)) != 0: continue
			var proof: Dictionary = {"source_snapshot":"patch523","source_npc_id":int(npc_key),"source_item_class_id":id,"bless_raw":1,"bless_state":"normal","required_quest_id":0,"source_rows":[row.duplicate(true)],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}
			var candidate: Dictionary = item.duplicate(true); candidate["source_m_drop_proof"] = proof
			if ACQUIRE._proof_problem(candidate,proof,1).is_empty():
				return {"item_name":str(item.name),"quantity":1,"item_record":candidate,"source_m_drop_proof":proof}
	return {}

## Floor drop rows of `id` from up to `limit` different original monsters.
func floor_entries(id: int, limit: int) -> Array:
	admit_droppers(id)
	var document: Dictionary = D.data()
	var item: Dictionary = record(id)
	var found: Array = []
	if item.is_empty(): return found
	item["source_m_item_id"] = id; item["bless_state"] = "normal"
	for npc_key: Variant in document.get("drops",{}):
		for row: Variant in document.drops[npc_key]:
			if not row is Dictionary or int(row.get("ItemClassID",0)) != id or int(row.get("Bless",0)) != 1 or int(row.get("RequiredQuestID",-1)) != 0: continue
			var proof: Dictionary = {"source_snapshot":"patch523","source_npc_id":int(npc_key),"source_item_class_id":id,"bless_raw":1,"bless_state":"normal","required_quest_id":0,"source_rows":[row.duplicate(true)],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}
			var candidate: Dictionary = item.duplicate(true); candidate["source_m_drop_proof"] = proof
			if ACQUIRE._proof_problem(candidate,proof,1).is_empty(): found.append({"item_name":str(item.name),"quantity":1,"item_record":candidate,"source_m_drop_proof":proof})
			break
		if found.size() >= limit: break
	return found

## The bag state a real floor pickup leaves (source523_ground_acquisition
## stages exactly this grant: the drop record with its monster proof), saved.
func floor_grant(world: Node, entry: Dictionary) -> bool:
	var instances: Dictionary = world.item_instances.duplicate(true)
	var staged: Dictionary = STACK.stage_grant(entry.item_record, 1, instances, {"kind":"source523_floor","floor_id":Crypto.new().generate_random_bytes(8).hex_encode(),"drop":entry.source_m_drop_proof.duplicate(true)})
	if not check(staged.get("ok",false), "floor grant staged"): return false
	var inventory: Dictionary = world.inventory.duplicate(true)
	inventory[str(entry.item_name)] = int(inventory.get(str(entry.item_name),0)) + 1
	if not check(world._save_game(true,{"inventory":inventory,"item_instances":staged.item_instances}) == OK, "floor grant save"): return false
	world.inventory = inventory; world.item_instances = staged.item_instances
	return true

## 2026-11-19 recording: the same original item from different monsters (and
## from the shop/quest grant path) sat in separate slots, because each stored
## record carries its own drop proof. Interleaved as in a real hunt.
func mixed_sources(world: Node) -> void:
	var coins: Array = floor_entries(SIEGE_POINT, 3)
	var hides: Array = floor_entries(LEATHER, 2)
	var fine: Array = floor_entries(FINE_LEATHER, 1)
	evidence["mixed_npcs"] = {"siege_point":coins.map(func(e: Dictionary) -> int: return int(e.source_m_drop_proof.source_npc_id)),"leather":hides.map(func(e: Dictionary) -> int: return int(e.source_m_drop_proof.source_npc_id))}
	if not check(coins.size() >= 2 and hides.size() >= 2, "original drop rows of 공성 포인트/가죽 from at least two monsters"): return
	var before_leather: int = int(world.inventory.get(str(record(LEATHER).name),0))
	for entry: Dictionary in [coins[0], coins[0], hides[0], coins[1], hides[1], coins[coins.size()-1], coins[0]]:
		if not floor_grant(world, entry): return
		world._refresh_inventory_hud() # what a pickup publishes
	evidence["mixed_after_pickups"] = {"siege_point":slots(world,SIEGE_POINT),"leather":slots(world,LEATHER)}
	var leather_entries: Array = world.item_instances.values().filter(func(e: Variant) -> bool: return e is Dictionary and e.get("name") == record(LEATHER).name)
	if leather_entries.size() > 1:
		var left: Dictionary = MERGE.stack_identity(leather_entries[0]); var right: Dictionary = MERGE.stack_identity(leather_entries[1])
		var keys: Array = []
		for key: Variant in left.keys() + right.keys():
			if left.get(key) != right.get(key): keys.append(str(key))
		if left.get("record") is Dictionary and right.get("record") is Dictionary:
			for key: Variant in left.record.keys() + right.record.keys():
				if left.record.get(key) != right.record.get(key): keys.append("record." + str(key))
		evidence["leather_identity_diff"] = keys
	check(slots(world,SIEGE_POINT) == [5], "공성 포인트 from %d monsters -> one slot of 5 (%s)" % [coins.size(), str(slots(world,SIEGE_POINT))])
	check(slots(world,LEATHER).size() == 1 and slots(world,LEATHER)[0] == before_leather+2, "가죽 from 2 monsters joins the existing slot (%s)" % str(slots(world,LEATHER)))
	# Shop/quest/debug grants (patch523_item_inventory.stage, no drop proof).
	if grant(world, SIEGE_POINT, 3):
		world._update_hud()
		check(slots(world,SIEGE_POINT) == [8], "a granted (shop/quest path) stack joins the picked-up one (%s)" % str(slots(world,SIEGE_POINT)))
	if not fine.is_empty() and floor_grant(world, fine[0]):
		world._refresh_inventory_hud()
		check(slots(world,FINE_LEATHER).size() == 1 and slots(world,LEATHER).size() == 1, "고급 가죽 (another ID) never joins 가죽 (%s / %s)" % [str(slots(world,FINE_LEATHER)), str(slots(world,LEATHER))])
	check(world.patch523_owner_state_problem.is_empty() and STACK.state_error(world.inventory,world.item_instances,world.consumable_service.export_state(),world.warehouse.snapshot(),world._ground_drops_snapshot(),world.dormant_character_items()).is_empty(), "mixed-source merge validates")
	check(world._save_game(true) == OK, "mixed-source save")
	reload(world)
	check(slots(world,SIEGE_POINT) == [8] and slots(world,LEATHER).size() == 1, "mixed-source stacks survive a reload (%s / %s)" % [str(slots(world,SIEGE_POINT)), str(slots(world,LEATHER))])

func pick_up(world: Node, entry: Dictionary) -> bool:
	var spawned: Button = world._spawn_ground_drop(str(entry.item_name), world.player.global_position, 1, "", D.ground_metadata(entry))
	if not check(is_instance_valid(spawned), "floor drop spawned"): return false
	var collected: bool = await collect_id(world, str(spawned.get_meta("id")))
	return check(collected, "actual Main floor pickup")

## The existing pickup action on a live floor view: stand on it and respect
## its minimum visible lifetime (views can be re-created, so look it up by id).
func collect_id(world: Node, id: String) -> bool:
	var view: Button = null
	for step: int in range(80):
		await process_frame
		view = world.ground_loot.views.get(id)
		if is_instance_valid(view) and Time.get_ticks_msec() - int(view.get("visible_since")) >= world.ground_loot.MIN_VISIBLE_MS + 20: break
		await create_timer(0.05).timeout
	var floor: Dictionary = world.ground_loot.records.get(id, {})
	if not is_instance_valid(view) or floor.is_empty():
		evidence["pickup_problem_"+id] = "no live view"
		return false
	world.player.global_position = Vector2(float(floor.position[0]), float(floor.position[1]))
	var ok: bool = world._collect_ground_drop(view)
	if not ok: evidence["pickup_problem_"+id] = {"since_ms":Time.get_ticks_msec()-int(view.get("visible_since")),"on_floor":world.ground_loot.records.has(id)}
	return ok

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	# CI Core tests share user://: put back whatever save this test found.
	var save_file: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_file)
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_file) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	check(world._save_game(true) == OK, "clean bag save")
	# Old save shape: one receipted stack per grant (as the bag showed it).
	for index: int in range(3):
		if not grant(world, LEATHER, 2): break
	for index: int in range(3):
		if not grant(world, POTION, 2): break
	for index: int in range(2):
		if not grant(world, SCROLL, 5): break
	for index: int in range(2):
		if not grant(world, ARMOR, 1): break
	if not grant(world, FINE_LEATHER, 2): pass
	evidence["old_save_slots"] = {"leather":slots(world,LEATHER),"potion":slots(world,POTION),"scroll":slots(world,SCROLL),"armor":slots(world,ARMOR)}
	check(slots(world,LEATHER).size() == 3 and slots(world,POTION).size() == 3 and slots(world,SCROLL).size() == 2, "old shape: one slot per grant")
	# One split stack is partly used (use-ledger row) before the merge.
	var leather_ids: Array = []
	for uid: String in world.item_instances:
		if world.item_instances[uid].get("name") == record(LEATHER).name: leather_ids.append(uid)
	var used_id: String = str(leather_ids[1])
	var owned: Dictionary = STACK.proof(world,used_id)
	var debit: Dictionary = STACK.stage_debit(world,[{"physical_id":used_id,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}])
	check(debit.get("ok",false), "debit staged: %s" % str(debit.get("reason",debit.get("error",""))))
	if debit.get("ok",false):
		check(world._save_game(true,debit.overrides) == OK, "debit save")
		world.inventory = debit.overrides.inventory; world.item_instances = debit.overrides.item_instances; world.consumable_service.import_state(debit.overrides.consumable_state)
	var potion_ids: Array = []
	for uid: String in world.item_instances:
		if world.item_instances[uid].get("name") == record(POTION).name: potion_ids.append(uid)
	var potion_owned: Dictionary = STACK.proof(world,str(potion_ids[1]))
	var potion_debit: Dictionary = STACK.stage_debit(world,[{"physical_id":str(potion_ids[1]),"quantity":1,"expected_quantity":potion_owned.remaining,"expected_remaining":int(potion_owned.remaining)-1,"source_native_stack_receipt":potion_owned.receipt}])
	if check(potion_debit.get("ok",false), "potion debit staged"):
		check(world._save_game(true,potion_debit.overrides) == OK, "potion debit save")
		world.inventory = potion_debit.overrides.inventory; world.item_instances = potion_debit.overrides.item_instances; world.consumable_service.import_state(potion_debit.overrides.consumable_state)
	world.ui_preferences.item_locks[str(record(SCROLL).name)+"@@@"+str(world.item_instances.keys().filter(func(id: String) -> bool: return world.item_instances[id].get("name")==record(SCROLL).name)[1])] = true
	var counts_before: Dictionary = counts(world)
	var weight_before: int = world._inventory_total_weight()
	var ledger_before: Dictionary = world.consumable_service.export_state().get(STACK.USES,{}).duplicate(true)
	var receipts_before: Dictionary = {}
	for uid: String in world.item_instances:
		if world.item_instances[uid].has(STACK.RECEIPT): receipts_before[uid] = world.item_instances[uid][STACK.RECEIPT].duplicate(true)
	check(world._save_game(true) == OK, "old-shape save")
	reload(world)
	var after_load: Dictionary = {"leather":slots(world,LEATHER),"potion":slots(world,POTION),"scroll":slots(world,SCROLL),"armor":slots(world,ARMOR)}
	evidence["after_load_slots"] = after_load
	check(after_load.leather == [5], "3 leather grants of 2 (1 used) -> one slot of 5")
	check(after_load.potion == [5], "3 potion grants of 2 (1 used) -> one slot of 5")
	check(after_load.scroll == [10], "2 scroll grants of 5 -> one slot of 10")
	check(after_load.armor == [1,1], "2 pieces of the same equipment item ID stay 2 separate instances")
	var armor_ids: Array = world.item_instances.keys().filter(func(id: String) -> bool: return world.item_instances[id].get("name")==record(ARMOR).name)
	check(armor_ids.size() == 2 and armor_ids[0] != armor_ids[1], "each equipment piece keeps its own physical ID")
	check(slots(world,FINE_LEATHER) == [2] and record(FINE_LEATHER).name != record(LEATHER).name, "a different item ID (고급 가죽) never merges into 가죽")
	var foreign: Dictionary = MERGE.plan({"a":{"name":"x","level":0,"record":{"slot":"weapon"},"source_native_stack_receipt":{}},"b":{"name":"x","level":0,"record":{"slot":"weapon"},"source_native_stack_receipt":{}}},{},{})
	check(not foreign.get("changed",true), "unproven/equipment-shaped entries are never merged")
	evidence["count_diff_after_load"] = diff(counts_before, counts(world))
	check(diff(counts_before, counts(world)).is_empty(), "bag counts unchanged by the merge")
	check(world._inventory_total_weight() == weight_before, "carried weight unchanged (%d)" % weight_before)
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem after merge: " + world.patch523_owner_state_problem)
	var journal: Dictionary = world.consumable_service.export_state().get(MERGE.MERGES,{})
	var kept: Dictionary = {}
	for event: Dictionary in journal.values():
		for component: Dictionary in event.components: kept[component.physical_id] = component
	var all_kept: bool = true
	for uid: String in receipts_before:
		if world.item_instances.has(uid) and world.item_instances[uid][STACK.RECEIPT] == receipts_before[uid]: continue
		if not kept.has(uid) or kept[uid].receipt != receipts_before[uid]: all_kept = false
	check(all_kept, "every absorbed stack's original receipt is kept in the merge journal")
	check(kept.has(used_id) and int(kept[used_id].used_quantity) == 1 and int(kept[used_id].remaining_quantity) == 1, "the used stack's history (used 1, remaining 1) is in the journal")
	var used_rows: int = 0
	for uid: String in ledger_before:
		if kept.has(uid) and int(kept[uid].used_quantity) == int(ledger_before[uid].used_quantity): used_rows += 1
	check(used_rows == ledger_before.size(), "every prior use-ledger row moved into the journal with its used quantity (%d/%d)" % [used_rows, ledger_before.size()])
	var scroll_uid: String = ""
	for uid: String in world.item_instances:
		if world.item_instances[uid].get("name") == record(SCROLL).name: scroll_uid = uid
	check(world._item_locked(str(record(SCROLL).name), scroll_uid), "a locked member keeps the merged stack locked")
	evidence["journal_events"] = journal.size()
	check(STACK.state_error(world.inventory,world.item_instances,world.consumable_service.export_state(),world.warehouse.snapshot(),world._ground_drops_snapshot(),world.dormant_character_items()).is_empty(), "merged state validates")
	check(world._save_game(true) == OK, "merged save")
	reload(world)
	check(slots(world,LEATHER) == [5] and slots(world,POTION) == [5] and slots(world,SCROLL) == [10] and diff(counts_before, counts(world)).is_empty(), "merged stacks survive another reload")
	# Floor pickups of one original material end in one slot. Let the reload's
	# deferred map/floor restoration settle first.
	for frame: int in range(30): await process_frame
	var entry: Dictionary = floor_entry(HALPAS)
	if entry.is_empty():
		var document: Dictionary = D.data()
		var sample: Dictionary = {"drop_npcs":document.get("drops",{}).size(),"npcs":document.get("npcs",{}).size(),"pack":D.pack_identity().get("schema")}
		for npc_key: Variant in document.get("drops",{}):
			var rows: Array = document.drops[npc_key]
			if rows.is_empty(): continue
			sample["npc_key"] = str(npc_key); sample["row"] = rows[0]; sample["npc"] = document.get("npcs",{}).get(str(npc_key),{}).keys()
			var id: int = int(rows[0].get("ItemClassID",0)); var item: Dictionary = record(id); item["source_m_item_id"] = id
			var proof: Dictionary = {"source_snapshot":"patch523","source_npc_id":int(npc_key),"source_item_class_id":id,"bless_raw":int(rows[0].get("Bless",0)),"required_quest_id":0,"source_rows":[rows[0]],"selection_policy":"host_uniform_distinct_items_then_distinct_variants","quantity_policy":"host_one"}
			item["source_bless_raw"] = item.get("source_bless_raw")
			sample["problem"] = ACQUIRE._proof_problem(item,proof,1)
			break
		evidence["floor_debug"] = sample
	if check(not entry.is_empty(), "an unconditional original drop row of a stackable material"):
		var dropped_id: int = int(entry.item_record.source_item_class_id)
		evidence["floor_item"] = {"id":dropped_id,"name":str(entry.item_name),"npc":int(entry.source_m_drop_proof.source_npc_id)}
		var seen: Array = []
		for index: int in range(4):
			if not await pick_up(world, entry): break
			seen.append(slots(world,dropped_id))
		evidence["floor_pickups"] = seen
		check(seen == [[1],[2],[3],[4]], "4 floor pickups -> one slot growing 1..4")
	# Drop one leather to the floor (partition) and pick it back up.
	var leather_uid: String = ""
	for uid: String in world.item_instances:
		if world.item_instances[uid].get("name") == record(LEATHER).name: leather_uid = uid
	var dropped: Dictionary = STACK.drop(world, str(record(LEATHER).name)+"@@@"+leather_uid, world.player.global_position)
	if check(dropped.get("ok",false), "drop 1 leather: %s" % str(dropped.get("reason",""))):
		check(slots(world,LEATHER) == [4], "4 leather left in the bag")
		var floor_id: String = ""
		for id: String in world.ground_loot.records:
			if world.ground_loot.records[id].get("item_name") == record(LEATHER).name: floor_id = id
		check(await collect_id(world, floor_id), "re-pickup of the dropped leather (%s)" % str(evidence.get("pickup_problem_"+floor_id,"")))
		check(slots(world,LEATHER) == [5], "re-picked leather merges back into one slot of 5 (%s)" % str(slots(world,LEATHER)))
	mixed_sources(world)
	# Original MaxStackAmount caps one stack.
	if grant(world, HALPAS, 9999) and grant(world, HALPAS, 3) and grant(world, HALPAS, 1):
		world._update_hud()
		evidence["cap_slots"] = slots(world,HALPAS)
		# Floor pickups left one slot of 4; 4+9999 would pass 10000, so 9999 keeps
		# its own slot (stacks are never split) and 3+1 fold into the next one.
		check(slots(world,HALPAS) == [4,9999,4], "MaxStackAmount 10000 caps a slot; 3+1 stack in the next slot (%s)" % str(slots(world,HALPAS)))
		check(slots(world,HALPAS).all(func(amount: int) -> bool: return amount <= 10000) and int(world.inventory.get(str(record(HALPAS).name),0)) == 4+9999+3+1, "no slot passes the original cap and the total is kept")
	var final_counts: Dictionary = counts(world)
	check(world._save_game(true) == OK, "final save")
	reload(world)
	evidence["final_slots"] = {"leather":slots(world,LEATHER),"potion":slots(world,POTION),"scroll":slots(world,SCROLL),"armor":slots(world,ARMOR),"halpas":slots(world,HALPAS)}
	evidence["count_diff_final"] = diff(final_counts, counts(world))
	check(diff(final_counts, counts(world)).is_empty() and world.patch523_owner_state_problem.is_empty(), "final reload keeps counts and ownership")
	world.queue_free()
	await process_frame
	if had_save:
		var restore := FileAccess.open(save_file, FileAccess.WRITE)
		if restore != null: restore.store_buffer(saved_bytes); restore.close()
	elif FileAccess.file_exists(save_file): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		await runtime()
	print("ITEM_STACKING523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
