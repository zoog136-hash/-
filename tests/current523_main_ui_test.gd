extends SceneTree
## The original main HUD comes from the 523 client UI add-on: the add-on's
## "ui" section becomes the main UI selection, the HUD binds it and its
## components (EXP, HP/MP, attack pad, top menu, wallet, ...) mount over the
## running game.
## Real input: -- --source523-pack=<installed pack with the UI add-on> [--shot=<png>].
## Without it: add-on selection rules only (no original files).
const PACK = preload("res://scripts/boot/source523_pack.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
const SELECTION = preload("res://scripts/ui/original_ui/source_main_selection.gd")
const SOURCE_PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const BLESSING = preload("res://scripts/ui/original_ui/source_main_blessing_bindings.gd")
const VITALS = preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
## Components whose mount result update_player reports, and their fields.
const COMPONENTS := {"exp":"last_result","hp_mp":"_char_result","combat":"_combat_result","menu":"_menu_result","wallet":"_wallet_result","blessing":"_blessing_result","map_name":"_map_name_result","target":"_target_result","primary_stats":"_primary_stats_result","quickslot":"_quickslot_result","inventory":"_inventory_result","inventory_name":"_inventory_name_result","inventory_lock":"_inventory_lock_result","character":"_character_result","auto_message":"_auto_message_result","system_message":"_system_message_result"}
## The core HUD must mount; the rest is reported.
const REQUIRED := ["exp","hp_mp","combat","menu"]
var checks: int = 0
var failures: Array[String] = []
var world: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _finish(extra: Dictionary = {}) -> void:
	var result: Dictionary = {"checks":checks,"failures":failures}
	result.merge(extra)
	print("CURRENT523_MAIN_UI_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

static func _reason(value: Dictionary) -> String:
	var text: String = str(value.get("code", value.get("error", "not_mounted")))
	for key: String in ["details","offset","member","missing_source_offsets"]:
		if value.has(key): text += " %s=%s" % [key, str(value[key])]
	return text.left(300)

func _initialize() -> void:
	_run.call_deferred()

func _rules() -> void:
	var sha: String = "ab".repeat(32)
	var descriptor: Dictionary = {"tables":{"path":"tables/source.zip"},"images":{"root":"images","manifest_sha256":"cd".repeat(32)},
		"bank":{"manifest":"bank/manifest.json","manifest_sha256":"ef".repeat(32)},"maps":{"root":"maps","manifest_sha256":"01".repeat(32)},"tiles":{"root":"tiles","manifest_sha256":"23".repeat(32)}}
	var addon: Dictionary = {"ui":{"root":"ui","manifest":"ui/original_ui.json","manifest_sha256":sha}}
	var selected: Dictionary = PACK.selections("/pack", descriptor, addon)
	check(selected.environment.get("TWILIGHT_SOURCE_UI") == "/pack/ui" and selected.environment.get("TWILIGHT_SOURCE_UI_SHA256") == sha, "the UI add-on selects the main UI pack")
	check(not PACK.selections("/pack", descriptor).environment.has("TWILIGHT_SOURCE_UI"), "no add-on, no main UI selection")
	check(PACK.missing_addons(descriptor, addon) == ["world_links"], "the installer still asks for the travel definitions")
	check(PACK.missing_addons(descriptor, {}) == ["world_links","ui"], "both add-ons are asked for on a bare pack")
	check(PACK.missing_addons(descriptor, addon.merged({"world_links":{}})).is_empty(), "nothing is asked for when both are installed")
	_scope_offsets()
	_callbacks_survive()

## A pack's partial node scopes load from JSON as floats; consumers ask with
## int source offsets, so the opened pack must hold ints.
func _scope_offsets() -> void:
	var dir: String = ProjectSettings.globalize_path("user://current523_main_ui_fixture")
	DirAccess.make_dir_recursive_absolute(dir.path_join("originals/UI/Main"))
	var raw: PackedByteArray = "fixture-csb".to_utf8_buffer()
	var original := FileAccess.open(dir.path_join("originals/UI/Main/Fixture.csb"), FileAccess.WRITE)
	original.store_buffer(raw)
	original.close()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(raw)
	var sha: String = digest.finish().hex_encode()
	var member: String = "UI/Main/Fixture.csb"
	var manifest: Dictionary = {"schema":"twilight-original-ui-v1","entries":[],"atlases":{},"blockers":[],
		"files":{member:{"sha256":sha,"bytes":raw.size()}},
		"scenes":{member:{"_source_sha256":sha,"_decode_blockers":[],"_partial_source_scene":true,"_selected_source_offsets":[12,34],"nodeTree":{}}},
		"node_scopes":{member:[12,34]}}
	var text: PackedByteArray = JSON.stringify(manifest).to_utf8_buffer()
	var file := FileAccess.open(dir.path_join("original_ui.json"), FileAccess.WRITE)
	file.store_buffer(text)
	file.close()
	digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(text)
	var pack = SOURCE_PACK.new()
	var opened: Dictionary = pack.open(dir, digest.finish().hex_encode())
	check(opened.get("ok", false), "the fixture UI pack opens: " + str(opened))
	if opened.get("ok", false):
		check(pack.manifest.node_scopes[member].has(34) and pack.scene(member)._selected_source_offsets.has(12), "partial node scopes answer int offsets")

## Button callbacks must outlive the contract that built them (a Callable
## alone does not keep its RefCounted input object alive).
func _callbacks_survive() -> void:
	var pack := FakePack.new()
	pack.manifest = {"files":{VITALS.CHAR_MEMBER:{"sha256":VITALS.CHAR_SHA256},BLESSING.WALLET:{"sha256":BLESSING.WALLET_SHA},BLESSING.MEMBER:{"sha256":BLESSING.SHA256},BLESSING.SLOT:{"sha256":BLESSING.SLOT_SHA}}}
	var hud := FakeHud.new()
	root.add_child(hud)
	var vitals: Dictionary = VITALS.build_char_info(pack, hud, {"hp":5,"max_hp":10,"mp":1,"max_mp":2,"level":3})
	check(vitals.get("ok", false), "fixture vitals contract: " + str(vitals))
	if vitals.get("ok", false):
		var button: Callable = vitals.bindings[20552].activate
		check(button.is_valid() and button.call().get("ok", false) and hud.opened, "the HP/MP status button still reaches the HUD")
	var blessing: Dictionary = BLESSING.build(pack, hud)
	check(blessing.get("ok", false), "fixture blessing contract: " + str(blessing))
	if blessing.get("ok", false):
		var button: Callable = blessing.bindings[BLESSING.PROJECT].bindings[BLESSING.BUTTON].activate
		check(button.is_valid() and button.call().get("ok", false) and hud.toggled, "the blessing button still reaches the HUD")
	hud.queue_free()

class FakePack extends RefCounted:
	var manifest: Dictionary = {}

class FakeHud extends Node:
	signal inventory_pressed
	var opened: bool = false
	var toggled: bool = false
	var v20_ain_state: Dictionary = {"blessing":7}
	var v20_leaf_button := Button.new()
	var v20_ain_panel := Control.new()
	func open_character() -> void: opened = true
	func _toggle_ain_window() -> void: toggled = true

func _run() -> void:
	_rules()
	var base: String = arg("--source523-pack=")
	if base.is_empty():
		_finish({"real_input_checked":false})
		return
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	var addons: Dictionary = PACK.read_addons(base) if read.ok else {}
	check(addons.has("ui"), "the installed pack carries the UI add-on")
	check(read.ok and PACK.apply(PACK.selections(base, read.descriptor, addons)).ok, "installed pack applied")
	HOST.refresh()
	var selected: Dictionary = SELECTION.selected_pack()
	check(selected.get("ok", false) and selected.get("selected", false), "the main UI pack opens: " + str(selected.get("code", selected.get("reason", ""))))
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var hud: Node = null
	for _frame: int in 1200:
		hud = world.get("hud")
		if bool(world.get("current523_aden_play_active")) and is_instance_valid(hud) and is_instance_valid(hud.get("original_main_ui_controller")) and bool(hud.get("original_main_ui_controller").get("_has_player_values")): break
		await process_frame
	check(bool(world.get("current523_aden_play_active")), "523 play mode is active: " + str(world.get("current523_aden_play_problem")))
	var controller: Node = hud.get("original_main_ui_controller") if is_instance_valid(hud) else null
	check(is_instance_valid(controller), "the HUD bound the original main UI: " + (str(hud.get("original_main_ui_status")) if is_instance_valid(hud) else "no hud"))
	# Let the deferred components (target, auto message, wallet) settle.
	for _frame: int in 60: await process_frame
	var mounted: Dictionary = {}
	if is_instance_valid(controller):
		for component: String in COMPONENTS:
			var value: Variant = controller.get(COMPONENTS[component])
			mounted[component] = "ok" if value is Dictionary and value.get("ok", false) else (_reason(value) if value is Dictionary and not value.is_empty() else "not_attempted")
		for component: String in REQUIRED:
			check(mounted.get(component) == "ok", "the original %s component mounts: %s" % [component, mounted.get(component)])
	var shot: String = arg("--shot=")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		# The picture is of the playing HUD, not the first-run class picker.
		if bool(hud.get("class_picker_initial")): hud.call("complete_class_selection")
		for _frame: int in 30: await process_frame
		root.get_viewport().get_texture().get_image().save_png(shot)
	_finish({"real_input_checked":true,"components":mounted})
