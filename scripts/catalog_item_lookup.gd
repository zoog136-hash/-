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
const MAX_INDEXED_SOURCES: int = 6
static var _indexed_sources: Array = []
static var index_builds: int = 0

static func _index_entry(source: Array, force: bool = false) -> Dictionary:
	for position: int in range(_indexed_sources.size()):
		var entry: Dictionary = _indexed_sources[position]
		if is_same(entry.source, source):
			if not force and int(entry.size) == source.size(): return entry
			_indexed_sources.remove_at(position)
			break
	var index: Dictionary = {}
	for position: int in range(source.size()):
		var value: Variant = source[position]
		if not value is Dictionary: continue
		var item_name: String = str((value as Dictionary).get("name", ""))
		if not index.has(item_name): index[item_name] = position
	var built: Dictionary = {"source":source, "size":source.size(), "index":index}
	_indexed_sources.append(built)
	while _indexed_sources.size() > MAX_INDEXED_SOURCES: _indexed_sources.pop_front()
	index_builds += 1
	return built

static func _validated(source: Array, entry: Dictionary, item_name: String) -> Variant:
	var position: int = int((entry.index as Dictionary).get(item_name, -1))
	if position < 0 or position >= source.size(): return null
	var value: Variant = source[position]
	if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name: return value
	return null

## First record in `source` whose name is `item_name`, or {} when absent.
## Same result as a linear first-match scan, without the per-call scan on hits.
static func first_by_name(source: Array, item_name: String) -> Dictionary:
	var entry: Dictionary = _index_entry(source)
	var hit: Variant = _validated(source, entry, item_name)
	if hit == null and (entry.index as Dictionary).has(item_name):
		# The indexed slot changed in place. Rebuild once and trust the new index.
		hit = _validated(source, _index_entry(source, true), item_name)
	if hit != null: return hit as Dictionary
	for value: Variant in source:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			_index_entry(source, true)
			return value as Dictionary
	return {}

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
