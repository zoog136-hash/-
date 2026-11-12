extends RefCounted
## One-shot ownership transfer of already verified map/tile metadata readers.
## The worker publishes only successful readers; the main thread consumes them
## after joining it. No files, Boolean acceptances or cross-run state are cached.
## A fresh manifest SHA check is mandatory on take; original member/texture
## byte verification remains in the readers at the point of actual consumption.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
static var _mutex: Mutex = Mutex.new()
static var _pending: Dictionary = {}

static func put(id: String, root: String, sha: String, reader: RefCounted) -> void:
	if id not in ["maps", "tiles"] or reader == null or not reader.has_method("matches_manifest"): return
	_mutex.lock()
	_pending[id] = {"root": root, "sha": sha, "reader": reader}
	_mutex.unlock()

static func take(id: String, root: String, sha: String) -> RefCounted:
	_mutex.lock()
	var entry: Dictionary = _pending.get(id, {})
	# A different selection must neither adopt nor consume the prepared one.
	if entry.is_empty() or entry.root != root or entry.sha != sha:
		_mutex.unlock()
		return null
	_pending.erase(id)
	_mutex.unlock()
	var reader: RefCounted = entry.reader
	if not bool(reader.call("matches_manifest", root, sha)): return null
	# The retained offset index still reads its already-open bake file. Preserve
	# the persisted-byte SHA check of a normal reopen before transferring it;
	# only the duplicate index construction and metadata decoding are avoided.
	if reader.get("_records") != null:
		var name: String = str(reader.call("bake_name_for", sha))
		var key: String = str(reader.call("bake_key_for", sha))
		if BAKE.verified_file(name, key).is_empty(): return null
	return reader

## Called after a cancelled boot/retry so no old reader survives that attempt.
static func clear() -> void:
	_mutex.lock()
	_pending.clear()
	_mutex.unlock()
