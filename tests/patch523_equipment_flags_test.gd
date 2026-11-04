extends SceneTree
func _initialize() -> void:
	var world = preload("res://scripts/world.gd").new()
	var failures: Array[String] = []
	world.equipped_items["weapon"] = {"name":"synthetic source weapon","slot":"weapon","type":"한손검","source_m_native_item":true,"source_is_two_handed":true}
	if world._current_weapon_supports_shield(): failures.append("explicit original two-handed flag ignored")
	var guarder: Dictionary = {"name":"synthetic source guarder","slot":"offhand","type":"가더","source_m_native_item":true,"source_can_equip_with_two_handed":false}
	if world._can_equip_offhand(guarder): failures.append("explicit original offhand prohibition ignored")
	guarder.source_can_equip_with_two_handed = true
	if not world._can_equip_offhand(guarder): failures.append("explicit original offhand permission ignored")
	guarder.erase("source_can_equip_with_two_handed")
	guarder.erase("source_m_native_item")
	if not world._can_equip_offhand(guarder): failures.append("legacy guarder compatibility changed")
	world.equipped_items["offhand"] = {"name":"legacy custom offhand","slot":"offhand","type":"custom"}
	world._enforce_shield_weapon_compatibility(true)
	if world.equipped_items.offhand.is_empty(): failures.append("legacy custom offhand removed by new source rule")
	world.equipped_items.weapon.erase("source_m_native_item")
	if not world._current_weapon_supports_shield(): failures.append("legacy one-handed host rule changed")
	world.free()
	print("PATCH523_EQUIPMENT_FLAGS_RESULT ",JSON.stringify({"checks":6,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
