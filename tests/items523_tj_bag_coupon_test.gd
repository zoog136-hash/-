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
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
class HistoricalService extends Service:
	# A fixture clock inside a TJ season window; the OS clock is unchanged.
	func clock() -> int:return int(Time.get_unix_time_from_datetime_string("2026-09-10T00:00:00"))
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var world: Node

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_TJ_BAG_COUPON_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func runtime() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	if not check(world.tj_coupons.load_default_source(), "TJ screen reads the installed original archive: %s" % world.tj_coupons.source_problem): return
	var service = HistoricalService.new(); service.definitions = world.tj_coupons.core.definitions
	world.tj_coupons.core = service
	check(world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}), "explicit test server context")
	check(world.tj_coupons.set_context("KR","1").ok, "TJ context saved")
	var origin: Dictionary = {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
	# A transform-fusion coupon in a season window that the bag can receive.
	var item: String = ""
	for id: String in service.definitions.coupons:
		var row: Dictionary = service.definitions.coupons[id]
		if int(row.profile.BuffCardDeckID)!=1 or int(row.profile.TJCouponHistoryType)!=1: continue
		var view: Dictionary = service.resolve(id,world.tj_coupons.context(),service.clock())
		if not view.get("ok",false) or view.window.is_empty() or service.date_value(int(view.window.StartDateTimeID))>service.wall(service.clock()) or service.date_value(int(view.window.EndDateTimeID))<=service.wall(service.clock()): continue
		if INVENTORY.stage(world,[{"item_class_id":int(id),"amount":1,"bless_raw":1,"enchant":0}],origin).get("ok",false): item = id; break
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
	var name_value: String = ""
	for uid: String in world.item_instances: name_value = str(world.item_instances[uid].get("name",""))
	var result: Dictionary = world.tj_coupons.redeem(item,str(event.id),int(service.state.revision),good,bad)
	evidence["redeem"] = {"ok":result.get("ok"),"error":result.get("error","")}
	check(result.get("ok",false), "redeem with a bag coupon: %s" % str(result.get("error","")))
	check(world.tj_coupons.bag_count(item)==1 and int(world.inventory.get(name_value,0))==1 and int(service.state.coupons.get(item,0))==0 and service.state.used.has(str(event.id)), "exactly one bag coupon spent; the TJ record stays 0; the event is used")
	var again: Dictionary = world.tj_coupons.redeem(item,str(event.id),int(service.state.revision),good,bad)
	check(not again.get("ok",true) and world.tj_coupons.bag_count(item)==1, "the same event is not usable twice; the other coupon stays")
	world._load_game(true)
	evidence["reload"] = {"bag":world.tj_coupons.bag_count(item),"own":int(service.state.coupons.get(item,0)),"receipts":service.state.receipts.size()}
	check(world.tj_coupons.bag_count(item)==1 and int(service.state.coupons.get(item,0))==0 and service.state.receipts.size()==1, "after reload: 1 bag coupon, TJ record 0, one receipt")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")

func run() -> void:
	if not SOURCE.not_installed():
		await runtime()
		if is_instance_valid(world): world.queue_free(); await process_frame
	print("ITEMS523_TJ_BAG_COUPON_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
