extends SceneTree
const RULES = preload("res://scripts/warehouse/inventory_source523.gd")
const REGISTRY = preload("res://scripts/warehouse/inventory_registered523.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REGISTRY_FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rules = RULES.new()
	check(rules.load_file(OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE")),"verified original inventory rule payload")
	var registry = REGISTRY.new()
	check(registry.load_existing(),"actual approved PR238 application payload reads existing argument/path")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var before: Dictionary = rules.registered_status(catalog["아이템"])
	check(before.deposit == 43 and before.sell == 9,"actual baseline catalog matches previous exact binding counts")
	var result: Dictionary = registry.attach(catalog,rules)
	var status: Dictionary = rules.registered_status(catalog["아이템"])
	print("ACTUAL_REGISTRY_COVERAGE ",JSON.stringify(status))
	check(result.added > 0 and result.collisions.is_empty(),"append only actual manifest-declared target definitions")
	check(status.deposit == 80 and status.sell == 19 and status.deposit_allowed == 79 and status.sell_allowed == 19,"actual registered identity and protected/TestItem coverage distinguished")
	var snapshot: String = JSON.stringify(catalog)
	check(registry.attach(catalog,rules).added == 0 and JSON.stringify(catalog) == snapshot,"same catalog binding is idempotent")
	for id: int in [137,138,6401,6411]:
		for bless: int in [1,2,3]:
			var count: int = 0
			for record: Dictionary in catalog["아이템"]:
				var resolved: Dictionary = rules.resolve(record)
				if not resolved.is_empty() and int(resolved.item.id) == id and int(resolved.bless) == bless:
					check(rules.eligible(resolved,"deposit"),"actual blessed/cursed source registration is storage-eligible")
					count += 1
			check(count == 1,"exact one registered stack key per enchant-scroll ID/bless")
	for id: int in [235,237,313,385]:
		var found: bool = false
		for record: Dictionary in catalog["아이템"]:
			if record.get("source_m_native_item",false) and int(record.get("source_item_class_id",0)) == id: found = true
		check(not found,"missing application definition remains unregistered "+str(id))
	for id: int in [45011,45021,45031,45041,8271]:
		var found: bool = false
		for record: Dictionary in catalog["아이템"]:
			if record.get("source_m_native_item",false) and int(record.get("source_item_class_id",0)) == id: found = true
		check(not found,"virtual or TestItem is never registered from auto-selection row "+str(id))
	var collision_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	collision_catalog["아이템"].append({"name":"different registered identity","sourceId":"m523:item:118692","source":"other"})
	var conflict: Dictionary = registry.attach(collision_catalog,rules)
	check(conflict.collisions.has("m523:item:118692") and collision_catalog["아이템"].any(func(record: Dictionary) -> bool: return record.name == "different registered identity"),"existing colliding source ID is preserved, never overwritten or aliased")
	print("INVENTORY_REGISTRY523: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
