extends RefCounted
## UNVERIFIED: original reward references only; no draw, choice, grant, or save.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

static func _reference(table: String, id: Variant) -> Dictionary:
	return {"table":table,"id":id}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _lookup(table: String, id: Variant, owner: Dictionary, unresolved: Array[Dictionary]) -> Dictionary:
	if not _integer(id):
		unresolved.append({"from":owner,"target":_reference(table,id),"reason":"source_reference_is_not_an_integer"})
		return {}
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(id))
	if matches.size()!=1:
		unresolved.append({"from":owner,"target":_reference(table,id),"reason":"source_row_missing_or_ambiguous",
			"status":"missing_source_reference" if matches.is_empty() else "ambiguous_source_reference",
			"matches":matches,"source_problem":SOURCE.problem()})
		return {}
	return matches[0]

static func _metadata(table: String, id: int) -> Dictionary:
	return {"identity":SOURCE.identity(),"root":_reference(table,id),"reference_only":true,"can_activate":false}

static func _source_exclusion(table: String, row: Dictionary, evidence: Array[Dictionary]) -> Dictionary:
	if row.is_empty(): return {}
	var declaration: Dictionary = SOURCE.declared_exclusion(table,row)
	if not declaration.is_empty(): evidence.append({"table":table,"row":row,"evidence":declaration})
	return declaration

static func _reward_edge(table: String, row: Dictionary, pending: Array[int], queued: Dictionary, unresolved: Array[Dictionary], exclusions: Array[Dictionary]) -> Dictionary:
	var child: Variant = row.get("RewardID")
	var edge: Dictionary = {"row":row,"reward_ref":_reference("Reward",child),"reference_only":true,"can_activate":false}
	var declaration: Dictionary = _source_exclusion(table,row,exclusions)
	if not declaration.is_empty():
		edge["excluded"] = true
		edge["declared_exclusion"] = declaration
		return edge
	if not _integer(child):
		unresolved.append({"from":_reference(table,row.get("ID")),"target":edge.reward_ref,"reason":"source_reference_is_not_an_integer"})
		return edge
	var key: String = str(int(child))
	if not queued.has(key):
		queued[key] = true
		pending.append(int(child))
	return edge

static func bag(id: int) -> Dictionary:
	var result: Dictionary = _metadata("LuckyBagClass",id)
	var unresolved: Array[Dictionary] = []
	var original: Dictionary = _lookup("LuckyBagClass",id,result.root,unresolved)
	var entities: Array[Dictionary] = []
	var excluded_items: Array[Dictionary] = []
	if not original.is_empty():
		# Exact existing compiler joins: LuckyBagEntityView.LuckyBagClassID,
		# then LuckyBagEntityClassLimit.LuckyBagEntityID -> Class.ID.
		for source_entity: Dictionary in SOURCE.related("LuckyBagEntityView","LuckyBagClassID",id):
			var entity_ref: Dictionary = _reference("LuckyBagEntityView",source_entity.get("ID"))
			var kind: Dictionary = _lookup("LuckyBagEntityType",source_entity.get("LuckyBagEntityTypeID"),entity_ref,unresolved)
			var item: Dictionary = _lookup("ItemClass",source_entity.get("ItemClassID"),entity_ref,unresolved)
			var limits: Array[Dictionary] = []
			if _integer(source_entity.get("ID")):
				for limit: Dictionary in SOURCE.related("LuckyBagEntityClassLimit","LuckyBagEntityID",int(source_entity.ID)):
					var character_class: Dictionary = _lookup("Class",limit.get("ClassID"),entity_ref,unresolved)
					limits.append({"row":limit,"character_class":character_class})
			else:
				unresolved.append({"from":result.root,"target":entity_ref,"reason":"source_entity_id_is_not_an_integer"})
			var excluded: bool = item.get("TestItem") == true
			if excluded: excluded_items.append(_reference("ItemClass",item.get("ID")))
			entities.append({
				"row":source_entity,"entity_type":kind,"item_class":item,"class_limits":limits,
				"probability_raw":source_entity.get("Probability"),"amount_raw":source_entity.get("ItemAmount"),
				"bless_raw":source_entity.get("ItemBlessCodeID"),"initial_enchant_raw":source_entity.get("ItemEnchant"),
				"limit_class_raw":source_entity.get("LimitClass"),
				"excluded":excluded,"exclusion_reason":"source_test_item" if excluded else "",
				"reference_only":true,"can_activate":false,
			})
	result.merge({"ok":not original.is_empty(),"lucky_bag_class":original,"entities":entities,
		"unresolved":unresolved,"excluded_item_refs":excluded_items,"join_complete":not original.is_empty() and unresolved.is_empty()})
	return result

static func reward(id: int) -> Dictionary:
	var result: Dictionary = _metadata("Reward",id)
	var unresolved: Array[Dictionary] = []
	var rewards: Dictionary = {}
	var selections: Dictionary = {}
	var random_rewards: Dictionary = {}
	var complex_groups: Dictionary = {}
	var unfollowed: Array[Dictionary] = []
	var excluded_items: Array[Dictionary] = []
	var exclusions: Array[Dictionary] = []
	var pending: Array[int] = [id]
	var queued: Dictionary = {str(id):true}
	# Each definition ID is joined once. Source relationship arrays retain
	# order/multiplicity; cycles remain ID edges, never nested execution.
	while not pending.is_empty():
		var reward_id: int = pending.pop_front()
		var reward_ref: Dictionary = _reference("Reward",reward_id)
		var original: Dictionary = _lookup("Reward",reward_id,reward_ref,unresolved)
		if original.is_empty(): continue
		var node: Dictionary = {
			"row":original,"reward_type":{},"character_class":{},
			"character_class_id_raw":original.get("CharacterClassID"),"no_character_class_limit":false,"attributes":[],
			"reference_only":true,"can_activate":false,
		}
		rewards[str(reward_id)] = node
		var declaration: Dictionary = _source_exclusion("Reward",original,exclusions)
		if not declaration.is_empty():
			node["excluded"] = true; node["declared_exclusion"] = declaration
			continue
		var kind: Dictionary = _lookup("RewardType",original.get("RewardTypeID"),reward_ref,unresolved)
		node.reward_type = kind
		var type_exclusion: Dictionary = _source_exclusion("RewardType",kind,exclusions)
		if not type_exclusion.is_empty():
			node["excluded"] = true; node["declared_type_exclusion"] = type_exclusion
			continue
		# The existing resolver defines zero as no class restriction, not Class0.
		var class_id: Variant = original.get("CharacterClassID")
		if _integer(class_id) and int(class_id)==0:
			node.no_character_class_limit = true
		else:
			node.character_class = _lookup("Class",class_id,reward_ref,unresolved)
		node.attributes = SOURCE.related("RewardAttribute","RewardID",reward_id)
		if kind.get("Name") == "Item":
			var item: Dictionary = _lookup("ItemClass",original.get("RewardClassID"),reward_ref,unresolved)
			var item_exclusion: Dictionary = _source_exclusion("ItemClass",item,exclusions)
			var test: Variant = item.get("TestItem")
			var excluded: bool = (typeof(test)==TYPE_BOOL and test) or not item_exclusion.is_empty()
			node["item_class"] = item
			node["test_declaration"] = {"field":"TestItem","present":item.has("TestItem"),"value":test}
			node["amount_raw"] = original.get("Amount")
			node["bless_raw"] = original.get("ItemBlessCodeID")
			# Reward declares no initial item enchant. In particular,
			# RewardEnhancementTypeID is retained in row and never used as one.
			node["excluded"] = excluded
			node["exclusion_reason"] = "source_declared_exclusion" if not item_exclusion.is_empty() else ("source_test_item" if excluded else "")
			if not item_exclusion.is_empty(): node["declared_exclusion"] = item_exclusion
			if excluded: excluded_items.append(_reference("ItemClass",item.get("ID")))
		elif kind.get("Name") == "SelectReward":
			var selection_id: Variant = original.get("RewardClassID")
			node["select_reward_ref"] = _reference("SelectReward",selection_id)
			if not _integer(selection_id):
				unresolved.append({"from":reward_ref,"target":node.select_reward_ref,"reason":"source_reference_is_not_an_integer"})
				continue
			var key: String = str(int(selection_id))
			if selections.has(key): continue
			var selection: Dictionary = _lookup("SelectReward",selection_id,reward_ref,unresolved)
			var entities: Array[Dictionary] = []
			selections[key] = {"row":selection,"entities":entities,"reference_only":true,"can_activate":false}
			if selection.is_empty(): continue
			var selection_exclusion: Dictionary = _source_exclusion("SelectReward",selection,exclusions)
			if not selection_exclusion.is_empty():
				selections[key]["excluded"] = true; selections[key]["declared_exclusion"] = selection_exclusion
				continue
			for entity: Dictionary in SOURCE.related("SelectRewardEntity","SelectRewardID",int(selection_id)):
				entities.append(_reward_edge("SelectRewardEntity",entity,pending,queued,unresolved,exclusions))
		elif kind.get("Name") == "RandomReward":
			var random_id: Variant = original.get("RewardClassID")
			node["random_reward_ref"] = _reference("RandomReward",random_id)
			if not _integer(random_id):
				unresolved.append({"from":reward_ref,"target":node.random_reward_ref,"reason":"source_reference_is_not_an_integer"})
				continue
			var random_key: String = str(int(random_id))
			if random_rewards.has(random_key): continue
			var random_definition: Dictionary = _lookup("RandomReward",random_id,reward_ref,unresolved)
			var random_entities: Array[Dictionary] = []
			random_rewards[random_key] = {"row":random_definition,"entities":random_entities,"reference_only":true,"can_activate":false}
			if random_definition.is_empty(): continue
			var random_exclusion: Dictionary = _source_exclusion("RandomReward",random_definition,exclusions)
			if not random_exclusion.is_empty():
				random_rewards[random_key]["excluded"] = true; random_rewards[random_key]["declared_exclusion"] = random_exclusion
				continue
			# Whole original pool, including duplicate/zero-weight rows. Missing
			# probabilities do not acquire an equal-weight or denominator policy.
			for entity: Dictionary in SOURCE.related("RandomRewardEntityView","RandomRewardID",int(random_id)):
				random_entities.append(_reward_edge("RandomRewardEntityView",entity,pending,queued,unresolved,exclusions))
		elif kind.get("Name") == "ComplexReward":
			var complex_id: Variant = original.get("RewardClassID")
			node["complex_group_ref"] = _reference("ComplexRewardGroup",complex_id)
			if not _integer(complex_id):
				unresolved.append({"from":reward_ref,"target":node.complex_group_ref,"reason":"source_reference_is_not_an_integer"})
				continue
			var complex_key: String = str(int(complex_id))
			if complex_groups.has(complex_key): continue
			var complex_definition: Dictionary = _lookup("ComplexRewardGroup",complex_id,reward_ref,unresolved)
			var branches: Array[Dictionary] = []
			complex_groups[complex_key] = {"row":complex_definition,"groups":branches,"reference_only":true,"can_activate":false}
			if complex_definition.is_empty(): continue
			var complex_exclusion: Dictionary = _source_exclusion("ComplexRewardGroup",complex_definition,exclusions)
			if not complex_exclusion.is_empty():
				complex_groups[complex_key]["excluded"] = true; complex_groups[complex_key]["declared_exclusion"] = complex_exclusion
				continue
			for group: Dictionary in SOURCE.related("ComplexReward","ComplexRewardGroupID",int(complex_id)):
				var branch_entities: Array[Dictionary] = []
				var branch: Dictionary = {"row":group,"entities":branch_entities,"reference_only":true,"can_activate":false}
				branches.append(branch)
				var branch_exclusion: Dictionary = _source_exclusion("ComplexReward",group,exclusions)
				if not branch_exclusion.is_empty():
					branch["excluded"] = true; branch["declared_exclusion"] = branch_exclusion
					continue
				if not _integer(group.get("ID")):
					unresolved.append({"from":_reference("ComplexRewardGroup",complex_id),"target":_reference("ComplexReward",group.get("ID")),"reason":"source_reference_is_not_an_integer"})
					continue
				# MaxCount/ComplexRewardTypeID/probabilities stay in raw rows;
				# no guaranteed, selection or random execution is assigned here.
				for entity: Dictionary in SOURCE.related("ComplexRewardEntity","ComplexRewardID",int(group.ID)):
					branch_entities.append(_reward_edge("ComplexRewardEntity",entity,pending,queued,unresolved,exclusions))
		else:
			# Other declared reward types belong to existing effect owners.
			# Retain their typed references without inventing a target table.
			unfollowed.append({"from":reward_ref,"reward_type":kind,
				"RewardClassID":original.get("RewardClassID")})
	result.merge({"ok":rewards.has(str(id)),"root_reward_id":id,"rewards":rewards,"selections":selections,
		"random_rewards":random_rewards,"complex_groups":complex_groups,"source_exclusion_evidence":exclusions,
		"unresolved":unresolved,"unfollowed_typed_references":unfollowed,"excluded_item_refs":excluded_items,
		"join_complete":rewards.has(str(id)) and unresolved.is_empty() and unfollowed.is_empty() and exclusions.is_empty()})
	return result
