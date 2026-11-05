extends SceneTree

const Consumer = preload("res://scripts/consumable_service.gd")
var failures: Array[String] = []
var checks: int = 0

class Messages extends Node:
	func show_message(_text: String) -> void: pass

class World extends Node:
	var inventory: Dictionary = {"속성 초기화 주문서":2,"속성 변경 주문서":2,"검":2}
	var item_instances: Dictionary = {}
	var hud = Messages.new()
	var writer_error: Error = OK
	var saved: Dictionary = {}
	func _parse_enhancement_target(reference: String) -> Dictionary:
		var parts := reference.split("@@@")
		return {"name":parts[0],"id":parts[1]}
	func _item_locked(_name: String,_id: String) -> bool: return false
	func _save_game(_quiet: bool, candidate: Dictionary) -> Error:
		if writer_error == OK: saved = candidate.duplicate(true)
		return writer_error
	func _update_hud() -> void: pass

func _initialize() -> void:
	var world := World.new()
	var consumer = Consumer.new()
	consumer.setup(world)
	var old: Dictionary = {"source_id":1,"bonus_ids":[1],"preserve":"old evidence"}
	for id: String in ["one","two"]:
		world.item_instances[id] = {"name":"검","element":"fire","element_level":3,"equipment523":{"elemental_smith":old.duplicate(true),"unrelated":17}}
	var before: Dictionary = world.item_instances.duplicate(true)
	world.writer_error = ERR_CANT_CREATE
	consumer.apply_element_management("속성 초기화 주문서","검@@@one")
	check(world.item_instances == before and world.inventory["속성 초기화 주문서"] == 2,"failed save preserves active smith, element and scroll")
	world.writer_error = OK
	consumer.apply_element_management("속성 초기화 주문서","검@@@one")
	check(not world.item_instances.one.equipment523.has("elemental_smith"),"reset retires smith permanently")
	check(world.item_instances.one.element_level == 0 and world.inventory["속성 초기화 주문서"] == 1,"reset and one scroll persist together")
	check(world.item_instances.one.equipment523_retired_elemental_smith == old,"source evidence retained outside active namespace")
	check(world.item_instances.one.equipment523.unrelated == 17 and world.item_instances.two == before.two,"unrelated option and identical other item survive")
	world.item_instances.one.element = "fire"
	world.item_instances.one.element_level = 3
	check(not world.item_instances.one.equipment523.has("elemental_smith"),"same-element reenchantment cannot revive retired smith")
	consumer.apply_element_management("속성 변경 주문서","검@@@two","water")
	check(world.item_instances.two.element == "water" and not world.item_instances.two.equipment523.has("elemental_smith"),"element change also retires only chosen smith")
	check(world.saved.item_instances.two.element == "water","durable candidate contains the changed element")
	consumer.free()
	world.hud.free()
	world.free()
	print("EQUIPMENT523_ELEMENT_LOSS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_ELEMENT_LOSS_FAIL: ",label)
