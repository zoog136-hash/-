extends RefCounted
## M55 (C15, R55) DownloadPlay cancel and M57 (C15/C20) repeating-spell request preparation.
## DESIGN_NOT_RECOVERED_API. Neither path sends anything or creates a visual effect.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

## M55: the reviewed local cancel body and the Event2D6 lambda do not store DownloadPlayManager+10
## directly. 01F6C280 releases the Timer owner and publishes an event; other listeners and
## destructors are open, so the active byte is NOT guaranteed unchanged. listeners: Array[Callable]
## each takes the state Dictionary and may mutate it (external, not original behaviour).
static func download_play_cancel(state: Dictionary, listeners: Array) -> Dictionary:
	var live: Dictionary = state.duplicate(true)
	var before: Variant = live.get("active10")
	var trace: Array = ["local_cancel_body", "01F6C280_release_timer_owner", "01F6C280_publish_event"]
	live["timer_owner"] = null
	for l: Callable in listeners:
		l.call(live)
		trace.append("external_listener")
	return V.rec("DownloadPlayCancel", "M55", V.CONFIRMED, {"state": live, "trace": trace, "direct_store_active10": false,
		"active10_before": before, "active10_after": live.get("active10"), "active10_invariant_guaranteed": false})

## M57: ClientRepeatingSpellManager. Integer countdown only; current target is looked up again at
## preparation time (never the target captured at start). When the countdown fires is not given by
## this package, so the caller decides when to call prepare_request().
static func repeating_make(spell_id: int, countdown: int) -> Dictionary:
	return V.rec("RepeatingSpell", "M57", V.CONFIRMED, {"spell_id": spell_id, "countdown": countdown, "captured_target": null, "is_visual_effect_queue": false})

static func repeating_countdown(state: Dictionary, step: Variant) -> Dictionary:
	if not (step is int) or not (state.countdown is int):
		return V.rec("RepeatingCountdown", "M57", V.REJECTED, {"state": state, "reason": "countdown is integer-only"})
	var out: Dictionary = state.duplicate(true)
	out["countdown"] = int(state.countdown) - int(step)
	return V.rec("RepeatingCountdown", "M57", V.CONFIRMED, {"state": out})

static func repeating_prepare_request(state: Dictionary, current_target_lookup: Callable) -> Dictionary:
	var target: Variant = current_target_lookup.call()
	return V.rec("RepeatingSpellRequestPreparation", "M57", V.CONFIRMED, {"spell_id": state.spell_id, "target": target,
		"target_source": "current_lookup_at_prepare", "sent": false, "ack": V.UNKNOWN, "visual_effect_created": false})

static func repeating_clear(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["cleared"] = true
	return out
