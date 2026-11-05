extends RefCounted
## Numeric card definitions come only from the supplied current523 archive.
## Saved namespaces are code ABI; they are never an old asset/data dependency.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITIES = preload("res://scripts/cards/current523_card_identity.gd")
const CATEGORIES = {1:"변신",2:"마법인형",98:"성물"}
const DECK_NAMES = {1:"PolymorphCardDeck",2:"MagicDollCardDeck",98:"HolyStuffCardDeck"}
const FLAT_FIELDS = {"HPPlus":"hpFlat","MPPlus":"mpFlat","Strength":"strFlat","Dexterity":"dexFlat","Intelligence":"intFlat","Wisdom":"wisFlat","Constitution":"conFlat","Charisma":"chaFlat","MagicResist":"mr","DamageReduction":"damage_reduction"}
const ASSET_FIELDS = ["DisplayBaseAssetID","DisplayScreenAssetID","DisplayDecoAssetID","IllustrationAssetID","HidedIllustrationAssetID"]
const TABLES = ["BuffCard","BuffCardDeck","BuffCardByClass","BuffBonus","Bonus","BonusType","Unit","Grade","DescData_Korean","Class","PolymorphEntityForSet","PolymorphEntity","NpcClass","AssetView","AssetType"]
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
	var options: Array[String] = []
	var sprites: Dictionary = {}
	for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",int(raw.BuffClassID)):
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
		for reference: Dictionary in _sprite_references(unit,bonus):
			record.source_typed_sprite_references.append(reference)
			var actor: Dictionary = reference.get("entity",reference.get("npc",{}))
			var field: String = "SpriteID" if reference.kind == "PolymorphSetID" else "Sprite"
			if _integer(actor.get(field)): sprites[int(actor[field])] = true
		record.source_bonuses.append(detail)
		if not type.is_empty() and not bonus.is_empty() and not unit.is_empty():
			record.sourceOptionsRaw.append({"type_id":type.ID,"value":bonus.get("Value"),"unit_id":unit.ID})
	if not blockers.is_empty(): return {}
	var sprite_ids: Array = sprites.keys()
	sprite_ids.sort()
	record.source_declared_patch523_sprite_ids = sprite_ids.duplicate()
	record.source_inworld_sprite_ids = sprite_ids.duplicate()
	record.sourceOptions = options
	record["desc"] = " · ".join(options)
	record["source_original"] = {"source_snapshot":"patch523","content_snapshot":"patch523", "card_id":raw.ID,"deck_id":raw.BuffCardDeckID,
		"grade_id":raw.GradeID,"grade_tier_id":raw.GradeTierID,"buff_class_id":raw.BuffClassID,
		"server_limit_set_id":raw.ServerLimitSetID,"start_datetime_id":raw.StartDateTimeID,"end_datetime_id":raw.EndDateTimeID,
		"source_definition_archive":identity.duplicate(true)}
	return record

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

