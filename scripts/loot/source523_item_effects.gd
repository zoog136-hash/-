extends RefCounted
## Original 523 consumables whose generic use spec stays blocked, read from
## their own ItemBonus rows (never from the item's name):
##  - random teleport scroll: TeleportTypeID 1 ("임의의 장소로 이동"), refused
##    inside its ConsumeTerritoryClassID areas (ConsumeTerritoryTypeId 2 =
##    "사용 불가 지역", ConsumeTerritories -> Territories rectangles);
##  - Ainhasad bless charge: EinasadBlessAbsolute in the original bless unit,
##    shown as points by EinasadVariable #42 (6000 per point, the item's own
##    description "(충전량 : N)" must agree), capped by
##    EinasadBlessMaxNeturalRechargeValue. The item's ItemConsumeRate group
##    (#12) Value is an added charge percent by user decision (85 x2 ... 89+
##    x5, above its last row the last Value; docs/einasad523_missing_rules.md). A LevelEinasadBlessRecharge
##    bonus (드래곤의 비약) names a level-indexed ItemConsumeRate group whose
##    Value at the character level is the charge in points (its description
##    "({0} 레벨 충전량 : {1})"), with the same group-12 bonus. An Experience
##    row with an ItemConsumeRate group of application type 42 (드래곤의 성수:
##    group 2, 10500 per 10000) also gives that EXP, checked against the
##    item's own description "EXP 31,920,000을 획득" and converted to the
##    TWILIGHT curve like the existing 드래곤의 성수 (HOLY_WATER_EXP);
##  - food whose buff also has RegenHP/RegenMP: those original amounts are added
##    per tick of the existing food regeneration cadence
##    (quest523_food_regen_interval_seconds, a TWILIGHT setting; the original
##    server interval is not in the tables).
## Plain name-keyed stacks (as the 523 shop sells them) use try_use_plain();
## receipted physical stacks use current523_native_stack (profile kinds
## "teleport" / "ain" / runtime_food) with prepare().
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FOOD_REASONS: Array[String] = ["unsupported_buff_effect:RegenHP","unsupported_buff_effect:RegenMP"]
const EINASAD_POINT_VARIABLE_TYPE := 42
const RULES = preload("res://scripts/einasad/einasad523_rules.gd")
const RECEIPT := "source_native_stack_receipt"
const EXP_PROGRESSION = preload("res://scripts/experience_progression.gd")
## Bonus application types of ItemConsumeRate rows on Einasad items.
const CHARGE_RATE_APPLICATION := 52
const EXPERIENCE_RATE_APPLICATION := 42
## Lineage M EXP of 드래곤의 성수 (its description "EXP 31,920,000을 획득").
const HOLY_WATER_SOURCE_EXP := 31920000
## Item lifetime rows: the projection resolves them and use eligibility
## refuses an expired item (patch523_item_use.eligibility).
const LIFETIME: Array[String] = ["DeleteTime","CannotExtendDeleteTime"]
## The eight already-expired historical event definitions express a direct
## blessing charge, neutral cap and original rate group but omit the later
## PlayerEinasadBless marker. Never bypass their existing lifetime/level gate.
const EARLY_EXPLICIT_AIN={122744:600000,123254:60000,123572:600000,123662:600000,124342:3000000,125971:600000,132933:600000,157071:600000}
## TWILIGHT 근사 switch: false keeps TeleportAmulet items unclaimed as before.
const AMULET_REUSABLE: bool = true
## TWILIGHT 근사 switch: ClassUsageInterval (seconds) on a fixed-destination
## scroll becomes its reuse delay instead of keeping the scroll.
const CLASS_USAGE_INTERVAL_AS_DELAY: bool = true

static var _areas: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _direct(row: Dictionary) -> bool:
	var bonus: Dictionary = row.get("bonus",{})
	return row.get("IsPossession")==false and _integer(bonus.get("BonusApplicationTypeID")) and int(bonus.BonusApplicationTypeID)==0 and _integer(bonus.get("BonusApplicationTargetID")) and int(bonus.BonusApplicationTargetID)==0 and _integer(bonus.get("Value"))

## The original definition when `record` is an ordinary, usable 523 consumable.
static func _definition(record: Dictionary) -> Dictionary:
	# TeleportAmulet (IsConsumable=false, IsActivatable=true) is projected as a
	# material; with the TWILIGHT 근사 switch it is a usable non-consumed item.
	var slot_ok: bool = record.get("slot")=="consumable" or (AMULET_REUSABLE and record.get("slot")=="material" and _amulet_category(record))
	if record.get("source_m_native_item")!=true or not slot_ok or record.get("source_test_item",true)!=false: return {}
	if not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false): return {}
	var definition: Dictionary = D.item_definition(record)
	var raw: Dictionary = definition.get("original_item",{})
	if raw.is_empty() or raw.get("TestItem")!=false or definition.get("excluded",false): return {}
	if not _integer(raw.get("TargettingTypeID")) or int(raw.TargettingTypeID)!=1 or not str(raw.get("ServiceRegionCode","")).is_empty(): return {}
	return definition

static func _amulet_category(record: Dictionary) -> bool:
	var raw: Dictionary = D.item_definition(record).get("original_item",{})
	return str(SOURCE.row("ItemCategory",int(raw.get("CategoryID",-1))).get("Name",""))=="TeleportAmulet"

## {"kind":"teleport", "territory_class_ids", "consume_delay_ms"} or {}.
static func teleport(record: Dictionary) -> Dictionary:
	var definition: Dictionary = _definition(record)
	if definition.is_empty(): return {}
	var kind: int = -1; var territories: Array[int] = []; var delay: int = 0
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String = str(row.get("bonus_type",{}).get("Name",""))
		if name in LIFETIME: continue
		if not _direct(row): return {}
		var value: int = int(row.bonus.Value)
		match name:
			"TeleportTypeID":
				if kind!=-1: return {}
				kind = value
			"ConsumeTerritoryClassID": territories.append(value)
			"ItemConsumeDelay": delay = value
			_: return {}
	if kind!=1 or delay<0: return {}
	return {"kind":"teleport","teleport_type_id":kind,"territory_class_ids":territories,"consume_delay_ms":delay}

## Fixed-destination teleport item (오만의 탑 n층 이동 주문서 등): exactly one
## TeleportToLocation (Unit LocationsID -> Locations LandID/X/Y, one cell) or
## TeleportToTerritory (Unit TerritoriesID -> Territories LandID + box) row,
## optional ConsumeTerritoryClassID rows (type 1 = "사용 지역": use only inside
## its ConsumeTerritories rectangles; type 2 = "사용 불가 지역"), lifetime,
## ItemConsumeDelay and ItemConsumeEffectSpriteID. Any other row (Life,
## ClassUsageInterval, TeleportTypeID, IgnoreNoTeleport, ...) has no rule
## here and keeps the item (docs/items523_remaining_missing_rules.md 16).
## {"kind":"teleport_location", "land_id", "bounds", "usable_classes",
## "forbidden_classes", "consume_delay_ms", "consume_sprite_id", "source"} or {}.
static func location_teleport(record: Dictionary) -> Dictionary:
	var definition: Dictionary = _definition(record)
	if definition.is_empty(): return {}
	var targets: Array = []; var classes: Array[int] = []; var delay: int = 0; var delays: int = 0; var sprite: int = 0; var sprites: int = 0
	# TWILIGHT 근사 (user policy 2026-11-16): a TeleportAmulet (이동/지배 부적) is
	# the same fixed-destination move but is not consumed ("1회성이 아니라
	# 무제한으로", 인벤 오만의 탑 가이드 https://lineagem.inven.co.kr/dataninfo/guide/?idx=185439,
	# checked 2026-11-16). Its StorableOnEnchant row and possession-only rows
	# (지배 부적 IgnoreNoTeleport / PossessItemSpellClassID inside the floor) are
	# not applied; UsageInterval (seconds) becomes its reuse delay.
	var amulet: bool = AMULET_REUSABLE and str(SOURCE.row("ItemCategory",int(definition.get("original_item",{}).get("CategoryID",-1))).get("Name",""))=="TeleportAmulet"
	var ignored: Array[String] = []
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String = str(row.get("bonus_type",{}).get("Name",""))
		if name in LIFETIME: continue
		# TWILIGHT 근사: the Life clock is kept by scripts/loot/item_life523.gd.
		if name=="Life" and preload("res://scripts/loot/item_life523.gd").ENABLED: continue
		if amulet and (name in ["StorableOnEnchant","IgnoreNoTeleport","PossessItemSpellClassID"] or row.get("IsPossession")==true):
			if name not in ignored: ignored.append(name)
			continue
		if not _direct(row): return {}
		var value: int = int(row.bonus.Value)
		var unit: String = str(row.get("unit",{}).get("Name",""))
		if (amulet and name=="UsageInterval" or name=="ClassUsageInterval" and CLASS_USAGE_INTERVAL_AS_DELAY) and unit=="Seconds" and value>0:
			# TWILIGHT 근사: ClassUsageInterval = reuse delay of this item class
			# (the existing cooldown is keyed by the item name, shared by copies).
			delay = value*1000; delays += 1
			continue
		match name:
			"TeleportToLocation":
				if unit!="LocationsID": return {}
				targets.append(["Locations",value])
			"TeleportToTerritory":
				if unit!="TerritoriesID": return {}
				targets.append(["Territories",value])
			"ConsumeTerritoryClassID": classes.append(value)
			"ItemConsumeDelay": delay = value; delays += 1
			"ItemConsumeEffectSpriteID": sprite = value; sprites += 1
			_: return {}
	if targets.size()!=1 or delays>1 or sprites>1 or delay<0 or sprite<0: return {}
	var table: String = str(targets[0][0]); var id: int = int(targets[0][1])
	if id<=0: return {}
	var rows: Array[Dictionary] = SOURCE.rows_matching(table,"ID",{id:true})
	if rows.size()!=1: return {}
	var target: Dictionary = rows[0]
	var bounds: Array = []
	if table=="Locations":
		for field: String in ["LandID","X","Y"]:
			if not _integer(target.get(field)): return {}
		bounds = [int(target.X),int(target.Y),int(target.X),int(target.Y)]
	else:
		for field: String in ["LandID","StartX","StartY","EndX","EndY"]:
			if not _integer(target.get(field)): return {}
		if int(target.EndX)<int(target.StartX) or int(target.EndY)<int(target.StartY): return {}
		bounds = [int(target.StartX),int(target.StartY),int(target.EndX),int(target.EndY)]
	if int(target.LandID)<=0 or SOURCE.rows_matching("Land","ID",{int(target.LandID):true}).size()!=1: return {}
	var usable: Array[int] = []; var forbidden: Array[int] = []
	for class_id: int in classes:
		var found: Array[Dictionary] = SOURCE.rows_matching("ConsumeTerritoryClass","ID",{class_id:true})
		if found.size()!=1 or not _integer(found[0].get("ConsumeTerritoryTypeId")): return {}
		match int(found[0].ConsumeTerritoryTypeId):
			1: usable.append(class_id)
			2: forbidden.append(class_id)
			_: return {}
	var result: Dictionary = {"kind":"teleport_location","land_id":int(target.LandID),"bounds":bounds,"usable_classes":usable,"forbidden_classes":forbidden,"consume_delay_ms":delay,"consume_sprite_id":sprite,"source":{"table":table,"id":id}}
	if amulet: result.merge({"reusable":true,"approximation":"TWILIGHT_REUSABLE_TELEPORT_AMULET","ignored_rows":ignored})
	return result

## 보고서2 NEW04 (원본 소비 규칙): a ConsumeTerritories point is inside when
## StartX <= x < EndX and StartY <= y < EndY (end exclusive; Rect2i.has_point is
## the same half-open test). A row with End <= Start contains no cell.
static func area_rect(territory: Dictionary) -> Rect2i:
	return Rect2i(int(territory.StartX),int(territory.StartY),maxi(0,int(territory.EndX)-int(territory.StartX)),maxi(0,int(territory.EndY)-int(territory.StartY)))

## Rectangles [{land, rect}] of ConsumeTerritoryClass ids, or null when a
## referenced row is missing.
static func consume_areas(class_ids: Array) -> Variant:
	var key: String = SOURCE.verified_key()+":areas:"+JSON.stringify(class_ids)
	if _areas.has(key): return _areas[key]
	var areas: Array = []
	for id: int in class_ids:
		var ids: Dictionary = {}
		for link: Dictionary in SOURCE.rows_matching("ConsumeTerritories","ConsumeTerritoryId",{id:true}):
			if not _integer(link.get("TerritoryId")): return null
			ids[int(link.TerritoryId)] = true
		if ids.is_empty(): return null
		var found: Array[Dictionary] = SOURCE.rows_matching("Territories","ID",ids)
		if found.size()!=ids.size(): return null
		for territory: Dictionary in found:
			for field: String in ["LandID","StartX","StartY","EndX","EndY"]:
				if not _integer(territory.get(field)): return null
			areas.append({"land":int(territory.LandID),"rect":area_rect(territory),"territory_id":int(territory.ID),"consume_territory_class_id":id})
	_areas[key] = areas
	return areas

## Inside one of `areas` (on the current Land, with a known source cell).
static func _inside(world: Node, areas: Array, point: Vector2) -> bool:
	var land: int = _land(world)
	var cell: Variant = _source_cell(world, point)
	if cell==null: return false
	for area: Dictionary in areas:
		if int(area.land)==land and (area.rect as Rect2i).has_point(cell): return true
	return false

## Forbidden rectangles [{land, rect}] of a teleport contract, or null when a
## referenced territory row is missing or is not a "cannot use" area.
static func forbidden_areas(contract: Dictionary) -> Variant:
	var key: String = SOURCE.verified_key()+":"+JSON.stringify(contract.territory_class_ids)
	if _areas.has(key): return _areas[key]
	var areas: Array = []
	for id: int in contract.territory_class_ids:
		var classes: Array[Dictionary] = SOURCE.rows_matching("ConsumeTerritoryClass","ID",{id:true})
		if classes.size()!=1 or not _integer(classes[0].get("ConsumeTerritoryTypeId")) or int(classes[0].ConsumeTerritoryTypeId)!=2: return null
		var ids: Dictionary = {}
		for link: Dictionary in SOURCE.rows_matching("ConsumeTerritories","ConsumeTerritoryId",{id:true}):
			if not _integer(link.get("TerritoryId")): return null
			ids[int(link.TerritoryId)] = true
		var found: Array[Dictionary] = SOURCE.rows_matching("Territories","ID",ids) if not ids.is_empty() else []
		if found.size()!=ids.size(): return null
		for territory: Dictionary in found:
			for field: String in ["LandID","StartX","StartY","EndX","EndY"]:
				if not _integer(territory.get(field)): return null
			areas.append({"land":int(territory.LandID),"rect":area_rect(territory),"territory_id":int(territory.ID),"consume_territory_class_id":id})
	_areas[key] = areas
	return areas

static func _land(world: Node) -> int:
	return int(world._regional_return_land())

static func _source_cell(world: Node, point: Vector2) -> Variant:
	var field: Variant = world.get("field_map")
	if field is OriginalPlayableField: return Vector2i((field as OriginalPlayableField).coordinates.to_source(point).floor())
	return null

static func _forbidden(world: Node, areas: Array, point: Vector2) -> bool:
	var land: int = _land(world)
	var cell: Variant = _source_cell(world, point)
	for area: Dictionary in areas:
		if int(area.land)!=land: continue
		# The current field is that Land: without its source coordinates the
		# point cannot be shown to lie outside the area.
		if cell==null or (area.rect as Rect2i).has_point(cell): return true
	return false

## {"kind":"ain", "points", "cap", "consume_rate_group"} or {}.
static func ain(record: Dictionary) -> Dictionary:
	var definition: Dictionary = _definition(record)
	if definition.is_empty(): return {}
	var absolute: int = -1; var cap: int = -1; var player: int = -1; var group: int = 0; var level_group: int = 0
	var experience: int = -1; var experience_group: int = 0
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String = str(row.get("bonus_type",{}).get("Name",""))
		var bonus: Dictionary = row.get("bonus",{})
		if name in LIFETIME: continue
		if name=="ItemConsumeRate":
			# A level-indexed ItemConsumeRate group reference: application type
			# 52 = the charge bonus group, 42 = the Experience rate group.
			if row.get("IsPossession")!=false or not _integer(bonus.get("Value")) or int(bonus.Value)<=0 or not _integer(bonus.get("BonusApplicationTypeID")) or not _integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID)!=0: return {}
			match int(bonus.BonusApplicationTypeID):
				CHARGE_RATE_APPLICATION:
					if group!=0: return {}
					group = int(bonus.Value)
				EXPERIENCE_RATE_APPLICATION:
					if experience_group!=0: return {}
					experience_group = int(bonus.Value)
				_: return {}
			continue
		if not _direct(row): return {}
		if name=="Experience":
			if experience!=-1 or int(bonus.Value)<=0: return {}
			experience = int(bonus.Value); continue
		if name=="LevelEinasadBlessRecharge":
			# Unit ItemConsumeRateGourpID: the Value is a group, not an amount.
			if level_group!=0 or int(bonus.Value)<=0: return {}
			level_group = int(bonus.Value); continue
		match name:
			"EinasadBlessAbsolute":
				if absolute!=-1: return {}
				absolute = int(bonus.Value)
			"EinasadBlessMaxNeturalRechargeValue":
				if cap!=-1: return {}
				cap = int(bonus.Value)
			"PlayerEinasadBless":
				if player!=-1: return {}
				player = int(bonus.Value)
			_: return {}
	var raw: Dictionary = definition.get("original_item",{})
	var early: bool=player==-1 and EARLY_EXPLICIT_AIN.get(int(raw.get("ID",0)),-2)==absolute and cap==599994000 and group==12 and level_group==0 and experience==-1 and experience_group==0
	if absolute<0 or (absolute==0 and level_group==0) or cap<=0 or (player!=1 and not early): return {}
	var variables: Array[Dictionary] = SOURCE.rows_matching("EinasadVariable","EinasadVariableTypeID",{EINASAD_POINT_VARIABLE_TYPE:true})
	if variables.size()!=1 or not _integer(variables[0].get("Value")) or int(variables[0].Value)<=0: return {}
	var unit: int = int(variables[0].Value)
	if absolute%unit!=0 or cap%unit!=0: return {}
	var points: int = absolute/unit
	# The item's own description states the charge in points.
	var story: String = str(SOURCE.row("DescData_Korean",int(raw.StoryDescID)).get("Description","")) if _integer(raw.get("StoryDescID")) and int(raw.StoryDescID)>0 else ""
	if (experience>0)!=(experience_group>0): return {}
	if experience>0:
		# 드래곤의 성수 family: "아인하사드의 축복 N을 충전하고 EXP M을 획득".
		# M is the Experience row times its group-42 rate per 10000 (group 2:
		# 10500 at levels 1 and 99 -> 30,400,000 x 1.05 = 31,920,000).
		if level_group>0: return {}
		var rate: int = uniform_rate(experience_group)
		if rate<=0 or experience*rate%10000!=0: return {}
		var charged: RegExMatch = RegEx.create_from_string("축복\\s*([0-9,]+)\\s*[을를]\\s*충전").search(story)
		var gained: RegExMatch = RegEx.create_from_string("EXP\\s*([0-9,]+)\\s*을\\s*획득").search(story)
		if charged==null or int(charged.get_string(1).replace(",",""))!=points or gained==null or int(gained.get_string(1).replace(",",""))!=experience*rate/10000: return {}
		return {"kind":"ain","points":points,"cap":cap/unit,"unit":unit,"consume_rate_group":group,"level_recharge_group":0,"experience":experience,"experience_rate_group":experience_group}
	if level_group>0:
		# The level amount is filled into the description template at use time.
		if not story.contains("레벨 충전량"): return {}
		return {"kind":"ain","points":points,"cap":cap/unit,"unit":unit,"consume_rate_group":group,"level_recharge_group":level_group}
	var match_result: RegExMatch = RegEx.create_from_string("충전량\\s*:\\s*([0-9,]+)").search(story)
	if match_result==null or int(match_result.get_string(1).replace(",",""))!=points: return {}
	return {"kind":"ain","points":points,"cap":cap/unit,"unit":unit,"consume_rate_group":group,"level_recharge_group":0}

## The one Value of an ItemConsumeRate group whose rows all agree, or -1. The
## rows are level keyed (group 2: levels 1 and 99); between two rows that
## differ the table does not say which applies, so only an all-equal group
## is read (inside its first..last level).
static func uniform_rate(group: int) -> int:
	var values: Dictionary = RULES.consume_rate_group(group)
	if values.is_empty(): return -1
	var rate: int = -1
	for level: int in values:
		if rate!=-1 and int(values[level])!=rate: return -1
		rate = int(values[level])
	return rate

## Lineage M EXP of one use at `level` (Experience x rate / 10000), or -1
## outside the rate group's level rows. 0 for an item without Experience.
static func source_experience(contract: Dictionary, level: int) -> int:
	if int(contract.get("experience",0))<=0: return 0
	var group: int = int(contract.experience_rate_group)
	var values: Dictionary = RULES.consume_rate_group(group)
	var rate: int = uniform_rate(group)
	if rate<=0: return -1
	var lowest: int = 1<<30; var highest: int = -1
	for row_level: int in values:
		lowest = mini(lowest,row_level); highest = maxi(highest,row_level)
	if level<lowest or level>highest: return -1
	return int(contract.experience)*rate/10000

## TWILIGHT EXP for a Lineage M amount: the existing curve conversion
## (experience_progression.gd: 31,920,000 Lineage M EXP of 드래곤의 성수 =
## HOLY_WATER_EXP on the x3 TWILIGHT curve), applied proportionally.
static func twilight_experience(source_amount: int) -> int:
	if source_amount<=0: return 0
	return int(round(float(source_amount)*float(EXP_PROGRESSION.HOLY_WATER_EXP)/float(HOLY_WATER_SOURCE_EXP)))

## Food reducer: the record with an unrestricted timed-buff spec whose
## RegenHP/RegenMP are per-tick amounts, or {} when this is not such food.
static func food_contract(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true: return {}
	var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("kind")!="source_timed_buff" or spec.get("activation_status")!="blocked" or spec.get("source_snapshot")!="patch523": return {}
	var reasons: Array = spec.get("blocked_reasons",[])
	if reasons.is_empty(): return {}
	for reason: Variant in reasons:
		if str(reason) not in FOOD_REASONS: return {}
	if spec.get("typed_effects",{}).is_empty() or float(spec.get("duration_seconds",0))<=0: return {}
	var amounts: Dictionary = {}
	for row: Dictionary in spec.get("source_buff_bonus",[]):
		var name: String = str(row.get("bonus_type",{}).get("Name",""))
		if name not in ["RegenHP","RegenMP"]: continue
		var bonus: Dictionary = row.get("bonus",{})
		if amounts.has(name) or row.get("unit",{}).get("Name")!="Value" or not _integer(bonus.get("Value")) or int(bonus.Value)<=0: return {}
		for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if not _integer(row.get(key)) or int(row[key])!=0: return {}
		if not _integer(bonus.get("BonusApplicationTypeID")) or int(bonus.BonusApplicationTypeID)!=0 or not _integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID)!=0: return {}
		amounts[name] = int(bonus.Value)
	for reason: Variant in reasons:
		if not amounts.has(str(reason).trim_prefix("unsupported_buff_effect:")): return {}
	return {"hp":int(amounts.get("RegenHP",0)),"mp":int(amounts.get("RegenMP",0))}

static func food_action(world: Node, record: Dictionary) -> Dictionary:
	var amounts: Dictionary = food_contract(record)
	if amounts.is_empty(): return record
	var cadence: float = preload("res://scripts/quests/quest_source_buffs523.gd").interval(world)
	if cadence<=0: return record
	var result: Dictionary = record.duplicate(true)
	var spec: Dictionary = NATIVE_FIELDS.full(result).get("source_use_spec",{}).duplicate(true)
	var typed: Dictionary = spec.typed_effects.duplicate(true)
	typed.merge({"hp_regen_tick":int(amounts.hp),"mp_regen_tick":int(amounts.mp),"tick_interval":cadence,"tick_elapsed":0.0,"source523_food_regen_policy":{"source_RegenHP":int(amounts.hp),"source_RegenMP":int(amounts.mp),"interval_seconds":cadence,"source_interval_verified":false,"policy":"TWILIGHT_existing_regeneration_clock"}})
	spec["typed_effects"] = typed
	spec["activation_status"] = "unrestricted"
	spec["host_policy_interpretation"] = "source_regen_amount_with_configurable_TWILIGHT_cadence"
	result["source_use_spec"] = spec
	return result

static func claims(record: Dictionary) -> String:
	if not teleport(record).is_empty(): return "teleport"
	if not location_teleport(record).is_empty(): return "teleport_location"
	if not ain(record).is_empty(): return "ain"
	if not food_contract(record).is_empty(): return "food"
	return ""

## Points one use charges at `level` before the existing charge-bonus
## percents, or -1 when the original rows do not decide it (charge_refusal).
static func charge_points(contract: Dictionary, level: int) -> int:
	var group: int = int(contract.get("consume_rate_group",0))
	var bonus: int = 0
	if group>0:
		# User decision: the group Value is an added percent (85 x2 ... 89+ x5).
		bonus = RULES.charge_bonus_percent(group, level)
		if bonus<0: return -1
	var level_group: int = int(contract.get("level_recharge_group",0))
	var base: int = int(contract.points)
	if level_group>0:
		# An absolute amount next to a level amount: how they combine is not stated.
		if int(contract.points)>0: return -1
		var values: Dictionary = RULES.consume_rate_group(level_group)
		if not values.has(level) or int(values[level])<=0: return -1
		base = int(values[level])
	return base*(100+bonus)/100

static func charge_refusal(contract: Dictionary, level: int) -> String:
	var group: int = int(contract.get("consume_rate_group",0))
	if group>0 and RULES.charge_bonus_percent(group, level)<0: return "원본 충전 보너스 표(ItemConsumeRate %d) %d레벨 확인 실패 · 아이템 보존" % [group, level]
	if int(contract.get("level_recharge_group",0))>0 and int(contract.points)>0: return "원본 고정·레벨 충전량 합산 규칙 미확정 · 아이템 보존"
	return "원본 %d레벨 충전량 행 없음 · 아이템 보존" % level

## Checks a teleport/Ainhasad use and computes its effect without changing
## anything: {"ok", "reason"} plus "destination" or "ainhasad_state".
static func prepare(world: Node, record: Dictionary, kind: String) -> Dictionary:
	var display: String = str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name","")))
	if kind=="teleport":
		var contract: Dictionary = teleport(record)
		if contract.is_empty(): return {"ok":false,"reason":"원본 순간이동 정의 확인 실패 · 주문서 보존"}
		if world.patch523_npc_spells.blocks("CannotTeleport") or world.player.is_stunned() or world.player.is_feared() or world.player.is_held(): return {"ok":false,"reason":"현재 상태에서는 순간이동할 수 없습니다 · 주문서 보존"}
		if world.field_map is OriginalPlayableField and world.field_map.uses_original_gameplay_rules() and not bool(world.field_map.definition.rules.get("teleportable",0)) and not (world.get("item_possession523") != null and world.item_possession523.ignores_no_teleport()): return {"ok":false,"reason":"원본 규칙상 순간이동 제한 지역입니다 · 주문서 보존"}
		var areas: Variant = forbidden_areas(contract)
		if areas==null: return {"ok":false,"reason":"원본 순간이동 불가 지역 자료 확인 실패 · 주문서 보존"}
		if _forbidden(world, areas, world.player.global_position): return {"ok":false,"reason":"원본 순간 이동 불가 지역입니다 · 주문서 보존"}
		for attempt: int in range(8):
			var destination: Vector2 = world.consumable_service._random_destination()
			if destination==Vector2.INF: break
			if not _forbidden(world, areas, destination): return {"ok":true,"destination":destination,"consume_delay_ms":int(contract.consume_delay_ms),"message":"%s · 현재 지도 임의 위치로 이동" % display}
		return {"ok":false,"reason":"이동 가능한 위치가 없습니다 · 주문서 보존"}
	if kind=="teleport_location":
		var contract: Dictionary = location_teleport(record)
		if contract.is_empty(): return {"ok":false,"reason":"원본 지정 위치 이동 정의 확인 실패 · 주문서 보존"}
		if not world.has_method("current523_aden_source_active") or not world.current523_aden_source_active(): return {"ok":false,"reason":"원본 523 지도에서만 사용할 수 있습니다 · 주문서 보존"}
		if world.patch523_npc_spells.blocks("CannotTeleport") or world.player.is_stunned() or world.player.is_feared() or world.player.is_held() or int(world.hp)<=0 or not world.charge_skill.is_empty() or float(world.portal_cooldown)>0: return {"ok":false,"reason":"현재 상태에서는 순간이동할 수 없습니다 · 주문서 보존"}
		var usable: Variant = consume_areas(contract.usable_classes)
		var forbidden: Variant = consume_areas(contract.forbidden_classes)
		if usable==null or forbidden==null: return {"ok":false,"reason":"원본 사용 지역 자료 확인 실패 · 주문서 보존"}
		var position: Vector2 = world.player.global_position
		if not (contract.usable_classes as Array).is_empty():
			# The item's own "사용 지역" rows say where it is used.
			if not _inside(world, usable, position): return {"ok":false,"reason":"원본 사용 지역에서만 사용할 수 있습니다 · 주문서 보존"}
		elif world.field_map is OriginalPlayableField and world.field_map.uses_original_gameplay_rules() and not bool(world.field_map.definition.rules.get("teleportable",0)): return {"ok":false,"reason":"원본 규칙상 순간이동 제한 지역입니다 · 주문서 보존"}
		if _forbidden(world, forbidden, position): return {"ok":false,"reason":"원본 사용 불가 지역입니다 · 주문서 보존"}
		var land_rows: Array[Dictionary] = SOURCE.rows_matching("Land","ID",{int(contract.land_id):true})
		var moving: Dictionary = {"ok":true,"travel":{"land_id":int(contract.land_id),"bounds":contract.bounds},"consume_delay_ms":int(contract.consume_delay_ms),"consume_sprite_id":int(contract.consume_sprite_id),"message":"%s · %s(으)로 이동" % [display, str(land_rows[0].get("Name","")) if land_rows.size()==1 else str(contract.land_id)]}
		if bool(contract.get("reusable",false)):
			moving["reusable"] = true
			moving.message += " (부적은 소모되지 않음 · TWILIGHT 근사)"
		return moving
	if kind=="ain":
		var contract: Dictionary = ain(record)
		if contract.is_empty(): return {"ok":false,"reason":"원본 아인하사드 충전 정의 확인 실패 · 아이템 보존"}
		var points: int = charge_points(contract, int(world.level))
		if points<0: return {"ok":false,"reason":charge_refusal(contract, int(world.level))}
		var service: TwilightAinhasadService = world.ain_service
		var cap: int = mini(int(contract.cap), service.charge_cap())
		if service.blessing>=cap: return {"ok":false,"reason":"아인하사드 축복이 최대치입니다 · 아이템 보존"}
		var amount: int = world._amount_with_ainhasad_charge_bonuses(points) if world.has_method("_amount_with_ainhasad_charge_bonuses") else int(round(float(points)*(1.0+(world.growth.bonus("blessing_charge:percent")+world.card_collections.bonus("blessing_charge:percent"))/100.0)))
		amount = mini(amount, cap-service.blessing)
		var before: Dictionary = service.export_state()
		var after: Dictionary = before.duplicate(true)
		after["blessing"] = int(before.blessing)+amount
		var result: Dictionary = {"ok":true,"ainhasad_state":after,"charged":amount,"message":"%s · 아인하사드 축복 +%d" % [display, amount]}
		var source_exp: int = source_experience(contract, int(world.level))
		if source_exp<0: return {"ok":false,"reason":"원본 %d레벨 경험치 배율(ItemConsumeRate %d) 행 범위 밖 · 아이템 보존" % [int(world.level), int(contract.experience_rate_group)]}
		if source_exp>0:
			var gained: int = twilight_experience(source_exp)
			if int(world.experience)>9007199254740991-gained: return {"ok":false,"reason":"경험치 정수 범위 초과 · 아이템 보존"}
			result["experience"] = int(world.experience)+gained
			result["experience_gained"] = gained
			result["source_experience"] = source_exp
			result.message = "%s · 아인하사드 축복 +%d · EXP +%d" % [display, amount, gained]
		return result
	return {"ok":false,"reason":"원본 사용 효과 미지원 · 아이템 보존"}

## A plain name-keyed stack of a claimed item (no receipted physical stack of
## that name): true when handled here.
static func try_use_plain(world: Node, item_name: String, known_record: Variant=null) -> bool:
	return (load("res://scripts/loot/source523_item_effects.gd") as Script).call("_try_use_plain_impl",world,item_name,known_record,false)

static func try_use_plain_loading(world: Node, item_name: String, known_record: Variant) -> bool:
	return await _try_use_plain_impl(world,item_name,known_record,true)

static func _try_use_plain_impl(world: Node, item_name: String, known_record: Variant, loading: bool) -> bool:
	if item_name.is_empty(): return false
	var record: Dictionary = known_record if known_record is Dictionary else world._find_catalog_item_record(item_name)
	if record.is_empty() or str(record.get("name",""))!=item_name: return false
	var kind: String = claims(record)
	if kind.is_empty(): return false
	for entry: Variant in world.item_instances.values():
		if entry is Dictionary and entry.get("name")==item_name and (entry as Dictionary).has(RECEIPT): return false
	if kind=="food": return preload("res://scripts/loot/patch523_item_use.gd").try_use(world, record)
	var use_owner: Script = preload("res://scripts/loot/patch523_item_use.gd")
	var problem: String = use_owner.eligibility(world, record)
	if problem.is_empty() and (not world._patch523_item_allowed() or world.hp<=0 or world._option_awakening_busy()): problem = "현재 사용·생존 상태 조건 미충족"
	if problem.is_empty() and (world._item_locked(item_name) or not _integer(world.inventory.get(item_name,0)) or int(world.inventory.get(item_name,0))<1): problem = "아이템이 없거나 잠겨 있습니다"
	if problem.is_empty() and not str(world.patch523_owner_state_problem).is_empty(): problem = "원본 소비 저장 보호 중 · 아이템 보존"
	if problem.is_empty() and not bool(D.item_definition(record).get("original_item",{}).get("CanUseWhenInvisible",false)) and world.is_player_concealed(): problem = "원본 조건: 은신 중 사용할 수 없습니다"
	var cooldown_key: String = "m523:item:"+str(int(record.source_item_class_id))
	if problem.is_empty() and float(world.item_use_cooldowns.get(cooldown_key,0.0))>0.0: problem = "원본 아이템 재사용 대기"
	if not problem.is_empty():
		world.hud.show_message(problem)
		return true
	var prepared: Dictionary = prepare(world, record, kind)
	if not prepared.get("ok",false):
		world.hud.show_message(str(prepared.get("reason","")))
		return true
	var inventory: Dictionary = use_owner.debit(world, item_name)
	var payload: Dictionary = {"inventory":inventory}
	var delay: float = float(prepared.get("consume_delay_ms",0))/1000.0
	if delay>0.0:
		var cooldowns: Dictionary = world.item_use_cooldowns.duplicate(true)
		cooldowns[cooldown_key] = delay; cooldowns[item_name] = delay
		payload["item_use_cooldowns"] = cooldowns
	if prepared.has("ainhasad_state"): payload["ainhasad_state"] = prepared.ainhasad_state
	if prepared.has("experience"): payload["experience"] = int(prepared.experience)
	if prepared.has("travel"):
		# The debit is saved by the arrival's own checkpoint save.
		var moved: Dictionary
		if loading: moved = await world.item523_teleport_land_loading(int(prepared.travel.land_id),prepared.travel.bounds,payload)
		else: moved = world.item523_teleport_land(int(prepared.travel.land_id),prepared.travel.bounds,payload)
		if not moved.get("ok",false):
			world.hud.show_message(str(moved.get("reason","이동 실패")) + (" · 정상 저장 불러오기 필요" if moved.get("uncertain",false) else " · 주문서 보존"))
			return true
		world.inventory = inventory
		if payload.has("item_use_cooldowns"): world.item_use_cooldowns = payload.item_use_cooldowns
		world.deferred_save.cancel()
		world.hud.refresh_inventory(world.inventory)
		world._update_hud()
		_emit_sprite(world, int(prepared.get("consume_sprite_id",0)))
		world.hud.show_message(str(prepared.message))
		world.hud.append_log(str(prepared.message))
		return true
	var previous: Vector2 = world.player.global_position
	if prepared.has("destination"):
		if loading and not await world.prepare_map_point(prepared.destination): return true
		world.consumable_service._teleport_player(prepared.destination)
	var saved: Error = load("res://scripts/loot/current523_native_stack.gd").sealed_save(world, payload) if payload.has("experience") else world._save_game(true, payload)
	if saved!=OK:
		if prepared.has("destination"): world.consumable_service._teleport_player(previous)
		world.hud.show_message("저장 실패 · 아이템과 기존 상태 보존")
		return true
	commit(world, prepared)
	world.inventory = inventory
	if payload.has("item_use_cooldowns"): world.item_use_cooldowns = payload.item_use_cooldowns
	world.deferred_save.cancel()
	world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	world.hud.show_message(str(prepared.message))
	world.hud.append_log(str(prepared.message))
	return true

static func _emit_sprite(world: Node, sprite: int) -> void:
	if sprite>0 and world.get("option_awakening")!=null: world.option_awakening.combat.emit_sprite(sprite,world.player)

## Applies a saved prepare() result to the running game (the position of a
## teleport is already applied before its save).
static func commit(world: Node, prepared: Dictionary) -> void:
	if prepared.has("ainhasad_state"):
		world.ain_service.import_state(prepared.ainhasad_state)
		world._update_ain_hud()
	if prepared.has("experience"):
		# Saved with the item debit; a level-up it reaches is applied after
		# that save and saved again once the current use has finished.
		world.experience = int(prepared.experience)
		var level_before: int = int(world.level)
		world._check_level_up()
		if int(world.level)!=level_before: world.call_deferred("_save_game", true)
		world._update_hud()
