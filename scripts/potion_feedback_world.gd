extends "res://scripts/world.gd"

## Thin presentation adapter. Inherit every gameplay calculation from world.gd.
## Main.tscn uses this subclass; no copied healing/buff/inventory/save logic.
const POTION_LIGHT = preload("res://scripts/animation/potion_feedback.gd")
var potion_feedback: TwilightPotionFeedback = null

func _show_potion_feedback(item_name: String, kind: String) -> void:
	var channel: String = POTION_LIGHT.channel_for(item_name, kind)
	if channel.is_empty() or not is_instance_valid(player): return
	if not is_instance_valid(potion_feedback):
		potion_feedback = POTION_LIGHT.new()
		potion_feedback.name = "PotionFeedback"
		player.add_child(potion_feedback)
		potion_feedback.setup(self, player)
	potion_feedback.play(channel)

func _use_healing_item(item_name: String, heal_amount: int) -> void:
	var before: int = int(inventory.get(item_name, 0))
	var hp_before: int = hp
	super._use_healing_item(item_name, heal_amount)
	if hp > hp_before and int(inventory.get(item_name, 0)) == before - 1:
		_show_potion_feedback(item_name, "hp")

func _use_timed_item_buff(record: Dictionary) -> bool:
	var applied: bool = super._use_timed_item_buff(record)
	if applied: _show_potion_feedback(str(record.get("name", "")), "timed")
	return applied

func _instant_mana_feedback(item_name: String, before: int, mp_before: int) -> void:
	if str(CONSUMABLE_RULES.definition(item_name).get("kind", "")) != "instant_mp": return
	if mp > mp_before and int(inventory.get(item_name, 0)) == before - 1:
		_show_potion_feedback(item_name, "instant_mp")

func _use_quick_item(item_name: String) -> void:
	var before: int = int(inventory.get(item_name, 0))
	var mp_before: int = mp
	super._use_quick_item(item_name)
	_instant_mana_feedback(item_name, before, mp_before)

func _on_inventory_item_activated(item_name: String) -> void:
	var name_value: String = str(_parse_enhancement_target(item_name).get("name", item_name))
	var before: int = int(inventory.get(name_value, 0))
	var mp_before: int = mp
	super._on_inventory_item_activated(item_name)
	_instant_mana_feedback(name_value, before, mp_before)
