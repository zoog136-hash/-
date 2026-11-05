extends RefCounted
## Source amounts are exact. Tick interval, drain chance and normal-hit scope
## are explicit TWILIGHT policies because the source contains no full formula.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const FIELDS: Array[String] = ["RegenHP","RegenMP","AbsoluteRegenHP","AbsoluteRegenMP","AttackDrainHP","AttackDrainMP","HPMPRegenOverWeight"]
static var cache: Dictionary = {}

static func effects(record: Dictionary) -> Dictionary:
	if not record.get("source_m_native_item",false) or not D.equipment(record): return {}
	var definition: Dictionary = D.item_definition(record)
	if definition.is_empty(): return {}
	var id: String = str(int(record.source_item_class_id))
	if cache.has(id): return cache[id]
	var result: Dictionary = {}
	for row: Dictionary in definition.get("item_bonus",[]):
		var key: String = str(row.bonus_type.Name)
		if key not in FIELDS or row.get("IsPossession") != false: continue
		if int(row.bonus.BonusApplicationTypeID) != 0 or int(row.bonus.BonusApplicationTargetID) != 0: continue
		if str(row.unit.Name) not in ["Value","TrueFalse"]: continue
		result[key] = int(result.get(key,0))+int(row.bonus.Value)
	cache[id] = result
	return result

static func tick(world: Node, delta: float) -> void:
	if world.hp <= 0: return
	var interval: float = clampf(float(world.ui_preferences.get("patch523_item_regen_interval_seconds",30.0)),1.0,300.0)
	world.source_item_regen_elapsed += maxf(delta,0.0)
	if world.source_item_regen_elapsed < interval: return
	var cycles: int = int(floor(world.source_item_regen_elapsed/interval))
	world.source_item_regen_elapsed = fmod(world.source_item_regen_elapsed,interval)
	var effects: Dictionary = world.equipment_effects.get("source_item_passives",{})
	var permitted: bool = world._inventory_total_weight()*2 < world._carrying_capacity() or int(effects.get("HPMPRegenOverWeight",0)) > 0
	var hp_gain: int = int(effects.get("AbsoluteRegenHP",0))+(int(effects.get("RegenHP",0)) if permitted else 0)
	var mp_gain: int = int(effects.get("AbsoluteRegenMP",0))+(int(effects.get("RegenMP",0)) if permitted else 0)
	var before_hp: int = world.hp
	var before_mp: int = world.mp
	world.hp = clampi(world.hp+cycles*hp_gain,0,world._effective_max_hp())
	world.mp = clampi(world.mp+cycles*mp_gain,0,world._effective_max_mp())
	if world.hp != before_hp or world.mp != before_mp:
		world.hud.append_log("원본 장비 회복 · HP %+d / MP %+d · 간격은 TWILIGHT 설정" % [world.hp-before_hp,world.mp-before_mp])
		world._refresh_combat_hud();world._request_deferred_save()

static func drain(world: Node, target: Node, reserved_hp: int = 0) -> int:
	var effects: Dictionary = world.equipment_effects.get("source_item_passives",{})
	var hp_amount: int = maxi(0,int(effects.get("AttackDrainHP",0)))
	var mp_amount: int = maxi(0,int(effects.get("AttackDrainMP",0)))
	if hp_amount == 0 and mp_amount == 0: return 0
	var chance: float = clampf(float(world.ui_preferences.get("patch523_item_drain_chance_percent",100.0)),0.0,100.0)/100.0
	if chance <= 0.0 or (chance < 1.0 and world.rng.randf() >= chance): return 0
	var stolen_hp: int = mini(hp_amount,maxi(0,target.hp-reserved_hp))
	var stolen_mp: int = mini(mp_amount,mini(maxi(0,target.mp),maxi(0,world._effective_max_mp()-world.mp)))
	world.hp = mini(world._effective_max_hp(),world.hp+stolen_hp)
	world.mp += stolen_mp;target.mp -= stolen_mp
	if stolen_hp > 0 or stolen_mp > 0:
		world.hud.append_log("원본 장비 일반 명중 흡수 · HP %d / MP %d · 발동률은 TWILIGHT 설정" % [stolen_hp,stolen_mp])
		world._refresh_combat_hud();world._request_deferred_save()
	return stolen_hp
