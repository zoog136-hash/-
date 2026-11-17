extends RefCounted
## User policy "원본에 없으면 검색 후 근사" for the floor body of an original
## 523 item whose own ItemClass.SpriteID has no floor picture (SpriteID 0,
## absent from the 523 client, or a source dummy): the ORIGINAL ground sprite
## used most often by other non-test items of the same original category —
## first the same ItemClass.CategoryID and the same "[분류-세부]" name kind
## (e.g. "[악세-귀걸이]"), else the same CategoryID. Only sprites that have a
## client static picture in the pinned bank count. Nothing is drawn here and
## nothing is chosen when the category has no original floor sprite.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
static var _key: String = ""
static var _by_kind: Dictionary = {}
static var _by_category: Dictionary = {}

## "[BM][악세-귀걸이] 룸티스..." -> "악세-귀걸이"; "" when the name has no kind tag.
static func name_kind(name: String) -> String:
	var at: int = 0
	while at < name.length() and name[at] == "[":
		var end: int = name.find("]", at)
		if end < 0: return ""
		var tag: String = name.substr(at + 1, end - at - 1)
		if "-" in tag: return tag
		at = end + 1
	return ""

static func _best(counts: Dictionary) -> int:
	var best: int = 0
	var best_count: int = 0
	for sprite: int in counts:
		var count: int = int(counts[sprite])
		if count > best_count or (count == best_count and sprite < best):
			best = sprite
			best_count = count
	return best

## `has_static` is Callable(sprite_id:int)->bool over the pinned bank.
static func _build(key: String, has_static: Callable) -> bool:
	if _key == key: return true
	var ids: Variant = DEF.column("ItemClass", "ID")
	var names: Variant = DEF.column("ItemClass", "Name")
	var sprites: Variant = DEF.column("ItemClass", "SpriteID")
	var categories: Variant = DEF.column("ItemClass", "CategoryID")
	var tests: Variant = DEF.column("ItemClass", "TestItem")
	var count: int = ids.size() if ids is Array or ids is PackedFloat64Array or ids is PackedInt64Array else 0
	if count == 0 or names.size() != count or sprites.size() != count or categories.size() != count or tests.size() != count: return false
	var kinds: Dictionary = {}
	var cats: Dictionary = {}
	var static_memo: Dictionary = {}
	for index: int in count:
		if tests[index] != false: continue
		var sprite: int = int(sprites[index])
		if sprite <= 0: continue
		if not static_memo.has(sprite): static_memo[sprite] = bool(has_static.call(sprite))
		if not static_memo[sprite]: continue
		var category: int = int(categories[index])
		var kind: String = name_kind(str(names[index]))
		if not cats.has(category): cats[category] = {}
		cats[category][sprite] = int(cats[category].get(sprite, 0)) + 1
		if kind.is_empty(): continue
		var kind_key: String = "%d|%s" % [category, kind]
		if not kinds.has(kind_key): kinds[kind_key] = {}
		kinds[kind_key][sprite] = int(kinds[kind_key].get(sprite, 0)) + 1
	_by_kind.clear()
	_by_category.clear()
	for kind_key: String in kinds: _by_kind[kind_key] = _best(kinds[kind_key])
	for category: int in cats: _by_category[category] = _best(cats[category])
	_key = key
	return true

## {ok, sprite_id, basis} or {ok:false, reason}.
static func select(original_item: Dictionary, bank_key: String, has_static: Callable) -> Dictionary:
	if not _build(bank_key, has_static): return {"ok":false,"reason":"current523_item_class_columns_unavailable"}
	var category: int = int(original_item.get("CategoryID", -1))
	var kind: String = name_kind(str(original_item.get("Name", "")))
	if not kind.is_empty() and _by_kind.has("%d|%s" % [category, kind]):
		return {"ok":true,"sprite_id":int(_by_kind["%d|%s" % [category, kind]]),"basis":"approx_same_category_and_name_kind","category_id":category,"name_kind":kind}
	if _by_category.has(category):
		return {"ok":true,"sprite_id":int(_by_category[category]),"basis":"approx_same_category","category_id":category}
	return {"ok":false,"reason":"current523_ground_category_has_no_original_sprite","category_id":category}

static func reset() -> void:
	_key = ""
	_by_kind.clear()
	_by_category.clear()
