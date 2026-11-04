extends SceneTree
## Run only with an isolated XDG profile and an installed private 523 pack.
const QA = preload("res://tests/qa_class_selection.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var world
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FISHING523_FAIL ", message)
func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame
func current() -> Control: return world.hud.workspace.find_child("Fishing523View", true, false)
func find_button(text_value: String) -> Button:
	for button: Node in current().find_children("*", "Button", true, false):
		if not button is OptionButton and str(button.text).begins_with(text_value): return button
	printerr("MISSING_BUTTON ", text_value, " tab=", current().tab)
	return null
func tap(control: Control) -> void:
	if control == null:
		check(false, "UI control exists")
		return
	var view: Control = current()
	if view != null and view.body.is_ancestor_of(control):
		(view.body.get_parent() as ScrollContainer).ensure_control_visible(control)
		await frames()
	var position: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2)
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 97
		event.position = position
		event.pressed = pressed
		root.push_input(event, true)
	await frames()
func accept() -> void: await tap(world.hud.find_child("ConfirmTransaction", true, false))
func cancel() -> void: await tap(world.hud.find_child("CancelTransaction", true, false))
func canonical(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))

func capture(filename: String) -> void:
	var directory: String = OS.get_environment("TWILIGHT_FISHING_EVIDENCE")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(filename + ".png")) == OK, "actual viewport capture " + filename)

func run() -> void:
	if OS.get_environment("TWILIGHT_FISHING523_PACK").is_empty() or OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty():
		printerr("Private source packs are required; this is not a passing skip.")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(QA.enter_game(world), "actual Main class confirmation")
	await frames()
	var rt = world.fishing523
	check(rt.rules.failure.is_empty(), "actual private 523 pack loads")
	world.level = 80 # Isolated test fixture, never a production grant.
	var chosen: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("아이템", []):
		if str(record.get("grade", "")) == "희귀" and str(record.get("slot", "")) == "weapon" and not str(record.name).contains("각인"):
			chosen = record
			break
	check(not chosen.is_empty(), "real host equipment exists")
	var before_ids: Dictionary = world.item_instances.duplicate(true)
	world._grant_playtest_catalog_variant(str(chosen.sourceId), 2)
	var ids: Array = []
	for id: String in world.item_instances:
		if not before_ids.has(id): ids.append(id)
	check(ids.size() == 2, "explicit test grant creates two distinct physical items")
	if ids.size() != 2:
		quit(1)
		return
	world.item_instances[ids[0]].level = 7
	world.item_instances[ids[1]].level = 9
	world.item_instances[ids[1]].locked = true
	check(world._save_game(true) == OK, "real initial atomic save")
	var preserved_quests: Variant = canonical(world.quest_service.export_state())
	check(not rt.equipment_reason(ids[0]).is_empty(), "Inven IDs are not treated as original ItemClassIDs")
	world.hud.toggle_menu()
	await frames()
	await tap(world.hud.workspace.find_child("MenuTile_fishing523", true, false))
	check(current() != null and world.hud.active_section == "fishing523", "normal Main menu opens fishing")
	await tap(find_button("장비 교환"))
	await tap(find_button("기존 TWILIGHT 장비 교환 허용"))
	await accept()
	check(rt.policy.host_equipment_exchange, "explicit host policy confirmation saved")
	check(rt.equipment_reason(ids[0]).is_empty(), "host physical gear becomes eligible only after opt-in")
	check(not rt.equipment_reason(ids[1]).is_empty(), "locked duplicate remains protected")
	var list: ItemList = current().equipment_list
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) == str(ids[0]): list.select(index)
	await capture("exchange-selection")
	var old_hash: String = FileAccess.get_sha256(world.save_path())
	await tap(find_button("선택한 실물 장비 교환"))
	await cancel()
	check(world.item_instances.has(ids[0]) and FileAccess.get_sha256(world.save_path()) == old_hash, "cancel preserves gear and save bytes")
	world.equipment_collections.test_save_writer = func(_path: String, _data: Dictionary) -> Error: return ERR_CANT_CREATE
	await tap(find_button("선택한 실물 장비 교환"))
	await accept()
	check(world.item_instances.has(ids[0]) and FileAccess.get_sha256(world.save_path()) == old_hash, "actual Main write failure rolls back cost and bytes")
	world.equipment_collections.test_save_writer = Callable()
	list = current().equipment_list
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) == str(ids[0]): list.select(index)
	await tap(find_button("선택한 실물 장비 교환"))
	await accept()
	check(not world.item_instances.has(ids[0]) and world.item_instances.has(ids[1]) and int(world.item_instances[ids[1]].level) == 9, "only selected physical ID is consumed")
	check(int(rt.state.items.get("303031", 0)) == 8, "guaranteed coin survives extra reward rolls")
	check(canonical(world.quest_service.export_state()) == preserved_quests, "existing quest state preserved")
	check(not rt.exchange([ids[0]], "repeat-consumed", int(rt.state.revision)).ok, "duplicate consumption rejected")
	await tap(find_button("낚시"))
	await tap(find_button("[낚시] 평범한 낚싯대"))
	await accept()
	check(int(rt.state.items.get("303021", 0)) == 50 and int(rt.state.items.get("303031", 0)) == 3, "normal purchase consumes five coins for fifty rods")
	await tap(find_button("자체 낚시 공간 입장"))
	check(paused and rt.active_territory == 1, "own fishing space pauses background world")
	await tap(find_button("낚싯대 1개로 시작"))
	await accept()
	check(int(rt.state.items.get("303021", 0)) == 49 and not rt.state.pending.is_empty(), "confirmed cast charges rod durably")
	# Accelerate elapsed waiting, then use the actual hook button and simulation.
	rt.session.tick(rt.session.wait_seconds + 0.1)
	await tap(find_button("입질 시 챔질"))
	check(rt.session.phase == "playing", "hook input enters original-parameter minigame")
	if rt.session.fish.is_empty():
		quit(1)
		return
	await capture("fishing-minigame")
	var fish_item: String = str(int(rt.session.fish.ItemClassID))
	for step: int in range(12000):
		rt.session.held = rt.session.cursor < rt.session.target
		rt.tick(0.016)
		if rt.session.phase == "idle": break
	check(int(rt.state.items.get(fish_item, 0)) == 1, "actual fish ID awarded after interactive success")
	check(rt.state.pending.is_empty(), "completed cast committed atomically")
	# Explicit private test fixture: exercise every exact card and bag route.
	# Production has no fixture grant or free-item button.
	var supplied: Dictionary = rt.state.duplicate(true)
	for item: String in rt.CARD_ITEMS: supplied.items[item] = 2
	var bags: Array = []
	for item: String in rt.rules.item_effects:
		if rt.has_bag(item):
			bags.append(item)
			supplied.items[item] = 1
	check(rt.commit(supplied).ok, "isolated card and bag fixture committed")
	await tap(find_button("낚시 보관함"))
	await capture("reward-bag")
	for item: String in rt.CARD_ITEMS:
		await tap(current().find_child("FishingCard_" + item, true, false))
		await accept()
		var card_identity: String = "source:m508:1:" + str(rt.CARD_ITEMS[item])
		check(bool(world.card_draw_fusion.export_state().owned["변신"].get(card_identity, false)), "exact source card is owned " + item)
		check(int(rt.state.items[item]) == 1, "card consumes exactly one item " + item)
		var token: String = rt.request_id()
		check(rt.use_card(item, token, int(rt.state.revision)).ok, "duplicate card becomes spare " + item)
		check(int(world.card_draw_fusion.export_state().spare["변신"].get(card_identity, 0)) >= 1, "spare identity preserved " + item)
		check(not rt.use_card(item, token, int(rt.state.revision)).ok, "same card request cannot repeat " + item)
	for item: String in bags:
		await tap(current().find_child("FishingBag_" + item, true, false))
		await accept()
		check(int(rt.state.items[item]) == 0, "source bag executes exactly once " + item)
	# Both contests and every original rank reward band use the actual writer.
	for contest: Dictionary in rt.rules.rows("FishContest"):
		var suitable: int = 1 if int(contest.ID) == 1 else 41
		check(rt.enter(suitable).ok, "contest territory entry")
		var cleared: Dictionary = rt.state.duplicate(true)
		cleared.contest = {}
		check(rt.commit(cleared).ok and rt.start_contest(int(contest.ID)).ok, "source contest starts")
		check(not rt.claim_contest().ok, "early contest claim rejected")
		for rank: Dictionary in rt.rules.rows("FishContestRank"):
			if int(rank.FishContestID) != int(contest.ID): continue
			var fixture: Dictionary = rt.state.duplicate(true)
			fixture.contest.claimed = false
			fixture.contest.ends_at = 0
			fixture.contest.score = 100
			fixture.contest.opponent_lengths = []
			for opponent: int in range(int(rank.RankRangeMin) - 1): fixture.contest.opponent_lengths.append(101)
			check(rt.commit(fixture).ok, "isolated rank fixture")
			var before_items: Dictionary = rt.state.items.duplicate(true)
			check(rt.claim_contest().ok, "actual rank claim " + str(rank.ID))
			for reward_link: Dictionary in rt.rules.rows("FishContestRankReward"):
				if int(reward_link.FishContestRankID) != int(rank.ID): continue
				var reward: Dictionary = rt.rules.row("Reward", int(reward_link.RewardID))
				var item: String = str(int(reward.RewardClassID))
				check(int(rt.state.items.get(item, 0)) - int(before_items.get(item, 0)) == int(reward.Amount), "exact rank reward " + str(reward.ID))
			check(not rt.claim_contest().ok, "contest cannot claim twice")
	world.hud._close_workspace()
	await frames()
	check(not paused and rt.active_territory == 0, "closing fishing restores world processing")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var expected: Variant = canonical(rt.state)
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.fishing523.items["303031"] = -1
	check(WRITER.write(world.save_path(), corrupt) == OK, "isolated corrupt-save fixture written")
	world._load_game(true)
	check(rt.blocked and canonical(rt.state) == expected, "corrupt fishing save refused before live mutation")
	check(world._save_game(true) != OK, "corrupt save cannot be overwritten by autosave")
	check(WRITER.write(world.save_path(), saved) == OK, "restore isolated baseline")
	world._load_game(true)
	check(not rt.blocked and canonical(rt.state) == expected, "valid reload restores fishing state")
	world.queue_free()
	await frames()
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	await frames()
	check(canonical(world.fishing523.state) == expected, "fresh Main instance reloads persisted ownership and receipts")
	check(canonical(world.quest_service.export_state()) == preserved_quests, "fresh Main keeps prior quest state")
	print("FISHING523_MAIN_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	world.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
