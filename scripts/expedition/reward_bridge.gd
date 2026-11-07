extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Exact inventory bindings only. Effect/craft/shop/automation engines stay with their owners.
const CURRENCY=preload("res://scripts/loot/currency_drops.gd")
const CARDS=preload("res://scripts/expedition/reward_cards.gd")
const WALLETS={3242:"변신 제작 코인",3252:"마법인형 제작 코인",3631:"명예 코인",246058:"성물 제작 코인"}
const EXCLUDED=[269382,269392,269402] # Existing user exclusion: Ziggurat reward boxes.
const OWNED_TICKETS=[166744,254088,342064,342074,352054,352064]
const TICKET_POLICY_TEXT="TWILIGHT 소지 티켓1개 소비 · 원본 추첨 풀·지급량 · 추가 구매 비용 없음 · 미연결 대상은 티켓 보존"
const DROP_SCRIPT="res://scripts/loot/patch523_monster_drops.gd"
const USE_SCRIPT="res://scripts/loot/patch523_item_use.gd"
const SUPPLIER_SCRIPT="res://scripts/loot/patch523_item_inventory.gd"
const MATERIAL_SCRIPT="res://scripts/crafting/patch523_expedition_materials.gd"

static func untagged(name:String)->String:
	var value:String=name.strip_edges()
	while value.begins_with("["):
		var end:int=value.find("]")
		if end<0:return ""
		value=value.substr(end+1).strip_edges()
	return value

static func protected_reason(item:Dictionary)->String:
	if item.is_empty():return "원본 아이템 정의 없음 · 아이템 보존"
	if EXCLUDED.has(int(item.ID)):return "사용자가 제외한 콘텐츠의 보상입니다 · 아이템 보존"
	if bool(item.get("TestItem",true)):return "원본 테스트 아이템입니다 · 일반 사용 차단·아이템 보존"
	return ""

static func host_property(host:Node,name:String)->Variant:
	for property:Dictionary in host.get_property_list():
		if property.name==name:return host.get(name)
	return null

static func provider()->Variant:
	return load(DROP_SCRIPT) if ResourceLoader.exists(DROP_SCRIPT) else null

static func consumer()->Variant:
	return load(USE_SCRIPT) if ResourceLoader.exists(USE_SCRIPT) else null

static func supplier()->Variant:
	return load(SUPPLIER_SCRIPT) if ResourceLoader.exists(SUPPLIER_SCRIPT) else null

static func exposes(service:Variant,method:String)->bool:
	if service==null:return false
	var methods:Array=service.get_script_method_list() if service is Script else service.get_method_list()
	for entry:Dictionary in methods:
		if entry.name==method:return true
	return false

static func definition(service:Variant,id:String)->Dictionary:
	# Full catalogs keep original rows in SHA-checked shards, not root summaries.
	if exposes(service,"definition_id"):return service.definition_id(id)
	return service.data().get("item_definitions",{}).get(id,{}) if service!=null else {}

static func shop(world:Node)->Variant:
	var service:Variant=host_property(world,"source_shop")
	var runtime:Variant=host_property(world,"expedition_local")
	return service if service!=null else (runtime.reward_recipients.get("source_shop") if runtime!=null else null)

static func open_issued_owner_ui(world:Node,key:String,item_name:String)->Dictionary:
	# A capability boundary, not another craft/enhancement executor. Selection
	# does not debit, roll, save, or acknowledge a new producer receipt.
	var parts:PackedStringArray=key.split(":")
	if parts.size()!=3:return {"handled":false}
	if int(parts[0]) in [137,138]:
		if not world.has_method("patch523_open_expedition_enhancement"):
			return {"handled":true,"ok":false,"committed":false,"error":"원본 탐험 주문서의 강화 소유자가 미설치입니다 · 주문서 보존"}
		var opened:Variant=world.call("patch523_open_expedition_enhancement",item_name)
		if opened is Dictionary and opened.get("handled",false):return opened
		return {"handled":true,"ok":false,"committed":false,"error":"원본 강화 소유자의 선택 결과를 확인하세요 · 자동 재시도 안함"}
	if not world.has_method("_patch523_craft_context") or not world.has_method("_patch523_craft_requested") or not world.has_method("_patch523_craft_item_index") or not ResourceLoader.exists(MATERIAL_SCRIPT):return {"handled":false}
	var owner:Variant=host_property(world,"expedition_local")
	var book:Variant=host_property(world,"patch523_equipment")
	var helper:Script=load(MATERIAL_SCRIPT)
	if int(parts[0]) not in helper.get_script_constant_map().get("IDS",[]):return {"handled":false}
	var context:Variant=world.call("_patch523_craft_context")
	if book==null or not context is Dictionary or context.get("expedition_owner")!=owner:return {"handled":true,"ok":false,"committed":false,"error":"탐험 재료의 제작 소유자 연결 확인 필요 · 재료 보존"}
	var material:Dictionary={"source_id":parts[0],"item":book.record(parts[0]).get("name",""),"physical":false,"bless_code":int(parts[1]),"level":int(parts[2])}
	var owned:Dictionary=helper.owned(book,material,world.inventory,world.item_instances,world.ui_preferences.get("item_locks",{}),context)
	if not owned.has(item_name):return {"handled":true,"ok":false,"committed":false,"error":"원본 재료의 발급·소지 증명 확인 필요 · 재료 보존"}
	# Ownership admission is not recipe/server qualification. Those conditions
	# remain with the real owner's quote/execute/one-save path.
	if not world.hud.has_method("open_crafting"):return {"handled":true,"ok":false,"committed":false,"error":"원본 제작 화면 미설치 · 재료 보존"}
	world.hud.open_crafting()
	return {"handled":true,"ok":true,"committed":false,"stage":"recipe_selection","message":"제작법을 선택하고 원본 조건을 확인하세요"}

static func claim_selection(world:Node,saved:Dictionary,entity_id:int)->bool:
	# The owner's dialog confirms later. Recheck our receipt and lock at that
	# boundary, then let the original consumer own selection/debit/output/save.
	var runtime:Variant=host_property(world,"expedition_local")
	var service:Variant=consumer()
	if runtime==null or service==null or runtime.busy or runtime.save_blocked or not runtime.validate(runtime.state).is_empty():return false
	var name:String=str(saved.get("name",""))
	if world._item_locked(name,""):world.hud.show_message("잠긴 탐험 선택상자입니다 · 아이템 보존");return false
	var key:String=str(runtime.state.get("native_handoffs",{}).get(name,""))
	if key.is_empty():return false
	var current:Dictionary=runtime._native_target(key)
	if not current.get("ok",false) or not provider().matches(saved,current.record):return false
	return service.claim_selection(world,saved,entity_id)

static func existing_target(host:Node,item:Dictionary,bless:int,enchant:int)->Dictionary:
	if not protected_reason(item).is_empty() or bless!=1 or enchant!=0:return {}
	var id:int=int(item.ID)
	if WALLETS.has(id):
		var name:String=CURRENCY.canonical_name(untagged(str(item.Name)))
		if int(item.CategoryID)!=122 or int(item.GradeID)!=1 or name!=WALLETS[id]:return {}
		var record:Dictionary=host._find_catalog_item_record(name)
		if record.get("slot")!="currency" or record.get("name")!=name or not CURRENCY.COIN_NAMES.has(name):return {}
		return {"ok":true,"record":record,"wallet":name,"kind":"wallet"}
	# Do not merge source-bound/unstorable/undeletable variants into a less restricted legacy stack.
	if int(item.get("CategoryID",0))!=10:return {} # Source stackable material category, not a use-effect item.
	for flag:String in ["IsTradable","IsStorable","IsDroppable","IsDeletable"]:
		if not bool(item.get(flag,false)):return {}
	var found:Array=[]
	for record:Dictionary in host.catalog_db.get("아이템",[]):
		if record.get("source")!="inven" or record.get("sourceId")!=str(id) or record.get("sourceUrl")!="https://lineagem.inven.co.kr/db/item/"+str(id):continue
		if record.get("slot")!="material" or record.get("name")!=untagged(str(item.Name)) or record.get("grade")!=CARDS.GRADES.get(int(item.GradeID)):continue
		found.append(record)
	if found.size()!=1:return {}
	var canonical:Dictionary=host._find_catalog_item_record(str(found[0].name))
	for field:String in ["name","source","sourceId","sourceUrl","slot","type","grade"]:
		if canonical.get(field)!=found[0].get(field):return {}
	return {"ok":true,"record":found[0],"wallet":"","kind":"legacy_material"}

static func recipient(host:Node,record:Dictionary,item:Dictionary,attached:Dictionary={})->String:
	var id:String=str(int(item.ID))
	var equipment:Variant=attached.get("patch523_equipment",host_property(host,"patch523_equipment"))
	if equipment!=null and equipment.item_entry(id).get("item_class",{})==item and equipment.catalog_identity_matches(record,id):return "PR239 제작·가공"
	var automation:Variant=attached.get("inventory_automation",host_property(host,"inventory_automation"))
	if automation!=null and bool(item.get("IsStorable",false)) and not automation.source_rules.resolve(record).is_empty():return "PR251 창고·판매"
	var shop:Variant=attached.get("source_shop",host_property(host,"source_shop"))
	if shop!=null:
		var binding:Dictionary=shop._resolve(shop._token(4,int(item.ID),1),false,host.inventory,host.gold)
		if binding.get("ok",false) and str(binding.binding.get("name",""))==str(record.get("name","")):return "PR247 상품 재료"
	return ""

static func registered_material_target(host:Node,item:Dictionary,bless:int,enchant:int,attached:Dictionary={})->Dictionary:
	# PR239 already has a verified original row and canonical record. Material
	# transfer must not require PR238's effect engine when that owner is absent.
	if not protected_reason(item).is_empty() or bless!=1 or enchant!=0:return {}
	var rules:Variant=attached.get("patch523_equipment",host_property(host,"patch523_equipment"))
	var id:String=str(int(item.ID))
	if rules==null or rules.item_entry(id).get("item_class",{})!=item:return {}
	var record:Dictionary=rules.record(id)
	if record.get("source")!="lineagem_patch523" or not record.get("source_m_native_item",false) or not NATIVE_FIELDS.full(record).get("source_use_spec",{}).is_empty() or not record.get("source_equip_slot_ids",[]).is_empty():return {}
	var registered:Dictionary=host._find_catalog_item_record(str(record.get("name","")))
	if not rules.catalog_identity_matches(registered,id):return {}
	for pair:Array in [["source_is_storable","IsStorable"],["source_is_tradable","IsTradable"],["source_is_droppable","IsDroppable"],["source_is_deletable","IsDeletable"]]:
		if bool(registered.get(pair[0],false))!=bool(item.get(pair[1],false)):return {}
	return {"ok":true,"record":registered,"wallet":"","kind":"native_material","recipient":"PR239 제작·가공"}
