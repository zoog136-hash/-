extends RefCounted
## Additional weapon-invoke debuffs. Source numbers stay typed and contextual.
## Hit checks, control mapping, boss scaling and cross-buff stacking are host policy.
## Caller validates the invoke roll, attack scope, main target, range and sight.
const Common = preload("res://scripts/equipment523/common.gd")
const MODE: String = "source_numbers_host_controls_v1"
const STATUS_FIELDS: Dictionary = {"ArmorClassBonus":"ac","RangeEvasion":"er","MeleeEvasion":"dg","DamageReduction":"reduction","MagicResist":"mr"}
const RAW_FIELDS: Dictionary = {"MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MeleeHit":"melee_accuracy"}
const CONTROL_FIELDS: Array[String] = ["CannotMove","CannotAttack","CannotCastSpell","CannotCastSkill","CannotUseItem","CannotTeleport","CannotLoot"]
static var _active: Dictionary = {}
static var _world_ref: WeakRef
static var _sequence: int = 0

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"attempted":false,"error":message}

static func _resisted(message: String) -> Dictionary:
	return {"ok":false,"attempted":true,"resisted":true,"error":message}

static func contract(pack: Dictionary, option: Dictionary, policy: Dictionary) -> Dictionary:
	if str(policy.get("invoke_debuff_mode","")) != MODE or str(policy.get("invoke_debuff_stack_mode","")) != "latest_field":
		return _fail("장비 디버프의 명시적 TWILIGHT 실행 정책이 필요합니다.")
	if str(policy.get("invoke_debuff_hit_mode","")) != "proc_only": return _fail("추가 명중식의 로컬 해석을 확인하세요.")
	if str(policy.get("invoke_debuff_world_rules","")) != "pve_no_alignment_or_counter_v1": return _fail("성향·카운터 시스템이 없는 현재 PvE 호스트 정책을 명시하세요.")
	if int(option.get("InvokeOptionTypeID",0)) != 1: return _fail("공격 주문 발동만 연결합니다.")
	for field: String in ["Param2","Param3","Param5","Param6","MaterialTypeID","MaterialAmount","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:
		if int(option.get(field,0)) != 0: return _fail("조건부 장비 디버프는 아직 연결되지 않았습니다.")
	if bool(option.get("IsAmmoAttack",false)): return _fail("탄약 조건 발동은 연결되지 않았습니다.")
	var spell: Dictionary = Common.find(pack,"SpellClass",int(option.get("Param1",0)))
	if spell.is_empty() or bool(spell.get("TestSpell",false)) or int(spell.get("TargettingTypeID",0)) != 2 or int(spell.get("TargetKindID",0)) != 11: return _fail("확인된 단일 대상 주문이 아닙니다.")
	for field: String in ["HPCost","MPCost","VPCost","SpellMaterialTypeID","SpellMaterialItemAmount","TargetAreaRadius","SpellCompositionNode","CopySpellClassID","MinCastRange","BackwardPathCount","TargetLimitCount","SiegeTargetKindID","HideCasterTime"]:
		if int(spell.get(field,0)) != 0: return _fail("범위·비용·연쇄 주문은 별도 계약이 필요합니다.")
	for field: String in ["IsAttackRange","IsChargeSpell","IsRequireSpellGroupMastery"]:
		if bool(spell.get(field,false)): return _fail("추가 사거리·충전·숙련 계약이 필요합니다.")
	var values: Dictionary = {}
	var expected: Dictionary = {"BuffClassID":16,"SpellDebuffMinDuration":17,"SpellDebuffMaxDuration":17,"SpecialResistanceTypeID":18}
	for link: Dictionary in Common.rows(pack,"SpellBonus"):
		if int(link.get("SpellClassID",0)) != int(spell.ID): continue
		if int(link.get("MinSpellLevel",0)) != 0: return _fail("주문 단계 조건을 확인하세요.")
		var effect: Dictionary = Common.bonus(pack,int(link.get("BonusID",0)))
		var raw: Dictionary = effect.get("raw",{})
		var type: Dictionary = effect.get("type",{})
		var name: String = str(type.get("Name",""))
		if not expected.has(name) or int(type.get("UnitID",0)) != int(expected[name]) or values.has(name): return _fail("복합 주문 또는 중복 수치는 연결하지 않습니다.")
		if int(raw.get("BonusApplicationTypeID",-1)) != 0 or int(raw.get("BonusApplicationTargetID",-1)) != 0: return _fail("조건부 주문 수치는 연결하지 않습니다.")
		values[name] = raw.get("Value",0)
	for field: String in ["BuffClassID","SpellDebuffMinDuration","SpellDebuffMaxDuration"]:
		if not values.has(field): return _fail("원본 디버프 기간·효과가 불완전합니다.")
	var low: float = float(values.SpellDebuffMinDuration)
	var high: float = float(values.SpellDebuffMaxDuration)
	if not is_finite(low) or not is_finite(high) or low <= 0 or high < low or high > 3600: return _fail("원본 디버프 기간이 잘못되었습니다.")
	# This policy names source endpoints. Uniform sampling is a host assumption;
	# the private table supplies no server distribution inside the interval.
	if high != low and str(policy.get("invoke_debuff_duration_mode","")) != "source_uniform_seconds": return _fail("범위 내 기간 선택의 로컬 정책이 필요합니다.")
	var buff: Dictionary = Common.find(pack,"BuffClass",int(values.BuffClassID))
	if buff.is_empty() or bool(buff.get("IsGood",true)) or not bool(buff.get("IsEraseOnTimeEnd",false)): return _fail("원본 디버프 정의가 없습니다.")
	if int(buff.get("BuffGroupID",0)) <= 0: return _fail("원본 버프 그룹 정보가 없습니다.")
	var group: Dictionary = Common.find(pack,"BuffGroup",int(buff.BuffGroupID))
	if group.is_empty() or bool(group.get("IsAllowOverlap",true)) or bool(group.get("IsEraseBySpellLevel",true)): return _fail("비중첩·시간제 버프 그룹 계약이 필요합니다.")
	for field: String in ["IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt","IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked","IsEraseOnCast","IsEraseOnHealed","IsEraseOnTargetChanged","IsDecreaseStackOnTimeEnd"]:
		if bool(buff.get(field,false)): return _fail("행동에 따른 해제 계약이 추가로 필요합니다.")
	for field: String in ["MaxHPPercent","EraseOnLevel","MaxStackCount","MPCostPercent","MinMPCost","IsEraseOnAttackedLimitations"]:
		if float(buff.get(field,0)) != 0: return _fail("추가 버프 조건이 연결되지 않았습니다.")
	for field: String in ["IsAbsoluteTimeBuff","IsObtainItemBuff","IsOverlapByPlayer","IsImmuneToDead","IsBuffGroup"]:
		if bool(buff.get(field,false)): return _fail("별도의 버프 시간·생명주기·중첩 계약이 필요합니다.")
	var status: Dictionary = {}
	var numeric: Dictionary = {}
	var healing: Dictionary = {}
	var controls: Dictionary = {}
	var count: int = 0
	var selectors: Dictionary = {}
	for link: Dictionary in Common.rows(pack,"BuffBonus"):
		if int(link.get("BuffClassID",0)) != int(buff.ID): continue
		count += 1
		for field: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if int(link.get(field,0)) != 0: return _fail("조건부 버프 수치는 연결하지 않습니다.")
		var effect: Dictionary = Common.bonus(pack,int(link.get("BonusID",0)))
		var raw: Dictionary = effect.get("raw",{})
		var type: Dictionary = effect.get("type",{})
		var name: String = str(type.get("Name",""))
		var unit: int = int(type.get("UnitID",0))
		var application: int = int(raw.get("BonusApplicationTypeID",-1))
		var target: int = int(raw.get("BonusApplicationTargetID",-1))
		var value: float = float(raw.get("Value",0))
		if not is_finite(value): return _fail("원본 디버프 수치가 잘못되었습니다.")
		var selector: String = "%s|%d|%d" % [name,application,target]
		if selectors.has(selector): return _fail("중복 원본 디버프 수치는 연결하지 않습니다.")
		selectors[selector] = true
		if name == "SpecialResistance" and unit == 3 and application == 2 and target == 6:
			status["status_resistance_6"] = value/10000.0
		elif STATUS_FIELDS.has(name) and unit == 1 and application == 0 and target == 0:
			status[STATUS_FIELDS[name]] = -value if name == "ArmorClassBonus" else value
		elif RAW_FIELDS.has(name) and unit == 1 and application == 0 and target == 0:
			numeric[RAW_FIELDS[name]] = value
		elif name in ["HPHealDecreasePercent","HPPotionDecreasePercent"] and unit == 3 and application == 0 and target == 0 and value >= 0 and value <= 1000000:
			healing["potion" if name == "HPPotionDecreasePercent" else "magic"] = int(value)
		elif name in CONTROL_FIELDS and unit == 20 and application == 0 and target == 0 and value == 1.0:
			controls[name] = true
		elif name == "StatusEffectID" and unit == 121 and application == 0 and target == 0 and value > 0 and value == float(int(value)):
			controls["source_status_effect_id"] = int(value)
		else: return _fail("버프의 실제 소비 경로가 연결되지 않았습니다: "+name)
	if count == 0: return _fail("원본 버프 수치가 없습니다.")
	var control: String = ""
	if controls.has("CannotMove"):
		var source_control: int = int(values.get("SpecialResistanceTypeID",0))
		var mapping: Dictionary = policy.get("invoke_debuff_control_map",{})
		control = str(mapping.get(str(source_control),""))
		if source_control not in [2,7] or control != ("stun" if source_control == 2 else "hold"): return _fail("원본 석화·홀드와 호스트 상태의 대응을 명시하세요.")
		if source_control == 7 and controls.size() != 2: return _fail("확인되지 않은 홀드 부조건입니다.")
		if source_control == 2:
			if controls.size() != CONTROL_FIELDS.size()+1: return _fail("확인되지 않은 석화 부조건입니다.")
			for field: String in CONTROL_FIELDS:
				if not controls.has(field): return _fail("석화의 전체 제어 조건이 없습니다.")
	elif not controls.is_empty() or values.has("SpecialResistanceTypeID"): return _fail("이 제어 상태의 전체 계약이 없습니다.")
	# The host has no NPC alignment/counter subsystem. Preserve this source
	# context explicitly; this is a PvE adaptation, not a reconstructed server rule.
	var source_context: Dictionary = {}
	for field: String in ["AlignmentTypeID","AlignmentChangeAmount","IsPierceCounterMagic","IsPierceCounterAssult"]: source_context[field] = spell.get(field,0)
	return {"ok":true,"spell":spell,"buff":buff,"group":group,"status":status,"numeric":numeric,"healing":healing,"control":control,"source_control":int(values.get("SpecialResistanceTypeID",0)),"source_context":source_context,"duration_min":low,"duration_max":high,"host_mode":MODE}

static func apply(pack: Dictionary, world: Node, victim: Node, option: Dictionary, policy: Dictionary, origin: Dictionary = {}) -> Dictionary:
	var parsed: Dictionary = contract(pack,option,policy)
	if not parsed.get("ok",false): return parsed
	if not is_instance_valid(world) or not is_instance_valid(victim) or bool(_field(victim,"dead",true)) or not _has_field(victim,"life_id") or _field(victim,"world_controller",null) != world: return _fail("동일 월드의 유효한 대상 생명주기가 없습니다.")
	if not Common.spell_target_allowed(world,victim,parsed.spell): return _fail("원본 주문은 은신 대상에게 시전할 수 없습니다.")
	if bool(victim.get_meta("is_player_combatant",false)): return _fail("현재 PvE 디버프 계약의 대상이 아닙니다.")
	if not _valid_origin(origin) or not world.has_method("_equipment523_invoke_owner") or world.call("_equipment523_invoke_owner",origin,int(parsed.spell.ID)) != true: return _fail("현재 물리 장비·슬롯·주문의 발동 소유권을 확인할 수 없습니다.")
	var status: Variant = _status(world)
	if status == null or not status.has_method("set_modifiers") or not status.has_method("remove_modifiers"): return _fail("실제 상태 효과 소비기가 없습니다.")
	var rng: Variant = _field(world,"rng",null)
	if not rng is RandomNumberGenerator: return _fail("실제 월드 난수 생성기가 없습니다.")
	var control: String = str(parsed.control)
	if not control.is_empty() and not victim.has_method("on_equipment523_control"): return _fail("독립 장비 제어 상태 경로가 없습니다.")
	_bind_world(world)
	var key: int = victim.get_instance_id()
	var entry: Dictionary = _active.get(key,{})
	if not _valid(entry,victim,world): entry = {"actor":weakref(victim),"world":weakref(world),"life_id":int(victim.life_id),"buffs":{}}
	var buff_id: String = str(int(parsed.buff.ID))
	var group_id: int = int(parsed.buff.BuffGroupID)
	for id: Variant in entry.buffs:
		var active: Dictionary = entry.buffs[id]
		if str(id) != buff_id and int(active.get("group_id",0)) == group_id and float(active.get("remaining",0)) > 0: return _fail("동일 그룹의 다른 버프는 기존 기록을 보존합니다. 원본 교체 우선순위는 미확인입니다.")
	var duration_factor: float = 1.0
	if not control.is_empty():
		var immunities: Variant = _field(victim,"status_immunities",[])
		if immunities is Array and immunities.has(control): return _resisted("대상이 제어 상태에 면역입니다.")
		var resistance: float = float(_field(victim,control+"_resistance",0))
		# The mapped host timer does not change the source resistance axis:
		# source 2 is petrification, source 6 is stun, and source 7 is hold.
		if status.has_method("modifier"): resistance += float(status.call("modifier",victim,"status_resistance_"+str(int(parsed.source_control))))
		if not is_finite(resistance): return _fail("대상의 호스트 저항 수치를 확인할 수 없습니다.")
		resistance = clampf(resistance,0,100)
		var chance: float = _bounded(policy.get("invoke_debuff_control_chance",1),0,1,1)*(1.0-resistance/100.0)
		if bool(_field(victim,"is_boss",false)):
			chance *= _bounded(policy.get("invoke_debuff_boss_chance_factor",.35),0,1,.35)
			duration_factor = _bounded(policy.get("invoke_debuff_boss_duration_factor",.35),0,1,.35)
		if chance <= 0 or duration_factor <= 0 or (chance < 1 and rng.randf() >= chance): return _resisted("호스트 제어 상태 저항")
	# Only successful variable-duration controls consume a duration draw.
	# Proc chance/cooldown belong to SetInvoke and are never rolled here.
	var duration: float = float(parsed.duration_min)
	if float(parsed.duration_max) != duration: duration = rng.randf_range(duration,float(parsed.duration_max))
	duration *= duration_factor
	var existing: Dictionary = entry.buffs.get(buff_id,{})
	duration = maxf(duration,float(existing.get("remaining",0)))
	_sequence += 1
	var source: String = "equipment523-debuff:"+buff_id
	entry.buffs[buff_id] = {"remaining":duration,"numeric":parsed.numeric.duplicate(true),"healing":parsed.healing.duplicate(true),"control":control,"origin":origin.duplicate(true),"order":_sequence,"source":source,"group_id":group_id}
	_active[key] = entry
	status.call("set_modifiers",victim,source,duration,parsed.status)
	if not control.is_empty(): victim.call("on_equipment523_control",control)
	return {"ok":true,"attempted":true,"spell_id":int(parsed.spell.ID),"buff_id":int(parsed.buff.ID),"duration":duration,"control":control,"origin":origin.duplicate(true),"source_control":int(parsed.source_control),"source_context":parsed.source_context,"source_duration":[parsed.duration_min,parsed.duration_max],"duration_policy":"TWILIGHT uniform selection within source endpoints; host resistance and boss factors","host_mode":MODE}

static func tick(world: Node, delta: float) -> void:
	if not is_instance_valid(world) or _world_ref == null or _world_ref.get_ref() != world: return
	if not is_finite(delta) or delta <= 0: delta = 0
	for key: Variant in _active.keys():
		var entry: Dictionary = _active[key]
		var actor: Node = entry.actor.get_ref()
		if not _valid(entry,actor,world):
			_remove_entry(key,world)
			continue
		for id: Variant in entry.buffs.keys():
			entry.buffs[id].remaining = float(entry.buffs[id].remaining)-maxf(0,delta)
			if float(entry.buffs[id].remaining) <= 0:
				var status: Variant = _status(world)
				if status != null and status.has_method("remove_modifiers"): status.call("remove_modifiers",actor,str(entry.buffs[id].source))
				entry.buffs.erase(id)
		if entry.buffs.is_empty(): _active.erase(key)

static func outgoing(actor: Node, amount: int, kind: String) -> int:
	var fields: Dictionary = _fields(actor)
	var field: String = "ranged_damage" if kind == "ranged" else "melee_damage" if kind == "melee" else ""
	if not fields.has(field): return amount
	var delta: int = int(fields[field])
	return maxi(0,amount+delta)

static func accuracy_delta(actor: Node, kind: String) -> int:
	return int(_fields(actor).get("melee_accuracy",0)) if kind == "melee" else 0

static func healing_weight(actor: Node, potion: bool = false) -> int:
	if not is_instance_valid(actor) or _world_ref == null: return 0
	var world: Node = _world_ref.get_ref()
	var entry: Dictionary = _active.get(actor.get_instance_id(),{})
	if not _valid(entry,actor,world): return 0
	var maximum: int = 0
	for buff: Dictionary in entry.buffs.values():
		if float(buff.remaining) > 0: maximum = maxi(maximum,int(buff.healing.get("potion" if potion else "magic",0)))
	return clampi(maximum,0,1000000)

static func control_active(actor: Node, kind: String) -> bool:
	if kind not in ["stun","hold"] or not is_instance_valid(actor) or _world_ref == null: return false
	var world: Node = _world_ref.get_ref()
	var entry: Dictionary = _active.get(actor.get_instance_id(),{})
	if not _valid(entry,actor,world): return false
	for buff: Dictionary in entry.buffs.values():
		if float(buff.remaining) > 0 and str(buff.get("control","")) == kind: return true
	return false

static func clear(world: Node = null) -> void:
	# An exiting previous Main must not erase the next Main's live effects.
	if world != null and (_world_ref == null or _world_ref.get_ref() != world): return
	var owner: Node = world if world != null else _world_ref.get_ref() if _world_ref != null else null
	for key: Variant in _active.keys(): _remove_entry(key,owner)
	_active.clear()
	_world_ref = null

static func _fields(actor: Node) -> Dictionary:
	if not is_instance_valid(actor) or _world_ref == null: return {}
	var world: Node = _world_ref.get_ref()
	var entry: Dictionary = _active.get(actor.get_instance_id(),{})
	if not _valid(entry,actor,world): return {}
	var ordered: Array = entry.buffs.values()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.order) < int(b.order))
	var values: Dictionary = {}
	for buff: Dictionary in ordered:
		if float(buff.remaining) > 0: values.merge(buff.numeric,true)
	return values

static func _bind_world(world: Node) -> void:
	if _world_ref == null or _world_ref.get_ref() != world:
		clear()
		_world_ref = weakref(world)

static func _valid(entry: Dictionary, actor: Node, world: Node) -> bool:
	# Same-map travel increments combat_generation but preserves timed buffs.
	# Map/reload/death teardown calls clear(world) explicitly.
	return not entry.is_empty() and is_instance_valid(actor) and is_instance_valid(world) and entry.get("actor") is WeakRef and entry.actor.get_ref() == actor and entry.get("world") is WeakRef and entry.world.get_ref() == world and _field(actor,"world_controller",null) == world and not bool(_field(actor,"dead",true)) and int(entry.get("life_id",-1)) == int(_field(actor,"life_id",-2))

static func _valid_origin(origin: Dictionary) -> bool:
	if not origin.get("instance_id") is String or str(origin.instance_id).is_empty(): return false
	for field: String in ["source_id","slot","bonus_id"]:
		if not origin.get(field) is int or int(origin[field]) <= 0: return false
	return true

static func _remove_entry(key: Variant, world: Node) -> void:
	var entry: Dictionary = _active.get(key,{})
	if entry.is_empty(): return
	var actor: Node = entry.actor.get_ref()
	var status: Variant = _status(world)
	if is_instance_valid(actor) and int(entry.get("life_id",-1)) == int(_field(actor,"life_id",-2)) and status != null and status.has_method("remove_modifiers"):
		for buff: Dictionary in entry.buffs.values(): status.call("remove_modifiers",actor,str(buff.source))
	_active.erase(key)

static func _status(world: Node) -> Variant:
	if not is_instance_valid(world): return null
	var service: Variant = _field(world,"original_skills",null)
	return _field(service,"status",null) if service != null else null

static func _has_field(object: Object, name: String) -> bool:
	if not is_instance_valid(object): return false
	for property: Dictionary in object.get_property_list():
		if str(property.get("name","")) == name: return true
	return false

static func _field(object: Object, name: String, fallback: Variant) -> Variant:
	return object.get(name) if _has_field(object,name) else fallback

static func _bounded(value: Variant, low: float, high: float, fallback: float) -> float:
	if not value is int and not value is float: return fallback
	return clampf(float(value),low,high) if is_finite(float(value)) else fallback
