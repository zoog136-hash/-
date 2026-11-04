extends SceneTree
const Service=preload("res://scripts/tj/coupon_service.gd")
const Economy=preload("res://scripts/cards/native_option_economy.gd")
class HistoricalService extends Service:
	var sample_time: int=int(Time.get_unix_time_from_datetime_string("2026-09-08T00:00:00"))
	func clock() -> int:return sample_time
var world
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var isolated: String=OS.get_environment("TWILIGHT_TJ_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):push_error("isolated profile required");quit(1);return
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	await process_frame;await process_frame
	world.set_process(false);world.player.set_physics_process(false);world.hud.complete_class_selection()
	for monster: Node in world.monsters_root.get_children():monster.set_process(false);monster.set_physics_process(false)
	check(await world.tj_coupons.install_async(OS.get_cmdline_user_args()[0]),"verified523 source installed")
	var service=HistoricalService.new();service.definitions=world.tj_coupons.core.definitions;world.tj_coupons.core=service
	world.gold=987654321
	check(world.tj_coupons.set_context("KR","1").ok,"declared server saved")
	var rt=world.option_awakening
	var category: String="변신"
	var identity: String=""
	var row: Dictionary={}
	for id: String in rt.core.definitions[category]:
		var candidate: Dictionary=rt.core.definition(category,id)
		if int(candidate.native_source.card.GradeID)>=3 and world.tj_coupons.awakening_compatibility(candidate).is_empty() and rt.core.native_eligibility(category,id).ok and not Economy.rule(candidate).is_empty():identity=id;row=candidate;break
	check(not identity.is_empty(),"latest-compatible native awakening target")
	if identity.is_empty():finish();return
	world.card_draw_fusion.owned[category][identity]=true
	var rule: Dictionary=Economy.rule(row)
	var entry: Dictionary=rt.core.card_progress(rt.progress,category,identity).duplicate(true)
	Economy.assign(entry,rule,int(rule.required)*Economy.SCALE)
	rt.progress.cards[category][identity]=entry;rt.progress.revision=int(rt.progress.revision)+1
	var probe:=RandomNumberGenerator.new()
	for value: int in range(1,1000):
		probe.seed=value
		if probe.randi_range(0,9999)>=int(rt.core.probabilities[category][row.grade]):rt.rng.seed=value;break
	var result: Dictionary=rt.awaken(category,identity)
	check(result.ok and not result.success,"real native engine failed attempt")
	check(service.state.history.size()==1 and int(service.state.history[0].history_type)==41,"same atomic attempt records genuine awakening history")
	var wanted: int=int(rule.required)*Economy.SCALE-Economy.units(rt.core.card_progress(rt.progress,category,identity),rule)
	var material_id: String=""
	var quantity:=0
	for id: String in rt.core.catalog[category]:
		var record: Dictionary=rt.core.catalog[category][id]
		var spec: Dictionary=Economy.material(record,rule)
		if spec.is_empty() or not rt.core.native_material_available(record):continue
		material_id=id;quantity=int(ceil(float(wanted)/float(spec.experience)));break
	check(not material_id.is_empty() and quantity>0,"source-valid refill materials")
	world.card_draw_fusion.owned[category][material_id]=true
	world.card_draw_fusion.spare[category][material_id]=quantity
	result=rt.feed(category,identity,{material_id:quantity})
	check(result.ok,"actual existing engine feeding debits duplicates and gold")
	service.sample_time=int(Time.get_unix_time_from_datetime_string("2026-09-10T00:00:00"))
	var item: String=""
	for id: String in service.definitions.coupons:
		var profile: Dictionary=service.definitions.coupons[id].profile
		if int(profile.TJCouponHistoryType)!=41:continue
		var view: Dictionary=service.candidates(id,world.tj_coupons.context(),service.clock())
		if view.get("ok",false) and view.events.size()==1:item=id;break
	check(not item.is_empty(),"historical source awakening coupon matches actual failure window")
	if item.is_empty():finish();return
	check(world.tj_coupons.grant_for_test(item).ok,"explicit fixture coupon grant persists")
	var event: Dictionary=service.state.history[0]
	var prior_attempts: int=int(rt.core.card_progress(rt.progress,category,identity).attempts)
	var prior_gold: int=int(world.gold)
	var card_id: String=str(int(row.native_source.card.ID))
	result=world.tj_coupons.redeem(item,str(event.id),int(service.state.revision),[card_id],[card_id])
	if not result.ok:print("TJ523_AWAKENING_REJECT "+str(result.get("error","unknown")))
	check(result.ok,"Main TJ awakening transaction executes")
	check(int(world.gold)==prior_gold-int(rule.attempt_cost),"existing source attempt cost preserved")
	check(int(rt.core.card_progress(rt.progress,category,identity).attempts)==prior_attempts+1,"actual awakening progress changes")
	check(int(service.state.coupons[item])==0 and service.state.receipts.size()==1,"coupon debit and effect receipt commit together")
	var expected: bool=bool(rt.core.card_progress(rt.progress,category,identity).awakened)
	world._load_game(true)
	check(not service.blocked and int(service.state.coupons[item])==0,"Main reload preserves spent awakening coupon")
	check(bool(rt.core.card_progress(rt.progress,category,identity).awakened)==expected,"Main reload preserves actual awakening outcome")
	finish()
func finish() -> void:
	print("TJ523_AWAKENING_MAIN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"actual_Main":true,"operating_system_clock_changed":false}))
	world.queue_free();quit(0 if failures.is_empty() else 1)
