extends SceneTree
## 523 map objects (S32 tail sprite records) are drawn from the installed 523
## SP2 bank: in 523 Aden the visible buildings/props resolve and draw.
## Real input: -- --source523-pack=<installed pack folder> [--shot=<png>].
## Without it: no bank selection means no objects and no failure.
const OBJECTS = preload("res://scripts/maps/current523_bank_objects.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
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
	print("CURRENT523_BANK_OBJECTS_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var base: String = arg("--source523-pack=")
	if base.is_empty():
		var objects: Node2D = OBJECTS.new()
		check(not objects.configure({}, null), "no bank, no coordinates: nothing is configured")
		check(not objects.problem.is_empty(), "the reason is reported")
		objects.free()
		_finish({"real_input_checked":false})
		return
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	check(read.ok and PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base))).ok, "installed pack applied")
	HOST.refresh()
	check(not OBJECTS.bank_selection().is_empty(), "the pack's bank is selected for map objects")
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for _frame: int in 900:
		if bool(world.get("current523_aden_play_active")): break
		await process_frame
	check(bool(world.get("current523_aden_play_active")), "523 play mode is active: " + str(world.get("current523_aden_play_problem")))
	var renderer: Node = world.get("field_renderer")
	var objects: Node = renderer.get_node_or_null("Current523BankMapObjects") if renderer != null else null
	check(objects != null, "the 523 renderer draws map objects from the bank: " + (str(renderer.get("map_objects_problem")) if renderer != null else "no renderer"))
	var metrics: Dictionary = objects.call("metrics") if objects != null else {}
	check(int(metrics.get("raw_records", 0)) > 0, "visible chunks carry object records")
	check(int(metrics.get("drawn_records", 0)) > 0, "objects are drawn")
	check(int(metrics.get("drawn_records", 0)) >= int(metrics.get("raw_records", 0)) * 9 / 10, "at least 90% of visible object records resolve")
	var pictures: int = 0
	if objects != null:
		for node: Node in objects.get_children():
			for child: Node in node.get_children():
				if child is Sprite2D and (child as Sprite2D).texture != null: pictures += 1
	check(pictures > 0, "object nodes hold source textures")
	# Animated objects advance on their own clock.
	for _frame: int in 30: await process_frame
	var shot: String = arg("--shot=")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		# The picture is of the map: hide the HUD and the new-character dialog.
		for layer: Node in world.find_children("*", "CanvasLayer", true, false): (layer as CanvasLayer).visible = false
		for _frame: int in 10: await process_frame
		root.get_viewport().get_texture().get_image().save_png(shot)
		if objects != null:
			(objects as CanvasItem).visible = false
			for _frame: int in 5: await process_frame
			root.get_viewport().get_texture().get_image().save_png(shot.get_basename() + "_without_objects.png")
			(objects as CanvasItem).visible = true
	_finish({"real_input_checked":true,"metrics":{"raw_records":metrics.get("raw_records"),"drawn_records":metrics.get("drawn_records"),"unresolved_source_ids":metrics.get("unresolved_source_ids"),"cached_sprites":metrics.get("cached_sprites"),"texture_bytes":metrics.get("texture_bytes")},"sprites_drawn":pictures})
