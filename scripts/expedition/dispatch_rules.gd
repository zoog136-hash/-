extends RefCounted
## Source card groups/effects, with explicit configurable party aggregation.
static func plan(catalog: RefCounted, cards: Array, policy: Dictionary) -> Dictionary:
	if cards.size()!=4: return {"ok":false,"error":"변신4장이 필요합니다."}
	var ordered := cards.duplicate(true)
	ordered.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var ca:Dictionary=catalog.record("BuffCard",int(a.source_id));var cb:Dictionary=catalog.record("BuffCard",int(b.source_id))
		var ga:int=int(catalog.record("Grade",int(ca.GradeID)).get("GradeValue",0));var gb:int=int(catalog.record("Grade",int(cb.GradeID)).get("GradeValue",0))
		var lowest:bool=policy.get("dispatch_representative","lowest_grade_then_level")=="lowest_grade_then_level"
		if ga!=gb: return ga<gb if lowest else ga>gb
		if int(a.skill_awaken_level)!=int(b.skill_awaken_level): return int(a.skill_awaken_level)<int(b.skill_awaken_level) if lowest else int(a.skill_awaken_level)>int(b.skill_awaken_level)
		return int(a.source_id)<int(b.source_id))
	var rep:Dictionary=ordered[0];var record:Dictionary=catalog.record("BuffCard",int(rep.source_id))
	var group_id:=0
	for group:Dictionary in catalog.rows("MagicDollExpeditionGroup"):
		if int(group.BuffCardDeckID)==1 and int(group.GradeID)==int(record.GradeID) and int(rep.skill_awaken_level)>=int(group.MinLevel) and int(rep.skill_awaken_level)<=int(group.MaxLevel):group_id=int(group.ID)
	if group_id==0:return {"ok":false,"error":"대표 변신의 원본 그룹이 없습니다."}
	var effects:={"hp":0,"heal":0,"luck_seconds":0,"rest_hp_percent":0,"win_permyriad":0}
	var synergies:Array=[]
	for evidence:Dictionary in catalog.synergy_evidence():
		if int(evidence.synergy.ServerLimitsetID)!=0:continue
		var pool:={}
		for member:Dictionary in evidence.members:
			if int(member.ServerLimitsetID)==0:pool[int(member.BuffCardID)]=true
		var matches:=0
		for selected:Dictionary in cards:
			if pool.has(int(selected.source_id)):matches+=1
		if matches<int(policy.get("dispatch_synergy_members",4)):continue
		synergies.append(int(evidence.synergy.ID))
		for entry:Dictionary in evidence.effects:
			var effect:Dictionary=entry.effect
			match int(effect.get("MagicDollExpeditionBonusTypeID",0)):
				1:effects.hp+=int(effect.Value)
				11:effects.heal+=int(effect.Value)
				21:effects.luck_seconds+=int(effect.Value)
				164:effects.rest_hp_percent+=int(effect.Value)
				174:effects.win_permyriad+=int(effect.Value)/100 # UIUnit3 denominator10000 => displayed1% for raw10000.
	return {"ok":true,"representative":rep,"group_id":group_id,"synergy_ids":synergies,"effects":effects}
