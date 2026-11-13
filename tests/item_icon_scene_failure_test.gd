extends SceneTree
## A mythic/unique item whose original animated (CSB) icon scene cannot attach
## must not be an unexplained blank slot: the existing "효과 미연결" label with
## the reason is shown and the reason is reported once. No image is drawn in
## its place. With the original pack the scene attaches and the label stays
## hidden, also with the Android fixed blend (SourceBlend.screen_copy_available=false).
const VIS = preload("res://scripts/ui/item_visual.gd")
const BLEND = preload("res://scripts/ui/original_ui/source_blend.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEM_ICON_SCENE_FAILURE_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func failure_case() -> void:
	var view := TextureRect.new(); root.add_child(view)
	var visual = VIS.new(); visual.name = "ItemVisual"; view.add_child(visual)
	var info: Dictionary = {"route":"source523_images","source_snapshot":"patch523","reason":"unsupported_csb","status":"original_icon_not_installed","provenance":{"icon_id":999999991}}
	visual._configure_presentation(view,{},"테스트 신화 무기",{},"inventory",{},info,true)
	var mark: Label = view.get_node("SubstituteIconMark") as Label
	check(view.texture == null, "no substitute image is drawn")
	check(mark.visible and mark.text == "효과 미연결" and not mark.tooltip_text.is_empty(), "failed scene shows 효과 미연결 with the reason (%s / %s)" % [mark.text,mark.tooltip_text])
	check(VIS.scene_failures.has(str(view.get_meta("item_visual").reason)), "the reason is reported once (%s)" % JSON.stringify(VIS.scene_failures))
	visual._configure_presentation(view,{},"",{},"inventory",{},info.duplicate(true),true)
	check(not mark.visible, "an empty slot still carries no label")
	evidence["failure_reason"] = str(view.get_meta("item_visual").reason)
	view.queue_free()

func pack_case() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var results: Dictionary = {}
	for copy: bool in [true,false]:
		BLEND.screen_copy_available = copy
		BLEND._cache.clear()
		for id: int in [362391,425]:
			var record: Dictionary = world._catalog_item_from_source_id("m523:item:"+str(id))
			var view := TextureRect.new(); view.size = Vector2(64,64); world.hud.add_child(view)
			VIS.apply(view,record,str(record.get("name","")),{},"inventory")
			await process_frame
			var info: Dictionary = view.get_meta("item_visual",{})
			var mark: Label = view.get_node_or_null("SubstituteIconMark") as Label
			var host: Node = view.get_node_or_null("SourceItemIconScene")
			check(str(info.get("status","")) == "verified_source_scene" and host != null and (mark == null or not mark.visible), "#%d original CSB icon scene attached (screen copy %s): %s" % [id,str(copy),str(info.get("reason",""))])
			results["%d:%s" % [id,str(copy)]] = str(info.get("status",""))
			view.queue_free()
	BLEND.screen_copy_available = not OS.has_feature("android")
	BLEND._cache.clear()
	evidence["pack"] = results
	world.queue_free()
	await process_frame

func run() -> void:
	failure_case()
	if not SOURCE.not_installed(): await pack_case()
	print("ITEM_ICON_SCENE_FAILURE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
