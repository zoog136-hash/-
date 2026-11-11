extends RefCounted
## Original 523 consumables whose generic use spec stays blocked, read from
## their own ItemBonus rows (never from the item's name):
##  - random teleport scroll: TeleportTypeID 1 ("임의의 장소로 이동"), refused
##    inside its ConsumeTerritoryClassID areas (ConsumeTerritoryTypeId 2 =
##    "사용 불가 지역", ConsumeTerritories -> Territories rectangles);
##  - Ainhasad bless charge: EinasadBlessAbsolute in the original bless unit,
##    shown as points by EinasadVariable #42 (6000 per point, the item's own
##    description "(충전량 : N)" must agree), capped by
##    EinasadBlessMaxNeturalRechargeValue. From the first level of the item's
##    ItemConsumeRate group (#12: 85) the item is kept: whether that Value is
##    an added percent, a multiplier percent or a per-10000 rate is not in the
##    tables (docs/einasad523_missing_rules.md). A LevelEinasadBlessRecharge
##    bonus (드래곤의 비약) names a level-indexed ItemConsumeRate group whose
##    Value at the character level is the charge in points (its description
##    "({0} 레벨 충전량 : {1})"), under the same group-12 limit;
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
## Item lifetime rows: the projection resolves them and use eligibility
## refuses an expired item (patch523_item_use.eligibility).
const LIFETIME: Array[String] = ["DeleteTime","CannotExtendDeleteTime"]

static var _areas: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _direct(row: Dictionary) -> bool:
	var bonus: Dictionary = row.get("bonus",{})
	return row.get("IsPossession")==false and _integer(bonus.get("BonusApplicationTypeID")) and int(bonus.BonusApplicationTypeID)==0 and _integer(bonus.get("BonusApplicationTargetID")) and int(bonus.BonusApplicationTargetID)==0 and _integer(bonus.get("Value"))

## The original definition when `record` is an ordinary, usable 523 consumable.
static func _definition(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("slot")!="consumable" or record.get("source_test_item",true)!=false: return {}
	if not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false): return {}
	var definition: Dictionary = D.item_definition(record)
	var raw: Dictionary = definition.get("original_item",{})
	if raw.is_empty() or raw.get("TestItem")!=false or definition.get("excluded",false): return {}
	if not _integer(raw.get("TargettingTypeID")) or int(raw.TargettingTypeID)!=1 or not str(raw.get("ServiceRegionCode","")).is_empty(): return {}
	return definition

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
			areas.append({"land":int(territory.LandID),"rect":Rect2i(int(territory.StartX),int(territory.StartY),int(territory.EndX)-int(territory.StartX)+1,int(territory.EndY)-int(territory.StartY)+1),"territory_id":int(territory.ID),"consume_territory_class_id":id})
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
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String = str(row.get("bonus_type",{}).get("Name",""))
		var bonus: Dictionary = row.get("bonus",{})
		if name in LIFETIME: continue
		if name=="ItemConsumeRate":
			# A level-indexed ItemConsumeRate group reference (application type 52).
			if group!=0 or row.get("IsPossession")!=false or not _integer(bonus.get("Value")) or int(bonus.Value)<=0 or not _integer(bonus.get("BonusApplicationTypeID")) or int(bonus.BonusApplicationTypeID)!=52 or not _integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID)!=0: return {}
			group = int(bonus.Value); continue
		if not _direct(row): return {}
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
	if absolute<0 or (absolute==0 and level_group==0) or cap<=0 or player!=1: return {}
	var variables: Array[Dictionary] = SOURCE.rows_matching("EinasadVariable","EinasadVariableTypeID",{EINASAD_POINT_VARIABLE_TYPE:true})
	if variables.size()!=1 or not _integer(variables[0].get("Value")) or int(variables[0].Value)<=0: return {}
	var unit: int = int(variables[0].Value)
	if absolute%unit!=0 or cap%unit!=0: return {}
	var points: int = absolute/unit
	# The item's own description states the charge in points.
	var raw: Dictionary = definition.get("original_item",{})
	var story: String = str(SOURCE.row("DescData_Korean",int(raw.StoryDescID)).get("Description","")) if _integer(raw.get("StoryDescID")) and int(raw.StoryDescID)>0 else ""
	if level_group>0:
		# The level amount is filled into the description template at use time.
		if not story.contains("레벨 충전량"): return {}
		return {"kind":"ain","points":points,"cap":cap/unit,"unit":unit,"consume_rate_group":group,"level_recharge_group":level_group}
	var match_result: RegExMatch = RegEx.create_from_string("충전량\\s*:\\s*([0-9,]+)").search(story)
	if match_result==null or int(match_result.get_string(1).replace(",",""))!=points: return {}
	return {"kind":"ain","points":points,"cap":cap/unit,"unit":unit,"consume_rate_group":group,"level_recharge_group":0}

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
	if not ain(record).is_empty(): return "ain"
	if not food_contract(record).is_empty(): return "food"
	return ""

## Points one use charges at `level` before the existing charge-bonus
## percents, or -1 when the original rows do not decide it (charge_refusal).
static func charge_points(contract: Dictionary, level: int) -> int:
	var group: int = int(contract.get("consume_rate_group",0))
	if group>0:
		var first: int = RULES.first_rate_level(group)
		if first<0 or level>=first: return -1
	var level_group: int = int(contract.get("level_recharge_group",0))
	if level_group<=0: return int(contract.points)
	# An absolute amount next to a level amount: how they combine is not stated.
	if int(contract.points)>0: return -1
	var values: Dictionary = RULES.consume_rate_group(level_group)
	if not values.has(level) or int(values[level])<=0: return -1
	return int(values[level])

static func charge_refusal(contract: Dictionary, level: int) -> String:
	var group: int = int(contract.get("consume_rate_group",0))
	if group>0:
		var first: int = RULES.first_rate_level(group)
		if first<0: return "원본 충전 보너스 표(ItemConsumeRate %d) 확인 실패 · 아이템 보존" % group
		if level>=first: return "원본 %d레벨 충전 보너스(ItemConsumeRate %d) 해석 미확정 · 아이템 보존" % [level, group]
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
		if world.field_map is OriginalPlayableField and world.field_map.uses_original_gameplay_rules() and not bool(world.field_map.definition.rules.get("teleportable",0)): return {"ok":false,"reason":"원본 규칙상 순간이동 제한 지역입니다 · 주문서 보존"}
		var areas: Variant = forbidden_areas(contract)
		if areas==null: return {"ok":false,"reason":"원본 순간이동 불가 지역 자료 확인 실패 · 주문서 보존"}
		if _forbidden(world, areas, world.player.global_position): return {"ok":false,"reason":"원본 순간 이동 불가 지역입니다 · 주문서 보존"}
		for attempt: int in range(8):
			var destination: Vector2 = world.consumable_service._random_destination()
			if destination==Vector2.INF: break
			if not _forbidden(world, areas, destination): return {"ok":true,"destination":destination,"consume_delay_ms":int(contract.consume_delay_ms),"message":"%s · 현재 지도 임의 위치로 이동" % display}
		return {"ok":false,"reason":"이동 가능한 위치가 없습니다 · 주문서 보존"}
	if kind=="ain":
		var contract: Dictionary = ain(record)
		if contract.is_empty(): return {"ok":false,"reason":"원본 아인하사드 충전 정의 확인 실패 · 아이템 보존"}
		var points: int = charge_points(contract, int(world.level))
		if points<0: return {"ok":false,"reason":charge_refusal(contract, int(world.level))}
		var service: TwilightAinhasadService = world.ain_service
		var cap: int = mini(int(contract.cap), service.charge_cap())
		if service.blessing>=cap: return {"ok":false,"reason":"아인하사드 축복이 최대치입니다 · 아이템 보존"}
		var amount: int = int(round(float(points)*(1.0+(world.growth.bonus("blessing_charge:percent")+world.card_collections.bonus("blessing_charge:percent"))/100.0)))
		amount = mini(amount, cap-service.blessing)
		var before: Dictionary = service.export_state()
		var after: Dictionary = before.duplicate(true)
		after["blessing"] = int(before.blessing)+amount
		return {"ok":true,"ainhasad_state":after,"charged":amount,"message":"%s · 아인하사드 축복 +%d" % [display, amount]}
	return {"ok":false,"reason":"원본 사용 효과 미지원 · 아이템 보존"}

## A plain name-keyed stack of a claimed item (no receipted physical stack of
## that name): true when handled here.
static func try_use_plain(world: Node, item_name: String) -> bool:
	if item_name.is_empty(): return false
	var record: Dictionary = world._find_catalog_item_record(item_name)
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
	var previous: Vector2 = world.player.global_position
	if prepared.has("destination"): world.consumable_service._teleport_player(prepared.destination)
	if world._save_game(true, payload)!=OK:
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

## Applies a saved prepare() result to the running game (the position of a
## teleport is already applied before its save).
static func commit(world: Node, prepared: Dictionary) -> void:
	if prepared.has("ainhasad_state"):
		world.ain_service.import_state(prepared.ainhasad_state)
		world._update_ain_hud()
