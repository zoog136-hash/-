extends RefCounted
## One independent relic summon. Only its exact523 secondary buff contributes.
const DATA=preload("res://scripts/cards/patch523_slot_data.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const MAP=preload("res://scripts/cards/native_doll_subslot.gd").MAP
const EXTRA_MAP={"PVEDamageReductionPercent":"pve_damage_reduction_pct","PVEMeleeHit":"pve_melee_hit","PVERangeHit":"pve_ranged_hit","PVEMagicHit":"pve_magic_hit","PierceMeleeEvasion":"melee_evasion_ignore","PierceRangeEvasion":"ranged_evasion_ignore","PierceMeleeDamageReduction":"melee_reduction_ignore","PierceRangeDamageReduction":"ranged_reduction_ignore","PierceMagicDamageReduction":"magic_reduction_ignore","CriticalMeleeDamage":"melee_critical_damage","CriticalRangeDamage":"ranged_critical_damage","CriticalMagicDamage":"magic_critical_damage"}
const FIELD: String="native_relic_subslot_identity"

static func identity_key(identity: String) -> String:
	var parts: PackedStringArray=identity.split(":")
	if parts.size()!=4 or parts[0]!="source" or parts[1] not in ["m508","m523"] or parts[2]!="98":return ""
	if not parts[3].is_valid_int() or str(int(parts[3]))!=parts[3] or int(parts[3])<=0:return ""
	return "98:"+parts[3]

static func definition(identity: String) -> Dictionary:
	return DATA.relic_card(identity_key(identity))

static func validate(value: Dictionary) -> String:
	var unlock_error: String=Unlock.validate(value)
	if not unlock_error.is_empty():return unlock_error
	if value.has("native_relic_summon_time"):
		var timer: Variant=value.native_relic_summon_time
		if not timer is Dictionary or timer.get("schema")!=1 or timer.get("item_class_id")!=365758 or timer.get("slot_index")!=11 or not timer.get("identity") is String or not preload("res://scripts/cards/native_awakening_supply.gd").integer(timer.get("expires_utc")):return "추가 성물 소환 시간 저장 형식 오류"
	if not value.has(FIELD):return ""
	var identity: Variant=value[FIELD]
	if not identity is String:return "추가 성물 저장 ID 형식 오류"
	if not identity.is_empty() and not DATA.installed():return DATA.problem+" · 기존 추가 성물 저장 보존"
	if not identity.is_empty() and not definition(identity).has("subslot_buff"):return "원본 추가 성물 연결 없음"
	return ""

static func unlocked(_level: int,buffs: Dictionary,progress: Dictionary={}) -> bool:
	if Unlock.unlocked(progress):return true
	for buff: Variant in buffs.values():
		if buff is Dictionary and buff.get("source_snapshot","")=="patch523" and int(buff.get("source_buff_class_id",0))==Unlock.BUFF:return true
	return false

static func source_available(card: Dictionary,context: Dictionary) -> bool:
	if int(card.get("BuffCardDeckID",0))!=98 or int(card.get("StartDateTimeID",0))!=0 or int(card.get("EndDateTimeID",0))!=0:return false
	return scope_available(int(card.get("ServerLimitSetID",-1)),context)

static func scope_available(limit: int,context: Dictionary) -> bool:
	if limit==0:return true
	# Read actual523 tuples; reusing an explicit region/world selection does not
	# reuse508 set definitions or infer a server from an ID, map or language.
	if context.get("source_snapshot","") not in ["base508","patch523"] or not context.get("ServiceRegionCode") is String:return false
	var number: Variant=context.get("WorldNo")
	if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or int(number)<=0:return false
	for row: Dictionary in DATA.relic_server_limits_for(limit):
		if int(row.ServerLimitSetID)==limit and row.ServiceRegionCode==context.ServiceRegionCode and int(row.WorldNo)==int(number):return true
	return false

static func exact_record(record: Dictionary,identity: String) -> bool:
	var key: String=identity_key(identity)
	if key.is_empty() or not DATA.has_relic_card(key) or Cards.card_id(record)!=identity:return false
	var raw: Dictionary=DATA.relic_card(key).card
	var expected: String="lineagem_base508" if identity.begins_with("source:m508:") else "lineagem_patch523"
	return record.get("source","")==expected and int(record.get("source_deck_id",0))==98 and int(record.get("source_card_id",0))==int(raw.ID) and int(record.get("source_grade_id",-1))==int(raw.GradeID)

static func eligibility(runtime: RefCounted,identity: String,level: int,buffs: Dictionary) -> Dictionary:
	if identity.is_empty():return {"ok":true}
	if not DATA.installed():return {"ok":false,"code":"slot_pack_missing","error":DATA.problem}
	if not unlocked(level,buffs,runtime.progress):return {"ok":false,"code":"relic_subslot_locked","error":"에바의 계시 습득이 필요합니다"}
	var row: Dictionary=definition(identity)
	if not row.has("subslot_buff"):return {"ok":false,"code":"source_identity","error":"원본 추가 성물 ID 연결 없음"}
	for effect: Dictionary in row.effects:
		if effect.type.Name=="DeleteTime":return {"ok":false,"code":"subslot_expiry_condition","error":"추가 성물 원본 만료 조건 확인 필요","source_bonus":effect.duplicate(true)}
	if not source_available(row.card,runtime.core.source_server_context):return {"ok":false,"code":"source_condition","error":"추가 성물 원본 서버·기간 조건 확인 필요"}
	var record: Dictionary=runtime.core.catalog.get("성물",{}).get(identity,{})
	if not exact_record(record,identity) or not runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},"성물",identity):return {"ok":false,"code":"ownership_condition","error":"성물 보유·원본 연결 확인 필요"}
	var main: Dictionary=runtime.world.equipped_catalog.get("성물",{})
	# The source forbids conflicts with a registered main; it supplies no rule
	# requiring a main to be present before this independent slot can be used.
	if main.is_empty():return {"ok":true}
	var main_id: String=Cards.card_id(main)
	if not exact_record(main,main_id):return {"ok":false,"code":"main_source_condition","error":"주 성물 원본 연결 확인 필요"}
	var main_row: Dictionary=definition(main_id)
	if not runtime.core.owned({"owned":runtime.world.card_draw_fusion.owned},"성물",main_id) or not source_available(main_row.card,runtime.core.source_server_context):return {"ok":false,"code":"main_ownership_condition","error":"주 성물 보유·원본 서버 조건 확인 필요"}
	# UIStaticTextData_Korean row2114 explicitly prohibits the same card OR
	# grade as the existing slot. Identity strings alone miss cross-snapshot use.
	if int(main_row.card.ID)==int(row.card.ID) or int(main_row.card.GradeID)==int(row.card.GradeID):return {"ok":false,"code":"same_card_grade","error":"주 성물과 다른 카드·등급 필요"}
	return {"ok":true}

static func secondary_groups(identity: String) -> Array:
	var key: String=identity_key(identity)
	var group: Dictionary=DATA.relic_option_group(key+":11")
	return [] if group.is_empty() else [group]

static func effects(runtime: RefCounted,identity: String) -> Dictionary:
	var out: Dictionary={"stats":{},"pending":[],"status_effect_ids":[],"slot_index":11,"summon_binding":{},"invoke_options":[],"source_zero_effects":[]}
	var row: Dictionary=definition(identity)
	if not row.has("subslot_buff"):return out
	var source: Array=row.effects.duplicate(true)
	if runtime.core.awakened(runtime.progress,"성물",identity):
		for group: Dictionary in secondary_groups(identity):
			if scope_available(int(group.group.ServerLimitsetID),runtime.core.source_server_context):source.append_array(group.effects)
	for effect: Dictionary in source:
		if effect.link.has("Level") and int(effect.link.Level)!=1:continue
		var name_value: String=str(effect.type.Name)
		if name_value=="BuffCardSummonNPCClassID" and int(effect.bonus.BonusApplicationTypeID)==461 and int(effect.bonus.BonusApplicationTargetID)==11 and int(effect.bonus.Value)==int(row.summon_binding.npc_class_id) and bool(row.summon_binding.display_sprite_verified):
			out.summon_binding=row.summon_binding.duplicate(true);continue
		if name_value=="StatusEffectID" and int(effect.bonus.BonusApplicationTypeID)==0 and int(effect.bonus.BonusApplicationTargetID)==0:
			out.status_effect_ids.append(int(effect.bonus.Value));continue
		if effect.link.has("CharacterLevel") and (int(effect.link.CharacterLevel)!=0 or int(effect.link.CharacterClass)!=0 or int(effect.link.MinSpellLevel)!=0):out.pending.append(effect);continue
		if name_value=="InvokeOption" and identity_key(identity)=="98:22182" and int(effect.bonus.ID)==2365228 and int(effect.bonus.BonusApplicationTypeID)==10 and int(effect.bonus.BonusApplicationTargetID)==16572 and effect.unit.Name=="Percentage":
			out.invoke_options.append(effect.duplicate(true));continue
		# Exact secondary rows already omit XP/cooldown/skill-level options.
		# Unsupported targeted, spell and invoke declarations remain visible.
		if int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or (not MAP.has(name_value) and not EXTRA_MAP.has(name_value)):out.pending.append(effect);continue
		var amount: float=float(effect.bonus.Value)
		if effect.unit.Name in ["Percentage","ValuePercent","Weight"]:
			var denominator: float=float(effect.ui_unit.get("Denominator",0))
			if denominator<=0:out.pending.append(effect);continue
			amount/=denominator
		elif effect.unit.Name!="Value":out.pending.append(effect);continue
		var key: String=EXTRA_MAP.get(name_value,MAP.get(name_value,""));out.stats[key]=float(out.stats.get(key,0))+amount
	return out

static func status_available(runtime: RefCounted,identity: String,status_id: int) -> bool:
	for group: Dictionary in secondary_groups(identity):
		if not scope_available(int(group.group.ServerLimitsetID),runtime.core.source_server_context):continue
		for effect: Dictionary in group.effects:
			if effect.type.Name=="StatusEffectID" and int(effect.link.Level)==1 and int(effect.bonus.Value)==status_id and int(effect.bonus.BonusApplicationTypeID)==0 and int(effect.bonus.BonusApplicationTargetID)==0:return true
	return false
