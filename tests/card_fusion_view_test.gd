extends SceneTree
const Cards = preload("res://scripts/card_draw_fusion.gd")
const Fusion = preload("res://scripts/ui/card_fusion_view.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, reason: String) -> void:
	if not condition:
		failures.append(reason)
		printerr("CARD_FUSION_VIEW_FAIL: " + reason)

func _run() -> void:
	var catalog: Dictionary = {}
	for category: String in Cards.CATEGORIES:
		var rows: Array = []
		for grade: String in Cards.GRADES:
			rows.append({"sourceId": category + "-" + grade, "name": category + " " + grade, "grade": grade})
		catalog[category] = rows
	var service = Cards.new()
	service.configure(catalog)
	var earned: Dictionary = {"owned": {"변신": {"source:변신-고급": true}}, "spare": {"변신": {"source:변신-고급": 4}}, "pity": {}}
	service.import_state(earned)
	var view: Control = Fusion.new()
	root.add_child(view)
	view.configure(catalog, service.export_state(), "변신")
	await process_frame
	var overall: Label = view.find_child("CardFusionOverall", true, false) as Label
	var materials: Label = view.find_child("CardFusionMaterialsCount", true, false) as Label
	var roster: ItemList = view.find_child("CardFusionOwnedList", true, false) as ItemList
	var confirm: Button = view.find_child("CardFusionConfirm", true, false) as Button
	check(overall != null and overall.text.contains("총 5장"), "five drawn copies are visible")
	check(materials != null and materials.text.contains("4 / 4장"), "four spendable duplicates are visible")
	check(roster != null and roster.item_count == 1 and roster.get_item_text(0).contains("보유 5장"), "one base copy plus duplicates")
	check(confirm != null and not confirm.disabled, "ready fusion is enabled")
	var emitted: Array = []
	view.fuse_requested.connect(func(category: String, grade: String) -> void:
		emitted.append(category + ":" + grade))
	view.call("_request")
	check(emitted == ["변신:고급"], "fusion request carries selected category and grade")
	view.set_category("성물")
	check(confirm.disabled, "other category stays locked without duplicate cards")
	check(overall.text.contains("총 0장"), "other category does not borrow ownership")
	view.set_category("변신")
	service.import_state({"owned": {"변신": {"source:변신-고급": true}}, "spare": {}, "pity": {}})
	view.set_collection_state(service.export_state())
	check(overall.text.contains("총 1장"), "updated collection state refreshes count immediately")
	check(confirm.disabled, "permanent unlock alone cannot be spent")
	view.queue_free()
	await process_frame
	if failures.is_empty(): print("CARD_FUSION_VIEW_OK")
	quit(0 if failures.is_empty() else 1)
