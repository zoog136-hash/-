extends RefCounted
## Storage protocol for a future source-verified honing adapter. NOT a rule engine.
## The default adapter cannot authorize, write or adopt a transaction.
## Keep one instance for the owning world's lifetime. While reload_required is
## true the host MUST suppress all saves, not merely the honing button. Recreate
## only after the host has successfully loaded the durable inventory AND ledger.
var reload_required: bool = false
var _busy: bool = false
var _finished: bool = false

func commit(path: String, before: Dictionary, candidate: Dictionary) -> Dictionary:
	if reload_required: return _result("reload_required")
	if _busy or _finished: return _result("attempt_already_used")
	_busy = true
	# Freeze nested dictionaries before calling adapters; they never receive the
	# caller's candidate or our authoritative expected copy by reference.
	var expected: Dictionary = candidate.duplicate(true)
	var previous: Dictionary = before.duplicate(true)
	if not _valid_payload(previous) or not _valid_payload(expected):
		_busy = false
		return _result("invalid_full_payload")
	var disk: Dictionary = _read(path)
	if not disk.ok or not _same(disk.payload, previous):
		_busy = false
		return _result("durable_base_changed")
	if not _authorize(previous.duplicate(true), expected.duplicate(true)):
		_busy = false
		return _result("source_transaction_not_authorized")
	# Authorization must recheck physical target, receipts, source rules, selected
	# outcome and live state. It must be synchronous, pure, and consume no RNG.
	# Check the disk again after it, before issuing exactly one write.
	var latest: Dictionary = _read(path)
	if not latest.ok or latest.sha256 != disk.sha256:
		_busy = false
		return _result("durable_base_changed")
	_finished = true
	# The host adapter must use its established stale-save/atomic writer contract,
	# and return without changing live state. Do not write around world._save_game.
	var error: Error = _write_payload(path, expected.duplicate(true))
	var durable: Dictionary = _read(path)
	var matched: bool = durable.ok and _same(durable.payload, expected)
	if error != OK or not matched:
		reload_required = true
		_busy = false
		return {"ok":false, "code":"save_requires_reload", "write_error":error,
			"durable_matches_candidate":matched, "reload_required":true}
	# Adopt all inventory, physical instances and quest ledger together. If the
	# adapter cannot do so, preserve disk and require a complete host reload.
	if not _adopt_payload(expected.duplicate(true)):
		reload_required = true
		_busy = false
		return _result("adoption_requires_reload")
	_busy = false
	return {"ok":true, "code":"committed", "reload_required":false}

func _authorize(_before: Dictionary, _candidate: Dictionary) -> bool:
	return false

func _write_payload(_path: String, _candidate: Dictionary) -> Error:
	return ERR_UNAVAILABLE

func _adopt_payload(_candidate: Dictionary) -> bool:
	return false

func _result(code: String) -> Dictionary:
	return {"ok":false, "code":code, "reload_required":reload_required}

static func _valid_payload(payload: Dictionary) -> bool:
	for key: String in ["inventory", "item_instances", "quest_state"]:
		if not payload.get(key) is Dictionary: return false
	return true

static func _same(left: Dictionary, right: Dictionary) -> bool:
	# Godot JSON parses integers as floats; compare both in the durable domain.
	return JSON.parse_string(JSON.stringify(left, "", true, true)) == JSON.parse_string(JSON.stringify(right, "", true, true))

static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false}
	# Read and hash the same bytes, avoiding a separate open/hash race.
	var length: int = file.get_length()
	if length <= 0 or length > 64 * 1024 * 1024:
		file.close()
		return {"ok":false}
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	if bytes.size() != length or error not in [OK, ERR_FILE_EOF]: return {"ok":false}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary: return {"ok":false}
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return {"ok":true, "payload":json.data, "sha256":hashing.finish().hex_encode()}
