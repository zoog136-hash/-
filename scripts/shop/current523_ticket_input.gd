extends RefCounted
## Original input projection for the existing owned-ticket service only.
## No ticket issuance, card registration, draw, policy migration or file writes.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const TICKETS = {166744:57244,254088:86258,342064:91082,342074:91052,352054:63803,352064:63793}
var problem: String = ""
var source_identity: Dictionary = {}
var blocked_pools: Array = []
var _pool_rows: Dictionary = {}

func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

func _row(table: String, value: Variant) -> Dictionary:
	if not _integer(value): problem = "ticket_non_integral_source_reference:"+table; return {}
	var rows: Array[Dictionary] = SOURCE.related(table,"ID",int(value))
	if rows.size()!=1: problem = "ticket_source_reference_missing_or_ambiguous:"+table+":"+str(int(value)); return {}
	return rows[0]

func _label(id: Variant) -> Variant:
	var row: Dictionary = _row("DescData_Korean",id)
	if row.is_empty(): return null
	if not row.get("Description") is String: problem = "ticket_source_label_invalid"; return null
	return row.Description

func _declared(table: String, row: Dictionary) -> bool:
	return not SOURCE.declared_exclusion(table,row).is_empty()

func _pool(pool_id: int) -> Array:
	var rows: Array[Dictionary] = SOURCE.related("GotChaEntityView","GotChaClassID",pool_id)
	if rows.is_empty(): problem = "ticket_original_pool_missing:"+str(pool_id); return []
	var total: int = 0
	var result: Array = []
	# Preserve the whole distribution and source order before considering any
	# exclusion. A blocked member never causes filtering or renormalization.
	for row: Dictionary in rows:
		for field: String in ["GotChaClassID","UnitID","ClassID","BuffCardID","Probability","Grade"]:
			if not _integer(row.get(field)): problem = "ticket_original_pool_integer_invalid:"+str(pool_id); return []
		if int(row.GotChaClassID)!=pool_id or row.UnitID!=33 or row.ClassID!=row.BuffCardID or row.Probability<0:
			problem = "ticket_original_pool_typed_identity_invalid:"+str(pool_id)
			return []
		total+=int(row.Probability)
		result.append({"card_id":int(row.BuffCardID),"weight":int(row.Probability),"grade_id":int(row.Grade)})
	if total!=1000000: problem = "ticket_original_pool_total_invalid_no_renormalization:"+str(pool_id); return []
	_pool_rows[str(pool_id)] = rows
	return result

func _pool_exclusions() -> bool:
	# All original pools have passed the complete-distribution guard. Only now
	# consider activation declarations, and reject the whole model on any hit.
	for pool_id: String in _pool_rows:
		var reasons: Array = []
		for row: Dictionary in _pool_rows[pool_id]:
			var card: Dictionary = _row("BuffCard",row.BuffCardID)
			var grade: Dictionary = _row("Grade",row.Grade)
			if card.is_empty() or grade.is_empty(): return false
			if _declared("GotChaEntityView",row): reasons.append({"table":"GotChaEntityView","card_id":row.BuffCardID})
			if _declared("BuffCard",card): reasons.append({"table":"BuffCard","card_id":row.BuffCardID})
			if _declared("Grade",grade): reasons.append({"table":"Grade","grade_id":row.Grade})
		if not reasons.is_empty(): blocked_pools.append({"pool_id":pool_id,"reason":"source_declared_exclusion","members":reasons})
	if not blocked_pools.is_empty(): problem = "ticket_original_pool_declared_exclusion_whole_model_deferred"; return false
	return true

func build() -> Dictionary:
	problem = ""; blocked_pools = []; _pool_rows = {}
	source_identity = SOURCE.identity()
	if source_identity.is_empty(): problem = "ticket_current523_unavailable:"+SOURCE.problem(); return {}
	var gotcha_unit: Dictionary = _row("Unit",35)
	var card_unit: Dictionary = _row("Unit",33)
	if gotcha_unit.get("Name")!="GotChaClassID" or card_unit.get("Name")!="BuffCardID":
		problem = "ticket_original_unit_contract_unavailable"
		return {}
	var tickets: Dictionary = {}
	var pools: Dictionary = {}
	var excluded_sources: Array = []
	for item_id: int in TICKETS:
		var market_id: int = TICKETS[item_id]
		var item: Dictionary = _row("ItemClass",item_id)
		var purchase: Dictionary = _row("MarketPurchase_Korean",market_id)
		if item.is_empty() or purchase.is_empty(): return {}
		if not item.get("TestItem") is bool: problem = "ticket_source_test_declaration_invalid"; return {}
		if item.TestItem: excluded_sources.append({"table":"ItemClass","id":item_id,"reason":"source_TestItem_true"})
		if _declared("ItemClass",item): excluded_sources.append({"table":"ItemClass","id":item_id})
		if _declared("MarketPurchase_Korean",purchase): excluded_sources.append({"table":"MarketPurchase_Korean","id":market_id})
		var values: Dictionary = {}
		for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_id):
			var bonus: Dictionary = _row("Bonus",link.get("BonusID"))
			if bonus.is_empty(): return {}
			var type: Dictionary = _row("BonusType",bonus.get("BonusTypeID"))
			if type.is_empty(): return {}
			var kind: Variant = type.get("Name")
			if kind not in ["MarketPurchaseID","CannotExtendDeleteTime"] or link.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or values.has(kind):
				problem = "ticket_source_restriction_unhandled"
				return {}
			if not _integer(bonus.get("Value")): problem = "ticket_source_bonus_value_invalid"; return {}
			values[kind] = int(bonus.Value)
			for entry: Array in [["ItemBonus",link],["Bonus",bonus],["BonusType",type]]:
				if _declared(entry[0],entry[1]): excluded_sources.append({"table":entry[0],"ticket_id":item_id})
		if values.get("MarketPurchaseID")!=market_id: problem = "ticket_source_item_market_identity_mismatch"; return {}
		var grants: Array = []
		for table: String in ["MarketPurchaseProduct","MarketBonusForPurchase"]:
			for relation: Dictionary in SOURCE.related(table,"MarketPurchaseID",market_id):
				var product: Dictionary = _row("MarketProduct",relation.get("MarketProductID"))
				if product.is_empty(): return {}
				if product.get("UnitID")!=35 or not _integer(product.get("Amount")) or product.Amount<1 or product.Amount>100 or not _integer(product.get("ClassID")):
					problem = "ticket_source_grant_unit_or_amount_unsupported"
					return {}
				if _declared(table,relation): excluded_sources.append({"table":table,"ticket_id":item_id})
				if _declared("MarketProduct",product): excluded_sources.append({"table":"MarketProduct","id":product.ID})
				var pool_id := int(product.ClassID)
				grants.append({"product_id":int(product.ID),"pool_id":pool_id,"count":int(product.Amount)})
				if not pools.has(str(pool_id)):
					var entries: Array = _pool(pool_id)
					if entries.is_empty(): return {}
					pools[str(pool_id)] = entries
		if grants.is_empty(): problem = "ticket_original_output_missing"; return {}
		var grade: Dictionary = _row("Grade",item.get("GradeID"))
		if grade.is_empty(): return {}
		if _declared("Grade",grade): excluded_sources.append({"table":"Grade","id":grade.ID})
		var name: Variant = _label(item.get("DescID"))
		var grade_name: Variant = _label(grade.get("DescID"))
		if name==null or grade_name==null: return {}
		tickets[str(item_id)] = {"name":name,"grade":grade_name,"original_item":item,"market_id":market_id,"cannot_extend_expiry":bool(values.get("CannotExtendDeleteTime",0)),"grants":grants}
	if not _pool_exclusions(): return {}
	if not excluded_sources.is_empty():
		problem = "ticket_source_declared_exclusion_whole_model_deferred"
		blocked_pools.append({"reason":problem,"sources":excluded_sources})
		return {}
	return {"schema":"twilight.source523.inventory-ticket-extension.v1","source_sha256":source_identity.get("source_sha256",""),"tickets":tickets,"pools":pools,
		"owned_use_policy":"twilight_one_owned_ticket_for_linked_products","redeem_owned_when_market_not_on_sale":true}
