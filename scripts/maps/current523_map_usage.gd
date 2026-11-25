extends RefCounted
## Partial, source-backed Main draw observations. Never a whole-file95% counter.
const WRITER=preload("res://scripts/skills/save_writer.gd")
const PATH="user://current523_map_consumption_v1.json"
const INVENTORY_SHA="c395f35afa067dfad04db3d615c7f39acbdea7134ae8f2023bbbf75c5639f1b7"
const DENOMINATOR={"Map":{"files":8311,"original_member_bytes":994755558},"Tile":{"files":8514,"original_member_bytes":297767184}}
## Main-thread bounded inbox. The worker alone owns the full v1 ledger.
const FLUSH_INTERVAL_MSEC: int = 10000
const MAX_PENDING: int = 2048
const MAX_PENDING_BYTES: int = 4 * 1024 * 1024
const MAX_RECENT: int = 2048
const MAX_RETAINED: int = 256
const MAX_RETAINED_BYTES: int = 512 * 1024
enum Observation { ACCEPTED, RETAINED, INVALID, DISABLED, DROPPED }
static var _retained: Array = []
static var _retained_bytes: int = 0
static var _dropped: int = 0
static var _committed_drops: int = 0
static var _recorded: Dictionary = {}
static var _pending: Array = []
static var _pending_bytes: int = 0
static var _task: int = -1
static var _result: Array = []
static var _worker: LedgerWorker
static var _last_flush: int = 0
static var _force: bool = false
static var _dirty: bool = false
static var _disabled: bool = false
static var _member_count: int = 0
static var _accepted: int = 0
static var _committed: int = 0
static var _rejected: int = 0
static var _conflicts: int = 0
static var _inflight: int = 0
static var _last_worker_usec: int = 0
static var problem: String = ""

static func actual_main(renderer: Node) -> bool:
	if DisplayServer.get_name()=="headless" or not is_instance_valid(renderer) or not renderer is CanvasItem or not renderer.is_visible_in_tree():return false
	var world: Node=renderer.get_parent()
	if world==null or world.scene_file_path!="res://Main.tscn":return false
	# Main uses the existing potion-feedback World subclass. Validate its real
	# inheritance chain rather than mistaking that subclass for an inspection.
	var script: Script=world.get_script()
	var owns_world: bool=false
	while script!=null:
		if script.resource_path=="res://scripts/world.gd":owns_world=true;break
		script=script.get_base_script()
	if not owns_world:return false
	return world.get("field_renderer")==renderer and bool(world.get("current523_aden_play_active")) and renderer.get("field")!=null and bool(renderer.get("field").get_meta("current523_source_field",false))

static func _origin() -> String:
	for arg: String in OS.get_cmdline_args():
		if arg in ["--script","-s"] or arg.begins_with("res://tests/"):return "AUTOMATED_ACTUAL_MAIN"
	return "USER_MAIN"

## Render-facing: no file access, JSON, deep copy, worker join or submission.
## Accepted/retained evidence is owned by the broker, even if never drawn again.
static func observe(renderer: Node, member: String, original_bytes: int, sha256: String, unit: String, source_offset: int=-1, source_length: int=0) -> bool:
	return observe_result(renderer, member, original_bytes, sha256, unit, source_offset, source_length) in [Observation.ACCEPTED, Observation.RETAINED]

static func observe_result(renderer: Node, member: String, original_bytes: int, sha256: String, unit: String, source_offset: int=-1, source_length: int=0) -> Observation:
	var seen_key: String=member+"|"+sha256+"|"+str(original_bytes)+"|"+unit+"|"+str(source_offset)+"|"+str(source_length)
	if _recorded.has(seen_key):return Observation.ACCEPTED
	if not actual_main(renderer): return Observation.INVALID
	return _enqueue_result(member, original_bytes, sha256, unit, source_offset, source_length, _origin(), seen_key)

## One synchronous ground draw has one visible Main and one observation origin.
## Keep ref order across atlases so the same events survive queue pressure.
static func observe_ground_refs(renderer: Node, tile_pack: RefCounted, refs: Dictionary) -> void:
	if refs.is_empty() or not actual_main(renderer): return
	var origin: String = _origin()
	var sources: Dictionary = {}
	for ref: int in refs:
		var tile_id: int = ref >> 8
		if not sources.has(tile_id):
			var identity: Dictionary = tile_pack.source_usage_identity(tile_id)
			if identity.is_empty():
				sources[tile_id] = {}
			else:
				var member: String = str(identity.member)
				var sha: String = str(identity.sha256)
				var bytes: int = int(identity.bytes)
				sources[tile_id] = {"member": member, "sha": sha, "bytes": bytes,
					"key_prefix": member + "|" + sha + "|" + str(bytes) + "|"}
		var source: Dictionary = sources[tile_id]
		if source.is_empty(): continue
		var unit: String = "subimage:" + str(ref & 255)
		var seen_key: String = source.key_prefix + unit + "|-1|0"
		if not _recorded.has(seen_key):
			_enqueue_result(source.member, source.bytes, source.sha, unit, -1, 0, origin, seen_key)

## Internal synthetic ingress. Public entry retains the visible Main gate;
## replay uses only captured scalars, never a renderer or a new visibility check.
static func _enqueue(member: String, original_bytes: int, sha256: String, unit: String, offset: int, length: int, origin: String, seen_key: String = "") -> bool:
	return _enqueue_result(member, original_bytes, sha256, unit, offset, length, origin, seen_key) in [Observation.ACCEPTED, Observation.RETAINED]

static func _enqueue_result(member: String, original_bytes: int, sha256: String, unit: String, offset: int, length: int, origin: String, seen_key: String = "") -> Observation:
	if original_bytes<=0 or sha256.length()!=64 or not sha256.is_valid_hex_number(false):return Observation.INVALID
	if not member.begins_with("Map/") and not member.begins_with("Tile/") and not member.begins_with("Sprite/") and not member.begins_with("Client/Text/"):return Observation.INVALID
	if member.length()>1024 or unit.is_empty() or unit.length()>256:return Observation.INVALID
	if origin not in ["USER_MAIN", "AUTOMATED_ACTUAL_MAIN"]: return Observation.INVALID
	if _disabled:
		_rejected += 1
		return Observation.DISABLED
	if seen_key.is_empty(): seen_key = var_to_str([member, original_bytes, sha256, unit, offset, length, origin])
	if _recorded.has(seen_key): return Observation.ACCEPTED
	var bytes: int = 4 * (member.length() + sha256.length() + unit.length() + origin.length()) + 32
	var retain: bool = not _retained.is_empty() or _pending.size() >= MAX_PENDING or _pending_bytes + bytes > MAX_PENDING_BYTES
	if retain and (_retained.size() >= MAX_RETAINED or _retained_bytes + bytes > MAX_RETAINED_BYTES):
		_rejected += 1
		_dropped += 1 # Explicit hard-bound loss, not invalid input or a force-kill.
		_force = true
		return Observation.DROPPED
	var event: Array = [member, original_bytes, sha256, unit, offset, length, origin]
	event.make_read_only()
	if retain:
		_retained.append(event)
		_retained_bytes += bytes
		_force = true # Pressure drains promptly, independent of camera/redraw.
	else:
		_pending.append(event)
		_pending_bytes += bytes
	_recorded[seen_key]=true
	if _recorded.size() > MAX_RECENT:
		for oldest: String in _recorded:
			_recorded.erase(oldest)
			break
	_accepted += 1
	return Observation.RETAINED if retain else Observation.ACCEPTED

## Existing draw callers only signal; the autoload pumps outside drawing.
static func flush(force: bool=false) -> void:
	_force = _force or force

static func pump() -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task): return
		WorkerThreadPool.wait_for_task_completion(_task) # Already complete only.
		_collect()
	if _disabled or (_pending.is_empty() and _retained.is_empty() and not _dirty and _dropped == _committed_drops): return
	var now: int = Time.get_ticks_msec()
	if not _force and now - _last_flush < FLUSH_INTERVAL_MSEC: return
	_force = not _retained.is_empty()
	_last_flush = now
	if _worker == null: _worker = LedgerWorker.new(PATH)
	# Transfer the bounded inbox itself: no deep copy of events or old ledger.
	var batch := Batch.new()
	batch.events = _pending
	batch.dropped = _dropped
	# O(1) promotion of already observed scalars; no event copying or redraw.
	_pending = _retained
	_pending_bytes = _retained_bytes
	_retained = []
	_retained_bytes = 0
	batch.events.make_read_only()
	_inflight = batch.events.size()
	_result = [null]
	_task = WorkerThreadPool.add_task(_worker.run.bind(batch, _result), false, "map usage ledger")

static func _collect() -> void:
	_task = -1
	if not _result[0] is Array or _result[0].size() != 8:
		_disabled = true
		problem = "소비 장부 작업 결과 누락: 미확정 관측은 저장 확인되지 않았습니다."
		_inflight = 0
		_result = []
		return
	var report: Array = _result[0]
	_disabled = report[0]
	_dirty = report[1]
	_member_count = report[2]
	problem = report[3]
	_committed = report[4]
	_committed_drops = report[7]
	_rejected += int(report[5])
	_conflicts += int(report[5])
	if int(report[5]) > 0: problem = "소비 장부의 원본 정체성이 다릅니다."
	_inflight = 0
	_last_worker_usec = report[6]
	_result = []

## Process teardown ONLY; scene changes/pause/draw never call this. Drain the
## final pending batch with at most three drain attempts, without an infinite
## exit loop on unwritable storage. A crash/OS kill can lose uncommitted RAM.
static func finish() -> void:
	for _attempt: int in 3:
		flush(true)
		pump()
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
			_collect()
		if _task < 0 and (_disabled or (_pending.is_empty() and _retained.is_empty() and not _dirty and _dropped == _committed_drops)): break

static func status() -> Dictionary:
	return {"file":PATH,"partial_member_identities":_member_count,"whole_files_used_claimed":0,"whole_original_bytes_used_claimed":0,"usage95_verified":false,"problem":problem,
		"accepted_observations":_accepted,"committed_observations":_committed,"rejected_observation_attempts":_rejected,
		"retained_observations":_retained.size(),"retained_payload_bytes_bound":_retained_bytes,"dropped_observation_attempts":_dropped,"committed_drop_attempts":_committed_drops,"uncommitted_drop_attempts":maxi(0,_dropped-_committed_drops),
		"pending_observations":_pending.size(),"inflight_observations":_inflight,"pending_payload_bytes_bound":_pending_bytes,"worker_active":_task>=0,"last_worker_usec":_last_worker_usec,"uncommitted":_accepted>_committed+_conflicts,"uncommitted_observations":maxi(0,_accepted-_committed-_conflicts),"disabled":_disabled}

## Exclusive transfer envelope. Worker detaches the payload immediately so
## task reaping on main only releases an empty envelope, not thousands of events.
class Batch extends RefCounted:
	var events: Array = []
	var dropped: int = 0

## Once submitted, no main-thread code reads or mutates these fields. Only
## immutable scalar event arrays and a private result slot cross the boundary.
class LedgerWorker extends RefCounted:
	const MAX_LEDGER_BYTES: int = 16 * 1024 * 1024
	var path: String
	var _loaded: bool = false
	var _members: Dictionary = {}
	var _disabled: bool = false
	var _dirty: bool = false
	var problem: String = ""
	var accepted: int = 0
	var committed: int = 0
	var prior_drops: int = 0
	var observed_drops: int = 0
	var committed_drops: int = 0
	func _init(destination: String) -> void: path = destination
	func _load() -> void:
		if _loaded:return
		_loaded=true
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null:
			if FileAccess.file_exists(path):problem="기존 소비 장부를 읽지 못했습니다.";_disabled=true
			return
		if file.get_length()>16*1024*1024:problem="기존 소비 장부가 검사 한도를 초과했습니다.";_disabled=true;return
		var parser := JSON.new()
		var parse_error: Error = parser.parse(file.get_as_text())
		file.close()
		var value: Variant = parser.data if parse_error == OK else null
		if value is Dictionary and value.get("schema")==1 and value.get("inventory_JSONL_SHA256")==INVENTORY_SHA and value.get("members") is Dictionary:
			for key: Variant in value.members:
				var row: Variant=value.members[key]
				if not row is Dictionary or not row.get("origins") is Dictionary or row.get("whole_file_used",true)!=false or row.get("original_member_bytes_fully_used_proven",-1)!=0:_disabled=true;break
				for origin: Variant in row.origins:
					var entry: Variant=row.origins[origin]
					if not entry is Dictionary or not entry.get("units") is Dictionary or not entry.get("source_ranges") is Dictionary:_disabled=true;break
			if not _disabled:
				_members=value.members
				prior_drops = maxi(0, int(value.get("recording_dropped_observation_attempts", 0)))
		else:_disabled=true
		if _disabled:problem="기존 소비 장부 형식이 달라 기록을 중단했습니다. 게임 상태는 바꾸지 않습니다."

	func run(envelope: Batch, result: Array) -> void:
		var batch: Array = envelope.events
		envelope.events = []
		var started: int = Time.get_ticks_usec()
		_load()
		var conflicts: int = 0
		if not _disabled:
			if envelope.dropped > observed_drops:
				observed_drops = envelope.dropped
				_dirty = true
			for event: Array in batch:
				if not _apply(event): conflicts += 1
			accepted += batch.size() - conflicts
			if _dirty:
				var snapshot: Dictionary = {"schema":1,"scope_owner":"MAPS","dataset":"current523","inventory_JSONL_SHA256":INVENTORY_SHA,"fixed_Map_Tile_denominator":DENOMINATOR,"members":_members,"claim":"Partial observations only. Compressed Sprite/TI2 frame units do not prove original byte coverage. QA Main is separate from USER_MAIN; no fixture/inspection observations.","global_non_sound_denominator_known":false,"usage95_verified":false}
				if prior_drops + observed_drops > 0: snapshot["recording_dropped_observation_attempts"] = prior_drops + observed_drops
				var text: String = JSON.stringify(snapshot, "", true, true)
				if text.to_utf8_buffer().size() > MAX_LEDGER_BYTES:
					_disabled = true
					problem = "소비 장부 한도 초과: 기존 파일 보존, 미확정 관측은 저장되지 않았습니다."
				else:
					var error: Error = WRITER.write_text(path, text)
					if error == OK:
						_dirty = false
						problem = ""
					else: problem = "소비 장부 저장 실패 (재시도 대기): " + error_string(error)
			if not _dirty:
				committed = accepted
				committed_drops = observed_drops
		result[0] = [_disabled, _dirty, _members.size(), problem, committed, conflicts, Time.get_ticks_usec() - started, committed_drops]

	func _apply(event: Array) -> bool:
		var member: String = event[0]
		var original_bytes: int = event[1]
		var sha256: String = event[2]
		var unit: String = event[3]
		var offset: int = event[4]
		var length: int = event[5]
		var origin: String = event[6]
		var key: String = member + "|" + sha256
		if not _members.has(key):
			_members[key] = {"member":member,"sha256":sha256,"original_member_bytes":original_bytes,"usage":"PARTIAL_OBSERVATION","whole_file_used":false,"original_member_bytes_fully_used_proven":0,"origins":{}}
		var row: Dictionary = _members[key]
		if int(row.get("original_member_bytes", -1)) != original_bytes: return false
		if not row.origins.has(origin): row.origins[origin] = {"units":{},"source_ranges":{}}
		var entry: Dictionary = row.origins[origin]
		if not entry.units.has(unit): entry.units[unit] = true; _dirty = true
		if offset >= 0 and length > 0 and offset <= original_bytes - length:
			var range_key: String = str(offset) + ":" + str(length)
			if not entry.source_ranges.has(range_key): entry.source_ranges[range_key] = true; _dirty = true
		return true
