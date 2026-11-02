extends RefCounted
## Extra summon slot, never another awakening purchase/level or a main-slot sum.
const DATA=preload("res://data/cards/base508_option_extensions.json")
const FIELD: String="native_subslot_identity"
const MAP={"HPPlus":"hpFlat","HPPlusPercent":"hpPct","Strength":"strFlat","Dexterity":"dexFlat","Intelligence":"intFlat","CarryPlus":"weightBonus","ArmorClass":"def","ArmorClassBonus":"def","AttackSpeedBonus":"attackSpeed","MoveSpeedBonus":"moveSpeedPct","PierceDamageReduction":"damage_reduction_ignore","MeleeHit":"meleeHit","RangeHit":"rangedHit","MagicHit":"magicHit","SpellPower":"sp"}
static func validate(value: Dictionary) -> String:
	var unlock_error: String=preload("res://scripts/cards/native_doll_unlock_item.gd").validate(value)
	if not unlock_error.is_empty():return unlock_error
	if not value.has(FIELD):return ""
	var id: Variant=value[FIELD]
	if not id is String:return "추가 인형 저장 ID 형식 오류"
	if not id.is_empty() and not DATA.data.subslot_buffs.has(id):return "원본 추가 인형 연결 없음"
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
	var row: Dictionary=DATA.data.subslot_buffs.get(identity,{})
	if row.is_empty():return {"ok":false,"code":"source_identity","error":"원본 추가 인형 ID 연결 없음"}
	var record: Dictionary=runtime.core.catalog["마법인형"].get(identity,{})
	if not runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},"마법인형",identity) or not runtime.core.native_material_available(record):return {"ok":false,"code":"ownership_condition","error":"인형 보유·원본 서버 조건 확인 필요"}
	var main: Dictionary=runtime.world.equipped_catalog.get("마법인형",{})
	if main.is_empty() or main.get("source","")!="lineagem_base508":return {"ok":false,"code":"main_required","error":"주 인형 소환 필요"}
	if int(main.get("source_card_id",0))==int(row.card.ID) or int(main.get("source_grade_id",0))==int(row.card.GradeID):return {"ok":false,"code":"same_card_grade","error":"주 인형과 다른 카드·등급 필요"}
	return {"ok":true}
static func effects(runtime: RefCounted,identity: String) -> Dictionary:
	var out: Dictionary={"stats":{},"pending":[],"status_effect_ids":[],"slot_index":11}
	var row: Dictionary=DATA.data.subslot_buffs.get(identity,{})
	if row.is_empty():return out
	var source: Array=row.effects.duplicate(true)
	# Same permanent awakening ledger; slot11 uses only its contextual group.
	if runtime.core.awakened(runtime.progress,"마법인형",identity):
		for group: Dictionary in DATA.data.option_groups:
			if group.identity!=identity or int(group.group.SlotIndex)!=11:continue
			var condition: Dictionary=runtime.core.native_conditions.evaluate(int(group.group.ServerLimitsetID),runtime.core.source_server_context)
			if condition.status in ["unrestricted","eligible"]:source.append_array(group.effects)
	for effect: Dictionary in source:
		if effect.link.has("Level") and int(effect.link.Level)!=1:continue
		var name_value: String=effect.type.Name
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
