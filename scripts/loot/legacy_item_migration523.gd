extends RefCounted
## Save migration: pre-November TWILIGHT items -> original 523 items.
##
## User decision 2026-11-13: when a save is loaded, each legacy item (an owned
## name without the " · 원본#<ItemClassID>" identity) is replaced by the 523
## original item whose name is exactly the same. Amount, enchant level,
## bless/attribute state and the bag / equipped / quickslot / warehouse
## positions are kept. Items with no exact match stay as they are (their slot
## keeps no icon) and are listed in the save marker.
##
## Name rule: the 523 name is the ItemClass description exactly as the game
## shows it (current523_native_item_projection.label(): strip_edges()). Only
## whitespace is normalised (trimmed, inner runs -> one space). "(각인)" is
## NOT normalised: 523 keeps it as part of distinct items (강철 면갑 #551 and
## 강철 면갑 (각인) #4901 are different ItemClass rows).
## One exact name can belong to several registered 523 rows: the smallest
## ItemClass ID is used (user decision 2026-11-13).
## A legacy item with no 523 item of exactly the same name is deleted from the
## bag, warehouse, equipped slots and quickslots (user decision 2026-11-13);
## each deletion (name, amount, where) is listed in the marker and the loaded
## file stays in the byte-for-byte backup, so it can be restored. 523 items,
## wallets/currencies, the current TWILIGHT growth stacks / card draw tickets
## and other-snapshot (base508) records are never deleted.
##
## Every replacement goes through the ordinary 523 grant path
## (patch523_item_inventory.stage) on an isolated scratch owner, so each new
## stack/equipment carries the same physical receipt a new grant carries.
## The migration is versioned (KEY/SCHEMA in the save), runs once, never on a
## save that already has the marker, and keeps the loaded save file byte for
## byte as <save>.pre-legacy523-items-<sha256> before anything is changed.
const PATCH523_ITEMS = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE523_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const REGIONAL_RETURN = preload("res://scripts/quickslots/regional_return.gd")
const KEY: String = "legacy_item_migration523"
## 1: exact-name replacement (#455). 2: + smallest ID for shared names and
## deletion of unmatched legacy items; a schema-1 save gets one schema-2 pass.
const SCHEMA: int = 2
const ORIGIN: Dictionary = {"kind":"twilight_legacy_item_migration523","schema":1}
const BACKUP_SUFFIX: String = ".pre-legacy523-items-"
## Owned keys the current game itself keeps without a 523 identity: wallets
## (다이아, 마일리지, coins), the TWILIGHT growth stacks and the card draw
## tickets. They are never renamed or deleted.
const SYSTEM_KEYS: Array[String] = ["다이아", "아데나", "마일리지", "수호석", "축복의 열쇠"]
const CURRENCY = preload("res://scripts/loot/currency_drops.gd")
const CARD_PACKS = preload("res://scripts/card_pack_items.gd")
const LIST_LIMIT: int = 400

## Minimal owner for one isolated grant: patch523_item_inventory.stage reads
## only these members, so each result holds exactly the granted item.
class GrantScratch extends Node:
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var gold: int = 0
	var host: Node
	func _catalog_item_from_source_id(source_id: String) -> Dictionary:
		return host._catalog_item_from_source_id(source_id)

static func normalize(name_value: String) -> String:
	var parts: PackedStringArray = name_value.strip_edges().split(" ", false)
	var words: PackedStringArray = []
	for part: String in parts:
		var word: String = part.strip_edges()
		if not word.is_empty(): words.append(word)
	return " ".join(words)

static func done(marker: Variant) -> bool:
	return marker is Dictionary and typeof(marker.get("schema")) in [TYPE_INT, TYPE_FLOAT] and int(marker.schema) >= SCHEMA

static func _id_suffix(name_value: String) -> int:
	var at: int = name_value.rfind(" · 원본#")
	if at < 0: return -1
	var digits: String = name_value.substr(at + 6)
	return int(digits) if digits.is_valid_int() and str(int(digits)) == digits and int(digits) > 0 else -1

## Exact-name index of the 523 items the game has registered:
## normalized display name -> Array of ItemClass IDs (ascending).
static func name_index(world: Node) -> Dictionary:
	var index: Dictionary = {}
	var by_id: Variant = world.get("catalog_item_by_source_id")
	if not by_id is Dictionary: return index
	for raw_key: Variant in by_id:
		var key: String = str(raw_key)
		if not key.begins_with("m523:item:"): continue
		var digits: String = key.substr(10)
		if not digits.is_valid_int() or str(int(digits)) != digits: continue
		var record: Variant = by_id[raw_key]
		if not record is Dictionary or record.get("source_m_native_item") != true or record.get("source_test_item", false) == true: continue
		var id: int = int(digits)
		var name_value: String = str(record.get("name", ""))
		if _id_suffix(name_value) != id: continue
		var display: String = normalize(name_value.substr(0, name_value.rfind(" · 원본#")))
		if display.is_empty(): continue
		if not index.has(display): index[display] = []
		index[display].append(id)
	for display: Variant in index: index[display].sort()
	return index

## True for an owned key that is a pre-November TWILIGHT item: no 523
## identity in its name or catalog record, and no 523 icon route.
static func is_legacy(world: Node, name_value: String) -> bool:
	if name_value.is_empty() or name_value in SYSTEM_KEYS or _id_suffix(name_value) > 0: return false
	if name_value.begins_with("[원본") or name_value.begins_with("TWILIGHT · "): return false
	if name_value in CURRENCY.CURRENCY_NAMES or CURRENCY.NAME_ALIASES.has(name_value) or CARD_PACKS.is_pack(name_value): return false
	var record: Dictionary = world._find_catalog_item_record(name_value)
	if str(record.get("slot", "")) == "currency": return false
	if record.get("source_m_native_item", false) or str(record.get("source_snapshot", "")) == "patch523": return false
	if not record.is_empty() and SOURCE523_IMAGES.handles_item(record): return false
	return true

## A legacy key with no same-name 523 item is deleted unless it belongs to
## another snapshot (e.g. base508 records), which stays and is listed.
static func deletable(world: Node, name_value: String) -> bool:
	if not is_legacy(world, name_value): return false
	var record: Dictionary = world._find_catalog_item_record(name_value)
	return not record.get("source_m_native_item", false) and str(record.get("source_snapshot", "")).is_empty()

## {"id":int, "rule":String} for an exact match, else {"reason", "candidates"}.
static func resolve(world: Node, index: Dictionary, name_value: String) -> Dictionary:
	var candidates: Array = index.get(normalize(name_value), [])
	if candidates.size() == 1: return {"id":int(candidates[0]), "rule":"exact_name"}
	if candidates.is_empty(): return {"reason":"no_exact_523_name", "candidates":[]}
	# Candidates are sorted ascending (name_index).
	return {"id":int(candidates[0]), "rule":"exact_name_smallest_id", "candidates":candidates.slice(0, 12)}

static func _bless_raw(physical: Dictionary) -> int:
	var state: String = str(physical.get("bless_state", "")).to_lower()
	if state in ["cursed", "저주"] or bool(physical.get("cursed", false)): return 3
	if state in ["blessed", "축복"] or bool(physical.get("blessed", false)): return 2
	return 1

## One isolated original grant: {"ok", "inventory", "item_instances", "gold"} or {"ok":false,"error"}.
static func _grant(world: Node, id: int, amount: int, bless: int, enchant: int) -> Dictionary:
	var scratch := GrantScratch.new()
	scratch.host = world
	var staged: Dictionary = PATCH523_ITEMS.stage(scratch, [{"item_class_id":id, "amount":amount, "bless_raw":bless, "enchant":enchant}], ORIGIN)
	scratch.free()
	if not staged.get("ok", false): return {"ok":false, "error":str(staged.get("error", "원본 지급 실패"))}
	var result: Dictionary = staged.overrides.duplicate(true)
	result["ok"] = true
	return result

static func _do_grant(grant: Callable, world: Node, id: int, amount: int, bless: int, enchant: int) -> Dictionary:
	return grant.call(world, id, amount, bless, enchant) if grant.is_valid() else _grant(world, id, amount, bless, enchant)

static func _ids_named(instances: Dictionary, name_value: String) -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in instances:
		var entry: Variant = instances[raw]
		if entry is Dictionary and str(entry.get("name", "")) == name_value: ids.append(str(raw))
	return ids

## Replaces `old_key` with `new_key` at the same position (acquisition order).
static func _rekey(counts: Dictionary, old_key: String, extra: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw: Variant in counts:
		var key: String = str(raw)
		if key == old_key:
			for added: Variant in extra: result[str(added)] = int(result.get(str(added), 0)) + int(extra[added])
		else:
			result[key] = int(result.get(key, 0)) + int(counts[raw])
	return result

## Migrates one owner (bag or warehouse) in place. `equipped` is the slot map
## for the bag owner and {} for the warehouse.
static func _migrate_owner(world: Node, grant: Callable, index: Dictionary, counts: Dictionary, instances: Dictionary, equipped: Dictionary, where: String, enhancement_levels: Dictionary, report: Dictionary, renamed: Dictionary, deleted: Dictionary) -> Dictionary:
	var gold_gain: int = 0
	# An equipped physical item may be worn with no bag count left.
	var names: Array = counts.keys()
	var worn_only: Dictionary = {}
	for slot: Variant in equipped:
		var worn: Variant = equipped[slot]
		if not worn is Dictionary or worn.is_empty(): continue
		var physical: Variant = instances.get(str(worn.get("instance_id", "")))
		if physical is Dictionary and not counts.has(str(physical.get("name", ""))) and not str(physical.get("name", "")) in names:
			names.append(str(physical.name)); worn_only[str(physical.name)] = true
	for raw_name: Variant in names:
		var old_name: String = str(raw_name)
		if not (counts.has(old_name) or worn_only.has(old_name)) or not is_legacy(world, old_name): continue
		var amount_value: Variant = counts.get(old_name, 0)
		if typeof(amount_value) not in [TYPE_INT, TYPE_FLOAT] or float(amount_value) != floorf(float(amount_value)) or (int(amount_value) <= 0 and not worn_only.has(old_name)): continue
		var amount: int = maxi(0, int(amount_value))
		var match: Dictionary = resolve(world, index, old_name)
		if not match.has("id"):
			if match.reason == "no_exact_523_name" and deletable(world, old_name):
				var removed_ids: Array[String] = _ids_named(instances, old_name)
				var levels: Array = []
				for uid: String in removed_ids:
					levels.append(int(instances[uid].get("level", 0)))
					instances.erase(uid)
				for slot: Variant in equipped:
					var worn: Variant = equipped[slot]
					if worn is Dictionary and not worn.is_empty() and (str(worn.get("instance_id", "")) in removed_ids or str(worn.get("name", "")) == old_name):
						equipped[slot] = {}
				counts.erase(old_name)
				enhancement_levels.erase(old_name)
				deleted[old_name] = true
				_note(report.deleted, {"name":old_name, "amount":amount, "where":where, "physical_levels":levels})
				continue
			_note(report.unmatched, {"name":old_name, "amount":amount, "where":where, "reason":match.reason, "candidates":match.candidates})
			continue
		var id: int = int(match.id)
		var target: Dictionary = world._catalog_item_from_source_id("m523:item:%d" % id)
		var new_name: String = str(target.get("name", ""))
		if new_name.is_empty():
			_note(report.unmatched, {"name":old_name, "amount":amount, "where":where, "reason":"523_record_not_registered", "candidates":[id]})
			continue
		var staged_counts: Dictionary = {}
		var staged_instances: Dictionary = {}
		var replaced: Dictionary = {}
		var problem: String = ""
		if D.equipment(target):
			var ids: Array[String] = _ids_named(instances, old_name)
			var level_fallback: int = int(enhancement_levels.get(old_name, 0)) if ids.is_empty() else 0
			var pieces: Array = []
			for uid: String in ids: pieces.append({"uid":uid, "physical":instances[uid]})
			for extra_index: int in range(maxi(0, amount - ids.size())): pieces.append({"uid":"", "physical":{"level":level_fallback}})
			for piece: Dictionary in pieces:
				var physical: Dictionary = piece.physical
				var granted: Dictionary = _do_grant(grant, world, id, 1, _bless_raw(physical), maxi(0, int(physical.get("level", 0))))
				if not granted.ok: problem = granted.error; break
				var fresh_ids: Array = granted.item_instances.keys()
				if fresh_ids.size() != 1: problem = "원본 장비 개체 생성 불일치"; break
				var entry: Dictionary = granted.item_instances[fresh_ids[0]]
				entry["element"] = str(physical.get("element", ""))
				entry["element_level"] = int(physical.get("element_level", 0))
				var uid: String = str(piece.uid)
				if uid.is_empty():
					uid = str(fresh_ids[0])
					if instances.has(uid) or staged_instances.has(uid): problem = "원본 장비 개체 ID 충돌"; break
				replaced[uid] = entry
			if problem.is_empty() and amount > 0: staged_counts[new_name] = amount
		elif amount <= 0:
			continue
		else:
			var granted: Dictionary = _do_grant(grant, world, id, amount, 1, 0)
			if granted.ok:
				staged_counts = granted.inventory
				for uid: Variant in granted.item_instances:
					if instances.has(uid): problem = "원본 묶음 개체 ID 충돌"; break
					staged_instances[uid] = granted.item_instances[uid]
				gold_gain += int(granted.get("gold", 0))
			elif REGIONAL_RETURN.supported(new_name, target):
				# Same plain name-keyed stack the starter kit uses for this item.
				staged_counts = {new_name: amount}
			else:
				problem = str(granted.error)
		if not problem.is_empty():
			_note(report.unmatched, {"name":old_name, "amount":amount, "where":where, "reason":"523_grant_refused: " + problem, "candidates":[id]})
			continue
		# Commit this item into the owner (still the caller's working copies).
		if counts.has(old_name):
			var rekeyed: Dictionary = _rekey(counts, old_name, staged_counts)
			counts.clear(); counts.merge(rekeyed)
		for uid: String in _ids_named(instances, old_name):
			if not replaced.has(uid): instances.erase(uid)
		for uid: Variant in replaced:
			instances[uid] = replaced[uid]
		for uid: Variant in staged_instances: instances[uid] = staged_instances[uid]
		for slot: Variant in equipped:
			var worn: Variant = equipped[slot]
			if not worn is Dictionary or worn.is_empty() or not replaced.has(str(worn.get("instance_id", ""))): continue
			var record: Dictionary = (replaced[str(worn.instance_id)].record as Dictionary).duplicate(true)
			record["instance_id"] = str(worn.instance_id)
			equipped[slot] = record
		enhancement_levels.erase(old_name)
		renamed[old_name] = new_name
		var row: Dictionary = {"from":old_name, "to":new_name, "item_class_id":id, "amount":amount, "where":where, "rule":match.rule}
		if match.has("candidates"): row["candidates"] = match.candidates
		_note(report.migrated, row)
	return {"gold":gold_gain}

static func _note(rows: Array, row: Dictionary) -> void:
	if rows.size() < LIST_LIMIT: rows.append(row)

## Exact-string reference rename inside a quickslot / preference tree.
static func _rename_refs(value: Variant, renamed: Dictionary) -> Variant:
	if value is String:
		var text: String = value
		if renamed.has(text): return renamed[text]
		var at: int = text.find("@@@")
		if at > 0 and renamed.has(text.substr(0, at)): return str(renamed[text.substr(0, at)]) + text.substr(at)
		return value
	if value is Array:
		var out: Array = []
		for item: Variant in value: out.append(_rename_refs(item, renamed))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[_rename_refs(key, renamed) if key is String else key] = _rename_refs(value[key], renamed)
		return out
	return value

## Keeps the loaded save file once, byte for byte, before migration.
static func backup(path: String, bytes: PackedByteArray) -> Dictionary:
	if path.is_empty() or bytes.is_empty(): return {"ok":false, "error":"이전 저장 백업 원본 없음"}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
	var sha: String = ctx.finish().hex_encode()
	var target: String = path + BACKUP_SUFFIX + sha
	if not FileAccess.file_exists(target):
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null: return {"ok":false, "error":"이전 아이템 백업 생성 실패"}
		file.store_buffer(bytes); file.close()
	if FileAccess.get_sha256(target) != sha: return {"ok":false, "error":"이전 아이템 백업 검증 실패"}
	return {"ok":true, "path":target, "sha256":sha}

## Runs the migration on the loaded `world` state. Returns the new marker in
## "marker" (empty when nothing may be decided yet: no 523 items registered).
## `grant` is the original grant (_grant); tests may pass a synthetic one with
## the same (world, item_class_id, amount, bless_raw, enchant) -> result shape.
static func run(world: Node, marker: Variant, loaded_path: String, loaded_bytes: PackedByteArray, grant: Callable = Callable()) -> Dictionary:
	if done(marker): return {"ok":true, "skipped":"already_migrated", "marker":marker}
	var index: Dictionary = name_index(world)
	if index.is_empty(): return {"ok":true, "skipped":"no_523_catalog", "marker":{}}
	var report: Dictionary = {"migrated":[], "unmatched":[], "deleted":[]}
	var renamed: Dictionary = {}
	var deleted: Dictionary = {}
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var equipped: Dictionary = world.equipped_items.duplicate(true)
	var levels: Dictionary = world.enhancement_levels.duplicate(true)
	var stored: Dictionary = world.warehouse.snapshot()
	var bag: Dictionary = _migrate_owner(world, grant, index, inventory, instances, equipped, "bag", levels, report, renamed, deleted)
	var stacks: Dictionary = stored.get("stacks", {})
	var stored_instances: Dictionary = stored.get("instances", {})
	var depot: Dictionary = _migrate_owner(world, grant, index, stacks, stored_instances, {}, "warehouse", levels, report, renamed, deleted)
	var result_marker: Dictionary = {"schema":SCHEMA, "rule":"exact_523_name_whitespace_only;shared_name_smallest_id;unmatched_deleted", "origin":ORIGIN.duplicate(true),
		"migrated_count":report.migrated.size(), "unmatched_count":report.unmatched.size(), "deleted_count":report.deleted.size(),
		"migrated":report.migrated, "unmatched":report.unmatched, "deleted":report.deleted, "backup":""}
	if marker is Dictionary and not marker.is_empty():
		# A schema-1 save: keep its record; this pass only touches what it left.
		result_marker["upgraded_from"] = {"schema":marker.get("schema"), "migrated_count":marker.get("migrated_count"), "unmatched_count":marker.get("unmatched_count"), "backup":marker.get("backup", ""), "migrated":marker.get("migrated", [])}
	if renamed.is_empty() and deleted.is_empty(): return {"ok":true, "changed":false, "marker":result_marker}
	var saved: Dictionary = backup(loaded_path, loaded_bytes)
	if not saved.ok: return {"ok":false, "error":saved.error, "marker":{}}
	result_marker["backup"] = str(saved.path).get_file()
	world.inventory = inventory
	world.item_instances = instances
	world.equipped_items = equipped
	world.enhancement_levels = levels
	world.warehouse.stacks = stacks
	world.warehouse.instances = stored_instances
	world.gold = int(world.gold) + int(bag.gold) + int(depot.gold)
	var slots: Array = world.quickslots.duplicate(true)
	for slot_index: int in range(slots.size()):
		var entry: Variant = slots[slot_index]
		if entry is Dictionary and str(entry.get("kind", "")) == "item" and renamed.has(str(entry.get("id", ""))):
			entry["id"] = renamed[str(entry.id)]
		elif entry is Dictionary and str(entry.get("kind", "")) == "item" and deleted.has(str(entry.get("id", ""))):
			slots[slot_index] = {}
	world.quickslots = slots
	var preferences: Dictionary = world.ui_preferences
	for key: String in ["item_locks", "quickslot_pages"]:
		if preferences.has(key): preferences[key] = _rename_refs(preferences[key], renamed)
	if preferences.get("item_locks") is Dictionary:
		for lock: Variant in preferences.item_locks.keys():
			var lock_name: String = str(lock)
			if lock_name.contains("@@@"): lock_name = lock_name.substr(0, lock_name.find("@@@"))
			if deleted.has(lock_name): preferences.item_locks.erase(lock)
	if renamed.has(str(world.equipped_ammo)) or deleted.has(str(world.equipped_ammo)): world.equipped_ammo = ""
	if world.get("inventory_automation") != null and world.inventory_automation.get("state") is Dictionary:
		world.inventory_automation.state = _rename_refs(world.inventory_automation.state, renamed)
		world.inventory_automation.state = _drop_refs(world.inventory_automation.state, deleted)
	return {"ok":true, "changed":true, "marker":result_marker, "renamed":renamed, "deleted":deleted}

## Removes exact-name references to deleted items from a preference tree.
static func _drop_refs(value: Variant, deleted: Dictionary) -> Variant:
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			if not (item is String and deleted.has(item)): out.append(_drop_refs(item, deleted))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			if not (key is String and deleted.has(key)): out[key] = _drop_refs(value[key], deleted)
		return out
	return value
