extends RefCounted
## Full private ItemClass sidecars. Two cached shards; no source code execution.
const ICON_IDENTITY = preload("res://scripts/ui/source_item_icon_identity.gd")
const PACK = preload("res://scripts/lineagem_pack_install.gd")
const MAX_SHARD = 8*1024*1024
const MAX_RAW = 16*1024*1024
static var cache: Dictionary = {}
static var order: Array[String] = []
static var problem: String = ""

static func reset() -> void:
	cache.clear();order.clear();problem = ""

static func safe_shard(name: String) -> bool:
	return name.begins_with("items/") and name.ends_with(".bin") and name.length() == 14 and name.substr(6,4).is_valid_int() and PACK.safe_relative(name)

static func validate_files(document: Dictionary, root: String) -> bool:
	if not document.get("full_item_catalog",false): return true
	var shards: Dictionary = document.get("item_shards",{})
	if shards.is_empty() or shards.size() > 256: return false
	for name: String in shards:
		var info: Dictionary = shards[name]
		var file: String = root.path_join(name)
		if not safe_shard(name) or int(info.get("bytes",0)) <= 0 or int(info.bytes) > MAX_SHARD or int(info.get("raw_bytes",0)) > MAX_RAW: return false
		if not FileAccess.file_exists(file) or FileAccess.get_sha256(file) != info.get("sha256",""): return false
	return document.get("item_shard_index",{}).size() == document.get("item_definitions",{}).size()

static func definition(document: Dictionary, root: String, id: String) -> Dictionary:
	if not document.get("full_item_catalog",false): return document.get("item_definitions",{}).get(id,{})
	var relative: String = str(document.get("item_shard_index",{}).get(id,""))
	if not safe_shard(relative): return {}
	var key: String = root.path_join(relative)
	if not cache.has(key):
		var info: Dictionary = document.get("item_shards",{}).get(relative,{})
		if info.is_empty() or not FileAccess.file_exists(key):
			problem = "원본 아이템 상세 조각 누락 · 아이템 보존";return {}
		var file := FileAccess.open(key,FileAccess.READ)
		if file == null or file.get_length() != int(info.bytes) or file.get_length() > MAX_SHARD: return {}
		var packed: PackedByteArray = file.get_buffer(file.get_length())
		if PACK.sha(packed) != info.sha256: problem = "원본 상세 해시 불일치 · 아이템 보존";return {}
		var raw: PackedByteArray = packed.decompress_dynamic(MAX_RAW,FileAccess.COMPRESSION_GZIP)
		if raw.size() != int(info.raw_bytes): return {}
		var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if not value is Dictionary or value.get("kind") != "patch523_item_definitions" or value.get("items",{}).size() != int(info.count): return {}
		while order.size() >= 2: cache.erase(order.pop_front())
		cache[key] = value.items
		order.append(key)
	return cache[key].get(id,{})

static func install(path: String, entries: Dictionary, header: Dictionary, document: Dictionary, root: String) -> Dictionary:
	var shards: Dictionary = document.get("item_shards",{})
	if shards != header.get("item_shards",{}) or shards.is_empty() or shards.size() > 256 or entries.size() != shards.size()+2: return {"ok":false,"error":"전체 아이템 조각 목록 불일치"}
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return {"ok":false,"error":"아이템 ZIP 열기 실패"}
	# The root is committed last. Partial writes never activate this version.
	for relative: String in shards:
		var info: Dictionary = shards[relative]
		var entry: String = "payload/"+relative
		if not safe_shard(relative) or int(info.get("bytes",0)) <= 0 or int(info.bytes) > MAX_SHARD or int(info.get("raw_bytes",0)) > MAX_RAW or int(entries.get(entry,-1)) != int(info.bytes): zip.close();return {"ok":false,"error":"아이템 조각 경로·크기 불일치"}
		var packed: PackedByteArray = zip.read_file(entry)
		if PACK.sha(packed) != info.get("sha256",""): zip.close();return {"ok":false,"error":"아이템 조각 해시 불일치"}
		var raw: PackedByteArray = packed.decompress_dynamic(MAX_RAW,FileAccess.COMPRESSION_GZIP)
		if raw.size() != int(info.raw_bytes): zip.close();return {"ok":false,"error":"아이템 조각 압축 검사 실패"}
		var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if not value is Dictionary or value.get("kind") != "patch523_item_definitions" or value.get("items",{}).size() != int(info.count): zip.close();return {"ok":false,"error":"아이템 조각 정의 불일치"}
		var error: String = write_blob(root.path_join(relative),packed,str(info.sha256))
		if not error.is_empty(): zip.close();return {"ok":false,"error":error}
	zip.close()
	return {"ok":true} if validate_files(document,root) else {"ok":false,"error":"전체 아이템 설치 검증 실패"}

static func write_blob(target: String, packed: PackedByteArray, fingerprint: String) -> String:
	if FileAccess.file_exists(target): return "" if FileAccess.get_sha256(target) == fingerprint else "기존 아이템 파일 손상 · 원본 보존"
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return "아이템 설치 폴더 생성 실패"
	var file := FileAccess.open(target+".pending",FileAccess.WRITE)
	if file == null: return "아이템 조각 기록 실패"
	file.store_buffer(packed);file.close()
	if FileAccess.get_sha256(target+".pending") != fingerprint or DirAccess.rename_absolute(target+".pending",target) != OK: return "아이템 조각 저장 검증 실패"
	return ""

static func register(document: Dictionary, catalog: Dictionary) -> Dictionary:
	ICON_IDENTITY.configure(document)
	var records: Array = catalog.get("아이템",[])
	var positions: Dictionary = {}
	for index: int in range(records.size()):
		positions[str(records[index].get("sourceId",""))] = index
		# Retained lookup for old saves/other suppliers, hidden from replacement UI.
		records[index]["source_preserved_legacy_catalog"] = true
	var added: int = 0
	var updated: int = 0
	for id: String in document.get("native_item_ids",[]):
		var source: Dictionary = document.item_definitions[id].native_record
		var states: Array = [1]
		if str(source.get("slot","")) in ["material","consumable","currency"]:
			for state: Variant in document.get("needed_bless_states",{}).get(id,[]):
				if int(state) in [2,3]: states.append(int(state))
		for state: int in states:
			var record: Dictionary = source.duplicate(true)
			ICON_IDENTITY.bind(record, document)
			record["source_bless_raw"] = state
			if state != 1:
				record["name"] = str(record.name)+(" · 축복" if state == 2 else " · 저주")
				record["sourceId"] = str(record.sourceId)+":bless:"+str(state)
			var prior: Dictionary = document.get("catalog_aliases",{}).get(id,{})
			if not prior.is_empty() and positions.has(str(prior.identity.sourceId)):
				var reviewed: Dictionary = records[int(positions[str(prior.identity.sourceId)])]
				for field: String in ["image_path","imageKey","sourceImageUrl"]:
					if reviewed.has(field): record[field] = reviewed[field]
				record["source_image_status"] = "existing_reviewed_catalog_reference_not_new_original_pixels"
			var key: String = str(record.sourceId)
			if positions.has(key): records[int(positions[key])] = record;updated += 1
			else: positions[key] = records.size();records.append(record);added += 1
	for id: String in document.get("catalog_aliases",{}):
		var alias: Dictionary = document.catalog_aliases[id]
		var key: String = str(alias.identity.sourceId)
		if not positions.has(key): continue
		var old: Dictionary = records[int(positions[key])]
		if old.get("name") != alias.original_identity.name: continue
		var record: Dictionary = document.item_definitions[id].native_record.duplicate(true)
		ICON_IDENTITY.bind(record, document)
		record.merge(alias.identity,true)
		record["source_legacy_catalog_alias"] = true
		record["source_preserved_legacy_catalog"] = true
		record["source_bless_raw"] = 1
		for field: String in ["image_path","imageKey","sourceImageUrl"]:
			if old.has(field): record[field] = old[field]
		records[int(positions[key])] = record
		updated += 1
	# One reviewed historical schema stored this dedicated wearable as material.
	# Keep both old blessing stack identities, without merging with the new
	# normal-name gear instances or granting any additional ownership.
	var stone: Dictionary = document.get("item_definitions",{}).get("323353",{}).get("native_record",{})
	if stone.get("slot") == "domination_stone":
		for state: int in [2,3]:
			var record: Dictionary = stone.duplicate(true)
			ICON_IDENTITY.bind(record, document)
			record["name"] = str(stone.name)+(" · 축복" if state == 2 else " · 저주")
			record["sourceId"] = str(stone.sourceId)+":bless:"+str(state)
			record["source_bless_raw"] = state
			record["source_legacy_stack_variant"] = true
			record["source_preserved_legacy_catalog"] = true
			record["bless_state"] = "blessed" if state == 2 else "cursed"
			var key: String = str(record.sourceId)
			if positions.has(key): records[int(positions[key])] = record;updated += 1
			else: positions[key] = records.size();records.append(record);added += 1
	catalog["아이템"] = records
	return {"added":added,"updated":updated,"native_definition_count":document.get("native_item_ids",[]).size()}
