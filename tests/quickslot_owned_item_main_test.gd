extends "res://tests/quickslot_register523_main_test.gd"
## Run only in a clean, isolated profile with the pinned 523 definitions/UI.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY=preload("res://scripts/loot/patch523_item_inventory.gd")
const IRON:=3032
const BOX:=135012
const SMITH:=223762
const WEAPON:=27
const SUMMIT:=160413

func run() -> void:
	root.size=Vector2i(2048,919)
	if not check(not FileAccess.file_exists("user://twilight_v20_save.json"),"disposable profile"): _done();return
	if not check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"original definitions admitted"): _done();return
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer=-100000
	if check(QA.enter_game(world,"기사"),"normal Main entry"):
		await frames()
		await _exercise(world)
	world.queue_free()
	await frames()
	_done()

func _done() -> void:
	print("QUICKSLOT_OWNED_ITEM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(1 if not failures.is_empty() else 0)

func _reference(world: TwilightWorld, id: int) -> String:
	for uid: String in world.item_instances:
		var row: Dictionary=world.item_instances[uid]
		if int(row.get("record",{}).get("source_item_class_id",0))==id:return str(row.name)+"@@@"+uid
	return ""

func _add(world: TwilightWorld, id: int, amount: int) -> bool:
	return SUPPLY.commit(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"quickslot_owned_item_test"})

func _exercise(world: TwilightWorld) -> void:
	if not check(_add(world,IRON,2) and _add(world,BOX,1) and _add(world,SMITH,1) and _add(world,WEAPON,1) and _add(world,SUMMIT,1),"issued five original items with receipts"):return
	var hud: Node=world.hud
	world.self_mode_enabled=false
	var iron: String=_reference(world,IRON)
	var box: String=_reference(world,BOX)
	var smith: String=_reference(world,SMITH)
	var weapon: String=_reference(world,WEAPON)
	var summit: String=_reference(world,SUMMIT)
	if not check(not iron.is_empty() and not box.is_empty() and not smith.is_empty() and not weapon.is_empty() and not summit.is_empty(),"each exact owned reference exists"):return
	var uid: String=iron.get_slice("@@@",1)
	var name: String=iron.get_slice("@@@",0)
	var weapon_id: String=weapon.get_slice("@@@",1)
	world.item_instances[weapon_id]["element"]="fire"
	world.item_instances[weapon_id]["element_level"]=3
	var slots: Dictionary={}
	for item: Array in [[IRON,iron,6],[BOX,box,7],[SMITH,smith,8],[WEAPON,weapon,9]]:
		var index: int=hud.quickslot_index(item[2])
		slots[item[0]]=index
		check(world._quickslot_registration_error("item",item[1]).is_empty(),"exact registration admitted #"+str(item[0]))
		if item[0]!=IRON:world._on_quickslot_assignment_requested(index,"item",item[1])
	check(world._quickslot_registration_error("item",name+"@@@absent").contains("가방"),"a different physical ID is refused")
	world._update_hud()
	hud.toggle_inventory()
	await frames(10)
	if not check(hud.original_inventory_is_open(),"source bag mounted"):return
	var from: Vector2=await bag_point(world,hud,name)
	var slot: Control=slot_control(hud,6)
	var to: Vector2=center(slot)
	if not check(from.is_finite() and to.is_finite(),"owned item and target slot are visible"):return
	await gesture(from,to,L.TOUCH_HOLD_SECONDS+0.2)
	var entry: Dictionary=world.quickslots[slots[IRON]]
	if not check(entry.get("instance_id")==uid and entry.get("id")==name and world.inventory.get(name,0)==2,"real touch drag retains the selected stack and does not spend it"):return
	if hud.original_inventory_is_open():hud.toggle_inventory()
	await frames()
	var point: Vector2=center(slot_control(hud,6))
	check(hud.original_quickslot_control(6)!=hud.v20_quickslot_buttons[6],"authored quickslot remains mounted")
	await tap(point)
	var active: Dictionary=world.active_item_buffs.get(name,{})
	check(world.inventory.get(name,0)==1 and active.get("duration")==960 and active.get("def")==10 and world._active_item_buff_total("def")>=10,"quickslot tap spends one and applies the original 16-minute AC effect")
	point=center(slot_control(hud,6))
	await gesture(point,point+Vector2(1,L.AUTO_PULL_DISTANCE+2),0.0,4)
	check(world.quickslots[slots[IRON]].get("auto")==true,"short down swipe enables AUTO")
	world.auto_item_clock=0.0
	world._run_auto_item_quickslots(0.25)
	check(world.inventory.get(name,0)==1,"AUTO waits while the buff is active")
	world._tick_item_buffs(960.0)
	world.item_use_cooldowns.clear()
	world.auto_item_clock=0.0
	world._run_auto_item_quickslots(0.25)
	check(world.inventory.get(name,0)==0 and world.active_item_buffs.has(name),"AUTO refreshes once after the effect expires")
	check(_add(world,IRON,1),"new stock is issued")
	var next: String=world._quickslot_item_reference(world.quickslots[slots[IRON]])
	check(next==_reference(world,IRON) and next!=iron,"depleted binding resolves a new stack of the exact original variant")
	check(world._save_game(true)==OK,"physical bindings save")
	world._load_game(true)
	await frames()
	check(world._quickslot_item_reference(world.quickslots[slots[IRON]])==next and world.quickslots[slots[IRON]].get("auto")==true,"exact resupply and AUTO survive load")
	point=center(slot_control(hud,6))
	await gesture(point,point-Vector2(1,L.AUTO_PULL_DISTANCE+2),0.0,4)
	check(world.quickslots[slots[IRON]].get("auto")==false,"short up swipe disables AUTO")
	world._set_item_locked(next,true)
	await tap(center(slot_control(hud,6)))
	check(world.inventory.get(name,0)==1 and hud.message_label.text.contains("잠긴"),"locked selected stock cannot be used by tapping")
	world._set_item_locked(next,false)
	var box_name: String=box.get_slice("@@@",0)
	point=center(slot_control(hud,7))
	await gesture(point,point+Vector2(1,L.AUTO_PULL_DISTANCE+2),0.0,4)
	check(world.inventory.get(box_name,0)==1 and not world.quickslots[slots[BOX]].get("auto",false),"down swipe does not spend or automate a one-use box")
	await tap(center(slot_control(hud,7)))
	check(world.inventory.get(box_name,0)==0 and _reference(world,117304)!="","a single tap uses the exact original box and issues its item")
	await tap(center(slot_control(hud,8)))
	var enchant: Variant=hud._original_enchant_window()
	check(enchant!=null and enchant.last_result.get("material_uid")==smith.get_slice("@@@",1) and world.inventory.get(smith.get_slice("@@@",0),0)==1,"elemental smith shortcut opens the original target chooser without a debit")
	hud._close_workspace()
	await tap(center(slot_control(hud,9)))
	check(world.equipped_items.get("weapon",{}).get("instance_id")==weapon_id,"weapon quickslot equips the selected physical weapon")
	await tap(center(slot_control(hud,9)))
	check(world.equipped_items.get("weapon",{}).get("instance_id")!=weapon_id,"another tap unequips that exact weapon")
	var summit_slot: int=hud.quickslot_index(8)
	world._on_quickslot_assignment_requested(summit_slot,"item",summit)
	check(world.quickslots[summit_slot].get("instance_id")==summit.get_slice("@@@",1),"summit scroll is registrable with its exact receipt")
	var initial: Vector2=world.player.global_position
	var map: String=world.active_map_id
	world.level=67
	await tap(center(slot_control(hud,8)))
	check(world.inventory.get(summit.get_slice("@@@",0),0)==1 and world.active_map_id==map and world.player.global_position==initial and hud.message_label.text.contains("레벨"),"under-level summit use preserves the scroll and current position")
	var legacy: String="낡은 장검"
	var legacy_id: String="quickslot-legacy-weapon"
	world.inventory[legacy]=int(world.inventory.get(legacy,0))+1
	world.item_instances[legacy_id]={"name":legacy,"level":0,"element":"","element_level":0}
	world._on_quickslot_assignment_requested(hud.quickslot_index(9),"item",legacy+"@@@"+legacy_id)
	check(world.quickslots[hud.quickslot_index(9)].get("instance_id")==legacy_id,"legacy gear without an embedded item record has an exact binding")
	await tap(center(slot_control(hud,9)))
	check(world.equipped_items.get("weapon",{}).get("instance_id")==legacy_id,"legacy gear uses its existing equip path")
	evidence["original_quickslot"]=hud.original_quickslot_control(6)!=hud.v20_quickslot_buttons[6]
