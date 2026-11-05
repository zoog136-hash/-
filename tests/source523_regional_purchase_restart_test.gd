extends "res://tests/source523_npc_local_main_test.gd"
func run() -> void:
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	var normal: String="귀환 주문서 (각인)";var target: String="잊혀진 귀환 주문서 (각인)"
	check(world.active_map_id=="source_70" and not world.source_save_blocked,"fresh combined process loads real saved PC counterpart map")
	check(world.get_regional_return_enabled() and str(world.quickslots[0].id)==normal and str(world.hud.quickslot_entries[0].id)==target,"fresh process keeps original slot and restores regional HUD projection")
	check(int(world.inventory.get(normal,0))==1 and int(world.inventory.get(target,0))==2 and int(world.gold)==49000,"fresh startup preserves exact actual NPC supply and charges")
	check(world.regional_return_stack(target).item_class_id==126424 and world.regional_return_stack(target).bless_raw==1,"startup catalogue decoration satisfies the real consumer")
	check(world.source_shop.orders().is_empty() and not world.source_shop.claim("2").ok,"fresh process cannot replay original supplier receipt")
	world._on_quickslot_pressed(0)
	check(int(world.inventory.get(target,0))==1 and int(world.inventory.get(normal,0))==1 and world.player.global_position==world._spawn_position(),"fresh consumer spends the purchased target once and reaches existing host entry")
	world._load_game(true);freeze(world)
	check(int(world.inventory.get(target,0))==1 and str(world.quickslots[0].id)==normal,"fresh-process use is durable without rewriting source slot key")
	world.queue_free();await frames()
	print("SOURCE523_REGIONAL_PURCHASE_RESTART_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
