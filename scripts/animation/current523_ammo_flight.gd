extends RefCounted
## Original 523 projectile of a normal ranged attack (bow arrow, gauntlet
## sting, gun explosion), drawn on the existing TwilightCombatFlights flight:
## the flight keeps speed, obstruction, cancellation and the single hit
## callback; this only follows its position with the original sprite
## (current523_source_effect_selection.select_ammo) and plays the original
## explosion one-shot where the flight hits. Without the original sprite the
## flight keeps its existing drawn line (nothing is substituted).
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const SELECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const TEXTURE_BUDGET: int = 8*1024*1024
static var last_status: Dictionary = {}

static func _original(record: Dictionary) -> Dictionary:
	if record.is_empty() or not record.get("source_m_native_item",false): return {}
	var row: Variant = FIELDS.full(record).get("source_original_item",{})
	return row if row is Dictionary else {}

## Complete ItemClass rows: worn weapon, then ammunition in the existing order
## (worn quiver equipment, then the stack the shot consumes).
static func rows(world: Node) -> Dictionary:
	var weapon: Dictionary = _original(world._equipped_weapon_record())
	var ammo: Array = []
	var quiver: Variant = world.equipped_items.get("offhand",{})
	if quiver is Dictionary and "Quiver" in FIELDS.full(quiver).get("source_equip_slots",[]):
		var row: Dictionary = _original(quiver)
		if not row.is_empty(): ammo.append(row)
	var stack: Dictionary = load("res://scripts/loot/current523_native_stack.gd").call("ammo_record",world,world._current_ammo_name())
	var stack_row: Dictionary = _original(stack)
	if not stack_row.is_empty() and not ammo.has(stack_row): ammo.append(stack_row)
	return {"weapon":weapon,"ammo":ammo}

static func _facing(direction: Vector2) -> int:
	return posmod(int(round(direction.angle()/(PI/4.0))),8)

## SPR action 0 is the projectile's own action ("fly" of arrows/stings, the
## gun explosion's only action); the bank plays it like the ground drop effect
## (current523_ground_drop_effect). Flight repeats while the existing flight
## lives (caller loop policy), the explosion is one-shot and frees itself.
const ACTION: int = 0
static func _make(world: Node, inputs: Dictionary, stage: String, facing: int) -> Node2D:
	var picked: Dictionary = SELECT.ammo_sprite(inputs.weapon,inputs.ammo,stage)
	last_status[stage] = picked.duplicate(true)
	if not picked.get("ok",false): return null
	var view = PREVIEW.new()
	var options: Dictionary = picked.options
	view.playback_mode_override = POLICY.mode(str(options.manifest_path).get_base_dir())
	if not view._configure_reference_bank(str(options.manifest_path),str(options.manifest_sha256),int(picked.sprite_id),{"idle":ACTION},{"idle":stage=="flight"},"idle","overlay"):
		last_status[stage] = {"ok":false,"reason":"current523_ammo_effect_bank_unavailable","error":str(view.reference_bank_status.get("error","")),"sprite_id":int(picked.sprite_id)}
		view.free()
		return null
	view._is_overlay = true
	view._overlay_facing = posmod(facing+3,8)
	view.source_facing = view._overlay_facing
	view.z_index = 2
	last_status[stage]["status"] = "configured_original_ammo_effect"
	last_status[stage].erase("options")
	return view

## Flight options for TwilightCombatFlights.launch ({} for a non-native weapon).
## Without an original flight sprite the existing line is kept and only the
## original explosion (if any) plays at the hit.
static func options(world: Node, origin: Vector2, target: Node2D) -> Dictionary:
	last_status = {}
	if world.combat_flights == null or not is_instance_valid(target): return {}
	var inputs: Dictionary = rows(world)
	if inputs.weapon.is_empty(): last_status["flight"] = {"ok":false,"reason":"current523_ammo_effect_native_weapon_required"}; return {}
	var aim: Vector2 = target.combat_hit_position() if target.has_method("combat_hit_position") else target.global_position
	var flight_node: Node2D = _make(world,inputs,"flight",_facing(aim-origin))
	if flight_node != null:
		flight_node.set_as_top_level(true)
		flight_node.global_position = origin
		flight_node.visible = false
		world.combat_flights.add_child(flight_node)
	var token: Dictionary = {"node":flight_node,"inputs":inputs,"world":weakref(world),"target":weakref(target),"point":origin}
	return {"visual_step":_step.bind(token),"visual_end":_end.bind(token),"current523_ammo_flight":last_status.duplicate(true)}

static func _step(flight: Dictionary, token: Dictionary) -> bool:
	token["point"] = flight.position
	var node: Variant = token.get("node")
	# No original flight sprite: the existing drawn line stays (false).
	if not is_instance_valid(node): return false
	var direction: Vector2 = (flight.position as Vector2)-(flight.previous as Vector2)
	if direction.length_squared() > 0.0001: node.set("_overlay_facing",posmod(_facing(direction)+3,8))
	node.global_position = flight.position
	node.visible = true
	return true

static func _end(token: Dictionary) -> void:
	var node: Variant = token.get("node")
	if is_instance_valid(node): node.queue_free()
	token.erase("node")
	var world: Node = token.world.get_ref()
	var target: Node2D = token.target.get_ref()
	if world == null or not is_instance_valid(target) or not is_instance_valid(world.combat_flights): return
	var end: Vector2 = target.combat_hit_position() if target.has_method("combat_hit_position") else target.global_position
	# Explosion only where the existing flight arrived (its hit), not on cancel.
	if (token.point as Vector2).distance_to(end) > 1.0: return
	var blast: Node2D = _make(world,token.inputs,"explosion",0)
	if blast == null: return
	blast.set_as_top_level(true)
	blast.global_position = end
	world.combat_flights.add_child(blast)
	token["explosion_started"] = true
