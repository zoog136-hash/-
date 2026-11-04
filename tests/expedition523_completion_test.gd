extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Runtime = preload("res://scripts/expedition/local_runtime.gd")
const Model = preload("res://scripts/expedition/estimated_simulation.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks := 0
var world: TwilightWorld
var view: Control
var test_now: int = 2000000000
var capture := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EXPEDITION_COMPLETION_FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func confirm() -> void:
	var modal := world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(modal != null and modal.is_visible_in_tree(), "actual transaction confirmation")
	if modal != null: (modal.find_child("ConfirmTransaction", true, false) as Button).pressed.emit()

func policy_only(type: int) -> void:
	# Controlled test fixtures; never change production configuration or source rows.
	for job: Dictionary in world.expedition_local.state.jobs:
		for k in job.sim.policy.normal_event_weights:
			job.sim.policy.normal_event_weights[k] = 1 if int(k) == type else 0

func snapshot() -> String:
	return JSON.stringify([world.gold, world.inventory, world.expedition_local.export_state(), world.skill_awakening.export_state(), world.expedition_local.random.state])

func capture_state(label: String) -> void:
	if capture.is_empty(): return
	view._refresh_jobs()
	for size in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		world.hud._fit_hud()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(view.claim_button.get_global_rect().end.y <= root.size.y and view.details.size.y > 40, "usable completion controls "+label+str(size))
		root.get_texture().get_image().save_png(capture+"-"+label+"-%dx%d.png" % [size.x,size.y])

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--expedition523-capture="): capture = arg.trim_prefix("--expedition523-capture=")
	world = (load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world)
	check(QA.enter_game(world), "actual Main class entry")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.save_timer = -100000.0
	world.expedition_local.clock = func() -> int: return test_now
	var catalog: RefCounted = world.get_expedition_catalog()
	if not catalog.ready():
		check(not world.request_expedition_start(1, []).ok, "missing pack blocks execution")
		finish(false)
		return
	var identity := ""
	for card: Dictionary in world.catalog_db.get("마법인형", []):
		var id := world.CARD_DRAW_FUSION.card_id(card)
		var spells: Array = world.skill_awakening.core.candidates(id)
		if card.get("source") == "lineagem_base508" and card.get("grade") == "희귀" and not spells.is_empty():
			identity = id
			world.card_draw_fusion.owned["마법인형"][id] = true
			world.skill_awakening.progress.cards[id] = {"spell_id":int(spells[0].spell_id),"level":5,"experience":"0"}
			break
	check(not identity.is_empty(), "real rare card fixture")
	world.gold = 300000
	check(world._save_game(true) == OK, "production baseline save")
	var path := world.save_path()
	world.hud.toggle_menu()
	(world.hud.workspace.find_child("MenuTile_expedition", true, false) as Button).pressed.emit()
	view = world.hud.workspace.find_child("ExpeditionSourceView", true, false) as Control
	check(view != null and view.is_visible_in_tree(), "actual expedition menu")
	(view.find_child("ExpeditionRules", true, false) as Button).pressed.emit()
	check(view.details.text.contains("TWILIGHT 추정") and view.details.text.contains("70.0"), "UI labels actual estimated rules")
	for i in range(view.card_picker.item_count):
		if view.card_picker.get_item_metadata(i).identity == identity:
			view.card_picker.select(i); view.card_picker.multi_selected.emit(i,true)
	view.start_button.pressed.emit(); confirm()
	check(world.gold == 290000 and world.expedition_local.state.jobs.size() == 1, "UI source cost and paid job")
	await process_frame
	var job_id := int(world.expedition_local.state.jobs[0].id)
	policy_only(71)
	world.expedition_local.advance(28800)
	check(world.expedition_local.state.jobs[0].status == "completed", "actual runtime survival completes")
	view._refresh_jobs()
	check(not view.claim_button.disabled and view.revive_button.disabled, "completion enables claim UI")
	await capture_state("completed")
	var unchanged := snapshot(); var disk := FileAccess.get_sha256(path)
	world.equipment_collections.save_blocked = true
	check(not world.expedition_local.claim(job_id).ok, "failed claim save rejected")
	check(snapshot() == unchanged and FileAccess.get_sha256(path) == disk, "failed claim preserves items receipts and disk")
	world.equipment_collections.save_blocked = false
	view.claim_button.pressed.emit(); confirm()
	check(world.expedition_local.state.jobs.is_empty() and world.expedition_local.state.receipts.has(str(job_id)), "UI claim releases card and saves receipt")
	check(int(world.expedition_local.state.storage.get("166594:1:0",0)) == 1, "original completion box received once")
	check(not world.expedition_local.claim(job_id).ok, "duplicate full claim rejected")
	await process_frame
	await capture_state("box")
	var revision := int(world.expedition_local.state.revision)
	unchanged = snapshot(); disk = FileAccess.get_sha256(path)
	world.equipment_collections.save_blocked = true
	check(not world.expedition_local.open_box("166594:1:0", revision).ok, "failed opening rejected")
	check(snapshot() == unchanged and FileAccess.get_sha256(path) == disk, "failed opening preserves box saved RNG and inventory")
	world.equipment_collections.save_blocked = false
	world.pending_map_save_record = {"pending_test":true}
	check(not world.expedition_local.open_box("166594:1:0", revision).ok and snapshot() == unchanged, "pending map activation blocks economic mutation")
	world.pending_map_save_record = {}
	view._refresh_storage(); view.open_button.pressed.emit(); confirm()
	check(not world.expedition_local.state.storage.has("166594:1:0") and world.expedition_local.state.storage.size() == 1, "UI consumes box and adds one weighted source row")
	await process_frame
	var reward_key: String = world.expedition_local.state.storage.keys()[0]
	var qty: int = int(world.expedition_local.state.storage[reward_key])
	var valid_row := false
	for row: Dictionary in catalog.completion_box_candidates(166594):
		if Model.key(int(row.ItemClassID),int(row.ItemBlessCodeID),int(row.ItemEnchant)) == reward_key and int(row.ItemAmount) == qty: valid_row = true
	check(valid_row, "opening outcome matches native candidate ID quantity bless enchant")
	check(not world.expedition_local.open_box("166594:1:0",revision).ok, "stale confirmation rejected")
	await capture_state("opened")
	view._refresh_storage(); view.withdraw_button.pressed.emit(); confirm()
	var issued_name: String = world.expedition_local.state.issued.get(reward_key, "")
	check(not issued_name.is_empty() and int(world.inventory.get(issued_name,0)) == qty and world.expedition_local.state.storage.is_empty(), "UI moves source reward into actual inventory")
	await process_frame
	disk = FileAccess.get_sha256(path)
	world._load_game(true)
	check(FileAccess.get_sha256(path) == disk and int(world.inventory.get(issued_name,0)) == qty, "reload keeps inventory and save bytes")
	var definitions := 0
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("sourceId") == "m523:expedition:"+reward_key: definitions += 1
	check(definitions == 1 and not world.expedition_local.claim(job_id).ok, "reload restores one source definition and no duplicate claim")
	# Source death damage and HP50% resurrection, with an explicit test fixture.
	check(world.request_expedition_start(1,[identity]).ok, "released card can depart again")
	job_id = int(world.expedition_local.state.jobs[0].id)
	policy_only(101); world.expedition_local.state.jobs[0].sim.hp = 1
	world.expedition_local.advance(540)
	check(world.expedition_local.state.jobs[0].status == "dead", "native fall bonus causes death")
	view._refresh_jobs()
	check(not view.revive_button.disabled and view.claim_button.disabled, "dead job exposes resurrection UI")
	await capture_state("dead")
	unchanged = snapshot(); disk = FileAccess.get_sha256(path)
	world.equipment_collections.save_blocked = true
	check(not world.expedition_local.resurrect(job_id).ok and snapshot() == unchanged and FileAccess.get_sha256(path) == disk, "failed resurrection keeps paid balance and death")
	world.equipment_collections.save_blocked = false
	view.revive_button.pressed.emit(); confirm()
	check(world.gold == 270000 and world.expedition_local.state.jobs[0].sim.hp == 215 and world.expedition_local.state.jobs[0].sim.resurrections == 1, "UI revive source HP50% with separately estimated entry-equivalent cost")
	await process_frame
	for revive in [2,3]:
		world.expedition_local.state.jobs[0].sim.hp = 1
		world.expedition_local.advance(540)
		check(world.expedition_local.resurrect(job_id).ok, "source resurrection allowance "+str(revive))
	world.expedition_local.state.jobs[0].sim.hp = 1
	world.expedition_local.advance(540)
	check(not world.expedition_local.resurrect(job_id).ok and world.gold == 250000, "source maximum3 revives cannot charge fourth")
	world.expedition_local.state.jobs[0].sim.loot = {"3252:1:0":5}
	world.expedition_local.state.jobs[0].sim.exp = "4200000"
	var spell: int = int(world.skill_awakening.progress.cards[identity].spell_id)
	view._refresh_jobs(); view.abort_button.pressed.emit(); confirm()
	check(world.expedition_local.state.jobs.is_empty() and int(world.expedition_local.state.storage.get("3252:1:0",0)) == 2 and not world.expedition_local.state.storage.has("166594:1:0"), "UI abort floors50% recovery without completion box")
	check(int(world.expedition_local.state.receipts[str(job_id)].exp) == 2100000 and int(world.skill_awakening.progress.cards[identity].experience) == 6309730526+2100000 and int(world.skill_awakening.progress.cards[identity].spell_id) == spell, "source experience thresholds applied with chosen spell preserved")
	check(not world.expedition_local.claim(job_id,true).ok, "duplicate abort recovery rejected")
	var growth: Dictionary = world.expedition_local._skill_reward(identity,3000000000)
	check(growth.state.cards[identity].level == 6 and growth.state.cards[identity].spell_id == spell and world.skill_awakening.progress.cards[identity].level == 5, "native cumulative thresholds level up staged reward without live mutation")
	await process_frame
	# Source daily15 cap and timezone policy; no reset on clock rollback.
	world.expedition_local.state.attempts["2"] = 15; world.expedition_local.state.day = world.expedition_local.today()
	check(not world.expedition_local.prepare(1,[identity]).ok, "daily15 blocks before payment")
	test_now += 86400
	check(world.request_expedition_start(1,[identity]).ok and world.expedition_local.state.attempts["2"] == 1, "forward daily reset allows source cost and resets counter")
	job_id = int(world.expedition_local.state.jobs[0].id); policy_only(71)
	var wall := test_now
	world.expedition_local.advance_to(wall+1080)
	check(world.expedition_local.state.jobs[0].remaining == 27720 and world.expedition_local.state.jobs[0].sim.events == 2, "offline elapsed replays two scheduled events")
	unchanged = snapshot()
	world.expedition_local.advance_to(wall+1080); world.expedition_local.advance_to(wall-100)
	check(snapshot() == unchanged, "repeated or backward wall clock cannot reroll or add progress")
	test_now -= 86400
	check(world.expedition_local.attempts_used("2") == 1, "backward date cannot reset attempts")
	# Corruption guard happens before unrelated player fields mutate.
	check(world._save_game(true) == OK, "checkpoint for corruption fixture")
	var good := FileAccess.get_file_as_bytes(path)
	var bad: Dictionary = JSON.parse_string(good.get_string_from_utf8())
	bad.expedition523_local.jobs[0].sim.hp = -1
	check(Writer.write(path,bad) == OK, "atomic corruption fixture")
	disk = FileAccess.get_sha256(path); world.gold = 123
	world._load_game(true)
	check(world.expedition_local.save_blocked and world.gold == 123 and world._save_game(true) != OK and FileAccess.get_sha256(path) == disk, "invalidHP protects source bytes and live player")
	var f := FileAccess.open(path,FileAccess.WRITE); f.store_buffer(good); f.close()
	world._load_game(true)
	check(not world.expedition_local.save_blocked and world.gold == 240000, "valid restore recovers paid state")
	# Migrate the previous paid pending format without a second departure charge.
	var old: Dictionary = JSON.parse_string(good.get_string_from_utf8())
	var legacy := Runtime.fresh(); legacy.revision = 1; legacy.attempts = {"2":1}
	legacy.jobs = [{"id":1,"spot_id":1,"group_id":242,"deck_id":2,"cost":10000,"identity":identity,"duration":28800,"remaining":0,"status":"awaiting_outcome","completion_reward_id":136194}]
	old.expedition523_local = legacy
	check(Writer.write(path,old) == OK, "legacy paid checkpoint fixture")
	disk = FileAccess.get_sha256(path)
	world._load_game(true)
	check(FileAccess.get_sha256(path) == disk and world.expedition_local.state.version == 2 and world.gold == 240000, "legacy migration accepts without rewrite or extra entry charge")
	world.expedition_local.tick(1.0)
	check(world.expedition_local.state.jobs[0].status in ["dead","completed"] and FileAccess.get_sha256(path+".pre-expedition-estimate-"+disk) == disk, "legacy elapsed replay and immutable SHA backup")
	job_id = int(world.expedition_local.state.jobs[0].id)
	var abort: bool = world.expedition_local.state.jobs[0].status == "dead"
	check(world.expedition_local.claim(job_id,abort).ok and not world.expedition_local.claim(job_id,abort).ok and world.gold == 240000, "legacy outcome settles once without charging paid entry")
	# Isolated source-box inventory fixture also exercises the real item-use handler.
	world.expedition_local.state.storage["166594:1:0"] = 1
	check(world.expedition_local.withdraw("166594:1:0").ok, "source completion box can move to inventory")
	var box_name: String = world.expedition_local.state.issued["166594:1:0"]
	unchanged = snapshot(); disk = FileAccess.get_sha256(path)
	world.equipment_collections.save_blocked = true
	world._on_inventory_item_activated(box_name)
	check(snapshot() == unchanged and FileAccess.get_sha256(path) == disk, "failed actual inventory-box use preserves quantity and RNG")
	world.equipment_collections.save_blocked = false
	var combat_rng: int = world.rng.state
	world._on_inventory_item_activated(box_name)
	check(not world.inventory.has(box_name) and world.rng.state == combat_rng, "actual inventory use consumes typed box with separate RNG")
	world._on_inventory_item_activated(box_name)
	check(not world.inventory.has(box_name), "used inventory box cannot be consumed twice")
	# Unrelated running-job timer checkpoints do not invalidate a storage modal.
	check(world.request_expedition_start(1,[identity]).ok, "parallel timer fixture starts")
	policy_only(71)
	world.expedition_local.state.storage["166594:1:0"] = 1
	view._refresh_storage()
	for index in range(view.storage_picker.item_count):
		if view.storage_picker.get_item_metadata(index) == "166594:1:0": view.storage_picker.select(index)
	view._refresh_storage_buttons(); view.open_button.pressed.emit()
	world.expedition_local.advance(1)
	confirm()
	check(not world.expedition_local.state.storage.has("166594:1:0"), "UI opening tolerates unrelated timer checkpoint")
	finish(true)

func finish(source: bool) -> void:
	print("EXPEDITION523_COMPLETION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_installed":source,"capture_requested":not capture.is_empty()}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
