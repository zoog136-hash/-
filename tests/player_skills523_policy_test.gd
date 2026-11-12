extends SceneTree

const SOURCE = preload("res://scripts/skills/player_skills523.gd")
var checks := 0
var failures: Array[String] = []
class ReadyPlayer extends Node2D:
	var silence_remaining: float = 0.0
	var source_523_spell_blocked: bool = false
	var motion: Dictionary = {"dead":false}
	func is_stunned() -> bool: return false
	func is_feared() -> bool: return false
	func is_silenced() -> bool: return false
class Patch523Spells extends RefCounted:
	var blocked: bool = false
	func blocks(_kind: String) -> bool: return blocked
class HalphasCombat extends RefCounted:
	var charge: Dictionary = {}
	func frozen(_actor) -> bool: return false
class HalphasStar extends RefCounted:
	var combat = HalphasCombat.new()
class CostHost extends Node:
	var patch523_npc_spells = Patch523Spells.new()
	var halphas_star = preload("res://scripts/cards/halphas_star_enchant_runtime.gd").new()
	var original_skills: RefCounted = null
	var combat_generation: int = 0
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
	var equipped_items: Dictionary = {}
	var equipped_catalog: Dictionary = {}
	# Catalog resolution always includes the actual relic ownership/context key,
	# even when this synthetic host has no equipped or acquired cards.
	var card_draw_fusion = preload("res://scripts/card_draw_fusion.gd").new()
	var card_collections = preload("res://scripts/cards/collection_runtime.gd").new()
	func _init() -> void:
		add_child(player)
		halphas_star.configure(self)
class DashPlayer extends Node2D:
	var motion: Dictionary = {"direction":Vector2.RIGHT}
class DashField extends RefCounted:
	var wall_x: float = 40
	func point_clear(point: Vector2, _radius: float) -> bool: return point.x < wall_x
class DashWorld extends Node:
	var player = DashPlayer.new()
	var field_map = DashField.new()
	func _is_walkable_world(_point: Vector2) -> bool: return true
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return true

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
	check(projected.range==base.range and projected.cast_time==base.cast_time and is_equal_approx(projected.cooldown,1.234),"raw range cannot invent pixel conversion; CastDelay 1234ms is the cooldown (user decision 2026-11-12)")
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
	adapter.profiles.synthetic=profile()
	adapter.profiles.synthetic.row.merge({"ID":349,"SpellCategoryID":4,"TargettingTypeID":1,"TargetKindID":2},true)
	adapter.profiles.synthetic.bonuses=[bonus("MPRestoration","Value",96),bonus("MPRestoration","Value",97,1),bonus("MPRestoration","Value",100,4)]
	var conversion := skill()
	conversion.mode="convert"
	conversion["mana"]=30
	projected=adapter.apply_to(conversion.duplicate(true),"기사",false)
	check(projected.mana==96 and projected.source523.applied.has("mana"),"base restoration excludes native enhanced levels even when host owns level1")
	check(SOURCE.detail_text(projected).contains("MP 회복: 96"),"UI describes applied base restoration")
	adapter.profiles.synthetic.row.ID=18304
	adapter.profiles.synthetic.bonuses=[bonus("MPRestoration","Value",80)]
	check(adapter.apply_to(conversion.duplicate(true),"기사",false).mana==80,"second reviewed self conversion uses typed flat restoration")
	adapter.profiles.synthetic.bonuses.append(bonus("MPRestoration","Value",81))
	check(not adapter.apply_to(conversion.duplicate(true),"기사",false).get("source523_block_reason","").is_empty(),"ambiguous duplicate restoration cannot fall back to invented amount")
	adapter.profiles.synthetic.bonuses=[bonus("MPRestoration","Percentage",80)]
	check(not adapter.apply_to(conversion.duplicate(true),"기사",false).get("source523_block_reason","").is_empty(),"percentage restoration cannot be treated as flat MP")
	adapter.profiles.synthetic=profile()
	projected=adapter.apply_to(base.duplicate(true),"기사",false)
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
	check(service.ready(self_buff),"test host implements current boss-state readiness contract")
	cost_host.halphas_star.combat.charge = {"synthetic_fixture":true}
	check(not service.ready(self_buff),"current charge contract blocks an otherwise ready self buff")
	cost_host.halphas_star.combat.charge.clear()
	cost_host.halphas_star.combat.states[cost_host.player.get_instance_id()] = {"target":weakref(cost_host.player),"generation":0,"life":-1,"ice":1.0}
	check(not service.ready(self_buff),"current frozen-player contract blocks an otherwise ready self buff")
	cost_host.halphas_star.combat.states.clear()
	cost_host.patch523_npc_spells.blocked = true
	check(not service.ready(self_buff),"boss CannotCastSkill still blocks test host")
	cost_host.patch523_npc_spells.blocked = false
	cost_host.player.source_523_spell_blocked = true
	check(not service.ready(self_buff),"boss spell-only block remains effective for magic")
	cost_host.player.source_523_spell_blocked = false
	var selected_enemy := TwilightMonster.new()
	check(service.auto_wants(self_buff,selected_enemy),"an unrelated selected enemy cannot block an automatic self buff")
	selected_enemy.free()
	var uninstalled: Dictionary={"id":"lmref_a145521a8b2fa008","runtime_blocked":true}
	adapter.prepare_estimate(uninstalled)
	check(uninstalled.runtime_blocked and not uninstalled.has("estimated523"),"estimate cannot activate an identity without its installed source profile")
	adapter.profiles[uninstalled.id]={"row":{"ID":37051,"SpellCompositionNode":999999}}
	adapter.prepare_estimate(uninstalled)
	check(uninstalled.runtime_blocked and not uninstalled.has("estimated523"),"wrong composition cannot borrow a named skill estimate")
	var detection_profile := profile()
	detection_profile.row.merge({"ID":37051,"SpellCompositionNode":804,"SpellCategoryID":371,"TargettingTypeID":1,"TargetKindID":103,"TargetAreaRadius":15},true)
	detection_profile.learn_limits=[{"ClassID":3,"IsTutorialSpell":false,"CharacterMinLevel":70}]
	detection_profile.target_kind={"Name":"InvisibleAndMeButCompany"}
	detection_profile.targeting_type={"Name":"Self"}
	adapter.profiles[uninstalled.id]=detection_profile
	uninstalled.merge({"class":"마법사","name":"합성 탐지","classes":["마법사"]},true)
	adapter.prepare_estimate(uninstalled)
	check(not uninstalled.runtime_blocked and uninstalled.mode=="detect" and uninstalled.minimum_level==70,"reviewed estimate promotes existing identity while retaining native learn limit")
	check(uninstalled.mp==17 and uninstalled.hp==12 and uninstalled.items=={"합성 재료":2},"estimated effect does not replace installed native costs with invented values")
	check(SOURCE.detail_text(uninstalled).contains("TWILIGHT 추정 적용"),"estimated execution remains visibly distinct from native restoration")
	var dash_world := DashWorld.new()
	var planner = preload("res://scripts/skills/estimated_nodes523.gd").new()
	planner.world=dash_world
	check(not planner.dash_plan({"dash_distance":120},null).is_finite(),"dash rejects obstructed footprint even when endpoint navigation and line of sight allow it")
	dash_world.field_map.wall_x=INF
	check(planner.dash_plan({"dash_distance":120},null)==Vector2(120,0),"unobstructed no-target dash preserves intended distance")
	dash_world.player.free();dash_world.free()
	cost_host.free()
	print("SKILLS523_POLICY_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

