extends SceneTree
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_DROP_FAIL: ", label)

func item(id: String, slot: String, grade: String = "일반") -> Dictionary:
	return {"name":"fixture"+id, "source":"inven", "sourceId":id, "sourceUrl":"https://lineagem.inven.co.kr/db/item/"+id, "slot":slot, "type":slot, "grade":grade, "heal":10 if id == "2" else 0}

func fixtures() -> Dictionary:
	var gear: Dictionary = item("1", "weapon", "희귀")
	var potion: Dictionary = item("2", "consumable", "유일")
	var material: Dictionary = item("3", "material")
	var rows: Array = []
	for values: Array in [[1,1,1,0],[2,1,1,0],[3,1,2,0],[4,1,1,99],[5,2,1,0],[6,2,2,0],[7,3,1,0],[8,1,14,0],[9,4,1,0]]:
		rows.append({"ID":values[0], "NpcClassID":100, "ItemClassID":values[1], "Bless":values[2], "RequiredQuestID":values[3], "source_row_1based":values[0]})
	return {"document":{"npcs":{"100":{"sprite_id":70,"source_name":"fixture-npc","attackable":true,"test_npc":false,"show_drop_info":true,"display_name":"fixture"}}, "drops":{"100":rows}, "bindings":{"1":gear,"2":potion,"3":material}, "bless_codes":{"1":"normal","2":"blessed","3":"cursed"}}, "catalog":{"by_name":{gear.name:gear,potion.name:potion,material.name:material}}, "identity":{"kind":DROPS.KIND,"source_npc_id":100,"source_sprite_id":70,"source_name":"fixture-npc"}}

func unit_checks() -> void:
	var f: Dictionary = fixtures()
	var groups: Dictionary = DROPS.resolve(f.document, f.identity, f.catalog)
	check(groups.size() == 3 and groups["1"].variants.size() == 2, "fixture distinct bless variants preserved; quest blocked")
	check(groups["1"].variants["1:0"].source_rows.size() == 2, "duplicate row provenance preserved without added variant weight")
	check(DROPS.diagnostics.quest_rows_blocked == 1 and DROPS.diagnostics.unsupported_bless_rows == 2 and DROPS.diagnostics.missing_item_bindings == 1, "quest lost and stack bless excluded explicitly")
	var bad: Dictionary = f.identity.duplicate(true)
	bad.source_npc_id = 101
	check(DROPS.resolve(f.document, bad, f.catalog).is_empty(), "no NPC name fallback")
	bad = f.identity.duplicate(true); bad.source_sprite_id = 71
	check(DROPS.resolve(f.document, bad, f.catalog).is_empty(), "sprite mismatch rejected")
	bad = f.identity.duplicate(true); bad.source_name = "same display name different variant"
	check(DROPS.resolve(f.document, bad, f.catalog).is_empty(), "source variant identity mismatch rejected")
	var wrong: Dictionary = f.catalog.duplicate(true)
	wrong.by_name["fixture1"].sourceId = "999"
	check(not DROPS.resolve(f.document, f.identity, wrong).has("1"), "catalog ID mutation rejected")
	check(DROPS.catalog_index([f.catalog.by_name["fixture1"], f.catalog.by_name["fixture1"]]).is_empty(), "ambiguous runtime inventory name rejected")
	var separate: Dictionary = {"by_name":{}, "patch523_by_name":f.catalog.by_name}
	check(DROPS.resolve(f.document, f.identity, separate).size() == 3 and separate.by_name.is_empty(), "source encyclopedia lookup keeps legacy loot pool unchanged")
	var rng := RandomNumberGenerator.new(); rng.seed = 523
	var reduced: Dictionary = f.document.duplicate(true)
	reduced.drops["100"].remove_at(1)
	var fewer: Dictionary = DROPS.resolve(reduced, f.identity, f.catalog)
	var a := RandomNumberGenerator.new(); var b := RandomNumberGenerator.new(); a.seed = 114; b.seed = 114
	for attempt: int in range(100):
		var first: Dictionary = DROPS.pick(groups, "equipment", "희귀", a)
		var second: Dictionary = DROPS.pick(fewer, "equipment", "희귀", b)
		check(first.source_m_drop_proof.bless_raw == second.source_m_drop_proof.bless_raw and first.quantity == 1, "duplicate source rows never increase weight/count")
	check(not DROPS.pick(groups, "potion", "", rng).is_empty(), "unique potion has no direct grade ban")
	check(DROPS.pick(groups, "equipment", "전설", rng).is_empty(), "successful grade never substitutes different grade")
	# All grades can be selected; unchanged field weights still exclude absent keys.
	for grade: String in LOOT.EQUIPMENT_GRADES:
		var changed: Dictionary = groups.duplicate(true); changed["1"].item.grade = grade
		check(not DROPS.pick(changed, "equipment", grade, rng).is_empty(), "candidate has no upper grade cap: "+grade)
	check(LOOT.NORMAL_EQUIPMENT_RATES == {"일반":0.001,"고급":0.001,"희귀":0.001,"영웅":0.00015}, "field grade chances unchanged")
	check(LOOT.BOSS_EQUIPMENT_RATES == {"일반":0.001,"고급":0.001,"희귀":0.001,"영웅":0.01,"전설":0.002,"신화":0.00025,"유일":0.00001}, "boss grade chances unchanged")
	for attempt: int in range(1000):
		var result: Array[Dictionary] = LOOT.roll_patch523(groups, false, rng)
		check(result.size() <= 3, "field bounded potion gear material rolls")
		for entry: Dictionary in result:
			check(entry.quantity == 1 and entry.source_m_drop_proof.required_quest_id == 0, "host quantity and quest exclusion")
	var legacy_potion: String = LOOT._pick_potion(["fixture2"], false, f.catalog, rng)
	check(legacy_potion == "fixture2", "legacy configured unique potion cap removed")
	check(DROPS.decode(PackedByteArray([1,2,3])).is_empty(), "untrusted data SHA rejected before decode")

func capture(name_value: String) -> void:
	var directory: String = OS.get_environment("TWILIGHT_DROP_CAPTURE_DIR")
	if directory.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(name_value+".png")) == OK, "actual rendered UI capture: "+name_value)

func world_checks() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main startup")
	world.field_population.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world._clear_monsters()
	world._clear_drops()
	var before: Dictionary = world.inventory.duplicate(true)
	var saved_sha: String = FileAccess.get_sha256(world.save_path()) if FileAccess.file_exists(world.save_path()) else ""
	# Actual native data test is opt-in; CI uses only synthetic rule tests above.
	var document: Dictionary = DROPS.data()
	if not document.is_empty():
		check(document.counts.rows == 46854 and document.counts.duplicate_extra_rows == 2582 and document.counts.pairs_with_condition_variants == 1858, "real 523 counts")
		var record: Dictionary = world.BASE508.npc_record(382, {"is_boss":true,"atk":8,"speed":70.0,"drop":[]})
		var native_identity: Dictionary = DROPS.identity(record)
		var groups: Dictionary = DROPS.candidates(native_identity, world.loot_catalog)
		check(groups.has("582") and groups["582"].variants.has("2:0"), "real 523 blessed boots resolve by exact ID")
		var one: Dictionary = {"582":groups.get("582", {}).duplicate(true)}
		one["582"].variants.erase("1:0") # Select the real blessed row to test physical transfer.
		var rng := RandomNumberGenerator.new(); rng.seed = 11
		var chosen: Dictionary = DROPS.pick(one, "equipment", "희귀", rng)
		check(chosen.get("item_record", {}).get("bless_state") == "blessed", "real original bless reaches entry")
		var view: Button = world._spawn_ground_drop(chosen.item_name, world.player.global_position, 1, "523", DROPS.ground_metadata(chosen))
		check(view != null and world.inventory == before, "real source equipment floor before inventory")
		if view != null:
			view.set("visible_since", Time.get_ticks_msec()-900)
			var floor_record: Dictionary = world.ground_loot.records[str(view.get_meta("id"))]
			var id: String = floor_record.physical_item.id
			check(view.tooltip_text.contains("523 드랍원 #382") and view.tooltip_text.contains("축복"), "actual ground UI source and bless")
			check(world._collect_ground_drop(view), "actual ground pickup")
			check(world.item_instances.has(id) and world.item_instances[id].bless_state == "blessed" and world.item_instances[id].record.source_m_drop_proof.source_npc_id == 382, "physical ownership and bless provenance survive pickup")
			check(world._save_game(true) == OK, "source physical equipment saved")
			world._load_game(true)
			check(world.item_instances.has(id) and world.item_instances[id].record.bless_state == "blessed", "source physical equipment survives actual save load")
			world.field_population.set_process(false)
			world._clear_monsters()
		var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(monster)
		monster.setup(record, world.player, world, null)
		monster.global_position = world.player.global_position
		check(DROPS.native(monster.loot_source_identity), "actual Monster.setup exact native identity")
		world._clear_drops(); before = world.inventory.duplicate(true)
		# Find a successful deterministic seed with the unchanged production roll.
		# A 20-kill sample can legitimately contain no rare equipment.
		var successful_seed: int = -1
		for seed_value: int in range(1000):
			rng.seed = seed_value
			if not LOOT.roll_patch523(groups, true, rng).is_empty(): successful_seed = seed_value; break
		check(successful_seed >= 0, "deterministic seed exercises a real configured drop")
		world.rng.seed = maxi(0, successful_seed)
		world._roll_drop(monster)
		check(not world.ground_loot.records.is_empty() and world.inventory == before, "actual Monster World roll only creates ground loot")
		for floor_record: Dictionary in world.ground_loot.records.values():
			check(floor_record.get("item_record", {}).get("source_m_drop_proof", {}).get("source_npc_id") == 382, "real kill roll keeps NPC-specific provenance")
		monster.died.connect(world._on_monster_died)
		monster.take_damage(monster.hp+1)
		var after_death_count: int = world.ground_loot.records.size()
		check(monster.dead and int(monster.get_meta("rewarded_life_id", -1)) == monster.life_id, "actual damage death signal reaches World reward transaction")
		world._on_monster_died(monster)
		check(world.ground_loot.records.size() == after_death_count and world.inventory == before, "duplicate death cannot duplicate native loot or grant directly")
		world.hud.open_catalog("아이템")
		world.hud.catalog_search.text = "지식의 부츠"
		world.hud._refresh_catalog_list("지식의 부츠")
		var selected_index: int = -1
		for index: int in range(world.hud.catalog_results.size()):
			if str(world.hud.catalog_results[index].get("sourceId", "")) == "582": selected_index = index; break
		check(selected_index >= 0, "actual catalog search finds exact source ID")
		if selected_index >= 0: world.hud._select_catalog_index(selected_index)
		check(world.hud.catalog_detail.text.contains("523 원본 드랍원") and world.hud.catalog_detail.text.contains("축복"), "actual item catalog renders original source conditions")
		world.hud._set_catalog_detail_view(true)
		await capture("patch523-item-drop-sources")
		monster.retire_for_pool()
		check(monster.loot_source_identity.is_empty(), "pool retirement clears native loot identity")
		monster.free()
	else:
		check(DROPS.candidates({"kind":DROPS.KIND,"source_npc_id":382}, world.loot_catalog).is_empty(), "missing pack fails closed")
		check(DROPS.source_text({}).contains("미설치"), "missing data shown in catalog")
		check(not FileAccess.file_exists(world.save_path()) or FileAccess.get_sha256(world.save_path()) == saved_sha, "missing optional pack never changes save bytes")
	world.hud.open_settings_info()
	await process_frame
	check(world.hud.find_child("InstallPatch523DropPack", true, false) != null, "actual settings installer is reachable")
	await capture("patch523-drop-install-settings")
	world.queue_free()
	await process_frame

func run() -> void:
	unit_checks()
	var install_path: String = OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP")
	if not install_path.is_empty():
		check(DROPS.install_zip(install_path).get("ok", false), "real private ZIP installed with production validator")
		check(FileAccess.get_sha256(DROPS.installed_path()) == DROPS.DATA_SHA, "installed real data SHA")
		check(DROPS.install_zip(install_path).get("ok", false), "same version reinstall preserves installed data")
		var invalid_path: String = "user://invalid-drop-pack.zip"
		var invalid := FileAccess.open(invalid_path, FileAccess.WRITE)
		invalid.store_buffer(PackedByteArray([1,2,3,4])); invalid.close()
		check(not DROPS.install_zip(invalid_path).get("ok", true), "damaged ZIP installation rejected")
		check(FileAccess.get_sha256(DROPS.installed_path()) == DROPS.DATA_SHA, "damaged update preserves installed original data")
	await world_checks()
	print("PATCH523_MONSTER_DROPS_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"original_data_loaded":not DROPS.data().is_empty()}))
	quit(0 if failures.is_empty() else 1)
