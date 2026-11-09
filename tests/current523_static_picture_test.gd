extends SceneTree
## Client static branch (no action descriptor) through ReferenceSp2Bank.load_static.
## Without arguments only the fail-closed contract is checked. With a private bank:
## --bank=<manifest.json> --sha=<pin> --sprites=<id,id,...> loads and renders each body.
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const VIEW = preload("res://scripts/loot/current523_ground_source_view.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var missing: Dictionary = BANK.new().load_static("/missing/current523-bank/manifest.json", "0".repeat(64), 45)
	check(not missing.get("ok", true), "missing bank fails closed")
	var view := VIEW.new()
	root.add_child(view)
	check(not view.configure_ground_source({}) and view.selection_status.get("status") == "source_only_pending", "ground view without a complete item stays pending")
	var evidence: Dictionary = {"loaded":0,"rendered":0,"with_shadow":0,"failed":{}}
	var manifest: String = argument("--bank=")
	if not manifest.is_empty():
		var pin: String = argument("--sha=")
		check(not BANK.new().load_static(manifest, "0".repeat(64), 45).get("ok", true), "wrong manifest pin denies static pictures")
		for part: String in argument("--sprites=").split(",", false):
			var bank = BANK.new()
			var opened: Dictionary = bank.load_static(manifest, pin, int(part))
			if not opened.get("ok", false):
				evidence.failed[part] = str(opened.get("error", ""))
				continue
			evidence.loaded += 1
			check(opened.layers[0].kind == "body" and int(opened.layers[0].group_bit) == 0 and int(opened.layers[0].frame_index) == 0, "static body is direction0 picture0: " + part)
			if opened.layers.size() > 1: evidence.with_shadow += 1
			var picture: Dictionary = bank.render_layer(opened.layers[0])
			if picture.get("ok", false) and not picture.get("empty", true) and picture.image.get_width() > 0: evidence.rendered += 1
		check(evidence.loaded > 0 and evidence.rendered == evidence.loaded, "every loaded static body renders")
	print("CURRENT523_STATIC_PICTURE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
