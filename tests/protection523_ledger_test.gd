extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Runtime = preload("res://scripts/protection/protection523_runtime.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual existing class loads")
	var service: RefCounted = world.protection523
	check(not service.source.is_empty(),"verified installed capsule restores")
	var before := FileAccess.get_sha256(world.save_path())
	var old_state: Dictionary = service.state.duplicate(true)
	var old_inventory: Dictionary = world.inventory.duplicate(true)
	var old_log: Array[Dictionary] = world.crafting_log.duplicate(true)
	var old_extra: Dictionary = world.equipment_collections.extra_save_fields.duplicate(true)
	service.state = Runtime.fresh()
	service.reset_clock()
	world.crafting_log.clear()
	world.inventory["정상의 가호(3단)"] = 1
	world.inventory["은총의 두루마리"] = 1
	var extra: Dictionary = world.equipment_collections.extra_save_fields
	extra["patch523_crafting_usage"] = {"schema":1,"recipes":{"patch523:142364":{"bucket":1,"used":1,"schedule":"604800:504000"}}}
	check(service.quote_craft(200723).ok,"unrelated valid PR239 quota preserved and allowed")
	extra.patch523_crafting_usage.recipes["patch523:132033"] = {"bucket":1,"used":1,"schedule":"lifetime"}
	check(not service.quote_craft(200723).ok,"nested exact generic recipe history prevents duplicate")
	extra.patch523_crafting_usage = {"blocked":true}
	check(not service.quote_craft(200723).ok,"blocked generic ledger remains blocked")
	extra.patch523_crafting_usage = {"schema":1,"recipes":[]}
	check(not service.quote_craft(200723).ok,"damaged generic ledger never resets quota")
	extra.erase("patch523_crafting_usage")
	world.crafting_log.append({"recipe_id":"patch523:132033","batch":1})
	check(not service.quote_craft(200723).ok,"existing exact generic log prevents duplicate")
	world.crafting_log.clear()
	var record: Dictionary = world._find_catalog_item_record("정상의 가호(3단)")
	var original_id: Variant = record.sourceId
	record.sourceId = "999999"
	check(service.owned_key(123373,world.inventory).is_empty(),"live identity change cannot use stale binding cache")
	record.sourceId = original_id
	check(not service.owned_key(123373,world.inventory).is_empty(),"restored exact identity remains usable")
	var invalid: Dictionary = old_state.duplicate(true)
	invalid.cooldowns["371108"] = "3600"
	check(not Runtime.validate(invalid).is_empty(),"malformed cooldown rejected without conversion")
	check(not service.load_state({"protection523":invalid}) and service.save_blocked,"damaged own save blocks before effects")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == before,"blocked own save preserves durable bytes")
	check(service.load_state({"protection523":old_state}),"valid own state can restore after rejection")
	service.state = invalid
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == before,"ordinary save cannot publish an invalid runtime namespace")
	var old_policy: Dictionary = service.policy.duplicate(true)
	service.policy.project_pvp_to_pve = false
	service.policy.same_group = "replace"
	check(service.load_state({}) and service.state.policy.project_pvp_to_pve == false and service.state.policy.same_group == "replace","legacy migration respects configured host defaults")
	service.policy = old_policy
	service.state = old_state
	world.inventory = old_inventory
	world.crafting_log = old_log
	world.equipment_collections.extra_save_fields = old_extra
	check(FileAccess.get_sha256(world.save_path()) == before,"read-only integration checks preserve exact save")
	print("PROTECTION523_LEDGER_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
