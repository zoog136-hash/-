extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Exact source ammunition and WeaponType.AmmoItemCategoryID. Spell-only
## projectiles stay raw definitions until their spell provider executes them.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
static var profiles: Dictionary = {}
static var weapon_rows: Dictionary = {}

static func weapon_type(record: Dictionary) -> Dictionary:
	if not record.get("source_m_native_item",false): return {}
	var definition: Dictionary = D.item_definition(record)
	if definition.is_empty(): return {}
	var id: String = str(int(record.source_item_class_id))
	if weapon_rows.has(id): return weapon_rows[id]
	var result: Dictionary = {}
	for row: Dictionary in definition.get("item_bonus",[]):
		if row.bonus_type.Name != "WeaponType" or not row.has("weapon_type"): continue
		if row.get("IsPossession") != false or int(row.bonus.BonusApplicationTypeID) != 0 or int(row.bonus.BonusApplicationTargetID) != 0: return {}
		if not result.is_empty() and result != row.weapon_type: return {}
		result = row.weapon_type
	weapon_rows[id] = result
	return result

static func profile(record: Dictionary) -> Dictionary:
	if not record.get("source_m_native_item",false) or NATIVE_FIELDS.field(record,"source_category_name") not in ["Arrow","Bullet","Sting"]: return {}
	record = NATIVE_FIELDS.full(record)
	var id: String = str(int(record.get("source_item_class_id",-1)))
	var definition: Dictionary = D.item_definition(record)
	if definition.is_empty(): return {}
	if profiles.has(id): return profiles[id]
	var result: Dictionary = {"category_id":int(record.source_category_id)}
	for row: Dictionary in definition.get("item_bonus",[]):
		var bonus: Dictionary = row.bonus
		if row.get("IsPossession") != false or int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0: return {}
		match str(row.bonus_type.Name):
			"WeaponSmallDamage": result["small_damage"] = int(bonus.Value)
			"WeaponLargeDamage": result["large_damage"] = int(bonus.Value)
			"AmmoEffectSpriteID", "AmmoExplosionSpriteID": result[str(row.bonus_type.Name)] = int(bonus.Value)
			_: return {}
	if int(result.get("small_damage",0)) <= 0 or int(result.get("large_damage",0)) <= 0: return {}
	profiles[id] = result
	return result

static func weapon_category(record: Dictionary) -> int:
	if not record.get("source_m_native_item",false): return -1
	var found: int = -1
	for row: Dictionary in D.item_definition(record).get("item_bonus",[]):
		if row.bonus_type.Name == "ShotWithoutArrow" and row.get("IsPossession") == false and int(row.bonus.BonusApplicationTypeID) == 0 and int(row.bonus.BonusApplicationTargetID) == 0 and int(row.bonus.Value) > 0: return 0
		if row.bonus_type.Name != "WeaponType" or not row.has("weapon_type"): continue
		if row.get("IsPossession") != false or int(row.bonus.BonusApplicationTypeID) != 0 or int(row.bonus.BonusApplicationTargetID) != 0: return -1
		var category: int = int(row.weapon_type.get("AmmoItemCategoryID",0))
		if found != -1 and found != category: return -1
		found = category
	return found

# The gameplay consumer receives exact current item identity, not visual enums.
static func current_profile(record: Dictionary) -> Dictionary:
	if D.equipment(record):return {} # Physical equipment is not also a quantity-ammunition grant.
	if record.get("source_projection")!="current523_original_typed_game_dto_v1" or D.current_original_definition(record).is_empty() or record.get("source_test_item")!=false or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var fields: Dictionary={"WeaponSmallDamage":"Value","WeaponLargeDamage":"Value","AmmoEffectSpriteID":"SpriteID","AmmoExplosionSpriteID":"SpriteID"}
	var seen: Dictionary={}
	for row: Dictionary in D.item_definition(record).get("item_bonus",[]):
		var kind: String=str(row.get("bonus_type",{}).get("Name",""))
		var value: Variant=row.get("bonus",{}).get("Value")
		if row.get("IsPossession")!=false or row.get("bonus",{}).get("BonusApplicationTypeID")!=0 or row.get("bonus",{}).get("BonusApplicationTargetID")!=0:return {}
		if not fields.has(kind) or seen.has(kind) or row.get("unit",{}).get("Name")!=fields[kind] or typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<0 or value>9007199254740991.0:return {}
		seen[kind]=int(value)
	var result: Dictionary=profile(record)
	var keys: Dictionary={"WeaponSmallDamage":"small_damage","WeaponLargeDamage":"large_damage","AmmoEffectSpriteID":"AmmoEffectSpriteID","AmmoExplosionSpriteID":"AmmoExplosionSpriteID"}
	for kind: String in seen:
		if result.get(keys[kind])!=seen[kind]:return {}
	return result

static func details(record: Dictionary) -> String:
	var data: Dictionary = profile(record)
	if data.is_empty(): return ""
	return "원본 탄약 · 작은 대상 %d / 큰 대상 %d\n탄약 수량은 발사마다 1개 소모 · 대미지 추첨은 TWILIGHT 설정(기본 1~원본 상한 균등 추정)\n원본 투사체 ID 보존 · 현재 게임의 기존 발사 연출 사용" % [int(data.small_damage),int(data.large_damage)]
