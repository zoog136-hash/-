extends RefCounted
const Native = preload("res://scripts/cards/native_collection_rules.gd")
const Slots=preload("res://scripts/cards/option_slot_definitions.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Source=preload("res://scripts/resources/current523_definition_rows.gd")

static func adapt(legacy: Dictionary, catalog: Dictionary) -> Dictionary:
	var result: Dictionary=legacy.duplicate(true)
	# Keep the ABI and saved namespace, but never populate final definitions
	# from the old card packs when the actual catalog/original is unavailable.
	result.cards=[]
	result.native_mode=Native.accepts_catalog(catalog)
	result.native_server_limits=[]
	result.patch523_server_limits=[]
	result["source_input_identity"]=Source.identity()
	result["source_problems"]=[]
	if not result.native_mode:
		result["source_unavailable"]=true
		result.source_problems.append("current_source_catalog_identity_unavailable")
		return result
	if result.source_input_identity.is_empty():
		result["source_unavailable"]=true
		result.source_problems.append("current523_source_unavailable:"+Source.problem())
		return result
	var source_aura_component: bool=ResourceLoader.exists("res://scripts/animation/source_awakening_aura.gd")
	var identities: Dictionary={}
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in catalog.get(category,[]):
			var identity: String=Cards.card_id(record)
			identities[identity]=int(identities.get(identity,0))+1
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in catalog.get(category,[]):
			var identity: String=Cards.card_id(record)
			var key: String=Slots._key(identity,1)
			if key.is_empty() or int(identities[identity])!=1:
				result.source_problems.append("invalid_or_ambiguous_catalog_card_identity:"+identity)
				continue
			var parts: PackedStringArray=key.split(":")
			if not Slots._integer(record.get("source_card_id")) or not Slots._integer(record.get("source_deck_id")) or int(record.source_card_id)!=int(parts[1]) or int(record.source_deck_id)!=int(parts[0]):
				result.source_problems.append("catalog_card_deck_mismatch:"+identity)
				continue
			var row: Dictionary=Slots.apply_reviewed_primary({"category":category,"id":identity,
				"expected_name":str(record.get("name","")),"grade":str(record.get("grade","")),
				"mapping":"exact_source_BuffCardID_deck"})
			if not row.get("source_available",false):
				result.source_problems.append(str(row.get("source_problem","source_option_unavailable")))
				continue
			var limits: Array=result.patch523_server_limits if identity.begins_with("source:m523:") else result.native_server_limits
			for limit: Dictionary in row.get("source_server_limits",[]):
				if not limit in limits:limits.append(limit)
			for text: String in row.pending_options.duplicate():
				if text.begins_with("원본 추가 옵션 슬롯 "):
					row.pending_options.erase(text)
					var replacement: String="추가 인형 소환 슬롯 11 · 같은 각성 장부 · 주 슬롯에 합산하지 않음"
					var index: int=row.bonus_options.find(text)
					if index>=0:row.bonus_options[index]=replacement
					row.applied_options.append(replacement)
			for effect: Dictionary in row.native_source.effects:
				if source_aura_component and not str(row.id).begins_with("source:m523:") and effect.type.Name=="StatusEffectID" and preload("res://scripts/cards/native_awakening_status.gd").binding(row).ok:
					effect.runtime_supported=true;effect.runtime_consumer="PR217_source_awakening_aura"
					var previous: String="StatusEffectID "+str(int(effect.bonus.Value))
					var message: String="원본 각성 시각 효과 · 원본 팩 필요"
					row.pending_options.erase(Slots.source_label(effect))
					row.pending_options.erase(previous);row.applied_options.append(message)
					var source_index: int=row.bonus_options.find(previous)
					if source_index>=0:row.bonus_options[source_index]=message
				if effect.type.Name=="InvokeOption" and int(effect.bonus.BonusApplicationTargetID) in [14463,17601,20344,20354]:
					effect.runtime_supported=true
					effect.runtime_consumer="native_option_combat_contextual_invoke"
					var probability: String="발동: "+str(float(effect.bonus.Value)/10000.0).trim_suffix(".0")+"%"
					row.pending_options.erase(Slots.source_label(effect))
					row.pending_options.erase(probability)
					row.applied_options.append(probability+" · 조건부 발동 연결")
				if effect.type.Name!="ArmorClassBonus" or int(effect.link.Level)!=1 or int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or effect.unit.Name!="Value":continue
				var value: int=int(effect.bonus.Value)
				row.stats["def"]=int(row.stats.get("def",0))+value
				var old: String="AC "+str(value);var label: String="AC -"+str(value)
				row.pending_options.erase(Slots.source_label(effect))
				row.pending_options.erase(old);row.applied_options.append(label)
				var index: int=row.bonus_options.find(old)
				if index>=0:row.bonus_options[index]=label
				effect.runtime_supported=true
				effect.runtime_consumer="existing_def_to_negative_AC"
			result.cards.append(row)
	result["source_unavailable"]=result.cards.is_empty()
	return result
