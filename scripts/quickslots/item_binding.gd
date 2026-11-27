extends RefCounted
## Old slots keep a name key. A bag selection also carries its physical ID.
## A spent/folded native stack can be replaced by the same original variant.
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const RECEIPT := "source_native_stack_receipt"

static func create(selection: Dictionary, row: Dictionary) -> Dictionary:
	var entry: Dictionary = {"kind":"item","id":selection.name,"auto":false}
	if str(selection.id).is_empty(): return entry
	entry["instance_id"] = str(selection.id)
	var record: Dictionary = row.get("record",{})
	if row.has(RECEIPT) and record.get("source_m_native_item",false) and FIELDS.field(record,"source_is_stackable")==true:
		entry["stock_source"] = str(record.get("sourceId",""))
		entry["stock_bless"] = int(record.get("source_bless_raw",0))
	return entry

static func resolve_reference(entry: Dictionary, inventory: Dictionary, instances: Dictionary, locked: Callable) -> String:
	var name: String = str(entry.get("id",""))
	var id: String = str(entry.get("instance_id",""))
	if id.is_empty(): return name
	if int(inventory.get(name,0))>0 and not instances.has(id) and not str(entry.get("stock_source","")).is_empty():
		var locked_stock: String = ""
		for replacement: String in instances:
			if not _same_stock(entry,instances[replacement]): continue
			if locked.call(name,replacement):
				if locked_stock.is_empty(): locked_stock = replacement
				continue
			id = replacement
			break
		if not instances.has(id) and not locked_stock.is_empty(): id = locked_stock
	return name+"@@@"+id

static func _same_stock(entry: Dictionary, row: Dictionary) -> bool:
	if row.get("name")!=entry.id or not row.has(RECEIPT): return false
	var record: Dictionary = row.get("record",{})
	return record.get("source_m_native_item",false) and record.get("sourceId")==entry.stock_source and record.get("source_bless_raw")==entry.get("stock_bless",0)

static func count(selection: Dictionary, inventory: Dictionary, instances: Dictionary) -> int:
	var total: int = int(inventory.get(selection.name,0))
	if str(selection.id).is_empty(): return total
	var row: Dictionary = instances.get(selection.id,{})
	if row.get("name")!=selection.name: return 0
	for field: String in ["source_native_stack_quantity","source_reward_quantity","source_awakening_quantity","source_card_currency_quantity"]:
		if row.has(field):return clampi(int(row[field]),0,maxi(0,total))
	return 1 if total>0 else 0
