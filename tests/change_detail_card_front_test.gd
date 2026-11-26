extends SceneTree
## User list 2026-11-26 #16: transform (전설 이하), doll and relic details
## showed the large IllustrationAssetID painting in Change_DetailView's
## CardSample (scale 1.5). It spilled over the option text and the 즉시 변신 /
## 각성 buttons. The authored node is a 46x46 card placeholder whose siblings
## CardSample_Screen / _Awaken / _Multi overlay the same card face, so every
## category and grade shows its DisplayBaseAssetID card front there.
##   godot --headless --path <repo> --script res://tests/change_detail_card_front_test.gd
##   (with the private original UI/images selected, a real Main is opened)
const QA = preload("res://tests/qa_class_selection.gd")
const WINDOW = preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Array = []

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CHANGE_DETAIL_CARD_FRONT_FAIL: " + label)
	return value

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var code: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_change_window.gd")
	check(not code.contains("Presentation.catalog_detail("), "the original detail never requests the illustration role")
	check(code.contains("_picture(Presentation.detail(record,true,false)) if not record.is_empty()"), "the detail uses the card-front role")
	if not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty() and not OS.get_environment("TWILIGHT_SOURCE523_IMAGES").is_empty():
		await live()
	print("CHANGE_DETAIL_CARD_FRONT_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func live() -> void:
	if not check(not FileAccess.file_exists("user://twilight_v20_save.json"), "isolated Main save"): return
	root.size = Vector2i(2048, 919)
	var w: Node = load("res://Main.tscn").instantiate()
	root.add_child(w); current_scene = w; w.set_process(false); w.save_timer = -100000
	if not check(QA.enter_game(w), "actual Main entered"): return
	for i in 4: await process_frame
	w.field_population.set_process(false); w.player.set_physics_process(false)
	var h: Node = w.hud
	for category: String in ["변신", "마법인형", "성물"]:
		var owned: Dictionary = w.card_draw_fusion.owned[category]
		var before: Dictionary = owned.duplicate()
		var picked: Array = []
		for grade: String in ["유일", "신화", "전설", "영웅"]:
			for r: Variant in w.catalog_db.get(category, []):
				if r is Dictionary and str(r.get("grade", "")) == grade:
					owned[CARDS.card_id(r)] = true
					picked.append(r)
					break
		w._update_hud()
		h.open_catalog(category)
		for i in 6: await process_frame
		var view: RefCounted = h.original_main_ui_controller.get("_change_window") if is_instance_valid(h.original_main_ui_controller) else null
		if not check(view != null and view.is_open(), category + " original catalog mounted"): continue
		var panel: Node2D = view._detail.source_nodes[WINDOW.SAMPLE_PANEL]
		var clip: Control = panel.find_child("SourceClipRect", true, false)
		for r: Dictionary in picked:
			view._selected = CARDS.card_id(r)
			var shown: Dictionary = view._show_selected()
			await process_frame
			var target: Node2D = view._detail.source_nodes[WINDOW.SAMPLE]
			var sprite: Sprite2D = target.get_meta("source_sprite")
			var front: Dictionary = preload("res://scripts/ui/source_card_presentation.gd").detail(r, true, false)
			var role: String = str(front.get("role", "")) if sprite.texture != null and front.get("texture") is Texture2D and sprite.texture.get_size() == front.texture.get_size() else "other"
			var size: Vector2 = sprite.texture.get_size() if sprite.texture != null else Vector2.ZERO
			var rect: Rect2 = sprite.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)
			var inside: bool = clip != null and clip.get_global_rect().encloses(rect.grow(-1.0))
			evidence.append([category, r.grade, role, size, inside])
			check(shown.get("illustration", false) and role == "DisplayBaseAssetID" and size == Vector2(108, 132), "%s %s detail shows its 108x132 card front" % [category, r.grade])
			check(inside, "%s %s card front stays inside Panel_CardSample" % [category, r.grade])
		h._close_workspace()
		owned.assign(before)
		w._update_hud()
		await process_frame
	w.queue_free()
	await process_frame
