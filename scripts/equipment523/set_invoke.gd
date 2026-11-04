extends RefCounted
## Exact set membership and persistent additional weapon-invoke selections.
## Slot selection, cumulative thresholds and the level-zero fallback are host policy.
const C = preload("res://scripts/equipment523/common.gd")
const TICKET_IDS: Array[int] = [169994,170004]
static var _busy: bool = false

static func denied(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.get("schema") != "equipment523-invoke-v1" or not value.get("slots") is Dictionary: return false
	if int(value.get("replacement_id",0)) <= 0 or not value.get("source_sha256") is String: return false
	if int(value.get("source_id",0)) <= 0 or str(value.get("target_id","")).is_empty(): return false
	for key: Variant in value.slots:
		if not str(key).is_valid_int() or int(key) <= 0 or not value.slots[key] is Dictionary: return false
		if int(value.slots[key].get("group_id",0)) <= 0 or int(value.slots[key].get("entity_id",0)) <= 0: return false
	return true

static func replacement_id(pack: Dictionary, source_id: String) -> int:
	var found: int = 0
	for row: Dictionary in C.rows(pack,"ItemBonus"):
		if str(int(row.get("ItemClassID",0))) != source_id or bool(row.get("IsPossession",false)): continue
		var value: Dictionary = C.bonus(pack,int(row.get("BonusID",0)))
		if value.get("type",{}).get("Name","") != "ItemInvokeReplacementID": continue
		var raw: Dictionary = value.get("raw",{})
		if int(raw.get("BonusApplicationTypeID",-1)) != 0 or int(raw.get("BonusApplicationTargetID",-1)) != 0: return 0
		if found != 0: return 0
		found = int(raw.get("Value",0))
	return found

static func slots(pack: Dictionary, replacement: int) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in C.rows(pack,"ItemInvokeReplacementEntityView"):
		if int(row.get("ItemInvokeReplacementID",0)) != replacement: continue
		var key: String = str(int(row.get("SlotNumber",0)))
		if not result.has(key): result[key] = []
		result[key].append(row)
	return result

static func slot_options(pack: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var available: Dictionary = slots(pack,replacement_id(pack,str(target.get("source_id",""))))
	for key: Variant in available:
		var choices: Array = available[key]
		if choices.size() <= 1: continue
		var labels: PackedStringArray = []
		for row: Dictionary in choices:
			var group: Dictionary = C.find(pack,"ItemInvokeReplacementBonusGroup",int(row.get("ItemInvokeReplacementBonusGroupID",0)))
			labels.append("%s %.4f%%" % [str(group.get("Name","미확인")),float(row.get("Prob",0))/10000.0])
		out.append({"slot":int(key),"detail":" / ".join(labels)})
	out.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.slot) < int(b.slot))
	return out

static func quote(pack: Dictionary, action: String, context: Dictionary) -> Dictionary:
	if action != "invoke_replacement": return denied("지원하지 않는 발동 교체 동작입니다")
	var target: Dictionary = context.get("target",{})
	var instance: String = str(target.get("instance_id",""))
	if instance.is_empty() or bool(target.get("locked",false)): return denied("잠금을 해제한 실제 장비 개체를 선택하세요")
	var replacement: int = replacement_id(pack,str(target.get("source_id","")))
	if replacement <= 0: return denied("이 장비에는 원본 발동 교체 경로가 없습니다")
	if not target.get("state",{}) is Dictionary or not valid_state(target.get("state",{}).get("invoke_replacement",{})): return denied("저장된 발동 교체 상태를 확인하세요. 기존 기록을 보존합니다")
	var saved: Dictionary = target.get("state",{}).get("invoke_replacement",{})
	if not saved.is_empty() and (int(saved.get("source_id",0)) != int(target.get("source_id",0)) or str(saved.get("target_id","")) != instance): return denied("다른 장비 개체의 발동 교체 기록을 보호합니다")
	var policy: Dictionary = context.get("policy",{})
	var slot: int = int(policy.get("invoke_slot",context.get("invoke_slot",0)))
	var choices: Array = slots(pack,replacement).get(str(slot),[])
	if choices.size() <= 1: return denied("변경 가능한 발동 슬롯을 선택하세요. 기본 발동은 보존합니다")
	var sum: int = 0
	for row: Dictionary in choices:
		if int(row.get("Prob",-1)) < 0: return denied("발동 교체 확률이 잘못되었습니다")
		sum += int(row.get("Prob",0))
	if sum != 1000000: return denied("발동 교체 슬롯의 원본 확률 합계가 불완전합니다")
	var ticket: String = ""
	for material: Dictionary in context.get("materials",[]):
		var source: int = int(material.get("source_id",0))
		if source not in TICKET_IDS or bool(material.get("locked",false)): continue
		if int(material.get("amount",1)) < 1: continue
		if not ticket.is_empty(): return denied("마법 부여 주문서 한 종류를 명시적으로 선택하세요")
		ticket = str(source)
	if ticket.is_empty(): return denied("마법 부여 주문서 또는 각인 주문서가 필요합니다")
	var gold_cost: int = int(policy.get("invoke_gold_cost",0))
	if gold_cost < 0: return denied("발동 교체 비용 설정을 확인하세요")
	return {"ok":true,"kind":action,"target_id":instance,"costs":[{"source_id":ticket,"amount":1}],"gold_cost":gold_cost,
		"detail":"마법 부여 주문서 1장 · 선택 슬롯 %d · 슬롯 선택/추가 아데나: TWILIGHT 설정 · 원본 확률 유지 · 복합 주문/오라 결과의 실제 효과는 미연결일 수 있습니다" % slot,
		"_replacement":replacement,"_slot":slot,"_choices":choices.duplicate(true),"_target":target.duplicate(true)}

static func roll(pack: Dictionary, proposal: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not bool(proposal.get("ok",false)) or proposal.get("kind") != "invoke_replacement": return denied("발동 교체 견적을 먼저 확인하세요")
	var selected: Dictionary = C.weighted(proposal.get("_choices",[]),"Prob",rng)
	if selected.is_empty(): return denied("발동 교체 결과를 선택하지 못했습니다")
	var target: Dictionary = proposal.get("_target",{})
	var state: Dictionary = target.get("state",{}).get("invoke_replacement",{}).duplicate(true)
	if not state.is_empty() and int(state.get("replacement_id",0)) != int(proposal._replacement): return denied("저장된 발동 교체 계열과 원본 장비가 다릅니다")
	var selected_slots: Dictionary = state.get("slots",{}).duplicate(true)
	selected_slots[str(int(proposal._slot))] = {"group_id":int(selected.ItemInvokeReplacementBonusGroupID),"entity_id":int(selected.ID)}
	state = {"schema":"equipment523-invoke-v1","replacement_id":int(proposal._replacement),"source_id":int(target.get("source_id",0)),"target_id":str(target.get("instance_id","")),"source_sha256":str(pack.get("source_sha256","")),"slots":selected_slots}
	var group: Dictionary = C.find(pack,"ItemInvokeReplacementBonusGroup",int(selected.ItemInvokeReplacementBonusGroupID))
	return {"ok":true,"state":{"invoke_replacement":state},"detail":"발동 슬롯 %d · %s" % [int(proposal._slot),str(group.get("Name","미확인"))]}

static func equipped(pack: Dictionary, targets: Array, policy: Dictionary = {}, _now: int = 0) -> Dictionary:
	var records: Array[Dictionary] = []
	var details: Array = []
	var unique: Dictionary = {}
	var instances: Dictionary = {}
	for target: Dictionary in targets:
		if not bool(target.get("equipped",true)): continue
		var source: String = str(target.get("source_id",""))
		var physical: String = str(target.get("instance_id",""))
		if source.is_empty() or physical.is_empty() or instances.has(physical): continue
		instances[physical] = true
		unique[source] = true
	var mode: String = str(policy.get("set_threshold_mode","cumulative"))
	if mode not in ["cumulative","highest"]: return {"records":records,"details":[{"error":"장비 세트 문턱 설정을 확인하세요"}]}
	for definition: Dictionary in C.rows(pack,"ItemSet"):
		var set_id: int = int(definition.get("ID",0))
		var count: int = 0
		for member: Dictionary in C.rows(pack,"ItemForItemSet"):
			if int(member.get("ItemSetID",0)) == set_id and unique.has(str(int(member.get("ItemClassID",0)))): count += 1
		if count == 0: continue
		var threshold: int = 0
		for row: Dictionary in C.rows(pack,"ItemSetBonus"):
			if int(row.get("ItemSetID",0)) == set_id and int(row.get("CompletionDegree",0)) <= count: threshold = maxi(threshold,int(row.CompletionDegree))
		var bonus_ids: Array = []
		var missing: Array = []
		for row: Dictionary in C.rows(pack,"ItemSetBonus"):
			if int(row.get("ItemSetID",0)) != set_id or int(row.get("CompletionDegree",0)) > count: continue
			if mode == "highest" and int(row.CompletionDegree) != threshold: continue
			var id: int = int(row.get("BonusID",0))
			bonus_ids.append(id)
			if not bool(C.bonus(pack,id).get("supported",false)): missing.append(id)
		records.append_array(C.effect_records(pack,bonus_ids))
		details.append({"set_id":set_id,"name":str(definition.get("Name","")),"count":count,"threshold":threshold,"threshold_policy":mode,"bonus_ids":bonus_ids,"unconnected_bonus_ids":missing,"unconnected_buff_id":int(definition.get("BuffClassID",0))})
	return {"records":records,"details":details}

static func effects(pack: Dictionary, target: Dictionary, policy: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not target.get("state",{}) is Dictionary or not valid_state(target.get("state",{}).get("invoke_replacement",{})): return result
	var state: Dictionary = target.get("state",{}).get("invoke_replacement",{})
	var replacement: int = replacement_id(pack,str(target.get("source_id","")))
	if state.get("schema") != "equipment523-invoke-v1" or int(state.get("replacement_id",0)) != replacement: return result
	if int(state.get("source_id",0)) != int(target.get("source_id",0)) or str(state.get("target_id","")) != str(target.get("instance_id","")): return result
	if str(state.get("source_sha256","")) != str(pack.get("source_sha256","")): return result
	var available: Dictionary = slots(pack,replacement)
	for key: Variant in state.get("slots",{}):
		var choice: Variant = state.slots[key]
		if not choice is Dictionary or not available.has(str(key)): continue
		var rows: Array = available[str(key)]
		if rows.size() <= 1: continue
		var valid: bool = false
		for row: Dictionary in rows:
			if int(row.get("ID",0)) == int(choice.get("entity_id",0)) and int(row.get("ItemInvokeReplacementBonusGroupID",0)) == int(choice.get("group_id",0)): valid = true
		if not valid: continue
		var group_id: int = int(choice.group_id)
		var level: int = int(target.get("level",0))
		var bless: int = int(target.get("bless_code",1))
		var exact: Array[Dictionary] = []
		var defaults: Array[Dictionary] = []
		for link: Dictionary in C.rows(pack,"ItemInvokeReplacementBonus"):
			if int(link.get("ItemInvokeReplacementBonusGroupID",0)) != group_id: continue
			if int(link.get("BlessCode",-1)) != bless and not (int(link.get("BlessCode",-1)) == 0 and bool(policy.get("invoke_zero_bless_selector",true))): continue
			if int(link.get("EnchantLevel",-1)) == level: exact.append(link)
			elif int(link.get("EnchantLevel",-1)) == 0: defaults.append(link)
		var chosen: Array[Dictionary] = exact
		if chosen.is_empty() and bool(policy.get("invoke_zero_level_fallback",true)): chosen = defaults
		for link: Dictionary in chosen:
			var value: Dictionary = C.bonus(pack,int(link.get("BonusID",0)))
			var raw: Dictionary = value.get("raw",{})
			if value.get("type",{}).get("Name","") != "InvokeOption" or int(value.get("type",{}).get("UnitID",0)) != 3 or int(raw.get("BonusApplicationTypeID",0)) != 10: continue
			var option: Dictionary = C.find(pack,"InvokeOption",int(raw.get("BonusApplicationTargetID",0)))
			if option.is_empty(): continue
			result.append({"instance_id":str(target.get("instance_id","")),"slot":int(key),"group_id":group_id,"bonus_id":int(link.BonusID),"link":link,"probability":int(raw.get("Value",0)),"option":option,"zero_level_fallback":exact.is_empty()})
	return result

static func _spell_values(pack: Dictionary, spell_id: int) -> Dictionary:
	var values: Dictionary = {}
	for link: Dictionary in C.rows(pack,"SpellBonus"):
		if int(link.get("SpellClassID",0)) != spell_id: continue
		if int(link.get("MinSpellLevel",0)) != 0: return {}
		var value: Dictionary = C.bonus(pack,int(link.get("BonusID",0)))
		var raw: Dictionary = value.get("raw",{})
		var name: String = str(value.get("type",{}).get("Name",""))
		if int(raw.get("BonusApplicationTypeID",-1)) != 0 or int(raw.get("BonusApplicationTargetID",-1)) != 0 or name.is_empty() or values.has(name): return {}
		var units: Dictionary = {"SpellDamageBase":1,"SpellDamageDiceNumber":1,"SpellDamageDiceSpotCount":1,"FixedMagicDamage":20,"IgnoreMagicResistance":20,"IgnoreDamageReductionCalculation":1}
		if not units.has(name) or int(value.get("type",{}).get("UnitID",0)) != int(units[name]): return {}
		values[name] = raw.get("Value",0)
	return values

static func spell_contract(pack: Dictionary, option: Dictionary) -> Dictionary:
	if int(option.get("InvokeOptionTypeID",0)) != 1: return denied("오라·특수 발동은 별도 실행 계약이 필요합니다")
	for key: String in ["Param2","Param3","Param5","Param6","MaterialTypeID","MaterialAmount","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:
		if int(option.get(key,0)) != 0: return denied("조건부 발동은 아직 연결되지 않았습니다")
	var spell: Dictionary = C.find(pack,"SpellClass",int(option.get("Param1",0)))
	if spell.is_empty() or bool(spell.get("TestSpell",false)): return denied("발동 주문 원본이 없습니다")
	for key: String in ["HPCost","MPCost","VPCost","SpellMaterialItemAmount","TargetAreaRadius","SpellCompositionNode","CopySpellClassID"]:
		if int(spell.get(key,0)) != 0: return denied("대상 범위·비용·연쇄 주문은 아직 연결되지 않았습니다")
	if int(spell.get("TargettingTypeID",0)) != 2: return denied("적 단일 대상 발동만 연결합니다")
	var values: Dictionary = _spell_values(pack,int(spell.ID))
	var allowed: Array[String] = ["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount","FixedMagicDamage","IgnoreMagicResistance","IgnoreDamageReductionCalculation"]
	if values.size() != allowed.size(): return denied("복합 주문 효과는 아직 연결되지 않았습니다")
	for key: String in allowed:
		if not values.has(key): return denied("발동 주문 수치가 불완전합니다")
	if int(values.FixedMagicDamage) != 1 or int(values.IgnoreMagicResistance) != 1 or int(values.IgnoreDamageReductionCalculation) != 1: return denied("비고정 주문 공식은 아직 연결되지 않았습니다")
	if int(values.SpellDamageBase) < 0 or int(values.SpellDamageDiceNumber) < 0 or int(values.SpellDamageDiceNumber) > 100 or int(values.SpellDamageDiceSpotCount) < 1: return denied("발동 주문 주사위가 잘못되었습니다")
	return {"ok":true,"spell":spell,"values":values}

static func on_hit(pack: Dictionary, world: Node, targets: Array, policy: Dictionary, victim: Node, attack_kind: String, main_target: bool, by_spell: bool) -> Array:
	var fired: Array = []
	if _busy or not is_instance_valid(victim) or bool(victim.get("dead")): return fired
	_busy = true
	var seen: Dictionary = {}
	for target: Dictionary in targets:
		if not bool(target.get("equipped",true)): continue
		var instance: String = str(target.get("instance_id",""))
		if instance.is_empty() or seen.has(instance): continue
		seen[instance] = true
		for effect: Dictionary in effects(pack,target,policy):
			var option: Dictionary = effect.option
			if bool(option.get("BySpellAttack",false)) != by_spell or bool(option.get("Param4",false)) and not main_target: continue
			var attack: int = int(option.get("AttackTypeID",0))
			if attack != 0 and attack != int({"melee":1,"ranged":2,"magic":3}.get(attack_kind,-1)): continue
			var contract: Dictionary = spell_contract(pack,option)
			if not bool(contract.get("ok",false)): continue
			var spell: Dictionary = contract.spell
			var cooldown: String = "equipment523-invoke|%s|%d" % [instance,int(spell.ID)]
			if float(world.skill_cooldowns.get(cooldown,0)) > 0: continue
			if world.has_method("_world_to_cell") and int(spell.get("CastRange",0)) > 0:
				var delta: Vector2i = world._world_to_cell(world.player.global_position) - world._world_to_cell(victim.global_position)
				if maxi(absi(delta.x),absi(delta.y)) > int(spell.CastRange): continue
			if world.has_method("_has_line_of_sight_world") and not world._has_line_of_sight_world(world.player.global_position,victim.global_position): continue
			var chance: int = int(effect.probability)
			if chance < 0 or chance > 1000000 or world.rng.randi_range(0,999999) >= chance: continue
			var values: Dictionary = contract.values
			var damage: int = int(values.SpellDamageBase)
			for _die: int in range(int(values.SpellDamageDiceNumber)): damage += world.rng.randi_range(1,int(values.SpellDamageDiceSpotCount))
			victim.take_damage(damage,false,"magic")
			world.skill_cooldowns[cooldown] = float(spell.get("CastDelay",0))/1000.0
			fired.append({"instance_id":instance,"slot":int(effect.slot),"spell_id":int(spell.ID),"damage":damage,"bonus_id":int(effect.bonus_id)})
			_emit_spell(world,spell,victim)
			if bool(victim.get("dead")):
				_busy = false
				return fired
	_busy = false
	return fired

static func _emit_spell(world: Node, spell: Dictionary, victim: Node) -> void:
	# Use the already installed private compositor when it is available.
	# An absent binding is not replaced with fabricated original art.
	var awakening: Variant = null
	for property: Dictionary in world.get_property_list():
		if property.get("name","") == "option_awakening": awakening = world.get("option_awakening")
	if awakening == null: return
	var combat: Variant = null
	for property: Dictionary in awakening.get_property_list():
		if property.get("name","") == "combat": combat = awakening.get("combat")
	if combat != null and combat.has_method("emit_spell"): combat.call("emit_spell",spell,victim)
