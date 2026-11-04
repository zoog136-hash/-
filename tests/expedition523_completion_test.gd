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
	check(world.expedition_local.claim(int(world.expedition_local.state.jobs[0].id),true).ok,"finish parallel timer fixture")
	# Optional source Adena buffs are purchased with departure in one transaction.
	world.gold = 300000; check(world._save_game(true)==OK,"buff fixture checkpoint")
	view._select_spot()
	for i in range(view.card_picker.item_count):
		if view.card_picker.get_item_metadata(i).identity == identity: view.card_picker.select(i)
	var hp_button := view.find_child("ExpeditionBuff_1",true,false) as CheckButton
	var potion_button := view.find_child("ExpeditionBuff_11",true,false) as CheckButton
	var luck_button := view.find_child("ExpeditionBuff_21",true,false) as CheckButton
	check(hp_button != null and potion_button != null and not luck_button.disabled,"UI source HP/potion/luck choices with separate local Diamond wallet")
	hp_button.button_pressed = true; potion_button.button_pressed = true; view._render()
	var prepared: Dictionary = world.expedition_local.prepare(1,[identity],[1,11])
	check(prepared.ok and prepared.cost==160000 and prepared.entry_cost==10000 and prepared.buffs.cost==150000,"source entry plus both exact native buff costs")
	check(not world.expedition_local.prepare(1,[identity],[1,1]).ok and not world.expedition_local.prepare(1,[identity],[21]).ok,"duplicate buff and unfunded local currency reject before payment")
	unchanged = snapshot(); disk = FileAccess.get_sha256(path)
	world.equipment_collections.save_blocked = true
	check(not world.request_expedition_start(1,[identity],[1,11]).ok and snapshot()==unchanged and FileAccess.get_sha256(path)==disk,"failed combined purchase preserves Gold buffs and RNG")
	world.equipment_collections.save_blocked = false
	view.start_button.pressed.emit(); confirm()
	check(world.gold==140000 and world.expedition_local.state.jobs[0].cost==10000 and world.expedition_local.state.jobs[0].sim.max_hp==630,"UI purchases buffs and preserves original entry fee for resurrection")
	await process_frame
	policy_only(71); world.expedition_local.state.jobs[0].sim.hp=400
	check(world._save_game(true)==OK,"potion progress baseline")
	unchanged=snapshot(); disk=FileAccess.get_sha256(path)
	world.equipment_collections.save_blocked=true
	world.expedition_local.advance(900)
	check(snapshot()==unchanged and FileAccess.get_sha256(path)==disk,"failed healing/event checkpoint preserves HP clock and RNG")
	world.equipment_collections.save_blocked=false
	world.expedition_local.advance(900)
	var healed: Dictionary=world.expedition_local.state.jobs[0].duplicate(true)
	check(healed.sim.hp==450 and healed.sim.next_potion==1800 and healed.sim.elapsed==900,"source50HP every900sec independently of event clock")
	var chunk_a:=healed.duplicate(true); var chunk_b:=healed.duplicate(true)
	Model.step(chunk_a,1800,catalog); Model.step(chunk_b,900,catalog); Model.step(chunk_b,900,catalog)
	check(chunk_a==chunk_b,"potion offline batch equals incremental saved RNG model")
	var invalid:Dictionary=world.expedition_local.export_state();invalid.jobs[0].sim.next_potion=900
	check(not world.expedition_local.validate(invalid).is_empty(),"invalid potion clock rejected")
	disk=FileAccess.get_sha256(path);world._load_game(true)
	check(FileAccess.get_sha256(path)==disk and world.expedition_local.state.jobs[0].sim.hp==450 and world.expedition_local.state.jobs[0].buff_ids.size()==2 and int(world.expedition_local.state.jobs[0].buff_ids[0])==1 and int(world.expedition_local.state.jobs[0].buff_ids[1])==11,"reload preserves paid buffs and healing clock without replay")
	view._refresh_jobs()
	if not capture.is_empty():
		(view.find_child("ExpeditionChoicesScroll",true,false) as ScrollContainer).ensure_control_visible(potion_button)
		await capture_state("buffs")
	# Four-card dispatch uses real source cards, source synergies and saved ownership.
	check(world.expedition_local.claim(int(world.expedition_local.state.jobs[0].id),true).ok,"finish buff fixture without refund")
	world.gold=1000000
	var party_ids:Array=[];var preferred:={};var hp_sum:=0
	for evidence:Dictionary in catalog.synergy_evidence():
		if int(evidence.synergy.ID)==34:
			for member:Dictionary in evidence.members:preferred[int(member.BuffCardID)]=true
	for card:Dictionary in world.catalog_db.get("변신",[]):
		if not preferred.has(int(card.get("source_card_id",0))) or card.get("source")!="lineagem_base508":continue
		var member_id:String=world.CARD_DRAW_FUSION.card_id(card)
		var spells:Array=world.skill_awakening.core.candidates(member_id)
		if spells.is_empty():continue
		world.card_draw_fusion.owned["변신"][member_id]=true
		world.skill_awakening.progress.cards[member_id]={"spell_id":int(spells[0].spell_id),"level":5,"experience":"0"}
		party_ids.append(member_id);hp_sum+=int(world.skill_awakening.core.profile(member_id,5).hp)
	check(party_ids.size()==4,"actual four-card native synergy roster present")
	if party_ids.size()!=4:finish(true);return
	check(world._save_game(true)==OK,"dispatch ownership checkpoint")
	view.spot_picker.select(view.spot_picker.get_item_index(274));view.spot_picker.item_selected.emit(view.spot_picker.selected)
	for i in range(view.card_picker.item_count):
		if view.card_picker.get_item_metadata(i).identity in party_ids:view.card_picker.select(i,false)
	view._render()
	var dispatch:Dictionary=world.expedition_local.prepare(274,party_ids)
	check(dispatch.ok and dispatch.inspection.party.synergy_ids.has(34) and not view.start_button.disabled,"actual UI source four-card eligibility and matched synergy")
	if not dispatch.ok or view.start_button.disabled:
		printerr("DISPATCH_PREPARE_DIAGNOSTIC ",dispatch.get("error","")," selected=",view.selected_identities())
		finish(true);return
	unchanged=snapshot();disk=FileAccess.get_sha256(path);world.equipment_collections.save_blocked=true
	check(not world.request_expedition_start(274,party_ids).ok and snapshot()==unchanged and FileAccess.get_sha256(path)==disk,"failed dispatch preserves four reservations cost and RNG")
	world.equipment_collections.save_blocked=false
	view.start_button.pressed.emit();confirm()
	check(world.gold==960000 and world.expedition_local.state.jobs[0].member_ids.size()==4 and world.expedition_local.state.jobs[0].sim.max_hp==hp_sum+2000,"UI starts source40000 dispatch with pooledHP and source2000 synergy")
	await process_frame
	check(party_ids.all(func(id:Variant)->bool:return world.expedition_local.reserved(str(id))) and not world.request_expedition_start(284,party_ids).ok,"all four members reserved across different source castles")
	var equip_before:String=JSON.stringify(world.equipped_catalog)
	for card:Dictionary in world.catalog_db.get("변신",[]):
		if world.CARD_DRAW_FUSION.card_id(card)==party_ids[0]:world._equip_catalog("변신",card)
	check(JSON.stringify(world.equipped_catalog)==equip_before,"dispatch member cannot become active transformation")
	job_id=int(world.expedition_local.state.jobs[0].id);policy_only(81);world.expedition_local.advance(540)
	check(int(world.expedition_local.state.jobs[0].sim.exp)==16800000,"native party experience event preserved")
	policy_only(71);world.expedition_local.advance(28260)
	check(world.expedition_local.state.jobs[0].status=="completed","four-card dispatch completes")
	view._refresh_jobs();await capture_state("dispatch")
	view.claim_button.pressed.emit();confirm()
	var split_ok:=true
	var exp_floor:int=int(world.skill_awakening.core.experiences["1:4"].CumExp)
	for id in party_ids:
		if int(world.skill_awakening.progress.cards[id].experience)!=exp_floor+4200000 or world.expedition_local.reserved(id):split_ok=false
	check(split_ok and not world.expedition_local.claim(job_id).ok,"party XP split once and all four reservations released")
	await process_frame
	check(world.request_expedition_start(274,party_ids).ok,"completed party can depart again")
	job_id=int(world.expedition_local.state.jobs[0].id);policy_only(101);world.expedition_local.state.jobs[0].sim.hp=1
	world.expedition_local.advance(540);var gold_before:int=world.gold
	check(world.expedition_local.state.jobs[0].status=="dead" and not world.expedition_local.resurrect(job_id).ok and world.gold==gold_before,"source50Diamond resurrection never substituted with Adena")
	unchanged=snapshot();disk=FileAccess.get_sha256(path);world.equipment_collections.save_blocked=true
	check(not world.expedition_local.exchange_diamonds(50).ok and snapshot()==unchanged and FileAccess.get_sha256(path)==disk,"failed local currency exchange preserves Gold and Diamond balance")
	world.equipment_collections.save_blocked=false
	view.diamond_amount.value=50;(view.find_child("ExpeditionExchangeDiamonds",true,false) as Button).pressed.emit();confirm()
	check(world.expedition_local.diamond_balance()==50 and world.gold==gold_before-500000,"UI local Diamond exchange uses explicit configurable TWILIGHT rate")
	await process_frame
	unchanged=snapshot();world.equipment_collections.save_blocked=true
	check(not world.expedition_local.resurrect(job_id).ok and snapshot()==unchanged,"failed native50Diamond resurrection preserves wallet and death")
	world.equipment_collections.save_blocked=false
	view._refresh_jobs();view.revive_button.pressed.emit();confirm()
	check(world.expedition_local.diamond_balance()==0 and world.gold==gold_before-500000 and world.expedition_local.state.jobs[0].status=="running","UI party revival consumes native50Diamond without another Adena debit")
	await process_frame
	check(world.expedition_local.claim(job_id,true).ok,"revived party independently supports abort recovery")
	view.diamond_amount.value=10;(view.find_child("ExpeditionExchangeDiamonds",true,false) as Button).pressed.emit();confirm()
	await process_frame
	view._select_spot()
	for i in range(view.card_picker.item_count):
		if view.card_picker.get_item_metadata(i).identity in party_ids:view.card_picker.select(i,false)
	var dispatch_luck:=view.find_child("ExpeditionBuff_84",true,false) as CheckButton
	dispatch_luck.button_pressed=true;view._render();view.start_button.pressed.emit();confirm()
	check(world.expedition_local.diamond_balance()==0 and world.expedition_local.state.jobs[0].sim.policy.event_interval_seconds==480,"UI native10Diamond luck reduces9min to8min")
	await process_frame
	view._refresh_jobs();await capture_state("luck")
	var bad_wallet:Dictionary=world.expedition_local.export_state();bad_wallet.local_diamonds=-1
	check(not world.expedition_local.validate(bad_wallet).is_empty(),"negative Diamond save rejected")
	# Native reward book adapter preserves existing fees/reroll rules and item locks.
	var requirement:Dictionary=world.skill_awakening.core.book_requirement(identity)
	var book_key:String=Model.key(int(requirement.item_class_id))
	world.expedition_local.state.storage[book_key]=1
	check(not world.expedition_local.compatible_skill_book(book_key).is_empty(),"latest source book item/effect/link exactly match existing awakening identity")
	check(world.expedition_local.withdraw(book_key).ok,"reward book withdraw creates typed inventory and canonical compatible physical instance")
	var book_name:String=world.expedition_local.state.issued[book_key]
	disk=FileAccess.get_sha256(path);world._load_game(true)
	check(FileAccess.get_sha256(path)==disk and int(world.inventory.get(book_name,0))==1,"source book physical compatibility survives byte-preserving reload")
	world.gold=maxi(int(world.gold),int(requirement.fee)+10000)
	check(world._save_game(true)==OK,"book fee baseline")
	unchanged=snapshot();disk=FileAccess.get_sha256(path);world.equipment_collections.save_blocked=true
	check(not world.skill_awakening.request_operation(identity).ok and snapshot()==unchanged and FileAccess.get_sha256(path)==disk,"failed existing awakening transaction preserves expedition book fee and RNG")
	world.equipment_collections.save_blocked=false
	var paid_before:int=world.gold
	world.hud.open_card_skill_awakening("마법인형",identity)
	var awakening_view:Control=world.hud.workspace.find_child("CardSkillAwakeningView",true,false)
	check(awakening_view!=null and not awakening_view.action.disabled,"existing actual skill awakening UI accepts the source reward book")
	if awakening_view!=null:awakening_view.action.pressed.emit()
	check(world.gold==paid_before-int(requirement.fee) and int(world.inventory.get(book_name,0))==0,"source reward book works through existing UI/API and unchanged user fee")
	check(not world.expedition_local.state.storage.has(book_key),"consumed reward book not regenerated from expedition storage")
	finish(true)

func finish(source: bool) -> void:
	print("EXPEDITION523_COMPLETION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_installed":source,"capture_requested":not capture.is_empty()}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
