extends RefCounted
## Private, data-only quest projection. Missing semantics fail closed per quest.
const USER_PATH = "user://quests_current523.json"
const DEV_PATH = "res://data/quests/private_current523.json"
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PAYLOAD_SHA = "2d11ecff4e695244220dc8e3a9b5707809f8bcfe34d7789a517880a6590bcb9a"
const MAX_BYTES = 16 * 1024 * 1024
var document: Dictionary = {}
var problem: String = "최신523 퀘스트 팩 미설치"
var quests: Array[Dictionary] = []
var class_ids: Dictionary = {}
var currency_ids: Dictionary = {}

func load_pack() -> bool:
	var path: String = USER_PATH if FileAccess.file_exists(USER_PATH) else DEV_PATH
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		problem = "퀘스트 팩 파일을 읽을 수 없습니다"
		return false
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if bytes.get_string_from_utf8().sha256_text() != PAYLOAD_SHA:
		problem = "퀘스트 팩 SHA-256 불일치"
		return false
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or not valid_document(value):
		problem = "퀘스트 팩 구조 오류"
		return false
	document = value
	for link: Dictionary in document.currency_links:
		if int(link.UnitID)==4 and bool(link.ForGive) and not currency_ids.has(int(link.ClassID)): currency_ids[int(link.ClassID)] = int(link.CurrencyID)
	for raw: Dictionary in document.quests:
		var row: Dictionary = raw.duplicate(true)
		row["objective"] = {"kind":"source", "count":1, "target":""}
		row["rewards"] = {}
		row["min_level"] = 1
		for condition: Dictionary in row.prerequisites:
			if condition.type_name == "MinLevel": row.min_level = maxi(row.min_level, int(condition.Value))
		quests.append(row)
	for row: Dictionary in document.classes:
		class_ids[str(row.name)] = int(row.id)
	problem = ""
	return true

static func valid_document(value: Dictionary) -> bool:
	if value.get("schema_version") != 2 or value.get("source_snapshot") != "patch523" or value.get("source_sha256") != SOURCE_SHA or value.get("provenance") != "verified_original_quest_projection": return false
	if not value.get("quests") is Array or value.quests.size() != 3621 or not value.get("classes") is Array: return false
	var seen: Dictionary = {}
	for raw: Variant in value.quests:
		if not raw is Dictionary: return false
		var id: String = str(raw.get("id", ""))
		if id != "m523:quest:"+str(int(raw.get("source_id",0))) or seen.has(id): return false
		seen[id] = true
		for key: String in ["prerequisites", "goals", "source_rewards", "enhancements", "blockers", "excluded_reasons"]:
			if not raw.get(key) is Array: return false
		if not raw.get("definition") is Dictionary: return false
	return true

static func install_zip(path: String) -> Dictionary:
	# Bounded central directory inspection before ZIPReader allocations.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024: return {"ok":false,"error":"퀘스트 팩 크기 오류"}
	var length: int = file.get_length()
	if length < 22: return {"ok":false,"error":"ZIP 구조 오류"}
	file.seek(length-22)
	var end: PackedByteArray = file.get_buffer(22)
	if end.decode_u32(0) != 0x06054b50 or end.decode_u16(4) != 0 or end.decode_u16(6) != 0 or end.decode_u16(8) != 2 or end.decode_u16(10) != 2 or end.decode_u16(20) != 0: return {"ok":false,"error":"퀘스트 ZIP 목록 오류"}
	var directory_offset: int = end.decode_u32(16)
	var directory_size: int = end.decode_u32(12)
	if directory_size > 2048 or directory_offset + directory_size != length-22: return {"ok":false,"error":"퀘스트 ZIP 경계 오류"}
	file.seek(directory_offset)
	var directory: PackedByteArray = file.get_buffer(directory_size)
	var at: int = 0
	var names: Dictionary = {}
	for i: int in range(2):
		if at+46 > directory.size() or directory.decode_u32(at) != 0x02014b50: return {"ok":false,"error":"퀘스트 ZIP 항목 오류"}
		var n: int = directory.decode_u16(at+28)
		var record_size: int = 46+n+directory.decode_u16(at+30)+directory.decode_u16(at+32)
		if at+record_size > directory.size(): return {"ok":false,"error":"퀘스트 ZIP 이름 오류"}
		var name: String = directory.slice(at+46,at+46+n).get_string_from_utf8()
		if name not in ["quest_pack.json","quests.json"] or names.has(name) or directory.decode_u16(at+8)&1 or directory.decode_u16(at+10) not in [0,8] or directory.decode_u32(at+24) > (4096 if name=="quest_pack.json" else MAX_BYTES) or directory.decode_u32(at+42) >= directory_offset: return {"ok":false,"error":"지원되지 않는 퀘스트 ZIP 항목"}
		names[name] = true
		at += record_size
	if at != directory.size(): return {"ok":false,"error":"퀘스트 ZIP 목록 손상"}
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return {"ok":false,"error":"ZIP 열기 실패"}
	var header: Variant = JSON.parse_string(zip.read_file("quest_pack.json").get_string_from_utf8())
	var payload: PackedByteArray = zip.read_file("quests.json")
	zip.close()
	if not header is Dictionary or header.get("kind") != "twilight-quests-current523" or header.get("schema") != 1 or header.get("source_sha256") != SOURCE_SHA or header.get("payload_sha256") != PAYLOAD_SHA or int(header.get("bytes",0)) != payload.size() or payload.get_string_from_utf8().sha256_text() != PAYLOAD_SHA: return {"ok":false,"error":"퀘스트 원본/해시 검증 실패"}
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())
	if not parsed is Dictionary or not valid_document(parsed): return {"ok":false,"error":"퀘스트 정의 검증 실패"}
	var result: Error = preload("res://scripts/skills/save_writer.gd").write_text(USER_PATH,payload.get_string_from_utf8())
	return {"ok":result==OK,"error":"퀘스트 팩 저장 실패 · 기존 파일 보존" if result!=OK else ""}

func gate(row: Dictionary, context: Dictionary, claimed: Dictionary, now: int) -> String:
	if not row.excluded_reasons.is_empty(): return str(row.excluded_reasons[0])
	if not row.blockers.is_empty(): return str(row.blockers[0])
	if row.starts_at == null or row.ends_at == null: return "원본 운영 기간 해석 보류"
	if now < int(row.starts_at): return "시작 전"
	if now > int(row.ends_at): return "기간 종료"
	var definition: Dictionary = row.definition
	if int(definition.TypeID) in [92,102,131,143,172,182,162,71,81]: return "연계 콘텐츠의 획득 조건 확인 필요"
	if int(definition.get("LimitWeeklyOpenTimeGroup",0)) != 0 or int(definition.get("LimitHours",0)) != 0: return "원본 운영 시간 조건 확인 필요"
	# The client dump does not contain the QuestResetType enum contract. Never
	# guess IDs from an unrelated reset table and accidentally farm rewards.
	if int(definition.get("QuestResetType",0)) != 0 or int(definition.get("MaxDailyRepeat",0)) != 0: return "원본 반복/초기화 규칙 확인 필요"
	for condition: Dictionary in row.prerequisites:
		var amount: int = int(condition.Value)
		match str(condition.type_name):
			"MinLevel":
				if int(context.get("level",1)) < amount: return "레벨 %d부터 이용" % amount
			"MaxLevel":
				if int(context.get("level",1)) > amount: return "최대 레벨 %d 제한" % amount
			"MinLevelByCharacterMaxLevel":
				if int(context.get("max_level",context.get("level",1))) < amount: return "최고 레벨 %d 필요" % amount
			"Class":
				if int(context.get("class_id",-1)) != amount: return "직업 조건 미충족"
			"ClassNot":
				if int(context.get("class_id",-1)) < 0 or int(context.get("class_id",-1)) == amount: return "직업 조건 미충족"
			"Quest":
				if not claimed.has("m523:quest:"+str(amount)): return "선행 퀘스트 %d 필요" % amount
			"CreateCharacter":
				# A live local character satisfies source CreateCharacter=1.
				if amount != 1: return "캐릭터 생성 조건 확인 필요"
			_: return "선행 조건 미연결: "+str(condition.type_name)
	return ""

func reward_plan(row: Dictionary, context: Dictionary) -> Dictionary:
	# QuestRewardEnhancement is an optional paid boost. The original base
	# Reward rows are granted; automatic completion never spends diamonds.
	# NC confirmation: 2019-01-30 patch notes, additional diamond consumption.
	var result: Dictionary = {"ok":true,"adena":0,"exp":0,"items":[],"quests":[],"pending_use":[],"optional_enhancement_unused":not row.enhancements.is_empty()}
	for reward: Dictionary in row.source_rewards:
		var character: int = int(reward.CharacterClassID)
		if character != 0 and int(context.get("class_id",-1)) < 0: return {"ok":false,"error":"직업별 보상 판별 대기"}
		if character != 0 and character != int(context.get("class_id",-1)): continue
		if bool(reward.ClanOnly): return {"ok":false,"error":"혈맹 전용 보상 제외"}
		if int(reward.RewardEnhancementTypeID) != 1:
			if int(reward.RewardEnhancementTypeID) in [11,21] and not row.enhancements.is_empty(): continue
			return {"ok":false,"error":"원본 보상 강화 유형 확인 필요"}
		var amount: int = int(reward.Amount)
		if amount < 0 or amount > 9007199254740991: return {"ok":false,"error":"보상 수량 오류"}
		match str(reward.type_name):
			"Exp": result.exp += amount
			"Item":
				var original: Dictionary = reward.get("source_item",{})
				if _currency_id(int(reward.RewardClassID)) == 1: result.adena += amount
				else:
					var coin_name: String = str(original.get("Name","")).trim_prefix("[화폐] ")
					var coins: Dictionary = context.get("currency_items",{})
					if _currency_id(int(reward.RewardClassID)) > 0 and coins.has(coin_name) and str(coins[coin_name].get("slot","")) == "currency":
						result.items.append({"record":coins[coin_name].duplicate(true),"quantity":amount,"stack_only":true,"source_reward_id":int(reward.ID)})
						continue
					var record: Dictionary = context.get("source_items",{}).get(str(int(reward.RewardClassID)),{})
					if bool(reward.UseImmediately) or int(reward.ItemBlessCodeID)!=1: record={}
					if record.is_empty():
						# Keep an exact native item in the real inventory with its
						# pinned identity. It cannot masquerade as usable legacy
						# equipment/consumables with the same display name.
						var label: String = str(original.get("Name",""))
						if label.is_empty(): return {"ok":false,"error":"원본 아이템 이름 누락"}
						if amount > 10000: return {"ok":false,"error":"원본 보상 수량의 개체 저장 연결 필요"}
						record = {"name":"[원본 보상] "+label,"source_display_name":label,"slot":"quest_reward","type":"원본 보상 보관","grade":"미확인","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:"+str(int(reward.RewardClassID)),"source_item_class_id":int(reward.RewardClassID),"source_original_item":original.duplicate(true),"source_pending_use":true,"quest_item":true,"weight":0,"droppable":false,"sellable":false,"desc":"원본 ID·수량을 보존한 보상입니다. 장착·사용 기능 연결 전까지 보관합니다."}
						result.pending_use.append(label)
						record["source_bless_code_id"] = int(reward.ItemBlessCodeID)
						record["source_use_immediately"] = bool(reward.UseImmediately)
						record["source_reward_id"] = int(reward.ID)
					result.items.append({"record":record.duplicate(true),"quantity":amount,"source_reward_id":int(reward.ID)})
			"NoReward": pass
			# Quest rewards unlock ownership, never waive a child's prerequisites.
			"Quest": result.quests.append(int(reward.RewardClassID))
			_: return {"ok":false,"error":"보상 미연결: "+str(reward.type_name)}
	return result

func _currency_id(item_id: int) -> int:
	return int(currency_ids.get(item_id,0))
