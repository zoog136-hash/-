extends RefCounted

const RULES = preload("res://scripts/consumable_rules.gd")

# Resolve a poll's requested names in one scan. Do not retain an index across
# catalog edits, generated equipment changes, save loads, or class changes.
# (The single-name helpers below keep a self-validating index; see there.)
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

# --- Indexed single-name lookups ---------------------------------------------
# Hot paths (every HUD refresh, every save, every bag redraw and grade sort)
# resolve one name at a time against the 2,000+ record catalog. A linear scan per
# name made a 150-entry bag cost ~70 ms per refresh and ~1.2 s to grade-sort on a
# desktop CPU. These helpers return exactly what a linear first-match scan would:
# - the index only stores the first position of each name;
# - every hit is re-validated against the live array, so in-place replacement
#   (catalog merges, fixtures) rebuilds the index instead of returning stale data;
# - a replaced or resized array is detected by identity and size;
# - every miss falls back to the original linear scan, so a name added in place
#   is still found (misses keep their previous cost; hits become O(1)).
#
# Memory: the index is a sorted PackedInt64Array of (String.hash() << 32 |
# first position), 8 bytes per distinct name, instead of a name -> position
# Dictionary (~70 bytes per entry; ~2.6 MB for the boot catalogs). Names whose
# hashes collide are all kept and told apart by the same validation, so the
# result is still exactly the linear first match. Appended names go to a small
# per-source tail Dictionary until the next rebuild.
const MAX_INDEXED_SOURCES: int = 6
const LOW32: int = 0xFFFFFFFF
static var _indexed_sources: Array = []
static var index_builds: int = 0

static func _name_of(value: Variant) -> String:
	return str((value as Dictionary).get("name", "")) if value is Dictionary else ""

static func _index_entry(source: Array, force: bool = false) -> Dictionary:
	for position: int in range(_indexed_sources.size()):
		var entry: Dictionary = _indexed_sources[position]
		if is_same(entry.source, source):
			if not force and int(entry.size) == source.size(): return entry
			if not force and source.size() > int(entry.size):
				# Records were appended (services registering items one by one):
				# index only the new tail instead of every record again. A slot
				# that changed in place is still caught by validation.
				var tail: Dictionary = entry.tail
				for added: int in range(int(entry.size), source.size()):
					var appended: Variant = source[added]
					if not appended is Dictionary: continue
					var appended_name: String = _name_of(appended)
					if not tail.has(appended_name) and _candidates(source, entry, appended_name).is_empty(): tail[appended_name] = added
				entry.size = source.size()
				return entry
			_indexed_sources.remove_at(position)
			break
	var seen: Dictionary = {}
	var keys := PackedInt64Array()
	for position: int in range(source.size()):
		var value: Variant = source[position]
		if not value is Dictionary: continue
		var item_name: String = _name_of(value)
		if seen.has(item_name): continue
		seen[item_name] = true
		keys.append(((item_name.hash() & LOW32) << 32) | position)
	keys.sort()
	var built: Dictionary = {"source":source, "size":source.size(), "keys":keys, "tail":{}}
	_indexed_sources.append(built)
	while _indexed_sources.size() > MAX_INDEXED_SOURCES: _indexed_sources.pop_front()
	index_builds += 1
	return built

## Indexed positions that may hold `item_name` (the tail entry, then every
## position whose name hash matches). Not yet validated against `source`.
static func _candidates(_source_array: Array, entry: Dictionary, item_name: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	var tail: Dictionary = entry.tail
	if tail.has(item_name): result.append(int(tail[item_name]))
	var digest: int = item_name.hash() & LOW32
	var keys: PackedInt64Array = entry.keys
	var at: int = keys.bsearch(digest << 32, true)
	while at < keys.size() and ((keys[at] >> 32) & LOW32) == digest:
		result.append(keys[at] & LOW32)
		at += 1
	return result

static func _validated(source: Array, entry: Dictionary, item_name: String) -> Variant:
	# Earliest validated candidate: one name has at most one indexed position;
	# others in the list are hash collisions and fail the name check.
	var best: int = -1
	for position: int in _candidates(source, entry, item_name):
		if position < 0 or position >= source.size() or (best >= 0 and position >= best): continue
		var value: Variant = source[position]
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name: best = position
	return source[best] if best >= 0 else null

## First record in `source` whose name is `item_name`, or {} when absent.
## Same result as a linear first-match scan, without the per-call scan on hits.
static func first_by_name(source: Array, item_name: String) -> Dictionary:
	var entry: Dictionary = _index_entry(source)
	var hit: Variant = _validated(source, entry, item_name)
	if hit == null and not _candidates(source, entry, item_name).is_empty():
		# The indexed slot changed in place. Rebuild once and trust the new index.
		hit = _validated(source, _index_entry(source, true), item_name)
	if hit != null: return hit as Dictionary
	for value: Variant in source:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			_index_entry(source, true)
			return value as Dictionary
	return {}

## Index bytes held across sources (probe/diagnostics).
static func index_metrics() -> Dictionary:
	var keys: int = 0
	var tail: int = 0
	for entry: Dictionary in _indexed_sources:
		keys += (entry.keys as PackedInt64Array).size()
		tail += (entry.tail as Dictionary).size()
	return {"sources":_indexed_sources.size(), "keys":keys, "tail":tail, "key_bytes":keys * 8}

## Equivalent to find_many(sources, instances, [item_name]).get(item_name, {}).
static func find_one(sources: Array, instances: Dictionary, item_name: String) -> Dictionary:
	if RULES.is_removed_item(item_name): return {}
	for source: Variant in sources:
		if not source is Array: continue
		# A match always carries its "name" key, so {} unambiguously means absent.
		var record: Dictionary = first_by_name(source as Array, item_name)
		if not record.is_empty(): return record
	for value: Variant in instances.values():
		if not value is Dictionary: continue
		if str(value.get("name", "")) == item_name and value.get("record", {}) is Dictionary:
			return value.get("record", {}).duplicate(true)
	return {}
