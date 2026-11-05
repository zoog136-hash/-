extends RefCounted
## Source-derived self recovery; only missing restoration amounts, cooldowns
## and the host shield cap are configurable estimates. Never edits native rows.
const PATH := "user://twilight_skill_rules523.cfg"
const DATA := "res://data/skills/recovery_rules523.json"
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA)).records
var settings: Dictionary = {}
var last_error: String = ""
var percent_denominator: float = 0
var stun_type_confirmed := false
var mage_sp_confirmed := false

func _init() -> void: reload_settings()

func reload_settings() -> void:
	var config := ConfigFile.new()
	settings.clear()
	last_error=""
	if not FileAccess.file_exists(PATH): return
	if config.load(PATH) != OK:
		last_error = "회복 설정 파일을 읽을 수 없어 기본값을 사용합니다. 기존 파일은 보존됩니다."
		return
	for id: String in rules:
		settings[id] = {}
		for key: String in rules[id].defaults:
			if not config.has_section_key(id,key):continue
			var value: Variant = config.get_value(id,key)
			if value is float or value is int:
				if is_finite(float(value)): settings[id][key] = bounded(key,float(value))
	last_error = ""

static func bounded(key: String, value: float) -> float:
	if key == "cooldown": return clampf(value,.1,3600)
	if key == "average_dice":return 1.0 if value>=.5 else 0.0
	if key == "shield_cap_percent": return clampf(value,1,100)
	return clampf(value,0,100000)

func value_for(id: String, key: String) -> float:
	return float(settings.get(id,{}).get(key,rules[id].defaults.get(key,0)))

func update_setting(id: String, key: String, value: float) -> bool:
	if not rules.has(id) or not rules[id].defaults.has(key) or not is_finite(value): return false
	var config := ConfigFile.new()
	if FileAccess.file_exists(PATH) and config.load(PATH) != OK:
		last_error = "손상된 기존 설정을 덮어쓰지 않았습니다."
		return false
	config.set_value(id,key,bounded(key,value))
	var temporary := PATH + ".pending"
	if config.save(temporary) != OK: last_error = "회복 설정 저장 실패"; return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(PATH)) != OK:
		DirAccess.remove_absolute(temporary);last_error = "회복 설정 교체 실패";return false
	reload_settings()
	return true

func configure_pack(pack: Dictionary) -> void:
	percent_denominator = 0
	for row: Dictionary in pack.get("ui_units",[]):
		if int(row.get("ID",0)) == 3 and int(row.get("UnitID",0)) == 3: percent_denominator = float(row.get("Denominator",0))
	var typed := false
	var stun := false
	var class_type := false
	var mage := false
	for row: Dictionary in pack.get("bonus_application_types",[]):
		if int(row.ID)==2 and str(row.Name)=="SpecialResistanceType": typed=true
		if int(row.ID)==62 and str(row.Name)=="Class":class_type=true
	for row: Dictionary in pack.get("classes",[]):
		if int(row.ID)==3 and str(row.Name)=="magician":mage=true
	for row: Dictionary in pack.get("special_resistance_types",[]):
		if int(row.ID)==6 and str(row.Name)=="Stun": stun=true
	stun_type_confirmed = typed and stun
	mage_sp_confirmed = class_type and mage

static func values(profile: Dictionary, name: String, unit: String) -> Array:
	var result: Array=[]
	for entry: Dictionary in profile.get("bonuses",[]):
		if str(entry.type.Name)!=name or str(entry.unit.Name)!=unit:continue
		if int(entry.link.get("MinSpellLevel",0))!=0 or int(entry.link.get("CharacterLevel",0))!=0 or int(entry.link.get("CharacterClass",0))!=0 or int(entry.bonus.BonusApplicationTypeID)!=0 or int(entry.bonus.BonusApplicationTargetID)!=0:continue
		result.append(entry.bonus.Value)
	return result

func spec_for(id: String, profile: Dictionary) -> Dictionary:
	if not rules.has(id) or percent_denominator<=0:return {}
	var rule: Dictionary=rules[id]
	if int(profile.row.ID)!=int(rule.spell_id):return {}
	var direct:=bool(rule.get("direct_self",false))
	if not direct and int(profile.row.SpellCategoryID)!=184:return {}
	if direct and (int(profile.row.TargettingTypeID)!=2 or int(profile.row.TargetKindID) not in [2,6]):return {}
	var components: Dictionary={}
	var self_cost: Dictionary={}
	if direct and not profile.costs.is_empty():
		for cost: Dictionary in profile.costs:
			if int(cost.TargetKindID)==1:
				if not self_cost.is_empty() or bool(cost.EachTargetCost) or int(cost.MpCostUnit)!=1:return {}
				self_cost=cost.duplicate(true)
		if self_cost.is_empty():return {}
	for component: Dictionary in profile.get("components",[]):components[int(component.row.ID)]=component
	if direct:components[int(rule.spell_id)]=profile
	for child: float in rule.components:
		if not components.has(int(child)):return {}
		var row: Dictionary=components[int(child)].row
		if int(row.HPCost)!=0 or int(row.MPCost)!=0 or int(row.SpellMaterialItemAmount)!=0 or not components[int(child)].costs.is_empty():return {}
	var healer: Dictionary=components[int(rule.heal_component)]
	if not direct and (int(healer.row.TargettingTypeID)!=1 or int(healer.row.TargetKindID)!=1):return {}
	var runtime: Dictionary={"heal":0,"heal_percent":0.0,"statuses":[],"stats":{},"stealth_after":false,"overflow_shield":false,"duration":0.0 if direct else 5.0,"cooldown":value_for(id,"cooldown"),"show_recovery_buff":not direct,"cast_while_disabled":values(profile,"IgnoreCannotCastSpell","TrueFalse")==[1.0] and values(profile,"IgnoreSpellCannotAttack","TrueFalse")==[1.0]}
	# Explicit flags, no inference from a RestorationID integer.
	var percent:=values(healer,"HPRestorationPercent","Percentage")
	var origin := "원본 비율"
	if int(rule.spell_id)==333:
		if self_cost.is_empty():return {}
		var reduction: Array=[]
		for buff: Dictionary in profile.buffs:reduction.append_array(values(buff,"DamageReductionPercent","Percentage"))
		var seconds:=values(profile,"SpellBuffDuration","Seconds")
		if reduction.size()!=1 or seconds.size()!=1:return {}
		runtime.stats={"receivedMultiplier":1.0-clampf(float(reduction[0])/(percent_denominator*100),0,1)}
		runtime.duration=float(seconds[0])
		runtime["runtime_desc"]="자신의 받는 피해 %.0f%% 감소 / %.0f초 (원본) · 자기 대상 비용표 %d · 재사용 %.1f초(TWILIGHT 설정) · 혈맹 대상은 포함하지 않음" % [(1.0-float(runtime.stats.receivedMultiplier))*100,float(runtime.duration),int(self_cost.ID),float(runtime.cooldown)]
		return {"runtime":runtime,"self_cost":self_cost,"meta":{"origin":"원본 계수·자기 비용 분기","summary":runtime.runtime_desc,"self_branch":true,"source_level":0,"settings_path":PATH,"component_count":1}}
	if int(rule.spell_id)==73:
		runtime.statuses=["poison"]
		runtime["runtime_desc"]="자신의 독 해제 · 공식 설명에 따른 로컬 상태 연결 · 재사용 %.1f초(TWILIGHT 설정)" % float(runtime.cooldown)
		return {"runtime":runtime,"meta":{"origin":"원본 비용·공개 설명 + 자기 대상 연결","summary":runtime.runtime_desc,"self_branch":true,"source_level":0,"settings_path":PATH,"component_count":1}}
	if percent.size()==1:runtime.heal_percent=float(percent[0])/(percent_denominator*100.0)
	elif int(rule.spell_id)==47412:
		var base:=values(healer,"SpellDamageBase","Value")
		var number:=values(healer,"SpellDamageDiceNumber","Value")
		var sides:=values(healer,"SpellDamageDiceSpotCount","Value")
		var sp: Array=[]
		for entry: Dictionary in healer.bonuses:
			if mage_sp_confirmed and str(entry.type.Name)=="HealIncreaseBySP" and str(entry.unit.Name)=="Percentage" and int(entry.link.MinSpellLevel)==0 and int(entry.bonus.BonusApplicationTypeID)==62 and int(entry.bonus.BonusApplicationTargetID)==3:sp.append(entry.bonus.Value)
		if base.size()!=1 or number.size()!=1 or sides.size()!=1 or sp.size()!=1:return {}
		runtime["heal_dice"]={"base":int(base[0]),"number":int(number[0]),"sides":int(sides[0]),"sp_scale":float(sp[0])/(percent_denominator*100.0),"sp_class_id":3,"average":value_for(id,"average_dice")>=.5}
		origin="원본 계수·TWILIGHT 조합 산식"
	elif rule.defaults.has("heal") and not values(healer,"RestorationID","RestorationID").is_empty():runtime.heal=int(value_for(id,"heal"));origin="회복량 추정"
	else:return {}
	var groups: Array[int]=[]
	for group: Variant in values(components[int(rule.clear_component)],"SpellBuffGroup","BuffGroupID"):groups.append(int(group))
	if groups.has(4):runtime.statuses.append("stun")
	if groups.has(17) or groups.has(1342):runtime.statuses.append("hold")
	if groups.has(1862):runtime.statuses.append("fear")
	if values(components[int(rule.clear_component)],"EraseFalseBuffGroup","Value")==[1.0]:runtime.statuses=["stun","hold","fear","silence","poison","bleed"]
	var duration:=values(components[int(rule.buff_component)],"SpellBuffDuration","Seconds")
	if duration.size()==1:runtime.duration=float(duration[0])
	if int(rule.spell_id)==35443 and stun_type_confirmed:
		for buff: Dictionary in components[int(rule.buff_component)].buffs:
			for entry: Dictionary in buff.bonuses:
				if str(entry.type.Name)=="SpecialResistance" and str(entry.unit.Name)=="Percentage" and int(entry.bonus.BonusApplicationTypeID)==2 and int(entry.bonus.BonusApplicationTargetID)==6 and int(entry.link.get("MinSpellLevel",0))==0 and int(entry.link.get("CharacterLevel",0))==0 and int(entry.link.get("CharacterClass",0))==0:
					runtime.stats["stunResistance"]=float(entry.bonus.Value)/percent_denominator
	if int(rule.spell_id)==69601:
		# Native70041/70051: ignore hit motion, no looting, erased on attack.
		for child: int in [69611,69641]:
			for buff: Dictionary in components[child].buffs:
				if values(buff,"IgnoreDamageMotionDelay","TrueFalse")==[1.0]:runtime.stats["ignoreDamageMotion"]=1
				if values(buff,"CannotLoot","TrueFalse")==[1.0]:runtime.stats["cannotLoot"]=1
				runtime["break_on_attack"]=bool(buff.row.IsEraseOnAttack)
	if values(healer,"OverHealBuff","TrueFalse")==[1.0]:
		runtime.overflow_shield=true
		runtime["shield_cap_percent"]=value_for(id,"shield_cap_percent")
		runtime["shield_duration"]=float(runtime.duration)
	var amount := "최대 HP %.0f%%" % (float(runtime.heal_percent)*100) if float(runtime.heal_percent)>0 else "HP %d (추정)" % int(runtime.heal)
	var summary := "%s 회복 · 해제 %s · 지속 %.1f초(원본) · 재사용 %.1f초(TWILIGHT 설정)" % [amount,"/".join(runtime.statuses),float(runtime.duration),float(runtime.cooldown)]
	if runtime.has("heal_dice"):
		var dice: Dictionary=runtime.heal_dice
		summary="자기 HP 회복: %d + %dd%d + SP×%.1f · 계수는 원본 / 조합·반올림은 TWILIGHT 산식 · %s · 재사용 %.1f초(설정)" % [int(dice.base),int(dice.number),int(dice.sides),float(dice.sp_scale),"주사위 평균값" if bool(dice.average) else "주사위 굴림",float(runtime.cooldown)]
	if int(rule.spell_id)==54703:summary+="\nPvP 리덕션5/5초 원문 · 현재 PvE 피해에는 미적용"
	if int(rule.spell_id)==35443:summary+="\n스턴 내성 +%.0f%% (원본 유형 확인)" % float(runtime.stats.get("stunResistance",0))
	if int(rule.spell_id)==69601:summary+="\n피격 모션 지연/줍기 제한 · 공격 시 해제 · 기존 NPC 비충돌 유지"
	if bool(runtime.overflow_shield):summary+="\n초과 회복 → 보호막 %.1f초(원본), 상한 최대HP %.0f%%(TWILIGHT 설정) · 자기 회복 분기" % [float(runtime.shield_duration),float(runtime.shield_cap_percent)]
	runtime["runtime_desc"]=summary
	if not self_cost.is_empty():summary+="\n자기 대상 비용: 원본 SpellCost %d번 조건 적용" % int(self_cost.ID)
	runtime["runtime_desc"]=summary
	return {"runtime":runtime,"self_cost":self_cost,"meta":{"origin":origin,"summary":summary,"self_branch":direct,"source_level":0,"settings_path":PATH,"component_count":components.size()}}
