extends Node
## patch523_item_inventory.stage() reads inventory, item_instances and gold
## and the catalog lookup from its world. This short-lived view hands it
## staged values (a transaction that is not committed yet); free it after use.
var _world: Object
var inventory: Dictionary
var item_instances: Dictionary
var gold: int

static func make(world: Object, staged_inventory: Dictionary, staged_instances: Dictionary, staged_gold: int) -> Node:
	var view = load("res://scripts/loot/patch523_stage_view.gd").new()
	view._world = world; view.inventory = staged_inventory; view.item_instances = staged_instances; view.gold = staged_gold
	return view

func _catalog_item_from_source_id(id: String) -> Dictionary:
	return _world.call("_catalog_item_from_source_id",id)

## {ok, overrides{inventory,item_instances,gold}} or {ok:false,error}.
static func stage_one(world: Object, staged_inventory: Dictionary, staged_instances: Dictionary, staged_gold: int, item_class_id: int, amount: int, bless: int, origin: Dictionary) -> Dictionary:
	var view: Node = make(world,staged_inventory,staged_instances,staged_gold)
	var result: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(view,[{"item_class_id":item_class_id,"amount":amount,"bless_raw":bless,"enchant":0}],origin)
	view.free()
	return result
