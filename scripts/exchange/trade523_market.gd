extends RefCounted
## Offline 523 서버 거래소 (the original Trade window's data and rules).
## - 검색 분류: the original UITradeMarketCategory tree (DescData_Korean names)
##   and UITradeMarketCategoryMappingView (ItemClass -> category).
## - 구매: one locally restocked offer per exact installed TWILIGHT catalog
##   item. Captured data supplies comparable unit prices only, never listings,
##   quantities, provenance, variants or stock. There is no server connection.
## - 기존 매물: no new listings. Previously saved escrow can be cancelled,
##   recovered after expiry or settled using its original recorded sale time.
## All transfers use game currency and one atomic save, never a server.
const RETIRED_ITEMS = preload("res://scripts/loot/retired_enhancement_items523.gd")
const Frozen=preload("res://scripts/exchange/frozen_exchange.gd")
const FrozenCatalog=preload("res://scripts/exchange/frozen_catalog.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const DUMMY=preload("res://scripts/quests/source_dummy523.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const STATE_KEY: String="trade523"
const DIAMOND: String="다이아"
## ItemTradeMarketPolicyValue (ServiceRegionCode KR).
const MIN_SALE_AMOUNT: int=10
const MAX_SALE_AMOUNT: int=9999999
## Previous TWILIGHT tax remains only for unsettled legacy sales.
const TAX_PERCENT: int=7
const BASE_TAX_PERCENT: int=2
const CASTLE_TAX_PERCENT: int=5
## History rows kept (최근 한달, the original Trade_Tab_CalculateList message).
const HISTORY_DAYS: int=30
const LIMIT: int=9007199254740991
var world: Object
var _categories: Array=[]
var _names: Dictionary={}
var _mapping: Dictionary={}
var _by_category: Dictionary={}
var _exact_prices: Dictionary={}
var _peer_prices: Dictionary={}
var _top_categories: Dictionary={}
var _item_names: Dictionary={}
var _item_cache: Dictionary={}
var problem: String=""

static func fresh_state() -> Dictionary:
	return {"version":1,"next_id":1,"listings":{},"history":[],"approx_day":0,"approx_used":{}}

static func _int(value: Variant, minimum: int=0, maximum: int=LIMIT) -> bool:
	return FrozenCatalog.integer(value,minimum,maximum)

static func validate_state(value: Variant) -> String:
	if not value is Dictionary or value.get("version")!=1:return "거래소 저장 형식 오류"
	if not _int(value.get("next_id"),1) or not _int(value.get("approx_day")) or not value.get("listings") is Dictionary or not value.get("history") is Array or not value.get("approx_used") is Dictionary:return "거래소 저장 항목 오류"
	for id: Variant in value.listings:
		var row: Variant=value.listings[id]
		if not id is String or not str(id).is_valid_int() or int(id)>=int(value.next_id) or not row is Dictionary:return "거래소 판매 번호 오류"
		for key: String in ["item_class_id","quantity","price","registered_at","expires_at","sell_at"]:
			if not _int(row.get(key),-1):return "거래소 판매 수치 오류"
		if int(row.quantity)<1 or int(row.price)<1 or not row.get("name") is String or not row.get("kind") in ["instance","native_stack","stack"]:return "거래소 판매 항목 오류"
		if row.kind=="instance" and (not row.get("instance") is Dictionary or not row.get("instance_id") is String):return "거래소 판매 장비 개체 오류"
	for entry: Variant in value.history:
		if not entry is Dictionary or not _int(entry.get("gross")) or not _int(entry.get("net")) or not _int(entry.get("at")):return "거래소 정산 내역 오류"
	for key: Variant in value.approx_used:
		if not key is String or not _int(value.approx_used[key],1):return "거래소 근사 매물 재고 오류"
	return ""

func configure(host: Object) -> Dictionary:
	world=host
	problem=""
	_item_cache.clear()
	_item_names.clear()
	_load_categories()
	return {"ok":problem.is_empty(),"problem":problem}

func shop() -> Object:
	return world.get("source_shop") if world!=null else null

func _now() -> int:
	var owner: Object=shop()
	return int(owner._now()) if owner!=null else int(Time.get_unix_time_from_system())

## The read-only view is taken once per query. Mutating routes always stage a
## detached copy, and malformed persisted state cannot be silently replaced.
func _saved_trade() -> Variant:
	var owner: Object=shop()
	return owner.state.get(STATE_KEY,fresh_state()) if owner!=null else fresh_state()

func state_problem() -> String:
	var value: Variant=_saved_trade()
	var error: String=validate_state(value)
	if not error.is_empty():return error
	if int(value.approx_day)>_stock_day():return "거래소 재고 저장 시각이 현재보다 앞섭니다"
	return ""

func state() -> Dictionary:
	return (_saved_trade() as Dictionary).duplicate(true) if state_problem().is_empty() else {}

func _stock_day() -> int:
	var owner: Object=shop()
	return Frozen.day_at(maxi(_now(),int(owner.state.get("clock_highwater",0))) if owner!=null else _now())

func _stock_view() -> Variant:
	var value: Variant=_saved_trade()
	if not validate_state(value).is_empty():return null
	var day: int=_stock_day()
	if int(value.approx_day)>day:return null
	return value.approx_used if int(value.approx_day)==day else {}

## --- Catalog -----------------------------------------------------------------

func _desc(id: int) -> String:
	return str(SOURCE.row("DescData_Korean",id).get("Description",""))

func _load_categories() -> void:
	_categories.clear()
	_names.clear()
	_mapping.clear()
	_by_category.clear()
	_top_categories.clear()
	var rows: Array[Dictionary]=SOURCE.rows("UITradeMarketCategory")
	if rows.is_empty():
		problem="원본 거래소 분류 표(UITradeMarketCategory)가 필요합니다"
		return
	var children: Dictionary={}
	for row: Dictionary in rows:
		if not bool(row.get("IsEnable",false)):continue
		var id: int=int(row.ID)
		_names[id]=_desc(int(row.get("DescID",0)))
		var parent: int=int(row.get("ParentID",0))
		_top_categories[id]=id if parent==0 else parent
		if parent==0:_categories.append({"id":id,"name":_names[id],"children":[]})
		else:
			if not children.has(parent):children[parent]=[]
			children[parent].append({"id":id,"name":_names[id],"parent":parent})
	for top: Dictionary in _categories:
		top.children=children.get(int(top.id),[])
	for row: Dictionary in SOURCE.rows("UITradeMarketCategoryMappingView"):
		var item: int=int(row.get("ItemClassID",0))
		var category: int=int(row.get("UITradeMarketCategoryID",0))
		if item<=0 or not _names.has(category):continue
		_mapping[item]=category
	# Build each category only after the final exact-ID mapping is selected.
	for item: int in _mapping:
		var category: int=_mapping[item]
		if not _by_category.has(category):_by_category[category]=[]
		_by_category[category].append(item)
	_index_reference_prices()

func categories() -> Array:
	return _categories.duplicate(true)

func category_name(id: int) -> String:
	return str(_names.get(id,""))

func top_of(category: int) -> int:
	return int(_top_categories.get(category,0))

func category_of(item_class_id: int) -> int:
	return int(_mapping.get(item_class_id,0))

static func _median(values: Array) -> float:
	values.sort()
	var middle: int=values.size()/2
	return float(values[middle]) if values.size()%2==1 else (float(values[middle-1])+float(values[middle]))*0.5

## Only the normalized quote crosses the captured/local boundary. Ordinary,
## unenchanted, non-elemental diamond samples; never use raw captured stock.
static func captured_unit(row: Dictionary) -> float:
	if row.get("enchant")!=0 or row.get("element_level")!=0 or row.get("element")!="":return -1.0
	var attrs: Variant=row.get("attributes")
	if not attrs is Dictionary or attrs.get("blessed_type")!=1:return -1.0
	if row.get("currency_unit_id")!=34 or row.get("currency_class_id")!=2:return -1.0
	if not _int(row.get("bundle_price"),1) or not _int(row.get("bundle_size"),1):return -1.0
	return float(row.bundle_price)/float(row.bundle_size)

func _index_reference_prices() -> void:
	_exact_prices.clear()
	_peer_prices.clear()
	var capture=FrozenCatalog.new()
	if not capture.load_snapshot() or not capture.captured():return
	var per_item: Dictionary={}
	for row: Dictionary in capture.rows():
		var id: int=int(row.item_class_id)
		if not _mapping.has(id):continue
		var unit: float=captured_unit(row)
		if unit<=0.0:continue
		if not per_item.has(id):per_item[id]=[]
		per_item[id].append(unit)
	var peers: Dictionary={}
	for id: int in per_item:
		var original: Dictionary=SOURCE.row("ItemClass",id)
		if original.get("TestItem")!=false or original.get("IsTradable")!=true or RETIRED_ITEMS.item(id):continue
		var unit: float=_median(per_item[id])
		_exact_prices[id]=unit
		var grade: int=int(original.get("GradeID",0))
		var top: int=top_of(category_of(id))
		# One vote per base ItemClass, not one vote per repeatedly observed listing.
		for key: String in ["%d:%d"%[top,grade],"*:%d"%grade]:
			if not peers.has(key):peers[key]=[]
			peers[key].append(unit)
	for key: String in peers:_peer_prices[key]={"unit":_median(peers[key]),"peer_items":peers[key].size()}

func price_reference(item_class_id: int) -> Dictionary:
	if not _mapping.has(item_class_id):return {}
	if _exact_prices.has(item_class_id):return {"unit":float(_exact_prices[item_class_id]),"basis":"exact"}
	var grade: int=int(SOURCE.row("ItemClass",item_class_id).get("GradeID",0))
	var top: int=top_of(category_of(item_class_id))
	var key: String="%d:%d"%[top,grade]
	if _peer_prices.has(key):return {"unit":float(_peer_prices[key].unit),"basis":"category_grade","peer_items":int(_peer_prices[key].peer_items)}
	key="*:%d"%grade
	if _peer_prices.has(key):return {"unit":float(_peer_prices[key].unit),"basis":"grade","peer_items":int(_peer_prices[key].peer_items)}
	return {}

func reference_unit_price(item_class_id: int) -> float:
	return float(price_reference(item_class_id).get("unit",0.0))

static func _source_key(id: int) -> String:
	return "m523:item:"+str(id)

func _local_record(id: int) -> Dictionary:
	return world._catalog_item_from_source_id(_source_key(id)) if world!=null and world.has_method("_catalog_item_from_source_id") else {}

## Never advertise a source-table-only item the live supply owner cannot grant.
func item(item_class_id: int) -> Dictionary:
	if not _mapping.has(item_class_id) or RETIRED_ITEMS.item(item_class_id):return {}
	var catalog: Dictionary=_local_record(item_class_id)
	if catalog.is_empty():return {}
	var cached: Variant=_item_cache.get(item_class_id)
	if cached is Dictionary and is_same(cached.catalog,catalog):return cached.item
	var found: Dictionary={}
	var original: Dictionary=SOURCE.row("ItemClass",item_class_id)
	if original.get("TestItem")==false and original.get("IsTradable")==true and DUMMY.item_id_evidence(item_class_id).is_empty():
		var record: Dictionary=D.definition_id(str(item_class_id)).get("native_record",{})
		if D.matches(catalog,record) and _ordinary(record) and INV.coin_wallet(item_class_id).is_empty() and D.currency_identity_name(record).is_empty():
			if D.equipment(record) or not STACK.supply_profile(record).is_empty():
				found={"item_class_id":item_class_id,"name":_item_name(item_class_id),"record":record,"grade":int(original.GradeID),"max_stack":1 if D.equipment(record) else maxi(1,int(original.MaxStackAmount))}
	_item_cache[item_class_id]={"catalog":catalog,"item":found}
	return found

func _source_clock_offset() -> int:
	return int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)) if world!=null else 540

func _ordinary(record: Dictionary) -> bool:
	return record.get("source_m_native_item")==true and int(record.get("source_bless_raw",1))==1 and str(record.get("bless_state","normal")) in ["","normal"] and not bool(record.get("is_engraved",false))

func _item_name(id: int) -> String:
	if not _item_names.has(id):
		var row: Dictionary=SOURCE.row("ItemClass",id)
		var title: String=_desc(int(row.get("DescID",0)))
		if not title.is_empty():_item_names[id]=title
	return str(_item_names.get(id,""))

## Local policy: one equipment, 1,000 materials or 10 other stackables,
## bounded by the item's own stack ceiling. Changing a price sample must
## not change quantity. A low total still obeys the existing 10-diamond minimum.
static func local_lot(max_stack: int, slot: String, unit: float) -> Dictionary:
	if max_stack<1 or not is_finite(unit) or unit<=0.0 or unit>MAX_SALE_AMOUNT:return {}
	var size: int=mini(max_stack,1000 if slot=="material" else 10)
	var total: float=unit*float(size)
	if total>MAX_SALE_AMOUNT:return {}
	return {"size":size,"price":maxi(MIN_SALE_AMOUNT,ceili(total))}

func _local_listing(item_class_id: int, used: Dictionary) -> Dictionary:
	var key: String="local:%d"%item_class_id
	if used.has(key):return {}
	var ref: Dictionary=price_reference(item_class_id)
	if ref.is_empty():return {}
	var info: Dictionary=item(item_class_id)
	if info.is_empty() or not D.deadline_problem(info.record,_source_clock_offset()).is_empty():return {}
	var lot: Dictionary=local_lot(int(info.max_stack),str(info.record.get("slot","")),float(ref.unit))
	if lot.is_empty():return {}
	var paid_unit: float=float(lot.price)/float(lot.size)
	return {"key":key,"name":str(info.name),"item_class_id":item_class_id,"bundle_size":int(lot.size),"bundle_price":int(lot.price),"unit_price":paid_unit,"unit_price_display":maxi(1,ceili(paid_unit)),"available":1,"enchant":0,"approx":ref.basis!="exact","price_basis":str(ref.basis),"grade":int(info.grade),"local":true}

## Name lookup before deal construction. Take a single live stock projection.
func search(category: int, query: String="") -> Array:
	var used: Variant=_stock_view()
	if not used is Dictionary:return []
	var ids: Array=[]
	if category==0:ids=_mapping.keys()
	else:
		ids=_by_category.get(category,[]).duplicate()
		for top: Dictionary in _categories:
			if int(top.id)!=category:continue
			for child: Dictionary in top.children:ids.append_array(_by_category.get(int(child.id),[]))
			break
	var needle: String=query.strip_edges().replace(" ","")
	var found: Array=[]
	for id: int in ids:
		if _local_record(id).is_empty():continue
		var name: String=_item_name(id)
		if name.is_empty() or (not needle.is_empty() and not name.replace(" ","").contains(needle)):continue
		var info: Dictionary=item(id)
		if info.is_empty() or not D.deadline_problem(info.record,_source_clock_offset()).is_empty():continue
		var row: Dictionary=_local_listing(id,used)
		var basis: String=str(price_reference(id).get("basis","")) if row.is_empty() else str(row.price_basis)
		found.append({"item_class_id":id,"name":name,"min_price":int(row.get("unit_price_display",0)),"unit_price":float(row.get("unit_price",0.0)),"count":int(not row.is_empty()),"approx":not basis.is_empty() and basis!="exact","grade":int(info.grade),"local":true,"price_basis":basis})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.grade)>int(b.grade) if int(a.grade)!=int(b.grade) else (str(a.name)<str(b.name) if str(a.name)!=str(b.name) else int(a.item_class_id)<int(b.item_class_id)))
	return found

func listings(item_class_id: int) -> Array:
	var used: Variant=_stock_view()
	if not used is Dictionary:return []
	var row: Dictionary=_local_listing(item_class_id,used)
	return [row] if not row.is_empty() else []

func listing(key: String) -> Dictionary:
	if not key.begins_with("local:"):return {}
	var suffix: String=key.trim_prefix("local:")
	if not suffix.is_valid_int() or str(int(suffix))!=suffix or int(suffix)<=0:return {}
	var rows: Array=listings(int(suffix))
	return rows[0] if rows.size()==1 else {}

func diamonds() -> int:
	return int(world.inventory.get(DIAMOND,0)) if world!=null else 0

## --- Purchase ----------------------------------------------------------------

func quote_buy(key: String) -> Dictionary:
	var blocked: String=state_problem()
	if not blocked.is_empty():return _fail(blocked+" · 기존 저장 보존")
	var row: Dictionary=listing(key)
	if row.is_empty():return _fail("판매 중인 TWILIGHT 매물이 없습니다")
	if diamonds()<int(row.bundle_price):return _fail("다이아가 부족합니다")
	return {"ok":true,"row":row,"total":int(row.bundle_price),"balance":diamonds()}

func buy(key: String) -> Dictionary:
	var quoted: Dictionary=quote_buy(key)
	if not quoted.ok:return quoted
	var owner: Object=shop()
	var started: Dictionary=owner._start()
	if not started.get("ok",false):return _fail(str(started.get("reason","거래 처리 중입니다")))
	# Migration inside _start or a day boundary must not spend a stale quote.
	var day: int=_stock_day()
	quoted=quote_buy(key)
	if not quoted.ok:owner._busy=false;return quoted
	var row: Dictionary=quoted.row
	var supplied: Dictionary=world.stage_source_item_grants([{"item_class_id":int(row.item_class_id),"amount":int(row.bundle_size),"bless_raw":1,"enchant":0}],{"kind":"trade523_local","listing_key":key,"bundle_size":int(row.bundle_size),"bundle_price":int(row.bundle_price),"price_basis":str(row.price_basis)})
	if not supplied.get("ok",false):
		owner._busy=false
		return _fail(str(supplied.get("error","원본 아이템 공급 실패")))
	var staged: Dictionary=supplied.overrides
	var inventory: Dictionary=staged.inventory
	if int(inventory.get(DIAMOND,0))<int(row.bundle_price):
		owner._busy=false
		return _fail("다이아가 부족합니다")
	inventory[DIAMOND]=int(inventory[DIAMOND])-int(row.bundle_price)
	if int(inventory[DIAMOND])==0:inventory.erase(DIAMOND)
	var trade: Dictionary=state()
	if trade.is_empty() or day!=_stock_day():
		owner._busy=false
		return _fail("재고 초기화 시각 또는 저장 상태가 바뀌었습니다 · 다시 확인해 주세요")
	if int(trade.approx_day)!=day:trade.approx_used={}
	trade.approx_day=day
	trade.approx_used[key]=1
	var next: Dictionary=owner.export_state()
	next[STATE_KEY]=trade
	var result: Dictionary=owner._commit(next,inventory,int(staged.gold),staged.item_instances,int(world.next_item_instance_id))
	if not result.get("ok",false):return _fail(str(result.get("reason","저장 실패")))
	_after_change()
	return {"ok":true,"item_class_id":int(row.item_class_id),"message":"%s 구매 완료 · %d 다이아 (TWILIGHT 매물)" % [str(row.name),int(row.bundle_price)]}

## --- Legacy escrow -----------------------------------------------------------

## Keep old callers fail-closed. There is no quote, fee, debit or escrow writer
## for a new user listing, even if called without the original UI.
func quote_sell(_reference: String, _quantity: int, _price: int) -> Dictionary:
	return {"ok":false,"code":"trade_sale_registration_removed","reason":"신규 판매 등록은 제공하지 않습니다."}

func register(reference: String, quantity: int, price: int) -> Dictionary:
	return quote_sell(reference,quantity,price)

static func settlement(price: int) -> Dictionary:
	var tax: int=price*TAX_PERCENT/100
	return {"gross":price,"tax":tax,"net":price-tax}

static func _status_at(row: Dictionary, now: int) -> String:
	var sold: bool=int(row.sell_at)>=0 and int(row.sell_at)<=now and int(row.sell_at)<int(row.expires_at)
	return "sold" if sold else ("expired" if now>=int(row.expires_at) else "selling")

## A small read-only scan, without cloning inventory, escrow or history for
## ordinary search. A malformed legacy save is never cleared here.
func has_reclaimable() -> bool:
	if not state_problem().is_empty():return false
	var trade: Dictionary=_saved_trade()
	var now: int=_now()
	for row: Dictionary in trade.listings.values():
		if _status_at(row,now)!="sold":return true
	return false

## My listings with their status now: selling / sold / expired.
func my_listings() -> Array:
	var now: int=_now()
	var found: Array=[]
	var trade: Dictionary=state()
	var ids: Array=trade.get("listings",{}).keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(a)<int(b))
	for id: String in ids:
		var row: Dictionary=trade.listings[id].duplicate(true)
		row["id"]=id
		row["status"]=_status_at(row,now)
		row["remaining_seconds"]=maxi(0,int(row.expires_at)-now)
		row.merge(settlement(int(row.price)),true)
		found.append(row)
	return found

## 판매 취소 (selling) / 회수 (expired): the goods go back to the bag.
func take_back(id: String) -> Dictionary:
	var blocked: String=state_problem()
	if not blocked.is_empty():return _fail(blocked+" · 기존 저장 보존")
	var row: Dictionary={}
	for listing: Dictionary in my_listings():
		if str(listing.id)==id:row=listing
	if row.is_empty():return _fail("판매 목록에 없는 아이템입니다")
	if str(row.status)=="sold":return _fail("이미 판매된 아이템은 정산 탭에서 정산하세요")
	var owner: Object=shop()
	var started: Dictionary=owner._start()
	if not started.get("ok",false):return _fail(str(started.get("reason","거래 처리 중입니다")))
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var gold: int=int(world.gold)
	var name: String=str(row.name)
	match str(row.kind):
		"instance":
			var uid: String=str(row.instance_id)
			if instances.has(uid):
				owner._busy=false
				return _fail("같은 장비 개체가 이미 있습니다 · 판매 보존")
			instances[uid]=row.instance
			inventory[name]=int(inventory.get(name,0))+1
		"stack":
			inventory[name]=int(inventory.get(name,0))+int(row.quantity)
		"native_stack":
			var supplied: Dictionary=world.stage_source_item_grants([{"item_class_id":int(row.item_class_id),"amount":int(row.quantity),"bless_raw":1,"enchant":0}],{"kind":"trade523_return","listing_id":id,"registered_physical_id":str(row.get("instance_id",""))})
			if not supplied.get("ok",false):
				owner._busy=false
				return _fail(str(supplied.get("error","원본 아이템 반환 실패 · 판매 보존")))
			inventory=supplied.overrides.inventory
			instances=supplied.overrides.item_instances
			gold=int(supplied.overrides.gold)
	var trade: Dictionary=state()
	trade.listings.erase(id)
	var next: Dictionary=owner.export_state()
	next[STATE_KEY]=trade
	var result: Dictionary=owner._commit(next,inventory,gold,instances,int(world.next_item_instance_id))
	if not result.get("ok",false):return _fail(str(result.get("reason","저장 실패")))
	_after_change()
	return {"ok":true,"message":("%s 판매 취소" if str(row.status)=="selling" else "%s 회수 완료") % name}

## 정산: every sold listing's net 다이아 (gross - tax) into the bag.
func settle_all() -> Dictionary:
	var blocked: String=state_problem()
	if not blocked.is_empty():return _fail(blocked+" · 기존 저장 보존")
	var sold: Array=[]
	for row: Dictionary in my_listings():
		if str(row.status)=="sold":sold.append(row)
	if sold.is_empty():return _fail("정산할 아이템이 없습니다")
	var owner: Object=shop()
	var started: Dictionary=owner._start()
	if not started.get("ok",false):return _fail(str(started.get("reason","거래 처리 중입니다")))
	var trade: Dictionary=state()
	var inventory: Dictionary=world.inventory.duplicate(true)
	var total: int=0
	var now: int=_now()
	for row: Dictionary in sold:
		total+=int(row.net)
		trade.listings.erase(str(row.id))
		trade.history.append({"name":str(row.name),"item_class_id":int(row.item_class_id),"quantity":int(row.quantity),"price":int(row.price),"gross":int(row.gross),"net":int(row.net),"sold_at":int(row.sell_at),"at":now})
	var kept: Array=[]
	for entry_value: Dictionary in trade.history:
		if now-int(entry_value.at)<=HISTORY_DAYS*86400:kept.append(entry_value)
	trade.history=kept
	inventory[DIAMOND]=int(inventory.get(DIAMOND,0))+total
	var next: Dictionary=owner.export_state()
	next[STATE_KEY]=trade
	var result: Dictionary=owner._commit(next,inventory,int(world.gold),world.item_instances.duplicate(true),int(world.next_item_instance_id))
	if not result.get("ok",false):return _fail(str(result.get("reason","저장 실패")))
	_after_change()
	return {"ok":true,"total":total,"count":sold.size(),"message":"정산 완료 · %d 다이아 (%d건)" % [total,sold.size()]}

func history() -> Array:
	var rows: Array=state().get("history",[]).duplicate(true)
	rows.reverse()
	return rows

func _after_change() -> void:
	if world==null:return
	if world.has_method("_index_item_weights"):world.call("_index_item_weights")
	var owner: Object=world.get("hud")
	if owner!=null and owner.has_method("refresh_inventory"):owner.call("refresh_inventory",world.inventory)
	if world.has_method("_update_hud"):world.call("_update_hud")

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"reason":message,"error":message}
