## Synthetic microbenchmark against the unchanged pre-optimization CRC loop.
extends SceneTree
const CRC = preload("res://scripts/resources/source_crc32.gd")
var table: Array[int] = []
func old_crc(bytes: PackedByteArray) -> String:
	if table.is_empty():
		for index: int in range(256):
			var entry: int = index
			for bit: int in range(8): entry = (entry >> 1) ^ (0xedb88320 if (entry & 1) != 0 else 0)
			table.append(entry)
	var value: int = 0xffffffff
	for byte: int in bytes: value = table[(value ^ byte) & 255] ^ (value >> 8)
	return "%08x" % ((value ^ 0xffffffff) & 0xffffffff)
func _initialize() -> void:
	var results: Array = []
	# Input generation and table warmup are outside timed regions. No file I/O.
	for length: int in [833000, 2097152]:
		var bytes := PackedByteArray()
		bytes.resize(length)
		for index: int in range(length): bytes[index] = ((index * 73) ^ (index >> 8) ^ 0xa5) & 255
		var expected: String = old_crc(bytes)
		if CRC.hex_digest(bytes) != expected: quit(1); return
		var legacy: Array = []; var slicing: Array = []
		for repeat: int in range(9):
			var at := Time.get_ticks_usec(); old_crc(bytes); legacy.append(Time.get_ticks_usec() - at)
			at = Time.get_ticks_usec(); CRC.hex_digest(bytes); slicing.append(Time.get_ticks_usec() - at)
		legacy.sort(); slicing.sort()
		results.append({"bytes":length,"legacy_median_us":legacy[4],"slicing_median_us":slicing[4],"legacy_samples_us":legacy,"slicing_samples_us":slicing,"crc32":expected})
	print("SOURCE_CRC32_BENCH " + JSON.stringify({"scope":"Linux Godot CPU synthetic CRC only; not Android spawn/frame/RAM", "results":results}))
	quit(0)
