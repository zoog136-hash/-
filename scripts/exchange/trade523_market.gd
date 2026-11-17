extends RefCounted
## Offline 523 서버 거래소 (the original Trade window's data and rules).
## - 검색 분류: the original UITradeMarketCategory tree (DescData_Korean names)
##   and UITradeMarketCategoryMappingView (ItemClass -> category).
## - 다른 플레이어 매물: the frozen real-server snapshot rows (frozen_exchange,
##   real observed prices, bought through that runtime) plus, for mapped items
##   the snapshot has no row for, TWILIGHT 근사 listings priced from the
##   snapshot's median unit price of the same top category and GradeID
##   (approx: true on every such row, docs/original_ui523_approx.md).
## - 판매 등록 / 판매 취소 / 회수 / 정산: the original ItemTradeMarketPolicyValue
##   (KR) limits: MaxSellCount 30, MinSaleAmount 10, MaxSaleAmount 9,999,999,
##   SaleDuration 4320 minutes, registration commission paid in ItemClass 26
##   (아데나). The commission amount, the tax and when a simulated buyer buys
##   are not in the original data: TWILIGHT 근사 (COMMISSION, TAX_PERCENT,
##   sale_delay()).
## Only game currencies move (다이아 / 아데나); nothing calls a network or a
## real payment. Every change is one atomic save through the shop runtime.
const Frozen=preload("res://scripts/exchange/frozen_exchange.gd")
const FrozenCatalog=preload("res://scripts/exchange/frozen_catalog.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const STATE_KEY: String="trade523"
const DIAMOND: String="다이아"
## ItemTradeMarketPolicyValue (ServiceRegionCode KR).
const MAX_SELL_COUNT: int=30
const MIN_SALE_AMOUNT: int=10
const MAX_SALE_AMOUNT: int=9999999
const SALE_MINUTES: int=4320
const MAX_FAVORITES: int=30
## TWILIGHT 근사: 등록 수수료 (아데나, per registration). The original names
## only the currency (RegisterCommissionUnitID 4 / ClassID 26).
const COMMISSION: int=1000
## TWILIGHT 근사: 기본세율 2% + 성 세율 5% (the original Trade_Popup_Input /
## Trade_Tab_Sell sample text); offline there is no castle owner to change it.
const TAX_PERCENT: int=7
const BASE_TAX_PERCENT: int=2
const CASTLE_TAX_PERCENT: int=5
## History rows kept (최근 한달, the original Trade_Tab_CalculateList message).
const HISTORY_DAYS: int=30
const LIMIT: int=9007199254740991
var world: Object
var frozen: RefCounted
var _categories: Array=[]
var _names: Dictionary={}
var _mapping: Dictionary={}
var _by_category: Dictionary={}
var _snapshot_items: Dictionary={}
var _grade_prices: Dictionary={}
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
	frozen=Frozen.new()
	if host is Node:frozen.configure(host)
	_load_categories()
	return {"ok":problem.is_empty(),"problem":problem}

func shop() -> Object:
	return world.get("source_shop") if world!=null else null

func _now() -> int:
	var owner: Object=shop()
	return int(owner._now()) if owner!=null else int(Time.get_unix_time_from_system())

func state() -> Dictionary:
	var owner: Object=shop()
	if owner==null:return fresh_state()
	var value: Variant=owner.state.get(STATE_KEY,fresh_state())
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

## --- Catalog -----------------------------------------------------------------

func _desc(id: int) -> String:
	return str(SOURCE.row("DescData_Korean",id).get("Description",""))

func _load_categories() -> void:
	_categories.clear()
	_names.clear()
	_mapping.clear()
	_by_category.clear()
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
		if not _by_category.has(category):_by_category[category]=[]
		_by_category[category].append(item)
	_index_snapshot()

func categories() -> Array:
	return _categories.duplicate(true)

func category_name(id: int) -> String:
	return str(_names.get(id,""))

func top_of(category: int) -> int:
	for top: Dictionary in _categories:
		if int(top.id)==category:return category
		for child: Dictionary in top.children:
			if int(child.id)==category:return int(top.id)
	return 0

func category_of(item_class_id: int) -> int:
	return int(_mapping.get(item_class_id,0))

func _index_snapshot() -> void:
	_snapshot_items.clear()
	_grade_prices.clear()
	if frozen==null or not frozen.catalog.captured():return
	var samples: Dictionary={}
	for row: Dictionary in frozen.catalog.rows():
		var id: int=int(row.item_class_id)
		if not _snapshot_items.has(id):_snapshot_items[id]=[]
		_snapshot_items[id].append(row)
		if int(row.enchant)!=0:continue
		var original: Dictionary=SOURCE.row("ItemClass",id)
		var grade: int=int(original.get("GradeID",0))
		var unit: float=float(row.bundle_price)/float(maxi(1,int(row.bundle_size)))
		var top: int=top_of(category_of(id))
		if top==0 and row.get("category1_ids") is Array and not (row.category1_ids as Array).is_empty():top=int(row.category1_ids[0])
		for key: String in ["%d:%d" % [top,grade],"*:%d" % grade,"*:*"]:
			if not samples.has(key):samples[key]=[]
			samples[key].append(unit)
	for key: String in samples:
		var values: Array=samples[key]
		values.sort()
		_grade_prices[key]=float(values[values.size()/2])

## TWILIGHT 근사 unit price (다이아) of an item without a snapshot row.
func approx_unit_price(item_class_id: int) -> float:
	var grade: int=int(SOURCE.row("ItemClass",item_class_id).get("GradeID",0))
	var top: int=top_of(category_of(item_class_id))
	for key: String in ["%d:%d" % [top,grade],"*:%d" % grade,"*:*"]:
		if _grade_prices.has(key):return float(_grade_prices[key])
	return float(MIN_SALE_AMOUNT)

## The lowest normal-row unit price other sellers ask (snapshot, else 근사).
func reference_unit_price(item_class_id: int) -> float:
	var best: float=INF
	for row: Dictionary in _snapshot_items.get(item_class_id,[]):
		if int(row.enchant)==0:best=minf(best,float(row.bundle_price)/float(maxi(1,int(row.bundle_size))))
	return best if best<INF else approx_unit_price(item_class_id)

## {item_class_id, name, record, stackable} of a grantable original item, or {}.
func item(item_class_id: int) -> Dictionary:
	if _item_cache.has(item_class_id):return _item_cache[item_class_id]
	var found: Dictionary={}
	var summary: Dictionary=D.definition_id(str(item_class_id))
	var original: Dictionary=SOURCE.row("ItemClass",item_class_id)
	var record: Dictionary=summary.get("native_record",{})
	if not record.is_empty() and not original.is_empty() and not bool(original.get("TestItem",false)) and preload("res://scripts/quests/source_dummy523.gd").item_id_evidence(item_class_id).is_empty():
		var name: String=_desc(int(original.get("DescID",0)))
		if name.is_empty():name=str(record.get("source_display_name",record.get("name","")))
		found={"item_class_id":item_class_id,"name":name,"record":record,"grade":int(original.get("GradeID",0)),"stackable":int(original.get("MaxStackAmount",1))>1,"tradable":bool(original.get("IsTradable",false))}
	_item_cache[item_class_id]=found
	return found

## Items listed under `category` (top or sub; 0 = every category) whose
## name contains `query`: [{item_class_id, name, min_price, count, approx}].
func search(category: int, query: String="") -> Array:
	var ids: Array=[]
	if category==0:ids=_mapping.keys()
	else:
		for top: Dictionary in _categories:
			if int(top.id)==category:
				ids.append_array(_by_category.get(category,[]))
				for child: Dictionary in top.children:ids.append_array(_by_category.get(int(child.id),[]))
		if ids.is_empty():ids=_by_category.get(category,[]).duplicate()
		# Snapshot rows recorded only with their top category.
		for id: int in _snapshot_items:
			if not _mapping.has(id) and _snapshot_top(id)==category:ids.append(id)
	var needle: String=query.strip_edges().replace(" ","")
	var found: Array=[]
	for id: int in ids:
		var listed: Array=listings(id)
		if listed.is_empty():continue
		var name: String=str(listed[0].name)
		if not needle.is_empty() and not name.replace(" ","").contains(needle):continue
		var lowest: int=LIMIT
		var count: int=0
		for row: Dictionary in listed:
			lowest=mini(lowest,int(row.unit_price_display))
			count+=int(row.available)
		found.append({"item_class_id":id,"name":name,"min_price":lowest,"count":count,"approx":bool(listed[0].approx),"grade":int(listed[0].grade)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.grade)>int(b.grade) if int(a.grade)!=int(b.grade) else str(a.name)<str(b.name))
	return found

func _snapshot_top(id: int) -> int:
	var first: Dictionary=_snapshot_items[id][0]
	var tops: Variant=first.get("category1_ids",[])
	return int(tops[0]) if tops is Array and not (tops as Array).is_empty() else 0

## Listings of `item_class_id` other sellers have now, cheapest unit first.
func listings(item_class_id: int) -> Array:
	var found: Array=[]
	var info: Dictionary=item(item_class_id)
	if _snapshot_items.has(item_class_id):
		for row: Dictionary in _snapshot_items[item_class_id]:
			var left: int=int(frozen.available(row))
			if left<1:continue
			found.append(_listing_view("snapshot:"+FrozenCatalog.key(row),str(row.item_name),int(row.bundle_size),int(row.bundle_price),left,int(row.enchant),false,int(info.get("grade",0)),item_class_id))
	elif not info.is_empty() and bool(info.tradable):
		for listing: Dictionary in _approx_rows(item_class_id,info):
			if int(listing.available)>0:found.append(listing)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.unit_price)<float(b.unit_price))
	return found

func _listing_view(key: String, name: String, size: int, price: int, left: int, enchant: int, approx: bool, grade: int, item_class_id: int) -> Dictionary:
	var unit: float=float(price)/float(maxi(1,size))
	return {"key":key,"name":("+%d " % enchant if enchant>0 else "")+name,"item_class_id":item_class_id,"bundle_size":size,"bundle_price":price,"unit_price":unit,"unit_price_display":maxi(1,ceili(unit)),"available":left,"enchant":enchant,"approx":approx,"grade":grade}

## Three deterministic TWILIGHT 근사 listings per item per game day
## (KST 05:00 reset): 100% / 110% / 125% of the approximate unit price.
func _approx_rows(item_class_id: int, info: Dictionary) -> Array:
	var unit: float=approx_unit_price(item_class_id)
	var day: int=Frozen.day_at(_now())
	var used: Dictionary=state().get("approx_used",{}) if int(state().get("approx_day",-1))==day else {}
	var rows: Array=[]
	var factors: Array[float]=[1.0,1.1,1.25]
	for index: int in range(factors.size()):
		var size: int=1
		if bool(info.stackable):
			size=1
			while float(size)*unit<float(MIN_SALE_AMOUNT) and size<100000:size*=10
		var price: int=clampi(ceili(unit*factors[index]*float(size)),MIN_SALE_AMOUNT,MAX_SALE_AMOUNT)
		var key: String="approx:%d:%d" % [item_class_id,index]
		var left: int=maxi(0,1-int(used.get(key,0)))
		rows.append(_listing_view(key,str(info.name),size,price,left,0,true,int(info.grade),item_class_id))
	return rows

func listing(key: String) -> Dictionary:
	var parts: PackedStringArray=key.split(":")
	var id: int=0
	if key.begins_with("approx:") and parts.size()==3:id=int(parts[1])
	elif key.begins_with("snapshot:"):
		var row: Dictionary=frozen.catalog.listing(key.trim_prefix("snapshot:"))
		id=int(row.get("item_class_id",0))
	for row: Dictionary in listings(id):
		if str(row.key)==key:return row
	return {}

func diamonds() -> int:
	return int(world.inventory.get(DIAMOND,0)) if world!=null else 0

## --- Purchase ----------------------------------------------------------------

func quote_buy(key: String) -> Dictionary:
	var row: Dictionary=listing(key)
	if row.is_empty():return _fail("이미 판매된 매물입니다")
	if key.begins_with("snapshot:"):
		var quoted: Dictionary=frozen.quote(key.trim_prefix("snapshot:"),1)
		if not quoted.get("ok",false):return _fail(str(quoted.get("reason","구매할 수 없습니다")))
	elif diamonds()<int(row.bundle_price):return _fail("다이아가 부족합니다")
	return {"ok":true,"row":row,"total":int(row.bundle_price),"balance":diamonds()}

func buy(key: String) -> Dictionary:
	var quoted: Dictionary=quote_buy(key)
	if not quoted.ok:return quoted
	if key.begins_with("snapshot:"):
		var bought: Dictionary=frozen.buy(key.trim_prefix("snapshot:"),1)
		return {"ok":true,"message":"%s 구매 완료 · %d 다이아" % [str(quoted.row.name),int(quoted.total)]} if bought.get("ok",false) else _fail(str(bought.get("reason","구매 실패")))
	var owner: Object=shop()
	var started: Dictionary=owner._start()
	if not started.get("ok",false):return _fail(str(started.get("reason","거래 처리 중입니다")))
	var row: Dictionary=quoted.row
	var supplied: Dictionary=world.stage_source_item_grants([{"item_class_id":int(row.item_class_id),"amount":int(row.bundle_size),"bless_raw":1,"enchant":0}],{"kind":"trade523_approx","listing_key":key,"bundle_size":int(row.bundle_size),"bundle_price":int(row.bundle_price),"approximation":"TWILIGHT 근사"})
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
	var day: int=Frozen.day_at(_now())
	if int(trade.approx_day)!=day:trade.approx_used={}
	trade.approx_day=day
	trade.approx_used[key]=int(trade.approx_used.get(key,0))+1
	var next: Dictionary=owner.export_state()
	next[STATE_KEY]=trade
	var result: Dictionary=owner._commit(next,inventory,int(staged.gold),staged.item_instances,int(world.next_item_instance_id))
	if not result.get("ok",false):return _fail(str(result.get("reason","저장 실패")))
	_after_change()
	return {"ok":true,"message":"%s 구매 완료 · %d 다이아 (TWILIGHT 근사 매물)" % [str(row.name),int(row.bundle_price)]}

## --- Selling -----------------------------------------------------------------

## The bag entries the 판매 tab lists: one per equipment instance, one per
## stack name. {reference, name, instance_id, count, record, item_class_id,
## equipment, registrable, reason}.
func bag_entries() -> Array:
	var found: Array=[]
	if world==null:return found
	var equipped: Dictionary={}
	for raw: Variant in world.get("equipped_items").values():
		if raw is Dictionary:equipped[str(raw.get("instance_id",""))]=true
	var instances: Dictionary=world.item_instances
	var names: Array=world.inventory.keys()
	for name: Variant in names:
		var count: Variant=world.inventory[name]
		if not name is String or not _int(count,1) or name in [DIAMOND,"아데나","마일리지"]:continue
		var base: Dictionary=world._find_catalog_item_record(name)
		if str(base.get("slot",""))=="currency":continue
		var equipment_ids: Array=[]
		for uid: String in instances:
			var entry: Variant=instances[uid]
			if entry is Dictionary and entry.get("name")==name and D.equipment(entry.get("record",base)) and not entry.has(STACK.QUANTITY):equipment_ids.append(uid)
		if not equipment_ids.is_empty():
			for uid: String in equipment_ids:
				if equipped.has(uid):continue
				var record: Dictionary=instances[uid].get("record",base)
				found.append(_entry(name,uid,1,record,true,int(instances[uid].get("level",0))))
			continue
		found.append(_entry(name,"",int(count),base,false,0))
	return found

func _entry(name: String, uid: String, count: int, record: Dictionary, equipment: bool, level: int) -> Dictionary:
	var id: int=int(record.get("source_item_class_id",0)) if record.get("source_m_native_item",false) else 0
	var reason: String=""
	if id<=0:reason="원본 523 아이템만 거래소에 등록할 수 있습니다"
	elif not _mapping.has(id) or not bool(SOURCE.row("ItemClass",id).get("IsTradable",false)):reason="거래소 거래 불가 아이템입니다"
	elif str(record.get("bless_state","normal")) not in ["","normal"]:reason="축복·저주 아이템은 등록할 수 없습니다"
	elif world._item_locked(name,uid) or world._item_locked(name):reason="잠긴 아이템입니다"
	return {"reference":name+("@@@"+uid if not uid.is_empty() else ""),"name":name,"instance_id":uid,"count":count,"record":record,"item_class_id":id,"equipment":equipment,"level":level,"registrable":reason.is_empty(),"reason":reason}

func entry(reference: String) -> Dictionary:
	for row: Dictionary in bag_entries():
		if str(row.reference)==reference:return row
	return {}

## The tax and commission of a sale of total `price` 다이아.
static func settlement(price: int) -> Dictionary:
	var gross: int=price
	var tax: int=gross*TAX_PERCENT/100
	return {"gross":gross,"tax":tax,"net":gross-tax,"commission":COMMISSION}

## 판매 등록 quote: `quantity` of the bag entry for a total `price` 다이아.
func quote_sell(reference: String, quantity: int, price: int) -> Dictionary:
	var row: Dictionary=entry(reference)
	if row.is_empty():return _fail("판매할 아이템을 찾지 못했습니다")
	if not bool(row.registrable):return _fail(str(row.reason))
	if quantity<1 or quantity>int(row.count):return _fail("판매 수량을 확인해주세요")
	if price<1:return _fail("판매 금액을 확인해주세요")
	var money: Dictionary=settlement(price)
	if int(money.gross)<MIN_SALE_AMOUNT:return _fail("총 판매 금액은 %d 다이아 이상부터 등록 가능합니다" % MIN_SALE_AMOUNT)
	if int(money.gross)>MAX_SALE_AMOUNT:return _fail("총 판매 금액이 최대 금액을 초과합니다")
	var active: int=0
	for listing: Dictionary in my_listings():
		if str(listing.status)!="sold":active+=1
	if active>=MAX_SELL_COUNT:return _fail("판매 등록은 최대 %d개까지 가능합니다" % MAX_SELL_COUNT)
	if int(world.gold)<COMMISSION:return _fail("등록 수수료 아데나가 부족합니다")
	var reference_price: float=reference_unit_price(int(row.item_class_id))
	var unit: float=float(price)/float(quantity)
	money.merge({"ok":true,"entry":row,"quantity":quantity,"price":price,"unit_price":unit,"reference":reference_price,"low_warning":unit<reference_price*0.8,"gold":int(world.gold)},true)
	return money

## TWILIGHT 근사: minutes until a simulated buyer takes a listing priced
## `unit_price` against the lowest other unit price; -1 = no buyer.
static func sale_delay(unit_price: float, reference: float) -> int:
	if reference<=0.0:return -1
	var ratio: float=unit_price/reference
	if ratio<=0.9:return 5
	if ratio<=1.0:return 30
	if ratio<=1.2:return 180
	if ratio<=1.5:return 1440
	return -1

func register(reference: String, quantity: int, price: int) -> Dictionary:
	var quoted: Dictionary=quote_sell(reference,quantity,price)
	if not quoted.ok:return quoted
	var owner: Object=shop()
	var started: Dictionary=owner._start()
	if not started.get("ok",false):return _fail(str(started.get("reason","거래 처리 중입니다")))
	var row: Dictionary=quoted.entry
	var removed: Dictionary=_stage_removal(row,quantity)
	if not removed.get("ok",false):
		owner._busy=false
		return removed
	var now: int=_now()
	var trade: Dictionary=state()
	var id: String=str(int(trade.next_id))
	var delay: int=sale_delay(float(quoted.unit_price),float(quoted.reference))
	var listing: Dictionary={"name":str(row.name),"item_class_id":int(row.item_class_id),"quantity":quantity,"price":price,"registered_at":now,"expires_at":now+SALE_MINUTES*60,"sell_at":(now+delay*60) if delay>=0 else -1,"kind":str(removed.kind),"instance_id":str(row.instance_id),"instance":removed.get("instance",{}),"commission":COMMISSION}
	trade.listings[id]=listing
	trade.next_id=int(trade.next_id)+1
	var next: Dictionary=owner.export_state()
	next[STATE_KEY]=trade
	var extra: Dictionary={}
	if removed.has("consumable_state"):extra["consumable_state"]=removed.consumable_state
	var result: Dictionary=owner._commit(next,removed.inventory,int(world.gold)-COMMISSION,removed.item_instances,int(world.next_item_instance_id),extra)
	if not result.get("ok",false):return _fail(str(result.get("reason","저장 실패")))
	_after_change()
	return {"ok":true,"id":id,"message":"%s ×%d 판매 등록 · %d 다이아" % [str(row.name),quantity,price]}

## The staged bag without the listed goods (the exact physical entries).
func _stage_removal(row: Dictionary, quantity: int) -> Dictionary:
	var name: String=str(row.name)
	var instances: Dictionary=world.item_instances.duplicate(true)
	if bool(row.equipment):
		var uid: String=str(row.instance_id)
		if quantity!=1 or not instances.has(uid):return _fail("판매할 장비 개체를 찾지 못했습니다")
		var inventory: Dictionary=world.inventory.duplicate(true)
		var kept: Dictionary=instances[uid].duplicate(true)
		instances.erase(uid)
		inventory[name]=int(inventory.get(name,0))-1
		if int(inventory[name])<=0:inventory.erase(name)
		return {"ok":true,"kind":"instance","instance":kept,"inventory":inventory,"item_instances":instances}
	var physical: Array=[]
	for uid: String in instances:
		var entry_value: Variant=instances[uid]
		if entry_value is Dictionary and entry_value.get("name")==name:physical.append(uid)
	if physical.is_empty():
		var bag: Dictionary=world.inventory.duplicate(true)
		if int(bag.get(name,0))<quantity:return _fail("판매할 수량이 부족합니다")
		bag[name]=int(bag[name])-quantity
		if int(bag[name])==0:bag.erase(name)
		return {"ok":true,"kind":"stack","inventory":bag,"item_instances":instances}
	var requests: Array=[]
	var left: int=quantity
	physical.sort()
	for uid: String in physical:
		if left<=0:break
		var owned: Dictionary=STACK.proof(world,uid)
		if owned.is_empty():continue
		var take: int=mini(left,int(owned.remaining))
		if take<1:continue
		requests.append({"physical_id":uid,"quantity":take,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-take,"source_native_stack_receipt":owned.receipt})
		left-=take
	if left>0:return _fail("원본 물리 수량이 부족합니다")
	var debited: Dictionary=STACK.stage_debit(world,requests)
	if not debited.get("ok",false):return _fail(str(debited.get("reason",debited.get("error","원본 물리 수량 차감 실패"))))
	var overrides: Dictionary=debited.overrides
	return {"ok":true,"kind":"native_stack","inventory":overrides.inventory,"item_instances":overrides.item_instances,"consumable_state":overrides.consumable_state}

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
		var sold: bool=int(row.sell_at)>=0 and int(row.sell_at)<=now and int(row.sell_at)<int(row.expires_at)
		row["status"]="sold" if sold else ("expired" if now>=int(row.expires_at) else "selling")
		row["remaining_seconds"]=maxi(0,int(row.expires_at)-now)
		row.merge(settlement(int(row.price)),true)
		found.append(row)
	return found

## 판매 취소 (selling) / 회수 (expired): the goods go back to the bag.
func take_back(id: String) -> Dictionary:
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
			var supplied: Dictionary=world.stage_source_item_grants([{"item_class_id":int(row.item_class_id),"amount":int(row.quantity),"bless_raw":1,"enchant":0}],{"kind":"trade523_return","listing_id":id})
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
