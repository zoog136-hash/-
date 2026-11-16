extends SceneTree
## 에스카로스·요정 숲 남은 규칙 — TWILIGHT 근사(근거 약함) 2026-11-17
## (docs/escaros_elfforest_territory523_missing_rules.md 2-2/3/8):
## - rounds: the hot open time's 30 minutes hold rounds 1..5 (6 minutes each), repeated;
##   only the current round's artifact takes a touchdown;
## - rank reward: the local record is rank 1; after a touchdown in a week the artifact's
##   EscarosArtifactRankReward is claimable once that week;
## - 요정 숲 승리 보상: weekly, Wednesday 05:00 KST; grades still open by total wins.
## With the original ZIP, in actual Main. Without it: a pre-approximation save still loads.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CONTENT = preload("res://scripts/content523/content523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CONTENT523_APPROX_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func old_save() -> Dictionary:
	return {"schema":1,"escaros":{"period":-1,"found":[],"touchdowns":{"4":2},"buffs":{}},"elf":{"blessing":0,"entries":1,"wins":2,"run":{},"claimed":[1]},"tq":{"active":{},"done":{},"failed":{}}}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var service = world.content523
	var model: Dictionary = CONTENT.models().escaros
	evidence["model"] = {"hot_minutes":model.dungeon.get("hot_duration_minutes"),"rank_rewards":model.get("rank_reward_by_artifact",{}).keys(),"first":model.constants.get("StartRoundNo"),"last":model.constants.get("EndRoundNo")}
	check(int(model.dungeon.get("hot_duration_minutes",0)) == 30 and model.get("rank_reward_by_artifact",{}).size() == 5, "hot open time 30 min, 5 artifact rank rewards "+str(evidence.model))
	# Rounds: 1800000000 is minute 30000000 = 0 mod 30.
	var base: int = 1800000000 - posmod(int(1800000000/60), 30)*60
	var rounds: Array = []
	for minute: int in [0, 5, 6, 12, 18, 24, 29, 30]: rounds.append(service.current_round(base + minute*60))
	evidence["rounds"] = rounds
	check(rounds == [1,1,2,3,4,5,5,1], "6-minute rounds 1..5 repeat every 30 minutes "+str(rounds))
	service.import_state({})
	service.now_override = base + 60 # round 1
	var first: Dictionary = {}; var second: Dictionary = {}
	for artifact: Dictionary in model.artifacts:
		if int(artifact.round) == 1: first = artifact
		if int(artifact.round) == 2: second = artifact
	var at1: Dictionary = {"land_id":int(first.land_id),"cell":first.cell}
	service._artifact_since[str(int(first.id))] = Time.get_ticks_msec() - 60000
	service._artifact_tick(at1)
	check(int(service.touchdowns().get(str(int(first.id)),0)) == 1, "round 1: its artifact takes a touchdown")
	var at2: Dictionary = {"land_id":int(second.land_id),"cell":second.cell}
	service._artifact_since[str(int(second.id))] = Time.get_ticks_msec() - 60000
	service._artifact_tick(at2)
	check(int(service.touchdowns().get(str(int(second.id)),0)) == 0, "round 1: the round 2 artifact does not")
	var ranks: Array = service.rank_rewards()
	evidence["ranks"] = ranks
	var row: Dictionary = ranks.filter(func(r: Dictionary) -> bool: return int(r.artifact) == int(first.id))[0]
	check(int(row.touches) == 1 and int(row.rank) == 1 and not bool(row.claimed) and int(row.reward.get("class_id",0)) > 0, "local rank 1 with this week's touchdown "+str(row))
	check(not service.claim_rank_reward(int(second.id)).ok, "no touchdown: no rank reward")
	var claimed: Dictionary = service.claim_rank_reward(int(first.id))
	evidence["claim"] = claimed
	check(claimed.get("ok",false) and not service.claim_rank_reward(int(first.id)).ok, "rank reward once per week "+str(claimed))
	service.now_override += 7*86400
	var next_week: Dictionary = service.rank_rewards().filter(func(r: Dictionary) -> bool: return int(r.artifact) == int(first.id))[0]
	check(int(next_week.touches) == 0 and not bool(next_week.claimed), "next week starts a new record")
	# Elf forest weekly reset.
	service.import_state(old_save())
	check(service.problem.is_empty(), "a save from before the weekly fields loads")
	var rewards_now: Array = service.elf_rewards()
	check(bool(rewards_now[0].claimed) and bool(rewards_now[1].reached), "old save: this week keeps its claims and wins")
	var monday_reset: int = service.week()
	service.now_override += 7*86400
	var rewards_next: Array = service.elf_rewards()
	evidence["elf"] = {"week":[monday_reset,service.week()],"claimed":rewards_next[0].claimed,"reached":rewards_next[0].reached,"open":service.open_elf_grades().size()}
	check(service.week() != monday_reset and not bool(rewards_next[0].claimed) and not bool(rewards_next[0].reached) and service.open_elf_grades().size() == 3, "next week: rewards reset, grades stay open by total wins "+str(evidence.elf))
	# Wednesday 05:00 KST is the boundary.
	var wed: int = 1800000000
	while service.week(wed) == service.week(wed - 3600): wed += 3600
	var kst: Dictionary = Time.get_datetime_dict_from_unix_time(wed + 9*3600)
	evidence["boundary"] = kst
	check(int(kst.weekday) == 3 and int(kst.hour) == 5, "the week turns on Wednesday 05:00 KST "+str(kst))
	service.now_override = -1
	service.import_state({})
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else: check(CONTENT.validate(old_save()).is_empty(), "a save from before the weekly fields validates")
	print("CONTENT523_APPROX_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
