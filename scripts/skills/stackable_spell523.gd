extends RefCounted
## 보고서2 R1: original 523 stackable (충전형) spells, e.g. 암흑기사 다크 소울 34922.
## Every number is an original table value:
##  - SpellBonus IsStackableSpell (9492) = 1 marks the spell; StackableSpellMaxStack
##    caps the stored charges, StackableSpellMaxSummon (9482) caps the active casts,
##    StackableSpellMaterialCount is spent per cast.
##  - Admission (oc_m95_m99_spell_state.stackable_admission): current <= 0 -> refused
##    (0xD1DA), active >= max -> refused (0xD1E4); passing only continues to the
##    normal checks (learned, cooldown, MP/HP/material) — it is not a success.
##  - Recharge: ActiveSpellPassiveSpellClassID -> its SpellClassID children ->
##    BuffClassID -> BuffBonus InvokeOption (Value = chance /1e6) -> InvokeOption
##    Attack_StackableSpell_KillNpc (42: +Param2 per kill) and
##    Attack_StackableSpell_AttackProb (64: +Param2 per normal attack with
##    Param6/1e6 probability); Param3 ms is the anti-spam gap of each rule.
##  - Effect: NextSpellClassID plate (SpellPlateDuration / SpellPlateInterval hits,
##    SampleTargetMaxCount targets, SpellDamageBase + DiceNumber d DiceSpotCount).
## TWILIGHT 근사: the plate lands around the caster (TargettingType 1, TargetArea
## radius × 48 px like the other approximated actives); the damage goes through the
## existing deal_damage. Charges are a separate store from ammo, materials and
## cooldowns, and are saved with the skill state.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STATE = preload("res://scripts/original_client/oc_m95_m99_spell_state.gd")
const PLAYER523 = preload("res://scripts/skills/player_skills523.gd")
const CELL: float = 48.0
var service: RefCounted
var charges: Dictionary = {}   # record id -> {"current": int, "active": int}
var gaps: Dictionary = {}      # record id + ":" + kind -> remaining seconds
var plates: Array = []         # live casts: {"id","skill","hits_left","next","remaining"}
var _specs: Dictionary = {}

func configure(owner: RefCounted) -> void:
	service = owner

func clear() -> void:
	plates.clear()
	gaps.clear()
	for id: String in charges: charges[id]["active"] = 0

static func _bonus_rows(spell_id: int) -> Array:
	var result: Array = []
	for link: Dictionary in SOURCE.related("SpellBonus","SpellClassID",spell_id):
		if int(link.get("MinSpellLevel",0))!=0: continue
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		if bonus.is_empty(): continue
		result.append({"type":str(SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))).get("Name","")),"bonus":bonus})
	return result

static func _first(rows: Array, type_name: String) -> Variant:
	for entry: Dictionary in rows:
		if entry.type==type_name: return entry.bonus.get("Value")
	return null

## Original stackable contract of one SpellClass, or {} when it is not one.
static func source_spec(spell_id: int) -> Dictionary:
	if spell_id<=0 or SOURCE.not_installed(): return {}
	var bonuses: Array = _bonus_rows(spell_id)
	if int(_first(bonuses,"IsStackableSpell") if _first(bonuses,"IsStackableSpell")!=null else 0)!=1: return {}
	var max_stack: int = int(_first(bonuses,"StackableSpellMaxStack") if _first(bonuses,"StackableSpellMaxStack")!=null else 0)
	var max_summon: int = int(_first(bonuses,"StackableSpellMaxSummon") if _first(bonuses,"StackableSpellMaxSummon")!=null else 0)
	var per_cast: int = int(_first(bonuses,"StackableSpellMaterialCount") if _first(bonuses,"StackableSpellMaterialCount")!=null else 0)
	var row: Dictionary = SOURCE.row("SpellClass",spell_id)
	if max_stack<=0 or max_summon<=0 or per_cast<=0 or row.is_empty() or row.get("TestSpell")!=false: return {}
	var spec: Dictionary = {"spell_id":spell_id,"max_stack":max_stack,"max_summon":max_summon,"per_cast":per_cast,
		"cooldown":maxf(0.0,float(row.get("CastDelay",0)))/1000.0,"radius":float(row.get("TargetAreaRadius",0))*CELL,
		"material_type":int(row.get("SpellMaterialTypeID",0)),"material_amount":int(row.get("SpellMaterialItemAmount",0)),
		"mp":int(row.get("MPCost",0)),"hp":int(row.get("HPCost",0)),"gains":[],"effect":{}}
	# Effect plate (NextSpellClassID that names this spell as its stack owner).
	for entry: Dictionary in bonuses:
		if entry.type!="NextSpellClassID": continue
		var child: Array = _bonus_rows(int(entry.bonus.Value))
		if int(_first(child,"StackableSpellClassID") if _first(child,"StackableSpellClassID")!=null else 0)!=spell_id: continue
		var interval: float = float(_first(child,"SpellPlateInterval") if _first(child,"SpellPlateInterval")!=null else 0)/1000.0
		var duration: float = float(_first(child,"SpellPlateDuration") if _first(child,"SpellPlateDuration")!=null else 0)/1000.0
		spec.effect = {"spell_id":int(entry.bonus.Value),"base":int(_first(child,"SpellDamageBase") if _first(child,"SpellDamageBase")!=null else 0),
			"number":int(_first(child,"SpellDamageDiceNumber") if _first(child,"SpellDamageDiceNumber")!=null else 0),
			"sides":int(_first(child,"SpellDamageDiceSpotCount") if _first(child,"SpellDamageDiceSpotCount")!=null else 0),
			"targets":int(_first(child,"SampleTargetMaxCount") if _first(child,"SampleTargetMaxCount")!=null else 0),
			"interval":interval,"duration":duration,"hits":int(floor(duration/interval))+1 if interval>0.0 else 1,
			"attack_type":"magic" if int(_first(child,"SpellAttackType") if _first(child,"SpellAttackType")!=null else 0)==2 else "melee"}
	if spec.effect.is_empty() or int(spec.effect.targets)<=0: return {}
	# Recharge rules through the always-on passive part.
	var passive: Variant = _first(bonuses,"ActiveSpellPassiveSpellClassID")
	var children: Array = []
	if passive!=null:
		for entry: Dictionary in _bonus_rows(int(passive)):
			if entry.type=="SpellClassID": children.append(int(entry.bonus.Value))
	for child_id: int in children:
		var buff: Variant = _first(_bonus_rows(child_id),"BuffClassID")
		if buff==null: continue
		for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",int(buff)):
			if int(link.get("MinSpellLevel",0))!=0: continue
			var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
			if str(SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))).get("Name",""))!="InvokeOption": continue
			var option: Dictionary = SOURCE.row("InvokeOption",int(bonus.get("BonusApplicationTargetID",-1)))
			if option.is_empty() or int(option.get("Param1",-1))!=spell_id: continue
			var kind: String = str(SOURCE.row("InvokeOptionType",int(option.get("InvokeOptionTypeID",-1))).get("Name",""))
			var gain: Dictionary = {"invoke_option_id":int(option.ID),"amount":maxi(0,int(option.get("Param2",0))),"gap":maxf(0.0,float(option.get("Param3",0)))/1000.0,
				"invoke_chance":clampf(float(bonus.get("Value",0))/1000000.0,0.0,1.0)}
			if kind=="Attack_StackableSpell_KillNpc": gain.merge({"event":"on_kill","probability":1.0})
			elif kind=="Attack_StackableSpell_AttackProb": gain.merge({"event":"on_hit","probability":clampf(float(option.get("Param6",0))/1000000.0,0.0,1.0)})
			else: continue
			if int(gain.amount)>0: spec.gains.append(gain)
	return spec

## The skill record's bound original SpellClass (player_skills523_bindings), then
## its stackable contract; cached per spell and definition generation.
func spec_for(record: Dictionary) -> Dictionary:
	if service==null or service.catalog==null or record.is_empty(): return {}
	var binding: Variant = service.catalog.source523.bindings.get("skills",{}).get(str(record.get("id","")),{})
	var spell_id: int = int(binding.get("spell_id",0)) if binding is Dictionary else 0
	if spell_id<=0: return {}
	var key: String = "%d|%d" % [spell_id,SOURCE.cache_generation()]
	if not _specs.has(key): _specs[key] = source_spec(spell_id)
	return _specs[key]

func handles(record: Dictionary) -> bool:
	return not spec_for(record).is_empty()

func state_of(id: String) -> Dictionary:
	if not charges.has(id): charges[id] = {"current":0,"active":0}
	return charges[id]

## Charge count shown on the quickslot / skill window (-1: not a stackable spell).
func count_for(record: Dictionary) -> int:
	if not handles(record): return -1
	return int(state_of(str(record.get("id",""))).current)

## M95 admission on this game's store, through the original decision function.
func admission(record: Dictionary) -> Dictionary:
	var spec: Dictionary = spec_for(record)
	if spec.is_empty(): return {"result":"continue_next_validation"}
	var current: Dictionary = state_of(str(record.id))
	var key: int = int(spec.spell_id)
	var world_model: Dictionary = {"bonus_lists":{key:[1,2]},"bonus_rows":{1:{"type":STATE.TYPE_IS_STACKABLE,"value":1},2:{"type":STATE.TYPE_STACKABLE_MAX,"value":int(spec.max_summon)}},
		"tree188":{key:{"current":int(current.current),"packet_max":int(spec.max_stack),"active":int(current.active)}}}
	var result: Dictionary = STATE.stackable_admission(world_model,key)
	if result.get("code",0)==STATE.RESULT_CURRENT_NOT_POSITIVE or (result.result=="continue_next_validation" and int(current.current)<int(spec.per_cast)):
		return {"result":"false","reason":"충전 없음 (0/%d)" % int(spec.max_stack),"code":"no_charge"}
	if result.get("code",0)==STATE.RESULT_ACTIVE_AT_MAX: return {"result":"false","reason":"최대 활성 수 %d" % int(spec.max_summon),"code":"active_limit"}
	return result

## The resolved skill for the normal cost checks: original MP/HP and material.
func cast_skill(record: Dictionary) -> Dictionary:
	var spec: Dictionary = spec_for(record)
	var skill: Dictionary = service.catalog.resolve(record)
	var items: Dictionary = {}
	if int(spec.material_amount)>0:
		var bridge: Dictionary = service.catalog.source523.bindings.get("material_inventory_keys",{}).get(str(int(spec.material_type)),{})
		if bridge.is_empty(): skill["source523_block_reason"] = "원본 재료 %d 인벤토리 연결 없음" % int(spec.material_type)
		else: items[str(bridge.inventory_key)] = int(spec.material_amount)
	skill.merge({"mode":"stackable523","activation":"active","items":items,"mp":int(spec.mp),"hp":int(spec.hp),"cooldown":float(spec.cooldown),
		"shape":"self_circle","radius":float(spec.radius),"targets":int(spec.effect.targets),"attack_type":str(spec.effect.attack_type)},true)
	return skill

func cast(record: Dictionary) -> bool:
	var gate: Dictionary = admission(record)
	if gate.result!="continue_next_validation":
		service.world.hud.show_message(str(gate.get("reason","충전형 스킬 사용 불가")))
		return false
	var skill: Dictionary = cast_skill(record)
	var reason: String = service.cost_reason(skill)
	if not reason.is_empty(): service.world.hud.show_message(reason); return false
	if not service.spend(skill): return false
	var spec: Dictionary = spec_for(record)
	var current: Dictionary = state_of(str(record.id))
	current.current = int(current.current)-int(spec.per_cast)
	current.active = int(current.active)+1
	service.world.skill_cooldowns[str(record.name)] = float(spec.cooldown)*service.world._skill_cooldown_factor()
	service.world.skill_global_cooldown = .3
	plates.append({"id":str(record.id),"skill":skill,"hits_left":int(spec.effect.hits),"next":0.0,"interval":float(spec.effect.interval),"remaining":float(spec.effect.duration),"effect":spec.effect.duplicate(true)})
	service.vfx.begin_cast(str(record.id),service.world.player,null)
	service.world._update_hud()
	return true

func _plate_hit(plate: Dictionary) -> void:
	var world: Node = service.world
	var effect: Dictionary = plate.effect
	var origin: Vector2 = world.player.global_position
	var near: Array = []; var far: Array = []
	for child: Node in world.monsters_root.get_children():
		if not child is TwilightMonster or child.dead: continue
		var monster := child as TwilightMonster
		if not PLAYER523.target_allowed(plate.skill,monster): continue
		var distance: float = origin.distance_to(monster.global_position)
		if distance<=CELL: near.append(monster)
		elif distance<=float(plate.skill.radius): far.append(monster)
	# Original: every target within 1 cell, plus at most SampleTargetMaxCount farther.
	far.sort_custom(func(a: TwilightMonster,b: TwilightMonster) -> bool: return a.global_position.distance_squared_to(origin)<b.global_position.distance_squared_to(origin))
	if far.size()>int(effect.targets): far.resize(int(effect.targets))
	for target: TwilightMonster in near+far:
		if not is_instance_valid(target) or target.dead: continue
		var power: int = int(effect.base)
		for _die: int in int(effect.number): power += world.rng.randi_range(1,maxi(1,int(effect.sides)))
		service.deal_damage({"id":str(plate.id),"name":str(plate.skill.get("name","")),"power":power,"attack_type":str(effect.attack_type),"shape":"area"},target)

func tick(delta: float) -> void:
	for key: String in gaps.keys():
		gaps[key] = float(gaps[key])-delta
		if float(gaps[key])<=0.0: gaps.erase(key)
	for plate: Dictionary in plates.duplicate():
		plate.next = float(plate.next)-delta
		plate.remaining = float(plate.remaining)-delta
		while int(plate.hits_left)>0 and float(plate.next)<=0.0:
			_plate_hit(plate)
			plate.hits_left = int(plate.hits_left)-1
			plate.next = float(plate.next)+float(plate.interval)
		if float(plate.remaining)<=0.0 and int(plate.hits_left)<=0:
			plates.erase(plate)
			var current: Dictionary = state_of(str(plate.id))
			current.active = maxi(0,int(current.active)-1)

## Recharge from a normal attack hit (on_hit, not by a spell) or a kill.
func on_event(event: String, attack: Dictionary) -> int:
	if event not in ["on_hit","on_kill"] or service==null or service.catalog==null: return 0
	if event=="on_hit" and bool(attack.get("by_spell",false)): return 0
	var gained: int = 0
	for record: Dictionary in service.catalog.records:
		if not service.catalog.owned(record): continue
		var spec: Dictionary = spec_for(record)
		if spec.is_empty(): continue
		var current: Dictionary = state_of(str(record.id))
		for gain: Dictionary in spec.gains:
			if gain.event!=event: continue
			var gap_key: String = str(record.id)+":"+str(gain.invoke_option_id)
			if gaps.has(gap_key) or int(current.current)>=int(spec.max_stack): continue
			if service.world.rng.randf()>=float(gain.invoke_chance)*float(gain.probability): continue
			var before: int = int(current.current)
			current.current = mini(int(spec.max_stack),before+int(gain.amount))
			gaps[gap_key] = float(gain.gap)
			gained += int(current.current)-before
	if gained>0: service.world._update_hud()
	return gained

func export_state() -> Dictionary:
	var stored: Dictionary = {}
	for id: String in charges: stored[id] = int(charges[id].current)
	return {"schema":1,"current":stored}

## Saved charges are clamped to the current original cap; active casts never persist.
func import_state(data: Variant) -> void:
	charges.clear(); plates.clear(); gaps.clear()
	if not data is Dictionary or int(data.get("schema",0))!=1 or not data.get("current") is Dictionary: return
	for id: Variant in data.current:
		var record: Dictionary = service.catalog.record_for(str(id)) if service!=null else {}
		var spec: Dictionary = spec_for(record) if not record.is_empty() else {}
		if spec.is_empty(): continue
		charges[str(id)] = {"current":clampi(int(data.current[id]),0,int(spec.max_stack)),"active":0}
