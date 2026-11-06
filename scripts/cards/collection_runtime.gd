extends RefCounted
## Derived state only: the existing card_draw_fusion.owned save remains the
## sole acquisition ledger. Loading old owned cards is silent and idempotent.
const Rules=preload("res://scripts/cards/collection_rules.gd")
const NativeRules=preload("res://scripts/cards/native_collection_rules.gd")
const NativeInput=preload("res://scripts/cards/current523_collection_input.gd")
const CurrentInput=preload("res://scripts/cards/current523_collection_projection.gd")
const NATIVE_PATH: String="res://data/cards/patch523_collections.json"
const ExistingStats=preload("res://scripts/collections/equipment_collection_stats.gd")
const PATH: String="res://data/cards/normal_collections.json"
const Policy=preload("res://scripts/cards/collection_policy.gd")
var policy_values: Dictionary=Policy.DEFAULTS.duplicate(true)
var policy_saved: Variant={}
var policy_problem: String=""
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
		if world!=null:
			world.set("equipment_records_dirty",true)
			world.set("equipment_effects_dirty",true)
	return valid

func configure(host: Node) -> bool:
	world=host
	# UNVERIFIED: old collection files remain preserved, but are neither final
	# inputs nor fallbacks. The current original and current catalog are required.
	core=NativeRules.new()
	var projection=CurrentInput.new()
	var data: Dictionary=projection.build(world.catalog_db)
	if data.is_empty():problem=projection.problem;return false
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
	var signature: int=hash([owned,_source_server_context,_option_version,policy_values]) if core is NativeRules else hash(owned)
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
		for active: Dictionary in NativeRules.interval_effects(effect,hp,maximum,bool(policy_values.hp_ratio_round_up)):
			if Rules.effect_code(active)==code:total+=float(active.value)
	return total

func displayed_effects(row: Dictionary, maximum_preview: bool=false) -> Array:
	var effects: Array=[]
	for effect: Dictionary in row.effects:
		if not core is NativeRules or not NativeRules.interval_supported(effect):
			var shown: Dictionary=effect
			if not maximum_preview and not estimated() and str(effect.get("runtime_policy","")).begins_with("twilight_"):
				shown=effect.duplicate(true);shown.value=0
			if not maximum_preview and str(effect.key) in ["while_stun_damage_reduction","while_fear_damage_reduction"] and not status_active("stun" if effect.key=="while_stun_damage_reduction" else "fear"):
				shown=effect.duplicate(true);shown.value=0
			effects.append(shown);continue
		if maximum_preview:
			var best: Dictionary={}
			for percent: int in range(1,101):
				for active: Dictionary in NativeRules.interval_effects(effect,percent,100):
					var code: String=Rules.effect_code(active)
					if not best.has(code) or float(active.value)>float(best[code].value):best[code]=active
			effects.append_array(best.values())
		else:effects.append_array(NativeRules.interval_effects(effect,int(world.hp),int(world._effective_max_hp()),bool(policy_values.hp_ratio_round_up)))
	return effects

func incoming_damage(amount: int, kind: String, critical: bool=false,context: Dictionary={}) -> int:
	# Local pipeline policy: source flat reductions, then source percent; retain
	# the existing minimum1 and90% cap. Other status ticks never use poison data.
	if kind not in ["melee","ranged","magic","poison"]:return amount
	var flat: float=bonus(kind+"_damage_reduction:flat")
	if critical:flat+=bonus("critical_damage_reduction:flat")
	for status: String in ["stun","fear"]:
		if status_active(status):flat+=bonus("while_"+status+"_damage_reduction:flat")
	if ranged_burst(kind,context):flat+=bonus("ranged_burst_reduction:flat")
	var guard: float=bonus("physical_magic_defense:percent")*float(policy_values.physical_magic_defense_factor) if estimated() and kind=="magic" and bool(context.get("physical_magic",false)) else 0.0
	var percent: float=clampf(bonus(kind+"_damage_reduction:percent")+guard-float(context.get("ignore_remaining",0.0)),0.0,90.0)
	var reduced: int=maxi(1,int(round(maxf(1.0,amount-flat)*(1.0-percent/100.0))))
	return maxi(1,int(round(reduced*(1.0-clampf(bonus("stacked_damage_reduction:percent") if estimated() else 0.0,0.0,90.0)/100.0))))

func status_active(kind: String) -> bool:
	return world!=null and is_instance_valid(world.player) and ((kind=="stun" and world.player.is_stunned()) or (kind=="fear" and world.player.is_feared()))

func damage_amplification(kind: String) -> float:
	return bonus("damage_reduction_ignore:percent")+bonus(kind+"_reduction_ignore:percent")+bonus("pve_damage_amplification:percent")

func avoidance_after_pierce(avoidance: int,kind: String) -> int:
	return maxi(0,avoidance-int(bonus(kind+"_evasion_ignore:flat")))

func critical_resistance(kind: String,elemental: bool=false) -> float:
	return bonus(kind+"_critical_resistance:percent")+(bonus("elemental_critical_resistance:percent") if elemental else 0.0)

func magic_heal(amount: int) -> int:
	var life: float=bonus("life:flat")*float(policy_values.life_heal_per_point) if estimated() else 0.0
	return maxi(0,int(round((amount+life)*(1.0+maxf(0.0,bonus("magic_heal:percent"))/100.0))))

func blocks_weapon_hit(kind: String,rng: RandomNumberGenerator, additional_percent: float=0.0) -> bool:
	if kind not in ["melee","ranged"] or not estimated():return false
	var input: float = additional_percent if is_finite(additional_percent) else 0.0
	var chance: float=clampf(bonus("weapon_block:percent")+input,0.0,100.0)
	return chance>0.0 and rng.randf()<chance/100.0

func final_blow(amount: int,rng: RandomNumberGenerator) -> Dictionary:
	var chance: float=clampf(bonus("final_blow_probability:percent"),0.0,100.0) if estimated() else 0.0
	if chance<=0.0 or rng.randf()>=chance/100.0:return {"damage":amount,"triggered":false}
	# Explicit local fallback: reuse the game's1.5x critical base, then source
	# final-blow flat/percent. Called once for an ordinary successful attack only.
	var base: int=int(round(amount*float(policy_values.final_blow_multiplier)))+int(bonus("final_blow_damage:flat"))
	return {"damage":maxi(1,int(round(base*(1.0+clampf(bonus("final_blow_amplification:percent"),0.0,300.0)/100.0)))),"triggered":true}

func estimated() -> bool:return bool(policy_values.estimates_enabled)

func export_policy() -> Variant:return policy_saved.duplicate(true) if policy_saved is Dictionary or policy_saved is Array else policy_saved

func import_policy(value: Variant) -> void:
	_dirty=true;_has_cache=false
	policy_saved=value.duplicate(true) if value is Dictionary or value is Array else value
	policy_values=Policy.DEFAULTS.duplicate(true);policy_problem=""
	if value is Dictionary and int(value.get("schema",0))==1 and value.get("server_context") is Dictionary:set_source_server_context(value.server_context)
	if value is Dictionary and value.is_empty():return
	if not value is Dictionary or int(value.get("schema",0))!=1 or not value.get("values") is Dictionary:
		policy_problem="설정 버전/형식 확인 필요 · 원본 저장 설정 보존";policy_values.estimates_enabled=false;return
	var checked: Dictionary=Policy.validate(value["values"])
	if checked.ok:policy_values=checked["values"]
	else:policy_problem=str(checked.error);policy_values.estimates_enabled=false

func apply_policy(values: Dictionary, context: Variant=null) -> Dictionary:
	var checked: Dictionary=Policy.validate(values)
	if not checked.ok:return checked
	var before: Variant=export_policy()
	var before_context: Dictionary=source_server_context()
	var before_hp: int=world.hp;var before_mp: int=world.mp
	var selected: Dictionary=context if context is Dictionary else before_context
	if not selected.is_empty() and not preload("res://scripts/cards/source_collection_conditions.gd").valid_context(selected):return {"ok":false,"error":"원본 서버 평가 프로필 형식 오류"}
	var next: Dictionary=before.duplicate(true) if before is Dictionary and int(before.get("schema",0))==1 else {}
	var merged_values: Dictionary=next.get("values",{}).duplicate(true) if next.get("values") is Dictionary else {}
	merged_values.merge(checked["values"],true)
	if not (before is Dictionary and (before.is_empty() or (int(before.get("schema",0))==1 and before.get("values") is Dictionary))):next["prior_unrecognized_policy"]=before
	next.merge({"schema":1,"values":merged_values,"server_context":selected},true)
	import_policy(next)
	world._invalidate_equipment_static()
	world.hp=mini(world.hp,world._effective_max_hp());world.mp=mini(world.mp,world._effective_max_mp())
	var result: Error=world._save_game(true)
	if result!=OK:
		import_policy(before);set_source_server_context(before_context);world.hp=before_hp;world.mp=before_mp;world._invalidate_equipment_static()
		return {"ok":false,"error":"저장 실패 · 이전 규칙 유지"}
	world._update_hud()
	return {"ok":true}

func death_damage_bonus() -> int:return int(round(bonus("death:flat")*float(policy_values.death_damage_per_point))) if estimated() else 0

func magic_resistance_after_pierce(mr: int, additional_percent: float=0.0) -> int:
	var input: float = additional_percent if is_finite(additional_percent) else 0.0
	var percent: float=clampf((bonus("magic_penetration:percent")+input)*float(policy_values.magic_penetration_factor),0.0,100.0) if estimated() else 0.0
	return maxi(0,int(round(mr*(1.0-percent/100.0))))

func native_spell_id(skill: Dictionary) -> int:
	# An explicit source identity always wins over the local adapter/profile.
	if skill.has("source_m_spell_id"):return int(skill.source_m_spell_id)
	var id: String=str(skill.get("id",""))
	if id=="lm_b39dbcf394503410":
		var ancient: String="lm_19a961b42a074ce1"
		return 37921 if world!=null and world.original_skills!=null and world.original_skills.catalog.owned(world.original_skills.catalog.record_for(ancient)) else 63
	if id=="lm_19a961b42a074ce1":return 37921
	if id=="lm_b9f1605d690c64f7":return 77761 if bool(policy_values.triple_arrow_spirit_profile) else 120712
	if estimated() and bool(policy_values.bleed_status_alias) and skill.get("status","")=="bleed":return 17564
	return 0

func spell_damage_bonus(skill: Dictionary) -> int:return int(bonus("spell_"+str(native_spell_id(skill))+"_damage:flat"))
func spell_hit_bonus(skill: Dictionary) -> float:return bonus("spell_"+str(native_spell_id(skill))+"_hit:percent")

func ranged_burst(kind: String,context: Dictionary) -> bool:
	if context.has("spell_tags"):return kind=="ranged" and context.spell_tags is Array and 1 in context.spell_tags
	return estimated() and kind=="ranged" and (int(context.get("spell_id",0)) in [77761,120712] or int(context.get("hit_count",1))>=int(policy_values.ranged_burst_min_hits))

func incoming_context(attacker: Node,kind: String) -> Dictionary:
	var context: Dictionary=attacker.collection_combat_context.duplicate(true)
	if not context.has("hit_count"):context.hit_count=int(attacker.special_attack.get("hits",attacker.special_attack.get("hit_count",1)))
	return context

func incoming_ignore(context: Dictionary) -> float:
	var amount: float=float(context.get("ignore_percent",policy_values.npc_ignore_default if estimated() else 0.0))
	var efficiency: float=bonus("reduction_efficiency:percent")*float(policy_values.reduction_efficiency_factor) if estimated() else 0.0
	return clampf(amount-efficiency,0.0,90.0)

func incoming_final_blow(amount: int,kind: String,context: Dictionary,rng: RandomNumberGenerator) -> Dictionary:
	if not estimated() and not context.has("final_blow_multiplier"):return {"damage":amount,"triggered":false}
	var chance: float=float(context.get("final_blow_probability",policy_values.npc_final_blow_default if estimated() else 0.0))
	chance=clampf(chance-bonus("final_blow_resistance:percent"),0.0,100.0)
	if kind not in ["melee","ranged"] or chance<=0 or rng.randf()>=chance/100.0:return {"damage":amount,"triggered":false}
	var multiplier: float=clampf(float(context.get("final_blow_multiplier",policy_values.final_blow_multiplier)),1.0,5.0)
	return {"damage":maxi(1,int(round(amount*multiplier))),"triggered":true}
