extends SceneTree

const SOURCE = preload("res://scripts/skills/player_skills523.gd")
var checks := 0
var failures: Array[String] = []
class ReadyPlayer extends RefCounted:
	var motion: Dictionary = {"dead":false}
	func is_stunned() -> bool: return false
	func is_feared() -> bool: return false
	func is_silenced() -> bool: return false
class CostHost extends Node:
	var hp: int = 99
	var mp: int = 99
	var inventory: Dictionary = {}
	var job_class: String = "마법사"
	var level: int = 90
	var player = ReadyPlayer.new()
	var pending_attack: Dictionary = {}
	var skill_global_cooldown: float = 0
	var skill_cooldowns: Dictionary = {}
	var active_skill_buffs: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("SKILLS523_POLICY_FAIL ", message)

func row() -> Dictionary:
	# Synthetic, deliberately unrelated numeric identity. Never an original row.
	return {"ID":99999991,"SpellTypeID":2,"SpellCompositionNode":0,"SpellCategoryID":8,
		"MPCostUnit":1,"VPCost":0,"HPCost":12,"MPCost":17,"SpellMaterialTypeID":1,
		"SpellMaterialItemAmount":2,"TargettingTypeID":2,"TargetKindID":11,
		"TargetAreaRadius":0,"CastRange":7,"MinCastRange":0,"CastDelay":1234,
		"CastGroupID":33333,"TargetLimitCount":0}

func bonus(name: String, unit: String, value: float, level: int = 0) -> Dictionary:
	return {"link":{"MinSpellLevel":level}, "bonus":{"Value":value,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},"type":{"Name":name},"unit":{"Name":unit}}

func profile() -> Dictionary:
	return {"row":row(),"target_kind":{"Name":"AllButMe"},"targeting_type":{"Name":"SingleObject"},
		"learn_limits":[{"ClassID":1,"IsTutorialSpell":false}],"costs":[],"cast_groups":[],
		"bonuses":[bonus("SpellDebuffMinDuration","Seconds",2),bonus("SpellDebuffMaxDuration","Seconds",5),bonus("BuffClassID","BuffClassID",99999992)],
		"buffs":[{"row":{"ID":99999992},"bonuses":[bonus("Stunned","TrueFalse",1)]}]}

func skill() -> Dictionary:
	return {"id":"synthetic","activation":"active","mode":"status","status":"stun",
		"shape":"circle","range":147.0,"cast_time":.4,"cooldown":9.0,"mp":3,"hp":0,
		"items":{"화살":3,"옛 재료":9},"power":43,"status_chance":.42,"debuff":{"ac":-3}}

func run() -> void:
	var adapter = SOURCE.new()
	adapter.bindings = {"class_ids":{"기사":1,"마법사":3},"material_inventory_keys":{"1":{"inventory_key":"합성 재료","native_item_id":99999993}},"retained_host_items":["화살"]}
	adapter.profiles = {"synthetic":profile()}
	var base := skill()
	var projected: Dictionary = adapter.apply_to(base.duplicate(true),"기사",false)
	check(projected.mp==17 and projected.hp==12,"exact source costs replace host costs")
	check(projected.items=={"화살":3,"합성 재료":2},"preserve ammunition while replacing old material")
	check(projected.shape=="single" and projected.targets==1,"zero-radius SingleObject cannot keep host splash")
	check(projected.duration_bounds==[2.0,5.0],"only confirmed main stun gets seconds bounds")
	check(projected.range==base.range and projected.cast_time==base.cast_time and projected.cooldown==base.cooldown,"raw range/delay cannot invent pixel/timing conversion")
	check(projected.power==base.power and projected.status_chance==base.status_chance and projected.debuff==base.debuff,"no new damage/probability/AC formula")
	check(not base.has("source523"),"input catalog record remains untouched")
	check(not adapter.apply_to(base.duplicate(true),"마법사",false).get("source523_block_reason","").is_empty(),"native class restriction")
	check(not adapter.apply_to(base.duplicate(true),"기사",true).get("source523_block_reason","").is_empty(),"unresolved upgrade cannot borrow base contract")
	adapter.profiles.synthetic.row.SpellTypeID=3
	check(not adapter.apply_to(base.duplicate(true),"기사",false).get("source523_block_reason","").is_empty(),"source passive cannot cast as active")
	adapter.profiles.synthetic=profile()
	adapter.profiles.synthetic.row.TargetKindID=52
	adapter.profiles.synthetic.target_kind.Name="PCButMe"
	check(not adapter.apply_to(base.duplicate(true),"기사",false).get("source523_block_reason","").is_empty(),"PC source cannot target host NPC")
	adapter.profiles.synthetic=profile()
	adapter.profiles.synthetic.costs=[{"synthetic_alternative":true}]
	check(not adapter.apply_to(base.duplicate(true),"기사",false).get("source523_block_reason","").is_empty(),"alternative cost dispatch cannot default to base")
	adapter.profiles.synthetic=profile()
	adapter.profiles.synthetic.row.SpellCompositionNode=4
	check(not adapter.apply_to(base.duplicate(true),"기사",false).get("source523_block_reason","").is_empty(),"unresolved composition node")
	adapter.profiles.synthetic=profile()
	adapter.profiles.synthetic.bonuses.append(bonus("SpellDebuffMinDuration","Seconds",1,2))
	projected=adapter.apply_to(base.duplicate(true),"기사",false)
	check(projected.duration_bounds==[2.0,5.0],"level-specific duration is not summed or substituted")
	adapter.profiles.synthetic.bonuses.append(bonus("SpellDebuffMinDuration","Seconds",4))
	check(not adapter.apply_to(base.duplicate(true),"기사",false).has("duration_bounds"),"duplicate applicable duration remains unresolved")
	adapter.profiles.synthetic=profile()
	adapter.profiles.synthetic.buffs[0].bonuses=[]
	check(not adapter.apply_to(base.duplicate(true),"기사",false).has("duration_bounds"),"duration cannot create a status without source flag")
	var before: Dictionary = adapter.profiles.duplicate(true)
	var revision: int = adapter.revision
	check(not adapter.load_pack("user://missing-skills523.json","0".repeat(64)),"missing pack rejected")
	check(adapter.profiles==before and adapter.revision==revision,"failed swap preserves existing snapshot")
	var corrupt_path := "user://skills523-corrupt-fixture.json"
	var corrupt_file := FileAccess.open(corrupt_path,FileAccess.WRITE)
	corrupt_file.store_string('{"schema_version":1,"patch":508}')
	corrupt_file.close()
	check(not adapter.load_pack(corrupt_path,"0".repeat(64)) and adapter.profiles==before,"byte corruption cannot replace active snapshot")
	check(not adapter.load_pack(corrupt_path,FileAccess.get_sha256(corrupt_path)) and adapter.profiles==before,"self-consistent obsolete pack is still rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	check(SOURCE.detail_text(projected).contains("합성 재료 2개"),"UI shares actual source material projection")
	adapter.bindings["reference_only_prefixes"] = ["lmref_"]
	adapter.profiles["lmref_synthetic"] = profile()
	var reference := skill()
	reference.id = "lmref_synthetic"
	reference["runtime_blocked"] = true
	reference["mode"] = "official_pending"
	var inspected: Dictionary = adapter.apply_to(reference.duplicate(true),"기사",false)
	check(inspected.runtime_blocked and inspected.mode=="official_pending" and inspected.mp==reference.mp and inspected.items==reference.items,"new source evidence cannot activate or rebalance a reference skill")
	check(inspected.source523.cast_range_raw==7 and inspected.source523.cast_delay_raw==1234,"reference UI retains native range/delay evidence without conversion")
	check(SOURCE.inventory_keys({"source523":{"applied":["materials"]}},"마력의 돌")==["마력의 돌","마력의 돌 (각인)"],"source material accepts explicitly reviewed catalog spelling")
	check(SOURCE.inventory_keys({},"마력의 돌")==["마력의 돌"],"unbound legacy costs retain their inventory contract")
	var cost_host := CostHost.new()
	var service = preload("res://scripts/skills/skill_service.gd").new()
	service.world=cost_host
	cost_host.inventory={"마력의 돌":2,"마력의 돌 (각인)":2}
	var cost: Dictionary={"mp":15,"hp":10,"items":{"마력의 돌":5},"source523":{"applied":["materials"]}}
	check(not service.spend(cost) and cost_host.mp==99 and cost_host.hp==99 and cost_host.inventory=={"마력의 돌":2,"마력의 돌 (각인)":2},"insufficient split stacks do not partially spend resources")
	cost_host.inventory["마력의 돌 (각인)"]=3
	check(service.spend(cost) and cost_host.mp==84 and cost_host.hp==89 and cost_host.inventory=={"마력의 돌":0,"마력의 돌 (각인)":0},"production spend consumes exact source amount across explicit inventory aliases")
	check(not service.spend(cost) and cost_host.mp==84 and cost_host.hp==89,"repeat failed payment cannot debit HP/MP")
	cost_host.inventory={"마력의 돌 (각인)":5}
	cost.erase("source523")
	check(not service.spend(cost) and cost_host.inventory=={"마력의 돌 (각인)":5},"unbound old skills do not gain new alias consumption")
	service.catalog=preload("res://scripts/skills/skill_catalog.gd").new()
	service.catalog.world=cost_host
	var self_buff: Dictionary={"id":"synthetic_self","name":"synthetic_self","class":"마법사","classes":["마법사"],"mode":"buff","activation":"active","source523":{"target_kind":"Me"},"items":{}}
	service.catalog.records=[self_buff]
	service.catalog.by_id={"synthetic_self":self_buff}
	service.catalog.learned={"synthetic_self":1}
	var selected_enemy := TwilightMonster.new()
	check(service.auto_wants(self_buff,selected_enemy),"an unrelated selected enemy cannot block an automatic self buff")
	selected_enemy.free()
	cost_host.free()
	print("SKILLS523_POLICY_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
