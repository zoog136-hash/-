extends RefCounted
## 지배 부적 소지 효과 (TWILIGHT 근사, 사용자 지시 2026-11-16).
## Original rows on a 지배 부적: IgnoreNoTeleport (IsPossession, BonusApplicationType
## 11 = Land, target = that floor's Land) and PossessItemSpellClassID 107943
## "지배자의 응시". The item's own original description (DescData, e.g. #122424)
## states the rest: "N층 지배 부적 소지 시 오만의 탑 N층에서 텔레포트 가능 · 오만의 탑
## 지배 부적 효과 적용 — 근거리/원거리 대미지 +3, 근거리/원거리 명중 +3, 마법 명중 +3,
## SP +3, 경험치 획득량 증가 +20%, 지배석 상자 드랍 확률 증가 +25%, 스킬: 지배자의 응시".
## Applied while the player stands in a Land one of the carried 지배 부적 names:
##  - teleport (순간이동) is allowed there despite NoTeleport;
##  - the listed numbers go through the existing item-buff sums (_active_item_buff_total).
## Not applied: the 지배석 상자 drop rate (no per-box drop multiplier consumer) and
## the 지배자의 응시 object finder (no finder consumer).
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const ENABLED := true
## Keys of world._active_item_buff_total from the item description.
const BONUS := {"melee_damage":3, "ranged_damage":3, "melee_accuracy":3, "ranged_accuracy":3, "magic_accuracy":3, "sp":3, "xp":20}

var world: Node = null
var _lands: Dictionary = {}
var _checked_ms: int = -100000
var _land_ms: int = -100000
var _land: int = -1

func configure(owner: Node) -> void:
	world = owner

## Lands where a carried item ignores NoTeleport (refreshed at most once a second).
func lands() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if now - _checked_ms < 1000: return _lands
	_checked_ms = now
	_lands = {}
	if not ENABLED or world == null: return _lands
	for value: Variant in world.item_instances.values():
		if not value is Dictionary or not (value as Dictionary).get("record") is Dictionary: continue
		var record: Dictionary = value.record
		if record.get("source_m_native_item") != true: continue
		for row: Dictionary in D.item_definition(record).get("item_bonus", []):
			if str(row.get("bonus_type",{}).get("Name","")) != "IgnoreNoTeleport" or row.get("IsPossession") != true: continue
			var bonus: Dictionary = row.get("bonus",{})
			if int(bonus.get("BonusApplicationTypeID",0)) == 11 and int(bonus.get("Value",0)) == 1: _lands[int(bonus.get("BonusApplicationTargetID",0))] = true
	return _lands

func current_land() -> int:
	var now: int = Time.get_ticks_msec()
	if now - _land_ms < 500: return _land
	_land_ms = now
	_land = -1
	if world != null and world.has_method("orim_current_land") and world.has_method("current523_aden_source_active") and world.current523_aden_source_active():
		_land = int(world.orim_current_land().get("land_id", -1))
	return _land

func active() -> bool:
	if not ENABLED: return false
	var held: Dictionary = lands()
	return not held.is_empty() and held.has(current_land())

func ignores_no_teleport() -> bool:
	return active()

func buff_value(key: String) -> int:
	if not BONUS.has(key) or not active(): return 0
	return int(BONUS[key])
