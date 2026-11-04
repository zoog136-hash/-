extends SceneTree
const RULES = preload("res://scripts/warehouse/inventory_source523.gd")
const AUTO = preload("res://scripts/warehouse/inventory_automation.gd")
const FIXTURE = preload("res://tests/inventory_maintenance_test.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("INVENTORY_SOURCE_FAIL: "+label)

static func native(row: Dictionary, bless: int = 1) -> Dictionary:
	return {"name":str(row.label)+" · 원본#"+str(int(row.id))+("" if bless == 1 else " · "+("축복" if bless == 2 else "저주")),"source":"lineagem_patch523","source_snapshot":"patch523","source_m_native_item":true,"source_item_class_id":int(row.id),"sourceId":"m523:item:"+str(int(row.id))+("" if bless == 1 else ":bless:"+str(bless)),"source_display_name":str(row.label),"source_bless_raw":bless,"grade":str(row.grade),"slot":"material"}

func run() -> void:
	var rules = RULES.new()
	var path: String = OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE")
	if path.is_empty() or not rules.load_file(path):
		check(false,"actual private source rule pack required")
		quit(1)
		return
	check(rules.document.counts.storage_rows == 84 and rules.document.counts.sell_rows == 25 and rules.document.items.size() == 80,"all source rows and classes retained")
	check(rules.document.counts.inven_storage_rows == 43 and rules.document.counts.inven_sell_rows == 9,"exact ID URL descriptor joins")
	check(rules.document.counts.confirmed_prices == 11 and rules.document.counts.virtual_selectors == 4,"prices separate from virtual selectors")
	for id: String in rules.document.items:
		var row: Dictionary = rules.definition(id)
		for bless: int in [1,2,3]:
			var record: Dictionary = native(row,bless)
			var resolved: Dictionary = rules.resolve(record)
			check(not resolved.is_empty() and int(resolved.item.id) == int(id) and int(resolved.bless) == bless,"native ID/bless contract "+id+":"+str(bless))
			var expected: bool = row.storage_bless.has(bless) and row.is_storable and not row.virtual and not row.test_item and not row.currency and not row.equipment and row.stackable
			check(rules.eligible(resolved,"deposit") == expected,"source storage membership "+id+":"+str(bless))
		if not row.binding.is_empty():
			var binding: Dictionary = row.binding.duplicate(true)
			check(not rules.resolve(binding).is_empty(),"verified current catalog binding "+id)
			binding.sourceId = "wrong-id"
			check(rules.resolve(binding).is_empty(),"same label with wrong source ID rejected "+id)
		if row.merchant_auto and not row.virtual and not row.test_item:
			var record: Dictionary = native(row)
			var inventory: Dictionary = {record.name:10}
			var quote: Dictionary = rules.quote(record,record.name,2,"",inventory,{}, {},100, {id:77})
			var expected: int = int(row.price.adena) if not row.price.is_empty() else 77
			check(quote.get("ok",false) and int(quote.payment) == 2*expected,"confirmed price wins; only unknown prices configurable "+id)
			check(str(quote.price_basis).contains("원본") if not row.price.is_empty() else str(quote.price_basis).contains("자체"),"price provenance visible "+id)
			record.bound = true
			check(not rules.quote(record,record.name,1,"",inventory,{}, {},100,{}).get("ok",false),"explicit bound flag protected "+id)
	for id: String in ["45011","45021","45031","45041"]:
		var record: Dictionary = native(rules.definition(id))
		check(not rules.eligible(rules.resolve(record),"sell"),"virtual group never becomes a sellable item "+id)
	var host := FIXTURE.Host.new()
	root.add_child(host)
	var service = AUTO.new()
	service.configure(host)
	service.source_rules.document = rules.document
	for id: String in ["45011","45021","45031","45041","8271"]:
		var protected_record: Dictionary = native(rules.definition(id))
		host.loot_catalog.by_name[protected_record.name] = protected_record
		host.inventory[protected_record.name] = 2
		check(not service.sale_quote(protected_record.name,1,"",host.inventory,host.item_instances,host.gold,false).get("ok",false),"actual manual/legacy fallback cannot sell virtual or TestItem "+id)
	host.free()
	var row: Dictionary = rules.definition("767")
	var record: Dictionary = native(row)
	var inventory: Dictionary = {record.name:5}
	check(not rules.quote(record,record.name,1,"",inventory,{}, {},9000000000000000000,{}).get("ok",false),"wallet ceiling checked before mutation")
	record.erase("source_bless_raw")
	check(rules.resolve(record).is_empty(),"unresolved native blessing cannot flatten into normal")
	record = native(row)
	record.source_item_class_id = 744
	check(rules.resolve(record).is_empty(),"contradictory native class and prefix rejected")
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	raw[raw.size()-2] = raw[raw.size()-2] ^ 1
	check(rules.parse(raw).is_empty(),"tampered payload rejected")
	var previous: String = JSON.stringify(rules.document)
	var damaged := FileAccess.open("user://damaged-rules.json",FileAccess.WRITE)
	damaged.store_buffer(raw)
	damaged.close()
	check(not rules.load_file("user://damaged-rules.json") and JSON.stringify(rules.document) == previous,"failed update preserves active definitions")
	var zip: String = OS.get_environment("TWILIGHT_AUTO_INVENTORY523_ZIP")
	check(not zip.is_empty() and rules.install_zip(zip).get("ok",false),"actual rule ZIP installs")
	var restored = RULES.new()
	check(restored.load_file("user://inventory523/inventory_rules523.json") and restored.fingerprint() == RULES.PACK_SHA,"installed rules survive a new consumer")
	var zip_before: String = FileAccess.get_sha256(zip)
	check(rules.install_zip(zip).get("ok",false) and FileAccess.get_sha256(zip) == zip_before,"same version install is idempotent and source ZIP unchanged")
	check(not rules.install_zip("user://damaged-rules.json").get("ok",false) and JSON.stringify(rules.document) == previous,"unsupported input rejected before ZIP decompression")
	print("INVENTORY_SOURCE523: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
