extends RefCounted
## M78 v2 (C12/C13, R78). DESIGN_NOT_RECOVERED_API. TextField detach/attach lifecycle for the
## end-cursor fixture scope only. This is not a full IME/attach equivalent: OS composition,
## selection, caret and repeated mid-cursor attach are not modelled.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

## state: {"active": id|null, "fields": {id: {"attached": bool, "hook_flag": bool, "impl": bool}}, "events": []}
static func make(ids: Array) -> Dictionary:
	var fields: Dictionary = {}
	for id: Variant in ids:
		fields[id] = {"attached": false, "hook_flag": false, "impl": true}
	return {"active": null, "fields": fields, "events": []}

## Same attached byte -> native early return (D003DA264).
static func attach(state: Dictionary, id: Variant) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	if bool(out.fields[id].attached):
		out.events.append("attach_early_return_same_state")
		return out
	out.fields[id].attached = true
	out["active"] = id
	out.events.append("attach")
	return out

## LF / control6 is a detach REQUEST. impl, non-null target and active identity are checked before
## canDetach. The selected UICC hook sets its flag first and returns false; canDetach inverts it.
## Flag, active clear, didDetach and observer are separate steps.
static func press_lf(state: Dictionary, id: Variant, target_nonnull: bool) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out.events.append("detach_request")
	if not bool(out.fields[id].impl) or not target_nonnull or out.active != id:
		return out
	out.fields[id].hook_flag = true
	out.events.append("hook_flag_set")
	var hook_return: bool = false
	var can_detach: bool = not hook_return
	if can_detach:
		out["active"] = null
		out.events.append("active_cleared")
		# What happens to the attached byte here is not fixed by this package; it is left as is.
		out.events.append("didDetach")
		out.events.append("observer")
	return out

## The tail dispatcher reads the CURRENT active again; with active null it does not produce event4.
static func tail_dispatch(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	if out.active != null:
		out.events.append("event4_return:%s" % str(out.active))
	return out

## removeDelegate is not detach: active/list cleanup without didDetach/observer; renderer
## attached/pending can remain.
static func remove_delegate(state: Dictionary, id: Variant) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	if out.active == id:
		out["active"] = null
	out.events.append("remove_delegate")
	out["renderer_attached_may_remain"] = bool(out.fields[id].attached)
	(out.fields as Dictionary).erase(id)
	return out
