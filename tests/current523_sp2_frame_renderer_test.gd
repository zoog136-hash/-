extends SceneTree
## Differential pixels/metadata against the unchanged decoder renderer.
## Synthetic FE data only; no original pack or GPU timing is claimed.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const FAST = preload("res://scripts/resources/current523_sp2_frame_renderer.gd")
const PARSES = preload("res://scripts/resources/sp2_parse_cache.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const SPARSE = preload("res://tests/reference_sp2_load_memo_test.gd")
const LARGE = preload("res://tests/sp2_parse_cache_test.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _u16(out: PackedByteArray, value: int) -> void:
	out.append(value & 255)
	out.append((value >> 8) & 255)

## Valid one-row FE member: 256 colors, nine runs cover every palette index.
func _palette(base: int) -> PackedByteArray:
	var out := PackedByteArray([254, 0])
	for index: int in 256: _u16(out, base + index)
	out.append_array(PackedByteArray([1, 1]))
	for value: int in [0, 0, 256, 1, 1]: _u16(out, value)
	out.append_array(PackedByteArray([0, 0, 0]))
	_u16(out, 0)
	out.append_array(PackedByteArray([1, 0, 0, 0, 0, 0, 9]))
	for index: int in 9: _u16(out, ((31 if index < 8 else 8) << 5) | ((1 << 10) if index == 8 else 0))
	for index: int in 256: out.append(index)
	return out

## Two coincident references make the final block overwrite the first,
## including palette index zero under either alpha policy.
func _overlap(a: int = 0, b: int = 0) -> PackedByteArray:
	var origin: Vector2i = DECODER._placement({"a":a,"b":b}, {"x":0,"y":0})
	var out := PackedByteArray([254, 2])
	for word: int in [0xf800, 0xffff]: _u16(out, word)
	out.append_array(PackedByteArray([1, 1]))
	for value: int in [origin.x, origin.y, origin.x + 2, origin.y + 2, 2]: _u16(out, value)
	out.append_array(PackedByteArray([a & 255, a & 255, b & 255, b & 255, 0, 22]))
	_u16(out, 0)
	_u16(out, 0) # delta=0 means next block, preserving the literal order.
	out.append_array(PackedByteArray([2, 0, 0, 0]))
	for block: int in 2:
		out.append_array(PackedByteArray([0, 0, 2]))
		_u16(out, 64 | (1 << 10))
		_u16(out, 64)
	out.append_array(PackedByteArray([1, 1, 1, 1, 0, 0, 0, 0]))
	return out

func _same(parsed: Dictionary, group: int, frame: int, options: Dictionary, label: String) -> void:
	var expected: Dictionary = DECODER.render(parsed, group, frame, options)
	var actual: Dictionary = FAST.render(parsed, group, frame, options)
	var left: Dictionary = expected.duplicate()
	var right: Dictionary = actual.duplicate()
	left.erase("image")
	right.erase("image")
	check(left == right, label + " metadata/errors")
	if expected.get("ok", false):
		check(expected.image.get_size() == actual.image.get_size() and expected.image.get_format() == actual.image.get_format() and expected.image.has_mipmaps() == actual.image.has_mipmaps() and expected.image.get_data() == actual.image.get_data(), label + " full RGBA bytes/shape")

func _compare(parsed: Dictionary, label: String) -> void:
	check(parsed.get("ok", false), label + " parses")
	if not parsed.get("ok", false): return
	var before: PackedByteArray = var_to_bytes(parsed)
	for alpha: String in ["opaque_samples", "index0_transparent"]:
		for rgb: String in ["bit_replication", "linear"]:
			for group: int in parsed.groups.size():
				for frame: int in parsed.groups[group].frames.size():
					_same(parsed, group, frame, {"alpha_policy":alpha,"rgb_policy":rgb}, label + str([alpha,rgb,group,frame]))
	check(before == var_to_bytes(parsed), label + " shared input unchanged")

func _run() -> void:
	# Every RGB565 word, both RGB policies and both alpha policies. High alpha
	# bytes also exercise packed colors above the signed 32-bit range.
	for base: int in range(0, 65536, 256): _compare(DECODER.parse(_palette(base)), "palette " + str(base))
	_compare(DECODER.parse(SPARSE.make_sp2(0b01010101, true)), "sparse/empty")
	_compare(DECODER.parse(_overlap()), "overlap/index0 overwrite")
	_compare(DECODER.parse(_overlap(-3, -2)), "negative odd placement")
	_compare(DECODER.parse(LARGE.build(2, 4, 31, 4)), "multiple stored frames")
	# Stored bounds variants exercise exactly the same accepted canvas policy.
	for bounds: Rect2i in [Rect2i(0,0,2,2), Rect2i(0,0,1,1), Rect2i(0,-1,2,3), Rect2i(1,1,1,1)]:
		var raw: PackedByteArray = _overlap()
		for index: int in 4:
			var values: Array[int] = [bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y]
			raw.encode_s16(8 + index * 2, values[index])
		_compare(DECODER.parse(raw), "bounds " + str(bounds))
	var valid: Dictionary = DECODER.parse(_overlap())
	_same({}, 0, 0, {}, "invalid parse")
	_same(valid, -1, 0, {}, "invalid group")
	_same(valid, 0, 99, {}, "invalid frame")
	_same(valid, 0, 0, {"alpha_policy":"missing"}, "invalid alpha policy")
	_same(valid, 0, 0, {"rgb_policy":"missing"}, "invalid RGB policy")
	var bad_reference: Dictionary = valid.duplicate(true)
	bad_reference.groups[0].frames[0].refs[0].index = 100
	_same(bad_reference, 0, 0, {}, "invalid block reference")
	var bad_bounds: Dictionary = valid.duplicate(true)
	bad_bounds.groups[0].frames[0].bounds = Rect2i(0,0,1,1)
	_same(bad_bounds, 0, 0, {}, "sample outside canvas")
	ASSETS._freeze(valid)
	_compare(valid, "read-only shared parse")
	var parse_key: String = PARSES.key_for("sha256:" + "a".repeat(64), 100)
	check(PARSES._code_key() == BAKE.code_key(["res://scripts/resources/current523_sp2_decoder.gd"]), "parse identity remains the unchanged decoder only")
	_same(valid, 0, 0, {}, "key stability render")
	check(parse_key == PARSES.key_for("sha256:" + "a".repeat(64), 100), "render does not change the device parse key")
	check(ASSETS.renderer_version() == BAKE.code_key(["res://scripts/resources/current523_sp2_frame_renderer.gd"]), "rendered identity includes the renderer code")
	check(ASSETS.rendered_key("parsed",0,0) != ASSETS.rendered_key("parsed",0,0,ASSETS.PIXEL_POLICY,"other compositor"), "rendered policies remain scoped")
	print("CURRENT523_SP2_FRAME_RENDERER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
