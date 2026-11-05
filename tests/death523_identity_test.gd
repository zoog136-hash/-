extends SceneTree
const Runtime = preload("res://scripts/death/runtime.gd")
class ExistingOwnership:
	extends RefCounted
	var equipped_items: Dictionary = {}
	var item_instances: Dictionary = {}
	var inventory: Dictionary = {}
	var catalog_item_variant_count: Dictionary = {}
	func _find_catalog_item_record(_name: String) -> Dictionary: return {}

func _initialize() -> void:
	var service = Runtime.new()
	var source_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--death523-source="): source_path = argument.trim_prefix("--death523-source=")
	var failures: Array[String] = []
	if not service.source.load_pack(source_path): failures.append("actual pinned source required")
	var host = ExistingOwnership.new()
	service.world = host
	var record: Dictionary = {"sourceId":"122394","name":"리치의 반지"}
	if not service.source.matches_item(record,"122394"): failures.append("native exact ring identity")
	host.inventory[record.name] = 1
	host.item_instances["77"] = {"name":record.name,"record":record.duplicate(true)}
	host.equipped_items.ring1 = {"name":record.name,"instance_id":"77"}
	if service.death_stats().value != 3: failures.append("owned equipped native ring has KarmaDeath3")
	host.equipped_items.ring2 = host.equipped_items.ring1.duplicate(true)
	if service.death_stats().value != 3: failures.append("duplicate physical ID counted twice")
	host.equipped_items.erase("ring2")
	host.item_instances["77"].name = "unrelated physical item"
	host.equipped_items.ring1.name = "unrelated physical item"
	host.inventory["unrelated physical item"] = 1
	if service.death_stats().value != 0: failures.append("valid native record attached to wrong physical name granted stat")
	host.item_instances["77"].name = record.name
	host.equipped_items.ring1.name = record.name
	host.item_instances["77"].record.sourceId = "200723"
	if service.death_stats().value != 0: failures.append("gaho ID or mismatching source identity granted Death-stat")
	if int(service.source.row(30).DropRate) != 0 or int(service.source.row(31).DropRate) != 5: failures.append("native item loss boundary")
	print("DEATH523_IDENTITY_RESULT ",JSON.stringify({"checks":7,"failures":failures,"scope":"PINNED_NATIVE_SOURCE_AND_EXISTING_PHYSICAL_OWNERSHIP_IDENTITY"}))
	quit(0 if failures.is_empty() else 1)
