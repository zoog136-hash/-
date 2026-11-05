extends RefCounted
const DATA=preload("res://data/shop/source523_wisdom.json")

static func install(world,catalog) -> Dictionary:
	var spec: Dictionary=DATA.data
	var item: Dictionary=catalog.record("ItemClass",int(spec.item_id))
	if item.is_empty() or item.get("TestItem",true) or catalog.label(int(item.get("DescID",0)))!=spec.name or int(item.get("GradeID",0))!=1:return {}
	var record: Dictionary=world._find_catalog_item_record(str(spec.name))
	if not record.is_empty() and (record.get("source")!="twilight-shop523-wisdom" or record.get("source_bless_raw")!=1):return {}
	if record.is_empty():
		record={"name":str(spec.name),"grade":"일반","slot":"consumable","type":"버프물약","source":"twilight-shop523-wisdom","source_item_class_id":int(spec.item_id),"source523_shop_item_id":int(spec.item_id),"source_bless_raw":1,"source523_shop_use_origin":str(spec.origin),"source_max_stack":int(item.get("MaxStackAmount",0)),"source_weight_raw":item.get("Weight",0),"droppable":item.get("IsDroppable",false),"storable":item.get("IsStorable",false),"weight":3,"desc":str(spec.origin)}
		world.item_db.append(record.duplicate(true));world.catalog_db["아이템"].append(record);world._index_item_weights()
	return {"4:376":{"name":str(spec.name),"record":record.duplicate(true)}}

static func try_use(world,name: String) -> bool:
	var record: Dictionary=world._find_catalog_item_record(name)
	if record.get("source")!="twilight-shop523-wisdom":return false
	var spec: Dictionary=DATA.data
	if record.get("name")!=spec.name or int(record.get("source_item_class_id",0))!=int(spec.item_id) or record.get("source_bless_raw")!=1:
		world.hud.show_message("지혜 물약 원본 정체 불일치 · 보존");return true
	var count:int=int(world.inventory.get(name,0))
	if count<=0 or int(world.hp)<=0 or float(world.item_use_cooldowns.get(name,0.0))>0.0:
		world.hud.show_message("보유량·생존·물약 재사용 대기를 확인하세요");return true
	var old_buffs:Dictionary=world.active_item_buffs.duplicate(true)
	var old_cooldowns:Dictionary=world.item_use_cooldowns.duplicate(true)
	var group:String="source523:buffgroup:"+str(int(spec.group))
	for key:String in world.active_item_buffs.keys():
		var current:Variant=world.active_item_buffs[key]
		if current is Dictionary and current.get("group")==group:world.active_item_buffs.erase(key)
	world.inventory[name]=count-1
	world.item_use_cooldowns[name]=float(spec.host_cooldown_seconds)
	world.active_item_buffs[name]={"group":group,"source_buff_id":int(spec.buff_id),"source523_erase_on_dead":true,"duration":float(spec.duration),"remaining":float(spec.duration),"sp":int(spec.sp),"mp_regen_tick":int(spec.mp_regen),"tick_interval":float(spec.host_regen_interval),"tick_elapsed":0.0}
	if world._save_game(true)!=OK:
		world.inventory[name]=count;world.active_item_buffs=old_buffs;world.item_use_cooldowns=old_cooldowns
		world._update_hud();world.hud.show_message("지혜 물약 저장 실패 · 물약·버프 보존");return true
	world._update_hud();world.hud.show_message(str(spec.name)+" 사용 · "+str(spec.origin))
	return true

static func clear_on_death(world) -> void:
	for key:String in world.active_item_buffs.keys():
		var buff:Variant=world.active_item_buffs[key]
		if buff is Dictionary and buff.get("source523_erase_on_dead",false):world.active_item_buffs.erase(key)
