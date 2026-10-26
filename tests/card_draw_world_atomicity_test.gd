extends SceneTree
## Uses Main's real draw/fusion handlers. It deliberately blocks saves and
## verifies that neither tickets nor permanent/duplicate cards are lost.
const Cards = preload("res://scripts/card_draw_fusion.gd")
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	if not ok:
		errors.append(reason)
		printerr("CARD_DRAW_WORLD_ATOMICITY_FAIL: " + reason)

func _run() -> void:
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.set("source_save_blocked", true)
	var cards: Object = world.get("card_draw_fusion")
	var generator: RandomNumberGenerator = cards.get("rng") as RandomNumberGenerator
	var inventory: Dictionary = world.get("inventory")
	var ticket: String = "최상급 성물 뽑기권 11회 팩"
	inventory[ticket] = 1
	check(bool(cards.call("can_draw", "성물")), "relic card pool supports a real draw")
	var before: Dictionary = cards.call("export_state")
	var roll_before: int = generator.state
	world.call("_use_card_pack_item", ticket)
	check(int(inventory.get(ticket, 0)) == 1, "blocked save does not spend ticket")
	check(cards.call("export_state") == before, "blocked save does not award unrecoverable cards")
	check(generator.state == roll_before, "failed transaction restores draw RNG state")
	var chosen: String = ""
	for raw: Variant in (world.get("catalog_db") as Dictionary).get("변신", []):
		if raw is Dictionary and str((raw as Dictionary).get("grade", "")) == "고급":
			chosen = Cards.card_id(raw)
			break
	check(not chosen.is_empty(), "source catalog contains fusion material")
	if not chosen.is_empty():
		var unlocked: Dictionary = {}
		unlocked[chosen] = true
		var extras: Dictionary = {}
		extras[chosen] = 4
		cards.call("import_state", {"owned":{"변신":unlocked}, "spare":{"변신":extras}, "pity":{}})
		before = cards.call("export_state")
		roll_before = generator.state
		world.call("_on_card_fusion_requested", "변신", "고급")
		check(cards.call("export_state") == before, "blocked save restores all fused duplicate cards")
		check(generator.state == roll_before, "blocked fusion restores RNG state")
	world.queue_free()
	await process_frame
	if errors.is_empty(): print("CARD_DRAW_WORLD_ATOMICITY_OK")
	quit(0 if errors.is_empty() else 1)
