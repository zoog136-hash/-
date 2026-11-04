extends SceneTree
const Slots=preload("res://scripts/cards/option_slot_definitions.gd")
const Base=preload("res://data/cards/base508_option_awakening.json")
const Doll=preload("res://scripts/cards/native_doll_subslot.gd")
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func multiset(effects: Array) -> Dictionary:
	var result: Dictionary={}
	for effect: Dictionary in effects:
		var key: String=JSON.stringify([int(effect.type.ID),int(effect.bonus.Value),int(effect.bonus.BonusApplicationTypeID),int(effect.bonus.BonusApplicationTargetID),int(effect.link.Level)])
		result[key]=int(result.get(key,0))+1
	return result
func _initialize() -> void:
	var pairs: Dictionary={2:0,98:0}
	for key: String in Slots.DATA.data.groups:
		var raw: Dictionary=Slots.DATA.data.groups[key]
		if int(raw.group.SlotIndex)!=11:continue
		var deck: int=int(raw.card.BuffCardDeckID)
		var identity: String="source:m508:"+str(deck)+":"+str(int(raw.card.ID))
		var main: Dictionary=Slots.group_for(identity,1)
		var extra: Dictionary=Slots.group_for(identity,11)
		check(int(main.group.ID)!=int(extra.group.ID) and extra.source_snapshot=="patch523","separate source groups "+key)
		var main_set: Dictionary=multiset(main.effects)
		var extra_set: Dictionary=multiset(extra.effects)
		for effect_key: String in extra_set:
			check(int(main_set.get(effect_key,0))>=int(extra_set[effect_key]),"extra effects preserve exact targets and multiplicity "+key)
		var removed: Array[String]=[]
		for effect: Dictionary in main.effects:
			var single: Dictionary=multiset([effect]);var effect_key: String=single.keys()[0]
			if int(main_set[effect_key])>int(extra_set.get(effect_key,0)):
				removed.append(str(effect.type.Name));main_set[effect_key]=int(main_set[effect_key])-1
		removed.sort()
		var expected: Array=["CarryPlus","EinasadSavingPercent","ExperienceAdditionPercent"] if deck==2 else ["ExperienceAdditionPercent","SpellCastDelayDecreasePercent"]
		check(removed==expected,"exact economic exclusions "+key)
		if deck==2:
			var runtime_group: Array=Doll.secondary_groups(identity)
			check(runtime_group.size()==1 and runtime_group[0].group==extra.group and runtime_group[0].effects==extra.effects,"doll uses contextual slot11 "+key)
		pairs[deck]=int(pairs[deck])+1
		# A caller mutating a preview must never mutate another slot or the cache.
		extra.effects.clear();extra.group.ID=-1
		check(not Slots.group_for(identity,11).effects.is_empty() and int(Slots.group_for(identity,11).group.ID)>0,"isolated source views "+key)
	check(pairs=={2:83,98:58},"all141 primary/additional pairs")
	for row: Dictionary in Base.data.definitions:
		var latest: Dictionary=Slots.group_for(row.id,1)
		var applied: Dictionary=Slots.apply_reviewed_primary(row)
		check(Slots.compatible_primary(row.id) and applied.native_source.group==latest.group and multiset(applied.native_source.effects)==multiset(latest.effects),"reviewed primary semantics match latest "+row.id)
		var view: Array=Slots.view(row.id)
		check(not view.is_empty() and int(view[0].group.SlotIndex)==1,"primary preview first "+row.id)
		if row.id=="source:m508:2:25002":
			check(applied.stats.xp==7 and applied.stats.weightBonus==500 and applied.stats.blessing_consumption_reduction_pct==3,"Mariela primary reviewed Level1 economy")
			check(not Doll.MAP.has("ExperienceAdditionPercent") and not Doll.MAP.has("EinasadSavingPercent"),"additional doll does not inherit primary economy")
	check(Slots.group_for("source:m508:1:12243",1).effects.all(func(effect: Dictionary) -> bool:return effect.type.Name!="StatusEffectID"),"Doppelganger has no invented status effect")
	for bad: String in ["source:m508:02:85","source:m508:2:-1","source:patch523:2:85","85",""]:
		check(Slots.view(bad).is_empty() and Slots.group_for(bad,11).is_empty(),"malformed identity inert "+bad)
	print("OPTION_SLOT_DEFINITIONS ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
