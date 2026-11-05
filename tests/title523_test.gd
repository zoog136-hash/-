extends SceneTree
const Runtime=preload("res://scripts/titles/title_runtime523.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
var checks:=0
var failures: Array[String]=[]
var instant:=1793797200

class Host extends Node:
	var level:=85
	var inventory: Dictionary={}
	var loot_catalog: Dictionary={}
	var item_instances: Dictionary={}
	var locks: Dictionary={}
	var titles
	var writes:=0
	var reject:=false
	var deferred:=0
	func _item_locked(key: String) -> bool: return locks.get(key,false)
	func _update_hud() -> void: pass
	func _request_deferred_save() -> void: deferred+=1
	func _save_game(_quiet: bool, overrides: Dictionary={}) -> Error:
		if reject: return ERR_CANT_CREATE
		var payload: Dictionary={"inventory":inventory.duplicate(true),"title523":titles.state.duplicate(true),"legacy":{"opaque":"preserve"}}
		payload.merge(overrides,true)
		writes+=1
		return Writer.write("user://title523-unit-save.json",payload)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("TITLE523_FAIL ",label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var host:=Host.new(); root.add_child(host)
	var t=Runtime.new(); host.titles=t; t.configure(host); t.clock=func() -> int: return instant
	var path:=OS.get_environment("TWILIGHT_TITLE523_ZIP")
	check(t.source.load_zip(path).is_empty(),"verified real523 ZIP loads")
	if not t.source.problem.is_empty(): printerr(t.source.problem); host.free(); quit(1); return
	check(t.source.stages.size()==25 and t.source.quests.size()==128 and t.source.effects.size()==41,"25 stages128 trials41 effects")
	check(t.source.stages[12].id==278 and t.source.stages[20].id==412,"sequence jumps preserved")
	check(t.source.stages[0].probability_raw==1500000 and int(t.policy.donation_denominator)==10000000,"raw rate separate from estimated divisor")
	check(t.source.minimum_level==85 and t.source.daily_limit==10,"source activation constants")
	check(t.source.powder_drop_rows.size()==178 and t.source.powder_record.source_category_name=="StackableItem","entire powder source membership and actual category")
	for row: Dictionary in t.source.powder_drop_rows:
		var native: Dictionary=t.source.powder_npcs[int(row.NpcClassID)]
		check(not t.powder_drop(int(row.NpcClassID),native,0.0).is_empty(),"all178 exact source suppliers "+str(row.ID))
		var wrong:=native.duplicate(true); wrong.Sprite=int(wrong.Sprite)+1
		check(t.powder_drop(int(row.NpcClassID),wrong,0.0).is_empty(),"all178 sprite mismatch rejected "+str(row.ID))
		check(t.powder_drop(int(row.NpcClassID),native,1.0).is_empty(),"all178 rate failure grants nothing "+str(row.ID))
	var key: String="상급 축복의 가루 · 원본#117544"
	var powder: Dictionary=t.source.powder_record.duplicate(true)
	host.inventory={key:2000,"old":7}; host.loot_catalog={"by_name":{key:powder}}
	check(t.can_pickup({"item_name":key,"quantity":1}),"native max stack allows valid pickup")
	host.inventory[key]=9999999
	check(not t.can_pickup({"item_name":key,"quantity":1}),"source max stack preserves floor on overflow")
	host.inventory[key]=2000
	check(t.powder_count()==2000,"exact supplier contract")
	host.locks[key]=true; check(t.powder_count()==0,"locked stack refused"); host.locks.clear()
	for field: String in ["source_snapshot","sourceId","source_display_name","source_category_name","name"]:
		host.loot_catalog.by_name[key]=powder.duplicate(true); host.loot_catalog.by_name[key][field]="wrong"
		check(t.powder_count()==0,"wrong metadata "+field)
	host.loot_catalog.by_name[key]=powder
	host.inventory["상급 축복의 가루"]=99999
	check(t.powder_count()==2000,"same name legacy stack excluded")
	host.level=84; check(not t.review("donation",0).ok,"84 level rejected"); host.level=85
	check(t.review("donation",0).ok,"review no charge")
	check(host.inventory[key]==2000 and t.state.revision==0,"review is read only")
	var before:=JSON.stringify(t.state); var inventory_before:=JSON.stringify(host.inventory)
	host.reject=true
	check(not t.attempt("donation",0).ok,"writer failure rejects")
	check(JSON.stringify(t.state)==before and JSON.stringify(host.inventory)==inventory_before,"failed write keeps RNG inventory revision")
	host.reject=false
	# Force a deterministic successful draw using a reproducible fixture seed;
	# production uses persisted RNG and real configured odds.
	var rng:=RandomNumberGenerator.new()
	for seed_value: int in range(1,10000):
		rng.seed=seed_value
		var initial:=str(rng.state)
		if rng.randi_range(0,9999999)<1500000: t.state.rng=initial; break
	check(t.attempt("donation",0).ok,"actual donation commit")
	check(not host.inventory.has(key) and host.inventory.old==7 and host.inventory["상급 축복의 가루"]==99999,"consume exact stack preserve unrelated")
	check(t.state.achieved==[8] and t.state.attempts==0,"donation grants one stage no general count")
	check(t.bonus("ArmorClass")==-2 and t.bonus("MagicResist")==2,"first main and sub bonuses")
	check(not t.attempt("donation",0).ok,"duplicate stale confirmation rejected")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://title523-unit-save.json"))
	check(saved.legacy.opaque=="preserve" and not saved.inventory.has(key),"actual atomic file includes exact deduction")
	check(t.check_load(saved).is_empty(),"roundtrip validates")
	t.restore(saved); check(t.state.achieved==[8],"restore JSON number IDs")
	var current: Dictionary=t.next_stage(); var q: Dictionary=t.source.quests[current.quests[0]]
	check(t.start_trial(int(q.id),int(t.state.revision)).ok,"one explicit trial starts")
	check(not t.record_last_hit(int(q.targets[0]),"a",false),"participation is not last hit")
	check(not t.record_last_hit(-9,"a",true,t.source.trial_npcs[int(q.targets[0])]),"wrong native target rejected")
	check(t.record_last_hit(int(q.targets[0]),"a",true,t.source.trial_npcs[int(q.targets[0])]),"direct exact native last hit")
	check(not t.record_last_hit(int(q.targets[0]),"a",true,t.source.trial_npcs[int(q.targets[0])]),"duplicate event rejected")
	check(t.state.active.count==1 and host.deferred==1,"progress one time and deferred save")
	check(not t.review("quest",int(t.state.revision)).ok,"incomplete trial rejected")
	for i: int in range(1,int(q.amount)): t.record_last_hit(int(q.targets[0]),str(i),true,t.source.trial_npcs[int(q.targets[0])])
	check(t.review("quest",int(t.state.revision)).ok,"one chosen target grants eligibility")
	check(t.state.achieved==[8],"goal completion alone does not grant title")
	var revision:=int(t.state.revision)
	t.policy.quest_success_percent=0.0
	check(t.attempt("quest",revision).ok,"normal failed review saves")
	check(t.state.attempts==1 and t.state.active.is_empty() and t.state.achieved==[8],"failure spends only normal eligibility")
	check(not t.attempt("quest",revision).ok,"normal duplicate rejected")
	check(t.start_trial(int(q.id),int(t.state.revision)).ok,"trial may be repeated after failed review")
	instant+=86400
	check(not t.record_last_hit(int(q.targets[0]),"late",true,t.source.trial_npcs[int(q.targets[0])]),"exact deadline expired")
	check(not t.review("quest",int(t.state.revision)).ok,"expired review blocked")
	check(t.start_trial(int(q.id),int(t.state.revision)).ok,"expired trial can restart explicitly")
	var future:=instant
	instant-=1
	check(not t.review("donation",int(t.state.revision)).ok and not t.record_last_hit(int(q.targets[0]),"reverse",true,t.source.trial_npcs[int(q.targets[0])]),"clock reversal blocks spending progress")
	instant=future
	t.state.active.count=q.amount; t.state.day=t.day(instant); t.state.attempts=10
	check(not t.review("quest",int(t.state.revision)).ok,"normal ten per day cap")
	host.inventory[key]=2500
	check(t.review("donation",int(t.state.revision)).ok,"donation bypasses normal cap")
	instant+=86400; t.state.active.expires=instant+86400; t.state.active.started=instant; t.state.last_clock=instant
	check(t.review("quest",int(t.state.revision)).ok,"new own day resets only general cap")
	t.state=Runtime.fresh()
	for stage: Dictionary in t.source.stages: t.state.achieved.append(int(stage.id))
	check(t.validate(t.state).is_empty(),"entire source prefix validates")
	check(t.bonus("ArmorClass")==-2 and t.bonus("MagicResist")==6 and t.bonus("MeleeDamage")==2 and t.bonus("MeleeHit")==4,"all main effects once and sub effects accumulated")
	check(t.bonus("WeaponBlock")==25 and t.bonus("FinalBlowProbability")==3 and t.bonus("FinalBlowAdditionalScale")==5,"unsupported combat effects preserved unmodified")
	check(t.bonus("SpecialResistance")==5 and t.bonus("HitSpecialResistance")==5,"source percent denominator10000")
	check(t.incoming(100,"melee",0.0)==50 and t.incoming(100,"ranged",0.0)==50,"configured weapon block both physical channels")
	check(t.incoming(100,"magic",0.0)==100 and t.incoming(100,"melee",0.99)==100,"weapon block excludes magic and failed draw")
	check(t.outgoing(100,0.0)==205 and t.outgoing(100,0.99)==100,"own final blow base plus exact source5percent")
	check(t.pve_reduction()==3 and t.pve_pierce()==5,"explicit offline adaptation consumes both PvP types")
	t.policy.pvp_bonus_in_pve=false
	check(t.pve_reduction()==0 and t.pve_pierce()==0,"native-only policy preserves PvP values without NPC effect")
	t.policy.pvp_bonus_in_pve=true
	var bad: Dictionary=t.state.duplicate(true); bad.achieved[12]=128
	check(not t.validate(bad).is_empty(),"fabricated sequence rejected")
	bad=t.state.duplicate(true); bad.rng="9223372036854775808"
	check(not t.validate(bad).is_empty(),"overflow RNG rejected")
	bad=t.state.duplicate(true); bad.revision=true
	check(not t.validate(bad).is_empty(),"bool is not counter")
	t.source.problem="missing"
	check(not t.validate(t.state).is_empty(),"missing source preserves owned progress")
	check(t.validate(Runtime.fresh()).is_empty(),"legacy save without title remains valid")
	t.source.problem=""
	var costs: Array=[2000,2500,4000,4000,4500,5000,8000,8000,9000,10000,11000,16000,16000,18000,20000,22000,32000,32000,34000,36000,38000,51000,54000,57000,60000]
	t.state=Runtime.fresh(); host.inventory={key:1000000,"old":7}
	for i: int in t.source.stages.size():
		var stage: Dictionary=t.source.stages[i]
		check(int(stage.cost)==int(costs[i]),"all25 independent source costs "+str(stage.id))
		for seed_value: int in range(1,10000):
			rng.seed=seed_value
			var initial:=str(rng.state)
			if rng.randi_range(0,9999999)<int(stage.probability_raw): t.state.rng=initial; break
		var prior_count:=int(host.inventory[key])
		check(t.attempt("donation",int(t.state.revision)).ok and t.state.achieved.size()==i+1 and t.state.achieved[i]==int(stage.id) and prior_count-int(host.inventory[key])==int(costs[i]),"all25 actual atomic transitions "+str(stage.id))
	var maximum_totals: Dictionary=t.totals()
	for i: int in t.source.stages.size():
		var stage: Dictionary=t.source.stages[i]
		for quest_id: int in stage.quests:
			t.state=Runtime.fresh()
			for j: int in i: t.state.achieved.append(int(t.source.stages[j].id))
			var trial: Dictionary=t.source.quests[quest_id]
			check(t.start_trial(quest_id,0).ok,"all128 explicit targets start "+str(quest_id))
			var ordinal:=0
			for npc_id: int in trial.targets:
				check(t.record_last_hit(npc_id,"trial-%d-%d"%[quest_id,ordinal],true,t.source.trial_npcs[npc_id]),"all325 group links and57 direct goals count "+str(quest_id)+":"+str(npc_id))
				ordinal+=1
			t.state.active.count=int(trial.amount)-1
			check(t.record_last_hit(int(trial.targets[0]),"last-%d"%quest_id,true,t.source.trial_npcs[int(trial.targets[0])]) and t.state.active.count==int(trial.amount) and t.state.achieved.size()==i,"all128 quantity boundaries; no direct title reward "+str(quest_id))
	check(maximum_totals.size()==15,"all15 bonus types preserved")
	print("TITLE523_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	host.free(); quit(0 if failures.is_empty() else 1)
