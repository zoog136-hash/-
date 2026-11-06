extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EXPEDITION_UI_FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://Main.tscn") as PackedScene
	check(scene != null, "actual Main scene")
	if scene == null:
		quit(1)
		return
	var world := scene.instantiate() as TwilightWorld
	root.add_child(world)
	check(QA.enter_game(world), "actual class confirmation")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.save_timer = -100000.0
	var identity := ""
	# Skill awakening definitions come only from the user's owned current523 ZIP.
	# Without it (CI), use a real source card without awakening progress; the
	# expedition checks below are unchanged.
	var awakening_definitions: bool = not DEFINITIONS.not_installed()
	for card: Dictionary in world.catalog_db.get("마법인형", []):
		var id := world.CARD_DRAW_FUSION.card_id(card)
		var candidates: Array = world.skill_awakening.core.candidates(id)
		if card.get("source") == "lineagem_base508" and card.get("grade") == "희귀" and (not awakening_definitions or not candidates.is_empty()):
			identity = id
			world.card_draw_fusion.owned["마법인형"][id] = true
			if awakening_definitions:
				world.skill_awakening.progress.cards[id] = {"spell_id": int(candidates[0].spell_id), "level": 5, "experience": "0"}
			break
	if awakening_definitions:
		check(not identity.is_empty(), "real source card and skill save identity")
	else:
		# Current cards come only from the owned ZIP; absence must stay empty
		# rather than substituting another card registry. Not counted as a pass.
		print("VALIDATION_SCOPE current523 definitions not installed: no source card identity; card-dependent expedition paths need the owned ZIP")
		check(world.catalog_db.get("마법인형", []).is_empty() and identity.is_empty(), "absent current523 install exposes no substitute card identity")
	world.gold = 200000
	check(world._save_game(true) == OK, "baseline save through production writer")
	var path := world.save_path()
	var baseline := FileAccess.get_sha256(path)
	var before := JSON.stringify([world.gold, world.inventory, world.item_instances, world.equipped_catalog, world.card_draw_fusion.export_state(), world.skill_awakening.export_state(), world.equipment_collections.export_state(), world.rng.state])
	var expected_source := false
	var capture := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expedition523-pack="): expected_source = true
		if argument.begins_with("--expedition523-capture="): capture = argument.trim_prefix("--expedition523-capture=")
	var catalog: RefCounted = world.get_expedition_catalog()
	check(catalog.ready() == expected_source, "explicit private pack presence")
	if expected_source:
		var original_equipped: Dictionary = world.equipped_catalog.duplicate(true)
		for candidate: Dictionary in world.catalog_db.get("마법인형", []):
			if world.CARD_DRAW_FUSION.card_id(candidate) == identity:
				world.equipped_catalog["마법인형"] = candidate.duplicate(true)
		check(not world.expedition_local.prepare(1, [identity]).ok, "source help rejects currently summoned primary card")
		world.equipped_catalog = original_equipped
		var secondary_field := "native_subslot_identity"
		var had_secondary: bool = world.option_awakening.progress.has(secondary_field)
		var old_secondary: Variant = world.option_awakening.progress.get(secondary_field)
		world.option_awakening.progress[secondary_field] = identity
		check(not world.expedition_local.prepare(1, [identity]).ok, "current additional summon also prevents departure")
		if had_secondary: world.option_awakening.progress[secondary_field] = old_secondary
		else: world.option_awakening.progress.erase(secondary_field)
	world.hud.toggle_menu()
	var tile: Button = world.hud.workspace.find_child("MenuTile_expedition", true, false)
	check(tile != null and tile.is_visible_in_tree(), "actual menu contains expedition tile")
	if tile != null:
		tile.pressed.emit()
	check(world.hud.active_section == "expedition", "menu opens expedition workspace")
	var view: Control = world.hud.workspace.find_child("ExpeditionSourceView", true, false)
	check(view != null and view.is_visible_in_tree(), "actual expedition view mounted")
	if view != null and expected_source:
		check(view.spot_picker.item_count == 29, "all original523 locations selectable")
		check(view.group_picker.item_count == 10, "reward groups displayed independently")
		check(view.start_button.disabled, "UI blocks unconfirmed execution")
		var selected := -1
		for index in range(view.card_picker.item_count):
			if view.card_picker.get_item_metadata(index).identity == identity: selected = index
		check(selected >= 0, "actual owned source card shown")
		if selected >= 0:
			view.card_picker.select(selected)
			view.card_picker.multi_selected.emit(selected, true)
			check(view.state_label.text.contains("정적 조건: 충족"), "selection updates eligibility result")
		check(view.details.text.contains("완주 상자") and view.details.text.contains("이벤트 보상 후보"), "UI separates completion from event rewards")
		var previous: String = view.details.text
		view.group_picker.select(1)
		view.group_picker.item_selected.emit(1)
		check(view.details.text != previous, "changing reward group updates displayed rows")
		view.spot_picker.select(view.spot_picker.get_item_index(223))
		view.spot_picker.item_selected.emit(view.spot_picker.selected)
		check(view.details.text.contains("이벤트 보상 풀이 없습니다"), "mythical-only location preserves missing low-grade pool")
		check(not world.inspect_expedition(223, [identity]).static_conditions_met, "actual Main minimum-grade gate")
		view.spot_picker.select(0)
		view.spot_picker.item_selected.emit(0)
		if not capture.is_empty():
			for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
				root.size = size
				world.hud._fit_hud()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				check(view.start_button.is_visible_in_tree() and view.start_button.get_global_rect().end.y <= root.size.y, "visible controls at " + str(size))
				root.get_texture().get_image().save_png(capture+"-%dx%d.png" % [size.x, size.y])
	check(JSON.stringify([world.gold, world.inventory, world.item_instances, world.equipped_catalog, world.card_draw_fusion.export_state(), world.skill_awakening.export_state(), world.equipment_collections.export_state(), world.rng.state]) == before, "UI and requests preserve progression currencies cards and RNG")
	check(FileAccess.get_sha256(path) == baseline, "original saved bytes unchanged")
	if expected_source:
		world.equipment_collections.save_blocked = true
		check(not world.request_expedition_start(1, [identity]).ok, "failed production save rejects start")
		check(world.gold == 200000 and world.expedition_local.state.jobs.is_empty(), "failed start preserves gold jobs and attempts")
		world.equipment_collections.save_blocked = false
		var selected := -1
		for index in range(view.card_picker.item_count):
			if view.card_picker.get_item_metadata(index).identity == identity: selected = index
		view.card_picker.select(selected)
		view.card_picker.multi_selected.emit(selected, true)
		check(not view.start_button.disabled, "supported source card can actually depart")
		view.start_button.pressed.emit()
		var confirmation: Control = world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
		check(confirmation != null and confirmation.is_visible_in_tree(), "real cost and settlement limitation confirmation")
		if confirmation != null:
			(confirmation.find_child("ConfirmTransaction", true, false) as Button).pressed.emit()
		check(world.gold == 190000 and world.expedition_local.state.jobs.size() == 1, "UI departure debits exact source10000 and persists one job")
		var equip_before: String = JSON.stringify(world.equipped_catalog)
		for candidate: Dictionary in world.catalog_db.get("마법인형", []):
			if world.CARD_DRAW_FUSION.card_id(candidate) == identity: world._equip_catalog("마법인형", candidate)
		check(JSON.stringify(world.equipped_catalog) == equip_before, "reserved expedition card cannot be summoned again")
		var subslot_before: String = JSON.stringify(world.option_awakening.progress)
		world._on_secondary_doll_requested(identity)
		check(JSON.stringify(world.option_awakening.progress) == subslot_before, "reserved expedition card cannot enter additional slot")
		check(FileAccess.get_sha256(path+".pre-expedition523-"+baseline) == baseline, "first departure preserves original bytes in SHA backup")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(saved.gold == 190000 and saved.expedition523_local.jobs[0].remaining == 28800, "cost and source8hour state saved atomically")
		if not capture.is_empty():
			view._render()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture+"-started.png")
		check(not world.request_expedition_start(1, [identity]).ok and world.gold == 190000, "duplicate departure cannot debit twice")
		# Deterministic test policy exercises completion; production defaults stay intact.
		for event_type in world.expedition_local.state.jobs[0].sim.policy.normal_event_weights:
			world.expedition_local.state.jobs[0].sim.policy.normal_event_weights[event_type] = 1 if event_type == "71" else 0
		var loot_before: String = JSON.stringify([world.inventory, world.item_instances, world.rng.state])
		world.expedition_local.advance(120)
		check(world.expedition_local.state.jobs[0].remaining == 28680, "local connected-time counter advances")
		check(world._save_game(true) == OK, "progress checkpoint saves")
		world._load_game(true)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		check(not world.expedition_local.save_blocked, "paid expedition checkpoint validates on real JSON reload: " + world.expedition_local.validate(JSON.parse_string(FileAccess.get_file_as_string(path)).expedition523_local))
		check(world.expedition_local.state.jobs[0].remaining == 28680 and world.gold == 190000, "actual reload preserves job time and paid gold")
		# Main reload also rebuilds actors; isolate the expedition counter's own
		# inventory/RNG effects from that unrelated production load path.
		loot_before = JSON.stringify([world.inventory, world.item_instances, world.rng.state])
		world.expedition_local.advance(28800)
		check(world.expedition_local.state.jobs[0].status == "completed" and world.expedition_local.state.jobs[0].remaining == 0, "surviving local estimate reaches actual completion")
		check(JSON.stringify([world.inventory, world.item_instances, world.rng.state]) == loot_before, "completion alone does not grant items or change combat RNG")
		check(world._save_game(true) == OK, "pending settlement persists")
		var settlement_before: String = JSON.stringify([world.expedition_local.export_state(), world.inventory, world.item_instances, world.gold, world.rng.state])
		var settlement_hash: String = FileAccess.get_sha256(path)
		var job_id: int = int(world.expedition_local.state.jobs[0].id)
		var contract: Dictionary = world.expedition_local.settlement_view(job_id)
		check(contract.ok and contract.claimable and int(contract.reward.ID) == 136194 and int(contract.item.ID) == 166594, "completed job binds its exact original completion box")
		var original_reward: Variant = world.expedition_local.state.jobs[0].completion_reward_id
		world.expedition_local.state.jobs[0].completion_reward_id = int(original_reward)+1
		check(not world.expedition_local.settlement_view(job_id).ok, "forged completion reference rejected")
		world.expedition_local.state.jobs[0].completion_reward_id = original_reward
		view._refresh_jobs()
		(view.find_child("ExpeditionSettlementInspect", true, false) as Button).pressed.emit()
		check(view.details.text.contains("탐험 기록") and view.details.text.contains("개봉") and view.details.text.contains("AbleMultiple"), "actual UI shows pending settlement route and opening boundary")
		world.expedition_local.settlement_view(job_id)
		check(JSON.stringify([world.expedition_local.export_state(), world.inventory, world.item_instances, world.gold, world.rng.state]) == settlement_before and FileAccess.get_sha256(path) == settlement_hash, "repeated settlement inspection cannot duplicate rewards or advance RNG/save")
		if not capture.is_empty():
			view._show_settlement()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture+"-completed.png")
		var good_bytes := FileAccess.get_file_as_bytes(path)
		var corrupt: Dictionary = JSON.parse_string(good_bytes.get_string_from_utf8())
		corrupt.expedition523_local.jobs[0].remaining = -1
		check(preload("res://scripts/skills/save_writer.gd").write(path, corrupt) == OK, "malformed-state fixture uses atomic writer")
		var corrupt_hash := FileAccess.get_sha256(path)
		world.gold = 123
		world._load_game(true)
		check(world.expedition_local.save_blocked and world.gold == 123, "malformed expedition rejects before player mutation")
		check(world._save_game(true) != OK and FileAccess.get_sha256(path) == corrupt_hash, "malformed source save remains protected")
		var restore_file := FileAccess.open(path, FileAccess.WRITE)
		restore_file.store_buffer(good_bytes)
		restore_file.close()
		world._load_game(true)
		check(not world.expedition_local.save_blocked and world.gold == 190000, "valid restore clears protection without losing paid progress")
		baseline = FileAccess.get_sha256(path)
	else:
		check(not world.request_expedition_start(1, [identity]).ok, "missing pack cannot depart")
	world._load_game(true)
	check(FileAccess.get_sha256(path) == baseline, "reload preserves saved bytes")
	print("EXPEDITION523_MAIN_UI_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "source_installed": catalog.ready(), "capture_requested": not capture.is_empty()}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
