extends RefCounted
## Private source tables stay outside Git. This adapter retains their original rows.
const COMMON_SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ZIP_BYTES := 25031173
const ZIP_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const INSTALLED := "user://growth96_definitions/source.zip"
const TOKEN := 371128
var problem := ""
var ready := false
var tables: Dictionary = {}
var points: Dictionary = {}
var rewards: Dictionary = {}
var by_point: Dictionary = {}
var items: Dictionary = {}
var collections: Dictionary = {}
var cards: Dictionary = {}
var audit: Dictionary = {}
var current_version: int = -1

static func sid(value: Variant) -> String:
	return str(int(value))

static func item_key(id: int) -> String:
	return "m523-growth-item:" + str(id)

func _rows(zip: ZIPReader, name: String) -> Array:
	var parsed: Variant = JSON.parse_string(zip.read_file("content/" + name + ".json").get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("rows") is Array:
		problem = "원본 표를 읽을 수 없습니다: " + name
		return []
	tables[name] = parsed.rows
	return parsed.rows

## indexed() lookups (last row per ID) over a Dictionary index or, when the
## index is a table name, over the common reader.
static func _row_of(index: Variant, id: String) -> Dictionary:
	if index is Dictionary: return index.get(id,{})
	if not id.is_valid_int(): return {}
	var matches: Array[Dictionary] = COMMON_SOURCE.related(str(index),"ID",int(id))
	return matches[-1] if not matches.is_empty() else {}

static func _has(index: Variant, id: String) -> bool:
	return index.has(id) if index is Dictionary else not _row_of(index,id).is_empty()

static func _at(index: Variant, id: String) -> Dictionary:
	return index[id] if index is Dictionary else _row_of(index,id)

static func indexed(rows: Array, key: String = "ID") -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in rows: out[sid(row[key])] = row
	return out

func load_source(path: String = "") -> bool:
	ready = false; problem = ""; audit.clear(); tables.clear(); points.clear(); rewards.clear(); by_point.clear(); items.clear(); collections.clear(); cards.clear()
	current_version = -1
	if path.is_empty():
		path = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
		if path.is_empty():
			path = INSTALLED
			# Only an absent default permits the common reader's already supplied
			# archive. Explicit or existing invalid inputs still fail below.
			if not FileAccess.file_exists(INSTALLED) and not DirAccess.dir_exists_absolute(INSTALLED):
				var shared_path: String = COMMON_SOURCE.archive_path()
				if not shared_path.is_empty(): path = shared_path
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		problem = "검증된 523 원본 정의 ZIP을 선택해 주세요. 보유 아이템을 자동 지급하지 않습니다."
		return false
	var size := file.get_length(); file.close()
	if size != ZIP_BYTES or FileAccess.get_sha256(path) != ZIP_SHA:
		problem = "원본 ZIP 크기 또는 SHA-256이 다릅니다."
		return false
	var zip := ZIPReader.new()
	if zip.open(path) != OK: problem = "원본 ZIP을 열 수 없습니다."; return false
	# The common reader holds these same verified archive bytes; its large
	# tables are looked up there instead of being parsed and indexed again.
	var shared: bool = COMMON_SOURCE.identity().get("source_sha256") == ZIP_SHA
	points = indexed(_rows(zip,"GrowthMotivation"))
	var growth_constants: Array = _rows(zip,"GrowthMotivationConstant")
	var links := _rows(zip,"GrowthMotivationReward")
	var all_rewards: Variant = "Reward" if shared else indexed(_rows(zip,"Reward"))
	var reward_types := indexed(_rows(zip,"RewardType"))
	var all_items: Variant = "ItemClass" if shared else indexed(_rows(zip,"ItemClass"))
	var item_rows := _rows(zip,"ItemBookItem")
	var card_links := _rows(zip,"ItemBookCardForItem")
	var all_cards := indexed(_rows(zip,"ItemBookCard"))
	var membership := _rows(zip,"ItemBookCardForCollection")
	var collection_rows := indexed(_rows(zip,"ItemBookCollection"))
	var slots := indexed(_rows(zip,"ItemBookCollectionSlot"))
	var slot_bonuses := _rows(zip,"ItemBookCollectionSlotBonus")
	var bonuses: Variant = "Bonus" if shared else indexed(_rows(zip,"Bonus"))
	var types := indexed(_rows(zip,"BonusType"))
	var units := indexed(_rows(zip,"Unit"))
	var ui_units := indexed(_rows(zip,"UIUnit"),"UnitID")
	var attributes := _rows(zip,"RewardAttribute")
	_rows(zip,"RewardEnhancement")
	var reward_groups := _rows(zip,"RewardGroup")
	var descriptions: Variant = "DescData_Korean" if shared else indexed(_rows(zip,"DescData_Korean"))
	zip.close()
	if not problem.is_empty(): return false
	# This is the native reward-version selector, not the local save schema.
	# Keep every reward row, but do not promote a future version merely because
	# it exists in a definition pack.
	var version_rows: int = 0
	for constant: Dictionary in growth_constants:
		if constant.get("Name") != "Version": continue
		version_rows += 1
		var value: Variant = constant.get("Value")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<0 or value>100:
			problem = "원본 성장 보상 버전 값이 유효하지 않습니다."; return false
		current_version = int(value)
	if version_rows!=1:
		problem = "원본 성장 보상 버전이 없거나 중복됩니다."; return false
	if points.size() != 71 or links.size() != 269:
		problem = "성장 지점·보상 전수 개수가 다릅니다."; return false
	var versions: Dictionary = {}
	for point: Dictionary in points.values():
		if int(point.Level) < 1 or int(point.Percent) < 0 or int(point.Percent) > 100: problem = "성장 달성 조건 오류"; return false
	for link: Dictionary in links:
		var id := sid(link.RewardID); var point := sid(link.GrowthMotivationID)
		if not points.has(point) or not _has(all_rewards,id) or rewards.has(id): problem = "보상 연결 또는 중복 오류"; return false
		var row: Dictionary = _at(all_rewards,id).duplicate(true)
		# Match the source namespace by its declared kind, as the existing quest
		# supplier does. A coincident numeric type ID is not an item contract.
		var reward_type: Dictionary = reward_types.get(sid(row.RewardTypeID),{})
		if reward_type.get("Name") != "Item" or int(row.RewardGetTimeTypeID) != 2 or int(row.CharacterClassID) != 0 or bool(row.UseImmediately) or bool(row.ClanOnly) or int(row.RewardEnhancementTypeID) != 1 or int(row.ItemBlessCodeID) != 1 or int(row.Ranking) != 0 or int(row.Amount) <= 0:
			problem = "지원하지 않는 성장 보상 조건: " + id; return false
		var item_id := sid(row.RewardClassID)
		if not _has(all_items,item_id): problem = "원본 아이템 연결 누락"; return false
		row["point_id"] = point; row["version"] = int(link.Version)
		rewards[id] = row; items[item_id] = _at(all_items,item_id)
		if not by_point.has(point): by_point[point] = []
		by_point[point].append(id); versions[sid(link.Version)] = true
	for row: Dictionary in attributes:
		if rewards.has(sid(row.RewardID)): problem = "추가 보상 속성의 실행 규칙 확인이 필요합니다."; return false
	for row: Dictionary in reward_groups:
		if rewards.has(sid(row.RewardID)): problem = "그룹 보상의 실행 규칙 확인이 필요합니다."; return false
	if by_point.size() != points.size(): problem = "보상 없는 성장 지점이 있습니다."; return false
	var token_items: Dictionary = {}
	for row: Dictionary in item_rows:
		if int(row.ItemClassID) != TOKEN: continue
		if int(row.Amount) != 1 or int(row.Enchant) != 0 or int(row.BlessCode) != 1 or int(row.ElementalType) != 0 or int(row.ElementalEnchant) != 0:
			problem = "증표 등록의 원본 조건이 다릅니다."; return false
		token_items[sid(row.ID)] = row
	for link: Dictionary in card_links:
		if not token_items.has(sid(link.ItemBookItemID)): continue
		var id := sid(link.ItemBookCardID)
		if cards.has(id) or not all_cards.has(id): problem = "증표 등록 카드 중복 또는 원본 카드 누락"; return false
		cards[id] = {"id":id,"item":token_items[sid(link.ItemBookItemID)],"collection_id":""}
	for link: Dictionary in membership:
		var id := sid(link.ItemBookCardID)
		if not cards.has(id): continue
		var cid := sid(link.ItemBookCollectionID)
		if not str(cards[id].collection_id).is_empty() or not collection_rows.has(cid): problem = "증표 컬렉션 연결 오류"; return false
		cards[id].collection_id = cid
		if not collections.has(cid):
			var raw: Dictionary = collection_rows[cid]
			if int(raw.Level) != 96 or int(raw.ServerLimitSetID) != 0 or int(raw.ExpireDateTimeID) != 0 or bool(raw.IsEvent): problem = "컬렉션 보호 조건이 다릅니다."; return false
			collections[cid] = {"id":cid,"name":str(_row_of(descriptions,sid(raw.DescID)).get("Description","증표 컬렉션 " + cid)),"raw":raw,"cards":[],"effects":[]}
		collections[cid].cards.append(id)
	var effect_count := 0
	for link: Dictionary in slot_bonuses:
		var slot: Dictionary = slots.get(sid(link.ItemBookCollectionSlotID),{})
		var cid := sid(slot.get("ItemBookCollectionID",0))
		if not collections.has(cid): continue
		var bonus: Dictionary = _row_of(bonuses,sid(link.BonusID))
		var type: Dictionary = types.get(sid(bonus.get("BonusTypeID","")),{})
		if int(link.GameClassID) != 0 or bonus.is_empty() or type.is_empty(): problem = "효과 연결 또는 클래스 조건 오류"; return false
		var unit: String = str(units.get(sid(type.UnitID),{}).get("Name",""))
		var denominator: float = 1.0 if unit == "Value" else float(ui_units.get(sid(type.UnitID),{}).get("Denominator",0))
		if unit not in ["Value","Percentage"] or denominator <= 0: problem = "효과 원본 단위 오류"; return false
		var value: float = float(bonus.Value) / denominator
		var name := str(type.Name)
		if name not in ["MeleeHit","RangeHit","MagicHit","PVPMeleeAdditionDamage","PVPRangeAdditionDamage","PVPMagicAdditionDamage","CriticalMeleeDamage","CriticalRangeDamage","CriticalMagicDamage","ResistIgnoreDamageReductionPercent","IgnoreMeleeDamageReductionPercent","IgnoreRangeDamageReductionPercent","IgnoreMagicDamageReductionPercent","IgnorePVPDamageReductionPercent","PVPPierceDamageReductionPercent","HitSpecialResistanceScale"]:
			problem = "지원하지 않는 효과 유형: " + name; return false
		var scoped := name == "HitSpecialResistanceScale"
		if (scoped and (int(bonus.BonusApplicationTypeID) != 252 or int(bonus.BonusApplicationTargetID) != 14)) or (not scoped and (int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0)):
			problem = "효과 적용 대상이 다릅니다."; return false
		collections[cid].effects.append({"name":name,"value":value,"display":str(_row_of(descriptions,sid(type.DescID)).get("Description",name)) + " +" + str(value) + ("%" if unit == "Percentage" else ""),"raw":bonus,"type":type,"slot":slot,"link":link,"policy_note":"대상14와 비율 공식은 원문에 없으므로 TWILIGHT 추정 실행을 선택할 수 있습니다." if scoped else ""})
		effect_count += 1
	if token_items.size() != 63 or cards.size() != 63 or collections.size() != 8 or effect_count != 16 or items.size() != 17:
		problem = "원본 증표·아이템 전수 연결 개수가 다릅니다."; return false
	var p96 := 0; var r96 := 0
	for point: Dictionary in points.values():
		if int(point.Level) == 96:
			p96 += 1; r96 += by_point.get(sid(point.ID),[]).size()
	if p96 != 9 or r96 != 36: problem = "96레벨 전수 연결 오류"; return false
	audit = {"points":points.size(),"rewards":rewards.size(),"items":items.size(),"versions":versions.keys(),"points96":p96,"rewards96":r96,"requirements":cards.size(),"collections":collections.size(),"effects":effect_count}
	# The selected rows live on in points/rewards/items/cards/collections. Whole
	# parsed tables (Bonus, ItemClass, Reward, ...) are not read after loading
	# and held ~0.9 GB with the original installed.
	tables.clear()
	ready = true
	return true

func item_record(id: int) -> Dictionary:
	var raw: Dictionary = items.get(str(id),{})
	if raw.is_empty(): return {}
	# Preserve the original row; its explicit test declaration prevents new activation.
	if raw.get("TestItem") is bool and raw.TestItem: return {}
	return {"name":item_key(id),"display_name":str(raw.Name),"source":"lineagem_patch523_growth","sourceId":"m523:item:" + str(id),"growth96_item_id":id,"grade":"일반","type":"소모품","weight":int(raw.Weight),"tradeable":bool(raw.IsTradable),"storable":bool(raw.IsStorable),"deletable":bool(raw.IsDeletable),"droppable":bool(raw.IsDroppable),"max_stack_amount":int(raw.MaxStackAmount),"use_level_min":int(raw.LevelLimitMin),"use_level_max":int(raw.LevelLimitMax),"desc":"원본 성장 보상 아이템입니다. 다른 출처의 같은 이름 아이템과 합치지 않습니다.","source_original":raw.duplicate(true)}
