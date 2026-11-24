extends SceneTree
## User decision 2026-11-13: an original TJ coupon received into the bag (a
## receipted storage stack) is usable on the TJ screen. The screen counts its
## own coupon record plus the bag units of the same ItemClass, spends exactly
## one unit of one source per use (own record first, then the bag's physical
## debit in the same save) and never copies bag coupons into its record.
## Without the original definition ZIP nothing runs but the result line.
const Service = preload("res://scripts/tj/coupon_service.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
class HistoricalService extends Service:
	# A fixture clock inside a TJ season window; the OS clock is unchanged.
	var fixture_now: int = int(Time.get_unix_time_from_datetime_string("2026-09-10T00:00:00"))
	func clock() -> int:return fixture_now
class LateWorld extends TwilightWorld:
	# Missing-source startup correctly locks the general save. The optional
	# isolated fixture substitutes only the storage boundary, with the same
	# production atomic writer and exact source coupon/receipt checks.
	func save_path() -> String: return "user://tj-focused-qa-save.json"
	func _save_game(_quiet: bool, collection_override: Dictionary = {}, _movement_override: Dictionary = {}, validate_only: bool = false, _background: bool = false) -> Error:
		if validate_only: return OK
		var data: Dictionary = {"tj_coupons523":tj_coupons.core.export_state(),"card_draw_fusion":card_draw_fusion.export_state(),
			"inventory":inventory,"item_instances":item_instances,"consumable_state":consumable_service.export_state(),"gold":gold}
		data.merge(collection_override,true)
		return Writer.write(save_path(),data)
	func reload_fixture() -> bool:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
		if not data is Dictionary: return false
		inventory = data.inventory; item_instances = data.item_instances; gold = int(data.gold)
		consumable_service.import_state(data.consumable_state)
		card_draw_fusion.import_state(data.card_draw_fusion)
		return tj_coupons.core.import_state(data.tj_coupons523)
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var world: Node

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_TJ_BAG_COUPON_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func runtime(late_archive: String = "") -> void:
	world = load("res://Main.tscn").instantiate()
	if not late_archive.is_empty(): world.set_script(LateWorld)
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	if not late_archive.is_empty():
		# Low-memory QA only: Main boots without the full installation, then
		# reads the same pinned original rows for this exercise.
		OS.set_environment("TWILIGHT_PATCH523_CONTENT",late_archive)
		SOURCE.reset()
	world.inventory = {}; world.item_instances = {}
	if not check(world.tj_coupons.load_default_source(), "TJ screen reads the installed original archive: %s" % world.tj_coupons.source_problem): return
	var service = HistoricalService.new(); service.definitions = world.tj_coupons.core.definitions
	world.tj_coupons.core = service
	if not late_archive.is_empty():
		# Original unconditional merge candidates only; this mounted-Main
		# fixture verifies the transaction, not the broad installed catalog.
		var seen: Dictionary = {}
		var selected_cards: Array = []
		for raw: Dictionary in service.definitions.cards.values():
			var grade: int = int(raw.GradeID)
			if int(raw.BuffCardDeckID)!=1 or grade not in [3,4] or seen.has(grade) or raw.IsNoMergeOut or int(raw.ServerLimitSetID)!=0 or int(raw.StartDateTimeID)!=0 or int(raw.EndDateTimeID)!=0:continue
			var id: int = int(raw.ID)
			selected_cards.append({"name":raw.Name,"grade":{3:"희귀",4:"영웅"}[grade],"sourceId":"m523:1:"+str(id),"source_card_id":id,"source_original":{"deck_id":1,"grade_id":grade}})
			seen[grade] = true
		world.catalog_db["변신"] = selected_cards
		world.card_draw_fusion.configure(world.catalog_db)
		evidence["mounted_main_with_exact_selected_rows"] = true
	check(world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}), "explicit test server context")
	var context_result: Dictionary = world.tj_coupons.set_context("KR","1")
	check(context_result.ok, "TJ context saved: "+str(context_result))
	var origin: Dictionary = {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
	# This original regular transform-fusion coupon has a source season but
	# no DeleteTime. Use the existing explicit no-expiry test policy only on
	# this fixture and put its clock inside that exact server's source window.
	# A wall-clock-dependent expired coupon must never become the test fixture.
	service.settings.allow_unknown_expiry = true
	var item: String = "323211"
	var selection: Dictionary = service.resolve(item,world.tj_coupons.context(),service.clock())
	if not check(selection.ok and not selection.window.is_empty(), "pinned original undated coupon has an exact applicable server season"): return
	var stamp: String = str(service.date_value(int(selection.window.StartDateTimeID)))
	if not check(stamp.length() == 12, "original server season timestamp is decoded"): return
	service.fixture_now = int(Time.get_unix_time_from_datetime_string("%s-%s-%sT%s:%s:00" % [
		stamp.substr(0,4),stamp.substr(4,2),stamp.substr(6,2),stamp.substr(8,2),stamp.substr(10,2)])) - 9*3600 + 60
	if not late_archive.is_empty():
		var record: Dictionary = D.variant_item(D.definition_id(item).get("native_record",{}),1)
		if not check(not record.is_empty(),"exact projected coupon exists before isolated catalog registration"):return
		world.catalog_db["아이템"].append(record)
		world._index_catalog_item_sources()
	var can_stage: Dictionary = INVENTORY.stage(world,[{"item_class_id":int(item),"amount":1,"bless_raw":1,"enchant":0}],origin)
	if not can_stage.get("ok",false):
		evidence["stage_block"] = can_stage
		item = ""
	if not check(not item.is_empty(), "an original TJ coupon the bag can receive"): return
	evidence["coupon"] = item
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":int(item),"amount":2,"bless_raw":1,"enchant":0}],origin)
	check(staged.get("ok",false) and world._save_game(true,staged.overrides)==OK, "two coupons granted into the bag and saved")
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	check(int(service.state.coupons.get(item,0))==0 and world.tj_coupons.bag_count(item)==2 and world.tj_coupons.owned_count(item)==2, "the TJ screen counts the 2 bag coupons; its own record is not copied (0)")
	# One real failed transform fusion is the TJ history to retry.
	var identities: Array = world.card_draw_fusion.pools["변신"]["희귀"]
	if not check(identities.size()>0, "actual source material pool"): return
	var identity: String = str(identities[0].id)
	world.card_draw_fusion.owned["변신"][identity] = true
	world.card_draw_fusion.spare["변신"][identity] = 4
	world._invalidate_equipment_static()
	var probe := RandomNumberGenerator.new()
	for seed_value: int in range(1,1000):
		probe.seed = seed_value
		if probe.randi_range(0,9999)>=Cards.FUSION_WEIGHTS["희귀"]: world.card_draw_fusion.rng.seed = seed_value; break
	world._on_card_fusion_requested("변신","희귀",1)
	await process_frame
	if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()
	await process_frame
	if not check(service.state.history.size()==1, "a real failed fusion records one TJ event"): return
	var event: Dictionary = service.state.history[0]
	var policy: Dictionary = service.definitions.coupons[item].profile
	var good: Array = []; var bad: Array = []
	for pair: Array in [[event.success_candidates,good,1],[event.fail_candidates,bad,maxi(1,int(policy.ChoiceFailCardCount))]]:
		for id: String in pair[0]:
			var card: Dictionary = service.definitions.cards.get(id,{})
			if card.is_empty() or int(card.get("ServerLimitSetID",0))!=0 or int(card.get("StartDateTimeID",0))!=0 or int(card.get("EndDateTimeID",0))!=0: continue
			pair[1].append(id)
			if pair[1].size()>=int(pair[2]): break
	if not check(good.size()==1 and bad.size()==maxi(1,int(policy.ChoiceFailCardCount)), "eligible candidates"): return
	var stacks: Array = world.tj_coupons.bag_stacks(item)
	if not check(not stacks.is_empty(), "actual receipted selectable coupon stack exists"): return
	var selected_uid: String = str(stacks[0].uid)
	var name_value: String = str(world.item_instances[selected_uid].name)
	# A legacy menu-owned coupon of the same class must never substitute for
	# a stale bag selection or be consumed by the focused physical flow.
	service.state.coupons[item] = 1
	var durable: String = FileAccess.get_sha256(world.save_path())
	world._on_inventory_item_activated(name_value + "@@@" + selected_uid)
	check(world.hud.active_section == "tj_coupons" and FileAccess.get_sha256(world.save_path()) == durable
		and world.tj_coupons.bag_count(item,selected_uid) == 2, "actual inventory action opens focused existing chooser without spending")
	var stale: Dictionary = world.tj_coupons.redeem(item,str(event.id),int(service.state.revision),good,bad,"missing-fixture-uid")
	check(not stale.ok and service.state.coupons[item] == 1 and FileAccess.get_sha256(world.save_path()) == durable,
		"invalid selected physical UID never substitutes a matching stack or menu-owned coupon")
	var result: Dictionary = world.tj_coupons.redeem(item,str(event.id),int(service.state.revision),good,bad,selected_uid)
	evidence["redeem"] = {"ok":result.get("ok"),"error":result.get("error","")}
	check(result.get("ok",false), "redeem with a bag coupon: %s" % str(result.get("error","")))
	check(world.tj_coupons.bag_count(item)==1 and int(world.inventory.get(name_value,0))==1 and int(service.state.coupons.get(item,0))==1 and service.state.used.has(str(event.id)), "exactly one selected bag coupon spent; unrelated menu coupon and used-event guard stay intact")
	var again: Dictionary = world.tj_coupons.redeem(item,str(event.id),int(service.state.revision),good,bad,selected_uid)
	check(not again.get("ok",true) and world.tj_coupons.bag_count(item)==1, "the same event is not usable twice; the other coupon stays")
	if late_archive.is_empty(): world._load_game(true)
	else: check(world.reload_fixture(),"isolated atomic save can be reloaded")
	evidence["reload"] = {"bag":world.tj_coupons.bag_count(item),"own":int(service.state.coupons.get(item,0)),"receipts":service.state.receipts.size()}
	check(world.tj_coupons.bag_count(item)==1 and int(service.state.coupons.get(item,0))==1 and service.state.receipts.size()==1, "after reload: exact remaining bag coupon, separate menu coupon, one receipt")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")

func run() -> void:
	var late_archive: String = OS.get_environment("TWILIGHT_TJ_QA_LATE_DEFINITIONS")
	if not late_archive.is_empty() and OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("late source fixture requires an isolated XDG_DATA_HOME")
		quit(2);return
	if not late_archive.is_empty() or not SOURCE.not_installed():
		await runtime(late_archive)
		if is_instance_valid(world): world.queue_free(); await process_frame
	print("ITEMS523_TJ_BAG_COUPON_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
