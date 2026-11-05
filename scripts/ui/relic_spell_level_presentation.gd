extends RefCounted
## Unregistered API boundary for the owner of the supplied original UI.
## No Control, polling, scene registration or automatic install/equip/save.
## A source layout and its verified node/action bindings must precede mounting.
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")

static func snapshot(world: Node, selected_relic: Dictionary) -> Dictionary:
	return RULES.for_world(world, selected_relic)

static func state_key(world: Node) -> int:
	return RULES.state_key(world)

static func install_source(path: String) -> Dictionary:
	# Explicit caller action only. The existing atomic installer validates the
	# exact source archive and never grants ownership or writes progression.
	return RULES.install_source(path)
