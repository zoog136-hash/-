extends SceneTree
const Catalog = preload("res://scripts/expedition/source_catalog.gd")
const Model = preload("res://scripts/expedition/estimated_simulation.gd")
const Dispatch=preload("res://scripts/expedition/dispatch_rules.gd")
const Runtime = preload("res://scripts/expedition/local_runtime.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func job(seed: int, p: Dictionary, hp: int = 430) -> Dictionary:
	var result := {"id": 1, "duration": 28800, "remaining": 28800, "status": "running", "spot_id": 1, "group_id": 242}
	Model.initialize(result, hp, 5, seed, p, 2000000000)
	return result

func only(type: int) -> Dictionary:
	var p := Model.policy()
	for k in p.normal_event_weights: p.normal_event_weights[k] = 1 if int(k) == type else 0
	return p

func _initialize() -> void:
	check(Model.valid_policy(Model.policy()), "custom defaults valid")
	var bad := Model.policy(); bad.monster_win_permyriad = 10001
	check(not Model.valid_policy(bad), "invalid probability rejected")
	var runtime := Runtime.new()
	check(runtime.validate(Runtime.fresh_estimate()).is_empty(), "new namespace valid")
	check(runtime.validate(JSON.parse_string(JSON.stringify(Runtime.fresh_estimate()))).is_empty(), "new namespace JSON roundtrip")
	var rng := RandomNumberGenerator.new(); rng.seed = 122
	var heavy := 0
	for i in range(10000):
		if Model.choose([{"ID": 1,"w":1},{"ID":2,"w":3},{"ID":3,"w":0}], "w", rng).ID == 2: heavy += 1
	check(heavy > 7000 and heavy < 8000, "weighted selection preserves unequal masses")
	var path := ""; var sha := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--expedition523-pack="): path = a.trim_prefix("--expedition523-pack=")
		if a.begins_with("--expedition523-sha256="): sha = a.trim_prefix("--expedition523-sha256=")
	var catalog := Catalog.new()
	if not path.is_empty():
		check(catalog.install(path, sha), "actual source pack")
		if catalog.ready():
			var original: String = JSON.stringify(catalog.rows("MagicDollExpeditionSpotReward"))
			var a := job(344, Model.policy()); var b := a.duplicate(true)
			Model.step(a, 28800, catalog)
			for i in range(480): Model.step(b, 60, catalog)
			check(a == b, "offline batch equals small online steps with same saved RNG")
			var safe := job(1, only(71))
			Model.step(safe, 28800, catalog)
			check(safe.status == "completed" and safe.remaining == 0 and safe.sim.events == 53, "controlled survival completes source8hours")
			var dead := job(1, only(101), 1)
			Model.step(dead, 28800, catalog)
			check(dead.status == "dead" and dead.sim.elapsed == 540 and dead.remaining == 28260, "source fall damage stops at death event")
			var find := job(4, only(61)); Model.step(find, 540, catalog)
			check(find.sim.loot.size() == 1 and find.sim.events == 1, "source item reward keeps typed quantity")
			var exp := job(4, only(81)); Model.step(exp, 28800, catalog)
			check(int(exp.sim.exp) == 53*4200000, "source expedition experience amount preserved")
			var potion := job(11,only(101))
			potion.sim.elapsed=2160; potion.remaining=26640; potion.sim.next_event=2700
			potion.sim.hp=1; potion.sim.potion_heal=50; potion.sim.potion_interval=900; potion.sim.next_potion=2700
			var after := potion.duplicate(true); after.sim.policy.potion_tie_order="after_event"
			Model.step(potion,540,catalog); Model.step(after,540,catalog)
			check(potion.status=="running" and potion.sim.hp==31 and after.status=="dead" and after.sim.next_potion==3600,"configurable equal-time event/potion order and death clock")
			var expected_effects:Dictionary={4:{"luck_seconds":30},14:{"win_permyriad":100},24:{"heal":100},34:{"hp":2000},44:{"hp":1000},54:{"rest_hp_percent":5}}
			for evidence:Dictionary in catalog.synergy_evidence():
				var roster:Array=[]
				for member:Dictionary in evidence.members.slice(0,4):roster.append({"source_id":int(member.BuffCardID),"identity":"source:m508:1:"+str(int(member.BuffCardID)),"skill_awaken_level":5,"owned":true})
				var party:Dictionary=Dispatch.plan(catalog,roster,Model.policy())
				var synergy_id:int=int(evidence.synergy.ID)
				if synergy_id==64:
					check(not party.ok or not party.synergy_ids.has(64),"source restricted synergy never unlocked by estimates")
					continue
				var exact:bool=party.ok and party.synergy_ids.has(synergy_id)
				if exact:
					for field in expected_effects[synergy_id]:exact=exact and int(party.effects[field])==int(expected_effects[synergy_id][field])
				check(exact,"native source synergy effect "+str(synergy_id))
				if synergy_id==34:
					roster[0].skill_awaken_level=20
					var low:Dictionary=Dispatch.plan(catalog,roster,Model.policy())
					var higher:Dictionary=Model.policy();higher.dispatch_representative="highest_grade_then_level"
					var high:Dictionary=Dispatch.plan(catalog,roster,higher)
					check(int(low.representative.skill_awaken_level)==5 and int(high.representative.skill_awaken_level)==20,"mixed-party representative policy configurable without modifying source groups")
			var successes := 0
			for seed in range(100):
				var sample := job(seed+100, Model.policy()); Model.step(sample, 28800, catalog)
				if sample.status == "completed": successes += 1
			check(successes > 0 and successes < 100, "default estimates allow both survival and death")
			check(JSON.stringify(catalog.rows("MagicDollExpeditionSpotReward")) == original, "simulation never edits original weights")
			print("ESTIMATED_BALANCE_SAMPLE ", JSON.stringify({"seeds":100,"rare_level5_completions":successes,"estimated_not_official":true}))
	print("EXPEDITION523_ESTIMATE_MODEL_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"source_installed":catalog.ready()}))
	quit(0 if failures.is_empty() else 1)
