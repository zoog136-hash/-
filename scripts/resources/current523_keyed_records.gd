extends RefCounted
## Keyed sections of a derived original model kept on device storage and read
## one entry at a time (Lineage M style: data stays on storage, only what is
## used is in memory).
##
## A producer splits its model into a small resident `head` and keyed
## `sections` (section -> {key -> value}). write() streams every entry into one
## record bake (current523_bake_cache.gd record_writer / finish_records, keyed
## by the producer's key: verified original identity + code key), reopens it
## and verifies its index; open() reopens an existing bake. Reads go through a
## small LRU, so a value read again shortly is the same instance and the
## resident cost is bounded by `capacity` entries instead of the whole model.
## Values read are exactly the values written (one var encoding per entry);
## section key order is kept for iteration.
##
## Storage failures (create / append / commit / reopen / index) return null;
## the producer applies the bake cache's policy (disk_required()).

const BAKE := preload("res://scripts/resources/current523_bake_cache.gd")
const LOG := preload("res://scripts/boot/boot_progress_log.gd")
const SEP := "\u001f"
const HEAD := "\u0001head"
const INDEX := "\u0001index"
const SCHEMA := "twilight.current523.keyed-records.v1"
const DEFAULT_CAPACITY: int = 24

static func id_of(section: String, key: String) -> String:
	return section + SEP + key

## Writes `head` and every section entry, then reopens and verifies the bake.
## null when any step fails (the writer's .part file is removed by the cache).
static func write(bake_name: String, value_key: String, head_value: Variant, sections: Dictionary, entry_capacity: int = DEFAULT_CAPACITY) -> Store:
	var writer = BAKE.record_writer(bake_name, value_key)
	if writer == null: return null
	var index: Dictionary = {"schema": SCHEMA, "sections": {}}
	for section: String in sections:
		var ids := PackedStringArray()
		var entries: Dictionary = sections[section]
		for key: Variant in entries:
			ids.append(str(key))
			writer.add(id_of(section, str(key)), entries[key])
		index.sections[section] = ids
	writer.add(HEAD, head_value)
	# Written last: an index lacking any record fails open() below.
	writer.add(INDEX, index)
	if not BAKE.finish_records(writer): return null
	var store: Store = open(bake_name, value_key, entry_capacity)
	if store == null: BAKE._failed(bake_name, "reopen", "verify_fail")
	return store

## The verified bake for `value_key`, or null (missing, stale, damaged index).
static func open(bake_name: String, value_key: String, entry_capacity: int = DEFAULT_CAPACITY) -> Store:
	if value_key.is_empty(): return null
	var file = BAKE.open_records(bake_name, value_key)
	if file == null: return null
	var index: Variant = file.read(INDEX) if file.has(INDEX) else null
	if not index is Dictionary or index.get("schema") != SCHEMA or not index.get("sections") is Dictionary or not file.has(HEAD):
		LOG.io(bake_name, "index", "corrupt")
		return null
	for section: Variant in index.sections:
		if not index.sections[section] is PackedStringArray:
			LOG.io(bake_name, "index", "corrupt")
			return null
		for key: String in index.sections[section]:
			if not file.has(id_of(str(section), key)):
				LOG.io(bake_name, "index", "corrupt")
				return null
	var head_value: Variant = file.read(HEAD)
	if head_value == null:
		LOG.io(bake_name, "index", "corrupt")
		return null
	var store := Store.new()
	store.name = bake_name
	store.records = file
	store.keys = index.sections
	store.head = head_value
	store.capacity = maxi(1, entry_capacity)
	return store

class Store extends RefCounted:
	var name: String = ""
	var records: RefCounted = null
	## section -> PackedStringArray of keys in model order (small, resident).
	var keys: Dictionary = {}
	var head: Variant = null
	var capacity: int = DEFAULT_CAPACITY
	## Test-visible: entries read from storage (LRU misses) and the last read problem.
	var reads: int = 0
	var problem: String = ""
	var _cache: Dictionary = {}

	func has(section: String, key: String) -> bool:
		return records != null and records.has(section + SEP + key)

	func section_keys(section: String) -> PackedStringArray:
		return keys.get(section, PackedStringArray())

	## The stored value, or `fallback` when the section has no such key.
	func value(section: String, key: String, fallback: Variant = null) -> Variant:
		var id: String = section + SEP + key
		if _cache.has(id):
			var hit: Variant = _cache[id]
			_cache.erase(id)
			_cache[id] = hit
			return hit
		if records == null or not records.has(id): return fallback
		var stored: Variant = records.read(id)
		reads += 1
		if stored == null:
			# The file went away or was damaged after it was verified: reported,
			# never replaced by a guess.
			problem = "read_fail:" + id
			LOG.io(name, "read", "fail")
			return fallback
		_cache[id] = stored
		while _cache.size() > capacity: _cache.erase(_cache.keys()[0])
		return stored

	func cached() -> int:
		return _cache.size()

	func release_cache() -> void:
		_cache.clear()
