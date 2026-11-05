extends RefCounted
## Projections for nine already registered skills; canonical identities stay intact.
const RECOVERY = preload("res://scripts/skills/recovery_rules523.gd")
const DATA = "res://data/skills/progression_rules523.json"
var policy = RECOVERY.new()
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA)).records

func _init() -> void:
	policy.rules = rules
	policy.reload_settings()

func value(id: String, key: String) -> float:
	return policy.value_for(id,key)

func update_setting(id: String, key: String, amount: float) -> bool:
	return policy.update_setting(id,key,amount)

static func buffs(profile: Dictionary, name: String, unit: String) -> Array:
	var result: Array=[]
	for buff: Dictionary in profile.buffs:result.append_array(RECOVERY.values(buff,name,unit))
	return result

func graph_for(id: String, profile: Dictionary) -> Dictionary:
	if not rules.has(id) or int(profile.row.ID)!=int(rules[id].spell_id):return {}
	var graph: Dictionary=profile.get("execution_graph",{})
	if int(graph.get("root_id",0))!=int(profile.row.ID):return {}
	var ids: Array=[]
	for node: Dictionary in graph.get("spells",[]):ids.append(int(node.row.ID))
	var expected: Array=[]
	for node: Variant in rules[id].nodes:expected.append(int(node))
	return graph if ids==expected else {}

static func node_for(graph: Dictionary, native_id: int) -> Dictionary:
	for node: Dictionary in graph.get("spells",[]):
		if int(node.row.ID)==native_id:return node
	return {}

static func option_for(graph: Dictionary, native_id: int, kind: String) -> Dictionary:
	for option: Dictionary in graph.get("invokes",[]):
		if int(option.row.ID)==native_id and str(option.type.Name)==kind:return option.row
	return {}

func spec_for(id: String, profile: Dictionary, denominator: float) -> Dictionary:
	if denominator<=0:return {}
	var graph:=graph_for(id,profile)
	if graph.is_empty():return {}
	var rule: Dictionary=rules[id]
	var kind: String=rule.kind
	var runtime: Dictionary={"stats":{},"mp":0,"hp":0,"items":{},"cooldown":0.0,"duration":0.0,"activation":"passive","mode":"stats"}
	var summary: String=""
	if kind=="light":
		var light:=buffs(profile,"LightRadius","Value")
		if light.size()!=1:return {}
		runtime.stats={"lightRadiusRaw":float(light[0]),"lightRadius":clampf(value(id,"light_radius"),16,1024)}
		summary="습득 후 상시 조명 · 원본 LightRadius %d · 표시 반경 %.0fpx(TWILIGHT 설정) · 직접 시전/소모 없음" % [int(light[0]),float(runtime.stats.lightRadius)]
	elif kind=="capacity":
		var hp:=buffs(profile,"HPPlusPercent","ValuePercent")
		var mp:=buffs(profile,"MPPlusPercent","ValuePercent")
		if hp.size()!=1 or mp.size()!=1:return {}
		runtime.stats={"hpPct":float(hp[0])/100.0,"mpPct":float(mp[0])/100.0}
		summary="습득 후 최대 HP +%.0f%% / 최대 MP +%.0f%% (원본 기본 단계) · 현재 자원을 회복/지급하지 않음 · 직접 시전/소모 없음" % [float(hp[0]),float(mp[0])]
	elif kind=="speed":
		var move:=buffs(profile,"MoveSpeedBonus","Percentage")
		var attack:=buffs(profile,"AttackSpeedBonus","Percentage")
		var cast_speed:=buffs(profile,"CastSpeedBonus","Percentage")
		if move.size()!=1 or attack.size()!=1 or cast_speed.size()!=1:return {}
		runtime.stats={"speed":1.0+float(move[0])/(denominator*100),"attackSpeed":float(attack[0])/denominator,"castSpeed":float(cast_speed[0])/denominator}
		summary="습득 후 이동/공격/시전 속도 +%.0f%% (원본) · 기존 TWILIGHT 속도 결합 정책 · 직접 시전/소모 없음" % float(runtime.stats.attackSpeed)
	elif kind=="amplify":
		var normal:=option_for(graph,841,"Attack_DamageScale")
		var magic:=option_for(graph,851,"Attack_DamageScale")
		if normal.is_empty() or magic.is_empty() or bool(normal.BySpellAttack) or not bool(magic.BySpellAttack) or normal.Param1!=magic.Param1:return {}
		var probabilities: Array=[]
		for buff: Dictionary in profile.buffs:
			for entry: Dictionary in buff.bonuses:
				if str(entry.type.Name)=="InvokeOption" and int(entry.link.MinSpellLevel)==0 and int(entry.bonus.BonusApplicationTypeID)==10 and int(entry.bonus.BonusApplicationTargetID) in [841,851]:probabilities.append(float(entry.bonus.Value)/(denominator*100))
		if probabilities.size()!=2 or probabilities[0]!=probabilities[1]:return {}
		runtime.mode="amplify";runtime["proc_chance"]=probabilities[0];runtime["multiplier"]=float(normal.Param1)/1000000.0
		summary="습득 후 일반/스킬 적중 피해에 %.0f%% 확률 ×%.1f (원본 Invoke841/851) · 반사/추가 발동 재귀 제외 · 최종 계산 순서는 TWILIGHT" % [float(runtime.proc_chance)*100,float(runtime.multiplier)]
	elif kind=="rapid":
		runtime.merge({"mode":"attack","activation":"active","shape":"single","attack_type":"ranged","element":"physical","weapons":["총"],"hits":clampi(int(value(id,"hits")),1,12),"power":int(value(id,"power")),"range":maxf(24,value(id,"range")),"cooldown":maxf(.1,value(id,"cooldown")),"cast_time":clampf(value(id,"cast_time"),.14,5)},true)
		summary="원본 MP8·정제석2 · 구성101 실행 정의 미확인: 기존 TWILIGHT 단일 %d연사/위력%d · 거리/시전/재사용/총알 소모는 자체 설정 · 원본 노드 복원 아님" % [int(runtime.hits),int(runtime.power)]
	else:
		var on:=node_for(graph,int(rule.on_id))
		if on.is_empty() or RECOVERY.values(profile,"ToggleOnSpellClassID","SpellClassID")!=[float(rule.on_id)]:return {}
		runtime.merge({"activation":"active","mode":"source_toggle"},true)
		if kind=="repeat":
			var repeated:=buffs(on,"RepeatingSpellBehavior","SpellClassID")
			var effect:=node_for(graph,int(rule.effect_id))
			var hits:=RECOVERY.values(effect,"SpellAttackMultiple","Value")
			if repeated!=[float(rule.effect_id)] or hits.size()!=1:return {}
			summary="ON/OFF → 일반 공격을 원본 효과%d의 %d연사로 교체 · 회당 MP%d/HP%d(원본) · 화살은 기존 게임 규칙 · 위력/거리/발사 간격은 TWILIGHT 설정 · 추가 노멀 공격/중복 지불 없음" % [int(rule.effect_id),int(hits[0]),int(effect.row.MPCost),int(effect.row.HPCost)]
		elif kind=="aura":
			var option:=option_for(graph,17541,"Aura_Spell")
			if option.is_empty() or int(option.Param1)!=int(rule.effect_id):return {}
			summary="ON: 도발 가능한 일반 몬스터 최대10개에 원본10초 도발 · 보스 제외는 TWILIGHT 정책 · 반경%.0fpx/갱신%.1f초(TWILIGHT 설정) · OFF로 중지 · 소모 없음" % [value(id,"radius"),maxf(.1,value(id,"interval"))]
		elif kind=="static":
			var option:=option_for(graph,19153,"Attack_Spell")
			if option.is_empty() or int(option.Param1)!=107343 or bool(option.BySpellAttack):return {}
			summary="ON: 일반 공격 적중 시 원본9%% 발동/번개석3 · 원본107343→107963의123+12d4 계수 · 기존 피해 계산/반경%.0fpx/발동 간격%.1f초는 TWILIGHT 정책 · 임의 공격력 중첩 없음" % [value(id,"radius"),maxf(.1,value(id,"interval"))]
		else:return {}
	runtime["runtime_desc"]=summary
	return {"runtime":runtime,"meta":{"kind":kind,"summary":summary,"source_level":0,"settings_path":RECOVERY.PATH,"root_spell_id":int(rule.spell_id)},"graph":graph}
