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
	var source_aura_component: bool=preload("res://scripts/resources/retired_assets.gd").usable("res://scripts/animation/source_awakening_aura.gd")
	var identities: Dictionary={}
	var base_limit_sets: Dictionary={}
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in catalog.get(category,[]):
			var identity: String=Cards.card_id(record)
			identities[identity]=int(identities.get(identity,0))+1
			var raw: Dictionary=record.get("source_original",{})
			if raw.get("source_snapshot")=="patch523" and int(raw.get("server_limit_set_id",0))>0:
				base_limit_sets[int(raw.server_limit_set_id)]=true
	# Base-card activation is independent of the optional awakening slot.
	# Use every current base card's exact server rows, including cards that
	# have no source awakening definition.
	for limit_id: int in base_limit_sets:
		for row: Dictionary in Source.related("ServerLimit","ServerLimitSetID",limit_id):
			if Source.declared_exclusion("ServerLimit",row).is_empty():result.patch523_server_limits.append(row)
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
			for effect: Dictionary in row.native_source.effects:
				if source_aura_component and not str(row.id).begins_with("source:m523:") and effect.type.Name=="StatusEffectID" and preload("res://scripts/cards/native_awakening_status.gd").binding(row).ok:
					effect.runtime_supported=true;effect.runtime_consumer="PR217_source_awakening_aura"
				if effect.type.Name=="InvokeOption" and int(effect.bonus.BonusApplicationTargetID) in [14463,17601,20344,20354]:
					effect.runtime_supported=true
					effect.runtime_consumer="native_option_combat_contextual_invoke"
				if effect.type.Name!="ArmorClassBonus" or int(effect.link.Level)!=1 or int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or effect.unit.Name!="Value":continue
				var value: int=int(effect.bonus.Value)
				row.stats["def"]=int(row.stats.get("def",0))+value
				effect.runtime_supported=true
				effect.runtime_consumer="existing_def_to_negative_AC"
			row.bonus_options=Slots.labels(row.native_source)
			row.applied_options=[]
			row.pending_options=[]
			for effect: Dictionary in row.native_source.effects:
				if int(effect.link.Level)!=1:continue
				var label: String=str(effect.display_label)
				var list: Array=row.applied_options if effect.get("runtime_supported",false) else row.pending_options
				if not list.has(label):list.append(label)
			result.cards.append(row)
	result["source_unavailable"]=result.cards.is_empty()
	return result

