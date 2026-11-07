extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Finite source MP regeneration, with an explicit host cadence. Source data
## provides amount/duration, not a verified server regeneration interval.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const IDS=[376,385]
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
static func interval(world: Node)->float:
	var value: Variant=world.ui_preferences.get("quest523_mp_regen_interval_seconds",30.0)
	if not (value is int or value is float) or not is_finite(float(value)) or value<1 or value>3600:return 0.0
	return float(value)
static func contract(record: Dictionary)->Dictionary:
	var id: int=int(record.get("source_item_class_id",0))
	if id not in IDS or D.current_original_definition(record).is_empty():return {}
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("kind")!="source_timed_buff" or spec.get("activation_status")!="blocked" or spec.get("source_snapshot")!="patch523":return {}
	var reasons: Array=spec.get("blocked_reasons",[])
	if reasons.is_empty() or not reasons.has("unsupported_buff_effect:RegenMP"):return {}
	for reason: String in reasons:
		if reason not in ["unsupported_buff_effect:RegenMP","no_supported_buff_effects"]:return {}
	if float(spec.get("duration_seconds",0))!=300 or int(spec.get("consume_delay_ms",-1))!=500:return {}
	var source: Dictionary=spec.get("source_buff_class",{});var group: Dictionary=spec.get("source_buff_group",{})
	if int(source.get("ID",0))!=(39 if id==376 else 82) or int(source.get("BuffGroupID",0))!=5 or int(group.get("ID",0))!=5 or group.get("IsAllowOverlap")!=true or group.get("IsAllowPriority")!=false or group.get("IsEraseBySpellLevel")!=false:return {}
	var regen: int=0;var power: int=0;var seen: Dictionary={}
	for row: Dictionary in spec.get("source_buff_bonus",[]):
		var name: String=str(row.get("bonus_type",{}).get("Name",""));var bonus: Dictionary=row.get("bonus",{})
		if name not in ["RegenMP","SpellPower"] or seen.has(name) or int(row.get("CharacterLevel",-1))!=0 or int(row.get("CharacterClass",-1))!=0 or int(row.get("MinSpellLevel",-1))!=0 or int(bonus.get("BonusApplicationTypeID",-1))!=0 or int(bonus.get("BonusApplicationTargetID",-1))!=0 or row.get("unit",{}).get("Name")!="Value":return {}
		var amount: Variant=bonus.get("Value")
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)!=floorf(float(amount)) or amount<=0:return {}
		seen[name]=true
		if name=="RegenMP":regen=int(amount)
		else:power=int(amount)
	if regen!=(2 if id==376 else 3) or power!=(2 if id==376 else 0) or seen.size()!=(2 if id==376 else 1):return {}
	var typed: Dictionary=spec.get("typed_effects",{})
	if id==376:
		var sp: Variant=typed.get("sp")
		if typed.size()!=1 or not (sp is int or sp is float) or float(sp)!=2.0:return {}
	elif not typed.is_empty():return {}
	return {"spec":spec,"regen":regen,"power":power}

static func action(world: Node,record: Dictionary)->Dictionary:
	var checked: Dictionary=contract(record)
	if checked.is_empty() or interval(world)<=0:return record
	var spec: Dictionary=checked.spec;var regen: int=int(checked.regen);var typed: Dictionary=spec.get("typed_effects",{})
	var result: Dictionary=record.duplicate(true);spec=spec.duplicate(true);typed=typed.duplicate(true)
	typed.merge({"mp_regen_tick":regen,"tick_interval":interval(world),"tick_elapsed":0.0,"quest523_regen_policy":{"kind":"TWILIGHT_existing_mana_potion_cadence","interval_seconds":interval(world),"source_interval_verified":false,"source_amount":regen}})
	spec["typed_effects"]=typed;spec["activation_status"]="unrestricted";spec["host_policy_interpretation"]="source_amount_duration_with_configurable_TWILIGHT_cadence"
	result["source_use_spec"]=spec
	return result
static func cancel(world: Node,groups: Array)->int:
	var removed: int=0
	for key: String in world.active_item_buffs.keys():
		var buff: Dictionary=world.active_item_buffs[key]
		if int(buff.get("source_item_class_id",0)) not in IDS or buff.get("source_snapshot")!="patch523" or not buff.has("quest523_regen_policy"):continue
		var source: Dictionary=buff.get("source_buff_class",{})
		if source.get("IsImmuneToCancellation",true):continue
		var matching: bool=groups.is_empty() and source.get("IsGood",false)
		for group: Variant in groups:
			if (group is int or group is float) and float(group)==float(source.get("BuffGroupID",-1)):matching=true
		if matching:
			world.active_item_buffs.erase(key);removed+=1
	if removed>0:world._refresh_speed_modifiers();world._update_hud()
	return removed
