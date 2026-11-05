extends RefCounted
## UNVERIFIED: original market/card-pool forward references only.
## No offer admission, denominator, probability sum, draw, grant or save.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _issue(context: Dictionary, owner: Dictionary, target: Dictionary, reason: String, raw: Dictionary = {}) -> void:
	context.unresolved.append({"from":owner,"target":target,"reason":reason,"raw":raw})
	if reason in ["missing_source_reference","ambiguous_source_reference","invalid_source_reference"]:
		context.blockers.append(reason+":"+str(target.get("table",target.get("namespace","unknown")))+":"+str(target.get("id",target.get("value",""))))

static func _table(context: Dictionary, table: String) -> bool:
	if not context.table_metadata.has(table): context.table_metadata[table] = SOURCE.table_metadata(table)
	var metadata: Dictionary = context.table_metadata[table]
	if metadata.get("version") != 523 or metadata.get("path") != "content/"+table+".json" or not _integer(metadata.get("row_count")):
		_issue(context,{}, {"table":table},"missing_source_reference",{"source_table_metadata":metadata,"source_problem":SOURCE.problem()})
		return false
	return true

static func _node(context: Dictionary, table: String, raw: Dictionary) -> Dictionary:
	var node: Dictionary = {"table":table,"row":raw,"reference_only":true,"can_activate":false,"excluded":false}
	if raw.is_empty(): return node
	var exclusion: Dictionary = SOURCE.declared_exclusion(table,raw)
	if not exclusion.is_empty():
		node.excluded = true
		node["declared_exclusion"] = exclusion
		context.source_exclusion_evidence.append({"table":table,"row":raw,"evidence":exclusion})
	if table == "ItemClass":
		var test: Variant = raw.get("TestItem")
		node["test_declaration"] = {"field":"TestItem","present":raw.has("TestItem"),"value":test}
		if typeof(test) == TYPE_BOOL and test:
			node.excluded = true
			node["test_exclusion_reason"] = "source_TestItem_true"
			context.source_exclusion_evidence.append({"table":table,"row":raw,"test_declaration":node.test_declaration})
		elif typeof(test) != TYPE_BOOL:
			_issue(context,{"table":table,"id":raw.get("ID")},{"table":table,"field":"TestItem","id":raw.get("ID")},"invalid_source_reference",raw)
	return node

static func _row(context: Dictionary, table: String, id: Variant, owner: Dictionary) -> Dictionary:
	if not _table(context,table): return _node(context,table,{})
	var target: Dictionary = {"table":table,"id":id}
	if not _integer(id) or int(id) < 0:
		_issue(context,owner,target,"invalid_source_reference")
		return _node(context,table,{})
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(id))
	if matches.size() != 1:
		_issue(context,owner,target,"missing_source_reference" if matches.is_empty() else "ambiguous_source_reference",{"matches":matches,"source_problem":SOURCE.problem()})
		return _node(context,table,{})
	return _node(context,table,matches[0])

static func _related(context: Dictionary, table: String, field: String, id: Variant, owner: Dictionary) -> Array:
	if not _table(context,table): return []
	if not _integer(id) or int(id) < 0:
		_issue(context,owner,{"table":table,"field":field,"id":id},"invalid_source_reference")
		return []
	return SOURCE.related(table,field,int(id))

static func _typed(row: Dictionary, unit: Dictionary) -> Dictionary:
	# ClassID has meaning only in this declared Unit namespace. Unknown units
	# never become an ItemClass/Class ID by numeric coincidence.
	return {"unit":unit,"unit_id":row.get("UnitID"),"namespace":unit.get("Name"),
		"value":row.get("ClassID"),"amount_raw":row.get("Amount"),"reference_only":true,"can_activate":false}

static func _queue_pool(context: Dictionary, id: Variant, owner: Dictionary) -> Variant:
	if not _integer(id) or int(id) < 0:
		_issue(context,owner,{"namespace":"GotChaClassID","value":id},"invalid_source_reference")
		return null
	var key: String = str(int(id))
	if not context.pools.has(key) and not context.pool_queued.has(key):
		context.pool_queued[key] = true
		context.pool_queue.append(int(id))
		context.pool_queue_owners[key] = owner
	# Only this ID is stored on an edge. A repeated or cyclic edge never embeds
	# the registry Dictionary or changes an original entry's amount/weight.
	return int(id)

static func _target(context: Dictionary, row: Dictionary, unit: Dictionary, owner: Dictionary, deferred_reason: String, allow_pool: bool = true) -> Dictionary:
	var result: Dictionary = {"typed_reference":_typed(row,unit.get("row",{})),"target":{},"pool":{},"pool_reference":null,"reference_only":true,"can_activate":false}
	if unit.get("row",{}).is_empty() or unit.get("excluded",false): return result
	# These are the exact public commerce/ticket Unit namespaces. Preserve
	# amount/conditions and read the target; no supplier or payment is executed.
	var name_value: Variant = unit.row.get("Name")
	if name_value == "ItemClassID": result.target = _row(context,"ItemClass",row.get("ClassID"),owner)
	elif name_value == "IntangibleItemClassID": result.target = _row(context,"IntangibleItemClass",row.get("ClassID"),owner)
	elif name_value == "BuffCardID": result.target = _row(context,"BuffCard",row.get("ClassID"),owner)
	elif name_value == "GotChaClassID":
		if allow_pool:
			result.pool = _pool(context,row.get("ClassID"),owner)
			if _integer(row.get("ClassID")) and int(row.ClassID) >= 0: result.pool_reference = int(row.ClassID)
		else: result.pool_reference = _queue_pool(context,row.get("ClassID"),owner)
	else:
		_issue(context,owner,result.typed_reference,deferred_reason,row)
	return result

static func _pool(context: Dictionary, id: Variant, owner: Dictionary) -> Dictionary:
	if not _integer(id) or int(id) < 0:
		_issue(context,owner,{"namespace":"GotChaClassID","value":id},"invalid_source_reference")
		return {}
	var key: String = str(int(id))
	if context.pools.has(key): return context.pools[key]
	var result: Dictionary = {"gotcha_class_id":id,"entries":[],"reference_only":true,"can_activate":false,
		"probability_contract":"verbatim_each_source_Probability; denominator_and_draw_rules_unresolved"}
	context.pools[key] = result
	var rows: Array = _related(context,"GotChaEntityView","GotChaClassID",id,owner)
	if rows.is_empty():
		_issue(context,owner,{"table":"GotChaEntityView","field":"GotChaClassID","id":id},"source_pool_relation_empty")
	for raw: Dictionary in rows:
		var entry: Dictionary = _node(context,"GotChaEntityView",raw)
		entry["probability_raw"] = raw.get("Probability")
		entry["card"] = {}
		result.entries.append(entry)
		if entry.excluded: continue
		var from: Dictionary = {"table":"GotChaEntityView","id":raw.get("ID"),"gotcha_class_id":id}
		var unit: Dictionary = _row(context,"Unit",raw.get("UnitID"),from)
		entry["unit"] = unit
		entry["typed_reference"] = _typed(raw,unit.row)
		if unit.row.is_empty() or unit.excluded: continue
		if unit.row.get("Name") == "BuffCardID":
			if not _integer(raw.get("ClassID")) or not _integer(raw.get("BuffCardID")):
				_issue(context,from,{"table":"BuffCard","id":raw.get("ClassID")},"invalid_source_reference",raw)
				continue
			if raw.ClassID != raw.BuffCardID:
				_issue(context,from,entry.typed_reference,"entity_ClassID_BuffCardID_identity_mismatch",raw)
				continue
		var resolved_entry: Dictionary = _target(context,raw,unit,from,"entity_target_namespace_unresolved",false)
		entry["target"] = resolved_entry.target
		entry["pool"] = resolved_entry.pool
		entry["pool_reference"] = resolved_entry.pool_reference
		if unit.row.get("Name") == "BuffCardID": entry.card = resolved_entry.target
	return result

static func _product(context: Dictionary, id: Variant, owner: Dictionary) -> Dictionary:
	var node: Dictionary = _row(context,"MarketProduct",id,owner)
	node["unit"] = {}; node["additional"] = []; node["pool"] = {}; node["pool_reference"] = null; node["target"] = {}
	if node.row.is_empty() or node.excluded: return node
	var raw: Dictionary = node.row
	var from: Dictionary = {"table":"MarketProduct","id":raw.get("ID")}
	var unit: Dictionary = _row(context,"Unit",raw.get("UnitID"),from)
	node.unit = unit
	node["typed_reference"] = _typed(raw,unit.row)
	for extra: Dictionary in _related(context,"MarketProductAdditional","MarketProductID",raw.get("ID"),from):
		var addition: Dictionary = _node(context,"MarketProductAdditional",extra)
		node.additional.append(addition)
		if addition.excluded: continue
		var additional_unit: Dictionary = _row(context,"Unit",extra.get("UnitID"),{"table":"MarketProductAdditional","id":extra.get("ID"),"market_product_id":raw.ID})
		addition["unit"] = additional_unit
		var resolved_addition: Dictionary = _target(context,extra,additional_unit,{"table":"MarketProductAdditional","id":extra.get("ID"),"market_product_id":raw.ID},"additional_product_target_namespace_unresolved")
		addition["typed_reference"] = resolved_addition.typed_reference
		addition["target"] = resolved_addition.target
		addition["pool"] = resolved_addition.pool
		addition["pool_reference"] = resolved_addition.pool_reference
	if unit.row.is_empty() or unit.excluded: return node
	var resolved_product: Dictionary = _target(context,raw,unit,from,"product_target_namespace_unresolved")
	node.target = resolved_product.target
	node.pool = resolved_product.pool
	node.pool_reference = resolved_product.pool_reference
	return node

static func _date(context: Dictionary, value: Variant, owner: Dictionary) -> Dictionary:
	# The existing commerce projection omits a zero date reference. Preserve
	# that source value without assigning a clock, expiry or eligibility.
	if _integer(value) and int(value) == 0:
		return {"table":"DateTimes_Korean","id":value,"row":{},"source_zero_reference":true,"reference_only":true,"can_activate":false}
	return _row(context,"DateTimes_Korean",value,owner)

static func describe(market_id: int, origin_item_bonus: Dictionary = {}) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	var context: Dictionary = {"unresolved":[],"blockers":[],"source_exclusion_evidence":[],"table_metadata":{},"pools":{},"pool_queue":[],"pool_queued":{},"pool_queue_owners":{}}
	var result: Dictionary = {"kind":"twilight.current523.market-gotcha-data.v1","ok":false,
		"market_purchase_id":market_id,"source":identity,"origin_item_bonus":origin_item_bonus,
		"purchase":{},"payment":{},"products":[],"bonus_products":[],"restrictions":[],"server_limits":[],
		"effective_from":{},"effective_to":{},"pools":context.pools,"unresolved":context.unresolved,
		"blockers":context.blockers,"source_exclusion_evidence":context.source_exclusion_evidence,
		"source_table_metadata":context.table_metadata,"reference_only":true,"can_activate":false,
		"ownership_authorized":false,"join_complete":false,
		"remaining_contract":["General pool denominator/caps/draw and selection rules require the existing owner",
			"Nested pool draw/replacement/count/denominator/grants remain unresolved; pool_reference is only a raw ID edge",
			"OnSale, dates, server and restriction rows are preserved without offer admission",
			"Unknown target namespaces and condition/payment semantics require the existing owner; no supply or purchase is authorized"]}
	var root: Dictionary = {"table":"MarketPurchase_Korean","id":market_id}
	if identity.is_empty():
		_issue(context,root,root,"missing_source_reference",{"source_problem":SOURCE.problem()})
		return result
	if not origin_item_bonus.is_empty():
		var bonus: Dictionary = origin_item_bonus.get("bonus",{})
		var type: Dictionary = origin_item_bonus.get("type",{})
		var unit: Dictionary = origin_item_bonus.get("unit",{})
		if type.get("Name") != "MarketPurchaseID" or bonus.get("Value") != market_id or bonus.get("BonusTypeID") != type.get("ID") or type.get("UnitID") != unit.get("ID") or not unit.get("Name") is String:
			_issue(context,{"table":"ItemBonus","id":origin_item_bonus.get("link",{}).get("ID")},root,"item_bonus_type_or_unit_namespace_unresolved",origin_item_bonus)
			return result
		# The public ticket compiler establishes this type-name join. The
		# original Unit is retained, without extending other Unit namespaces.
		result["namespace_evidence"] = {"bonus_type":type,"unit":unit,"join":"MarketPurchaseID -> MarketPurchase_Korean.ID"}
	var purchase: Dictionary = _row(context,"MarketPurchase_Korean",market_id,root)
	result.purchase = purchase
	if purchase.row.is_empty(): return result
	result.ok = true
	if purchase.excluded:
		result["excluded"] = true
		result["declared_exclusion"] = purchase.declared_exclusion
		return result
	var raw: Dictionary = purchase.row
	result.effective_from = _date(context,raw.get("EffectiveFromId"),root)
	result.effective_to = _date(context,raw.get("EffectiveToId"),root)
	var payment: Dictionary = _row(context,"MarketPayment_Korean",raw.get("MarketPaymentID"),root)
	result.payment = payment
	if not payment.row.is_empty() and not payment.excluded:
		var unit: Dictionary = _row(context,"Unit",payment.row.get("UnitID"),{"table":"MarketPayment_Korean","id":payment.row.get("ID")})
		payment["unit"] = unit
		var resolved_payment: Dictionary = _target(context,payment.row,unit,{"table":"MarketPayment_Korean","id":payment.row.get("ID")},"payment_target_namespace_unresolved")
		payment["typed_reference"] = resolved_payment.typed_reference
		payment["target"] = resolved_payment.target
		payment["pool"] = resolved_payment.pool
		payment["pool_reference"] = resolved_payment.pool_reference
	for table: String in ["MarketPurchaseProduct","MarketBonusForPurchase"]:
		for link: Dictionary in _related(context,table,"MarketPurchaseID",market_id,root):
			var relation: Dictionary = _node(context,table,link)
			relation["product"] = {}
			if table == "MarketPurchaseProduct": result.products.append(relation)
			else: result.bonus_products.append(relation)
			if not relation.excluded: relation.product = _product(context,link.get("MarketProductID"),{"table":table,"id":link.get("ID"),"market_purchase_id":market_id})
	for raw_restriction: Dictionary in _related(context,"MarketPurchaseRestriction","MarketPurchaseId",market_id,root):
		var restriction: Dictionary = _node(context,"MarketPurchaseRestriction",raw_restriction)
		result.restrictions.append(restriction)
		if restriction.excluded: continue
		restriction["value_unit"] = _row(context,"Unit",raw_restriction.get("ValueUnitId"),root)
		restriction["duration_unit"] = _row(context,"Unit",raw_restriction.get("DurationUnitId"),root)
		_issue(context,root,{"namespace":restriction.value_unit.row.get("Name"),"value":raw_restriction.get("Value"),"duration_unit":restriction.duration_unit.row,"duration_raw":raw_restriction.get("DurationValue")},"purchase_restriction_interpretation_deferred",raw_restriction)
	for link: Dictionary in _related(context,"MarketPurchaseServerLimitGroup","MarketPurchaseID",market_id,root):
		var limit: Dictionary = _node(context,"MarketPurchaseServerLimitGroup",link)
		limit["servers"] = []
		result.server_limits.append(limit)
		if limit.excluded: continue
		var servers: Array = _related(context,"ServerLimit","ServerLimitSetID",link.get("ServerLimitSetID"),root)
		if servers.is_empty() and _integer(link.get("ServerLimitSetID")) and int(link.ServerLimitSetID) != 0:
			_issue(context,root,{"table":"ServerLimit","field":"ServerLimitSetID","id":link.ServerLimitSetID},"missing_source_reference",link)
		for server: Dictionary in servers:
			limit.servers.append(_node(context,"ServerLimit",server))
	# Read each newly reached pool through the same original-row reader. _pool
	# appends source entries verbatim and only queues further pool IDs, so this
	# work list can close cycles without recursion or cyclic Dictionary objects.
	var pool_cursor: int = 0
	while pool_cursor < context.pool_queue.size():
		var pool_id: int = int(context.pool_queue[pool_cursor])
		pool_cursor += 1
		_pool(context,pool_id,context.pool_queue_owners.get(str(pool_id),{}))
	if result.products.is_empty() and result.bonus_products.is_empty(): _issue(context,root,{"table":"MarketPurchaseProduct","field":"MarketPurchaseID","id":market_id},"source_market_product_relations_empty")
	result.join_complete = context.unresolved.is_empty() and context.source_exclusion_evidence.is_empty()
	return result
