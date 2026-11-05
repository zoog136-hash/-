extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("MONSTERBOOK_UI_FAIL ", label)

func confirmed(action: String, sequence: int) -> Dictionary:
	return {"action": action, "book_id": 6013, "sequence": sequence, "epoch": "explicit-test-day", "authority": "TEST_ONLY_CONFIRMED_ADAPTER", "approved": true, "server_allowed": true, "clock_locale": "Korean", "source_clock": "202610200500"}

func test_action_authority(action: String, book_id: int, level_id: int, state: Dictionary) -> Dictionary:
	var receipt := confirmed(action, int(state.books[str(book_id)].sequence) + 1)
	receipt.book_id = book_id
	receipt.level_id = level_id
	receipt.registration_approved = true
	return receipt

func test_credit_authority(npc_id: int, _life_id: int, _actor: int, state: Dictionary) -> Dictionary:
	var receipt := confirmed("count", int(state.books['6013'].sequence) + 1)
	receipt.npc_class_id = npc_id
	receipt.level_ids = [16423]
	return receipt

func tap(control: Control, canceled: bool = false) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.position = point
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = point
	release.pressed = false
	release.canceled = canceled
	root.push_input(release, true)
	await process_frame

func all_text(node: Node) -> String:
	var value: String = str(node.get("text")) if node is Label or node is Button else ""
	for child: Node in node.get_children(): value += "\n" + all_text(child)
	return value

func run() -> void:
	check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(), "explicit current map pack")
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main class confirmation")
	world.player.set_physics_process(false)
	# This retained test exercises the explicit external adapter contract.
	world.monsterbook523_runtime.action_authority = Callable()
	world.monsterbook523_runtime.credit_authority = Callable()
	world.monsterbook523_runtime.clock_authority = Callable()
	world.monsterbook523_runtime.settlement = Callable()
	check(world.monsterbook523.loaded(), "actual Main consumed private523 pack with digest")
	if not world.monsterbook523.loaded():
		world.queue_free()
		quit(1)
		return
	world.hud.toggle_menu()
	await process_frame
	var tile: Button = world.hud.find_child("MenuTile_monsterbook523", true, false)
	check(tile != null and tile.is_visible_in_tree(), "menu exposes separate monsterbook entry")
	if tile == null: quit(1); return
	await process_frame
	await process_frame
	world.hud.menu_scroll_view.ensure_control_visible(tile)
	await process_frame
	await process_frame
	await process_frame
	print("MONSTERBOOK_ROUTE ",tile.get_global_rect()," viewport=",root.size)
	await tap(tile)
	var panel: Control = world.hud.find_child("MonsterBook523Panel", true, false)
	check(panel != null and panel.is_visible_in_tree(), "viewport native touch opens real dedicated panel")
	if panel == null:
		world.queue_free()
		quit(1)
		return
	check(panel.list.item_count == 33, "33 current definitions visible")
	panel.search.text = "특수 던전 토벌자"
	panel.search.text_changed.emit(panel.search.text)
	check(panel.list.item_count == 1 and panel.selected_id == 6013, "search selects exact daily book")
	check(all_text(panel).contains("처치 0 / 1000") and all_text(panel).contains("단계 옵션 없음"), "visible count/empty daily bonus")
	var claim: Button = panel.find_child("MonsterBook_claim_16423", true, false)
	check(claim != null and claim.disabled and not claim.tooltip_text.is_empty(), "unconfirmed payouts disabled with reason")
	panel.history.button_pressed = true
	panel.search.text = ""
	panel.search.text_changed.emit("")
	check(panel.list.item_count == 557, "history shows all557 definitions")
	panel.history.button_pressed = false
	panel.search.text = "특수 던전 토벌자"
	panel.search.text_changed.emit(panel.search.text)
	var before_inventory: Dictionary = world.inventory.duplicate(true)
	var before_gold: int = world.gold
	var begin := confirmed("begin_epoch", 1)
	begin.reset_approved = true
	check(world.monsterbook523_runtime.apply_confirmed(begin), "explicit epoch durably starts via actual save writer")
	var seeded: Dictionary = world.monsterbook523.export_state()
	seeded.books['6013'].epochs['explicit-test-day'].counts['16423'] = 999
	check(world.monsterbook523.import_state(seeded), "isolated confirmed snapshot setup")
	world.monsterbook523_runtime.credit_authority = Callable(self, "test_credit_authority")
	var actor: Node = load("res://scenes/Monster.tscn").instantiate()
	actor.source_m_npc_id = 6681
	actor.life_id = 100
	world.monsterbook523_runtime.on_death(actor)
	actor.free()
	check(int(world.monsterbook523.progress(6013).counts['16423']) == 1000, "exact NPC confirmed death adapter increments existing stage")
	check(all_text(panel).contains("처치 1000 / 1000"), "open panel updates after committed credit")
	world.monsterbook523_runtime.action_authority = Callable(self, "test_action_authority")
	panel.refresh()
	var register: Button = panel.find_child("MonsterBook_register_16423", true, false)
	check(register != null and not register.disabled, "eligible zero-cost stage button enabled with explicit authority")
	panel.stage_scroll.ensure_control_visible(register)
	await process_frame
	await tap(register, true)
	check(not world.monsterbook523.progress(6013).registered.has(16423), "canceled touch cannot register")
	await tap(register)
	await process_frame
	check(panel.result.text == "등록 완료" and all_text(panel).contains("보상 미수령"), "registration result visible separately from reward claim")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(saved.monsterbook523.books['6013'].epochs['explicit-test-day'].registered[0]) == 16423, "registration physically persisted")
	check(world.inventory == before_inventory and world.gold == before_gold, "Gem/EXP/item conversions not invented")
	var state_before: Dictionary = world.monsterbook523.export_state()
	var denied: Dictionary = world.request_monsterbook_action("claim", 6013, 16423)
	check(not denied.ok and world.monsterbook523.export_state() == state_before, "entire unreviewed original reward bundle remains unclaimed")
	# Confirmed selection plus explicit current source clock drives an actual flat
	# combat consumer. This is not automatic native stacking or timezone inference.
	var flat_stage: Dictionary = {}
	var flat_book_id: int = 0
	for book: Dictionary in world.monsterbook523.books():
		for stage: Dictionary in world.monsterbook523.levels(int(book.ID)):
			for bonus: Dictionary in stage.bonuses:
				if world.monsterbook523.row("BonusType",int(bonus.BonusTypeID)).get("Name") == "MeleeDamage":
					flat_stage = stage
					flat_book_id = int(book.ID)
	var damage_before: int = world._melee_damage_stat()
	var ranged_before: int = world._ranged_damage_stat()
	var bonus_state: Dictionary = state_before.duplicate(true)
	bonus_state.books[str(flat_book_id)] = {"sequence":1,"current_epoch":"confirmed-season","epochs":{"confirmed-season":{"counts":{str(int(flat_stage.ID)):int(flat_stage.Amount)},"registered":[int(flat_stage.ID)],"claimed":[],"effective_levels":[int(flat_stage.ID)]}}}
	check(world.monsterbook523.import_state(bonus_state), "confirmed registered effect snapshot setup")
	check(world._melee_damage_stat() == damage_before, "unconfirmed current clock cannot activate timed bonus")
	world.monsterbook523_runtime.clock_authority = func() -> String: return "202610290500"
	check(world._melee_damage_stat() == damage_before + 1 and world._ranged_damage_stat() == ranged_before + 1, "whole selected stage reaches actual melee and ranged combat stats")
	world.monsterbook523_runtime.clock_authority = func() -> String: return "202611040500"
	check(world._melee_damage_stat() == damage_before and world.monsterbook523.progress(flat_book_id).registered == [int(flat_stage.ID)], "bonus expires without deleting registration")
	world.monsterbook523.import_state(state_before)
	var path: String = world.save_path()
	var hash: String = FileAccess.get_sha256(path)
	world._load_game(true)
	check(world.monsterbook523.export_state() == state_before and FileAccess.get_sha256(path) == hash, "actual Main reload preserves original state and bytes")
	# Render real UI at both sizes. These captures do not assert original artwork fidelity.
	var capture_dir: String = OS.get_environment("MONSTERBOOK523_CAPTURES")
	for size: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		root.content_scale_size = size
		root.size = size
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		check(panel.is_visible_in_tree() and panel.get_global_rect().size.x > 100 and panel.get_global_rect().size.y > 100, "panel laid out at %s" % size)
		check(panel.get_global_rect().end.x <= float(size.x) + 2 and panel.get_global_rect().end.y <= float(size.y) + 2, "panel contained at %s" % size)
		if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(capture_dir)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture_dir + "/monsterbook-%dx%d.png" % [size.x,size.y]) == OK, "actual OpenGL screenshot")
	var small_claim: Button = panel.find_child("MonsterBook_claim_16423", true, false)
	panel.stage_scroll.ensure_control_visible(small_claim)
	await process_frame
	await process_frame
	check(panel.stage_scroll.scroll_vertical > 0, "small screen exposes overflowing stage details by scrolling")
	check(panel.stage_scroll.get_global_rect().intersects(small_claim.get_global_rect()), "small screen reward control reachable")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_dir + "/monsterbook-960x540-rewards.png") == OK, "small-screen reward detail capture")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.monsterbook523.books['6013'].epochs['explicit-test-day'].counts['16423'] = -1
	check(Writer.write(path, malformed) == OK, "isolated malformed save setup")
	var bad_sha: String = FileAccess.get_sha256(path)
	world.gold = before_gold + 7
	world._load_game(true)
	check(world.monsterbook523_runtime.save_blocked and world.gold == before_gold + 7, "malformed MB fails before progression mutation")
	check(world._save_game(true) != OK and FileAccess.get_sha256(path) == bad_sha, "malformed original bytes cannot be overwritten")
	check(Writer.write(path, saved) == OK, "restore valid isolated save")
	world._load_game(true)
	check(not world.monsterbook523_runtime.save_blocked, "valid reload clears block")
	print("MONSTERBOOK523_MAIN_UI_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_CURRENT_MAP_UI_AND_CONFIRMED_ADAPTER; NO_NATIVE_CREDIT_OR_PAYOUT_CONVERSION_INVENTED"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
