extends RefCounted
## Read-only physical ownership boundary for ItemHoning. Not an eligibility rule.
## No source rows, inferred rates, migration, RNG, or save writes live here.

static func _count(value: Variant) -> int:
	if not (value is int or value is float): return -1
	if not is_finite(float(value)) or float(value) != floorf(float(value)) or value < 0 or value > 9007199254740991: return -1
	return int(value)

static func inspect(inventory: Dictionary, physical: Dictionary, instance_id: String) -> Dictionary:
	if instance_id.is_empty() or not physical.get(instance_id) is Dictionary:
		return _blocked("missing_instance")
	var selected: Dictionary = physical[instance_id]
	var name_value: Variant = selected.get("name")
	if not name_value is String or name_value.is_empty(): return _blocked("invalid_identity")
	var name: String = name_value
	var owned: int = _count(inventory.get(name))
	if owned <= 0: return _blocked("not_owned")
	var reserved: int = 0
	for raw_id: Variant in physical:
		var entry: Variant = physical[raw_id]
		if not entry is Dictionary: return _blocked("invalid_physical_state")
		if entry.get("name") != name: continue
		if not raw_id is String or raw_id.is_empty(): return _blocked("invalid_identity")
		var record: Variant = entry.get("record", {})
		if not record is Dictionary: return _blocked("invalid_physical_state")
		var quantity: int = _count(entry.get("source_reward_quantity", record.get("source_reward_quantity", 1)))
		if quantity <= 0: return _blocked("invalid_quantity")
		if record.has("source_reward_quantity") and _count(record.source_reward_quantity) != quantity:
			return _blocked("invalid_quantity")
		# Compare before adding to avoid overflow even in damaged saves.
		if quantity > owned - reserved: return _blocked("ownership_mismatch")
		reserved += quantity
	var selected_record: Dictionary = selected.get("record", {})
	var selected_quantity: int = _count(selected.get("source_reward_quantity", selected_record.get("source_reward_quantity", 1)))
	if selected_quantity != 1: return _blocked("stack_is_not_target")
	if _count(selected.get("level", 0)) < 0: return _blocked("invalid_level")
	# This copy is deliberately opaque. Preserve unknown options/receipts/honing
	# records without treating them as verified effects or rewriting their schema.
	return {"ok":true, "instance_id":instance_id, "name":name,
		"instance":selected.duplicate(true), "eligibility":"unverified"}

static func quote(inventory: Dictionary, physical: Dictionary, instance_id: String) -> Dictionary:
	var target: Dictionary = inspect(inventory, physical, instance_id)
	if not target.ok: return target
	# No boolean/config switch can enable consumption before source validation.
	return {"ok":false, "code":"source_rules_unverified", "target":target,
		"eligibility":"unverified", "costs":null, "probability":null,
		"failure_transition":null, "destruction_transition":null}

static func _blocked(code: String) -> Dictionary:
	return {"ok":false, "code":code}
