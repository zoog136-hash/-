extends RefCounted
## Numeric card definitions come only from the supplied current523 archive.
## Saved namespaces are code ABI; they are never an old asset/data dependency.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ACTIVE_OPTIONS = preload("res://scripts/cards/active_card_options523.gd")
const IDENTITIES = preload("res://scripts/cards/current523_card_identity.gd")
const CATEGORIES = {1:"변신",2:"마법인형",98:"성물"}
const DECK_NAMES = {1:"PolymorphCardDeck",2:"MagicDollCardDeck",98:"HolyStuffCardDeck"}
const FLAT_FIELDS = {"HPPlus":"hpFlat","MPPlus":"mpFlat","Strength":"strFlat","Dexterity":"dexFlat","Intelligence":"intFlat","Wisdom":"wisFlat","Constitution":"conFlat","Charisma":"chaFlat","MagicResist":"mr","DamageReduction":"damage_reduction"}
const ASSET_FIELDS = ["DisplayBaseAssetID","DisplayScreenAssetID","DisplayDecoAssetID","IllustrationAssetID","HidedIllustrationAssetID"]
const TABLES = ["BuffCard","BuffCardDeck","BuffCardByClass","BuffBonus","Bonus","BonusType","Unit","UIUnit","BonusApplicationType","SpecialResistanceType","InvokeOption","InvokeOptionType","SpellClass","ItemClass","ElementalType","NpcGroup","NpcClassForNpcGroup","Grade","DescData_Korean","Class","PolymorphEntityForSet","PolymorphEntity","NpcClass","AssetView","AssetType"]
static var problem: String = ""
static var npc_problem: String = ""

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _description(id: Variant, fallback: String = "") -> String:
	if not _integer(id) or int(id) <= 0: return fallback
	var row: Dictionary = SOURCE.row("DescData_Korean",int(id))
	var text: Variant = row.get("Description")
	return str(text) if text is String and not str(text).is_empty() else fallback

static func _reference(table: String, id: Variant, blockers: Array[String]) -> Dictionary:
	if not _integer(id):
		blockers.append("invalid_source_reference:"+table)
		return {}
	var row: Dictionary = SOURCE.row(table,int(id))
	if row.is_empty(): blockers.append("missing_source_reference:"+table+":"+str(int(id)))
	return row

static func _assets(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ASSET_FIELDS:
		var id: Variant = source.get(field)
		if not _integer(id) or int(id) == 0:
			result[field] = null
			continue
		var views: Array[Dictionary] = SOURCE.related("AssetView","AssetId",int(id))
		if views.size() != 1:
			result[field] = {"asset_id":int(id),"status":"source_asset_reference_unavailable","reference_only":true,"pixels_available":false}
			continue
		var asset: Dictionary = views[0]
		var type: Dictionary = SOURCE.row("AssetType",int(asset.AssetTypeId)) if _integer(asset.get("AssetTypeId")) else {}
		var reference: Dictionary = {"asset_id":asset.AssetId,"asset_type_id":asset.get("AssetTypeId"),"asset_view":asset,"asset_type_row":type,"reference_only":true,"pixels_available":false}
		if type.get("Name") is String and type.get("Path") is String and asset.get("FilePath") is String:
			reference["asset_type"] = type.Name
			reference["path"] = str(type.Path)+str(asset.FilePath)
		else:
			reference["status"] = "source_asset_type_reference_unavailable"
		result[field] = reference
	return result

static func _direct(link: Dictionary, bonus: Dictionary) -> bool:
	for field: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
		if link.get(field,0) != 0: return false
	return bonus.get("BonusApplicationTypeID") == 0 and bonus.get("BonusApplicationTargetID") == 0

static func _sprite_references(unit: Dictionary, bonus: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _integer(bonus.get("Value")): return result
	var id: int = int(bonus.Value)
	if unit.get("Name") == "PolymorphSetID":
		for link: Dictionary in SOURCE.related("PolymorphEntityForSet","PolymorphSetID",id):
			var entity: Dictionary = SOURCE.row("PolymorphEntity",int(link.PolymorphEntityID)) if _integer(link.get("PolymorphEntityID")) else {}
			result.append({"kind":"PolymorphSetID","id":id,"link":link,"entity":entity,"reference_only":true,"can_execute":false})
	elif unit.get("Name") == "NPCClassID":
		result.append({"kind":"NPCClassID","id":id,"npc":SOURCE.row("NpcClass",id),"reference_only":true,"can_execute":false})
	return result

static func _card(raw: Dictionary, deck: Dictionary, source_id: String, identity: Dictionary, blockers: Array[String]) -> Dictionary:
	var grade: Dictionary = _reference("Grade",raw.get("GradeID"),blockers)
	if grade.is_empty(): return {}
	for field: String in ["GradeTierID","BuffClassID","DisplaySpriteID","ServerLimitSetID","StartDateTimeID","EndDateTimeID"]:
		if not _integer(raw.get(field)): blockers.append("invalid_source_card_field:"+field)
	for field: String in ["IsNoMergeOut","IsNoSwapOut"]:
		if typeof(raw.get(field)) != TYPE_BOOL: blockers.append("missing_source_card_flag:"+field)
	if not blockers.is_empty(): return {}
	var saved_namespace: String = str(source_id.split(":")[0])
	var record: Dictionary = {
		"name":_description(raw.get("DescID"),str(raw.get("Name",""))),
		"grade":_description(grade.get("DescID"),str(grade.get("Name",""))),"type":"공통",
		"source":"lineagem_base508" if saved_namespace == "m508" else "lineagem_patch523","sourceId":source_id,
		"source_snapshot":"patch523","content_snapshot":"patch523","source_content_snapshot":"patch523",
		"source_identity_namespace":saved_namespace,"source_tag_scope":"saved_identity_ABI_only; definition_origin_is_current523",
		"source_definition_archive":identity.duplicate(true),
		"source_card_id":raw.ID,"source_deck_id":raw.BuffCardDeckID,"source_grade_id":raw.GradeID,"source_grade_tier_id":raw.GradeTierID,
		"source_internal_name":raw.get("Name",""),"source_display_sprite_id":raw.DisplaySpriteID,
		"source_original_card":raw.duplicate(true),"source_deck":deck.duplicate(true),"source_grade":grade,
		"source_class_variants":SOURCE.related("BuffCardByClass","BuffCardID",int(raw.ID)),
		"source_merge_out_disabled":raw.IsNoMergeOut,"source_swap_out_disabled":raw.IsNoSwapOut,
		"source_ui_assets":_assets(raw),"source_bonuses":[],"source_stat_application":[],
		"sourceOptions":[],"sourceOptionsRaw":[],"source_typed_sprite_references":[],
		"source_declared_patch523_sprite_ids":[],"source_inworld_sprite_ids":[],
		"source_visual_status":"patch523_original_pixels_unconnected","image_path":""}
	if saved_namespace == "m523": record["source_draw_pool_pending"] = true
	_apply_buff(record,int(raw.BuffClassID),blockers)
	if not blockers.is_empty(): return {}
	record["source_original"] = {"source_snapshot":"patch523","content_snapshot":"patch523", "card_id":raw.ID,"deck_id":raw.BuffCardDeckID,
		"grade_id":raw.GradeID,"grade_tier_id":raw.GradeTierID,"buff_class_id":raw.BuffClassID,
		"server_limit_set_id":raw.ServerLimitSetID,"start_datetime_id":raw.StartDateTimeID,"end_datetime_id":raw.EndDateTimeID,
		"source_definition_archive":identity.duplicate(true)}
	return record

## Bonus-derived fields of a card record from one BuffClass (BuffBonus rows):
## source_bonuses, options, flat stat fields, typed sprite references.
static func _apply_buff(record: Dictionary, buff_class_id: int, blockers: Array[String]) -> void:
	var options: Array[String] = []
	var display: Array[Dictionary] = []
	var spell_options: Dictionary = {}
	var npc_group_damage: Dictionary = {}
	var invokes: Array[Dictionary] = []
	var sprites: Dictionary = {}
	for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",buff_class_id):
		var bonus: Dictionary = _reference("Bonus",link.get("BonusID"),blockers)
		var type: Dictionary = _reference("BonusType",bonus.get("BonusTypeID"),blockers) if not bonus.is_empty() else {}
		var unit: Dictionary = _reference("Unit",type.get("UnitID"),blockers) if not type.is_empty() else {}
		var text: String = _description(type.get("DescID"))
		var detail: Dictionary = {"buff_bonus":link,"bonus":bonus,"bonus_type":type,"unit":unit,"localized_description":text,"application":"raw_preserved_pending_semantics"}
		if unit.get("ID") == 1 and _direct(link,bonus) and _integer(bonus.get("Value")):
			detail.application = "unconditional_native_value"
			options.append((text if not text.is_empty() else str(type.get("Name","")))+" "+("+" if int(bonus.Value) >= 0 else "")+str(int(bonus.Value)))
			var type_name: String = str(type.get("Name",""))
			if FLAT_FIELDS.has(type_name):
				var field: String = FLAT_FIELDS[type_name]
				record[field] = int(record.get(field,0))+int(bonus.Value)
				record.source_stat_application.append({"field":field,"source_bonus_id":bonus.ID,"rule":"Unit1_Value_direct"})
		var line: Dictionary = _card_option(link,bonus,type,unit,text)
		if not line.is_empty(): display.append(line)
		var stat: Dictionary = _active_stat(link,bonus,type,unit,line)
		if not stat.is_empty():
			record[stat.field] = record.get(stat.field,0.0)+stat.amount
			detail.application = "native_active_card_stat"
			record.source_stat_application.append({"field":stat.field,"source_bonus_id":bonus.ID,"rule":"verified_native_card_unit"})
		elif _is_unconditional(link) and line.has("amount") and int(bonus.get("BonusApplicationTypeID",0))==1:
			var spell_field: String = ACTIVE_OPTIONS.spell_field(str(type.get("Name","")),str(unit.get("Name","")))
			if not spell_field.is_empty():
				var spell_id: int = int(bonus.BonusApplicationTargetID)
				if not spell_options.has(spell_id):spell_options[spell_id]={}
				spell_options[spell_id][spell_field] = float(spell_options[spell_id].get(spell_field,0.0))+float(line.amount)
				detail.application = "native_active_card_spell"
		elif _is_unconditional(link) and line.has("amount") and type.get("Name")=="TargetDamageBonus" and unit.get("Name")=="Value":
			var app: Dictionary = SOURCE.row("BonusApplicationType",int(bonus.get("BonusApplicationTypeID",-1)))
			if app.get("Name")=="NpcGroup":
				for member: Dictionary in SOURCE.related("NpcClassForNpcGroup","NpcGroupID",int(bonus.BonusApplicationTargetID)):
					var npc_id: int = int(member.get("NpcClassID",0))
					if npc_id>0 and int(member.get("ServerLimitSetID",-1))==0:npc_group_damage[npc_id]=int(npc_group_damage.get(npc_id,0))+int(line.amount)
				if not npc_group_damage.is_empty():detail.application = "native_active_card_npc_group"
		if int(record.source_deck_id) in [1,98] and type.get("Name")=="InvokeOption" and unit.get("Name")=="Percentage" and int(bonus.get("BonusApplicationTypeID",0))==10 and _is_unconditional(link):
			invokes.append({"link":link,"type":type,"unit":unit,"bonus":bonus,"base_card":true})
			detail.application = "native_card_invoke_candidate"
		for reference: Dictionary in _sprite_references(unit,bonus):
			record.source_typed_sprite_references.append(reference)
			var actor: Dictionary = reference.get("entity",reference.get("npc",{}))
			var field: String = "SpriteID" if reference.kind == "PolymorphSetID" else "Sprite"
			if _integer(actor.get(field)): sprites[int(actor[field])] = true
		record.source_bonuses.append(detail)
		if not type.is_empty() and not bonus.is_empty() and not unit.is_empty():
			record.sourceOptionsRaw.append({"type_id":type.ID,"value":bonus.get("Value"),"unit_id":unit.ID})
	if not blockers.is_empty(): return
	var sprite_ids: Array = sprites.keys()
	sprite_ids.sort()
	record.source_declared_patch523_sprite_ids = sprite_ids.duplicate()
	record.source_inworld_sprite_ids = sprite_ids.duplicate()
	record.sourceOptions = options
	display.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.priority>b.priority)
	record["source_card_display_options"] = display
	record["source_card_spell_options"] = spell_options
	record["source_card_npc_group_damage"] = npc_group_damage
	record["source_card_base_invokes"] = invokes
	record["desc"] = " · ".join(options)

## Original tooltips have their own units and application targets. Keep these
## display rows separate from the older flat-stat text consumed by gameplay.
static func _card_option(link: Dictionary, bonus: Dictionary, type: Dictionary, unit: Dictionary, text: String) -> Dictionary:
	if type.get("IsShowOnToolTip")!=true or not _integer(bonus.get("Value")): return {}
	var label: String = text
	var amount: int = int(bonus.Value)
	var unit_name: String = str(unit.get("Name",""))
	var kind: String = str(type.get("Name",""))
	var app: Dictionary = SOURCE.row("BonusApplicationType",int(bonus.get("BonusApplicationTypeID",-1)))
	var target: int = int(bonus.get("BonusApplicationTargetID",0))
	match str(app.get("Name","")):
		"Character":
			if target!=0: return {}
		"SpecialResistanceType":
			var scope: String = _description(SOURCE.row("SpecialResistanceType",target).get("DescID"))
			if scope.is_empty(): return {}
			if label.is_empty() and kind=="ImmuneSpecialResistance":label="면역"
			label = scope+" "+label
		"InvokeOption":
			var invoke: Dictionary = SOURCE.row("InvokeOption",target)
			if invoke.get("IsShowOnToolTip")!=true:return {}
			var effect: String = _description(invoke.get("DescID"))
			if effect.is_empty():
				var invoke_type: Dictionary = SOURCE.row("InvokeOptionType",int(invoke.get("InvokeOptionTypeID",-1)))
				if SOURCE.row("Unit",int(invoke_type.get("Param1Unit",-1))).get("Name")=="SpellClassID":
					var spell: Dictionary = SOURCE.row("SpellClass",int(invoke.get("Param1",-1)))
					effect = _description(spell.get("DescID"))
			if effect.is_empty():return {}
			label += " "+effect
		"DescID":
			var title: String = _plain_tooltip(_description(target))
			if title.is_empty():return {}
			if kind=="FixedDesc" and unit_name=="DescID":
				var value_text: String = _description(amount)
				return {"label":title,"value":value_text,"priority":int(type.get("DescPriority",0))}
			if not label.is_empty():label+=" · "+title
		"SpellClass","ItemClass","NpcGroup","ElementalResistanceType":
			var table: String = str(app.Name) if app.Name!="ElementalResistanceType" else "ElementalType"
			var scoped: Dictionary = SOURCE.row(table,target)
			if scoped.is_empty(): return {}
			var scope: String = _description(scoped.get("DescID"),str(scoped.get("Name","")))
			if not scope.is_empty(): label=scope+" · "+label
		_:
			return {}
	if label.strip_edges().is_empty(): return {}
	var divisor: int = 1
	var suffix: String = ""
	match unit_name:
		"Value":
			pass
		"TrueFalse":
			if amount!=1:return {}
			return {"label":_plain_tooltip(label),"value":"","priority":int(type.get("DescPriority",0)),"amount":1}
		"Percentage","ValuePercent","Weight":
			var units: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(unit.ID))
			if units.size()!=1: return {}
			divisor = int(units[0].get("Denominator",0))
			if divisor<=0: return {}
			if unit_name!="Weight": suffix="%"
		_:
			return {}
	var value: float = float(amount)/divisor
	var shown: String = ("%.4f" % value).rstrip("0").rstrip(".")
	if kind!="InvokeOption" and value>=0: shown="+"+shown
	var level: int = int(link.get("CharacterLevel",0))
	var job: int = int(link.get("CharacterClass",0))
	var skill: int = int(link.get("MinSpellLevel",0))
	if level>0: label+=" · Lv.%d 이상" % level
	if job>0:
		var job_name: String = _description(SOURCE.row("Class",job).get("DescID"))
		if job_name.is_empty(): return {}
		label+=" · "+job_name
	if skill>0: label+=" · 스킬 Lv.%d 이상" % skill
	return {"label":_plain_tooltip(label),"value":shown+suffix,"priority":int(type.get("DescPriority",0)),"amount":value}

static func _plain_tooltip(source: String) -> String:
	if source.find("<")<0:return source.strip_edges()
	var markup := RegEx.create_from_string("<[^>]+>")
	return markup.sub(source,"",true).strip_edges()

## Existing runtime consumers have different numeric scales. Only connect
## source rows with an exact unit, target and no unsatisfied condition.
static func _is_unconditional(link: Dictionary) -> bool:
	for field: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
		if int(link.get(field,0))!=0:return false
	return true

static func _active_stat(link: Dictionary, bonus: Dictionary, type: Dictionary, unit: Dictionary, display: Dictionary) -> Dictionary:
	if not display.has("amount") or not _is_unconditional(link): return {}
	var kind: String = str(type.get("Name",""))
	var unit_name: String = str(unit.get("Name",""))
	var amount: float = float(display.amount)
	if _direct(link,bonus): return ACTIVE_OPTIONS.direct_stat(kind,unit_name,amount)
	match int(bonus.get("BonusApplicationTypeID",0)):
		2:
			var status: String = str(SOURCE.row("SpecialResistanceType",int(bonus.BonusApplicationTargetID)).get("Name","")).to_lower()
			if kind=="ImmuneSpecialResistance" and unit_name=="TrueFalse" and status in ["dark","ice"] and amount==1:
				return {"field":"source_card_immune_"+status,"amount":amount}
			if kind not in ["SpecialResistance","HitSpecialResistance"] or unit_name!="Percentage":return {}
			if status not in ["stun","fear","silence","hold","poison","dark","ice"]:return {}
			return {"field":status+("_accuracy" if kind=="HitSpecialResistance" else "_resistance"),"amount":amount}
		3:
			if kind!="ElementalDamage" or unit_name!="Value":return {}
			var element: String = str(SOURCE.row("ElementalType",int(bonus.BonusApplicationTargetID)).get("Name",""))
			if not ACTIVE_OPTIONS.ELEMENTS.has(element):return {}
			return {"field":"equipment523_element_flat_"+ACTIVE_OPTIONS.ELEMENTS[element],"amount":amount}
		5:
			if kind=="IncreaseNpcItemDropAmount" and unit_name=="ValuePercent" and int(bonus.BonusApplicationTargetID)==26:
				return {"field":"adena_drop_pct","amount":amount}
	return {}

## 보고서2 R2 (BuffCardByClass, 138행): a ClassifiedByClass card has one row per
## character class and gender. The row for the playing character replaces the
## BuffClassID (bonuses, options, polymorph chain) and the display sprite/assets.
## The saved identity is never changed: sourceId, source_card_id, name and
## source_original_card stay the base card's, so ownership and collections are the
## same. No exact row -> the base card. Gender unknown (0) -> only the bonuses,
## when every row of the class shares one BuffClassID.
static func variant_row(record: Dictionary, class_id: int, gender_id: int) -> Dictionary:
	var raw: Variant = record.get("source_original_card")
	if class_id<=0 or not raw is Dictionary or raw.get("ClassifiedByClass")!=true: return {}
	var exact: Array = []; var by_class: Array = []
	for row: Variant in record.get("source_class_variants",[]):
		if not row is Dictionary or not _integer(row.get("ClassID")) or int(row.ClassID)!=class_id or int(row.get("BuffCardID",-1))!=int(raw.get("ID",-2)): continue
		by_class.append(row)
		if _integer(row.get("Gender")) and int(row.Gender)==gender_id: exact.append(row)
	if gender_id in [1,2]: return exact[0] if exact.size()==1 else {}
	var buffs: Dictionary = {}
	for row: Dictionary in by_class: buffs[int(row.get("BuffClassID",-1))] = true
	return {"BuffClassID":buffs.keys()[0],"ClassID":class_id,"Gender":0,"_bonus_only":true} if by_class.size()>0 and buffs.size()==1 else {}

static var _variant_cache: Dictionary = {}
const VARIANT_CLEARED_FIELDS: Array[String] = ["source_bonuses","source_stat_application","sourceOptions","sourceOptionsRaw","source_card_display_options","source_card_spell_options","source_card_npc_group_damage","source_card_base_invokes","source_typed_sprite_references","source_declared_patch523_sprite_ids","source_inworld_sprite_ids","desc"]
static func class_variant(record: Dictionary, class_id: int, gender_id: int) -> Dictionary:
	var row: Dictionary = variant_row(record,class_id,gender_id)
	if row.is_empty(): return record
	var key: String = "%s|%d|%d|%s|%d" % [str(record.get("sourceId","")),class_id,gender_id,str(SOURCE.identity().get("source_sha256","")),SOURCE.cache_generation()]
	if _variant_cache.has(key): return _variant_cache[key]
	var result: Dictionary = record.duplicate(false)
	for field: String in VARIANT_CLEARED_FIELDS: result[field] = [] if field!="desc" else ""
	for field: String in FLAT_FIELDS.values(): result.erase(field)
	for applied_stat: Dictionary in record.get("source_stat_application",[]):
		result.erase(applied_stat.field)
	var blockers: Array[String] = []
	_apply_buff(result,int(row.BuffClassID),blockers)
	if not blockers.is_empty(): return record
	var applied: Dictionary = {"basis":"BuffCardByClass","class_id":class_id,"gender_id":gender_id,"buff_class_id":int(row.BuffClassID),"base_buff_class_id":int(record.source_original_card.get("BuffClassID",0))}
	if not row.get("_bonus_only",false):
		result["source_display_sprite_id"] = row.get("DisplaySpriteID")
		result["source_ui_assets"] = _assets(row)
		applied.merge({"row_id":int(row.ID),"display_sprite_id":row.get("DisplaySpriteID"),"base_display_sprite_id":record.get("source_display_sprite_id"),
			"display_name":_description(row.get("DescID"),str(record.get("name",""))),"history":_description(row.get("HistoryDescID"))})
	result["source_class_variant"] = applied
	if _variant_cache.size()>=256: _variant_cache.clear()
	_variant_cache[key] = result
	return result

static func _classes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Dictionary in SOURCE.rows("Class"):
		if typeof(raw.get("CanCreateClient")) != TYPE_BOOL or not bool(raw.CanCreateClient): continue
		if not SOURCE.declared_exclusion("Class",raw).is_empty(): continue
		var name_value: String = _description(raw.get("DescID"))
		if name_value.is_empty(): continue
		result.append({"source_original":raw,"name":name_value,"male_sprite_id":raw.get("MaleSpriteID"),"female_sprite_id":raw.get("FemaleSpriteID")})
	return result

static func build() -> Dictionary:
	problem = ""
	var identity: Dictionary = SOURCE.identity()
	var result: Dictionary = {"schema":1,"source_snapshot":"patch523","content_snapshot":"patch523","ready":false,
		"source_definition_archive":identity,"source_zip_sha256":identity.get("source_sha256",""),
		"catalog":{"변신":[],"마법인형":[],"성물":[]},"classes":[],"source_table_sha256":{},"unavailable_cards":[],"excluded_cards":[]}
	if identity.is_empty():
		problem = SOURCE.problem()
		result["problem"] = problem
		return result
	var rows: Array[Dictionary] = SOURCE.rows("BuffCard")
	if rows.is_empty():
		problem = "현재523 BuffCard 원문 입력을 읽을 수 없습니다. 구 카드팩으로 대체하지 않습니다."
		result["problem"] = problem
		return result
	for raw: Dictionary in rows:
		if not _integer(raw.get("ID")) or not _integer(raw.get("BuffCardDeckID")): continue
		var deck_id: int = int(raw.BuffCardDeckID)
		if not CATEGORIES.has(deck_id): continue
		var exclusion: Dictionary = SOURCE.declared_exclusion("BuffCard",raw)
		if not exclusion.is_empty():
			result.excluded_cards.append({"source_card_id":raw.ID,"source_deck_id":deck_id,"declaration":exclusion})
			continue
		var source_id: String = IDENTITIES.source_id(deck_id,int(raw.ID))
		if source_id.is_empty():
			result.unavailable_cards.append({"source_card_id":raw.ID,"source_deck_id":deck_id,"reason":"saved_namespace_not_declared","reference_only":true,"can_activate":false})
			continue
		var blockers: Array[String] = []
		var deck: Dictionary = _reference("BuffCardDeck",deck_id,blockers)
		if deck.get("Name") != DECK_NAMES[deck_id]: blockers.append("source_deck_contract_unavailable")
		var record: Dictionary = _card(raw,deck,source_id,identity,blockers) if blockers.is_empty() else {}
		if record.is_empty():
			result.unavailable_cards.append({"source_card_id":raw.ID,"source_deck_id":deck_id,"sourceId":source_id,"blockers":blockers})
			continue
		result.catalog[CATEGORIES[deck_id]].append(record)
	result.classes = _classes()
	for table: String in TABLES:
		var metadata: Dictionary = SOURCE.table_metadata(table)
		if metadata.has("sha256"): result.source_table_sha256[table] = metadata.sha256
	result.ready = true
	if not result.unavailable_cards.is_empty(): problem = "일부 현재523 카드의 원문 관계 또는 저장 정체가 미확보 상태입니다."
	result["problem"] = problem
	return result

static func npc(source_id: int) -> Dictionary:
	npc_problem = ""
	if SOURCE.identity().is_empty():
		npc_problem = SOURCE.problem()
		return {}
	var raw: Dictionary = SOURCE.row("NpcClass",source_id)
	if raw.is_empty():
		npc_problem = "현재523 NpcClass#"+str(source_id)+" 원문이 없습니다."
		return {}
	if typeof(raw.get("TestNPC")) != TYPE_BOOL:
		npc_problem = "현재523 NPC의 명시적 TestNPC 선언을 읽을 수 없습니다."
		return {}
	if bool(raw.TestNPC) or not SOURCE.declared_exclusion("NpcClass",raw).is_empty():
		npc_problem = "원문에서 명시적으로 제외된 NPC입니다."
		return {}
	var label: String = _description(raw.get("DescId"))
	if label.is_empty():
		npc_problem = "현재523 NPC의 명시적 DescId 표시명을 읽을 수 없습니다."
		return {}
	var result: Dictionary = raw.duplicate(true)
	result["DisplayName_from_DescId"] = label
	result["source_snapshot"] = "patch523"
	result["content_snapshot"] = "patch523"
	result["source_definition_archive"] = SOURCE.identity()
	return result

