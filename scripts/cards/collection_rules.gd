extends RefCounted
## Permanent acquisition collections. No registration, consumption, randomness,
## save writes, source-name aliases, or changes to equipment collections.
const Cards=preload("res://scripts/card_draw_fusion.gd")
const ExistingStats=preload("res://scripts/collections/equipment_collection_stats.gd")
const EXTRA_EFFECTS: Array[String]=["hp_regeneration:flat","mp_regeneration:flat","potion_heal:flat","potion_heal:percent"]
var definitions: Array[Dictionary]=[]
var availability: Dictionary={}
var error: String=""

func configure(data: Dictionary,catalog: Dictionary) -> bool:
	definitions.clear();availability.clear();error=""
	if int(data.get("schema_version",0))!=1 or not data.get("collections") is Array:return _fail("컬렉션 데이터 버전 오류")
	var known: Dictionary={}
	for category: String in Cards.CATEGORIES:
		known[category]={}
		for record: Dictionary in catalog.get(category,[]):known[category][Cards.card_id(record)]=record
	var identities: Dictionary={}
	for raw: Variant in data.get("collections",[]):
		if not raw is Dictionary:return _fail("컬렉션 정의 형식 오류")
		var row: Dictionary=raw.duplicate(true)
		var identity: String=str(row.get("id",""))
		var category: String=str(row.get("category",""))
		if identity.is_empty() or identities.has(identity) or not Cards.CATEGORIES.has(category):return _fail("컬렉션 ID/분류 오류")
		identities[identity]=true
		if not row.get("requirements",[]) is Array or row.requirements.is_empty() or not row.get("effects",[]) is Array:return _fail("컬렉션 조건/효과 오류")
		var problems: Array[String]=[]
		if not row.get("source") is Dictionary:return _fail("컬렉션 출처 형식 오류")
		var source: Dictionary=row.source
		var date: String=str(source.get("date",""))
		if not bool(source.get("verified_pre2026",false)) or date.length()!=10 or date>"2025-12-31" or date<"2017-06-21":problems.append("source_version_unverified")
		var seen: Dictionary={}
		for value: Variant in row.requirements:
			if not value is Dictionary:return _fail("컬렉션 카드 조건 형식 오류")
			var requirement: Dictionary=value
			var cat: String=str(requirement.get("category",category))
			var key: String=str(requirement.get("id",""))
			if not known.has(cat) or not known[cat].has(key):problems.append("card_unmapped:"+cat+":"+str(requirement.get("name",key)))
			if seen.has(cat+":"+key):return _fail("같은 영구 획득 카드를 중복 조건으로 계산할 수 없습니다")
			seen[cat+":"+key]=true
			requirement["category"]=cat
			if bool(requirement.get("awakened",false)):problems.append("awakening_collection_separate")
		if row.effects.is_empty():problems.append("effect_unverified")
		for value: Variant in row.effects:
			if not value is Dictionary:return _fail("컬렉션 효과 형식 오류")
			var effect: Dictionary=value
			var code: String=effect_code(effect)
			if not ExistingStats.SUPPORTED.has(code) and not EXTRA_EFFECTS.has(code):problems.append("effect_unsupported:"+code)
			var amount: Variant=effect.get("value")
			if not (amount is int or amount is float) or not is_finite(float(amount)):return _fail("컬렉션 효과 수치 오류")
			if (str(effect.get("unit",""))=="flat" or code=="potion_heal:percent") and float(amount)!=floorf(float(amount)):problems.append("fractional_effect_unsupported:"+code)
		availability[identity]=problems
		definitions.append(row)
	return true

func _fail(message: String) -> bool:
	error=message;definitions.clear();availability.clear();return false

static func effect_code(effect: Dictionary) -> String:
	return str(effect.get("key",""))+":"+str(effect.get("unit",""))

func derive(card_state: Dictionary) -> Dictionary:
	var owned: Dictionary=card_state.get("owned",{})
	var views: Array[Dictionary]=[]
	var totals: Dictionary={}
	var completed: Dictionary={}
	for definition: Dictionary in definitions:
		var row: Dictionary=definition.duplicate(true)
		var met: int=0
		for requirement: Dictionary in row.requirements:
			# First acquisition is retained after all spendable duplicates are gone.
			var acquired: bool=bool(owned.get(requirement.category,{}).get(str(requirement.id),false))
			requirement["met"]=acquired
			if acquired:met+=1
		row["met_count"]=met
		row["conditions_met"]=met==row.requirements.size()
		row["problems"]=(availability[str(row.id)] as Array).duplicate()
		row["available"]=row.problems.is_empty()
		row["completed"]=row.available and row.conditions_met
		if row.completed:
			completed[str(row.id)]=true
			for effect: Dictionary in row.effects:
				var code: String=effect_code(effect)
				totals[code]=float(totals.get(code,0.0))+float(effect.value)
		views.append(row)
	return {"rows":views,"totals":totals,"completed":completed}
