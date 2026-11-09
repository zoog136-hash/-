extends RefCounted
## Shares identical read-only sub-values (Lineage M style "one copy per value").
##
## Derived original data repeats the same rows many times (a reward's full
## ItemClass row in every quest that grants it, the archive identity in every
## evidence entry). After a JSON parse or a bake read every repetition is its
## own Dictionary (~1 KB each). intern() replaces equal Dictionaries/Arrays
## with one shared instance; values compare equal before and after, only
## identity changes. Use it only on data its owner treats as read-only.

## Interns `value` in place where possible and returns the canonical value.
## `pool` (content hash -> instances) may be reused across calls so equal
## values in different structures are shared.
static func intern(value: Variant, pool: Dictionary, depth: int = 6) -> Variant:
	if depth < 0: return value
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.is_read_only(): return value
		for key: Variant in dictionary.keys():
			var child: Variant = dictionary[key]
			if child is Dictionary or child is Array: dictionary[key] = intern(child, pool, depth - 1)
		return _canonical(value, pool)
	if value is Array:
		var array: Array = value
		if array.is_read_only(): return value
		for index: int in array.size():
			var child: Variant = array[index]
			if child is Dictionary or child is Array: array[index] = intern(child, pool, depth - 1)
		return _canonical(value, pool)
	return value

static func _canonical(value: Variant, pool: Dictionary) -> Variant:
	# Empty containers are cheap and the likeliest to be filled later: never shared.
	if (value is Dictionary or value is Array) and value.is_empty(): return value
	# Content hash, then a deep equality check (same type and same entries in
	# the same order), so only truly equal values are shared.
	var digest: int = hash(value)
	var candidates: Variant = pool.get(digest)
	if candidates is Array:
		for known: Variant in candidates:
			if typeof(known) == typeof(value) and _same(known, value): return known
		(candidates as Array).append(value)
	else: pool[digest] = [value]
	return value

static func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size() or (a as Dictionary).keys() != (b as Dictionary).keys(): return false
		if a is Dictionary and (a as Dictionary).is_typed() != (b as Dictionary).is_typed(): return false
	elif a is Array:
		if (a as Array).is_typed() != (b as Array).is_typed() or (a as Array).get_typed_builtin() != (b as Array).get_typed_builtin(): return false
	return var_to_bytes(a) == var_to_bytes(b)
