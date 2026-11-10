extends SceneTree
## SP2 frame bounds, per nonempty frame: half-open (x2/y2 exclusive, filled
## exactly: the long-standing rule), half-open with blank rows before the
## samples, or end-inclusive (the samples end exactly on the stored x2/y2 pixel).
## The male knight 15270 mixes these within one file. Anything else is rejected.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 255)
	bytes.append((value >> 8) & 255)

## One group, the given frames (each [x1,y1,x2,y2]) all referencing block 0.
func _fixture(frame_bounds: Array, commands: Array, indices: Array) -> PackedByteArray:
	var bytes := PackedByteArray([254, 2])
	for color: int in [0, 65535]: _u16(bytes, color)
	bytes.append(1)
	bytes.append(frame_bounds.size())
	for bounds: Array in frame_bounds:
		for value: int in bounds: _u16(bytes, value)
		_u16(bytes, 1)
		bytes.append_array(PackedByteArray([0, 0, 22]))
		_u16(bytes, 0)
	_u16(bytes, 1)
	_u16(bytes, 0)
	bytes.append_array(PackedByteArray([0, 0, commands.size()]))
	for command: int in commands: _u16(bytes, command)
	for sample: int in indices: bytes.append(sample)
	return bytes

func _initialize() -> void:
	# A 2x2 square of white samples: two rows of two (count 2, then next row).
	var square: Array = [64 | (1 << 10), 64]
	var white: Array = [1, 1, 1, 1]
	var half_open: Dictionary = DECODER.parse(_fixture([[0, 0, 2, 2]], square, white))
	check(half_open.ok and half_open.bounds_rule == "half_open", "exact half-open bounds keep the half-open rule")
	if half_open.ok:
		var image: Image = DECODER.render(half_open, 0, 0).image
		check(image.get_size() == Vector2i(2, 2) and image.get_pixel(1, 1).a == 1.0, "half-open canvas is unchanged")
	var inclusive: Dictionary = DECODER.parse(_fixture([[0, 0, 1, 1]], square, white))
	check(inclusive.ok and inclusive.bounds_rule == "per_frame" and inclusive.groups[0].frames[0].bounds_rule == "end_inclusive", "end-inclusive bounds are read as such")
	if inclusive.ok:
		var drawn: Dictionary = DECODER.render(inclusive, 0, 0)
		check(drawn.ok and drawn.image.get_size() == Vector2i(2, 2) and drawn.offset == Vector2i.ZERO, "end-inclusive canvas covers the last row and column")
		check(drawn.ok and drawn.image.get_pixel(1, 1).a == 1.0 and drawn.image.get_pixel(1, 1).is_equal_approx(Color.WHITE), "the corner sample is drawn")
		check(inclusive.groups[0].frames[0].raw_bounds == PackedInt32Array([0, 0, 1, 1]), "the stored bounds are retained")
	# Samples on rows 1-2 only (a blank first row): inside the inclusive bounds,
	# ending exactly on its last pixel.
	var gap: Dictionary = DECODER.parse(_fixture([[0, 0, 1, 2]], [0 | (1 << 10), 64 | (1 << 10), 64], white))
	check(gap.ok and gap.groups[0].frames[0].bounds_rule == "end_inclusive", "an end-inclusive frame may start with blank rows")
	if gap.ok:
		var image: Image = DECODER.render(gap, 0, 0).image
		check(image.get_size() == Vector2i(2, 3) and image.get_pixel(0, 0).a == 0.0 and image.get_pixel(1, 2).a == 1.0, "blank rows stay transparent")
	var mixed: Dictionary = DECODER.parse(_fixture([[0, 0, 2, 2], [0, 0, 1, 1]], square, white))
	check(mixed.ok and mixed.groups[0].frames[0].bounds_rule == "half_open" and mixed.groups[0].frames[1].bounds_rule == "end_inclusive", "each frame keeps its own rule in one file")
	if mixed.ok:
		check(DECODER.render(mixed, 0, 0).image.get_size() == Vector2i(2, 2) and DECODER.render(mixed, 0, 1).image.get_size() == Vector2i(2, 2), "both frames draw the same 2x2 picture")
	# Half-open with a blank first row: stored (0,0)-(2,3), samples rows 1-2.
	var margin: Dictionary = DECODER.parse(_fixture([[0, 0, 2, 3]], [0 | (1 << 10), 64 | (1 << 10), 64], white))
	check(margin.ok and margin.groups[0].frames[0].bounds_rule == "half_open_margin", "half-open bounds may hold blank rows above the samples")
	if margin.ok:
		var image: Image = DECODER.render(margin, 0, 0).image
		check(image.get_size() == Vector2i(2, 3) and image.get_pixel(1, 0).a == 0.0 and image.get_pixel(1, 2).a == 1.0, "the stored canvas keeps the blank rows")
	check(not DECODER.parse(_fixture([[0, 0, 3, 3]], square, white)).ok, "bounds larger than the samples are rejected")
	check(not DECODER.parse(_fixture([[0, 0, 1, 2]], square, white)).ok, "bounds ending past the samples are rejected")
	check(not DECODER.parse(_fixture([[1, 0, 2, 1]], square, white)).ok, "samples left of the bounds are rejected")
	print("CURRENT523_SP2_BOUNDS_RULE_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
