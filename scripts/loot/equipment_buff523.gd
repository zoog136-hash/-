extends RefCounted
## 장비 상시 버프 (ItemBonus `BuffClassID` on wearable items, 104종) — TWILIGHT 근사, 지시 2026-11-16.
## docs/items523_remaining_missing_rules.md 10.1. While an item is worn its BuffClass rows
## that have an existing receiver are added through world._active_item_buff_total.
## Not applied (listed): the fishing-rod 폴 forms (fishing is a cut feature), the
## polymorph appearance itself (PolymorphSetID — the card register owns appearance),
## and flag rows without a receiver (대상 고정·발동 억제 무시·투명·공격 불가 등).
## A worn polymorph buff (one with PolymorphSetID) is a polymorph: in Lineage M a form
## replaces the other, so its speed rows (공격·이동·시전 속도) apply only while no
## polymorph card is worn (근거 약함, conservative: never stacks two forms).
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ENABLED := true
## BonusType -> [buff key, divisor] (Percentage = 1/10000 %).
const RECEIVERS := {
	"MeleeDamage":["melee_damage",1], "RangeDamage":["ranged_damage",1], "DamageReduction":["damage_reduction",1],
	"PVEDamageReduction":["pve_damage_reduction",1], "PVPDamageReduction":["pve_damage_reduction",1], "MagicResist":["mr",1],
	"MeleeHit":["melee_accuracy",1], "RangeHit":["ranged_accuracy",1], "MagicHit":["magic_accuracy",1], "SpellPower":["sp",1],
	"AttackSpeedBonus":["attack_speed",10000], "MoveSpeedBonus":["move_speed",10000]}
const SPEED_KEYS := ["attack_speed","move_speed"]
const EXCLUDED_SLOTS := ["fishing_rod"]

var world: Node = null
var _cache: Dictionary = {}
var _checked_ms: int = -100000
var _values: Dictionary = {}

func configure(owner: Node) -> void:
	world = owner

## {buff_id, polymorph, values{key:int}, unmapped[]} for one worn original record ({} = none).
func buff_of(record: Dictionary) -> Dictionary:
	var id: int = int(record.get("source_item_class_id",0))
	if id <= 0 or record.get("source_m_native_item") != true: return {}
	if _cache.has(id): return _cache[id]
	var out: Dictionary = {}
	if str(record.get("slot","")) not in EXCLUDED_SLOTS:
		for row: Dictionary in D.item_definition(record).get("item_bonus",[]):
			if str(row.get("bonus_type",{}).get("Name","")) != "BuffClassID" or row.get("IsPossession") == true: continue
			var bonus: Dictionary = row.get("bonus",{})
			if int(bonus.get("BonusApplicationTypeID",0)) != 0: continue
			var buff_id: int = int(bonus.get("Value",0))
			out = {"buff_id":buff_id,"polymorph":false,"values":{},"unmapped":[]}
			for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",buff_id):
				var source: Dictionary = SOURCE.row("Bonus", int(link.get("BonusID",0)))
				var kind: String = str(SOURCE.row("BonusType", int(source.get("BonusTypeID",0))).get("Name",""))
				if kind == "PolymorphSetID": out.polymorph = true; continue
				if not RECEIVERS.has(kind) or int(source.get("BonusApplicationTypeID",0)) != 0 or int(link.get("CharacterLevel",0)) != 0:
					if kind not in out.unmapped: out.unmapped.append(kind)
					continue
				var key: String = str(RECEIVERS[kind][0])
				out.values[key] = int(out.values.get(key,0)) + int(float(source.get("Value",0)) / float(RECEIVERS[kind][1]))
	_cache[id] = out
	return out

func _refresh() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _checked_ms < 500: return
	_checked_ms = now
	_values = {}
	if not ENABLED or world == null: return
	var card: Variant = world.equipped_catalog.get("변신", {}) if world.get("equipped_catalog") is Dictionary else {}
	var card_form: bool = card is Dictionary and not (card as Dictionary).is_empty()
	var seen: Dictionary = {}
	for slot: Variant in world.equipped_items:
		var worn: Variant = world.equipped_items[slot]
		if not worn is Dictionary: continue
		var uid: String = str((worn as Dictionary).get("instance_id",""))
		if uid.is_empty() or seen.has(uid): continue
		seen[uid] = true
		var physical: Variant = world.item_instances.get(uid, {})
		if not physical is Dictionary or not (physical as Dictionary).get("record") is Dictionary: continue
		var buff: Dictionary = buff_of(physical.record)
		if buff.is_empty(): continue
		for key: String in buff.values:
			if bool(buff.polymorph) and card_form and key in SPEED_KEYS: continue
			_values[key] = int(_values.get(key,0)) + int(buff.values[key])

func invalidate() -> void:
	_checked_ms = -100000

func buff_value(key: String) -> int:
	_refresh()
	return int(_values.get(key,0))
