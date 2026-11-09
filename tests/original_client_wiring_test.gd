extends SceneTree
## Proves the original-client adapter is the code path the game now uses, and that
## replacing the old inline arithmetic changed no in-domain result.
const SELECT = preload("res://scripts/original_client/sprite_selection.gd")
const ASSETS = preload("res://scripts/original_client/asset_resolver.gd")
const WIRED := {
	"res://scripts/resources/reference_sp2_bank.gd": "ORIGINAL_SELECTION.sp2_group",
	"res://scripts/resources/current523_identity_pack.gd": "ORIGINAL_SELECTION.sp2_group",
	"res://scripts/resources/source523_image_pack.gd": "ORIGINAL_ASSETS.join_path",
}
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	failures.append(message)

func run() -> void:
	# 1) The three game files call the adapter, compile, and no longer hold the old arithmetic.
	for path: String in WIRED:
		var text: String = FileAccess.get_file_as_string(path)
		if not text.contains(WIRED[path]): fail("not wired: " + path)
		if text.contains("address & ~7") or text.contains("address & 7"): fail("old inline arithmetic remains: " + path)
		var script: Variant = load(path)
		if not (script is GDScript) or not (script as GDScript).can_instantiate(): fail("does not compile: " + path)
	# 2) Exhaustive differential: old arithmetic vs adapter over every u16 word0, both
	#    declared_flag values and all 8 directions.
	var compared: int = 0
	var equal: int = 0
	var wrapped: int = 0
	for flag: int in [0, 1]:
		for word0: int in range(65536):
			for direction: int in range(8):
				var address: int = word0 + (direction if flag == 1 else 0)
				var old_file_b: int = address & ~7
				var old_bit: int = address & 7
				var group: Dictionary = SELECT.sp2_group(word0, flag == 1, direction)
				compared += 1
				if address <= 0xFFFF:
					if group.file_b == old_file_b and group.direction == old_bit and SELECT.primary_name(27255, group.file_b) == "Sprite/%d-%d.sp2" % [27255, old_file_b]:
						equal += 1
					else:
						fail("in-domain mismatch word0=%d flag=%d direction=%d" % [word0, flag, direction])
				else:
					# Past 0xFFFF the original u16 add wraps; the old inline code did not.
					wrapped += 1
					if group.file_b != ((address & 0xFFFF) & 0xFFF8) or group.direction != (address & 7): fail("wrap result wrong word0=%d direction=%d" % [word0, direction])
	# 3) The pack's literal join is unchanged.
	for pair: Array in [["icon/", "Item/adena_3.png"], ["", "x.png"], ["icon", "Item/x.png"], ["a/", ""]]:
		if ASSETS.join_path(pair[0], pair[1]) != str(pair[0]) + str(pair[1]): fail("join differs for " + str(pair))
	print("ORIGINAL_CLIENT_WIRING_RESULT ", JSON.stringify({"compared": compared, "equal_in_domain": equal, "wrapped_out_of_domain": wrapped, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
