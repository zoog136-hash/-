extends SceneTree
## Original 523 혈맹 as the local player's own clan (scripts/clan523).
## Synthetic rows always run: creation conditions (ClanCreateGameClass,
## CreateLevelCondition, CreateCommission), the ClanExperience level reading,
## the ClanReward -> BuffClass -> Bonus buff mapping, donation limits and
## points, weekly rewards, MerchantGoods clan conditions, emblem grade and the
## save. In actual Main the clan buff reaches the existing buff consumers and
## the clan state survives save -> reload. With the original ZIP installed the
## real tables are also compared.
const CLAN = preload("res://scripts/clan523/clan523.gd")
const EMB = preload("res://scripts/emblem523/emblem523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BASE508 = preload("res://scripts/lineagem_base508.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CLAN523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

## A table source with the rows()/related() calls the builder uses.
class Rows extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array: return tables.get(table,[])
	func related(table: String, field: String, id: int) -> Array:
		var out: Array = []
		for row: Dictionary in tables.get(table,[]):
			if typeof(row.get(field)) in [TYPE_INT,TYPE_FLOAT] and int(row[field])==id: out.append(row)
		return out

## A world with the values the clan reads and a save that can fail.
class FakeWorld extends RefCounted:
	var level: int = 30
	var gold: int = 1000000
	var job_class: String = "군주"
	var inventory: Dictionary = {"다이아":1000}
	var item_instances: Dictionary = {}
	var save_result: int = OK
	var saves: int = 0
	func _save_game(_quiet: bool, _overrides: Dictionary = {}) -> int:
		saves += 1
		return save_result
	func _catalog_item_from_source_id(_id: String) -> Dictionary: return {}

func synthetic() -> Rows:
	var src := Rows.new()
	# Floats, as the original archive delivers numbers.
	src.tables = {
		"ClanExperience":[{"Level":2.0,"CumulativeExperience":200.0},{"Level":1.0,"CumulativeExperience":100.0},{"Level":3.0,"CumulativeExperience":999999.0}],
		"ClanPolicies":[{"Name":"CreateLevelCondition","Value":30.0,"UnitId":0.0,"ClassId":0.0},{"Name":"CreateCommission","Value":100000.0,"UnitId":4.0,"ClassId":26.0},
			{"Name":"MaxDonateCount","Value":3.0,"UnitId":1.0,"ClassId":0.0},{"Name":"WeeklyMaxDonatePoint","Value":250.0,"UnitId":0.0,"ClassId":0.0},
			{"Name":"DonateExpRatio","Value":1.0,"UnitId":0.0,"ClassId":0.0},{"Name":"AdenaDonateID","Value":2.0,"UnitId":0.0,"ClassId":0.0}],
		"Unit":[{"ID":4.0,"Name":"ItemClassID"},{"ID":34.0,"Name":"IntangibleItemClassID"},{"ID":222.0,"Name":"ClanExperience"},{"ID":11422.0,"Name":"ClanDonatePoint"},{"ID":242.0,"Name":"Einasad"},{"ID":1.0,"Name":"Value"},{"ID":3.0,"Name":"Percentage"}],
		"ClanCreateGameClass":[{"GameClassID":8.0}],
		"Class":[{"ID":8.0,"DescID":57.0}],
		"DescData_Korean":[{"ID":57.0,"Description":"군주"},{"ID":5.0,"Description":"혈맹 군주"},{"ID":10.0,"Description":"일반"},{"ID":11.0,"Description":"고급"},{"ID":20.0,"Description":"혈맹 버프 1단계"},{"ID":30.0,"Description":"혈맹 채팅"}],
		"ClanMemberRankType":[{"ID":1.0,"Name":"Owner","DescID":5.0}],
		"Currency":[{"ID":1.0,"Name":"Adena"},{"ID":4.0,"Name":"Gem"}],
		"CurrencyUnitClass":[{"CurrencyID":1.0,"UnitID":4.0,"ClassID":26.0},{"CurrencyID":4.0,"UnitID":34.0,"ClassID":2.0}],
		"ClanDonatePolicy":[{"ClanDonateID":2.0,"DailyMaxDonatePoint":200.0}],
		"ClanDonate":[{"ID":12.0,"PaymentCurrencyID":4.0,"Amount":100.0,"DescID":11.0,"Name":"고급","SlotType":2.0},{"ID":2.0,"PaymentCurrencyID":1.0,"Amount":200000.0,"DescID":10.0,"Name":"일반","SlotType":1.0}],
		"ClanDonateReward":[{"ID":1.0,"ClanDonateID":2.0,"UnitID":222.0,"ClassID":0.0,"Amount":90.0},{"ID":2.0,"ClanDonateID":2.0,"UnitID":11422.0,"ClassID":0.0,"Amount":90.0},
			{"ID":3.0,"ClanDonateID":2.0,"UnitID":4.0,"ClassID":3631.0,"Amount":600.0},{"ID":4.0,"ClanDonateID":12.0,"UnitID":222.0,"ClassID":0.0,"Amount":150.0},
			{"ID":5.0,"ClanDonateID":12.0,"UnitID":242.0,"ClassID":0.0,"Amount":2500.0},{"ID":6.0,"ClanDonateID":12.0,"UnitID":11422.0,"ClassID":0.0,"Amount":150.0}],
		"ItemClass":[{"ID":3631.0,"DescID":0.0},{"ID":777.0,"DescID":0.0}],
		"ClanDonateWeeklyReward":[{"ID":9.0,"DonatePoint":100.0,"RewardID":900.0,"IsBonus":false}],
		"Reward":[{"ID":900.0,"RewardTypeID":2.0,"RewardClassID":777.0,"Amount":5.0,"ItemBlessCodeID":1.0},{"ID":41.0,"RewardTypeID":4.0,"RewardClassID":10761.0},{"ID":51.0,"RewardTypeID":4.0,"RewardClassID":10771.0}],
		"RewardType":[{"ID":2.0,"Name":"Item"},{"ID":4.0,"Name":"Buff"}],
		"UIClanBenefit":[{"ClanLevel":1.0,"ContentsDescID":30.0,"BuffIconAssetID":45641.0}],
		"ClanReward":[{"Level":1.0,"RewardID":41.0},{"Level":2.0,"RewardID":51.0}],
		"BuffClass":[{"ID":10761.0,"Name":"[혈맹] 버프 1단계","DescID":20.0},{"ID":10771.0,"Name":"[혈맹] 버프 2단계","DescID":0.0}],
		"BuffBonus":[{"BuffClassID":10761.0,"BonusID":1.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},
			{"BuffClassID":10771.0,"BonusID":2.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},{"BuffClassID":10771.0,"BonusID":3.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},
			{"BuffClassID":10771.0,"BonusID":4.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},{"BuffClassID":10771.0,"BonusID":5.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0}],
		"Bonus":[{"ID":1.0,"BonusTypeID":133.0,"Value":10000.0},{"ID":2.0,"BonusTypeID":17.0,"Value":4.0},{"ID":3.0,"BonusTypeID":30.0,"Value":1.0},{"ID":4.0,"BonusTypeID":114.0,"Value":3.0},
			{"ID":5.0,"BonusTypeID":17.0,"Value":2.0,"BonusApplicationTypeID":1.0}],
		"BonusType":[{"ID":133.0,"Name":"ExperienceAdditionPercent","UnitID":3.0},{"ID":17.0,"Name":"HPPlus","UnitID":1.0},{"ID":30.0,"Name":"ArmorClassBonus","UnitID":1.0},{"ID":114.0,"Name":"RangeEvasion","UnitID":1.0}],
		"UIUnit":[{"UnitID":3.0,"Denominator":10000.0}],
	}
	return src

func rules() -> Dictionary:
	var data: Dictionary = CLAN.build(synthetic())
	if not check(data.get("ok",false),"synthetic rows build: "+str(data.get("problem",""))): return data
	check(data.levels.size()==3 and int(data.levels[0].level)==1 and int(data.max_level)==3,"ClanExperience sorted by Level")
	check(CLAN.level_for(data.levels,0)==1 and CLAN.level_for(data.levels,99)==1 and CLAN.level_for(data.levels,100)==2 and CLAN.level_for(data.levels,200)==3 and CLAN.level_for(data.levels,9999999)==3,"CumulativeExperience of L completes L; capped at the last level")
	check(data.create_classes==[8] and data.create_class_names==["군주"] and data.owner_rank=="혈맹 군주","ClanCreateGameClass 8 (군주) and Owner rank text")
	check(data.donates.size()==2 and int(data.donates[0].id)==2 and data.donates[0].name=="일반","donations in SlotType order with DescData names")
	check(CLAN.payment_wallet(data.by_donate[2].payment)=="아데나" and CLAN.payment_wallet(data.by_donate[12].payment)=="다이아","Adena -> 아데나, Gem (Intangible 2) -> 다이아")
	var one: Dictionary = data.buffs[1]
	check(one.effects=={"xp":1} and one.name=="혈맹 버프 1단계","ExperienceAdditionPercent 10000 / 10000 = 1 percent point")
	var two: Dictionary = data.buffs[2]
	check(two.effects=={"hp_flat":4,"def":1},"HPPlus -> hp_flat, ArmorClassBonus -> def (Value)")
	var held: Array = []
	for row: Dictionary in two.held: held.append(str(row.type))
	check(held==["RangeEvasion","HPPlus"],"no consumer (RangeEvasion) and conditional rows are held, not applied")
	check(str(data.benefits[1].text)=="혈맹 채팅" and int(data.benefits[1].icon_asset_id)==45641,"UIClanBenefit text and icon asset")
	var bad: Rows = synthetic()
	bad.tables.ClanCreateGameClass = []
	check(not CLAN.build(bad).get("ok",true),"no ClanCreateGameClass row: unavailable")
	return data

func flow(data: Dictionary) -> void:
	CLAN.use_definition(data)
	var clan := CLAN.new()
	clan.now_override = 1800000000
	var world := FakeWorld.new()
	check(CLAN._class_id(world)==8,"군주 is original class 8")
	world.job_class = "기사"
	check(not clan.create_quote(world).ok,"a 기사 cannot found a clan")
	world.job_class = "군주"; world.level = 29
	check(not clan.create_quote(world).ok,"below CreateLevelCondition")
	world.level = 30; world.gold = 99999
	check(not clan.create_quote(world).ok,"commission not affordable")
	world.gold = 1000000
	check(not clan.create(world,"   ").ok and not clan.has_clan(),"empty name refused")
	world.save_result = ERR_CANT_CREATE
	check(not clan.create(world,"황혼").ok and not clan.has_clan() and world.gold==1000000,"failed save keeps no clan and the adena")
	world.save_result = OK
	var created: Dictionary = clan.create(world,"황혼")
	check(created.ok and clan.has_clan() and clan.level()==1 and world.gold==900000,"created: level 1, commission paid: "+str(created))
	check(clan.buff_value("xp")==1 and clan.buff_value("hp_flat")==0,"level 1 buff")
	check(not clan.create_quote(world).ok,"only one clan")
	var first: Dictionary = clan.donate(world,2)
	evidence["donate"] = first
	check(first.ok and int(clan.state.experience)==90 and int(clan.state.week_points)==90 and world.gold==700000,"adena donation: 90 exp and points, 200,000 paid")
	check(first.withheld.size()==1 and str(first.withheld[0]).contains("600"),"an item without a game owner is withheld and named")
	var second: Dictionary = clan.donate(world,2)
	check(second.ok and clan.level()==2 and clan.buff_value("hp_flat")==4 and clan.buff_value("def")==1,"180 exp -> level 2 buff")
	check(not clan.donate_quote(world,2).ok,"DailyMaxDonatePoint 200 refuses a third 90-point adena donation")
	var gem: Dictionary = clan.donate(world,12)
	check(gem.ok and int(world.inventory["다이아"])==900 and int(clan.state.week_points)==250 and str(gem.withheld).contains("아인하사드"),"Gem donation, weekly points capped at WeeklyMaxDonatePoint, Einasad withheld")
	check(not clan.donate_quote(world,12).ok,"MaxDonateCount 3 per day")
	clan.now_override += 86400
	check(clan.donate_quote(world,12).ok,"the next game day allows donations again")
	var weekly: Dictionary = clan.weekly_quote(world,9)
	check(weekly.ok,"100-point weekly row reachable: "+str(weekly))
	check(not clan.claim_weekly(world,9).ok and clan.state.weekly_claimed.is_empty(),"weekly item without a game owner is refused, not marked claimed")
	# MerchantGoods clan columns
	check(clan.merchant_gate({"ClanLevelMin":2.0,"LimitMinClanLevel":2.0}).ok,"clan level 2 opens a level-2 row")
	check(not clan.merchant_gate({"ClanLevelMin":0.0,"LimitMinClanLevel":4.0}).ok,"the higher of ClanLevelMin/LimitMinClanLevel applies")
	check(not clan.merchant_gate({"ClanLevelMin":1.0,"LimitMinClanLevel":1.0,"DaysAfterClanJoin":7.0}).ok,"DaysAfterClanJoin is refused")
	check(not clan.merchant_gate({"ClanLevelMin":1.0,"LimitClanMemberRank":true}).ok,"LimitClanMemberRank is refused")
	check(not CLAN.new().merchant_gate({"ClanLevelMin":2.0}).ok and CLAN.new().merchant_gate({"ClanLevelMin":0.0}).ok,"no clan: only rows without a clan level")
	check(clan.level()==3 and clan.emblem_grade()==3,"emblem OpenGrade follows the clan level")
	# Save
	var saved: Dictionary = clan.export_state()
	check(CLAN.validate(saved).is_empty(),"exported state validates")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	var reloaded := CLAN.new()
	reloaded.import_state(parsed)
	check(reloaded.has_clan() and reloaded.level()==3 and reloaded.state.name=="황혼" and reloaded.state.experience is int,"JSON floats reload as the same clan")
	for broken: Variant in [{"schema":2},{"schema":1,"name":""},{"schema":1.0,"name":"a","created_at":-1}]:
		var target := CLAN.new()
		target.import_state(broken)
		check(not target.has_clan() and not target.problem.is_empty(),"invalid save refused: "+str(broken))
	var empty := CLAN.new()
	empty.import_state({})
	check(not empty.has_clan() and empty.problem.is_empty() and empty.level()==0 and empty.buff_value("xp")==0,"no clan: no level, no buff")

func runtime(data: Dictionary) -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world,"군주"), "actual Main map entry")
	CLAN.use_definition(data)
	check(world.get("clan523")!=null and not world.clan523.has_clan(),"the world owns an empty clan")
	var before_hp: int = world._active_item_buff_total("hp_flat")
	var before_xp: int = world._active_item_buff_total("xp")
	world.clan523.import_state({"schema":1,"name":"황혼","created_at":1,"experience":150,"day":0,"donations":{},"day_points":{},"week":0,"week_points":0,"weekly_claimed":[]})
	check(world._active_item_buff_total("hp_flat")==before_hp+4 and world._active_item_buff_total("def")>=1,"clan buff reaches the existing buff consumers")
	check(world._active_item_buff_total("xp")==before_xp,"level 2 has no xp row in the synthetic buff")
	check(world._save_game(true)==OK,"save with a clan")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://twilight_v20_save.json"))
	check(parsed is Dictionary and str(parsed.get("clan523",{}).get("name",""))=="황혼","the save holds clan523")
	world.clan523.import_state({})
	world.clan523.import_state(parsed.get("clan523",{}) if parsed is Dictionary else {})
	check(world.clan523.has_clan() and world.clan523.level()==2,"reload keeps the clan")
	check(EMB.grade_for(world)>=2,"emblem grade from the world clan")
	world.hud.call("open_clan523")
	await process_frame
	var panel: Node = world.hud.find_child("Clan523Panel",true,false)
	check(panel!=null and panel.find_child("Clan523Merchant",true,false)!=null,"clan window opens with the clan merchant button")
	world.queue_free()
	await process_frame

func installed() -> void:
	CLAN.reset_cache()
	var data: Dictionary = CLAN.definition()
	if not check(data.get("ok",false),"original clan rows validate: "+str(data.get("problem",""))): return
	evidence["original"] = {"levels":data.levels.size(),"donates":data.donates.size(),"weekly":data.weekly.size(),"l20":data.buffs[20].effects}
	check(data.levels.size()==20 and int(data.levels[0].cumulative)==4000,"ClanExperience 20 levels, level 1 completes at 4000")
	check(data.create_classes==[8] and int(data.policies.CreateLevelCondition.value)==30 and int(data.policies.CreateCommission.value)==100000,"군주, Lv.30, 100,000 아데나")
	check(data.buffs[1].effects=={"xp":1},"clan buff 1: 경험치 +1%")
	check(int(data.buffs[20].effects.get("hp_flat",0))==70 and int(data.buffs[20].effects.get("def",0))==3,"clan buff 20: HP +70, AC 3")

func run() -> void:
	var data: Dictionary = rules()
	if data.get("ok",false):
		flow(data)
		await runtime(data)
	if not SOURCE.not_installed(): installed()
	CLAN.reset_cache()
	print("CLAN523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
