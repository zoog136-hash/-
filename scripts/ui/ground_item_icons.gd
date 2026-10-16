extends RefCounted
## Presentation categories only. Never change the target's name, sourceId or grade.
const MANIFEST: String = "res://data/ground_item_icons.json"
const WEAPONS: Dictionary = {"한손검":"sword","양손검":"greatsword","그레이트소드":"greatsword","단검":"dagger","활":"bow","창":"spear","도끼":"axe","사이드":"scythe","이도류":"dual","크로우":"claw","지팡이":"staff","라이플":"rifle","핸드캐넌":"cannon","체인소드":"chain","마검":"runesword","룬소드":"runesword","건틀렛":"gauntlet"}
const SLOTS: Dictionary = {"helmet":"helmet","body":"armor","tshirt":"tshirt","cloak":"cloak","gloves":"gloves","boots":"boots","pants":"pants","gaiters":"pants","offhand":"shield","shoulder":"shoulder","necklace":"necklace","belt":"belt","bracelet":"bracelet","badge":"badge","crystal":"crystal","catalyst":"catalyst","rune":"rune"}
const TYPES: Dictionary = {"투구":"helmet","갑옷":"armor","티셔츠":"tshirt","망토":"cloak","각반":"pants","장갑":"gloves","신발":"boots","방패":"shield","방패/가더":"shield","가더":"shield","견갑":"shoulder","목걸이":"necklace","반지":"ring","귀걸이":"earring","팔찌":"bracelet","벨트":"belt","휘장":"badge","인장":"seal","수정":"crystal","카탈리스트":"catalyst","룬":"rune"}
static var _loaded: bool = false
static var _entries: Dictionary = {}

static func category(record: Dictionary, item_name: String) -> String:
	var kind: String = str(record.get("type", "")).replace(" ", "")
	var slot: String = str(record.get("slot", "")).to_lower()
	# Equipment identity wins over words such as 미스릴/가죽/마력/드래곤.
	if slot in ["weapon", "mainhand"]: return str(WEAPONS.get(kind, "sword"))
	if SLOTS.has(slot): return str(SLOTS[slot])
	if slot.begins_with("ring"): return "ring"
	if slot.begins_with("earring"): return "earring"
	if slot.begins_with("seal"): return "seal"
	if WEAPONS.has(kind): return str(WEAPONS[kind])
	if TYPES.has(kind): return str(TYPES[kind])
	if item_name == "아데나" or slot == "currency" or kind == "화폐": return "coins"
	if kind == "상자" or item_name.ends_with("상자") or item_name.ends_with("주머니"): return "box"
	if "비법서" in item_name or "제작서" in item_name: return "recipe"
	if bool(record.get("crafting_scroll", false)) or "주문서" in kind or "주문서" in item_name or "두루마리" in item_name: return "scroll"
	if "화살" in item_name: return "arrow"
	if "탄환" in item_name or "총알" in item_name: return "bullet"
	if "요리" in kind or "음식" in kind or "스테이크" in item_name or "연어" in item_name or "칠면조" in item_name: return "food"
	if "마나" in item_name or "MP" in item_name or "마력 회복" in item_name: return "potion_mp"
	if "회복" in item_name or "HP" in item_name: return "potion_hp"
	if "엘릭서" in item_name: return "elixir"
	if "드래곤" in item_name and ("성수" not in item_name): return "dragon_gem"
	if "물약" in item_name or "성수" in item_name: return "potion_buff"
	if "재료" in kind or slot == "material" or bool(record.get("crafting_material", false)):
		if "가죽" in item_name: return "leather"
		if "천" in item_name and ("조각" in item_name or item_name == "천"): return "cloth"
		if "가루" in item_name or "잿가루" in item_name: return "powder"
		if "광석" in item_name or "철" in item_name or "미스릴" in item_name or "연마석" in item_name or "정제석" in item_name: return "ore"
		if "결정" in item_name or "보석" in item_name or "루비" in item_name or "사파이어" in item_name or kind in ["지배석", "마안", "성배"]: return "gem"
		return "material"
	if "축복" in kind or "보석" in kind: return "gem"
	if slot == "consumable": return "potion_buff"
	return "misc"

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (parsed is Dictionary) or int(parsed.get("schema", 0)) != 1 or parsed.get("scope", "") != "ground_only": return
	for key: Variant in parsed.get("categories", {}):
		var entry: Variant = parsed.categories[key]
		if not (entry is Dictionary): continue
		var path: String = str(entry.get("path", ""))
		if not path.begins_with("res://assets/ground_categories/") or ".." in path or "\\" in path or not path.ends_with(".png"): continue
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path): continue
		_entries[str(key)] = entry

static func lookup(record: Dictionary, item_name: String) -> Dictionary:
	_ensure()
	if record.is_empty() or item_name.is_empty(): return {}
	var key: String = category(record, item_name)
	var entry: Dictionary = _entries.get(key, {})
	if entry.is_empty(): return {}
	var result: Dictionary = entry.duplicate(true)
	result["category"] = key
	return result
