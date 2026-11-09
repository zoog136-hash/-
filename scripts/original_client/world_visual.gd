extends RefCounted
## C27 / P7. DESIGN_NOT_RECOVERED_API. Light, weather and screen-effect display state. Server
## world rules (time, weather generation) are not here.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const WEATHER_CLEAR_ENUM := 7
const WATER_ENUM := 2

static func make() -> Dictionary:
	return {"record": "WorldVisualState", "design_status": VOCAB.EVIDENCE_DESIGN, "light_sources": [], "daynight_phase": null, "weather_fifo": [],
		"screen_effect_events": [], "active_weather": null, "light_alpha": 0.0}

## Light is consumed when radius + EC, as a signed byte, is positive.
static func light_consumed(radius_plus_ec: int) -> bool:
	return VOCAB.i8(radius_plus_ec) > 0

## Each step lerps the CURRENT alpha toward the target; it is not a fixed-start linear ramp.
static func light_step(current_alpha: float, target_alpha: float, t: float) -> float:
	return current_alpha + (target_alpha - current_alpha) * t

## Packet 190: type and amount go into a FIFO; one entry is consumed per valid tick.
static func weather_enqueue(state: Dictionary, type: int, amount: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	(out["weather_fifo"] as Array).append({"type": type, "amount": amount})
	return out

## stopAll first, then the selected weather start. Type 0 selects clear (enum 7); the water enum
## (2) is not selected by this switch.
static func weather_tick(state: Dictionary) -> Dictionary:
	if (state.weather_fifo as Array).is_empty():
		return {"state": state, "consumed": null, "stopped_all": false}
	var out: Dictionary = state.duplicate(true)
	var entry: Dictionary = (out["weather_fifo"] as Array).pop_front()
	var started: Variant = _weather_enum(int(entry.type))
	out["active_weather"] = started
	return {"state": out, "consumed": entry, "stopped_all": true, "started_enum": started}

static func _weather_enum(type: int) -> Variant:
	if type == 0:
		return WEATHER_CLEAR_ENUM
	if type == WATER_ENUM:
		return null
	return type

## TargetScreenEffect 422: local target only, id-only payload; duplicates are published as-is.
static func screen_effect_422(state: Dictionary, target_is_local: bool, effect_id: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	if target_is_local:
		(out["screen_effect_events"] as Array).append({"event": 422, "id": effect_id})
	return out
