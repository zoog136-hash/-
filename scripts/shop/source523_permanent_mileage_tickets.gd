extends RefCounted
## Two permanent owned-ticket SKUs also grant mileage. Keep this narrow
## original relation separate from the persisted existing draw-policy model.
## Old 2020 mixed offers are not reactivated and no market purchase is made.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const VARIANTS={
	200408:[364608,1169358,71568,97048,1288,1,97058,240],
	200458:[364708,1169458,71578,97068,1298,10,97078,2400],
}
const WALLET:String="마일리지"

static func spec(id:int, raw:Dictionary)->Dictionary:
	if not VARIANTS.has(id) or SOURCE.identity().is_empty() or raw!=SOURCE.row("ItemClass",id) or raw.get("TestItem")!=false:return {}
	if not SOURCE.declared_exclusion("ItemClass",raw).is_empty() or SOURCE.row("ItemCategory",int(raw.CategoryID)).get("Name")!="LinMarketProduct":return {}
	if SOURCE.row("Unit",35).get("Name")!="GotChaClassID" or SOURCE.row("Unit",34).get("Name")!="IntangibleItemClassID" or SOURCE.row("IntangibleItemClass",1).get("Name")!="VIPBonusPoint":return {}
	var expected:Array=VARIANTS[id]
	var item_links:Array[Dictionary]=SOURCE.related("ItemBonus","ItemClassID",id)
	if item_links.size()!=1:return {}
	var item_link:Dictionary=item_links[0]
	var bonus:Dictionary=SOURCE.row("Bonus",int(expected[1]))
	var bonus_type:Dictionary=SOURCE.row("BonusType",541)
	if item_link.get("ID")!=expected[0] or item_link.get("BonusID")!=expected[1] or item_link.get("IsPossession")!=false or bonus.get("BonusTypeID")!=541 or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or bonus.get("Value")!=expected[2] or bonus_type.get("Name")!="MarketPurchaseID":return {}
	var purchase:Dictionary=SOURCE.row("MarketPurchase_Korean",int(expected[2]))
	if purchase.is_empty() or purchase.get("EffectiveFromId")!=1 or purchase.get("EffectiveToId")!=3:return {}
	for x:Array in [["ItemBonus",item_link],["Bonus",bonus],["BonusType",bonus_type],["MarketPurchase_Korean",purchase]]:
		if not SOURCE.declared_exclusion(x[0],x[1]).is_empty():return {}
	var products:Dictionary={}
	for table:String in ["MarketPurchaseProduct","MarketBonusForPurchase"]:
		for edge:Dictionary in SOURCE.related(table,"MarketPurchaseID",int(expected[2])):
			if not SOURCE.declared_exclusion(table,edge).is_empty():return {}
			var product_id:int=int(edge.MarketProductID)
			if products.has(product_id):return {}
			var product:Dictionary=SOURCE.row("MarketProduct",product_id)
			if product.is_empty() or not SOURCE.declared_exclusion("MarketProduct",product).is_empty():return {}
			products[product_id]=[int(product.get("UnitID",-1)),int(product.get("ClassID",-1)),int(product.get("Amount",-1))]
	if products.size()!=2 or products.get(expected[3])!=[35,expected[4],expected[5]] or products.get(expected[6])!=[34,1,expected[7]]:return {}
	# The existing ticket consumer requires a whole accepted pool separately,
	# whether it was already in the old policy or is lazily read from source.
	return {"item_id":id,"market_id":int(expected[2]),"grants":[{"product_id":int(expected[3]),"pool_id":int(expected[4]),"count":int(expected[5])}],"original_mileage":int(expected[7])}
