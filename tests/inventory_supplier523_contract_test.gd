extends SceneTree
## Explicit PR247 supplier fixtures; does not install/merge a supplier runtime.
const RULES = preload("res://scripts/warehouse/inventory_source523.gd")
const AUTO = preload("res://scripts/warehouse/inventory_automation.gd")
const HOST = preload("res://tests/inventory_maintenance_test.gd")
const SOURCE_TEST = preload("res://tests/inventory_source523_test.gd")
const CONSUMABLE = preload("res://scripts/consumable_rules.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("SUPPLIER_CONTRACT_FAIL: "+label)
static func supplier_record(row: Dictionary) -> Dictionary:
	# Exact startup record shape from PR247 9b2cb076 NpcConsumables.install.
	var record: Dictionary = CONSUMABLE.definition(row.label)
	record.merge({"name":row.label,"source":"twilight-shop523-consumable","source523_shop_item_id":int(row.id),"source523_shop_use_origin":"TWILIGHT 기존 소모품 효과 재사용 · 원본 각인 ID/스택 보존"},true)
	return record
func run() -> void:
	var rules = RULES.new()
	check(rules.load_file(OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE")),"authenticated original rules required")
	for id: String in ["235","237","313","385"]:
		var row: Dictionary = rules.definition(id)
		check(not row.is_empty() and row.is_storable and not row.test_item,"all four source definitions already exist in verified rules "+id)
		for bless: int in [1,2,3]:
			var registered: Dictionary = SOURCE_TEST.native(row,bless)
			check(not rules.resolve(registered).is_empty() and rules.eligible(rules.resolve(registered),"deposit") == (bless == 1),"existing PR238 native registration contract keeps exact state "+id+":"+str(bless))
	for id: String in ["313","385"]:
		var row: Dictionary = rules.definition(id)
		var record: Dictionary = supplier_record(row)
		var before: String = JSON.stringify(record)
		check(rules.resolve(record).is_empty(),"supplier-shaped saved metadata without runtime catalog registration rejected "+id)
		rules.registered_records = [record]
		var resolved: Dictionary = rules.resolve(record)
		check(not resolved.is_empty() and int(resolved.item.id) == int(id) and int(resolved.bless) == 1,"PR247 normal engraved supplier key resolves "+id)
		check(rules.eligible(resolved,"deposit") and rules.eligible(resolved,"sell") == row.merchant_auto,"original store/sell restrictions retained "+id)
		check(JSON.stringify(record) == before and rules.resolve(record,{"source_bless_raw":2}).is_empty(),"read-only stack identity never accepts physical blessing override "+id)
		for mutation: Dictionary in [{"source":"inven"},{"source523_shop_item_id":235},{"source523_shop_item_id":float(id.to_int())+.5},{"name":row.label.replace(" (각인)","")},{"source523_shop_use_origin":"unverified"},{"source_bless_raw":2},{"source_bless_raw":1.5},{"blessed":true},{"bless_state":"cursed"},{"source_item_class_id":999},{"source_item_class_id":float(id.to_int())+.5},{"sourceId":"m523:item:"+id},{"slot":"weapon"},{"kind":"return"},{"type":"material"},{"grade":"고급"},{"source_test_item":true}]:
			var bad: Dictionary = record.merged(mutation,true)
			rules.registered_records = [bad]
			check(rules.resolve(bad).is_empty(),"contradictory supplier metadata rejected "+id+" "+JSON.stringify(mutation))
		rules.registered_records = [record,record.duplicate(true)]
		check(rules.resolve(record).is_empty(),"duplicate supplier catalog name cannot establish unique provenance "+id)
		var normal: Dictionary = record.merged({"source_bless_raw":1.0,"source_item_class_id":float(id.to_int()),"bless_state":"normal"},true)
		rules.registered_records = [normal]
		check(not rules.resolve(normal).is_empty() and rules.resolve(normal.duplicate(true)).is_empty(),"registered normal metadata accepted; detached saved copy cannot supply provenance "+id)
	var host := HOST.Host.new();root.add_child(host)
	var auto = AUTO.new();auto.configure(host)
	check(auto.set_source_only(true).ok,"source-only processing explicitly enabled")
	var teleport: Dictionary = supplier_record(rules.definition("313"))
	var mana: Dictionary = supplier_record(rules.definition("385"))
	host.inventory[teleport.name] = 5;host.inventory[mana.name] = 4
	check(not auto.set_target("deposit",teleport.name,"",true,2).ok,"saved string without registered provider record is not upgraded")
	host.loot_catalog.by_name[teleport.name] = teleport;host.loot_catalog.by_name[mana.name] = mana
	auto.source_rules.registered_records = [teleport,mana]
	host.inventory["순간이동 주문서"] = 8;host.inventory["마나 회복 물약"] = 9
	check(auto.set_target("deposit",teleport.name,"",true,2).ok and auto.set_native_price("385",17).ok and auto.set_target("sell",mana.name,"",true,1).ok,"supplier exact keys and explicit own unknown price can be selected")
	var plan: Dictionary = auto.maintenance.preview(true,true)
	check(plan.ok and plan.cart.size() == 2 and plan.payment == 51 and plan.override.inventory[teleport.name] == 2 and plan.override.inventory[mana.name] == 1,"supplier cart keeps reserves and separately priced merchant target")
	check(plan.override.inventory["순간이동 주문서"] == 8 and plan.override.inventory["마나 회복 물약"] == 9 and str(plan.cart[1].price_basis).contains("자체"),"ordinary same-name stacks unchanged and unknown price clearly local")
	host.ui_preferences.item_locks[mana.name] = true
	check(auto.preview("sell").cart.is_empty(),"existing locks still exclude supplier stack")
	host.ui_preferences.item_locks.clear()
	var snapshot: String = host.snapshot(auto);host.fail_write = true
	check(not auto.commit_plan(plan).ok and host.snapshot(auto) == snapshot,"writer failure preserves supplier quantities, reserves and wallet")
	host.fail_write = false
	check(auto.commit_plan(plan).ok and host.inventory[teleport.name] == 2 and host.warehouse.stacks[teleport.name] == 3 and host.inventory[mana.name] == 1 and host.gold == 10051,"supplier contract can commit existing transaction atomically")
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(auto.preview("sell").cart.is_empty() and host.gold == 10051,"save restoration cannot duplicate supplier sale")
	host.free()
	print("INVENTORY_SUPPLIER_CONTRACT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
