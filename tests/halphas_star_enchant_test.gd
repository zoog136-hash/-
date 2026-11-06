extends SceneTree
const Rules = preload("res://scripts/cards/native_halphas_star_enchant.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("HALPHAS_STAR_FAIL: ", label)

func settle() -> void:
	for i: int in range(4): await process_frame

func tap(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main class selection")
	world.player.set_physics_process(false)
	# Menu input stays live; isolate assertions from unrelated simulation time.
	world.legacy_population.set_process(false)
	world.original_population.set_process(false)
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	# The initial HUD replaces its legacy catalog container with queue_free.
	# Wait for its first rendered frame before opening the retained catalog.
	await settle()
	var record: Dictionary = {}
	var matches: int = 0
	for category: String in Cards.CATEGORIES:
		for candidate: Dictionary in world.catalog_db[category]:
			if Rules.is_target(category, candidate):
				matches += 1
				record = candidate
			else:
				check(not Rules.snapshot(category, candidate, {}, 999999999).ok, "no generalization " + Cards.card_id(candidate))
	if DEFINITIONS.not_installed():
		# CI never has the user's owned current523 definition ZIP. The rule then
		# has no definition: no card qualifies and every request refuses.
		print("VALIDATION_SCOPE current523 definitions not installed: Halphas checks verify the absent-install path")
		var status: Dictionary = Rules.input_status()
		check(matches == 0 and record.is_empty(), "no card qualifies without the owned definitions")
		check(not bool(status.available) and str(status.problem).begins_with("halphas_current523_unavailable"), "unavailable definitions are reported, not substituted")
		print("HALPHAS_STAR_ENCHANT_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
		world.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	check(matches == 1 and not record.is_empty(), "only original Halphas group qualifies")
	if record.is_empty():
		world.queue_free()
		quit(1)
		return
	var identity: String = Cards.card_id(record)
	var forged: Dictionary = record.duplicate(true)
	forged.sourceId = "m508:1:18722"
	check(not Rules.is_target("변신", forged), "other unique transform cannot impersonate Halphas")
	check(not Rules.is_target("마법인형", record), "category restriction")
	var unowned: Dictionary = Rules.snapshot("변신", record, {}, 0)
	check(unowned.ok and not unowned.owned and unowned.problems.has("not_owned"), "unowned inspection")
	var definition: Dictionary = Rules.DATA.data
	check(int(definition.content_control.ID) == 1154 and definition.content_control.Enable == false, "source feature control explicitly false")
	check(int(definition.content_control.ServerLimitSetID) == int(definition.group.ServerLimitsetID), "feature and group share unresolved server scope")
	check(definition.unresolved_server_limit_sets.size() == 1 and int(definition.unresolved_server_limit_sets[0]) == 274, "source group server definition is unresolved")
	check(definition.bonuses.size() == 43 and definition.sprite_options.size() == 3, "all source bonus and cosmetic references retained")
	for i: int in range(3):
		var rule: Dictionary = unowned.stages[i]
		check(int(rule.Enchant) == i + 1 and int(rule.SourceAmount) == i + 1, "source stage material count " + str(i))
		check(int(rule.CurrencyID) == 1 and int(rule.CurrencyCost) == 5500000, "source Adena cost " + str(i))
		check(not rule.affordable, "zero gold not affordable " + str(i))
		check(int(rule.Probability) == [1000000, 666000, 333000][i], "raw probability preserved " + str(i))
	world.card_draw_fusion.owned["변신"][identity] = true
	world.card_draw_fusion.spare["변신"][identity] = 99
	world.gold = 999999999
	var server: Dictionary = definition.server_limits[0]
	var context: Dictionary = {"source_snapshot":"base508", "WorldNo":server.WorldNo, "ServiceRegionCode":server.ServiceRegionCode}
	check(world.card_collections.set_source_server_context(context), "exact source server context")
	world.source_card_visual_options[record.sourceId] = 24
	var owned: Dictionary = Rules.from_world(world, "변신", identity)
	check(owned.owned and not owned.can_attempt and owned.problems.has("server_definition_missing"), "owned wealthy card still respects missing group gate")
	check(owned.server_evaluations[0].status == "eligible", "card server membership resolved independently")
	check(owned.problems.has("source_feature_disabled"), "card server membership does not override feature control")
	owned.feature_control.Enable = true
	check(Rules.DATA.data.content_control.Enable == false, "caller cannot mutate authoritative source feature flag")
	check(owned.earned_stage == null, "selected stage3 cosmetic never implies earned level")
	check(world._save_game(true) == OK, "real save before request")
	var save_path: String = world.save_path()
	var before_sha: String = FileAccess.get_sha256(save_path)
	var before_cards: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	var before_visuals: Dictionary = world.source_card_visual_options.duplicate(true)
	var before_collection: Dictionary = world.equipment_collections.export_state().duplicate(true)
	var before_bosses: Dictionary = world.legacy_population.export_state().duplicate(true)
	for unused: int in range(3):
		var result: Dictionary = Rules.from_world(world, "변신", identity, true)
		check(not result.ok and result.code == "source_feature_disabled", "direct request safely rejects explicit source false")
	var hud: Node = world.hud
	world._update_hud()
	for extent: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = extent
		hud.open_catalog("변신")
		hud.catalog_search.text = "해방된 할파스"
		hud.catalog_search.text_changed.emit(hud.catalog_search.text)
		await settle()
		check(hud.catalog_results.size() == 1, "actual catalog filter " + str(extent))
		hud._on_catalog_item_selected(0)
		hud._set_catalog_detail_view(true)
		await settle()
		var entry: Button = hud.halphas_star_enchant_button
		hud.catalog_body_actions.ensure_control_visible(entry)
		await settle()
		check(entry.is_visible_in_tree() and not entry.disabled, "Halphas entry visible " + str(extent))
		await tap(entry)
		check(hud.active_section == "halphas_star_enchant", "real mouse opens Halphas view " + str(extent))
		var action: Button = hud.workspace.find_child("HalphasStarEnchantAttempt", true, false)
		check(action != null and action.disabled, "unresolved attempt disabled " + str(extent))
		if action != null:
			for stage: int in range(1,4):
				var label: Label = hud.workspace.find_child("HalphasStage" + str(stage), true, false)
				check(label != null and label.text.contains("5500000"), "source stage cost visible " + str(stage))
			var check_button: Button = hud.workspace.find_child("HalphasStarEnchantCheck", true, false)
			check(check_button != null and not check_button.disabled, "condition recheck can be used")
			if check_button != null:
				var scroll: ScrollContainer = hud.workspace.find_child("HalphasStarEnchantScroll", true, false)
				scroll.ensure_control_visible(check_button)
				await settle()
				await tap(check_button)
				action = hud.workspace.find_child("HalphasStarEnchantAttempt", true, false)
				check(root.get_visible_rect().encloses(action.get_global_rect()), "disabled attempt remains visible beside recheck")
			var status: Label = hud.workspace.find_child("HalphasStarEnchantStatus", true, false)
			check(status != null and status.text.begins_with("확인 결과") and status.text.contains("소모되지 않습니다"), "blocked UI result shown after actual click")
			if DisplayServer.get_name() != "headless" and "--capture-halphas" in OS.get_cmdline_user_args():
				await process_frame
				check(root.get_texture().get_image().save_png("/tmp/halphas-" + str(extent.x) + ".png") == OK, "actual OpenGL capture")
		hud.open_catalog("마법인형")
		await settle()
		check(not hud.halphas_star_enchant_button.is_visible_in_tree(), "no entry on another category")
	check(FileAccess.get_sha256(save_path) == before_sha, "UI and requests preserve exact save bytes")
	check(world.gold == 999999999, "no gold consumed")
	check(world.card_draw_fusion.export_state() == before_cards, "ownership spares and card RNG unchanged")
	check(world.source_card_visual_options == before_visuals, "existing source cosmetic selection preserved")
	check(world.equipment_collections.export_state() == before_collection, "collection progress preserved")
	check(world.legacy_population.export_state() == before_bosses, "boss state preserved")
	print("HALPHAS_STAR_ENCHANT_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
