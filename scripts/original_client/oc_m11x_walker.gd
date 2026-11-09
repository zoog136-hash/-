extends RefCounted
## M110 / M111 (C09, C13; F110 / F111). DESIGN_NOT_RECOVERED_API.
## M110: WalkerObjectProxy deactivation 01CAC840 - filtered+98 snapshot into pending+78, then
##       capture CURRENT +D0, clear it FIRST, then request the stored callable (+C8 virtual+10).
## M111: pool checkout 01CA56A0 separated from active registration 01CA60C0; duplicate active key
##       -> destructor0 -> append(saved pointer) -> null (no prior decrement/pop, no rollback).
## Records are dictionaries mutated in place so that hooks/callbacks can re-enter like the original
## receiver. Walker+D0 is NOT a UserObject OID; pending tuples are NOT the ENTER packet tree.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")

const ALLOCATOR_RVA := "03605E20"
const FREE_RVA := "03605E5C"
const M110_EVIDENCE := {"order": C.EVIDENCE_CONFIRMED, "callable_target": C.EVIDENCE_UNKNOWN, "peer_pool_return": C.EVIDENCE_UNKNOWN}
const M111_EVIDENCE := {"checkout_order": C.EVIDENCE_CONFIRMED, "n_plus_one": C.EVIDENCE_CONDITIONAL, "teardown": C.EVIDENCE_UNKNOWN}

## ---------------- M110 ----------------

## peer: {"f78": int, "f94": Array(16 bytes), "component": {"pointer": {"filtered98": [tuple]} | null, "control": ctrl | null}}
## tuple: {"id": int, "pair": {"pointer": Variant, "control": ctrl | null}}
static func make_walker(peer: Variant, pending: Array, callable: Variant) -> Dictionary:
	return {"record": "WalkerObjectProxy", "design_status": C.DESIGN, "D0_peer": peer, "pending78": pending, "C8_callable": callable,
		"f28": null, "f30": null, "trace": []}

## 024C97E0 -> 024C3810 -> 021C9800: copy ID DWORD and the +8/+10 shared pair, stride 24, order and
## duplicates kept, one strong increment per copied tuple. The source vector is not moved/cleared.
static func copy_filtered(src: Array) -> Array:
	var out: Array = []
	for t: Dictionary in src:
		var pair: Dictionary = t.pair
		C.retain(pair.control)
		out.append({"id": C.i32(int(t.id)), "pair": {"pointer": pair.pointer, "control": pair.control}})
	return out

static func release_tuples(tuples: Array) -> void:
	for t: Dictionary in tuples:
		C.release_local(t.pair.control)

## hooks.cleanup: Callable(W) invoked after temp/component cleanup and BEFORE the final reread
## (the original does not assume cleanup leaves the receiver unchanged).
static func deactivate(w: Dictionary, hooks: Dictionary = {}) -> Dictionary:
	var trace: Array = w.trace
	var entry_peer: Variant = w.D0_peer
	if entry_peer != null:
		w["f28"] = C.i32(int(entry_peer.f78))
		var observed_again: Variant = w.D0_peer
		w["f30"] = (observed_again.f94 as Array).duplicate()
		var for_component: Variant = w.D0_peer
		var comp: Dictionary = for_component.get("component", {"pointer": null, "control": null})
		if comp.pointer != null:
			var temp: Array = copy_filtered(comp.pointer.filtered98)
			trace.append("filtered-copy")
			# alias compare kept: a temp that IS the pending vector is not released/replaced.
			if not is_same(w.pending78, temp):
				release_tuples(w.pending78)
				w["pending78"] = temp
				trace.append("pending-replaced")
			temp = []
		else:
			trace.append("component-absent-pending-kept")
		C.release_local(comp.control)  # control checked even when the pointer is null
		trace.append("component-local-release")
	if hooks.has("cleanup"):
		(hooks.cleanup as Callable).call(w)
	var captured_current_peer: Variant = w.D0_peer  # 01CACA16, separate from entry_peer
	w["D0_peer"] = null  # 01CACA1D: clear BEFORE the request
	trace.append("D0-cleared")
	if captured_current_peer == null:
		return {"entry_peer": entry_peer, "captured_peer": null, "callable_requested": false}
	var callable: Variant = w.C8_callable
	if callable == null:
		trace.append("bad_function_call_boundary")
		return {"entry_peer": entry_peer, "captured_peer": captured_current_peer, "callable_requested": false, "outcome": C.UNGUARDED_BOUNDARY}
	trace.append("callable-requested")
	# Argument is the ADDRESS of the stack slot holding the peer, modelled as a holder.
	(callable as Callable).call(w, {"slot": captured_current_peer})
	# No forced re-clear of +D0 / +78 / +C8 after the callback.
	return {"entry_peer": entry_peer, "captured_peer": captured_current_peer, "callable_requested": true}

## ---------------- M111 ----------------

## Pool P = manager+510. "available" is the logical sequence; checkout takes its LAST element
## (logical = start + count - 1). "all" (P+28) and "active" (P+78) are pointer-keyed tables of (p,p).
static func make_pool(available: Array, batch: int) -> Dictionary:
	var all_table: Dictionary = {}
	for p: Variant in available:
		all_table[p] = p
	return {"record": "WalkerPool", "design_status": C.DESIGN, "available": available.duplicate(), "start": 0, "batch": batch,
		"all": all_table, "active": {}, "trace": []}

## 01CA60C0: existing key -> (existing, false) and the temporary node is freed; value NOT replaced.
static func register_unique(table: Dictionary, p: Variant) -> bool:
	if table.has(p):
		return false
	table[p] = p
	return true

static func append_available(pool: Dictionary, p: Variant) -> void:
	(pool.available as Array).append(p)

## hooks: "allocate" Callable() -> Variant (null = failed allocation), "construct" Callable(p),
## "destruct" Callable(p). All may mutate the pool (re-entry is not excluded by the original).
static func checkout(pool: Dictionary, hooks: Dictionary) -> Variant:
	var trace: Array = pool.trace
	if (pool.available as Array).is_empty():
		var batch: int = C.i32(int(pool.batch))  # read ONCE
		for _i: int in maxi(batch, 0):
			var p: Variant = (hooks.allocate as Callable).call()
			if p != null:
				if register_unique(pool.all, p):
					append_available(pool, p)
					trace.append("refill-append")
				else:
					trace.append("refill-duplicate-no-free-no-append")
		if (pool.available as Array).is_empty():  # CURRENT count after refill
			trace.append("checkout-null-empty")
			return null
	var saved_p: Variant = (pool.available as Array).back()
	(hooks.construct as Callable).call(saved_p)
	trace.append("construct")  # constructor always precedes active registration
	if not register_unique(pool.active, saved_p):
		(hooks.destruct as Callable).call(saved_p)
		trace.append("destructor0")
		append_available(pool, saved_p)  # appends; NOT erase/rollback
		trace.append("append-saved")
		return null
	(pool.available as Array).pop_back()  # CURRENT count decremented only on success
	if (pool.available as Array).is_empty():
		pool["start"] = 0
	trace.append("checkout-ok")
	return saved_p

## 01CA5950: policy 01CA9E00 (not argument F2) chooses pool vs direct allocation. The F3 shared
## control is read AFTER the branch returns; the result is saved across cleanup, not re-read.
static func factory(pool_enabled: bool, pool: Dictionary, hooks: Dictionary, shared_argument: Dictionary) -> Dictionary:
	var result: Variant = null
	if pool_enabled:
		result = checkout(pool, hooks)
	else:
		var storage: Variant = (hooks.allocate as Callable).call()
		if storage != null:
			(hooks.construct as Callable).call(storage)
			result = storage
	var control: Variant = shared_argument.get("control")
	C.release_local(control)
	return {"result": result, "argument10_disposed": true}
