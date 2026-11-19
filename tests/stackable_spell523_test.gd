extends SceneTree
## 보고서2 R1: original stackable (충전형) spells. Without the original definition
## ZIP only the admission rule runs on a supplied store. With it 암흑기사 다크 소울
## (34922) is read from the tables, charged by kills/attacks, cast from the charge
## store (refused at 0 charges and at the active limit, a refused cast spends
## nothing), shown on the quickslot/skill window count, and saved.
const STACK = preload("res://scripts/skills/stackable_spell523.gd")
const STATE = preload("res://scripts/original_client/oc_m95_m99_spell_state.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QUICK = preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const DARK_SOUL: String = "lm_82baa209008667a5"
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("STACKABLE_SPELL523_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func admission_rule() -> void:
	var model := func(current: int, active: int) -> Dictionary:
		return {"bonus_lists":{7:[1,2]},"bonus_rows":{1:{"type":STATE.TYPE_IS_STACKABLE,"value":1},2:{"type":STATE.TYPE_STACKABLE_MAX,"value":2}},"tree188":{7:{"current":current,"packet_max":2,"active":active}}}
	check(STATE.stackable_admission(model.call(0,0),7).get("code")==STATE.RESULT_CURRENT_NOT_POSITIVE, "0 charges -> refused (0xD1DA)")
	check(STATE.stackable_admission(model.call(1,2),7).get("code")==STATE.RESULT_ACTIVE_AT_MAX, "active at max -> refused (0xD1E4)")
	check(STATE.stackable_admission(model.call(1,1),7).result=="continue_next_validation", "1 charge, 1 active of 2 -> continues to the normal checks")
	var shown: Dictionary = QUICK.amount_presentation(true,"",{"stack_count":2,"ammo_count":2,"can_use_without_ammo":true})
	check(shown.text=="2" and shown.visible, "quickslot shows the charge count through the original count refresh")
	check(not QUICK.amount_presentation(true,"",{"stack_count":0,"ammo_count":0,"can_use_without_ammo":true}).visible, "0 charges hide the quickslot count (original set_count)")
	check(QUICK.amount_presentation(true,"",{"ammo_count":5,"can_use_without_ammo":false}).text=="5", "ammo slots keep the ammo count")

func table() -> void:
	var spec: Dictionary = STACK.source_spec(34922)
	evidence["spec"] = spec
	check(int(spec.get("max_stack",0))==2 and int(spec.get("max_summon",0))==2 and int(spec.get("per_cast",0))==1, "다크 소울: StackableSpellMaxStack 2, MaxSummon 2, MaterialCount 1")
	check(int(spec.get("material_type",0))==102 and int(spec.get("material_amount",0))==4 and is_equal_approx(float(spec.get("cooldown",0)),2.0), "흑마법 결정체(102) 4개, CastDelay 2초")
	var effect: Dictionary = spec.get("effect",{})
	check(int(effect.get("hits",0))==3 and int(effect.get("targets",0))==5 and int(effect.get("base",0))==110 and int(effect.get("number",0))==10 and int(effect.get("sides",0))==5, "#3회 타격: 2.5초/1초 = 3회, 최대 5명, 110+10d5")
	var kinds: Dictionary = {}
	for gain: Dictionary in spec.get("gains",[]): kinds[str(gain.event)] = gain
	check(kinds.has("on_kill") and is_equal_approx(float(kinds.on_kill.probability),1.0) and int(kinds.on_kill.amount)==1 and is_equal_approx(float(kinds.on_kill.gap),0.1), "처치 시 +1 (InvokeOption 42, 100ms)")
	check(kinds.has("on_hit") and is_equal_approx(float(kinds.on_hit.probability),0.1) and int(kinds.on_hit.amount)==1, "공격 시 10% +1 (InvokeOption 64 Param6 100000)")
	check(STACK.source_spec(1).is_empty(), "a normal spell is not stackable")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world,"암흑기사"), "actual Main entry as 암흑기사")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters()
	var service: RefCounted = world.original_skills
	var record: Dictionary = service.catalog.record_for(DARK_SOUL)
	world.level = maxi(int(world.level),60)
	service.catalog.learned[DARK_SOUL] = 1
	check(service.catalog.owned(record) and service.stackable.handles(record), "learned 다크 소울 is a stackable spell")
	check(world._quickslot_registration_error("skill",str(record.name)).is_empty(), "다크 소울 can be put on a quickslot")
	var stones: String = "흑마법 결정체"
	world.inventory[stones] = 8
	world.skill_cooldowns.clear(); world.skill_global_cooldown = 0
	check(not service.ready(record) and service.stackable.admission(record).get("code")=="no_charge", "0 charges: refused")
	check(not service.cast(record) and int(world.inventory.get(stones,0))==8, "a refused cast spends no material")
	# Recharge: kills always (+1, gap 0.1 s), cap 2.
	service.stackable.on_event("on_kill",{})
	check(service.stackable.count_for(record)==1, "a kill gives +1")
	service.stackable.on_event("on_kill",{})
	check(service.stackable.count_for(record)==1, "inside the 100 ms gap no second charge")
	service.stackable.tick(0.2)
	service.stackable.on_event("on_kill",{}); service.stackable.tick(0.2); service.stackable.on_event("on_kill",{})
	check(service.stackable.count_for(record)==2, "charges stop at StackableSpellMaxStack 2")
	var by_spell: int = service.stackable.on_event("on_hit",{"by_spell":true})
	check(by_spell==0, "a spell hit does not charge")
	var ammo: Dictionary = world._quickslot_ammo_source({"kind":"skill","id":str(record.name)})
	check(int(ammo.get("stack_count",-1))==2, "quickslot/skill window source shows 2 charges %s" % str(ammo))
	# Cast twice: the second reaches the active limit only if the first is still live.
	check(service.cast(record), "cast with charges")
	check(service.stackable.count_for(record)==1 and int(service.stackable.state_of(DARK_SOUL).active)==1 and int(world.inventory.get(stones,0))==4, "one charge and 4 결정체 spent, one active")
	world.skill_cooldowns.clear(); world.skill_global_cooldown = 0
	service.stackable.state_of(DARK_SOUL).active = 2
	check(not service.cast(record) and service.stackable.admission(record).get("code")=="active_limit" and int(world.inventory.get(stones,0))==4, "active at the limit: refused, nothing spent")
	service.stackable.state_of(DARK_SOUL).active = 1
	for _step: int in 30: service.stackable.tick(0.1)
	check(int(service.stackable.state_of(DARK_SOUL).active)==0 and service.stackable.plates.is_empty(), "the plate ends after its 2.5 s and frees the active slot")
	# Attack recharge with a 10% roll.
	var attack_rolls: int = 0
	service.stackable.state_of(DARK_SOUL).current = 0
	for _i: int in 400:
		service.stackable.tick(0.2)
		if service.stackable.on_event("on_hit",{"by_spell":false})>0:
			attack_rolls += 1
			service.stackable.state_of(DARK_SOUL).current = 0
	evidence["attack_charges_of_400"] = attack_rolls
	check(attack_rolls>=15 and attack_rolls<=70, "normal attacks charge about 10%% of the time (%d/400)" % attack_rolls)
	# Save and reload keep the stored charges.
	service.stackable.state_of(DARK_SOUL).current = 2
	check(world._save_game(true)==OK, "the state saves")
	service.stackable.state_of(DARK_SOUL).current = 0
	world._load_game(true)
	check(world.original_skills.stackable.count_for(world.original_skills.catalog.record_for(DARK_SOUL))==2, "2 charges survive the reload")
	world.queue_free()
	await process_frame

func run() -> void:
	admission_rule()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("STACKABLE_SPELL523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
