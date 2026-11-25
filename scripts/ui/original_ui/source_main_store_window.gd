extends RefCounted
## The original 523 NPC 상점 window: Store_All (frame, 상 점 title, close)
## with the goods list on the left (Store_PurchaseAuto's ListView, one
## Store_PurchaseAutoList row per product: picture, name, 보유 count, price)
## and the 소지품 grid on the right (Store_Inventory). The 소지품 grid of the
## client names QuickSlotEdit_SlotSet, absent from the 523 client; by the
## user's decision (A안) it shows Inventory_Slot_Set lines (the storage
## window's rule). Products, prices, the quantity confirmation and payment
## come from the talking NPC's original merchant (MerchantGoods of the
## merchant whose EarthObject is that NPC, source523_npc_definitions); quotes,
## the quantity confirmation and payment stay with world.source_shop
## (quote_merchant / buy_merchant, delivered through the order box as in the
## 원본 상점 panel). An NPC with no merchant link lists no goods.
## At a 잡화상인 a 소지품 grid tap sells that item (original keypad count,
## see sells()); elsewhere the grid is shown only.
## Left out (no rule here): 자동 주문 (target amount slider, 1/2/3 SET), the
## cart, the 판매 / 자동 판매 mode scenes (not in the UI pack), the batch count
## buttons, 혈맹 코인, tax, help, tooltips and every effect layer.
const RETIRED_ITEMS = preload("res://scripts/loot/retired_enhancement_items523.gd")
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const Storage=preload("res://scripts/ui/original_ui/source_main_storage_window.gd")
const TownNpcs=preload("res://scripts/npc/source523_town_npcs.gd")
const ShopCatalog=preload("res://scripts/shop/source523_shop_catalog.gd")
const Calculator=preload("res://scripts/ui/original_ui/source_main_calculator.gd")
const Runtime=preload("res://scripts/shop/source523_shop_runtime.gd")
const Router=preload("res://scripts/ui/original_ui/source_button_router.gd")
const ROOT="UI/Store/Store_All.csb"
const BAG="UI/Store/Store_Inventory.csb"
const GOODS="UI/Store/Store_PurchaseAuto.csb"
const ROW="UI/Store/Store_PurchaseAutoList.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316,15012,9004,6880]}
const REQUIRED: Array[String]=[ROOT,BAG,GOODS,ROW,SET,SLOT]
## Store_All_Layout in StoreScene (600, 337.5).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
const P_BAG="Store_Inventory/Nd_Inventory/"
const P_GOODS="Store_PurchaseAuto/Nd_PurchaseAuto/"
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
## Store_Inventory's SlotSet position in its ScrollView (Storage_Inventory's).
const BAG_ROW_POSITION=Vector2(155.0,-460.0)
const ROW_HEIGHT: float=81.0
const ROW_GAP: float=1.0
const OTHER: Array[String]=["Store_Cart","Store_SaleInventory","Store_Sale","Store_SaleAuto","Store_BtnSet","Store_Sell","Nd_SaleButton","Nd_Max","Nd_SaleButton_2","Nd_Button","Nd_AutoSale","Nd_AutoPurchase","Btn_Repurcharse","Nd_ClanCoin","Nd_SystemMessage","Nd_Tax","Btn_Help","Fx_Activate","Hud_AutoMessage_Dungeon","FullFrameType_A/Fx_Img_BG_Particle","Panel_Spine"]
const TAB_NODES={"all":"Btn_All","equip":"Btn_Equipment","consume":"Btn_Consume","etc":"Btn_Etc"}
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _npc_id: String=""
## The talking NPC's original EarthObject class (0: none).
var npc_class: int=0
## The talking NPC's shown name ("[잡화상인] 세린").
var npc_name: String=""
var last_sale: Dictionary={}
var _merchants: Array[int]=[]
var _scene: Node2D
var _tab: String="all"
var _bag: RefCounted=Storage.Scroller.new()
var _list: RefCounted=Storage.Scroller.new()
var _goods: Array=[]
var _bag_rows: Array=[]
var _last_out: Dictionary={}
var last_result: Dictionary={}
## The original quantity keypad (Common_Calculator) of a purchase.
var calculator: RefCounted=Calculator.new()
var last_purchase: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_store_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	calculator.configure(pack)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## `npc_id` is the talking town NPC (empty: no merchant, no goods).
func open(parent: Node, npc_id: String) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_store_window_host_unavailable")
	_parent=weakref(parent)
	_npc_id=npc_id
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var npc: Dictionary=TownNpcs.record(hud.get_parent(),npc_id) if hud!=null and not npc_id.is_empty() and hud.get_parent().get("field_map")!=null else {}
	npc_class=int(npc.get("source523_earth_object_class_id",0))
	npc_name=str(npc.get("name",""))
	_tab="all"
	_bag.y=null
	_list.y=null
	return _stage()

func refresh() -> Dictionary:
	if not is_open():return {"ok":true,"handled":false}
	_bag.keep()
	_list.keep()
	return _stage()

func close() -> void:
	calculator.close()
	var previous: Node2D=_scene
	_scene=null
	_bag.content=null
	_list.content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func goods() -> Array:
	return _goods

func bag_rows() -> Array:
	return _bag_rows

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

## Every bag stack and physical item (the bag's own identities).
static func rows_of(inventory: Dictionary, instances: Dictionary) -> Array:
	var by_name: Dictionary={}
	for raw_id: Variant in instances.keys():
		var entry: Variant=instances[raw_id]
		if entry is Dictionary:
			var name: String=str(entry.get("name",""))
			if not by_name.has(name):by_name[name]=[]
			by_name[name].append(str(raw_id))
	var names: Array=inventory.keys()
	names.sort()
	var rows: Array=[]
	for raw_name: Variant in names:
		var name: String=str(raw_name)
		var count: int=int(inventory[raw_name])
		if count<=0 or name=="아데나":continue
		if by_name.has(name):
			var ids: Array=by_name[name]
			ids.sort()
			for id: String in ids:rows.append({"name":name,"count":1,"instance_id":id,"level":int(instances[id].get("level",0))})
		else:rows.append({"name":name,"count":count,"instance_id":""})
	return rows

static func price_text(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

## Merchants whose original EarthObject is `class_id` (object_links).
static func merchants_for(records: Dictionary, class_id: int) -> Array[int]:
	var out: Array[int]=[]
	if class_id<=0:return out
	for key: Variant in records.keys():
		var row: Variant=records[key]
		if not row is Dictionary:continue
		for obj: Variant in row.get("object_links",[]):
			if obj is Dictionary and int(obj.get("earth_object_id",-1))==class_id and not out.has(int(key)):out.append(int(key))
	out.sort()
	return out

## The merchants' goods in MerchantGoods order of DisplayPriority, ID.
func _merchant_goods(world: Object) -> Array:
	var runtime: Object=world.get("source_shop")
	var catalog: RefCounted=ShopCatalog.session()
	if runtime==null or catalog==null or not catalog.available():return []
	runtime.call("bind_source",catalog)
	_merchants=merchants_for(runtime.npc_definitions.records,npc_class)
	var wanted: Dictionary={}
	for merchant: int in _merchants:
		for id: Variant in runtime.npc_definitions.records.get(str(merchant),{}).get("goods_ids",[]):wanted[int(id)]=true
	var rows: Array=[]
	for row: Dictionary in catalog.rows("MerchantGoods"):
		if not wanted.has(int(row.ID)):continue
		var class_id: int=int(row.get("ItemClassID",0))
		if RETIRED_ITEMS.item(class_id):continue
		var item: Dictionary=catalog.record("ItemClass",class_id)
		var title: String=catalog.label(int(item.get("DescID",0)))
		var quote: Dictionary=runtime.call("quote_merchant",int(row.ID),1)
		var payment: Dictionary=quote.get("payment",{}) if quote.get("payment") is Dictionary else {}
		rows.append({"id":int(row.ID),"class_id":class_id,"name":title if not title.is_empty() else str(item.get("Name","아이템 #%d" % class_id)),
			"price":int(payment.get("amount",-1)),"ok":bool(quote.get("ok",false)),"reason":str(quote.get("reason","")),"priority":int(row.get("DisplayPriority",0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority<b.priority or (a.priority==b.priority and a.id<b.id))
	return rows

func _record(world: Object, row: Dictionary) -> Dictionary:
	var name: String=str(row.get("name",""))
	var record: Dictionary=world.call("_find_catalog_item_record",name)
	# A blessed/cursed stack is not a catalog row; its picture is its base row's.
	if record.is_empty():record=preload("res://scripts/loot/patch523_monster_drops.gd").bless_stack_record(name,func(base: String) -> Dictionary: return world.call("_find_catalog_item_record",base))
	var id: String=str(row.get("instance_id",""))
	var instances: Variant=world.get("item_instances")
	if not id.is_empty() and instances is Dictionary and instances.has(id) and instances[id] is Dictionary:record=instances[id].get("record",record)
	return record

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_store_window_host_unavailable")
	var world: Object=hud.get_parent()
	_goods=_merchant_goods(world)
	var all_rows: Array=rows_of(world.get("inventory"),world.get("item_instances"))
	var classify: Callable=func(row: Dictionary) -> String:
		var record: Dictionary=_record(world,row)
		return Storage.kind_of(record,not str(world.call("_enhancement_kind_for_record",record)).is_empty())
	_bag_rows=Storage.filter(all_rows,_tab,classify)
	var spec: Dictionary={}
	for name: String in OTHER:spec[name]={"exclude":true}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for tab_name: String in TAB_NODES:
		var on: bool=_tab==tab_name
		spec[P_BAG+"Tab/"+TAB_NODES[tab_name]+"_On"]={"visible":on}
		spec[P_BAG+"Tab/"+TAB_NODES[tab_name]+"_Off"]={"visible":not on,"activate":Callable(self,"_set_tab").bind(tab_name)}
	spec[P_BAG+"Nd_Number/Label_Count"]={"role":"source_text","text":str(_bag_rows.size())}
	spec[P_BAG+"ScrollView"]={"role":"source_scroll","input":Callable(_bag,"input")}
	# The goods list: 구매 목록 with 보유 / 가격 columns over the authored headers.
	spec[P_GOODS+"Label_Title"]={"role":"source_text","text":"구매 목록"}
	spec[P_GOODS+"Label_Volume"]={"role":"source_text","text":"가 격"}
	spec[P_GOODS+"ListView"]={"input":Callable(_list,"input")}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var pictures: int=0
	var listed: Dictionary=_fill_goods(hud,world,next,out)
	var bag_content: Variant=Storage.new()._scroll_content(next,out,P_BAG+"ScrollView") if listed.get("ok",false) else null
	if listed.get("ok",false) and not bag_content is Node2D:listed=_fail("source_store_window_bag_rows_missing")
	var added: Dictionary=_add_bag_lines(world,bag_content) if listed.get("ok",false) else listed
	if not added.get("ok",false):
		next.free()
		last_result=added
		return added
	pictures=int(listed.get("pictures",0))+int(added.get("pictures",0))
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	Storage._input_below_content(next,out,P_BAG+"ScrollView")
	_bag.bind(bag_content,BAG_ROW_POSITION.y,maxi(1,ceili(float(_bag_rows.size())/float(SET_SLOTS.size()))))
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"goods":_goods.size(),"bag_rows":_bag_rows.size(),"pictures":pictures,"tab":_tab}
	return last_result

func _fill_goods(hud: Node, world: Object, root: Node2D, out: Dictionary) -> Dictionary:
	var located: Dictionary=NamedTree.locate(root,out,P_GOODS+"ListView")
	var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _fail("source_store_window_goods_list_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,GOODS,"Nd_PurchaseAuto/ListView")
	var pictures: int=0
	var owned: Dictionary=hud.lineage_inventory_ui.inventory
	for index: int in range(_goods.size()):
		var entry: Dictionary=_goods[index]
		var name: String=str(entry.name)
		var row_out: Dictionary={}
		var row_built: Dictionary=_tree.scene_of(ROW,{
			"Panel":{"input":Callable(_list,"input")},
			"Panel/Label_Item":{"role":"source_text","text":name},
			"Panel/Text_Amount":{"role":"source_text","text":price_text(int(owned.get(name,0)))},
			"Panel/Label_Amount_On":{"role":"source_text","text":price_text(int(entry.price)) if int(entry.price)>=0 else "-"},
			"Panel/Label_Amount_Off":{"visible":false},
			"Panel/Nd_Slider":{"exclude":true},
			"Panel/Nd_Lock":{"exclude":true},
			"Panel/Btn_Calculator":{"activate":Callable(self,"_buy_requested").bind(index)},
			"Panel/Slot/Btn":{"activate":Callable(self,"_buy_requested").bind(index)},
			"Panel/Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false},
			"Panel/Slot/Sp_Select":{"visible":false},
			"Panel/Slot/Text_Amount":{"visible":false},
		},row_out)
		if not row_built.get("ok",false):return row_built
		for suffix: String in ["Panel/Btn_Calculator","Panel/Slot/Btn"]:forward_drag(row_built.scene,row_out,suffix,Callable(_list,"input"))
		# The product picture is no bag item: its tap buys like Btn_Calculator.
		_route_slots(row_built.scene)
		_tree.add_row(content,ROW,row_built.scene,index,size,ROW_GAP)
		if _class_picture(row_built.scene,row_out,"Panel/Slot/Sp_IconSample",int(entry.class_id)):pictures+=1
	_list.content=content
	_list.top=content.position.y
	_list.bottom=minf(_list.top,size.y-(ROW_HEIGHT+ROW_GAP)*float(_goods.size()))
	if _list.y!=null:content.position.y=clampf(float(_list.y),_list.bottom,_list.top)
	return {"ok":true,"pictures":pictures}

func _add_bag_lines(world: Object, content: Node2D) -> Dictionary:
	var pictures: int=0
	var lines: int=maxi(1,ceili(float(_bag_rows.size())/float(SET_SLOTS.size())))
	for line: int in range(lines):
		var row_out: Dictionary={}
		var spec: Dictionary={}
		for name: String in ["Nd_Slot/Fx_Slot_UnLock","Nd_Slot_Extension","Nd_Slot_Extension_Lock"]:spec[name]={"exclude":true}
		for index: int in range(SET_SLOTS.size()):
			var key: String="Nd_Slot/"+SET_SLOTS[index]+"/"
			var at: int=line*SET_SLOTS.size()+index
			var row: Dictionary=_bag_rows[at] if at<_bag_rows.size() else {}
			var text: String=Storage.amount_text(row) if not row.is_empty() else ""
			spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
			spec[key+"Sp_Select"]={"visible":false}
			spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
			spec[key+"Btn"]={"activate":Callable(self,"_bag_tapped").bind(at)}
		var built: Dictionary=_tree.scene_of(SET,spec,row_out)
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		for index: int in range(SET_SLOTS.size()):forward_drag(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn",Callable(_bag,"input"))
		scene.position=BAG_ROW_POSITION+Vector2(0.0,Storage.ROW_PITCH*float(line))
		# A 잡화상인 buys from this grid: its slots answer the HUD router.
		if sells():_route_slots(scene)
		content.add_child(scene)
		for index: int in range(SET_SLOTS.size()):
			var at: int=line*SET_SLOTS.size()+index
			if at<_bag_rows.size() and _picture(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",_record(world,_bag_rows[at]),str(_bag_rows[at].get("name",""))):pictures+=1
	return {"ok":true,"pictures":pictures}

func _picture(root: Node2D, out: Dictionary, suffix: String, record: Dictionary, title: String) -> bool:
	if record.is_empty():return false
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item(record,title)
	return NativeIcons.show_item(located.player,located.offset,info,_hud.get_ref())

func _class_picture(root: Node2D, out: Dictionary, suffix: String, class_id: int) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false) or class_id<=0:return false
	var info: Dictionary=SourceImages.describe_item_class(class_id)
	return NativeIcons.show_item(located.player,located.offset,info,_hud.get_ref())

## --- Actions -----------------------------------------------------------------

## Whether the talking NPC buys items (user list 2026-11-21 #16 "잡화 NPC에게
## 판매 가능하게"): a 잡화상인. The client sells to its 아이템 매입 상인
## (BuyList, MerchantGoods DialogActionTypeID 2): the price is that original
## buy row (source_shop.sale_quote), else TWILIGHT's existing buyback price
## (inventory_automation.sale_quote) (TWILIGHT 근사: the 잡화상인 buys).
func sells() -> bool:
	return npc_name.contains("잡화상인")

## A 소지품 grid item at a 잡화상인: the sale quote, the original quantity
## keypad (Common_Calculator, up to the owned count; equipment one by one),
## then world._sell_shop_item (adena in, item out, one save). Elsewhere the
## grid is shown only.
func _bag_tapped(at: int = -1) -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	if _bag.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	if not sells() or at<0 or at>=_bag_rows.size():return {"ok":true,"shown_only":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if hud==null or parent==null:return _fail("source_store_window_host_unavailable")
	var world: Object=hud.get_parent()
	var row: Dictionary=_bag_rows[at]
	var name: String=str(row.get("name",""))
	var id: String=str(row.get("instance_id",""))
	# The original buy row first (source523 BuyList), else the existing sale.
	var quote: Dictionary=world.get("source_shop").call("sale_quote",name,1,id)
	if not quote.get("ok",false):
		var existing: Dictionary=world.get("inventory_automation").call("sale_quote",name,1,id,world.get("inventory"),world.get("item_instances"),int(world.get("gold")),false)
		if existing.get("ok",false):quote=existing
	if not quote.get("ok",false):
		hud.show_message(str(quote.get("reason","판매할 수 없는 아이템입니다")))
		return {"ok":true,"refused":str(quote.get("reason",""))}
	var limit: int=1 if not id.is_empty() else clampi(int(world.get("inventory").get(name,0)),1,SELL_MAX)
	var opened: Dictionary=calculator.open(parent,limit,Callable(self,"sell").bind(name,id))
	if opened.get("handled",false):return {"ok":true,"requested_sale":name,"calculator":true,"maximum":limit}
	hud.confirm_action("원본 상점 · 판매","%s\n개당 %s 아데나 · 판매할 수량을 선택하세요" % [name,price_text(int(quote.get("payment",0)))],"판매",func(amount: int) -> void: sell(amount,name,id),limit)
	return {"ok":true,"requested_sale":name,"calculator":false,"maximum":limit}

## The most one sale takes (the existing buyback's single-stack limit).
const SELL_MAX: int=99

## Sells `amount` of `name` (equipment: its physical `id`) for adena.
func sell(amount: int, name: String, id: String) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_store_window_host_unavailable")
	var world: Object=hud.get_parent()
	var gold_before: int=int(world.get("gold"))
	var count_before: int=int(world.get("inventory").get(name,0))
	var original: Dictionary=world.get("source_shop").call("sale_quote",name,amount,id)
	if original.get("ok",false):
		var sold: Dictionary=world.get("source_shop").call("sell_to_merchant",name,amount,id)
		hud.show_message(str(sold.get("reason","판매할 수 없습니다")))
		if sold.get("ok",false):
			world.call("_update_hud")
			hud.refresh_inventory(world.get("inventory"))
	else:world.call("_sell_shop_item",name,amount,id)
	var paid: int=int(world.get("gold"))-gold_before
	last_sale={"ok":paid>0 and int(world.get("inventory").get(name,0))==count_before-amount,"name":name,"quantity":amount,"payment":paid}
	refresh()
	return last_sale

## A product row -> the original merchant quote, the original quantity keypad
## (Common_Calculator) and world.source_shop.buy_merchant: the price is paid
## and the goods go into the bag in one save (an original NPC 상점 purchase
## goes straight into the bag; it is refused when the bag cannot take it).
func _buy_requested(index: int) -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	if _list.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	if index<0 or index>=_goods.size():return {"ok":true,"empty":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_store_window_host_unavailable")
	var world: Object=hud.get_parent()
	var runtime: Object=world.get("source_shop")
	var id: int=int(_goods[index].id)
	var quote: Dictionary=runtime.call("quote_merchant",id,1)
	if not quote.get("ok",false):
		hud.show_message(str(quote.get("reason","구매할 수 없는 상품입니다")))
		return {"ok":true,"refused":str(quote.get("reason",""))}
	var limit: int=affordable(quote,world)
	if limit<1:
		hud.show_message("NPC 구매 재화 부족")
		return {"ok":true,"refused":"NPC 구매 재화 부족"}
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var opened: Dictionary=calculator.open(parent,limit,Callable(self,"purchase").bind(id)) if parent!=null else _fail("source_store_window_host_unavailable")
	if opened.get("handled",false):return {"ok":true,"requested":id,"calculator":true,"maximum":limit}
	# No keypad member: the existing quantity confirmation.
	var name: String=str(_goods[index].name)
	var body: String="%s\n단가 %s · 구매할 수량을 선택하세요\n구매품은 가방에 바로 들어갑니다" % [name,price_text(int(_goods[index].price))]
	hud.confirm_action("원본 상점 · 구매",body,"구매",func(amount: int) -> void: purchase(amount,id),limit)
	return {"ok":true,"requested":id,"calculator":false,"maximum":limit}

## The largest count the balance pays for (1..1000).
static func affordable(quote: Dictionary, world: Object) -> int:
	var payment: Dictionary=quote.get("payment",{}) if quote.get("payment") is Dictionary else {}
	var unit: int=int(payment.get("amount",0))
	if unit<=0:return 0
	var binding: Dictionary=quote.get("payment_binding",{}) if quote.get("payment_binding") is Dictionary else {}
	var balance: int=int(world.get("gold")) if binding.get("gold",false) else int(world.get("inventory").get(str(binding.get("name","")),0))
	@warning_ignore("integer_division")
	return clampi(balance/unit,0,1000)

## Pays `amount` of merchant row `id` and puts the goods into the bag.
func purchase(amount: int, id: int) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_store_window_host_unavailable")
	var world: Object=hud.get_parent()
	var result: Dictionary=world.get("source_shop").call("buy_merchant",id,amount,Runtime.Delivery.BAG)
	last_purchase=result
	hud.show_message(str(result.get("reason","거래를 완료했습니다")))
	if result.get("ok",false):
		world.call("_update_hud")
		hud.refresh_inventory(world.get("inventory"))
	refresh()
	return result

## Marks the original Common_Slot roots under `node` as router-owned (a
## store row's product picture; PointerTransfer owns only bag/quick slots).
static func _route_slots(node: Node) -> void:
	var identity: Variant=node.get_meta("original_ui_source",{})
	if identity is Dictionary and identity.get("scene")==SLOT:node.set_meta("source_slot_routed",true)
	for child: Node in node.get_children():_route_slots(child)

## A button inside a list passes its finger's drag to that list (the router's
## `source_drag_forward`; the GUI path for a mouse).
static func forward_drag(root: Node2D, out: Dictionary, suffix: String, input: Callable) -> void:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var button: Variant=node.get_meta("source_button") if is_instance_valid(node) and node.has_meta("source_button") else null
	if not is_instance_valid(button):return
	button.set_meta(Router.DRAG_META,input)
	var area: Variant=button.get("_input_area")
	if area is Control and not area.gui_input.is_connected(input):area.gui_input.connect(input)

func _set_tab(tab_name: String) -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	_tab=tab_name
	_bag.y=null
	_list.keep()
	return _stage()

func _close_requested() -> Dictionary:
	if calculator.is_open():return {"ok":true,"ignored_under_keypad":true}
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
