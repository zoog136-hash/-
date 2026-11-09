extends RefCounted
## C16 / P4. DESIGN_NOT_RECOVERED_API. Spell effect lifetimes and result callbacks. Server
## results arrive as display input only; hit, damage and reflection are never decided here.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const FACTORY_TYPES := [1, 11, 21, 31, 64, 78]
const QUEUE_KINDS := ["attack_range_receive", "caster_command", "sequential_target", "renderer_key4"]

static func create_primary(effect_type: int) -> Dictionary:
	if effect_type in FACTORY_TYPES:
		return {"primary": effect_type, "side_visuals_evaluated_separately": true}
	return {"primary": null, "side_visuals_evaluated_separately": true, "note": "unsupported type: no primary effect, which is not the same as no side visual"}

static func make_instance(kind: String, source: Variant, target_identity: Variant, sprite: int, ordinal: int, completion_policy: String, queue_kind: String) -> Dictionary:
	return {"record": "EffectInstance", "design_status": VOCAB.EVIDENCE_DESIGN, "kind": kind, "source": source, "target_identity": target_identity,
		"sprite": sprite, "ordinal": ordinal, "completion_policy": completion_policy, "callback_payload": null, "queue_kind": queue_kind, "state": "active", "remaining": 0}

## Missile 11: completes (callback + removal) only when it reaches the destination. Using up
## its remaining repetitions without arriving removes it with no callback.
static func missile_step(effect: Dictionary, reached_destination: bool) -> Dictionary:
	var out: Dictionary = effect.duplicate(true)
	if reached_destination:
		out["state"] = "removed"
		return {"effect": out, "completion_callback": true}
	out["remaining"] = int(effect.remaining) - 1
	if int(out.remaining) <= 0:
		out["state"] = "removed"
		return {"effect": out, "completion_callback": false}
	return {"effect": out, "completion_callback": false}

## Direct 21: finishing the advance shows completion and is removed on the NEXT callback, not
## immediately.
static func direct_advance(effect: Dictionary, advance_complete: bool) -> Dictionary:
	var out: Dictionary = effect.duplicate(true)
	if advance_complete:
		out["state"] = "completed_display"
	return {"effect": out, "removed_now": false}

static func direct_callback(effect: Dictionary) -> Dictionary:
	var out: Dictionary = effect.duplicate(true)
	if out.state == "completed_display":
		out["state"] = "removed"
	return {"effect": out, "removed": out.state == "removed"}

## Splash 64: the callback fires at activation; a failed advance step removes it.
static func splash_activate(effect: Dictionary) -> Dictionary:
	return {"effect": effect, "activation_callback": true}

static func splash_advance(effect: Dictionary, advance_ok: bool) -> Dictionary:
	var out: Dictionary = effect.duplicate(true)
	if not advance_ok:
		out["state"] = "removed"
	return {"effect": out}

## Blast 31 and Directional 78 are chains: at ordinal 2 a NEW object of the same subclass
## continues. They are not one linear projectile.
static func chain_next(effect: Dictionary) -> Dictionary:
	if effect.kind in ["blast31", "directional78"] and int(effect.ordinal) == 2:
		return {"spawn": make_instance(effect.kind, effect.source, effect.target_identity, int(effect.sprite), 0, effect.completion_policy, effect.queue_kind)}
	return {"spawn": null}

## Result and damage kind are different enums. The ordinary FailEffectSpriteID is never
## assigned to a failure sprite automatically.
static func received_combat_visual(result_enum: int, damage_kind_enum: int, fail_sprite_id: Variant = null) -> Dictionary:
	return {"result": result_enum, "damage_kind": damage_kind_enum, "fail_sprite": fail_sprite_id, "server_decided": true}

## The result visual re-reads the target's position when the callback runs.
static func callback_target_position(target_identity: Variant, current_positions: Dictionary, first_seen_position: Vector2i) -> Dictionary:
	if current_positions.has(target_identity):
		return {"position": current_positions[target_identity], "requeried": true}
	return {"position": first_seen_position, "requeried": false, "note": "target no longer known; the first position is only a last resort"}
