extends RefCounted
const DATA = preload("res://data/cards/base508_option_awakening.json")
const Native = preload("res://scripts/cards/native_collection_rules.gd")
static func adapt(legacy: Dictionary, catalog: Dictionary) -> Dictionary:
	if not Native.accepts_catalog(catalog): return legacy
	var result: Dictionary=legacy.duplicate(true)
	result.native_mode=true
	result.native_server_limits=DATA.data.source_server_limits
	for original: Dictionary in DATA.data.definitions:
		var row: Dictionary=original.duplicate(true)
		for effect: Dictionary in row.native_source.effects:
			if effect.type.Name!="ArmorClassBonus" or int(effect.link.Level)!=1 or int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or effect.unit.Name!="Value":continue
			var value: int=int(effect.bonus.Value)
			row.stats["def"]=int(row.stats.get("def",0))+value
			var old: String="AC "+str(value);var label: String="AC -"+str(value)
			row.pending_options.erase(old);row.applied_options.append(label)
			var index: int=row.bonus_options.find(old)
			if index>=0:row.bonus_options[index]=label
			effect.runtime_supported=true
			effect.runtime_consumer="existing_def_to_negative_AC"
		result.cards.append(row)
	return result
