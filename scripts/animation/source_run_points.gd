extends RefCounted
## Original acceleration stage that switches the player's movement action from
## the walk actor to the SpriteRun run actor (user decision 2026-11-19: walk
## normally, run at acceleration stage 1 or more, as the original does).
##
## Original 523 tables: BonusType 168 "RunSpritePoint" with
## BonusApplicationType 394 "RunSpriteLevel" (target = stage). Only the
## acceleration buffs carry it: 1단 (BuffClass 10 헤이스트, 40 초록 물약, 11111
## 강화 초록 물약, ...) level 1; 2단 (41 용기의 물약, 42 엘븐 와퍼, 43 악마의 피,
## 26 홀리 스위프트, ...) level 2; 3단 (237 드래곤의 진주, ...) level 3; each +1.
## A test "강제 걷기 만들기" debuff (84031) gives -1 with no level.
## Lineage Remaster notes (Inven news 214388): "드래곤의 진주를 사용하면
## 리니지M처럼 이동 속도가 증가한 달리기 모션이 적용된다".
##
## Combination (TWILIGHT 근사, the original rule is not in the tables): one
## point per stage level held (buffs of the same stage share a BuffGroup and do
## not stack), plus unlevelled values.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const RUN_SPRITE_POINT: int = 168
const RUN_SPRITE_LEVEL: int = 394
static var _memo: Dictionary = {}
static var _memo_generation: int = -1

## {"levels": {stage: value}, "flat": value} of one original BuffClass.
static func buff_points(buff_class_id: int) -> Dictionary:
	if buff_class_id <= 0: return {}
	var generation: int = DEF.cache_generation()
	if generation != _memo_generation:
		_memo.clear()
		_memo_generation = generation
	if _memo.has(buff_class_id): return _memo[buff_class_id]
	if DEF.not_installed(): return {}
	var levels: Dictionary = {}
	var flat: int = 0
	var found: bool = false
	for link: Dictionary in DEF.related("BuffBonus", "BuffClassID", buff_class_id):
		var bonus: Dictionary = DEF.row("Bonus", int(link.get("BonusID", -1)))
		if int(bonus.get("BonusTypeID", -1)) != RUN_SPRITE_POINT: continue
		found = true
		var value: int = int(bonus.get("Value", 0))
		if int(bonus.get("BonusApplicationTypeID", 0)) == RUN_SPRITE_LEVEL:
			var stage: int = int(bonus.get("BonusApplicationTargetID", 0))
			levels[stage] = maxi(int(levels.get(stage, value)), value)
		else:
			flat += value
	var result: Dictionary = {"levels": levels, "flat": flat} if found else {}
	_memo[buff_class_id] = result
	return result

## Original BuffClass id of one TWILIGHT buff record, or 0.
static func record_buff_class_id(record: Variant) -> int:
	if not record is Dictionary: return 0
	var buff: Dictionary = record
	var source: Variant = buff.get("source_buff_class")
	if source is Dictionary and int((source as Dictionary).get("ID", 0)) > 0: return int(source.ID)
	for key: String in ["source_buff_class_id", "buff_class_id"]:
		if int(buff.get(key, 0)) > 0: return int(buff[key])
	return 0

## Acceleration points of `buff_class_ids`: {"known": bool, "points": int}.
## known is false when none of them carries a RunSpritePoint.
static func points(buff_class_ids: Array) -> Dictionary:
	var levels: Dictionary = {}
	var flat: int = 0
	var known: bool = false
	for id: Variant in buff_class_ids:
		var entry: Dictionary = buff_points(int(id))
		if entry.is_empty(): continue
		known = true
		flat += int(entry.flat)
		for stage: Variant in entry.levels:
			levels[stage] = maxi(int(levels.get(stage, entry.levels[stage])), int(entry.levels[stage]))
	var total: int = flat
	for stage: Variant in levels: total += int(levels[stage])
	return {"known": known, "points": total}

## Points from the effects the world currently applies to the player: timed
## item buffs and skill buffs (any record naming its original BuffClass).
static func from_world(world: Object) -> Dictionary:
	var ids: Array = []
	if world != null and is_instance_valid(world):
		for list_name: String in ["active_item_buffs", "active_skill_buffs"]:
			var list: Variant = world.get(list_name)
			if not list is Dictionary: continue
			for value: Variant in (list as Dictionary).values():
				var id: int = record_buff_class_id(value)
				if id > 0: ids.append(id)
	return points(ids)
