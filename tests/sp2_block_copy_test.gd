extends SceneTree
## Differential contract test against the pre-optimization block reader.
## Synthetic only: sample bytes, run coordinates/order, error precedence and
## reader position must remain identical, including every truncated prefix.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func compare(commands: PackedInt32Array, bytes: PackedByteArray, palette: int, start: int = 0) -> void:
	var before := DECODER.Reader.new(bytes)
	var after := DECODER.Reader.new(bytes)
	before.position = start
	after.position = start
	var expected: Dictionary = {"commands":commands}
	var actual: Dictionary = {"commands":commands}
	var old: Dictionary = _legacy_block(before, expected, palette)
	var result: Dictionary = DECODER._read_block(after, actual, palette)
	check(var_to_bytes(old) == var_to_bytes(result) and var_to_bytes(expected) == var_to_bytes(actual) and before.position == after.position and before.error == after.error, "exact block/result/cursor at case %d" % checks)

func _initialize() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 523
	for trial: int in 160:
		var commands := PackedInt32Array()
		var count: int = 0
		for index: int in (trial % 32):
			var word: int = random.randi_range(0, 65535)
			commands.append(word)
			count += (word >> 5) & 31
		var bytes := PackedByteArray([87, 42, 11])
		var palette: int = [1, 3, 4, 128, 255, 256][trial % 6]
		for index: int in count: bytes.append(random.randi_range(0, palette - 1))
		compare(commands, bytes, palette, 3)
		for length: int in range(3, bytes.size()): compare(commands, bytes.slice(0, length), palette, 3)
		if count > 0 and palette < 256:
			bytes[3 + count / 2] = 255
			compare(commands, bytes, palette, 3)
	# Maximum commands per encoded block, all-zero runs, horizontal advance,
	# row advance without samples, and first invalid palette value ordering.
	var full := PackedInt32Array()
	full.resize(255)
	full.fill((31 << 5) | (1 << 10))
	var samples := PackedByteArray()
	samples.resize(255 * 31)
	samples.fill(0)
	compare(full, samples, 256)
	full.fill(0)
	compare(full, PackedByteArray(), 1)
	compare(PackedInt32Array([31, 1 << 10, 2 << 5]), PackedByteArray([9, 7]), 4)
	# An existing error is preserved even for a zero-length command.
	var failed := DECODER.Reader.new(PackedByteArray())
	failed.error = "existing failure"
	check(DECODER._read_block(failed, {"commands":PackedInt32Array([0])}, 256).error == "existing failure" and failed.position == 0, "existing reader failure")
	HITCH._details.clear()
	HITCH._counters.clear()
	check(not DECODER.parse(PackedByteArray()).ok, "empty parse rejected")
	check(HITCH._details.has("sp2.decoder_total") and HITCH._counters.get("sp2.decoder_reject") == 1, "failed cold parse included in total telemetry")
	print("SP2_BLOCK_COPY_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

static func _legacy_block(reader: DECODER.Reader,block: Dictionary,palette_size: int) -> Dictionary:
	var commands: PackedInt32Array = block.commands
	var indices := PackedByteArray()
	var runs := PackedInt32Array() # Repeated x, y, sample-offset, sample-count.
	var xx: int = 0
	var yy: int = 0
	var has_samples: bool = false
	var extent := Rect2i()
	for word: int in commands:
		xx += word & 31
		var count: int = (word >> 5) & 31
		var step: int = word >> 10
		var samples: PackedByteArray = reader.take(count)
		if not reader.error.is_empty(): return DECODER._fail(reader.error)
		if count > 0:
			runs.append_array(PackedInt32Array([xx,yy,indices.size(),count]))
			indices.append_array(samples)
			var run_bounds := Rect2i(xx,yy,count,1)
			extent = extent.merge(run_bounds) if has_samples else run_bounds
			has_samples = true
		if step > 0:
			yy += step
			xx = 0
		else:
			xx += count
	# Palette range for the whole block at once (native scans) instead of a
	# GDScript loop over every sample; the first offending sample in stream
	# order is reported exactly as before.
	if palette_size < 256 and not indices.is_empty():
		for value: int in range(palette_size, 256):
			if indices.has(value):
				for sample: int in indices:
					if sample >= palette_size: return DECODER._fail("Palette index %d exceeds %d entries." % [sample,palette_size])
	block["indices"] = indices
	block["runs"] = runs
	block["sample_count"] = indices.size()
	block["sample_bounds"] = extent
	block["empty"] = not has_samples
	return {"ok":true,"error":""}

