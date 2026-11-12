extends SceneTree
## Synthetic graph fixtures only; the original archive is deliberately absent.
## This tests the public evidence API and the private discard-before-return
## seam, never claims full record()/template equivalence without originals.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const DUMMY = preload("res://scripts/quests/source_dummy523.gd")
var checks: int = 0
var failures: Array[String] = []
var cases: int = 0

class Classes extends P.RegistrationScope:
	func active_classes(_reader: Variant, _collect: Callable) -> Dictionary:
		return {1:{"ID":1.0,"CanCreateClient":true},2:{"ID":2.0,"CanCreateClient":true}}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var had_source_env: bool=OS.has_environment("TWILIGHT_PATCH523_CONTENT")
	var source_env: String=OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT","")
	SOURCE.reset()
	check(SOURCE.identity().is_empty(),"fixture cannot accidentally read an installed original archive")
	var previous: P.RegistrationScope=P._swap_registration_scope(Classes.new())
	var observations: Dictionary=DUMMY.observed_exclusions.duplicate(true)
	for kind: String in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]:
		_compare(_definition(kind),kind,"unrestricted","",kind)
	var limited: Dictionary=_definition("source_weighted_bag")
	limited.class_rows=[{"ClassID":1.0}]
	var entity: Dictionary=limited.source_typed_references[0].bag.entities[0]
	entity.row.LimitClass=1.0
	entity.class_limits=[{"row":{"ID":11.0,"ClassID":1.0,"raw_nested":{"values":[1.0,2.0]}},"character_class":{"ID":1.0,"Name":"class1"}}]
	_compare(limited,"source_weighted_bag","unrestricted","","valid class limit")
	var blocked: Dictionary=limited.duplicate(true)
	blocked.class_rows=[]
	_compare(blocked,"source_weighted_bag","blocked","incomplete_lucky_bag_probability_for_class:2","class-specific denominator remains incomplete")
	blocked=limited.duplicate(true)
	blocked.source_typed_references[0].bag.entities[0].class_limits[0].character_class.ID=2.0
	_compare(blocked,"source_weighted_bag","blocked","unsupported_lucky_bag_entity_class","mismatched class join")
	for change: Dictionary in [{"Probability":-1.0},{"Probability":0.5},{"ItemAmount":0.0},{"ItemBlessCodeID":4.0},{"ItemEnchant":-1.0},{"LimitClass":77.0}]:
		blocked=_definition("source_weighted_bag")
		blocked.source_typed_references[0].bag.entities[0].row.merge(change,true)
		_compare(blocked,"source_weighted_bag","blocked","","invalid source field "+str(change))
	blocked=_definition("source_weighted_bag")
	blocked.source_typed_references[0].bag.entities[0].entity_type.Name="UnknownOriginalType"
	_compare(blocked,"source_weighted_bag","blocked","unsupported_lucky_bag_entity_type","unsupported declared type name")
	blocked=_definition("guaranteed_bag")
	blocked.source_typed_references[0].bag.entities[0].row.Name="[더미] retained entity fixture"
	_compare(blocked,"guaranteed_bag","blocked","source_declared_bag_entity_exclusion","excluded source entity observation")
	blocked=_definition("guaranteed_bag")
	blocked.source_typed_references[0].bag.entities[0].item_class.Name="[더미] retained item fixture"
	_compare(blocked,"guaranteed_bag","blocked","source_test_or_excluded_reward_item","excluded source item observation")
	blocked=_definition("guaranteed_bag")
	blocked.source_typed_references[0].bag.entities[0].item_class.TestItem=true
	_compare(blocked,"guaranteed_bag","blocked","source_test_or_excluded_reward_item","test item stays blocked")
	blocked=_definition("mixed_rewards_bag")
	blocked.original_item.TargettingTypeID=2.0
	_compare(blocked,"mixed_rewards_bag","blocked","unsupported_targetting_type","source target constraint")
	for mutation: String in ["unsupported numeric type","incomplete graph","duplicate root ref","excluded root"]:
		blocked=_definition("guaranteed_bag")
		match mutation:
			"unsupported numeric type": blocked.source_typed_references[0].bag.entities[0].row.LuckyBagEntityTypeID=9.0
			"incomplete graph": blocked.source_typed_references[0].bag.join_complete=false
			"duplicate root ref": blocked.source_typed_references.append(blocked.source_typed_references[0].duplicate(true))
			"excluded root": blocked.source_typed_references[0].bag.lucky_bag_class.Name="[더미] retained root fixture"
		_compare(blocked,"","","",mutation)
	_deep_copy(limited)
	DUMMY.observed_exclusions=observations
	check(P._swap_registration_scope(previous) is Classes,"bag fixture restores the prior registration scope")
	SOURCE.reset()
	if had_source_env: OS.set_environment("TWILIGHT_PATCH523_CONTENT",source_env)
	else: OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	print("CURRENT523_REWARD_BAG_RETENTION_RESULT "+JSON.stringify({"checks":checks,"cases":cases,"failures":failures,"fixture":"synthetic_metadata_only","record_or_template_equivalence_claimed":false,"original_zip_read":false}))
	quit(0 if failures.is_empty() else 1)

func _entity(id: int, kind: int, probability: float) -> Dictionary:
	return {"row":{"ID":float(id),"LuckyBagEntityTypeID":float(kind),"ItemClassID":float(id+1000),"Name":"entity fixture", "Probability":probability,
		"ItemAmount":2.0,"ItemBlessCodeID":1.0,"ItemEnchant":0.0,"LimitClass":10000.0,"raw_nested":{"values":[1.0,{"x":[true,null]}]}},
		"entity_type":{"ID":float(kind),"Name":"Probability" if kind==0 else "IsGiven","metadata":{"values":[1.0,2.0]}},
		"item_class":{"ID":float(id+1000),"Name":"item fixture","TestItem":false},"class_limits":[]}

func _definition(kind: String) -> Dictionary:
	var entities: Array=[]
	if kind=="guaranteed_bag": entities=[_entity(1,1,0.0),_entity(2,1,0.0)]
	else:
		entities=[_entity(1,0,2500000.0),_entity(2,0,7500000.0),_entity(3,0,0.0)]
		if kind=="mixed_rewards_bag":entities.append(_entity(4,1,0.0))
	var graph: Dictionary={"identity":SOURCE.identity(),"join_complete":true,"lucky_bag_class":{"ID":50.0,"Name":"bag fixture","raw_nested":{"values":[1.0,2.0]}},"entities":entities}
	return {"original_item":{"ID":500.0,"TargettingTypeID":1.0,"ServiceRegionCode":"","CanUseWhenInvisible":false},"category":{"IsConsumable":true},
		"item_bonus":[{"ID":77.0,"IsPossession":false,"bonus_type":{"Name":"LuckyBagClassID"},"unit":{"Name":"LuckyBagClassID"},"bonus":{"Value":50.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0}}],
		"class_rows":[],"source_typed_references":[{"item_bonus_id":77.0,"id":50,"bag":graph}]}

func _compare(definition: Dictionary, kind: String, status: String, reason: String, label: String) -> void:
	cases += 1
	var before: PackedByteArray=var_to_bytes(definition)
	DUMMY.observed_exclusions.clear()
	var public: Dictionary=P.reward_bag(definition)
	var observed: PackedByteArray=var_to_bytes(DUMMY.observed_exclusions)
	DUMMY.observed_exclusions.clear()
	var explicit: Dictionary=P.reward_bag(definition,true)
	check(var_to_bytes(public)==var_to_bytes(explicit),label+": omitted argument preserves exact public true evidence API")
	check(observed==var_to_bytes(DUMMY.observed_exclusions),label+": default and explicit true preserve identical observed exclusions")
	DUMMY.observed_exclusions.clear()
	var discarded: Dictionary=P.reward_bag(definition,false)
	check(observed==var_to_bytes(DUMMY.observed_exclusions),label+": opt-out retains exclusion-observation side effects")
	var expected: Dictionary=public.duplicate(true);expected.erase("source_entities")
	var actual: Dictionary=discarded.duplicate(true);actual.erase("source_entities")
	check(var_to_bytes(actual)==var_to_bytes(expected),label+": stripping only disposable source_entities leaves byte-identical full spec")
	check(var_to_bytes(definition)==before,label+": all helper calls preserve the complete input graph bytes")
	if kind.is_empty():
		check(public.is_empty() and discarded.is_empty(),label+": both paths retain source rejection")
		return
	check(public.get("kind")==kind and discarded.get("kind")==kind and public.get("activation_status")==status,label+": actual expected kind and admission status retained")
	check(public.source_entities.size()==definition.source_typed_references[0].bag.entities.size() and discarded.source_entities.is_empty(),label+": public evidence remains complete and false avoids only its retained copies")
	check(public.rewards.size()==definition.source_typed_references[0].bag.entities.size(),label+": zero-weight and duplicate source rows still contribute their unchanged reward records")
	if not reason.is_empty():check(reason in public.blocked_reasons,label+": expected source blocker remains visible")
	if kind!="guaranteed_bag" and status=="unrestricted":
		check(public.source_probability_denominator==10000000 and public.class_probability_totals.get("1")==10000000,label+": native probability denominator remains unchanged")

func _deep_copy(definition: Dictionary) -> void:
	var before: PackedByteArray=var_to_bytes(definition)
	var public: Dictionary=P.reward_bag(definition)
	public.source_entities[0].raw_nested.values.append("mutated")
	public.source_entities[0].entity_type.metadata.values.append("mutated")
	public.source_entities[0].class_limits[0].raw_nested.values.append("mutated")
	check(var_to_bytes(definition)==before,"public source entity/type/class-limit raw fields retain their original deep-copy isolation")
