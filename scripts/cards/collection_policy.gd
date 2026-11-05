extends RefCounted
## User-visible local compatibility estimates. Native amounts/units stay immutable.
const DEFAULTS: Dictionary={"estimates_enabled":true,"hp_ratio_round_up":true,"final_blow_multiplier":1.5,"weapon_block_reduction":100.0,"life_heal_per_point":1.0,"death_damage_per_point":1.0,"magic_penetration_factor":1.0,"physical_magic_defense_factor":1.0,"reduction_efficiency_factor":1.0,"ranged_burst_min_hits":2.0,"npc_final_blow_default":0.0,"npc_ignore_default":0.0,"triple_arrow_spirit_profile":false,"bleed_status_alias":true}
const SPECS: Array[Dictionary]=[
 {"key":"hp_ratio_round_up","label":"HP 구간 비율 올림 (끄면 버림 · 로컬 판정 방식)","bool":true},
 {"key":"estimates_enabled","label":"추가 로컬 추정 동작 사용","bool":true},
 {"key":"final_blow_multiplier","label":"결정타 기본 배율 (추정)","min":1.0,"max":5.0,"step":0.1},
 {"key":"weapon_block_reduction","label":"무기 막기 성공 시 피해 감소 % (추정)","min":0.0,"max":100.0,"step":1.0},
 {"key":"life_heal_per_point","label":"생명 1당 마법 회복 추가량 (추정)","min":0.0,"max":10.0,"step":0.1},
 {"key":"death_damage_per_point","label":"죽음 1당 적중 피해 추가량 (추정)","min":0.0,"max":10.0,"step":0.1},
 {"key":"magic_penetration_factor","label":"마법 관통의 MR 무시 환산 배율 (추정)","min":0.0,"max":5.0,"step":0.1},
 {"key":"physical_magic_defense_factor","label":"물리 마법 방어의 피해 감소 환산 배율 (추정)","min":0.0,"max":5.0,"step":0.1},
 {"key":"reduction_efficiency_factor","label":"대미지 감소 효율의 관통 상쇄 배율 (추정)","min":0.0,"max":5.0,"step":0.1},
 {"key":"ranged_burst_min_hits","label":"원본 태그가 없는 원거리 연사 최소 타수 (추정)","min":2.0,"max":8.0,"step":1.0},
 {"key":"npc_final_blow_default","label":"명시된 값 없는 몬스터 결정타 % (기본 0)","min":0.0,"max":100.0,"step":0.1},
 {"key":"npc_ignore_default","label":"명시된 값 없는 몬스터 감소 무시 % (기본 0)","min":0.0,"max":90.0,"step":0.1},
 {"key":"triple_arrow_spirit_profile","label":"로컬 트리플 애로우에 스피릿 원본 보상 선택 (기본형과 동시 적용 안 함)","bool":true},
 {"key":"bleed_status_alias","label":"원본 스킬 ID가 없는 로컬 출혈을 총사 출혈과 대응 (추정)","bool":true}
]
static func validate(values: Dictionary) -> Dictionary:
	var result: Dictionary=DEFAULTS.duplicate(true)
	for spec: Dictionary in SPECS:
		var key: String=spec.key
		if not values.has(key):continue
		var value: Variant=values[key]
		if spec.get("bool",false):
			if not value is bool:return {"ok":false,"error":"설정 형식 오류: "+key}
		else:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<spec.min or float(value)>spec.max:return {"ok":false,"error":"설정 범위 오류: "+key}
			if spec.step==1.0 and float(value)!=floorf(float(value)):return {"ok":false,"error":"정수 설정 필요: "+key}
		result[key]=value
	return {"ok":true,"values":result}
