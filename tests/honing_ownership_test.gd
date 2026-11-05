extends SceneTree

const Ownership = preload("res://scripts/honing/ownership.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	# Synthetic ownership only; these names/IDs/rates are not original rules.
	var inventory: Dictionary = {"fixture blade":2, "fixture material":3}
	var physical: Dictionary = {
		"11":{"name":"fixture blade", "level":7, "element":"fire", "element_level":3,
			"unknown_option":{"value":8}, "opaque_honing":{"unverified":true}},
		"12":{"name":"fixture blade", "level":9, "record":{"custom":true}},
		"13":{"name":"fixture material", "source_reward_quantity":3,
			"record":{"source_reward_quantity":3}, "quest_reward_receipt":{"quantity":3}}}
	var original: PackedByteArray = var_to_bytes([inventory,physical])
	var first: Dictionary = Ownership.inspect(inventory,physical,"11")
	check(first.ok and first.instance.level == 7, "select exact first physical instance")
	check(Ownership.inspect(inventory,physical,"12").instance.level == 9, "same name is a distinct instance")
	first.instance.unknown_option.value = 100
	check(physical["11"].unknown_option.value == 8, "inspection must not alias stored options")
	check(Ownership.inspect(inventory,physical,"missing").code == "missing_instance", "missing target")
	check(Ownership.inspect(inventory,physical,"13").code == "stack_is_not_target", "material stack is not a physical target")
	var empty: Dictionary = inventory.duplicate(true)
	empty["fixture blade"] = 0
	check(not Ownership.inspect(empty,physical,"11").ok, "no owned quantity")
	empty["fixture blade"] = 1
	check(Ownership.inspect(empty,physical,"11").code == "ownership_mismatch", "duplicate physical ownership cannot exceed bag")
	for bad: Variant in [-1, 1.5, "2", true, INF, NAN]:
		empty["fixture blade"] = bad
		check(not Ownership.inspect(empty,physical,"11").ok, "damaged bag quantity")
	var damaged: Dictionary = physical.duplicate(true)
	damaged["11"].record = "damaged"
	check(not Ownership.inspect(inventory,damaged,"11").ok, "damaged record rejected")
	damaged = physical.duplicate(true)
	damaged["11"].level = -1
	check(not Ownership.inspect(inventory,damaged,"11").ok, "invalid enhancement rejected")
	damaged = physical.duplicate(true)
	damaged["13"].source_reward_quantity = 2
	check(Ownership.inspect(inventory,damaged,"13").code == "invalid_quantity", "receipt quantities disagree")
	for index: int in range(10):
		var quote: Dictionary = Ownership.quote(inventory,physical,"11")
		check(not quote.ok and quote.code == "source_rules_unverified", "repeated request stays locked")
		check(quote.costs == null and quote.probability == null, "unknown is not a free or guaranteed attempt")
	check(var_to_bytes([inventory,physical]) == original, "all queries preserve all original bytes in memory")
	# JSON round trips model representation changes, not actual Main restart/save.
	for index: int in range(5):
		physical = JSON.parse_string(JSON.stringify(physical))
		check(Ownership.inspect(inventory,physical,"11").ok, "integral JSON numbers retain identity")
		check(physical["11"].opaque_honing.unverified and physical["11"].unknown_option.value == 8, "opaque state remains intact")
	print("HONING_OWNERSHIP checks=%d failures=%d (synthetic read-only boundary only)" % [checks, failures])
	quit(1 if failures else 0)
