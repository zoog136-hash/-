extends SceneTree

const BLESSING = preload("res://scripts/equipment_blessing.gd")
const INVENTORY_UI = preload("res://scripts/ui/lineage_inventory_ui.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("BLESSING FAIL: " + message)

func _run() -> void:
	# Equipment and grade effects do not cumulatively include lower grades.
	_check(int(BLESSING.bonus_for("일반", "weapon").get("hp", 0)) == 50, "normal weapon HP")
	_check(int(BLESSING.bonus_for("희귀", "weapon").get("accuracy", 0)) == 1, "rare weapon hit")
	for high_grade: String in ["신화", "유일"]:
		_check(BLESSING.bonus_for(high_grade, "weapon") == BLESSING.bonus_for("전설", "weapon"), high_grade + " weapon must match legendary")
		_check(BLESSING.bonus_for(high_grade, "armor") == BLESSING.bonus_for("전설", "armor"), high_grade + " armor must match legendary")
		_check(BLESSING.effect_text(high_grade, "weapon") == "추가 대미지 +1", high_grade + " weapon blessing label")
		_check(BLESSING.effect_text(high_grade, "armor") == "AC -1", high_grade + " armor blessing label")
	_check(int(BLESSING.bonus_for("영웅", "armor").get("defense", 0)) == 1, "hero armor AC")
	_check(int(BLESSING.bonus_for("고급", "armor").get("hp", 0)) == 30, "advanced armor HP")
	_check(BLESSING.bonus_for("희귀", "accessory").is_empty(), "accessory cannot use basic scroll")
	_check(not BLESSING.roll_succeeds("일반", 99.99) and BLESSING.roll_succeeds("일반", 0.0), "deterministic success/failure edges")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main scene missing")
		_finish()
		return
	var world: Variant = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var service: Node = world.get("consumable_service") as Node
	if service == null:
		_check(false, "Consumable service missing")
		world.queue_free()
		await process_frame
		_finish()
		return
	var inv: Dictionary = world.get("inventory") as Dictionary
	var scroll: String = "축복 부여 주문서 (각인)"
	_check(str(world.call("_find_catalog_item_record", scroll).get("name", "")) == scroll, "blessing scroll missing from item catalog")
	inv["낡은 장검"] = 2
	inv[scroll] = 5
	world.set("item_instances", {})
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var ids: Array[String] = []
	for raw_id: Variant in instances.keys():
		if str((instances[raw_id] as Dictionary).get("name", "")) == "낡은 장검":
			ids.append(str(raw_id))
	ids.sort()
	_check(ids.size() == 2, "two same-name swords need separate physical IDs")
	if ids.size() != 2:
		world.queue_free()
		await process_frame
		_finish()
		return
	var a: String = ids[0]
	var b: String = ids[1]
	var weapon: Dictionary = world.call("_find_catalog_item_record", "낡은 장검")
	world.call("_equip_or_acquire_item", weapon, false, a)
	var base_hp: int = int(world.call("_effective_max_hp"))
	var grade: String = str(weapon.get("grade", "일반"))
	var expected_hp: int = int(BLESSING.bonus_for(grade, "weapon").get("hp", 0))
	var expected_hit: int = int(BLESSING.bonus_for(grade, "weapon").get("accuracy", 0))
	var expected_damage: int = int(BLESSING.bonus_for(grade, "weapon").get("damage", 0))
	_check(bool(service.call("apply_bless_scroll", scroll, "낡은 장검@@@" + a, 0.0)), "forced successful blessing")
	instances = world.get("item_instances") as Dictionary
	_check(BLESSING.is_blessed(instances[a] as Dictionary, weapon), "selected sword has blessing")
	_check(not BLESSING.is_blessed(instances[b] as Dictionary, weapon), "second sword inherited blessing")
	# Blessing must appear in the item name only: no star or duplicate prefix.
	var ui: Control = INVENTORY_UI.new()
	ui.set("character_state", {"item_instances": instances, "enhancement_levels": {}})
	var blessed_name: String = str(ui.call("_enhanced_display_name", weapon, "낡은 장검@@@" + a))
	var ordinary_name: String = str(ui.call("_enhanced_display_name", weapon, "낡은 장검@@@" + b))
	_check(blessed_name == "축복받은 낡은 장검", "blessed item name or duplicate decorations")
	_check(ordinary_name == "낡은 장검", "ordinary copy inherited blessing label")
	_check(str(ui.call("_status_badges", weapon, "낡은 장검@@@" + a)) == "", "blessing star still rendered")
	_check(not blessed_name.contains("✦"), "star remained in blessed name")
	ui.queue_free()
	_check(int(inv.get(scroll, 0)) == 4, "successful blessing must consume exactly one scroll")
	_check(int(world.call("_effective_max_hp")) == base_hp + expected_hp, "equipped HP blessing missing")
	_check(int(world.call("_equipped_bless_bonus", "accuracy")) == expected_hit, "equipped weapon accuracy bonus missing")
	_check(int(world.call("_equipped_bless_bonus", "damage")) == expected_damage, "equipped weapon damage bonus missing")
	_check(not bool(service.call("apply_bless_scroll", scroll, "낡은 장검@@@" + a, 0.0)), "duplicate blessing incorrectly succeeded")
	_check(int(inv.get(scroll, 0)) == 4, "already blessed weapon consumed a scroll")

	_check(not bool(service.call("apply_bless_scroll", scroll, "낡은 장검@@@" + b, 99.99)), "forced failure should not bless")
	instances = world.get("item_instances") as Dictionary
	_check(instances.has(b) and not BLESSING.is_blessed(instances[b] as Dictionary, weapon), "failure destroyed or blessed target")
	_check(int(inv.get("낡은 장검", 0)) == 2, "failure destroyed inventory equipment")
	_check(int(inv.get(scroll, 0)) == 3, "failed blessing must consume scroll")
	_check(not bool(service.call("apply_bless_scroll", scroll, "낡은 장검")), "name-only ambiguity allowed")
	_check(int(inv.get(scroll, 0)) == 3, "invalid target consumed scroll")
	_check(not bool(service.call("apply_bless_scroll", scroll, "낡은 장검@@@nonexistent")), "invalid instance allowed")
	_check(int(inv.get(scroll, 0)) == 3, "nonexistent target consumed scroll")

	world.call("_save_game", true)
	world.set("item_instances", {})
	world.call("_load_game", true)
	instances = world.get("item_instances") as Dictionary
	_check(instances.has(a) and instances.has(b), "save/load lost physical copies")
	if instances.has(a) and instances.has(b):
		_check(BLESSING.is_blessed(instances[a] as Dictionary, weapon), "save/load lost blessed state")
		_check(not BLESSING.is_blessed(instances[b] as Dictionary, weapon), "save/load copied blessing to another sword")
		_check(int(world.call("_effective_max_hp")) == base_hp + expected_hp, "restored equipped blessing not effective")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("EQUIPMENT_BLESSING_SMOKE_OK: per-instance, chance, scroll costs, equipped stats, save/load")
		quit(0)
	else:
		print("EQUIPMENT_BLESSING_SMOKE_FAILED: %d errors" % failures.size())
		quit(1)
