extends SceneTree
## Standalone synthetic check of the SP2 parse device cache and the decoder's
## block palette check (no original data).
##   godot --headless --path <repo> --script res://tests/sp2_parse_cache_test.gd
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const DIR := "user://sp2_parse_cache_test"
## var_to_str(parse).sha256_text() of build(4, 200, 31, 0) with the decoder
## before the block palette check change (Godot 4.7.2).
const REFERENCE_PARSE_SHA_PREFIX := "f545a7531d0a836c"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SP2_PARSE_CACHE_FAIL: " + label)

## A valid FE SP2: `groups` directions x `frames` frames, each frame one block
## of `rows` rows of 31 samples; marker 0 = 256 palette entries.
static func build(groups: int, frames: int, rows: int, marker: int, bad_sample: int = -1) -> PackedByteArray:
	var out := PackedByteArray([254, marker])
	var entries: int = 256 if marker == 0 else marker
	for index: int in entries:
		out.append(index & 255)
		out.append((index * 7) & 127)
	var mask: int = 0
	for group: int in groups: mask |= 1 << group
	out.append(mask)
	for group: int in groups:
		out.append(frames)
		for frame: int in frames:
			for value: int in [0, 0, 31, rows]:
				out.append(value & 255)
				out.append((value >> 8) & 255)
			out.append(1)
			out.append(0)
			out.append_array(PackedByteArray([0, 0, 0]))
			out.append(frame & 255)
			out.append((frame >> 8) & 255)
		var count := PackedByteArray()
		count.resize(4)
		count.encode_s32(0, frames)
		out.append_array(count)
		for frame: int in frames:
			out.append_array(PackedByteArray([0, 0, rows]))
			for row: int in rows:
				var word: int = (31 << 5) | (1 << 10)
				out.append(word & 255)
				out.append((word >> 8) & 255)
	var samples := PackedByteArray()
	samples.resize(groups * frames * rows * 31)
	for index: int in samples.size(): samples[index] = (index * 13) % mini(entries, 256)
	if bad_sample >= 0:
		samples[40] = bad_sample
		samples[41] = bad_sample + 1 if bad_sample < 255 else bad_sample
	out.append_array(samples)
	return out

func _initialize() -> void:
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var dir := DirAccess.open(DIR)
	if dir != null:
		for name: String in dir.get_files(): DirAccess.remove_absolute(DIR.path_join(name))

func _run() -> void:
	_clean()
	CACHE.reset_for_test(DIR)
	var raw: PackedByteArray = build(4, 200, 31, 0)
	# Decoder output is unchanged by the block palette check.
	var reference: Dictionary = DECODER.parse(raw)
	check(reference.ok and var_to_str(reference).sha256_text().begins_with(REFERENCE_PARSE_SHA_PREFIX), "decoder parse equals the previous decoder's output")
	# Miss, write, then a hit equal to the fresh parse.
	var started: int = Time.get_ticks_usec()
	var first: Dictionary = CACHE.parse(raw)
	var miss_usec: int = Time.get_ticks_usec() - started
	check(first.ok and CACHE.misses == 1 and CACHE.writes == 1 and CACHE.hits == 0, "the first parse is a miss and is stored")
	check(var_to_str(first) == var_to_str(reference), "a missed parse is the decoder parse")
	started = Time.get_ticks_usec()
	var second: Dictionary = CACHE.parse(raw)
	var hit_usec: int = Time.get_ticks_usec() - started
	check(CACHE.hits == 1, "the second parse of the same bytes is a hit")
	check(var_to_str(second) == var_to_str(reference), "a cached parse equals the decoder parse, raw and body included")
	check(second.raw == raw and second.body == reference.body, "raw and body are reattached from the original bytes")
	check(hit_usec < miss_usec, "a hit is faster than a parse (%d us vs %d us)" % [hit_usec, miss_usec])
	var with_known: Dictionary = CACHE.parse(raw, _sha(raw))
	check(CACHE.hits == 2 and var_to_str(with_known) == var_to_str(reference), "a passed verified SHA-256 finds the same entry")
	# Different bytes never reuse the entry.
	var other: PackedByteArray = build(4, 200, 31, 0)
	other[other.size() - 1] = (other[other.size() - 1] + 1) % 256
	var other_parse: Dictionary = CACHE.parse(other)
	check(CACHE.misses == 2 and var_to_str(other_parse) == var_to_str(DECODER.parse(other)), "changed bytes are parsed fresh")
	# A corrupted entry is rejected, removed and replaced by a fresh parse.
	var path: String = CACHE.path_for(CACHE.key_for("sha256:" + _sha(raw), raw.size()))
	var stored: PackedByteArray = FileAccess.get_file_as_bytes(path)
	stored[stored.size() - 10] ^= 0x5a
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(stored)
	file.close()
	var after_corrupt: Dictionary = CACHE.parse(raw)
	check(CACHE.rejects == 1 and var_to_str(after_corrupt) == var_to_str(reference), "a corrupted entry is rejected and the parse is fresh")
	check(FileAccess.file_exists(path) and CACHE.writes == 3, "the rejected entry is rewritten")
	# A truncated entry is rejected too.
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(stored.slice(0, 64))
	file.close()
	var after_truncate: Dictionary = CACHE.parse(raw)
	check(CACHE.rejects == 2 and var_to_str(after_truncate) == var_to_str(reference), "a truncated entry is rejected")
	# Invalid input: same error as the decoder, nothing stored.
	var writes_before: int = CACHE.writes
	var bad: PackedByteArray = build(1, 4, 4, 4, 9)
	var bad_parse: Dictionary = CACHE.parse(bad)
	var bad_reference: Dictionary = DECODER.parse(bad)
	check(not bad_parse.ok and bad_parse.error == bad_reference.error and CACHE.writes == writes_before, "an invalid SP2 fails as before and is not stored")
	check(str(bad_parse.error).contains("Palette index 9 exceeds 4 entries."), "the first out-of-range sample is reported in stream order: " + str(bad_parse.error))
	var small: Dictionary = DECODER.parse(build(1, 4, 4, 4))
	check(small.ok, "in-range samples of a small palette parse")
	# Disabled: the decoder directly.
	CACHE.enabled = false
	var hits_before: int = CACHE.hits
	check(var_to_str(CACHE.parse(raw)) == var_to_str(reference) and CACHE.hits == hits_before, "disabled bypasses the cache")
	CACHE.enabled = true
	# Pruning keeps the newest entries under the limit.
	var total: int = 0
	var dir := DirAccess.open(DIR)
	for name: String in dir.get_files(): total += int(FileAccess.get_size(DIR.path_join(name)))
	var removed: int = CACHE.prune(total - 1)
	var left: int = 0
	for name: String in DirAccess.open(DIR).get_files(): left += int(FileAccess.get_size(DIR.path_join(name)))
	check(removed >= 1 and left <= total - 1, "prune removes entries until under the limit")
	_clean()
	print("SP2_PARSE_CACHE_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "miss_us":miss_usec, "hit_us":hit_usec}))
	quit(0 if failures.is_empty() else 1)

func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
