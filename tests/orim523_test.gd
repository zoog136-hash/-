extends SceneTree
## 오림의 흔적 (scripts/orim523). Synthetic OrimsTrail* rows always run (floats,
## as the archive delivers numbers): stage -> Territory -> Land, heroes and the
## hidden heroes open (user decision 2026-11-13), start skill, level curve, ExperienceAdditionPercent, skill
## cards (OrimsTrailSpellMaxCount, IsHidden level 0, synergy requirements),
## HPPlus raising hero HP, CastDelay minus the cooldown bonus, preparation
## BuffClass bonuses through the UIUnit denominator, reroll cost, Orim NPC
## role/exp/attacks/groups and the save validator. Actual Main gets the
## in-field Orim panel. With the original ZIP installed the real tables are
## counted too.
const MODEL = preload("res://scripts/orim523/orim523.gd")
const RUN = preload("res://scripts/orim523/orim523_run.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ORIM523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

class Rows extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array: return tables.get(table,[])
	func related(table: String, field: String, id: int) -> Array:
		var out: Array = []
		for row: Dictionary in tables.get(table,[]):
			if typeof(row.get(field)) in [TYPE_INT,TYPE_FLOAT] and int(row[field])==id: out.append(row)
		return out

func synthetic() -> Rows:
	var src := Rows.new()
	src.tables = {
		"Unit":[{"ID":1.0,"Name":"Value"},{"ID":3.0,"Name":"Percentage"}],
		"UIUnit":[{"ID":1.0,"UnitID":1.0,"Denominator":0.0},{"ID":3.0,"UnitID":3.0,"Denominator":10000.0}],
		"TargettingType":[{"ID":1.0,"Name":"Self"},{"ID":2.0,"Name":"SingleObject"}],
		"Land":[{"ID":48752.0,"Name":"[오림의 흔적][1 스테이지] 게렝의 집","AssetPath":"13459/"}],
		"Territories":[{"ID":224812.0,"LandID":48752.0,"StartX":10.0,"StartY":20.0,"EndX":12.0,"EndY":22.0},{"ID":225672.0,"LandID":48752.0,"StartX":30.0,"StartY":30.0,"EndX":31.0,"EndY":31.0}],
		"OrimsTrailStage":[{"ID":2.0,"StageIndex":1.0,"TeleportTerritoryID":224812.0,"TimeLimit":420.0,"IsHard":false},{"ID":111.0,"StageIndex":1.0,"TeleportTerritoryID":224812.0,"TimeLimit":420.0,"IsHard":true}],
		"UIOrimsTrailStage":[{"ID":12.0,"StageName":"1. 대마법사 저지 작전","StoryDescID":9001.0,"OrimsTrailStageIndex":1.0}],
		"DescData_Korean":[{"ID":9001.0,"Description":"이야기"},{"ID":9101.0,"Description":"늑대인간"},{"ID":9102.0,"Description":"대마법사 게렝"}],
		"OrimsTrailCharacter":[
			{"ID":2.0,"Name":"카스파","SpriteID":23755.0,"OrimsTrailSpellClassID":2.0,"Hp":350.0,"Sp":20.0,"Probability":175.0,"PortraitNode":"Nd_Normal"},
			{"ID":12.0,"Name":"발터자르","SpriteID":23765.0,"OrimsTrailSpellClassID":62.0,"Hp":400.0,"Sp":20.0,"Probability":175.0,"PortraitNode":"Nd_Normal"},
			{"ID":43.0,"Name":"제온","SpriteID":25543.0,"OrimsTrailSpellClassID":2.0,"Hp":450.0,"Sp":20.0,"Probability":150.0,"PortraitNode":"Nd_Hidden_Xeon"}],
		"UIOrimsTrailCharacter":[{"ID":2.0,"OrimsTrailCharacterID":2.0,"Name":"불의 카스파","SubTitle":"지옥의 불꽃","StoryDescID":9001.0}],
		"OrimsTrailExperience":[{"ID":3.0,"Level":3.0,"Experience":300.0,"IsHard":false},{"ID":1.0,"Level":1.0,"Experience":0.0,"IsHard":false},{"ID":2.0,"Level":2.0,"Experience":100.0,"IsHard":false},
			{"ID":11.0,"Level":1.0,"Experience":0.0,"IsHard":true},{"ID":12.0,"Level":2.0,"Experience":50.0,"IsHard":true}],
		"OrimsTrailSpellType":[{"ID":2.0,"Name":"Attack"},{"ID":12.0,"Name":"Utility"},{"ID":31.0,"Name":"Synergy"}],
		"OrimsTrailSpellMaxCount":[{"ID":2.0,"SpellTypeID":2.0,"MaxCount":2.0},{"ID":12.0,"SpellTypeID":12.0,"MaxCount":2.0},{"ID":31.0,"SpellTypeID":31.0,"MaxCount":1.0}],
		"OrimsTrailSpellGroup":[{"ID":2.0,"Name":"파이어 볼","DescID":0.0},{"ID":12.0,"Name":"어스퀘이크","DescID":0.0},{"ID":52.0,"Name":"최대 HP","DescID":0.0},
			{"ID":62.0,"Name":"쿨타임 감소","DescID":0.0},{"ID":433.0,"Name":"토탈 리커버리","DescID":0.0},{"ID":511.0,"Name":"이계의 마왕","DescID":0.0}],
		"OrimsTrailSpellClass":[
			{"ID":2.0,"Name":"파이어 볼(Lv 0)","SpellGroupID":2.0,"SpellLevel":0.0,"SpellTypeID":2.0,"CastGroupID":232.0,"IsHidden":false},
			{"ID":12.0,"Name":"파이어 볼(Lv 1)","SpellGroupID":2.0,"SpellLevel":1.0,"SpellTypeID":2.0,"CastGroupID":922.0,"IsHidden":false},
			{"ID":62.0,"Name":"어스퀘이크(Lv 0)","SpellGroupID":12.0,"SpellLevel":0.0,"SpellTypeID":2.0,"CastGroupID":242.0,"IsHidden":false},
			{"ID":72.0,"Name":"최대 HP(Lv 0)","SpellGroupID":52.0,"SpellLevel":0.0,"SpellTypeID":12.0,"CastGroupID":252.0,"IsHidden":false},
			{"ID":82.0,"Name":"쿨타임 감소(Lv 0)","SpellGroupID":62.0,"SpellLevel":0.0,"SpellTypeID":12.0,"CastGroupID":262.0,"IsHidden":false},
			{"ID":92.0,"Name":"토탈 리커버리(Lv 0)","SpellGroupID":433.0,"SpellLevel":0.0,"SpellTypeID":12.0,"CastGroupID":272.0,"IsHidden":true},
			{"ID":102.0,"Name":"이계의 마왕(Lv 0)","SpellGroupID":511.0,"SpellLevel":0.0,"SpellTypeID":31.0,"CastGroupID":282.0,"IsHidden":false}],
		"OrimsTrailMultipleSpellCastGroupEntity":[
			{"ID":1.0,"CastGroupID":232.0,"Order":1.0,"TargettingTypeID":12.0,"SpellClassID":74442.0,"NextSpellDelay":0.0},
			{"ID":2.0,"CastGroupID":922.0,"Order":2.0,"TargettingTypeID":12.0,"SpellClassID":74452.0,"NextSpellDelay":100.0},
			{"ID":3.0,"CastGroupID":922.0,"Order":1.0,"TargettingTypeID":12.0,"SpellClassID":74442.0,"NextSpellDelay":100.0},
			{"ID":4.0,"CastGroupID":242.0,"Order":1.0,"TargettingTypeID":12.0,"SpellClassID":74442.0,"NextSpellDelay":0.0},
			{"ID":5.0,"CastGroupID":252.0,"Order":1.0,"TargettingTypeID":2.0,"SpellClassID":75602.0,"NextSpellDelay":0.0},
			{"ID":6.0,"CastGroupID":262.0,"Order":1.0,"TargettingTypeID":2.0,"SpellClassID":75662.0,"NextSpellDelay":0.0}],
		"SpellClass":[
			{"ID":74442.0,"Name":"[오림의 흔적] 파이어 볼 (lv 0)","CastDelay":2000.0,"TargetAreaRadius":2.0,"CastRange":7.0,"TargettingTypeID":2.0,"EffectSpriteID":0.0,"IconID":0.0},
			{"ID":74452.0,"Name":"[오림의 흔적] 파이어 볼 (lv 1)","CastDelay":1800.0,"TargetAreaRadius":2.0,"CastRange":7.0,"TargettingTypeID":2.0,"EffectSpriteID":0.0,"IconID":0.0},
			{"ID":75602.0,"Name":"[오림의 흔적] 최대 HP (Lv 0)","CastDelay":0.0,"TargetAreaRadius":0.0,"CastRange":0.0,"TargettingTypeID":1.0,"EffectSpriteID":0.0,"IconID":0.0},
			{"ID":75662.0,"Name":"[오림의 흔적] 스킬 쿨타임 감소 (lv 0)","CastDelay":0.0,"TargetAreaRadius":0.0,"CastRange":0.0,"TargettingTypeID":1.0,"EffectSpriteID":0.0,"IconID":0.0}],
		"BonusType":[{"ID":1.0,"Name":"SpellDamageBase","UnitID":1.0},{"ID":2.0,"Name":"BuffClassID","UnitID":1.0},{"ID":3.0,"Name":"HPPlus","UnitID":1.0},
			{"ID":4.0,"Name":"OrimsTrailSpellCastDelayDecreasePercent","UnitID":3.0},{"ID":5.0,"Name":"MoveSpeedBonus","UnitID":3.0},{"ID":6.0,"Name":"AttackSpeedBonus","UnitID":3.0},
			{"ID":7.0,"Name":"RunSpritePoint","UnitID":1.0},{"ID":8.0,"Name":"ExperienceAdditionPercent","UnitID":3.0}],
		"Bonus":[{"ID":1.0,"BonusTypeID":1.0,"Value":22.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":2.0,"BonusTypeID":2.0,"Value":71612.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":3.0,"BonusTypeID":3.0,"Value":115.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":4.0,"BonusTypeID":2.0,"Value":72002.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":5.0,"BonusTypeID":4.0,"Value":500000.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":6.0,"BonusTypeID":5.0,"Value":250000.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":7.0,"BonusTypeID":6.0,"Value":250000.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0},
			{"ID":8.0,"BonusTypeID":7.0,"Value":1.0,"BonusApplicationTypeID":394.0,"BonusApplicationTargetID":1.0},
			{"ID":9.0,"BonusTypeID":1.0,"Value":30.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0}],
		"SpellBonus":[{"ID":1.0,"SpellClassID":74442.0,"BonusID":1.0,"MinSpellLevel":0.0},{"ID":2.0,"SpellClassID":75602.0,"BonusID":2.0,"MinSpellLevel":0.0},
			{"ID":3.0,"SpellClassID":75662.0,"BonusID":4.0,"MinSpellLevel":0.0},{"ID":4.0,"SpellClassID":74452.0,"BonusID":9.0,"MinSpellLevel":0.0}],
		"BuffClass":[{"ID":71612.0,"Name":"최대 HP"},{"ID":72002.0,"Name":"쿨감"},{"ID":71672.0,"Name":"[오림의 흔적][가속] 1단 (헤이스트)"}],
		"BuffBonus":[{"ID":1.0,"BuffClassID":71612.0,"BonusID":3.0,"MinSpellLevel":0.0},{"ID":2.0,"BuffClassID":72002.0,"BonusID":5.0,"MinSpellLevel":0.0},
			{"ID":3.0,"BuffClassID":71672.0,"BonusID":6.0,"MinSpellLevel":0.0},{"ID":4.0,"BuffClassID":71672.0,"BonusID":7.0,"MinSpellLevel":0.0},{"ID":5.0,"BuffClassID":71672.0,"BonusID":8.0,"MinSpellLevel":0.0}],
		"OrimsTrailSynergySpellCombination":[{"ID":1.0,"ResultSpellGroupID":511.0}],
		"OrimsTrailSynergySpellCombinationRequirement":[{"ID":1.0,"CombinationID":1.0,"SpellGroupID":2.0,"MinSpellLevel":0.0,"DisplayPriority":2.0},{"ID":2.0,"CombinationID":1.0,"SpellGroupID":52.0,"MinSpellLevel":0.0,"DisplayPriority":1.0}],
		"OrimsTrailSynergySpellCombinationReward":[{"ID":1.0,"CombinationID":1.0,"RewardID":314131.0}],
		"Reward":[{"ID":314131.0,"RewardTypeID":2.0,"RewardClassID":299361.0,"Amount":1.0,"ItemBlessCodeID":1.0}],
		"ItemClass":[{"ID":299361.0,"Name":"[오림의 흔적][n차] 시너지 스킬 보상 상자 (이벤트) - 기간삭제"}],
		"OrimsTrailRerollCurrencyCost":[{"ID":1.0,"RerollCount":1.0,"Cost":10.0},{"ID":51.0,"RerollCount":6.0,"Cost":20.0}],
		"OrimsTrailBuff":[{"ID":2.0,"BuffClassID":71672.0,"CurrencyID":1.0,"CurrencyCost":200000.0}],
		"OrimsTrailNpcType":[{"ID":1.0,"Name":"Monster"},{"ID":21.0,"Name":"Boss"}],
		"OrimsTrailNpc":[{"ID":1.0,"NpcClassID":79052.0,"OrimsTrailNpcTypeID":1.0},{"ID":2.0,"NpcClassID":79142.0,"OrimsTrailNpcTypeID":21.0}],
		"NpcClass":[{"ID":79052.0,"Name":"[오림의 흔적] 늑대인간","DescId":9101.0,"HP":50.0,"MP":0.0,"AC":-1.0,"MR":0.0,"Exp":100.0,"Sprite":1234.0},
			{"ID":79142.0,"Name":"[오림의 흔적] 게렝","DescId":9102.0,"HP":4000.0,"MP":0.0,"AC":-1.0,"MR":0.0,"Exp":100.0,"Sprite":1235.0}],
		"NpcAttack":[{"ID":1.0,"NpcClassID":79052.0,"IsSpell":false,"DiceCount":2.0,"DiceSpots":3.0,"DiceBonus":1.0}],
		"OrimsTrailSpawn":[{"ID":1.0,"StageID":2.0,"Second":10.0,"NpcClassID":0.0,"NpcGroupID":15442.0,"Count":5.0,"Level":1.0,"TerritoriesID":225672.0,"RelativeShapeID":0.0,"Randomly":true}],
		"NpcClassForNpcGroup":[{"ID":1.0,"NpcGroupID":15442.0,"NpcClassID":79052.0}],
		"OrimsTrailConstant":[{"ID":22.0,"Value":174.0,"OrimsTrailConstantType":22.0,"ServerLimitSetID":0.0}]}
	return src

func rules() -> Dictionary:
	var data: Dictionary = MODEL.build(synthetic())
	if not check(data.get("ok",false),"synthetic model builds: "+str(data.get("problem",""))): return data
	var stage: Dictionary = data.stages[2]
	check(int(stage.land_id)==48752 and str(stage.asset_path)=="13459/" and int(stage.territory.StartX)==10 and int(stage.time_limit)==420 and not bool(stage.hard),"stage -> Territory -> Land 48752 (13459/)")
	check(bool(data.stages[111].hard) and str(stage.name)=="1. 대마법사 저지 작전" and str(stage.story)=="이야기","hard stage separate; UI stage name/story by StageIndex")
	check(data.characters.size()==3 and bool(data.characters[2].hidden) and not bool(data.characters[0].hidden),"Nd_Hidden_* hero is marked hidden")
	check(RUN.selectable(data).size()==3,"hidden hero selectable from the start (user decision 2026-11-13)")
	var synergy: Dictionary = RUN.synergy_for(data,511)
	check(int(synergy.get("id",0))==1 and synergy.reward_rows.size()==1 and int(synergy.reward_rows[0].row.RewardClassID)==299361 and int(synergy.reward_rows[0].row.Amount)==1 and str(synergy.reward_rows[0].name).contains("시너지 스킬 보상 상자"),"synergy reward row -> original box item 299361 x1")
	check(RUN.synergy_receipt(synergy)=="orim_synergy:1" and RUN.synergy_for(data,2).is_empty(),"one ledger key per combination; ordinary skills have none")
	check(data.curves.normal==[0,100,300] and data.curves.hard==[0,50],"curves sorted by Level, normal/hard apart")
	check(MODEL.level_for(data.curves.normal,99)==1 and MODEL.level_for(data.curves.normal,100)==2 and MODEL.level_for(data.curves.normal,5000)==3,"cumulative level reading")
	check(data.max_count=={"Attack":2,"Utility":2,"Synergy":1},"OrimsTrailSpellMaxCount by type")
	var fire: Dictionary = data.spells[74442]
	check(int(fire.delay_ms)==2000 and int(fire.radius)==2 and int(fire.range)==7 and int(fire.effects.damage)==22 and str(fire.targeting)=="SingleObject","SpellClass CastDelay/area/range + SpellDamageBase")
	check(int(data.spells[75602].effects.max_hp)==115 and data.spells[75602].buff_ids==[71612],"BuffClassID -> BuffBonus HPPlus 115")
	check(is_equal_approx(float(data.spells[75662].effects.cooldown),50.0),"OrimsTrailSpellCastDelayDecreasePercent 500000 / UIUnit 10000 = 50%")
	check(data.casts[922].map(func(e: Dictionary)->int: return int(e.spell))==[74442,74452],"cast group entries in Order")
	var haste: Dictionary = data.buffs[0]
	check(int(haste.cost)==200000 and int(haste.currency)==1 and is_equal_approx(float(haste.effects.move_speed),25.0) and is_equal_approx(float(haste.effects.attack_speed),25.0),"preparation buff: 200000 아데나, move/attack +25%")
	check(haste.held.size()==1 and str(haste.held[0].type)=="RunSpritePoint","conditional RunSpritePoint kept as held, not applied")
	check(str(data.npc[79052].type)=="Monster" and int(data.npc[79052].exp)==100 and str(data.npc[79052].name)=="늑대인간" and data.npc[79052].attacks.size()==1,"Orim NPC role/exp/name/attack")
	check(str(data.npc[79142].type)=="Boss" and data.npc_groups[15442]==[79052],"boss role and NpcGroup members")
	check(RUN.reroll_cost(data,1)==10 and RUN.reroll_cost(data,6)==20 and RUN.reroll_cost(data,11)==-1,"OrimsTrailRerollCurrencyCost by count")
	return data

func flow(data: Dictionary) -> void:
	var xeon: Dictionary = RUN.start(data,43)
	check(int(xeon.get("hero_hp",0))==450 and xeon.get("spells",{})=={"2":0},"hidden hero starts with its original HP 450 and start skill")
	var orim: Dictionary = RUN.start(data,2)
	check(int(orim.hero_hp)==350 and int(orim.hero_max)==350 and orim.spells=={"2":0},"Kaspa: HP 350, start skill 파이어 볼 Lv0")
	var b: Dictionary = RUN.start(data,12)
	check(b.spells=={"12":0},"Balthazar starts with 어스퀘이크 Lv0")
	check(RUN.gain(data,orim,100,false)==1 and int(orim.level)==2 and int(orim.pending)==1,"100 exp -> Lv2, one card pick pending")
	check(RUN.gain(data,orim,1000,true)==0 and int(orim.level)==2,"hard curve tops out at its own last row")
	var pool: Array = RUN.candidates(data,orim)
	check(pool==[2,12,52,62],"cards: upgrade owned, new under MaxCount, IsHidden Lv0 and unmet synergy left out: "+str(pool))
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	check(RUN.offer(data,orim,rng).size()==RUN.OFFER_COUNT,"three cards shown")
	orim.offer = [52]
	check(not RUN.choose(data,orim,2).ok,"a card not shown is refused")
	var picked: Dictionary = RUN.choose(data,orim,52)
	check(picked.ok and orim.spells.get("52")==0 and int(orim.hero_max)==465 and int(orim.hero_hp)==465 and int(orim.pending)==0,"HPPlus 115 raises hero HP 350 -> 465")
	check(RUN.candidates(data,orim).has(511),"synergy result offered once 파이어 볼 + 최대 HP are owned")
	orim.spells["511"] = 0
	check(not RUN.candidates(data,orim).has(511),"synergy owned is not offered again")
	orim.spells["12"] = 0
	check(not RUN.candidates(data,orim).has(12) or orim.spells.has("12"),"attack MaxCount 2 respected")
	orim.spells.erase("12")
	var casters: Array = RUN.casters(data,orim)
	check(casters.size()==1 and int(casters[0].cooldown_ms)==2000,"파이어 볼 casts every 2000 ms")
	orim.spells["62"] = 0
	casters = RUN.casters(data,orim)
	check(casters.size()==1 and int(casters[0].cooldown_ms)==1000,"쿨타임 감소 50% -> 1000 ms")
	orim.spells["2"] = 1
	check(RUN.casters(data,orim).size()==2,"Lv1 cast group casts both of its entries")
	check(is_equal_approx(float(RUN.buff_effects(data,{"71672":true}).move_speed),25.0) and float(RUN.buff_effects(data,{}).move_speed)==0.0,"bought preparation buff only")
	check(RUN.valid(data,orim),"run state validates")
	var bad: Dictionary = orim.duplicate(true); bad.spells["2"] = 9
	check(not RUN.valid(data,bad),"unknown skill level refused")
	bad = orim.duplicate(true); bad.character = 999
	check(not RUN.valid(data,bad),"unknown hero refused")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(orim))
	check(RUN.valid(data,roundtrip) and RUN.hero_max(data,roundtrip)==int(orim.hero_max),"state survives a JSON save round trip (floats)")
	evidence["synthetic"] = {"spells":orim.spells,"hero_max":orim.hero_max}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	var job: String = str(world.get("job_class")) if not str(world.get("job_class")).is_empty() else "기사"
	check(QA.enter_game(world,job),"actual Main map entry")
	var panel: Node = world.hud.find_child("Orim523Hud",true,false)
	check(panel!=null and not panel.visible,"in-field Orim panel present and hidden with no run")
	check(world.dungeon_play.orim_status().is_empty(),"no Orim run status")
	check(world.has_method("orim_enter_land") and world.has_method("orim_current_land"),"original Land travel hooks")
	world.queue_free()
	await process_frame

func installed() -> void:
	MODEL.release()
	var data: Dictionary = MODEL.installed()
	if not check(data.get("ok",false),"original Orim tables: "+str(data.get("problem",""))): return
	evidence["original"] = data.counts
	check(int(data.counts.stages)==20 and int(data.counts.characters)==6 and int(data.counts.groups)==48 and int(data.counts.spell_levels)==288,"20 stages, 6 heroes, 48 skill groups, 288 skill levels")
	check(int(data.counts.npc)==244 and int(data.counts.curve_normal)==99 and int(data.counts.curve_hard)==99 and int(data.counts.reroll)==10 and int(data.counts.buffs)==4,"244 NPCs, 99+99 levels, 10 rerolls, 4 buffs")
	check(RUN.selectable(data).size()==6,"all 6 heroes selectable (2 hidden open)")
	var boxes: int = 0
	for synergy: Dictionary in data.synergies: boxes += synergy.reward_rows.size()
	check(boxes==7,"7 synergy reward rows resolved")
	check(int(data.stages[2].land_id)==48752,"stage 2 -> Land 48752")
	MODEL.release()

func run() -> void:
	var data: Dictionary = rules()
	if data.get("ok",false): flow(data)
	await runtime()
	if not SOURCE.not_installed(): installed()
	print("ORIM523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
