extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Adapter=preload("res://scripts/expedition/reward_cards.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var world:TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world);world.process_mode=Node.PROCESS_MODE_DISABLED;world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main entry")
	var source:RefCounted=world.get_expedition_catalog()
	check(source.ready(),"verified source pack installed")
	if not source.ready():world.queue_free();finish();return
	var granted:int=0;var blocked:int=0
	for item:Dictionary in source.rows("ItemClass"):
		var raw:Dictionary=Adapter.fixed_target(source,int(item.ID))
		if raw.is_empty():continue
		var key:String=str(int(item.ID))+":1:0"
		world.expedition_local.state.storage[key]=1
		check(world.expedition_local.withdraw(key).ok,"actual inventory receipt "+str(item.ID))
		var name:String=world.expedition_local.state.issued[key]
		var record:Dictionary=Adapter.registered(world.catalog_db,raw)
		var identity:String=world.CARD_DRAW_FUSION.card_id(record)
		var category:String=Adapter.CATEGORIES[int(raw.BuffCardDeckID)]
		var before:int=world.card_draw_fusion.total_count(category,identity)
		var card_state:String=JSON.stringify(world.card_draw_fusion.export_state())
		var gold:int=world.gold;var rng:int=world.card_draw_fusion.rng.state
		var disk:String=FileAccess.get_sha256(world.save_path())
		world._on_inventory_item_activated(name)
		if Adapter.item_conditions(source,int(item.ID)).is_empty():
			granted+=1
			check(world.card_draw_fusion.total_count(category,identity)==before+1 and not world.inventory.has(name),"exact fixed-card use "+str(item.ID))
			check(world.card_draw_fusion.source_card_receipts.back().identity==identity,"source receipt target "+str(item.ID))
		else:
			blocked+=1
			check(JSON.stringify(world.card_draw_fusion.export_state())==card_state and int(world.inventory.get(name,0))==1 and FileAccess.get_sha256(world.save_path())==disk,"original restriction preserves item ownership and disk "+str(item.ID))
		check(world.gold==gold and world.card_draw_fusion.rng.state==rng,"fixed grant preserves money and draw RNG "+str(item.ID))
	check(granted==21 and blocked==7,"21 executed and7 source-restricted rewards checked")
	var disk:String=FileAccess.get_sha256(world.save_path());var state:String=JSON.stringify(world.card_draw_fusion.export_state())
	world._load_game(true)
	check(FileAccess.get_sha256(world.save_path())==disk and JSON.stringify(world.card_draw_fusion.export_state())==state,"all fixed-card ownership and source receipts survive reconnect")
	world.queue_free();finish()
func finish()->void:
	print("EXPEDITION523_REWARD_INVENTORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
