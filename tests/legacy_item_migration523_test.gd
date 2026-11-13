extends SceneTree
## Synthetic check of scripts/loot/legacy_item_migration523.gd: legacy
## (pre-November) items -> the 523 original item of exactly the same name.
## No original tables, resources or saves are used; the 523 catalog and the
## grant are small synthetic stand-ins with the same record/result shapes.
const MIG = preload("res://scripts/loot/legacy_item_migration523.gd")

class FakeWarehouse extends RefCounted:
	var stacks: Dictionary = {}
	var instances: Dictionary = {}
	func snapshot() -> Dictionary:
		return {"stacks":stacks.duplicate(true), "instances":instances.duplicate(true)}

class FakeAutomation extends RefCounted:
	var state: Dictionary = {}

class FakeWorld extends Node:
	var catalog_item_by_source_id: Dictionary = {}
	var legacy_records: Dictionary = {}
	var item_db: Array = []
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var enhancement_levels: Dictionary = {}
	var warehouse := FakeWarehouse.new()
	var inventory_automation := FakeAutomation.new()
	var gold: int = 0
	var quickslots: Array = []
	var ui_preferences: Dictionary = {}
	var equipped_ammo: String = ""
	func _catalog_item_from_source_id(source_id: String) -> Dictionary:
		return catalog_item_by_source_id.get(source_id, {})
	func _find_catalog_item_record(name_value: String) -> Dictionary:
		for record: Dictionary in catalog_item_by_source_id.values():
			if record.name == name_value: return record
		for record: Dictionary in item_db:
			if record.name == name_value: return record
		return legacy_records.get(name_value, {})

var grants: Array = []

func _initialize() -> void:
	call_deferred("run")

func _native(world: FakeWorld, id: int, display: String, slot: String, test_item: bool = false) -> void:
	world.catalog_item_by_source_id["m523:item:%d" % id] = {"name":display + " · 원본#%d" % id, "sourceId":"m523:item:%d" % id,
		"source":"lineagem_patch523", "source_snapshot":"patch523", "source_m_native_item":true, "source_item_class_id":id,
		"source_test_item":test_item, "slot":slot}

## Same result shape as patch523_item_inventory.stage overrides.
func _fake_grant(world: Node, id: int, amount: int, bless: int, enchant: int) -> Dictionary:
	grants.append([id, amount, bless, enchant])
	if id == 7777: return {"ok":false, "error":"새 원문 비장비 물리 수량·소비 소유자 연결 대기"}
	var record: Dictionary = world._catalog_item_from_source_id("m523:item:%d" % id)
	var uid: String = "%032x" % (grants.size() * 7919)
	if record.slot != "material":
		return {"ok":true, "gold":0, "inventory":{record.name:amount}, "item_instances":{uid:{"name":record.name, "record":record.duplicate(true), "level":enchant, "element":"", "element_level":0, "bless_state":{1:"normal", 2:"blessed", 3:"cursed"}[bless], "source_m_reward_proof":{"item_class_id":id, "bless":bless, "enchant":enchant}}}}
	return {"ok":true, "gold":0, "inventory":{record.name:amount}, "item_instances":{uid:{"name":record.name, "record":record.duplicate(true), "level":0, "source_native_stack_quantity":amount, "source_native_stack_receipt":{"item_class_id":id, "granted_quantity":amount}}}}

func _world() -> FakeWorld:
	var world := FakeWorld.new()
	_native(world, 65291, "축복 부여 주문서 (각인)", "material")
	_native(world, 6401, "무기 마법 주문서 (각인)", "material")
	_native(world, 551, "강철 면갑", "helmet")
	_native(world, 4901, "강철 면갑 (각인)", "helmet")
	_native(world, 549, "드래곤의 다이아몬드", "material")
	_native(world, 139581, "드래곤의 다이아몬드", "material")
	_native(world, 127534, "고대의 판금 갑옷", "body")
	_native(world, 247108, "고대의 판금 갑옷", "body")
	_native(world, 7777, "봉인된 상자", "material")
	_native(world, 8888, "테스트 반지", "ring", true)
	_native(world, 1000, "마나 회복 물약 (각인)", "material")
	world.legacy_records = {"고대의 판금 갑옷":{"name":"고대의 판금 갑옷", "source":"inven", "sourceId":"247108", "slot":"body"},
		"강철 면갑":{"name":"강철 면갑", "source":"inven", "sourceId":"551", "slot":"helmet"},
		"고대 반지":{"name":"고대 반지", "source_snapshot":"base508", "slot":"ring"}}
	world.item_db = [{"name":"HP 물약", "slot":"consumable"}, {"name":"마나 회복 물약", "slot":"consumable"}, {"name":"낡은 장검", "slot":"weapon"}, {"name":"명예 코인", "slot":"currency"}]
	world.inventory = {"HP 물약":100, "축복 부여 주문서 (각인) · 원본#65291":5, "강철 면갑":2, "축복 부여 주문서 (각인)":3,
		"드래곤의 다이아몬드":4, "고대의 판금 갑옷":1, "마나 회복 물약":10, "봉인된 상자":1, "테스트 반지":1, "다이아":50, "무기 마법  주문서 (각인)":6, "낡은 장검":1, "명예 코인":30, "수호석":7, "최상급 변신 뽑기권":1, "고대 반지":1}
	world.item_instances = {"11":{"name":"강철 면갑", "level":3, "element":"water", "element_level":2, "bless_state":"blessed"},
		"12":{"name":"고대의 판금 갑옷", "level":7, "element":"", "element_level":0, "bless_state":"cursed"},
		"13":{"name":"테스트 반지", "level":0}, "14":{"name":"낡은 장검", "level":2}}
	world.equipped_items = {"helmet":{"name":"강철 면갑", "instance_id":"11", "slot":"helmet"}, "body":{"name":"고대의 판금 갑옷", "instance_id":"12"}, "weapon":{"name":"낡은 장검", "instance_id":"14"}}
	world.enhancement_levels = {"강철 면갑":4}
	world.warehouse.stacks = {"축복 부여 주문서 (각인)":2, "강철 면갑 (각인)":1}
	world.warehouse.instances = {"21":{"name":"강철 면갑 (각인)", "level":1, "element":"earth", "element_level":1}}
	world.quickslots = [{"kind":"skill", "id":"축복 부여 주문서 (각인)"}, {"kind":"item", "id":"축복 부여 주문서 (각인)"}, {"kind":"item", "id":"HP 물약"}, {"kind":"item", "id":"낡은 장검"}]
	world.ui_preferences = {"item_locks":{"강철 면갑@@@11":true, "HP 물약":true}, "quickslot_pages":{"기사":[0, 0]}}
	world.inventory_automation.state = {"store":["축복 부여 주문서 (각인)"]}
	return world

func _check_migrated(world: FakeWorld, marker: Dictionary, result: Dictionary, failures: Array[String], tag: String) -> void:
	if not result.get("ok", false) or not result.get("changed", false): failures.append(tag + " run result %s" % str(result.keys()))
	var keys: Array = world.inventory.keys()
	var expected_keys: Array = ["축복 부여 주문서 (각인) · 원본#65291", "강철 면갑 · 원본#551", "드래곤의 다이아몬드 · 원본#549", "고대의 판금 갑옷 · 원본#127534", "봉인된 상자", "다이아", "무기 마법 주문서 (각인) · 원본#6401", "명예 코인", "수호석", "최상급 변신 뽑기권", "고대 반지"]
	if keys != expected_keys: failures.append(tag + " bag order/keys %s" % str(keys))
	if int(world.inventory.get("축복 부여 주문서 (각인) · 원본#65291", 0)) != 8: failures.append(tag + " merged stack amount")
	if int(world.inventory.get("강철 면갑 · 원본#551", 0)) != 2 or int(world.inventory.get("드래곤의 다이아몬드 · 원본#549", 0)) != 4 or int(world.inventory.get("무기 마법 주문서 (각인) · 원본#6401", 0)) != 6 or int(world.inventory.get("다이아", 0)) != 50 or int(world.inventory.get("명예 코인", 0)) != 30: failures.append(tag + " amounts / wallets")
	var helmet: Dictionary = world.item_instances.get("11", {})
	if helmet.get("name") != "강철 면갑 · 원본#551" or int(helmet.get("level", -1)) != 3 or helmet.get("element") != "water" or int(helmet.get("element_level", 0)) != 2 or helmet.get("bless_state") != "blessed": failures.append(tag + " equipment instance kept in place %s" % str(helmet))
	var body: Dictionary = world.item_instances.get("12", {})
	if body.get("name") != "고대의 판금 갑옷 · 원본#127534" or int(body.get("level", -1)) != 7 or body.get("bless_state") != "cursed": failures.append(tag + " smallest-ID cursed body %s" % str(body))
	var extra_helmets: int = 0
	for uid: String in world.item_instances:
		var entry: Dictionary = world.item_instances[uid]
		if uid != "11" and entry.get("name") == "강철 면갑 · 원본#551":
			extra_helmets += 1
			if int(entry.get("level", -1)) != 0: failures.append(tag + " second helmet must not borrow the legacy name-level")
	if extra_helmets != 1: failures.append(tag + " missing second helmet piece %d" % extra_helmets)
	if world.equipped_items.helmet.get("name") != "강철 면갑 · 원본#551" or world.equipped_items.helmet.get("instance_id") != "11": failures.append(tag + " equipped helmet")
	if world.equipped_items.body.get("instance_id") != "12" or world.equipped_items.body.get("name") != "고대의 판금 갑옷 · 원본#127534": failures.append(tag + " equipped body")
	if not world.equipped_items.weapon.is_empty() or world.item_instances.has("14"): failures.append(tag + " deleted equipped weapon still worn/owned")
	if world.item_instances.has("13"): failures.append(tag + " deleted item's physical copy must go")
	if int(world.inventory.get("수호석", 0)) != 7 or int(world.inventory.get("최상급 변신 뽑기권", 0)) != 1 or int(world.inventory.get("고대 반지", 0)) != 1: failures.append(tag + " protected keys changed")
	if world.enhancement_levels.has("강철 면갑"): failures.append(tag + " legacy name-level not retired")
	if world.warehouse.stacks != {"축복 부여 주문서 (각인) · 원본#65291":2, "강철 면갑 (각인) · 원본#4901":1}: failures.append(tag + " warehouse stacks %s" % str(world.warehouse.stacks))
	var depot: Dictionary = world.warehouse.instances.get("21", {})
	if depot.get("name") != "강철 면갑 (각인) · 원본#4901" or int(depot.get("level", -1)) != 1 or depot.get("element") != "earth": failures.append(tag + " warehouse equipment")
	if world.quickslots[0].get("id") != "축복 부여 주문서 (각인)" or world.quickslots[0].get("kind") != "skill" or world.quickslots[1].get("id") != "축복 부여 주문서 (각인) · 원본#65291" or not world.quickslots[2].is_empty() or not world.quickslots[3].is_empty(): failures.append(tag + " quickslots %s" % str(world.quickslots))
	if world.ui_preferences.item_locks != {"강철 면갑 · 원본#551@@@11":true}: failures.append(tag + " item locks %s" % str(world.ui_preferences.item_locks))
	if world.inventory_automation.state != {"store":["축복 부여 주문서 (각인) · 원본#65291"]}: failures.append(tag + " automation refs")
	var deleted: Dictionary = {}
	for row: Dictionary in marker.get("deleted", []): deleted[row.name] = row
	if deleted.keys() != ["HP 물약", "마나 회복 물약", "테스트 반지", "낡은 장검"] or int(deleted["HP 물약"].amount) != 100: failures.append(tag + " deleted list %s" % str(deleted.keys()))
	var unmatched: Dictionary = {}
	for row: Dictionary in marker.get("unmatched", []): unmatched[row.name] = row
	if unmatched.keys() != ["봉인된 상자", "고대 반지"]: failures.append(tag + " kept list %s" % str(unmatched.keys()))
	if not str(unmatched.get("봉인된 상자", {}).get("reason", "")).begins_with("523_grant_refused"): failures.append(tag + " refused grant must stay")
	var shared: bool = false
	for row: Dictionary in marker.get("migrated", []):
		if row.get("from") == "드래곤의 다이아몬드" and row.get("rule") == "exact_name_smallest_id" and int(row.get("item_class_id", 0)) == 549: shared = true
	if not shared: failures.append(tag + " smallest ID rule not recorded")
	if int(marker.get("schema", 0)) != 2 or int(marker.get("migrated_count", 0)) != 7 or int(marker.get("deleted_count", 0)) != 4: failures.append(tag + " marker %s/%s/%s" % [str(marker.get("schema")), str(marker.get("migrated_count")), str(marker.get("deleted_count"))])

func run() -> void:
	var failures: Array[String] = []
	var path: String = "user://legacy_item_migration523_test.json"
	var bytes: PackedByteArray = "{\"legacy\":true}".to_utf8_buffer()
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
	var sha: String = ctx.finish().hex_encode()
	var backup: String = path + MIG.BACKUP_SUFFIX + sha
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
	# Name rule.
	if MIG.normalize("  무기 마법  주문서 (각인) ") != "무기 마법 주문서 (각인)": failures.append("whitespace normalisation")
	var world := _world()
	var index: Dictionary = MIG.name_index(world)
	if index.has("테스트 반지"): failures.append("test item indexed")
	if index.get("드래곤의 다이아몬드", []) != [549, 139581]: failures.append("ambiguous candidates %s" % str(index.get("드래곤의 다이아몬드")))
	if MIG.is_legacy(world, "다이아") or MIG.is_legacy(world, "명예 코인") or MIG.is_legacy(world, "축복 부여 주문서 (각인) · 원본#65291"): failures.append("wallet/523 key treated as legacy")
	if MIG.deletable(world, "고대 반지") or MIG.deletable(world, "수호석") or MIG.deletable(world, "최상급 변신 뽑기권") or not MIG.deletable(world, "HP 물약"): failures.append("deletion guard")
	# Migration (schema 2: smallest ID for a shared name, unmatched legacy deleted).
	var result: Dictionary = MIG.run(world, {}, path, bytes, _fake_grant)
	var marker: Dictionary = result.get("marker", {})
	_check_migrated(world, marker, result, failures, "fresh")
	if not FileAccess.file_exists(backup) or FileAccess.get_sha256(backup) != sha or marker.get("backup") != backup.get_file(): failures.append("byte-for-byte backup")
	# Idempotent: a saved schema-2 marker skips; a second pass changes nothing.
	var snapshot: String = JSON.stringify([world.inventory, world.item_instances, world.warehouse.snapshot(), world.quickslots, world.equipped_items])
	var again: Dictionary = MIG.run(world, marker, path, bytes, _fake_grant)
	if again.get("skipped") != "already_migrated" or again.get("marker") != marker: failures.append("marker did not stop a second migration")
	var count_before: int = grants.size()
	var rerun: Dictionary = MIG.run(world, {}, path, bytes, _fake_grant)
	if rerun.get("changed", true) or JSON.stringify([world.inventory, world.item_instances, world.warehouse.snapshot(), world.quickslots, world.equipped_items]) != snapshot: failures.append("second pass changed migrated data")
	if grants.size() - count_before != 1: failures.append("second pass re-granted (only the refused stack may be retried): %d" % (grants.size() - count_before))
	# A save already migrated by schema 1 gets exactly one schema-2 pass.
	var old := _world()
	var v1: Dictionary = {"schema":1, "migrated_count":4, "unmatched_count":6, "backup":"x", "migrated":[]}
	var upgraded: Dictionary = MIG.run(old, v1, path, bytes, _fake_grant)
	_check_migrated(old, upgraded.get("marker", {}), upgraded, failures, "schema1")
	if upgraded.get("marker", {}).get("upgraded_from", {}).get("schema") != 1: failures.append("schema-1 record not kept")
	if MIG.run(old, upgraded.marker, path, bytes, _fake_grant).get("skipped") != "already_migrated": failures.append("schema-2 marker must stop the upgrade")
	old.free()
	# Without the installed 523 items nothing is decided and no marker is written.
	var bare := FakeWorld.new()
	bare.inventory = {"HP 물약":1}
	var none: Dictionary = MIG.run(bare, {}, path, bytes, _fake_grant)
	if none.get("skipped") != "no_523_catalog" or not none.get("marker", {}).is_empty() or bare.inventory != {"HP 물약":1}: failures.append("no-catalog run")
	bare.free(); world.free()
	DirAccess.remove_absolute(backup)
	print("LEGACY_ITEM_MIGRATION523_RESULT ", JSON.stringify({"failures":failures, "grants":grants.size()}))
	quit(0 if failures.is_empty() else 1)
