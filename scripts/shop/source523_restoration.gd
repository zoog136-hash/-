extends RefCounted
## Reuse the real potion consumer; failed durable writes restore quantity/HP/RNG.
const DATA = preload("res://data/shop/source523_restoration.json")

static func install(world, catalog) -> Dictionary:
	var result: Dictionary={}
	var changed: bool=false
	for id: String in DATA.data.items:
		var spec: Dictionary=DATA.data.items[id]
		var original: Dictionary=catalog.record("ItemClass",int(id))
		if original.is_empty() or original.get("TestItem",true) or catalog.label(int(original.get("DescID",0)))!=spec.name:continue
		var name: String=str(spec.name)
		var record: Dictionary=world._find_catalog_item_record(name)
		var fresh: bool=record.is_empty()
		if not record.is_empty() and (record.get("source")!="twilight-shop523-restoration" or int(record.get("source_item_class_id",0))!=int(id) or record.get("source_bless_raw")!=1):continue
		if record.is_empty():
			record={"name":name,"grade":"일반","type":"회복물약","slot":"consumable","heal":int(spec.base),"source":"twilight-shop523-restoration","source_item_class_id":int(id),"source523_shop_item_id":int(id),"source_bless_raw":1,"source523_shop_use_origin":str(DATA.data.origin),"weight":3,"desc":"기본 회복 %d + %dd%d · %s" % [int(spec.base),int(spec.dice_count),int(spec.dice_sides),str(DATA.data.origin)]}
		record.merge({"source_weight_raw":original.get("Weight",0),"source_max_stack":int(original.get("MaxStackAmount",0)),"droppable":original.get("IsDroppable",false),"storable":original.get("IsStorable",false),"source_is_tradable":original.get("IsTradable",false)},true)
		if fresh:
			world.item_db.append(record.duplicate(true));world.catalog_db["아이템"].append(record);changed=true
		result["4:"+id]={"name":name,"record":record.duplicate(true)}
	if changed:world._index_item_weights()
	return result

static func try_use(world, name: String) -> bool:
	var record: Dictionary=world._find_catalog_item_record(name)
	if record.get("source")!="twilight-shop523-restoration":return false
	var spec: Dictionary=DATA.data.items.get(str(int(record.get("source_item_class_id",0))),{})
	if spec.is_empty() or spec.name!=name or record.get("source_bless_raw")!=1 or DATA.data.dice_policy!="base_plus_uniform_dice":
		world.hud.show_message("회복제 원본 정체/적용 정책 확인 실패 · 보존");return true
	var before: int=int(world.inventory.get(name,0))
	if before<=0 or int(world.hp)<=0 or int(world.hp)>=int(world._effective_max_hp()) or float(world.item_use_cooldowns.get(world.HP_POTION_COOLDOWN_KEY,0.0))>0.0:
		world.hud.show_message("회복제 보유량·HP·공유 재사용 대기를 확인하세요");return true
	var old_hp: int=int(world.hp)
	var old_rng: int=world.rng.state
	var old_cooldowns: Dictionary=world.item_use_cooldowns.duplicate(true)
	var amount: int=int(spec.base)
	for die: int in range(int(spec.dice_count)):amount+=world.rng.randi_range(1,int(spec.dice_sides))
	world._use_healing_item(name,amount)
	if int(world.inventory.get(name,0))==before:return true
	if world._save_game(true)!=OK:
		world.hp=old_hp;world.inventory[name]=before;world.item_use_cooldowns=old_cooldowns;world.rng.state=old_rng
		world._update_hud();world.hud.show_message("회복 저장 실패 · HP·물약·난수 보존")
	return true
