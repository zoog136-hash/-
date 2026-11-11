extends RefCounted
## Original 523 BuffCardDeckBonus: (BuffCardDeckID, GradeID) -> BonusID.
## The table holds only the deck, the card grade and the bonus. The active
## (equipped, owned) card of each deck supplies its deck and grade, exactly as
## its own BuffClass bonuses are applied. Nothing else is read from the table
## because nothing else is in it: no owned-count, collection or combination
## column exists (see docs/card_deck_bonus523_missing_rules.md).
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BASE508 = preload("res://scripts/lineagem_base508.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const TABLE := "BuffCardDeckBonus"
## Decks the existing card registry connects (current523_card_catalog.CATEGORIES).
const DECKS := {1:"변신",2:"마법인형",98:"성물"}
## Existing consumers. "record" fields are read from _all_equipped_records(),
## "catalog" fields through _catalog_stat_sum()/the cast-speed policy line.
## Percentage values are over the UIUnit Denominator (10000) = percent points,
## Weight over its Denominator (100), Value as is - the same rule as
## option_slot_definitions.gd.
const FIELDS := {
	"MoveSpeedBonus":["speedBonusPct","record"],
	"AttackSpeedBonus":["attackSpeed","record"],
	"ExperienceAdditionPercent":["xp","record_fraction"],
	"EinasadSavingPercent":["blessing_consumption_reduction_pct","record"],
	"HPPlus":["hpFlat","record"],
	"MPPlus":["mpFlat","catalog"],
	"CarryPlus":["weightBonus","catalog"],
	"SpellCastDelayDecreasePercent":["skillCooldownPct","catalog"],
	"CastSpeedBonus":["castSpeed","catalog"],
}
const UNITS := {"Percentage":10000,"Weight":100,"Value":1}
const LABELS := {"MoveSpeedBonus":"이동 속도","AttackSpeedBonus":"공격 속도","ExperienceAdditionPercent":"획득 경험치",
	"EinasadSavingPercent":"아인하사드 절약","HPPlus":"최대 HP","MPPlus":"최대 MP","CarryPlus":"무게 보너스",
	"SpellCastDelayDecreasePercent":"스킬 쿨타임 감소","CastSpeedBonus":"시전 속도","HitRecoverySpeedBonus":"피격 회복 속도"}

var world: Node
var problem: String = ""
## "deck:grade" -> Array of resolved effects.
var definitions: Dictionary = {}
## Rows kept as data but not applied, with the reason.
var held: Array[Dictionary] = []
var _loaded: bool = false
var _signature: int = 0
var _records: Array[Dictionary] = []
var _totals: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

func configure(host: Node) -> bool:
	world = host
	load_definitions()
	return problem.is_empty()

func load_definitions() -> void:
	if _loaded: return
	_loaded = true
	definitions.clear(); held.clear(); problem = ""
	if SOURCE.identity().is_empty():
		problem = "원본523 정의 ZIP 미설치 · 카드 덱 보너스 보류: " + SOURCE.problem()
		return
	var rows: Array[Dictionary] = SOURCE.rows(TABLE)
	if rows.is_empty():
		problem = "원본 " + TABLE + " 표를 읽을 수 없습니다"
		return
	for raw: Dictionary in rows:
		var effect: Dictionary = _resolve(raw)
		if not bool(effect.get("applied",false)):
			held.append(effect); continue
		var key: String = str(int(raw.BuffCardDeckID)) + ":" + str(int(raw.GradeID))
		if not definitions.has(key): definitions[key] = []
		definitions[key].append(effect)

func _hold(raw: Dictionary, reason: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"applied":false,"row":raw.duplicate(true),"reason":reason}
	result.merge(extra)
	return result

func _resolve(raw: Dictionary) -> Dictionary:
	for field: String in ["ID","BuffCardDeckID","GradeID","BonusID"]:
		if not _integer(raw.get(field)): return _hold(raw,"invalid_field:"+field)
	if not SOURCE.declared_exclusion(TABLE,raw).is_empty(): return _hold(raw,"source_declared_exclusion")
	var deck_id: int = int(raw.BuffCardDeckID)
	if not DECKS.has(deck_id): return _hold(raw,"deck_not_connected:"+str(deck_id))
	if SOURCE.row("Grade",int(raw.GradeID)).is_empty(): return _hold(raw,"missing_grade")
	var bonus: Dictionary = SOURCE.row("Bonus",int(raw.BonusID))
	if bonus.is_empty() or not _integer(bonus.get("Value")) or not _integer(bonus.get("BonusTypeID")): return _hold(raw,"missing_bonus")
	var type: Dictionary = SOURCE.row("BonusType",int(bonus.BonusTypeID))
	var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1))) if _integer(type.get("UnitID")) else {}
	var type_name: String = str(type.get("Name",""))
	var unit_name: String = str(unit.get("Name",""))
	var extra: Dictionary = {"bonus":bonus.duplicate(true),"type_name":type_name,"unit_name":unit_name}
	if type.is_empty() or unit.is_empty(): return _hold(raw,"missing_bonus_type_or_unit",extra)
	if int(bonus.get("BonusApplicationTypeID",-1)) != 0 or int(bonus.get("BonusApplicationTargetID",-1)) != 0: return _hold(raw,"conditional_bonus_application",extra)
	if not FIELDS.has(type_name): return _hold(raw,"no_game_consumer:"+type_name,extra)
	if not UNITS.has(unit_name): return _hold(raw,"unit_not_supported:"+unit_name,extra)
	var denominator: int = int(UNITS[unit_name])
	if unit_name != "Value":
		var ui: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(unit.ID))
		if ui.size() != 1 or int(ui[0].get("Denominator",0)) != denominator: return _hold(raw,"display_denominator_mismatch:"+unit_name,extra)
	var amount: float = float(bonus.Value) / float(denominator)
	var mapping: Array = FIELDS[type_name]
	extra.merge({"applied":true,"deck_id":deck_id,"grade_id":int(raw.GradeID),"field":mapping[0],"consumer":mapping[1],
		"amount":amount,"label":str(LABELS.get(type_name,type_name))+" +"+str(snappedf(amount,0.01)).trim_suffix(".0")+("%" if unit_name=="Percentage" else "")})
	var result: Dictionary = {"row":raw.duplicate(true)}
	result.merge(extra)
	return result

## Effects for one deck and grade, applied or not.
func effects_for(deck_id: int, grade_id: int) -> Array:
	load_definitions()
	return (definitions.get(str(deck_id)+":"+str(grade_id),[]) as Array).duplicate(true)

func held_for(deck_id: int, grade_id: int) -> Array[Dictionary]:
	load_definitions()
	var result: Array[Dictionary] = []
	for entry: Dictionary in held:
		if _integer(entry.row.get("BuffCardDeckID")) and int(entry.row.BuffCardDeckID)==deck_id and int(entry.row.get("GradeID",-1))==grade_id: result.append(entry.duplicate(true))
	return result

## The active card of a deck: equipped, a current original card, owned.
func active_card(category: String) -> Dictionary:
	if world == null: return {}
	var value: Variant = world.equipped_catalog.get(category,{})
	if not value is Dictionary or (value as Dictionary).is_empty() or not BASE508.native(value): return {}
	var record: Dictionary = world._verified_catalog_record(category,value)
	if record.is_empty() or record.get("source_snapshot","") != "patch523": return {}
	var identity: String = Cards.card_id(record)
	if world.card_draw_fusion.owned.get(category,{}).get(identity,false) != true: return {}
	var original: Variant = record.get("source_original_card")
	if not original is Dictionary or not _integer(original.get("ID")) or not _integer(original.get("BuffCardDeckID")) or not _integer(original.get("GradeID")): return {}
	if DECKS.get(int(original.BuffCardDeckID),"") != category: return {}
	return {"identity":identity,"deck_id":int(original.BuffCardDeckID),"grade_id":int(original.GradeID),"card_id":int(original.ID),"name":str(record.get("name",""))}

func _rebuild() -> void:
	if world == null or not problem.is_empty():
		_records.clear(); _totals.clear(); _signature = 0
		return
	var signature: int = hash([world.equipped_catalog,world.card_draw_fusion.owned])
	if signature == _signature and _signature != 0: return
	_signature = signature; _records.clear(); _totals.clear()
	for category: String in DECKS.values():
		var card: Dictionary = active_card(category)
		if card.is_empty(): continue
		var record: Dictionary = {"_card_deck_bonus":true,"origin":"deck_bonus:"+str(card.deck_id)+":"+str(card.grade_id)+":"+str(card.identity)}
		for effect: Dictionary in effects_for(int(card.deck_id),int(card.grade_id)):
			var field: String = str(effect.field)
			var amount: float = float(effect.amount)
			match str(effect.consumer):
				"record": record[field] = float(record.get(field,0.0)) + amount
				"record_fraction": record[field] = float(record.get(field,0.0)) + amount / 100.0
				"catalog": _totals[field] = float(_totals.get(field,0.0)) + amount
		if record.size() > 2: _records.append(record)

func bonus_records() -> Array[Dictionary]:
	_rebuild()
	return _records.duplicate(true)

func catalog_bonus(key: String) -> int:
	_rebuild()
	return int(round(float(_totals.get(key,0.0))))

## Current deck bonuses by category for UI/diagnostics.
func view() -> Dictionary:
	var result: Dictionary = {"problem":problem,"decks":{}}
	for category: String in DECKS.values():
		var card: Dictionary = active_card(category)
		if card.is_empty(): continue
		var labels: Array[String] = []
		for effect: Dictionary in effects_for(int(card.deck_id),int(card.grade_id)):
			if float(effect.amount) != 0.0: labels.append(str(effect.label))
		result.decks[category] = {"card":card,"labels":labels,"held":held_for(int(card.deck_id),int(card.grade_id)).size()}
	return result
