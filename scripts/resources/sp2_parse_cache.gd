extends RefCounted
## Device cache of SP2 parses (user://sp2_parse_cache).
##
## Placing one 523 monster parsed every SP2 member of every role and direction
## in GDScript (an 833 KB member: ~40-50 ms on a desktop CPU, several times
## that on a phone); the phone recorded a 16 s "몬스터 배치" frame. The parse
## result (without the raw/body bytes) is stored once per verified original and
## read back with the engine's native bytes_to_var (~5 ms for the same member).
##
## The key is the SHA-256 of the original bytes being parsed (passed in when
## already verified, hashed natively otherwise) and their size, the decoder
## script's bytes, this format and the engine version, so a
## changed original or decoder never reuses an entry. Each entry carries the
## SHA-256 of its payload; any mismatch, missing file or decode problem falls
## back to a fresh DECODER.parse(). Nothing here changes what the parse is.
const DECODER_PATH := "res://scripts/resources/current523_sp2_decoder.gd"
const DECODER = preload(DECODER_PATH)
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const FORMAT := "twilight.sp2-parse.v1"
const MAGIC := "TWSP2C1"
## Entries above this total are removed oldest first (checked every PRUNE_EVERY writes).
const MAX_TOTAL_BYTES: int = 384 * 1024 * 1024
const PRUNE_EVERY: int = 32

static var root: String = "user://sp2_parse_cache"
static var enabled: bool = true
static var hits: int = 0
static var misses: int = 0
static var writes: int = 0
static var rejects: int = 0
static var _code: String = ""
static var _writes_since_prune: int = 0
## Engine.print_error_messages is process global. The decoder and _body_of()
## turn it off around a Brotli decompress and restore it; a worker doing the
## same at the same time could restore a stale value. Every toggle therefore
## holds this lock: the main-thread parse() for its whole call, a worker
## (parse_off_main) only around its own decompress.
static var _quiet: Mutex = Mutex.new()

static func _code_key() -> String:
	if _code.is_empty(): _code = BAKE.code_key([DECODER_PATH])
	return _code

## The cache key for a verified original, or "" when no stable key exists.
static func key_for(identity: String, size: int) -> String:
	if identity.is_empty() or size <= 0: return ""
	var code: String = _code_key()
	if code.is_empty(): return ""
	return ("|".join(PackedStringArray([FORMAT, identity, str(size), code, BAKE.engine_key()]))).sha256_text()

static func path_for(key: String) -> String:
	return root.path_join(key.left(48) + ".bin")

## DECODER.parse(raw), from the device cache when an entry for these exact
## bytes exists. `raw_sha256` may be the already verified SHA-256 of `raw`.
static func parse(raw: PackedByteArray, raw_sha256: String = "") -> Dictionary:
	var started: int = FRAME_HITCH.now()
	_quiet.lock()
	var result: Dictionary = _parse(raw, raw_sha256)
	_quiet.unlock()
	FRAME_HITCH.detail("sp2.parse", started)
	return result

## DECODER.parse(raw) for other main-thread callers, holding the same lock.
static func decode_locked(raw: PackedByteArray) -> Dictionary:
	_quiet.lock()
	var result: Dictionary = DECODER.parse(raw)
	_quiet.unlock()
	return result

## Lazily computed statics a worker reads; called on the main thread before
## any parse_off_main() task is started.
static func prepare_off_main() -> void:
	_code_key()

## parse() for a worker thread (sp2_background_loader.gd): the same cache key,
## entry checks, writes and DECODER result, without the frame-hitch log, the
## shared counters or pruning. Counts go to `stats`; the main thread applies
## them with apply_off_main_stats(). The Brotli body is decompressed once,
## under _quiet, and the decoder's remaining steps run on it unchanged.
static func parse_off_main(raw: PackedByteArray, raw_sha256: String, stats: Dictionary) -> Dictionary:
	var body: Variant = null
	if not raw.is_empty() and raw.size() <= DECODER.MAX_INPUT_BYTES:
		if raw[0] == 254: body = raw
		else:
			_quiet.lock()
			var previous_errors: bool = Engine.print_error_messages
			Engine.print_error_messages = false
			body = raw.decompress(DECODER.MAX_BODY_BYTES, FileAccess.COMPRESSION_BROTLI)
			Engine.print_error_messages = previous_errors
			_quiet.unlock()
	return _parse(raw, raw_sha256, stats, body)

static func apply_off_main_stats(stats: Dictionary) -> void:
	hits += int(stats.get("hits", 0))
	misses += int(stats.get("misses", 0))
	rejects += int(stats.get("rejects", 0))
	for name: String in ["hits", "misses", "rejects"]:
		if int(stats.get(name, 0)) > 0: FRAME_HITCH.count({"hits":"sp2.disk_hit","misses":"sp2.disk_miss","rejects":"sp2.disk_reject"}[name], int(stats[name]))
	var written: int = int(stats.get("writes", 0))
	if written <= 0: return
	writes += written
	_writes_since_prune += written
	if _writes_since_prune >= PRUNE_EVERY:
		_writes_since_prune = 0
		prune(MAX_TOTAL_BYTES)

## DECODER.parse(raw) given its FE body (raw itself, or raw's Brotli
## decompression): the decoder's steps after its decompress, unchanged.
## Pinned equal to DECODER.parse by tests/sp2_background_load_test.gd.
static func _decode_body(raw: PackedByteArray, body: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size() > DECODER.MAX_INPUT_BYTES or raw[0] == 254: return DECODER.parse(raw)
	if body.size() < 2 or body.size() > DECODER.MAX_BODY_BYTES or body[0] != 254:
		return DECODER._fail("Invalid, incomplete or oversized Brotli/FE SP2 body.")
	var marker: int = body[1]
	var layouts: Array = [1,3] if marker == 1 else [256 if marker == 0 else marker]
	var passed: Array[Dictionary] = []
	var errors: Array[String] = []
	for entries: int in layouts:
		var candidate: Dictionary = DECODER._parse_candidate(body,entries)
		if candidate.ok: passed.append(candidate)
		else: errors.append(str(candidate.error))
	if passed.size() != 1:
		return DECODER._fail("SP2 palette marker %d has %d complete valid layouts: %s" % [marker,passed.size(),"; ".join(errors)])
	var parsed: Dictionary = passed[0]
	parsed["raw"] = raw
	parsed["body"] = body
	parsed["palette_marker"] = marker
	parsed["estimated"] = true
	return parsed

static func _count(stats: Variant, name: String, hitch: String) -> void:
	if stats is Dictionary:
		stats[name] = int(stats.get(name, 0)) + 1
		return
	match name:
		"hits": hits += 1
		"misses": misses += 1
		"rejects": rejects += 1
	FRAME_HITCH.count(hitch)

static func _parse(raw: PackedByteArray, raw_sha256: String, stats: Variant = null, body: Variant = null) -> Dictionary:
	if not enabled or raw.is_empty() or raw.size() > DECODER.MAX_INPUT_BYTES: return DECODER.parse(raw) if body == null else _decode_body(raw, body)
	var digest: String = raw_sha256
	if digest.length() != 64:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(raw)
		digest = hashing.finish().hex_encode()
	var key: String = key_for("sha256:" + digest, raw.size())
	if key.is_empty(): return DECODER.parse(raw) if body == null else _decode_body(raw, body)
	var cached: Dictionary = _read(key, raw, stats, body)
	if not cached.is_empty():
		_count(stats, "hits", "sp2.disk_hit")
		return cached
	_count(stats, "misses", "sp2.disk_miss")
	var fresh: Dictionary = DECODER.parse(raw) if body == null else _decode_body(raw, body)
	if fresh.get("ok", false): _write(key, fresh, stats)
	return fresh

static func _body_of(raw: PackedByteArray) -> PackedByteArray:
	if raw.is_empty() or raw[0] == 254: return raw
	var previous_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var body: PackedByteArray = raw.decompress(DECODER.MAX_BODY_BYTES, FileAccess.COMPRESSION_BROTLI)
	Engine.print_error_messages = previous_errors
	return body

static func _read(key: String, raw: PackedByteArray, stats: Variant = null, known_body: Variant = null) -> Dictionary:
	var path: String = path_for(key)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var magic: String = file.get_pascal_string()
	var stored_key: String = file.get_pascal_string()
	var payload_sha: String = file.get_pascal_string()
	var body_size: int = int(file.get_64())
	var payload_size: int = int(file.get_64())
	if magic != MAGIC or stored_key != key or payload_size <= 0 or payload_size > 256 * 1024 * 1024 or file.get_position() + payload_size != file.get_length():
		file.close()
		_reject(path, stats)
		return {}
	var payload: PackedByteArray = file.get_buffer(payload_size)
	file.close()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(payload)
	if payload.size() != payload_size or hashing.finish().hex_encode() != payload_sha:
		_reject(path, stats)
		return {}
	var value: Variant = bytes_to_var(payload)
	if not value is Dictionary or not (value as Dictionary).get("ok", false):
		_reject(path, stats)
		return {}
	var body: PackedByteArray = _body_of(raw) if known_body == null else known_body
	if body.size() != body_size:
		_reject(path, stats)
		return {}
	var parsed: Dictionary = value
	parsed["raw"] = raw
	parsed["body"] = body
	return parsed

static func _reject(path: String, stats: Variant = null) -> void:
	_count(stats, "rejects", "sp2.disk_reject")
	DirAccess.remove_absolute(path)

static func _write(key: String, parsed: Dictionary, stats: Variant = null) -> void:
	var stored: Dictionary = parsed.duplicate()
	var body: PackedByteArray = stored.get("body", PackedByteArray())
	stored.erase("raw")
	stored.erase("body")
	var payload: PackedByteArray = var_to_bytes(stored)
	if not DirAccess.dir_exists_absolute(root): DirAccess.make_dir_recursive_absolute(root)
	var path: String = path_for(key)
	# Two workers may write the same entry (identical bytes of two members).
	var part: String = path + (".part" if stats == null else ".%d.part" % OS.get_thread_caller_id())
	var file := FileAccess.open(part, FileAccess.WRITE)
	if file == null: return
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(payload)
	file.store_pascal_string(MAGIC)
	file.store_pascal_string(key)
	file.store_pascal_string(hashing.finish().hex_encode())
	file.store_64(body.size())
	file.store_64(payload.size())
	var ok: bool = file.store_buffer(payload) and file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(part, path) != OK:
		DirAccess.remove_absolute(part)
		return
	if stats is Dictionary:
		stats["writes"] = int(stats.get("writes", 0)) + 1
		return
	writes += 1
	_writes_since_prune += 1
	if _writes_since_prune >= PRUNE_EVERY:
		_writes_since_prune = 0
		prune(MAX_TOTAL_BYTES)

## Removes the oldest entries until the cache holds at most `limit` bytes.
static func prune(limit: int) -> int:
	var dir := DirAccess.open(root)
	if dir == null: return 0
	var entries: Array = []
	var total: int = 0
	for name: String in dir.get_files():
		var path: String = root.path_join(name)
		if name.ends_with(".part"):
			DirAccess.remove_absolute(path)
			continue
		var size: int = int(FileAccess.get_size(path))
		total += size
		entries.append([int(FileAccess.get_modified_time(path)), path, size])
	if total <= limit: return 0
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var removed: int = 0
	for entry: Array in entries:
		if total <= limit: break
		DirAccess.remove_absolute(str(entry[1]))
		total -= int(entry[2])
		removed += 1
	return removed

static func reset_for_test(directory: String) -> void:
	root = directory
	enabled = true
	hits = 0
	misses = 0
	writes = 0
	rejects = 0
	_writes_since_prune = 0
