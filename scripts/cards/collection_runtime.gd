extends RefCounted
## Derived state only: the existing card_draw_fusion.owned save remains the
## sole acquisition ledger. Loading old owned cards is silent and idempotent.
const Rules=preload("res://scripts/cards/collection_rules.gd")
const NativeRules=preload("res://scripts/cards/native_collection_rules.gd")
const NATIVE_PATH: String="res://data/cards/patch523_collections.json"
const ExistingStats=preload("res://scripts/collections/equipment_collection_stats.gd")
const PATH: String="res://data/cards/normal_collections.json"
var world: Node
var core=Rules.new()
var problem: String=""
var revision: int=0
var rebuild_count: int=0
var totals: Dictionary={}
var _views: Array=[]
var _interval_rewards: Array[Dictionary]=[]
var _completed: Dictionary={}
var _announced: Dictionary={}
var _record: Dictionary={}
var _dirty: bool=true
var _has_cache: bool=false
var _owned_hash: int=0
var _source_server_context: Dictionary={}
var _option_version: String=""

func set_source_server_context(context: Dictionary) -> bool:
	# Caller must supply the actual native game profile. Nothing is inferred or
	# written to a save. Invalid/missing input clears prior eligible context.
	var valid: bool=preload("res://scripts/cards/source_collection_conditions.gd").valid_context(context)
	var value: Dictionary=context.duplicate(true) if valid else {}
	if value!=_source_server_context:
		_source_server_context=value
		invalidate()
		if world!=null:world.set("equipment_records_dirty",true)
	return valid

func configure(host: Node) -> bool:
	world=host
	var native: bool=NativeRules.accepts_catalog(world.catalog_db)
	core=NativeRules.new() if native else Rules.new()
	var path: String=NATIVE_PATH if native else PATH
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not data is Dictionary:
		problem="일반 카드 컬렉션 데이터 누락/손상";return false
	if not core.configure(data,world.catalog_db):problem=core.error;return false
	problem="";restore_from_owned();return true

func invalidate() -> void:_dirty=true

func current_revision() -> int:
	_ensure();return revision

func _ensure() -> void:
	if world==null or not problem.is_empty():return
	var option_version: String=str(world.option_awakening.core.native_mode)+":"+str(world.option_awakening.progress.get("revision",0)) if core is NativeRules else ""
	if option_version!=_option_version:_dirty=true
	if not _dirty:return
	_option_version=option_version
	_dirty=false
	var owned: Dictionary=world.card_draw_fusion.owned
	var signature: int=hash([owned,_source_server_context,_option_version]) if core is NativeRules else hash(owned)
	if _has_cache and signature==_owned_hash:return
	_owned_hash=signature;_has_cache=true
	var state: Dictionary={"owned":owned,"source_server_context":_source_server_context}
	if core is NativeRules:state.source_option_awakening=world.option_awakening.native_collection_state()
	var derived: Dictionary=core.derive(state)
	_views=derived.rows;totals=derived.totals;_completed=derived.completed
	_interval_rewards.clear()
	if core is NativeRules:
		for row: Dictionary in _views:
			if row.completed:
				for effect: Dictionary in row.effects:
					if NativeRules.interval_supported(effect):_interval_rewards.append(effect)
	_record=ExistingStats.record(totals)
	if core is NativeRules:_record.merge(NativeRules.stat_record_additions(totals),true)
	if not _record.is_empty():
		_record.erase("_equipment_collection_bonus")
		_record["_card_collection_bonus"]=true
	revision+=1;rebuild_count+=1

func restore_from_owned() -> void:
	_dirty=true;_has_cache=false;_ensure()
	# An old save already owned these cards. Rebuilding progress must neither
	# grant cards nor announce every achievement again after each reload.
	_announced=_completed.duplicate()

func reconcile() -> Array[String]:
	_ensure()
	var newly_completed: Array[String]=[]
	for identity: String in _completed:
		if not _announced.has(identity):newly_completed.append(identity)
		_announced[identity]=true
	return newly_completed

func snapshot(category: String="",card_id: String="") -> Array:
	_ensure()
	var rows: Array=[]
	for row: Dictionary in _views:
		if card_id.is_empty() and not category.is_empty() and str(row.category)!=category:continue
		if not card_id.is_empty() and not row.requirements.any(func(requirement: Dictionary) -> bool:return str(requirement.id)==card_id and str(requirement.category)==category):continue
		rows.append(row.duplicate(true))
	return rows

func bonus(code: String) -> float:
	_ensure();return float(totals.get(code,0.0))

func catalog_bonus(key: String) -> int:
	_ensure()
	if core is NativeRules and NativeRules.NATIVE_CATALOG_FIELDS.has(key):
		return int(totals.get(NativeRules.NATIVE_CATALOG_FIELDS[key],0))
	var extra: Dictionary={"potionHealFlat":"potion_heal:flat","potionHealPct":"potion_heal:percent"}
	return int(totals.get(extra[key],0)) if extra.has(key) else ExistingStats.catalog_bonus(totals,key)

func stat_record() -> Dictionary:
	_ensure();return _record

func source_server_context() -> Dictionary:
	return _source_server_context.duplicate(true)

func interval_bonus(code: String, hp: int, maximum: int) -> float:
	_ensure()
	var total: float=0.0
	if not core is NativeRules:return total
	for effect: Dictionary in _interval_rewards:
		for active: Dictionary in NativeRules.interval_effects(effect,hp,maximum):
			if Rules.effect_code(active)==code:total+=float(active.value)
	return total

func displayed_effects(row: Dictionary, maximum_preview: bool=false) -> Array:
	var effects: Array=[]
	for effect: Dictionary in row.effects:
		if not core is NativeRules or not NativeRules.interval_supported(effect):effects.append(effect);continue
		if maximum_preview:
			var best: Dictionary={}
			for percent: int in range(1,101):
				for active: Dictionary in NativeRules.interval_effects(effect,percent,100):
					var code: String=Rules.effect_code(active)
					if not best.has(code) or float(active.value)>float(best[code].value):best[code]=active
			effects.append_array(best.values())
		else:effects.append_array(NativeRules.interval_effects(effect,int(world.hp),int(world._effective_max_hp())))
	return effects

func incoming_damage(amount: int, kind: String, critical: bool=false) -> int:
	# Local pipeline policy: source flat reductions, then source percent; retain
	# the existing minimum1 and90% cap. Other status ticks never use poison data.
	if kind not in ["melee","ranged","magic","poison"]:return amount
	var flat: float=bonus(kind+"_damage_reduction:flat")
	if critical:flat+=bonus("critical_damage_reduction:flat")
	var percent: float=clampf(bonus(kind+"_damage_reduction:percent"),0.0,90.0)
	return maxi(1,int(round(maxf(1.0,amount-flat)*(1.0-percent/100.0))))
