extends SceneTree
## Real Main regression for the unregistered presentation/API boundary.
## This proves form removal and existing behavior, not original UI completion.
const QA = preload("res://tests/qa_class_selection.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const PRESENTATION = preload("res://scripts/ui/relic_spell_level_presentation.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: String = ""
var world: TwilightWorld
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RELIC_UNBOUND_FAIL ", message)
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await process_frame
func freeze() -> void:
	world.set_process(false); world.save_timer = -100000.0
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func no_replacement(hud: Node) -> bool:
	for node_name: String in ["RelicSpellLevelPanel", "RelicSpellLevelValues", "RelicSpellLevelStatus", "RelicSpellLevelImport", "RelicSpellLevelSourcePicker"]:
		if hud.find_child(node_name, true, false) != null: return false
	return true
func run() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="): path = arg.trim_prefix("--source-zip=")
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	if path.is_empty(): printerr("Explicit authorized source ZIP required"); quit(2); return
	root.size = Vector2i(1280, 720)
	world = load("res://Main.tscn").instantiate(); world.set_process(false)
	root.add_child(world); freeze(); await frames(8)
	check(QA.enter_game(world), "actual Main class confirmation"); freeze()
	var hud: Node = world.hud
	var record: Dictionary = {}
	for row: Dictionary in world.catalog_db["성물"]:
		if int(row.get("source_card_id", 0)) == 21428: record = row; break
	check(not record.is_empty(), "actual canonical hero relic")
	var identity: String = CARDS.card_id(record)
	check(world._save_game(true) == OK, "durable initial progression fixture")
	var initial_hash: String = FileAccess.get_sha256(world.save_path())
	var inventory: Dictionary = world.inventory.duplicate(true)
	var gold: int = world.gold
	var initial_cards: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	hud.open_catalog("성물"); await frames(6)
	check(no_replacement(hud), "ordinary relic screen mounts no invented panel/import/picker")
	check(not PRESENTATION.snapshot(world, record).ok, "missing source API stays unavailable")
	check(not PRESENTATION.install_source(path + ".missing").get("ok", false), "invalid explicit import rejected")
	check(FileAccess.get_sha256(world.save_path()) == initial_hash, "opening/query/rejected import preserves exact save")
	check(world.card_draw_fusion.export_state() == initial_cards and world.inventory == inventory and world.gold == gold, "absent presentation cannot grant ownership or spend resources")
	check(PRESENTATION.install_source(path).get("ok", false), "explicit API preserves verified atomic source installation")
	check(FileAccess.get_sha256(RULES.INSTALLED) == RULES.SOURCE_SHA256, "installed source bytes match pinned archive")
	var unowned: Dictionary = PRESENTATION.snapshot(world, record)
	check(unowned.ok and unowned.code == "not_owned" and not unowned.active, "unowned source query remains read only")
	unowned.effects.clear(); unowned.bonus_by_grade.clear()
	check(not PRESENTATION.snapshot(world, record).effects.is_empty(), "caller cannot mutate loaded rules through snapshot")
	check(FileAccess.get_sha256(world.save_path()) == initial_hash and world.card_draw_fusion.export_state() == initial_cards, "successful rules install does not write progression or grant cards")
	world.card_draw_fusion.owned["성물"][identity] = true # Isolated test fixture only.
	world._update_hud()
	check(world._save_game(true) == OK, "durable owned fixture through existing save")
	var save_hash: String = FileAccess.get_sha256(world.save_path())
	var cards: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	hud.open_catalog("성물"); await frames(4)
	hud.catalog_search.text = str(record.name); hud.catalog_search.text_changed.emit(str(record.name)); await frames(4)
	var selected_index: int = -1
	for index: int in range(hud.catalog_results.size()):
		if CARDS.card_id(hud.catalog_results[index]) == identity: selected_index = index; break
	check(selected_index >= 0, "search retains exact selected source identity")
	if selected_index >= 0: hud._on_catalog_item_selected(selected_index)
	await frames(4)
	var before_key: int = PRESENTATION.state_key(world)
	var before: Dictionary = PRESENTATION.snapshot(world, record)
	check(before.ok and before.code == "not_equipped" and int(before.bonus_by_grade.get(1, 0)) == 1, "unregistered boundary exposes raw original grade bonus")
	for _index: int in range(10): PRESENTATION.snapshot(world, record); PRESENTATION.state_key(world)
	check(FileAccess.get_sha256(world.save_path()) == save_hash and world.equipped_catalog["성물"].is_empty(), "repeated presentation reads never equip or save")
	hud.catalog_equip_button.pressed.emit(); await frames()
	var modal: Control = hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(modal != null, "existing summon confirmation remains wired")
	if modal != null: modal.confirm_button.pressed.emit()
	await frames(6)
	check(CARDS.card_id(world.equipped_catalog["성물"]) == identity, "existing explicit summon applies exact card")
	check(PRESENTATION.snapshot(world, record).active and PRESENTATION.state_key(world) != before_key, "unregistered read reflects actual state without polling nodes")
	check(hud.relic_reference_view.status.text.contains(str(record.name)), "existing summon label still refreshes")
	check(world.source_relic_spell_level(1, 0).effective_level == 1 and world.source_relic_spell_level(4, 0).effective_level == 0, "actual Main grade-specific level modifier remains connected")
	var summon_hash: String = FileAccess.get_sha256(world.save_path())
	var vitals: Array = [world.hp, world.mp]
	world.equipment_collections.save_blocked = true
	hud.catalog_clear_button.pressed.emit(); await frames()
	var rejected_modal: Control = hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(rejected_modal != null, "existing release confirmation available during save failure")
	if rejected_modal != null: rejected_modal.confirm_button.pressed.emit()
	await frames()
	check(CARDS.card_id(world.equipped_catalog["성물"]) == identity and PRESENTATION.snapshot(world, record).active, "failed release preserves selection and active source effect")
	check(FileAccess.get_sha256(world.save_path()) == summon_hash and [world.hp, world.mp] == vitals, "failed release preserves exact save and live resources")
	world.equipment_collections.save_blocked = false
	for extent: Vector2i in [Vector2i(1280,720), Vector2i(854,480)]:
		root.size = extent; DisplayServer.window_set_size(extent); await frames(8)
		hud._set_catalog_detail_view(true); await frames(4)
		check(no_replacement(hud) and hud.relic_reference_view.is_visible_in_tree(), "existing relic view opens without substitute controls " + str(extent))
		if not captures.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(captures)
			check(root.get_texture().get_image().save_png(captures.path_join("relic-unbound-" + str(extent.x) + ".png")) == OK, "actual OpenGL capture " + str(extent))
	hud.catalog_clear_button.pressed.emit(); await frames(6)
	var clear_modal: Control = hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	if clear_modal != null: clear_modal.confirm_button.pressed.emit(); await frames(4)
	check(world.equipped_catalog["성물"].is_empty() and world.source_relic_spell_level(1, 0).bonus == 0, "existing release removes modifier")
	check(not PRESENTATION.snapshot(world, record).active and hud.relic_reference_view.status.text.contains("없음"), "release updates existing state without invented form")
	check(world.inventory == inventory and world.gold == gold and world.card_draw_fusion.export_state() == cards, "explicit summon/release spends no inventory gold or awakening materials")
	check(JSON.parse_string(FileAccess.get_file_as_string(world.save_path())).equipped_catalog == normalized(world.equipped_catalog), "release persists selection through existing atomic writer")
	var persisted_hash: String = FileAccess.get_sha256(world.save_path())
	world.queue_free(); await frames(2)
	RULES._rules.clear(); RULES._default_checked = false
	world = load("res://Main.tscn").instantiate(); world.set_process(false)
	root.add_child(world); freeze(); await frames(8)
	check(QA.enter_game(world), "actual Main reentry class flow"); freeze()
	check(world.equipped_catalog["성물"].is_empty() and world.card_draw_fusion.export_state() == cards, "real Main reentry preserves release and ownership")
	check(normalized(world.inventory) == normalized(inventory) and world.gold == gold, "reentry preserves inventory and gold")
	check(FileAccess.get_sha256(world.save_path()) == persisted_hash, "reentry preserves exact save bytes")
	check(FileAccess.get_sha256(RULES.INSTALLED) == RULES.SOURCE_SHA256 and PRESENTATION.snapshot(world, record).code == "not_equipped", "installed source survives reentry through unchanged API")
	world.hud.open_catalog("성물"); await frames()
	check(no_replacement(world.hud), "reentry does not remount unverified presentation")
	print("RELIC_SPELL_LEVEL_UNBOUND_MAIN_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "renderer":DisplayServer.get_name(), "original_ui":"UNREGISTERED"}))
	world.queue_free(); await frames(2); quit(0 if failures.is_empty() else 1)
