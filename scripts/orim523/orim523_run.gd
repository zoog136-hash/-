extends RefCounted
## 오림의 흔적 run rules on top of the original model (orim523.gd).
## The run state is a plain Dictionary saved inside the existing dungeon play
## ledger (source_dungeon_play.active.orim). Original values: hero HP/SP and
## starting skill, level curves, skill groups/levels/types/limits, synergy
## requirements, reroll costs, NPC Exp, spell CastDelay/range/area/damage and
## buff bonuses. Own choices (named, not in the tables) are the constants
## below; docs/orim523_missing_rules.md lists them.
const MODEL = preload("res://scripts/orim523/orim523.gd")
## Own: how many skill cards one level-up shows (no original row names it).
const OFFER_COUNT := 3
## Own: hidden heroes have no unlock rule in the tables, so they stay locked.
const HIDDEN_SELECTABLE := false
const PASSIVE := ["move_speed","attack_speed","max_hp","exp","cooldown","boss_damage"]

static func _i(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] else 0

static func character(model: Dictionary, id: int) -> Dictionary:
	for hero: Dictionary in model.get("characters",[]):
		if int(hero.id)==id: return hero
	return {}

static func selectable(model: Dictionary) -> Array:
	var out: Array = []
	for hero: Dictionary in model.get("characters",[]):
		if HIDDEN_SELECTABLE or not bool(hero.hidden): out.append(hero)
	return out

static func start(model: Dictionary, character_id: int) -> Dictionary:
	var hero: Dictionary = character(model,character_id)
	if hero.is_empty() or (bool(hero.hidden) and not HIDDEN_SELECTABLE): return {}
	var orim: Dictionary = {"character":int(hero.id),"exp":0,"level":1,"spells":{},"offer":[],"pending":0,"hero_hp":0,"hero_max":0,"casts":{}}
	if model.groups.has(int(hero.start_group)): orim.spells[str(int(hero.start_group))] = int(hero.start_level)
	orim.hero_max = hero_max(model,orim)
	orim.hero_hp = orim.hero_max
	return orim

static func valid(model: Dictionary, orim: Variant) -> bool:
	if not orim is Dictionary: return false
	for key: String in ["character","exp","level","pending","hero_hp","hero_max"]:
		if typeof(orim.get(key)) not in [TYPE_INT,TYPE_FLOAT] or float(orim[key])<0 or float(orim[key])>9.0e15: return false
	if character(model,_i(orim.character)).is_empty() or not orim.get("spells") is Dictionary or not orim.get("offer") is Array or orim.offer.size()>8: return false
	for key: Variant in orim.spells:
		var group: Dictionary = model.groups.get(int(str(key)),{}) if str(key).is_valid_int() else {}
		if group.is_empty() or not group.levels.has(_i(orim.spells[key])): return false
	for gid: Variant in orim.offer:
		if not model.groups.has(_i(gid)): return false
	return true

static func curve(model: Dictionary, hard: bool) -> Array:
	return model.curves.get("hard" if hard else "normal",[])

static func _entries(model: Dictionary, gid: int, level: int) -> Array:
	var group: Dictionary = model.groups.get(gid,{})
	var row: Dictionary = group.get("levels",{}).get(level,{})
	return model.casts.get(int(row.get("cast_group",0)),[])

## Sum of the passive bonuses of every owned skill at its level.
static func effects(model: Dictionary, orim: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in PASSIVE: out[key] = 0.0
	for key: Variant in orim.get("spells",{}):
		for entry: Dictionary in _entries(model,int(str(key)),_i(orim.spells[key])):
			var spell: Dictionary = model.spells.get(int(entry.spell),{})
			for name: String in PASSIVE:
				out[name] = float(out[name])+float(spell.get("effects",{}).get(name,0))
	return out

static func hero_max(model: Dictionary, orim: Dictionary) -> int:
	return maxi(1,int(character(model,_i(orim.character)).get("hp",1))+int(effects(model,orim).max_hp))

## Adds experience (with the owned ExperienceAdditionPercent); returns levels gained.
static func gain(model: Dictionary, orim: Dictionary, amount: int, hard: bool) -> int:
	var bonus: float = float(effects(model,orim).exp)
	orim.exp = int(orim.exp)+int(round(float(amount)*(1.0+bonus/100.0)))
	var reached: int = MODEL.level_for(curve(model,hard),int(orim.exp))
	var gained: int = maxi(0,reached-int(orim.level))
	orim.level = maxi(int(orim.level),reached)
	orim.pending = int(orim.pending)+gained
	return gained

static func _type_count(model: Dictionary, orim: Dictionary, type: String) -> int:
	var count: int = 0
	for key: Variant in orim.spells:
		if str(model.groups.get(int(str(key)),{}).get("type",""))==type: count += 1
	return count

## Groups a level-up may show: owned below their top level, new groups while
## their type is below OrimsTrailSpellMaxCount (a group whose level-0 row is
## IsHidden is not offered new), synergy results whose requirements are owned.
static func candidates(model: Dictionary, orim: Dictionary) -> Array:
	var out: Array = []
	var synergy_results: Dictionary = {}
	for synergy: Dictionary in model.synergies: synergy_results[int(synergy.result)] = synergy
	for gid: int in model.groups:
		var group: Dictionary = model.groups[gid]
		var key: String = str(gid)
		if orim.spells.has(key):
			if _i(orim.spells[key])<int(group.max_level) and group.levels.has(_i(orim.spells[key])+1): out.append(gid)
			continue
		if not group.levels.has(0) or bool(group.levels[0].hidden): continue
		var limit: int = int(model.max_count.get(str(group.type),0))
		if _type_count(model,orim,str(group.type))>=limit: continue
		if synergy_results.has(gid):
			var ready: bool = true
			for need: Dictionary in synergy_results[gid].requires:
				if not orim.spells.has(str(int(need.group))) or _i(orim.spells[str(int(need.group))])<int(need.min_level): ready = false
			if not ready: continue
		out.append(gid)
	out.sort()
	return out

static func offer(model: Dictionary, orim: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = candidates(model,orim)
	var picked: Array = []
	while not pool.is_empty() and picked.size()<OFFER_COUNT:
		picked.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	orim.offer = picked
	return picked

static func choose(model: Dictionary, orim: Dictionary, gid: int) -> Dictionary:
	var shown: bool = false
	for value: Variant in orim.offer:
		if _i(value)==gid: shown = true
	if not shown: return {"ok":false,"reason":"제시된 스킬이 아닙니다"}
	var key: String = str(gid)
	var before_max: int = hero_max(model,orim)
	orim.spells[key] = (_i(orim.spells[key])+1) if orim.spells.has(key) else 0
	orim.offer = []
	orim.pending = maxi(0,int(orim.pending)-1)
	var after_max: int = hero_max(model,orim)
	orim.hero_max = after_max
	orim.hero_hp = clampi(int(orim.hero_hp)+maxi(0,after_max-before_max),0,after_max)
	var group: Dictionary = model.groups[gid]
	return {"ok":true,"group":gid,"level":int(orim.spells[key]),"name":str(group.levels[int(orim.spells[key])].name)}

## Owned skills that cast: every cast-group entry with a CastDelay or damage.
static func casters(model: Dictionary, orim: Dictionary) -> Array:
	var out: Array = []
	var cooldown: float = clampf(float(effects(model,orim).cooldown),0.0,90.0)
	for key: Variant in orim.get("spells",{}):
		var gid: int = int(str(key))
		var index: int = 0
		for entry: Dictionary in _entries(model,gid,_i(orim.spells[key])):
			var spell: Dictionary = model.spells.get(int(entry.spell),{})
			if int(spell.get("delay_ms",0))>0 and int(spell.get("effects",{}).get("damage",0))>0:
				out.append({"key":str(gid)+":"+str(index),"group":gid,"spell":spell,"cooldown_ms":int(round(float(spell.delay_ms)*(1.0-cooldown/100.0)))})
			index += 1
	return out

static func npc_exp(model: Dictionary, npc_id: int) -> int:
	return int(model.npc.get(npc_id,{}).get("exp",0))

## Original BuffClass bonuses of the bought preparation buffs.
static func buff_effects(model: Dictionary, bought: Dictionary) -> Dictionary:
	var out: Dictionary = {"move_speed":0.0,"attack_speed":0.0}
	for buff: Dictionary in model.get("buffs",[]):
		if not bought.has(str(int(buff.buff_class_id))): continue
		for key: String in out: out[key] = float(out[key])+float(buff.effects.get(key,0))
	return out

static func reroll_cost(model: Dictionary, count: int) -> int:
	return int(model.reroll.get(count,-1))
