extends RefCounted
## M104 Walker awakening selection (024CF3E0) and M109 Walker pending apply (01CAA010) (C09/C04/C13).
## DESIGN_NOT_RECOVERED_API. Walker+D0 is a RAW peer association: it is not the actor OID+D0 and
## the +78 pending effect vector is not the pending ENTER packet tree. Nothing here retains,
## rolls back or makes callbacks reentrancy-safe.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")

## Native flat key: primary=deck at flat+4, secondary=grade at flat+0, signed int32 lexicographic.
static func physical_key_bytes(deck: int, grade: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s32(0, V.i32(grade))
	b.encode_s32(4, V.i32(deck))
	return b

static func key_less(a: Array, b: Array) -> bool:  # [deck, grade] signed
	if V.i32(int(a[0])) != V.i32(int(b[0])):
		return V.i32(int(a[0])) < V.i32(int(b[0]))
	return V.i32(int(a[1])) < V.i32(int(b[1]))

## Signed lower_bound + reverse compare. Exact only for an ascending sorted table; first of
## duplicate keys wins. An unsorted table is rejected (undefended input), not repaired.
static func awaken_lookup(rows: Array, deck: int, grade: int) -> Variant:
	for i: int in range(1, rows.size()):
		if key_less([rows[i][0], rows[i][1]], [rows[i - 1][0], rows[i - 1][1]]):
			return {"status": V.REJECTED_UNDEFENDED, "note": "table not ascending"}
	var q: Array = [deck, grade]
	for r: Array in rows:
		if not key_less([r[0], r[1]], q):
			if key_less(q, [r[0], r[1]]):
				return null
			return V.i32(int(r[2]))  # StatusEffectID at payload+1C; no positive filter
	return null

## Card lookups: missing card -> 1 for each lookup (two separate lookups: grade then deck).
static func card_grade_deck(cards: Dictionary, card_id: int) -> Array:
	var c: Variant = cards.get(V.i32(card_id))
	var grade: int = 1 if c == null else int(c.grade)
	var deck: int = 1 if c == null else int(c.deck)
	return [deck, grade]

## 024CF3E0(PC, incoming, index). Returns per-slot actions in order.
## pc: {"owner": Variant, "slots": Array of 4 raw walker refs (2 groups x 2) or null}
## walker: {"byte65": int, "card": int, "d0": Variant, "pending78": Array}
## env: {"mode": int (effect option +1C), "self": Variant, "cards", "awaken_rows", "luid", "components": Dictionary peer->component}
static func augment(pc: Dictionary, incoming: Array, index: int, env: Dictionary) -> Dictionary:
	var actions: Array = []
	if pc.get("owner") == null or V.u32(index) > 1:
		return {"actions": ["dispose(incoming)"]}
	var start: int = V.i32(index) * 2
	for s: int in [start, start + 1]:
		var w: Variant = pc.slots[s]
		if w == null:
			continue
		var temp: Array = []
		if int(w.byte65) != 0:
			var mode: int = V.i32(int(env.mode))
			if mode != 2 and (mode != 1 or pc.owner == env.self):
				var dg: Array = card_grade_deck(env.cards, int(w.card))
				var effect_id: Variant = awaken_lookup(env.awaken_rows, int(dg[0]), int(dg[1]))
				if effect_id is int:
					temp.append([effect_id, env.luid])
		temp.append_array(incoming.duplicate(true))  # ordered, duplicates retained
		var peer: Variant = w.get("d0")
		if peer == null:
			w["pending78"] = temp.duplicate(true)  # 01CAC550 overwrite, copy then dispose
			actions.append({"slot": s, "path": "pending_assign", "tuples": temp})
		else:
			var comp: Variant = env.components.get(peer)
			if comp != null:
				actions.append({"slot": s, "path": "immediate_reconcile", "tuples": temp})
			else:
				actions.append({"slot": s, "path": "component_missing_no_pending_fallback"})
	actions.append("dispose(incoming)")
	return {"actions": actions}

## 01CA5D80 growth capacity rule: n > max_size error; max(n, old+old/2) saturated at max_size.
const VECTOR24_MAX := 0x0AAAAAAAAAAAAAAA
static func grow_capacity(n: int, old_capacity: int) -> Variant:
	if n > VECTOR24_MAX or n < 0:
		return {"status": "length_error"}
	var grown: int = old_capacity + old_capacity / 2
	if grown > VECTOR24_MAX or grown < 0:
		grown = VECTOR24_MAX
	return maxi(n, grown)

# ---------------------------------------------------------------- M109
## 01CAA010(W). Entry +D0 nonnull -> the WHOLE operation is skipped (pending replay too).
## Null path: opaque factory, store the result into the same +D0 (no caller factory-null guard),
## callbacks/cleanup (may mutate W), then RE-READ pending begin/end and +D0. Nonempty pending
## with a component -> reconcile(component, exact address of W+78). Pending is NOT cleared.
## hooks: {"factory": Callable(W)->peer, "callbacks": Callable(W) (may mutate), "components": Dictionary}
static func apply_pending(w: Dictionary, hooks: Dictionary) -> Dictionary:
	var ev: Array = []
	if w.get("d0") != null:
		return {"skipped": true, "events": ev}
	var peer: Variant = (hooks.factory as Callable).call(w)
	ev.append("factory")
	w["d0"] = peer
	ev.append("store_d0")
	if peer == null:
		ev.append("factory_null_stored_without_guard")
	var cb: Variant = hooks.get("callbacks")
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(w)
		ev.append("callable_replace_cleanup")
	var pending: Array = w.get("pending78", [])
	if pending.is_empty():
		ev.append("pending_empty_return")
		return {"skipped": false, "events": ev}
	var peer_now: Variant = w.get("d0")
	var comp: Variant = null if peer_now == null else hooks.components.get(peer_now)  # null input -> empty pair
	if comp != null:
		ev.append("reconcile(component,&W+78)")
		return {"skipped": false, "events": ev, "reconciled_with": pending, "peer_used": peer_now, "pending_after": w.get("pending78")}
	ev.append("component_missing")
	return {"skipped": false, "events": ev}

## 024CF350 controller: two groups x two raw slots; DL!=0 -> 01CAA010, DL==0 -> opaque 01CAC840.
static func controller(pc_slots: Array, dl: int, hooks: Dictionary) -> Array:
	var out: Array = []
	for w: Variant in pc_slots:
		if w == null:
			continue
		if dl != 0:
			out.append(apply_pending(w, hooks))
		else:
			out.append({"opaque": "01CAC840"})
	return out
