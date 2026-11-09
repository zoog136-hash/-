extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Immutable private rule pack. Identity joins never grant or rename items.
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PACK_SHA = "a6f06d657bc34a86d91ccbcaf9f2c836312df6e57d15d38e890aa74061b12bc5"
const PACK_BYTES: int = 49818
const ZIP_SHA = "df1836767b85abd2e5f67ac023f005c80dc6df9cf8fa5022518887354eb9126d"
const ZIP_BYTES: int = 8872
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FULL_ITEMS = preload("res://scripts/loot/patch523_monster_drops.gd")
const DEFAULT_FILE = "user://inventory523/inventory_rules523.json"
const CATALOG_FILE = "res://data/catalog_v19.json"
const PRICE_FILE = "res://data/automation/inventory523_prices.json"
const SOURCE_TABLES = ["StorageAutoStore","MerchantAutoSell","ItemClass","ItemCategory","ItemEquipSlot","DescData_Korean","Grade","ItemBlessCode","ConstantData"]
const SOURCE_POLICY = "Native selection IDs/bless states and exact catalog identities. Publicly corroborated prices win; otherwise existing host grade rates, labelled as host policy. No virtual item grants, native activation, coordinates or NPC placements inferred."
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
const SHOP = preload("res://scripts/shop/shop_catalog.gd")
const FIELDS = ["name","source","sourceId","sourceUrl","slot","type","grade"]
var document: Dictionary = {}
var problem: String = "523 원본 규칙을 설치해 주세요"
var registered_records: Array = []

static func configured_file() -> String:
	var configured: String = OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE")
	return configured if configured != "" else DEFAULT_FILE

func fingerprint() -> String:
	return PACK_SHA if not document.is_empty() else ""

func parse(raw: PackedByteArray) -> Dictionary:
	if raw.size() != PACK_BYTES: return {}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(raw)
	if hash.finish().hex_encode() != PACK_SHA: return {}
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary: return {}
	var data: Dictionary = parser.data
	if data.get("schema") != "twilight-inventory523-v1" or data.get("source_sha256") != SOURCE_SHA: return {}
	if data.get("items",{}).size() != 80 or data.get("storage_rows",[]).size() != 84 or data.get("sell_rows",[]).size() != 25: return {}
	return data

func load_file(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	var open_error: Error = FileAccess.get_open_error()
	if file == null and open_error == ERR_FILE_NOT_FOUND and path == DEFAULT_FILE and OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE").is_empty() and not FileAccess.file_exists(path):
		return _load_original_if_uninstalled()
	if file == null or file.get_length() != PACK_BYTES:
		problem = "523 원본 규칙 파일을 확인해주세요"
		return false
	var next: Dictionary = parse(file.get_buffer(PACK_BYTES))
	if next.is_empty():
		problem = "523 원본 규칙의 버전·무결성을 확인할 수 없습니다"
		return false
	document = next
	problem = ""
	return true

static func _source_canonical(value: Variant) -> Variant:
	# The Python generator serializes original integral JSON numbers as ints.
	if value is float and _integer(value) and absf(value) <= 9007199254740991.0: return int(value)
	if value is Array:
		var rows: Array = []
		for entry: Variant in value: rows.append(_source_canonical(entry))
		return rows
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _source_canonical(value[key])
		return result
	return value

static func _source_json(value: Variant) -> String:
	return JSON.stringify(_source_canonical(value),"",true,true)

func _source_failure(reason: String) -> Dictionary:
	problem = "보유 원본523 자동 정비 입력 대기 · "+reason
	return {}

static func _remember_description(cache: Dictionary, id: Variant, text: Variant) -> void:
	if not _integer(id) or not text is String: return
	cache[str(int(id))] = str(text).strip_edges()

static func _sidecar_descriptions(item_id: int, original: Dictionary, grade: Dictionary, cache: Dictionary) -> void:
	var definition: Dictionary = FULL_ITEMS.definition_id(str(item_id))
	if definition.is_empty() or _source_json(definition.get("original_item",{})) != _source_json(original): return
	for field: String in ["DescID","IdentifiedDescID"]:
		var reference: Variant = definition.get("source_descriptions",{}).get(field)
		if reference is Dictionary and reference.get("id") == original.get(field):
			_remember_description(cache,reference.get("id"),reference.get("text"))
	# compile_items binds this exact Grade.DescID to native_record.grade.
	var native: Dictionary = NATIVE_FIELDS.full(definition.get("native_record",{}))
	if _source_json(definition.get("grade",{})) == _source_json(grade) and native.get("source_grade_id") == grade.get("ID") and native.get("source_label_status") == "source_descriptor":
		_remember_description(cache,grade.get("DescID"),native.get("grade"))

static func _source_description(id: int, cache: Dictionary) -> String:
	var key: String = str(id)
	if cache.has(key): return str(cache[key])
	if id <= 0: return ""
	# Only the selected items' explicit description IDs are requested. A first
	# original text lookup can parse its table; it is not whole-table game use.
	var row: Dictionary = SOURCE.row("DescData_Korean",id)
	if row.get("Description") is String: _remember_description(cache,id,row.Description)
	return str(cache.get(key,""))

func _source_document() -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	if identity.get("source_sha256") != SOURCE_SHA: return _source_failure(SOURCE.problem())
	var provenance: Dictionary = {}
	for table: String in SOURCE_TABLES:
		var metadata: Dictionary = SOURCE.table_metadata(table)
		if metadata.get("path") != "content/"+table+".json" or not metadata.get("sha256") is String or not _integer(metadata.get("bytes")) or not _integer(metadata.get("row_count")):
			return _source_failure("원문 표 정체 없음: "+table)
		provenance[table] = {"sha256":metadata.sha256,"bytes":int(metadata.bytes),"rows":int(metadata.row_count)}
	var storage_rows: Array[Dictionary] = SOURCE.rows("StorageAutoStore")
	var sell_rows: Array[Dictionary] = SOURCE.rows("MerchantAutoSell")
	if storage_rows.size() != 84 or sell_rows.size() != 25: return _source_failure("기존84개 보관·25개 매입 선택과 다름")
	var storage: Dictionary = {}
	var selling: Dictionary = {}
	var selected: Dictionary = {}
	for row: Dictionary in storage_rows:
		if not _integer(row.get("ItemClassID")) or not _integer(row.get("ItemBlessCodeID")): return _source_failure("보관 ID·축복 참조 없음")
		var id: String = str(int(row.ItemClassID))
		if not storage.has(id): storage[id] = []
		storage[id].append(row.ItemBlessCodeID)
		selected[id] = true
	for row: Dictionary in sell_rows:
		if not _integer(row.get("ItemClassID")): return _source_failure("매입 ID 참조 없음")
		var id: String = str(int(row.ItemClassID))
		selling[id] = true
		selected[id] = true
	if selected.size() != 80: return _source_failure("기존80개 아이템 선택과 다름")
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_FILE))
	var price_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRICE_FILE))
	if not catalog is Dictionary or not catalog.get("아이템") is Array: return _source_failure("기존 ID·URL 바인딩 카탈로그 없음")
	if not price_data is Dictionary or not price_data.get("prices") is Dictionary: return _source_failure("기존 확정 매입가 정책 없음")
	var prices: Dictionary = price_data.prices
	for key: Variant in prices:
		if not key is String or not str(key).is_valid_int() or not selling.has(str(int(key))): return _source_failure("원본 매입 선택 밖 가격 정책")
	var names: Dictionary = {}
	var by_id: Dictionary = {}
	for value: Variant in catalog["아이템"]:
		if not value is Dictionary or not value.get("name") is String: return _source_failure("기존 카탈로그 이름 구조 없음")
		var record: Dictionary = value
		var name_value: String = record.name
		names[name_value] = int(names.get(name_value,0))+1
		var id: String = str(record.get("sourceId",""))
		if record.get("source") != "inven" or not id.is_valid_int() or id.begins_with("+") or id.begins_with("-"): continue
		id = str(int(id))
		if not by_id.has(id): by_id[id] = []
		by_id[id].append(record)
	var definitions: Dictionary = {}
	var descriptions: Dictionary = {}
	var virtual_count: int = 0
	var test_count: int = 0
	for key: String in selected:
		var id: int = int(key)
		var original: Dictionary = SOURCE.row("ItemClass",id)
		if original.is_empty(): return _source_failure("ItemClass#"+key+" 없음")
		for field: String in ["CategoryID","GradeID","DescID","IdentifiedDescID","Cost"]:
			if not _integer(original.get(field)): return _source_failure("ItemClass#"+key+"."+field+" 없음")
		for field: String in ["IsStorable","IsTradable","TestItem"]:
			if typeof(original.get(field)) != TYPE_BOOL: return _source_failure("ItemClass#"+key+"."+field+" 선언 없음")
		if not original.get("Name") is String: return _source_failure("ItemClass#"+key+".Name 없음")
		var category: Dictionary = SOURCE.row("ItemCategory",int(original.CategoryID))
		var grade: Dictionary = SOURCE.row("Grade",int(original.GradeID))
		if not category.get("Name") is String or typeof(category.get("IsStackable")) != TYPE_BOOL or not _integer(grade.get("DescID")):
			return _source_failure("ItemClass#"+key+" 범주·등급 원문 없음")
		_sidecar_descriptions(id,original,grade,descriptions)
		var identified: String = _source_description(int(original.IdentifiedDescID),descriptions)
		var description: String = _source_description(int(original.DescID),descriptions)
		var grade_label: String = _source_description(int(grade.DescID),descriptions)
		var label: String = identified if not identified.is_empty() else description
		if label.is_empty() or grade_label.is_empty(): return _source_failure("ItemClass#"+key+" 필수 원문 표시명·등급 없음")
		var binding: Dictionary = {}
		var pending: String = "no_unique_exact_id"
		var candidates: Array = by_id.get(key,[])
		if candidates.size() == 1:
			var candidate: Dictionary = candidates[0]
			if candidate.get("sourceUrl") != "https://lineagem.inven.co.kr/db/item/"+key:
				pending = "source_url_id_mismatch"
			elif str(candidate.name).strip_edges() not in [descriptions.get(str(int(original.DescID))),descriptions.get(str(int(original.IdentifiedDescID)))]:
				pending = "exact_descriptor_mismatch"
			elif int(names.get(candidate.name,0)) != 1:
				pending = "ambiguous_inventory_name"
			else:
				for field: String in FIELDS: binding[field] = candidate.get(field,"")
				pending = ""
		var price: Variant = prices.get(key,{})
		if not price is Dictionary: return _source_failure("ItemClass#"+key+" 가격 정책 구조 없음")
		if not price.is_empty() and (not _integer(price.get("adena")) or float(price.adena) <= 0 or price.adena != original.Cost): return _source_failure("ItemClass#"+key+" 원문·확정 매입가 불일치")
		var virtual: bool = str(original.Name).begins_with("[자동판매]")
		virtual_count += int(virtual)
		test_count += int(bool(original.TestItem))
		definitions[key] = {"id":id,"label":label,"source_record_sha256":_source_json(original).sha256_text(),
			"is_storable":original.IsStorable,"player_tradable":original.IsTradable,"source_cost":original.Cost,"grade":grade_label,
			"stackable":category.IsStackable,"currency":category.Name == "Currency",
			"equipment":not SOURCE.related("ItemEquipSlot","ItemClassID",id).is_empty(),"virtual":virtual,"test_item":original.TestItem,
			"storage_bless":storage.get(key,[]),"merchant_auto":selling.has(key),"binding":binding,"binding_pending":pending,"price":price}
	var auto_sell_value: Variant = null
	for constant: Dictionary in SOURCE.rows("ConstantData"):
		if constant.get("Name") == "AutoSellMaxCount": auto_sell_value = constant.get("Value")
	if auto_sell_value is String:
		if not str(auto_sell_value).is_valid_int(): return _source_failure("AutoSellMaxCount 원문 정수 없음")
		auto_sell_value = int(auto_sell_value)
	elif not _integer(auto_sell_value): return _source_failure("AutoSellMaxCount 원문 없음")
	var storage_bindings: int = 0
	var sell_bindings: int = 0
	for row: Dictionary in storage_rows:
		if not definitions[str(int(row.ItemClassID))].binding.is_empty(): storage_bindings += 1
	for row: Dictionary in sell_rows:
		if not definitions[str(int(row.ItemClassID))].binding.is_empty(): sell_bindings += 1
	return {"schema":"twilight-inventory523-v1","source_sha256":SOURCE_SHA,"source_tables":provenance,"items":definitions,
		"storage_rows":storage_rows,"sell_rows":sell_rows,"bless_codes":SOURCE.rows("ItemBlessCode"),"auto_sell_max":int(auto_sell_value),
		"counts":{"storage_rows":storage_rows.size(),"sell_rows":sell_rows.size(),"items":definitions.size(),
			"inven_storage_rows":storage_bindings,"inven_sell_rows":sell_bindings,"confirmed_prices":prices.size(),
			"virtual_selectors":virtual_count,"test_items":test_count},"policy":SOURCE_POLICY}

func _load_original_if_uninstalled() -> bool:
	# An explicit, present, corrupt or inaccessible compiled input is never
	# bypassed. Reproduce only the already approved payload, entirely in memory.
	if not OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE").is_empty() or FileAccess.file_exists(DEFAULT_FILE): return false
	var next: Dictionary = _source_document()
	if next.is_empty(): return false
	var raw: PackedByteArray = (_source_json(next)+"\n").to_utf8_buffer()
	var reproduced: Dictionary = parse(raw)
	if reproduced.is_empty():
		problem = "보유 원본523으로 기존 자동 정비 규칙의 동일 크기·SHA를 재현하지 못했습니다 · 기존 규칙·소유품 보존"
		return false
	if not OS.get_environment("TWILIGHT_AUTO_INVENTORY523_FILE").is_empty() or FileAccess.file_exists(DEFAULT_FILE):
		problem = "자동 정비 규칙 입력이 변경됐습니다 · 기존 규칙 파일을 다시 읽어주세요"
		return false
	document = reproduced
	problem = ""
	return true

func install_zip(path: String) -> Dictionary:
	var input := FileAccess.open(path,FileAccess.READ)
	if input == null or input.get_length() != ZIP_BYTES or FileAccess.get_sha256(path) != ZIP_SHA: return {"ok":false,"reason":"지원하는 원본 규칙 ZIP의 크기·버전이 아닙니다"}
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return {"ok":false,"reason":"규칙 ZIP을 열 수 없습니다"}
	var raw: PackedByteArray = archive.read_file("inventory_rules523.json") if archive.file_exists("inventory_rules523.json") else PackedByteArray()
	archive.close()
	var next: Dictionary = parse(raw)
	if next.is_empty(): return {"ok":false,"reason":"지원하는 523 원본 규칙 ZIP이 아닙니다"}
	var destination: String = "user://inventory523/inventory_rules523.json"
	var absolute: String = ProjectSettings.globalize_path(destination)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return {"ok":false,"reason":"규칙 저장 폴더를 만들 수 없습니다"}
	if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) == PACK_SHA:
		document = next
		problem = ""
		return {"ok":true}
	var temp: String = absolute+".tmp"
	var stream := FileAccess.open(temp,FileAccess.WRITE)
	if stream == null: return {"ok":false,"reason":"규칙 파일 저장 실패 · 이전 규칙 보존"}
	stream.store_buffer(raw)
	stream.flush()
	var error: Error = stream.get_error()
	stream.close()
	if error != OK or FileAccess.get_sha256(temp) != PACK_SHA:
		DirAccess.remove_absolute(temp)
		return {"ok":false,"reason":"규칙 쓰기 검증 실패 · 이전 규칙 보존"}
	if FileAccess.file_exists(absolute):
		var previous_sha: String = FileAccess.get_sha256(absolute)
		var backup: String = absolute+".previous-"+previous_sha
		if (not FileAccess.file_exists(backup) and DirAccess.copy_absolute(absolute,backup) != OK) or FileAccess.get_sha256(backup) != previous_sha:
			DirAccess.remove_absolute(temp)
			return {"ok":false,"reason":"이전 규칙 백업 실패 · 교체 중지"}
	if DirAccess.rename_absolute(temp,absolute) != OK:
		DirAccess.remove_absolute(temp)
		return {"ok":false,"reason":"규칙 교체 실패 · 이전 규칙 보존"}
	document = next
	problem = ""
	return {"ok":true}

static func _canonical_identity(record: Dictionary) -> Array:
	var out: Array = []
	for key: String in FIELDS: out.append(str(record.get(key,"")))
	for key: String in ["source_snapshot","source_m_native_item","source_item_class_id","source_display_name","source_bless_raw"]: out.append(str(record.get(key,"")))
	return out

func registered_status(records: Array) -> Dictionary:
	registered_records = records
	var matched: Dictionary = {}
	for record: Dictionary in records:
		var resolved: Dictionary = resolve(record)
		if resolved.is_empty(): continue
		matched[str(int(resolved.item.id))+":"+str(int(resolved.bless))] = resolved
	var result: Dictionary = {"deposit":0,"sell":0,"deposit_allowed":0,"sell_allowed":0,"missing":[],"registered_keys":matched.size()}
	for mode: String in ["deposit","sell"]:
		for row: Dictionary in document.get("storage_rows" if mode == "deposit" else "sell_rows",[]):
			var key: String = str(int(row.ItemClassID))+":"+str(int(row.get("ItemBlessCodeID",1)))
			if matched.has(key):
				result[mode] += 1
				if eligible(matched[key],mode): result[mode+"_allowed"] += 1
			else: result.missing.append({"mode":mode,"id":int(row.ItemClassID),"bless":int(row.get("ItemBlessCodeID",1)),"virtual":bool(definition(str(int(row.ItemClassID))).get("virtual",false))})
	return result

func definition(id: String) -> Dictionary:
	return document.get("items",{}).get(id,{})

func resolve(record: Dictionary, physical: Dictionary = {}) -> Dictionary:
	if document.is_empty() or record.is_empty(): return {}
	if record.get("source") == "twilight-shop523-consumable": return _resolve_shop_stack(record,physical)
	var id: String = str(record.get("sourceId",""))
	var bless: int = 1
	if record.get("source") == "inven":
		var row: Dictionary = definition(id)
		var binding: Dictionary = row.get("binding",{})
		if binding.is_empty(): return {}
		for field: String in FIELDS:
			if record.get(field,"") != binding.get(field,""): return {}
		# The exact unique Inven normal stack has no alternate bless key. Do not
		# reinterpret a blessed/unknown physical state as that normal stack.
		if not physical.is_empty() or record.get("blessed",false) or str(record.get("bless_state","")) not in ["","normal"]: return {}
		if record.has("source_bless_raw") and int(record.source_bless_raw) != 1: return {}
		return {"item":row,"bless":1,"identity":"inven_exact_id_url_descriptor_normal_stack"}
	if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("source_m_native_item") != true: return {}
	var raw_id: Variant = record.get("source_item_class_id",0)
	if not _integer(raw_id) or int(raw_id) <= 0: return {}
	id = str(int(raw_id))
	var row: Dictionary = definition(id)
	if row.is_empty() or record.get("source_display_name") != row.label: return {}
	if record.get("grade") != row.grade: return {}
	var raw_bless: Variant = physical.get("source_bless_raw",record.get("source_bless_raw",0))
	if not _integer(raw_bless) or int(raw_bless) not in [1,2,3]: return {}
	bless = int(raw_bless)
	var suffix: String = "" if bless == 1 else ":bless:"+str(bless)
	var caption: String = "" if bless == 1 else " · "+("축복" if bless == 2 else "저주")
	if str(record.get("sourceId","")) != "m523:item:"+id+suffix or str(record.get("name","")) != str(row.label)+" · 원본#"+id+caption: return {}
	return {"item":row,"bless":bless,"identity":"m523_explicit_class_and_bless"}

func _resolve_shop_stack(record: Dictionary, physical: Dictionary) -> Dictionary:
	# PR247 9b2cb076's runtime catalog contract, not a save-string migration.
	# Only the two already-supplied automation targets are accepted. No records,
	# ownership, use effects, aliases or blessing variants are created here.
	var raw_id: Variant = record.get("source523_shop_item_id")
	if not _integer(raw_id) or int(raw_id) not in [313,385] or not physical.is_empty(): return {}
	var registered: int = 0
	for candidate: Dictionary in registered_records:
		if candidate.get("name") == record.get("name"):
			if not is_same(candidate,record): return {}
			registered += 1
	if registered != 1: return {}
	var id: int = int(raw_id)
	var row: Dictionary = definition(str(id))
	if row.is_empty() or record.get("name") != row.label or record.get("grade") != row.grade or record.get("slot") != "consumable": return {}
	if record.get("kind") != ("teleport" if id == 313 else "regen") or record.get("type") != ("이동주문서" if id == 313 else "회복물약"): return {}
	if record.get("source523_shop_use_origin") != "TWILIGHT 기존 소모품 효과 재사용 · 원본 각인 ID/스택 보존" or str(record.get("sourceId","")) != "": return {}
	if record.get("blessed",false) or str(record.get("bless_state","")).to_lower() not in ["","normal"]: return {}
	if record.has("source_bless_raw") and (not _integer(record.source_bless_raw) or int(record.source_bless_raw) != 1): return {}
	if record.has("source_item_class_id") and (not _integer(record.source_item_class_id) or int(record.source_item_class_id) != id): return {}
	if record.get("source_test_item",false): return {}
	return {"item":row,"bless":1,"identity":"pr247_registered_normal_engraved_stack"}

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func eligible(resolved: Dictionary, mode: String) -> bool:
	if resolved.is_empty(): return false
	var row: Dictionary = resolved.item
	if row.virtual or row.test_item or row.currency or row.equipment or not row.stackable: return false
	if mode == "deposit":
		# JSON uses float numbers while resolved blessing IDs are integers.
		# Array.has is type-sensitive; compare the source numeric IDs explicitly.
		if not row.is_storable: return false
		for allowed: Variant in row.storage_bless:
			if int(allowed) == int(resolved.bless): return true
		return false
	return mode == "sell" and row.merchant_auto and int(resolved.bless) == 1

func quote(record: Dictionary, name: String, quantity: int, id: String, inventory: Dictionary, physical: Dictionary, equipped: Dictionary, wallet: int, overrides: Dictionary) -> Dictionary:
	var resolved: Dictionary = resolve(record,physical.get(id,{}) if id != "" else {})
	if not eligible(resolved,"sell"): return {"ok":false,"reason":"원본 매입 대상·축복 상태를 확인할 수 없습니다"}
	if id != "" or quantity < 1 or quantity > BUYBACK.MAX_STACK_SALE or int(inventory.get(name,0)) < quantity or wallet < 0: return {"ok":false,"reason":"매입 수량 또는 소지품이 유효하지 않습니다"}
	if bool(record.get("bound",false)) or record.get("tradeable",true) == false or bool(record.get("quest_item",false)): return {"ok":false,"reason":"귀속·퀘스트·명시적 거래 보호 아이템입니다"}
	var row: Dictionary = resolved.item
	var policy: Dictionary = row.price
	var unit: int = int(policy.adena) if not policy.is_empty() else int(overrides.get(str(int(row.id)),BUYBACK.GRADE_BUYBACK.get(str(row.grade),0)))
	var basis: String = "523 원본·공개 확인 매입가" if not policy.is_empty() else "자체 매입값 · 기존 등급 기준" if not overrides.has(str(int(row.id))) else "자체 매입값 · 사용자 설정"
	if policy.is_empty():
		var purchase: int = SHOP.price_for(name)
		if purchase > 0: unit = mini(unit,purchase)
	if unit <= 0 or unit > 1000000000 or wallet > BUYBACK.MAX_WALLET-unit*quantity: return {"ok":false,"reason":"매입가 미설정 또는 지갑 한도 초과"}
	return {"ok":true,"item_name":name,"quantity":quantity,"instance_id":"","enhancement":0,"payment":unit*quantity,"unit_price":unit,"price_basis":basis,"source_item_class_id":int(row.id)}
