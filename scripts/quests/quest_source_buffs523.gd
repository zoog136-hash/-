extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Exact source effects, consumed by the existing finite/infinite item owners.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const IDS=[1186,282793,295524]
const FOOD=[282793,295524]
const FOOD_TYPED={"melee_damage":2,"melee_accuracy":1,"mr":10,"damage_reduction":2,"ranged_damage":2,"ranged_accuracy":1,"sp":2}
static func interval(world: Node)->float:
	var value: Variant=world.ui_preferences.get("quest523_food_regen_interval_seconds",30.0)
	if not (value is int or value is float) or not is_finite(float(value)) or value<1 or value>3600:return 0.0
	return float(value)
static func profile(saved: Dictionary)->Dictionary:
	var id: int=int(saved.get("source_item_class_id",0))
	if id not in IDS or D.current_original_definition(saved).is_empty():return {}
	var definition: Dictionary=D.definition_id(str(id));var record: Dictionary=D.expected_variant(definition.get("native_record",{}),saved)
	if record.is_empty() or not D.matches(record,saved) or record.get("source_test_item",true):return {}
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{});var food: bool=id in FOOD
	var reasons: Array=["source_infinite_amount_not_supported","unsupported_buff_effect:RegenMP","unsupported_buff_effect:RegenHP"] if food else ["unsupported_buff_effect:ExperienceAdditionPercent","no_supported_buff_effects"]
	if spec.get("kind")!="source_timed_buff" or spec.get("source_snapshot")!="patch523" or spec.get("activation_status")!="blocked" or not C.same(spec.get("blocked_reasons"),reasons) or spec.get("duration_seconds")!=1800 or spec.get("consume_delay_ms")!=500:return {}
	var buff_id: int=78583 if id==282793 else (80852 if id==295524 else 278)
	var expected: Dictionary={"ItemConsumeDelay":[500,"MilliSeconds"],"BuffClassID":[buff_id,"BuffClassID"],"BuffDuration":[1800,"Seconds"],"ItemConsumeEffectSpriteID":[751,"SpriteID"]}
	if food:expected["InfiniteAmount"]=[1,"Value"]
	var seen: Dictionary={}
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String=str(row.bonus_type.Name)
		if not expected.has(name) or seen.has(name) or row.get("IsPossession")!=false or row.bonus.get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.bonus.Value!=expected[name][0] or row.unit.Name!=expected[name][1]:return {}
		seen[name]=true
	if seen.size()!=expected.size():return {}
	var source: Dictionary=spec.get("source_buff_class",{});var group: Dictionary=spec.get("source_buff_group",{})
	if source.get("ID")!=buff_id or source.get("BuffGroupID")!=(291 if food else 5) or source.get("IsImmuneToCancellation")!=true or source.get("IsImmuneToDead")!=(not food) or group.get("ID")!=source.get("BuffGroupID") or group.get("IsAllowOverlap")!=(not food) or group.get("IsAllowPriority")!=false or group.get("IsEraseBySpellLevel")!=false:return {}
	var values: Dictionary={"MeleeDamage":2,"MeleeHit":1,"RegenMP":3,"RegenHP":2,"MagicResist":10,"DamageReduction":2,"RangeDamage":2,"RangeHit":1,"SpellPower":2} if food else {"ExperienceAdditionPercent":100000}
	seen.clear()
	for row: Dictionary in spec.get("source_buff_bonus",[]):
		var name: String=str(row.bonus_type.Name)
		if not values.has(name) or seen.has(name) or row.get("CharacterLevel")!=0 or row.get("CharacterClass")!=0 or row.get("MinSpellLevel")!=0 or row.bonus.get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.bonus.Value!=values[name] or row.unit.Name!=("Value" if food else "Percentage"):return {}
		seen[name]=true
	if seen.size()!=values.size() or not C.same(spec.get("typed_effects"),FOOD_TYPED if food else {}):return {}
	var result: Dictionary=record.duplicate(true);spec=spec.duplicate(true)
	spec["typed_effects"]=FOOD_TYPED.duplicate(true) if food else {"xp":10}
	if not food:spec["activation_status"]="unrestricted"
	result["source_use_spec"]=spec
	return result
static func action(world: Node,saved: Dictionary)->Dictionary:
	if int(saved.get("source_item_class_id",0)) not in IDS:return saved
	var record: Dictionary=profile(saved)
	if record.is_empty():return saved
	if int(record.source_item_class_id) in FOOD:
		var cadence: float=interval(world)
		if cadence<=0:return saved
		NATIVE_FIELDS.full(record).source_use_spec.typed_effects.merge({"mp_regen_tick":3,"hp_regen_tick":2,"tick_interval":cadence,"tick_elapsed":0.0,"quest523_food_policy":{"source_MP":3,"source_HP":2,"interval_seconds":cadence,"source_interval_verified":false,"policy":"TWILIGHT_existing_regeneration_clock"}})
		NATIVE_FIELDS.full(record).source_use_spec["activation_status"]="unrestricted"
	return record
