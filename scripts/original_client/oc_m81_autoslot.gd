extends RefCounted
## M81 v2 (C15/C20, R81_ORDER). DESIGN_NOT_RECOVERED_API. QuickSlotAutoManager slot sweep and
## local request preparation as fixed by the final QA (PASS_BOUNDED_STATIC). A local preparation
## result is not a server response code; nothing here sends, casts, or decides cooldown/combat.
## Not modelled (not in this package): virtual-ID selection, BuffDeck/aux item helpers, HP/MP
## threshold product formula, remembered spell/OID TTL, Hunting settings.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

const MAIN_INTERVAL_F32 := 0.5

## Observer: qword delta -> CVTSI2SS (signed64 -> f32, one rounding) -> DIVSS 1000.0f.
static func delta_seconds(delta_qword: int) -> float:
	return V.f32(V.i64_to_f32_direct(delta_qword) / 1000.0)

## ADDSS accumulate; fire only for ORDERED elapsed > interval (equality and NaN do not fire);
## subtract the interval ONCE (no catch-up while, no clamp to zero).
static func timer_step(elapsed: float, dt: float, interval: float = MAIN_INTERVAL_F32) -> Dictionary:
	var e: float = V.f32(elapsed + dt)
	var fire: bool = e > interval
	if fire:
		e = V.f32(e - interval)
	return {"elapsed": e, "fired": fire}

## Manager callback order: queued pass -> enable(+D8) -> safety zone -> spell pass -> auxiliary
## pass; both passes always run and their bools are ORed.
static func manager_callback(enable_d8: bool, safety_ok: bool, queued_pass: Callable, spell_pass: Callable, aux_pass: Callable) -> Dictionary:
	var trace: Array = ["queued_pass"]
	queued_pass.call()
	if not enable_d8:
		trace.append("enable_D8_false_stop")
		return {"trace": trace, "result": false}
	if not safety_ok:
		trace.append("safety_zone_stop")
		return {"trace": trace, "result": false}
	var a: bool = spell_pass.call()
	trace.append("spell_pass")
	var b: bool = aux_pass.call()
	trace.append("aux_pass")
	return {"trace": trace, "result": a or b}

## pair: {"page": i32, "button": i32}. Priority key page*5+button wraps at signed32.
static func priority_key(pair: Dictionary) -> int:
	return V.i32(int(pair.page) * 5 + int(pair.button))

## Priority ordering by the signed32 key (stable sort is a DESIGN choice: tie order is not fixed).
## Non-priority: in-place shuffle by the injected shuffler. Virtual pairs go in FRONT of the copy.
static func build_local_order(pairs: Array, priority: bool, virtual_pairs: Array, shuffler: Callable) -> Dictionary:
	var local: Array = pairs.duplicate(true)
	if priority:
		var keyed: Array = []
		for i: int in local.size():
			keyed.append([priority_key(local[i]), i, local[i]])
		keyed.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
		local = keyed.map(func(x: Array) -> Dictionary: return x[2])
	else:
		shuffler.call(local)
	var out: Array = virtual_pairs.duplicate(true)
	out.append_array(local)
	return {"order": out, "tie_order": V.CONDITIONAL if priority else "SHUFFLED"}

## Q81-ORDER01 metadata resolution plus the observed read order. env Callables:
##  getter() -> Variant (substitution getter; may answer differently per call),
##  ordinary() -> Variant, cooldown_ready(meta) -> bool, learned(id) -> bool,
##  read(name) -> int (HPCost/HP/MPcost/MP/self_v78/passive/category/maxMP).
## Every call is logged in `calls`.
static func evaluate_pair(is_virtual: bool, env: Dictionary) -> Dictionary:
	var calls: Array = []
	var first: Variant = env.getter.call()
	calls.append("getter1")
	var r15: Variant = first
	var meta: Variant = null
	if first != null:
		meta = env.getter.call()
		calls.append("getter2")
		if meta == null:
			calls.append("slot_shared_cleanup")
			return {"outcome": "NEXT_PAIR", "calls": calls, "meta": null}
	else:
		meta = env.ordinary.call()
		calls.append("ordinary_lookup")
		if meta == null:
			calls.append("slot_shared_cleanup")
			return {"outcome": "NEXT_PAIR", "calls": calls, "meta": null, "evidence": V.CONDITIONAL}
	calls.append("cooldown")
	if not bool(env.cooldown_ready.call(meta)):
		calls.append("slot_shared_cleanup")
		return {"outcome": "NEXT_PAIR", "calls": calls, "meta": meta, "evidence": V.CONDITIONAL}
	if not is_virtual:
		if r15 == null:
			calls.append("learned:%s" % str(meta.id))
			if not bool(env.learned.call(meta.id)):
				calls.append("slot_shared_cleanup")
				return {"outcome": "NEXT_PAIR", "calls": calls, "meta": meta, "evidence": V.CONDITIONAL}
		else:
			calls.append("learned_exempt_by_first_return")
	var reads: Dictionary = observe_resources(meta, env.read)
	calls.append_array(reads.order)
	return {"outcome": "RESOURCES_OBSERVED", "calls": calls, "meta": meta, "values": reads.values, "learned_basis": "first_return_R15"}

## HPCost -> HP(stat4) -> meta.ID/MPcost -> MP(stat6) -> self v78 -> passive only if v78 == 1 ->
## category -> maxMP(stat5). Each value is read once at its point; nothing is re-read later.
static func observe_resources(meta: Variant, read: Callable) -> Dictionary:
	var order: Array = []
	var values: Dictionary = {}
	for name: String in ["HPCost", "HP_stat4", "meta_ID", "MPcost", "MP_stat6", "self_v78"]:
		values[name] = read.call(name)
		order.append(name)
	if int(values.self_v78) == 1:
		values["passive"] = read.call("passive")
		order.append("passive")
	for name: String in ["category", "maxMP_stat5"]:
		values[name] = read.call(name)
		order.append(name)
	return {"order": order, "values": values}

## Priority-reservation resource step (S0989 L77). flags start all false and persist over the sweep.
static func reservation_step(flags: Dictionary, ready: bool, hp: int, hp_cost: int, mp: int, mp_cost: int) -> String:
	if not ready:
		flags.mpShort = bool(flags.mpShort) or (mp < mp_cost)
		flags.hpShort = bool(flags.hpShort) or (hp <= hp_cost)
		if mp_cost > 0 and hp_cost > 0 and (flags.mpShort or flags.hpShort):
			return "ABORT_SWEEP_RETURN_ACCUMULATED"
		return "NEXT_SLOT"
	if mp_cost > 0 and mp >= mp_cost and flags.mpShort:
		return "SKIP"
	if hp_cost > 0 and hp > hp_cost and flags.hpShort:
		return "SKIP"
	return "PROCEED"

static func make_flags() -> Dictionary:
	return {"mpShort": false, "hpShort": false, "failedMP": false, "failedHP": false}

## A sweep keeps going after a successful pair (local event published, then the next pair).
## pair_eval(pair) -> "SUCCESS"|"NEXT"|"ABORT"
static func sweep(order: Array, pair_eval: Callable) -> Dictionary:
	var success: bool = false
	var events: Array = []
	var visited: Array = []
	for p: Dictionary in order:
		visited.append(p)
		var r: String = pair_eval.call(p)
		if r == "ABORT":
			break
		if r == "SUCCESS":
			success = true
			events.append("local_event:%d/%d" % [int(p.page), int(p.button)])
	return {"result": success, "events": events, "visited": visited.size()}

static func make_manager() -> Dictionary:
	return {"v28": {"size": 3, "capacity": 8}, "v40": {"size": 2, "capacity": 4}, "v58": {"size": 1, "capacity": 4},
		"virtual70": [1], "queued_F0": {"nodes": [{"page": 0, "button": 1}], "sentinel": true}, "enable_D8": true,
		"gates": {"safety": true}, "clock": 7, "main_elapsed": 0.25}

## 02131540: end=begin of +28/+40/+58 only. Capacity, virtual+70, queued+F0, enable/gates/clock/timers are kept.
static func clear_selected(m: Dictionary) -> Dictionary:
	var out: Dictionary = m.duplicate(true)
	for k: String in ["v28", "v40", "v58"]:
		out[k].size = 0
	return out

## 0218E330: queued nodes/count only; the sentinel stays.
static func clear_queued(m: Dictionary) -> Dictionary:
	var out: Dictionary = m.duplicate(true)
	out.queued_F0.nodes = []
	return out

## 0218D970: clear queued, insert one pair; slot v58 true sets main.elapsed = interval, so a
## following zero delta does not fire (strict >).
static func queue_single(m: Dictionary, pair: Dictionary, slot_v58: bool) -> Dictionary:
	var out: Dictionary = clear_queued(m)
	out.queued_F0.nodes = [pair.duplicate()]
	if slot_v58:
		out.main_elapsed = MAIN_INTERVAL_F32
	return out
