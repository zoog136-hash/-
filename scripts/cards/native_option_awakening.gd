extends RefCounted
const DATA = preload("res://data/cards/base508_option_awakening.json")
const Native = preload("res://scripts/cards/native_collection_rules.gd")
const Slots=preload("res://scripts/cards/option_slot_definitions.gd")
static func adapt(legacy: Dictionary, catalog: Dictionary) -> Dictionary:
	if not Native.accepts_catalog(catalog): return legacy
	var result: Dictionary=legacy.duplicate(true)
	result.native_mode=true
	result.native_server_limits=DATA.data.source_server_limits
	var source_aura_component: bool=ResourceLoader.exists("res://scripts/animation/source_awakening_aura.gd")
	for original: Dictionary in DATA.data.definitions:
		var row: Dictionary=Slots.apply_reviewed_primary(original.duplicate(true))
		for text: String in row.pending_options.duplicate():
			if text.begins_with("원본 추가 옵션 슬롯 "):
				row.pending_options.erase(text)
				var replacement: String="추가 인형 소환 슬롯 11 · 같은 각성 장부 · 주 슬롯에 합산하지 않음"
				var index: int=row.bonus_options.find(text)
				if index>=0:row.bonus_options[index]=replacement
				row.applied_options.append(replacement)
		for effect: Dictionary in row.native_source.effects:
			if source_aura_component and effect.type.Name=="StatusEffectID" and preload("res://scripts/cards/native_awakening_status.gd").binding(row).ok:
				effect.runtime_supported=true;effect.runtime_consumer="PR217_source_awakening_aura"
				var previous: String="StatusEffectID "+str(int(effect.bonus.Value))
				var message: String="원본 각성 시각 효과 · 원본 팩 필요"
				row.pending_options.erase(previous);row.applied_options.append(message)
				var source_index: int=row.bonus_options.find(previous)
				if source_index>=0:row.bonus_options[source_index]=message
			if effect.type.Name=="InvokeOption" and int(effect.bonus.BonusApplicationTargetID) in [14463,17601,20344,20354]:
				effect.runtime_supported=true
				effect.runtime_consumer="native_option_combat_contextual_invoke"
				var probability: String="발동: "+str(float(effect.bonus.Value)/10000.0).trim_suffix(".0")+"%"
				row.pending_options.erase(probability)
				row.applied_options.append(probability+" · 조건부 발동 연결")
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
