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
	var value: Dictionary = SOURCE.row(table,int(id))
	if value.is_empty():
		unresolved.append({"from":owner,"target":_reference(table,id),"reason":"source_row_missing_or_ambiguous"})
	return value

static func _metadata(table: String, id: int) -> Dictionary:
	return {"identity":SOURCE.identity(),"root":_reference(table,id),"reference_only":true,"can_activate":false}

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
	var unfollowed: Array[Dictionary] = []
	var excluded_items: Array[Dictionary] = []
	var pending: Array[int] = [id]
	var queued: Dictionary = {str(id):true}
	# Each Reward ID and each SelectReward ID is joined once. Entity rows keep
	# their explicit ID references, including duplicate edges and cycles.
	while not pending.is_empty():
		var reward_id: int = pending.pop_front()
		var reward_ref: Dictionary = _reference("Reward",reward_id)
		var original: Dictionary = _lookup("Reward",reward_id,reward_ref,unresolved)
		if original.is_empty(): continue
		var kind: Dictionary = _lookup("RewardType",original.get("RewardTypeID"),reward_ref,unresolved)
		var character_class: Dictionary = _lookup("Class",original.get("CharacterClassID"),reward_ref,unresolved)
		var node: Dictionary = {
			"row":original,"reward_type":kind,"character_class":character_class,
			"attributes":SOURCE.related("RewardAttribute","RewardID",reward_id),
			"reference_only":true,"can_activate":false,
		}
		rewards[str(reward_id)] = node
		if kind.get("Name") == "Item":
			var item: Dictionary = _lookup("ItemClass",original.get("RewardClassID"),reward_ref,unresolved)
			var excluded: bool = item.get("TestItem") == true
			node["item_class"] = item
			node["amount_raw"] = original.get("Amount")
			node["bless_raw"] = original.get("ItemBlessCodeID")
			# Reward declares no initial item enchant. In particular,
			# RewardEnhancementTypeID is retained in row and never used as one.
			node["excluded"] = excluded
			node["exclusion_reason"] = "source_test_item" if excluded else ""
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
			for entity: Dictionary in SOURCE.related("SelectRewardEntity","SelectRewardID",int(selection_id)):
				var child: Variant = entity.get("RewardID")
				var child_ref: Dictionary = _reference("Reward",child)
				entities.append({"row":entity,"reward_ref":child_ref})
				if not _integer(child):
					unresolved.append({"from":_reference("SelectRewardEntity",entity.get("ID")),"target":child_ref,"reason":"source_reference_is_not_an_integer"})
					continue
				var child_key: String = str(int(child))
				if not queued.has(child_key):
					queued[child_key] = true
					pending.append(int(child))
		else:
			# Other declared reward types belong to existing effect owners.
			# Retain their typed references without inventing a target table.
			unfollowed.append({"from":reward_ref,"reward_type":kind,
				"RewardClassID":original.get("RewardClassID")})
	result.merge({"ok":rewards.has(str(id)),"root_reward_id":id,"rewards":rewards,"selections":selections,
		"unresolved":unresolved,"unfollowed_typed_references":unfollowed,"excluded_item_refs":excluded_items,
		"join_complete":rewards.has(str(id)) and unresolved.is_empty() and unfollowed.is_empty()})
	return result
