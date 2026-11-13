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
# - a miss falls back to the original linear scan once; the miss is then
#   remembered on that source's index entry until the array is replaced,
#   resized, re-indexed, or forget_misses() is called. Production only ever
#   replaces a slot in place with a record of the SAME name (catalog merges),
#   which never turns a remembered miss into a hit. Code that renames a slot
#   in place to a name that was already looked up must call forget_misses().
#   (Every attack resolved the selected ammo name several times; each miss was
#   a full scan of the boot catalogs, ~28 ms per call on a desktop CPU.)
#
# Memory: the index is a sorted PackedInt64Array of (String.hash() << 32 |
# first position), 8 bytes per distinct name, instead of a name -> position
# Dictionary (~70 bytes per entry; ~2.6 MB for the boot catalogs). Names whose
# hashes collide are all kept and told apart by the same validation, so the
# result is still exactly the linear first match. Appended names go to a small
# per-source tail Dictionary until the next rebuild.
const MAX_INDEXED_SOURCES: int = 6
const MAX_REMEMBERED_MISSES: int = 4096
const LOW32: int = 0xFFFFFFFF
static var _indexed_sources: Array = []
static var index_builds: int = 0
static var miss_scans: int = 0

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
					(entry.misses as Dictionary).erase(appended_name)
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
	var built: Dictionary = {"source":source, "size":source.size(), "keys":keys, "tail":{}, "misses":{}}
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
	var misses: Dictionary = _index_entry(source).misses
	if misses.has(item_name): return {}
	miss_scans += 1
	for value: Variant in source:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			_index_entry(source, true)
			return value as Dictionary
	if misses.size() >= MAX_REMEMBERED_MISSES: misses.clear()
	misses[item_name] = true
	return {}

## Drop every remembered miss (after renaming a slot in place).
static func forget_misses() -> void:
	for entry: Dictionary in _indexed_sources: (entry.misses as Dictionary).clear()

## Index bytes held across sources (probe/diagnostics).
static func index_metrics() -> Dictionary:
	var keys: int = 0
	var tail: int = 0
	for entry: Dictionary in _indexed_sources:
		keys += (entry.keys as PackedInt64Array).size()
		tail += (entry.tail as Dictionary).size()
	var misses: int = 0
	for entry: Dictionary in _indexed_sources: misses += (entry.misses as Dictionary).size()
	return {"sources":_indexed_sources.size(), "keys":keys, "tail":tail, "key_bytes":keys * 8, "misses":misses}

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

## A single synchronous cash install owns these sources and only appends through
## note_append(). Never use for arbitrary live catalogs or callback providers.
## Public find_one()/first_by_name() retain their self-validating behavior.
class CashInstallScope extends RefCounted:
	const REMOVED = preload("res://scripts/consumable_rules.gd")
	var active: bool = true
	var rows: Array = []
	var sizes: Array[int] = []
	var names: Array[Dictionary] = []
	func _init(sources: Array) -> void:
		for source: Variant in sources:
			if not source is Array: active = false; return
			rows.append(source); sizes.append(source.size())
			var first: Dictionary = {}
			for at: int in range(source.size()):
				var value: Variant = source[at]
				if value is Dictionary:
					var name: String = str(value.get("name", ""))
					if not first.has(name): first[name] = at
			names.append(first)
	func valid_sources(sources: Array) -> bool:
		if not active or sources.size() != rows.size(): return false
		for at: int in range(rows.size()):
			if not is_same(sources[at],rows[at]) or rows[at].size() != sizes[at]:
				active = false; return false
		return true
	func note_append(source: Array) -> void:
		if not active: return
		for at: int in range(rows.size()):
			if not is_same(source,rows[at]): continue
			if source.size() != sizes[at]+1: active = false; return
			var value: Variant = source[-1]
			if value is Dictionary:
				var name: String = str(value.get("name", ""))
				if not names[at].has(name): names[at][name] = sizes[at]
			sizes[at] = source.size()
			return
		active = false
	## null requests the original public lookup; {} is a proven scoped miss.
	func find_one(sources: Array, instances: Dictionary, name: String) -> Variant:
		if not valid_sources(sources): return null
		if REMOVED.is_removed_item(name): return {}
		for at: int in range(rows.size()):
			if not names[at].has(name): continue
			var value: Variant = rows[at][int(names[at][name])]
			if not value is Dictionary or str(value.get("name", "")) != name:
				active = false; return null
			# Public find_one skips an empty first match for this whole source.
			if not value.is_empty(): return value
		for value: Variant in instances.values():
			if value is Dictionary and str(value.get("name", "")) == name and value.get("record", {}) is Dictionary:
				return value.get("record", {}).duplicate(true)
		return {}
	func close() -> void:
		active = false; rows.clear(); sizes.clear(); names.clear()
