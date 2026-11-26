extends RefCounted
## Permanent deletion is not a floor drop or 용해. Revalidate the exact
## selection and its quantity/receipt against the original ItemClass flag,
## then publish only after the existing durable save accepts the debit.
const STACK=preload("res://scripts/loot/current523_native_stack.gd")
const SourceItems=preload("res://scripts/loot/patch523_monster_drops.gd")
const Identity=preload("res://scripts/ui/source523_item_identity.gd")
const RETIRED=preload("res://scripts/loot/retired_enhancement_items523.gd")

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

static func quote(world: Node, reference: String) -> Dictionary:
	if reference.is_empty():return _fail("삭제할 아이템을 먼저 선택하세요.")
	var parsed: Dictionary=world._parse_enhancement_target(reference)
	var name: String=str(parsed.name)
	var uid: String=str(parsed.id)
	if name.is_empty() or reference!=name+("@@@"+uid if not uid.is_empty() else ""):return _fail("선택한 아이템을 확인할 수 없습니다.")
	var held: Variant=world.inventory.get(name)
	if not STACK.integer(held) or int(held)<1:return _fail("선택한 아이템을 더 이상 보유하지 않습니다.")
	if world._item_locked(name) or (not uid.is_empty() and world._item_locked(name,uid)):return _fail("잠긴 아이템은 삭제할 수 없습니다.")
	if world.hp<=0 or world.death_recovery.blocked() or world._option_awakening_busy():return _fail("현재 상태에서는 아이템을 삭제할 수 없습니다.")
	if str(world.get("equipped_ammo"))==name and not bool(world.get("ammo_unequipped")):
		var worn: Variant=world.consumable_service.export_state().get(STACK.AMMO_EQUIPPED,{})
		if uid.is_empty() or not worn is Dictionary or worn.get("physical_id","") in ["",uid]:return _fail("장착을 해제한 뒤 삭제하세요.")
	var record: Dictionary={}
	var entry: Dictionary={}
	var kind: String="plain"
	var maximum: int=int(held)
	if not uid.is_empty():
		var physical: Variant=world.item_instances.get(uid)
		if not physical is Dictionary or physical.get("name")!=name or not physical.get("record") is Dictionary:return _fail("선택한 아이템 개체를 확인할 수 없습니다.")
		if world._is_instance_equipped(uid):return _fail("장착을 해제한 뒤 삭제하세요.")
		entry=physical
		record=entry.record
		if entry.has(STACK.RECEIPT):
			var owned: Dictionary=STACK.proof(world,uid)
			if owned.is_empty() or entry.has(STACK.TOKEN_RANK) or int(owned.remaining)>maximum:return _fail("이 물리 묶음의 삭제 조건을 확인할 수 없습니다.")
			maximum=int(owned.remaining)
			kind="native_stack"
		elif SourceItems.equipment(record) and not entry.has("source_awakening_quantity") and not entry.has("source_card_currency_quantity"):
			maximum=1
			kind="equipment"
		else:return _fail("이 물리 아이템의 삭제 방식은 확인되지 않았습니다.")
	else:
		for existing: Variant in world.item_instances.values():
			if existing is Dictionary and existing.get("name")==name:return _fail("합쳐진 이름으로는 삭제할 수 없습니다. 아이템 개체를 선택하세요.")
		record=world._find_catalog_item_record(name)
		if str(world.get("equipped_ammo"))==name or SourceItems.equipment(record):return _fail("장착을 해제하고 실제 개체를 선택하세요.")
	if record.get("source_m_native_item")!=true or record.get("name")!=name or RETIRED.record(record) or record.get("quest_item",false) or str(record.get("slot",""))=="currency":
		return _fail("이 아이템의 원본 삭제 조건을 확인할 수 없습니다.")
	var source: Dictionary=SourceItems.item_definition(record).get("original_item",{})
	if source.get("TestItem")!=false or source.get("IsDeletable")!=true:return _fail("원본에서 삭제할 수 없는 아이템입니다.")
	return {"ok":true,"reference":reference,"name":name,"display_name":Identity.display_name(record,name),"uid":uid,"kind":kind,"maximum":maximum,"item_class_id":int(source.ID),"entry":entry.duplicate(true)}

static func request(world: Node, reference: String) -> Dictionary:
	var offered: Dictionary=quote(world,reference)
	if not offered.get("ok",false):
		world.hud.show_message(offered.message)
		return offered
	var opened: Dictionary=world.hud.confirm_inventory_delete(str(offered.display_name),int(offered.item_class_id),int(offered.maximum),
		func(quantity: int) -> bool:
			if world.hud.lineage_inventory_ui.selected_item!=reference:
				world.hud.show_message("선택한 아이템이 바뀌어 삭제하지 않았습니다.")
				return false
			var result: Dictionary=commit(world,offered,quantity)
			world.hud.show_message(result.message)
			return result.ok)
	return {"ok":opened.get("handled",false),"pending":opened.get("handled",false),"popup":opened}

static func commit(world: Node, expected: Dictionary, quantity: int) -> Dictionary:
	var current: Dictionary=quote(world,str(expected.get("reference","")))
	if not current.get("ok",false):return current
	if current!=expected or quantity<1 or quantity>int(current.maximum):return _fail("아이템 개체나 수량이 바뀌어 삭제하지 않았습니다.")
	var staged: Dictionary={}
	if current.kind=="native_stack":
		var owned: Dictionary=STACK.proof(world,current.uid)
		if owned.is_empty():return _fail("원본 물리 묶음을 확인할 수 없습니다.")
		var paid: Dictionary=STACK.stage_debit(world,[{"physical_id":current.uid,"quantity":quantity,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-quantity,"source_native_stack_receipt":owned.receipt}])
		if not paid.get("ok",false):return _fail("원본 물리 수량을 확인할 수 없습니다. 아이템은 보존했습니다.")
		staged=paid.overrides
	else:
		var bag: Dictionary=world.inventory.duplicate()
		var instances: Dictionary=world.item_instances.duplicate()
		bag[current.name]=int(bag[current.name])-quantity
		if int(bag[current.name])==0:bag.erase(current.name)
		if current.kind=="equipment":instances.erase(current.uid)
		staged={"inventory":bag,"item_instances":instances}
	var saved: Error=STACK.sealed_save(world,staged)
	if saved!=OK:return _fail("저장하지 못해 아이템을 삭제하지 않았습니다.")
	world.inventory=staged.inventory
	world.item_instances=staged.item_instances
	if staged.has("consumable_state"):world.consumable_service.import_state(staged.consumable_state)
	world.deferred_save.cancel()
	# Do not fold compatible neighbours after committing one selected UID.
	world._publish_player_hud(false)
	world.hud.refresh_inventory(world.inventory)
	return {"ok":true,"message":"%s %d개를 삭제했습니다." % [str(current.display_name),quantity]}
