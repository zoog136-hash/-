extends RefCounted
## Source facts and explicitly local availability stay separate from paid orders.
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const OriginalInput = preload("res://scripts/shop/source523_npc_input_projection.gd")
const RULES_PATH: String="res://data/shop/source523_npc_local_rules.json"
const MAX_INPUT_BYTES: int=8*1024*1024
var records: Dictionary={}
var loaded_sha256: String=""
var problem: String=""
var source_semantics: Dictionary={}
var input_identity: Dictionary={}
var current_shop_sha256: String=""
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))

static func _pack_arguments() -> Dictionary:
	var result: Dictionary={"explicit":false,"path":"","sha256":""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-npc-pack"):
			result.explicit=true;result.path=""
			if arg.begins_with("--source523-npc-pack="):result.path=arg.trim_prefix("--source523-npc-pack=")
		if arg.begins_with("--source523-npc-sha256"):
			result.explicit=true;result.sha256=""
			if arg.begins_with("--source523-npc-sha256="):result.sha256=arg.trim_prefix("--source523-npc-sha256=")
	return result

func configure(source) -> void:
	var arguments: Dictionary=_pack_arguments()
	if arguments.explicit:
		load_pack(arguments.path,arguments.sha256,source.loaded_sha256)
		return
	load_original(source)

func load_pack(path: String, expected: String, shop_sha256: String) -> bool:
	if expected.length()!=64 or not expected.is_valid_hex_number(false) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected.to_lower():return _fail("NPC 원본 팩 해시 확인 실패")
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_INPUT_BYTES:return _fail("NPC 원본 팩 접근·크기 오류")
	var bytes: PackedByteArray=file.get_buffer(file.get_length());file.close()
	return _load_payload(bytes,expected,shop_sha256,{"kind":"twilight.source523.npc-pack-input.v1","npc_model_sha256":expected.to_lower(),"npc_model_bytes":bytes.size(),"shop_model_sha256":shop_sha256,"declared_source_archive_sha256":Catalog.SOURCE_SHA256})

func load_original(source) -> bool:
	# UNVERIFIED: no original fallback may bypass any explicit NPC selection.
	if _pack_arguments().explicit:return _fail("명시한 NPC 원본 팩 입력을 우회하지 않습니다")
	var shop_sha256: String=str(source.loaded_sha256)
	if shop_sha256.length()!=64 or not shop_sha256.is_valid_hex_number(false):return _fail("현재 상점 모델의 실제 SHA256이 필요합니다")
	if not loaded_sha256.is_empty() and problem.is_empty() and current_shop_sha256==shop_sha256:return true
	var projection=OriginalInput.new()
	var pack: Dictionary=projection.build(shop_sha256)
	if pack.is_empty():return _fail(projection.problem)
	var bytes: PackedByteArray=JSON.stringify(pack,"",true,true).to_utf8_buffer()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	var actual: String=hash.finish().hex_encode()
	return _load_payload(bytes,actual,shop_sha256,{"kind":"twilight.source523.npc-original-input.v1","npc_model_sha256":actual,"npc_model_bytes":bytes.size(),"shop_model_sha256":shop_sha256,"source_archive_sha256":Catalog.SOURCE_SHA256})

func _load_payload(bytes: PackedByteArray, expected: String, shop_sha256: String, identity: Dictionary) -> bool:
	if bytes.size()>MAX_INPUT_BYTES:return _fail("NPC 원본 팩 접근·크기 오류")
	var parser:=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return _fail("NPC 원본 팩 JSON 오류")
	var pack: Dictionary=parser.data
	if pack.get("schema")!="twilight.source523.npc-definitions.v1" or pack.get("patch")!=523 or pack.get("source_zip_sha256")!=Catalog.SOURCE_SHA256 or pack.get("shop_pack_sha256")!=shop_sha256 or not pack.get("merchants") is Array:return _fail("NPC 팩과 기존 상점 팩의 원본 불일치")
	var next: Dictionary={}
	if not pack.get("source_semantics",{}) is Dictionary:return _fail("NPC 원본 의미 정의 형식 오류")
	var semantics: Dictionary=pack.get("source_semantics",{})
	for key: String in ["item_bless_codes","reset_schedule_types","refresh_constants"]:
		if not semantics.get(key,{}) is Dictionary:return _fail("NPC 의미 정의 누락·형식 오류")
	for row: Variant in pack.merchants:
		if not row is Dictionary or not Catalog._integer(row.get("merchant_id")) or not row.get("goods_ids") is Array or not row.get("object_links") is Array or next.has(str(int(row.merchant_id))):return _fail("NPC 원본 연결 형식 오류")
		var goods_index: Dictionary={}
		for id: Variant in row.goods_ids:
			if not Catalog._integer(id) or int(id)<1 or goods_index.has(str(int(id))):return _fail("NPC 원본 상품 ID 오류")
			goods_index[str(int(id))]=true
		for obj: Variant in row.object_links:
			if not obj is Dictionary or not Catalog._integer(obj.get("earth_object_id")) or not obj.get("currency_ids") is Array or not obj.get("sell_action_row_ids") is Array or not obj.get("spawns") is Array or not obj.get("attributes") is Array:return _fail("NPC 객체 연결 형식 오류")
			if not obj.get("object_defined") is bool or not obj.get("currency_defined_and_unique") is bool:return _fail("NPC 객체 정의 여부 오류")
			for id: Variant in obj.currency_ids+obj.sell_action_row_ids:
				if not Catalog._integer(id) or int(id)<1:return _fail("NPC 재화·동작 ID 오류")
			for spawn: Variant in obj.spawns:
				if not spawn is Dictionary or not Catalog._integer(spawn.get("ID")) or not Catalog._integer(spawn.get("ServerLimitSetID")) or not spawn.get("SpawnManually") is bool:return _fail("NPC 스폰 조건 형식 오류")
		next[str(int(row.merchant_id))]=row.duplicate(true)
		next[str(int(row.merchant_id))]["goods_index"]=goods_index
	records=next
	source_semantics=semantics.duplicate(true)
	loaded_sha256=expected.to_lower()
	current_shop_sha256=str(pack.shop_pack_sha256)
	input_identity=identity.duplicate(true)
	# This input may have a new NPC model SHA. Never rewrite cached orders or
	# receipts to it; their existing NPC/shop hash settlement remains PR269's.
	problem=""
	return true

func _fail(message: String) -> bool:
	problem=message
	return false

static func validate_rules(value: Variant) -> String:
	if not value is Dictionary or value.get("schema")!="twilight.source523.npc-local-rules.v1":return "NPC 자체 규칙 형식 오류"
	for key: String in ["enabled","zero_hours_are_open","zero_dates_are_open","remote_catalog"]:
		if not value.get(key) is bool:return "NPC 자체 규칙 값 오류"
	if not value.get("merchants") is Array or value.merchants.size()>192:return "NPC 자체 대상 오류"
	var ids: Dictionary={}
	for row: Variant in value.merchants:
		if not row is Dictionary or not row.get("label") is String or row.label.is_empty():return "NPC 자체 대상 이름 오류"
		for key: String in ["merchant_id","earth_object_id","spawn_id"]:
			if not Catalog._integer(row.get(key)) or int(row[key])<1:return "NPC 자체 대상 연결 오류"
		if ids.has(int(row.merchant_id)):return "중복 NPC 자체 대상"
		if row.has("minimum_level") and (not Catalog._integer(row.minimum_level) or int(row.minimum_level)<1):return "NPC 자체 접근 레벨 오류"
		if row.has("access_note") and (not row.access_note is String or row.access_note.is_empty()):return "NPC 자체 접근 설명 오류"
		if row.has("allow_range_attribute") and not row.allow_range_attribute is bool:return "NPC 거리 속성 자체 연결 오류"
		if row.has("equipment_mode") and row.equipment_mode!="normal_zero_only":return "NPC 장비 지급 설정 오류"
		ids[int(row.merchant_id)]=true
	return ""

func supports_normal_equipment(merchant_id: int, bless_code: int) -> bool:
	return rule_for(merchant_id).get("equipment_mode")=="normal_zero_only" and source_semantics.get("item_bless_codes",{}).get(str(bless_code))=="Normal"

func rule_hash(merchant_id: int = 0) -> String:
	var effective: Dictionary=rules.duplicate(true)
	if merchant_id>0:effective.merchants=[rule_for(merchant_id)]
	return JSON.stringify(effective,"",true,true).sha256_text()

func rule_for(merchant_id: int) -> Dictionary:
	if not validate_rules(rules).is_empty() or not rules.enabled:return {}
	for row: Dictionary in rules.merchants:
		if int(row.merchant_id)==merchant_id:return row
	return {}

func currency_for(merchant_id: int) -> int:
	var row: Dictionary=records.get(str(merchant_id),{})
	var ids: Dictionary={}
	for obj: Dictionary in row.get("object_links",[]):
		if not obj.get("object_defined",false) or not obj.get("currency_defined_and_unique",false) or obj.currency_ids.size()!=1:return 0
		if not Catalog._integer(obj.currency_ids[0]):return 0
		ids[int(obj.currency_ids[0])]=true
	return int(ids.keys()[0]) if ids.size()==1 else 0

## world (optional): a spawn limited to an original ServerLimitSet opens only
## when that set names the game's server profile (current523_server_profile:
## offline KR world 1), e.g. 기란 혈맹 상인 린 (merchant 91, set 762).
func context(merchant_id: int, goods_id: int, world: Variant = null) -> Dictionary:
	if not problem.is_empty():return {"ok":false,"reason":problem}
	if loaded_sha256.is_empty():return {"ok":false,"reason":"검증된 NPC 원본 팩이 필요합니다"}
	var rule: Dictionary=rule_for(merchant_id)
	if rule.is_empty() or not rules.remote_catalog:return {"ok":false,"reason":"NPC별 TWILIGHT 오프라인 규칙이 설정되지 않았습니다"}
	var row: Dictionary=records.get(str(merchant_id),{})
	if not row.get("goods_index",{}).has(str(goods_id)):return {"ok":false,"reason":"NPC 원본 상품 연결 불일치"}
	for obj: Dictionary in row.get("object_links",[]):
		if int(obj.earth_object_id)!=int(rule.earth_object_id):continue
		if not obj.get("object_defined",false) or obj.sell_action_row_ids.is_empty() or not _attributes_supported(obj.attributes,rule):return {"ok":false,"reason":"NPC 객체의 동작·별도 권한 조건 확인 필요"}
		for spawn: Dictionary in obj.spawns:
			if int(spawn.ID)!=int(rule.spawn_id):continue
			if spawn.SpawnManually:return {"ok":false,"reason":"NPC 수동·서버 스폰 조건 확인 필요"}
			var server_note: String=""
			if int(spawn.ServerLimitSetID)!=0:
				if world==null:return {"ok":false,"reason":"NPC 수동·서버 스폰 조건 확인 필요"}
				var allowed: Dictionary=preload("res://scripts/loot/current523_server_profile.gd").allows(world,spawn.ServerLimitSetID)
				if not allowed.get("ok",false):return {"ok":false,"reason":str(allowed.get("reason","NPC 서버 스폰 조건 미충족"))}
				server_note=" · 원본 서버 세트 %d (%s %d서버)" % [int(spawn.ServerLimitSetID),str(allowed.profile.ServiceRegionCode),int(allowed.profile.WorldNo)]
			var currency: int=currency_for(merchant_id)
			if currency<1:return {"ok":false,"reason":"NPC 원본 재화 연결이 유일하지 않습니다"}
			return {"ok":true,"currency_id":currency,"label":str(rule.label),"origin":"TWILIGHT 오프라인 가정 · 0시간/0날짜 상시 · 원격 목록 거래"+server_note+(" · "+str(rule.access_note) if rule.has("access_note") else ""),"minimum_level":int(rule.get("minimum_level",0)),"rules_sha256":rule_hash(merchant_id),"npc_pack_sha256":loaded_sha256}
	return {"ok":false,"reason":"설정된 NPC 객체·스폰을 원본에서 확인할 수 없습니다"}

func _attributes_supported(attributes: Array, rule: Dictionary) -> bool:
	for attribute: Dictionary in attributes:
		if not rule.get("allow_range_attribute",false) or int(attribute.get("id",0))!=15 or attribute.get("name")!="Range" or not Catalog._integer(attribute.get("value")) or int(attribute.value)<1 or int(attribute.value)>20:return false
	return true

