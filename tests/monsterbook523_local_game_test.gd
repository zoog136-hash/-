extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Book = preload("res://scripts/monsterbook/monsterbook523.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node
var active_unix: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("MONSTERBOOK_LOCAL_FAIL ",label)

func _initialize() -> void:
	call_deferred("run")

func fail_save(_path: String, _data: Dictionary) -> Error:
	return ERR_CANT_CREATE

func spawn(npc_id: int) -> Node:
	var actor: Node = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(actor)
	actor.setup({"name":"source-monsterbook-test","source_m_npc_id":npc_id,"hp":1,"xp":0,"gold":0,"drop":[],"lv":1},world.player,world,null)
	actor.global_position = world.player.global_position + Vector2(40,0)
	actor.set_physics_process(false)
	actor.died.connect(world._on_monster_died)
	return actor

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var press := InputEventScreenTouch.new()
	press.index = 6
	press.position = point
	press.pressed = true
	root.push_input(press,true)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 6
	release.position = point
	release.pressed = false
	root.push_input(release,true)
	await process_frame

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"real Main entry")
	var runtime: RefCounted = world.monsterbook523_runtime
	# Retain the original manual policy as a supported regression setting.
	runtime.economy.settings.natural_counter_mode = "manual"
	runtime.economy.settings.bonus_mode = "manual"
	check(runtime.catalog.loaded(),"actual v2 source pack")
	if not runtime.catalog.loaded(): world.queue_free();quit(1);return
	# Regression of the source-date mode; local season rotation is covered by monsterbook523_rotation_test.
	runtime.catalog.rotate_ended_seasons = false
	check(runtime.local.window_problem(6013) == "도감 기간 종료","current system clock does not resurrect source season22")
	active_unix = int(Time.get_unix_time_from_datetime_dict({"year":2026,"month":10,"day":19,"hour":20,"minute":30,"second":0}))
	runtime.local.unix_clock = func() -> int: return active_unix
	check(runtime.local.source_clock() == "202610200530","reuse Korean playtest calendar")
	check(runtime.local.window_problem(6013).is_empty(),"source counting window active in isolated clock fixture")
	var epoch: String = runtime.local.epoch(6013)
	var seed: Dictionary = runtime.catalog.export_state()
	seed.books['6013'] = {"sequence":1,"current_epoch":epoch,"epochs":{epoch:{"counts":{"16423":999},"kill_count":999,"registered":[],"claimed":[],"effective_levels":[]}}}
	check(runtime.catalog.import_state(seed) and world._save_game(true) == OK,"existing count999 durably loaded")
	var actor := spawn(6681)
	actor.take_damage(int(actor.hp) + 1)
	var progress: Dictionary = runtime.catalog.progress(6013)
	check(int(progress.counts['16423']) == 1000 and int(progress.kill_count) == 1000,"actual take_damage death automatically credits exact NPC")
	check(progress.registered.has(16423),"1000th kill automatically records first stage without Gem")
	check(progress.claimed.is_empty(),"death never directly puts book reward items into bag")
	world._on_monster_died(actor)
	runtime.on_death(actor)
	check(int(runtime.catalog.progress(6013).kill_count) == 1000,"duplicate actual death and adapter replay count once")
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var expected_progress: Dictionary = runtime.economy.experience_state(runtime.economy.experience_amount(runtime.catalog.row("Reward",434143)))
	var gold_before: int = world.gold
	check(world.monsterbook_action_status("claim",6013,16423).is_empty(),"original item and explicitly configured EXP can be claimed")
	world.hud.open_monsterbook523()
	var panel: Control = world.hud.find_child("MonsterBook523Panel",true,false)
	panel.search.text = "특수 던전 토벌자"
	panel.search.text_changed.emit(panel.search.text)
	var claim: Button = panel.find_child("MonsterBook_claim_16423",true,false)
	check(claim != null and not claim.disabled,"real UI claim enabled by default adapter")
	world.equipment_collections.test_save_writer = Callable(self,"fail_save")
	var rejected: Dictionary = world.request_monsterbook_action("claim",6013,16423)
	check(not rejected.ok and world.inventory == inventory_before and runtime.catalog.progress(6013).get("reward_claims",[]).is_empty(),"failed claim save preserves inventory and reward ownership")
	world.equipment_collections.test_save_writer = Callable()
	for frame: int in range(3): await process_frame
	panel.stage_scroll.ensure_control_visible(claim)
	for frame: int in range(3): await process_frame
	if DisplayServer.get_name() == "headless": claim.pressed.emit()
	else: await tap(claim)
	check(panel.result.text.contains("보상 수령 완료"),"default UI displays actual full payout")
	check(runtime.catalog.reward_claimed(6013,16423,434153) and runtime.catalog.reward_claimed(6013,16423,434143),"coin and configured EXP both paid once")
	var coin: Dictionary = runtime.items.definition(runtime.catalog.row("Reward",434153))
	check(int(world.inventory.get(coin.name,0)) == 1500,"source-qualified honor coin stock actually in existing inventory")
	check(world.gold == gold_before and runtime.catalog.progress(6013).get("reward_conversions",{}).get("434143",{}).get("provenance","") == "twilight_custom_holy_water_ratio_v1","original raw EXP retained with distinct custom settlement provenance")
	check(runtime.catalog.progress(6013).claimed.has(16423),"full item and EXP payout marks exactly its stage paid")
	var replay: Dictionary = world.request_monsterbook_action("claim",6013,16423)
	check(not replay.ok and int(world.inventory[coin.name]) == 1500,"full reward replay blocked")
	check(int(world.level) == int(expected_progress.level) and int(world.experience) == int(expected_progress.experience) and int(world.attack_power) == int(expected_progress.attack_power),"EXP gain uses existing curve, level gains and attack fields")
	var saved_state: Dictionary = runtime.catalog.export_state()
	var path: String = world.save_path()
	var sha: String = FileAccess.get_sha256(path)
	world._load_game(true)
	check(runtime.catalog.export_state() == saved_state and int(world.inventory[coin.name]) == 1500 and FileAccess.get_sha256(path) == sha,"real reload preserves source item definition, quantity and full reward receipt")
	check(int(world.level) == int(expected_progress.level) and int(world.experience) == int(expected_progress.experience) and int(world.attack_power) == int(expected_progress.attack_power),"real reload restores exact settled level and attack fields")
	check(world._find_catalog_item_record(coin.name).get("sourceId") == coin.sourceId,"source definition restored in normal item lookup")
	world._warehouse_transfer(coin.name,1,"deposit","")
	check(int(world.inventory[coin.name]) == 1500 and int(world.warehouse.stacks.get(coin.name,0)) == 0,"original non-storable restriction preserved")
	# An actual later life remains countable; a rejected save retries without double credit.
	var next_actor := spawn(6681)
	world.equipment_collections.test_save_writer = Callable(self,"fail_save")
	next_actor.take_damage(int(next_actor.hp)+1)
	check(int(runtime.catalog.progress(6013).kill_count) == 1000 and runtime.pending_deaths.size() == 1,"failed automatic count remains queued, not falsely published")
	world.equipment_collections.test_save_writer = Callable()
	runtime.retry_pending(true)
	check(int(runtime.catalog.progress(6013).kill_count) == 1001 and runtime.pending_deaths.is_empty(),"queued real death durably retries once")
	var prior_epoch: String = runtime.local.epoch(6013)
	active_unix += 86400
	var fresh_actor := spawn(6681)
	fresh_actor.take_damage(int(fresh_actor.hp)+1)
	var after: Dictionary = runtime.catalog.export_state()
	check(runtime.local.epoch(6013) != prior_epoch and int(runtime.catalog.progress(6013).kill_count) == 1 and int(runtime.catalog.progress(6013).counts.get("16423",0)) == 1,"next Korean day starts a new count only on an actual eligible death")
	check(after.books['6013'].epochs[prior_epoch].get("reward_claims",[]).has(434153) and int(world.inventory[coin.name]) == 1500,"daily rollover preserves previous receipts and owned coin")
	active_unix -= 86400
	check(not runtime.local.window_problem(6013).is_empty(),"clock rollback cannot reopen prior daily reward")
	# A different current book has a real first-stage target/threshold. Later-stage
	# arithmetic stays unresolved while its raw total and first-stage count work.
	active_unix += 86400
	var other: Node = spawn(104938)
	other.take_damage(int(other.hp)+1)
	check(int(runtime.catalog.progress(5903).get("kill_count",0)) == 1,"new523 hotspot death feeds its own book automatically")
	var levels: Array = runtime.catalog.levels(5903)
	check(int(runtime.catalog.progress(5903).counts.get(str(int(levels[0].ID)),0)) == 1,"multi-stage book first-stage count works")
	check(world.monsterbook_action_status("register",5903,int(levels[1].ID)).contains("후속 단계"),"only ambiguous later-stage arithmetic remains blocked")
	var first_id: int = int(levels[0].ID)
	var second_id: int = int(levels[1].ID)
	check(not world.request_monsterbook_action("instant",5903,first_id).ok,"instant completion requires a funded internal Gem wallet")
	var exchange_gold: int = world.gold
	world.equipment_collections.test_save_writer = Callable(self,"fail_save")
	check(not runtime.economy.exchange(10).ok and runtime.economy.gems() == 0 and world.gold == exchange_gold,"exchange save failure preserves both currencies")
	world.equipment_collections.test_save_writer = Callable()
	panel.search.text = str(runtime.catalog.row("MonsterBook",5903).Name)
	panel.search.text_changed.emit(panel.search.text)
	for frame: int in range(3): await process_frame
	var exchange_button: Button = panel.find_child("MonsterBookExchange",true,false)
	panel.stage_scroll.ensure_control_visible(exchange_button)
	for frame: int in range(3): await process_frame
	if DisplayServer.get_name() == "headless": exchange_button.pressed.emit()
	else: await tap(exchange_button)
	check(runtime.economy.gems() == 10 and world.gold == exchange_gold - 10*int(runtime.economy.BALANCE.data.adena_per_internal_gem),"actual exchange UI touch publishes both currencies")
	check(runtime.economy.exchange(9990).ok,"internal Gem acquisition uses explicit configurable fallback")
	var gems_before: int = runtime.economy.gems()
	var count_before: int = int(runtime.catalog.progress(5903).kill_count)
	world.equipment_collections.test_save_writer = Callable(self,"fail_save")
	check(not world.request_monsterbook_action("instant",5903,first_id).ok and runtime.economy.gems() == gems_before and not runtime.catalog.progress(5903).registered.has(first_id),"instant save failure cannot charge or complete stage")
	world.equipment_collections.test_save_writer = Callable()
	panel.show_selected()
	for frame: int in range(3): await process_frame
	var instant_button: Button = panel.find_child("MonsterBook_instant_"+str(first_id),true,false)
	panel.stage_scroll.ensure_control_visible(instant_button)
	for frame: int in range(3): await process_frame
	if DisplayServer.get_name() == "headless": instant_button.pressed.emit()
	else: await tap(instant_button)
	check(runtime.catalog.progress(5903).registered.has(first_id) and runtime.economy.gems() == gems_before-int(levels[0].CurrencyCost),"actual instant UI touch consumes exact source Gem cost")
	var capture_dir: String = OS.get_environment("MONSTERBOOK523_CAPTURES")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		for frame: int in range(3): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_dir+"/monsterbook-default-paid-completion.png") == OK,"actual default gameplay UI capture")
	check(world.request_monsterbook_action("instant",5903,second_id).ok and int(runtime.catalog.progress(5903).kill_count) == count_before,"instant stage2 works without inventing kill carry/reset arithmetic")
	check(not world.request_monsterbook_action("instant",5903,second_id).ok,"instant stage cannot be purchased twice")
	var wallet_state: Dictionary = runtime.catalog.export_state()
	world._load_game(true)
	check(runtime.catalog.export_state() == wallet_state,"internal wallet, exact stage completions and spend ledger survive real reload")
	# Every source-priced current stage has a working paid completion path.
	# Fixture funds are isolated; no player gold or live event dates change.
	world.gold = 2000000000
	for batch: int in range(10): check(runtime.economy.exchange(10000).ok,"fixture funds use the same internal exchange transaction")
	var completed: int = 0
	for book: Dictionary in runtime.catalog.books():
		for stage: Dictionary in runtime.catalog.levels(int(book.ID)):
			if int(stage.CurrencyCost) <= 0: continue
			var id: int = int(stage.ID)
			if not runtime.catalog.progress(int(book.ID)).get("registered",[]).has(id): check(world.request_monsterbook_action("instant",int(book.ID),id).ok,"source-priced stage can actually complete")
			completed += 1
	check(completed == 96,"all 96 source-priced stages covered, daily remains free")
	# Explicit player selection applies one owned stage; no native stacking claim.
	for wanted: String in ["ArmorClass","CarryPlus","ExperienceAdditionPercent","MoveSpeedBonus","MeleeCritical"]:
		var chosen_book: int = 0
		var chosen_stage: int = 0
		for book: Dictionary in runtime.catalog.books():
			for stage: Dictionary in runtime.catalog.levels(int(book.ID)):
				if int(stage.Level) != 2: continue
				for bonus: Dictionary in stage.bonuses:
					if runtime.catalog.row("BonusType",int(bonus.BonusTypeID)).get("Name") == wanted:
						chosen_book = int(book.ID)
						chosen_stage = int(stage.ID)
		check(chosen_book > 0 and world.request_monsterbook_action("effects",chosen_book,chosen_stage).ok,"owned stage explicit selection reaches real world")
	var extras: Dictionary = runtime.extra_stats()
	check(extras.get("def") == 1 and extras.get("weightBonus") == 100 and extras.get("xpPct") == 2 and extras.get("moveSpeedPct") == 2 and extras.get("meleeCrit") == 1,"exact source UIUnit denominators drive flat, Weight, Percentage and ValuePercent stats")
	check(world._experience_multiplier() >= 1.02 and world._effective_attack_speed_bonus_percent() >= 0,"selected EXP modifier reaches existing actual consumer")
	var owned: Dictionary = runtime.catalog.export_state()
	active_unix = int(Time.get_unix_time_from_datetime_dict({"year":2026,"month":11,"day":3,"hour":20,"minute":0,"second":0}))
	runtime.tick()
	check(runtime.extra_stats().is_empty() and runtime.catalog.export_state() == owned,"source option deadline hides combat effects while preserving ownership")
	world.hud._close_workspace()
	world._open_inventory()
	check(world.hud.lineage_inventory_ui.catalog_data["아이템"].any(func(r: Variant) -> bool: return r is Dictionary and r.get("sourceId") == coin.sourceId),"existing inventory UI receives exact source item definition")
	print("MONSTERBOOK523_LOCAL_GAME_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MONSTER_DEATH_MANUAL_COMPAT_REGRESSION_UI_ECONOMY_AND_SAVE"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
