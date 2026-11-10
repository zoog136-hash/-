extends RefCounted
## Extra summon slot, never another awakening purchase/level or a main-slot sum.
const INPUT=preload("res://scripts/cards/current523_option_combat_input.gd")
const Slots=preload("res://scripts/cards/option_slot_definitions.gd")
const FIELD: String="native_subslot_identity"
const MAP={"HPPlus":"hpFlat","HPPlusPercent":"hpPct","Strength":"strFlat","Dexterity":"dexFlat","Intelligence":"intFlat","CarryPlus":"weightBonus","ArmorClass":"def","ArmorClassBonus":"def","AttackSpeedBonus":"attackSpeed","MoveSpeedBonus":"moveSpeedPct","PierceDamageReduction":"damage_reduction_ignore","MeleeHit":"meleeHit","RangeHit":"rangedHit","MagicHit":"magicHit","SpellPower":"sp","Constitution":"conFlat","MPPlus":"mpFlat","DamageReduction":"damageReduction","MagicResist":"mr","MeleeEvasion":"dg","RangeEvasion":"er","MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","MagicDamage":"magicDamage","MeleeCritical":"meleeCrit","RangeCritical":"rangedCrit","HPPotionIncreaseStatic":"potionHealFlat","HPPotionIncreasePercent":"potionHealPct","PVEDamageReduction":"pve_damage_reduction","PVEMeleeAdditionDamage":"pve_melee_damage","PVERangeAdditionDamage":"pve_ranged_damage","PVEMagicAdditionDamage":"pve_magic_damage"}
static func validate(value: Dictionary) -> String:
	var unlock_error: String=preload("res://scripts/cards/native_doll_unlock_item.gd").validate(value)
	if not unlock_error.is_empty():return unlock_error
	if not value.has(FIELD):return ""
	var id: Variant=value[FIELD]
	if not id is String:return "추가 인형 저장 ID 형식 오류"
	if not id.is_empty() and subslot_row(id).is_empty():return "원본 추가 인형 연결 없음"
	return ""
static func unlocked(level: int,buffs: Dictionary,progress: Dictionary={}) -> bool:
	if level<95:return false
	if preload("res://scripts/cards/native_doll_unlock_item.gd").unlocked(progress):return true
	# Exact source marker only. Names/level alone never grant Eva's Call.
	for buff: Variant in buffs.values():
		if buff is Dictionary and buff.get("source_snapshot","")=="base508" and int(buff.get("source_buff_class_id",0))==91531:return true
	return false
static func eligibility(runtime: RefCounted,identity: String,level: int,buffs: Dictionary) -> Dictionary:
	if identity.is_empty():return {"ok":true}
	if not unlocked(level,buffs,runtime.progress):return {"ok":false,"code":"subslot_locked","error":"95레벨 및 에바의 부름 습득이 필요합니다"}
	var row: Dictionary=subslot_row(identity)
	if row.is_empty():return {"ok":false,"code":"source_identity","error":"원본 추가 인형 ID 연결 없음"}
	# A zero DeleteTime value with a DateTime target is an absolute source
	# expiry clause, not a zero-duration/no-limit marker. Collection-only
	# period overrides never remove summon-buff conditions.
	for effect: Dictionary in row.effects:
		if effect.type.Name=="DeleteTime":return {"ok":false,"code":"subslot_expiry_condition","error":"추가 인형 원본 만료 조건 확인 필요 · DateTime "+str(int(effect.bonus.BonusApplicationTargetID)),"source_bonus":effect.duplicate(true)}
	var record: Dictionary=runtime.core.catalog["마법인형"].get(identity,{})
	if not runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},"마법인형",identity) or not runtime.core.native_material_available(record):return {"ok":false,"code":"ownership_condition","error":"인형 보유·원본 서버 조건 확인 필요"}
	var main: Dictionary=runtime.world.equipped_catalog.get("마법인형",{})
	if main.is_empty() or not preload("res://scripts/lineagem_base508.gd").native(main):return {"ok":false,"code":"main_required","error":"주 인형 소환 필요"}
	var main_id: String=preload("res://scripts/card_draw_fusion.gd").card_id(main)
	if not runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},"마법인형",main_id) or not runtime.core.native_material_available(main):return {"ok":false,"code":"main_ownership_condition","error":"주 인형 보유·원본 서버 조건 확인 필요"}
	if int(main.get("source_card_id",0))==int(row.card.ID) or int(main.get("source_grade_id",0))==int(row.card.GradeID):return {"ok":false,"code":"same_card_grade","error":"주 인형과 다른 카드·등급 필요"}
	return {"ok":true}
static func effects(runtime: RefCounted,identity: String) -> Dictionary:
	var out: Dictionary={"stats":{},"pending":[],"status_effect_ids":[],"slot_index":11,"summon_binding":{},"invoke_options":[],"source_zero_effects":[]}
	var row: Dictionary=subslot_row(identity)
	if row.is_empty():return out
	var source: Array=row.effects.duplicate(true)
	# Same permanent awakening ledger; slot11 uses only its contextual group.
	if runtime.core.awakened(runtime.progress,"마법인형",identity):
		for group: Dictionary in secondary_groups(identity):
			var evaluator: RefCounted=runtime.core.patch523_conditions if identity.begins_with("source:m523:") else runtime.core.native_conditions
			var condition: Dictionary=evaluator.evaluate(int(group.group.ServerLimitsetID),runtime.core.source_server_context)
			if condition.status in ["unrestricted","eligible"]:source.append_array(group.effects)
	for effect: Dictionary in source:
		if effect.link.has("Level") and int(effect.link.Level)!=1:continue
		var name_value: String=effect.type.Name
		if name_value in ["ExperienceAdditionPercent","EinasadSavingPercent"] and int(effect.bonus.Value)==0 and int(effect.bonus.BonusApplicationTypeID)==0 and int(effect.bonus.BonusApplicationTargetID)==0:
			out.source_zero_effects.append(effect.duplicate(true));continue
		if name_value=="BuffCardSummonNPCClassID":
			var binding: Dictionary=INPUT.subslot_npc_binding(identity)
			if int(effect.bonus.BonusApplicationTypeID)==461 and int(effect.bonus.BonusApplicationTargetID)==11 and int(binding.get("npc_class_id",0))==int(effect.bonus.Value) and bool(binding.get("display_sprite_verified",false)):
				out.summon_binding=binding.duplicate(true);continue
		if name_value=="InvokeOption" and int(effect.bonus.BonusApplicationTypeID)==10 and int(effect.bonus.BonusApplicationTargetID) in [10661,3323]:
			out.invoke_options.append(effect.duplicate(true));continue
		if name_value=="StatusEffectID":out.status_effect_ids.append(int(effect.bonus.Value));continue
		if int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or not MAP.has(name_value):out.pending.append(effect.duplicate(true));continue
		if effect.link.has("CharacterLevel") and (int(effect.link.CharacterLevel)!=0 or int(effect.link.CharacterClass)!=0 or int(effect.link.MinSpellLevel)!=0):out.pending.append(effect.duplicate(true));continue
		var amount: float=float(effect.bonus.Value)
		if effect.unit.Name in ["Percentage","ValuePercent","Weight"]:
			var denominator: float=float(effect.ui_unit.get("Denominator",0))
			if denominator<=0:out.pending.append(effect.duplicate(true));continue
			amount/=denominator
		elif effect.unit.Name!="Value":out.pending.append(effect.duplicate(true));continue
		var key: String=MAP[name_value];out.stats[key]=float(out.stats.get(key,0))+amount
	return out

static func secondary_groups(identity: String) -> Array:
	var group: Dictionary=Slots.group_for(identity,11)
	return [group] if not group.is_empty() and int(group.card.BuffCardDeckID)==2 else []
static func subslot_row(identity: String) -> Dictionary:
	return INPUT.subslot_buff(identity)
static func status_available(runtime: RefCounted,identity: String,status_id: int) -> bool:
	for group: Dictionary in secondary_groups(identity):
		var evaluator: RefCounted=runtime.core.patch523_conditions if identity.begins_with("source:m523:") else runtime.core.native_conditions
		var condition: Dictionary=evaluator.evaluate(int(group.group.ServerLimitsetID),runtime.core.source_server_context)
		if condition.status not in ["unrestricted","eligible"]:continue
		for effect: Dictionary in group.effects:
			if effect.type.Name=="StatusEffectID" and int(effect.link.Level)==1 and int(effect.bonus.Value)==status_id and int(effect.bonus.BonusApplicationTypeID)==0 and int(effect.bonus.BonusApplicationTargetID)==0:return true
	return false

