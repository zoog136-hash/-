extends RefCounted
## Register the supplied shared item definitions for crafting. No loot/use engine.
const ZIP_SHA="91de04c0f3ed613b76a69fea992347d82bdab79b6ef316049d3f77e90a3484d7"
const BIN_SHA="bec901d26a7766f2c77e9781ce636f17c14e7ba1b33617840eb5a5d5123bafd3"
const STORE="user://lineagem_patch523_drops/"+BIN_SHA+"/monster_drops.bin"
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
static var problem: String=""

static func read(path: String) -> Dictionary:
	problem=""
	if not FileAccess.file_exists(path): return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()!=1806317:
		problem="공통 아이템 자료 크기 불일치"; return {}
	var packed: PackedByteArray=file.get_buffer(file.get_length())
	file.close()
	if INSTALL.sha(packed)!=BIN_SHA:
		problem="공통 아이템 자료 SHA 불일치"; return {}
	var raw: PackedByteArray=packed.decompress_dynamic(32*1024*1024,FileAccess.COMPRESSION_GZIP)
	var document: Variant=JSON.parse_string(raw.get_string_from_utf8())
	if not document is Dictionary or int(document.get("schema",0))!=2 or document.get("kind")!="patch523_monster_drop_membership" or document.get("source_snapshot")!="patch523" or document.get("catalog_sha256")!=FileAccess.get_sha256("res://data/catalog_v19.json"):
		problem="현재 기반 카탈로그와 맞지 않는 공통 아이템 자료"; return {}
	if not document.get("item_definitions") is Dictionary or not document.get("native_item_ids") is Array or not document.get("native_reward_item_ids") is Array:
		problem="공통 아이템 정의 구조 오류"; return {}
	return document

static func available() -> Dictionary:
	var path: String=OS.get_environment("TWILIGHT_PATCH523_CRAFT_CATALOG_BIN")
	if path.is_empty():
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--patch523-drop-root="): path=arg.trim_prefix("--patch523-drop-root=").path_join("monster_drops.bin")
	if path.is_empty(): path=STORE
	return read(path)

static func register(catalog: Dictionary, document: Dictionary) -> Dictionary:
	if document.is_empty(): return {"ok":false,"reason":problem}
	var ids: Dictionary={}
	for key: Variant in document.get("native_item_ids",[])+document.get("native_reward_item_ids",[]): ids[str(key)]=true
	var records: Array=catalog.get("아이템",[]).duplicate()
	var current: Dictionary={}
	for item: Dictionary in records:
		var key: String=str(item.get("sourceId",""))
		if not key.is_empty(): current[key]=item
	var added: int=0
	var skipped_tests: int=0
	var registered_count: int=0
	for key: String in ids:
		var definition: Dictionary=document.item_definitions.get(key,{})
		var original: Dictionary=definition.get("original_item",{})
		var item: Dictionary=definition.get("native_record",{}).duplicate(true)
		if int(original.get("ID",0))!=int(key) or item.get("source")!="lineagem_patch523" or item.get("source_snapshot")!="patch523" or not item.get("source_m_native_item",false) or int(item.get("source_item_class_id",0))!=int(key) or item.get("sourceId")!="m523:item:"+key or item.get("name")!=str(item.get("source_display_name",""))+" · 원본#"+key:
			return {"ok":false,"reason":"공통 아이템 정체 불일치 · 기존 카탈로그 보존"}
		if original.get("TestItem",false) or item.get("source_test_item",false):
			skipped_tests+=1; continue
		item["source_bless_raw"]=1
		registered_count+=1
		if current.has(str(item.sourceId)):
			var previous: Dictionary=current[str(item.sourceId)]
			for field: String in ["name","source","source_snapshot","source_item_class_id","source_m_native_item","source_test_item","source_display_name","slot","source_is_stackable","source_class_ids","source_equip_slot_ids","source_level_limit_min","source_level_limit_max"]:
				if previous.get(field)!=item.get(field): return {"ok":false,"reason":"기존 공통 아이템 정체 충돌 · 교체하지 않았습니다"}
			continue
		records.append(item); current[str(item.sourceId)]=item; added+=1
	# Publish only after all identities have passed. Ownership/save data untouched.
	catalog["아이템"]=records
	return {"ok":true,"added":added,"registered_count":registered_count,"skipped_tests":skipped_tests,"source_bin_sha256":BIN_SHA}

static func install_zip(path: String) -> Dictionary:
	problem=""
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=ZIP_SHA:
		problem="제공된 공통 아이템 ZIP의 SHA가 아닙니다"; return {}
	var checked: Dictionary=INSTALL.validate_zip(path)
	if not checked.get("ok",false) or checked.get("entries",{}).size()!=2 or int(checked.entries.get("payload/monster_drops.bin",0))!=1806317:
		problem="공통 아이템 ZIP 구조 오류"; return {}
	var archive:=ZIPReader.new()
	if archive.open(path)!=OK:
		problem="공통 아이템 ZIP 읽기 실패"; return {}
	var header: Variant=JSON.parse_string(archive.read_file("pack.json").get_string_from_utf8())
	var packed: PackedByteArray=archive.read_file("payload/monster_drops.bin")
	archive.close()
	if not header is Dictionary or header.get("sha256")!=BIN_SHA or header.get("source_snapshot")!="patch523" or header.get("kind")!="patch523_monster_drop_membership" or INSTALL.sha(packed)!=BIN_SHA:
		problem="공통 아이템 ZIP 내용 불일치"; return {}
	var target: String=ProjectSettings.globalize_path(STORE)
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:
		problem="공통 아이템 보관 폴더 생성 실패"; return {}
	if FileAccess.file_exists(STORE):
		if FileAccess.get_sha256(STORE)!=BIN_SHA:
			problem="기존 공통 아이템 자료 손상 · 원본 보존"; return {}
	else:
		var temporary: String=target+".part-"+str(Time.get_ticks_usec())
		var file:=FileAccess.open(temporary,FileAccess.WRITE)
		if file==null:
			problem="공통 아이템 자료 기록 실패"; return {}
		file.store_buffer(packed); file.flush()
		var error: Error=file.get_error(); file.close()
		if error!=OK or FileAccess.get_sha256(temporary)!=BIN_SHA or DirAccess.rename_absolute(temporary,target)!=OK:
			problem="공통 아이템 자료 보관 실패 · 기존 설치 보존"; return {}
	var document: Dictionary=read(STORE)
	return {"path":STORE,"document":document} if not document.is_empty() else {}
