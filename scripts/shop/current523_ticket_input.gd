extends RefCounted
## Original input projection for the existing owned-ticket service only.
## No ticket issuance, card registration, draw, policy migration or file writes.
##
## Every non-test ItemClass of the LinMarketProduct category is a candidate:
## its single MarketPurchaseID bonus names a MarketPurchase whose
## MarketPurchaseProduct/MarketBonusForPurchase rows grant MarketProducts. A
## ticket is redeemable only when every product is a GotChaClassID draw and
## every pool it draws from is whole (probabilities total 1,000,000, no
## declared exclusion). Anything else is listed in `unsupported` with its
## reason and stays an ordinary owned item: a pool is never filtered or
## renormalized, and one unsupported ticket no longer blocks the others.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CATEGORY = "LinMarketProduct"
const ALLOWED_BONUSES = ["MarketPurchaseID","CannotExtendDeleteTime","DeleteTime"]
var problem: String = ""
var source_identity: Dictionary = {}
var blocked_pools: Array = []
var _pool_rows: Dictionary = {}
var _pool_problems: Dictionary = {}

func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

## Exactly one row with this ID, or {} with the reason in `failure`.
func _row(table: String, value: Variant, failure: Array) -> Dictionary:
	if not _integer(value): failure.append("non_integral_source_reference:"+table); return {}
	var rows: Array[Dictionary] = SOURCE.related(table,"ID",int(value))
	if rows.size()!=1: failure.append("source_reference_missing_or_ambiguous:"+table+":"+str(int(value))); return {}
	return rows[0]

func _label(id: Variant, failure: Array) -> Variant:
	var row: Dictionary = _row("DescData_Korean",id,failure)
	if row.is_empty(): return null
	if not row.get("Description") is String: failure.append("source_label_invalid"); return null
	return row.Description

func _declared(table: String, row: Dictionary) -> bool:
	return not SOURCE.declared_exclusion(table,row).is_empty()

## The whole original distribution in source order, or [] when the pool is
## incomplete, mistyped or carries a declared exclusion (reason kept).
func _pool(pool_id: int) -> Array:
	var rows: Array[Dictionary] = SOURCE.related("GotChaEntityView","GotChaClassID",pool_id)
	if rows.is_empty(): _pool_problems[str(pool_id)] = "original_pool_missing"; return []
	var total: int = 0
	var result: Array = []
	for row: Dictionary in rows:
		for field: String in ["GotChaClassID","UnitID","ClassID","BuffCardID","Probability","Grade"]:
			if not _integer(row.get(field)): _pool_problems[str(pool_id)] = "original_pool_integer_invalid"; return []
		if int(row.GotChaClassID)!=pool_id or row.UnitID!=33 or row.ClassID!=row.BuffCardID or row.Probability<0:
			_pool_problems[str(pool_id)] = "original_pool_typed_identity_invalid"; return []
		total+=int(row.Probability)
		result.append({"card_id":int(row.BuffCardID),"weight":int(row.Probability),"grade_id":int(row.Grade)})
	if total!=1000000: _pool_problems[str(pool_id)] = "original_pool_total_invalid_no_renormalization"; return []
	# Only a complete distribution is checked for declarations; any hit
	# withholds the whole pool rather than filtering a member.
	var reasons: Array = []
	for row: Dictionary in rows:
		var failure: Array = []
		var card: Dictionary = _row("BuffCard",row.BuffCardID,failure)
		var grade: Dictionary = _row("Grade",row.Grade,failure)
		if card.is_empty() or grade.is_empty(): _pool_problems[str(pool_id)] = str(failure[0]); return []
		if _declared("GotChaEntityView",row): reasons.append({"table":"GotChaEntityView","card_id":row.BuffCardID})
		if _declared("BuffCard",card): reasons.append({"table":"BuffCard","card_id":row.BuffCardID})
		if _declared("Grade",grade): reasons.append({"table":"Grade","grade_id":row.Grade})
	if not reasons.is_empty():
		blocked_pools.append({"pool_id":str(pool_id),"reason":"source_declared_exclusion","members":reasons})
		_pool_problems[str(pool_id)] = "original_pool_declared_exclusion"; return []
	_pool_rows[str(pool_id)] = rows
	return result

func _category_id() -> int:
	var found: Array = []
	for row: Dictionary in SOURCE.rows("ItemCategory"):
		if row.get("Name")==CATEGORY and _integer(row.get("ID")): found.append(int(row.ID))
	return int(found[0]) if found.size()==1 else -1

## One ticket's spec, or {"unsupported": reason}.
func _ticket(item: Dictionary, pools: Dictionary) -> Dictionary:
	var failure: Array = []
	var item_id: int = int(item.ID)
	if _declared("ItemClass",item): return {"unsupported":"source_declared_exclusion:ItemClass"}
	var values: Dictionary = {}
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_id):
		var bonus: Dictionary = _row("Bonus",link.get("BonusID"),failure)
		if bonus.is_empty(): return {"unsupported":str(failure[0])}
		var type: Dictionary = _row("BonusType",bonus.get("BonusTypeID"),failure)
		if type.is_empty(): return {"unsupported":str(failure[0])}
		var kind: Variant = type.get("Name")
		if kind not in ALLOWED_BONUSES: return {"unsupported":"ticket_source_restriction_unhandled:"+str(kind)}
		if link.get("IsPossession")!=false or values.has(kind): return {"unsupported":"ticket_source_restriction_unhandled:"+str(kind)}
		for entry: Array in [["ItemBonus",link],["Bonus",bonus],["BonusType",type]]:
			if _declared(entry[0],entry[1]): return {"unsupported":"source_declared_exclusion:"+str(entry[0])}
		# DeleteTime stays with the item record (source_delete_time_raw) and is
		# enforced by the existing deadline check when the ticket is used.
		if kind=="DeleteTime": values[kind] = true; continue
		if bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or not _integer(bonus.get("Value")): return {"unsupported":"ticket_source_bonus_value_invalid:"+str(kind)}
		values[kind] = int(bonus.Value)
	if not values.has("MarketPurchaseID"): return {"unsupported":"ticket_market_purchase_missing"}
	var market_id: int = int(values.MarketPurchaseID)
	var purchase: Dictionary = _row("MarketPurchase_Korean",market_id,failure)
	if purchase.is_empty(): return {"unsupported":str(failure[0])}
	if _declared("MarketPurchase_Korean",purchase): return {"unsupported":"source_declared_exclusion:MarketPurchase_Korean"}
	var grants: Array = []
	var used_pools: Array = []
	for table: String in ["MarketPurchaseProduct","MarketBonusForPurchase"]:
		for relation: Dictionary in SOURCE.related(table,"MarketPurchaseID",market_id):
			var product: Dictionary = _row("MarketProduct",relation.get("MarketProductID"),failure)
			if product.is_empty(): return {"unsupported":str(failure[0])}
			if product.get("UnitID")!=35: return {"unsupported":"ticket_source_grant_unit_unsupported:"+str(product.get("UnitID"))}
			if not _integer(product.get("Amount")) or product.Amount<1 or product.Amount>100 or not _integer(product.get("ClassID")): return {"unsupported":"ticket_source_grant_amount_unsupported"}
			if _declared(table,relation): return {"unsupported":"source_declared_exclusion:"+table}
			if _declared("MarketProduct",product): return {"unsupported":"source_declared_exclusion:MarketProduct"}
			var pool_id := int(product.ClassID)
			grants.append({"product_id":int(product.ID),"pool_id":pool_id,"count":int(product.Amount)})
			used_pools.append(pool_id)
	if grants.is_empty(): return {"unsupported":"ticket_original_output_missing"}
	for pool_id: int in used_pools:
		if not pools.has(str(pool_id)) and not _pool_problems.has(str(pool_id)):
			var entries: Array = _pool(pool_id)
			if not entries.is_empty(): pools[str(pool_id)] = entries
		if _pool_problems.has(str(pool_id)): return {"unsupported":"pool:"+str(pool_id)+":"+str(_pool_problems[str(pool_id)])}
	var grade: Dictionary = _row("Grade",item.get("GradeID"),failure)
	if grade.is_empty(): return {"unsupported":str(failure[0])}
	if _declared("Grade",grade): return {"unsupported":"source_declared_exclusion:Grade"}
	var name: Variant = _label(item.get("DescID"),failure)
	var grade_name: Variant = _label(grade.get("DescID"),failure)
	if name==null or grade_name==null: return {"unsupported":str(failure[0]) if not failure.is_empty() else "source_label_missing"}
	return {"name":name,"grade":grade_name,"item_id":item_id,"market_id":market_id,"cannot_extend_expiry":bool(values.get("CannotExtendDeleteTime",0)),"source_delete_time":values.has("DeleteTime"),"grants":grants}

func build() -> Dictionary:
	problem = ""; blocked_pools = []; _pool_rows = {}; _pool_problems = {}
	source_identity = SOURCE.identity()
	if source_identity.is_empty(): problem = "ticket_current523_unavailable:"+SOURCE.problem(); return {}
	var failure: Array = []
	var gotcha_unit: Dictionary = _row("Unit",35,failure)
	var card_unit: Dictionary = _row("Unit",33,failure)
	if gotcha_unit.get("Name")!="GotChaClassID" or card_unit.get("Name")!="BuffCardID":
		problem = "ticket_original_unit_contract_unavailable"
		return {}
	var category: int = _category_id()
	if category<0: problem = "ticket_original_category_unavailable"; return {}
	var tickets: Dictionary = {}
	var pools: Dictionary = {}
	var unsupported: Dictionary = {}
	var items: Array[Dictionary] = SOURCE.related("ItemClass","CategoryID",category)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID) < int(b.ID))
	for item: Dictionary in items:
		if not _integer(item.get("ID")) or not item.get("TestItem") is bool: problem = "ticket_source_test_declaration_invalid"; return {}
		if item.TestItem: continue
		var spec: Dictionary = _ticket(item,pools)
		if spec.has("unsupported"): unsupported[str(int(item.ID))] = spec.unsupported
		else: tickets[str(int(item.ID))] = spec
	if tickets.is_empty(): problem = "ticket_original_model_empty"; return {}
	return {"schema":"twilight.source523.inventory-ticket-extension.v2","source_sha256":source_identity.get("source_sha256",""),"tickets":tickets,"pools":pools,"unsupported":unsupported,
		"owned_use_policy":"twilight_one_owned_ticket_for_linked_products","redeem_owned_when_market_not_on_sale":true}
