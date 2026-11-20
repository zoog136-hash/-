extends SceneTree
## 523 magic doll / relic cards carry a 추가 슬롯 buff (SubSlotBuffClassID)
## whose summon is conditional (BonusApplicationType 461
## BuffCardSummonSlotType). That conditional branch must not void the card's
## own unconditional summon: every 523 doll and relic failed selection with
## current523_typed_buff_entity_chain_incomplete and never appeared on the
## field (user report 2026-11-20 "인형 성물 안나오고"). Synthetic rows shaped
## like [마법인형]그레그 (BuffClass 51701 -> sub-slot 92001).
const BANK=preload("res://scripts/resources/current523_source_bank.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("CURRENT523_CARD_SUBSLOT_SUMMON_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _tables(sub_condition: int, main_condition: int) -> void:
	var rows: Dictionary={
		"BuffClass":[{"ID":51701,"Name":"[마법인형]_그레그"},{"ID":92001,"Name":"[추가슬롯][마법인형]_그레그"}],
		"BuffBonus":[{"ID":1,"BuffClassID":51701,"BonusID":329281,"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0},
			{"ID":2,"BuffClassID":51701,"BonusID":329681,"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0},
			{"ID":3,"BuffClassID":51701,"BonusID":2187631,"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0},
			{"ID":4,"BuffClassID":92001,"BonusID":2179891,"CharacterLevel":0,"CharacterClass":0,"MinSpellLevel":0}],
		"Bonus":[{"ID":329281,"BonusTypeID":10,"Value":28871,"BonusApplicationTypeID":main_condition,"BonusApplicationTargetID":0},
			{"ID":329681,"BonusTypeID":11,"Value":1,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},
			{"ID":2187631,"BonusTypeID":12,"Value":92001,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},
			{"ID":2179891,"BonusTypeID":10,"Value":28871,"BonusApplicationTypeID":sub_condition,"BonusApplicationTargetID":1 if sub_condition!=0 else 0}],
		"BonusType":[{"ID":10,"Name":"BuffCardSummonNPCClassID","UnitID":20},{"ID":11,"Name":"MeleeDamage","UnitID":0},{"ID":12,"Name":"SubSlotBuffClassID","UnitID":21}],
		"Unit":[{"ID":20,"Name":"NPCClassID"},{"ID":21,"Name":"BuffClassID"}],
		"BonusApplicationType":[{"ID":0,"Name":"Character"},{"ID":461,"Name":"BuffCardSummonSlotType"}],
		"NpcClass":[{"ID":28871,"Name":"magic doll greg","Sprite":9699,"TestNPC":false}],
	}
	BANK._rows=rows
	BANK._by_id={}
	for table: String in rows:
		var by_id: Dictionary={}
		for row: Dictionary in rows[table]:by_id[int(row.ID)]=row
		BANK._by_id[table]=by_id

func _run() -> void:
	var shared: bool=BANK._shared
	var rows: Dictionary=BANK._rows
	var by_id: Dictionary=BANK._by_id
	BANK._shared=false
	var path: Array=[{"table":"BuffCard","row":{"ID":10671}}]
	_tables(461,0)
	var chains: Array=[]
	check(BANK._walk_buff(51701,path,[],chains),"a card whose 추가 슬롯 summon is conditional keeps its own summon")
	check(chains.size()==1 and int(chains[0].sprite_id)==9699,"only the unconditional summon body is selected: "+str(chains.size()))
	check(chains.size()==1 and int(chains[0].native_application_condition.BonusApplicationTypeID)==0,"the conditional 461 summon is still not admitted")
	_tables(0,0)
	chains=[]
	check(BANK._walk_buff(51701,path,[],chains) and chains.size()==2,"an unconditional 추가 슬롯 summon is still followed")
	_tables(461,461)
	chains=[]
	check(not BANK._walk_buff(51701,path,[],chains),"a card whose own summon is conditional is still refused")
	BANK._shared=shared
	BANK._rows=rows
	BANK._by_id=by_id
	print("CURRENT523_CARD_SUBSLOT_SUMMON_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
