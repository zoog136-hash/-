extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Source definitions and explicit TWILIGHT adapters; not a server emulator.
const PATH = "res://data/growth/symbol_source523.json"
const Combat = preload("res://scripts/growth/symbol_combat.gd")
const CommonSource = preload("res://scripts/resources/current523_definition_rows.gd")
var data: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("source_snapshot") == "patch523":
		data = parsed
		_adopt_original_rows()

func _original_row(table: String, cached: Dictionary) -> Dictionary:
	var value: Variant = cached.get("ID")
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or absf(float(value))>9007199254740991.0: return cached
	var original: Dictionary = CommonSource.row(table,int(value))
	# Adopt only the same complete selected row. Missing/different originals
	# never expand the cache, alter its derived effects or replace its policies.
	return original if original.get("ID") == value and original == cached else cached

func _original_field(owner: Dictionary, field: String, table: String) -> void:
	var value: Variant = owner.get(field)
	if value is Dictionary: owner[field] = _original_row(table,value)

func _original_list(owner: Dictionary, field: String, table: String) -> void:
	var values: Variant = owner.get(field)
	if not values is Array: return
	for index: int in range(values.size()):
		if values[index] is Dictionary: values[index] = _original_row(table,values[index])

func _original_full_list(owner: Dictionary, field: String, table: String) -> void:
	var cached: Variant = owner.get(field)
	if not cached is Array: return
	var metadata: Dictionary = CommonSource.table_metadata(table)
	if metadata.get("path") != "content/"+table+".json": return
	var original: Array[Dictionary] = CommonSource.rows(table)
	if metadata.get("row_count") != original.size(): return
	# Only compiler-declared whole-table arrays use this path. Equality retains
	# every original row, its position and the existing empty-array meaning.
	if original == cached: owner[field] = original

func _original_detail(detail: Dictionary, table: String) -> void:
	# These are the exact raw-row fields produced by import_symbol523.detail.
	_original_field(detail,"row",table)
	_original_field(detail,"bonus","Bonus")
	_original_field(detail,"bonus_type","BonusType")
	_original_field(detail,"unit","Unit")
	if detail.get("bonus",{}).get("BonusApplicationTypeID") == 2:
		_original_field(detail,"application_target","SpecialResistanceType")
	var intervals: Variant = detail.get("nested_intervals")
	if not intervals is Array: return
	for interval: Variant in intervals:
		if not interval is Dictionary: continue
		_original_field(interval,"row","IntervalBonus")
		_original_field(interval,"bonus","Bonus")
		_original_field(interval,"bonus_type","BonusType")
		_original_field(interval,"category","IntervalBonusCategory")

func _adopt_original_rows() -> void:
	var identity: Dictionary = CommonSource.identity()
	if identity.is_empty() or identity.get("source_sha256") != CommonSource.SOURCE_SHA or identity.get("source_snapshot") != data.get("source_snapshot"): return
	var emblems: Variant = data.get("emblems")
	if emblems is Dictionary:
		for native: Variant in emblems.values():
			if not native is Dictionary: continue
			_original_field(native,"definition","SymbolType")
			_original_list(native,"costs","SymbolEnchantCost")
			var normal: Variant = native.get("normal")
			if normal is Array:
				for detail: Variant in normal:
					if detail is Dictionary: _original_detail(detail,"SymbolBonus")
			var absolutes: Variant = native.get("absolute")
			if absolutes is Dictionary:
				for grade: Variant in absolutes.values():
					if not grade is Dictionary: continue
					_original_field(grade,"payment","SymbolAbsoluteBonusView")
					var options: Variant = grade.get("options")
					if options is Array:
						for detail: Variant in options:
							if detail is Dictionary: _original_detail(detail,"SymbolAbsoluteBonusView")
	for pair: Array in [["constants","SymbolConstant"],["probabilities","SymbolEnchantProbability"],["payments","SymbolPayment"],["enchant_levels","SymbolEnchant"]]:
		_original_full_list(data,pair[0],pair[1])
	_original_list(data,"dates","DateTimes_Korean")
	var items: Variant = data.get("items")
	if items is Dictionary:
		for key: Variant in items:
			if items[key] is Dictionary: items[key] = _original_row("ItemClass",items[key])
	var grades: Variant = data.get("item_grades")
	if grades is Dictionary:
		for grade: Variant in grades.values():
			if grade is Dictionary: _original_field(grade,"row","Grade")
	var item_bonuses: Variant = data.get("item_bonuses")
	if item_bonuses is Array:
		for detail: Variant in item_bonuses:
			if not detail is Dictionary: continue
			_original_field(detail,"row","ItemBonus")
			_original_field(detail,"bonus","Bonus")
			_original_field(detail,"type","BonusType")
	_original_field(data,"delete_time_application","BonusApplicationType")
	var invoke: Variant = data.get("veil_invoke")
	if invoke is Dictionary:
		_original_field(invoke,"option","InvokeOption")
		_original_field(invoke,"type","InvokeOptionType")

func apply(config: Dictionary) -> void:
	if data.is_empty(): return
	for row: Dictionary in config.emblems:
		var native: Dictionary = data.emblems.get(str(row.id),{})
		if native.is_empty(): continue
		row["source_symbol_type_id"] = native.definition.ID
		row["source_server_limit_set_id"] = native.definition.ServerLimitSetID
		row["verified_costs"] = {}
		for cost: Dictionary in native.costs: row.verified_costs[str(int(cost.EnchantCount)+1)] = int(cost.Cost)
		row.effects = native.effects.duplicate(true)
		if not Combat.estimates():
			for stage: Dictionary in row.effects:
				for key: String in stage.keys():
					if key.begins_with("local_"):stage.erase(key)
		row["source_absolute"] = native.absolute.duplicate(true)
		row["deferred_effects"] = []
		for detail: Dictionary in native.normal:
			var label: String = str(detail.description.get("Description",detail.bonus_type.Name))
			if detail.status == "deferred" and not row.deferred_effects.has(label): row.deferred_effects.append(label)
			if str(detail.get("local_policy","")).begins_with("estimate:") and not Combat.estimates():row.deferred_effects.append(label+" · 자체 근사 꺼짐")
		for grade: int in range(1,6): row.absolute_key_costs[grade-1] = int(native.absolute[str(grade)].payment.ForceOpenCost)
	config["source_snapshot"] = "patch523"
	for constant: Dictionary in data.constants:
		if constant.Name == "ProbabilityChangeCost": config.reroll_cost = int(constant.Value)
	# Baseline odds already in the game are retained; source min/max are not
	# themselves a declaration of a baseline or of a uniform sampling scheme.
	# Existing offline availability is retained, without interpreting server sets.

func probability_rows(stage: int) -> Array:
	var result: Array = []
	for row: Dictionary in data.get("probabilities",[]):
		if int(row.Enchant) == stage: result.append(row)
	return result

func special_rate(stage: int, jump: int) -> float:
	for row: Dictionary in probability_rows(stage):
		if int(row.DeltaEnchant) == jump: return float(row.SpecialRouteProbability)/1000000.0
	return 0.0

func enchant_limit() -> int:
	# Enchant is the physical enhancement stage. EnchantLevel and UIText are
	# presentation metadata and must not replace it with the Roman tier (0..10).
	var rows: Variant = data.get("enchant_levels")
	if not rows is Array or rows.is_empty() or rows.size()>1000: return -1
	var stages: Dictionary = {}
	var maximum: int = -1
	for raw: Variant in rows:
		if not raw is Dictionary: return -1
		var value: Variant = raw.get("Enchant")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<0 or value>=rows.size(): return -1
		var stage: int = int(value)
		if stages.has(stage): return -1
		stages[stage] = true
		maximum = maxi(maximum,stage)
	if maximum<1 or maximum+1!=stages.size(): return -1
	for stage: int in range(maximum+1):
		if not stages.has(stage): return -1
	# Existing per-symbol effect arrays must cover the source stages before a
	# transaction can reach them. Do not unlock an unsupported new stage.
	var symbols: Variant = data.get("emblems")
	if not symbols is Dictionary or symbols.is_empty(): return -1
	for native: Variant in symbols.values():
		if not native is Dictionary or not native.get("effects") is Array or native.effects.size()<=maximum: return -1
	return maximum

func absolute(id: String, grade: int) -> Dictionary:
	return data.get("emblems",{}).get(id,{}).get("absolute",{}).get(str(grade),{})

func absolute_effects(id: String, grades: Array) -> Dictionary:
	var result: Dictionary = {}
	for grade: Variant in grades:
		for detail: Dictionary in absolute(id,int(grade)).get("options",[]):
			if str(detail.get("local_policy","")).begins_with("estimate:") and not Combat.estimates():continue
			for key: String in detail.effects: result[key] = float(result.get(key,0))+float(detail.effects[key])
	return result

func absolute_block(id: String, grade: int) -> String:
	var row: Dictionary = absolute(id,grade)
	if row.is_empty(): return "원본 절대 옵션 정의 없음"
	for detail: Dictionary in row.options:
		if detail.status != "applied": return "현재 전투에 연결되지 않은 절대 효과 · 보류"
		if str(detail.get("local_policy","")).begins_with("estimate:") and not Combat.estimates():return "자체 전투 근사 설정이 꺼져 있습니다"
	return ""

func options_text(id: String, stage: int, grades: Array = []) -> Array[String]:
	var result: Array[String] = []
	var native: Dictionary = data.get("emblems",{}).get(id,{})
	for detail: Dictionary in native.get("normal",[]):
		if int(detail.row.Enchant)>stage or detail.status == "applied": continue
		result.append("%d단계: %s · 적용 보류" % [int(detail.row.Enchant),option_text(detail)])
	for grade: int in range(1,6):
		for detail: Dictionary in absolute(id,grade).get("options",[]):
			var off: bool=str(detail.get("local_policy","")).begins_with("estimate:") and not Combat.estimates()
			result.append("절대 %d: %s · %s" % [grade,option_text(detail),"자체 근사 꺼짐" if off else "적용" if grades.has(grade) and detail.status=="applied" else "미개방" if detail.status=="applied" else "효과 연결 보류"])
	return result

func option_text(detail: Dictionary) -> String:
	var label: String = str(detail.get("display_name",detail.description.get("Description",detail.bonus_type.Name)))
	var policy: String=str(detail.get("local_policy",""))
	var converted: bool=not policy.is_empty()
	var estimated: bool=policy.begins_with("estimate:")
	if converted: label=label.replace("PVP","PVE").replace("PvP","PvE")
	if label.is_empty():label="아머 브레이크 피해 감소"
	var note: String=" · 자체 근사 · 설정 가능" if estimated else " · 기존 단독플레이 처리" if converted else ""
	if converted and str(detail.bonus_type.Name).contains("PVP") and not estimated:note=" · 원본 PVP → 단독플레이 PVE"
	if estimated and not Combat.estimates():note+=" · 꺼짐"
	if estimated and str(detail.bonus_type.Name).contains("ScaleForArmorBreak"):return label+" +%s%%" % str(detail.effects.values()[0])+note
	if detail.bonus_type.Name == "HPIntervalBonus" and not detail.get("nested_intervals",[]).is_empty():
		var interval: Dictionary = detail.nested_intervals[0]
		return "HP %s%% 이하 피해량 감소 +%s%%" % [str(interval.row.High),str(float(interval.bonus.Value)/10000.0)]
	var value: float = float(detail.bonus.Value)
	var suffix: String = ""
	if detail.bonus_type.Name=="AttackedMeleeMagicDamageScaleForArmorBreak": return label+" · 원문 단위 해석 보류"
	match str(detail.unit.Name):
		"Percentage": value /= 10000.0; suffix = "%"
		"ValuePercent": suffix = "%"
		"Value", "TrueFalse": pass
		"Weight": value /= 100.0
		_: return label+" · 세부 효과 확인 중"
	return "%s %s%s%s%s%s" % [label,"+" if value>=0 else "",str(value),suffix," · 조건부 효과" if int(detail.bonus.BonusApplicationTypeID)!=0 and detail.status!="applied" else "",note]

func item_key(id: int) -> String:
	return "m523:item:"+str(id)

func item_record(id: int) -> Dictionary:
	var item: Dictionary = data.get("items",{}).get(str(id),{})
	if item.is_empty(): return {}
	var grade: String = str(data.get("item_grades",{}).get(str(int(item.GradeID)),{}).get("name_ko","미확인"))
	for row: Dictionary in data.get("recharge",[]):
		if int(row.ItemClassID) != id: continue
		return {"name":str(row.name_ko),"type":"문양 재료","slot":"","grade":grade,"desc":"축복 포인트 %d 충전" % int(row.amount),"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":item_key(id),"source_item_class_id":id,"source_grade_id":int(item.GradeID),"source_original_item":item.duplicate(true)}
	if id == 231772:
		return {"name":str(data.item_names[str(id)]),"type":"문양 재료","slot":"","grade":grade,"desc":"30단계 미만 문양 초기화 · 일반 강화 포인트 환급","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":item_key(id),"source_item_class_id":id,"source_grade_id":int(item.GradeID),"source_original_item":item.duplicate(true)}
	return {}

func reset_material(instance: Dictionary) -> bool:
	var record: Variant = instance.get("record")
	if not record is Dictionary or record.get("source_snapshot") != "patch523" or record.get("source") != "lineagem_patch523": return false
	var raw_id: Variant = record.get("source_item_class_id",0)
	if not (raw_id is int or raw_id is float) or not is_finite(float(raw_id)) or float(raw_id) != floorf(float(raw_id)) or raw_id < 1 or raw_id > 1000000000: return false
	var id: int = int(raw_id)
	var bound: bool = false
	for current: Variant in data.get("currency_backing",{}).get("current_Currency712_item_ids",[]):
		if int(current) == id: bound = true
	if not bound: return false
	# Temporary variants have timezone-less expiry mappings; do not guess.
	if id != 231772 or record.get("sourceId") != item_key(id) or instance.get("name") != record.get("name"): return false
	return NATIVE_FIELDS.full(record).get("source_original_item") == data.items.get(str(id))

func material(instance: Dictionary) -> bool:
	return reset_material(instance) or not recharge(instance).is_empty()

func install(catalog: Dictionary, loot: Dictionary) -> void:
	# Definitions only; neither drop odds nor ownership is granted here.
	var ids: Array = [231772]
	for row: Dictionary in data.get("recharge",[]): ids.append(int(row.ItemClassID))
	for id: int in ids:
		var record: Dictionary = item_record(id)
		if record.is_empty() or not material({"name":record.name,"record":record}): continue
		var exists: bool = false
		for previous: Dictionary in catalog.get("아이템",[]):
			if previous.get("sourceId") == record.sourceId: exists = true
		if not exists: catalog["아이템"].append(record)
		if not loot.get("by_name",{}).has(str(record.name)): loot.by_name[str(record.name)] = record

func prepare_pickup(drop: Dictionary, instances: Dictionary, next_id: int) -> Dictionary:
	var unchanged: Dictionary = {"item_instances":instances,"next_item_instance_id":next_id}
	if drop.has("physical_item") or not drop.get("item_record") is Dictionary: return unchanged
	var record: Dictionary = drop.item_record
	if not material({"name":drop.get("item_name"),"record":record}): return unchanged
	var quantity: Variant = drop.get("quantity",0)
	if not (quantity is int or quantity is float) or float(quantity) != floorf(float(quantity)) or quantity < 1 or quantity > 10000: return unchanged
	var result: Dictionary = instances.duplicate(true)
	var candidate: int = maxi(1,next_id)
	for index: int in range(int(quantity)):
		while result.has(str(candidate)): candidate += 1
		result[str(candidate)] = {"name":str(record.name),"level":0,"record":NATIVE_FIELDS.full(record).duplicate(true)}
		candidate += 1
	return {"item_instances":result,"next_item_instance_id":candidate}

func recharge(instance: Dictionary) -> Dictionary:
	var record: Variant = instance.get("record")
	if not record is Dictionary or record.get("source_snapshot") != "patch523" or record.get("source") != "lineagem_patch523": return {}
	var raw_id: Variant = record.get("source_item_class_id",0)
	if not (raw_id is int or raw_id is float) or not is_finite(float(raw_id)) or float(raw_id) != floorf(float(raw_id)) or raw_id < 1 or raw_id > 1000000000: return {}
	var id: int = int(raw_id)
	if record.get("sourceId") != item_key(id): return {}
	if instance.get("name") != record.get("name"): return {}
	for row: Dictionary in data.get("recharge",[]):
		if int(row.ItemClassID) != id: continue
		if row.TestItem: return {}
		var item: Dictionary = data.items.get(str(id),{})
		if item.is_empty() or item.TestItem: return {}
		# Timezone-less expiry and additional use conditions cannot be silently
		# dropped. Base holy water remains usable; event definitions remain data.
		for detail: Dictionary in data.item_bonuses:
			if int(detail.row.ItemClassID) == id and detail.type.Name not in ["IntangibleItemClassID","IntangibleItemAmount"]: return {}
		if NATIVE_FIELDS.full(record).get("source_original_item") != item: return {}
		return {"item_id":id,"amount":int(row.amount),"name":str(record.name)}
	return {}
