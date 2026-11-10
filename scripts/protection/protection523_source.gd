extends RefCounted

const CommonSource = preload("res://scripts/resources/current523_definition_rows.gd")
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SOURCE_BYTES := 25031173
const IDS := [200723,245718,297828,328254,346911,371108]
const DISABLED_ID := 327823
const SOURCE_DIR := "user://protection523/source"
const RUNTIME_DIR := "user://protection523/runtime"
const POINTER := "user://protection523/active.json"
const LEGACY_CAPSULE_SHA := "a94475ac15454668ad1983de0b326b0c4be7e149bca02c342d913d5eef6bfa2d"
const MATERIAL_CAPSULE_SHA := "5009ae003c2be60aa3a2d88efe96b9d97280e178be85048f6e69aafcbee21d3f"
const CAPSULE_SHA := "aefe4f39ba5574dc3dab70feb8a623567efc84b8e94888494a59a8dfa6d606c1"
const QUEST_MATERIAL_IDS := [96004,96014,200698]
const SUPPLY_RECIPE_IDS := [37044,47273]

static func denied(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func select_rows(zip: ZIPReader, table: String, key: String, ids: Array, hashes: Dictionary) -> Array:
	var member := "content/%s.json" % table
	if not zip.file_exists(member): return []
	var bytes := zip.read_file(member)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	hashes[table] = hash.finish().hex_encode()
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8().trim_prefix("\ufeff")) != OK or not parser.data is Dictionary: return []
	var result: Array = []
	for row: Variant in parser.data.get("rows",[]):
		if row is Dictionary and ids.has(int(row.get(key,-1))): result.append(row)
	return result

static func index(rows: Array, key: String = "ID") -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows: result[str(int(row.get(key,-1)))] = row
	return result

static func ids(rows: Array, key: String) -> Array:
	var result: Array = []
	for row: Dictionary in rows:
		var value := int(row.get(key,0))
		if not result.has(value): result.append(value)
	return result

static func extract(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return denied("원본523 ZIP을 찾을 수 없습니다")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return denied("원본 ZIP 읽기 실패")
	var size := file.get_length()
	file.close()
	if size != SOURCE_BYTES or FileAccess.get_sha256(path) != SOURCE_SHA: return denied("검증된 최신523 원본과 크기·SHA가 다릅니다")
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return denied("원본 ZIP 열기 실패")
	var hashes: Dictionary = {}
	var raw: Dictionary = {}
	var all_ids: Array = IDS.duplicate()
	all_ids.append_array([DISABLED_ID,123373,200698,3631,96004,96014])
	raw.MaterialReward = []
	for row: Dictionary in select_rows(zip,"Reward","RewardClassID",QUEST_MATERIAL_IDS,hashes):
		if int(row.RewardTypeID) == 2: raw.MaterialReward.append(row)
	raw.MaterialQuestReward = select_rows(zip,"QuestReward","RewardID",ids(raw.MaterialReward,"ID"),hashes)
	raw.SupplyRecipeView = select_rows(zip,"ItemCraftView","ItemCraftID",SUPPLY_RECIPE_IDS,hashes)
	for table: String in ["ItemCraftInput","ItemCraftOutputView","ItemCraftRestriction"]:
		raw["Supply"+table] = select_rows(zip,table,"ItemCraftID",SUPPLY_RECIPE_IDS,hashes)
	raw.Group604BuffClass = select_rows(zip,"BuffClass","BuffGroupID",[604],hashes)
	var shared_buffs: Array = ids(raw.Group604BuffClass,"ID")
	var shared_bonus: Array = select_rows(zip,"Bonus","BonusTypeID",[78],hashes)
	raw.Group604BuffBonuses = []
	for row: Dictionary in shared_bonus:
		if shared_buffs.has(int(row.Value)): raw.Group604BuffBonuses.append(row)
	raw.Group604ItemBonus = select_rows(zip,"ItemBonus","BonusID",ids(raw.Group604BuffBonuses,"ID"),hashes)
	all_ids.append_array(ids(raw.Group604ItemBonus,"ItemClassID"))
	raw.ItemClass = select_rows(zip,"ItemClass","ID",all_ids,hashes)
	raw.ItemCategory = select_rows(zip,"ItemCategory","ID",[10204],hashes)
	raw.ItemBonus = select_rows(zip,"ItemBonus","ItemClassID",IDS + [DISABLED_ID],hashes)
	# Resolve item bonus -> Appellation -> BuffClass. Appellation.RewardID is
	# explicitly a BuffClass ID here, never a general Reward table join.
	raw.Bonus = select_rows(zip,"Bonus","ID",ids(raw.ItemBonus,"BonusID"),hashes)
	var title_ids: Array = []
	var buff_ids: Array = []
	for bonus: Dictionary in raw.Bonus:
		if int(bonus.BonusTypeID) == 7243: title_ids.append(int(bonus.Value))
		if int(bonus.BonusTypeID) == 78: buff_ids.append(int(bonus.Value))
	raw.Appellation = select_rows(zip,"Appellation","ID",title_ids,hashes)
	buff_ids.append_array(ids(raw.Appellation,"RewardID"))
	raw.BuffClass = select_rows(zip,"BuffClass","ID",buff_ids,hashes)
	raw.BuffBonus = select_rows(zip,"BuffBonus","BuffClassID",buff_ids,hashes)
	var bonus_ids: Array = ids(raw.ItemBonus,"BonusID")
	bonus_ids.append_array(ids(raw.BuffBonus,"BonusID"))
	raw.Bonus = select_rows(zip,"Bonus","ID",bonus_ids,hashes)
	raw.BonusType = select_rows(zip,"BonusType","ID",ids(raw.Bonus,"BonusTypeID"),hashes)
	raw.BuffGroup = select_rows(zip,"BuffGroup","ID",[604,841],hashes)
	raw.ItemCraftView = select_rows(zip,"ItemCraftView","ItemClassID",IDS + [DISABLED_ID],hashes)
	var crafts: Array = ids(raw.ItemCraftView,"ItemCraftID")
	for table: String in ["ItemCraftInput","ItemCraftOutputView","ItemCraftRestriction"]:
		raw[table] = select_rows(zip,table,"ItemCraftID",crafts,hashes)
	var desc_ids: Array = ids(raw.ItemClass,"IdentifiedDescID")
	desc_ids.append_array(ids(raw.Appellation,"DescID"))
	raw.DescData_Korean = select_rows(zip,"DescData_Korean","ID",desc_ids,hashes)
	zip.close()
	var capsule := {"schema":1,"source_sha256":SOURCE_SHA,"source_bytes":SOURCE_BYTES,"member_sha256":hashes,"tables":raw}
	var result := compile(capsule)
	if not bool(result.get("ok",false)): return result
	result["capsule"] = capsule
	return result

static func compile(capsule: Dictionary) -> Dictionary:
	if int(capsule.get("schema",0)) != 1 or str(capsule.get("source_sha256","")) != SOURCE_SHA: return denied("가호 원본 출처 확인 필요")
	var raw: Dictionary = capsule.get("tables",{})
	for table: String in ["ItemClass","ItemCategory","ItemBonus","Bonus","BuffClass","BuffBonus","Appellation","BuffGroup","ItemCraftView","ItemCraftInput","ItemCraftOutputView","ItemCraftRestriction","DescData_Korean"]:
		if not raw.get(table) is Array: return denied("가호 원본 표 누락: " + table)
	var items := index(raw.ItemClass)
	var bonuses := index(raw.Bonus)
	var buffs := index(raw.BuffClass)
	var titles := index(raw.Appellation)
	var desc := index(raw.DescData_Korean)
	var recipes := index(raw.ItemCraftView,"ItemClassID")
	var groups := index(raw.BuffGroup)
	if bool(groups.get("604",{}).get("IsAllowOverlap",true)) or bool(groups.get("841",{}).get("IsAllowOverlap",true)): return denied("원본 비중첩 그룹 확인 필요")
	var definitions: Dictionary = {}
	for item_id: int in IDS:
		var key := str(item_id)
		if not items.has(key) or not recipes.has(key): return denied("원본 가호·제작식 누락")
		var use: Dictionary = {}
		var possession: Dictionary = {}
		for link: Dictionary in raw.ItemBonus:
			if int(link.ItemClassID) != item_id: continue
			var bonus: Dictionary = bonuses.get(str(int(link.BonusID)),{})
			if bonus.is_empty(): return denied("원본 보너스 누락")
			var destination: Dictionary = possession if bool(link.IsPossession) else use
			destination[str(int(bonus.BonusTypeID))] = int(bonus.Value)
		var buff: Dictionary = buffs.get(str(int(use.get("78",0))),{})
		var title: Dictionary = titles.get(str(int(use.get("7243",0))),{})
		var title_buff: Dictionary = buffs.get(str(int(title.get("RewardID",0))),{})
		if buff.is_empty() or title.is_empty() or title_buff.is_empty(): return denied("가호 버프·영구 호칭 연결 누락")
		var category: Dictionary = index(raw.ItemCategory).get(str(int(items[key].CategoryID)),{})
		if bool(category.get("IsConsumable",true)) or not bool(category.get("IsActivatable",false)): return denied("가호 본체 비소모 계약 확인 필요")
		if int(buff.get("BuffGroupID",0)) != 604 or int(title_buff.get("BuffGroupID",0)) != 841: return denied("가호 그룹 불일치")
		var buff_flat := 0
		var title_flat := 0
		for link: Dictionary in raw.BuffBonus:
			var bonus: Dictionary = bonuses.get(str(int(link.BonusID)),{})
			if int(link.get("CharacterLevel",0)) != 0 or int(link.get("CharacterClass",0)) != 0 or int(link.get("MinSpellLevel",0)) != 0: return denied("미지원 가호 조건")
			if int(link.BuffClassID) == int(buff.ID) and int(bonus.get("BonusTypeID",0)) == 301: buff_flat += int(bonus.Value)
			if int(link.BuffClassID) == int(title_buff.ID) and int(bonus.get("BonusTypeID",0)) == 112: title_flat += int(bonus.Value)
		var recipe: Dictionary = recipes[key]
		var recipe_id := int(recipe.ItemCraftID)
		if int(recipe.get("ServerLimitSetID",-1)) != 0 or int(recipe.get("LevelLimitValue",-1)) != 0 or int(recipe.get("AlwaysSuccess",0)) != 1 or int(recipe.get("EffectiveFrom",0)) != 1 or int(recipe.get("EffectiveTo",0)) != 3 or bool(recipe.get("IsCoalitionItem",true)) or int(recipe.get("CraftGroupTypeID",-1)) != 0:
			return denied("가호 제작 서버·기간·레벨·확정 조건 확인 필요")
		if not bool(title.get("IsPermanent",false)) or bool(title.get("IsTest",true)) or bool(title.get("IsClan",true)) or not bool(buff.get("IsImmuneToDead",false)) or not bool(title_buff.get("IsImmuneToDead",false)):
			return denied("가호 영구 호칭·사망 유지 계약 확인 필요")
		var inputs: Array = []
		var limits: Array = []
		var outputs: Array = []
		for row: Dictionary in raw.ItemCraftInput:
			if int(row.ItemCraftID) == recipe_id: inputs.append(row)
		for row: Dictionary in raw.ItemCraftRestriction:
			if int(row.ItemCraftID) == recipe_id: limits.append(row)
		for row: Dictionary in raw.ItemCraftOutputView:
			if int(row.ItemCraftID) == recipe_id: outputs.append(row)
		if inputs.size() != 2 or limits.size() != 1 or outputs.size() != 1: return denied("가호 제작 입력·제한·출력 확인 필요")
		if int(limits[0].ServiceTypeID) != 13 or int(limits[0].Value) != 1 or int(limits[0].RefreshUnitID) != 111: return denied("캐릭터당 1회 제작 계약 확인 필요")
		if int(outputs[0].Probability) != 1000000 or int(outputs[0].Amount) != 1 or int(outputs[0].ItemClassID) != item_id: return denied("확정 제작 출력 확인 필요")
		definitions[key] = {"id":item_id,"name":str(desc.get(str(int(items[key].IdentifiedDescID)),{}).get("Description","")),
			"item":items[key],"possession_flat":int(possession.get("301",0)),"possession_percent_raw":int(possession.get("7818",0)),
			"buff_flat":buff_flat,"buff":buff,"duration":int(use.get("109",0)),"cooldown":int(use.get("1022",0)),
			"material_id":int(use.get("2312",0)),"material_amount":int(use.get("2322",0)),
			"consume_sprite_id":int(use.get("107",0)),
			"title":title,"title_buff":title_buff,"title_flat":title_flat,
			"recipe":recipe,"inputs":inputs,"restriction":limits[0],"output":outputs[0]}
		if definitions[key].name.is_empty() or int(use.get("2312",0)) != 3631 or int(use.get("2322",0)) != 10 or int(use.get("107",0)) <= 0: return denied("가호 이름·명예 코인·사용 연출 계약 불일치")
	var material_rewards := index(raw.get("MaterialReward",[]))
	var material_quests: Dictionary = {}
	for link: Dictionary in raw.get("MaterialQuestReward",[]):
		var key := str(int(link.RewardID))
		if not material_quests.has(key): material_quests[key] = []
		material_quests[key].append(int(link.QuestID))
	var supply_recipes: Dictionary = {}
	if not raw.get("SupplyRecipeView") is Array or raw.SupplyRecipeView.size() != 2 or not raw.get("SupplyItemCraftRestriction") is Array or not raw.SupplyItemCraftRestriction.is_empty(): return denied("정상 가호 공급 제작식·제한 확인 필요")
	for view: Dictionary in raw.SupplyRecipeView:
		var recipe_id := int(view.ItemCraftID)
		var item_id := int(view.ItemClassID)
		if recipe_id not in SUPPLY_RECIPE_IDS or item_id not in [75764,123373] or int(view.AlwaysSuccess) != 1 or int(view.ServerLimitSetID) != 0 or int(view.LevelLimitValue) != 0 or int(view.EffectiveFrom) != 1 or int(view.EffectiveTo) != 3 or bool(view.IsCoalitionItem) or int(view.CraftGroupTypeID) != 0 or bool(view.NoRepeat): return denied("정상 가호 공급 제작 조건 미지원")
		var inputs: Array = []
		var outputs: Array = []
		for row: Dictionary in raw.get("SupplyItemCraftInput",[]):
			if int(row.ItemCraftID) == recipe_id:
				if int(row.Amount) != 1 or int(row.Enchant) != 0 or int(row.ItemBlessCodeID) != 1 or int(row.ItemHoningEpithetID) != 0: return denied("정상 가호 공급 재료 상태 미지원")
				inputs.append(row)
		for row: Dictionary in raw.get("SupplyItemCraftOutputView",[]):
			if int(row.ItemCraftID) == recipe_id: outputs.append(row)
		if inputs.size() != 2 or outputs.size() != 1 or int(outputs[0].Probability) != 1000000 or int(outputs[0].Amount) != 1 or int(outputs[0].ItemClassID) != item_id or int(outputs[0].Enchant) != 0 or int(outputs[0].ItemBlessCodeID) != 1: return denied("정상 가호 공급 제작 입출력 미지원")
		supply_recipes[str(item_id)] = {"id":item_id,"name":str(desc.get(str(int(items[str(item_id)].IdentifiedDescID)),{}).get("Description","")),"recipe":view,"inputs":inputs,"output":outputs[0]}
	return {"ok":true,"definitions":definitions,"items":items,"descriptions":desc,"supply_recipes":supply_recipes,"material_rewards":material_rewards,"material_quests":material_quests,"source_sha256":SOURCE_SHA,
		"group604_item_ids":ids(raw.get("Group604ItemBonus",[]),"ItemClassID")}

static func install(path: String) -> Dictionary:
	var result := extract(path)
	if not bool(result.get("ok",false)): return result
	var text := JSON.stringify(result.capsule,"",true)
	var digest := text.sha256_text()
	if not CAPSULE_SHA.is_empty() and digest != CAPSULE_SHA: return denied("가호 실행 데이터 해시 불일치")
	for directory: String in [SOURCE_DIR,RUNTIME_DIR]:
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK: return denied("가호 설치 폴더 생성 실패")
	var backup := SOURCE_DIR + "/" + SOURCE_SHA + ".zip"
	if not FileAccess.file_exists(backup):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup)) != OK: return denied("가호 원본 보존 실패")
	if FileAccess.get_sha256(backup) != SOURCE_SHA: return denied("보존된 가호 원본 해시 불일치")
	var runtime := RUNTIME_DIR + "/" + digest + ".json"
	var write_error := write_text(runtime,text)
	if write_error != OK: return denied("가호 실행 데이터 저장 실패")
	if FileAccess.get_sha256(runtime) != digest: return denied("가호 실행 데이터 읽기 검증 실패")
	var pointer := {"schema":1,"sha256":digest,"source_sha256":SOURCE_SHA}
	if write_text(POINTER,JSON.stringify(pointer)) != OK: return denied("가호 설치 선택 저장 실패")
	result.erase("capsule")
	result["runtime_sha256"] = digest
	return result

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
const BAKE_NAME := "protection523_original"

static func restore() -> Dictionary:
	var selected := FileAccess.open(POINTER,FileAccess.READ)
	if selected == null:
		# Only actual absence permits the held original input. Existing but
		# unreadable/invalid selections must retain their own failure priority.
		var open_error := FileAccess.get_open_error()
		if open_error != ERR_FILE_NOT_FOUND or FileAccess.file_exists(POINTER) or DirAccess.dir_exists_absolute(POINTER): return denied("가호 설치 선택 파일 접근 실패")
		var parent := DirAccess.open(POINTER.get_base_dir())
		if parent != null and parent.is_link(POINTER.get_file()): return denied("가호 설치 선택 파일 접근 실패")
		var source_path: String = CommonSource.archive_path()
		if source_path.is_empty(): return denied("원본523 ZIP을 설치해 주세요")
		# The extraction is a pure function of the verified original and this
		# code; a later start reuses this device's baked result.
		var verified: bool = CommonSource.identity().get("source_sha256") == SOURCE_SHA
		var bake_key: String = BAKE.projection_key(BAKE_NAME, CommonSource.verified_key()) if verified else ""
		var baked: Variant = BAKE.read(BAKE_NAME, bake_key)
		if baked is Dictionary and bool((baked as Dictionary).get("ok", false)): return baked
		BOOT_LOG.mark("protection_cold_build")
		var original := extract(source_path)
		original.erase("capsule")
		if verified and bool(original.get("ok", false)): BAKE.write(BAKE_NAME, bake_key, original)
		return original
	selected.close()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(POINTER)) != OK or not parser.data is Dictionary: return denied("가호 설치 선택 파일 손상")
	var pointer: Dictionary = parser.data
	if pointer.get("source_sha256") != SOURCE_SHA or pointer.get("schema") != 1: return denied("가호 설치 출처 손상")
	var digest := str(pointer.get("sha256",""))
	if digest.length() != 64 or digest != digest.to_lower() or not digest.is_valid_hex_number(false): return denied("가호 설치 해시 손상")
	if digest in [LEGACY_CAPSULE_SHA,MATERIAL_CAPSULE_SHA]:
		# Reuse the already installed, pinned source ZIP. Retain the old capsule
		# and replace the active pointer only after a complete verified install.
		var backup := SOURCE_DIR + "/" + SOURCE_SHA + ".zip"
		if FileAccess.file_exists(backup) and FileAccess.get_sha256(backup) == SOURCE_SHA: return install(backup)
		return denied("기존 가호 원본 ZIP 확인 후 다시 설치해 주세요")
	if not CAPSULE_SHA.is_empty() and digest != CAPSULE_SHA: return denied("가호 실행 데이터 출처 확인 필요")
	var runtime := RUNTIME_DIR + "/" + digest + ".json"
	if not FileAccess.file_exists(runtime): return denied("가호 실행 데이터 파일 누락")
	if FileAccess.get_sha256(runtime) != digest: return denied("가호 실행 데이터 파일 손상")
	if parser.parse(FileAccess.get_file_as_string(runtime)) != OK or not parser.data is Dictionary: return denied("가호 실행 데이터 해석 실패")
	return compile(parser.data)

static func write_text(path: String, content: String) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
