extends SceneTree
## The 523 TI2 decoder's display alpha follows the reviewed 508 tile rule
## (tools/map_restore/base508_ti2.py render(display_alpha=True)) exactly:
## bit 16 brightness alpha, bit 32 darkness alpha, excluded colors, bit 4 half
## alpha; plain blocks and uncovered pixels are unchanged.
const DECODER = preload("res://scripts/maps/current523_ti2_decoder.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

## RGB565 components expanded the way the decoder writes them.
func _put(rgba: PackedByteArray, frame: int, x: int, y: int, red5: int, green6: int, blue5: int) -> int:
	var at: int = (((frame >> 4) * 24 + y) * 384 + (frame % 16) * 24 + x) * 4
	rgba[at] = (red5 << 3) | (red5 >> 2)
	rgba[at + 1] = (green6 << 2) | (green6 >> 4)
	rgba[at + 2] = (blue5 << 3) | (blue5 >> 2)
	rgba[at + 3] = 255
	return at

func _initialize() -> void:
	var rgba := PackedByteArray()
	rgba.resize(384 * 384 * 4)
	rgba.fill(0)
	# frame 0 plain (flag 2), 1 half (6), 2 brightness (18), 3 darkness (34),
	# 17 diamond brightness (82), 20 diamond half (70).
	var flags := PackedByteArray()
	flags.resize(32)
	flags.fill(2)
	flags[1] = 6
	flags[2] = 18
	flags[3] = 34
	flags[17] = 82
	flags[20] = 70
	var plain: int = _put(rgba, 0, 3, 3, 16, 32, 8)
	var half: int = _put(rgba, 1, 5, 7, 16, 32, 8)
	var bright: int = _put(rgba, 2, 1, 1, 16, 32, 8)
	var white: int = _put(rgba, 2, 2, 1, 31, 63, 31)
	var dim: int = _put(rgba, 2, 3, 1, 1, 2, 1)
	var dark: int = _put(rgba, 3, 4, 4, 16, 32, 8)
	var near_black: int = _put(rgba, 3, 5, 4, 2, 4, 2)
	var black: int = _put(rgba, 3, 6, 4, 0, 0, 0)
	var yellow: int = _put(rgba, 3, 7, 4, 31, 63, 0)
	var diamond: int = _put(rgba, 17, 12, 11, 31, 0, 0)
	var diamond_half: int = _put(rgba, 20, 12, 11, 4, 8, 4)
	var uncovered: int = (((1 >> 4) * 24 + 0) * 384 + (1 % 16) * 24 + 0) * 4
	var colors_before: PackedByteArray = rgba.duplicate()
	DECODER.display_alpha(rgba, flags)
	check(rgba[plain + 3] == 255, "a plain block stays opaque")
	check(rgba[half + 3] == 128, "bit 4 is half alpha")
	check(rgba[bright + 3] == 16 * 255 / 31, "bit 16 is brightness alpha: " + str(rgba[bright + 3]))
	check(rgba[white + 3] == 0, "pure white drops out of a bit 16 block")
	check(rgba[dim + 3] == 0, "alpha below 8 drops out")
	check(rgba[dark + 3] == 15 * 255 / 31, "bit 32 is darkness alpha: " + str(rgba[dark + 3]))
	check(rgba[near_black + 3] == 29 * 255 / 31, "a near-black shadow pixel stays dark: " + str(rgba[near_black + 3]))
	check(rgba[black + 3] == 0, "pure black drops out of a bit 32 block")
	check(rgba[yellow + 3] == 0, "0x7fe0 drops out")
	check(rgba[diamond + 3] == 255, "diamond bit 16 uses brightness alpha (bright red)")
	check(rgba[diamond_half + 3] == 128, "diamond bit 4 is half alpha")
	check(rgba[uncovered + 3] == 0, "uncovered pixels stay transparent")
	var colors_same: bool = true
	for at: int in range(0, rgba.size(), 4):
		if rgba[at] != colors_before[at] or rgba[at + 1] != colors_before[at + 1] or rgba[at + 2] != colors_before[at + 2]: colors_same = false; break
	check(colors_same, "original colors are never changed")
	# The one-pass decoder path uses per-rule palette tables with the same values.
	check([DECODER.display_rule(2), DECODER.display_rule(6), DECODER.display_rule(18), DECODER.display_rule(34), DECODER.display_rule(50), DECODER.display_rule(82)] == [0, 1, 2, 3, 3, 2], "flag to rule mapping")
	var color: int = rgba[bright] | (rgba[bright + 1] << 8) | (rgba[bright + 2] << 16) | (255 << 24)
	var tables: Array[PackedInt64Array] = DECODER.display_tables(PackedInt64Array([color]))
	check(tables.size() == 4 and tables[0][0] == color, "the opaque table is the palette itself")
	check([tables[1][0] >> 24, tables[2][0] >> 24, tables[3][0] >> 24] == [128, 16 * 255 / 31, 15 * 255 / 31], "table alphas match the per-pixel rule")
	check((tables[2][0] & 0xFFFFFF) == (color & 0xFFFFFF), "table colors are unchanged")
	print("CURRENT523_TI2_DISPLAY_ALPHA_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
