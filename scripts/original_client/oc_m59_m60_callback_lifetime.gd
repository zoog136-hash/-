extends RefCounted
## M59 (C11/C12/C13/C18, R59) and M60 (C06/C13/C14, R60). DESIGN_NOT_RECOVERED_API.
## Ref-counted owners, timeline callback storage and the Scheduler +61 flag. Field survival is
## only modelled while another retain remains; the final release runs the destructor, which
## destroys the callback storage. A sender retain does not retain the callback's raw owner.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

## ---- M59 refs (one Dictionary per object, mutated in place by these helpers) ------------
static func make_ref(name: String, fields: Dictionary, callback: Variant = null) -> Dictionary:
	return {"name": name, "refs": 1, "destroyed": false, "fields": fields.duplicate(true), "callback_storage": callback}

## Retain/release on a destroyed object is not defended by the original; the design layer refuses it.
static func retain(obj: Dictionary) -> bool:
	if obj.destroyed:
		return false
	obj.refs = int(obj.refs) + 1
	return true

static func release(obj: Dictionary) -> bool:
	if obj.destroyed:
		return false
	obj.refs = int(obj.refs) - 1
	if int(obj.refs) == 0:
		obj.destroyed = true
		obj.callback_storage = null
		obj.fields = {}
	return true

## ActionManager removal drops the manager's action ref only. No pause, no field clear.
static func manager_remove(timeline: Dictionary) -> Dictionary:
	release(timeline)
	return {"fields_preserved": not timeline.destroyed, "destructor_ran": timeline.destroyed, "paused": false}

## Sender retain: the widget gains a ref; the callback's raw owner gains nothing.
static func sender_retain(widget: Dictionary, raw_owner: Dictionary) -> Dictionary:
	var owner_refs: int = int(raw_owner.refs)
	retain(widget)
	return {"widget_refs": widget.refs, "raw_owner_refs_unchanged": int(raw_owner.refs) == owner_refs}

## ---- M60 Scheduler -----------------------------------------------------------------------
class Scheduler:
	extends RefCounted
	## +61 is not reset on entry. Queue callbacks run BEFORE update writes +61=1; a nested update's
	## normal return writes 0 and does not restore the outer value or a depth.
	var flag61: int = 0
	var scheduled: Array = []
	var pending: Array = []

	func update(queue_callbacks: Array) -> void:
		for cb: Callable in queue_callbacks:
			cb.call(self)
		flag61 = 1
		var snapshot: Array = scheduled.duplicate()
		for cb: Callable in snapshot:
			cb.call(self)
		flag61 = 0

	## unscheduleAll and pending clear are different, and neither cancels a snapshot already cloned.
	func unschedule_all() -> void:
		scheduled.clear()

	func clear_pending() -> void:
		pending.clear()

	func run_cloned_snapshot(snapshot: Array) -> int:
		var ran: int = 0
		for cb: Callable in snapshot:
			cb.call(self)
			ran += 1
		return ran
