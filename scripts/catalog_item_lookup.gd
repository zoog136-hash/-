extends RefCounted

const RULES = preload("res://scripts/consumable_rules.gd")

# Resolve a poll's requested names in one scan. Do not retain an index across
# catalog edits, generated equipment changes, save loads, or class changes.
static func find_many(sources: Array, instances: Dictionary, names: Array) -> Dictionary:
	var missing: Dictionary = {}
	for value: Variant in names:
		var item_name: String = str(value)
		if not RULES.is_removed_item(item_name): missing[item_name] = true
	var found: Dictionary = {}
	for source: Variant in sources:
		if missing.is_empty(): return found
		if not source is Array: continue
		for value: Variant in source:
			if not value is Dictionary: continue
			var item_name: String = str(value.get("name", ""))
			if missing.has(item_name):
				found[item_name] = value
				missing.erase(item_name)
				if missing.is_empty(): return found
	for value: Variant in instances.values():
		if not value is Dictionary: continue
		var item_name: String = str(value.get("name", ""))
		if missing.has(item_name) and value.get("record", {}) is Dictionary:
			found[item_name] = value.get("record", {}).duplicate(true)
			missing.erase(item_name)
			if missing.is_empty(): break
	return found
