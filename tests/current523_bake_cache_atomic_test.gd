extends SceneTree
## D02: replacing a device bake never loses the accepted one first.
## write()/commit_file() publish a new generation (data file read back, new
## metadata read back, then one rename of the metadata). Every storage
## failure before that rename - including a real one (missing finished file)
## and injected ones (write/commit/verify/meta/swap) - keeps the previous
## metadata and data readable under their own key, never serves them for a
## different key, and leaves no new file behind.
##   godot --headless --path <repo> --script res://tests/current523_bake_cache_atomic_test.gd
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("BAKE_CACHE_ATOMIC_FAIL: " + label)

func _initialize() -> void: call_deferred("run")

## Every file of this bake on storage (meta, data, generations, parts).
func files(name: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(BAKE.ROOT)
	if dir == null: return result
	for file_name: String in dir.get_files():
		if file_name == name + ".json" or file_name.begins_with(name + ".json.") or file_name.begins_with(name + ".bin") or file_name.begins_with(name + ".g"): result.append(file_name)
	result.sort()
	return result

func meta_key(name: String) -> String:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(BAKE.ROOT + "/" + name + ".json"))
	return str(meta.get("key", "")) if meta is Dictionary else ""

func finished_part(name: String, bytes: PackedByteArray) -> String:
	var part: String = BAKE.data_path(name) + ".part"
	var file := FileAccess.open(part, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return part

func run() -> void:
	var name: String = "atomic_fixture"
	BAKE.clear(name)
	BAKE.store_failures.clear()
	# --- write(): accepted generation, then failing replacements -------------
	check(BAKE.write(name, "key-1", {"value": 1}), "first bake written")
	var accepted: PackedStringArray = files(name)
	check(accepted.size() == 2, "one metadata + one data file: " + str(accepted))
	check(BAKE.read(name, "key-1") == {"value": 1}, "first bake reads")
	for stage: String in ["write", "verify", "meta", "swap"]:
		BAKE.store_failures.clear()
		BAKE.fault = name + "|" + stage
		var ok: bool = BAKE.write(name, "key-2", {"value": 2})
		BAKE.fault = ""
		check(not ok, "write fails at " + stage)
		check(BAKE.store_failures.has(name), "failure recorded at " + stage)
		check(BAKE.read(name, "key-1") == {"value": 1}, "previous bake still reads after a failed write at " + stage)
		check(BAKE.read(name, "key-2") == null and not BAKE.present(name, "key-2"), "the kept bake is never served for the new key at " + stage)
		check(meta_key(name) == "key-1", "metadata still names the accepted key at " + stage)
		check(files(name) == accepted, "no new or partial file left at " + stage + ": " + str(files(name)))
	# --- commit_file(): file-format bakes -------------------------------------
	var payload := PackedByteArray([1, 2, 3, 4, 5])
	check(BAKE.commit_file(name, "key-3", finished_part(name, payload)), "file bake committed")
	var committed: String = BAKE.verified_file(name, "key-3")
	check(not committed.is_empty() and FileAccess.get_file_as_bytes(committed) == payload and BAKE.data_path(name) == committed, "committed file verifies and is the data path")
	check(BAKE.read(name, "key-1") == null, "the superseded key misses after a successful replacement")
	accepted = files(name)
	check(accepted.size() == 2, "superseded generation removed: " + str(accepted))
	for stage: String in ["commit", "verify", "meta", "swap", "missing"]:
		BAKE.store_failures.clear()
		var part: String = BAKE.ROOT + "/absent.part" if stage == "missing" else finished_part(name, PackedByteArray([9, 9]))
		if stage != "missing": BAKE.fault = name + "|" + stage
		var ok: bool = BAKE.commit_file(name, "key-4", part)
		BAKE.fault = ""
		check(not ok, "commit fails at " + stage)
		check(BAKE.store_failures.has(name), "commit failure recorded at " + stage)
		check(BAKE.verified_file(name, "key-3") == committed and FileAccess.get_file_as_bytes(committed) == payload, "previous file bake still verifies after a failed commit at " + stage)
		check(BAKE.verified_file(name, "key-4").is_empty(), "the kept file is never served for the new key at " + stage)
		check(files(name) == accepted, "no new or partial file left after commit " + stage + ": " + str(files(name)))
	# --- records (streamed writer) -------------------------------------------
	check(BAKE.write_records(name, "key-5", PackedStringArray(["a", "b"]), [10, 20]), "record bake written")
	BAKE.fault = name + "|swap"
	check(not BAKE.write_records(name, "key-6", PackedStringArray(["a"]), [99]), "record replacement fails at swap")
	BAKE.fault = ""
	var records: BAKE.RecordFile = BAKE.open_records(name, "key-5")
	check(records != null and records.read("a") == 10 and records.read("b") == 20, "previous records still read after a failed replacement")
	check(BAKE.open_records(name, "key-6") == null, "failed records key misses")
	records = null
	# --- crash leftovers and older layouts ------------------------------------
	var stray: String = BAKE.ROOT + "/" + name + ".g0123456789abcdef.bin"
	var leftover := FileAccess.open(stray, FileAccess.WRITE)
	leftover.store_string("unpublished")
	leftover.close()
	check(BAKE.open_records(name, "key-5") != null, "an unpublished generation (crash before the swap) is ignored")
	check(BAKE.write(name, "key-7", {"value": 7}) and not FileAccess.file_exists(stray), "the next publish removes the crash leftover")
	BAKE.clear(name)
	check(files(name).is_empty(), "clear removes every file of the bake")
	# Metadata written before generations existed (fixed data file name) stays readable.
	var bytes: PackedByteArray = var_to_bytes({"legacy": true})
	var legacy := FileAccess.open(BAKE.ROOT + "/" + name + ".bin", FileAccess.WRITE)
	legacy.store_buffer(bytes)
	legacy.close()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	var meta := FileAccess.open(BAKE.ROOT + "/" + name + ".json", FileAccess.WRITE)
	meta.store_string(JSON.stringify({"schema": BAKE.SCHEMA, "key": "key-8", "sha256": hash.finish().hex_encode(), "bytes": bytes.size()}))
	meta.close()
	check(BAKE.read(name, "key-8") == {"legacy": true}, "an existing pre-generation bake still reads")
	BAKE.fault = name + "|meta"
	check(not BAKE.write(name, "key-9", {"value": 9}) and BAKE.read(name, "key-8") == {"legacy": true}, "a failed replacement keeps the pre-generation bake")
	BAKE.fault = ""
	check(BAKE.write(name, "key-9", {"value": 9}) and not FileAccess.file_exists(BAKE.ROOT + "/" + name + ".bin") and BAKE.read(name, "key-9") == {"value": 9}, "a successful replacement moves it to a generation")
	# A metadata pointer outside this bake's generation names is never followed.
	meta = FileAccess.open(BAKE.ROOT + "/" + name + ".json", FileAccess.WRITE)
	meta.store_string(JSON.stringify({"schema": BAKE.SCHEMA, "key": "key-10", "sha256": "", "bytes": 1, "file": "../other.bin"}))
	meta.close()
	check(BAKE.read(name, "key-10") == null and BAKE.verified_file(name, "key-10").is_empty() and not BAKE.present(name, "key-10"), "a foreign data pointer is a miss")
	BAKE.clear(name)
	BAKE.store_failures.clear()
	print("BAKE_CACHE_ATOMIC_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
