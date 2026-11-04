extends SceneTree
const Growth = preload("res://scripts/growth/growth_runtime.gd")
var failures: Array[String] = []
var checks: int = 0

class Host extends Node:
	var rng:=RandomNumberGenerator.new()
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var hp: int = 1
	var mp: int = 1
	var reject_save: bool = false
	var persisted: Dictionary = {}
	func _save_game(_quiet: bool, overrides: Dictionary) -> Error:
		if reject_save: return ERR_CANT_CREATE
		persisted = JSON.parse_string(JSON.stringify(overrides))
		return OK
	func _invalidate_equipment_static() -> void: pass
	func _effective_max_hp() -> int: return 100000
	func _effective_max_mp() -> int: return 100000
	func _update_hud() -> void: pass

var host: Host
var rt

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("SYMBOL523_FAIL "+message)

func act(action: String, id: String = "", count: int = 1) -> Dictionary:
	return rt.execute(action,id,count,int(rt.state.revision))

func fixture(stage: int, attempts: int, spent: int = 0) -> Dictionary:
	return {"stage":stage,"attempts":attempts,"spent":spent,"guaranteed":false,"absolute":0}

func reset_state() -> void:
	rt.restore(Growth.fresh())
	rt.state.points = 10000000
	host.inventory.clear(); host.item_instances.clear()

func give(id: int, instance_id: String) -> void:
	var record: Dictionary = rt.source523.item_record(id)
	host.inventory[record.name] = int(host.inventory.get(record.name,0))+1
	host.item_instances[instance_id] = {"name":record.name,"level":0,"record":record}

func run() -> void:
	host = Host.new(); root.add_child(host)
	rt = Growth.new(); rt.configure(host)
	check(not rt.development and rt.config.get("source_snapshot")=="patch523","production uses523")
	check(rt.legacy_guardians.size()==6 and rt.legacy_guardians[0].nodes.size()==11,"legacy guardian catalogue preserved")
	var guardian_count: int = 0
	for group: Dictionary in rt.config.guardians: guardian_count += group.nodes.size()
	check(rt.config.guardians==rt.guardian_source.data.guardians and rt.config.guardians.size()==6 and guardian_count==172,"production guardian catalogue preserves all source523 slots")
	check(rt.source523.data.recharge.size()==103,"103 distinct recharge definitions")
	check(rt.source523.data.probabilities.size()==87,"87 probability rows")
	var expiry_found: bool = false
	for date: Dictionary in rt.source523.data.dates:
		if int(date.ID)==254042 and int(date.Year)==2027 and int(date.Month)==2 and int(date.Day)==24: expiry_found = true
	check(expiry_found and rt.source523.data.delete_time_application.Name=="DateTime","DeleteTime target-date FK retained independently fromValue0")
	for id: String in rt.source523.data.emblems:
		for cost: Dictionary in rt.source523.data.emblems[id].costs:
			check(int(rt.cost_for(id,int(cost.EnchantCount)))==int(cost.Cost),id+" exact cost "+str(cost.EnchantCount))
	check(rt.cost_for("eva",7)==2560,"source replaces historical3840 eighth-cost")
	check(rt.cost_for("shilen",0)==45,"Silen distinct family cost")
	check(rt.emblem("maphr").effects[1].get("max_hp:flat")==10,"source HP at firstMaphr stage")
	check(rt.emblem("paagrio").effects[30].get("magic_damage:flat",0)==0,"no invented magicDamage alias forSpellPower")
	check(rt.emblem("paagrio").effects[30].get("weight_bonus:flat")==150,"explicit weight adapter")
	reset_state()
	check(act("enhance","eva").ok and rt.progress("eva").spent==20,"first production enhancement unlocked")
	check(rt.state.economy.enhancement_spent==20,"enhancement ledger")
	var before: Dictionary = rt.state.duplicate(true)
	host.reject_save = true
	check(not act("enhance","eva").ok and rt.state==before,"failed enhancement save rolls back")
	host.reject_save = false
	var revision: int = int(rt.state.revision)
	check(act("reroll","eva").ok,"source reroll")
	check(not rt.execute("reroll","eva",1,revision).ok,"stale request rejects")
	check(rt.progress("eva").spent==20 and rt.state.economy.probability_spent==1,"reroll separate from enhancement refund")
	check(act("buy_key").ok and rt.state.economy.shop_spent==1000,"shop ledger separate")
	give(231772,"901")
	var previous_points: int = int(rt.state.points)
	check(act("reset","eva").ok,"permanent source scroll resets")
	check(rt.state.points==previous_points+20 and rt.state.economy.refunded==20,"refund excludes shop and reroll")
	check(not host.item_instances.has("901") and host.inventory[rt.source523.item_record(231772).name]==0,"reset consumes exact physical source scroll")
	check(host.inventory["축복의 열쇠"]==1,"reset cannot refund key purchase")
	reset_state()
	rt.state.emblems["eva"] = fixture(30,10,100)
	give(231772,"901")
	check(not act("reset","eva").ok,"stage30 reset forbidden")
	check(not act("enhance","eva").ok,"stage30 enhancement forbidden")
	rt.state.emblems["eva"] = fixture(20,20,100)
	check(not act("enhance","eva").ok,"attempt20 independent cap")
	reset_state()
	rt.rng.seed = 150
	rt.rerolls.eva = [0.0,0.0,100.0]
	check(act("enhance","eva",5).ok,"five action")
	var five: Dictionary = rt.progress("eva")
	reset_state()
	rt.rng.seed = 150
	check(act("enhance","eva",5).ok and rt.progress("eva")==five,"five ignores manual odds")
	for stage: int in [27,28]:
		var observed: Dictionary = {}
		for index: int in range(80):
			rt.state.emblems["eva"] = fixture(stage,10)
			check(act("reroll","eva").ok,"late stage reroll available")
			var odds: Array = rt.rerolls.eva
			if stage==27:
				check(float(odds[2])>=.4 and float(odds[2])<=.5,"narrow +3 bounds")
				observed[str(odds[2])] = true
			else:
				check(float(odds[1])>=.5 and float(odds[1])<=1.0 and float(odds[2])==0,"late +2 bounds and no+3")
				observed[str(odds[1])] = true
			check(is_equal_approx(float(odds[0])+float(odds[1])+float(odds[2]),100.0),"late odds sum")
		check(observed.size()==(2 if stage==27 else 6),"local sampler derives candidate count from bounds")
	reset_state()
	for index: int in range(80):
		rt.state.emblems["eva"] = fixture(27,10)
		rt.rerolls.eva = [0.0,0.0,100.0]
		check(act("enhance","eva").ok and not rt.progress("eva").guaranteed,"zero specialRoute is respected")
	reset_state()
	check(not act("absolute","sayha",1).ok,"absolute requires30")
	rt.state.emblems["sayha"] = fixture(30,10)
	host.inventory["축복의 열쇠"] = 100
	var payment: Dictionary = rt.source523.absolute("sayha",1).payment
	check(act("absolute","sayha",1).ok,"supported grade1 guaranteed action")
	check(host.inventory["축복의 열쇠"]==100-int(payment.ForceOpenCost),"exact source force cost")
	check(rt.progress("sayha").absolute_grades==[1],"independent explicit grade state")
	check(is_equal_approx(rt.bonus("experience_bonus:percent"),float(rt.emblem("sayha").effects[30]["experience_bonus:percent"])+5.0),"absolute effect reaches live stats")
	check(not act("absolute","sayha",1).ok,"duplicate absolute blocked")
	check(rt.source523.absolute_block("sayha",2).is_empty() and not act("absolute","sayha",2).ok,"known second grade still requires66 actual keys")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(rt.state))
	check(rt.validate(restored).is_empty(),"new state validates afterJSON")
	rt.restore(restored)
	check(not act("absolute","sayha",1).ok,"JSON grade normalization prevents duplicate")
	rt.state.emblems["eva"] = fixture(30,10)
	check(act("absolute","eva",1).ok and rt.bonus("magic_heal:percent")==10 and rt.bonus("potion_percent:percent")==20,"Eva magic heal is separate from potion effects")
	reset_state()
	rt.state.emblems["sayha"] = fixture(30,10)
	rt.rng.seed = 100
	var failure_seen: bool = false
	for index: int in range(50):
		var points_before: int = int(rt.state.points)
		var result: Dictionary = act("absolute_chance","sayha",1)
		check(result.ok and rt.state.points==points_before-int(payment.OpenCost),"chance attempt exact charge")
		if not rt.progress("sayha").get("absolute_grades",[]).has(1): failure_seen=true; break
		rt.state.emblems["sayha"] = fixture(30,10)
	check(failure_seen and rt.state.economy.absolute_spent>0,"failed chance persists cost withoutgrant")
	reset_state()
	check(not act("holy_water").ok,"name-only legacy stack not source-converted")
	give(117294,"902")
	var charge_record: Dictionary = host.item_instances["902"].record.duplicate(true)
	var untouched_points: int = int(rt.state.points)
	host.reject_save = true
	check(not act("recharge","902").ok and host.item_instances.has("902") and rt.state.points==untouched_points,"recharge rollback retains physical ID")
	host.reject_save = false
	check(act("recharge","902").ok and rt.state.points==untouched_points+100,"exact source recharge100")
	check(not host.item_instances.has("902") and host.inventory[charge_record.name]==0,"recharge consumes physical andcount together")
	check(not act("recharge","902").ok,"physical recharge duplicate rejected")
	var altered: Dictionary = charge_record.duplicate(true)
	altered.source_snapshot = "base508"
	check(rt.source523.recharge({"name":altered.name,"record":altered}).is_empty(),"snapshot identity not guessed")
	altered = charge_record.duplicate(true); altered.source_original_item.Weight = 999
	check(rt.source523.recharge({"name":altered.name,"record":altered}).is_empty(),"original item byte projection identity retained")
	altered = charge_record.duplicate(true); altered.source_item_class_id = 117294.5
	check(rt.source523.recharge({"name":altered.name,"record":altered}).is_empty(),"fractional source ID rejected")
	var expired: Dictionary = rt.source523.item_record(155593)
	check(rt.source523.recharge({"name":expired.name,"record":expired}).is_empty(),"expiry conditions not discarded")
	var pickup: Dictionary = rt.source523.prepare_pickup({"item_name":charge_record.name,"item_record":charge_record,"quantity":2},{},1)
	check(pickup.item_instances.size()==2 and pickup.next_item_instance_id==3,"real drop bridge preserves per-unit identity")
	var invalid: Dictionary = Growth.fresh(); invalid["economy"]={"shop_spent":-1}
	check(not rt.validate(invalid).is_empty(),"negative ledger rejected")
	var old_save: Dictionary = Growth.fresh(); old_save.emblems["eva"] = fixture(3,1,20)
	check(rt.validate(old_save).is_empty(),"old schema1 save preserved")
	var catalog: Dictionary = {"아이템":[]}; var loot: Dictionary = {"by_name":{}}
	rt.source523.install(catalog,loot)
	check(catalog["아이템"].size()>=5,"usable materials installed in real catalogue")
	print("SYMBOL523_TEST ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
