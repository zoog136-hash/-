extends RefCounted
## A bounded projection of the verified 523 input. It is not a general
## equipment pack and can never authorize alchemy, invoke or legacy custody.
const Common=preload("res://scripts/equipment523/common.gd")
const SCHEMA="twilight-native-smelt-rules-v1"
const SHA="c2509aafb6eaade682ff5d82ba38c2e7e37fc44a529bef4b27b194a95cd2e61f"
const BYTES:=129620
const ADDON_SHA="62286e8bde4f4b780f23bb1507cdafa1b24d3ebe77869af88ac26224e6a5e48b"
const ADDON_BYTES:=130772
const SECTION="equipment_smelt"
const MEMBER="smelt.json"
const ENV="TWILIGHT_NATIVE_SMELT_SIDECAR"
const EXPECTED_COUNTS={"ItemSmelt":12,"ItemSmeltEntity":65,"ItemSpiritSmeltEntity":16,"ItemSmeltSlotActive":24,"ItemSmeltBonus":311}

static func selection_valid(entry:Dictionary)->bool:
	return entry.get("root")==SECTION and entry.get("manifest")==SECTION+"/"+MEMBER and entry.get("manifest_sha256")==SHA

static func read(path:String)->Dictionary:
	if path.is_empty():return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()!=BYTES:return {}
	var bytes:PackedByteArray=file.get_buffer(BYTES)
	file.close()
	if not verifies(bytes):return {}
	var parsed:Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("schema")!=SCHEMA or parsed.get("source_sha256")!=Common.SOURCE_SHA:return {}
	if not parsed.get("tables") is Dictionary or not parsed.get("items") is Dictionary or not parsed.get("bonuses") is Dictionary:return {}
	for table:String in EXPECTED_COUNTS:
		if Common.rows(parsed,table).size()!=EXPECTED_COUNTS[table]:return {}
	if parsed.items.size()!=80:return {}
	return parsed

static func verifies(bytes:PackedByteArray)->bool:
	if bytes.size()!=BYTES:return false
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256);digest.update(bytes)
	return digest.finish().hex_encode()==SHA

## Background job: local byte/hash/JSON only, no scene, cache or save access.
static func prepare(path:String)->Dictionary:
	var start:int=Time.get_ticks_usec()
	var rules:Dictionary=read(path)
	return {"rules":rules,"usec":Time.get_ticks_usec()-start}
