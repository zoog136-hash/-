extends "res://tests/original_client_test_base.gd"
## M110 - M123 acceptance tests on the DESIGN modules (reference package 01-123). The original
## binary is never executed; a PASS means the design module follows the written contract on the
## fixture, not native equivalence, timing or pixels. Real package values come from
## data/original_client/fixtures/m110_m123_fixture.json ("real"); everything else is synthetic.
const C = preload("res://scripts/original_client/oc_m11x_common.gd")
const WALK = preload("res://scripts/original_client/oc_m11x_walker.gd")
const KL = preload("res://scripts/original_client/oc_m11x_keys_land.gd")
const OL = preload("res://scripts/original_client/oc_m11x_outline.gd")
const SC = preload("res://scripts/original_client/oc_m11x_scenario_ui.gd")
const ZW = preload("res://scripts/original_client/oc_m12x_ziggurat_warzone.gd")
const SP = preload("res://scripts/original_client/oc_m12x_screen_spine.gd")
const SS = preload("res://scripts/original_client/oc_m12x_short_selector.gd")
const FIXTURE_PATH := "res://data/original_client/fixtures/m110_m123_fixture.json"

var fx: Dictionary = {}
var real: Dictionary = {}

func run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	fx = parsed if parsed is Dictionary else {}
	real = fx.get("real", {})
	check("FIXTURE", not real.is_empty(), "m110_m123 fixture could not be read")
	if real.is_empty():
		finish("ORIGINAL_CLIENT_M110_M123_RESULT")
		return
	t_m110()
	t_m111()
	t_m112()
	t_m113()
	t_m115()
	t_m118()
	t_m119()
	t_m121()
	t_m122()
	t_m123()
	t_m123_model_cases()
	finish("ORIGINAL_CLIENT_M110_M123_RESULT", {"fixture_id": fx.get("fixture_id", ""), "fixture_sha256": FileAccess.get_sha256(FIXTURE_PATH)})

static func by_id(rows: Array, key: String = "ID") -> Dictionary:
	var out: Dictionary = {}
	for r: Dictionary in rows:
		out[int(r[key])] = r
	return out

static func sorted_by(rows: Array, key: String) -> Array:
	var out: Array = rows.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a[key]) < int(b[key]))
	return out

## ---------------------------------------------------------------- M110
func t_m110() -> void:
	var mk_peer := func(comp_pointer: Variant, comp_control: Variant) -> Dictionary:
		return {"id": "peer", "f78": 0x1234, "f94": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], "component": {"pointer": comp_pointer, "control": comp_control}}
	var old_ctl: Dictionary = C.make_control(1, 1)
	var old_pending: Array = [{"id": 9, "pair": {"pointer": "old", "control": old_ctl}}]
	var cb_log: Array = []
	var callback := func(w: Dictionary, holder: Dictionary) -> void:
		cb_log.append({"peer_during": w.D0_peer, "slot": holder.slot})
	# component absent: pointer null, control still released
	var absent_ctl: Dictionary = C.make_control(1, 1)
	var w1: Dictionary = WALK.make_walker(mk_peer.call(null, absent_ctl), old_pending.duplicate(), callback)
	var r1: Dictionary = WALK.deactivate(w1)
	check("M110-T01", w1.pending78.size() == 1 and w1.pending78[0].id == 9 and int(old_ctl.strong) == 1, "component-absent keeps pending")
	check("M110-T01", int(absent_ctl.strong) == 0 and (absent_ctl.events as Array).has("destroy-owned"), "control released even when the component pointer is null")
	check("M110-T01", w1.D0_peer == null and r1.callable_requested and cb_log[0].peer_during == null and cb_log[0].slot.id == "peer", "clear before request; callable gets the captured peer slot")
	check("M110-T01", w1.f28 == 0x1234 and (w1.f30 as Array).size() == 16, "peer+78 -> W+28 and 16 bytes of peer+94 -> W+30")
	# present-empty: pending replaced with empty, old tuples released
	var old_ctl2: Dictionary = C.make_control(1, 1)
	var w2: Dictionary = WALK.make_walker(mk_peer.call({"filtered98": []}, null), [{"id": 9, "pair": {"pointer": "old", "control": old_ctl2}}], callback)
	WALK.deactivate(w2)
	check("M110-T01", w2.pending78.is_empty() and int(old_ctl2.strong) == 0, "present-empty replaces pending with empty (not the same as absent)")
	# nonempty with ordered duplicates of the same control
	var caster: Dictionary = C.make_control(1, 1)
	var src: Array = [{"id": 5, "pair": {"pointer": "c", "control": caster}}, {"id": 5, "pair": {"pointer": "c", "control": caster}}, {"id": -3, "pair": {"pointer": null, "control": null}}]
	var w3: Dictionary = WALK.make_walker(mk_peer.call({"filtered98": src}, null), [], callback)
	WALK.deactivate(w3)
	check("M110-T01", w3.pending78.size() == 3 and w3.pending78[0].id == 5 and w3.pending78[2].id == -3 and int(caster.strong) == 3, "order/duplicates kept, one strong increment per tuple")
	check("M110-T01", src.size() == 3 and not is_same(w3.pending78, src), "source filtered vector is not moved or cleared")
	# callback re-writes the association: no forced re-clear afterwards
	var new_peer: Dictionary = mk_peer.call(null, null)
	var rewriting := func(w: Dictionary, _holder: Dictionary) -> void:
		w["D0_peer"] = new_peer
		w["pending78"] = [{"id": 77, "pair": {"pointer": "n", "control": null}}]
	var w4: Dictionary = WALK.make_walker(mk_peer.call({"filtered98": []}, null), [], rewriting)
	WALK.deactivate(w4)
	check("M110-T02", is_same(w4.D0_peer, new_peer) and w4.pending78[0].id == 77, "callback-installed peer/pending survive (no post-callback write)")
	# cleanup hook replaces the peer -> the CURRENT one is captured, not the entry peer
	var swapped: Dictionary = mk_peer.call(null, null)
	swapped["id"] = "swapped"
	cb_log.clear()
	var w5: Dictionary = WALK.make_walker(mk_peer.call({"filtered98": []}, null), [], callback)
	var r5: Dictionary = WALK.deactivate(w5, {"cleanup": func(w: Dictionary) -> void: w["D0_peer"] = swapped})
	check("M110-X1", r5.entry_peer.id == "peer" and r5.captured_peer.id == "swapped" and cb_log[0].slot.id == "swapped", "entry peer and captured current peer are separate observations")
	var w6: Dictionary = WALK.make_walker(null, old_pending.duplicate(), callback)
	var r6: Dictionary = WALK.deactivate(w6)
	check("M110-X1", r6.callable_requested == false and w6.pending78.size() == 1 and (w6.trace as Array).has("D0-cleared"), "entry null: no snapshot but the final reread/reset still runs")
	var w7: Dictionary = WALK.make_walker(mk_peer.call(null, null), [], null)
	var r7: Dictionary = WALK.deactivate(w7)
	check("M110-X1", w7.D0_peer == null and r7.get("outcome") == C.UNGUARDED_BOUNDARY, "callable missing: clear already happened, then bad_function_call boundary")
	check("M110-X1", WALK.ALLOCATOR_RVA == "03605E20" and WALK.FREE_RVA == "03605E5C", "allocator/free RVAs")

## ---------------------------------------------------------------- M111
func t_m111() -> void:
	var log: Array = []
	var alloc_queue: Array = ["p1", "p2", null, "p1"]
	var hooks := {"allocate": func() -> Variant: return alloc_queue.pop_front() if not alloc_queue.is_empty() else null,
		"construct": func(p: Variant) -> void: log.append(["construct", p]),
		"destruct": func(p: Variant) -> void: log.append(["destruct", p])}
	var empty_pool: Dictionary = WALK.make_pool([], 4)
	var got: Variant = WALK.checkout(empty_pool, hooks)
	check("M111-T01", got == "p2" and empty_pool.available == ["p1"] and empty_pool.all.size() == 2, "empty pool refills batch 4 (null alloc skipped, duplicate not appended) then checks out the last")
	check("M111-T01", (empty_pool.trace as Array).count("refill-duplicate-no-free-no-append") == 1 and log[0] == ["construct", "p2"], "duplicate in the all-table: no free, no append, loop continues")
	var nonempty: Dictionary = WALK.make_pool(["a", "b"], 4)
	alloc_queue.clear()
	var got2: Variant = WALK.checkout(nonempty, hooks)
	check("M111-T01", got2 == "b" and nonempty.available == ["a"] and not (nonempty.trace as Array).has("refill-append"), "nonempty pool: no refill")
	var zero_batch: Dictionary = WALK.make_pool([], 0)
	check("M111-T01", WALK.checkout(zero_batch, hooks) == null and zero_batch.available.is_empty(), "batch <= 0 -> no refill -> null")
	# batch read once even if the allocator changes it
	var once: Dictionary = WALK.make_pool([], 2)
	var n_alloc: Array = [0]
	var hooks_once := hooks.duplicate()
	hooks_once["allocate"] = func() -> Variant:
		n_alloc[0] += 1
		once["batch"] = 100
		return "q%d" % n_alloc[0]
	WALK.checkout(once, hooks_once)
	check("M111-T01", n_alloc[0] == 2, "signed batch read once")
	# duplicate active registration
	log.clear()
	var dup: Dictionary = WALK.make_pool(["a", "p"], 4)
	dup.active["p"] = "p"
	var res: Variant = WALK.checkout(dup, hooks)
	check("M111-T02", res == null and dup.available == ["a", "p", "p"], "failure yields A+[p] (n+1); p not removed first")
	check("M111-T02", log == [["construct", "p"], ["destruct", "p"]] and (dup.trace as Array).slice(-3) == ["construct", "destructor0", "append-saved"], "constructor -> destructor0 -> append(saved) order")
	var shared := {"control": C.make_control(1, 1)}
	var f: Dictionary = WALK.factory(false, WALK.make_pool([], 1), {"allocate": func() -> Variant: return null, "construct": hooks.construct, "destruct": hooks.destruct}, shared)
	check("M111-X1", f.result == null and int(shared.control.strong) == 0, "direct allocation null -> null result; F3 control still released after the branch")

## ---------------------------------------------------------------- M112
func t_m112() -> void:
	var k: PackedByteArray = KL.physical_key({"grade": -1, "deck": 2})
	check("M112-T01", k.hex_encode() == "ffffffff02000000", "physical [grade, deck] little-endian")
	var rows: Array = [
		{"key": KL.physical_key({"grade": 1, "deck": -1}), "effect_id": 101},
		{"key": KL.physical_key({"grade": -1, "deck": 2}), "effect_id": 102},
		{"key": KL.physical_key({"grade": 3, "deck": -1}), "effect_id": 103},
		{"key": KL.physical_key({"grade": -5, "deck": 0}), "effect_id": 104}]
	var sem: Array = KL.sort_semantic(rows)
	var order: Array = sem.map(func(r: Dictionary) -> int: return int(r.effect_id))
	check("M112-T01", order == [101, 103, 104, 102], "semantic order signed(deck) then signed(grade); got %s" % str(order))
	check("M112-T01", KL.lookup_effect(sem, -1, 3) == 103 and KL.lookup_effect(sem, 2, -1) == 102 and KL.lookup_effect(sem, 3, -1) == null, "lookup uses (deck, grade), swapped pair misses")
	var u64_sorted: Array = rows.duplicate()
	u64_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return C.u64_gt(KL.u64_view(b.key), KL.u64_view(a.key)))
	check("M112-T01", u64_sorted.map(func(r: Dictionary) -> int: return int(r.effect_id)) != order, "a uint64 numeric compare of the bytes is NOT equivalent")
	check("M112-X1", KL.table_key({"key_callable": null}, {"grade": 1, "deck": 1}).get("outcome") == C.UNGUARDED_BOUNDARY, "missing key callable: no key output")

## ---------------------------------------------------------------- M113
func t_m113() -> void:
	var real_rows: Array = real.m113_land_attribute_type11.rows
	check("M113-T02", real_rows.size() == 6, "six real type11 rows")
	var table := {"rows": [{"ID": 1, "LandID": 63, "LandAttributeTypeID": 3, "Value": 9}] + real_rows + [{"ID": 2, "LandID": 900, "LandAttributeTypeID": 11, "Value": 0}, {"ID": 3, "LandID": 901, "LandAttributeTypeID": 11, "Value": -4}]}
	for row: Dictionary in real_rows:
		var wz := {"blocks": {2: {"active": false}}, "trace": []}
		var r: Dictionary = KL.select_water(table, int(row.LandID), wz)
		check("M113-T02", r.request == "start" and int(r.matched.ID) == int(row.ID) and wz.blocks[2].active, "real Land %d selects Water" % int(row.LandID))
	for land: int in [900, 901]:
		var wz0 := {"blocks": {2: {"active": false}}, "trace": []}
		check("M113-T02", KL.select_water(table, land, wz0).request == "start", "type11 present with Value %s still selects (Value not read)" % str(land))
	var wz1 := {"blocks": {2: {"active": true}}, "trace": []}
	var r1: Dictionary = KL.select_water(table, 12345, wz1)
	check("M113-T01", r1.request == "stop" and (wz1.trace as Array).has("stop-body"), "no type11 row + active -> stop request")
	var wz2 := {"blocks": {2: {"active": false}}, "trace": []}
	check("M113-T01", KL.select_water(table, 12345, wz2).request == "none_inactive" and wz2.trace.is_empty(), "no type11 row + inactive -> nothing")
	check("M113-T01", KL.select_water({"rows": [{"ID": 1, "LandID": 63, "LandAttributeTypeID": 3, "Value": 9}]}, 63, {"blocks": {}, "trace": []}).request == "none_inactive", "other attribute types of the same Land do not select")
	var wz3 := {"blocks": {2: {"active": true}}, "trace": []}
	var r3: Dictionary = KL.select_water(table, 65, wz3)
	check("M113-T03", r3.request == "none_already_active" and wz3.trace.is_empty(), "already active: no restart request")
	check("M113-X1", KL.select_water(null, 65, {"blocks": {}, "trace": []}).get("outcome") == C.UNGUARDED_BOUNDARY, "missing table is not an empty table (no safe no-op)")
	var wz4 := {"blocks": {}, "trace": []}
	KL.select_water(table, 65, wz4)
	check("M113-X1", wz4.trace == ["start-requested", "start-body-skipped-missing-block"], "missing block: start requested, body not reached")
	var wz5 := {"blocks": {}, "trace": []}
	KL.select_water(table, 65, wz5, {"after_query": func(w: Dictionary) -> void: w.blocks[2] = {"active": true}})
	check("M113-X1", wz5.trace == ["start-requested", "start-body-already-active"], "query snapshot and wrapper lookup are separate observations")
	check("M113-X1", not KL.m42_stop_all_touches(2) and KL.m42_stop_all_touches(1), "M42 stopAll excludes enum2")

## ---------------------------------------------------------------- M114
func outline_env(extra: Dictionary = {}) -> Dictionary:
	var env := {"selection30": {"type24": 0, "i18": 0, "i1C": 0, "i20": 0, "name10": ""}, "ref_rows": sorted_by(real.m115_outline.ui_outline_ref, "ID"),
		"color_rows": by_id(real.m115_outline.color_11441), "npc_predicate": func(_a: Dictionary) -> bool: return false}
	env.merge(extra, true)
	return env

static func mk_actor(type24: int, b8: int, fields: Dictionary = {}) -> Dictionary:
	var a := {"identity": {"type24": type24, "i18": 1, "i1C": 2, "i20": 3, "name10": "x"}, "b8": b8, "attr134": 0, "effect_map": {5: 55}, "framecell": {"attr": 0}}
	a.merge(fields, true)
	return a

func t_m115() -> void:
	check("M115-X1", OL.PAIRS.size() == 18 and (real.m115_outline.decision_table as Array).size() == 18, "18 pairs")
	for i: int in 18:
		var dt: Dictionary = real.m115_outline.decision_table[i]
		check("M115-X1", int(OL.PAIRS[i].priority) == int(dt.priority) and OL.PAIRS[i].ref == dt.resolver_ref_key, "pair %d matches DECISION_TABLE" % (i + 1))
	# first predicate true (identity) beats 2 and 3 which are also true
	var sel := {"type24": 6, "i18": 1, "i1C": 2, "i20": 3, "name10": "x"}
	var a1: Dictionary = mk_actor(6, 0)
	var r1: Dictionary = OL.refresh(a1, outline_env({"selection30": sel}))
	check("M115-T01", r1.selected_priority == 1 and r1.outline_id == 8 and r1.predicate_calls == [1], "priority1 wins although 2/3 are true")
	var a2: Dictionary = mk_actor(6, 0)
	var r2: Dictionary = OL.refresh(a2, outline_env())
	check("M115-T01", r2.selected_priority == 2 and r2.outline_id == 121, "Ref111 resolves to UIOutline121 (not 111)")
	var a3: Dictionary = mk_actor(6, 0)
	var r3: Dictionary = OL.refresh(a3, outline_env({"ref_rows": null}))
	check("M115-T01", r3.selected_priority == 2 and r3.outline_id == 0 and a3.effect_map[4] == 0 and int(a3.attr134) & 0x8000 != 0, "resolver0 is applied; no fallthrough to priority3")
	var a4: Dictionary = mk_actor(9, -1)
	a4.effect_map[4] = 18
	a4["attr134"] = 0x8000
	var r4: Dictionary = OL.refresh(a4, outline_env())
	check("M115-T01", r4.selected_priority == null and not a4.effect_map.has(4) and a4.effect_map[5] == 55 and int(a4.attr134) & 0x8000 == 0 and r4.predicate_calls.size() == 18, "all false -> remove key4/bit only, key5 kept")
	var a5: Dictionary = mk_actor(3, -1)
	var r5: Dictionary = OL.refresh(a5, outline_env())
	check("M115-X1", r5.predicate_calls.has(9) and r5.predicate_calls.has(10), "priority 9 and 10 are both invoked (no dedup)")
	var elf := {"ptr18": {"i78": 0}, "byte10": 0, "byteE4": 1}
	var a6: Dictionary = mk_actor(2, 0, {"character": elf})
	var r6: Dictionary = OL.refresh(a6, outline_env())
	check("M115-X1", r6.selected_priority == 13, "real Color11441.ColorTableID=0 -> priority11 false, falls to 13 (b8==0)")
	var r6b: Dictionary = OL.refresh(mk_actor(2, 0, {"character": elf}), outline_env({"color_rows": {11441: {"ColorTableID": 5}}}))
	check("M115-X1", r6b.selected_priority == 11 and r6b.outline_id == 88, "synthetic nonzero ColorTableID enables priority11")
	check("M115-X1", OL.refresh(mk_actor(6, -1, {"byte7e": 1, "character": {"ptr18": null, "byte10": 0}}), outline_env()).selected_priority == null, "blocked character (ptr18 null) blocks byte7E predicate")
	check("M115-X1", OL.identity_equal({"type24": 0, "i18": 0, "i1C": 0, "i20": 0, "name10": ""}, {"type24": 0, "i18": 5, "i1C": 0, "i20": 0, "name10": "q"}), "right type0 -> left type0 suffices")
	var assoc := {"framecell": null, "attr134": 0, "effect_map": {}}
	OL.apply_outline({"framecell": null, "attr134": 0, "effect_map": {}, "associated": assoc}, 28)
	check("M115-X1", assoc.effect_map[4] == 28 and int(assoc.attr134) == 0x8000, "apply recurses into the associated actor")
	# colour manager from real rows
	var ct: Dictionary = by_id(real.m115_outline.color_table_used)
	var mgr: Dictionary = OL.build_manager(real.m115_outline.ui_outline, ct)
	check("M115-X1", mgr.color[8] == [63488, 63650, 63813, 63975, 64170, 63975, 63813, 63650], "UIOutline8 FF6C6C/FF0000 includeMin=false RGB565 samples")
	check("M115-X1", mgr.color[171] == [65535, 53119, 40671, 26207, 13759, 1311, 13759, 26175, 40671, 53087], "UIOutline171 '#FFFFFF'/00a2ff includeMin=true 10 samples")
	check("M115-X1", mgr.color[28] == [59387, 48983, 38579, 28175, 17771, 28175, 38579, 48983], "UIOutline28 209a37/e3ffdf")
	check("M115-X1", OL.parse_color("#B1F7AF") == [0xB1, 0xF7, 0xAF] and OL.parse_color("80112233") == [0x11, 0x22, 0x33] and OL.parse_color("12345") == [0, 0, 0], "'#' strip, ARGB order, malformed -> 0")
	check("M115-X1", OL.color_from_table(ct, 999999) == [0, 0, 0], "missing ColorTable row -> 0 (no Color alias hop)")
	# period
	check("M115-T02", OL.period(mgr, 8) == 100 and OL.period(mgr, 171) == 40, "Period0 -> not inserted -> 100; Period40 kept")
	var prows: Array = [{"ID": 901, "MinColorTableID": 38, "MaxColorTableID": 37, "Period": 65535, "MinAlpha": -1, "MaxAlpha": -1, "IsIncludeMinColor": false},
		{"ID": 902, "MinColorTableID": 38, "MaxColorTableID": 37, "Period": 65536, "MinAlpha": -1, "MaxAlpha": -1, "IsIncludeMinColor": false},
		{"ID": 903, "MinColorTableID": 38, "MaxColorTableID": 37, "Period": 65537, "MinAlpha": -1, "MaxAlpha": -1, "IsIncludeMinColor": false},
		{"ID": 904, "MinColorTableID": 38, "MaxColorTableID": 37, "Period": 2147483647, "MinAlpha": 0, "MaxAlpha": 150, "IsIncludeMinColor": false},
		{"ID": 905, "MinColorTableID": 38, "MaxColorTableID": 37, "Period": -5, "MinAlpha": 30, "MaxAlpha": 70, "IsIncludeMinColor": false},
		{"ID": 906, "MinColorTableID": 38, "MaxColorTableID": 37, "Period": 10, "MinAlpha": -1, "MaxAlpha": 70, "IsIncludeMinColor": false}]
	var pm: Dictionary = OL.build_manager(prows, ct)
	check("M115-T02", OL.period(pm, 901) == 65535 and OL.period(pm, 902) == 0 and OL.period(pm, 903) == 1 and OL.period(pm, 904) == 65535 and OL.period(pm, 905) == 100, "low16: 65535, 65536->0, 65537->1, INT_MAX->65535, negative->default 100")
	check("M115-T02", OL.color_at(pm, 902, 1000).get("outcome") == C.UNGUARDED_BOUNDARY, "period 0 with a nonempty vector stays an IDIV-0 boundary")
	check("M115-T02", OL.color_at(pm, 901, 65535 * 3).index == 3 and OL.color_at(mgr, 8, 799).index == 7 and OL.color_at(mgr, 8, 800).index == 0, "index = (clock / period) % count")
	# alpha
	check("M115-T03", OL.alpha_at(mgr, 8, 0).value == 100 and not mgr.alpha.has(8), "MinAlpha -1 -> no alpha vector -> 100")
	check("M115-T03", mgr.alpha[171] == [100, 100, 100, 100, 100, 100, 100, 100, 100, 100], "real 100/100")
	check("M115-T03", pm.alpha[904] == [100, 80, 60, 40, 20, 0, 20, 40, 60, 80] and pm.alpha[905] == [70, 62, 54, 46, 38, 30, 38, 46, 54, 62] and not pm.alpha.has(906), "clamp 0..100; any negative skips the helper")
	var dupm: Dictionary = OL.build_manager([{"ID": 8, "MinColorTableID": 22161, "MaxColorTableID": 22151, "Period": 7, "MinAlpha": -1, "MaxAlpha": -1, "IsIncludeMinColor": false}], ct, mgr)
	check("M115-X1", dupm.color[8][0] == 63488 and dupm.period.get(8) == 7, "duplicate id keeps first colour entry; maps not cleared first")

## ---------------------------------------------------------------- M116
func albino_root() -> Dictionary:
	return C.make_node("Node", "Node", [C.make_node("Nd_AlbinoBoss", "Node", [C.make_node("Sp_Boss", "Sprite"), C.make_node("Label", "Text")])])

static func albino_event(asset: Variant, desc: Variant) -> Dictionary:
	return {"kind": "SingleValueEvent<DynamicMap<string>>", "map": {"assetid": asset, "descid": desc}}

func t_m118() -> void:
	var aliases: Dictionary = real.m118_albino.aliases
	var env := {"assets": {1: "a1.png", 2: "a2.png", 3: "a3.png"}, "descs": {11: "d11", 22: "d22", 33: "d33"}}
	var layout: Dictionary = SC.make_albino_layout(albino_root(), aliases, {"ranges": {"Fx_On": real.m118_albino.authored.Fx_On}})
	layout.root.visible = false
	var cap := {"layout": layout}
	check("M118-T01", SC.albino_receive(cap, albino_event(1, 11), env) == "presented" and layout.root.visible and layout.trace.has(["play", "Fx_On", false]), "hidden: show, play Fx_On (authored 5..210), present")
	check("M118-T01", SC.albino_receive(cap, albino_event(2, 22), env) == "queued" and SC.albino_receive(cap, albino_event(3, 33), env) == "queued" and int(layout.queue.count) == 2, "visible: A and B appended")
	SC.albino_last_frame(layout, env)
	check("M118-T01", layout.published.size() == 1 and layout.published[0].map == {"assetid": 3, "descid": 33} and int(layout.queue.count) == 1, "last frame hides then pops the NEWEST (B) and republishes 423")
	check("M118-T01", not layout.root.visible and layout.published[0].event == 423, "hide before drain")
	SC.albino_last_frame(layout, env)
	check("M118-T01", layout.published[1].map == {"assetid": 2, "descid": 22} and int(layout.queue.count) == 0 and int(layout.queue.head) == 0, "then A; head reset at empty; one publication per callback")
	SC.albino_last_frame(layout, env)
	check("M118-T01", layout.published.size() == 2, "empty queue: no publication")
	# LIFO across growth (capacity 8 -> 16)
	var lg: Dictionary = SC.make_albino_layout(albino_root(), aliases, null)
	for i: int in 9:
		SC.albino_append(lg, albino_event(100 + i, -i))
	check("M118-X1", int(lg.queue.capacity) == 16 and int(lg.queue.count) == 9, "growth keeps all pairs")
	SC.albino_drain(lg)
	check("M118-X1", lg.published[0].map == {"assetid": 108, "descid": -8}, "LIFO after growth; signed DWORD kept")
	var lt: Dictionary = SC.make_albino_layout(albino_root(), aliases, null)
	lt.root.visible = false
	check("M118-X1", SC.albino_receive({"layout": lt}, albino_event("x", 5.5), env) == "presented" and C.dot_path(lt.root, "Nd_AlbinoBoss.Sp_Boss").texture == "", "typed failure -> 0 (asset 0 path empty)")
	check("M118-X1", SC.albino_receive({"layout": lt}, {"kind": "Other"}, env) == "invalid", "non-SingleValueEvent is invalid")
	# null timeline: no show/play, but a valid root is still changed
	var ln: Dictionary = SC.make_albino_layout(albino_root(), aliases, null)
	ln.root.visible = false
	check("M118-T02", SC.albino_receive({"layout": ln}, albino_event(1, 11), env) == "presented" and not ln.root.visible and ln.trace.is_empty() and C.dot_path(ln.root, "Nd_AlbinoBoss.Label").text == "d11", "null timeline still writes sprite/text")
	var lr: Dictionary = SC.make_albino_layout(null, aliases, null)
	check("M118-T02", SC.albino_receive({"layout": lr}, albino_event(1, 11), env) == "sprite-missing-text-skipped", "stable null root skips both children")
	var ls_root: Dictionary = albino_root()
	ls_root.visible = false
	(ls_root.children[0].children as Array).remove_at(0)
	var ls: Dictionary = SC.make_albino_layout(ls_root, aliases, {"ranges": {}})
	check("M118-T02", SC.albino_receive({"layout": ls}, albino_event(1, 11), env) == "sprite-missing-text-skipped" and C.dot_path(ls_root, "Nd_AlbinoBoss.Label").text == null and ls_root.visible, "sprite failure skips text after the animation requests")
	var lnull: Dictionary = SC.make_albino_layout(albino_root(), aliases, {"ranges": {}})
	lnull.root.visible = false
	var out: String = SC.albino_receive({"layout": lnull}, albino_event(1, 11), env.merged({"hooks": {"after_visibility": func(l: Dictionary, _v: bool) -> void: l["timeline58"] = null}}))
	check("M118-T02", out == C.UNGUARDED_BOUNDARY, "timeline cleared during show: reread has no null check (boundary)")

## ---------------------------------------------------------------- M119
func escaros_root() -> Dictionary:
	var spell_child: Dictionary = C.make_node("Nd_Set_R_Top_ActionSpell", "ProjectNode", [C.make_node("Nd_ActionSpell", "Node", [
		C.make_node("Nd_SkillName", "Node", [C.make_node("Text_1", "Text")]), C.make_node("Nd_SkillInfo", "Node", [C.make_node("Sp_SkillIcon", "Sprite")])])])
	spell_child["action"] = {}
	return C.make_node("Node", "Node", [C.make_node("Nd_Text_1", "Node", [C.make_node("Text_1", "Text")]), C.make_node("Nd_Text_2", "Node", [C.make_node("Text_2", "Text")]),
		C.make_node("Fx_Dummy", "Node", [C.make_node("Fx_Panel_Img", "Node", [C.make_node("Img", "Sprite")])]), spell_child])

func escaros_env() -> Dictionary:
	var e: Dictionary = real.m119_escaros
	var npc_attr: Dictionary = {}
	for a: Dictionary in e.npc_attribute:
		npc_attr[int(a.NpcClassID)] = int(a.Value)
	var chain: Dictionary = e.spell_chain
	return {"screen_effects": by_id(e.screen_effect), "npc": by_id(e.npc_class), "npc_attr": npc_attr, "titles": by_id(e.appellation_title),
		"spells": {"SpellClass": {int(chain.SpellClass.ID): chain.SpellClass}, "bonuses_by_spell": {int(chain.SpellBonus.SpellClassID): [chain.Bonus]},
			"SpellMark": {int(chain.SpellMark.ID): chain.SpellMark}, "SpellMarkType": {}},
		"descs": {1099754: "npc-name", 5000: "desc-5000", 1100834: "spell-name"}, "assets": {256874: "illust.png"}}

static func esc_event(id: Variant, npc: Variant, spell: Variant, desc: Variant) -> Dictionary:
	var m := {}
	for pair: Array in [["id", id], ["npcclassid", npc], ["spellclassid", spell], ["descid", desc]]:
		if pair[1] != null:
			m[pair[0]] = pair[1]
	return {"kind": "SingleValueEvent<DynamicMap<string>>", "map": m}

func t_m119() -> void:
	var aliases: Dictionary = real.m119_escaros.aliases
	var env: Dictionary = escaros_env()
	var owner: Dictionary = SC.make_escaros_owner(escaros_root(), aliases, {"ranges": real.m119_escaros.authored.main})
	owner.root.visible = false
	var cap := {"owner": owner}
	check("M119-X1", int(owner.priority) == 99, "+F8 initial 99")
	var r1: Dictionary = SC.escaros_receive(cap, esc_event(544, 71774, null, 5000), env)
	check("M119-T01", r1.stage == "committed" and r1.shown and int(owner.priority) == 1 and owner.root.visible, "invisible: no compare; 544 (Priority1) committed and shown")
	check("M119-T01", SC.escaros_receive(cap, esc_event(554, 71774, null, 5000), env).stage == "priority-rejected", "visible + equal priority -> rejected")
	var big: Dictionary = env.duplicate()
	big["screen_effects"] = (env.screen_effects as Dictionary).merged({9001: {"ID": 9001, "Priority": 5}})
	check("M119-T01", SC.escaros_receive(cap, esc_event(9001, 71774, null, 5000), big).stage == "priority-rejected", "visible + larger priority -> rejected")
	var trace_before: int = owner.trace.size()
	var r3: Dictionary = SC.escaros_receive(cap, esc_event(534, 71774, null, 5000), env)
	check("M119-T01", r3.stage == "committed" and int(owner.priority) == 0 and r3.shown == false and owner.trace.slice(trace_before) == ["completion-replaced"], "visible + smaller priority -> replaced, main show NOT restarted")
	SC.escaros_last_frame(owner)
	check("M119-T02", not owner.root.visible and int(owner.priority) == 0 and C.dot_path(owner.root, "Nd_Text_1.Text_1").text == "npc-name", "spell 0: completion hides (priority/text kept)")
	check("M119-T02", C.dot_path(owner.root, "Nd_Set_R_Top_ActionSpell").visible == false, "spell child hidden for spell 0")
	# spell present (real chain 62024 -> Bonus6544 Value4 -> SpellMark4 Delay10 -> 10000 ms; SpellMarkType 0 absent)
	var o2: Dictionary = SC.make_escaros_owner(escaros_root(), aliases, {"ranges": {}})
	o2.root.visible = false
	var r4: Dictionary = SC.escaros_receive({"owner": o2}, esc_event(544, 71774, 62024, 5000), env)
	var icon: Dictionary = C.dot_path(o2.root, "Nd_Set_R_Top_ActionSpell.Nd_ActionSpell.Nd_SkillInfo.Sp_SkillIcon")
	check("M119-T02", r4.spell_stage == "spell-timer-10000" and icon.texture == null and C.dot_path(o2.root, "Nd_Set_R_Top_ActionSpell.Nd_ActionSpell.Nd_SkillName.Text_1").text == "spell-name", "real spell chain: timer 10000ms, missing SpellMarkType -> no texture")
	SC.escaros_last_frame(o2)
	check("M119-T02", o2.root.visible, "spell != 0: main completion does nothing")
	var tm: Dictionary = o2.spell_pair100
	check("M119-T02", not SC.remains_timer_update(tm, 9999) and SC.remains_timer_update(tm, 1), "RemainsTimer expiry at lifetime <= 0 (timer input, not wall-clock)")
	var o2b_old: Dictionary = o2.spell_pair100
	SC.escaros_optional_spell(o2, 62024, env)
	check("M119-T02", o2b_old.get("released") == true and not is_same(o2.spell_pair100, o2b_old), "new timer stored, old released after")
	# middle child failure: desc Text missing
	var root3: Dictionary = escaros_root()
	(root3.children as Array).remove_at(1)
	root3.visible = false
	var o3: Dictionary = SC.make_escaros_owner(root3, aliases, {"ranges": {}})
	var r5: Dictionary = SC.escaros_receive({"owner": o3}, esc_event(534, 71774, null, 5000), env)
	check("M119-T03", r5.stage == "desc-text-missing" and int(o3.priority) == 99 and o3.controller.completion != null and C.dot_path(root3, "Nd_Text_1.Text_1").text == "npc-name", "completion replaced + name written; priority not committed")
	var o4: Dictionary = SC.make_escaros_owner(escaros_root(), aliases, {"ranges": {}})
	o4.root.visible = false
	var no_title: Dictionary = env.duplicate()
	no_title["titles"] = {}
	var r6: Dictionary = SC.escaros_receive({"owner": o4}, esc_event(534, 71774, null, 5000), no_title)
	check("M119-X1", r6.stage == "title-missing" and C.dot_path(o4.root, "Nd_Text_2.Text_2").text == "desc-5000" and int(o4.priority) == 99, "attribute 564 present + title missing -> return after desc write")
	check("M119-X1", SC.escaros_receive({"owner": o4}, esc_event(534, 1, null, 5000), env).stage == "committed", "no attribute row -> proceeds to icon (NpcClass 1)")
	check("M119-X1", SC.escaros_receive({"owner": o4}, esc_event(null, null, null, null), env).stage == "preflight-all-null", "all four pointers null -> preflight return")

## ---------------------------------------------------------------- M120
func t_m121() -> void:
	var w: Dictionary = real.m121_warzone
	var action := {"duration": int(w.action.duration), "speed": float(w.action.speed), "ranges": w.ranges}
	var block := {"active": false, "path": w.csb_logical_path, "parent": {"children": []}}
	var hooks := {"create_node": func(_p: String) -> Variant: return {"name": "Node"}, "create_timeline": func(_p: String) -> Variant: return action,
		"find_particle": func(_n: Dictionary) -> Variant: return {"name": "Particle_1"}}
	var r: Dictionary = ZW.start_weather(block, false, hooks)
	var named: Variant = ZW.named_play_request(action, "Fx_Start", true)
	check("M121-T01", r.request == {"start": 0, "end": 500, "loop": true} and named == {"start": 5, "end": 500, "loop": true} and r.request != named, "native start 0..500 loop=true differs from named Fx_Start 5..500")
	check("M121-T01", r.prewarm_steps == 100 and block.active and action.frame_event_callback_installed and float(action.speed) == 0.5, "prewarm 100x0.2, frame-event callback installed, authored speed 0.5 kept")
	check("M121-T01", ZW.start_weather(block, false, hooks).stage == "already-active", "already active returns")
	var b2 := {"active": false, "path": "x", "parent": {"children": []}}
	var r2: Dictionary = ZW.start_weather(b2, true, {"create_node": hooks.create_node, "create_timeline": func(_p: String) -> Variant: return null})
	check("M121-T01", r2.request == null and b2.active and b2.parent.children.size() == 1, "null action does not undo node creation; still active")
	check("M121-T01", ZW.start_weather({"active": false, "path": "x", "parent": {"children": []}}, true, {"create_node": func(_p: String) -> Variant: return null, "create_timeline": hooks.create_timeline}).stage == "node-null", "node null -> return")
	check("M121-T01", (w.ranges as Dictionary).has("animation0") and (w.ranges.animation0 as Array).map(func(x: Variant) -> int: return int(x)) == [1500, 2000], "authored animation0 1500..2000 preserved (not judged unused)")
	var frame := {"index": int(w.frame_event.frame), "text": w.frame_event.text, "tag": int(w.frame_event.tag)}
	var sound := {"UI_WARZONE_IN": w.sound_join.SoundMaterialID}
	var e1: Dictionary = ZW.event_frame_on_enter(frame, action, 7, sound)
	check("M121-T02", e1.emitted and e1.sound_name == "UI_WARZONE_IN" and e1.sound_lookup == 84903 and e1.playback_observed == false, "frame7 EventSound name lookup only")
	check("M121-T02", not ZW.event_frame_on_enter(frame, action, 6, sound).emitted and not ZW.event_frame_on_enter(frame, null, 9, sound).emitted, "current frame < 7 or no action -> not emitted")
	var narrow := {"start": 8, "end": 500}
	check("M121-T02", not ZW.event_frame_on_enter(frame, narrow, 9, sound).emitted, "frame 7 outside start 8..end 500 is not emitted")
	for pname: String in w.plists:
		var p: Dictionary = w.plists[pname]
		var raw: PackedByteArray = Marshalls.base64_to_raw(p.base64)
		var ins: Dictionary = ZW.inspect_plist(raw)
		check("M121-T03", raw.size() == int(p.size) and ins.strict == "REJECTED" and ins.first_document_end == int(p.xml_end_offset) and ins.tail_hex == str(p.trailing_hex), "%s strict reject; first document end %d" % [pname, int(p.xml_end_offset)])
		check("M121-T03", ins.textureFileName == p.textureFileName and ins.native_acceptance == C.EVIDENCE_UNKNOWN and ins.original_size == raw.size(), "%s texture from first document only; bytes not trimmed" % pname)
	var clean: Dictionary = ZW.inspect_plist("<plist><dict></dict></plist>\r\n".to_utf8_buffer())
	check("M121-T03", clean.strict == "ACCEPTED", "well-formed synthetic plist accepted")
	check("M121-X1", (w.direct_references as Array).size() == 8 and (w.particle_textures as Array).size() == 2, "8 direct references + 2 particle textures")

## ---------------------------------------------------------------- M122
func spine_env(files: Array, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = real.m122_spine
	var stem: String = SP.stem_of(str(m.asset_view[0].FilePath))
	var f: Dictionary = {}
	for x: String in files:
		f[x.replace("{stem}", stem)] = true
	var env := {"asset_rows": sorted_by(m.asset_view, "AssetId"), "files": f, "spine_data": {"Spine/%s.json" % stem: {"animations": m.animations, "version": m.spine_version}}, "trace": []}
	env.merge(extra, true)
	return env

func spine_layout(alias: Variant) -> Dictionary:
	var aliases: Dictionary = {} if alias == null else {"SCREEN_EFFECT_SPINE_TARGET_NODE": alias}
	var root: Dictionary = C.make_node("Node", "Node", [C.make_node("Nd_Spine", "SingleNode"), C.make_node("Sp_GlowBox", "Sprite")])
	return {"root50": C.make_node("Layout", "Node", [root]), "aliases": aliases, "trace": []}

func t_m122() -> void:
	var m: Dictionary = real.m122_spine
	var row: Dictionary = m.screen_effect
	var uispine: Dictionary = {int(m.ui_spine.ID): m.ui_spine}
	check("M122-X1", SP.stem_of("Cut_Scene_Spine/Spine_Cut_Scene_Valakas_Raid.json") == "Cut_Scene_Spine/Spine_Cut_Scene_Valakas_Raid" and SP.stem_of("a.b/c") == "a" and SP.stem_of("noext") == "noext", "stem: last dot, not stopped by '/'")
	var layout: Dictionary = spine_layout(m.target_alias.SCREEN_EFFECT_SPINE_TARGET_NODE)
	var env: Dictionary = spine_env(["Spine/{stem}.json", "Spine/{stem}.atlas"])
	var r: Dictionary = SP.screen_effect_spine(layout, row, uispine, env)
	check("M122-T01", row.isLoop == false and r.attached and r.node.tracks[0] == {"animation": "animation", "loop": true} and r.node.scale == 1.0, "real 832: isLoop=false but autoFirst -> track0 'animation' loop=true")
	check("M122-T01", r.node.attached_to == "Nd_Spine" and layout.trace == ["csb-group-timeline", "shake-audio-continue"] and r.node.complete508 != null and r.node.event548.fn == null, "attached to Node.Nd_Spine; completion installed, empty event fn")
	check("M122-T01", SP.set_animation(r.node, 1, "PlayOn", false) == null, "CSB PlayOn is not a Spine animation name")
	var offset_row: Dictionary = {1382: {"ID": 1382, "AssetID": 302112, "OffsetX": 7, "OffsetY": -3, "Flip": true}}
	var ro: Dictionary = SP.screen_effect_spine(spine_layout("Node.Nd_Spine"), row, offset_row, spine_env(["Spine/{stem}.json", "Spine/{stem}.atlas"]))
	check("M122-X1", not ro.node.has("offset") and not ro.node.has("flip") and ro.attached, "OffsetX/OffsetY/Flip not applied by the selected caller")
	# empty / missing target: no parent fallback
	var le: Dictionary = spine_layout(null)
	var re: Dictionary = SP.screen_effect_spine(le, row, uispine, spine_env(["Spine/{stem}.json", "Spine/{stem}.atlas"]))
	check("M122-T02", re.node != null and not re.attached and (le.root50.children as Array).size() == 1 and (le.root50.children[0].children as Array).size() == 2, "empty alias: no attachment, no parent fallback")
	var lm: Dictionary = spine_layout("Node.Nd_Missing")
	var rm: Dictionary = SP.screen_effect_spine(lm, row, uispine, spine_env(["Spine/{stem}.json", "Spine/{stem}.atlas"]))
	check("M122-T02", not rm.attached and lm.trace.back() == "shake-audio-continue", "unresolved target: no attachment; later shake/audio continue")
	# missing atlas
	var la: Dictionary = spine_layout("Node.Nd_Spine")
	var ea: Dictionary = spine_env(["Spine/{stem}.json"])
	var ra: Dictionary = SP.screen_effect_spine(la, row, uispine, ea)
	check("M122-T03", ra.node == null and ea.trace.has("atlas-missing-null") and la.trace.has("csb-group-timeline"), "missing atlas -> null; earlier CSB/group work stays")
	var ej: Dictionary = spine_env([])
	check("M122-T03", SP.load_by_asset(302112, true, null, null, ej) == null and ej.trace.has("json-missing-null"), "json checked first")
	var en: Dictionary = spine_env(["Spine/{stem}.json", "Spine/{stem}.atlas"], {"asset_rows": null})
	check("M122-T03", SP.load_by_asset(302112, true, null, null, en) == null and en.trace == ["destroy-incoming-callables"], "missing table: callables destroyed, null")
	var ep: Dictionary = spine_env(["Spine/{stem}.json", "Spine/{stem}.atlas"], {"spine_data": {}})
	check("M122-T03", SP.load_by_asset(302112, true, null, null, ep).get("outcome") == C.UNGUARDED_BOUNDARY, "files present but parsed data null -> unguarded boundary, not a safe null")
	# completion callback exception
	var node: Dictionary = r.node
	var res: Dictionary = SP.dispatch_queue(node, [{"type": 3}, {"type": 5}], func(t: int, _e: Dictionary) -> Dictionary: return {"throw": t == 3})
	check("M122-T04", res.aborted and res.delivered == [3] and res.flag_left_set and node.queue_reentrancy_flag, "completion throw: no catch, later events not delivered, reentrancy flag left set")
	var ok: Dictionary = SP.dispatch_queue(node, [{"type": 3}, {"type": 5}], func(_t: int, _e: Dictionary) -> Dictionary: return {})
	check("M122-T04", not ok.aborted and ok.delivered == [3, 5] and not node.queue_reentrancy_flag, "normal tail clears the flag")
	var entry := {"t34": 0.5, "t3C": 0.5, "t38": 0.0, "f48": 3, "f24": 0}
	var seen: Array = []
	var hv: Dictionary = SP.handle_event(entry, {"name": "Loop", "time": 1.25}, func(e: Dictionary) -> void: seen.append(e.t34))
	check("M122-X1", hv.event_fn_invoked and seen == [1.25] and entry.f24 == 1 and entry.f48 == 0, "Loop writes the entry BEFORE invoking eventFn")
	check("M122-X1", SP.handle_event(entry, {"name": "{\"EventSound\":\"S1\"}", "time": 0.0}, null).sound_name == "S1", "EventSound JSON name -> named audio boundary")

## ---------------------------------------------------------------- M123
func sel_env(overrides: Dictionary = {}) -> Dictionary:
	var a := {"id": "a", "type24": 6, "control": C.make_control(1, 1)}
	var env := {"player": {"motion": 4, "coord148": [1, 1], "coord150": [1, 1], "facing125": 0}, "world20": 0,
		"global": {"byte132": 0, "byte133": 0, "hasbits10": 0}, "receiver": {"deadline": 0}, "now": 0,
		"manager": {"list": [a], "gate": true, "current": null}, "auto_owner": {"byte18": false},
		"actors": {"a": {"luid": a, "object_data": {"v20": true}}},
		"selector": func(_ex: Array, _flag: bool, _t: int) -> Dictionary: return {"list": [a]}, "trace": [], "requests": [], "hooks": {}}
	env.merge(overrides, true)
	return env

func t_m123() -> void:
	# T01 AutoPlay x count
	var e1: Dictionary = sel_env({"auto_owner": {"byte18": true}, "global": {"byte132": 1}})
	e1.manager.list = []
	check("M123-T01", SS.on_local_c6(e1) == "none" and e1.trace.is_empty(), "AutoPlay + count0: nothing")
	var e2: Dictionary = sel_env({"auto_owner": {"byte18": false}, "global": {"byte132": 1}})
	e2.manager.list = []
	check("M123-T01", SS.on_local_c6(e2) == "search" and e2.trace.has("select:61"), "manual + count0: 0x3D search with an empty exclusion")
	var e3: Dictionary = sel_env({"auto_owner": {"byte18": true}, "global": {"byte132": 1}})
	check("M123-T01", SS.on_local_c6(e3) == "search" and e3.trace.has("select:3") and e3.trace.has("choose-call"), "AutoPlay + count1 resolved: selector 3, clear/apply/targetable/choose")
	var e4: Dictionary = sel_env({"global": {"byte132": 1}})
	e4.manager.list.append({"id": "b", "type24": 6, "control": null})
	check("M123-T01", SS.on_local_c6(e4) == "rotate" and e4.manager.list.map(func(x: Dictionary) -> String: return x.id) == ["b", "a"], "count 2: rotation instead of search")
	# T02 empty/nonempty list
	var e5: Dictionary = sel_env({"global": {"byte132": 1}, "actors": {}})
	check("M123-T02", SS.on_local_c6(e5) == "rotate", "count1 but front actor unresolved -> empty exclusion -> rotate attempt")
	var e6: Dictionary = sel_env({"auto_owner": {"byte18": true}, "global": {"byte132": 1}, "selector": func(_ex: Array, _f: bool, _t: int) -> Dictionary: return {"list": []}})
	SS.on_local_c6(e6)
	check("M123-T02", e6.trace == ["input-create", "select:3", "descriptor-destroy", "rotate-call", "input-destroy"], "empty candidate descriptor destroyed before rotate")
	# T03 deadline equality / wrap
	var e7: Dictionary = sel_env({"now": 10, "receiver": {"deadline": 10}})
	check("M123-T03", SS.on_local_c6(e7) == "direction-requested" and int(e7.receiver.deadline) == 310 and e7.requests[0] == {"packet": 0x77, "direction": 1}, "deadline == now proceeds; now+300 stored; facing 0 -> 1")
	var e8: Dictionary = sel_env({"now": 0, "receiver": {"deadline": -1}})
	check("M123-T03", SS.on_local_c6(e8) == "throttled" and int(e8.receiver.deadline) == -1, "unsigned deadline 2^64-1 > now 0 -> throttled")
	var e9: Dictionary = sel_env({"now": -1, "receiver": {"deadline": 0}})
	check("M123-T03", SS.on_local_c6(e9) == "direction-requested" and int(e9.receiver.deadline) == 299, "now 2^64-1 -> low64(now+300) = 299")
	# T04 rotation allocation failure
	var e10: Dictionary = sel_env({"global": {"byte132": 1}, "hooks": {"append_fails": true}})
	e10.manager.list.append({"id": "b", "type24": 6, "control": null})
	e10.manager["current"] = {"id": "a", "nonempty": true}
	SS.on_local_c6(e10)
	check("M123-T04", e10.rotate_calls == ["deselect", "allocation-failure"] and e10.manager.list.size() == 1 and e10.manager.current == null, "allocation failure after deselect/removal leaves the partial state (no transaction)")
	var e11: Dictionary = sel_env({"global": {"byte132": 1}})
	e11.manager.list.append({"id": "b", "type24": 6, "control": null})
	e11.manager["gate"] = false
	SS.on_local_c6(e11)
	check("M123-T04", e11.manager.list.map(func(x: Dictionary) -> String: return x.id) == ["a", "b"] and e11.rotate_calls.is_empty(), "rotation gate blocked: no change (not a reset)")
	# T05 writer callback kind change and row/widget mutation
	var page := {"byte171": false, "byte170": false, "slots": {0xA0: 3, 0x130: -1}, "widgets": {0x88: "old-widget", 0x118: "w118"}}
	var capw := {"page": page, "kind": 0}
	var genv := {"global": {"byte132": 1, "byte133": 1, "hasbits10": 0, "saves": 0}, "hooks": {"row_update": func(c: Dictionary, _r: int) -> void: c["kind"] = 1}}
	var w1: Dictionary = SS.option_writer(capw, 0, genv)
	check("M123-T05", w1.tuple == [0xA0, 3, -1, 0x88, "old-widget", 0x132, 24] and int(genv.global.byte132) == 0 and int(genv.global.hasbits10) == 1 << 24 and int(genv.global.saves) == 1, "kind 0 -> 1 during callback: row/widget from initial kind, stored field from current kind")
	var page2 := {"slots": {0xA0: -1, 0x130: 4}, "widgets": {0x88: "w88", 0x118: "old-widget"}}
	var cap2 := {"page": page2, "kind": 1}
	var genv2 := {"global": {"hasbits10": 0}, "hooks": {"row_update": func(c: Dictionary, _r: int) -> void:
		c.page.slots[0x130] = 6
		c.page.widgets[0x118] = "new-widget"
		c["kind"] = 0}}
	var w2: Dictionary = SS.option_writer(cap2, 1, genv2)
	check("M123-T05", w2.tuple == [0x130, 4, 6, 0x118, "new-widget", 0x133, 25] and int(genv2.global.byte133) == 1, "kind 1 -> 0 with row/widget rewritten: no overwrite back, widget re-read")
	check("M123-T05", SS.option_writer({"page": {"byte171": true, "slots": {}, "widgets": {}}, "kind": 0}, 1, {"global": {}}).get("returned_early") == true, "page+171 blocks the writer")
	check("M123-T05", SS.WRITER_PIECES.map(func(p: Array) -> int: return int(p[1]) - int(p[0])) == [57, 125, 96], "writer = three chained pdata pieces 57/125/96 bytes")

## ---------------------------------------------------------------- M123 MODEL_CASES.json
func u64v(v: Variant) -> Variant:
	if v is String and (v as String).begins_with("u64:"):
		return C.u64_from_hex((v as String).substr(4))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return u64v(x))
	return v

func model_actual(case_name: String) -> Variant:
	var rx := RegEx.new()
	if case_name.begins_with("entry player"):
		var parts: PackedStringArray = case_name.split(" ")
		return SS.entry_allowed({} if parts[2] == "True" else null, int(parts[4]))
	if case_name.begins_with("phase"):
		var p: PackedStringArray = case_name.split(" ")
		return SS.touch_route(int(p[1]), p[3] == "True")
	if case_name in ["walking early stop", "first live coordinate failure", "second live coordinate failure", "third actor motion failure"]:
		var env: Dictionary = sel_env()
		match case_name:
			"walking early stop":
				env.player.motion = 1
			"first live coordinate failure":
				env.player.coord150 = [2, 2]
			"second live coordinate failure":
				var reads := [0]
				var other := {"motion": 4, "coord148": [1, 1], "coord150": [9, 9], "facing125": 3}
				env.hooks["player_read"] = func(e: Dictionary) -> void:
					reads[0] += 1
					if reads[0] == 3:
						e["player"] = other
			"third actor motion failure":
				env.player.motion = 0
		SS.on_local_c6(env)
		return [env.trace, env.receiver.deadline]
	if case_name.begins_with("deadline "):
		var p2: PackedStringArray = case_name.split(" ")
		var env2: Dictionary = sel_env()
		env2.receiver.deadline = dec_u64(p2[1])
		env2.now = dec_u64(p2[3])
		var out: String = SS.on_local_c6(env2)
		return [out == "direction-requested", env2.receiver.deadline]
	if case_name.begins_with("signed facing "):
		return SS.next_direction(int(case_name.split(" ")[2]))
	if case_name == "preparation failure retains throttle":
		var env3: Dictionary = sel_env({"now": 40, "hooks": {"packet_preparation_fails": true}})
		SS.on_local_c6(env3)
		return env3.receiver.deadline
	rx.compile("^auto (True|False) count (\\d+) resolved (True|False)$")
	var mt: RegExMatch = rx.search(case_name)
	if mt != null:
		var env4: Dictionary = sel_env({"auto_owner": {"byte18": mt.get_string(1) == "True"}, "global": {"byte132": 1}})
		env4.manager["size64"] = dec_u64(mt.get_string(2))
		if mt.get_string(3) == "False":
			env4.actors = {}
		return SS.on_local_c6(env4)
	match case_name:
		"auto empty candidate destroys before rotate":
			var e: Dictionary = sel_env({"auto_owner": {"byte18": true}, "global": {"byte132": 1}, "selector": func(_x: Array, _f: bool, _t: int) -> Dictionary: return {"list": []}})
			SS.on_local_c6(e)
			return e.trace
		"auto full operation order", "apply false not inspected", "choose false not inspected":
			var e: Dictionary = sel_env({"auto_owner": {"byte18": true}, "global": {"byte132": 1}})
			SS.on_local_c6(e)
			return e.trace
		"untargetable skips choose":
			var e: Dictionary = sel_env({"auto_owner": {"byte18": true}, "global": {"byte132": 1}})
			e.actors.a.object_data = {"v20": false}
			SS.on_local_c6(e)
			return e.trace.has("choose-call")
		"manual empty candidates still apply":
			var e: Dictionary = sel_env({"global": {"byte132": 1}, "selector": func(_x: Array, _f: bool, _t: int) -> Dictionary: return {"list": []}})
			e.manager.list = []
			SS.on_local_c6(e)
			return e.trace.has("apply-call")
		"low32 count truncation":
			var e: Dictionary = sel_env({"global": {"byte132": 1}})
			e.manager["size64"] = 0x100000000
			SS.on_local_c6(e)
			return e.last_exclusion
		"rotate multi":
			var e: Dictionary = sel_env()
			e.manager.list = [{"id": "a", "type24": 6}, {"id": "b", "type24": 6}, {"id": "c", "type24": 6}]
			e.manager.current = {"id": "a"}
			SS.rotate(e)
			return e.manager.list.map(func(x: Dictionary) -> String: return x.id)
		"rotate gate blocked", "rotate singleton":
			var e: Dictionary = sel_env()
			e.manager.list = [{"id": "a", "type24": 6}, {"id": "b", "type24": 6}] if case_name == "rotate gate blocked" else [{"id": "a", "type24": 6}]
			e.manager.gate = case_name != "rotate gate blocked"
			e.manager.current = {"id": "a"}
			var r: Dictionary = SS.rotate(e)
			return [e.manager.list.map(func(x: Dictionary) -> String: return x.id), r.calls]
		"rotation auto front type 2", "rotation auto front type 7", "rotation auto front type 3":
			var e: Dictionary = sel_env({"auto_owner": {"byte18": true}})
			e.manager.list = [{"id": "x", "type24": 6}, {"id": "y", "type24": int(case_name.right(1))}]
			e.manager.current = {"id": "x"}
			return (SS.rotate(e).calls as Array).has("choose")
		"rotation no previous current":
			var e: Dictionary = sel_env()
			e.manager.list = [{"id": "x", "type24": 6}, {"id": "y", "type24": 3}]
			return (SS.rotate(e).calls as Array).has("choose")
		"all 256 signed-byte arithmetic equivalence":
			var same: int = 0
			for f: int in range(-128, 128):
				var v: int = f + 1
				if SS.next_direction(f) == v - 8 * int(float(v) / 8.0):
					same += 1
			return same
		"singleton shared ownership survives temporary":
			var e: Dictionary = sel_env()
			e.actors.a.luid.control = C.make_control(0, 1)  # base: references held outside this path not counted
			return SS.build_exclusion(e, 1).temp_counts
		"cleanup last shared", "cleanup shared retained":
			var cb: Dictionary = C.make_control(1 if case_name == "cleanup last shared" else 2, 1)
			var events: Array = []
			SS.destroy_list([{"id": "a", "control": cb}], events)
			return [cb.strong, cb.weak, events]
	if case_name.begins_with("writer "):
		return writer_case(case_name)
	return "UNMAPPED"

static func dec_u64(text: String) -> int:
	var v: int = 0
	for ch: String in text:
		v = C.u64_add(mul10_u64(v), ch.to_int())
	return v

static func mul10_u64(v: int) -> int:
	var x2: int = C.u64_add(v, v)
	var x8: int = C.u64_add(C.u64_add(x2, x2), C.u64_add(x2, x2))
	return C.u64_add(x8, x2)

func writer_case(case_name: String) -> Variant:
	var kind: int = 0
	var slot_a0: int = -1
	var slot_130: int = -1
	var hook: Variant = null
	match case_name:
		"writer kind zero to one reread":
			slot_a0 = 3
			hook = func(c: Dictionary, _r: int) -> void: c["kind"] = 1
		"writer kind one to zero reread":
			kind = 1
			slot_130 = 3
			hook = func(c: Dictionary, _r: int) -> void: c["kind"] = 0
		"writer kind unchanged zero":
			slot_a0 = 2
		"writer kind unchanged nonzero":
			kind = 1
			slot_130 = 2
		"writer slot address not sentinel value":
			kind = 1
		"writer zero is valid row index":
			slot_a0 = 0
		"writer callback changes current row record":
			slot_a0 = 4
			hook = func(c: Dictionary, _r: int) -> void:
				c.page.slots[0xA0] = 9
				c["kind"] = 1
		"writer callback changes widget record before reread":
			kind = 1
			slot_130 = 4
			hook = func(c: Dictionary, _r: int) -> void:
				c.page.slots[0x130] = 6
				c.page.widgets[0x118] = "new-widget"
				c["kind"] = 0
	var cap := {"page": {"slots": {0xA0: slot_a0, 0x130: slot_130}, "widgets": {0x88: "old-widget", 0x118: "old-widget"}}, "kind": kind}
	var env := {"global": {"hasbits10": 0}, "hooks": {} if hook == null else {"row_update": hook}}
	return SS.option_writer(cap, 1, env).tuple

func t_m123_model_cases() -> void:
	var mc: Dictionary = real.m123_model_cases
	check("M123-MC", (mc.cases as Array).size() == int(mc.case_count) and int(mc.case_count) == 72, "72 MODEL_CASES")
	var matched: int = 0
	for c: Dictionary in mc.cases:
		var actual: Variant = u64v(model_actual(str(c.name)))
		var expected: Variant = u64v(c.expected)
		var ok: bool = str(actual) == str(expected)
		if ok:
			matched += 1
		check("M123-MC", ok, "%s: actual %s expected %s" % [c.name, str(actual), str(expected)])
	check("M123-MC", matched == 72, "matched %d/72" % matched)
