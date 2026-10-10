extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const SAVE_PATH := "user://twilight_v20_save.json"
var world: TwilightWorld
var checks: int = 0
var failures: Array[String] = []
var audited: int = 0
var upgrades: int = 0
var weapons: int = 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("LEARNING_CONDITIONS FAIL: ", message)

func learn_book(record: Dictionary) -> void:
	world.inventory[str(record.book_name)] = 1
	check(world.original_skills.catalog.learn(str(record.id)), "real book learning: " + str(record.name))

func audit_records() -> void:
	var catalog := world.original_skills.catalog
	for record: Dictionary in catalog.records:
		audited += 1
		catalog.learned.clear()
		world.active_skill_buffs.clear()
		world.job_class = str(record.classes[0])
		world.level = int(record.minimum_level) - 1
		world.inventory[str(record.book_name)] = 1
		var revision := catalog.revision
		check(not catalog.learn(str(record.id)), str(record.name) + " rejects level below threshold")
		check(int(world.inventory[str(record.book_name)]) == 1 and catalog.revision == revision and not catalog.owned(record), "low level consumes no book or ownership")
		world.level = 90
		world.inventory[str(record.book_name)] = 0
		check(not catalog.learn(str(record.id)) and not catalog.owned(record), str(record.name) + " needs a book")
		world.gold = int(record.book_cost) - 1
		var gold_before := world.gold
		check(not catalog.buy_book(str(record.id)), str(record.name) + " rejects insufficient gold")
		check(world.gold == gold_before and int(world.inventory[str(record.book_name)]) == 0, "failed purchase is atomic")
		world.gold = int(record.book_cost)
		check(catalog.buy_book(str(record.id)), str(record.name) + " real shop purchase")
		check(world.gold == 0 and int(world.inventory[str(record.book_name)]) == 1, "purchase spends exact cost for one book")
		check(catalog.learn(str(record.id)), str(record.name) + " can learn at valid level")
		check(catalog.owned(record) and int(world.inventory[str(record.book_name)]) == 0 and catalog.revision == revision + 1, "learning grants one stable ID and consumes one book")
		world.inventory[str(record.book_name)] = 1
		check(not catalog.learn(str(record.id)) and int(world.inventory[str(record.book_name)]) == 1 and catalog.revision == revision + 1, "duplicate learning is atomic")
		if str(record.activation) == "passive":
			world.mp = 999
			check(not world._cast_job_skill(str(record.id)) and world.mp == 999, str(record.name) + " passive cannot be cast")
		for other: String in world.JOB_CLASS_ORDER:
			if record.classes.has(other): continue
			world.job_class = other
			check(not catalog.owned(record) and not catalog.enabled(record), str(record.name) + " other class cannot activate stored ownership")
			catalog.learned.clear()
			check(not catalog.learn(str(record.id)) and int(world.inventory[str(record.book_name)]) == 1, str(record.name) + " other class cannot consume its book")
			break
	var before := catalog.export_state()
	check(not catalog.learn("unknown_future_id") and not catalog.buy_book("unknown_future_id"), "unknown ID has no learning or shop path")
	check(catalog.export_state() == before, "unknown ID does not change learned state")

func audit_upgrades() -> void:
	var catalog := world.original_skills.catalog
	world.level = 90
	# Iterate a snapshot because the order-independence probe reverses records.
	for augment: Dictionary in catalog.records.duplicate():
		var relation: Dictionary = catalog.relations.get(str(augment.id), {})
		if str(augment.mode) != "upgrade": continue
		upgrades += 1
		catalog.learned.clear()
		world.job_class = str(augment.classes[0])
		var chain: Array[Dictionary] = []
		var cursor := augment
		while not cursor.is_empty():
			chain.push_front(cursor)
			cursor = catalog.record_for(str(catalog.relations.get(str(cursor.id), {}).get("upgrades_from", "")))
		var base: Dictionary = chain[0]
		learn_book(base)
		var plain := catalog.resolve(base)
		check(not plain.has("resolved_grade"), str(base.name) + " unlearned upgrades do not apply")
		for step: Dictionary in chain.slice(1): learn_book(step)
		var resolved := catalog.resolve(base)
		for key: String in relation.get("patch", {}):
			check(resolved.get(key) == relation.patch[key], str(augment.name) + " applies its final patch: " + key)
		check(str(resolved.resolved_grade) == str(augment.grade), "resolved grade follows the learned tier")
		var previous := catalog.records.duplicate()
		catalog.records.reverse()
		check(catalog.resolve(base) == resolved, "ancestry order survives reversed catalog order")
		catalog.records = previous
		check(base == catalog.record_for(str(base.id)) and not base.has("resolved_grade"), "resolution does not mutate the base record")
		world.mp = 999
		check(not world._cast_job_skill(str(augment.id)) and world.mp == 999, "upgrade cannot be cast separately")

func audit_weapon_and_school() -> void:
	var service := world.original_skills
	var catalog := service.catalog
	for record: Dictionary in catalog.records:
		if record.get("weapons", []).is_empty(): continue
		weapons += 1
		catalog.learned.clear()
		world.job_class = str(record.classes[0])
		world.equipped_items.clear()
		learn_book(record)
		check(catalog.owned(record) and not catalog.enabled(record), "weapon restriction does not prevent book ownership")
		world.mp = 999
		world.skill_cooldowns.clear()
		world.skill_global_cooldown = 0
		var state_before := world.rng.state
		check(not world._cast_job_skill(str(record.id)) and not service.auto_wants(record), str(record.name) + " manual and AUTO reject wrong weapon")
		check(world.mp == 999 and world.skill_cooldowns.is_empty() and world.rng.state == state_before, "wrong weapon spends no MP, cooldown or RNG")
		world.equipped_items["weapon"] = {"name":"조건 검사 무기","type":record.weapons[0],"slot":"weapon"}
		check(catalog.enabled(record), str(record.name) + " activates with the recorded weapon")
	catalog.learned.clear()
	world.job_class = "요정"
	learn_book(catalog.record_for("네이쳐스 터치"))
	learn_book(catalog.record_for("아이언 스킨"))
	catalog.schools["요정"] = "water"
	check(catalog.stat("hpFlat") == 60 and catalog.stat("def") == 0, "water activates only water passive")
	catalog.schools["요정"] = "earth"
	check(catalog.stat("hpFlat") == 0 and catalog.stat("def") == 8, "earth activates only earth passive")
	world.job_class = "마법사"
	check(catalog.stat("hpFlat") == 0 and catalog.stat("def") == 0, "other class cannot use stored elf passives")

func audit_live_upgrade() -> void:
	var service := world.original_skills
	var catalog := service.catalog
	world._on_job_class_selected("뇌신")
	world.active_skill_buffs.clear()
	world.equipped_items.clear()
	catalog.learned.clear()
	catalog.seed_starters()
	var base := catalog.record_for("썬더 아머")
	var augment := catalog.record_for("썬더 아머(미스틱)")
	learn_book(base)
	world.mp = 999
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill(str(base.id)), "actual base armor cast before learning its upgrade")
	check(service.stat("physicalResistance") == 5 and service.incoming_damage(null, "melee", 100) == 95, "base armor uses its stored local resistance")
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill("실드"), "keep a second real buff during learning")
	var other: Dictionary = world.active_skill_buffs["실드"].duplicate(true)
	world.active_skill_buffs[str(base.name)]["remaining"] = 60.0
	world.mp = 777
	world.skill_cooldowns[str(base.name)] = 33.0
	world.skill_global_cooldown = .2
	var event_before: Dictionary = service.event_counts.duplicate(true)
	learn_book(augment)
	check(service.stat("physicalResistance") == 8 and service.stat("dg") == 4, "learning upgrade immediately updates the already-active buff")
	check(service.incoming_damage(null, "melee", 100) == 92, "actual incoming damage immediately uses the learned upgrade")
	var buff: Dictionary = world.active_skill_buffs[str(base.name)]
	check(float(buff.remaining) == 60.0 and world.mp == 777 and float(world.skill_cooldowns[str(base.name)]) == 33.0 and is_equal_approx(world.skill_global_cooldown, .2), "learning does not recast, extend duration or spend resources")
	check(world.active_skill_buffs.size() == 2 and world.active_skill_buffs["실드"] == other and service.event_counts == event_before, "unrelated buffs and cast events stay unchanged")
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(save.active_skill_buffs[str(base.name)].skill_stats.physicalResistance) == 8, "learning saves the updated active buff atomically")
	world._load_game(true)
	check(service.stat("physicalResistance") == 8 and service.stat("dg") == 4 and service.incoming_damage(null, "melee", 100) == 92, "load agrees with the pre-save upgraded effect")
	check(float(world.active_skill_buffs[str(base.name)].remaining) == 60.0, "load does not extend upgraded buff time")

func run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	world.level = 90
	audit_records()
	audit_upgrades()
	audit_weapon_and_school()
	audit_live_upgrade()
	check(audited == 125 and upgrades == 10 and weapons == 4, "audit covers every current record, upgrade and weapon restriction")
	print("LEARNING_AUDIT_COUNTS records=", audited, " upgrades=", upgrades, " weapons=", weapons)
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_LEARNING_CONDITIONS_OK checks=", checks, " records=", audited, " upgrades=", upgrades, " weapons=", weapons)
	quit(0 if failures.is_empty() else 1)
