extends RefCounted
## Off-main-thread preparation of original 523 bank inputs.
##
## A cold original bank load did all of its pure-data work on the main thread:
## read each SP2 member, SHA-256/CRC32 it, parse it (or read its device parse
## cache entry), pack it (sp2_compact_parse) and read + SHA-256 + parse every
## action JSON. On the phone one monster spawn recorded sp2.bank_load
## 143-354 ms, sp2.parse 85 ms and sp2.compact 47 ms inside one frame.
##
## Here that work runs on WorkerThreadPool tasks. A worker only touches
## FileAccess, HashingContext, PackedByteArray, JSON and the pure static
## parse/pack functions; never a Node, the SceneTree, RenderingServer, the
## frame-hitch log, the shared parsed-asset store or the bank's verified-member
## stamps. Results are handed back on the main thread (poll(), every process
## frame while work is in flight, or take(), which waits for a task still
## running). The bank then applies exactly the checks and bookkeeping of its
## synchronous path to the prepared values, so a prepared load equals the
## synchronous one; any integrity failure found by a worker is returned as the
## same rejection. Each result carries the file's size and modification time
## at the read: a file changed after that is never served from here.
const PARSE_CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const COMPACT = preload("res://scripts/resources/sp2_compact_parse.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

## false = every caller uses its synchronous path (as before this loader).
static var enabled: bool = true
## Completed results kept for their consumer, bounded (oldest first).
const MAX_READY: int = 96
const MAX_READY_BYTES: int = 96 * 1024 * 1024
## Queued/running tasks; further requests wait for a free slot (the caller
## stays deferred and asks again).
const MAX_INFLIGHT: int = 24

static var _inflight: Dictionary = {} # key -> Job
static var _ready: Dictionary = {} # key -> Job (insertion order = age)
static var _ready_bytes: int = 0
static var _pump: Pump = null
static var _crc_table: PackedInt64Array = PackedInt64Array()
## Diagnostics (tests and the frame-hitch log).
static var requested: int = 0
static var completed: int = 0
static var waited: int = 0
static var serial: int = 0 # increments whenever a result becomes ready
static var worker_threads: Dictionary = {} # thread caller id -> tasks

class Job:
	extends RefCounted
	var kind: String = ""
	var key: String = ""
	var label: String = ""
	var path: String = ""
	var expected_bytes: int = 0
	var max_bytes: int = 0
	var sha256: String = ""
	var crc32: String = ""
	var need_parse: bool = false
	var crc_table: PackedInt64Array
	var follow: Callable
	var work: Callable
	var hold: RefCounted = null # keeps the object `work` is bound to alive
	var task: int = -1
	var result: Dictionary = {}

	func run() -> void:
		var thread: int = OS.get_thread_caller_id()
		if kind == "call": result = {"value": work.call()}
		else: result = _member() if kind == "member" else _json()
		result["thread"] = thread

	func _stamp() -> Array:
		if not FileAccess.file_exists(path): return []
		return [int(FileAccess.get_size(path)), int(FileAccess.get_modified_time(path))]

	## Same reads, checks and messages as reference_sp2_bank._json().
	func _json() -> Dictionary:
		var stamp: Array = _stamp()
		var file := FileAccess.open(path, FileAccess.READ) if not stamp.is_empty() else null
		if file == null or file.get_length() <= 0 or file.get_length() > max_bytes:
			return {"stamp":stamp,"size":0,"value":{"ok":false,"error":"Missing or oversized bank JSON: " + path}}
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		if sha256.length() != 64 or hashing.finish().hex_encode() != sha256:
			return {"stamp":stamp,"size":bytes.size(),"value":{"ok":false,"error":"Bank JSON SHA256 mismatch: " + path}}
		var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not value is Dictionary:
			return {"stamp":stamp,"size":bytes.size(),"value":{"ok":false,"error":"Bank JSON is not an object."}}
		return {"stamp":stamp,"size":bytes.size(),"value":{"ok":true,"value":value},"members":_members_of(value)}

	## Members a bank load of this action JSON verifies (its drawn, non-null
	## layers). Only a prefetch hint: the bank still derives and checks every
	## address itself.
	static func _members_of(source: Dictionary) -> Array:
		var found: Dictionary = {}
		var actor: Variant = source.get("actor")
		if not actor is Dictionary or not actor.get("roles") is Dictionary: return []
		for track: Variant in actor.roles.values():
			if not track is Dictionary or not track.get("directions") is Array: continue
			for frames: Variant in track.directions:
				if not frames is Array: continue
				for frame: Variant in frames:
					if not frame is Dictionary or not frame.get("layers") is Array: continue
					for layer: Variant in frame.layers:
						if layer is Dictionary and not layer.has("client_null") and layer.get("member") is String: found[layer.member] = true
		return found.keys()

	## Same reads, checks, messages and parse/pack as reference_sp2_bank
	## _read_verified() + PARSE_CACHE.parse() + COMPACT.from_parse().
	func _member() -> Dictionary:
		var stamp: Array = _stamp()
		if stamp.is_empty() or int(stamp[0]) != expected_bytes:
			return {"stamp":stamp,"verified":false,"error":"Original SP2 missing or changed size: " + label}
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != expected_bytes:
			return {"stamp":stamp,"verified":false,"error":"Original SP2 missing or changed size: " + label}
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		if not sha256.is_empty():
			var hashing := HashingContext.new()
			hashing.start(HashingContext.HASH_SHA256)
			hashing.update(bytes)
			if hashing.finish().hex_encode() != sha256:
				return {"stamp":stamp,"verified":false,"error":"Original SP2 SHA256 mismatch: " + label}
		if not crc32.is_empty() and _crc(bytes) != crc32:
			return {"stamp":stamp,"verified":false,"error":"Received original SP2 CRC32 mismatch: " + label}
		var done: Dictionary = {"stamp":stamp,"verified":true,"raw_size":bytes.size(),"has_parse":need_parse}
		if not need_parse: return done
		var stats: Dictionary = {}
		var fresh: Dictionary = PARSE_CACHE.parse_off_main(bytes, sha256, stats)
		done["parse_stats"] = stats
		if not fresh.get("ok", false):
			done["parse_failure"] = fresh
			return done
		var packed: Dictionary = COMPACT.from_parse(fresh)
		done["parsed"] = packed
		done["cost"] = COMPACT.bytes_of(packed)
		return done

	func _crc(bytes: PackedByteArray) -> String:
		var value: int = 0xffffffff
		for byte: int in bytes: value = int(crc_table[(value ^ byte) & 255]) ^ (value >> 8)
		return "%08x" % ((value ^ 0xffffffff) & 0xffffffff)

## Polls on every process frame while any task is in flight.
## (No script reference is kept: static state -> pump -> script would be a
## reference cycle.)
class Pump:
	extends RefCounted
	var connected: bool = false
	func on_frame() -> void:
		load("res://scripts/resources/sp2_background_loader.gd").poll()

static func _ensure_pump() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null: return
	if _pump == null: _pump = Pump.new()
	if not _pump.connected:
		tree.process_frame.connect(_pump.on_frame)
		_pump.connected = true

static func _release_pump() -> void:
	if _pump == null: return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.process_frame.is_connected(_pump.on_frame): tree.process_frame.disconnect(_pump.on_frame)
	_pump.connected = false
	_pump = null

static func _on_main() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()

static func member_key(file_path: String, identity_key: String, bytes: int) -> String:
	return "member|%s|%s|%d" % [file_path, identity_key, bytes]

static func json_key(path: String, sha256: String) -> String:
	return "json|%s|%s" % [path, sha256]

static func busy() -> bool:
	return not _inflight.is_empty()

## Nothing running and nothing kept: loads skip their lookups here.
static func idle() -> bool:
	return _inflight.is_empty() and _ready.is_empty()

static func in_flight(key: String) -> bool:
	return _inflight.has(key)

## True while any of `keys` is still being prepared.
static func pending(keys: Array) -> bool:
	for key: Variant in keys:
		if _inflight.has(str(key)): return true
	return false

static func _current(job: Job) -> bool:
	if job.kind == "call": return true
	var stamp: Variant = job.result.get("stamp")
	if not stamp is Array or (stamp as Array).size() != 2: return false
	return FileAccess.file_exists(job.path) and int(FileAccess.get_size(job.path)) == int(stamp[0]) and int(FileAccess.get_modified_time(job.path)) == int(stamp[1])

## "none", "pending" or "ready" (a completed result for the file as it is now).
static func state(key: String) -> String:
	if _inflight.has(key):
		var job: Job = _inflight[key]
		if job.task >= 0 and WorkerThreadPool.is_task_completed(job.task): poll()
		else: return "pending"
	if _ready.has(key):
		if _current(_ready[key]): return "ready"
		_drop_ready(key)
	return "none"

static func request_member(label: String, file_path: String, spec: Dictionary, identity_key: String, need_parse: bool) -> bool:
	var key: String = member_key(file_path, identity_key, int(spec.get("bytes", 0)))
	if _inflight.has(key) or _ready.has(key): return true
	var job := Job.new()
	job.kind = "member"
	job.key = key
	job.label = label
	job.path = file_path
	job.expected_bytes = int(spec.get("bytes", 0))
	var sha: Variant = spec.get("sha256")
	job.sha256 = str(sha) if sha is String else ""
	job.crc32 = str(spec.get("crc32", "")) if job.sha256.is_empty() else ""
	job.need_parse = need_parse
	if not job.crc32.is_empty(): job.crc_table = _crc_rows()
	return _dispatch(job)

static func request_json(path: String, sha256: String, max_bytes: int, follow: Callable = Callable()) -> bool:
	var key: String = json_key(path, sha256)
	if _inflight.has(key) or _ready.has(key): return true
	var job := Job.new()
	job.kind = "json"
	job.key = key
	job.label = path
	job.path = path
	job.sha256 = sha256
	job.max_bytes = max_bytes
	job.follow = follow
	return _dispatch(job)

## Runs `work` (a pure-data Callable returning a Dictionary; it must touch no
## Node/SceneTree/shared main-thread state) on a worker. take(key) returns
## {"value": <its result>}.
static func request_call(key: String, work: Callable, hold: RefCounted = null) -> bool:
	if _inflight.has(key) or _ready.has(key): return true
	var job := Job.new()
	job.kind = "call"
	job.key = key
	job.label = key
	job.work = work
	job.hold = hold
	return _dispatch(job)

static func _dispatch(job: Job) -> bool:
	if not enabled or not _on_main(): return false
	if _inflight.size() >= MAX_INFLIGHT:
		FRAME_HITCH.count("sp2.bg_queue_full")
		return false
	# Lazily computed statics are prepared here, on the main thread, so no
	# worker ever initializes shared state.
	PARSE_CACHE.prepare_off_main()
	job.task = WorkerThreadPool.add_task(job.run, false, "sp2 original load")
	_inflight[job.key] = job
	requested += 1
	FRAME_HITCH.count("sp2.bg_requested")
	_ensure_pump()
	return true

static func _crc_rows() -> PackedInt64Array:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for index: int in range(256):
			var entry: int = index
			for bit: int in range(8): entry = (entry >> 1) ^ (0xedb88320 if (entry & 1) != 0 else 0)
			_crc_table[index] = entry
	return _crc_table

## Collects finished tasks (main thread only).
static func poll() -> void:
	if not _on_main() or _inflight.is_empty():
		if _inflight.is_empty(): _release_pump()
		return
	var finished: Array[Job] = []
	for job: Job in _inflight.values():
		if WorkerThreadPool.is_task_completed(job.task): finished.append(job)
	for job: Job in finished: _finish(job)
	if _inflight.is_empty(): _release_pump()

static func _finish(job: Job) -> void:
	WorkerThreadPool.wait_for_task_completion(job.task)
	job.work = Callable()
	job.hold = null
	_inflight.erase(job.key)
	job.task = -1
	completed += 1
	serial += 1
	var thread: int = int(job.result.get("thread", -1))
	worker_threads[thread] = int(worker_threads.get(thread, 0)) + 1
	var stats: Variant = job.result.get("parse_stats")
	if stats is Dictionary: PARSE_CACHE.apply_off_main_stats(stats)
	FRAME_HITCH.count("sp2.bg_completed")
	_ready[job.key] = job
	_ready_bytes += _weight(job)
	while _ready.size() > MAX_READY or (_ready_bytes > MAX_READY_BYTES and _ready.size() > 1):
		_drop_ready(_ready.keys()[0])
	# The follow-up may reference other scripts; never keep it (cycles).
	var follow: Callable = job.follow
	job.follow = Callable()
	if follow.is_valid() and _ready.has(job.key): follow.call(job.result)

static func _weight(job: Job) -> int:
	return int(job.result.get("cost", 0)) + int(job.result.get("size", 0))

static func _drop_ready(key: String) -> void:
	var job: Variant = _ready.get(key)
	if job == null: return
	_ready_bytes -= _weight(job)
	_ready.erase(key)

## The completed result for `key` while its file is unchanged, or {}. A task
## still running is waited for (its remaining time only, never a second read).
static func take(key: String, wait: bool = true, keep: bool = false) -> Dictionary:
	if not _on_main(): return {}
	if _inflight.has(key):
		var job: Job = _inflight[key]
		if not WorkerThreadPool.is_task_completed(job.task):
			if not wait: return {}
			var started: int = FRAME_HITCH.now()
			waited += 1
			FRAME_HITCH.count("sp2.bg_waited")
			_finish(job)
			FRAME_HITCH.detail("sp2.bg_wait", started)
		else:
			_finish(job)
		if _inflight.is_empty(): _release_pump()
	if not _ready.has(key): return {}
	var done: Job = _ready[key]
	if not keep: _drop_ready(key)
	if not _current(done):
		if keep: _drop_ready(key)
		FRAME_HITCH.count("sp2.bg_stale")
		return {}
	FRAME_HITCH.count("sp2.bg_used")
	return done.result

## Waits for every task (tests, map change) and forgets all results.
static func clear() -> void:
	for job: Job in _inflight.values(): WorkerThreadPool.wait_for_task_completion(job.task)
	_inflight.clear()
	_ready.clear()
	_ready_bytes = 0
	_release_pump()

static func reset_for_tests() -> void:
	clear()
	enabled = true
	requested = 0
	completed = 0
	waited = 0
	serial = 0
	worker_threads.clear()
