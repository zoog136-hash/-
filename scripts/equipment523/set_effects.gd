extends RefCounted
## Additional set contracts. Every value comes from typed source rows; runtime
## clocks are owned by one equipment service, never by an individual copy.
const C = preload("res://scripts/equipment523/common.gd")
const CHANNELS: Array[String] = ["fire", "water", "wind", "earth"]
const FLAGS: Dictionary = {"CanSenseInvisibility":"invisibility", "RevealDoppelPolymorphChange":"doppel", "RevealCamouflage":"camouflage"}
var current: Dictionary = {}
var guard: Dictionary = {}
var cooldowns: Dictionary = {}
var markers: Dictionary = {}
var locks: Dictionary = {}
var source_sha: String = ""
var _busy: bool = false
var _visual_events: Array[Dictionary] = []

func _remove_guard(reason: String) -> void:
	if guard.is_empty(): return
	var visual: Dictionary = guard.get("removal_visual",{})
	if int(visual.get("Value",0)) > 0:
		# Removal supplies a SpriteID, not an action. The existing compositor
		# must resolve a verified unambiguous source action or report unavailable.
		_visual_events.append({"kind":"guard_removed","reason":reason,"buff_id":int(guard.get("buff_id",0)),"spell":{"ID":0,"OnBuffRemovedEffectSpriteID":int(visual.Value)},"field":"OnBuffRemovedEffectSpriteID"})
	guard.clear()

func drain_visual_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = _visual_events
	_visual_events = []
	return events

func bind_guard_visual(pack: Dictionary) -> void:
	# Saves contain clocks and identities, never renderer selectors. Rebuild
	# the removal selector before expiry/death can consume a restored clock.
	if guard.is_empty() or source_sha != str(pack.get("source_sha256","")): return
	var selector: Dictionary = _typed(pack,int(guard.get("bonus_id",0)),"HPIntervalBonus",10674)
	if selector.is_empty(): return
	var parsed: Dictionary = interval_contract(pack,selector)
	if not bool(parsed.get("ok",false)): return
	if int(guard.get("buff_id",0)) != int(parsed.interval.buff.ID): return
	guard.removal_visual = parsed.interval.removal_visual.duplicate(true)

static func _typed(pack: Dictionary, id: int, name: String, unit: int, application: int = 0, target: int = 0) -> Dictionary:
	var value: Dictionary = C.bonus(pack,id)
	var raw: Dictionary = value.get("raw",{})
	var kind: Dictionary = value.get("type",{})
	if int(raw.get("ID",0)) != id or kind.get("Name","") != name or int(kind.get("UnitID",-1)) != unit: return {}
	if int(raw.get("BonusTypeID",0)) != int(kind.get("ID",0)): return {}
	if int(raw.get("BonusApplicationTypeID",-1)) != application or int(raw.get("BonusApplicationTargetID",-1)) != target: return {}
	return raw

static func _error(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func _policy_number_valid(policy: Dictionary, key: String, default_value: float, positive: bool = false) -> bool:
	var value: Variant = policy.get(key,default_value)
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and (float(value) > 0.0 if positive else float(value) >= 0.0)

static func _spell_values(pack: Dictionary, id: int) -> Dictionary:
	var values: Dictionary = {}
	for row: Dictionary in C.rows(pack,"SpellBonus"):
		if int(row.get("SpellClassID",0)) != id: continue
		if int(row.get("MinSpellLevel",-1)) != 0: return {}
		var bonus: Dictionary = C.bonus(pack,int(row.get("BonusID",0)))
		var raw: Dictionary = bonus.get("raw",{})
		var name: String = str(bonus.get("type",{}).get("Name",""))
		if raw.is_empty() or name.is_empty() or values.has(name): return {}
		if int(raw.get("BonusApplicationTypeID",-1)) != 0 or int(raw.get("BonusApplicationTargetID",-1)) != 0: return {}
		values[name] = {"raw":raw,"type":bonus.get("type",{}),"link":row}
	return values

static func _spell(pack: Dictionary, id: int, targetting: int) -> Dictionary:
	var spell: Dictionary = C.find(pack,"SpellClass",id)
	if spell.is_empty() or bool(spell.get("TestSpell",false)) or int(spell.get("TargettingTypeID",0)) != targetting: return {}
	for key: String in ["HPCost","MPCost","VPCost","SpellMaterialItemAmount","TargetAreaRadius","CopySpellClassID","SpellCompositionNode"]:
		if int(spell.get(key,0)) != 0: return {}
	return spell

static func _value(values: Dictionary, name: String, unit: int) -> int:
	var entry: Dictionary = values.get(name,{})
	if int(entry.get("type",{}).get("UnitID",-1)) != unit: return -1
	return int(entry.get("raw",{}).get("Value",-1))

static func _option(pack: Dictionary, raw: Dictionary, kind: int) -> Dictionary:
	var option: Dictionary = C.find(pack,"InvokeOption",int(raw.get("BonusApplicationTargetID",0)))
	if option.is_empty() or int(option.get("InvokeOptionTypeID",0)) != kind: return {}
	for key: String in ["Param2","Param5","Param6","MaterialTypeID","MaterialAmount","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:
		if int(option.get(key,0)) != 0: return {}
	return option

static func yahi_contract(pack: Dictionary, raw: Dictionary) -> Dictionary:
	var option: Dictionary = _option(pack,raw,1)
	if option.is_empty() or int(option.get("Param3",0)) != 0: return _error("set invoke option contract")
	var spell: Dictionary = _spell(pack,int(option.get("Param1",0)),2)
	var values: Dictionary = _spell_values(pack,int(spell.get("ID",0)))
	if values.size() != 4: return _error("set target spell graph")
	var buff_id: int = _value(values,"BuffClassID",16)
	var duration: int = _value(values,"SpellDebuffMinDuration",17)
	if duration <= 0 or duration != _value(values,"SpellDebuffMaxDuration",17): return _error("set debuff duration")
	var next_spell: Dictionary = _spell(pack,_value(values,"NextSpellClassID",12),1)
	var next_values: Dictionary = _spell_values(pack,int(next_spell.get("ID",0)))
	if next_values.size() != 2 or _value(next_values,"SpellBuffDuration",17) != duration: return _error("set self buff graph")
	var self_buff_id: int = _value(next_values,"BuffClassID",16)
	var buff: Dictionary = C.find(pack,"BuffClass",buff_id)
	var self_buff: Dictionary = C.find(pack,"BuffClass",self_buff_id)
	if buff.is_empty() or self_buff.is_empty() or bool(buff.get("IsGood",true)) or not bool(self_buff.get("IsGood",false)): return _error("set buff ownership")
	var reduction: int = 0
	var stack_rows: Array = []
	for stack: Dictionary in C.rows(pack,"BuffStack"):
		if int(stack.get("BuffClassID",0)) != buff_id: continue
		if int(stack.get("StackCount",0)) != 1 or bool(stack.get("isAdditionalStack",true)): return _error("set stack behavior")
		for row: Dictionary in C.rows(pack,"BuffStackBonus"):
			if int(row.get("BuffStackID",0)) != int(stack.ID): continue
			var effect: Dictionary = _typed(pack,int(row.get("BonusID",0)),"PVPDamageReduction",1)
			if effect.is_empty(): return _error("set stack effect")
			reduction += int(effect.Value)
			stack_rows.append(row)
	if stack_rows.size() != 1 or reduction >= 0: return _error("set stack reduction")
	# No hidden numeric effect may be silently dropped from either buff.
	for row: Dictionary in C.rows(pack,"BuffBonus"):
		if int(row.get("BuffClassID",0)) in [buff_id,self_buff_id]: return _error("unexpected set buff bonus")
	return {"ok":true,"option":option,"spell":spell,"buff":buff,"self_buff":self_buff,"next_spell":next_spell,"duration":duration,"reduction":reduction,"stack_rows":stack_rows}

static func interval_contract(pack: Dictionary, raw: Dictionary) -> Dictionary:
	var category_id: int = int(raw.get("Value",0))
	var category: Dictionary = C.find(pack,"IntervalBonusCategory",category_id)
	if category.is_empty(): return _error("missing HP interval category")
	var intervals: Array = []
	for row: Dictionary in C.rows(pack,"IntervalBonus"):
		if int(row.get("IntervalBonusCategory",0)) != category_id: continue
		var id: int = int(row.get("BonusID",0))
		var bonus: Dictionary = C.bonus(pack,id)
		var effect: Dictionary = _typed(pack,id,"InvokeOption",3,10,int(bonus.get("raw",{}).get("BonusApplicationTargetID",0)))
		if effect.is_empty() or int(effect.get("Value",0)) != 1000000: return _error("HP interval probability")
		var option: Dictionary = _option(pack,effect,2)
		if option.is_empty() or int(option.get("Param3",0)) != 1: return _error("defensive invoke contract")
		var spell: Dictionary = _spell(pack,int(option.get("Param1",0)),1)
		var values: Dictionary = _spell_values(pack,int(spell.get("ID",0)))
		if values.size() != 2: return _error("guard spell graph")
		var duration: int = _value(values,"SpellBuffDuration",17)
		var buff_id: int = _value(values,"BuffClassID",16)
		var buff: Dictionary = C.find(pack,"BuffClass",buff_id)
		var hits: int = 0
		var group_id: int = 0
		var visual: Dictionary = {}
		var status_id: int = 0
		var seen: Dictionary = {}
		for link: Dictionary in C.rows(pack,"BuffBonus"):
			if int(link.get("BuffClassID",0)) != buff_id: continue
			for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
				if int(link.get(key,0)) != 0: return _error("guard conditional buff")
			var entry: Dictionary = C.bonus(pack,int(link.get("BonusID",0)))
			var effect_raw: Dictionary = entry.get("raw",{})
			var name: String = str(entry.get("type",{}).get("Name",""))
			if seen.has(name): return _error("guard duplicate effect")
			seen[name] = true
			match name:
				"CounterAssult":
					group_id = int(effect_raw.get("BonusApplicationTargetID",0))
					if _typed(pack,int(link.BonusID),name,1,381,group_id).is_empty(): return _error("guard hit count type")
					hits = int(effect_raw.get("Value",0))
				"StatusEffectID":
					if _typed(pack,int(link.BonusID),name,121).is_empty(): return _error("guard status type")
					status_id = int(effect_raw.get("Value",0))
				"OnBuffRemovedEffectSpriteID":
					if _typed(pack,int(link.BonusID),name,21).is_empty(): return _error("guard removal visual type")
					visual = effect_raw
				_: return _error("unknown guard effect")
		var attack_types: Array = []
		for member: Dictionary in C.rows(pack,"UniversalGroupSet"):
			if int(member.get("GroupID",0)) != group_id: continue
			if int(member.get("UnitID",0)) != 10431: return _error("guard group member type")
			var attack: int = int(member.get("Value",0))
			if attack not in [1,2,52,62] or attack_types.has(attack): return _error("unsupported guard attack type")
			attack_types.append(attack)
		if buff.is_empty() or duration <= 0 or hits <= 0 or attack_types.size() != 4 or seen.size() != 3: return _error("incomplete guard graph")
		var low: float = float(row.get("Low",-1))
		var high: float = float(row.get("High",-1))
		if low < 0 or high > 100 or high < low: return _error("invalid HP interval")
		intervals.append({"row":row,"category":category,"option":option,"spell":spell,"buff":buff,"duration":duration,"hits":hits,"attack_types":attack_types,"low":low,"high":high,"status_id":status_id,"removal_visual":visual})
	if intervals.size() != 1: return _error("ambiguous HP interval")
	return {"ok":true,"interval":intervals[0]}

static func contract(pack: Dictionary, link: Dictionary) -> Dictionary:
	var id: int = int(link.get("BonusID",0))
	var entry: Dictionary = C.bonus(pack,id)
	var raw: Dictionary = entry.get("raw",{})
	var name: String = str(entry.get("type",{}).get("Name",""))
	var result: Dictionary = {}
	match name:
		"ElementalResistance":
			if int(raw.get("BonusApplicationTargetID",0)) != 5: return {}
			if _typed(pack,id,name,3,3,5).is_empty(): return _error("all-element resistance type")
			result = {"kind":"stat","record":{"element_resist_all":float(raw.Value)/10000.0}}
		"HitSpecialResistance":
			if int(raw.get("BonusApplicationTargetID",0)) != 8: return {}
			if _typed(pack,id,name,3,2,8).is_empty(): return _error("fear accuracy type")
			result = {"kind":"stat","record":{"fear_accuracy":float(raw.Value)/10000.0}}
		"CastSpeedBonus":
			if _typed(pack,id,name,3).is_empty(): return _error("cast speed type")
			result = {"kind":"stat","record":{"equipment523_set_cast_speed_pct":float(raw.Value)/10000.0}}
		"AttackDrainHP", "AttackDrainMP":
			if _typed(pack,id,name,1).is_empty() or int(raw.Value) < 0: return _error("attack drain type")
			result = {"kind":"drain","resource":"hp" if name == "AttackDrainHP" else "mp","value":int(raw.Value)}
		"CanSenseInvisibility", "RevealDoppelPolymorphChange", "RevealCamouflage":
			if _typed(pack,id,name,20).is_empty() or int(raw.Value) not in [0,1]: return _error("reveal flag type")
			result = {"kind":"reveal","flag":FLAGS[name],"enabled":int(raw.Value) == 1}
		"FixedDesc":
			if _typed(pack,id,name,41,72,int(raw.get("BonusApplicationTargetID",0))).is_empty(): return _error("description type")
			var caption: Dictionary = C.find(pack,"DescData_Korean",int(raw.get("BonusApplicationTargetID",0)))
			result = {"kind":"description","description_id":int(raw.get("BonusApplicationTargetID",0)),"description":str(caption.get("Description",""))}
		"InvokeOption":
			if _typed(pack,id,name,3,10,int(raw.get("BonusApplicationTargetID",0))).is_empty() or int(raw.get("Value",-1)) < 0 or int(raw.get("Value",0)) > 1000000: return _error("set invoke type")
			result = yahi_contract(pack,raw)
			if not bool(result.get("ok",false)): return result
			result.kind = "invoke"
			result.probability = int(raw.Value)
		"HPIntervalBonus":
			if _typed(pack,id,name,10674).is_empty(): return _error("HP interval selector type")
			result = interval_contract(pack,raw)
			if not bool(result.get("ok",false)): return result
			result.kind = "interval"
		"BuffClassID":
			if _typed(pack,id,name,16).is_empty(): return _error("set buff type")
			var buff: Dictionary = C.find(pack,"BuffClass",int(raw.get("Value",0)))
			if buff.is_empty(): return _error("missing set buff")
			for row: Dictionary in C.rows(pack,"BuffBonus"):
				if int(row.get("BuffClassID",0)) == int(buff.ID): return _error("unexpected marker buff stats")
			result = {"kind":"marker","buff":buff}
		_: return {}
	result.ok = true
	result.bonus_id = id
	result.raw = raw
	result.link = link
	result.set_id = int(link.get("ItemSetID",0))
	return result

static func contracts(pack: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in C.rows(pack,"ItemSetBonus"):
		var value: Dictionary = contract(pack,row)
		if not value.is_empty(): out.append(value)
	return out

static func resolve(pack: Dictionary, targets: Array, policy: Dictionary = {}) -> Dictionary:
	# The verified pack is immutable. Runtime-only indexes/cache never enter the
	# private source file or saves. A changed physical membership invalidates it.
	var identities: Array[String] = []
	for target: Variant in targets:
		if target is Dictionary:
			identities.append(JSON.stringify([str(target.get("instance_id","")),int(target.get("source_id",0)),bool(target.get("equipped",true)),int(target.get("level",0)),int(target.get("bless_code",0))]))
	identities.sort()
	var signature: String = JSON.stringify([pack.get("source_sha256",""),pack.get("equipment523_effect_audit",{}),identities,policy.get("set_threshold_mode","cumulative")])
	var cached: Dictionary = pack.get("_equipment523_set_cache",{})
	if cached.get("signature","") == signature: return cached.value
	var result: Dictionary = _resolve(pack,targets,policy)
	pack["_equipment523_set_cache"] = {"signature":signature,"value":result}
	return result

static func _resolve(pack: Dictionary, targets: Array, policy: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"records":[],"capabilities":{},"invokes":[],"intervals":[],"buffs":[],"drains":[],"diagnostics":[],"set_ids":[]}
	var mode: String = str(policy.get("set_threshold_mode","cumulative"))
	if mode not in ["cumulative","highest"]:
		out.diagnostics.append("invalid set threshold policy")
		return out
	var sources: Dictionary = {}
	var physical: Dictionary = {}
	for value: Variant in targets:
		if not value is Dictionary or not bool(value.get("equipped",true)): continue
		var instance: String = str(value.get("instance_id",""))
		var source: int = int(value.get("source_id",0))
		if instance.is_empty() or source <= 0 or physical.has(instance) or C.item(pack,source).is_empty(): continue
		physical[instance] = true
		sources[source] = true
	for definition: Dictionary in C.rows(pack,"ItemSet"):
		var set_id: int = int(definition.get("ID",0))
		if bool(definition.get("IsTest",false)) or str(definition.get("Name","")).contains("[테스트]"): continue
		var count: int = 0
		var membership: Dictionary = {}
		for member: Dictionary in C.rows(pack,"ItemForItemSet"):
			if int(member.get("ItemSetID",0)) != set_id: continue
			var source: int = int(member.get("ItemClassID",0))
			if membership.has(source): continue
			membership[source] = true
			if sources.has(source) and not bool(C.item(pack,source).get("raw",{}).get("TestItem",false)): count += 1
		if count == 0: continue
		var threshold: int = 0
		for link: Dictionary in C.rows(pack,"ItemSetBonus"):
			if int(link.get("ItemSetID",0)) == set_id and int(link.get("CompletionDegree",0)) <= count: threshold = maxi(threshold,int(link.CompletionDegree))
		if threshold <= 0: continue
		out.set_ids.append(set_id)
		for link: Dictionary in C.rows(pack,"ItemSetBonus"):
			if int(link.get("ItemSetID",0)) != set_id or int(link.get("CompletionDegree",0)) > count: continue
			if mode == "highest" and int(link.CompletionDegree) != threshold: continue
			var effect: Dictionary = contract(pack,link)
			if effect.is_empty(): continue
			if not bool(effect.get("ok",false)):
				out.diagnostics.append({"set_id":set_id,"bonus_id":int(link.BonusID),"error":effect.get("error","")})
				continue
			effect["count"] = count
			match str(effect.kind):
				"stat":
					var record: Dictionary = effect.record.duplicate(true)
					record.merge({"equipment523_synthetic":true,"equipment523_bonus_id":int(effect.bonus_id),"equipment523_set_id":set_id,"name":"세트 효과 · " + str(definition.get("Name",""))})
					out.records.append(record)
				"reveal": out.capabilities[effect.flag] = bool(out.capabilities.get(effect.flag,false)) or bool(effect.enabled)
				"invoke": out.invokes.append(effect)
				"interval": out.intervals.append(effect)
				"marker":
					if int(definition.get("BuffClassID",0)) != int(effect.buff.ID): out.diagnostics.append("set marker definition mismatch")
					else: out.buffs.append(effect)
				"drain": out.drains.append(effect)
	return out

static func cast_speed(records: Array) -> float:
	var total: float = 0.0
	for record: Dictionary in records: total += float(record.get("equipment523_set_cast_speed_pct",0))
	return total

static func _guard_trigger_allowed(interval: Dictionary, policy: Dictionary, context: Dictionary) -> bool:
	if not bool(context.get("incoming_event",false)): return false
	var option: Dictionary = interval.option
	if int(option.get("Param3",0)) == 1 and not bool(context.get("attacker_is_pc",false)) and not bool(policy.get("set_pvp_targets_as_pve",false)): return false
	if bool(option.get("BySpellAttack",false)) != bool(context.get("by_spell",false)): return false
	var selector: int = int(option.get("AttackTypeID",0))
	if selector != 0 and selector != int({"melee":1,"ranged":2,"magic":3}.get(str(context.get("attack_kind","")),0)): return false
	return bool(context.get("landed",true)) or option.get("Param4") == true

func sync(pack: Dictionary, targets: Array, policy: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var sha: String = str(pack.get("source_sha256",""))
	if not source_sha.is_empty() and source_sha != sha: clear()
	source_sha = sha
	current = resolve(pack,targets,policy).duplicate(false)
	current.diagnostics = current.diagnostics.duplicate()
	var alive: bool = bool(context.get("alive",true))
	var chosen: Dictionary = {}
	for candidate: Dictionary in current.intervals:
		if chosen.is_empty() or int(candidate.link.CompletionDegree) > int(chosen.link.CompletionDegree): chosen = candidate
	# These intervals are alternative stages of one group, not cumulative casts.
	# Choosing the highest achieved stage is an explicit TWILIGHT policy.
	if str(policy.get("set_interval_overlap","highest")) != "highest":
		chosen = {}
		current.diagnostics.append("unsupported interval overlap policy")
	if not guard.is_empty() and (chosen.is_empty() or int(guard.get("bonus_id",0)) != int(chosen.bonus_id) or not alive): _remove_guard("source_condition_lost")
	if not guard.is_empty():
		var trusted: Dictionary = chosen.interval
		# Save payloads preserve clocks, never their own effect values or selectors.
		if int(guard.get("set_id",0)) != int(chosen.set_id) or int(guard.get("buff_id",0)) != int(trusted.buff.ID): _remove_guard("source_identity_rejected")
		else:
			guard.remaining = clampf(float(guard.get("remaining",0)),0.0,float(trusted.duration))
			guard.hits = clampi(int(guard.get("hits",0)),0,int(trusted.hits))
			guard.attack_types = trusted.attack_types.duplicate()
			guard.status_id = int(trusted.status_id)
			guard.removal_visual = trusted.removal_visual.duplicate(true)
			if float(guard.remaining) <= 0 or int(guard.hits) <= 0: _remove_guard("expired_or_exhausted")
	var max_hp: int = int(context.get("max_hp",0))
	var hp_percent: float = 100.0 * float(context.get("hp",0)) / float(max_hp) if max_hp > 0 else -1.0
	if alive and not chosen.is_empty() and guard.is_empty() and _guard_trigger_allowed(chosen.interval,policy,context):
		var interval: Dictionary = chosen.interval
		var key: String = "group:" + str(int(interval.buff.get("BuffGroupID",0)))
		var divisor_valid: bool = _policy_number_valid(policy,"set_interval_cast_delay_divisor",1000.0,true)
		var divisor: float = float(policy.get("set_interval_cast_delay_divisor",1000.0)) if divisor_valid else 0.0
		if not divisor_valid:
			current.diagnostics.append("invalid guard CastDelay conversion policy")
		elif hp_percent >= float(interval.low) and hp_percent <= float(interval.high) and float(cooldowns.get(key,0)) <= 0:
			guard = {"bonus_id":int(chosen.bonus_id),"set_id":int(chosen.set_id),"buff_id":int(interval.buff.ID),"remaining":float(interval.duration),"hits":int(interval.hits),"attack_types":interval.attack_types.duplicate(),"status_id":int(interval.status_id),"removal_visual":interval.removal_visual.duplicate(true)}
			cooldowns[key] = float(interval.spell.get("CastDelay",0))/divisor
			_visual_events.append({"kind":"guard_created","buff_id":int(interval.buff.ID),"spell":interval.spell.duplicate(true),"field":"EffectSpriteID"})
	var prior_markers: Dictionary = markers
	markers = {}
	for marker: Dictionary in current.buffs:
		if bool(context.get("zone_allowed",false)):
			var key: String = str(int(marker.buff.ID))
			if alive or prior_markers.has(key) and marker.buff.get("IsImmuneToDead") == true:
				markers[key] = {"set_id":int(marker.set_id),"buff_id":int(marker.buff.ID),"raw":marker.buff.duplicate(true),"numeric_effects":0}
		else: current.diagnostics.append({"set_id":int(marker.set_id),"error":"set aura requires an eligible source siege zone"})
	var active_invokes: Dictionary = {}
	for effect: Dictionary in current.invokes: active_invokes[str(int(effect.set_id))+":"+str(int(effect.bonus_id))] = true
	for key: String in locks.keys():
		# Source rows do not specify equipment-detach lifetime. Keep the
		# existing local detach policy explicit and check its exact effect,
		# rather than a lower threshold of the same set.
		var available: bool = active_invokes.has(str(int(locks[key].get("set_id",0)))+":"+str(int(locks[key].get("bonus_id",0))))
		if not alive or policy.get("set_yahi_detach_mode","effect_unavailable") == "effect_unavailable" and not available: _remove_lock(key)
	return current

func advance(delta: float) -> void:
	var elapsed: float = maxf(0.0,delta)
	for key: String in cooldowns.keys(): cooldowns[key] = maxf(0.0,float(cooldowns[key])-elapsed)
	if not guard.is_empty():
		guard.remaining = maxf(0.0,float(guard.get("remaining",0))-elapsed)
		if float(guard.remaining) <= 0 or int(guard.get("hits",0)) <= 0: _remove_guard("expired_or_exhausted")
	for key: String in locks.keys():
		locks[key].remaining = maxf(0.0,float(locks[key].get("remaining",0))-elapsed)
		var target: Node = locks[key].target.get_ref()
		if float(locks[key].remaining) <= 0 or not is_instance_valid(target) or bool(target.get("dead")) or int(target.get("life_id")) != int(locks[key].life_id): _remove_lock(key)

func incoming(attack_kind: String, by_spell: bool = false, attacker_is_pc: bool = false, policy: Dictionary = {}, landed: bool = true) -> bool:
	if not attacker_is_pc and not bool(policy.get("set_pvp_targets_as_pve",false)): return false
	# Param4 allows a missed attack to trigger the defensive spell. The
	# original does not define whether a miss spends CounterAssult charges;
	# this policy spends a charge only for a landed hit actually prevented.
	if not landed and policy.get("set_guard_miss_consumption","landed_only") != "all_attempts": return false
	var attack: int = int({"melee":52 if by_spell else 1,"ranged":62 if by_spell else 2,"magic":3}.get(attack_kind,0))
	if guard.is_empty() or float(guard.get("remaining",0)) <= 0 or int(guard.get("hits",0)) <= 0 or not guard.get("attack_types",[]).has(attack): return false
	guard.hits = int(guard.hits)-1
	if int(guard.hits) == 0: _remove_guard("exhausted")
	return true

func locked_target() -> Node:
	for key: String in locks:
		var target: Node = locks[key].target.get_ref()
		if bool(locks[key].get("enforce_lock",true)) and is_instance_valid(target) and not bool(target.get("dead")) and int(target.get("life_id")) == int(locks[key].life_id): return target
	return null

func _remove_lock(key: String) -> void:
	var lock: Dictionary = locks.get(key,{})
	var status: Variant = lock.get("status")
	var target: Node = lock.target.get_ref() if lock.has("target") else null
	if status != null and is_instance_valid(target): status.remove_modifiers(target,key)
	locks.erase(key)

func on_hit(world: Node, pack: Dictionary, targets: Array, policy: Dictionary, victim: Node, attack_kind: String, main_target: bool = true, by_spell: bool = false, _available_hp: int = -1, _available_mp: int = -1) -> Array:
	var fired: Array = []
	if _busy or not is_instance_valid(victim): return fired
	for key: String in ["set_drain_hp_per_point","set_drain_mp_per_point"]:
		if not _policy_number_valid(policy,key,0.0):
			current["diagnostics"] = current.get("diagnostics",[]).duplicate()
			current.diagnostics.append({"error":"invalid numeric set drain policy","field":key})
			return fired
	_busy = true
	var active: Dictionary = resolve(pack,targets,policy)
	if not by_spell and attack_kind in ["melee","ranged"]:
		for drain: Dictionary in active.drains:
			var resource: String = str(drain.resource)
			# The original supplies a value, not a recovered drain formula.
			var coefficient: float = maxf(0.0,float(policy.get("set_drain_" + resource + "_per_point",0.0)))
			var amount: int = maxi(0,int(floor(float(drain.value)*coefficient)))
			if amount <= 0 or bool(victim.get("dead")): continue
			if resource == "hp":
				var before: int = maxi(0,int(victim.get("hp")))
				victim.take_damage(mini(before,amount),false,attack_kind)
				amount = maxi(0,before-maxi(0,int(victim.get("hp"))))
				world.hp = mini(world._effective_max_hp(),int(world.hp)+amount)
			else:
				amount = mini(maxi(0,int(victim.get("mp"))),amount)
				victim.mp = int(victim.mp)-amount
				world.mp = mini(world._effective_max_mp(),int(world.mp)+amount)
			if amount > 0: fired.append({"kind":"drain","resource":resource,"amount":amount,"bonus_id":int(drain.bonus_id)})
	for effect: Dictionary in active.invokes:
		if bool(victim.get("dead")): break
		var option: Dictionary = effect.option
		if bool(option.get("BySpellAttack",false)) != by_spell or bool(option.get("Param4",false)) and not main_target: continue
		var attack: int = int(option.get("AttackTypeID",0))
		if attack != 0 and attack != int({"melee":1,"ranged":2,"magic":3}.get(attack_kind,-1)): continue
		var target_kind: Dictionary = C.find(pack,"TargetKind",int(effect.spell.get("TargetKindID",0)))
		if target_kind.get("Name","") != "PCButMe": continue
		if not C.spell_target_allowed(world,victim,effect.spell): continue
		if not bool(victim.get_meta("is_player_combatant",false)) and not bool(policy.get("set_pvp_targets_as_pve",false)): continue
		if world.has_method("_world_to_cell") and int(effect.spell.get("CastRange",0)) > 0:
			var delta: Vector2i = world._world_to_cell(world.player.global_position)-world._world_to_cell(victim.global_position)
			if maxi(absi(delta.x),absi(delta.y)) > int(effect.spell.CastRange): continue
		if world.has_method("_has_line_of_sight_world") and not world._has_line_of_sight_world(world.player.global_position,victim.global_position): continue
		if world.get("original_skills") == null or world.original_skills.get("status") == null: continue
		var key: String = "equipment523-set-yahi|" + str(int(effect.set_id))
		var enforce_lock: bool = bool(policy.get("set_yahi_target_lock",true))
		if enforce_lock and locks.has(key) and locked_target() != victim: continue
		if world.rng.randi_range(0,999999) >= int(effect.probability): continue
		var status: Variant = world.original_skills.status
		if locks.has(key): _remove_lock(key)
		status.set_modifiers(victim,key,float(effect.duration),{"reduction":int(effect.reduction)})
		locks[key] = {"set_id":int(effect.set_id),"bonus_id":int(effect.bonus_id),"target":weakref(victim),"life_id":int(victim.get("life_id")),"remaining":float(effect.duration),"status":status,"buff_id":int(effect.buff.ID),"self_buff_id":int(effect.self_buff.ID),"enforce_lock":enforce_lock}
		if world.has_method("equipment523_emit_spell"):
			world.call("equipment523_emit_spell",effect.spell,victim)
			world.call("equipment523_emit_spell",effect.next_spell,world.player)
		fired.append({"kind":"target_lock","set_id":int(effect.set_id),"bonus_id":int(effect.bonus_id),"buff_id":int(effect.buff.ID),"self_buff_id":int(effect.self_buff.ID),"duration":float(effect.duration)})
	_busy = false
	return fired

func clear(_world: Node = null) -> void:
	for key: String in locks.keys(): _remove_lock(key)
	_remove_guard("cleared")
	cooldowns.clear()
	markers.clear()
	current.clear()
	source_sha = ""

func on_death() -> void:
	# Losing a non-death-immune buff does not reset its reuse clock.
	for key: String in locks.keys(): _remove_lock(key)
	_remove_guard("death")
	for key: String in markers.keys():
		if markers[key].get("raw",{}).get("IsImmuneToDead") != true: markers.erase(key)

func cancel(pack: Dictionary, groups: Array = []) -> int:
	# The ordinary cancel spell can remove a live guard, but cannot reset the
	# independently owned reuse clock. Markers and Yahi's two source buffs are
	# cancellation immune and are deliberately untouched by this operation.
	if guard.is_empty() or source_sha != str(pack.get("source_sha256","")): return 0
	var selector: Dictionary = _typed(pack,int(guard.get("bonus_id",0)),"HPIntervalBonus",10674)
	if selector.is_empty(): return 0
	var graph: Dictionary = interval_contract(pack,selector)
	if not bool(graph.get("ok",false)): return 0
	var buff: Dictionary = graph.interval.buff
	if int(guard.get("buff_id",0)) != int(buff.get("ID",0)): return 0
	if not buff.get("IsImmuneToCancellation") is bool or bool(buff.IsImmuneToCancellation): return 0
	if groups.is_empty():
		if not buff.get("IsGood") is bool or not bool(buff.IsGood): return 0
	else:
		var matched: bool = false
		for group: Variant in groups:
			if typeof(group) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(group)) or float(group) != floorf(float(group)): continue
			if int(group) == int(buff.get("BuffGroupID",0)) and int(group) > 0: matched = true
		if not matched: return 0
	_remove_guard("cancelled")
	return 1

func export_state() -> Dictionary:
	# Actor references/debuffs are life scoped and never rebound to a new NPC
	# after reconnect. Equipment-derived auras are recomputed from actual slots.
	if source_sha.is_empty() and guard.is_empty() and cooldowns.is_empty(): return {}
	var saved_guard: Dictionary = {}
	if not guard.is_empty():
		for key: String in ["bonus_id","set_id","buff_id","remaining","hits"]: saved_guard[key] = guard[key]
	return {"schema":"equipment523-set-effects-v1","source_sha256":source_sha,"guard":saved_guard,"cooldowns":cooldowns.duplicate(true)}

static func validate_state(data: Variant) -> String:
	if not data is Dictionary: return "set effect state must be a dictionary"
	if data.is_empty(): return ""
	if data.get("schema","") != "equipment523-set-effects-v1": return "unknown set effect state schema"
	if not data.get("source_sha256") is String or str(data.source_sha256).is_empty(): return "missing set source identity"
	if str(data.source_sha256) != C.SOURCE_SHA: return "unknown set source identity; preserve saved state"
	if not data.get("guard") is Dictionary or not data.get("cooldowns") is Dictionary: return "invalid set clocks"
	var saved: Dictionary = data.guard
	if not saved.is_empty():
		for key: String in ["bonus_id","set_id","buff_id","hits"]:
			var number: Variant = saved.get(key)
			if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floorf(float(number)) or float(number) <= 0 or float(number) > 9007199254740991.0: return "invalid guard " + key
		if typeof(saved.get("remaining")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(saved.remaining)) or float(saved.remaining) <= 0: return "invalid guard remaining duration"
	for key: Variant in data.cooldowns:
		if not key is String or not key.begins_with("group:") or not key.trim_prefix("group:").is_valid_int() or int(key.trim_prefix("group:")) <= 0: return "invalid guard cooldown key"
		if key != "group:"+str(int(key.trim_prefix("group:"))): return "noncanonical guard cooldown key"
		var value: Variant = data.cooldowns[key]
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0: return "invalid guard cooldown value"
	return ""

func import_state(data: Dictionary) -> void:
	clear()
	if data.is_empty() or not validate_state(data).is_empty(): return
	source_sha = str(data.get("source_sha256",""))
	if source_sha.is_empty(): return
	if data.get("guard") is Dictionary: guard = data.guard.duplicate(true)
	if data.get("cooldowns") is Dictionary:
		for key: Variant in data.cooldowns:
			if not str(key).begins_with("group:"): continue
			cooldowns[str(key)] = maxf(0.0,float(data.cooldowns[key]))
