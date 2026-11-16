extends RefCounted
## 보유 칭호 (ItemBonus `ItemPossessionAppellationID`) — TWILIGHT 근사, 지시 2026-11-16.
## The original row names an Appellation (호칭); its RewardID is a BuffClass
## (the same join protection523_source reads). The table has no rule for how
## several held titles combine, so (근거 약함, conservative) only ONE title is
## active: the held one with the highest Appellation.Priority (then the highest ID).
## Its BuffBonus rows that have an existing receiver go through
## world._active_item_buff_total; the rest are listed in `unmapped`.
## PvP rows follow the user decision 2026-11-16 13:46 (PvP numbers as vs-monster numbers).
## docs/items523_remaining_missing_rules.md 18.2.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const ENABLED := true
## BonusType -> [buff key, divisor] (Percentage is 1/10000 of a percent).
const RECEIVERS := {
	"ExperienceAdditionPercent":["xp",10000], "PVEDamageReduction":["pve_damage_reduction",1], "PVPDamageReduction":["pve_damage_reduction",1],
	"PVEDamageReductionPercent":["pve_damage_reduction_pct",10000], "DamageReductionPercent":["pve_damage_reduction_pct",10000],
	"DamageReduction":["damage_reduction",1], "MeleeHit":["melee_accuracy",1], "RangeHit":["ranged_accuracy",1], "MagicHit":["magic_accuracy",1],
	"ArmorClass":["def",1], "MagicResist":["mr",1], "AttackSpeedBonus":["attack_speed",10000], "MoveSpeedBonus":["move_speed",10000]}

var world: Node = null
var _checked_ms: int = -100000
var _active: Dictionary = {}
var _cache: Dictionary = {}

func configure(owner: Node) -> void:
	world = owner

static func appellation_of(record: Dictionary) -> int:
	if record.get("source_m_native_item") != true: return 0
	for row: Dictionary in D.item_definition(record).get("item_bonus", []):
		if str(row.get("bonus_type",{}).get("Name","")) != "ItemPossessionAppellationID": continue
		var bonus: Dictionary = row.get("bonus",{})
		if int(bonus.get("BonusApplicationTypeID",0)) == 0 and typeof(bonus.get("Value")) in [TYPE_INT,TYPE_FLOAT] and int(bonus.Value) > 0: return int(bonus.Value)
	return 0

## {id, name, buff_id, values{key:int}, unmapped[]} for one Appellation.
func title(id: int) -> Dictionary:
	if _cache.has(id): return _cache[id]
	var row: Dictionary = SOURCE.row("Appellation", id)
	var out: Dictionary = {}
	if not row.is_empty() and row.get("IsTest") != true:
		var name_value: String = str(row.get("Name",""))
		var title_row: Dictionary = SOURCE.row("AppellationTitle", int(row.get("TitleID",0)))
		if not title_row.is_empty(): name_value = str(SOURCE.row("DescData_Korean", int(title_row.get("DescID",0))).get("Description", name_value))
		out = {"id":id, "name":name_value, "priority":int(row.get("Priority",0)), "buff_id":int(row.get("RewardID",0)), "values":{}, "unmapped":[]}
		for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",int(row.get("RewardID",0))):
			var bonus: Dictionary = SOURCE.row("Bonus", int(link.get("BonusID",0)))
			var kind: String = str(SOURCE.row("BonusType", int(bonus.get("BonusTypeID",0))).get("Name",""))
			if not RECEIVERS.has(kind) or int(bonus.get("BonusApplicationTypeID",0)) != 0: out.unmapped.append(kind); continue
			var key: String = str(RECEIVERS[kind][0])
			out.values[key] = int(out.values.get(key,0)) + int(float(bonus.get("Value",0)) / float(RECEIVERS[kind][1]))
	_cache[id] = out
	return out

## The one active held title (refreshed at most once a second).
func active() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if now - _checked_ms < 1000: return _active
	_checked_ms = now
	_active = {}
	if not ENABLED or world == null: return _active
	for value: Variant in world.item_instances.values():
		if not value is Dictionary or not (value as Dictionary).get("record") is Dictionary: continue
		var id: int = appellation_of(value.record)
		if id <= 0 or int(world.inventory.get(str(value.get("name","")),0)) <= 0: continue
		var candidate: Dictionary = title(id)
		if candidate.is_empty(): continue
		if _active.is_empty() or int(candidate.priority) > int(_active.priority) or (int(candidate.priority) == int(_active.priority) and id > int(_active.id)): _active = candidate
	return _active

func buff_value(key: String) -> int:
	return int(active().get("values",{}).get(key,0))

func display_name() -> String:
	return str(active().get("name",""))
