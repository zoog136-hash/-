extends SceneTree
const RULES = preload("res://scripts/consumable_rules.gd")
const Forge = preload("res://scripts/ui/renewal_forge.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("BLESSING_SCROLL_UI_FAIL: " + label)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var inventory: Dictionary = world.get("inventory")
	inventory["축복 부여 주문서 (각인)"] = 2
	inventory["낡은 장검"] = 1
	world.call("_sync_item_instances")
	var items: Dictionary = world.get("item_instances")
	var target: String = ""
	for id: Variant in items:
		if str((items[id] as Dictionary).get("name", "")) == "낡은 장검":
			target = "낡은 장검@@@" + str(id)
			break
	_check(not target.is_empty(), "real physical equipment ID")
	_check(str(RULES.definition("축복 부여 주문서 (각인)").get("kind", "")) == "equipment_bless", "engraved scroll normalizes to blessing rule")
	var hud: Node = world.get("hud")
	var calls: Array = []
	hud.blessing_target_requested.connect(func(scroll: String, selected: String) -> void:
		calls.append([scroll, selected]))
	if not target.is_empty():
		var forge: Control = Forge.new()
		root.add_child(forge)
		forge.configure_blessing(hud, "축복 부여 주문서 (각인)", [
			{"name":"낡은 장검", "target_id":target, "instance_id":target.split("@@@")[1],
			"level":0,"success_chance":60.0,"bonus_text":"최대 HP +50"}
		])
		await process_frame
		_check(forge.mode == "blessing", "blessing uses native forge picker")
		_check(forge.action.text.contains("축복 부여"), "blessing has visible submit action")
		_check(forge.detail.text.contains("성공률"), "blessing details show chance")
		forge.queue_free()
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("BLESSING_SCROLL_UI_OK")
	quit(0 if failures.is_empty() else 1)
