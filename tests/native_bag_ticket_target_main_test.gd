extends SceneTree
## Real Main bag activation keeps the selected receipt, even when another
## exact original stack has the identical catalog name. Source ZIP optional.
const RAW=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const INV=preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const SHOP=preload("res://scripts/shop/source523_shop_catalog.gd")
const CARDS=preload("res://scripts/lineagem_base508.gd")
const MILEAGE=preload("res://scripts/shop/source523_permanent_mileage_tickets.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const MAIN_ID:int=342064
const CROSS_ID:int=352054
var checks:int=0
var failures:Array[String]=[]
var rejected:Dictionary={}
var consumed:int=0
var mixed_consumed:int=0
func ck(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("BAG_TICKET_TARGET_MAIN_FAIL ",label)
	return ok
func _initialize()->void:run.call_deferred()
func refuse(_file:String,payload:Dictionary)->Error:
	rejected=payload
	return ERR_CANT_CREATE
func run()->void:
	var source:String=OS.get_environment("TWILIGHT_BAG_TICKET_TARGET_DEFINITIONS")
	if not source.is_empty() and ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"isolated Main file"):
		await exact(source)
	else:
		ck(MAIN_ID!=CROSS_ID,"two distinct exact source identities in the optional test")
	print("BAG_TICKET_TARGET_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"consumed":consumed,"mixed_consumed":mixed_consumed}))
	quit(0 if failures.is_empty() else 1)

static func freeze(w:Node)->void:
	w.set_process(false);w.save_timer=-100000
	w.field_population.set_process(false);w.player.set_physics_process(false)

static func card_total(w:Node)->int:
	var n:int=0
	for category:String in w.card_draw_fusion.owned:
		n+=w.card_draw_fusion.owned[category].size()
		for copies:Variant in w.card_draw_fusion.spare[category].values():n+=int(copies)
	return n

func exact(source:String)->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);freeze(w)
	ck(QA.enter_game(w),"actual Main enters")
	await process_frame;await process_frame;freeze(w)
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",source);RAW.reset();SHOP.release()
	var input=SHOP.session()
	if not ck(input.available() and RAW.identity().get("source_sha256")==RAW.SOURCE_SHA,"pinned original market data: "+input.error):
		w.queue_free();await process_frame;return
	w.catalog_db=CARDS.apply_catalog(w.catalog_db)
	w.card_draw_fusion.configure(w.catalog_db)
	w.source_shop.bind_source(input)
	w.skill_awakening=w.SKILL_AWAKENING.new();w.skill_awakening.configure(w)
	var record:Dictionary=D.variant_item(D.definition_id(str(MAIN_ID)).get("native_record",{}),1)
	var other:Dictionary=D.variant_item(D.definition_id(str(CROSS_ID)).get("native_record",{}),1)
	if not ck(not STACK.draw_ticket_profile(record).is_empty() and not STACK.draw_ticket_profile(other).is_empty(),"both exact projected tickets"):
		w.queue_free();await process_frame;return
	w.catalog_db["아이템"].append(record);w.catalog_db["아이템"].append(other);w._index_catalog_item_sources()
	var name:String=str(record.name);var origin:Dictionary={"kind":"qa_native_ticket_receipt"}
	var req:Dictionary={"item_class_id":MAIN_ID,"amount":1,"bless_raw":1,"enchant":0}
	var cross:Dictionary={"item_class_id":CROSS_ID,"amount":1,"bless_raw":1,"enchant":0}
	# Definitions are mounted after Main entry in this scoped fixture.
	# Its unbound template store uses the ordinary legacy merge cap, so
	# seed a full first stack and one second copy (as older saves can have).
	var cap:int=preload("res://scripts/loot/native_stack_merge.gd").APPROX_MAX_STACK
	var full:Dictionary=req.duplicate();full.amount=cap
	if not ck(INV.commit(w,[full,req,cross],origin),"three valid original supply receipts: "+w.hud.message_label.text):
		w.queue_free();await process_frame;return
	var uid:Array[String]=[];var different:String=""
	for candidate:String in w.item_instances:
		var item_id:int=int(STACK.proof(w,candidate).get("receipt",{}).get("item_class_id",0))
		if item_id==MAIN_ID:uid.append(candidate)
		if item_id==CROSS_ID:different=candidate
	if not ck(uid.size()==2 and not different.is_empty() and int(STACK.proof(w,uid[0]).get("remaining",0))==cap and int(STACK.proof(w,uid[1]).get("remaining",0))==1,"two legitimate same-name physical slots plus another item"):
		w.queue_free();await process_frame;return
	var sel:String=name+"@@@"+uid[1];var use_rng:int=w.source_shop.inventory_tickets.random.state
	var before_cards:int=card_total(w);var gold:int=w.gold;var general_rng:int=w.card_draw_fusion.rng.state
	var model:Dictionary=w.source_shop.inventory_tickets.document
	ck(model.get("tickets",{}).size()==4661 and model.get("pools",{}).size()==161,"actual accepted original model has 4661 tickets/161 whole pools")
	var quote:Dictionary=w.source_shop.quote_inventory_ticket(name,{},uid[1])
	if not ck(quote.get("ok",false) and quote.get("draw_count")==5,"chosen ticket uses original five-result pool: "+str(quote.get("reason",""))+" missing="+str(quote.get("missing_card_ids",[]).size())):
		w.queue_free();await process_frame;return
	var bytes:String=FileAccess.get_sha256(w.save_path())
	ck(not w.source_shop.use_inventory_ticket(name,{},different).get("ok",false),"cross-lane valid receipt cannot substitute")
	w.ui_preferences.item_locks[sel]=true
	w.hud.inventory_item_activated.emit(sel)
	ck(w.item_instances.has(uid[0]) and w.item_instances.has(uid[1]) and w.source_shop.inventory_tickets.random.state==use_rng and FileAccess.get_sha256(w.save_path())==bytes,"locked selected bag slot preserves both receipts and RNG")
	w.ui_preferences.item_locks.erase(sel)
	w.equipment_collections.test_save_writer=refuse
	w.hud.inventory_item_activated.emit(sel)
	ck(rejected.get("item_instances",{}).has(uid[0]) and not rejected.get("item_instances",{}).has(uid[1]),"actual rejected commit candidate pays the selected second slot, not first")
	ck(w.item_instances.has(uid[0]) and w.item_instances.has(uid[1]) and card_total(w)==before_cards and w.source_shop.inventory_tickets.random.state==use_rng and FileAccess.get_sha256(w.save_path())==bytes,"refused commit preserves both receipts, cards, RNG and file")
	w.equipment_collections.test_save_writer=Callable()
	w._load_game(true);freeze(w)
	w.hud.inventory_item_activated.emit(sel)
	if ck(w.item_instances.has(uid[0]) and not w.item_instances.has(uid[1]) and w.inventory.get(name)==cap and card_total(w)==before_cards+5,"actual bag dispatch pays only selected receipt and receives 5 results: "+w.hud.message_label.text):consumed+=1
	if is_instance_valid(w.hud.card_reveal_stage):w.hud.card_reveal_stage.close_reveal()
	w._load_game(true);freeze(w)
	var state:Dictionary=w.source_shop.state.get("ticket_redemption",{})
	ck(w.item_instances.has(uid[0]) and not w.item_instances.has(uid[1]) and w.item_instances.has(different) and card_total(w)==before_cards+5 and int(state.get("uses",0))==1 and w.gold==gold and w.card_draw_fusion.rng.state==general_rng,"reload keeps exact debit, cards, count; keeps the other SKU, gold and general RNG")
	bytes=FileAccess.get_sha256(w.save_path());use_rng=w.source_shop.inventory_tickets.random.state
	w.hud.inventory_item_activated.emit(sel)
	ck(not w.source_shop.use_inventory_ticket(name,{},uid[1]).get("ok",false) and w.item_instances.has(uid[0]) and card_total(w)==before_cards+5 and FileAccess.get_sha256(w.save_path())==bytes and w.source_shop.inventory_tickets.random.state==use_rng,"stale exhausted slot refuses rather than redeeming the same-name remainder")
	w.ui_preferences.item_locks[name+"@@@"+uid[0]]=true
	ck(not w.source_shop.use_inventory_ticket(name).get("ok",false) and w.item_instances.has(uid[0]) and FileAccess.get_sha256(w.save_path())==bytes,"name-only request cannot fall back from locked native receipt to a legacy debit")
	await mixed_mileage(w)
	w.queue_free();await process_frame

func mixed_mileage(w:Node)->void:
	var service=w.source_shop.inventory_tickets
	var baseline_model:String=service.loaded_sha
	ck(MILEAGE.spec(144743,RAW.row("ItemClass",144743)).is_empty(),"expired mixed product does not enter the extension")
	for id:int in MILEAGE.VARIANTS:
		var expected:Array=MILEAGE.VARIANTS[id]
		var spec:Dictionary=MILEAGE.spec(id,RAW.row("ItemClass",id))
		if not ck(spec.get("original_mileage")==expected[7] and spec.get("grants",[]).size()==1 and service.document.unsupported.has(str(id)),"exact original card draw and mileage pair, separate from prior declared policy "+str(id)):continue
		var item:Dictionary=D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
		w.catalog_db["아이템"].append(item);w._index_catalog_item_sources()
		if not ck(INV.commit(w,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"qa_permanent_mileage_ticket"}),"one original mixed ticket receipt "+str(id)):continue
		var uid:String=""
		for k:String in w.item_instances:
			if STACK.proof(w,k).get("receipt",{}).get("item_class_id")==id:uid=k;break
		if not ck(not uid.is_empty(),"physical mixed ticket identity "+str(id)):continue
		var name:String=str(item.name);var ref:String=name+"@@@"+uid
		var current:int=int(w.inventory.get("마일리지",0));var cards:int=card_total(w);var count:int=int(expected[5]);var amount:int=int(expected[7])
		var gold:int=w.gold;var rng:int=int(service.random.state)
		var ticket_uses:int=int(w.source_shop.state.get("ticket_redemption",{}).get("uses",0))
		var quote:Dictionary=w.source_shop.quote_inventory_ticket(name,{},uid)
		if not ck(quote.get("ok",false) and quote.get("original_mileage")==amount and quote.get("draw_count")==count and not w.source_shop.quote_inventory_ticket(name).get("ok",false),"owned exact card+wallet only when selected "+str(id)+": "+str(quote.get("reason",""))):continue
		if id==200408:
			var bytes:String=FileAccess.get_sha256(w.save_path())
			w.inventory["마일리지"]=w.source_shop.LIMIT
			ck(not w.source_shop.quote_inventory_ticket(name,{},uid).get("ok",false) and STACK.proof(w,uid).get("remaining")==1,"mileage cap prevents debit or draw")
			if current==0:w.inventory.erase("마일리지")
			else:w.inventory["마일리지"]=current
			rejected.clear()
			w.equipment_collections.test_save_writer=refuse
			w.hud.inventory_item_activated.emit(ref)
			ck(rejected.get("inventory",{}).get("마일리지")==current+amount and not rejected.get("item_instances",{}).has(uid),"one rejected save would have contained wallet and exact debit")
			ck(w.item_instances.has(uid) and int(w.inventory.get("마일리지",0))==current and card_total(w)==cards and service.random.state==rng and FileAccess.get_sha256(w.save_path())==bytes,"failed mixed save preserves card, ticket, wallet, RNG and file")
			w.equipment_collections.test_save_writer=Callable()
			w._load_game(true);freeze(w)
		w.hud.inventory_item_activated.emit(ref)
		if ck(not w.item_instances.has(uid) and int(w.inventory.get("마일리지",0))==current+amount and card_total(w)==cards+count and w.hud.message_label.text.contains("마일리지"),"actual bag grants "+str(count)+" cards and "+str(amount)+" mileage for selected "+str(id)+": "+w.hud.message_label.text):mixed_consumed+=1
		if is_instance_valid(w.hud.card_reveal_stage):w.hud.card_reveal_stage.close_reveal()
		await process_frame
		w._load_game(true);freeze(w)
		ck(not w.item_instances.has(uid) and int(w.inventory.get("마일리지",0))==current+amount and card_total(w)==cards+count and w.gold==gold and service.loaded_sha==baseline_model and w.source_shop.state.get("ticket_redemption",{}).get("uses")==ticket_uses+1,"reload preserves grant and prior policy fingerprint "+str(id))
