extends RefCounted
## 523 membership selects candidates; loot_drop.gd owns all chances and counts.
const KIND = "patch523_monster_drop_membership"
const DATA_SHA = "4455cbbd2e6dc5392ccb2f142d99124ad2b5966e2dbca6d5fd3bb1f7b0cde0a3"
const FILE_NAME = "monster_drops.bin"
const RESOURCE_PATH = "res://data/lineagem_patch523/monster_drops.bin"
const STORE = "user://lineagem_patch523_drops"
const MAX_PACKED = 8 * 1024 * 1024
const MAX_RAW = 32 * 1024 * 1024
static var _data: Dictionary = {}
static var _checked: bool = false
static var _sources: Dictionary = {}
static var diagnostics: Dictionary = {}

static func installed_path() -> String:
	return STORE.path_join(DATA_SHA).path_join(FILE_NAME)

static func decode(packed: PackedByteArray) -> Dictionary:
	if packed.size() > MAX_PACKED or packed.is_empty(): return {}
	if preload("res://scripts/lineagem_pack_install.gd").sha(packed) != DATA_SHA: return {}
	var raw: PackedByteArray = packed.decompress_dynamic(MAX_RAW, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty(): return {}
	var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not value is Dictionary or value.get("schema") != 1 or value.get("kind") != KIND or value.get("source_snapshot") != "patch523": return {}
	return value

static func data() -> Dictionary:
	if _checked: return _data
	_checked = true
	var paths: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-drop-root="): paths.append(arg.trim_prefix("--patch523-drop-root=").path_join(FILE_NAME))
	paths.append(RESOURCE_PATH)
	paths.append(installed_path())
	for path: String in paths:
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_PACKED: continue
		_data = decode(file.get_buffer(file.get_length()))
		if not _data.is_empty(): return _data
	return {}

static func identity(record: Dictionary) -> Dictionary:
	var original: Dictionary = record.get("source_m_original", {})
	var id: int = int(record.get("source_m_npc_id", -1))
	if record.get("source_m_snapshot", "") not in ["base508", "patch523"] or id <= 0 or int(original.get("ID", -2)) != id: return {}
	return {"kind":KIND, "source_npc_id":id, "source_sprite_id":int(original.get("Sprite", -1)), "source_name":str(original.get("Name", ""))}

static func native(value: Dictionary) -> bool:
	return value.get("kind") == KIND and int(value.get("source_npc_id", -1)) > 0

static func equipment(item: Dictionary) -> bool:
	if item.get("crafting_scroll", false): return bool(item.get("drop_as_equipment", false)) and item.get("slot", "") == "consumable"
	return str(item.get("slot", "")) not in ["", "currency", "consumable"]

static func item_kind(item: Dictionary) -> String:
	if equipment(item): return "equipment"
	if item.get("slot", "") == "currency": return "unsupported_currency"
	if item.get("slot", "") == "consumable" and int(item.get("heal", 0)) > 0: return "potion"
	return "material"

static func matches(item: Dictionary, link: Dictionary) -> bool:
	if item.is_empty() or link.is_empty(): return false
	for key: String in ["name", "source", "sourceId", "sourceUrl", "slot", "type", "grade"]:
		if str(item.get(key, "")) != str(link.get(key, "")): return false
	return true

static func catalog_index(items: Array) -> Dictionary:
	# Main's legacy loot pool is smaller than its item encyclopedia. Keep this
	# exact-source lookup separate so registering source gear never widens a
	# legacy monster's configured candidate pool.
	var index: Dictionary = {}
	var ambiguous: Dictionary = {}
	for item: Dictionary in items:
		var name_value: String = str(item.get("name", ""))
		if index.has(name_value): ambiguous[name_value] = true
		index[name_value] = item
	for name_value: String in ambiguous: index.erase(name_value)
	return index

static func resolve(document: Dictionary, value: Dictionary, catalog: Dictionary) -> Dictionary:
	var id: String = str(int(value.get("source_npc_id", -1)))
	var npc: Dictionary = document.get("npcs", {}).get(id, {})
	var report: Dictionary = {"npc_id":id, "missing_item_bindings":0, "quest_rows_blocked":0, "unsupported_bless_rows":0, "unsupported_currency_rows":0, "duplicate_rows_ignored":0}
	diagnostics = report
	if not native(value) or npc.is_empty() or int(npc.get("sprite_id", -1)) != int(value.get("source_sprite_id", -2)) or npc.get("source_name") != value.get("source_name"): return {}
	if not npc.get("attackable", false) or npc.get("test_npc", true): return {}
	var groups: Dictionary = {}
	for row: Dictionary in document.get("drops", {}).get(id, []):
		# Quests were excluded by the user. Preserve their rows in the pack/UI,
		# but never turn a quest requirement into an unconditional drop.
		if int(row.RequiredQuestID) != 0: report.quest_rows_blocked += 1; continue
		var item_id: String = str(int(row.ItemClassID))
		var link: Dictionary = document.get("bindings", {}).get(item_id, {})
		var item: Dictionary = catalog.get("patch523_by_name", catalog.get("by_name", {})).get(str(link.get("name", "")), {})
		if not matches(item, link): report.missing_item_bindings += 1; continue
		var bless: int = int(row.Bless)
		# Stack ownership has no distinct bless variant. Do not flatten it.
		if bless not in [1, 2, 3] or (bless != 1 and (not equipment(item) or item.get("slot") == "consumable")):
			report.unsupported_bless_rows += 1; continue
		var kind: String = item_kind(item)
		if kind == "unsupported_currency": report.unsupported_currency_rows += 1; continue
		if not groups.has(item_id): groups[item_id] = {"item_class_id":int(item_id), "item":item, "kind":kind, "variants":{}}
		var key: String = "%d:%d" % [bless, int(row.RequiredQuestID)]
		var variants: Dictionary = groups[item_id].variants
		if variants.has(key):
			variants[key].source_rows.append(row.duplicate(true))
			report.duplicate_rows_ignored += 1
			continue
		variants[key] = {"source_snapshot":"patch523", "source_npc_id":int(id), "source_item_class_id":int(item_id), "bless_raw":bless, "bless_state":str(document.bless_codes[str(bless)]), "required_quest_id":int(row.RequiredQuestID), "source_rows":[row.duplicate(true)], "selection_policy":"host_uniform_distinct_items_then_distinct_variants", "quantity_policy":"host_one"}
	return groups

static func candidates(value: Dictionary, catalog: Dictionary) -> Dictionary:
	var document: Dictionary = data()
	if document.is_empty():
		diagnostics = {"status":"patch523_drop_pack_missing_or_invalid"}
		return {}
	return resolve(document, value, catalog)

static func pick(groups: Dictionary, kind: String, grade: String, rng: RandomNumberGenerator) -> Dictionary:
	var choices: Array = []
	for group: Dictionary in groups.values():
		if group.kind != kind: continue
		# This equality retains the host rarity roll. It is not a separate cap.
		if kind == "equipment" and str(group.item.get("grade", "일반")) != grade: continue
		choices.append(group)
	if choices.is_empty(): return {}
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.item_class_id) < int(b.item_class_id))
	var selected: Dictionary = choices[rng.randi_range(0, choices.size()-1)]
	var keys: Array = selected.variants.keys()
	keys.sort()
	var proof: Dictionary = selected.variants[keys[rng.randi_range(0, keys.size()-1)]].duplicate(true)
	var item: Dictionary = selected.item.duplicate(true)
	item["source_m_item_id"] = selected.item_class_id
	item["bless_state"] = proof.bless_state
	item["source_m_drop_proof"] = proof
	return {"item_name":str(item.name), "quantity":1, "item_record":item, "source_m_drop_proof":proof}

static func ground_metadata(entry: Dictionary) -> Dictionary:
	if not entry.has("source_m_drop_proof") or not entry.get("item_record") is Dictionary: return {}
	var item: Dictionary = entry.item_record.duplicate(true)
	var result: Dictionary = {"item_record":item}
	if equipment(item) and item.get("slot") != "consumable":
		result["physical_item"] = {"id":Crypto.new().generate_random_bytes(16).hex_encode(), "data":{"name":str(entry.item_name), "level":0, "element":"", "element_level":0, "record":item, "bless_state":item.bless_state, "source_m_drop_proof":entry.source_m_drop_proof.duplicate(true)}}
	return result

static func source_rows(item: Dictionary) -> Array:
	var document: Dictionary = data()
	var item_id: String = str(item.get("sourceId", ""))
	if document.is_empty() or not matches(item, document.get("bindings", {}).get(item_id, {})): return []
	if _sources.is_empty():
		for id: String in document.get("drops", {}):
			var npc: Dictionary = document.npcs[id]
			if not npc.show_drop_info or npc.test_npc: continue
			var seen: Dictionary = {}
			for row: Dictionary in document.drops[id]:
				var key: String = "%d:%d:%d" % [int(row.ItemClassID), int(row.Bless), int(row.RequiredQuestID)]
				if seen.has(key): continue
				seen[key] = true
				var source_item: String = str(int(row.ItemClassID))
				if not _sources.has(source_item): _sources[source_item] = []
				_sources[source_item].append({"npc_id":int(id), "name":str(npc.display_name), "source_name":str(npc.source_name), "bless":int(row.Bless), "quest":int(row.RequiredQuestID)})
	return _sources.get(item_id, [])

static func source_text(item: Dictionary) -> String:
	if data().is_empty(): return "523 드랍 자료 미설치 · 설정에서 드랍 자료 ZIP을 설치하세요."
	var rows: Array = source_rows(item)
	if rows.is_empty(): return "523 드랍원: 현재 아이템 ID와 검증된 연결 없음"
	var lines: PackedStringArray = ["523 원본 드랍원 · 실제 출현·획득 보장 아님", "확률·수량: TWILIGHT 규칙 · 일반 몬스터 전설 이상 가중치 0 유지"]
	for row: Dictionary in rows.slice(0, 24):
		var state: String = {1:"일반", 2:"축복", 3:"저주"}.get(int(row.bless), "미지원 상태 %d" % int(row.bless))
		var quest: String = " · 퀘스트 %d 필요(드랍 제외)" % int(row.quest) if int(row.quest) != 0 else ""
		lines.append("%s (#%d) · %s%s" % [str(row.name), int(row.npc_id), state, quest])
	if rows.size() > 24: lines.append("외 %d개 원본 조건" % (rows.size()-24))
	return "\n".join(lines)

static func install_zip(path: String) -> Dictionary:
	var validation: Dictionary = preload("res://scripts/lineagem_pack_install.gd").validate_zip(path)
	if not validation.get("ok", false) or validation.entries.size() != 2 or not validation.entries.has("payload/monster_drops.bin") or int(validation.entries["payload/monster_drops.bin"]) > MAX_PACKED:
		return {"ok":false, "error":"지원되는 드랍 자료 ZIP이 아닙니다."}
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return {"ok":false, "error":"드랍 ZIP을 열 수 없습니다."}
	var header: Variant = JSON.parse_string(zip.read_file("pack.json").get_string_from_utf8())
	var packed: PackedByteArray = zip.read_file("payload/monster_drops.bin")
	zip.close()
	if not header is Dictionary or header.get("kind") != KIND or header.get("sha256") != DATA_SHA or int(header.get("bytes", -1)) != packed.size() or decode(packed).is_empty():
		return {"ok":false, "error":"드랍 자료 버전 또는 무결성 검사 실패 · 기존 자료 유지"}
	var target: String = installed_path()
	if FileAccess.file_exists(target):
		if FileAccess.get_sha256(target) != DATA_SHA: return {"ok":false, "error":"기존 드랍 자료 손상 · 파일을 보존했습니다."}
	else:
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return {"ok":false, "error":"드랍 자료 폴더를 만들 수 없습니다."}
		var pending: String = target + ".pending"
		var file := FileAccess.open(pending, FileAccess.WRITE)
		if file == null: return {"ok":false, "error":"드랍 자료를 기록할 수 없습니다."}
		file.store_buffer(packed)
		file.close()
		if FileAccess.get_sha256(pending) != DATA_SHA or DirAccess.rename_absolute(pending, target) != OK: return {"ok":false, "error":"드랍 자료 설치 실패 · 기존 자료 유지"}
	_checked = false
	_data = {}
	_sources = {}
	return {"ok":true, "path":target, "sha256":DATA_SHA}
