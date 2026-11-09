extends "res://tests/original_client_test_base.gd"
## M47-M81 acceptance tests (design-level; the original binary is never executed).
## Test ids: PKG-Cxx-Tyy = proposed case of baseline_01_81/IMPLEMENTATION_CHECKLIST.json;
## Mxx-Tyy = case taken from that module's contract/QA sentence.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")
const LOC = preload("res://scripts/original_client/oc_m47_m81_locators.gd")
const M47 = preload("res://scripts/original_client/oc_m47_item_storage.gd")
const M48 = preload("res://scripts/original_client/oc_m48_resource_corpus.gd")
const M50 = preload("res://scripts/original_client/oc_m50_options_persistence.gd")
const MOVE = preload("res://scripts/original_client/oc_m51_m79_manual_move.gd")
const M52 = preload("res://scripts/original_client/oc_m52_label_locale.gd")
const REQ = preload("res://scripts/original_client/oc_m55_m57_requests.gd")
const FX = preload("res://scripts/original_client/oc_m56_m65_actor_effects.gd")
const LIFE = preload("res://scripts/original_client/oc_m59_m60_callback_lifetime.gd")
const UIW = preload("res://scripts/original_client/oc_m66_m75_ui_workflows.gd")
const ALIAS = preload("res://scripts/original_client/oc_m74_ui_alias.gd")
const IMG = preload("res://scripts/original_client/oc_m76_m77_image_surface.gd")
const TF = preload("res://scripts/original_client/oc_m78_textfield.gd")
const MARK = preload("res://scripts/original_client/oc_m80_minimap_marker.gd")
const AUTO = preload("res://scripts/original_client/oc_m81_autoslot.gd")
const FIXTURE_PATH := "res://data/original_client/fixtures/m47_m81_fixture.json"

var fx: Dictionary = {}

func run() -> void:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	fx = parsed if parsed is Dictionary else {}
	check("FIXTURE", not fx.is_empty(), "fixture could not be read")
	var pv: Dictionary = fx.get("package_values", {})
	var sv: Dictionary = fx.get("synthetic_values", {})
	_m47(pv, sv)
	_m48(pv)
	_locators(pv)
	_m50(sv)
	_m51_m79(sv)
	_m52(pv)
	_m55_m57()
	_m56_m65(pv)
	_m59_m60()
	_ui(pv)
	_m74(pv)
	_m76_m77(pv, sv)
	_m78()
	_m80(pv)
	_m81(pv, sv)
	finish("ORIGINAL_CLIENT_M47_M81_RESULT", {"fixture_id": fx.get("fixture_id", ""), "fixture_sha256": FileAccess.get_sha256(FIXTURE_PATH)})

func _m47(pv: Dictionary, sv: Dictionary) -> void:
	var c: Dictionary = M47.classify_tables(int(pv.M47.tables_in_erratum), 7)
	check("M47-T01", c.qwords_per_stride == 7 and c.callable_methods == 61 * 6 and c.col_data_slots == 61, "0x38 stride: 6 callable + next-table COL DATA (got %s)" % str(c))
	check("M47-T01", M47.classify_slot(6) == "NEXT_TABLE_RTTI_COL_DATA" and M47.classify_slot(5) == "CALLABLE" and M47.classify_tables(1, 8).evidence == V.REJECTED, "slot6 is DATA; reading past the stride is rejected")
	var q: Dictionary = M47.quantity_to_f32(str(sv.M47_double_rounding_int64.value).to_int())
	check("M47-T02", q.f32_bits == "5D800001" and q.via_f64_bits_contrast == "5D800000", "direct int64->f32 differs from f64-first (got %s/%s)" % [q.f32_bits, q.via_f64_bits_contrast])
	check("M47-T02", M47.quantity_to_f32(-(1 << 62)).f32_bits == "DE800000" and V.f32_bits(V.i64_to_f32_direct(-9223372036854775807 - 1)) == 0xDF000000, "negative and INT64_MIN")

func _m48(pv: Dictionary) -> void:
	var counts: Dictionary = M48.CURRENT525_COUNTS
	for k: String in ["dat", "canonical_resources", "direct_spr", "sp2", "sp2_complete", "sp2_prefix_only", "sp2_unsupported_non_fe", "ti2", "ti2_eof_pass", "s32"]:
		check("M48-T01", int(counts[k]) == int(pv.M48[k]), "count %s matches the package" % k)
	var cc: Dictionary = M48.counts_consistent(counts)
	check("M48-T01", cc.sp2_parts_match and cc.ti2_parts_match, "SP2/TI2 parts add up")
	var pref: Dictionary = M48.classify_sp2("Sprite/x.sp2", 0xFE, true, false, "ab")
	check("PKG-C08-T01", pref.class == "SP2_PREFIX_ONLY" and pref.frames == null and pref.blocks == null and pref.bytes_preserved and pref.payload_sha256 == "ab", "prefix-only keeps bytes/hash, no frames/blocks")
	var nonfe: Dictionary = M48.classify_sp2(pv.M48.non_fe_path, 0x12, false, false, "cd")
	check("M48-T02", nonfe.class == "SP2_UNSUPPORTED_NON_FE" and M48.known_exception(pv.M48.ti2_exception).short_bytes == int(pv.M48.ti2_short_bytes), "non-FE and TI2 pixel-short stay explicit exceptions")
	check("PKG-C08-T02", M48.p12_manifest_absent(5).missing_file_count == null, "virtual name pairs are not missing files")

func _locators(pv: Dictionary) -> void:
	var rows: Array = []
	for i: int in 2630:
		rows.append("R%d" % i)
	check("M49-T01", LOC.helper_cfg_inventory(rows).complete == false, "2630 rows without 01CBFC5F is incomplete")
	rows.append(pv.M49.must_include)
	check("M49-T01", LOC.helper_cfg_inventory(rows).complete == true, "2631 rows with 01CBFC5F")
	check("M53-T01", LOC.classify_int3("CALL_NO_RETURN") == "CODE_TERMINAL_KEEP_IN_CFG" and LOC.classify_int3("RET") == "PADDING" and LOC.classify_int3("JMP_UNCONDITIONAL") == "PADDING", "INT3 after no-return CALL is code")
	check("M53-T01", LOC.FACTS.R53_int3.leaf_context_int3_bytes == int(pv.M53.leaf_int3_bytes), "47 not 46")
	for a: String in pv.M54.ack_constants:
		check("M54-T01", LOC.classify_rva(a).kind == "DATA_ACK_CONSTANT_16B" and LOC.classify_rva(a).callable == false, "%s is DATA, not a getter" % a)
	check("M62-T01", LOC.classify_rva(pv.M62.lea).kind == "LEA_RDX_RSP_40" and LOC.classify_rva(pv.M62.copy_call).kind == "CALL_QWORD_PTR_RAX_VIRTUAL0_COPY", "copy CALL is 0213579E")
	check("M63-T02", LOC.classify_rva("02547760").callable and not LOC.classify_rva("02547770").callable, "entry vs internal locator")
	var sw: Dictionary = LOC.classify_in_pdata(0x5060D4, 0x5058B0, 0x506120, [[0x5060D4, 0x506120]])
	check("M64-T01", sw.inside_pdata and sw.kind == "DATA" and (0x506120 - 0x5060D4) == int(pv.M64.switch_bytes), "switch DATA in pdata is not code")
	check("M80-T03", LOC.classify_rva(pv.M80.superseded).evidence == V.REJECTED and LOC.classify_rva(pv.M80.arrow_tag_write).evidence == V.CONFIRMED, "E0330B7BB rejected, E0330B7BC used")

func _m50(sv: Dictionary) -> void:
	var fields: Array = sv.M50_fields.fields
	var absent: Dictionary = M50.load_options({}, {"present": false}, {"present": true, "content": "ok", "fields": fields.slice(0, 2)}, false)
	var empty: Dictionary = M50.load_options({}, {"present": true, "content": "empty"}, {"present": true, "content": "ok", "fields": fields.slice(0, 2)}, true)
	check("PKG-C16-T01", absent.fallback_attempted and absent.return_bool == true and absent.options.bgm == 3, "absent primary -> fallback; migration save false keeps load true")
	check("PKG-C16-T01", empty.fallback_attempted == false and empty.options.is_empty(), "empty primary -> no fallback retry")
	var late: Dictionary = M50.load_options({"bgm": 1}, {"present": true, "content": "ok", "fields": fields}, {}, true)
	check("M50-T01", late.conversion_failed and late.rolled_back == false and late.options.bgm == 3 and late.options.sfx == 5 and not late.options.has("late"), "late conversion failure keeps earlier in-place mutation")
	var syn: Dictionary = M50.load_options({"bgm": 1}, {"present": true, "content": "syntax_error", "fields": fields}, {}, true)
	check("M50-T01", syn.options.bgm == 1, "syntax failure applies nothing")
	var s1: Dictionary = M50.save_options(true, true)
	check("M50-T02", s1.return_bool == true and s1.durable_guaranteed == false and s1.trace == ["serialize", "open", "write", "flush", "close"], "post-open stream error still true; not durable")
	check("M50-T02", M50.save_options(false, false).return_bool == false, "open failure false")
	var pa: Dictionary = M50.payload_address(0x1000)
	check("PKG-C04-T02", pa.payload_address == 0x1008 and pa.dereference_row_plus_8 == false, "row+8 is an address, not a loaded pointer")

func _m51_m79(sv: Dictionary) -> void:
	check("M51-T01", MOVE.cast_node_to_button(5, ["Button", "Widget", "Node"]).result == 5 and MOVE.cast_node_to_button(6, ["Widget", "Node"]).result == null, "cast target is Button, not Widget")
	check("M51-T01", MOVE.focus_handler_return().bool_true_claim == "REMOVED_BY_ERRATUM", "bool true claim removed")
	var none: Dictionary = MOVE.player_gate([{"id": 1, "player_component": false}])
	check("PKG-C15-T01", none.continue_tick and not none.component_found and not none.released, "no PlayerComponent -> tick continues")
	var first_nonnull: Dictionary = MOVE.acquire_player_component([{"id": null, "player_component": true}, {"id": 7, "player_component": true, "byte218": 0}, {"id": 8, "player_component": true}])
	check("M79-T01", first_nonnull.component.id == 7 and first_nonnull.strong_acquired, "first non-null dynamic_cast result")
	check("M79-T01", MOVE.player_gate([{"id": 7, "player_component": true, "byte218": 1}]).continue_tick == false, "+218 nonzero -> release and return")
	var dir: Dictionary = sv.M79_direction
	var st := {"facing": int(dir.facing), "pending": false}
	var ok_col := {"observer_dword10": 0, "terrain_reject": false, "portal": false, "actors": []}
	var same: Dictionary = MOVE.manual_move(st, [{"direction": int(dir.facing), "collision": ok_col}], int(dir.original_direction))
	check("PKG-C15-T02", "reset_01FEE540" in same.trace and "skip_this_A6_only" in same.trace and not same.a6_prepared and not same.a8_prepared, "same facing: reset kept, this A6 skipped")
	var a6: Dictionary = MOVE.manual_move(st, [{"direction": 4, "collision": ok_col}], int(dir.original_direction))
	var t: Array = a6.trace
	check("M79-T02", a6.a6_prepared and t.find("write_+50=999") < t.find("call_A6_02476960") and t.find("call_A6_02476960") < t.find("store_+78") and a6.state.field50 == 999 and a6.state.field22 == 0 and a6.sender_success_checked == false, "+50/+22 before A6, +78 after")
	var blocked := {"observer_dword10": 0, "terrain_reject": true}
	var occ := {"observer_dword10": 0, "terrain_reject": false, "portal": false, "self_id": 1, "actors": [{"id": 1, "contains": true, "pred_01C8F9A0": false}, {"id": 2, "component_first_null": true}, {"id": 3, "contains": true, "pred_01C8F9A0": false}]}
	var all_rej: Dictionary = MOVE.manual_move(st, [{"direction": 3, "collision": blocked}, {"direction": 5, "collision": occ}], int(dir.original_direction))
	check("PKG-C15-T03", all_rej.a8_prepared and all_rej.a8_direction_i32 == int(dir.original_direction) and not all_rej.a6_prepared, "all rejected -> A8 with original int32 direction")
	check("M79-T03", MOVE.candidate_collision({"observer_dword10": 1, "terrain_reject": true}).allowed and MOVE.candidate_collision({"observer_dword10": 0, "terrain_reject": false, "portal": true, "actors": [{"id": 3, "contains": true, "pred_01C8F9A0": false}]}).allowed, "observer skips collision; portal skips actor loop")
	check("M79-T03", MOVE.signed_remainder(-3, 8) == -3 and MOVE.signed_remainder(1, 0) == null, "signed remainder; zero divisor rejected")

func _m52(pv: Dictionary) -> void:
	var lab: Dictionary = M52.make_label("atlasA", 1)
	var same: Dictionary = M52.set_atlas(lab, "atlasA")
	check("PKG-C11-T02", same.label.byte3CC == 0 and same.label.retains.is_empty() and same.label.releases.is_empty() and same.ownership_swapped == false, "same non-null atlas clears 3CC, no retain/release")
	var nulls: Dictionary = M52.set_atlas(M52.make_label(null, 1), null)
	check("M52-T01", nulls.label.byte3CC == 1 and nulls.cleared_3cc == false, "same null: no clear")
	check("M52-T01", M52.set_atlas(lab, null).evidence == V.NOT_DESCRIBED, "non-null -> null is not invented")
	var pr: Dictionary = M52.listener_priorities()
	check("M52-T02", pr.purge == int(pv.M52.purge_priority) and pr.reset == int(pv.M52.reset_priority) and pr.event_order_proven == false, "purge 1 / reset 2")
	check("M52-T03", M52.locale_reload(true, false, true, null).combined_success == null, "four separate results")

func _m55_m57() -> void:
	var writer := func(s: Dictionary) -> void: s["active10"] = 0
	var c: Dictionary = REQ.download_play_cancel({"active10": 1, "timer_owner": "T"}, [writer])
	check("M55-T01", c.direct_store_active10 == false and c.active10_invariant_guaranteed == false and c.active10_after == 0 and c.state.timer_owner == null, "no direct store, but invariance not promised")
	var r: Dictionary = REQ.repeating_make(77, 3)
	check("M57-T01", REQ.repeating_countdown(r, 0.5).evidence == V.REJECTED and REQ.repeating_countdown(r, 1).state.countdown == 2, "integer countdown only")
	var target: Array = [10]
	var lookup := func() -> Variant: return target[0]
	target[0] = 11
	var prep: Dictionary = REQ.repeating_prepare_request(r, lookup)
	check("M57-T02", prep.target == 11 and prep.sent == false and prep.visual_effect_created == false, "current target looked up at preparation time; no effect queue")

func _m56_m65(pv: Dictionary) -> void:
	check("M56-T01", FX.buff_gate(1) == "EPILOGUE_BEFORE_BUFF_READ" and FX.buff_gate(0x100) == "PROCESS_BUFF" and FX.buff_gate(0) == "PROCESS_BUFF", "AL nonzero returns before the buff read (AL = low byte)")
	var s2: Dictionary = FX.apply_desired({"live": [1]}, [5], [5], 2)
	check("M56-T02", s2.events.is_empty() and s2.actor.live.is_empty() and s2.actor.desired == [5] and s2.reconcile_complete == false, "state2 skips 2F8/9DD, keeps desired")
	check("M56-T02", FX.apply_desired({}, [], [], 1).events == [0x2F8, 0x9DD], "normal path has both events")
	var p16: Dictionary = FX.packet_sprite_low16(int(pv.M61.input))
	check("M61-T01", p16.stored_i16 == int(pv.M61.stored_i16) and p16.final_sprite == V.UNKNOWN, "65536 -> 0 is width only")
	var m: Dictionary = FX.delay_make()
	var a: Dictionary = FX.delay_admit(m, 100, 7)
	var b: Dictionary = FX.delay_admit(a.manager, 100, 7)
	var c: Dictionary = FX.delay_admit(b.manager, 100, 8)
	check("M62-T02", a.admitted and not a.delayed and b.suppressed and c.admitted, "duplicate suppression keyed by sprite + source position; not a delay")
	var sel: Dictionary = FX.special_attack_select(int(pv.M63.index), int(pv.M63.count))
	check("PKG-C09-T01", sel.remainder_u64 == int(pv.M63.remainder) and sel.address_index_i32 == int(pv.M63.address_index), "remainder 2147483648 vs index -2147483648 (got %s)" % str(sel))
	check("M63-T01", sel.sprite_id_byte_offset == int(pv.M63.address_index) * 0x28 + 0x18 and FX.special_attack_select(3, 0).evidence == V.REJECTED, "stride/offset; count 0 rejected")
	var t: Dictionary = FX.materialize_tick([1, 2], 1, true, "null", {"luid": 9})
	check("PKG-C09-T02", t.pending == [2] and t.fallback_ids == {"luid": 9} and t.null_outcome_is_external_oracle, "pending removed on null; fallback kept")
	check("PKG-C09-T02", FX.materialize_tick([1], 1, true, "nonnull", {"luid": 9}).fallback_ids.is_empty() and FX.materialize_tick([1], 1, false, "nonnull", {}).evidence == V.REJECTED, "fallback cleared only on nonnull; null actor rejected")

func _m59_m60() -> void:
	var tl: Dictionary = LIFE.make_ref("timeline", {"speed": 2}, "cb")
	LIFE.retain(tl)
	var r1: Dictionary = LIFE.manager_remove(tl)
	check("M59-T01", r1.fields_preserved and tl.fields.speed == 2 and tl.callback_storage == "cb" and r1.paused == false, "other retain left: fields kept")
	var r2: Dictionary = LIFE.manager_remove(tl)
	check("M59-T01", r2.destructor_ran and tl.callback_storage == null and LIFE.retain(tl) == false, "final release destroys callback storage")
	var w: Dictionary = LIFE.make_ref("widget", {})
	var owner: Dictionary = LIFE.make_ref("raw_owner", {})
	check("M59-T02", LIFE.sender_retain(w, owner).raw_owner_refs_unchanged and w.refs == 2, "sender retain does not retain raw owner")
	var sch = LIFE.Scheduler.new()
	var seen: Array = []
	var inner_queue := func(s) -> void: seen.append(["inner_queue", s.flag61])
	var outer_timer := func(s) -> void:
		seen.append(["outer_timer_before", s.flag61])
		s.scheduled = []
		s.update([inner_queue])
		seen.append(["outer_timer_after", s.flag61])
	sch.scheduled = [outer_timer]
	var outer_queue := func(s) -> void: seen.append(["outer_queue", s.flag61])
	sch.update([outer_queue])
	check("M60-T01", seen == [["outer_queue", 0], ["outer_timer_before", 1], ["inner_queue", 1], ["outer_timer_after", 0]], "+61 seen by nested queue is 1; inner return writes 0 (got %s)" % str(seen))
	var count: Array = [0]
	var cb := func(_s) -> void: count[0] += 1
	sch.scheduled = [cb]
	var snapshot: Array = sch.scheduled.duplicate()
	sch.unschedule_all()
	sch.clear_pending()
	check("PKG-C13-T03", sch.run_cloned_snapshot(snapshot) == 1 and count[0] == 1 and sch.scheduled.is_empty(), "cloned snapshot still runs after unscheduleAll/pending clear")

func _ui(pv: Dictionary) -> void:
	check("M66-T01", UIW.craft_submit([]).events == [int(pv.M66.event)] and UIW.craft_submit([]).request.items.is_empty() and UIW.craft_submit(null).evidence == V.NOT_DESCRIBED and UIW.craft_submit(null).request == null, "present-empty -> event213 + empty request; null differs")
	var pd: Dictionary = UIW.quest_parent_detail(null, {"t": 1})
	check("PKG-C17-T01", pd.steps == ["refreshGoals_end_missing", "reward", "story"] and pd.refresh_goals_ended_early, "missing goal ends refreshGoals; parent continues")
	check("PKG-C17-T01", UIW.quest_goals_only_local147(null, {}).steps == ["refreshGoals_end_missing"], "goals-only consumer has no parent processing")
	var row: Dictionary = UIW.chat_row("old")
	row["dirty"] = true
	var saw: Array = [""]
	var fmt_empty := func(r: Dictionary) -> String:
		saw[0] = r.dynamic_map.message
		return ""
	var u1: Dictionary = UIW.chat_update(row, "first", fmt_empty)
	check("M69-T01", saw[0] == "first" and u1.row.cache730 == "first" and u1.row.rich_builds == 0 and u1.row.dirty == true, "message changed before formatter; empty skips rich only")
	var u2: Dictionary = UIW.chat_update(u1.row, "second", func(r: Dictionary) -> String: return "<b>" + r.dynamic_map.message)
	check("M69-T01", u2.row.cache730 == "first" and u2.row.rich == "<b>second" and u2.row.rich_builds == 1, "+730 first-message cache kept")
	var e0: Dictionary = UIW.expedition_refresh(0, [3, 4])
	check("M70-T01", e0.trace == ["helper_skipped_spot0", "card_3_F9", "card_3_FA", "card_4_F9", "card_4_FA"], "spot0 skips helper, caller F9/FA continue")
	check("M70-T02", UIW.expedition_state(0, 5).setter_called == false and UIW.expedition_state(3, 0xFFFFFFFF).snapshot_count_i32 == -1 and UIW.expedition_state(3, 0xFFFFFFFF).iterations == 0, "state0 skip; state3 signed count")
	var ids: Array = (pv.M71.candidate_ids as Array).map(func(x: Variant) -> int: return int(x))
	var only22: Dictionary = UIW.collection_rows([{"id": ids[0], "grade_widget": false}])
	check("M71-T01", only22.rows == [22] and only22.radios.is_empty(), "22 null: rows 22, no radios")
	var both: Dictionary = UIW.collection_rows([{"id": ids[0], "grade_widget": false}, {"id": ids[1]}])
	check("PKG-C17-T02", both.rows == [22, 24] and both.radios == [24] and both.first_radio_callback == 24 and both.setters == [22, 24], "first radio callback is 24")
	check("M71-T02", UIW.timeline_factory(true, false).frame_event_callback_registered == false and UIW.timeline_factory(true, true).frame_event_callback_registered and UIW.timeline_factory(false, true).root50 == null and not UIW.timeline_factory(true, true).is_popup_node_factory, "0338C360 is createTimeline wrapper")
	var root := {"root50": "A"}
	root["root50"] = "B"
	check("M71-T02", UIW.collection_destructor(root).released == "B", "destructor reads root+50 fresh")
	var pr: Dictionary = UIW.parcel_row(null, 1, null)
	check("M73-T01", pr.steps.slice(0, 4) == ["retain", "row_lookup", "string_cleanup", "expiry_guard_skip"] and "item_unread" in pr.steps and "visibility_guard_skip" in pr.steps, "expiry guard after cleanup; separate guards")
	var mk: Dictionary = UIW.market_register(["a", "b", null, "d", "e"], "P", null, "o20", false)
	check("PKG-C17-T03", not ("fee_callback_register" in mk.trace) and not ("clear_1" in mk.trace) and "ready=0" in mk.trace and "show_attempt" in mk.trace and "incoming_shared_cleanup" in mk.trace and mk.existing_slot_cleared == false, "one label null: only fee/clear skipped")
	var full: Dictionary = UIW.market_register(["a", "b", "c", "d", "e"], "P", "o18", null, true)
	check("M75-T01", "local870" in full.trace and "optional+18" in full.trace and not ("optional+20" in full.trace) and "animation" in full.trace and UIW.market_register([], null, null, null, false).evidence == V.REJECTED, "optional guards; primary+10 unguarded rejected")

func _m74(pv: Dictionary) -> void:
	var session: Dictionary = {}
	var aliases := {"EMPTYKEY": "", "PANEL": "Nd.Panel_Arrow"}
	var miss: Dictionary = ALIAS.lookup(aliases, "nokey", session)
	var empty_hit: Dictionary = ALIAS.lookup(aliases, "emptykey", session)
	check("PKG-C11-T01", miss.nonnull and miss.value == "" and miss.identity.ends_with(pv.M74.shared_empty_address) and empty_hit.value == "" and miss.identity != empty_hit.identity, "miss = shared-empty identity, not node+40")
	check("PKG-C11-T01", ALIAS.typed_text(miss) == null and ALIAS.typed_text(empty_hit) == null and miss.effects[0] == "singleton_init_or_file_read" and empty_hit.effects[0] != "singleton_init_or_file_read", "typed helper null; query side effects recorded")
	var tree := {"name": "root", "children": [{"name": "Nd", "children": [{"name": "Other", "children": []}]}, {"name": "Nd", "children": [{"name": "Panel_Arrow", "children": []}]}]}
	check("M74-T01", ALIAS.walk(tree, "Nd.Panel_Arrow") == null, "first exact direct child only; no backtracking to the second Nd")
	var r: Dictionary = ALIAS.resolve_alias_node(aliases, null, "panel", {})
	check("M74-T02", r.node == null and r.queries == 2 and r.root_checked_after_second_query, "non-empty alias: second query before root check")
	check("M74-T02", ALIAS.resolve_alias_node(aliases, tree, "missing", {}).queries == 1, "empty alias stops after one query")
	check("M74-T03", ALIAS.detach_then_layout_cast({"name": "n"}, ["Layout", "Widget"]).trace == ["detach_from_parent", "cast_to_Layout"] and ALIAS.ALIAS_SURVEY_COUNT == int(pv.M74.alias_survey_count), "detach before Layout cast")

func _m76_m77(pv: Dictionary, sv: Dictionary) -> void:
	var add: Dictionary = IMG.cache_add({}, "t", false, true, false)
	check("PKG-C13-T01", add.inserted and add.cache.has("t") and add.image_bool_used == false and IMG.cache_add({}, "u", true, false, true).inserted == false, "Texture bool gates insertion; Image bool ignored")
	check("M76-T01", IMG.apply_selected_result(null).visible == false and IMG.apply_selected_result(null).texture == "UNCHANGED" and IMG.setter_null().texture == "WHITE_TEXTURE_SUBSTITUTE", "null result hides; setter(null) white")
	var cache := {"a": {"refs": 1}, "held": {"refs": 2}}
	var s1: Dictionary = IMG.sweep(cache)
	var released: Dictionary = s1.cache.duplicate(true)
	released.held.refs = 1
	var s2: Dictionary = IMG.sweep(released)
	check("PKG-C13-T02", s1.removed == ["a"] and s1.cache.has("held") and s2.removed == ["held"], "held texture survives until a later sweep")
	check("M76-T02", IMG.close_screen(cache).order == ["transition_virtual_effects", "sweep_ref1", "csb_clear"], "sweep before CSB clear")
	var n: Array = sv.M77_alloc_cases.normal
	var w0: Array = sv.M77_alloc_cases.wrap_zero
	var ng: Array = sv.M77_alloc_cases.negative_low32
	check("M77-T01", IMG.cpu_alloc_bytes(n[0], n[1], n[2]).malloc_u32 == 3240000 and IMG.cpu_alloc_bytes(w0[0], w0[1], w0[2]).malloc_u32 == 0, "low32 product /8")
	var neg: Dictionary = IMG.cpu_alloc_bytes(ng[0], ng[1], ng[2])
	check("M77-T01", neg.product_i32 == -2147483640 and neg.div8_trunc == -268435455 and neg.malloc_u32 == 4026531841 and IMG.gpu_temp_bytes(1, 536870912) == -2147483648, "signed /8 toward zero, u32 zero-extend; GPU temp sign-extends (got %s)" % str(neg))
	var env: Array = pv.M77.fixed_envelope
	var plan: Dictionary = IMG.resample_plan(env[0], env[1], float(pv.M77.cx), float(pv.M77.cy))
	check("PKG-C14-T01", plan.requested == Vector2i(600, 337) and plan.write_envelope == Vector2i(1200, 675) and plan.normal_success == false, "requested dims vs fixed envelope; shortfall not hidden")
	var tex := {"name": 4, "width": 10, "height": 10, "unpack_alignment": 4}
	var bad: Dictionary = IMG.init_with_mipmaps(tex, true, 64, 64, 1, true)
	check("PKG-C14-T02", bad.return_bool == false and bad.texture.name == 5 and bad.texture.unpack_alignment == 1 and bad.texture.width == 10 and bad.restored == false, "new name/alignment with old metadata")
	check("M77-T02", IMG.update_with_data(0).return_bool == false and IMG.update_with_data(3).return_bool and IMG.update_with_data(3).gl_error_checked == false, "update: no glGetError")
	check("M77-T02", IMG.GL_PIXEL_UNPACK_BUFFER == 0x88EC and IMG.GL_PIXEL_UNPACK_BUFFER_BINDING == 0x88EF and IMG.scale_samples(0.5, 0.5, 0.5, 0.5).single_snapshot == false, "target vs binding pname")

func _m78() -> void:
	var s: Dictionary = TF.attach(TF.make(["A", "B"]), "A")
	var inactive: Dictionary = TF.press_lf(s, "B", true)
	check("PKG-C12-T01", inactive.fields.B.hook_flag == false and inactive.events[-1] == "detach_request" and inactive.active == "A", "inactive field: request, no hook/flag")
	var det: Dictionary = TF.press_lf(s, "A", true)
	var ev: Array = det.events
	check("M78-T01", det.active == null and ev.find("hook_flag_set") < ev.find("active_cleared") and ev.find("active_cleared") < ev.find("didDetach") and ev.find("didDetach") < ev.find("observer"), "flag, clear, didDetach, observer are ordered steps")
	var tail: Dictionary = TF.tail_dispatch(det)
	check("PKG-C12-T02", not (str(tail.events).contains("event4")), "fresh active null: no forced event4")
	var again: Dictionary = TF.attach(s, "A")
	check("PKG-C12-T03", again.events[-1] == "attach_early_return_same_state", "same-attached early return")
	var rm: Dictionary = TF.remove_delegate(s, "A")
	check("M78-T02", rm.active == null and not ("didDetach" in rm.events) and not ("observer" in rm.events) and rm.renderer_attached_may_remain, "removeDelegate is not detach")

func _m80(pv: Dictionary) -> void:
	var mm: Dictionary = MARK.make()
	var a: Dictionary = MARK.apply_snapshot(mm, {"status": "valid", "target": 9, "visible": true})
	var dup: Dictionary = MARK.apply_snapshot(a.state, {"status": "valid", "target": 9, "visible": false})
	check("PKG-C10-T01", dup.path == "UPDATE_SAME_NODE" and dup.state.factory_calls == 1 and dup.state.markers[9].node == a.state.markers[9].node, "duplicate updates same node")
	var expd: Dictionary = MARK.apply_snapshot(dup.state, {"status": "expired", "target": 9})
	check("PKG-C18-T02", expd.path == "PRESERVE_EXISTING" and expd.state.markers[9].setter_visible == false and MARK.apply_snapshot(dup.state, {"status": "alias_null"}).path == "PRESERVE_EXISTING", "expired/alias-null keep marker")
	var back: Dictionary = MARK.apply_snapshot(MARK.remove(dup.state, 9), {"status": "valid", "target": 9})
	check("M80-T01", back.path == "NEW_INSTANCE" and back.state.factory_calls == 2 and back.state.markers[9].node != a.state.markers[9].node and MARK.refresh(dup.state).reattach_calls == 1, "remove then reappear -> new instance; refresh reattaches")
	var h: Dictionary = MARK.hide(dup.state)
	check("PKG-C10-T02", h.view_visible == false and h.subscribed and not h.destroyed and h.markers.has(9), "hide is not unsubscribe/destroy")
	var tag: Dictionary = MARK.arrow_after_timeline(dup.state.markers[9], true)
	check("M80-T02", tag.tag == int(pv.M80.tag) and tag.helper_ran == false, "tag 1234567 written without timeline null guard")
	var f: Dictionary = MARK.frame_visibility(dup.state.markers[9], 20)
	check("PKG-C18-T01", f.setter_visible == false and f.final_visibility == "NOT_OBSERVED" and f.track_windows_containing_frame == [[5, 30]] and MARK.frame_visibility(dup.state.markers[9], 32).track_windows_containing_frame.is_empty(), "setter vs per-frame visibility")

func _m81(pv: Dictionary, sv: Dictionary) -> void:
	var interval: float = float(pv.M81.interval)
	var eq: Dictionary = AUTO.timer_step(0.0, float(pv.M81.equal_case_elapsed), interval)
	var acc: Dictionary = AUTO.timer_step(0.0, float(pv.M81.accumulated_case), interval)
	check("PKG-C20-T01", eq.fired == false and acc.fired and acc.elapsed == float(pv.M81.expected_remaining), "0.5 == 0.5 no fire; 0.75 -> 0.25")
	var big: Dictionary = AUTO.timer_step(0.0, 5.0, interval)
	check("M81-T01", big.fired and big.elapsed == 4.5 and AUTO.timer_step(0.0, NAN, interval).fired == false, "subtract once; NaN no fire")
	check("M81-T01", "%08X" % V.f32_bits(AUTO.delta_seconds(int(sv.M81_delta_qword.value))) == sv.M81_delta_qword.expected_seconds_f32_bits, "qword -> f32 / 1000.0f")
	var order: Array = []
	var q := func() -> void: order.append("queued")
	var sp := func() -> bool:
		order.append("spell")
		return true
	var ax := func() -> bool:
		order.append("aux")
		return false
	var off: Dictionary = AUTO.manager_callback(false, true, q, sp, ax)
	check("PKG-C20-T02", off.trace == ["queued_pass", "enable_D8_false_stop"] and order == ["queued"], "queued pass before enable gate")
	order.clear()
	var on: Dictionary = AUTO.manager_callback(true, true, q, sp, ax)
	check("PKG-C20-T08", on.result == true and order == ["queued", "spell", "aux"], "aux pass runs after a true spell pass")
	var sw: Dictionary = AUTO.sweep([{"page": 0, "button": 1}, {"page": 0, "button": 2}, {"page": 0, "button": 3}], func(p: Dictionary) -> String: return "SUCCESS" if int(p.button) != 2 else "NEXT")
	check("PKG-C20-T08", sw.visited == 3 and sw.events.size() == 2 and sw.result, "sweep continues after success")
	var A := {"id": 1}
	var B := {"id": 2}
	var O := {"id": 3}
	var e3: Dictionary = _env([A, null], O, true, 1)
	var r3: Dictionary = AUTO.evaluate_pair(false, e3)
	check("PKG-C20-T03", r3.outcome == "NEXT_PAIR" and r3.calls == ["getter1", "getter2", "slot_shared_cleanup"] and (e3.reads as Array).is_empty(), "A then null: no fallback/cooldown/reads")
	var r4: Dictionary = AUTO.evaluate_pair(false, _env([A, B], O, false, 1))
	check("PKG-C20-T04", r4.meta == B and "learned_exempt_by_first_return" in r4.calls and r4.outcome == "RESOURCES_OBSERVED", "B metadata, learned basis A")
	var r5: Dictionary = AUTO.evaluate_pair(false, _env([null], O, true, 1))
	check("PKG-C20-T05", r5.meta == O and r5.calls.count("ordinary_lookup") == 1 and "learned:3" in r5.calls, "ordinary once; learned with O.ID")
	var e6: Dictionary = _env([null], O, true, 2)
	AUTO.evaluate_pair(false, e6)
	var e6b: Dictionary = _env([null], O, true, 255)
	AUTO.evaluate_pair(false, e6b)
	check("PKG-C20-T06", not ("passive" in e6.reads) and not ("passive" in e6b.reads), "v78 2/255: no passive read")
	var e7: Dictionary = _env([null], O, true, 1)
	var r7: Dictionary = AUTO.evaluate_pair(false, e7)
	check("PKG-C20-T07", e7.reads == ["HPCost", "HP_stat4", "meta_ID", "MPcost", "MP_stat6", "self_v78", "passive", "category", "maxMP_stat5"] and r7.values.HPCost == 1 and r7.values.maxMP_stat5 == 9, "observed read order, each read once")
	var fl: Dictionary = AUTO.make_flags()
	check("PKG-C20-T09", AUTO.reservation_step(fl, false, 10, 10, 10, 10) == "ABORT_SWEEP_RETURN_ACCUMULATED" and fl.hpShort == true and fl.mpShort == false, "HP==cost short (<=), MP==cost not short (<)")
	var fl2: Dictionary = {"mpShort": true, "hpShort": true, "failedMP": false, "failedHP": false}
	check("PKG-C20-T09", AUTO.reservation_step(fl2, true, 10, 10, 10, 10) == "SKIP" and AUTO.reservation_step({"mpShort": false, "hpShort": true}, true, 10, 10, 10, 10) == "PROCEED", "ready: MP>=cost vs HP>cost")
	var m: Dictionary = AUTO.make_manager()
	var c: Dictionary = AUTO.clear_selected(m)
	check("PKG-C20-T10", c.v28.size == 0 and c.v40.size == 0 and c.v58.size == 0 and c.v28.capacity == 8 and c.virtual70 == m.virtual70 and c.queued_F0 == m.queued_F0 and c.enable_D8 and c.clock == m.clock and c.main_elapsed == m.main_elapsed, "end=begin only")
	var qs: Dictionary = AUTO.queue_single(m, {"page": 2, "button": 3}, true)
	check("M81-T02", qs.queued_F0.nodes.size() == 1 and qs.queued_F0.sentinel and AUTO.timer_step(qs.main_elapsed, 0.0).fired == false and AUTO.clear_queued(m).queued_F0.sentinel, "v58 sets elapsed=interval; next zero delta does not fire")
	var pairs: Array = sv.M81_pairs.pairs
	var lo: Dictionary = AUTO.build_local_order(pairs, true, [{"page": 9, "button": 9}], func(_a: Array) -> void: pass)
	check("M81-T03", AUTO.priority_key(pairs[2]) == -2147483646 and lo.order[0].page == 9 and lo.order[1].page == 429496730 and lo.order[2].button == 4 and lo.order[3].button == 2, "signed32 key wrap; virtual pairs in front (got %s)" % str(lo.order))
	var shuffled: Dictionary = AUTO.build_local_order(pairs, false, [], func(a: Array) -> void: a.reverse())
	check("M81-T03", shuffled.order[0].page == 429496730 and pairs[0].page == 1, "non-priority shuffles the local copy in place")

class Env:
	extends RefCounted
	## Synthetic per-call answers for the M81 metadata/resource readers.
	var answers: Array
	var idx: int = 0
	var ordinary_value: Variant
	var learned_ok: bool
	var v78: int
	var reads: Array = []

	func getter() -> Variant:
		var r: Variant = answers[idx]
		idx += 1
		return r

	func ordinary() -> Variant:
		return ordinary_value

	func cooldown_ready(_m: Variant) -> bool:
		return true

	func learned(_id: Variant) -> bool:
		return learned_ok

	func read(name: String) -> int:
		reads.append(name)
		return v78 if name == "self_v78" else reads.size()

func _env(answers: Array, ordinary: Variant, learned_ok: bool, v78: int) -> Dictionary:
	var e := Env.new()
	e.answers = answers
	e.ordinary_value = ordinary
	e.learned_ok = learned_ok
	e.v78 = v78
	return {"getter": e.getter, "ordinary": e.ordinary, "cooldown_ready": e.cooldown_ready, "learned": e.learned, "read": e.read, "reads": e.reads, "obj": e}
