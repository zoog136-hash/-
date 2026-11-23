extends RefCounted
## A worker handoff of a newly built save payload. `owned` is private to the
## caller: only audited deep exporters may contribute roots, never live state.
## Exact root identity is required. Replacements (transaction overrides, trim
## results, unknown extension fields) are conservatively copied. No memo/cache
## survives the call, so nested edits and external changes cannot reuse a proof.
static func capture(owned: Dictionary, key: String, exported: Dictionary) -> Dictionary:
	owned[key] = exported
	return exported

static func freeze(data: Dictionary, owned: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(false)
	for key: Variant in data:
		var value: Variant = data[key]
		if owned.has(key) and is_same(value, owned[key]): continue
		if value is Dictionary or value is Array:
			result[key] = value.duplicate(true)
		elif typeof(value) >= TYPE_PACKED_BYTE_ARRAY and typeof(value) <= TYPE_PACKED_VECTOR4_ARRAY:
			result[key] = value.duplicate()
	return result
