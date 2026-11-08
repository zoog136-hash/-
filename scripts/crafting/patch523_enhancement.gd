extends RefCounted
## Exact item/scroll joins; economic/state interpretations are separate policy.
const OPTIONS=preload("res://scripts/inven_option_adapter.gd")
const POLICY="res://data/crafting/patch523_enhancement_policy.json"
static var _settings: Dictionary={}
static var _policy_digest: String=""
static var _invoke_tables: Dictionary={}

static func policy() -> Dictionary:
	if not _settings.is_empty(): return _settings
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(POLICY))
	if parsed is Dictionary:
		_settings=parsed
		_policy_digest=FileAccess.get_sha256(POLICY)
	return _settings

static func item_id(record: Dictionary) -> String:
	if record.get("source")=="inven": return str(record.get("sourceId",""))
	if record.get("source")=="lineagem_patch523" and record.get("source_m_native_item",false) and record.get("source_snapshot")=="patch523" and str(record.get("sourceId",""))=="m523:item:"+str(int(record.get("source_item_class_id",0))): return str(int(record.source_item_class_id))
	return ""

static func prepare(book: Object, record: Dictionary, blessing: int) -> Dictionary:
	if blessing not in [1,2]:return record
	var id: String=item_id(record)
	if id.is_empty() or not book.catalog_identity_matches(record,id): return record
	var runtime: Dictionary=book.equipment_runtime_of(id)
	if runtime.is_empty(): return record
	var settings: Dictionary=policy()
	var basis: Dictionary=record.get("patch523_effect_basis",{})
	if basis.get("selection")=="source_exact_level" and basis.get("sha256")==book.digest and basis.get("policy_sha256")==_policy_digest and int(basis.get("bless_code",-1))==blessing: return record
	# Never replace unknown/custom enchant data from a save or another feature.
	if record.has("enhancement_options") and not record.get("patch523_effect_basis",{}).get("selection","") in ["exact_level_only","source_exact_level"]: return record
	var output: Dictionary=record.duplicate(true)
	var base: Dictionary=OPTIONS.annotate(book.record(id))
	var levels: Dictionary=runtime.options.get(str(blessing),{}).duplicate(true)
	for level: Variant in levels:
		for key: Variant in levels[level]:
			var value: Variant=levels[level][key]
			if value is Dictionary: levels[level][key]=float(value.total)-float(base.get(str(value.base_key),0))*float(value.scale)
	# Preserve the previously delivered, verified seal base subtraction contract.
	if id in ["30671","130551"] and blessing==2:
		var seal: Dictionary=book.supported_seal_options(id,2)
		for level: Variant in seal: levels[level].merge(seal[level],true)
	output["enhancement_options"]=levels
	var extra: Dictionary=runtime.extra_options.get(str(blessing),{}).duplicate(true)
	for level: Variant in extra:
		for key: Variant in extra[level]:
			var value: Variant=extra[level][key]
			if value is Dictionary: extra[level][key]=float(value.total)-float(base.get(str(value.base_key),0))*float(value.scale)
	# The source probability table allows an attempt at +20 while its numeric
	# effect table ends at +20. Keep this single missing effect rank explicit.
	var local_last_rank: bool=false
	if settings.get("missing_level21_effect","")=="continue_last_delta":
		for values: Dictionary in [levels,extra]:
			if values.get("21",{}).is_empty() and not values.get("20",{}).is_empty():
				var next: Dictionary={}
				for key: String in values["20"]:
					var previous: float=float(values.get("19",{}).get(key,values["20"][key]))
					next[key]=float(values["20"][key])*2.0-previous
				values["21"]=next;local_last_rank=true
	output["enhancement_extra_options"]=extra
	if runtime.get("invokes") is Dictionary:
		var invokes: Dictionary=runtime.invokes.get(str(blessing),{}).duplicate(true)
		if settings.get("missing_level21_invoke","")=="keep_level20" and invokes.get("21",[]).is_empty() and not invokes.get("20",[]).is_empty():invokes["21"]=invokes["20"].duplicate(true)
		# New rows store a source option reference once in the private table.
		# Hydrate only this physical item's rows; old delivered inline rows work.
		if not _invoke_tables.has(book.digest):
			var lookup: Dictionary={}
			for option: Dictionary in book.data.get("enchantment",{}).get("InvokeOption",[]):lookup[str(int(option.ID))]=option
			_invoke_tables[book.digest]=lookup
		for rows: Array in invokes.values():
			for effect: Dictionary in rows:
				if not effect.has("option") and effect.has("option_id"):
					var option: Dictionary=_invoke_tables[book.digest].get(str(int(effect.option_id)),{})
					if not option.is_empty():effect["option"]=option.duplicate(true)
				if effect.get("kind")=="attack_source_spell" and effect.get("option") is Dictionary:
					effect["spell_name"]=str(book.data.get("equipment_spell_profiles",{}).get(str(int(effect.option.Param1)),{}).get("source_spell",{}).get("Name",""))
		var has_invokes: bool=false
		for rows: Array in invokes.values():
			if not rows.is_empty():has_invokes=true;break
		if has_invokes:output["patch523_invoke_options"]=invokes
		else:output.erase("patch523_invoke_options")
	output["patch523_blessing_bonus"]=runtime.blessing.duplicate(true)
	output["patch523_effect_basis"]={"sha256":book.digest,"policy_sha256":_policy_digest,"bless_code":blessing,"selection":"source_exact_level","local_level21_extrapolation":local_last_rank,"unconnected_effect_row_ids":runtime.get("unconnected_effect_row_ids",[]).duplicate()}
	return output

static func cursed_rule(book: RefCounted,record: Dictionary,scroll_id: String,level: int,blessing: int) -> Dictionary:
	var settings: Dictionary=policy()
	if scroll_id not in ["137","138","6401","6411"] or not settings.get("source_cursed_scroll_enabled",false):return {"source_rule":true,"success":0.0,"reason":"저주 주문서의 정확한 원본 계열/설정 확인 필요"}
	# Reuse only the exact target/scroll group, cost and quantity. A cursed
	# scroll never inherits the normal scroll's success/destruction outcomes.
	var original: Dictionary=rule(book,record,scroll_id,level,blessing,1)
	if not original.get("source_rule",false) or not original.has("group"):return original
	var loss: int=int(settings.get("source_cursed_level_loss",1))
	var minimum: int=int(settings.get("source_cursed_min_level",0))
	if loss<1 or minimum<0 or level-loss<minimum:return {"source_rule":true,"success":0.0,"reason":"저주 주문서 하락 최저 단계 · TWILIGHT 설정에 따라 재료 보존"}
	original.merge({"success":0.0,"no_change":0.0,"destroy":0.0,"decrease":100.0,"side_effect_level_loss":loss,"forced_decrease":true,"leaps":[],"gain_text":"-%d" % loss,
		"basis":str(original.basis)+" · 공식 각인 저주 안내 -1 / 현재 하락 -%d·최저 단계·계열 공통 적용: TWILIGHT 설정" % loss},true)
	return original

static func selected(rows: Array, group: int, level: int, blessing: int, settings: Dictionary) -> Dictionary:
	var exact: Array=[]
	var defaults: Array=[]
	for row: Dictionary in rows:
		if int(row.ItemEnchantProbabilityGroupID)!=group or int(row.EnchantLevel)!=level: continue
		if int(row.TargetItemBlessCode)==blessing: exact.append(row)
		elif int(row.TargetItemBlessCode)==0: defaults.append(row)
	if exact.size()==1: return exact[0]
	if exact.is_empty() and defaults.size()==1 and settings.get("default_zero_target_selector",false): return defaults[0]
	return {}

static func rule(book: Object, record: Dictionary, scroll_id: String, level: int, blessing: int, scroll_bless: int) -> Dictionary:
	var id: String=item_id(record)
	if id.is_empty(): return {}
	if not book.catalog_identity_matches(record,id):
		return {"source_rule":true,"success":0.0,"reason":"원본 ID와 현재 등록 카탈로그 정체를 확인하세요"} if book.data.get("items",{}).has(id) else {}
	if blessing not in [1,2] or scroll_bless not in [1,2]:return {"source_rule":true,"success":0.0,"reason":"지원하지 않거나 일치하지 않는 원본 축복 상태입니다"}
	var scroll_class: Dictionary=book.item_entry(scroll_id).get("item_class",{})
	if scroll_class.is_empty() or scroll_class.get("TestItem",false) or not str(scroll_class.get("ServiceRegionCode","")).is_empty():return {"source_rule":true,"success":0.0,"reason":"원본 테스트·서비스 지역 자격을 확인하세요"}
	# Preserve the narrower, publicly verified seal eligibility from the earlier
	# delivered path. A default-zero selector must never widen that contract.
	if id in ["30671","130551"]:
		if scroll_id=="320802" and (blessing!=1 or level<0 or level>7):return {"source_rule":true,"success":0.0,"reason":"일반 인장 전용 확인된 주문서입니다"}
		if scroll_id=="166044" and (blessing not in [1,2] or level<4 or level>7):return {"source_rule":true,"success":0.0,"reason":"보호 주문서의 확인된 인장 단계가 아닙니다"}
	var evidence: Dictionary=book.enhancement_evidence(int(id),int(scroll_id),level,blessing,scroll_bless)
	if evidence.groups.size()!=1: return {"source_rule":true,"success":0.0,"reason":"원본 장비·주문서 그룹 또는 자격 불일치"}
	var group: int=int(evidence.groups[0])
	var settings: Dictionary=policy()
	var probability: Dictionary=selected(evidence.probabilities,group,level,blessing,settings)
	var cost: Dictionary=selected(evidence.costs,group,level,blessing,settings)
	var tables: Dictionary=book.data.get("enchantment",{})
	var view_ok: bool=false
	for row: Dictionary in tables.get("ItemEnchantProbabilityView",[]):
		if int(row.ItemEnchantProbabilityGroupID)==group and int(row.EnchantLevel)==level and int(row.ServerLimitSetID)==0: view_ok=true
	var total: int=int(probability.get("Success",0))+int(probability.get("Remain",0))+int(probability.get("Vaporize",0))+int(probability.get("SideEffect",0))
	if total!=1000000 or cost.is_empty() or not view_ok or settings.get("cost_currency")!="adena": return {"source_rule":true,"success":0.0,"reason":"원본 단계·확률·비용 조건을 확인하세요"}
	var count: int=int(cost.ConsumeAmount) if int(cost.ConsumeAmount)>0 else int(settings.get("zero_consume_scrolls",0))
	if count<1 or count>10000 or int(cost.Cost)<0: return {"source_rule":true,"success":0.0,"reason":"강화 소비 설정을 확인하세요"}
	var safe: int=0
	for current: int in range(21):
		var row: Dictionary=selected(tables.get("BmItemEnchantProView",[]),group,current,blessing,settings)
		if int(row.get("Success",0))!=1000000: break
		safe=current+1
	var leaps: Array=[{"gain":1,"probability":1000000}]
	var disabled: bool=false
	for link: Dictionary in book.item_entry(scroll_id).get("item_bonuses",[]):
		var b: Dictionary=book.bonus_row(str(int(link.BonusID)))
		if int(b.get("BonusTypeID",0))==8402: disabled=bool(settings.get("leap_disabled_bonus_presence",true)) or int(b.get("Value",0))!=0
	if scroll_bless==2 and not disabled:
		var leap_group: int=0
		for row: Dictionary in tables.get("ItemEnchantProbabilityGroup",[]):
			if int(row.ID)==group: leap_group=int(row.ItemBlessEnchantID)
		var candidates: Array=[]
		var sum: int=0
		for row: Dictionary in tables.get("ItemBlessEnchantProbability",[]):
			if int(row.ItemBlessEnchantID)==leap_group and int(row.CurrentEnchantLevel)==level:
				candidates.append({"gain":int(row.LeapCount),"probability":int(row.Probability)})
				sum+=int(row.Probability)
		if sum==1000000: leaps=candidates
	var gains: PackedStringArray=[]
	for row: Dictionary in leaps: gains.append("+%d" % int(row.gain))
	var material: String=""
	var material_id: int=int(book.item_entry(id).item_class.MaterialID)
	for row: Dictionary in tables.get("Material",[]):
		if int(row.ID)==material_id: material=str(row.Name)
	return {"source_rule":true,"success":float(probability.Success)/10000.0,"no_change":float(probability.Remain)/10000.0,
		"destroy":float(probability.Vaporize)/10000.0,"decrease":float(probability.SideEffect)/10000.0,
		"safe_level":safe,"cost":int(cost.Cost),"count":count,"group":group,"leaps":leaps,"gain_text":" / ".join(gains),
		"side_effect_level_loss":maxi(0,int(settings.get("side_effect_level_loss",1))),
		"basis":"원본523 그룹 %d · 재질 %s · 통화/수량0/기본축복선택: 게임 설정" % [group,material]}
