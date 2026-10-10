extends SceneTree

const MOTION = preload("res://scripts/animation/actor_motion.gd")
const FX = preload("res://scripts/animation/player_action_fx.gd")
const MAP = preload("res://scripts/maps/field_renderer.gd")
const INVENTORY = preload("res://scripts/ui/renewal_inventory.gd")
const CATALOG = preload("res://scripts/ui/renewal_hud.gd")
const SHOP = preload("res://scripts/ui/renewal_shop.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var motion: TwilightActorMotion = MOTION.new()
	motion.advance(1.0 / 60.0, Vector2(210.0, 0.0))
	assert(motion.state == "run", "Normal-speed running must be visually distinct")
	motion.advance(1.0 / 60.0, Vector2(55.0, 0.0))
	assert(motion.state == "walk", "Slow movement must retain the walking state")
	motion.begin_attack(.4, Vector2.RIGHT, "slash")
	motion.advance(.2, Vector2.ZERO)
	assert(motion.visual_progress > 0.0, "Attack visual clock must advance")
	var fx: Node = FX.new()
	var map_renderer: Node = MAP.new()
	var inventory_ui: Node = INVENTORY.new()
	var catalog_ui: Node = CATALOG.new()
	var shop = SHOP.new()
	assert(fx.has_method("_draw"))
	assert(map_renderer.has_method("_scatter_ambient_details"))
	assert(inventory_ui.has_method("_activate_dragged_equipment"))
	assert(catalog_ui.has_method("_end_catalog_drag"))
	shop.filtered = [["테스트 상품", 100, "물약"]]
	shop._select(0)
	assert(str(shop.selected[0]) == "테스트 상품")
	for node: Node in [fx, map_renderer, inventory_ui, catalog_ui, shop]:
		node.free()
	print("VISIBLE_GAMEPLAY_SMOKE_OK")
	quit(0)
