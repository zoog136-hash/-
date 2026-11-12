extends RefCounted
## 오림의 흔적 (OrimsTrail*) — the original 523 table model.
## Pure reader: every number here comes from an original row. Rules that the
## tables do not hold are not filled in here; the run layer (orim523_run.gd)
## names each of its own choices, and docs/orim523_missing_rules.md lists them.
##
## `src` is any object with rows(table) and related(table, field, id), the
## same contract as scripts/resources/current523_definition_rows.gd (the real
## archive) or a synthetic test table. Table numbers arrive as floats.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

## Bonus types the run layer applies; everything else is kept and reported.
const EFFECTS := {"MoveSpeedBonus":"move_speed","AttackSpeedBonus":"attack_speed","HPPlus":"max_hp",
	"ExperienceAdditionPercent":"exp","OrimsTrailSpellCastDelayDecreasePercent":"cooldown",
	"BossPierceDamageReductionPercent":"boss_damage","SpellDamageBase":"damage","HPRestoration":"heal",
	"ChainReactionCount":"chain"}
const PERCENT := ["move_speed","attack_speed","exp","cooldown","boss_damage"]
const NPC_TABLES := ["NpcClass","NpcAttack","NpcClassForNpcGroup","DescData_Korean"]

static var _cache: Dictionary = {}

static func _i(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] else 0

static func _one(src: Variant, table: String, id: int) -> Dictionary:
	var matches: Array = src.related(table,"ID",id)
	return matches[-1] if not matches.is_empty() else {}

static func _text(src: Variant, id: int) -> String:
	if id<=0: return ""
	var matches: Array = src.related("DescData_Korean","ID",id)
	return "" if matches.is_empty() else str(matches[-1].get("Description",""))

## Cached model of the installed original archive (empty problem = usable).
static func installed() -> Dictionary:
	var sha: String = str(SOURCE.identity().get("source_sha256",""))
	if _cache.get("sha","")==sha and _cache.has("data"): return _cache.data
	var data: Dictionary = build(SOURCE) if not sha.is_empty() else {"ok":false,"problem":"원본 523 정의 ZIP 미설치"}
	_cache = {"sha":sha,"data":data}
	return data

static func release() -> void:
	_cache.clear()

static var _lands: Dictionary = {}
## Land IDs of the Orim stages (OrimsTrailStage.TeleportTerritoryID -> Territories.LandID).
static func stage_land_ids() -> Dictionary:
	var sha: String = str(SOURCE.identity().get("source_sha256",""))
	if _lands.get("sha","")==sha and _lands.has("ids"): return _lands.ids
	var ids: Dictionary = {}
	if not sha.is_empty():
		for row: Dictionary in SOURCE.rows("OrimsTrailStage"):
			var territory: Dictionary = _one(SOURCE,"Territories",_i(row.get("TeleportTerritoryID")))
			if not territory.is_empty(): ids[_i(territory.get("LandID"))] = true
	_lands = {"sha":sha,"ids":ids}
	return ids

## Bonus rows of one owner (SpellBonus by SpellClassID, BuffBonus by BuffClassID).
static func _bonuses(src: Variant, link_table: String, field: String, id: int, units: Dictionary, denominators: Dictionary) -> Dictionary:
	var out: Dictionary = {"effects":{},"held":[],"buffs":[]}
	for link: Dictionary in src.related(link_table,field,id):
		var bonus: Dictionary = _one(src,"Bonus",_i(link.get("BonusID")))
		var type: Dictionary = _one(src,"BonusType",_i(bonus.get("BonusTypeID")))
		var name: String = str(type.get("Name",""))
		var value: int = _i(bonus.get("Value"))
		if name=="BuffClassID":
			out.buffs.append(value); continue
		var conditional: bool = _i(bonus.get("BonusApplicationTypeID"))!=0 or _i(bonus.get("BonusApplicationTargetID"))!=0 or _i(link.get("MinSpellLevel"))!=0
		if not EFFECTS.has(name) or conditional:
			out.held.append({"type":name,"value":value,"conditional":conditional}); continue
		var key: String = EFFECTS[name]
		var unit: String = str(units.get(_i(type.get("UnitID")),""))
		if key in PERCENT:
			var denominator: int = int(denominators.get(_i(type.get("UnitID")),0))
			if unit!="Percentage" or denominator<=0:
				out.held.append({"type":name,"value":value,"reason":"백분율 단위 해석 불가"}); continue
			out.effects[key] = float(out.effects.get(key,0.0))+float(value)/float(denominator)
		else:
			out.effects[key] = int(out.effects.get(key,0))+value
	return out

static func _merge(into: Dictionary, part: Dictionary) -> void:
	for key: String in part.effects:
		into.effects[key] = into.effects.get(key,0)+part.effects[key]
	into.held.append_array(part.held)

## One original SpellClass: its timing/area fields and its applied bonuses,
## including the bonuses of every BuffClass it declares.
static func _spell(src: Variant, id: int, units: Dictionary, denominators: Dictionary, targeting: Dictionary) -> Dictionary:
	var row: Dictionary = _one(src,"SpellClass",id)
	if row.is_empty(): return {}
	var spell: Dictionary = {"id":id,"name":str(row.get("Name","")),"delay_ms":_i(row.get("CastDelay")),
		"radius":_i(row.get("TargetAreaRadius")),"range":_i(row.get("CastRange")),
		"targeting":str(targeting.get(_i(row.get("TargettingTypeID")),"")),"effect_sprite":_i(row.get("EffectSpriteID")),
		"icon":_i(row.get("IconID")),"effects":{},"held":[],"buff_ids":[]}
	var own: Dictionary = _bonuses(src,"SpellBonus","SpellClassID",id,units,denominators)
	_merge(spell,own)
	for buff_id: int in own.buffs:
		spell.buff_ids.append(buff_id)
		_merge(spell,_bonuses(src,"BuffBonus","BuffClassID",buff_id,units,denominators))
	return spell

static func build(src: Variant) -> Dictionary:
	var data: Dictionary = {"ok":false,"problem":"","stages":{},"characters":[],"curves":{"normal":[],"hard":[]},
		"groups":{},"spells":{},"casts":{},"max_count":{},"synergies":[],"reroll":{},"buffs":[],
		"npc":{},"npc_groups":{},"constants":[],"counts":{}}
	var units: Dictionary = {}
	for row: Dictionary in src.rows("Unit"): units[_i(row.ID)] = str(row.get("Name",""))
	var denominators: Dictionary = {}
	for row: Dictionary in src.rows("UIUnit"): denominators[_i(row.get("UnitID"))] = _i(row.get("Denominator"))
	var targeting: Dictionary = {}
	for row: Dictionary in src.rows("TargettingType"): targeting[_i(row.ID)] = str(row.get("Name",""))
	# Stages: TeleportTerritoryID -> Territories -> Land, UI by StageIndex.
	var ui_stage: Dictionary = {}
	for row: Dictionary in src.rows("UIOrimsTrailStage"): ui_stage[_i(row.get("OrimsTrailStageIndex"))] = row
	for row: Dictionary in src.rows("OrimsTrailStage"):
		var territory: Dictionary = _one(src,"Territories",_i(row.get("TeleportTerritoryID")))
		var land: Dictionary = _one(src,"Land",_i(territory.get("LandID")))
		var ui: Dictionary = ui_stage.get(_i(row.get("StageIndex")),{})
		data.stages[_i(row.ID)] = {"id":_i(row.ID),"index":_i(row.get("StageIndex")),"hard":bool(row.get("IsHard",false)),
			"time_limit":_i(row.get("TimeLimit")),"territory":territory.duplicate(true),"land_id":_i(territory.get("LandID")),
			"land_name":str(land.get("Name","")),"asset_path":str(land.get("AssetPath","")),
			"name":str(ui.get("StageName","")),"story":_text(src,_i(ui.get("StoryDescID")))}
	# Characters (heroes) and their UI rows.
	var ui_hero: Dictionary = {}
	for row: Dictionary in src.rows("UIOrimsTrailCharacter"): ui_hero[_i(row.get("OrimsTrailCharacterID"))] = row
	for row: Dictionary in src.rows("OrimsTrailCharacter"):
		var start: Dictionary = _one(src,"OrimsTrailSpellClass",_i(row.get("OrimsTrailSpellClassID")))
		var ui: Dictionary = ui_hero.get(_i(row.ID),{})
		data.characters.append({"id":_i(row.ID),"name":str(row.get("Name","")),"hp":_i(row.get("Hp")),"sp":_i(row.get("Sp")),
			"sprite":_i(row.get("SpriteID")),"probability":_i(row.get("Probability")),"portrait_node":str(row.get("PortraitNode","")),
			"hidden":str(row.get("PortraitNode","")).begins_with("Nd_Hidden"),"start_group":_i(start.get("SpellGroupID")),
			"start_level":_i(start.get("SpellLevel")),"title":str(ui.get("Name","")),"subtitle":str(ui.get("SubTitle","")),
			"story":_text(src,_i(ui.get("StoryDescID")))})
	data.characters.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.id)<int(b.id))
	# Orim level curves (cumulative experience per level), normal and hard.
	var curve_rows: Array = src.rows("OrimsTrailExperience")
	curve_rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return _i(a.get("Level"))<_i(b.get("Level")))
	for row: Dictionary in curve_rows:
		data.curves["hard" if bool(row.get("IsHard",false)) else "normal"].append(_i(row.get("Experience")))
	# Spell types, per-type ownership limits, groups and their levels.
	var type_names: Dictionary = {}
	for row: Dictionary in src.rows("OrimsTrailSpellType"): type_names[_i(row.ID)] = str(row.get("Name",""))
	for row: Dictionary in src.rows("OrimsTrailSpellMaxCount"): data.max_count[str(type_names.get(_i(row.get("SpellTypeID")),""))] = _i(row.get("MaxCount"))
	for row: Dictionary in src.rows("OrimsTrailSpellGroup"):
		data.groups[_i(row.ID)] = {"id":_i(row.ID),"name":str(row.get("Name","")),"desc":_text(src,_i(row.get("DescID"))),"type":"","levels":{},"max_level":-1}
	var cast_ids: Dictionary = {}
	for row: Dictionary in src.rows("OrimsTrailSpellClass"):
		var group: Dictionary = data.groups.get(_i(row.get("SpellGroupID")),{})
		if group.is_empty(): continue
		var level: int = _i(row.get("SpellLevel"))
		group.type = str(type_names.get(_i(row.get("SpellTypeID")),""))
		group.levels[level] = {"id":_i(row.ID),"name":str(row.get("Name","")),"cast_group":_i(row.get("CastGroupID")),"hidden":bool(row.get("IsHidden",false))}
		group.max_level = maxi(int(group.max_level),level)
		cast_ids[_i(row.get("CastGroupID"))] = true
	for row: Dictionary in src.rows("OrimsTrailMultipleSpellCastGroupEntity"):
		var cast: int = _i(row.get("CastGroupID"))
		if not cast_ids.has(cast): continue
		if not data.casts.has(cast): data.casts[cast] = []
		data.casts[cast].append({"order":_i(row.get("Order")),"spell":_i(row.get("SpellClassID")),"next_delay_ms":_i(row.get("NextSpellDelay")),"targeting_raw":_i(row.get("TargettingTypeID"))})
	for cast: int in data.casts:
		data.casts[cast].sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.order)<int(b.order))
		for entry: Dictionary in data.casts[cast]:
			if not data.spells.has(int(entry.spell)):
				var spell: Dictionary = _spell(src,int(entry.spell),units,denominators,targeting)
				if not spell.is_empty(): data.spells[int(entry.spell)] = spell
	# Synergy: every required group owned -> the result group can be offered.
	var rewards: Dictionary = {}
	for row: Dictionary in src.rows("OrimsTrailSynergySpellCombinationReward"):
		var key: int = _i(row.get("CombinationID")); if not rewards.has(key): rewards[key] = []
		rewards[key].append(_i(row.get("RewardID")))
	var requires: Dictionary = {}
	for row: Dictionary in src.rows("OrimsTrailSynergySpellCombinationRequirement"):
		var key2: int = _i(row.get("CombinationID")); if not requires.has(key2): requires[key2] = []
		requires[key2].append({"group":_i(row.get("SpellGroupID")),"min_level":_i(row.get("MinSpellLevel")),"priority":_i(row.get("DisplayPriority"))})
	for row: Dictionary in src.rows("OrimsTrailSynergySpellCombination"):
		var id: int = _i(row.ID)
		var needs: Array = requires.get(id,[])
		needs.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.priority)<int(b.priority))
		var reward_rows: Array = []
		for reward_id: int in rewards.get(id,[]):
			var reward: Dictionary = _one(src,"Reward",reward_id)
			if reward.is_empty(): continue
			reward_rows.append({"row":reward.duplicate(true),"name":str(_one(src,"ItemClass",_i(reward.get("RewardClassID"))).get("Name",""))})
		data.synergies.append({"id":id,"result":_i(row.get("ResultSpellGroupID")),"requires":needs,"rewards":rewards.get(id,[]),"reward_rows":reward_rows})
	for row: Dictionary in src.rows("OrimsTrailRerollCurrencyCost"): data.reroll[_i(row.get("RerollCount"))] = _i(row.get("Cost"))
	# Preparation buffs: cost + the BuffClass bonuses.
	for row: Dictionary in src.rows("OrimsTrailBuff"):
		var buff_id: int = _i(row.get("BuffClassID"))
		var buff: Dictionary = {"buff_class_id":buff_id,"currency":_i(row.get("CurrencyID")),"cost":_i(row.get("CurrencyCost")),
			"name":str(_one(src,"BuffClass",buff_id).get("Name","")),"effects":{},"held":[]}
		_merge(buff,_bonuses(src,"BuffBonus","BuffClassID",buff_id,units,denominators))
		data.buffs.append(buff)
	# Orim NPCs: role, original stats/exp/sprite, name, basic attacks, groups.
	var roles: Dictionary = {}
	for row: Dictionary in src.rows("OrimsTrailNpcType"): roles[_i(row.ID)] = str(row.get("Name",""))
	for row: Dictionary in src.rows("OrimsTrailNpc"):
		var npc_id: int = _i(row.get("NpcClassID"))
		var npc: Dictionary = _one(src,"NpcClass",npc_id)
		var attacks: Array = []
		for attack: Dictionary in src.related("NpcAttack","NpcClassID",npc_id): attacks.append(attack.duplicate(true))
		var name: String = _text(src,_i(npc.get("DescId")))
		data.npc[npc_id] = {"id":npc_id,"type":str(roles.get(_i(row.get("OrimsTrailNpcTypeID")),"")),"row":npc.duplicate(true),
			"hp":_i(npc.get("HP")),"mp":_i(npc.get("MP")),"ac":_i(npc.get("AC")),"mr":_i(npc.get("MR")),"exp":_i(npc.get("Exp")),
			"sprite":_i(npc.get("Sprite")),"name":name if not name.is_empty() else str(npc.get("Name","")),"attacks":attacks}
	var group_ids: Dictionary = {}
	for row: Dictionary in src.rows("OrimsTrailSpawn"):
		if _i(row.get("NpcGroupID"))!=0: group_ids[_i(row.get("NpcGroupID"))] = true
	for group_id: int in group_ids:
		var members: Array = []
		for link: Dictionary in src.related("NpcClassForNpcGroup","NpcGroupID",group_id): members.append(_i(link.get("NpcClassID")))
		data.npc_groups[group_id] = members
	for row: Dictionary in src.rows("OrimsTrailConstant"): data.constants.append(row.duplicate(true))
	var held: int = 0
	for spell: Dictionary in data.spells.values(): held += spell.held.size()
	data.counts = {"stages":data.stages.size(),"characters":data.characters.size(),"groups":data.groups.size(),
		"spell_levels":_count_levels(data),"casts":data.casts.size(),"spells":data.spells.size(),"synergies":data.synergies.size(),
		"npc":data.npc.size(),"npc_with_attack":_count_attacks(data),"npc_groups":data.npc_groups.size(),"held_spell_bonuses":held,
		"curve_normal":data.curves.normal.size(),"curve_hard":data.curves.hard.size(),"buffs":data.buffs.size(),"reroll":data.reroll.size()}
	if data.stages.is_empty() or data.characters.is_empty() or data.groups.is_empty() or data.npc.is_empty():
		data.problem = "오림의 흔적 원본 표가 비어 있습니다"
		return data
	data.ok = true
	return data

static func _count_levels(data: Dictionary) -> int:
	var total: int = 0
	for group: Dictionary in data.groups.values(): total += group.levels.size()
	return total

static func _count_attacks(data: Dictionary) -> int:
	var total: int = 0
	for npc: Dictionary in data.npc.values(): total += 1 if not npc.attacks.is_empty() else 0
	return total

## Level reached with `exp` total on a cumulative curve (level 1 = index 0).
static func level_for(curve: Array, experience: int) -> int:
	var level: int = 1
	for index: int in range(curve.size()):
		if experience>=int(curve[index]): level = index+1
	return level
